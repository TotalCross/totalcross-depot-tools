# zlib

Builds zlib as a TotalCross native dependency.

```bash
./fetch.sh
cmake -S . -B build/cmake -DCMAKE_INSTALL_PREFIX="$PWD/install"
cmake --build build/cmake
cmake --install build/cmake
./scripts/package-artifact.sh
```

