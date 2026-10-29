# Device reference — Samsung Galaxy J8 (SM-J810G)

Everything in this file was measured from the device or read from the pinned
device tree. Where the two disagree, both values are shown.

## 1. Identity

| Property | Value | Source |
|---|---|---|
| Model | SM-J810G | `ro.product.model` |
| Device codename | `j8y18lte` | `ro.product.device`, `ro.product.device` in build |
| Marketing name | Galaxy J8 (2018) | — |
| Shipped Android | 8.0 (TouchWiz Essence) | device tree README |
| Target Android here | 10 / API 29 (LineageOS 17.1) | this project |
| Bootloader (last read) | `J810GDDU6CWH2` | `ro.boot.bootloader` |
| Verified boot state | `green` | `ro.boot.verifiedbootstate` |
| `ro.boot.flash.locked` | `1` | measured |
| Knox warranty bit | `1` (tripped) | `ro.boot.warranty_bit` |

The unit this project was developed against has a **broken power button**.
That constrains recovery and rebooting — see [recovery.md](recovery.md).

## 2. Hardware

| Property | Value |
|---|---|
| SoC | Qualcomm Snapdragon 450 (`msm8953`, SDM450), 14 nm |
| CPU | 8 × Cortex-A53, up to 1.80 GHz |
| GPU | Adreno 506, GLES 3.2 |
| RAM | 4 GB |
| Storage | 64 GB eMMC |
| microSD | up to 256 GB |
| Display | 720 × 1480 px, 18.5:9, ~280 dpi, 60 Hz |
| Battery | 3500 mAh, non-removable |
| Rear camera | 16 MP + 5 MP depth, LED flash |
| Front camera | 16 MP, LED flash |
| Fingerprint | rear-mounted |
| Sensors | accelerometer, proximity, light, gyro, compass |
| Widevine | `libwvhidl.so` + TEE firmware present; security level not queryable over ADB |

## 3. Architecture: `arm32_binder64`

This is the single most important constraint of the port.

```make
TARGET_ARCH                 := arm      # 32-bit userspace
TARGET_ARCH_VARIANT         := armv8-a
TARGET_CPU_VARIANT          := cortex-a53
TARGET_USES_64_BIT_BINDER   := true     # 64-bit binder
TARGET_KERNEL_ARCH          := arm64    # 64-bit kernel
TARGET_KERNEL_CROSS_COMPILE_PREFIX := aarch64-linux-android-
```

- The vendor blobs are 32-bit (`armeabi-v7a` only). There is no 64-bit
  vendor userspace on this device.
- Therefore userspace stays 32-bit (`zygote32`,
  `ro.product.cpu.abilist=armeabi-v7a,armeabi`), while the kernel is arm64.
- You cannot build Android 10 for this device with a 32-bit-only kernel
  configuration and expect the 64-bit binder path to work; the kernel is
  rebuilt as arm64.

## 4. Partitions

| Partition | Block node | Size (bytes) | Size |
|---|---|---:|---|
| boot | `mmcblk0p25` | 33,554,432 | 32 MiB |
| recovery | `mmcblk0p26` | 33,554,432 | 32 MiB |
| persist | `mmcblk0p31` | 1,048,576 | 1 MiB |
| system | `mmcblk0p40` | 3,397,386,240 | ~3.16 GiB |
| vendor | `mmcblk0p41` | 503,316,480 | 480 MiB |
| cache | `mmcblk0p43` | 314,572,800 | 300 MiB |
| userdata | `mmcblk0p46` | 57,415,790,592 | ~53.5 GiB |

Notes:

- Numbers come from `BoardConfig.mk` and were cross-checked against
  `/dev/block/by-name/` on a live device.
- The live `userdata` measurement was 57,415,806,976 B — 16,384 B larger than
  the build-time value. Do not assume either number blindly; measure with
  `blockdev --getsize64 /dev/block/by-name/<name>` before writing raw images.
- `/dev/block/by-name/*` symlinks exist in the running system and in TWRP.
  Using them is safer than hard-coding `mmcblk0pNN`.
- **Never** write `persist`, `efs`, `modemst1/2`, `fsg`, `fsc`, `apnhlos` or
  `modem`. They carry identity, calibration and radio data.

## 5. Boot image format

The device uses the **legacy boot image header (v0)**, not header v1/v2 and
not `boot_signature`/vendor-boot.

| Field | Value |
|---|---|
| Magic | `ANDROID!` |
| Header version | 0 (legacy) |
| Page size | 2048 |
| `kernel_addr` | `0x80008000` (base `0x80000000` + 0x8000) |
| `ramdisk_addr` | `0x82000000` |
| `tags_addr` | `0x81e00000` |
| `BOARD_KERNEL_IMAGE_NAME` | `Image.gz-dtb` |
| Kernel payload | ~12.3 MB (`kernel_size=12,297,618` measured) |
| Boot ramdisk | ~779 KB (`ramdisk_size=762,577` measured) |
| Recovery ramdisk | ~16-17 MB |

The `mkbootimg` arguments are pinned in the device tree:

```make
BOARD_MKBOOTIMG_ARGS := --ramdisk_offset 0x02000000 --tags_offset 0x01e00000
```

Because the header parameters match the stock layout, a repacked `boot.img`
loads without patching the bootloader.

## 6. Kernel cmdline

From `BoardConfig.mk:47`:

```text
console=null androidboot.hardware=qcom msm_rtb.filter=0x237 ehci-hcd.park=3
androidboot.bootdevice=7824900.sdhci lpm_levels.sleep_disabled=1
androidboot.selinux=permissive
```

The build appends `buildvariant=userdebug`, and the resulting string is what
is embedded in the produced `boot.img`:

```text
console=null androidboot.hardware=qcom msm_rtb.filter=0x237 ehci-hcd.park=3
androidboot.bootdevice=7824900.sdhci lpm_levels.sleep_disabled=1
androidboot.selinux=permissive buildvariant=userdebug
```

`androidboot.selinux=permissive` is the **only** SELinux setting in the whole
device + vendor tree. A release build must change it to `enforcing` and fix
the resulting denials — see [build-troubleshooting.md](build-troubleshooting.md)
and [integrity.md](integrity.md).

## 7. Root directory layout

The device tree declares extra root entries:

```make
BOARD_ROOT_EXTRA_SYMLINKS := \
    /vendor/dsp:/dsp \
    /vendor/firmware_mnt:/firmware \
    /mnt/vendor/persist:/persist \
    /mnt/vendor/efs:/efs

BOARD_ROOT_EXTRA_FOLDERS := config omr efs
```

This is exactly the set that the failing `e2fsdroid` step trips over. See
[build-troubleshooting.md](build-troubleshooting.md#1-e2fsdroid-fails-on-firmware).

## 8. Kernel

| Property | Value |
|---|---|
| Version | 3.18.140 |
| Source | `kernel/samsung/j8y18lte` (goldfish07), pin `3a7e80328b108097e984c028c0fd1f9e65678e31` |
| Config | `arch/arm64/configs/j8y18lte_defconfig` |
| Toolchain | `prebuilts/gcc/linux-x86/aarch64/aarch64-linux-android-4.9` |
| Output | `Image.gz-dtb` |
| Binder | `CONFIG_ANDROID_BINDER_IPC=y` |
| SELinux | `CONFIG_SECURITY_SELINUX=y` |
| dm-verity | `CONFIG_DM_VERITY=y` (capability only; never used) |
| AVB | not supported by this kernel — no `CONFIG_DM_VERITY_AVB`, no `CONFIG_ANDROID_VERIFIED_BOOT` |
| File-based encryption | `CONFIG_FS_ENCRYPTION` **not set** |

The last two lines explain a lot of the behaviour in this project: the build
cannot be AVB-verified even if you wanted it to be, and `/data` cannot be
file-encrypted.

## 9. Vendor blobs

| Property | Value |
|---|---|
| Repository | `goldfish07/android_vendor_samsung_j8y18lte` |
| Pin | `ca797aa33d3e786613cc86440f1b00b32bbf7d43` |
| Content | ~211 MB of blobs from Samsung **Android 10** firmware `J810GDDU5CUF2` |
| Manifest | `vendor/samsung/j8y18lte/j8y18lte-vendor.mk` |
| Blob list | `device/samsung/j8y18lte/proprietary-files.txt` |

The blobs being Android 10-era is the reason Android 10 is the realistic
target for a from-source build: the HAL interfaces match.

## 10. Quick inspection commands

```bash
# identity
adb shell getprop ro.product.device
adb shell getprop ro.boot.bootloader
adb shell getprop ro.boot.verifiedbootstate
adb shell getprop ro.boot.warranty_bit

# partition sizes (works in Android with root adb, and in TWRP)
adb shell blockdev --getsize64 /dev/block/by-name/system
adb shell blockdev --getsize64 /dev/block/by-name/vendor

# boot header of a built image
python3 - <<'EOF'
import struct
h = open('boot.img','rb').read(2048)
f = struct.unpack('<8s10I16s512s32s1024s', h[:1664])
print('magic', f[0], 'kernel', f[1], 'ramdisk', f[3], 'page', f[5])
print('kernel_addr 0x%08x ramdisk_addr 0x%08x tags 0x%08x' % (f[6], f[7], f[8]))
print('cmdline', f[10].split(b'\0')[0].decode())
EOF
```
