<!-- Archived report. Host names, IP addresses, user names, paths and the device serial have been genericised; wording and figures are otherwise unchanged. -->

# Android 10 / LineageOS 17.1 Build Status — 2026-10-26

## Current state

- Source tree: `/home/builder/android/lineage-17.1` on the WSL distro of the Windows host `builder`.
- Device/kernel/vendor pins are in `.repo/local_manifests/j8y18lte.xml`.
- Full source tree built far enough to produce:
  - `boot.img`
  - `vendor.img`
  - a system image, built manually after the normal image step failed.
- No OTA ZIP was produced.
- The system/vendor/boot images are not signed with the project release keys.
- The phone is currently disconnected from the controller, so nothing has been flashed.

## Build problem

The normal `m bacon` / `systemimage` flow fails in `e2fsdroid`:

```
set_selinux_xattr: No such file or directory searching for label "/firmware"
```

Variants also failed on `/config/.keep` and `/omr` when the device-tree
root-folder/file_context workarounds were applied.

Root cause is the 17.1 device tree's root directory/symlink and
file_contexts handling:

- `BOARD_ROOT_EXTRA_SYMLINKS` contains `/vendor/firmware_mnt:/firmware`.
- `BOARD_ROOT_EXTRA_FOLDERS` contains `config omr efs`.
- The build does not reliably stage these into the image source tree before
  `e2fsdroid`, and removing the labels breaks image creation.

Source edits made during debugging were restored from git:
- `device/samsung/j8y18lte/BoardConfig.mk`
- `device/samsung/j8y18lte/config.fs`
- `device/samsung/j8y18lte/sepolicy/file_contexts`
- `device/qcom/sepolicy-legacy/common/file_contexts`

## Manual images

Generated with the prebuilt `mke2fs`/`e2fsdroid` and a minimal
`u:object_r:rootfs:s0` label set:

| File | Size | SHA-256 |
|---|---:|---|
| `boot.img` | 13,064,192 | `b335f5611d2329dfad1df6182d8bce7606ac85b6a0be07c2a704a7e57afcffe3` |
| `system-raw.img` | 3,397,386,240 | `d071d4b81ab7354866ceec4da91fe714ade314f894078c7d930680cf2c082863` |
| `vendor-raw.img` | 503,316,480 | `11aab794a42f7815ccef081433d528ba0cdeaa60ccadcc4c26708323884ef820` |

Location on controller:

`C:\Users\user\staging\android10-images\`

Boot cmdline includes:

```
androidboot.selinux=permissive buildvariant=userdebug
```

Because the manual system image uses a minimal label set, it is a
**permissive boot-test image**, not a final release image.

## Install procedure (when phone is connected)

1. Boot TWRP and confirm `adb devices` shows `a7d4xxxx recovery`.
2. Push the three images to `/sdcard`.
3. Flash:
   - `boot.img` -> boot partition
   - `system-raw.img` -> system partition
   - `vendor-raw.img` -> vendor partition
4. Format data.
5. Reboot to system.
6. Validate display/touch, Wi-Fi, RIL, audio, camera, storage, charging.

TWRP command for reboot: `twrp reboot system`.

## Constraints

No GApps, KernelSU/root, debloat, tuning, or bootloader changes.
Keep TWRP intact.
