#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda.
# SPDX-License-Identifier: MIT
import json
import pathlib
import re
import sys


ROOT = pathlib.Path(__file__).resolve().parents[2]


def load_json(path):
    with path.open(encoding="utf-8") as handle:
        return json.load(handle)


def write_json(path, value):
    path.write_text(json.dumps(value, indent=4) + "\n", encoding="utf-8")


def replace_version_tags(path, version, new_tag):
    tag_re = re.compile(rf"skia-{re.escape(version)}(?:-r[0-9]+)?")
    text = path.read_text(encoding="utf-8")
    updated = tag_re.sub(new_tag, text)
    if updated != text:
        path.write_text(updated, encoding="utf-8")


def main(argv):
    if len(argv) != 2:
        print("Usage: update-skia-release-tag.py TAG", file=sys.stderr)
        return 2

    new_tag = argv[1]
    manifest_path = ROOT / "skia" / "manifest.json"
    artifacts_path = ROOT / "skia" / "artifacts.json"

    manifest = load_json(manifest_path)
    skia_version = manifest["skia"]["commit"][:8]
    valid_tag = re.compile(rf"^skia-{re.escape(skia_version)}(?:-r[0-9]+)?$")
    if not valid_tag.fullmatch(new_tag):
        print(
            f"Invalid Skia release tag '{new_tag}', expected skia-{skia_version} or skia-{skia_version}-rN",
            file=sys.stderr,
        )
        return 1

    manifest["release"]["tag"] = new_tag
    write_json(manifest_path, manifest)

    artifacts = load_json(artifacts_path)
    artifacts["release"]["tag"] = new_tag
    artifacts["defaults"]["source"]["tag"] = new_tag
    write_json(artifacts_path, artifacts)

    for relative_path in (
        "deps.yml",
        "skia/manifest.yml",
        "skia/fetch.sh",
        "skia/cmake/AutoFetchSkia.cmake",
    ):
        replace_version_tags(ROOT / relative_path, skia_version, new_tag)

    print(new_tag)
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
