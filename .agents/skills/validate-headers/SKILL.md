---
name: validate-headers
description: Validate SPDX copyright and MIT license headers on changed or staged first-party files before a commit; use for new files, header fixes, or copyright-check failures, not for generated or vendored artifacts.
---

# Validate changed-file headers

Use the narrowest file set that matches the intended commit.

1. Identify the scope without dumping the whole worktree:

       git diff --name-only --diff-filter=ACMR --cached -- <task paths>

   If nothing is staged, inspect the intended working-tree paths with:

       git diff --name-only --diff-filter=ACMR -- <task paths>

2. Exclude generated, vendored, third-party, build, distribution, and explicitly exempt paths according to `tools/check-copyright.py` and `AGENTS.md`. Do not add repository headers to upstream source files merely to make the validator pass.

3. Prefer changed-file validation when the validator supports it:

       python3 tools/check-copyright.py --paths <changed files>

   Until that interface exists, run the repository validator once, save output, and show only failures relevant to the intended commit:

       python3 tools/check-copyright.py > /tmp/depot-tools-headers.log 2>&1
       status=$?
       if [ "$status" -ne 0 ]; then
         grep -F -f <(printf '%s\n' <changed files>) /tmp/depot-tools-headers.log || tail -80 /tmp/depot-tools-headers.log
       fi
       exit "$status"

4. Fix headers with the comment style appropriate to the file. New first-party files use:

       SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda.
       SPDX-License-Identifier: MIT

5. Rerun the focused check and `git diff --check -- <task paths>`.

6. Report only the files checked, pass/fail status, and log path. Do not paste the full repository validation output.

Do not stage, commit, amend, or push unless the user explicitly requests those actions or the active ExecPlan requires a commit checkpoint.
