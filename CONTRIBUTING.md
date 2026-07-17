# Contributing

Changes should remain scoped to the dependency or workflow they update. Run
the relevant checks described in `AGENTS.md` before opening a pull request.

## Copyright headers

New first-party source files must include the following SPDX metadata:

    SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda.
    SPDX-License-Identifier: MIT

Use the comment syntax appropriate for the file type. Preserve shebangs, XML
declarations, encoding declarations, and other required first-line constructs.

Do not replace or modify copyright and license notices in third-party,
vendored, generated, or separately licensed files. The imported Windows
`stdbool.h` compatibility headers are examples of files excluded from this
repository's rule.

The file `.agent/PLANS.md` is intentionally exempt from the SPDX header rule
and must not be modified solely to add a header. Other files under `.agent/`
are not automatically exempt.

Run the repository copyright validation command before submitting a pull
request:

    python3 tools/check-copyright.py
