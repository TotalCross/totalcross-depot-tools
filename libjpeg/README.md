# libjpeg

Static IJG libjpeg v10 prebuilts for TotalCross.

Artifacts are installed under `local/<platform>/<arch>` and contain:

- `include/jconfig.h`
- `include/jerror.h`
- `include/jmorecfg.h`
- `include/jpeglib.h`
- `lib/libjpeg.a` or the Windows static import name
- `manifest.txt`

Use `cmake/AutoFetchLibJpeg.cmake` before `find_package(JPEG MODULE)` when a
consumer should download the matching prebuilt automatically.
