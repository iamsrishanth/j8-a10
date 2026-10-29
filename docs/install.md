# Installing the build

> ⚠️ **Nothing here has been flashed to real hardware yet.** The build
> completes and produces a valid OTA ZIP, but no device test has been recorded.
> Read [Rollback reality](#7-rollback-reality) before you start.

## 1. Prerequisites

| Requirement | Detail |
|---|---|
| Bootloader | Unlocked (`OEM LOCK: OFF` in Download mode) |
| Recovery | TWRP for `j8y18lte` installed and bootable (3.x) |
| Host tools | `adb` (platform-tools), `sha256sum` |
| Battery | Charged. **The reference device's power button is broken** — a dead battery means no easy way back |
| Files | The OTA ZIP, *or* `boot.img` + `system.img` + `vendor.img` from the same build |

Verify what you are about to flash:

```bash
sha256sum lineage-17.1-*-UNOFFICIAL-j8y18lte.zip
# compare with artifacts/SHA256SUMS.txt
unzip -p lineage-17.1-*-UNOFFICIAL-j8y18lte.zip META-INF/com/android/metadata
```

The OTA metadata should contain `pre-device=j8y18lte`, `post-sdk-level=29`
and `ota-type=BLOCK`. If `pre-device` is anything else, stop.

## 2. Back up first

Identity partitions are not rebuildable from source:

```powershell
pwsh -File scripts/backup-device.ps1 -Serial <serial> -BackupRoot D:\j8-backup
```

This verifies SHA-256 of every dumped partition against the device. It does
**not** dump `system`/`vendor` (size) or `userdata` (privacy), so it is **not**
a full rollback set. Say that out loud before flashing.

## 3. Install the OTA with TWRP sideload (recommended)

```bash
adb devices -l                 # expect: <serial>  recovery
adb reboot recovery            # only works from a booted Android
```

1. In TWRP: **Wipe → Format Data → yes.**
   Required — a locally built ROM uses different signing keys than whatever is
   installed, and Android will not boot over a `/data` written by another key.
   This erases `/data` **and** internal storage (`/sdcard`).
2. In TWRP: **Advanced → ADB Sideload** (swipe to start).
3. On the host:

   ```bash
   adb devices -l               # expect: <serial>  sideload
   adb sideload lineage-17.1-20261029-UNOFFICIAL-j8y18lte.zip
   ```

4. Wait for `Total xfer: 1.00x` and TWRP's success message. Do not reboot early.
5. Reboot to system: **Reboot → System**, or `adb shell twrp reboot system`.

What the OTA writes (from its `updater-script`):

```text
block_image_update("/dev/block/bootdevice/by-name/system", …)
block_image_update("/dev/block/bootdevice/by-name/vendor", …)
package_extract_file("boot.img", "/dev/block/bootdevice/by-name/boot");
```

- It does **not** contain or flash a recovery image — **TWRP survives**.
- Do not flash the build's `recovery.img` unless you intend to replace TWRP.

If `/sdcard` is not mounted after Format Data, stage the ZIP on a microSD card
or push it to `/cache` (which survives Format Data):

```bash
adb push lineage-17.1-*.zip /cache/
# then in TWRP: Install → select /cache/<file>
```

## 4. Install raw images (when there is no OTA)

Useful for bringing up a build that never got packaged, or for restoring one
image at a time.

`system.img` and `vendor.img` from the build are **Android sparse**. TWRP's
*Install Image* handles them; `dd` does not. Convert for `dd`:

```bash
out/host/linux-x86/bin/simg2img system.img system-raw.img
out/host/linux-x86/bin/simg2img vendor.img vendor-raw.img
```

TWRP method (no shell needed):

```bash
adb push boot.img        /cache/boot.img
adb push system-raw.img  /cache/system.img
adb push vendor-raw.img  /cache/vendor.img
adb shell sha256sum /cache/*.img
# TWRP: Install -> Install Image -> pick file -> pick partition:
#   boot.img   -> Boot
#   system.img -> System Image
#   vendor.img -> Vendor Image
```

## 5. Fallback: `dd` from a shell

Only with a **shell-capable** environment — TWRP's *sideload* mode has no
shell.

```bash
adb shell 'blockdev --getsize64 /dev/block/by-name/system'   # capacity check
adb push boot.img        /data/local/tmp/boot.img
adb push system-raw.img  /data/local/tmp/system.img
adb push vendor-raw.img  /data/local/tmp/vendor.img
adb shell 'sha256sum /data/local/tmp/boot.img /data/local/tmp/system.img /data/local/tmp/vendor.img'
adb shell 'dd if=/data/local/tmp/boot.img   of=/dev/block/by-name/boot   bs=1M'
adb shell 'dd if=/data/local/tmp/system.img of=/dev/block/by-name/system bs=1M'
adb shell 'dd if=/data/local/tmp/vendor.img of=/dev/block/by-name/vendor bs=1M'
adb shell 'sync'
```

Rules:

- raw images only, and smaller than the partition (`blockdev --getsize64`);
- write `boot`, `system`, `vendor` — nothing else in a normal install;
- **never** write `persist`, `efs`, `modemst*`, `fsg`, `fsc`, `apnhlos`,
  `modem` unless restoring that exact verified backup.

## 6. Odin (last resort)

Only sensible with a fully working Samsung-compatible archive.

- Knox is tripped and `ro.boot.flash.locked=1`; Odin may reject a
  non-Samsung-signed image or stall at `SetupConnection`.
- Do **not** enable *Re-Partition* or *NAND Erase*; do not flash a PIT you did
  not generate from this device.
- Packing TWRP as an Odin `AP` tar boots recovery in place of Android — a
  rescue trick, not an install method. See
  [recovery.md](recovery.md#4-the-twrp-on-boot-rescue-experimental-last-resort).

## 7. Rollback reality

- No verified full rollback set exists in this project. The partition backups
  cover boot/recovery/identity, not `system`/`vendor`.
- If the new build does not boot, TWRP can format and retry, but there is no
  preserved previous system image to restore.
- With a broken power button, "cannot boot Android **and** cannot reach TWRP"
  is a brick until a Download-mode route is found.
- The safe order is: dump partitions → confirm TWRP boots → only then write.

## 8. First boot

Expect 5–15 minutes (dexopt). If it hangs:

```bash
adb devices
adb shell getprop sys.boot_completed
adb shell dmesg > dmesg.txt
adb logcat -d > logcat.txt
adb shell cat /proc/last_kmsg > last_kmsg.txt 2>/dev/null
```

Or run `scripts/collect-bootlogs.sh`. A boot animation that never ends is a
`system_server`/HAL problem, not an image-build problem — the image either
mounted or it did not. Check `getenforce`, the first fatal exception in
`logcat`, and `/proc/cmdline`.

## 9. Going back to another ROM

Every ROM needs: TWRP → Format Data → flash that ROM. Different signing keys
mean an in-place downgrade is not possible without wiping data.
