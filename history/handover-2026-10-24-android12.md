<!-- Archived report. Host names, IP addresses, user names, paths and the device serial have been genericised; wording and figures are otherwise unchanged. -->

# j8-os — Handover

State captured: 2026-10-24 (Asia/Calcutta). Everything below was measured or
executed, not assumed. Read section 8 (Open Issues) before starting.

---

## 1. Objective

Build a custom Android image for **Samsung Galaxy J8 (SM-J810G, `j8y18lte`)**,
based on **LineageOS 19.0 (Android 12L)**, with:

- MindTheGapps + Play Integrity fix (so official WhatsApp + Netflix install)
- KernelSU root (v0.9.5 — see 8.2)
- Own release signing keys, SELinux enforcing
- Aggressive debloat, call recording, performance tuning, custom boot animation
- Best-effort VoLTE/VoWiFi

Fallback target: **LineageOS 18.1 (Android 11)** if 19.0 will not boot.

---

## 2. Access

| Alias | Command | Target | Notes |
|---|---|---|---|
| `ubu` | `ssh ubu` | `builder@10.0.0.2` | **Build host** — Ubuntu 22.04.5 WSL2 |
| `builder` | `ssh builder` | Windows host `HOST\builder` | WSL owner; use to run `wsl.exe` |
| `zeus` | `ssh zeus` | `altuser@alt-host` (10.0.0.3) | alternate Linux host, 146 GB free, 4 cores |

- SSH config: `C:\Users\user\.ssh\config` (written by previous agent)
- Auth: `~/.ssh/id_ed25519` (comment `Claw`), no passphrase, no agent needed
- Key is installed in:
  - Windows host: `C:\ProgramData\ssh\administrators_authorized_keys` (sshd reads
    this, not the user file, because `builder` is in Administrators)
  - Ubuntu: `/home/builder/.ssh/authorized_keys`
- **Passwordless sudo** on the build host: `/etc/sudoers.d/90-builder`
  (`builder ALL=(ALL) NOPASSWD:ALL`). Required — the account has no password.

MagicDNS is unreliable from Windows; always connect by IP or via the `ubu` alias.

---

## 3. Build host state (already provisioned)

| Item | Value |
|---|---|
| OS | Ubuntu 22.04.5 LTS (WSL2), kernel 6.18.54.1-microsoft-standard-WSL2 |
| CPU | 16 threads (i5-13450HX) |
| RAM | 12 GB (`memory=12GB`) — reports 11 GiB |
| Swap | 16 GB at `D:\wsl\swap.vhdx` |
| Disk | `/` on `D:\wsl\ubuntu\ext4.vhdx`; D: has ~299 GB free |
| systemd | enabled (PID 1) — required for services |

### WSL config — `C:\Users\Builder\.wslconfig`

```ini
[wsl2]
memory=12GB
processors=16
swap=16GB
swapFile=D:\\wsl\\swap.vhdx
```

### Keep-alive (critical)

WSL tears the VM down when idle, which kills `tailscaled` and drops SSH. A scheduled
task holds it up:

- Task name: `WSL-Ubuntu2204-KeepAlive`
- Trigger: **At system start up**, principal `HOST\builder`, **S4U** (no password)
- Action: `D:\wsl\keepalive.cmd` → `wsl.exe -d Ubuntu-22.04 -u root -- /bin/sh -c "exec sleep infinity"`
- Verified: task starts the distro under its S4U principal. **Not verified across a real reboot** — confirm after the next restart.

If the distro shows `Stopped`, run:

```powershell
schtasks /Run /TN WSL-Ubuntu2204-KeepAlive
```

### Tailscale

- Node `build-host` = **10.0.0.2**, `BackendState: Running`
- Tailscale SSH enabled; exit node advertised (needs admin approval; disable with
  `tailscale set --advertise-exit-node=false` if undesired)
- Key expiry: disabled by the operator

### Removed

- Ubuntu 26.04 distro unregistered (Python 3.14 + no JDK 11 made it unusable for a
  2021-era tree). Backup: `D:\wsl\ubuntu-26-backup.tar` (1.54 GB) — safe to delete.

---

## 4. Toolchain status on `ubu`

Installed and verified:

| Package | Version |
|---|---|
| openjdk-11-jdk | 11.0.32.1 |
| python3 | 3.10.12 |
| ccache | 4.5.1 |
| gcc / g++ (+ multilib) | 11.4.0 |
| build-essential, bison, flex, gperf, imagemagick, libelf-dev, libssl-dev, lz4, lzop, pngcrush, schedtool, squashfs-tools, xsltproc, zip, zlib1g-dev, git-lfs | current (jammy) |

**`repo` is unverified.** The launcher was written to `/usr/local/bin/repo`, but
`repo --version` returned `<repo not installed>`. Fix before proceeding:

```bash
curl -fsSL https://storage.googleapis.com/git-repo-downloads/repo -o ~/bin/repo
chmod a+x ~/bin/repo && export PATH=$HOME/bin:$PATH
repo --version
```

git is configured globally as `j8-os build <build@j8-os.local>`; adjust if commits need an identity.

---

## 5. Device state (SM-J810G, serial `a7d4xxxx`)

| Property | Value |
|---|---|
| Current ROM | AICP 11 (Android 11), userdebug, **SELinux permissive** |
| adb | `adbd running as root` |
| SoC / GPU | Snapdragon 450 (msm8953) / Adreno 506 |
| RAM / storage | 4 GB / 64 GB |
| Display | 720×1480 @ 280 dpi, 60 Hz |
| Bootloader | `J810GDDU6CWH2`, verified boot `green`, `flash.locked=1`, `warranty_bit=1` (Knox tripped) |
| ABI | `armeabi-v7a` only, `zygote32` |
| Widevine | `libwvhidl.so` + TEE firmware + `/efs/widevine` present; **level not queryable via adb** |

### Partition map (`/dev/block/by-name/`)

| Partition | Block | Size (bytes) |
|---|---|---|
| boot | `mmcblk0p25` | 33,554,432 |
| recovery | `mmcblk0p26` | 33,554,432 |
| system | `mmcblk0p40` | 3,397,386,240 |
| vendor | `mmcblk0p41` | 503,316,480 |
| cache | `mmcblk0p43` | 314,572,800 |
| userdata | `mmcblk0p46` | 57,415,790,592 |

### Boot image header (measured)

Legacy v0, `ANDROID!` magic, page size 2048, kernel_addr `0x80000000`,
ramdisk_addr `0x82000000`, tags_addr `0x81e00000`, kernel ≈ 12.3 MB,
ramdisk ≈ 779 KB. Matches the device tree's `BoardConfig.mk` — a repacked image will load.

---

## 6. Source components

| Repo | Path | Branch |
|---|---|---|
| LineageOS manifest | — | `lineage-19.0` |
| `goldfish07/android_device_samsung_j8y18lte` | `device/samsung/j8y18lte` | `lineage-19.0` |
| `goldfish07/android_kernel_samsung_j8y18lte` | `kernel/samsung/j8y18lte` | `lineage-19.0` |
| `goldfish07/android_vendor_samsung_j8y18lte` | `vendor/samsung/j8y18lte` | `10` |

Ready-to-copy manifest: [local_manifests/j8y18lte.xml](../manifests/j8y18lte.xml)

### Key build parameters (from `BoardConfig.mk`)

```make
TARGET_ARCH := arm                    # 32-bit userspace
TARGET_ARCH_VARIANT := armv8-a
TARGET_CPU_VARIANT := cortex-a53
TARGET_USES_64_BIT_BINDER := true
TARGET_BOARD_SUFFIX := _64
TARGET_KERNEL_ARCH := arm64           # 64-bit kernel
TARGET_KERNEL_CONFIG := j8y18lte_defconfig
TARGET_LINUX_KERNEL_VERSION := 3.18
TARGET_KERNEL_CLANG_COMPILE := false  # GCC 4.9 prebuilt
BOARD_VNDK_VERSION := current
```

This is `arm32_binder64`: 64-bit kernel, 32-bit userspace. The current AICP kernel
is `armv8l` (32-bit), so the kernel is a genuine rebuild, not a carry-over.

---

## 7. Build procedure

```bash
mkdir -p ~/android/lineage && cd ~/android/lineage
repo init -u https://github.com/LineageOS/android.git -b lineage-19.0 --git-lfs
mkdir -p .repo/local_manifests
# copy j8y18lte.xml into .repo/local_manifests/

repo sync -c -j16 --force-sync --no-clone-bundle --no-tags

source build/envsetup.sh
breakfast lineage_j8y18lte

export USE_CCACHE=1
export CCACHE_EXEC=/usr/bin/ccache
ccache -M 40G

mka bacon -j16
```

Outputs in `out/target/product/j8y18lte/`:
`lineage-19.0-<date>-UNOFFICIAL-j8y18lte.zip`, `boot.img`, `recovery.img`,
`system.img`, `vendor.img`.

Disk budget: source ~70 GB, `out` ~85 GB, ccache 40 GB, headroom ~99 GB → ~200 GB of the 299 GB available.

---

## 8. Open issues — read before starting

### 8.1 `lineage-19.0` may be an unproven branch (highest risk)

Two lines in its `BoardConfig.mk` look copied from 18.1 and are suspicious for Android 12:
`BOARD_VNDK_VERSION := current` and
`include device/qcom/sepolicy-legacy-um/SEPolicy.mk`.
No published builds of this branch were found. Expect debugging, not a clean `brunch`.
**Fallback: `lineage-18.1` (Android 11), which this device already runs as AICP 11.**

### 8.2 KernelSU on kernel 3.18

- Upstream **dropped non-GKI support in v1.0**; last usable release is **v0.9.5**.
- 3.18 is older than 4.8, so the `kprobe` path is unreliable → **manual integration**:
  - `fs/exec.c` → `do_execveat_common`
  - `fs/open.c` → `faccessat` syscall (no `do_faccessat` on 3.18)
  - `fs/read_write.c` → `vfs_read`
  - `fs/stat.c` → **`vfs_fstatat`** (3.18 has no `vfs_statx`)
  - optional: `fs/devpts/inode.c`, `drivers/input/input.c` (safe mode), backport `path_umount`
  - enable `CONFIG_KSU=y` in `j8y18lte_defconfig`
- **Rule: integrate KernelSU only after the ROM boots cleanly.** A kernel bug = bootloop
  with no adb and no recovery, only Download mode.

### 8.3 Signing keys force a data wipe

Own release keys ≠ AICP `test-keys`. Android will not boot over a data partition
signed with different keys — **factory reset on first flash**.

### 8.4 Widevine / Netflix

Knox is tripped, which usually drops Widevine to **L3 → Netflix 480p SD**. Confirm
with a DRM Info app after first boot. Do not promise HD.

### 8.5 Play Integrity is spoofing

MindTheGapps + ZygiskNext + PlayIntegrityFix defeats Google attestation. It works
until Google changes something. Never install Netflix/WhatsApp from third-party APK
mirrors — Play Store only (WhatsApp has an official APK at `whatsapp.com/android`).

### 8.6 Recovery risk

`ro.boot.flash.locked=1` on a Knox-tripped unit. If Odin refuses, `dd` from root adb
is the only path — and it requires a bootable system. **Always dump partitions first**
(see [scripts/backup-partitions.ps1](../scripts/backup-partitions.ps1)).

### 8.7 Secret on a network share

`<network-share>\Linux-OpenSSH-Setup.sh` contains an embedded Tailscale auth key
(`tskey-auth-…`) usable by anyone who can read it. Do not copy it into the repo or
commit it. Rotate if the share is broadly accessible.

---

## 9. Next steps (in order)

1. Verify/repair `repo` on the build host (§4).
2. Audit `lineage-19.0` for completeness — diff against `lineage-18.1`, check
   `sepolicy-legacy-um` exists in the 19.0 tree, confirm the vendor blobs satisfy
   `j8y18lte-vendor.mk`.
3. **Back up device partitions** to `<project>\backup\` before anything is flashed.
4. `repo init` + `repo sync` + `breakfast` (fast fail if the tree is incomplete).
5. First build (`mka bacon -j16`), then fix compile errors.
6. Flash, validate against the checklist in BUILD-SPEC §10.
7. Only then: KernelSU, Play Integrity stack, debloat, feature packs.
8. If 19.0 cannot boot after two fix cycles → switch to `lineage-18.1`.

---

## 10. File inventory

| File | Purpose |
|---|---|
| `HANDOVER.md` | this document |
| `BUILD-SPEC.md` | full technical build specification |
| `local_manifests/j8y18lte.xml` | device/kernel/vendor manifest |
| `scripts/backup-partitions.ps1` | pre-flash partition dump |
