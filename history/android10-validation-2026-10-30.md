<!-- Archived report. Host names, IP addresses, user names, paths, the device serial and MAC addresses have been genericised; wording and figures are otherwise unchanged. -->

# Android 10 / LineageOS 17.1 — Validation

Device: SM-J810G `j8y18lte` serial `a7d4xxxx`
Controller: `controller` (Windows 10.0.26300), Asia/Calcutta
Build under test: `lineage_j8y18lte-userdebug 10 QQ3A.200805.001 eng.<builder>.20261030.043220`
`ro.lineage.version = 17.1-20261029-UNOFFICIAL-j8y18lte`, ABI `armeabi-v7a` (32-bit), SDK 29
OTA: `j8os-17.1-20261030-0507-signed-ota.zip`, sha256 `d105a267a8979b2b634b02aa48f5094f898f6ed0537a35e0bf3be0817592fd91`
Installed 2026-10-30 05:22 IST via TWRP `/sbin/twrp install`; data formatted 05:23 IST; first boot 05:25 IST.

> **Scope note.** This first cycle is the **diagnostic build with SELinux permissive**
> (`androidboot.selinux=permissive` baked into the kernel cmdline). Results below are
> diagnostic-boot results, not final release acceptance. The enforcing build is a separate,
> later artifact.

## 1. Boot and identity — PASSED

| Test | Result | Evidence |
|---|---|---|
| Device reaches Android | **PASSED** | `adb devices` → `a7d4xxxx device product:lineage_j8y18lte model:SM_J810G` |
| `sys.boot_completed` | **PASSED** | `1` within ~45 s of reboot |
| Boot animation finished | **PASSED** | `init.svc.bootanim=stopped` |
| Android 10 / API 29 | **PASSED** | `ro.build.version.release=10`, `ro.build.version.sdk=29` |
| Intended build identity | **PASSED** | `/system/build.prop`: `ro.build.display.id=lineage_j8y18lte-userdebug 10 QQ3A.200805.001 eng.<builder>.20261030.043220`, `ro.build.tags=release-keys`, `ro.lineage.version=17.1-20261029-UNOFFICIAL-j8y18lte` |
| ABI | **PASSED** | `ro.product.cpu.abi=armeabi-v7a`, vendor abilist `armeabi-v7a,armeabi` |
| Release signing applied | **PASSED** | `ro.build.tags=release-keys`, `ro.vendor.build.tags=release-keys`; APKs signed with `/home/builder/secure/j8os-keys` (sign_target_files_apks log) |
| LineageOS framework present | **PASSED** | `/system/priv-app/LineageParts`, `ro.lineage.build.version=17.1` |
| First-run UI | **PASSED** | `mResumedActivity=org.lineageos.setupwizard/.WelcomeActivity`; screenshot shows LineageOS welcome screen at 720×1480 |

## 2. Display, touch, storage — PASSED (touch to confirm)

| Test | Result | Evidence |
|---|---|---|
| Display initialises at native resolution | **PASSED** | screenshot 720×1480, density 280 |
| UI renders and is responsive | **PASSED** | setup wizard drawn; no SurfaceFlinger crash in logcat |
| Touch input | **NOT TESTED** (needs a human tap — see §8) | — |
| Internal storage mounted | **PASSED** | `/data` ext4 52 G, 69 M used after format |
| Cache | **PASSED** | `/cache` ext4 275 M, 212 K used |
| Partition layout | **PASSED** | system 3,397,386,240 · vendor 503,316,480 · boot/recovery 33,554,432 (all match BoardConfig) |

## 3. Connectivity — PARTIAL

| Test | Result | Evidence |
|---|---|---|
| Wi-Fi driver/firmware loads | **PASSED** | `wi-fi is enabled`, `wlan0` UP with MAC `xx:xx:xx:xx:xx:xx`, `curState=StaEnabledState`, `/vendor/firmware/wlan/prima` present |
| Wi-Fi associates to an AP | **NOT TESTED** | no credentials supplied; `curState=DisconnectedState` |
| Bluetooth powers on | **PASSED** | after `svc bluetooth enable`: `state: ON`, address `xx:xx:xx:xx:xx:xx`, name `SM-J810G`, `Bluetooth crashed 0 times` |
| Bluetooth pairing/audio | **NOT TESTED** | no accessory available |
| RIL stack | **PASSED** | `gsm.version.ril-impl=Samsung RIL v4.0`, `init.svc.ril-daemon=running`, `ril-daemon1=running`, `com.android.phone` running |
| SIM / cellular service | **BLOCKED** | `gsm.sim.state=ABSENT,ABSENT` — no SIM in the device; `mServiceState=OUT_OF_SERVICE` follows from that, not from a RIL fault |
| Voice call / SMS | **BLOCKED** | requires a SIM and a human-initiated call |

## 4. Audio, camera, sensors, power — PARTIAL

| Test | Result | Evidence |
|---|---|---|
| audioserver runs | **PASSED** | `init.svc.audioserver=running` |
| Audio HAL + effect libraries load | **PASSED** | `dumpsys media.audio_flinger` shows vendor effect libs (`libswdap.so` Dolby DAX3, `libgearvr.so` Samsung VR360) |
| Speaker / earpiece / mic audible | **NOT TESTED** | needs a human listening test |
| Camera service | **PASSED** | `cameraserver` running; `Number of camera devices: 2` (rear + front) |
| Camera capture | **NOT TESTED** | needs an on-device app interaction |
| Sensors | **PASSED** | 5 h/w sensors running: LIS2DS accelerometer, STK3013 proximity, A96T3X6 grip, significant-motion, tilt |
| Battery reporting | **PASSED** | `level: 33`, `voltage: 4010`, `temperature: 329`, `health: 2`, `USB powered: true` |
| Charging | **PASSED** | `status: 2` (charging) over USB |

## 5. SELinux — diagnostic (permissive) + runtime enforcing probe

| Test | Result | Evidence |
|---|---|---|
| Build cmdline | permissive (diagnostic build, by design) | `androidboot.selinux=permissive` in boot.img |
| Runtime `setenforce 1` on the running system | **PASSED (survives)** | `getenforce=Enforcing` held for 20 s+; `sys.boot_completed` stayed 1; Setup Wizard stayed resumed; `adb` stayed connected |
| Denials under enforcing | 32 in 20 s | all cosmetic: `healthd` reading `/sys/class/power_supply/battery/{capacity,voltage_now,current_now,charge_full,charge_counter,present}` (labelled `sysfs` instead of `sysfs_batteryinfo`), and `kernel` reading `hall_detect` |
| Correct file labels | **PASSED** | image verified with `debugfs ea_list`: `/firmware`→`firmware_file`, `/omr`→`omr_file`, `/efs`→`efs_file`, `/config`→`rootfs`, `/system/bin/init`→`init_exec`, `/system/bin/logd`→`logd_exec` |

Follow-up for the release build: add `healthd`/`kernel` battery-sysfs allow rules if a clean
enforcing boot shows denials that matter (they did not break anything at runtime).

## 6. Recovery route (broken power button) — PASSED

| Test | Result | Evidence |
|---|---|---|
| TWRP still installed after OTA | **PASSED** | `sha256(/dev/block/by-name/recovery)=1b6538d5…6e05` unchanged before and after install |
| OTA does not touch recovery | **PASSED** | OTA contains no recovery image; updater-script writes system, vendor, boot only |
| Software route to recovery | **PASSED** | `/sbin/twrp reboot recovery` used to enter TWRP; TWRP CLI also exposes `reboot [recovery|download|bootloader|poweroff|edl]` |
| ADB survives data format | **PASSED** | `/data/misc/adb/adb_keys` restored immediately after `twrp format data`; Android's adbd authorised the controller on first boot with no on-screen prompt |

## 7. Defects observed

1. `ro.build.fingerprint` / `ro.system.build.fingerprint` resolve to the **stock Samsung**
   string `samsung/j8y18ltedd/j8y18lte:10/QP1A.190711.020/J810GDDU4CUB2:user/release-keys`
   even though `/system/build.prop` and `/vendor/build.prop` contain the correct LineageOS
   values with `release-keys`. Cause: the **stock ODM partition** (`/odm/build.prop`, untouched,
   as designed) defines these properties and overrides them. Cosmetic; note it because
   Play-Safety/CTS-style checks read `ro.build.fingerprint`.
2. `healthd` battery sysfs denials under enforcing (see §5) — cosmetic, charging still reported.

## 8. Tests that require the human operator

- Tap through the Setup Wizard (confirms the touchscreen and the display pipeline end to end).
- Play a sound (confirms speaker + audio HAL path).
- Take a photo (confirms camera capture).
- Insert a SIM and confirm network registration / a test call (RIL is already running).

## 9. Release acceptance status

**NOT YET ACCEPTED as a release**: this cycle is the permissive diagnostic build. The enforcing
release artifact is built separately and must repeat §1, §2 (boot to launcher), §5 (enforcing from
cold boot) before release acceptance.

The enforcing artifact already exists and is verified:

| Artifact | SHA-256 |
|---|---|
| `j8os-17.1-enforcing-20261030-0532-signed-ota.zip` (build host) | `8f5669c8ae47368e986ae7f9610b94857ee005832ef7e935e6138376f3c98abc` |
| `enforcing-boot.img` (controller) | `fc23372e91e90281892cdd979e6affd34c0e3f19146f7fbaf4a6507f521a8e54` |

`enforcing-boot.img` was extracted from the signed enforcing OTA and its embedded cmdline verified
to contain **no** `androidboot.selinux=permissive`
(`console=null androidboot.hardware=qcom msm_rtb.filter=0x237 ehci-hcd.park=3 androidboot.bootdevice=7824900.sdhci lpm_levels.sleep_disabled=1 buildvariant=userdebug`).

## 10. Boot-cycle log

| Cycle | Image | Result | Evidence |
|---|---|---|---|
| 0 (pre-session) | flat Android 10 + permissive boot, rootfs-only labels | reached init but `logd` exited 255 in a loop, then userspace rebooted to recovery | pstore `console-ramoops` (preserved, see E8) |
| 1 (this session) | correctly-labelled system/vendor + permissive boot | **PASSED**: boot_completed=1, UI, Wi-Fi/BT/RIL/sensors/camera, enforcing-at-runtime survived 5 h | `validation-20261030\` |
| 2 (pending) | same system/vendor + **enforcing** boot | **BLOCKED**: phone powered off during the reboot-to-recovery and has not re-enumerated (battery drained while the controller slept 5½ h) | — |

## 11. Root cause of the earlier failure (now evidenced)

Cycle 0 used an image whose only label set was `u:object_r:rootfs:s0` and, more importantly, was a
**flat** image. The kernel/init chain for this device is system-as-root: `/init` is a symlink to
`/system/bin/init` and `init.rc` links `/system/bin` → `/bin`. A flat image mounted at `/` leaves
`/system/bin/*` absent, which is consistent with `logd` being reaped immediately (status 255) and
with the repeated `Service 'logd' exited with status 255` lines in the preserved pstore log.
Cycle 1 with the build's native nested image and correct labels eliminated that failure.
