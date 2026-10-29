# Installing the build

> ⚠️ Nothing in this repository has been flashed to a device yet. This
> document is the reviewed procedure, not a report of a successful install.
> Read [Rollback reality](#6-rollback-reality) before you start.

## 1. Prerequisites

| Requirement | Detail |
|---|---|
| Bootloader | Unlocked (`OEM LOCK: OFF` in Download mode) |
| Recovery | TWRP for `j8y18lte` installed and bootable |
| Host tools | `adb` (platform-tools), `sha256sum`, `simg2img` from the build tree |
| Battery | Charged. **The power button on the reference device is broken** — a dead battery means no easy way back |
| Files | `boot.img`, `system.img`, `vendor.img` from the same build |

Images land in `out/target/product/j8y18lte/`. `system.img` is often **sparse**
(`-E android_sparse`); raw-write paths need a raw image:

```bash
# convert sparse -> raw (once, on the build host)
out/host/linux-x86/bin/simg2img system.img system-raw.img
```

Check the size: a raw `system` image must be ≤ 3,397,386,240 B and a raw
`vendor` image ≤ 503,316,480 B.

## 2. Back up first

The device tree backup is optional; the identity partitions are not.

```powershell
pwsh -File scripts/backup-device.ps1 -Serial <serial> -BackupRoot D:\j8-backup
```

This dumps `boot`, `recovery`, `efs`, `persist`, `modemst1/2`, `fsg`, `fsc`,
`misc`, `config` and verifies SHA-256 of every file. It deliberately does not
dump `system`/`vendor` (size) or `userdata` (privacy) — which means **it is not
a full rollback set**. Say that out loud before flashing.

## 3. Install with TWRP (recommended)

This path needs no shell — it works with TWRP's touch UI plus plain `adb push`.

```bash
adb devices -l                       # confirm: <serial>  recovery
adb shell twrp reboot system         # only if you need to leave recovery first
```

1. Boot into TWRP:
   ```bash
   adb reboot recovery
   ```
   (With a broken power button, this is the only practical route — see
   [recovery.md](recovery.md).)
2. **Wipe → Format Data → yes.**
   Required: a locally signed build uses different signing keys than the
   previous ROM, and Android will not boot over a data partition signed with
   another key. This erases `/data` *and* internal storage (`/sdcard`).
3. Push the images **after** the wipe:
   ```bash
   adb push boot.img   /sdcard/boot.img
   adb push system-raw.img /sdcard/system.img
   adb push vendor-raw.img /sdcard/vendor.img
   ```
   If `/sdcard` is not mounted after Format Data, use `/cache/` or a microSD
   card instead — `/cache` survives Format Data.
4. Verify hashes on the device:
   ```bash
   adb shell sha256sum /sdcard/boot.img /sdcard/system.img /sdcard/vendor.img
   ```
5. In TWRP: **Install → Install Image**, then for each file select the
   matching partition:
   - `boot.img` → **Boot**
   - `system.img` → **System Image**
   - `vendor.img` → **Vendor Image**
6. Reboot to system. Collect logs immediately (see
   [validation.md](validation.md)).

## 4. Install with `dd` (shell-capable recovery or root adb)

Only when you have a **shell** — TWRP's ADB *sideload* mode has no shell.

```bash
adb shell 'ls -l /dev/block/by-name/'
adb shell 'blockdev --getsize64 /dev/block/by-name/boot'

adb push boot.img   /data/local/tmp/boot.img
adb push system.img /data/local/tmp/system.img
adb push vendor.img /data/local/tmp/vendor.img

adb shell 'sha256sum /data/local/tmp/boot.img /data/local/tmp/system.img /data/local/tmp/vendor.img'

adb shell 'dd if=/data/local/tmp/boot.img   of=/dev/block/by-name/boot   bs=1M'
adb shell 'dd if=/data/local/tmp/system.img of=/dev/block/by-name/system bs=1M'
adb shell 'dd if=/data/local/tmp/vendor.img of=/dev/block/by-name/vendor bs=1M'
adb shell 'sync'
```

Rules for this path:

- The image must be **raw**, not sparse.
- `dd` does not check that the image fits. Compare byte counts first.
- Write only `boot`, `system` and `vendor` in a normal install.
- Never write `persist`, `efs`, `modemst*`, `fsg`, `fsc`, `apnhlos`, `modem`
  or `recovery` unless you are deliberately restoring that exact backup.

## 5. Odin (last resort)

An Odin flash is only sensible when you have a fully working Samsung archive.
Constraints on this device:

- Knox is tripped (`ro.boot.warranty_bit=1`) and `ro.boot.flash.locked=1`;
  Odin may refuse signed-but-not-Samsung images or stall at `SetupConnection`.
- Do **not** enable *Re-Partition* or *NAND Erase*, and do not flash a PIT you
  did not generate from this device.
- A TWRP image packed as `AP` boots recovery *in place of* the boot partition;
  it is a recovery-rescue trick, not an install method, and it leaves Android
  unbootable until you restore a boot image.

If you must build a tar for Odin:

```bash
tar -c boot.img > boot.tar
# Odin wants a tar; the .md5 sidecar is optional
```

## 6. Rollback reality

Be honest with yourself about this before the first write:

- There is **no verified full rollback set** for this device in this project.
  Partition backups cover identity and boot/recovery, not `system`/`vendor`.
- If the new build does not boot, TWRP can still format/retry, but there is no
  preserved AICP/LineageOS system image to restore.
- With a broken power button, a device that cannot boot Android *and* cannot
  reach TWRP is a brick until a USB/Download-mode route is found.
- The safest order is: dump partitions → confirm TWRP boots → only then write.

## 7. First boot

Expect 5–15 minutes on first boot (dexopt). If it hangs:

```bash
adb devices
adb shell getprop sys.boot_completed
adb shell dmesg > dmesg.txt
adb logcat -d > logcat.txt
adb shell cat /proc/last_kmsg > last_kmsg.txt 2>/dev/null
```

A boot animation that never ends is a `system_server` or HAL problem, not an
`e2fsdroid` problem — the image either mounted or it did not. Check
`/proc/cmdline`, the SELinux mode (`getenforce`), and the first fatal exception
in `logcat`.

## 8. Uninstall / return to another ROM

Any other ROM needs the same treatment: TWRP → Format Data → flash that ROM's
images or OTA ZIP. Because every ROM signs with different keys, you cannot
downgrade in place without wiping data.
