# Recovery and the button-less workflow

The reference device has a **broken power button**: no key combination reaches
recovery, Download mode or a forced reboot. Every procedure here is built
around that. It has been exercised on the device.

## 1. What is installed

| Item | Value |
|---|---|
| Recovery | TWRP **3.6.1_9-goldfish07** (Ayush Bisht), in the `recovery` partition |
| Recovery image hash | `1b6538d566fd0a0c622ca2e78dedeb1b86a3dbf5f9199e9575ef67de0efd6e05` (33,554,432 B) |
| Survives an OTA install | **yes** — the ROM's updater has no recovery payload, verified byte-identical after flashing |
| ADB | works in TWRP main UI; **sideload mode has no shell** |

## 2. ADB in recovery

| Mode | `adb` works? | Notes |
|---|---|---|
| TWRP main UI | yes, if authorised | host sees `<serial>  recovery` |
| ADB Sideload | `sideload` only | `adb shell` returns `error: closed` |
| Fastboot | no | this device uses Download mode, not fastboot |

### If ADB shows `unauthorized`

That is not a cable or driver problem: TWRP's adbd rejects the host key because
`/data/misc/adb/adb_keys` is missing or empty — typically after a data format.
Observed and fixed on this device like this:

1. Push the host public key (`%USERPROFILE%\.android\adbkey.pub`) to the phone's
   internal storage over **MTP** as `/sdcard/adb_keys`.
2. Push a small script as `/sdcard/adbfix.sh`:

   ```sh
   #!/system/bin/sh
   mkdir -p /data/misc/adb
   cp /sdcard/adb_keys /data/misc/adb/adb_keys
   chown 1000:2000 /data/misc/adb/adb_keys
   chmod 0640 /data/misc/adb/adb_keys
   ```

3. On the phone: **TWRP → Advanced → Terminal**, run `sh /sdcard/adbfix.sh`, then
   **Reboot → Recovery** (no power button involved).
4. `adb devices -l` should now show `<serial>  recovery`.

Remember: formatting `/data` (which includes `/sdcard`) deletes the key again.

## 3. The `twrp` CLI

TWRP 3.6.1 on this device exposes a command-line tool that makes recovery fully
scriptable:

```bash
adb shell /sbin/twrp
#   install <zip>        wipe <partition>      format data
#   backup | restore     remountrw             fixperms
#   mount | unmount <path>
#   reboot [recovery|system|download|bootloader|poweroff|edl]
```

Verified commands:

```bash
adb shell "/sbin/twrp install /sdcard/j8os-17.1-*.zip"   # script succeeded: result was [1.000000]
adb shell "/sbin/twrp format data"
adb shell "/sbin/twrp reboot system"                     # reliable
adb shell "/sbin/twrp reboot recovery"
```

Plain `adb reboot` / `adb shell reboot` from recovery did **not** reliably take
effect; use `/sbin/twrp reboot …`.

## 4. Keeping a recovery route alive

- Keep TWRP's own image (`twrp-recovery-<serial>.img`, hash above) off-device.
- Keep a **boot image that reaches adbd** as your rollback. This is the real
  safety net on a power-button-less device: if Android boots far enough for
  `adb`, you can always get back to TWRP.
- Before flashing an unproven boot image, consider pre-setting the boot-control
  block so a power cycle lands in recovery:

  ```bash
  printf 'boot-recovery' | dd of=/dev/block/by-name/misc bs=1 seek=0 conv=notrunc
  ```

  `misc` is 1 MB, backed up by `scripts/backup-device.ps1`, and the change is
  12 bytes and reversible.

## 5. Battery: the failure mode that actually bit

The device booted fine, was left idle for ~5½ hours while the host slept, and
then **powered off during a reboot to recovery** and stopped enumerating on
USB. Nothing was being written; the battery was simply empty.

Rules that follow from that:

- Keep the phone on a **powered** USB port between sessions, not on a sleeping
  laptop's port.
- Check `dumpsys battery` before rebooting into recovery for a flash.
- Do not start a flash below ~40 %.
- If it goes dark: leave it charging and poll `adb devices` /
  `Get-PnpDevice` for `VID_04E8` / `VID_18D1`. It will come back.

## 6. The "TWRP on boot" rescue (last resort, untested here)

If Android will not boot and TWRP is unreachable, the remaining lever is
Download mode + Odin: pack a known-good TWRP image as an Odin `AP` tar so the
phone boots *into TWRP* instead of Android, fix what you need, then write a
valid `boot.img` back.

Caveats, stated because they matter:

- It overwrites the Android boot image.
- Odin has **never** been exercised successfully on this unit; a
  `SetupConnection` stall was reported historically, and the phone has not been
  observed in Download mode since.
- Download mode requires a key combination this device cannot perform.

So: expect it to be theoretical, not a plan.

## 7. Off-device backups

`scripts/backup-device.ps1` dumps and verifies each partition. Priority order:

1. `efs`, `persist`, `modemst1`, `modemst2`, `fsg`, `fsc` — identity,
   calibration, radio. Never restored casually.
2. `boot`, `recovery` — gets you back to a known state.
3. `system`, `vendor` — the ROM itself; large.
4. `userdata` — personal data; prefer per-app backups and `adb pull /sdcard`.

A dump is only as good as its verification: the script compares size and
SHA-256 against the device for every file. Check them yourself too.

## 8. Physical reality check

With no power button and no working Download mode, a phone that cannot reach
`adbd` or TWRP is a brick until the battery/button is serviced. Plan every
write so that the image you flash is one that reaches `adbd`, and keep the last
known-good boot image on hand.
