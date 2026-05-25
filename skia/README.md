# skia

This dependency packages the Skia prebuilts produced by
`TotalCross/totalcross-depot-tools`.

The source/build side is pinned in `manifest.json`, while `artifacts.json`
describes the GitHub Release assets consumed by TotalCross.

## Fetch release artifacts

```bash
./fetch.sh --platform linux --arch x86_64 --install-dev
./fetch.sh --platform macos --arch arm64 --install-dev
./fetch.sh --platform android --arch arm64-v8a
```

The default source is the `TotalCross/totalcross-depot-tools` release declared
in `artifacts.json`. Override it with `--base-url`, `--github-repo`,
`--release-tag`, or `--source`.

## Build artifacts

```bash
./scripts/build-macos-arm64.sh
./scripts/build-macos-x86_64.sh
./scripts/build-linux-x86_64.sh
./scripts/build-linux-armv7l.sh
./scripts/build-android-arm64.sh
./scripts/build-android-armv7.sh
./scripts/package-dev-bundle.sh
```

They expect Skia and depot_tools checkouts under this directory:

```text
skia/skia/
skia/depot_tools/
```

Create or update those checkouts with:

```bash
./scripts/fetch-source.sh
```
