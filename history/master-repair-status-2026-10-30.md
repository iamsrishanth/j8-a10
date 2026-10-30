<!-- Archived report. Host names, IP addresses, user names, paths, the device serial and MAC addresses have been genericised; wording and figures are otherwise unchanged. -->

# J8 OS — Master Repair Status

Updated: **2026-10-30 11:25 IST** (controller `controller`, Asia/Calcutta)
Device: SM-J810G / `j8y18lte` / serial `a7d4xxxx`
Build host: WSL2 Ubuntu 22.04 on `build-host` (10.0.0.2), reachable as `ssh ubu`
Source: `/home/builder/android/lineage-17.1`

## 0. Current state in one paragraph

**LineageOS 17.1 (Android 10) now builds, signs and installs, and the phone has booted it to a
working UI.** `m systemimage` and `m bacon` both succeed after a real root-cause fix to the device
SELinux configuration; the OTA is signed with the project release keys; TWRP is intact; data was
formatted; and the phone booted to `sys.boot_completed=1` with the LineageOS Setup Wizard on
screen, then the lock screen, with Wi-Fi, Bluetooth, RIL, sensors, camera service, storage and
charging all healthy. The phone was then deliberately rebooted to recovery to swap in the
SELinux-enforcing boot image — and at that point it **went dark and dropped off USB**, almost
certainly because its battery drained while the controller laptop slept for 5½ hours. It is
currently off/hung with no USB enumeration; the last verified good state is the permissive
Android 10 install described below.

## 1. What changed since the handover (headline)

| Area | Handover / agent reports said | Observed 2026-10-30 | Status |
|---|---|---|---|
| Phone connection | "no ADB device, no Samsung USB device" | USB composite present; ADB works after key re-install | **RESOLVED** |
| Recovery | TWRP 3.6.1 reachable | TWRP `3.6.1_9-goldfish07`, `/sbin/twrp` CLI, root shell | **VERIFIED** |
| Installed OS | "Android 11 C0 non-booting" | **Android 10** installed (`ro.build.version.release=10`) | **CORRECTED** |
| Boot partition | "restored C0 enforcing boot" | Was byte-identical to the Android 10 **permissive diagnostic** boot | **CORRECTED** |
| On-device backups | listed in handover | **gone** (`/sdcard` wiped by the earlier data format) | **LOST** |
| Build blocker | "e2fsdroid root-folder/file_context handling" | Root cause: device sepolicy dir never reached `BOARD_VENDOR_SEPOLICY_DIRS` | **FIXED** |
| OTA ZIP | "none produced" | `m bacon` → signed OTA produced and installed | **DONE** |
| Android 10 boots | never validated | **booted to UI**, `sys.boot_completed=1` | **DONE** |
| Verity/AVB | "verity/AVB issue" | No AVB anywhere; kernel has no AVB support; verity not configured | **REJECTED** |

## 2. Evidence ledger

| # | Observation | When / source | Fact or hypothesis | Needs recheck |
|---|---|---|---|---|
| E1 | `a7d4xxxx unauthorized` while `VID_18D1&PID_4EE2` enumerated | 10-30 04:26, adb + PnP | **Fact** | — |
| E2 | Cause: data format emptied `/data/misc/adb/adb_keys` | 04:45, after key install | **Fact** | — |
| E3 | ADB authorised via MTP-delivered key + TWRP terminal script | 04:45 | **Fact** | — |
| E4 | Partition sizes match BoardConfig (boot/recovery 33,554,432; system 3,397,386,240; vendor 503,316,480; userdata 57,415,806,976) | 04:50, `blockdev` on device | **Fact** | — |
| E5 | Pre-OTA system was a *flat* Android 10 image with rootfs-only labels | 04:52, mount + build.prop | **Fact** | superseded |
| E6 | Pre-OTA boot partition == `android10-images\boot.img` (permissive) | 04:54, sha256 of dump | **Fact** | — |
| E7 | Build failed at e2fsdroid `searching for label "/firmware"` with pristine sources | 04:34, `m systemimage` | **Fact** | fixed |
| E8 | Device sepolicy dir absent from `file_contexts.bin`; `$(LOCAL_PATH)` clobbered in the decisive parse pass (`system/sepolicy/sepolicy` instead of the device path) | 04:40–04:53, make warnings + ninja inputs | **Fact** | — |
| E9 | After fix: `/firmware`→firmware_file, `/omr`→omr_file, `/efs`→efs_file, `/config`→rootfs, `init_exec`, `logd_exec` in `system.img` | 05:03, `debugfs ea_list` | **Fact** | — |
| E10 | `m systemimage` OK; `m bacon` OK | 05:03, 05:05 | **Fact** | — |
| E11 | Signed OTA (release keys) `d105a267…fd91`, 543,446,412 B | 05:18 | **Fact** | — |
| E12 | OTA writes system, vendor, boot only; no recovery payload; device assert `j8y18lte` | 05:20, updater-script | **Fact** | — |
| E13 | Install via `/sbin/twrp install` → `script succeeded: result was [1.000000]` | 05:22 | **Fact** | — |
| E14 | Data formatted; ADB key re-seeded into fresh `/data` | 05:23 | **Fact** | — |
| E15 | First boot: `sys.boot_completed=1`, Setup Wizard resumed, 720×1480 | 05:25–05:27 | **Fact** | — |
| E16 | Wi-Fi enabled (MAC xx:xx:xx:xx:xx:xx), Bluetooth ON (xx:xx:xx:xx:xx:xx), RIL daemons running, 5 sensors, 2 cameras, battery 33 % charging | 05:27–05:35 | **Fact** | — |
| E17 | SIM absent → cellular service untestable | 05:27 | **Fact** | needs SIM |
| E18 | Runtime `setenforce 1` held for 5+ hours with UI/adb/Wi-Fi intact; only cosmetic denials (healthd sysfs, kernel hall_detect) | 05:30 → 11:17 | **Fact** | cold-boot enforcing still untested |
| E19 | Enforcing build artifact produced: `j8os-17.1-enforcing-20261030-0532-signed-ota.zip` `8f5669c8…8abc`; boot.img `fc23372e…a8e54` with **no** `androidboot.selinux=permissive` | 05:39 | **Fact** | — |
| E20 | After `adb reboot recovery`, phone stopped enumerating on USB and screen went black | 11:18–11:24 | **Fact** | likely battery drained during controller sleep |
| E21 | No `init`/`vold`/`servicemanager` denials in the permissive first boot (532 denials: 445 `flags_health_check`, 32 `zygote` stune, rest minor) → enforcing cold boot has no obvious blocker | 11:20 analysis of dmesg | **Fact (analysis)** | to confirm on device |

## 3. Backups captured today (first time efs/modem were ever dumped)

`C:\Users\user\staging\device-backups-20261030\`

| File | Bytes | SHA-256 |
|---|---:|---|
| boot-partition-current.img (permissive boot) | 33,554,432 | `d3068258ce373060d6ebd4d4a7be967a9c2df377534bf8d92e4883f28c5a886d` |
| efs.img | 16,777,216 | `355103dd5a693746166cc6129fb16f68dda76db87892fac45c47e57668c76214` |
| modemst1.img | 4,194,304 | `dec8b6f07f229d7eeabf1e650f55a594ac6e3c7bcac41c5b01f539125378277e` |
| modemst2.img | 4,194,304 | `402884e7976336d23621a53b78e7c603a16b8e9d69b66e4aa9a067274b6e0327` |
| fsg.img | 4,194,304 | `4e3e180a4f50bd3536ae90d8299fdd850be8f6f50107a34fca3e2ea1cdade33f` |
| persist.img | 33,554,432 | `d061870c25aaccc1156143b83d6a3f6d121d34c0fe3ea3ae9e774f8a7870531a` |
| misc.img | 1,048,576 | `f5f22730aa58099dade8760a2add1bdda5064f7b621c7151e145afcbdde12054` |
| config.img | 1,048,576 | `30e14955ebf1352266dc2ff8067e68104607e750abb9d3b36582b8af909fcb58` |
| console-ramoops.txt / pmsg | — | previous boot kernel console |

## 4. Artifacts

| Artifact | Location | SHA-256 |
|---|---|---|
| Permissive signed OTA (installed & booted) | `C:\Users\user\staging\artifacts\j8os-17.1-20261030-0507-signed-ota.zip`; also `/mnt/d/j8-os/artifacts/j8os-17.1-release/` | `d105a267a8979b2b634b02aa48f5094f898f6ed0537a35e0bf3be0817592fd91` |
| Enforcing signed OTA | `/mnt/d/j8-os/artifacts/j8os-17.1-release/j8os-17.1-enforcing-20261030-0532-signed-ota.zip` | `8f5669c8ae47368e986ae7f9610b94857ee005832ef7e935e6138376f3c98abc` |
| Enforcing boot.img (no permissive cmdline) | `C:\Users\user\staging\artifacts\enforcing-boot.img` | `fc23372e91e90281892cdd979e6affd34c0e3f19146f7fbaf4a6507f521a8e54` |
| TWRP recovery (unchanged, still installed) | `C:\Users\user\staging\recovery\twrp-recovery-a7d4xxxx.img` | `1b6538d566fd0a0c622ca2e78dedeb1b86a3dbf5f9199e9575ef67de0efd6e05` |
| Original pre-C0 boot partition | `C:\Users\user\j8-os-backups\a7d4xxxx\*\recovery\boot.img` | `7e9994ea36953456eb80ee6d32693f8ca779bb9ea92178b02aca53fae463c976` |

## 5. Exact next step

1. **Physical:** keep the phone on a powered USB port until it enumerates again (charging from a
   drained battery). When it comes back it will be either TWRP or the installed permissive
   Android 10.
2. **Then:** flash `enforcing-boot.img` from TWRP (`dd` to `/dev/block/by-name/boot`), reboot, and
   confirm `getenforce=Enforcing` from a cold boot — the last release-acceptance gate.
3. Everything else (build, sign, install, permissive validation) is complete and reproducible from
   the scripts in `<project>\scripts\remote\`.
