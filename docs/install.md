# Installing the build

This procedure has been executed on hardware: the OTA was installed through
TWRP, data was formatted, and Android 10 booted to a working UI. The steps and
outputs below are the ones actually observed.

## 1. Prerequisites

| Requirement | Detail |
|---|---|
| Bootloader | Unlocked (`OEM LOCK: OFF` in Download mode) |
| Recovery | TWRP 3.6.1 for `j8y18lte`, ADB authorised |
| Host tools | `adb` (platform-tools), `sha256sum` |
| Battery | **Charged.** The reference device has a broken power button and was lost for hours because it drained mid-session |
| Files | The signed OTA ZIP (`j8os-17.1-*-signed-ota.zip`) |

Verify what you are about to flash:

```bash
sha256sum j8os-17.1-enforcing-20261030-0532-signed-ota.zip
# 8f5669c8ae47368e986ae7f9610b94857ee005832ef7e935e6138376f3c98abc
unzip -p j8os-17.1-*.zip META-INF/com/android/metadata
```

`pre-device=j8y18lte`, `post-sdk-level=29`, `ota-type=BLOCK`, and
`post-build=…:userdebug/release-keys` are the strings to look for.

## 2. Back up first

```powershell
pwsh -File scripts/backup-device.ps1 -Serial <serial> -BackupRoot D:\j8-backup
```

Dumps and verifies `boot`, `recovery`, `efs`, `persist`, `modemst1/2`, `fsg`,
`fsc`, `misc`, `config`. It does **not** cover `system`/`vendor`/`userdata`, so
it is not a full rollback set — say that out loud before flashing.

## 3. Get into TWRP

With a broken power button, recovery is a software-only destination:

```bash
adb devices -l                 # confirm the device is online
adb reboot recovery            # from a booted Android
```

If Android will not boot, you are dependent on whatever recovery route you
prepared beforehand — see [recovery.md](recovery.md).

## 4. Format data

This is mandatory: the ROM is signed with different keys than whatever was
installed, and Android will not boot over a `/data` written by another key.

```bash
adb shell "/sbin/twrp format data"
```

**This also erases internal storage (`/sdcard`)** — it lives in `/data/media`.
That means the controller's ADB key in `/data/misc/adb/adb_keys` is gone after
the wipe; re-seed it before the next recovery session (see
[recovery.md §2](recovery.md#2-adb-in-recovery)).

## 5. Install the OTA

There are two ways; both were tested.

**A. TWRP's own installer (used for the validated build):**

```bash
adb push j8os-17.1-*.zip /sdcard/
adb shell sha256sum /sdcard/j8os-17.1-*.zip      # must match the host hash
adb shell "/sbin/twrp install /sdcard/j8os-17.1-*.zip"
```

Expected output ends with:

```text
script succeeded: result was [1.000000]
```

**B. ADB sideload (no shell needed):**

```bash
# TWRP: Advanced -> ADB Sideload (swipe to start)
adb devices -l                  # <serial>  sideload
adb sideload j8os-17.1-*.zip
# wait for: Total xfer: 1.00x
```

Stop on any write error or non-zero script result. **Do not reboot after a
failed write.**

## 6. Verify before rebooting

```bash
adb shell sha256sum /dev/block/by-name/boot     # expect the OTA's boot.img hash
adb shell sha256sum /dev/block/by-name/recovery # expect the TWRP hash, unchanged
adb shell blockdev --getsize64 /dev/block/by-name/system
```

What the OTA touches, from its own `updater-script`:

```text
block_image_update("/dev/block/bootdevice/by-name/system", …)
block_image_update("/dev/block/bootdevice/by-name/vendor", …)
package_extract_file("boot.img", "/dev/block/bootdevice/by-name/boot");
```

No recovery payload — **TWRP survives**, and it was verified byte-identical
after the install.

## 7. Boot

```bash
adb shell "/sbin/twrp reboot system"
adb wait-for-device
adb shell getprop sys.boot_completed     # 1
adb shell getprop ro.build.version.release   # 10
```

First boot takes a few minutes (dexopt). Then run
[`scripts/collect-bootlogs.sh`](../scripts/collect-bootlogs.sh) or the checks in
[validation.md](validation.md).

## 8. Optional: make a power-cycle land in recovery

If you are about to boot an **unproven** boot image on a device with no working
power button, you can pre-set the boot-control block so the next boot lands in
recovery instead of looping:

```bash
printf 'boot-recovery' | dd of=/dev/block/by-name/misc bs=1 seek=0 conv=notrunc
```

`misc` is backed up by `scripts/backup-device.ps1`, and the write is 12 bytes
and reversible. It is not part of the normal sequence — only use it when a
failed boot would otherwise leave you with no software route.

## 9. Rollback

| Failure mode | Recovery action |
|---|---|
| Boots but behaves badly | In TWRP, restore the previous `boot` image from your backup |
| Hangs before adbd | No software route; wait for a power cycle (or pre-set `misc` as in §8) |
| TWRP lost | Restore the TWRP image by `dd` from another recovery, or Odin |
| IMEI/modem damage | Restore `efs`/`modemst1`/`modemst2`/`fsg` from the verified backup |

There is no complete known-good `system`/`vendor` image off-device, so
"rollback" in practice means the boot image — not the ROM.

## 10. Going back to another ROM

TWRP → format data → flash that ROM. Different signing keys make an in-place
switch impossible without wiping data.
