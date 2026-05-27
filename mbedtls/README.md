# mbedTLS

Builds mbedTLS 3.5.2 as static libraries for the platforms consumed by
TotalCross.

```bash
cmake -S . -B build/cmake -DCMAKE_INSTALL_PREFIX="$PWD/install"
cmake --build build/cmake
cmake --install build/cmake
./scripts/package-artifact.sh build/cmake install linux/x86_64
```

Release archives contain:

```text
mbedtls/<platform>/<arch>/
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
