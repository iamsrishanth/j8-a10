<!-- Archived report. Host names, IP addresses, user names, paths and the device serial have been genericised; wording and figures are otherwise unchanged. -->

# J8 OS Handover — 2026-10-26

## 1. Snapshot

- Device: Samsung Galaxy J8, **SM-J810G / j8y18lte**, serial `a7d4xxxx`.
- Recovery: TWRP 3.6.1, working and ADB-accessible.
- Phone battery: **100%** at handover.
- Current installed system: LineageOS 18.1 / Android 11 C0, **non-booting**.
- Current boot image: original C0 **enforcing** boot image.
- Data: formatted; no important user data.
- No working Android system is installed.
- No GApps, KernelSU/root, debloat, tuning, or bootloader changes are installed.

## 2. Immediate status

The Android 11 C0 experiment was stopped. It reached the boot animation under permissive SELinux but `system_server` could not complete because the vendor audio HAL/audio-policy path never published `media.audio_policy`. That work is documented here:

- `C:\Users\user\staging\reports\C0-ANDROID11-VIABILITY.md`
- `C:\Users\user\staging\reports\C0-BOOT-FAILURE.md`

The current task is to produce a usable **LineageOS 17.1 / Android 10** build.

## 3. Android 10 build environment

Use the Windows host `builder` and its WSL distro:

```powershell
ssh builder@build-host
wsl.exe -d Ubuntu-22.04 -- bash
```

WSL was repaired during this session by enabling `Microsoft-Windows-Subsystem-Linux` and rebooting Windows. It now starts normally.

- Source tree: `/home/builder/android/lineage-17.1`
- Source size: 111 GB
- WSL filesystem: about **827 GB free**
- Windows D: free space: about **170 GB**
- WSL VHDX: `D:\wsl\ubuntu\ext4.vhdx`, compacted to about 131 GB.
- Android 11 source tree `/home/builder/android/lineage-18.1` was deleted (173 GB).

Build pins in `.repo/local_manifests/j8y18lte.xml`:

- Device: `goldfish07/android_device_samsung_j8y18lte` @ `1b4f25eff98554feac5c0ab945c70be6589c3693`
- Kernel: `goldfish07/android_kernel_samsung_j8y18lte` @ `3a7e80328b108097e984c028c0fd1f9e65678e31`
- Vendor: `goldfish07/android_vendor_samsung_j8y18lte` @ `ca797aa33d3e786613cc86440f1b00b32bbf7d43`

Build command:

```bash
wsl.exe -d Ubuntu-22.04 -- bash /mnt/d/j8-os/scripts/build-17.1-j16.sh
```

The script runs `lunch lineage_j8y18lte-userdebug` and `m -j16 bacon`, logging to `/mnt/d/j8-os/logs/`.

## 4. Current build blocker

Latest log:

`/mnt/d/j8-os/logs/build-17.1-j16-20261026-005040.log`

The build reaches system-image creation, then `e2fsdroid` fails while applying SELinux contexts:

```text
set_selinux_xattr: No such file or directory searching for label "/config/.keep"
set_selinux_xattr: Inappropriate ioctl for device searching for label "/omr"
e2fsdroid: File too large while configuring the file system
loaded 3654 fs_config entries
```

There is **no OTA ZIP yet**:

`out/target/product/j8y18lte/lineage-17.1-*.zip` does not exist.

This is a root-directory / `file_contexts` / `fs_config` problem in the 17.1 device tree, not a compiler, signing, or disk-space problem. The build previously failed on `/firmware`, then `/omr`, then `/config/.keep`.

## 5. Source changes made while debugging

These changes are **not all backed up**. Restore or review before continuing.

### Backed up

- `device/samsung/j8y18lte/config.fs`
  - Backup: `config.fs.orig`
  - Change: removed the `[firmware/]` block.
- `device/qcom/sepolicy-legacy/common/file_contexts`
  - Backup: `file_contexts.orig`
  - Change: removed the `/firmware(/.*)?` label line.

### Not backed up

- `device/samsung/j8y18lte/BoardConfig.mk`
  - Removed the line:
    `/vendor/firmware_mnt:/firmware \`
  - Original line is known and can be re-added.
- `device/samsung/j8y18lte/sepolicy/file_contexts`
  - Removed the line:
    `/omr(/.*)?         u:object_r:omr_file:s0`
  - No `.orig` copy was made.
- `external/chromium-webview/prebuilt/arm/webview.apk`
  - Originally a 133-byte Git LFS pointer.
  - Replaced with a valid 51 MB APK from a GitHub LFS clone at `/home/builder/webview`.
  - No backup of the pointer was made.

### Ephemeral `out/` changes

Directories and `.keep` files were created under:

- `out/target/product/j8y18lte/system/{firmware,omr,efs,config,dsp,persist}`
- `out/target/product/j8y18lte/root/{omr,efs,config,dsp,persist}`

These are build-output workarounds, not source changes.

## 6. Recommended clean fix

The clean approach is to restore the original device-tree files and fix the root directory creation properly:

1. Restore `config.fs.orig`.
2. Restore `file_contexts.orig` for the qcom legacy tree.
3. Re-add the `/vendor/firmware_mnt:/firmware` entry to `BoardConfig.mk`.
4. Re-add the `/omr` label to `device/samsung/j8y18lte/sepolicy/file_contexts`.
5. Compare this 17.1 device tree against the known-good 18.1 tree or another working 17.1 build for root-folder/symlink handling.
6. Ensure `BOARD_ROOT_EXTRA_FOLDERS` and `BOARD_ROOT_EXTRA_SYMLINKS` are actually populated in `out/target/product/j8y18lte/root` before system-image creation.
7. Run `m -j16 bacon` again.

Do **not** keep deleting `file_contexts` lines as the primary fix; that can leave the final image with missing runtime labels.

## 7. Signing keys

Project release keys are on the build host:

`/home/builder/secure/j8os-keys/`

Contains `releasekey`, `platform`, `shared`, `media`, `verity`, `networkstack`, `nfc`, and related `.pk8`/`.x509.pem` files.

No private key material is reproduced in this handover. Do not copy the keys into the phone image or repository.

## 8. Phone recovery / reboot

TWRP is reachable by ADB as `recovery`.

Useful commands from the Windows controller:

```powershell
adb devices -l
adb -s a7d4xxxx reboot recovery
```

TWRP shell reboot that works:

```sh
twrp reboot system
```

`adb reboot` and `/sbin/reboot` did **not** reliably leave recovery in this session; use the `twrp` CLI.

TWRP backups and originals on `/sdcard` include:

- `/sdcard/boot-full.img` — original full boot partition backup
- `/sdcard/boot-permissive.img` — permissive diagnostic boot
- `/sdcard/misc-backup.img`
- `/sdcard/services-orig/` — original Android 11 `services.jar` and oat files
- `/sdcard/audioserver.orig`, `/sdcard/audioserver.rc.orig`
- `/sdcard/android.hardware.audio.service.orig`, `.rc.orig`
- `/sdcard/audio.primary.msm8953.so.orig`
- `/sdcard/audio_policy_configuration.xml.orig`
- `/sdcard/j8os-18.1-C0-20261024-signed-ota.zip` — C0 Android 11 OTA

The C0 signed OTA was also moved to the Windows host at:

`C:\Users\builder\j8-os-artifacts\j8os-18.1-C0-20261024-signed-ota.zip`

## 9. Installing the Android 10 build

When an OTA exists:

1. Verify the ZIP and its hash.
2. Push it to `/sdcard`.
3. In TWRP, install the ZIP (or use the `twrp install` CLI).
4. Format data because the current data is from Android 11.
5. Reboot to system.
6. Validate display/touch, Wi-Fi, RIL, audio, camera, storage, charging, and SELinux state.

The OTA should write boot/system/vendor only; TWRP recovery is separate.

## 10. Fallback prebuilt

A prebuilt LineageOS 17.1 ZIP exists at SourceForge:

`https://sourceforge.net/projects/samsung-j8y18lte/files/CustomRom/Lineage/17.1/lineage-17.1-20240124-UNOFFICIAL-j8y18lte.zip/download`

Scripted downloads from this environment returned HTTP 403. A normal browser download is required if this fallback is used. It is not signed with the project release keys.

## 11. Constraints

Do not add any of the following without a new explicit approval:

- GApps
- KernelSU or any root solution
- Debloat
- Tuning
- Bootloader changes

Keep TWRP intact.

## 12. Key artifacts / hashes

- TWRP image: `1b6538d566fd0a0c622ca2e78dedeb1b86a3dbf5f9199e9575ef67de0efd6e05`
- Original full boot backup: `157ea74df6467ddafbd7d48b78a1ad56a67826391d35a987619eaa12131f9ed8`
- C0 permissive boot: `7e08ae6843f5d3c17f64edde671cbce45ff6b1dd78f3b2cf99c9f665825e44d3`
- C0 signed OTA: `50ed8c4a7e3e7b48252172451bb06889bad2b19e55d08b2f73bc86c4681162b5`
- C0 boot image: `39f8c74438cd61906b3c9c961f33ae92266cea15616f33ec0e3028f6a3c3c366`

The C0 signed target-files ZIP was deleted to free D: space; the signed OTA remains in the phone's `/sdcard` and at `C:\Users\builder\j8-os-artifacts\` on the Windows host.

## 13. Next action

Resolve the 17.1 root-directory/context mismatch, finish `m bacon`, sign the OTA with `/home/builder/secure/j8os-keys/`, and install through TWRP.
