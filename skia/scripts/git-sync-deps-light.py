#!/usr/bin/env python3
import argparse
import pathlib
import shutil
import subprocess
import sys


def run(cmd, cwd=None, quiet=False, check=True):
    if not quiet:
        print("+ " + " ".join(cmd), flush=True)
    return subprocess.run(
        cmd,
        cwd=str(cwd) if cwd else None,
        check=check,
        universal_newlines=True,
        stdout=subprocess.PIPE if quiet else None,
        stderr=subprocess.STDOUT if quiet else None,
    )


def quiet_output(cmd, cwd=None):
    result = run(cmd, cwd=cwd, quiet=True, check=False)
    if result.returncode != 0:
        return ""
    return result.stdout.strip()


def read_deps(deps_path):
    scope = {}

    def var(name):
        return scope["vars"][name]

    scope.update(
        {
            "Var": var,
            "vars": {},
            "deps": {},
            "deps_os": {},
            "hooks": [],
            "recursedeps": [],
            "use_relative_paths": False,
        }
    )

    exec(deps_path.read_text(encoding="utf-8"), {}, scope)
    return scope


def normalize_dep(dep_path, dep_value):
    if dep_value is None:
        return None

    if isinstance(dep_value, dict):
        dep_value = dep_value.get("url")

    if not dep_value:
        return None

    if not isinstance(dep_value, str):
        raise ValueError(f"unsupported DEPS value for {dep_path!r}: {dep_value!r}")

    rel_path = pathlib.PurePosixPath(dep_path)
    if rel_path.is_absolute() or ".." in rel_path.parts:
        return None

    if "@" not in dep_value:
        raise ValueError(f"dependency {dep_path!r} is not pinned to a commit: {dep_value!r}")

    url, commit = dep_value.rsplit("@", 1)
    if not url or not commit:
        raise ValueError(f"dependency {dep_path!r} has an invalid URL/commit: {dep_value!r}")

    return dep_path, url, commit


def dependency_entries(scope):
    entries = []
    for dep_path, dep_value in sorted(scope.get("deps", {}).items()):
        normalized = normalize_dep(dep_path, dep_value)
        if normalized:
            entries.append(normalized)
    return entries


def ensure_repo(repo_dir, url):
    repo_dir.parent.mkdir(parents=True, exist_ok=True)

    if not (repo_dir / ".git").is_dir():
        if repo_dir.exists():
            shutil.rmtree(str(repo_dir))
        repo_dir.mkdir(parents=True, exist_ok=True)
        run(["git", "init", "-q"], cwd=repo_dir)

    current_origin = quiet_output(["git", "remote", "get-url", "origin"], cwd=repo_dir)
    if current_origin:
        if current_origin != url:
            run(["git", "remote", "set-url", "origin", url], cwd=repo_dir)
    else:
        run(["git", "remote", "add", "origin", url], cwd=repo_dir)


def is_at_commit(repo_dir, commit):
    head = quiet_output(["git", "rev-parse", "HEAD"], cwd=repo_dir)
    return head == commit


def fetch_commit(repo_dir, commit):
    fetch_base = ["git", "fetch", "--depth=1", "origin", commit]
    fetch_filtered = ["git", "fetch", "--filter=blob:none", "--depth=1", "origin", commit]

    result = run(fetch_filtered, cwd=repo_dir, check=False)
    if result.returncode != 0:
        print(f"warning: filtered fetch failed for {repo_dir}; retrying without blob filter", file=sys.stderr)
        run(fetch_base, cwd=repo_dir)

    run(["git", "checkout", "--detach", "-q", "FETCH_HEAD"], cwd=repo_dir)


def sync_deps(skia_dir, dry_run):
    deps_path = skia_dir / "DEPS"
    if not deps_path.is_file():
        raise SystemExit(f"missing Skia DEPS file at {deps_path}")

    entries = dependency_entries(read_deps(deps_path))
    if dry_run:
        for rel_path, url, commit in entries:
            print(f"{rel_path} {url} {commit}")
        return

    synced = 0
    already_current = 0
    for rel_path, url, commit in entries:
        repo_dir = skia_dir / pathlib.PurePosixPath(rel_path)
        ensure_repo(repo_dir, url)
        if is_at_commit(repo_dir, commit):
            already_current += 1
            continue
        print(f"Syncing {rel_path} -> {commit}", flush=True)
        fetch_commit(repo_dir, commit)
        synced += 1

    print(f"Skia deps ready: {already_current} current, {synced} synced", flush=True)


def parse_args(argv):
    script_dir = pathlib.Path(__file__).resolve().parent
    default_skia_dir = script_dir.parent / "skia"

    parser = argparse.ArgumentParser(description="Lightweight Skia DEPS sync.")
    parser.add_argument("--skia-dir", type=pathlib.Path, default=default_skia_dir)
    parser.add_argument("--dry-run", action="store_true")
    return parser.parse_args(argv)


def main(argv=None):
    args = parse_args(argv or sys.argv[1:])
    sync_deps(args.skia_dir.resolve(), args.dry_run)
    return 0


if __name__ == "__main__":
    sys.exit(main())
