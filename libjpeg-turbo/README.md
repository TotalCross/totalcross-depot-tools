# libjpeg-turbo

Static libjpeg-turbo v3.1.4.1 prebuilts for TotalCross.

Artifacts are installed under `local/<platform>/<arch>` and contain the classic
libjpeg API plus the TurboJPEG API:

- `include/jconfig.h`
- `include/jerror.h`
- `include/jmorecfg.h`
- `include/jpeglib.h`
- `include/turbojpeg.h`
- `lib/libjpeg.a` or `jpeg-static.lib`
- `lib/libturbojpeg.a` or `turbojpeg-static.lib`
- `manifest.txt`

Use `cmake/AutoFetchLibJpegTurbo.cmake` before `find_package(JPEG MODULE)` when
a consumer should download the matching prebuilt automatically. The module
publishes `JPEG::JPEG` and `TurboJPEG::TurboJPEG`.
