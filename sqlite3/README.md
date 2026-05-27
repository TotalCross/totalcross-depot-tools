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
`local/<platform>/<arch>`.

To consume a prebuilt release asset:

```bash
./fetch.sh --platform linux --arch x86_64
```
