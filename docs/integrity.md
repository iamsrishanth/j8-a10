# Boot integrity on this build: AVB, dm-verity, SELinux

Short version: **this device tree produces an image with no verified-boot
chain at all.** No AVB, no dm-verity, no vbmeta. SELinux is permissive. That
is not a bug to chase — it is the configuration, and it is why a boot failure
on this build must be diagnosed from somewhere other than "verity rejected
the image".

All findings below were verified against the pinned tree and the built images.

## 1. Summary table

| Question | Verdict | Decisive evidence |
|---|---|---|
| AVB (Android Verified Boot) | **OFF** | `BOARD_AVB_ENABLE` never defined; no `avb_*` keys in `misc_info.txt`; no `vbmeta*.img`; no `AVBf` footer on any image; kernel has no AVB support |
| dm-verity (classic) | **OFF at build time** | `PRODUCT_SUPPORTS_VERITY` never set → no `verity=` key in `misc_info.txt`, no hash tree appended |
| system-as-root (legacy) | **NO** (`BOARD_BUILD_SYSTEM_ROOT_IMAGE` unset) | a real first-stage `/init` binary lives in the boot ramdisk |
| SELinux | **permissive** | `androidboot.selinux=permissive` in `BoardConfig.mk` **and** byte-for-byte inside the built `boot.img` |
| File-based encryption | **off / unsupported** | normal-boot fstab has no `forceencrypt`/`fileencryption`; kernel `CONFIG_FS_ENCRYPTION` unset |

## 2. BoardConfig variables

`device/samsung/j8y18lte/BoardConfig.mk` includes only:

- `-include vendor/samsung/j8y18lte/BoardConfigVendor.mk` (generated stub, no variables)
- `include device/qcom/sepolicy-legacy-um/sepolicy.mk` (no verity/AVB content)

There is no `BoardConfigCommon.mk`, no `device/qcom/msm8953` common config, and
`vendor/lineage/config/BoardConfigLineage.mk` sets nothing relevant.

| Variable | Value |
|---|---|
| `BOARD_AVB_ENABLE` | not set |
| `BOARD_AVB_KEY_PATH`, `BOARD_AVB_ALGORITHM` | not set |
| `BOARD_DM_VERITY*` | not set |
| `PRODUCT_SUPPORTS_VERITY` | not set |
| `BOARD_BUILD_SYSTEM_ROOT_IMAGE` | not set (⇒ false) |
| `BOARD_VNDK_VERSION` | `current` |
| `BOARD_VNDK_RUNTIME_DISABLE` | `true` |

Every AVB code path in `build/make` is gated on the literal string `true`, and
there is no default assignment for `BOARD_AVB_ENABLE`. "Not set" therefore
means "off", not "default on".

## 3. What the build actually writes

`misc_info.txt` for this build contains these keys:

```text
recovery_api_version fstab_version blocksize boot_size recovery_size
recovery_mount_options tool_extensions default_system_dev_certificate
extra_recovery_keys mkbootimg_args mkbootimg_version_args use_set_metadata
multistage_support blockimgdiff_versions system_size userdata_size
cache_fs_type cache_size vendor_fs_type vendor_size ext_mkuserimg fs_type
extfs_sparse_flag squashfs_sparse_flag selinux_fc root_dir ota_override_device
lpmake super_metadata_device
```

No `avb_enable`, no `avb_avbtool`, no `verity=`, no `verity_key=`, no
`verity_signer_cmd=`, no `system_root_image`. That is conclusive: releasetools
has nothing to sign with.

## 4. Built images — byte-level checks

| Image | Bytes | AVB footer (`AVBf` in last 4 KiB) | `AVB0` at offset 0 |
|---|---:|---|---|
| `boot.img` | 13,064,192 | no | no |
| `recovery.img` | 22,284,288 | no | no |
| `vendor.img` | 248,877,228 sparse → 503,316,480 raw | no | no |
| `system.img` | 1,078,473,140 sparse | (sparse container) | no |
| `vbmeta.img` | — | **does not exist** | — |

Decisive evidence, strongest first:

1. **`misc_info.txt` has no `avb_*`, no `verity=` and no `system_root_image`
   key.** Releasetools is data-driven from that file; with those keys absent
   there is nothing to sign and no verification metadata to generate.
2. **No `vbmeta*.img` exists** in the product output.
3. **No AVB footer on the images.** Unpacking the sparse `vendor.img` yields
   exactly 503,316,480 B of valid ext4 (partition size) with no `AVBf` in its
   last 4 KiB; `boot.img` has none either. With AVB,
   `avbtool add_hash_footer --partition_size N` pads and appends a footer.

(Image sizes change between builds; the assertions above were re-checked
against the artifacts listed in
[`../artifacts/MANIFEST.md`](../artifacts/MANIFEST.md).)

## 5. Boot image internals

```text
magic        ANDROID!
header       legacy v0
page_size    2048
kernel_size  12,297,618
ramdisk_size 762,577
kernel_addr  0x80008000
ramdisk_addr 0x82000000
tags_addr    0x81e00000
cmdline      console=null androidboot.hardware=qcom msm_rtb.filter=0x237
             ehci-hcd.park=3 androidboot.bootdevice=7824900.sdhci
             lpm_levels.sleep_disabled=1 androidboot.selinux=permissive
             buildvariant=userdebug
```

The **enforcing** image is byte-identical apart from the cmdline:

```text
console=null androidboot.hardware=qcom msm_rtb.filter=0x237 ehci-hcd.park=3
androidboot.bootdevice=7824900.sdhci lpm_levels.sleep_disabled=1 buildvariant=userdebug
```

(`sha256` of the permissive boot: `b335f561…ffe3`; enforcing:
`fc23372e…a8e54`. Same kernel and ramdisk — only the cmdline string differs.)

The boot ramdisk contains 7 entries (`apex/ debug_ramdisk/ dev/ init mnt/ proc/
sys/`) and a 1.37 MB statically linked first-stage `init`. **There is no fstab
in the boot ramdisk.** The runtime fstab lives at `/vendor/etc/fstab.qcom`.

## 6. Kernel capability

| Symbol | State |
|---|---|
| `CONFIG_DM_VERITY` | `y` |
| `CONFIG_DM_VERITY_FEC` | not set |
| `CONFIG_DM_VERITY_AVB` | **symbol does not exist** in this 3.18 Kconfig |
| `CONFIG_ANDROID_VERIFIED_BOOT` | **symbol does not exist** |
| `CONFIG_SECURITY_SELINUX` | `y` |
| `CONFIG_SECURITY_SELINUX_DEVELOP` | `y` |
| `CONFIG_SECURITY_SELINUX_ALWAYS_ENFORCE` | not present |
| `CONFIG_FS_ENCRYPTION` | not set |

This kernel could not validate a vbmeta image even if one were generated. It
does have classic dm-verity as a capability, but nothing builds a hash tree for
it to consume.

## 7. The two fstabs, and what they imply

`vendor/etc/fstab.qcom` (normal boot):

| Partition | Flags | Note |
|---|---|---|
| `/system` | `ro,barrier=1,discard wait,recoveryonly` | `recoveryonly` ⇒ fs_mgr skips it at normal boot |
| `/data` | `…,errors=panic wait,check,reservedsize=128M` | no encryption |
| `/cache` | `… wait,check` | — |
| `/vendor` | **no entry at all** | — |

`rootdir/fstab.recovery.qcom` (`TARGET_RECOVERY_FSTAB`):

| Partition | Flags | Note |
|---|---|---|
| `/system` | `… wait,slotselect,verify` | `verify` present, but no verity metadata exists |
| `/data` | `… wait,check,forceencrypt=footer,quota,reservedsize=128M` | `forceencrypt` cannot succeed: kernel has no FS encryption |
| `/vendor` | `ro wait,recoveryonly` | — |

Two structural oddities worth knowing before debugging a boot failure:

1. `/system` is marked `recoveryonly` in the normal-boot fstab, and the boot
   ramdisk has no fstab of its own. **Resolved in practice:** the device boots
   (system-as-root; `/init` links to `/system/bin/init`), so fs_mgr finds the
   vendor fstab after `/vendor` is mounted. It is worth knowing because a
   *flat* image — one without the nested `/system` tree — fails exactly here
   and loops `logd` at exit 255.
2. The recovery fstab asks for `forceencrypt=footer` while the kernel has
   `CONFIG_FS_ENCRYPTION` unset — a configuration that cannot work as written.
   The normal-boot fstab requests no encryption, and `/data` is indeed
   unencrypted.

## 8. SELinux

There are **two** boot images in this project, identical apart from one
kernel-cmdline word:

| Build | `androidboot.selinux` | Status |
|---|---|---|
| Permissive (diagnostic) | `permissive` | installed and validated — [VALIDATION.md](../VALIDATION.md) |
| Enforcing (release candidate) | *(absent ⇒ enforcing)* | built, signed, not yet flashed |

`androidboot.selinux=enforcing` is not written explicitly; the enforcing image
simply **omits** the `permissive` argument, so the kernel uses its default.
`SELINUX_DEVELOP=y` is set in the kernel config, which makes that default
permissive unless the policy is loaded as enforcing — so the boot must be
verified with `getenforce`, not assumed.

### What was measured on the device

- Permissive build: ~530 AVC denials per boot, all logged and none fatal —
  mostly `flags_health_check` property reads (445), plus `main`/zygote,
  `health@2.0-service`, `init.qcom.post_boot` and `healthd`.
- Runtime `setenforce 1` on the running permissive build **held for 5+ hours**
  with the UI, adb, Wi-Fi and `sys.boot_completed=1` intact. Under enforcing,
  the only denials were `healthd` reading battery sysfs
  (`/sys/class/power_supply/battery/*`, labelled `sysfs` instead of
  `sysfs_batteryinfo`) and `kernel` reading `hall_detect`.
- The built image itself carries correct labels: `/firmware` → `firmware_file`,
  `/omr` → `omr_file`, `/efs` → `efs_file`, `/config` → `rootfs`,
  `/system/bin/init` → `init_exec`, `/system/bin/logd` → `logd_exec`.

The clean `init`/`vold`/`servicemanager` domains show no denials, which is why
an enforcing cold boot is expected to work — but it has **not been proven
yet**, and this document does not claim otherwise.

Denial breakdown: [`../evidence/2026-10-30-first-boot/avc-denials-summary.txt`](../evidence/2026-10-30-first-boot/avc-denials-summary.txt).

## 9. What to do about it

| Goal | Action |
|---|---|
| Reproduce the validated build | `scripts/set-selinux-mode.sh permissive`, build, sign |
| Produce the enforcing candidate | `scripts/set-selinux-mode.sh enforcing`, build, sign, flash, confirm `getenforce` |
| Add dm-verity | set `PRODUCT_SUPPORTS_VERITY := true`, provide `verity` keys, expect fstab changes |
| Add AVB | not possible on this kernel without backporting AVB support; the bootloader would also have to accept it |

For bring-up, permissive first is the pragmatic order: it removes a whole class
of failure modes from the debugging surface. It is not a shipping
configuration.
