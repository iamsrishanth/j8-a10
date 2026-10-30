<!-- Archived report. Host names, IP addresses, user names, paths, the device serial and MAC addresses have been genericised; wording and figures are otherwise unchanged. -->

# J8 OS — Install and Rollback Plan (Android 10 / LineageOS 17.1)

Date: 2026-10-30 · Device: SM-J810G `j8y18lte` serial `a7d4xxxx` · Recovery: TWRP 3.6.1

## 1. What will be installed

| Item | Source | Notes |
|---|---|---|
| OTA ZIP (signed) | `/mnt/d/j8-os/artifacts/j8os-17.1-release/j8os-17.1-<stamp>-signed-ota.zip` | built by `m bacon`, re-signed with `/home/builder/secure/j8os-keys` |
| Contents | `boot.img`, `system.new.dat.br`, `vendor.new.dat.br`, `system/vendor.transfer.list`, `META-INF/...` | **no `recovery.img`** — TWRP in the recovery partition is untouched |
| Data | formatted by the operator in TWRP (already authorised by the task's "installation preparation and installation") | current data holds nothing of value (52 MB used, only `TWRP/`) |

Build identity of the artifact: `lineage_j8y18lte-userdebug` /
`lineage-17.1-20261029-UNOFFICIAL-j8y18lte` / Android 10 `QQ3A.200805.001` /
`arm` (32-bit) — vendor abilist `armeabi-v7a,armeabi`.

SELinux: **permissive** in this first (diagnostic) cycle — `BOARD_KERNEL_CMDLINE` contains
`androidboot.selinux=permissive`. A second, enforcing build follows acceptance.

## 2. Preconditions (all verified 2026-10-30)

- [x] Phone identity: `a7d4xxxx`, `ro.product.device=j8y18lte`, TWRP `3.6.1_9-goldfish07`.
- [x] Recovery partition intact: `sha256(/dev/block/by-name/recovery)` = `1b6538d5…6e05`.
- [x] Partition sizes measured live:
      boot/recovery 33,554,432 · system 3,397,386,240 · vendor 503,316,480 ·
      userdata 57,415,806,976 · omr 20,971,520 · efs 16,777,216 · config 1,048,576.
- [x] Off-device backups of boot, efs, modemst1/2, fsg, persist, misc, config, plus previous
      kernel console log (`device-backups-20261030\`), and pre-existing backup of the original
      pre-C0 boot image (`C:\Users\user\j8-os-backups\a7d4xxxx\*\recovery\boot.img`).
- [x] Transfer space: D: ≈ 156 GB free; `/sdcard` 52 GB free.
- [ ] Battery: 14 % at 04:50 IST and charging; the operator explicitly authorised proceeding
      regardless. **Accepted risk**, recorded here.

## 3. Reboot constraint (the real hazard)

The power button is dead. There is **no key-combo route to recovery or Download Mode**. The only
way out of a normal boot is software:

```
adb -s a7d4xxxx reboot recovery      # works while adbd is running
/sbin/twrp reboot recovery           # works inside TWRP
```

Therefore:
- If the new Android 10 boot reaches `adbd`, we can always return to TWRP (and the installed
  build has `androidboot.selinux=permissive`, which maximises the chance of adbd starting).
- If it hangs before `adbd`, the phone must be left until it can be recovered through a
  power cycle — i.e. **this is the one irreversible-risk step**, and it is why the boot image is
  being tested in permissive mode first.
- Evidence that userspace was able to reboot to recovery on the last Android boot
  (`console-ramoops`: `init: reboot: Restarting system with command 'recovery'` at t=1765 s)
  supports that adbd/userspace comes up on this build.

## 4. Write sequence

All commands run on the Windows controller with the phone in TWRP and ADB authorised.

### 4.1 Stage the OTA

```powershell
adb -s a7d4xxxx push <signed-ota.zip> /sdcard/
adb -s a7d4xxxx shell sha256sum /sdcard/<name>.zip   # must equal local hash
```

Stop if the hash differs (transfer failure) — do not flash.

### 4.2 Install

```powershell
adb -s a7d4xxxx shell "/sbin/twrp install /sdcard/<name>.zip"
```

The OTA writes **boot, system, vendor** only (verified from its `updater-script`); the recovery
partition is not touched.

Expected: TWRP reports "Installing zip file… script succeeded: result was [0.200000]".

Stop conditions: any write error, any `assert` failure, or a non-zero script result. **Do not
reboot after a failed write.**

### 4.3 Verify the write before rebooting

```powershell
adb -s a7d4xxxx shell sha256sum /dev/block/by-name/boot        # expect the new boot.img hash
adb -s a7d4xxxx shell blockdev --getsize64 /dev/block/by-name/system
```

Also re-check `sha256sum /dev/block/by-name/recovery` is still `1b6538d5…6e05`.

### 4.4 Format data

The current data is Android 10-incompatible leftovers from the Android 11 period (and the app
signing identities change with the release keys):

```powershell
adb -s a7d4xxxx shell "/sbin/twrp format data"
```

Preserve `/sdcard` first if anything matters — nothing does at the moment (only `TWRP/`,
`adb_keys`, `adbfix.sh`). Note the OTA already removed `/sdcard/adb_keys`? No — `/sdcard` is a
separate volume; formatting `/data` also wipes `/sdcard` (it lives in `/data/media`). Re-push
`adb_keys` afterwards so a future recovery session stays authorised (or use the same
`adbfix.sh` route).

### 4.5 Boot

```powershell
adb -s a7d4xxxx shell "/sbin/twrp reboot system"
```

Then: `adb wait-for-device`, and capture
```
adb shell getprop sys.boot_completed
adb shell getprop ro.build.version.release     # expect 10
adb shell getprop ro.build.fingerprint
adb logcat -d > logcat.txt
adb shell dmesg > dmesg.txt
```

## 5. Rollback

| Failure mode | Recovery action |
|---|---|
| New system boots but is broken | In TWRP, flash the previous boot (`device-backups-20261030\boot-partition-current.img`, sha256 `d3068258…`) — this is the Android 10 permissive boot that was on the device. |
| Boot hangs before adbd | No software route. Wait for power cycle; on next power-on the bootloader boots the `boot` partition again. To force recovery, the boot control block (`misc`) would have to be pre-set to `boot-recovery` **before** rebooting — see §6. |
| TWRP itself lost | Restore `twrp-recovery-a7d4xxxx.img` (sha256 `1b6538d5…6e05`) via `dd` from another recovery, or Odin with the `recovery.img`-named tar. |
| IMEI / modem damage | `efs.img`, `modemst1.img`, `modemst2.img`, `fsg.img` from `device-backups-20261030\` (dumped today, first time ever). |

There is **no complete known-good Android system image** anywhere off-device (stock or otherwise);
this is documented in the artifact review. Rollback of `system`/`vendor` is only possible to the
current Android 10 install — which is exactly what is being replaced — so the practical rollback
is "boot" only.

## 6. Optional safety measure before the first boot

Write the Android boot-control block in `misc` to request recovery on the next boot, so that a
power-cycle lands in TWRP instead of looping into the same broken Android:

```
printf 'boot-recovery' | dd of=/dev/block/by-name/misc bs=1 seek=0 conv=notrunc
```

This is a 12-byte, reversible write inside a *backed-up* partition (`misc.img` captured today).
It is **not** part of the default sequence; it is proposed only if the first boot fails and a
power cycle is the only remaining trigger.

## 7. Authorisation scope

- Granted by the task: installation of the Android 10 candidate and data formatting as part of
  it ("Complete available investigation, source fixes, builds, artifact verification, and
  installation preparation autonomously. Continue through authorized installation and validation
  when the phone is available.").
- Explicitly **out of scope and not performed**: re-partition, NAND erase, bootloader changes,
  PIT files, changing the recovery partition, GApps, Magisk/KernelSU/root, debloat, tuning.
