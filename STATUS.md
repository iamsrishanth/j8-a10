# Status

Last updated: **2026-10-30 11:45 IST** (Asia/Calcutta).

## TL;DR

**Android 10 now builds, is signed with the project's own release keys, installs
through TWRP, and boots to a working LineageOS 17.1 UI on the SM-J810G.**

The build that was validated is the **permissive diagnostic** one
(`androidboot.selinux=permissive`). A matching **enforcing** OTA exists and is
verified, but has not been flashed yet: the phone powered off during the
reboot-to-recovery and has not re-enumerated on USB since (battery drained
while the host slept ~5½ h).

## Stage table

| Stage | State | Evidence |
|---|---|---|
| Source sync (LineageOS 17.1 + pins) | ✅ | `1b4f25e` / `3a7e803` / `ca797aa` |
| Build fix (sepolicy aggregation + property contexts) | ✅ | [`docs/build-troubleshooting.md`](docs/build-troubleshooting.md) |
| `m systemimage` / `m bacon` | ✅ | `Package Complete`, `#### build completed successfully` |
| Release-key signing | ✅ | OTA `post-build` says `userdebug/release-keys`; signed with the project key set |
| TWRP install | ✅ | `/sbin/twrp install` → `script succeeded: result was [1.000000]` |
| Data format | ✅ | `/sbin/twrp format data`, fresh ext4 `/data` |
| First boot | ✅ | `sys.boot_completed=1`, Setup Wizard rendered at 720×1480 |
| Hardware validation (permissive build) | ⚠️ partial | [`VALIDATION.md`](VALIDATION.md) — display/BT/RIL/sensors/camera-service/storage/charging pass; touch/audio/camera-capture/SIM not tested |
| Enforcing cold boot | ⛔ blocked | phone offline since 11:18 IST |
| Release acceptance | ⛔ not yet | requires the enforcing cold boot + the human tests |

## Build identity (installed, validated)

| Property | Value |
|---|---|
| Build | `lineage_j8y18lte-userdebug 10 QQ3A.200805.001 …` |
| LineageOS version | `17.1-20261029-UNOFFICIAL-j8y18lte` |
| Android / SDK | 10 / 29 |
| Security patch | 2023-02-05 |
| ABIs | `armeabi-v7a`, `armeabi` (32-bit userspace, 64-bit kernel) |
| Build tags | **`release-keys`** (own keys applied) |
| SELinux (installed build) | permissive — diagnostic |
| SELinux (artifact ready) | enforcing — not yet flashed |
| AVB / dm-verity | none ([analysis](docs/integrity.md)) |

## Artifacts

| Artifact | Bytes | SHA-256 |
|---|---:|---|
| Permissive signed OTA (**installed & booted**) | 543,446,412 | `d105a267a8979b2b634b02aa48f5094f898f6ed0537a35e0bf3be0817592fd91` |
| Permissive signed target-files | 1,293,717,122 | `e48075692dfd0666e71c23af1d6179accfbbae4cb31e32ce982aaf6d9c899072` |
| Enforcing signed OTA (**ready, not flashed**) | 543,446,361 | `8f5669c8ae47368e986ae7f9610b94857ee005832ef7e935e6138376f3c98abc` |
| Enforcing signed target-files | 1,293,716,968 | `0e429f547404203e0cf9d15da82fc97689e57ccc120154c64ec784f4e0ca1263` |
| `boot.img` — permissive (inside permissive OTA) | 13,064,192 | `b335f5611d2329dfad1df6182d8bce7606ac85b6a0be07c2a704a7e57afcffe3` |
| `boot.img` — enforcing (inside enforcing OTA) | 13,064,192 | `fc23372e91e90281892cdd979e6affd34c0e3f19146f7fbaf4a6507f521a8e54` |
| TWRP recovery (unchanged by the OTA) | 33,554,432 | `1b6538d566fd0a0c622ca2e78dedeb1b86a3dbf5f9199e9575ef67de0efd6e05` |

Full list, including identity-partition backups:
[`artifacts/MANIFEST.md`](artifacts/MANIFEST.md).

## What was verified on the device

- `sys.boot_completed=1` within ~45 s; Setup Wizard and lock screen rendered.
- Wi-Fi driver/firmware up (`wlan0`), Bluetooth ON, Samsung RIL v4.0 daemons
  running, 5 sensors, 2 camera devices, `/data` 52 GB, charging.
- Runtime `setenforce 1` held for **5+ hours** with UI, adb and Wi-Fi intact;
  only cosmetic denials (`healthd` battery sysfs, `kernel` hall_detect).
- TWRP still present after the OTA; the OTA writes system/vendor/boot only.
- ADB survived the data format once `/data/misc/adb/adb_keys` was re-seeded.

Details, per-test evidence and screenshots: [`VALIDATION.md`](VALIDATION.md)
and [`evidence/2026-10-30-first-boot/`](evidence/2026-10-30-first-boot/).

## Known defects

1. **`ro.build.fingerprint` shows the stock Samsung string**
   (`samsung/j8y18ltedd/j8y18lte:10/QP1A.190711.020/J810GDDU4CUB2:user/release-keys`)
   even though `/system/build.prop` and `/vendor/build.prop` carry the correct
   LineageOS values. The untouched stock **ODM** partition defines it and wins.
   Cosmetic for now; anything that reads the fingerprint (Play certification,
   CTS-style checks) will see a stock Samsung build.
2. **`healthd` battery-sysfs denials** under enforcing — the battery is still
   reported and charging works; the labels need `sysfs_batteryinfo` rules if a
   cold enforcing boot shows the same noise.
3. The permissive build logs ~530 AVC denials per boot (mostly
   `flags_health_check` property reads). They are informational only in
   permissive mode.

## Current blocker (physical, not software)

The phone went dark right after `adb reboot recovery` at **11:18 IST** and
stopped enumerating on USB. No write was in flight (the enforcing boot image
had not been written). Most likely the battery drained while the host slept
05:40–11:00 and the reboot exhausted it.

**Next action:** leave the phone on a powered USB port until Windows enumerates
it again (`Get-PnpDevice` for `VID_04E8`/`VID_18D1`, or `adb devices`), then:

1. If it boots the installed Android 10: `adb reboot recovery`.
2. In TWRP: push `enforcing-boot.img` (sha256 `fc23372e…a8e54`),
   `dd if=/sdcard/enforcing-boot.img of=/dev/block/by-name/boot bs=4096`,
   read back and compare, then `/sbin/twrp reboot system`.
3. Confirm `getenforce` = `Enforcing` **from a cold boot**, then re-run
   [`VALIDATION.md`](VALIDATION.md).

## Next steps after that

1. Human tests: tap through Setup Wizard (touch), play audio, take a photo.
2. Insert a SIM and confirm registration/calls — RIL is already running.
3. Decide whether to chase the ODM fingerprint override (would need an
   ODM/vendor prop overlay or a modified stock ODM — out of scope for now).
4. Add `healthd`/`kernel` battery-sysfs policy rules if the enforcing cold
   boot shows the same denials.
