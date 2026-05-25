# mbedtls

Builds Mbed TLS with tests and programs disabled for dependency packaging.

```bash
./fetch.sh
cmake -S . -B build/cmake -DCMAKE_INSTALL_PREFIX="$PWD/install"
cmake --build build/cmake
cmake --install build/cmake
./scripts/package-artifact.sh
```

