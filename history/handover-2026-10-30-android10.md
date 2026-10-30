<!-- Archived report. Host names, IP addresses, user names, paths, the device serial and MAC addresses have been genericised; wording and figures are otherwise unchanged. -->

# J8 OS Handover — 2026-10-30

Supersedes `HANDOVER-2026-10-26.md` for the Android 10 work item. History is preserved in that
file and in `HANDOVER.md`; the current Android 10 scope supersedes all Android 11/12 plans.

## 1. Snapshot

- Device: Samsung Galaxy J8, **SM-J810G / j8y18lte**, serial `a7d4xxxx`.
- Controller: Windows laptop `controller` (Windows 10.0.26300).
- Build host: **not this laptop** — WSL2 Ubuntu 22.04 on `build-host` (Tailscale
  `10.0.0.2`), reachable from the controller as **`ssh ubu`**.
  `/home/builder/android/lineage-17.1`, ≈824 GB free.
- Recovery: TWRP **3.6.1_9-goldfish07(Ayush Bisht)** in the recovery partition, ADB authorised.
  Recovery partition hash `1b6538d5…6e05` (unchanged through the whole session).
- Installed system at last check: **LineageOS 17.1 / Android 10**, permissive diagnostic boot,
  booted to a working UI.
- Phone state at handover: **off / not enumerating on USB** after a reboot; battery likely drained
  while the controller laptop slept ~5½ h. See §7.

## 2. What works (verified on device)

- Build → sign → OTA → TWRP install → boot, end to end.
- Android 10 `/ API 29`, `lineage-17.1-20261029-UNOFFICIAL-j8y18lte`, `armeabi-v7a`.
- `sys.boot_completed=1`, Setup Wizard then lock screen rendered at 720×1480.
- Wi-Fi on (MAC `xx:xx:xx:xx:xx:xx`), Bluetooth on (`xx:xx:xx:xx:xx:xx`), 5 sensors, 2 cameras,
  Samsung RIL v4.0 daemons running, battery/charging reporting, storage.
- SELinux enforcing survives at runtime (5+ h) with only cosmetic denials.

Not yet verified: touch panel (human tap), audio out, camera capture, Wi-Fi association,
SIM/cellular (no SIM fitted), enforcing **cold** boot.

## 3. Build fix (the blocker that stopped the previous agents)

`m systemimage` died in `e2fsdroid` at `searching for label "/firmware"`. Not a root-folder or
`.keep` problem — **the device's SELinux policy directory was never compiled into the image**.

- `device/samsung/j8y18lte/BoardConfig.mk:235` used `BOARD_SEPOLICY_DIRS += $(LOCAL_PATH)/sepolicy`.
  In the decisive parse pass `$(LOCAL_PATH)` expands to `system/sepolicy`, so the entry became
  `system/sepolicy/sepolicy` and the real device dir never reached `BOARD_VENDOR_SEPOLICY_DIRS`
  (which Android 10's `build_vendor_policy()` actually reads).
- Fix: use the literal path, keep it **last** in the list so qcom policy file ordering still puts
  type declarations before device policy uses.
- Second fix: `device/samsung/j8y18lte/sepolicy/property_contexts` had no trailing newline, which
  corrupted the merged vendor property contexts (`…vendor_default_prop:s0# Aux camera blacklist…`).

Diff is 2 files / 3 lines (plus a trailing newline in `BoardConfig.mk`). Details:
`reports/ANDROID10-BUILD-FIX.md`.

## 4. Artifacts

| Artifact | Path | SHA-256 |
|---|---|---|
| Permissive signed OTA (installed, booted) | `C:\Users\user\staging\artifacts\j8os-17.1-20261030-0507-signed-ota.zip` | `d105a267a8979b2b634b02aa48f5094f898f6ed0537a35e0bf3be0817592fd91` |
| Enforcing signed OTA | `/mnt/d/j8-os/artifacts/j8os-17.1-release/j8os-17.1-enforcing-20261030-0532-signed-ota.zip` | `8f5669c8ae47368e986ae7f9610b94857ee005832ef7e935e6138376f3c98abc` |
| Enforcing boot.img | `C:\Users\user\staging\artifacts\enforcing-boot.img` | `fc23372e91e90281892cdd979e6affd34c0e3f19146f7fbaf4a6507f521a8e54` |
| Permissive diagnostic boot (rollback) | `C:\Users\user\staging\device-backups-20261030\boot-partition-current.img` | `d3068258ce373060d6ebd4d4a7be967a9c2df377534bf8d92e4883f28c5a886d` |
| TWRP recovery image | `C:\Users\user\staging\recovery\twrp-recovery-a7d4xxxx.img` | `1b6538d566fd0a0c622ca2e78dedeb1b86a3dbf5f9199e9575ef67de0efd6e05` |
| Modem/NV backups (new) | `C:\Users\user\staging\device-backups-20261030\` | see `MASTER-REPAIR-STATUS.md` §3 |

Signing keys: `/home/builder/secure/j8os-keys` (private keys stay on the build host; not in any
repo, log or image).

## 5. Reusable scripts (this session, on the controller)

`<project>\scripts\remote\`
- `build-enforcing.sh` — patches cmdline, `m bacon`, signs target-files + OTA with release keys.
- `sign171.sh` — sign-only variant.
- `fix5.sh` — the exact BoardConfig/`property_contexts` fix.
- `verify2.sh` / `device-survey.sh` / `validate.sh` — device verification helpers.

## 6. Recovery route without a power button

- In TWRP: `/sbin/twrp reboot {recovery|system|download|bootloader|poweroff|edl}`.
- In Android: `adb -s a7d4xxxx reboot recovery`.
- **There is no hardware key combination available** (power button dead), so never boot an image
  that cannot reach `adbd` or TWRP.
- Odin/Download Mode remains a theoretical fallback only; it has never been exercised in this
  session and the phone has never been observed in Download Mode since.

## 7. Current blocker and exact next step

The phone went dark immediately after `adb reboot recovery` at 11:18 IST and stopped enumerating on
USB. Working hypothesis: battery drained while the controller laptop slept 05:40–11:00, so the
reboot exhausted it. Nothing suggests a flash problem — no write was in flight (the enforcing boot
image had not been written yet).

Next action (physical): keep the phone on a **powered** USB port until Windows enumerates it again
(watch `Get-PnpDevice` for `VID_04E8`/`VID_18D1`, or `adb devices`). When it returns:

1. If it boots the installed Android 10 (permissive): `adb reboot recovery`.
2. In TWRP: push `enforcing-boot.img`, verify sha256 `fc23372e…a8e54`,
   `dd if=/sdcard/enforcing-boot.img of=/dev/block/by-name/boot bs=4096`, verify readback,
   `/sbin/twrp reboot system`.
3. Confirm `getenforce` = `Enforcing` on a cold boot and re-run the validation checks.

To prevent a repeat: keep the controller awake (or use a wall charger between device sessions).
