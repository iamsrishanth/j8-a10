# Validation — Android 10 on the Galaxy J8

Measured on hardware: **SM-J810G / `j8y18lte`**, 2026-10-30.
Build under test: `lineage_j8y18lte-userdebug 10 QQ3A.200805.001`,
`ro.lineage.version = 17.1-20261029-UNOFFICIAL-j8y18lte`, `armeabi-v7a`, SDK 29,
**release-keys** signed.
OTA: `j8os-17.1-20261030-0507-signed-ota.zip`,
sha256 `d105a267a8979b2b634b02aa48f5094f898f6ed0537a35e0bf3be0817592fd91`.

Installed 05:22 IST via TWRP `/sbin/twrp install`; data formatted 05:23;
first boot 05:25.

> **Scope.** This cycle is the **permissive diagnostic build**
> (`androidboot.selinux=permissive` in the kernel cmdline). These are
> diagnostic-boot results, not final release acceptance. The enforcing build
> exists as a separate artifact and still needs its own cold boot.

| | |
|---|---|
| ![LineageOS Setup Wizard](evidence/2026-10-30-first-boot/screenshots/setup-wizard-04-33.png) | ![Lock screen](evidence/2026-10-30-first-boot/screenshots/lock-screen-11-17.png) |
| First boot, 04:33 — LineageOS Setup Wizard at 720×1480 | 11:17 — lock screen, "No SIM card", 5½ h of uptime |

## 1. Boot and identity — PASSED

| Test | Result | Evidence |
|---|---|---|
| Device reaches Android | **PASS** | `adb devices` → `<serial> device product:lineage_j8y18lte model:SM_J810G` |
| `sys.boot_completed` | **PASS** | `1` within ~45 s |
| Boot animation finished | **PASS** | `init.svc.bootanim=stopped` |
| Android 10 / API 29 | **PASS** | `ro.build.version.release=10`, `ro.build.version.sdk=29` |
| Build identity | **PASS** | `/system/build.prop`: `ro.build.display.id=lineage_j8y18lte-userdebug 10 QQ3A.200805.001 …`, `ro.lineage.version=17.1-20261029-UNOFFICIAL-j8y18lte` |
| ABI | **PASS** | `ro.product.cpu.abi=armeabi-v7a`; vendor abilist `armeabi-v7a,armeabi` |
| Release signing | **PASS** | `ro.build.tags=release-keys`, `ro.vendor.build.tags=release-keys` |
| LineageOS framework | **PASS** | `LineageParts` present, `ro.lineage.build.version=17.1` |
| First-run UI | **PASS** | `mResumedActivity=org.lineageos.setupwizard/.WelcomeActivity` |

## 2. Display, touch, storage — PASSED (touch untested)

| Test | Result | Evidence |
|---|---|---|
| Display at native resolution | **PASS** | screenshots 720×1480, density 280 |
| UI renders, no compositor crash | **PASS** | Setup Wizard drawn; no SurfaceFlinger failure in logcat |
| Touch input | **NOT TESTED** | requires a human tap |
| `/data` mounted | **PASS** | ext4 52 GB, 69 MB used after format |
| `/cache` mounted | **PASS** | ext4 275 MB |
| Partition layout | **PASS** | system 3,397,386,240 · vendor 503,316,480 · boot/recovery 33,554,432 |

## 3. Connectivity — PARTIAL

| Test | Result | Evidence |
|---|---|---|
| Wi-Fi driver + firmware load | **PASS** | `wlan0` UP, `curState=StaEnabledState`, `/vendor/firmware/wlan/prima` present |
| Wi-Fi association | **NOT TESTED** | no credentials supplied |
| Bluetooth powers on | **PASS** | `svc bluetooth enable` → `state: ON`, name `SM-J810G`, 0 crashes |
| Bluetooth pairing/audio | **NOT TESTED** | no accessory |
| RIL stack | **PASS** | `gsm.version.ril-impl=Samsung RIL v4.0`, `ril-daemon` + `ril-daemon1` running |
| SIM / cellular service | **BLOCKED** | `gsm.sim.state=ABSENT,ABSENT` — no SIM fitted |
| Calls / SMS | **BLOCKED** | needs SIM + human |

## 4. Audio, camera, sensors, power — PARTIAL

| Test | Result | Evidence |
|---|---|---|
| audioserver | **PASS** | `init.svc.audioserver=running` |
| Audio HAL + effect libraries | **PASS** | `dumpsys media.audio_flinger` shows vendor effect libs (Dolby DAX3, Samsung VR360) |
| Speaker / earpiece / mic | **NOT TESTED** | needs a human listening test |
| Camera service | **PASS** | `cameraserver` running, `Number of camera devices: 2` |
| Camera capture | **NOT TESTED** | needs an app interaction |
| Sensors | **PASS** | 5 h/w sensors: LIS2DS accel, STK3013 proximity, A96T3X6 grip, significant-motion, tilt |
| Battery reporting | **PASS** | level 33 %, 4010 mV, 32.9 °C, health 2 |
| Charging over USB | **PASS** | `status: 2` (charging) |

## 5. SELinux

| Test | Result | Evidence |
|---|---|---|
| Build cmdline | permissive (diagnostic build, by design) | `androidboot.selinux=permissive` inside `boot.img` |
| Runtime `setenforce 1` | **PASS — held 5+ h** | `getenforce=Enforcing`; `sys.boot_completed` stayed 1; adb + Wi-Fi + UI intact |
| Denials under enforcing | 32 in 20 s, all cosmetic | `healthd` reading battery sysfs; `kernel` reading `hall_detect` |
| File labels in the image | **PASS** | `debugfs ea_list`: `/firmware`→`firmware_file`, `/omr`→`omr_file`, `/efs`→`efs_file`, `/config`→`rootfs`, `init_exec`, `logd_exec` |
| Cold boot with enforcing image | **BLOCKED** | phone offline before the enforcing boot could be written |

Denial breakdown from the permissive boot:
[`evidence/2026-10-30-first-boot/avc-denials-summary.txt`](evidence/2026-10-30-first-boot/avc-denials-summary.txt)
(532 denials, 445 of them `flags_health_check` property reads).

## 6. Recovery route (broken power button) — PASSED

| Test | Result | Evidence |
|---|---|---|
| TWRP survives the OTA | **PASS** | `sha256(/dev/block/by-name/recovery)` unchanged: `1b6538d5…6e05` |
| OTA does not touch recovery | **PASS** | no recovery payload; updater writes system/vendor/boot |
| Software route into recovery | **PASS** | `/sbin/twrp reboot recovery`; CLI also offers `download`, `bootloader`, `poweroff`, `edl` |
| ADB after data format | **PASS** | `/data/misc/adb/adb_keys` re-seeded; adbd authorised with no on-screen prompt |

## 7. Boot-cycle log

| Cycle | Image | Result |
|---|---|---|
| 0 | earlier flat image, rootfs-only labels | reached `init`, `logd` exited 255 in a loop, userspace rebooted to recovery |
| 1 | correctly-labelled system/vendor + **permissive** boot | **PASSED** — `boot_completed=1`, UI, Wi-Fi/BT/RIL/sensors/camera services, 5+ h uptime |
| 2 | same system/vendor + **enforcing** boot | **BLOCKED** — phone powered off during reboot-to-recovery (battery) |

## 8. Tests that need a human

- Tap through the Setup Wizard (touch + display pipeline end to end).
- Play a sound (speaker, audio HAL path).
- Take a photo (camera capture).
- Insert a SIM; confirm registration and a test call (RIL already runs).

## 9. Release acceptance

**Not yet accepted.** The enforcing artifact
(`j8os-17.1-enforcing-20261030-0532-signed-ota.zip`,
sha256 `8f5669c8ae47368e986ae7f9610b94857ee005832ef7e935e6138376f3c98abc`)
must boot cold with `getenforce=Enforcing`, and the human tests in §8 must pass.
Everything up to and including the permissive boot is done and reproducible.

Raw evidence: [`evidence/2026-10-30-first-boot/`](evidence/2026-10-30-first-boot/)
(`getprop`, kernel log, denial summary, logcat errors, screenshots).
