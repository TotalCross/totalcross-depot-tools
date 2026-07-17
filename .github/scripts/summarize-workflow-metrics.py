#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda.
# SPDX-License-Identifier: MIT
"""Summarize compact workflow-metrics JSON files as Markdown."""
import argparse
import json
from pathlib import Path


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("inputs", nargs="+")
    parser.add_argument("--output", required=True)
    args = parser.parse_args()
    rows = [json.loads(Path(name).read_text(encoding="utf-8")) for name in args.inputs]
    lines = ["| workflow | run | runner jobs | elapsed seconds | cache |", "| --- | ---: | ---: | ---: | --- |"]
    for item in rows:
        lines.append(f"| {item['workflow']} | {item['run_id']} | {item['runner_jobs']} | {item['elapsed_seconds'] or 'n/a'} | {item['cache_status']} |")
    Path(args.output).write_text("\n".join(lines) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
