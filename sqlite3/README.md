# sqlite3

Builds SQLite from the upstream amalgamation used by TotalCross.

```bash
./fetch.sh
cmake -S . -B build/cmake -DCMAKE_INSTALL_PREFIX="$PWD/install"
cmake --build build/cmake
cmake --install build/cmake
./scripts/package-artifact.sh
```

