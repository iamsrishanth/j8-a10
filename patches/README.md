# Patches

Local changes applied on top of the pinned device tree. Apply them with
[`../scripts/apply-patches.sh`](../scripts/apply-patches.sh), which is
idempotent and refuses to guess when the tree is in an unexpected state.

| Patch | File | Effect |
|---|---|---|
| `0001-BoardConfig-device-sepolicy-path.patch` | `BoardConfig.mk` | Registers the device's sepolicy directory by a literal path (`device/samsung/j8y18lte/sepolicy`) instead of `$(LOCAL_PATH)/sepolicy`, and adds the missing final newline |
| `0002-sepolicy-property-contexts-trailing-newline.patch` | `sepolicy/property_contexts` | Adds the missing final newline that corrupted the merged policy file |
| `0003-BoardConfig-selinux-enforcing-cmdline.patch` | `BoardConfig.mk` | Drops `androidboot.selinux=permissive` from the kernel cmdline (release / enforcing build) |

Patches 1 and 2 are **required for the ROM to build at all**. Patch 3 is a
policy choice: without it the build boots permissive, which is what was
validated first. Toggle it with
[`../scripts/set-selinux-mode.sh`](../scripts/set-selinux-mode.sh).

## Why these matter

**0001 — explicit sepolicy path.** `m systemimage` labels the image with
`file_contexts.bin`, which `build_vendor_policy()` generates from
`BOARD_VENDOR_SEPOLICY_DIRS`. The pinned tree only set `BOARD_SEPOLICY_DIRS`
using `$(LOCAL_PATH)`; in the decisive parse pass that variable had already
been rewritten, so the entry became `system/sepolicy/sepolicy` and the device's
own policy directory never reached the merge. Every device context — `/firmware`,
`/omr`, `/efs`, the `mmcblk` block devices, the vendor service domains — was
dropped, and `e2fsdroid` aborted with:

```text
set_selinux_xattr: No such file or directory searching for label "/firmware"
```

**0002 — trailing newline.** The policy build concatenates every
`property_contexts` through `cpp`. Without a final newline, this file's last
rule is glued to the next file's first line:

```text
vendor.sys.qseecomd.enable  u:object_r:vendor_default_prop:s0# Aux camera blacklist prop readable to everything
```

and `vendor_property_contexts` fails its check with
`Type 'camera blacklist prop readable to everything' is not valid`.

**0003 — SELinux mode.** The cmdline is baked into `boot.img`, so this is a
build-time choice, not a runtime property. Removing the `permissive` argument
lets the kernel default to enforcing; that behaviour still has to be verified
with `getenforce` after a cold boot.

All three are analysed in
[`../docs/build-troubleshooting.md`](../docs/build-troubleshooting.md) and
[`../docs/integrity.md`](../docs/integrity.md).

## Applying

```bash
SRC=~/android/lineage-17.1 ./scripts/apply-patches.sh
```

or manually, inside the device tree:

```bash
cd ~/android/lineage-17.1/device/samsung/j8y18lte
git apply --check ../../../../patches/0001-*.patch   # dry run
git apply ../../../../patches/0001-*.patch
```

## Generating a new patch

```bash
cd ~/android/lineage-17.1/device/samsung/j8y18lte
# ... make and test your change ...
git format-patch -1 --stdout > ../../patches/000N-short-name.patch
```

State in the patch message **how it was tested**. "It compiles" is not a test
if the failure it fixes happens at runtime.
