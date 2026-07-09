# minizip-ng

Builds minizip-ng as a TotalCross native dependency, linked against this
repository's zlib-ng prebuilts.

```bash
bash ../zlib-ng/fetch.sh --platform macos --arch arm64
cmake -S . -B build/cmake -G Ninja \
  -DZLIB_DIR="$PWD/../zlib-ng/local/macos/arm64"
cmake --build build/cmake
cmake --install build/cmake --prefix "$PWD/install"
bash scripts/package-artifact.sh build/cmake install macos/arm64
```

If you already have a local checkout of minizip-ng sources, point CMake at it to
avoid downloading during configure:

```bash
cmake -S . -B build/cmake -G Ninja \
  -DZLIB_DIR="$PWD/../zlib-ng/local/macos/arm64" \
  -DMINIZIP_NG_SOURCE_DIR=/path/to/minizip-ng
```
