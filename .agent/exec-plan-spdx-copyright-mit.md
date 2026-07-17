# Standardize SPDX copyright notices and maintainer attribution

This ExecPlan is a living document. The sections `Progress`, `Surprises & Discoveries`, `Decision Log`, and `Outcomes & Retrospective` must be kept up to date as work proceeds.

This plan must be maintained in accordance with the repository's `.agent/PLANS.md`. The file `.agent/PLANS.md` is itself explicitly excluded from the SPDX header rule defined by this plan.

## Purpose / Big Picture

The repository currently identifies the company in source-file copyright notices, but the notices may not be uniform, machine-readable, or easy to validate. The project is maintained by Fabio Sobral, whose role should also be visible to contributors and users without changing the legal copyright holder.

After this change:

1. applicable first-party source files use standardized SPDX headers;
2. the copyright holder is written exactly as:

       SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda.

3. the license identifier is:

       SPDX-License-Identifier: MIT

4. Fabio Sobral is visibly identified as the project creator and lead maintainer in repository-level documentation;
5. `AUTHORS.md` records project authorship and maintenance responsibility;
6. `CODEOWNERS` identifies `@flsobral` as the default code owner;
7. an automated validation command detects missing, malformed, or obsolete copyright headers;
8. continuous integration runs the validation for pull requests and relevant branch updates;
9. contributor documentation explains how copyright headers must be added to new files;
10. `.agent/PLANS.md` is always excluded from header validation and must not be modified merely to add an SPDX header.

The implementation must distinguish legal ownership from project attribution:

- `Amalgam Solucoes em TI Ltda.` is the copyright holder.
- `Fabio Sobral` is the creator and lead maintainer.
- Fabio Sobral must not be added as an additional copyright holder unless a separate legal decision explicitly requires it.

A contributor must be able to clone the repository, run one documented validation command, and receive a clear success or failure result.

## Progress

- [x] (2026-07-17) Inspected repository structure, `AGENTS.md`, `.agent/PLANS.md`, licensing files, documentation, CI workflows, tracked-file types, and existing copyright markers.
- [x] (2026-07-17) Confirmed the repository already used MIT text and updated its copyright line to the required company holder.
- [x] (2026-07-17) Defined block-comment and hash-comment canonical headers, including shebang handling.
- [x] (2026-07-17) Defined explicit exclusions: exact `.agent/PLANS.md`, two imported Windows `stdbool.h` files, third-party/generated directory names, and `THIRD_PARTY_NOTICES.md`.
- [x] (2026-07-17) Implemented deterministic `tools/check-copyright.py` using NUL-delimited `git ls-files` output.
- [x] (2026-07-17) Added dependency-free fixture tests in `tools/test-check-copyright.py`.
- [x] (2026-07-17) Migrated 161 applicable tracked files to the canonical SPDX metadata while preserving historical third-party copyright lines.
- [x] (2026-07-17) Updated `LICENSE`, `AUTHORS.md`, `README.md`, `.github/CODEOWNERS`, and `CONTRIBUTING.md`.
- [x] (2026-07-17) Added `.github/workflows/validate-copyright.yml` for pull requests and pushes to `main`.
- [x] (2026-07-17) Ran focused validation, shell/YAML checks, and staged-diff review; no source body changes were introduced.
- [x] (2026-07-17) Committed the implementation as `16b8e1e` (`chore: standardize SPDX copyright metadata`); the final amend will include this plan update.

## Surprises & Discoveries

Record repository-specific findings here as implementation proceeds.

Examples of findings that belong in this section:

- different historical company names in existing headers;
- files licensed under terms different from the main repository;
- vendored dependencies containing third-party copyright notices;
- generated files that must not be edited manually;
- scripts or build tools that already perform partial license validation;
- source formats requiring unusual comment syntax;
- files whose first line must remain a shebang, XML declaration, encoding declaration, or another interpreter directive;
- references to LGPL or another previous license that must be updated or intentionally retained;
- existing rules in `.agent/PLANS.md` that affect implementation while the file itself remains exempt from the header rule.

Do not silently normalize exceptions. Document each important exception and the reason for it.

- Observation: `LICENSE` was already MIT but named `TotalCross Platform` rather than the required legal holder.
  Evidence: The baseline `LICENSE` line was `Copyright (c) 2026 TotalCross Platform`; it now names `Amalgam Solucoes em TI Ltda.`.
- Observation: 25 legacy SPDX declarations used `LGPL-2.1-only` or prose company notices in first-party implementation and build files.
  Evidence: The baseline grep found these declarations in CMake modules and AxTLS extension files; the applicable files now use `MIT`.
- Observation: Two Windows `stdbool.h` files are imported compatibility headers with their own notices.
  Evidence: `axtls/extensions/windows/stdbool.h` and `qrcodegen/extensions/windows/stdbool.h` contain third-party-style notices and are explicitly excluded.
- Observation: The validator itself initially matched its fixture strings for old LGPL values.
  Evidence: After staging new tools, validation reported its own source; constructing the legacy marker strings at runtime removed the false positives while retaining the test coverage.
- Observation: The repository contains no top-level build system for the full dependency bundle.
  Evidence: Build verification is dependency-specific; the repository-level checks used here are the documented shell/YAML validation plus the standalone validator tests.

## Decision Log

- Decision: Use `SPDX-FileCopyrightText` and `SPDX-License-Identifier` instead of prose-only copyright notices.
  Rationale: SPDX headers are concise, machine-readable, widely supported, and easier to validate consistently.
  Date: 2026-07-17

- Decision: Use the exact copyright line:

      SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda.

  Rationale: This is the copyright holder and year explicitly required for this repository-wide standardization.
  Date: 2026-07-17

- Decision: Use the SPDX license identifier `MIT`.
  Rationale: The repository is to be licensed under the MIT License, whose canonical SPDX identifier is `MIT`.
  Date: 2026-07-17

- Decision: Ensure the authoritative license file contains the standard MIT License text and identifies `2026 Amalgam Solucoes em TI Ltda.` as the copyright holder.
  Rationale: SPDX headers must agree with the repository-level license grant.
  Date: 2026-07-17

- Decision: Exclude the exact path `.agent/PLANS.md` from the SPDX header rule.
  Rationale: The file defines operational instructions for maintaining ExecPlans and must not be altered merely to satisfy source-header validation. The exclusion is path-specific and must not automatically exempt other files under `.agent/`.
  Date: 2026-07-17

- Decision: Identify Fabio Sobral as `Creator and Lead Maintainer` in repository-level documentation.
  Rationale: Project authorship and current maintenance should be visible without changing the legal copyright holder.
  Date: 2026-07-17

- Decision: Do not add personal `@author` tags or maintainer comments to every source file.
  Rationale: Per-file authorship tags become stale, duplicate repository metadata, and can be confused with legal ownership. Visibility is better provided through the README, `AUTHORS.md`, `CODEOWNERS`, and Git history.
  Date: 2026-07-17

- Decision: Do not replace or rewrite third-party copyright notices.
  Rationale: Vendored, imported, generated, or separately licensed files retain their original ownership and licensing information.
  Date: 2026-07-17

- Decision: Include comment-capable YAML, Dockerfiles, manifests, `CMakeLists.txt`, scripts, CMake modules, and native test sources in the candidate set.
  Rationale: These are first-party build or implementation inputs consumed directly by the repository and support comments without changing parsing semantics.
  Date: 2026-07-17

- Decision: Exclude only the two imported Windows `stdbool.h` compatibility headers in addition to the exact plan-file exception.
  Rationale: Their existing notices identify imported compatibility material; excluding their parent directories would be broader than the evidence supports.
  Date: 2026-07-17

- Decision: Validation must be deterministic and runnable locally as well as in CI.
  Rationale: Contributors should discover copyright problems before submitting a pull request.
  Date: 2026-07-17

## Outcomes & Retrospective

The implementation inspected 194 files in the final Git index and validated 161 applicable files. Three explicit paths were excluded: `.agent/PLANS.md` and the two imported Windows `stdbool.h` headers. The validator also skips known generated, vendored, third-party, output, and notice directories or basenames when they occur.

The repository was consistently migrated to MIT for first-party source and build metadata. Historical third-party copyright lines in Skia and the OpenBSD-derived AxTLS implementation were retained. The historical AxTLS changelog marker was updated from LGPL to MIT because it described the repository's own current release metadata rather than a bundled third-party notice.

The local command is `python3 tools/check-copyright.py`, and CI runs that same command in `.github/workflows/validate-copyright.yml` for pull requests and pushes to `main`. `python3 tools/test-check-copyright.py`, `bash -n sqlite3/fetch.sh mbedtls/fetch.sh skia/fetch.sh`, Ruby YAML loading, and `git diff --cached --check` passed. No full dependency build was run because this repository has no top-level build and its dependency builds require external source archives or platform-specific inputs.

The main limitation is that the validator intentionally covers comment-capable first-party formats and does not infer ownership for arbitrary Markdown, JSON, binary, patch, or separately licensed files. New exceptions must be added explicitly and documented. The implementation was committed as `16b8e1e` before this final plan-only amend.

## Context and Orientation

Before modifying files, inspect the repository rather than assuming its layout.

Start with:

    pwd
    find .. -name AGENTS.md -o -path '*/.agent/PLANS.md' -o -name PLANS.md
    git status --short
    find . -maxdepth 3 -type f | sort | sed -n '1,240p'

Read all applicable `AGENTS.md` files before editing anything. Read `.agent/PLANS.md` before executing or updating this plan, but do not add an SPDX header to it.

Inspect licensing and attribution files:

    find . -maxdepth 3 -type f \( \
      -iname 'LICENSE*' -o \
      -iname 'COPYING*' -o \
      -iname 'NOTICE*' -o \
      -iname 'AUTHORS*' -o \
      -iname 'README*' -o \
      -iname 'CONTRIBUTING*' -o \
      -iname 'CODEOWNERS' \
    \) -print

Inspect existing copyright and license markers:

    git grep -n -I -E \
      'Copyright|SPDX-FileCopyrightText|SPDX-License-Identifier|Lesser General Public License|LGPL|MIT License' \
      -- . \
      ':(exclude).git/**' \
      ':(exclude)build/**' \
      ':(exclude)dist/**' \
      ':(exclude)out/**' \
      ':(exclude)target/**' \
      ':(exclude)node_modules/**' \
      || true

Inspect CI and build entry points:

    find .github -maxdepth 3 -type f -print 2>/dev/null | sort
    find . -maxdepth 2 -type f \( \
      -name 'build.gradle' -o \
      -name 'build.gradle.kts' -o \
      -name 'settings.gradle' -o \
      -name 'settings.gradle.kts' -o \
      -name 'CMakeLists.txt' -o \
      -name 'Makefile' -o \
      -name 'pom.xml' -o \
      -name 'package.json' \
    \) -print

Do not assume that every tracked text file should receive a header. Classify files before migration.

Relevant categories normally include:

- first-party Java, Kotlin, C, C++, Objective-C, Objective-C++, Rust, Python, shell, Gradle, Groovy, JavaScript, TypeScript, and similar implementation files;
- first-party build scripts whose syntax supports comments;
- first-party test source files;
- first-party example source files.

Files normally excluded include:

- the exact path `.agent/PLANS.md`;
- vendored or subtree-managed third-party source;
- files with existing third-party copyright;
- generated files;
- build outputs;
- minified assets;
- lockfiles;
- binary files;
- patch files;
- external fixtures copied verbatim;
- license texts;
- files whose format does not safely permit comments;
- files explicitly excluded by repository policy.

Repository documentation should make these exclusions understandable and maintainable.

## Canonical SPDX headers

Use the shortest valid comment syntax for each file format while preserving mandatory first-line constructs.

### C-style source files

For Java, Kotlin, C, C++, Objective-C, Objective-C++, JavaScript, TypeScript, Gradle, Groovy, and other formats supporting block comments:

    /*
     * SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda.
     * SPDX-License-Identifier: MIT
     */

Prefer this format for consistency unless repository conventions require line comments.

### Hash-comment source files

For shell, Python, Ruby, YAML, and similar formats:

    # SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda.
    # SPDX-License-Identifier: MIT

When a file starts with a shebang, preserve the shebang as the first line and place the SPDX header immediately after it:

    #!/usr/bin/env bash
    # SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda.
    # SPDX-License-Identifier: MIT

Preserve Python encoding declarations in their required location.

### XML-style files

For XML and other compatible formats, preserve the XML declaration as the first line when present, then use:

    <!--
      SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda.
      SPDX-License-Identifier: MIT
    -->

Do not add comments to formats where doing so could change parsing semantics.

### Explicit `.agent/PLANS.md` exception

The file `.agent/PLANS.md` must not receive a canonical SPDX header as part of this migration.

The validator must match this path exactly and skip it before extension-based inclusion rules are evaluated. The exclusion should be represented by an explicit constant or configuration entry, for example:

    EXCLUDED_PATHS = {
        ".agent/PLANS.md",
    }

Do not generalize this exception to all Markdown files or to the entire `.agent/` directory unless a later documented decision explicitly requires it.

### Existing historical years

The requested canonical first-party copyright line uses `2026`. Do not invent earlier years from Git history.

If an existing first-party file contains a legally meaningful historical range, such as `2001-2026`, do not silently discard it. Record the finding in `Surprises & Discoveries` and determine whether the repository-wide requirement is intended to replace historical notices or only standardize newly owned work.

Unless repository evidence clearly requires preservation, use the exact requested canonical line:

    SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda.

Never modify historical years belonging to third parties.

## Repository-level MIT license

Create or update the authoritative repository license file, normally `LICENSE`, with the standard MIT License text.

The copyright line in the license file must be:

    Copyright (c) 2026 Amalgam Solucoes em TI Ltda.

Do not add an SPDX header to the license text itself unless the repository already follows a convention that requires one. The license file must not contain residual statements that make the repository appear to remain under LGPL.

Search for and review previous license references in:

- `README.md`;
- package metadata;
- build descriptors;
- source headers;
- generated documentation configuration;
- distribution manifests;
- website or publishing metadata stored in the repository;
- CI checks;
- contribution documentation.

Update first-party references to identify the MIT License. Preserve third-party license declarations where required.

## Repository-level attribution

### AUTHORS.md

Create or update `AUTHORS.md` with concise attribution.

The file should contain content equivalent to:

    # Authors

    ## Creator and Lead Maintainer

    Fabio Sobral<br>
    GitHub: [@flsobral](https://github.com/flsobral)

    ## Copyright holder

    Amalgam Solucoes em TI Ltda.

    ## Contributors

    Additional contributors are recorded in the Git history.

    Copyright ownership and project authorship are separate concepts. Unless
    explicitly stated otherwise, contributions are licensed under the MIT
    License used by this repository.

Adapt the last paragraph to the repository's actual contribution policy. Do not make claims about copyright assignment or contributor license agreements unless the repository contains authoritative documentation supporting those claims.

### README.md

Add a visible but restrained maintainer section near the project introduction, community section, or contribution section.

Use wording equivalent to:

    ## Maintainer

    Created and maintained by [Fabio Sobral](https://github.com/flsobral).

    Copyright © 2026 Amalgam Solucoes em TI Ltda.

    Licensed under the MIT License.

Do not imply that Fabio Sobral personally owns the company copyright.

If the README already contains an authorship, governance, or license section, update it rather than creating a duplicate.

### CODEOWNERS

Create or update `.github/CODEOWNERS` so that Fabio Sobral is the default code owner:

    * @flsobral

Preserve any existing path-specific ownership rules. Since later matching rules take precedence in GitHub CODEOWNERS syntax, place the repository-wide fallback where it does not unintentionally override more specific rules.

Do not enable branch protection or mandatory code-owner review unless explicitly requested. This plan adds ownership metadata only.

## Contributor documentation

Update the most appropriate contributor-facing file, normally `CONTRIBUTING.md`, with a section equivalent to:

    ## Copyright headers

    New first-party source files must include the following SPDX metadata:

        SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda.
        SPDX-License-Identifier: MIT

    Use the comment syntax appropriate for the file type. Preserve shebangs,
    XML declarations, encoding declarations, and other required first-line
    constructs.

    Do not replace or modify copyright and license notices in third-party,
    vendored, generated, or separately licensed files.

    The file `.agent/PLANS.md` is intentionally exempt from the SPDX header
    rule and must not be modified solely to add a header.

    Run the repository copyright validation command before submitting a pull
    request.

Document the exact local command after implementing the validation tool.

If the repository contains templates used to create source files, update them to emit the canonical SPDX header.

## Validation tool

Implement the validator using an existing repository language where practical. Prefer a small dependency-free script over introducing a new runtime or package manager.

Good locations include:

    tools/check-copyright.py
    scripts/check-copyright.py
    tools/check-copyright.sh

Prefer Python when it is already available in CI because it offers reliable path handling and readable diagnostics. If the project deliberately avoids Python, use the repository's existing scripting language.

The validator must:

1. obtain candidate files from Git rather than recursively scanning build output;
2. inspect tracked files and, when useful, staged files;
3. skip the exact path `.agent/PLANS.md` before applying inclusion rules;
4. apply explicit inclusion and exclusion rules;
5. detect third-party and generated directories;
6. verify both canonical SPDX lines;
7. verify the exact company spelling;
8. verify the expected license identifier `MIT`;
9. identify obsolete first-party company notices or old LGPL SPDX identifiers that should have been migrated;
10. print one concise diagnostic per failing file;
11. exit with status zero on success and nonzero on failure;
12. produce deterministic output sorted by path;
13. support paths containing spaces;
14. avoid rewriting files during validation.

A suitable candidate-file source is:

    git ls-files -z

Do not parse newline-delimited file lists when NUL-delimited output is available.

Diagnostics should resemble:

    path/to/File.java: missing SPDX-FileCopyrightText
    path/to/File.java: expected copyright holder "2026 Amalgam Solucoes em TI Ltda."
    path/to/File.java: expected SPDX license "MIT"
    path/to/File.java: obsolete SPDX license "LGPL-2.1-only"

Routine exclusions need not be printed during successful validation. A summary may report counts and should mention the number of explicit path exclusions.

A successful run should resemble:

    Copyright validation passed: 842 applicable files checked; 1 explicit path excluded.

Keep output concise because the command will run in CI and may be consumed by automated agents.

### Configuration

Avoid scattering exclusion rules throughout the implementation.

Store them in one clearly named location, either:

- constants near the top of the validator;
- a dedicated configuration file;
- an existing repository-wide license configuration mechanism.

At minimum, configuration must include the exact exclusion:

    .agent/PLANS.md

Document why each non-obvious exclusion exists.

Patterns must be path-aware. Do not exclude every directory named `third_party` or `generated` without checking repository conventions.

### Optional modes

A `--check` mode is mandatory if modes are supported.

A `--fix` mode may be implemented only if it can safely preserve:

- shebangs;
- XML declarations;
- encoding declarations;
- BOMs;
- existing third-party notices;
- line-ending conventions;
- generated-file boundaries;
- the `.agent/PLANS.md` exclusion.

Do not implement automatic rewriting merely for convenience. A narrowly scoped migration script used once and removed before final submission is acceptable if the final validator remains simple and safe.

## Tests for the validator

Add lightweight automated tests or fixture-based checks.

At minimum, cover:

1. valid C-style MIT header;
2. valid hash-comment MIT header;
3. shebang followed by a valid header;
4. missing copyright line;
5. missing license line;
6. misspelled company name;
7. wrong year;
8. previous `LGPL-2.1-only` identifier when `MIT` is expected;
9. third-party file exclusion;
10. generated-file exclusion;
11. exact exclusion of `.agent/PLANS.md`;
12. confirmation that another file under `.agent/` is not excluded automatically;
13. path containing spaces;
14. deterministic sorted diagnostics.

Use the repository's existing test framework when one exists. Otherwise, a dependency-free test script is sufficient.

The test must not depend on the developer's global Git configuration.

## Migration procedure

Build an inventory before bulk editing.

Generate machine-readable or plain-text reports under a temporary directory that is not committed, for example:

    mkdir -p build/copyright-audit

Record:

- all tracked files;
- candidate first-party source files;
- files already using SPDX;
- files using legacy company copyright notices;
- files using LGPL identifiers;
- files with third-party notices;
- excluded generated or vendored files;
- explicit exclusions, including `.agent/PLANS.md`;
- files requiring manual review.

Do not commit audit outputs unless the repository already maintains generated compliance reports.

Perform migration in small, reviewable groups:

1. validator and tests;
2. root MIT license and attribution files;
3. one source language or module at a time;
4. build metadata and documentation containing previous license references;
5. CI integration;
6. final cleanup.

For each group:

- apply headers;
- run the validator;
- inspect `git diff --check`;
- inspect a focused diff;
- ensure no code body changed;
- confirm `.agent/PLANS.md` remains unchanged unless it requires a plan-content update unrelated to the header migration.

Do not mix formatting changes, import reordering, or unrelated source cleanup into the copyright migration.

When replacing old headers, remove redundant prose only when the new SPDX header fully represents the same first-party ownership and license. Preserve legally relevant third-party notices, warranty statements, or special permissions.

## CI integration

Inspect existing workflows and reuse their conventions.

Add a focused job or step named similarly to:

    copyright
    license-headers
    validate-copyright

The CI step must invoke the same command documented for local use.

For example:

    python3 tools/check-copyright.py

or, if exposed through the build:

    ./gradlew checkCopyright

Prefer integrating the script into the existing build tool when doing so does not hide its direct invocation or add unnecessary complexity.

The workflow should run for:

- pull requests affecting relevant source, script, documentation, license, validator, or configuration paths;
- pushes to the main development branch, following existing repository policy.

Avoid an overly narrow path filter that lets new unsupported source extensions bypass validation. Running this lightweight check on every pull request is acceptable.

Do not create duplicate workflows when an existing validation workflow can host the new job.

The job should use pinned or repository-standard action versions and minimum permissions.

## Public build integration

When the repository uses Gradle, expose a task such as:

    ./gradlew checkCopyright

The task should execute the validator and participate in the appropriate verification lifecycle, usually `check`, if this does not make unrelated build workflows impractical.

For CMake-based projects, consider a custom target such as:

    cmake --build <build-dir> --target check-copyright

For Make-based projects, consider:

    make check-copyright

The direct script invocation should remain available for CI debugging.

Do not introduce integration with every build system merely because multiple build files exist. Integrate with the primary contributor workflow.

## Concrete Steps

The exact commands must be adapted after repository inspection.

### 1. Establish the baseline

Run:

    git status --short
    git branch --show-current
    git rev-parse --show-toplevel
    git grep -n -I -E 'Copyright|SPDX-|LGPL|MIT License' -- . || true

Record counts and important variations in `Surprises & Discoveries`.

Verify the authoritative license text:

    sed -n '1,240p' LICENSE 2>/dev/null || true
    sed -n '1,240p' COPYING 2>/dev/null || true
    sed -n '1,240p' COPYING.LESSER 2>/dev/null || true

Identify all first-party LGPL references that must change to MIT and all third-party LGPL references that must remain untouched.

### 2. Implement the validator first

Create the validator and tests before bulk migration. Initially, it is expected to fail against legacy files.

Run its tests independently.

Example:

    python3 tools/test-check-copyright.py
    python3 tools/check-copyright.py

Capture a concise baseline failure summary rather than pasting thousands of diagnostics into the ExecPlan.

Verify explicitly that `.agent/PLANS.md` is not reported as missing a header.

### 3. Update the repository license

Create or replace the authoritative license file with the standard MIT License text containing:

    Copyright (c) 2026 Amalgam Solucoes em TI Ltda.

Remove obsolete first-party repository-level LGPL license files only when they are no longer required for bundled third-party components or historical compliance. Do not delete third-party license texts.

### 4. Add attribution metadata

Create or update:

    AUTHORS.md
    README.md
    .github/CODEOWNERS
    CONTRIBUTING.md

Ensure the documentation consistently distinguishes:

- copyright holder: Amalgam Solucoes em TI Ltda.;
- creator and lead maintainer: Fabio Sobral;
- GitHub owner: `@flsobral`;
- license: MIT License;
- explicit header exception: `.agent/PLANS.md`.

### 5. Migrate source headers and license references

Update applicable first-party files using syntax-aware transformations.

For each module or source family:

    python3 tools/check-copyright.py
    git diff --check
    git diff --stat
    git diff -- path/to/module

Confirm that source changes are limited to file headers and necessary license metadata.

Use a syntax-aware or extension-aware migration script if the repository contains many files. Review the script before running it, then review representative output for every supported syntax.

Remove temporary migration tooling before completion unless it remains useful and is documented.

### 6. Add build and CI entry points

Add the local verification entry point and CI job.

Run the exact CI command locally.

Inspect workflow syntax and, where available, use the repository's workflow linter.

### 7. Run final validation

At minimum, run:

    python3 tools/test-check-copyright.py
    python3 tools/check-copyright.py
    git diff --check
    git status --short

Also run the repository's focused verification suite and the normal build command required by its `AGENTS.md` and `.agent/PLANS.md`.

Examples, depending on the repository:

    ./gradlew checkCopyright
    ./gradlew test
    ./gradlew check
    cmake --build build --target check-copyright
    ctest --test-dir build --output-on-failure

Avoid running unnecessarily verbose full builds repeatedly. Redirect verbose build output to a file and print only the relevant tail on failure:

    ./gradlew check > build/gradle-check.log 2>&1 || {
      status=$?
      tail -n 200 build/gradle-check.log
      exit "$status"
    }

On success, print only a concise summary.

## Validation and Acceptance

The implementation is complete only when all of the following are observable.

### Header correctness

Every applicable first-party source file contains, using appropriate comment syntax:

    SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda.
    SPDX-License-Identifier: MIT

The spelling, capitalization, punctuation, year, and license identifier must match exactly.

### Explicit plan-file exclusion

The file `.agent/PLANS.md`:

- does not need an SPDX header;
- is excluded by an exact path rule;
- is not reported by local or CI validation;
- is not used as justification to exclude other `.agent/` files automatically;
- is not modified solely to add copyright metadata.

### Legal exceptions

Third-party, vendored, generated, and separately licensed files retain their original notices and are excluded by explicit, documented rules.

No third-party owner is replaced with Amalgam Solucoes em TI Ltda.

Third-party LGPL notices remain intact where applicable.

### Repository license

The authoritative license file contains the standard MIT License text and the line:

    Copyright (c) 2026 Amalgam Solucoes em TI Ltda.

First-party project metadata no longer describes the project as LGPL-licensed.

### Maintainer visibility

A repository visitor can find Fabio Sobral's role without opening source files.

`README.md` identifies Fabio Sobral as creator and maintainer.

`AUTHORS.md` identifies:

- Fabio Sobral as Creator and Lead Maintainer;
- Amalgam Solucoes em TI Ltda. as copyright holder.

`.github/CODEOWNERS` contains an appropriate default rule for `@flsobral`.

### Local validation

The documented local command succeeds from a clean checkout:

    python3 tools/check-copyright.py

or the final repository-specific equivalent.

Intentionally removing one SPDX line from a fixture or temporary test file makes validation fail with a clear file-specific diagnostic.

Adding `.agent/PLANS.md` to the test repository without an SPDX header does not make validation fail.

### CI validation

The repository CI executes the same validator and fails when an applicable source file lacks the required header or still uses the old first-party LGPL identifier.

### Build integrity

The normal focused build and test suite continue to pass.

Header migration causes no semantic source-code changes.

### Diff quality

The final diff contains no unrelated formatting, generated output, build artifacts, local configuration, or temporary audit files.

## Idempotence and Recovery

The validator is read-only and safe to run repeatedly.

Header migration must be idempotent: running the migration mechanism twice must not duplicate headers.

Before any bulk rewrite:

    git status --short

If unrelated local modifications exist, do not overwrite or discard them.

Use Git to review and recover individual migration mistakes:

    git diff -- path/to/file
    git restore --source=HEAD -- path/to/file

Do not run destructive commands such as:

    git reset --hard
    git clean -fd
    git checkout -- .

unless explicitly authorized.

If a bulk transformation affects unexpected files, stop, record the issue in `Surprises & Discoveries`, revert only the files changed by the transformation, refine the selection rules, and rerun the focused migration.

If `.agent/PLANS.md` is modified only by the migration tool, treat that as a validator or migration-selection defect, restore the file, add a regression test, and rerun the migration.

## Artifacts and Notes

Keep concise evidence of:

- the initial count of legacy notices;
- the final count of validated first-party files;
- the list or count of excluded third-party trees;
- confirmation of the `.agent/PLANS.md` exact exclusion;
- validator test output;
- final validation output;
- MIT license verification;
- build and test results.

Do not paste large repetitive file lists or complete build logs into this document. Store temporary logs under the build directory and summarize only the result and relevant failure excerpts.

Expected final concise evidence should resemble:

    Copyright validator tests: passed
    Copyright validation: passed, 842 applicable files checked
    Explicit path exclusions: 1 (.agent/PLANS.md)
    Excluded third-party files: 127
    Repository license: MIT
    Build: passed
    Tests: passed

## Final Review Checklist

Before concluding:

- [ ] The authoritative repository license is MIT.
- [ ] The MIT license text contains `Copyright (c) 2026 Amalgam Solucoes em TI Ltda.`.
- [ ] The canonical SPDX license identifier is exactly `MIT`.
- [ ] The company name is exactly `Amalgam Solucoes em TI Ltda.`.
- [ ] The year is exactly `2026`.
- [ ] `.agent/PLANS.md` is excluded by exact path.
- [ ] `.agent/PLANS.md` did not receive a header solely because of this migration.
- [ ] Other `.agent/` files are not accidentally exempted.
- [ ] Fabio Sobral is described as creator and lead maintainer, not as copyright holder.
- [ ] Third-party notices were preserved.
- [ ] Third-party LGPL declarations were preserved where required.
- [ ] Generated files were not manually modified.
- [ ] New-file rules are documented.
- [ ] The validator is deterministic.
- [ ] Validator tests pass.
- [ ] CI invokes the validator.
- [ ] The documented local command works.
- [ ] Focused repository tests pass.
- [ ] `git diff --check` passes.
- [ ] The final diff contains no unrelated changes.

## Plan Revision Note

This revision changes the repository license and canonical source-file SPDX identifier from LGPL 2.1 to MIT:

    SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda.
    SPDX-License-Identifier: MIT

It also introduces an exact, mandatory exclusion for:

    .agent/PLANS.md

The exclusion applies only to the SPDX header rule. The file must still be read and followed when executing or maintaining ExecPlans.

## Editorial Report

### Editorial Summary

The repository had mixed company notices and legacy LGPL SPDX identifiers, while its authoritative license was already MIT under an outdated holder name. The completed change standardizes first-party comment-capable files on the required 2026 company copyright and MIT identifier, makes Fabio Sobral visible as creator and lead maintainer, and adds a repeatable local and CI check.

### Original Plan versus Actual Outcome

The planned validator, tests, source migration, repository attribution, MIT correction, contributor guidance, CI integration, and final review were completed. The migration covers 161 applicable files rather than only the initially observed 143 because `CMakeLists.txt` files were recognized during review. No automatic fix mode was retained; the one-time migration helper was removed after use. No full dependency build was performed because the repository has no aggregate build entry point and the individual builds require external inputs.

### What Changed

`tools/check-copyright.py` validates Git-tracked comment-capable files with sorted diagnostics and explicit exclusions. `tools/test-check-copyright.py` exercises valid headers, malformed headers, old LGPL, path handling, ordering, third-party/generated exclusions, and the exact `.agent/PLANS.md` exception. First-party source, tests, scripts, manifests, CMake files, Dockerfiles, and workflows were migrated. `LICENSE`, `AUTHORS.md`, `README.md`, `CONTRIBUTING.md`, `.github/CODEOWNERS`, and `.github/workflows/validate-copyright.yml` provide the legal, attribution, contributor, ownership, and CI metadata.

### Decisions and Trade-offs

The validator uses dependency-free Python and `git ls-files -z` for deterministic, space-safe input. It checks headers without rewriting files, which avoids accidental source changes but requires contributors to add headers manually. The exact plan-file exclusion is separate from the two narrowly scoped imported-header exclusions; broad `.agent/` or third-party-directory exemptions were not introduced.

### Unexpected Problems and Discoveries

The validator initially reported its own literal LGPL fixture strings after the new tools were staged. Runtime construction of those test markers preserved coverage without making the validator fail on its own implementation. The existing MIT license holder also differed from the required company name, and two compatibility headers needed explicit preservation as imported material.

### Validation and Measurable Results

Observed results include `Copyright validator tests: passed`, `Copyright validation passed: 161 applicable files checked; 3 explicit path excluded.`, successful shell syntax checks for `sqlite3/fetch.sh`, `mbedtls/fetch.sh`, and `skia/fetch.sh`, successful Ruby YAML loading for `deps.yml` and dependency manifests, and a clean staged `git diff --check` after removing documentation hard-break whitespace. No performance or artifact-size measurement was taken.

### Useful Evidence and Examples

The validator's output is the concise acceptance evidence. Representative migration diffs are in `axtls/extensions/pbkdf2.c`, `skia/cmake/FindSkia.cmake`, and `.github/scripts/validate-commit-message.sh`. The CI invocation is visible in `.github/workflows/validate-copyright.yml`, and the final staged diff records the complete header migration.

### Limitations, Remaining Work, and Open Questions

No full dependency build was run in this environment. The validator does not inspect binary, JSON, Markdown, patch, license-text, or separately licensed files unless a future policy explicitly adds support. The implementation commit is `16b8e1e` before the final plan-only amend.

### Possible Article Angles

- “Making SPDX headers enforceable in a dependency repository” for maintainers who need deterministic license checks without adding a package manager; the takeaway is to classify files before migration.
- “Separating legal copyright from project maintainership” for open-source project stewards; the takeaway is to use repository attribution, authorship, and code ownership metadata for different responsibilities.
- “Testing the validator against its own legacy fixtures” for tooling authors; the takeaway is to prevent compliance checks from matching their embedded negative examples.

### Suggested Narrative

Start with mixed legacy notices and the mismatch between the MIT license and its holder name. Explain the file-classification constraints, exact plan-file exception, and preservation of imported notices. Follow the implementation of the read-only Git-based validator and fixture tests, describe the self-matching false positive, then show the 161-file migration, CI command, observed validation output, and the limits of comment-capable coverage.

### Claims Requiring Human Review

The legal holder name, the decision to treat the two `stdbool.h` files as imported compatibility material, and the historical interpretation of the AxTLS changelog should receive normal human legal or project-owner review before external publication. No security or performance claims are made.
