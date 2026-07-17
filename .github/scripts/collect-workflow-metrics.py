#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda.
# SPDX-License-Identifier: MIT
"""Create compact, reproducible GitHub Actions timing evidence for one run."""
from __future__ import annotations

import argparse
import json
import subprocess
from datetime import datetime
from pathlib import Path


def api(endpoint: str) -> object:
    result = subprocess.run(["gh", "api", endpoint], check=True, capture_output=True, text=True)
    return json.loads(result.stdout)


def seconds(start: str | None, end: str | None) -> float | None:
    if not start or not end:
        return None
    parse = lambda value: datetime.fromisoformat(value.replace("Z", "+00:00"))
    return round((parse(end) - parse(start)).total_seconds(), 3)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo", required=True)
    parser.add_argument("--run-id", required=True)
    parser.add_argument("--output", required=True)
    args = parser.parse_args()
    run = api(f"repos/{args.repo}/actions/runs/{args.run_id}")
    jobs = api(f"repos/{args.repo}/actions/runs/{args.run_id}/jobs?per_page=100")["jobs"]
    artifacts = api(f"repos/{args.repo}/actions/runs/{args.run_id}/artifacts?per_page=100")["artifacts"]
    compact_jobs = []
    for job in jobs:
        compact_jobs.append({
            "name": job["name"], "runner": job.get("runner_name"), "labels": job.get("labels", []),
            "started_at": job.get("started_at"), "completed_at": job.get("completed_at"),
            "elapsed_seconds": seconds(job.get("started_at"), job.get("completed_at")), "conclusion": job.get("conclusion"),
            "steps": [{"name": step["name"], "started_at": step.get("started_at"), "completed_at": step.get("completed_at"), "conclusion": step.get("conclusion"), "elapsed_seconds": seconds(step.get("started_at"), step.get("completed_at"))} for step in job.get("steps", [])],
        })
    report = {
        "workflow": run["name"], "run_id": int(args.run_id), "event": run["event"], "head_sha": run["head_sha"], "attempt": run["run_attempt"],
        "status": run["status"], "conclusion": run["conclusion"], "created_at": run["created_at"], "started_at": run.get("run_started_at"), "updated_at": run["updated_at"],
        "queue_seconds": seconds(run["created_at"], run.get("run_started_at")), "elapsed_seconds": seconds(run.get("run_started_at"), run["updated_at"]),
        "runner_jobs": len([job for job in compact_jobs if job["started_at"]]), "jobs": compact_jobs,
        "artifacts": [{"name": item["name"], "size_in_bytes": item["size_in_bytes"]} for item in artifacts],
        "cache_status": "not available from the Actions run API",
    }
    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
