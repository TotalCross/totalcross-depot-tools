#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda.
# SPDX-License-Identifier: MIT
"""Atomically update selected dependency release fields in the bundle index."""
from __future__ import annotations
import argparse
import re
from pathlib import Path


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--file", default="deps.yml")
    parser.add_argument("--pin", action="append", default=[], metavar="DEPENDENCY=TAG")
    args = parser.parse_args()
    pins = dict(item.split("=", 1) for item in args.pin)
    source = Path(args.file).read_text(encoding="utf-8")
    for dependency, tag in pins.items():
        pattern = rf"(^  {re.escape(dependency)}:\n(?:    .*\n)*?    release: )[^\n]+$"
        source, count = re.subn(pattern, rf"\g<1>{tag}", source, flags=re.MULTILINE)
        if count != 1:
            raise SystemExit(f"expected exactly one {dependency} entry, found {count}")
    Path(args.file).write_text(source, encoding="utf-8")


if __name__ == "__main__":
    raise SystemExit(main())
