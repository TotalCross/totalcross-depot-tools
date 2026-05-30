# zlib-ng

Builds zlib-ng as a TotalCross native dependency in zlib compatibility mode.
The iOS release artifact is packaged as `zlib-ng-ios-xcframework.tar.gz`, with
device and simulator arm64 slices in `lib/libz.xcframework`.

```bash
cmake -S . -B build/cmake -G Ninja -DCMAKE_INSTALL_PREFIX="$PWD/install"
cmake --build build/cmake
cmake --install build/cmake
bash scripts/package-artifact.sh build/cmake install macos/arm64
```

If you already have a local checkout of the zlib-ng sources, point CMake at it
to avoid downloading during configure:

```bash
cmake -S . -B build/cmake -G Ninja \
  -DCMAKE_INSTALL_PREFIX="$PWD/install" \
  -DZLIB_NG_SOURCE_DIR=/path/to/zlib-ng
```
