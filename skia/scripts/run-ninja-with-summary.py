#!/usr/bin/env python3
import argparse
import datetime as dt
import json
import os
import re
import subprocess
import sys
import time
from pathlib import Path


PROGRESS_RE = re.compile(r"^\[\d+/\d+\]")
FAILED_RE = re.compile(r"^FAILED:\s*(?P<target>.+)")
CLANG_GCC_RE = re.compile(
    r"^(?P<file>.*?):(?P<line>\d+):(?:(?P<column>\d+):)?\s*"
    r"(?P<severity>fatal error|error|warning|note):\s*(?P<message>.*)$"
)
MSVC_RE = re.compile(
    r"^(?P<file>.+?)\((?P<line>\d+)(?:,(?P<column>\d+))?\):\s*"
    r"(?P<severity>fatal error|error|warning|note)\s*(?:[A-Z]+\d+)?:\s*(?P<message>.*)$"
)

LINKER_PATTERNS = (
    re.compile(r"\bld(?:\.lld|64)?(?:\.exe)?:", re.IGNORECASE),
    re.compile(r"\bundefined reference\b", re.IGNORECASE),
    re.compile(r"\bduplicate symbol\b", re.IGNORECASE),
    re.compile(r"\bcollect2:\s*error:", re.IGNORECASE),
)

GENERIC_DIAGNOSTIC_PATTERNS = (
    ("error", re.compile(r"\b(?:fatal error|clang: error|error):", re.IGNORECASE)),
    ("warning", re.compile(r"\bwarning:", re.IGNORECASE)),
    ("note", re.compile(r"\bnote:", re.IGNORECASE)),
)

MAX_CONSOLE_LINE = 4000
MAX_CONTEXT_LINES = 12
MAX_SUMMARY_ENTRIES = 500


def utc_now():
    return dt.datetime.now(dt.timezone.utc)


def isoformat(value):
    return value.isoformat(timespec="seconds").replace("+00:00", "Z")


def truncate_for_console(line):
    if len(line) <= MAX_CONSOLE_LINE:
        return line
    return line[:MAX_CONSOLE_LINE] + " ... [truncated in console; see build-full.log]"


def normalized_diagnostic(line):
    for matcher in (CLANG_GCC_RE, MSVC_RE):
        match = matcher.match(line)
        if match:
            data = match.groupdict()
            severity = data["severity"]
            if severity == "fatal error":
                severity = "error"
            return {
                "file": data.get("file"),
                "line": int(data["line"]) if data.get("line") else None,
                "column": int(data["column"]) if data.get("column") else None,
                "severity": severity,
                "message": data.get("message", ""),
                "raw_line": line,
            }

    for severity, matcher in GENERIC_DIAGNOSTIC_PATTERNS:
        if matcher.search(line):
            return {
                "file": None,
                "line": None,
                "column": None,
                "severity": severity,
                "message": line.strip(),
                "raw_line": line,
            }

    return None


def is_linker_diagnostic(line):
    return any(pattern.search(line) for pattern in LINKER_PATTERNS)


def should_print_line(line, failure_context_remaining):
    diagnostic = normalized_diagnostic(line)

    if PROGRESS_RE.match(line):
        return True
    if FAILED_RE.match(line):
        return True
    if "ninja: error:" in line:
        return True
    if is_linker_diagnostic(line):
        return True
    if failure_context_remaining > 0 and line.strip():
        return True
    if diagnostic and diagnostic["severity"] == "error":
        return True
    return False


def append_limited(items, item):
    if len(items) < MAX_SUMMARY_ENTRIES:
        items.append(item)


def process_lines(lines, command, build_dir, full_log_path, started_at, ended_at, exit_code):
    failed_targets = []
    errors = []
    warnings = []
    notes = []
    linker_diagnostics = []
    contexts = []

    for index, line in enumerate(lines):
        failed = FAILED_RE.match(line)
        if failed:
            target = failed.group("target").strip()
            if target and target not in failed_targets:
                append_limited(failed_targets, target)
            start = max(0, index - 3)
            end = min(len(lines), index + MAX_CONTEXT_LINES + 1)
            append_limited(
                contexts,
                {
                    "line": index + 1,
                    "trigger": line,
                    "before": lines[start:index],
                    "after": lines[index + 1 : end],
                },
            )

        diagnostic = normalized_diagnostic(line)
        if diagnostic:
            if diagnostic["severity"] == "warning":
                append_limited(warnings, diagnostic)
            elif diagnostic["severity"] == "note":
                append_limited(notes, diagnostic)
            else:
                append_limited(errors, diagnostic)

        if is_linker_diagnostic(line):
            append_limited(
                linker_diagnostics,
                {
                    "message": line.strip(),
                    "raw_line": line,
                    "line": index + 1,
                },
            )

    return {
        "status": "success" if exit_code == 0 else "failure",
        "exit_code": exit_code,
        "build_command": command,
        "build_dir": str(build_dir),
        "timestamps": {
            "started_at": isoformat(started_at),
            "ended_at": isoformat(ended_at),
            "duration_seconds": round((ended_at - started_at).total_seconds(), 3),
        },
        "logs": {
            "full": str(full_log_path),
        },
        "failed_targets": failed_targets,
        "errors": errors,
        "warnings": warnings,
        "notes": notes,
        "linker_diagnostics": linker_diagnostics,
        "contexts": contexts,
        "limits": {
            "max_summary_entries_per_section": MAX_SUMMARY_ENTRIES,
            "max_context_lines_after_failure": MAX_CONTEXT_LINES,
        },
    }


def run_command(command, build_dir, logs_dir):
    logs_dir.mkdir(parents=True, exist_ok=True)
    full_log_path = logs_dir / "build-full.log"
    summary_path = logs_dir / "build-summary.json"

    started_at = utc_now()
    lines = []
    exit_code = 127
    failure_context_remaining = 0

    with full_log_path.open("w", encoding="utf-8", errors="replace", newline="") as full_log:
        full_log.write("$ " + " ".join(command) + "\n")
        full_log.write("started_at=" + isoformat(started_at) + "\n")
        full_log.flush()

        try:
            process = subprocess.Popen(
                command,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                bufsize=0,
            )
        except OSError as exc:
            line = f"error: failed to start build command: {exc}"
            full_log.write(line + "\n")
            print(line, flush=True)
            lines.append(line)
        else:
            assert process.stdout is not None
            for raw_line_bytes in process.stdout:
                raw_line = raw_line_bytes.decode("utf-8", errors="replace")
                line = raw_line.rstrip("\r\n")
                full_log.write(raw_line)
                lines.append(line)

                if FAILED_RE.match(line):
                    failure_context_remaining = MAX_CONTEXT_LINES

                if should_print_line(line, failure_context_remaining):
                    print(truncate_for_console(line), flush=True)

                if failure_context_remaining > 0 and not FAILED_RE.match(line):
                    failure_context_remaining -= 1

            exit_code = process.wait()

    ended_at = utc_now()
    summary = process_lines(lines, command, build_dir, full_log_path, started_at, ended_at, exit_code)
    summary_path.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    return exit_code


def parse_args(argv):
    parser = argparse.ArgumentParser(description="Run Ninja while preserving full logs and summarizing diagnostics.")
    parser.add_argument("--build-dir", required=True, type=Path)
    parser.add_argument("--logs-dir", required=True, type=Path)
    parser.add_argument("--target", default="")
    parser.add_argument("command", nargs=argparse.REMAINDER)
    args = parser.parse_args(argv)
    if args.command and args.command[0] == "--":
        args.command = args.command[1:]
    if not args.command:
        parser.error("missing command after --")
    return args


def main(argv=None):
    args = parse_args(argv or sys.argv[1:])
    return run_command(args.command, args.build_dir, args.logs_dir)


if __name__ == "__main__":
    sys.exit(main())
