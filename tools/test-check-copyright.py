#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda.
# SPDX-License-Identifier: MIT
"""Dependency-free tests for tools/check-copyright.py."""

from __future__ import annotations

import os
import pathlib
import subprocess
import importlib.util
import sys
import tempfile

MODULE_PATH = pathlib.Path(__file__).with_name("check-copyright.py")
SPEC = importlib.util.spec_from_file_location("check_copyright", MODULE_PATH)
assert SPEC and SPEC.loader
check_copyright = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = check_copyright
SPEC.loader.exec_module(check_copyright)


def write(root: pathlib.Path, name: str, content: str) -> None:
    path = root / name
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")


def git(root: pathlib.Path, *args: str) -> None:
    subprocess.run(["git", *args], cwd=root, check=True, stdout=subprocess.DEVNULL)


def main() -> int:
    with tempfile.TemporaryDirectory() as directory:
        root = pathlib.Path(directory)
        git(root, "init", "-q")
        env = os.environ.copy()
        env.update({"GIT_AUTHOR_NAME": "Test", "GIT_AUTHOR_EMAIL": "test@example.invalid",
                    "GIT_COMMITTER_NAME": "Test", "GIT_COMMITTER_EMAIL": "test@example.invalid"})
        valid_block = "/*\n * " + check_copyright.COPYRIGHT + "\n * " + check_copyright.LICENSE + "\n */\n"
        valid_hash = "# " + check_copyright.COPYRIGHT + "\n# " + check_copyright.LICENSE + "\n"
        write(root, "valid.c", valid_block)
        write(root, "valid.py", valid_hash)
        write(root, "script.sh", "#!/usr/bin/env bash\n" + valid_hash)
        write(root, "missing-copyright.c", "/*\n * " + check_copyright.LICENSE + "\n */\n")
        write(root, "missing-license.py", "# " + check_copyright.COPYRIGHT + "\n")
        write(root, "wrong-company.c", valid_block.replace("Amalgam Solucoes em TI Ltda.", "Amalgam Solucoes de TI Ltda."))
        write(root, "wrong-year.c", valid_block.replace("2026", "2025"))
        write(root, "old-lgpl.c", valid_block.replace("MIT", "LG" + "PL-2.1-only"))
        write(root, "third_party/copied.c", "third-party\n")
        write(root, "generated/output.c", "generated\n")
        write(root, ".agent/PLANS.md", "plan\n")
        write(root, ".agent/other.py", "not exempt\n")
        write(root, "directory with spaces/file.py", "not valid\n")
        git(root, "add", ".")
        subprocess.run(["git", "-c", "user.name=Test", "-c", "user.email=test@example.invalid", "commit", "-qm", "fixtures"], cwd=root, check=True, env=env)

        diagnostics = check_copyright.validate(root)
        assert diagnostics == sorted(diagnostics)
        required = {
            "missing-copyright.c: missing SPDX-FileCopyrightText",
            "missing-license.py: missing SPDX-License-Identifier",
            'old-lgpl.c: obsolete SPDX license "' + "LG" + 'PL-2.1-only"',
            'wrong-company.c: expected copyright holder "2026 Amalgam Solucoes em TI Ltda."',
            'wrong-year.c: expected copyright holder "2026 Amalgam Solucoes em TI Ltda."',
            ".agent/other.py: missing SPDX-FileCopyrightText",
            "directory with spaces/file.py: missing SPDX-FileCopyrightText",
        }
        assert required.issubset(diagnostics), diagnostics
        assert diagnostics == sorted(diagnostics)
        assert not any(item.startswith(".agent/PLANS.md:") for item in diagnostics)
        assert not any(item.startswith("third_party/") for item in diagnostics)
        assert not any(item.startswith("generated/") for item in diagnostics)
        assert check_copyright.classify(".agent/PLANS.md") is None
        assert check_copyright.classify(".agent/other.py") is not None
        assert check_copyright.classify("third_party/copied.c") is None
        assert check_copyright.classify("generated/output.c") is None
        assert check_copyright.classify("CMakeLists.txt").style == "hash"
    print("Copyright validator tests: passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
