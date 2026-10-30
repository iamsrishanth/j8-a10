<!-- Archived report. Host names, IP addresses, user names, paths, the device serial and MAC addresses have been genericised; wording and figures are otherwise unchanged. -->

# Android 10 / LineageOS 17.1 — Build Fix

Date: 2026-10-30
Host: WSL2 Ubuntu 22.04 on `build-host`, tree `/home/builder/android/lineage-17.1`
Product: `lineage_j8y18lte-userdebug` · `LINEAGE_VERSION=17.1-20261029-UNOFFICIAL-j8y18lte`
Android: 10 (`QQ3A.200805.001`)

## 1. Symptom (reproduced from clean sources)

```
set_selinux_xattr: No such file or directory searching for label "/firmware"
e2fsdroid: No such file or directory while configuring the file system
ninja: build stopped: subcommand failed.      # target: systemimage
```

Reproduced on 2026-10-30 04:34 with **pristine** sources (device tree at pin
`1b4f25eff98554feac5c0ab945c70be6589c3693`, `git status` clean except an untracked
`config.fs.orig`). So the failure was never caused by the earlier debugging edits.

## 2. Root cause

`m systemimage` labels the image with
`out/target/product/j8y18lte/obj/ETC/file_contexts.bin_intermediates/file_contexts.bin`.
That file is built by `system/sepolicy/Android.mk` from:

* plat contexts (`system/sepolicy/{public,private}`), and
* **`build_vendor_policy`, which reads `BOARD_VENDOR_SEPOLICY_DIRS`** (`system/sepolicy/Android.mk:121,1125`).

The device tree only set the legacy variable:

```make
# device/samsung/j8y18lte/BoardConfig.mk:235 (original)
BOARD_SEPOLICY_DIRS += $(LOCAL_PATH)/sepolicy
```

Android 10's compatibility shim copies `BOARD_SEPOLICY_DIRS` into
`BOARD_VENDOR_SEPOLICY_DIRS` at parse time (`system/sepolicy/Android.mk:99-101`), **but in this
tree the value appended for the device was wrong**: `$(LOCAL_PATH)` was clobbered in the decisive
parse pass, so the shim received `system/sepolicy/sepolicy` instead of
`device/samsung/j8y18lte/sepolicy`.

Instrumented evidence (makefile `$(warning)`, then reverted):

```
J8D_VENDOR=[system/sepolicy/sepolicy device/qcom/sepolicy-legacy-um/vendor/common …
            device/lineage/sepolicy/common/vendor]
J8D_WILD=[device/samsung/j8y18lte/sepolicy/file_contexts]     # file exists
J8D_SAM=[]                                                     # but is not in the list
```

Consequence: **every j8y18lte context entry was silently dropped** — `/firmware`, `/omr`,
`/efs`, `/config`, `sec_efsblk_device`, block-device nodes, and the device service domains.
`e2fsdroid` then failed on the first unlabeled path it met and aborted image creation.

This also explains the previous agent's confusing sequence `/firmware` → `/omr` →
`/config/.keep`: they were deleting/adding labels to chase paths that were never labelled in the
first place, and the shift in which path failed first depended on which workaround was active.

## 3. Fix (minimal, source-level)

```diff
--- a/device/samsung/j8y18lte/BoardConfig.mk
+++ b/device/samsung/j8y18lte/BoardConfig.mk
@@
 include device/qcom/sepolicy-legacy-um/sepolicy.mk
-BOARD_SEPOLICY_DIRS += $(LOCAL_PATH)/sepolicy
+BOARD_SEPOLICY_DIRS += device/samsung/j8y18lte/sepolicy
@@ end of file
-WIFI_HIDL_FEATURE_DISABLE_AP_MAC_RANDOMIZATION := true
\ No newline at end of file
+WIFI_HIDL_FEATURE_DISABLE_AP_MAC_RANDOMIZATION := true
```

```diff
--- a/device/samsung/j8y18lte/sepolicy/property_contexts
+++ b/device/samsung/j8y18lte/sepolicy/property_contexts
@@
-vendor.sys.qseecomd.enable             u:object_r:vendor_default_prop:s0
\ No newline at end of file
+vendor.sys.qseecomd.enable             u:object_r:vendor_default_prop:s0
```

Why the literal path: `$(LOCAL_PATH)` is unreliable in this BoardConfig — the qcom/lineage
sepolicy fragments included at `BoardConfig.mk:234` leave it pointing elsewhere in one of the
build's evaluation passes. Using the literal device path removes the ambiguity, and because the
entry lands **last** in `BOARD_SEPOLICY_DIRS`, the shim appends it last in
`BOARD_VENDOR_SEPOLICY_DIRS`, which preserves qcom-before-device ordering.

The trailing newline in `property_contexts` matters: the merged vendor contexts are concatenated
without an automatic newline between files in this branch, so the final line of the device file
was glued to the next file's first comment, producing

```
vendor.sys.qseecomd.enable …:s0# Aux camera blacklist prop readable to everything
```

and `property_info_checker` refused to serialise the result.

### Two intermediate experiments (rejected, kept for the record)

1. `BOARD_VENDOR_SEPOLICY_DIRS += $(BOARD_SEPOLICY_DIRS)` — appended *all* dirs a second time →
   `Multiple same specifications for /dev/…` in `vendor_file_contexts`. Rejected.
2. Appending only the device dir to `BOARD_VENDOR_SEPOLICY_DIRS` at BoardConfig time — correct
   content, but places the device dir **before** qcom policy, so
   `hal_gnss_qti.te:11: ERROR 'unknown type hal_gnss_qti'` (type declared later in the
   concatenation, and `checkpolicy` requires declaration before use). Rejected.

A stale kati graph also masked the fix for one cycle; forcing regeneration
(`rm -f out/.kati_stamp-* out/build-*.ninja out/combined-*.ninja`) was required once.

## 4. Verification

Context merge (after fix):

```
file_contexts.device.tmp:  ^/omr 1   ^/firmware 1
```

Built image `out/target/product/j8y18lte/system.img`,
sha256 `e3cecf2b21494595b1441034d698eb239038f145b041c0e317df4a0a2a1a3742`
(sparse 1,078,473,140 B; raw 3,397,386,240 B), verified with `debugfs ea_list`:

| path | label |
|---|---|
| `/firmware` (symlink) | `u:object_r:firmware_file:s0` |
| `/omr` | `u:object_r:omr_file:s0` |
| `/config` | `u:object_r:rootfs:s0` |
| `/efs` | `u:object_r:efs_file:s0` |
| `/system/bin/logd` | `u:object_r:logd_exec:s0` |
| `/system/bin/init` | `u:object_r:init_exec:s0` |

The previous manual image labelled everything `u:object_r:rootfs:s0`; this is the first
correctly-labelled image for this device.

## 5. Artifact manifest (current)

| Artifact | Bytes | SHA-256 |
|---|---:|---|
| `system.img` (sparse) | 1,078,473,140 | `e3cecf2b21494595b1441034d698eb239038f145b041c0e317df4a0a2a1a3742` |
| `boot.img` (permissive diagnostic) | 13,064,192 | `b335f5611d2329dfad1df6182d8bce7606ac85b6a0be07c2a704a7e57afcffe3` |
| `vendor.img` | 248,783,020 | `4d7ce4cf6ecc92c8d72ad1112e41a307170c2bb9af46b640e27bd98f9c4a825c` |
| `recovery.img` | 22,284,288 | (built from boot; TWRP stays in the recovery partition) |

Diagnostic images from 2026-10-26 are preserved untouched under
`C:\Users\user\staging\android10-images\` with their original hashes
(`b335f561…`, `d071d4b8…`, `11aab794…`).

## 6. Still to do on the build

- `m bacon` → target-files + OTA ZIP (running).
- Sign with `/home/builder/secure/j8os-keys/` via
  `sign_target_files_apks` + `ota_from_target_files` (same tooling as the C0 flow).
- Remove `androidboot.selinux=permissive` from `BOARD_KERNEL_CMDLINE` for the release build and
  re-verify enforcing boot. The diagnostic build keeps it permissive on purpose.
