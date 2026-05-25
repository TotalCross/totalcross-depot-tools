# TotalCross native dependencies

This repository keeps third-party native dependencies used by TotalCross in a
versioned, reproducible layout. Each dependency owns its download, build,
packaging and CMake consumption files.

## Layout

- `deps.yml`: compatible dependency bundle index.
- `<dependency>/manifest.yml`: source version, build flags and artifact names.
- `<dependency>/fetch.sh`: downloads or stages the dependency sources.
- `<dependency>/CMakeLists.txt`: builds the dependency in isolation.
- `<dependency>/cmake`: CMake modules used by TotalCross consumers.
- `<dependency>/scripts/package-artifact.sh`: creates release archives.
- `docker`: shared build images by target platform.

TotalCross can consume this repository as a submodule or as an unpacked package:

```cmake
list(APPEND CMAKE_MODULE_PATH "${CMAKE_SOURCE_DIR}/deps/sqlite3/cmake")
list(APPEND CMAKE_MODULE_PATH "${CMAKE_SOURCE_DIR}/deps/mbedtls/cmake")
```

