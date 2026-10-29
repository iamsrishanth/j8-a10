# Status

Last updated: **2026-10-30 05:07** (Asia/Calcutta). Every statement below is
backed by a command output, a log, or a file hash recorded in this repository
([`logs/`](logs/), [`artifacts/`](artifacts/), [`history/`](history/)).

## TL;DR

`m -j16 bacon` on the pinned LineageOS 17.1 tree for `j8y18lte` now **completes**
and produces a 543 MB OTA ZIP. The build is `userdebug`, **test-key signed**,
SELinux **permissive**. It has **not** been flashed or booted on hardware.

## Stage table

| Stage | State | Evidence |
|---|---|---|
| Source sync (`lineage-17.1`) | âœ… | tree ~120 GB, `.repo` 18 GB |
| Device/kernel/vendor pins | âœ… | `1b4f25e` / `3a7e803` / `ca797aa` (`repo status` clean apart from the two patches) |
| `breakfast lineage_j8y18lte` | âœ… | `TARGET_PRODUCT=lineage_j8y18lte`, `TARGET_BUILD_VARIANT=userdebug` |
| Kernel (3.18.140, arm64) | âœ… | `Image.gz-dtb`, 12,297,618 B payload in `boot.img` |
| `system.img` | âœ… | Android sparse, 1,078,473,140 B |
| `vendor.img` | âœ… | Android sparse, 248,877,228 B |
| `boot.img` | âœ… | 13,064,192 B |
| `recovery.img` | âœ… | 22,284,288 B |
| **OTA ZIP** | âœ… | `lineage-17.1-20261029-UNOFFICIAL-j8y18lte.zip`, 543,395,513 B, `Package Complete` in the log |
| Release-key signing | âŒ | OTA cert is AOSP testkey (`CN=Android`) |
| Device install / boot | âŒ | not attempted in the recorded sessions |
| Runtime validation | âŒ | no device evidence exists |

Build log: [`logs/2026-10-30-bacon-success.log`](logs/2026-10-30-bacon-success.log)
(`#### build completed successfully (02:51) ####`).

## Build identity (from the OTA metadata and `build.prop`)

| Property | Value |
|---|---|
| Android release / SDK | 10 / 29 |
| LineageOS version | 17.1 |
| Build variant | `userdebug` |
| Build tags | `test-keys` |
| Fingerprint | `samsung/lineage_j8y18lte/j8y18lte:10/QQ3A.200805.001/eng.<builder>.<stamp>:userdebug/test-keys` |
| Security patch level | 2023-02-05 |
| ABIs | `armeabi-v7a`, `armeabi` (32-bit userspace, no 64-bit ABI) |
| SELinux | **permissive** |
| AVB / dm-verity | none ([analysis](docs/integrity.md)) |
| OTA type | BLOCK, brotli-compressed `system.new.dat.br` + `vendor.new.dat.br` |

## What the OTA writes

From `META-INF/com/google/android/updater-script` in the produced ZIP:

```text
block_image_update("/dev/block/bootdevice/by-name/system", â€¦) ||
block_image_update("/dev/block/bootdevice/by-name/vendor", â€¦) ||
package_extract_file("boot.img", "/dev/block/bootdevice/by-name/boot");
```

- Writes **system**, **vendor** and **boot** only.
- Does **not** contain or flash `recovery` â€” TWRP survives the install.
- OTA asserts `pre-device=j8y18lte`.

## Artifacts (SHA-256)

| File | Bytes | SHA-256 |
|---|---:|---|
| `lineage-17.1-20261029-UNOFFICIAL-j8y18lte.zip` | 543,395,513 | `f3c520dc0307af653d0f867d881008932c8a538e8a119eb017bdba1e32958940` |
| `boot.img` | 13,064,192 | `b335f5611d2329dfad1df6182d8bce7606ac85b6a0be07c2a704a7e57afcffe3` |
| `system.img` (sparse) | 1,078,473,140 | `e3cecf2b21494595b1441034d698eb239038f145b041c0e317df4a0a2a1a3742` |
| `vendor.img` (sparse) | 248,877,228 | `41816c1ca3d12c4072487d21e9c4c4c3a04dcca9b61c0223cf0f8aba93f8ecc3` |
| `recovery.img` | 22,284,288 | `9910c42bda21239bbaa99985222f06cdd05b6ef91aba1b2d636eb8a994b60d37` |

Earlier diagnostic images (raw, minimal label set) are recorded in
[`artifacts/MANIFEST.md`](artifacts/MANIFEST.md) and must not be confused
with these.

## Source state

The build runs on the pinned tree with two local changes, both persisted as
patches in [`patches/`](patches/):

| File | Change |
|---|---|
| `device/samsung/j8y18lte/BoardConfig.mk` | `BOARD_SEPOLICY_DIRS += device/samsung/j8y18lte/sepolicy` (explicit path instead of `$(LOCAL_PATH)`), plus a final newline |
| `device/samsung/j8y18lte/sepolicy/property_contexts` | added the missing final newline |

Both are described with root-cause analysis in
[`docs/build-troubleshooting.md`](docs/build-troubleshooting.md).

## Device state (last recorded)

- TWRP reachable over ADB in earlier sessions; ADB sideload confirmed working.
- Partition backups captured 2026-10-30: boot, efs, persist, modemst1/2, fsg,
  fsc, config, misc (+ `console-ramoops`, `pmsg-ramoops`). **Not** a full
  rollback set â€” no `system`/`vendor` images.
- No Android 10 image has been written to the device.
- Power button is broken; all recovery work is driven over ADB.

## Next steps

1. **Sign with project keys** ([docs/signing.md](docs/signing.md)) â€” the
   current ZIP is test-key signed. Expect a mandatory data wipe on first flash.
2. **Install over TWRP** ([docs/install.md](docs/install.md)): Format Data,
   then sideload the ZIP or write the images directly.
3. **Validate** with the matrix in [docs/validation.md](docs/validation.md),
   capturing `dmesg`/`logcat`/`getprop` on the first boot.
4. Only then decide whether to pursue **SELinux enforcing** â€” that requires
   iterating on vendor HAL policy and will produce boot loops until complete.
5. Record the result here with boot-log evidence before calling the ROM
   "working".
