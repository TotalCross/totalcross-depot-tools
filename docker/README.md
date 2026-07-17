# Linux build image contract

The `linux-*` images remain the compatibility image names consumed by existing
workflows. Version `v2.0.1` is the minimal native-CMake generation: Ubuntu
Bionic, the distribution that defines the oldest glibc baseline for these
artifacts, with GCC, the Kitware CMake repository (CMake 3.16 or newer), Ninja,
Git, ccache, curl, and rsync only. It does not include SDL, audio, X11, Wayland,
or desktop graphics headers.

`skia-linux-amd64` is separate because Skia needs Python, ccache, rsync and the
AArch64 cross compiler. GN is obtained deterministically from Skia's pinned
`depot_tools` checkout rather than an Ubuntu package. Build jobs must not
install packages at runtime.
The supported targets remain x86_64, armv7l, and aarch64 and package scripts
must continue to emit static libraries only.
