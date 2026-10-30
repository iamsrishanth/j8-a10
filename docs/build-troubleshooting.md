# Build troubleshooting

Failures actually hit while building Android 10 for `j8y18lte`, in the order
they appeared, with the fix that resolved each one.

---

## 1. `e2fsdroid` fails on `/firmware` (resolved)

### Symptom

```text
mkuserimg_mke2fs.py INFO: Running: e2fsdroid -p out/target/product/j8y18lte/system \
  -S out/target/product/j8y18lte/obj/ETC/file_contexts.bin_intermediates/file_contexts.bin \
  -f ... -a / .../system.img
mkuserimg_mke2fs.py ERROR: Failed to run e2fsdroid_cmd:
  set_selinux_xattr: No such file or directory searching for label "/firmware"
e2fsdroid: No such file or directory while configuring the file system
```

Variants of the same failure appeared at different times with `/omr` and
`/config/.keep` instead of `/firmware`.

### What the message actually means

It is **not** a missing file. The message is produced by
`set_selinux_xattr()` in `external/e2fsprogs/contrib/android/perms.c`:

```c
retval = selabel_lookup(params->sehnd, &secontext, params->filename, inode.i_mode);
if (retval < 0) {
    int saved_errno = errno;
    com_err(__func__, errno,
        _("searching for label \"%s\""), params->filename);
```

`selabel_lookup()` returns `-1`/`ENOENT` when **no rule in the compiled
`file_contexts.bin` matches the path**. So e2fsdroid is walking an entry named
`/firmware` in the system image source tree and cannot find a label for it.

### Root cause

`m systemimage` labels the image with
`out/target/product/j8y18lte/obj/ETC/file_contexts.bin_intermediates/file_contexts.bin`.
That file is built by `system/sepolicy/Android.mk` from the platform contexts
plus **`build_vendor_policy`, which reads `BOARD_VENDOR_SEPOLICY_DIRS`**.

The device tree only set the legacy variable:

```make
# device/samsung/j8y18lte/BoardConfig.mk (pinned state)
BOARD_SEPOLICY_DIRS += $(LOCAL_PATH)/sepolicy
```

Android 10's compatibility shim copies `BOARD_SEPOLICY_DIRS` into
`BOARD_VENDOR_SEPOLICY_DIRS` at parse time — **but the value it received was
wrong**. In the decisive parse pass `$(LOCAL_PATH)` had already been clobbered,
so the entry became `system/sepolicy/sepolicy` instead of the device's own
directory.

Instrumented evidence (temporary `$(warning)` lines, since removed):

```text
J8D_VENDOR=[system/sepolicy/sepolicy device/qcom/sepolicy-legacy-um/vendor/common …
            device/lineage/sepolicy/common/vendor]
J8D_WILD=[device/samsung/j8y18lte/sepolicy/file_contexts]     # the file exists
J8D_SAM=[]                                                     # but is not in the list
```

Consequence: **every `j8y18lte` context entry was silently dropped** from the
image — `/firmware`, `/omr`, `/efs`, `/config`, the `mmcblk` block devices and
the device's own service domains. `e2fsdroid` then failed on the first
unlabelled path it met and aborted image creation.

That also explains the confusing earlier sequence of failures (`/firmware` →
`/omr` → `/config/.keep`): those reports were chasing paths that had never been
labelled in the first place, and which one failed first depended on which
workaround was active at the time.

`/firmware` itself is a **runtime** path: `rootdir/fstab.qcom` mounts the vfat
`apnhlos` partition at `/vendor/firmware_mnt` with
`context=u:object_r:firmware_file:s0`. The device's `sepolicy/file_contexts`
labels it (`/firmware(/.*)?  u:object_r:firmware_file:s0`) — but only if that
directory reaches the merge.

### Fix

Use the literal path, and keep it **last** in the list so the qcom fragments
still contribute their type declarations before device policy uses them:

```diff
-BOARD_SEPOLICY_DIRS += $(LOCAL_PATH)/sepolicy
+BOARD_SEPOLICY_DIRS += device/samsung/j8y18lte/sepolicy
```

Plus the trailing-newline fix from §2 — both are in
[`../patches/`](../patches/).

Verify the merge and the image:

```bash
grep -c . out/target/product/j8y18lte/obj/ETC/file_contexts.bin_intermediates/file_contexts.device.tmp
grep -E '\^/(firmware|omr)' out/target/product/j8y18lte/obj/ETC/file_contexts.bin_intermediates/file_contexts.device.tmp

# after a successful systemimage:
debugfs -R 'ea_list /firmware' out/target/product/j8y18lte/system.img | grep -i selinux
```

Expected labels in the finished image: `/firmware` → `firmware_file`,
`/omr` → `omr_file`, `/efs` → `efs_file`, `/config` → `rootfs`,
`/system/bin/init` → `init_exec`, `/system/bin/logd` → `logd_exec`.

### Two rejected attempts (kept for the record)

1. `BOARD_VENDOR_SEPOLICY_DIRS += $(BOARD_SEPOLICY_DIRS)` — appends every
   directory a second time → `Multiple same specifications for /dev/…` in
   `vendor_file_contexts`.
2. Appending only the device directory to `BOARD_VENDOR_SEPOLICY_DIRS` at
   BoardConfig time — correct content, but places the device directory
   **before** the qcom policy, so `checkpolicy` fails on
   `hal_gnss_qti.te:11: ERROR 'unknown type hal_gnss_qti'` (declaration order
   matters).

### Stale kati graph

A stale `kati` state masked the fix for one cycle. If a source change appears
to have no effect on the build, force regeneration:

```bash
rm -f out/.kati_stamp-* out/build-*.ninja out/combined-*.ninja
```

### The wrong fix, for the record

Do **not** delete lines from `config.fs`, `sepolicy/file_contexts` or
`device/qcom/sepolicy-legacy/common/file_contexts` to make the build pass.
That produces an image that builds and then mislabels runtime paths — a much
harder failure to debug than the build error you started with. An earlier
attempt did exactly this; the edits were reverted from git.

---

## 2. `vendor_property_contexts` check fails — "Type 'camera blacklist prop readable to everything' is not valid" (resolved)

### Symptom

```text
FAILED: out/target/product/j8y18lte/obj/ETC/vendor_property_contexts_intermediates/vendor_property_contexts
Could not read line from '.../vendor_property_contexts':
  Type 'camera blacklist prop readable to everything' is not valid
```

### Cause

`device/samsung/j8y18lte/sepolicy/property_contexts` ended **without a
trailing newline**. The sepolicy build concatenates every policy directory's
`property_contexts` through `cpp`, so the missing newline glued the last rule
to the first line of the next file:

```text
vendor.sys.qseecomd.enable             u:object_r:vendor_default_prop:s0# Aux camera blacklist prop readable to everything
```

`property_info_checker` then parses `# Aux camera blacklist prop readable to
everything` as if it were a context and reports the "type" as the comment
text.

### Fix

Add the missing final newline, and check the whole tree for the same defect:

```bash
printf '\n' >> device/samsung/j8y18lte/sepolicy/property_contexts

# advisory sweep across every policy dir used by the build
for f in $(find device/ -name property_contexts -o -name file_contexts | sort); do
  [ -n "$(tail -c1 "$f")" ] && echo "no trailing newline: $f"
done
```

`BoardConfig.mk` had the same defect (`\ No newline at end of file` on its last
line); the patch in [`patches/`](../patches/) fixes both.

---

## 3. `chromium-webview` is a Git LFS pointer (workaround)

### Symptom

`external/chromium-webview/prebuilt/arm/webview.apk` is 133 bytes and starts
with `version https://git-lfs.github.com/spec/v1`. Packaging fails or produces
a ROM without a usable WebView.

### Fix

Either sync with LFS from the start:

```bash
repo init -u https://github.com/LineageOS/android.git -b lineage-17.1 --git-lfs
```

or replace the pointer with a real ARM WebView APK of the matching version
(from a LineageOS 17.1 build of another arm device), then rebuild.

---

## 4. `repo --version` prints `<repo not installed>`

The launcher script is present but the Python payload behind it is not.

```bash
mkdir -p ~/bin
curl -fsSL https://storage.googleapis.com/git-repo-downloads/repo -o ~/bin/repo
chmod a+x ~/bin/repo
export PATH=$HOME/bin:$PATH
repo --version
```

---

## 5. Out-of-memory during the build

12 GB RAM with `-j16` is workable but tight; `ninja` gets OOM-killed with no
obvious error, or the host swaps heavily.

```bash
# lower concurrency, keep ccache
m -j8 bacon
```

Check `dmesg | grep -i 'killed process'` on the host (WSL2: from Windows,
`wsl dmesg`). Also confirm enough swap — this project used 16 GB of swap on a
dedicated VHDX.

---

## 6. Builds on a shared filesystem are slow or corrupt outputs

Do not build inside `/mnt/c` or `/mnt/d` under WSL. Those are 9p/DrvFs mounts:
case sensitivity, extended attributes and permissions do not behave like ext4,
and the build creates thousands of small files. Keep the source on the native
filesystem and copy only finished artifacts out.

---

## 7. Reading a failed build log

```bash
grep -n -E '^FAILED|error:|ERROR:' build.log | head -30
```

- The **first** `FAILED:` is the cause; everything after it is fallout.
- `[ 99% 529/530]` style progress means almost everything compiled — the
  failure is in the last step (usually image creation or packaging).
- `ninja: build stopped: subcommand failed` is a summary, not a cause.
- `warning:` lines from the kernel defconfig are normal on this 3.18 tree.
