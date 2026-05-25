# libpng

Builds libpng against the compatible zlib package.

```bash
../zlib/fetch.sh
cmake -S ../zlib -B ../zlib/build/cmake -DCMAKE_INSTALL_PREFIX="$PWD/../zlib/install"
cmake --build ../zlib/build/cmake
cmake --install ../zlib/build/cmake

./fetch.sh
cmake -S . -B build/cmake -DCMAKE_INSTALL_PREFIX="$PWD/install" -DZLIB_ROOT="$PWD/../zlib/install"
cmake --build build/cmake
cmake --install build/cmake
./scripts/package-artifact.sh
```

