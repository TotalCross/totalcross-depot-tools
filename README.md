# TotalCross native dependencies

This repository keeps third-party native dependencies used by TotalCross in a
versioned, reproducible layout. Each dependency owns its download, build,
packaging and CMake consumption files.

## Layout

- `deps.yml`: compatible dependency bundle index.
- `<dependency>/manifest.yml`: source version, build flags and artifact names.

When one dependency build consumes another repository artifact, it resolves the
compatible release pin from `deps.yml`. This keeps Skia, libpng, minizip, and
minizip-ng aligned with the bundle rather than selecting the newest release.
- `<dependency>/fetch.sh`: downloads or stages the dependency sources.
- `<dependency>/CMakeLists.txt`: builds the dependency in isolation.
- `<dependency>/cmake`: CMake modules used by TotalCross consumers.
- `<dependency>/scripts/package-artifact.sh`: creates release archives.
- `docker`: shared build images by target platform.

Skia is the exception on the build side: it is built with GN/Ninja through 
scripts, and consumed through the CMake fetch/find modules imported from 
TotalCrossVM.

## Maintainer

Created and maintained by [Fabio Sobral](https://github.com/flsobral).

Copyright © 2026 Amalgam Solucoes em TI Ltda.

Licensed under the MIT License.

TotalCross can consume this repository as a submodule or as an unpacked package:

```cmake
list(APPEND CMAKE_MODULE_PATH "${CMAKE_SOURCE_DIR}/deps/sqlite3/cmake")
list(APPEND CMAKE_MODULE_PATH "${CMAKE_SOURCE_DIR}/deps/mbedtls/cmake")
list(APPEND CMAKE_MODULE_PATH "${CMAKE_SOURCE_DIR}/deps/axtls/cmake")
list(APPEND CMAKE_MODULE_PATH "${CMAKE_SOURCE_DIR}/deps/qrcodegen/cmake")
list(APPEND CMAKE_MODULE_PATH "${CMAKE_SOURCE_DIR}/deps/qrcode/cmake")
```
