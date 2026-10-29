# Patches

Local changes applied on top of the pinned device tree. Apply them with
[`../scripts/apply-patches.sh`](../scripts/apply-patches.sh), which is
idempotent and refuses to guess when the tree is in an unexpected state.

| Patch | File | Effect |
|---|---|---|
| `0001-BoardConfig-explicit-sepolicy-path.patch` | `BoardConfig.mk` | Registers the device's sepolicy directory by an explicit path (`device/samsung/j8y18lte/sepolicy`) instead of `$(LOCAL_PATH)/sepolicy`, and adds the missing final newline |
| `0002-sepolicy-property-contexts-trailing-newline.patch` | `sepolicy/property_contexts` | Adds the missing final newline that corrupted the merged policy file |

## Why these two matter

**0001 — explicit sepolicy path.** Android 10 merges every `BOARD_SEPOLICY_DIRS`
entry into the file contexts used for the system image. `$(LOCAL_PATH)` is an
`Android.mk` variable; depending on include order in `BoardConfig.mk` it can be
unset, which silently drops the device's own `file_contexts` (the entries for
`/firmware`, `/omr`, the `mmcblk` block devices and the Samsung HAL binaries)
from the merge. When that happens, `e2fsdroid` fails with
`set_selinux_xattr: … searching for label "/firmware"` — `selabel_lookup()`
found no rule at all.

**0002 — trailing newline.** The policy build concatenates every
`property_contexts` through `cpp`. Without a final newline, the last rule of
this file is joined to the first line of the next file, producing a line like

```text
vendor.sys.qseecomd.enable  u:object_r:vendor_default_prop:s0# Aux camera blacklist prop readable to everything
```

and `vendor_property_contexts` fails its validation with a confusing
"Type 'camera blacklist prop readable to everything' is not valid".

Both failures are analysed in
[`../docs/build-troubleshooting.md`](../docs/build-troubleshooting.md).

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
