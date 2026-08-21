#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Amalgam Solucoes em TI Ltda.
# SPDX-License-Identifier: MIT
"""Create a reproducible gzip-compressed tar archive for an artifact tree."""

from __future__ import print_function

import gzip
import os
import sys
import tarfile


def normalized_tarinfo(archive, path, arcname):
    info = archive.gettarinfo(path, arcname)
    info.uid = 0
    info.gid = 0
    info.uname = "root"
    info.gname = "root"
    info.mtime = 0
    return info


def iter_paths(root, relative_root):
    start = os.path.join(root, relative_root)
    yield start, relative_root
    for directory, directories, files in os.walk(start):
        directories.sort()
        files.sort()
        relative_directory = os.path.relpath(directory, root)
        for name in directories:
            path = os.path.join(directory, name)
            yield path, os.path.join(relative_directory, name)
        for name in files:
            path = os.path.join(directory, name)
            yield path, os.path.join(relative_directory, name)


def main(argv):
    if len(argv) != 4:
        print("usage: create-deterministic-archive.py ROOT TREE OUTPUT", file=sys.stderr)
        return 2

    root, relative_root, output = argv[1:]
    tree = os.path.join(root, relative_root)
    if not os.path.isdir(tree):
        print("artifact tree does not exist: {0}".format(tree), file=sys.stderr)
        return 1

    with open(output, "wb") as output_handle:
        with gzip.GzipFile(filename="", mode="wb", fileobj=output_handle, mtime=0) as compressed:
            with tarfile.open(fileobj=compressed, mode="w", format=tarfile.PAX_FORMAT) as archive:
                for path, arcname in iter_paths(root, relative_root):
                    info = normalized_tarinfo(archive, path, arcname)
                    if info.isfile():
                        with open(path, "rb") as input_handle:
                            archive.addfile(info, input_handle)
                    else:
                        archive.addfile(info)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
