<!-- Archived report. Host names, IP addresses, user names, paths and the device serial have been genericised; wording and figures are otherwise unchanged. -->

# j8-os — Custom Android Image Build Specification

Target: **Samsung Galaxy J8 (SM-J810G)**, codename `j8y18lte`
Distribution: **LineageOS 19.0** (Android 12L / API 31)
Build host: `build-host` (Ubuntu 22.04.5 LTS on WSL2, D:\wsl\ubuntu)

---

## 1. Device target

| Property | Value | Source |
|---|---|---|
| Model | SM-J810G | `ro.product.model` (measured) |
| Codename | `j8y18lte` | `ro.product.device` |
| SoC | Qualcomm Snapdragon 450 (`msm8953`, SDM450) | `/proc/cpuinfo`, `ro.board.platform` |
| CPU | 8× Cortex-A53 @ 1.80 GHz | measured |
| GPU | Adreno 506, GLES 3.2 | `dumpsys SurfaceFlinger` |
| RAM | 4 GB | `/proc/meminfo` |
| Storage | 64 GB eMMC | `df` |
| Display | 720×1480 @ 280 dpi, 60 Hz | `wm size` |
| Battery | 3500 mAh | `charge_full_design` |
| Bootloader | J810GDDU6CWH2, verified boot `green` | `ro.bootloader` |
| Current ROM | AICP 11 (Android 11), userdebug, SELinux permissive | measured |

**Architecture decision — the key constraint:**

```
TARGET_ARCH                 := arm            # 32-bit userspace
TARGET_USES_64_BIT_BINDER   := true           # 64-bit binder
TARGET_BOARD_SUFFIX         := _64
TARGET_KERNEL_ARCH          := arm64          # 64-bit kernel
```

The device ships 32-bit vendor blobs, so userspace stays `armeabi-v7a` (`arm32_binder64`).
The kernel is rebuilt **arm64** — this is a change from the current `armv8l` (32-bit) kernel.
Android 12 cannot be built 32-bit-only with a 32-bit kernel; the 64-bit kernel with
32-bit userspace is the supported configuration.

---

## 2. Build host

| Resource | Value | Verdict |
|---|---|---|
| OS | Ubuntu 22.04.5 LTS | matches A12-era toolchain |
| CPU | 16 threads (i5-13450HX) | `-j16` viable |
| RAM | 12 GB (WSL `memory=12GB`) | adequate; 16 GB ideal |
| Swap | 16 GB at `D:\wsl\swap.vhdx` | protects against OOM |
| Disk | `D:\wsl\ubuntu\ext4.vhdx`, **299 GB** free | sufficient with ccache |
| systemd | enabled (PID 1) | required for services |

---

## 3. Source components

| Repo | Path in tree | Branch |
|---|---|---|
| `LineageOS/android` | (manifest) | `lineage-19.0` |
| `goldfish07/android_device_samsung_j8y18lte` | `device/samsung/j8y18lte` | `lineage-19.0` |
| `goldfish07/android_kernel_samsung_j8y18lte` | `kernel/samsung/j8y18lte` | `lineage-19.0` |
| `goldfish07/android_vendor_samsung_j8y18lte` | `vendor/samsung/j8y18lte` | `10` |

Vendor blobs are Android 10-era (~211 MB). This is the normal LineageOS pattern for
a device whose last official Samsung firmware was Android 10.

### `local_manifests/j8y18lte.xml`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<manifest>
  <remote name="gold" fetch="https://github.com/goldfish07" />

  <project name="android_device_samsung_j8y18lte"
           path="device/samsung/j8y18lte"
           remote="gold" revision="lineage-19.0" />
  <project name="android_kernel_samsung_j8y18lte"
           path="kernel/samsung/j8y18lte"
           remote="gold" revision="lineage-19.0" />
  <project name="android_vendor_samsung_j8y18lte"
           path="vendor/samsung/j8y18lte"
           remote="gold" revision="10" />
</manifest>
```

---

## 4. Disk budget (D: 299 GB)

| Item | Estimate |
|---|---|
| `.repo` + source tree | 70 GB |
| `out/` (arm-only userspace, arm64 kernel) | 85 GB |
| ccache (optional, capped) | 40 GB |
| Linux kernel `out` | 5 GB |
| Headroom / retries | ~99 GB |
| **Total** | **~200 GB** |

Ccache is affordable here, unlike the original 130 GB estimate.

---

## 5. Toolchain and packages

```
openjdk-11-jdk          # Android 12 requires JDK 11, not 17/21
build-essential  bc  bison  flex  gperf  zip  unzip
gcc-multilib  g++-multilib  libc6-dev-i386
libssl-dev  libelf-dev  liblz4-tool  lzop  zlib1g-dev
lib32ncurses5-dev  lib32readline-dev  lib32z1-dev
libncurses5-dev  libxml2  libxml2-utils  xsltproc
imagemagick  pngcrush  squashfs-tools  schedtool
python3  rsync  curl  git  git-lfs  ccache
android-sdk-platform-tools   # adb/fastboot for flashing
```

### Installation status (as of handover)

**Done on `ubu`:** openjdk-11-jdk 11.0.32.1, python3 3.10.12, ccache 4.5.1,
gcc/g++ 11.4.0 + multilib, build-essential, bison, flex, gperf, imagemagick,
libelf-dev, libssl-dev, lz4, lzop, pngcrush, schedtool, squashfs-tools, xsltproc,
zip, zlib1g-dev, git-lfs. Passwordless sudo is configured.

**Outstanding:** `repo` was written to `/usr/local/bin/repo` but `repo --version`
returned `<repo not installed>`. Repair before syncing:

```bash
curl -fsSL https://storage.googleapis.com/git-repo-downloads/repo -o ~/bin/repo
chmod a+x ~/bin/repo && export PATH=$HOME/bin:$PATH && repo --version
```

Python: Ubuntu 22.04 ships **3.10** — correct for the A12 build system. (The old
Ubuntu 26.04 attempt would have failed on Python 3.14 and a missing JDK 11.)

---

## 6. Build procedure

```bash
mkdir -p ~/android/lineage && cd ~/android/lineage

repo init -u https://github.com/LineageOS/android.git -b lineage-19.0 --git-lfs
mkdir -p .repo/local_manifests
# write j8y18lte.xml here (section 3)

repo sync -c -j16 --force-sync --no-clone-bundle --no-tags

source build/envsetup.sh
breakfast lineage_j8y18lte          # resolves device/kernel/vendor deps

export USE_CCACHE=1
export CCACHE_EXEC=/usr/bin/ccache
ccache -M 40G

mka bacon -j16                      # or: brunch j8y18lte
```

Kernel is compiled automatically from `TARGET_KERNEL_SOURCE` with
`j8y18lte_defconfig`, cross-compiled `aarch64-linux-android-` (GCC 4.9 prebuilt,
`TARGET_KERNEL_CLANG_COMPILE := false`), producing `Image.gz-dtb`.

### Boot image parameters (from `BoardConfig.mk`)

| Parameter | Value |
|---|---|
| `BOARD_KERNEL_BASE` | `0x80000000` |
| `BOARD_RAMDISK_OFFSET` | `0x02000000` |
| `BOARD_TAGS_OFFSET` | `0x01e00000` |
| `BOARD_KERNEL_PAGESIZE` | 2048 |
| `BOARD_KERNEL_IMAGE_NAME` | `Image.gz-dtb` |
| Kernel version | 3.18 |

These match the live device header exactly (verified: legacy v0, page size 2048),
so a repacked boot image will load.

### Partition sizes (from `BoardConfig.mk`, confirmed against live device)

| Partition | Bytes | Block |
|---|---|---|
| boot | 33,554,432 | `mmcblk0p25` |
| recovery | 33,554,432 | `mmcblk0p26` |
| system | 3,397,386,240 | `mmcblk0p40` |
| vendor | 503,316,480 | `mmcblk0p41` |
| cache | 314,572,800 | `mmcblk0p43` |
| userdata | 57,415,790,592 | `mmcblk0p46` |

---

## 7. Output artifacts

`out/target/product/j8y18lte/`

- `lineage-19.0-<date>-UNOFFICIAL-j8y18lte.zip` — flashable ROM (~1.0–1.5 GB)
- `boot.img` — kernel + ramdisk
- `recovery.img` — Lineage recovery
- `system.img`, `vendor.img` — raw partition images

---

## 8. Backup before flashing (mandatory)

Device currently has working AICP 11 and root adb. Dump first:

```bash
adb root
adb shell dd if=/dev/block/by-name/boot   of=/sdcard/boot-stock.img
adb shell dd if=/dev/block/by-name/system of=/sdcard/system-stock.img
adb shell dd if=/dev/block/by-name/vendor of=/sdcard/vendor-stock.img
adb pull /sdcard/boot-stock.img  <project>\backup\
adb pull /sdcard/system-stock.img <project>\backup\
adb pull /sdcard/vendor-stock.img <project>\backup\
```

## 9. Flashing paths

**Preferred:** boot Lineage recovery, `adb sideload lineage-19.0-*.zip`.

**Fallback (root adb, no recovery):**

```bash
adb push boot.img   /data/local/tmp/boot.img
adb shell su -c "dd if=/data/local/tmp/boot.img of=/dev/block/by-name/boot"
adb shell su -c "dd if=/data/local/tmp/system.img of=/dev/block/by-name/system"
```

**Last resort:** package images as Odin `AP` tar.

Note: `ro.boot.flash.locked` reports `1` on a Knox-tripped device. If Odin refuses,
`dd` from root adb is the working path — but only while a bootable system exists.

## 10. Validation checklist

- `getprop ro.build.version.release` → `12`
- `getprop ro.lineage.build.version` present
- `getprop ro.build.version.sdk` → `31`
- Boot to home screen, touch, display rotation
- Wi-Fi, Bluetooth, cellular data, calls, SMS
- Camera (back + front), flashlight
- Audio (speaker, earpiece, headset), microphone
- GPS lock, sensors (accel, proximity)
- Fingerprint, charging, battery reporting
- SELinux state and `ro.build.type`

## 11. Risk register

| Risk | Likelihood | Mitigation |
|---|---|---|
| `lineage-19.0` branch incomplete | **High** | `BOARD_VNDK_VERSION := current` and `device/qcom/sepolicy-legacy-um` look copied from 18.1. Fall back to `lineage-18.1` (Android 11) which AICP 11 already proves works. |
| Android 10 vendor blobs vs A12 system | Medium | VNDK compat shims; may need `PRODUCT_SHIPPING_API_LEVEL` / VNDK overrides |
| GCC 4.9 prebuilt absent in 19.0 tree | Low | Switch kernel to Clang or vendor a toolchain |
| 32-bit camera HAL (`BOARD_QTI_CAMERA_32BIT_ONLY`) | Medium | Camera may crash; fall back to older camera provider |
| Kernel 3.18 vs A12 expectations | Medium | Kernel builds from source; watch for missing syscalls/selinux policy |
| RAM pressure at 12 GB | Low | `-j8` instead of `-j16`; swap already 16 GB |

**Decision rule:** if `lineage-19.0` fails to boot after two fix cycles, ship
**LineageOS 18.1 (Android 11, 32-bit kernel as today)** — proven on this hardware —
and treat Android 12 as a stretch goal.

## 12. Chosen configuration (decided)

| Decision | Choice |
|---|---|
| Google services | **MindTheGapps** + Play Integrity fix (revised — required for WhatsApp/Netflix) |
| Root | **KernelSU** (see 12.1 — needs kernel work) |
| Signing | **Own release keys** (`make_key`) |
| SELinux | **Enforcing** in release |
| Debloat | **Aggressive / minimal** |
| Feature packs | Call recording, performance tuning, custom boot animation, VoLTE/VoWiFi attempt |
| Strategy | Android 12 first, fall back to 18.1 (A11) if it won't boot |

### 12.1 KernelSU on kernel 3.18 — the hard part

Upstream facts (kernelsu.org, non-GKI integration guide):

- **Non-GKI support was dropped in KernelSU v1.0.** The last usable version is **v0.9.5**.
- The easy path uses `kprobe` (`CONFIG_KPROBES=y`). The guide states that if kprobe
  is unreliable — *explicitly the case for kernels older than 4.8* — integration must
  be done **manually**.
- Our kernel is **3.18**, so plan on the manual path, patching four files:
  - `fs/exec.c` → `do_execveat_common` (su/sucompat)
  - `fs/open.c` → `faccessat` syscall (3.18 has no `do_faccessat`; patch the SYSCALL_DEFINE)
  - `fs/read_write.c` → `vfs_read`
  - `fs/stat.c` → **`vfs_fstatat`** (3.18 has no `vfs_statx`)
  - optional: `fs/devpts/inode.c` (fixes `pm` in terminal), `drivers/input/input.c` (safe mode)
  - optional: backport `path_umount` from 5.9 for module-umount support
- `CONFIG_KSU=y` added to `j8y18lte_defconfig`.

**Sequencing rule:** KernelSU is integrated **only after the ROM boots cleanly
without it**. A KernelSU mistake produces a bootloop in the kernel itself, where
neither adb nor recovery is reachable — only Download mode/Odin. Never debug two
unknowns at once.

**Recovery risk:** `ro.boot.flash.locked` reports `1` on this Knox-tripped unit.
If a kernel bootloops, the only way back is Download mode + Odin, which depends on
OEM unlock still being honoured. A working `boot.img` dump is therefore mandatory
before any kernel flash.

### 12.2 Feature implementation notes

| Feature | How | Risk |
|---|---|---|
| Vanilla | `PRODUCT_PACKAGES` trim, no Gapps zip | none |
| Call recording | Dialer feature flags + `ro.` properties | msm8953 audio HAL may not support two-way |
| Performance | zRAM 1 GB, `schedutil`/`interactive` tuning, 0.5× animations, CFQ→`deadline` | low |
| Boot animation | replace `bootanimation.zip` @ 720×1480 | none |
| Aggressive debloat | package removal list applied post-boot | medium — recoverable |
| VoLTE/VoWiFi | carrier config + IMS props | **high** — A10 blobs on A12; likely non-functional |
| Own keys | `make_key` × 4, sign release zip + images | **forces full data wipe** |

### 12.3 Signing / wipe implication

Switching from AICP's `test-keys` to own release keys changes the platform
signature. Android will refuse to boot over an existing data partition signed with
different keys — **a factory reset is unavoidable** on first flash of this image.
Back up personal data before flashing.

### 12.4 Google apps + Play Integrity (revised requirement)

Goal: install **official WhatsApp and Netflix** from Play Store on a rooted
custom ROM. This reverses the original "vanilla" decision and requires:

| Component | Purpose |
|---|---|
| **MindTheGapps** (Android 12L build) | Provides Play Store + GMS |
| **KernelSU v0.9.5** | Root, with hiding |
| **ZygiskNext** | Zygisk API layer for KernelSU |
| **PlayIntegrityFix (PIF)** | Spoofs device fingerprint / attestation |
| **Device registration** | GSF ID must be Google-certified for Play Store to list Netflix |

### Security reality — stated plainly

- Passing Play Integrity means **defeating Google's device attestation**. This is
  evasion, not hardening. It works today; a server-side change can break it.
- Netflix visibility in Play Store depends on BASIC integrity + device
  certification. If Play Integrity fails, Netflix disappears from search.
- **Widevine**: device has a real implementation (`libwvhidl.so`, TEE firmware,
  `/efs/widevine` keys), but the security level is **not queryable via adb** on
  this build. Knox is tripped (`ro.boot.warranty_bit=1`), which on Samsung usually
  means **L3 → Netflix capped at 480p SD**. Confirm with a DRM Info app post-boot.
  HD (L1) is unlikely and should not be promised.
- **WhatsApp** does not need Play Integrity; Meta publishes an official signed APK
  at `whatsapp.com/android` as a fallback if Play Store listing fails.
- Mitigations kept: SELinux **enforcing**, own release keys, apps installed only
  from Play Store (never third-party APK mirrors).

## 13. Timeline estimate

| Phase | Time |
|---|---|
| Host prep + toolchain install | 20–30 min |
| `repo init` + `repo sync` | 40–90 min (network bound) |
| First build | 2–4 h (16 threads) |
| Debug cycle per failure | 30 min – 2 h |
| Flashing + validation | 30 min |
