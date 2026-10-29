# Manifests

Two files, both meant to be copied into `<source-tree>/.repo/local_manifests/`
**before** the first `repo sync`.

| File | Purpose |
|---|---|
| `j8y18lte.xml` | Pins the device tree, kernel and vendor blobs to exact commits |
| `roomservice.xml` | Pulls `hardware/samsung` and `device/samsung_slsi/sepolicy` |

## Why `--force-sync` and pins

`repo sync -c --force-sync` keeps only the current branch and makes an
interrupted sync restartable without leftover mismatched state. The explicit
hashes mean a later `repo sync` will not silently move the device tree out
from under a working build.

If you *want* newer upstream code, change the pin deliberately, then update
[`../docs/sources.md`](../docs/sources.md) and record the new build's artifact
hashes.

## Syncing

```bash
repo init -u https://github.com/LineageOS/android.git -b lineage-17.1
cp manifests/j8y18lte.xml manifests/roomservice.xml .repo/local_manifests/
repo sync -c -j8 --force-sync --no-clone-bundle --no-tags
```

Verify the pins landed:

```bash
repo manifest -r -o /tmp/pinned.xml && grep -E 'j8y18lte' -A2 /tmp/pinned.xml
```

## A note on `--git-lfs`

The LineageOS 17.1 tree contains Git LFS objects (notably
`external/chromium-webview/prebuilt/*/webview.apk`). A sync without LFS
yields 133-byte pointer files that break the build at packaging time. See
[`../docs/build-troubleshooting.md`](../docs/build-troubleshooting.md#3-chromium-webview-is-a-git-lfs-pointer).
