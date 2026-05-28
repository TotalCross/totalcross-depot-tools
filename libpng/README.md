# libpng

Builds libpng against the prebuilt `zlib-ng` release for the target platform.

```bash
bash ../zlib-ng/fetch.sh --platform macos --arch arm64
cmake -S . -B build/cmake -G Ninja \
  -DCMAKE_INSTALL_PREFIX="$PWD/install" \
  -DZLIB_DIR="$PWD/../zlib-ng/local/macos/arm64"
cmake --build build/cmake
cmake --install build/cmake
bash scripts/package-artifact.sh build/cmake install macos/arm64
```

If you already have a local checkout of the libpng sources, point CMake at it:

```bash
cmake -S . -B build/cmake -G Ninja \
  -DCMAKE_INSTALL_PREFIX="$PWD/install" \
  -DZLIB_DIR="$PWD/../zlib-ng/local/macos/arm64" \
  -DLIBPNG_SOURCE_DIR=/path/to/libpng
```
