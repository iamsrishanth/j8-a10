# Recovery and the button-less workflow

The reference device has a **broken power button**. That changes everything
about recovery: you cannot hold Volume Up + Power to enter TWRP, you cannot
force a reboot by holding buttons, and you cannot power the phone back on if it
shuts down completely. Every procedure in this repository is designed around
that constraint.

## 1. What works

| Action | Method |
|---|---|
| Enter recovery | `adb reboot recovery` from a booted Android |
| Reboot out of recovery | `adb shell twrp reboot system` (see below) |
| Reboot to bootloader/download | `adb reboot download` |
| Power off safely | avoid it — keep a bootable system or TWRP |
| Wipe data | TWRP UI (**Wipe → Format Data**) |
| Sideload an OTA | TWRP **Advanced → ADB Sideload**, then `adb sideload <zip>` |

### TWRP's own reboot command

On the reference unit, generic reboot commands were unreliable from recovery:

```bash
adb shell twrp reboot system      # worked
adb shell reboot system           # did not reliably leave recovery
adb reboot                        # did not reliably leave recovery
```

Use the `twrp` CLI when it exists; `reboot`/`reboot -p` from the recovery shell
did not always take effect.

## 2. ADB in recovery

| Mode | `adb` works? | Notes |
|---|---|---|
| TWRP main UI | yes, if authorized | host sees `<serial>  recovery` |
| ADB Sideload | yes, `sideload` only | **no shell**, `adb shell` returns `error: closed` |
| Fastboot | no | this device uses Download mode, not fastboot |

If the host shows `unauthorized`, the TWRP key is not in
`/data/misc/adb/adb_keys`. Accept the prompt on screen, or push your public key
into the recovery's key file while it is mounted. Do not blindly overwrite
`adb_keys` on a device whose data you care about.

## 3. Keeping a recovery route alive

The recovery partition is separate from the system. A normal Android image
build does **not** overwrite `recovery.img` — but if your install method writes
boot/system/vendor only, TWRP stays intact.

Recommended belt-and-braces:

1. Copy the TWRP image to the phone's `/cache` (survives Format Data, unlike
   `/sdcard`):
   ```bash
   adb push twrp-recovery-<serial>.img /cache/twrp-recovery.img
   ```
2. Keep a copy on the host, with its SHA-256 recorded.
3. Confirm it is the *same* image that is currently flashed (compare hashes),
   because a recovery image is not a data backup.

To restore TWRP if it ever gets overwritten:

```bash
adb push twrp-recovery.img /data/local/tmp/twrp.img   # from a booted system
adb shell 'dd if=/data/local/tmp/twrp.img of=/dev/block/by-name/recovery bs=1M'
adb shell 'sync'
```

This requires a booted system or a shell-capable recovery. Neither may be
available if you have just bricked the boot image — which is why the order
matters.

## 4. The "TWRP on boot" rescue (experimental, last resort)

If Android will not boot and TWRP is unreachable by any other route, the only
remaining lever is Download mode + Odin:

- Pack a **known-good TWRP image** as an Odin `AP` tar and flash it. It lands
  in the `boot` partition, so the phone boots *into TWRP* instead of Android.
- From that TWRP you can run `adb shell`, repair partitions, or restore a boot
  image.
- Afterwards you **must** write a valid `boot.img` back, or the phone will keep
  booting recovery.

Risks: this overwrites the Android boot image; if Odin stalls at
`SetupConnection` (which has been observed on this Knox-tripped unit) you gain
nothing and may lose the last working slot. Treat it as an experiment with a
written-down expected outcome, not a guaranteed instruction. The single-member
tar proves only what is in the archive — not that the phone will accept it.

## 5. Off-device backups

`scripts/backup-device.ps1` (PowerShell) and `scripts/backup-partitions.ps1`
do partition-level dumps over ADB with size and SHA-256 verification.

What to back up, in priority order:

1. `efs`, `persist`, `modemst1`, `modemst2`, `fsg`, `fsc` — identity,
   calibration, radio. **Never restored casually.**
2. `boot`, `recovery` — lets you get back to a known state.
3. `system`, `vendor` — only useful if you have space; these are the ROM.
4. `userdata` — personal data, privacy sensitive. Prefer a normal
   `adb pull /sdcard` plus per-app backups.

Everything above is only as good as its verification: compare hashes after
pulling.

## 6. If you lose the power button *and* the system

There is no software-only way to power a phone on. The realistic options, in
order of cost:

1. USB cable insertion can wake some Qualcomm devices from a powered-off state
   (not reliable, and not a documented behaviour — treat any success as luck).
2. Charge the battery externally, then use Download mode.
3. Repair the power button, or use a momentary-contact jumper on the button's
   pads.

Plan the install so that you never end up in that state: keep TWRP working,
keep a bootable boot image on hand, and do not erase the only working system
without a tested replacement.
