# sqlite3-see

Builds the private SQLite Encryption Extension package. Provide the source as
an archive path or authenticated URL:

```bash
SQLITE_SEE_ARCHIVE=/path/to/sqlite-see.zip ./fetch.sh
cmake -S . -B build/cmake -DCMAKE_INSTALL_PREFIX="$PWD/install"
cmake --build build/cmake
cmake --install build/cmake
./scripts/package-artifact.sh
```

