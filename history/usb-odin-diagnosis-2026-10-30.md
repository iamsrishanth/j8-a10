<!-- Archived report. Host names, IP addresses, user names, paths, the device serial and MAC addresses have been genericised; wording and figures are otherwise unchanged. -->

# J8 OS — USB / Odin / Recovery Diagnosis

Updated: 2026-10-30 (controller `controller`, Windows 10.0.26300, Asia/Calcutta)
Device: SM-J810G / j8y18lte / serial `a7d4xxxx`

## Bottom line

**Odin and Download Mode were never needed, and the earlier "no USB device" reports are obsolete.**
The phone is physically connected, enumerates normally, and TWRP 3.6.1 is running with an
authorised ADB shell as of 2026-10-30 04:45 IST. This is evidence-branch **D** from the task
definition ("TWRP ADB already works — proceed without an unnecessary Odin flash").

## 1. Enumeration snapshot (2026-10-30 04:26–04:45 IST)

| Item | Value |
|---|---|
| ADB binary | `C:\platform-tools\adb.exe`, 1.0.41 (37.0.1-15733141) |
| USB composite | `USB\VID_18D1&PID_4EE2\a7d4xxxx` — device string `j8y18lte`, `REV_0318` |
| Interface 00 | MTP, `WUDFWpdMtp`, driver `Microsoft 10.0.26100.9711`, ProblemCode 0 |
| Interface 01 | `Android Composite ADB Interface`, `ff/42/01`, `WinUSB 7.0.0.4` (Google, Inc.), ProblemCode 0 |
| COM ports | Only Bluetooth serial ports (COM3–COM8). No Samsung modem/odin COM port present because the phone is not in Download Mode. |

Interpretation: this is the normal AOSP "MTP + ADB" composite, i.e. a *booted* Android-family
system (here: TWRP). WinUSB is bound to the ADB interface by the Google USB driver, which is
correct for adb and does **not** indicate a Zadig/Heimdall/libusb takeover. No Kies/Smart Switch
process was running.

## 2. ADB authorisation (root cause and fix)

Initial state: `adb devices -l` showed `a7d4xxxx unauthorized`.

Cause: the data partition was formatted during the earlier work, so `/data/misc/adb/adb_keys`
was empty and TWRP's adbd (secure mode) rejected the controller key. This is *not* a cable,
port, driver, or phone-mode problem.

Fix (2026-10-30 04:36–04:45 IST), without a working power button:

1. Controller public key (`%USERPROFILE%\.android\adbkey.pub`, 711 bytes) copied to the phone's
   internal storage over MTP as `/sdcard/adb_keys`; read-back SHA-256 matched the source file.
2. `/sdcard/adbfix.sh` copied over MTP (929 bytes, read-back hash matched). It does
   `mkdir -p /data/misc/adb`, copies the key, sets owner `1000:2000`, mode `0640`.
3. Operator ran, in TWRP → Advanced → Terminal: `sh /sdcard/adbfix.sh`, then
   Reboot → Recovery (no power button involved).
4. Result:
   - `a7d4xxxx  recovery  product:lineage_j8y18lte model:j8y18lte device:j8y18lte`
   - `ro.twrp.version = 3.6.1_9-goldfish07(Ayush Bisht)`
   - `/data/misc/adb/adb_keys` = 711 bytes, `system:shell`, mode 0640.
   - shell probe: `getprop ro.hardware` = `qcom`, `ro.board.platform` = `msm8953`,
     `ro.bootloader` = `J810GDDU6CWH2`.

## 3. Odin status

Odin was **not** run in this session. The historical "SetupConnection" stall and the user-supplied
Download Mode screenshot (`OEM LOCK: OFF, FRP LOCK: OFF, KG STATUS: Checking,
CURRENT BINARY: Custom, SECURE DOWNLOAD: ENABLE`) are recorded here as supplied evidence only;
they were not re-observed, and the current state makes Odin unnecessary.

Odin becomes relevant only if the bootloader itself must be used (e.g. boot image rejected by ABL
and no recovery route remains). Nothing in the current evidence requires it.

Historical tool paths were **not** verified in this session because they were not needed:
- `C:\platform-tools\adb.exe` — verified present and used.
- `C:\Users\user\staging\tools\Odin3_v3.14.4\...` — not exercised.

## 4. Reboot route with a broken power button (verified capability)

TWRP exposes a CLI that does not need the power button:

```
/sbin/twrp  — TWRP openrecoveryscript command line tool, version 3.6.1_9-goldfish07
  install /path/to/update.zip
  wipe <partition>            format data
  backup|restore ...          remountrw   fixperms   mount|unmount <path>
  reboot [recovery|poweroff|bootloader|download|edl]
```

Also available: `adb -s a7d4xxxx reboot {recovery|download}` (adbd is up and authorised while in
TWRP), and TWRP's GUI Reboot menu.

Limitation that still governs device writes: **once the phone leaves recovery for a normal boot,
the only way back is a software reboot from the running system.** There is no hardware recovery
key combination available with a dead power button, and Download Mode cannot be entered by key
combo either. Therefore any boot image written to `boot` must be one that reaches `adbd`.

## 5. Unresolved / to re-check

- Whether a *second* Windows host or cable would change anything: unknown and not required —
  the current enumeration is healthy and adb works at 35 MB/s.
- Download Mode behaviour under Odin (SetupConnection stall) remains unexplained by direct
  observation. It is out of scope unless recovery becomes unavailable.
