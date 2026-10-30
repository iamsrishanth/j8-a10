# Building Android 10 for `j8y18lte`

Target: **LineageOS 17.1** (Android 10, API 29), `lineage_j8y18lte-userdebug`.

This is the procedure that was actually executed on the reference build host.
It does not yet produce a flashable ZIP — the last step fails, see
[build-troubleshooting.md](build-troubleshooting.md). Everything up to and
including `boot.img`, `recovery.img` and `vendor.img` succeeds.

---

## 1. Host requirements

| Resource | Minimum | Used here |
|---|---|---|
| OS | Ubuntu 20.04/22.04 x86_64 (or WSL2) | Ubuntu 22.04.5 LTS on WSL2 |
| CPU | 8 threads | 16 threads (i5-13450HX), `-j16` |
| RAM | 12 GB | 12 GB + 16 GB swap |
| Disk | ~130 GB free for source + out | 120 GB tree, 824 GB free |
| JDK | 11 | OpenJDK 11.0.32 |
| Python | 3.8–3.10 | 3.10.12 |

Do **not** build on a 9p/DrvFs mount (`/mnt/c`, `/mnt/d` under WSL) — file
metadata loss and slow I/O break the build. Keep the tree on the native ext4
filesystem and only export finished artifacts to the shared mount.

### Packages

```bash
sudo apt install -y \
  openjdk-11-jdk python3 python3-pip git git-lfs \
  build-essential bc bison flex gperf zip unzip \
  gcc-multilib g++-multilib libc6-dev-i386 lib32ncurses-dev \
  libssl-dev libelf-dev liblz4-tool lzop zlib1g-dev \
  libncurses5 libncurses5-dev libtinfo5 libxml2 libxml2-utils xsltproc \
  imagemagick pngcrush schedtool squashfs-tools rsync curl ccache ninja-build \
  android-sdk-platform-tools
```

### `repo`

```bash
mkdir -p ~/bin
curl -fsSL https://storage.googleapis.com/git-repo-downloads/repo -o ~/bin/repo
chmod a+x ~/bin/repo
export PATH=$HOME/bin:$PATH
repo --version
```

`repo --version` printing `<repo not installed>` means the launcher is broken;
re-download it rather than continuing.

---

## 2. Sync the source

```bash
export SRC=$HOME/android/lineage-17.1
mkdir -p "$SRC" && cd "$SRC"

git config --global user.name  "your name"
git config --global user.email "you@example.com"

repo init -u https://github.com/LineageOS/android.git -b lineage-17.1
```

Add the device/kernel/vendor pins before the first sync. Copy both files from
this repository:

```bash
mkdir -p .repo/local_manifests
cp <this-repo>/manifests/j8y18lte.xml   .repo/local_manifests/
cp <this-repo>/manifests/roomservice.xml .repo/local_manifests/
```

`j8y18lte.xml` pins:

| Project | Path | Revision |
|---|---|---|
| `goldfish07/android_device_samsung_j8y18lte` | `device/samsung/j8y18lte` | `1b4f25eff98554feac5c0ab945c70be6589c3693` |
| `goldfish07/android_kernel_samsung_j8y18lte` | `kernel/samsung/j8y18lte` | `3a7e80328b108097e984c028c0fd1f9e65678e31` |
| `goldfish07/android_vendor_samsung_j8y18lte` | `vendor/samsung/j8y18lte` | `ca797aa33d3e786613cc86440f1b00b32bbf7d43` |

`roomservice.xml` adds the two LineageOS dependencies the device tree does not
pull automatically:

- `hardware/samsung`
- `device/samsung_slsi/sepolicy`

Then sync. This is the long step (~100 GB, network bound):

```bash
repo sync -c -j8 --force-sync --no-clone-bundle --no-tags
```

`-c` (current branch only) and `--no-tags` keep the checkout to a sane size.
`--force-sync` makes retries after an interrupted sync safe.

`scripts/sync.sh` in this repository does all of the above.

---

## 3. Apply the local patches

The pinned device tree needs at least one local fix to match how Android 10
collects vendor sepolicy:

```bash
bash <this-repo>/scripts/apply-patches.sh
```

The script is idempotent, refuses to apply on top of a dirty tree it cannot
recognise, and prints the resulting `git log -1`.

For what the patch does and why, see
[build-troubleshooting.md](build-troubleshooting.md#2-device-sepolicy-entries-were-silently-dropped).

---

## 4. Configure and build

```bash
cd "$SRC"
export JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64
export USE_CCACHE=1
export CCACHE_EXEC=/usr/bin/ccache
export CCACHE_DIR=$HOME/.ccache/lineage-17.1
ccache -M 30G

source build/envsetup.sh
breakfast lineage_j8y18lte          # or: lunch lineage_j8y18lte-userdebug
```

`breakfast` resolves the dependencies from `lineage.dependencies`
(`android_hardware_samsung`, `android_packages_resources_devicesettings`) and
prints `TARGET_PRODUCT=lineage_j8y18lte`.

Build:

```bash
m -j16 bacon
```

or use the wrapper, which timestamps the log:

```bash
bash <this-repo>/scripts/build.sh        # JOBS=16 by default
```

Memory note: on a 12 GB host, `-j16` works but leaves little headroom. If
`ninja` gets OOM-killed, drop to `-j8`.

### Signing the build with your own keys

The default `m bacon` output is signed with the AOSP **test keys**. To produce
a build signed with your own keys (which is what the installed artifact in
[`../STATUS.md`](../STATUS.md) is):

```bash
m -j8 target-files-package otatools
KEYS=~/secure/j8os-keys ./scripts/sign-ota.sh
```

That runs `sign_target_files_apks` + `ota_from_target_files` and verifies the
OTA certificate matches your release key. Details:
[signing.md](signing.md).

Because the platform signature changes, flashing a re-signed build over another
ROM requires a data wipe.

### Switching SELinux mode

The pinned device tree carries `androidboot.selinux=permissive` in
`BOARD_KERNEL_CMDLINE`. Two artifacts come out of that switch:

```bash
# diagnostic build (what was validated first)
./scripts/set-selinux-mode.sh permissive && m -j16 bacon

# release build (enforcing; needs a policy that survives a cold boot)
./scripts/set-selinux-mode.sh enforcing && m -j16 bacon
```

The mode is baked into the boot image cmdline, so check it after building:

```bash
strings out/target/product/j8y18lte/boot.img | grep -o 'androidboot.selinux=[a-z]*'
```

### Outputs

```text
out/target/product/j8y18lte/
├── boot.img              # kernel + ramdisk        13,064,192 B
├── recovery.img          # Lineage recovery        22,284,288 B
├── system.img            # sparse system image     1,078,473,140 B
├── vendor.img            # sparse vendor image     248,877,228 B
└── lineage-17.1-<date>-UNOFFICIAL-j8y18lte.zip      543,395,513 B
```

A successful run ends with:

```text
Package Complete: out/target/product/j8y18lte/lineage-17.1-<date>-UNOFFICIAL-j8y18lte.zip
#### build completed successfully (… ) ####
```

---

## 5. Disk and time budget

| Item | Size |
|---|---|
| `.repo` (18 GB) + working trees | ~120 GB total |
| `out/` | ~30–40 GB incremental |
| ccache (30 GB cap) | up to 30 GB |
| Logs and artifacts | < 1 GB |

| Phase | Time |
|---|---|
| `repo sync` | 40–120 min (network) |
| First full build (`-j16`) | 1.5–3 h |
| Incremental rebuild after a small change | 1–5 min |

---

## 6. Verifying what you built

```bash
# Identity baked into the build
grep -E 'ro.build.version.(release|sdk)|ro.build.type|ro.build.tags|ro.product.cpu.abilist' \
  out/target/product/j8y18lte/system/build.prop

# Boot image header + cmdline
python3 - <<'EOF'
import struct
d = open('out/target/product/j8y18lte/boot.img','rb').read(2048)
(magic, ksize, kaddr, rsize, raddr, ssize, saddr,
 tags, page, hdr_ver, os_ver) = struct.unpack('<8s10I', d[:48])
cmdline = d[64:576].split(b'\0')[0].decode()
print(magic, 'kernel', ksize, 'ramdisk', rsize, 'page', page)
print('addrs', hex(kaddr), hex(raddr), hex(tags))
print('cmdline:', cmdline)
EOF

# Partition-sized filesystem check
file out/target/product/j8y18lte/system.img
```

`scripts/verify-artifacts.sh` runs these checks against an artifact directory.

---

## 7. Common pitfalls

| Symptom | Cause | Fix |
|---|---|---|
| `repo --version` → `<repo not installed>` | broken launcher | re-download `repo` |
| `breakfast` cannot find the device | `local_manifests` not copied before sync | add them, `repo sync` again |
| Kernel build fails on missing `aarch64-linux-android-gcc` | prebuilt toolchain not synced | confirm `prebuilts/gcc/.../aarch64-linux-android-4.9` exists |
| `webview.apk` is a 133-byte file | Git LFS pointer, not the APK | `repo sync` with LFS, or see [build-troubleshooting.md](build-troubleshooting.md#3-chromium-webview-is-a-git-lfs-pointer) |
| `e2fsdroid ... searching for label "/firmware"` | device sepolicy dir never reached `BOARD_VENDOR_SEPOLICY_DIRS` | apply [`patches/0001`](../patches/0001-BoardConfig-device-sepolicy-path.patch); see [build-troubleshooting.md](build-troubleshooting.md#1-e2fsdroid-fails-on-firmware) |
| `Type 'camera blacklist prop readable to everything' is not valid` | missing trailing newline in `sepolicy/property_contexts` | apply [`patches/0002`](../patches/0002-sepolicy-property-contexts-trailing-newline.patch) |
| A source change appears to have no effect | stale kati graph | `rm -f out/.kati_stamp-* out/build-*.ninja out/combined-*.ninja` |
| `ninja: build stopped` at 99 % on another target | look up the first `error:` in the log, not the last | grep the log |

Both device-tree fixes are applied by
[`../scripts/apply-patches.sh`](../scripts/apply-patches.sh). The validated
build for this repository used exactly that tree; see
[`../STATUS.md`](../STATUS.md) for what it produced and
[`../VALIDATION.md`](../VALIDATION.md) for what it did on the device.
