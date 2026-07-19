<!--
SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda.
SPDX-License-Identifier: MIT
-->

# Codex Execution Plans (ExecPlans)

An ExecPlan is a living design and execution document for a complex feature,
release-process change, platform addition, or significant refactor. It must let a
new contributor make the next safe change, verify it proportionally, and recover
after interruption without reconstructing the complete project history.

## Precedence and scope

Apply instructions in this order:

1. safety and data-preservation instructions;
2. explicit user instructions for the current task;
3. the token, output, commit, and validation budget in `AGENTS.md`;
4. this document;
5. instructions specific to the active ExecPlan.

An ExecPlan cannot make an expensive validation mandatory after every slice merely
because it recorded that validation at an earlier checkpoint. Use the smallest
validation that proves the current change unless the user requests more, the
milestone is closing, an ABI/platform/release contract changed, or prior failure
evidence justifies escalation.

## Resumable plans, not duplicated context

A plan is self-contained when it contains the knowledge needed to implement the
change or names stable repository paths that hold that knowledge. A reference
must explain what the file contains and when it should be read. “See the docs” is
not sufficient.

When creating a new plan, read `AGENTS.md` and this file in full, then inspect only
the repository paths and external sources needed to make the plan concrete.

When resuming a plan, read its state file first when one exists. Otherwise locate
the active headings and read only the sections needed for the next action. Do not
routinely reread the full plan, architecture documents, historical archive,
evidence index, or editorial report. Context compaction is not a reason to search
the whole repository again.

The active plan should normally remain around 300–450 lines and a state file
around 100–150 lines. These are soft limits. When a plan grows beyond them, move
completed detail and raw evidence into supporting files rather than deleting
necessary safety or implementation context.

## Required plan structure

Every active ExecPlan contains or adapts these sections:

- `Purpose / Big Picture`: observable developer or user outcome.
- `Working Set and Resume Protocol`: supporting-file paths and the first read for
  continuation.
- `Progress`: meaningful completed checkpoints and remaining work.
- `Current Architecture and Scope`: only context needed for remaining work.
- `Plan of Work`: completed milestone summaries, active milestone, and next
  milestones.
- `Surprises & Discoveries`: observations that materially affect remaining work.
- `Decision Log`: choices that change architecture, compatibility, release,
  validation, or operation policy.
- `Validation and Acceptance`: observable behavior and applicable validation
  levels from `AGENTS.md`.
- `Risks and Open Questions`: unresolved issues that can change implementation.
- `Idempotence and Recovery`: safe retry, concurrency, and local-change behavior.
- `Outcomes & Retrospective`: short milestone-level factual summary.
- `Revision Note`: only material plan-policy or milestone consolidations.

A completed plan also has a factual editorial report. The active plan may point to
`.agent/reports/<plan>-editorial.md` rather than carrying a large report inline.

## Supporting files

Use supporting files only when they simplify resumption:

- `.agent/state/<plan>.md` is rewritten rather than appended. It records the
  active milestone and slice, last logical commit, active paths, next concrete
  action, focused validation completed, deferred validation and reason, active
  decisions, blockers, deliberate out-of-scope files, and a resume command. It is
  the first normal read.
- `.agent/evidence/<plan>.md` or `.jsonl` is append-only. It records compact
  evidence: timestamp, revision, milestone/slice, command or wrapper, status,
  counts, log/artifact paths, necessary hashes, and limitation. Search it
  selectively; do not read it during every resume.
- `.agent/archive/<plan>-history.md` stores completed milestone detail, rejected
  alternatives whose rationale remains useful, and retired revision notes. It is
  not read by default.
- `.agent/reports/<plan>-editorial.md` is a concise factual handoff updated at
  important milestone completion and final completion, not after every slice.

Do not copy the same log, matrix, hash, benchmark table, or conclusion into every
supporting file.

## Progress, decisions, and checkpoints

`Progress` records meaningful checkpoints: a logical commit, functional slice,
material direction change, or completed milestone. Do not add separate entries
for implementation, validation, documentation, and commit when they belong to one
checkpoint. Point to evidence rather than repeating it.

The `Decision Log` contains only choices that alter future work. Do not record
mechanical test commands, every target name, or standing repository policy.

Keep `Surprises & Discoveries` only for observations that affect remaining work.
Move resolved history to the archive.

During a slice, update state only when needed for safe resumption. After a logical
commit, record what changed, focused validation, remaining work, and deferrals.
At a milestone checkpoint, consolidate the plan, history, evidence, editorial
report, and next state.

## Validation and benchmarks

Validation is mandatory in proportion to risk. Use the four validation levels in
`AGENTS.md` and stop at the first sufficient level.

Each milestone must state observable acceptance and the validation level normally
required. A plan may name exact focused commands but must not turn a historical
full matrix into a perpetual slice requirement.

Save complete tool output in logs or artifacts. Record compact summaries and paths
in evidence.

Benchmark only workloads that exercise the changed behavior or measurement path.
Run a small smoke benchmark for an affected hot path and a full checkpoint only at
milestone closure, optimization validation, measurement-regime change, or explicit
user request. Preserve raw samples outside the active plan.

## Writing guidance

Use plain language. Define non-obvious terms at first use. State the observable
purpose before implementation detail.

Name repository-relative paths, modules, scripts, working directories, commands,
expected concise outcomes, and safe retry behavior. Prefer prose to large tables
and inventories.

Do not replace key repository knowledge with an external link. Stable local
documentation may be referenced when its role and read condition are stated.

Do not dump generated code, full workflows, large manifests, raw logs, complete
matrices, or every differential case into an ExecPlan. Use small excerpts, paths,
commands, and evidence references.

## Milestones

A milestone describes:

- the goal and why it matters;
- the files and contracts changed;
- the behavior that exists at its end;
- the proof required;
- fallback or compatibility paths that remain;
- the next boundary.

Milestones should produce incremental observable value. Prototypes and parallel
paths are acceptable when they are bounded, additive, independently testable, and
have clear promotion or removal criteria.

## Releases and state-changing work

A plan that creates commits, tags, pushes, releases, or metadata updates must state:

- which operations are automatic and which require explicit user execution;
- concurrency protection and race rechecks;
- idempotent behavior when a release already exists;
- how an effective release tag is selected;
- which commit a tag and release point to;
- how partial publication is detected and recovered;
- how unrelated local changes remain untouched.

Prefer dry-run or build-only validation before enabling release operations.

## Completion

At plan completion, reconcile the final implementation with `Outcomes &
Retrospective` and the editorial report. Distinguish delivered work from planned
work, measurements from estimates, and supported targets from aspirations.

The editorial report should contain:

- `Editorial Summary`;
- `Original Plan versus Actual Outcome`;
- `What Changed`;
- `Decisions and Trade-offs`;
- `Unexpected Problems and Discoveries`;
- `Validation and Measurable Results`;
- `Useful Evidence and Examples`;
- `Limitations, Remaining Work, and Open Questions`;
- `Possible Article Angles`;
- `Suggested Narrative`;
- `Claims Requiring Human Review`.

## Minimal skeleton

    # <Short action-oriented title>

    This ExecPlan follows `AGENTS.md` and `.agent/PLANS.md`.

    ## Purpose / Big Picture

    Explain the observable outcome and how a developer can see it.

    ## Working Set and Resume Protocol

    Name state, evidence, history, and editorial paths and when each is read.

    ## Progress

    - [x] (YYYY-MM-DDThh:mm:ssZ) Significant completed checkpoint.
    - [ ] Active slice and next concrete action.
    - [ ] Remaining milestone or finalization work.

    ## Current Architecture and Scope

    Explain only the contracts and paths needed for remaining work.

    ## Plan of Work

    Summarize completed milestones, detail the active milestone, and describe next
    milestones with observable acceptance.

    ## Surprises & Discoveries

    - Observation: ...
      Evidence: ...

    ## Decision Log

    - Decision: ...
      Rationale: ...
      Date: ...

    ## Validation and Acceptance

    Name the validation level, focused command, expected concise result, and any
    deferred expensive validation with its reason.

    ## Risks and Open Questions

    State unresolved implementation, platform, compatibility, release, or
    concurrency questions.

    ## Idempotence and Recovery

    State safe retries, partial-release recovery, and local paths that remain
    untouched.

    ## Outcomes & Retrospective

    Summarize completed milestone outcomes and point to evidence/history.

    ## Revision Note

    Record only a material plan-policy or milestone consolidation and its reason.
