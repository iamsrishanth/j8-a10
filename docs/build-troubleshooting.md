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

### Why `/firmware` was in the system tree at all

`/firmware` is a **runtime** path on this device, not a system-image path:

- `rootdir/fstab.qcom` mounts the vfat `apnhlos` partition at
  `/vendor/firmware_mnt` with `context=u:object_r:firmware_file:s0`;
- `rootdir/init.qcom.rc` has the `symlink /vendor/firmware_mnt /firmware` lines
  **commented out**;
- the device's `sepolicy/file_contexts` labels `/firmware(/.*)?` for the
  runtime path.

None of that should put a `/firmware` entry in `system/`. What did was
**debugging leftovers**: earlier attempts had created `firmware`, `omr`,
`config`, `efs`, `dsp` and `persist` entries under
`out/target/product/j8y18lte/system/` (and `.keep` files) to "make the error go
away". A dangling `firmware -> /vendor/firmware_mnt` symlink in the staging
tree is exactly an entry whose path has no matching label in the *system*
context set, because the policy entry that matches is the vendor-prefixed one
(`/vendor/firmware_mnt(/.*)?`).

Confirm for yourself:

```bash
strings out/target/product/j8y18lte/obj/ETC/file_contexts.bin_intermediates/file_contexts.bin \
  | grep -E 'firmware|omr'
```

You will see `/vendor/firmware_mnt(/.*)?` and `/vendor/bt_firmware(/.*)?` —
never a bare `/firmware`.

### Fix

1. **Remove the manual workarounds from the staging tree** and let the build
   recreate it:

   ```bash
   rm -rf out/target/product/j8y18lte/system out/target/product/j8y18lte/root
   m -j16 bacon
   ```

2. **Make sure the device's sepolicy directory is registered by an explicit
   path**, so its entries participate in the aggregation the image build uses:

   ```make
   # device/samsung/j8y18lte/BoardConfig.mk
   BOARD_SEPOLICY_DIRS += device/samsung/j8y18lte/sepolicy
   ```

   (The pinned tree used `$(LOCAL_PATH)/sepolicy` here. `LOCAL_PATH` is an
   `Android.mk` variable; relying on it inside `BoardConfig.mk` is fragile.)

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
