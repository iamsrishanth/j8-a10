#!/usr/bin/env bash
#
# DIAGNOSTIC ONLY — build a system image by hand with a minimal label set.
#
# This exists because a normal `m bacon` once failed at the system-image step.
# It bypasses the merged file_contexts entirely and labels everything
# `u:object_r:rootfs:s0`, which means:
#
#   * the image is NOT release quality,
#   * SELinux labels are wrong for every path,
#   * it is only useful to answer "does this build reach init?"
#
# Use the normal build (scripts/build.sh) unless you are debugging.
#
#   SRC=~/android/lineage-17.1 ./scripts/build-images-manual.sh
#
set -euo pipefail

SRC=${SRC:-$HOME/android/lineage-17.1}
OUT=${OUT:-$SRC/out/target/product/j8y18lte}
DEST=${DEST:-$PWD/diagnostic-images}

BLOCKS=829440           # 3,397,386,240 B / 4096
cd "$SRC"

[ -d "$OUT/system" ] || { echo "error: $OUT/system missing — run a build first" >&2; exit 1; }
mkdir -p "$DEST"

echo "==> creating empty ext4 (sparse)"
"$SRC/out/host/linux-x86/bin/mke2fs" -O ^has_journal -L / -I 256 -M / -m 0 \
  -E android_sparse -t ext4 -b 4096 "$DEST/system-sparse.img" "$BLOCKS"

echo "==> labelling everything rootfs (diagnostic only)"
printf '/.* u:object_r:rootfs:s0\n' > "$DEST/minimal_file_contexts"

echo "==> populating image"
"$SRC/out/host/linux-x86/bin/e2fsdroid" \
  -p "$OUT/system" \
  -S "$DEST/minimal_file_contexts" \
  -f "$OUT/system" \
  -a / \
  "$DEST/system-sparse.img"

echo "==> converting to raw (needed for dd / TWRP image install)"
"$SRC/out/host/linux-x86/bin/simg2img" "$DEST/system-sparse.img" "$DEST/system-raw.img"

cp -f "$OUT/vendor.img" "$DEST/vendor-sparse.img" 2>/dev/null || true
"$SRC/out/host/linux-x86/bin/simg2img" "$DEST/vendor-sparse.img" "$DEST/vendor-raw.img" 2>/dev/null || true
cp -f "$OUT/boot.img" "$DEST/boot.img" 2>/dev/null || true

echo
echo "==> output"
ls -l "$DEST"
sha256sum "$DEST"/*.img
echo
echo "REMINDER: this system image has no real SELinux labels. Diagnostic use only."
