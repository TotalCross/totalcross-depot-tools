# TotalCross consumer behavior reference

Use these paths in `TotalCross/totalcross` as a behavior reference:

- `TotalCrossVM/deps/fetch-depot-tools.sh` reads an environment override or the
  first non-comment line of `totalcross-depot-tools.ref`, verifies the checkout
  origin, fetches tags, restores missing Git metadata, and checks out the ref.
- `TotalCrossVM/deps/totalcross-depot-tools.ref` is the committed pin.
- `TotalCrossVM/CMakeLists.txt` fetches the checkout when `deps.yml` is absent,
  adds dependency CMake module paths, invokes auto-fetch modules, calls
  `find_package`, and links imported targets.

Do not copy its LGPL headers into another project. Preserve the target consumer's
license, directory names, feature flags, and platform conditions.
