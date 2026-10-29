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
| `recovery.img` | 22,274,048 | no | no |
| `vendor.img` | 248,783,020 | no | no |
| `system.img` | — | not created | — |
| `vbmeta.img` | — | **does not exist** | — |

Second, independent confirmation: partition images are **not padded to the
board partition sizes**. With AVB, `avbtool add_hash_footer --partition_size N`
pads the image to exactly `N`. Here `boot.img` is 13,064,192 B against a
33,554,432 B partition, and `vendor.img` is 248,783,020 B against 503,316,480 B.

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
   ramdisk has no fstab of its own. How (and whether) `/system` and `/vendor`
   get mounted at normal boot is **unverified** and needs a real boot log.
2. The recovery fstab asks for `forceencrypt=footer` while the kernel has
   `CONFIG_FS_ENCRYPTION` unset — a configuration that cannot work as written.

## 8. SELinux

- The only SELinux setting in the device + vendor trees is
  `androidboot.selinux=permissive` in `BoardConfig.mk`.
- `androidboot.selinux=enforcing` appears nowhere.
- `SELINUX_DEVELOP=y` is set in the kernel config, so the default without a
  cmdline override would be permissive anyway.

Consequence: SELinux denials in `logcat`/`dmesg` on this build are **logged,
not fatal**. They are not the reason a boot hangs. A release build must flip
this to `enforcing` and then fix the real denials, which is a separate body of
work (Samsung HAL domains are the usual suspects).

## 9. What to do about it

| Goal | Action |
|---|---|
| Reproduce this build exactly | change nothing — this is the configured behaviour |
| Add dm-verity | set `PRODUCT_SUPPORTS_VERITY := true`, provide `verity` keys, and expect fstab changes |
| Add AVB | not possible on this kernel without backporting AVB support; the bootloader would also have to accept it |
| Make it enforcing | change the cmdline, build, capture denials, iteratively add policy — and expect boot loops until the policy is complete |

For a bring-up build, the current configuration is the pragmatic one: it
removes a whole class of failure modes from the debugging surface.
