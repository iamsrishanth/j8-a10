# Post-install validation

> **Results already measured on hardware** are in
> [`../VALIDATION.md`](../VALIDATION.md) — that is the file to read for what
> this build actually does. This page is the reusable checklist for the next
> flashing cycle (for example: the enforcing cold boot, or after a policy
> change).

A build that flashes is not a working ROM. Fill this table in with real
evidence and store the raw output next to it. "Not tested" is a valid — and
honest — result.

## 1. Build identity

```bash
adb shell getprop ro.build.version.release      # expect 10
adb shell getprop ro.build.version.sdk          # expect 29
adb shell getprop ro.build.type                 # userdebug / user
adb shell getprop ro.product.device             # j8y18lte
adb shell getprop ro.product.cpu.abilist        # armeabi-v7a,armeabi
adb shell getprop ro.zygote                     # zygote32
adb shell getprop ro.lineage.build.version      # expect 17.1
adb shell getprop sys.boot_completed            # expect 1
```

## 2. Test matrix

| # | Area | Test | Pass criteria | Result |
|---|---|---|---|---|
| 1 | Boot | Reboot to home screen ×3 | Reaches launcher every time, no bootloop | ☐ |
| 2 | Display | Brightness slider, rotation, 720×1480 | No tearing, auto-brightness responds | ☐ |
| 3 | Touch | Tap, long-press, multi-touch, gestures | No dead zones, no ghost touches | ☐ |
| 4 | Storage | `df -h /data`, write 1 GB file | Full capacity available, no I/O errors | ☐ |
| 5 | Wi-Fi | Connect to 2.4 GHz + 5 GHz AP | Associates, gets DHCP, internet works | ☐ |
| 6 | Bluetooth | Pair headset | Pairs, media audio routes | ☐ |
| 7 | Audio out | Speaker, earpiece, headset | All three routes, no distortion | ☐ |
| 8 | Microphone | Voice recorder | Records audible speech | ☐ |
| 9 | Camera | Rear + front, photo + video | Captures, saves, no HAL crash | ☐ |
| 10 | Flashlight | Quick-settings toggle | LED on/off | ☐ |
| 11 | Sensors | `dumpsys sensorservice` | Accel/light/prox/gyro report data | ☐ |
| 12 | Fingerprint | Enrol + unlock | Enrols, unlocks repeatedly | ☐ |
| 13 | SIM/RIL | Calls, SMS, mobile data, VoLTE | Call audio both ways; data attaches | ☐ |
| 14 | GPS | `dumpsys location`, cold fix | Fix under 2 min outdoors | ☐ |
| 15 | Charging | Charge to 100 %, drain to 15 % | No thermal shutdown, sane % curve | ☐ |
| 16 | SELinux | `getenforce` | `Enforcing` for a release build (permissive is a *known deviation*) | ☐ |
| 17 | Reboot | Software reboot + recovery | Reboot works; TWRP still reachable | ☐ |
| 18 | Sleep | Screen off 30 min | Wakes on touch/call, no SoD | ☐ |

## 3. Evidence collection

```bash
stamp=$(date +%Y%m%d-%H%M%S)
mkdir -p "evidence/$stamp" && cd "evidence/$stamp"

adb shell getprop                  > props.txt
adb shell getenforce              > selinux.txt
adb shell dmesg                    > dmesg.txt
adb logcat -d -b all               > logcat.txt
adb shell dumpsys sensorservice    > sensors.txt
adb shell dumpsys media.camera     > camera.txt
adb shell dumpsys telephony.registry > telephony.txt
adb shell dumpsys wifi             > wifi.txt
adb shell dumpsys SurfaceFlinger   > surfaceflinger.txt
adb shell df -h                    > df.txt
adb shell cat /proc/last_kmsg      > last_kmsg.txt 2>/dev/null
```

Batch denials and crashes:

```bash
grep -c 'avc: denied'  dmesg.txt logcat.txt
grep -E 'FATAL EXCEPTION|Watchdog|system_server.*died' logcat.txt | head -40
```

## 4. Boot-failure triage order

When it does not boot, work in this order — each step rules out a whole class
of causes:

1. **Does the bootloader accept the image?** No message, no LED pattern
   change → kernel/header problem, not userspace.
2. **Does the kernel start?** `last_kmsg`/`pstore` non-empty → kernel fine.
3. **Does first-stage init mount `/system` and `/vendor`?** Look for
   `init: [libfs_mgr]` lines and any `failed to mount` messages.
4. **Does `system_server` start?** `Zygote` and `SystemServer` lines.
5. **SELinux denials?** With permissive builds they are logged but not fatal;
   do not chase them as the root cause of a hang.
6. **HAL/ABI mismatch?** Missing vendor libraries produce `linker` errors in
   logcat long before UI appears.

Rule: change one thing per cycle, identify each image by hash, and record the
observed result. Two failed cycles on the same hypothesis means the hypothesis
is wrong — reassess instead of re-flashing.

## 5. Acceptance for "usable ROM"

Only call a build usable when, on real hardware:

- `sys.boot_completed=1` and the launcher is stable for 30 minutes,
- display, touch, Wi-Fi, audio, cameras, storage and charging work,
- SIM/RIL behaves for calls and SMS,
- SELinux is `Enforcing` **or** the deviation is explicitly documented,
- a software reboot returns to a bootable system, and
- TWRP is still reachable.
