# zlib

Builds madler zlib as a TotalCross native dependency using the same static
`Z_SOLO` layout consumed by `TotalCrossVM`.

```bash
cmake -S . -B build/cmake -G Ninja -DCMAKE_INSTALL_PREFIX="$PWD/install"
cmake --build build/cmake
cmake --install build/cmake
bash scripts/package-artifact.sh build/cmake install macos/arm64
```

If you already have a local checkout of the zlib sources, point CMake at it to
avoid downloading during configure:

```bash
cmake -S . -B build/cmake -G Ninja \
  -DCMAKE_INSTALL_PREFIX="$PWD/install" \
  -DZLIB_SOURCE_DIR=/path/to/zlib
```
