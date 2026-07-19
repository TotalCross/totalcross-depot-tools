---
name: logical-commits
description: Create frequent but non-trivial logical Git commits with English Conventional Commit headers, required scope, explanatory bodies, focused validation, and preservation of unrelated local changes; invoke only when the user asks to commit or an active ExecPlan explicitly requires commits.
---

# Commit logical repository changes

This skill changes Git state. Confirm that committing is explicitly requested by the user or required by an active ExecPlan whose execution was requested.

1. Read the active state file first when executing an ExecPlan. Determine the current functional slice and intended paths.

2. Inspect scoped changes:

       git status --short -- <task paths>
       git diff --stat -- <task paths>
       git diff -- <task paths>

   Inspect staged changes separately. Do not run destructive cleanup and do not include unrelated modifications.

3. Split changes by behavior or contract, not by file count. Suitable commit boundaries include:

   - one shared interface plus its focused tests;
   - one platform-family migration;
   - one dependency scaffold and its documentation;
   - one release-policy change and its idempotence tests;
   - one follow-up fix discovered by validation.

   Do not create a commit for formatting-only fragments that belong to the same functional change. Do not combine architecture, unrelated cleanup, generated artifacts, and documentation for another feature.

4. Before each commit, run the `validate-headers` skill and the smallest validation sufficient for that slice. Always run:

       git diff --check --cached

   Save verbose build output to a log and record only a compact summary.

5. Stage only intended paths:

       git add -- <paths>

   Review:

       git diff --cached --stat
       git diff --cached -- <paths>

6. Write an English Conventional Commit message:

       <type>(<scope>): imperative description

   The subject starts lowercase, uses imperative mood, has at least three words, does not end with a period, and remains within 80 characters.

   For every non-trivial change, add a body that explains:

   - why the change is needed;
   - what behavior or contract changes;
   - platform, compatibility, artifact, or release impact;
   - focused validation completed and important deferrals.

   Example:

       refactor(build): centralize native target policy

       Resolve Android, Linux, and Windows platform settings from the shared
       native-build configuration so workflows and explicit target wrappers no
       longer repeat toolchain values.

       Keep minizip on Android API 24 while the default remains API 23. Validate
       configuration resolution and the zlib build-only workflow.

7. Commit without amending or rewriting history unless explicitly requested.

8. Validate the created commit message with:

       ./.github/scripts/validate-commit-message.sh HEAD

9. Update the active ExecPlan state after the logical commit. Update the active plan only when this commit reaches a functional-family, architecture, ABI, release-policy, or milestone checkpoint.

10. Report the commit hash, subject, paths, focused validations, and any deferred expensive validation. Do not push unless explicitly requested.
