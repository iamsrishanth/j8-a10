# Sources, pins and licensing

## 1. Upstream components

| Component | Repository | Path in tree | Pin |
|---|---|---|---|
| LineageOS manifest | `LineageOS/android` @ `lineage-17.1` | — | branch tip at sync time |
| Device tree | [`goldfish07/android_device_samsung_j8y18lte`](https://github.com/goldfish07/android_device_samsung_j8y18lte) | `device/samsung/j8y18lte` | `1b4f25eff98554feac5c0ab945c70be6589c3693` |
| Kernel | [`goldfish07/android_kernel_samsung_j8y18lte`](https://github.com/goldfish07/android_kernel_samsung_j8y18lte) | `kernel/samsung/j8y18lte` | `3a7e80328b108097e984c028c0fd1f9e65678e31` |
| Vendor blobs | [`goldfish07/android_vendor_samsung_j8y18lte`](https://github.com/goldfish07/android_vendor_samsung_j8y18lte) | `vendor/samsung/j8y18lte` | `ca797aa33d3e786613cc86440f1b00b32bbf7d43` |
| Samsung hardware | [`LineageOS/android_hardware_samsung`](https://github.com/LineageOS/android_hardware_samsung) | `hardware/samsung` | branch default |
| Samsung SLPI sepolicy | [`LineageOS/android_device_samsung_slsi_sepolicy`](https://github.com/LineageOS/android_device_samsung_slsi_sepolicy) | `device/samsung_slsi/sepolicy` | branch default |
| Device settings | `LineageOS/android_packages_resources_devicesettings` | `packages/resources/devicesettings` | branch default |

The pins are exactly what `manifests/j8y18lte.xml` and
`manifests/roomservice.xml` encode. If you change a pin, record the build and
the resulting image hashes.

### Why pins instead of branch names

A branch tip moves; a ROM build does not. Pinning device/kernel/vendor means:

- the exact same tree can be rebuilt months later,
- a failure can be bisected against a known-good combination,
- and "it worked yesterday" becomes a specific, checkable claim.

## 2. What is vendored here, and why

`device/samsung/j8y18lte/` is a **verbatim copy** of the device tree at the
pin, plus the local patches in [`patches/`](../patches/). It is included so the
actual ROM configuration is readable in this repository without syncing 120 GB.

It is not the source of truth. Upstream (`goldfish07`) is. If the two
disagree, upstream wins unless the difference is one of the patches.

Not vendored:

| Item | Size | Why not |
|---|---:|---|
| Kernel source | 833 MB | available upstream; GPL source stays upstream |
| Vendor blobs | 236 MB | proprietary; must be extracted from firmware |
| AOSP / LineageOS framework | ~100 GB | manifest handles it |

## 3. Vendor blobs

The blobs in `vendor/samsung/j8y18lte` are extracted from Samsung's Android 10
firmware for this model (`J810GDDU5CUF2`), using the device tree's
`extract-files.sh` and `proprietary-files.txt`.

Legal position, stated plainly: these files are Samsung/Qualcomm proprietary
binaries. Redistributing them is a licensing question this repository does not
answer. The manifest points at a public mirror; if you redistribute a ROM, you
do so at your own risk.

## 4. Licensing of this repository

| Part | License |
|---|---|
| Documentation, scripts, build tooling in this repo | Apache-2.0 ([LICENSE](../LICENSE)) |
| Vendored device tree | Apache-2.0, per its upstream headers |
| Kernel (referenced by pin) | GPL-2.0 |
| AOSP / LineageOS components | Apache-2.0 (mixed with other OSS licenses) |
| Samsung/Qualcomm vendor blobs | proprietary; not distributed here |

**GPL note for anyone distributing images:** if you publish a flashable ROM
built from this tree, you are distributing a GPL-2.0 kernel binary and must
make the corresponding kernel source available. The pin in the manifest is the
easiest way to satisfy that — link to the exact commit you built.

## 5. Reproducing the exact tree

```bash
repo init -u https://github.com/LineageOS/android.git -b lineage-17.1
mkdir -p .repo/local_manifests
cp manifests/j8y18lte.xml manifests/roomservice.xml .repo/local_manifests/
repo sync -c -j8 --force-sync --no-clone-bundle --no-tags
bash scripts/apply-patches.sh
```

Verify each pinned component:

```bash
for p in device/samsung/j8y18lte kernel/samsung/j8y18lte vendor/samsung/j8y18lte; do
  printf '%-40s %s\n' "$p" "$(git -C "$p" rev-parse HEAD)"
done
```

Expected:

```text
device/samsung/j8y18lte                  1b4f25eff98554feac5c0ab945c70be6589c3693
kernel/samsung/j8y18lte                  3a7e80328b108097e984c028c0fd1f9e65678e31
vendor/samsung/j8y18lte                  ca797aa33d3e786613cc86440f1b00b32bbf7d43
```

## 6. Attribution

The device tree, kernel and vendor repositories are the work of
[goldfish07](https://github.com/goldfish07) and the LineageOS project. This
repository adds the Android 10 bring-up notes, build tooling, analysis and the
local patches. No authorship of the upstream work is claimed.
