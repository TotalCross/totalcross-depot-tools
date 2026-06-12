# SQLite3

Builds SQLite3 3.32.3 as a static library using the same SQLite compile options
used by the TotalCross VM build.

```bash
cmake -S . -B build/cmake -DCMAKE_INSTALL_PREFIX="$PWD/install"
cmake --build build/cmake
cmake --install build/cmake
./scripts/package-artifact.sh build/cmake install linux/x86_64
```

Release archives contain:

```text
sqlite3/<platform>/<arch>/
  include/
  lib/
  manifest.txt
```

Fetched prebuilts are installed with the same platform split under
`local/<release-tag>-<repo-hash12>/<platform>/<arch>`. The hash is the first
12 hex characters of the SHA-256 of the `OWNER/REPO` value passed with
`--github-repo`. This lets multiple SQLite3 release origins coexist locally.

To consume a prebuilt release asset:

```bash
./fetch.sh --platform linux --arch x86_64
```

To fetch the same release tag from another repository without overwriting the
default TotalCross copy:

```bash
./fetch.sh \
  --platform linux \
  --arch x86_64 \
  --release-tag sqlite3-3.32.3 \
  --github-repo Example/sqlite-builds
```

CMake consumers can select the same origin by setting `SQLITE3_RELEASE_TAG` and
`SQLITE3_GITHUB_REPO`. `FindSQLite3.cmake` and `AutoFetchSQLite3.cmake` resolve
the matching local path automatically.
