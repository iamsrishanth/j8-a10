#!/usr/bin/env bash
#
# Verify a set of built artifacts against artifacts/SHA256SUMS.txt and the
# device's partition sizes.
#
#   ./scripts/verify-artifacts.sh path/to/out/target/product/j8y18lte
#
set -euo pipefail

DIR=${1:-${OUT:-out/target/product/j8y18lte}}
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
SUMS="$HERE/artifacts/SHA256SUMS.txt"

[ -d "$DIR" ] || { echo "error: no such directory: $DIR" >&2; exit 1; }

# Partition capacities from BoardConfig.mk / the live device.
declare -A MAX=(
  [boot]=33554432
  [recovery]=33554432
  [system]=3397386240
  [vendor]=503316480
  [cache]=314572800
)

echo "==> files"
ls -l "$DIR"/*.img "$DIR"/*.zip 2>/dev/null || true

echo
echo "==> hashes vs artifacts/SHA256SUMS.txt"
fail=0
while read -r hash name; do
  case "$hash" in \#*|"") continue;; esac
  f="$DIR/$name"
  [ -f "$f" ] || continue
  got=$(sha256sum "$f" | cut -d' ' -f1)
  if [ "$got" = "$hash" ]; then
    echo "  OK    $name"
  else
    echo "  DIFF  $name"
    echo "        expected $hash"
    echo "        actual   $got"
    fail=1
  fi
done < "$SUMS"
[ "$fail" -eq 0 ] && echo "  (all present files match)" || echo "  !! mismatch above"

echo
echo "==> image sizes vs partition capacity"
for img in boot recovery system vendor; do
  f="$DIR/$img.img"
  [ -f "$f" ] || continue
  size=$(stat -c %s "$f")
  max=${MAX[$img]}
  pct=$(( size * 100 / max ))
  printf '  %-9s %12d B  %3d%% of %d B\n' "$img" "$size" "$pct" "$max"
  if [ "$size" -gt "$max" ]; then
    echo "  !! $img.img does NOT fit its partition"
    fail=1
  fi
done

echo
echo "==> file types"
for f in "$DIR"/system.img "$DIR"/vendor.img; do
  [ -f "$f" ] && { printf '  %s: ' "$(basename "$f")"; file -b "$f"; }
done

echo
echo "==> boot image header"
BOOT="$DIR/boot.img"
if [ -f "$BOOT" ]; then
  python3 - "$BOOT" <<'EOF'
import struct, sys
p = sys.argv[1]
with open(p, 'rb') as f:
    h = f.read(1632)
fields = struct.unpack('<8s10I16s512s32s1024s', h)
magic, kernel_size, kernel_addr, ramdisk_size, ramdisk_addr, _, page_size = fields[:7]
tags_addr = fields[9] if len(fields) > 9 else 0
print('  magic        ', magic)
print('  kernel_size  ', kernel_size)
print('  ramdisk_size ', ramdisk_size)
print('  page_size    ', page_size)
print('  kernel_addr   0x%08x' % kernel_addr)
print('  ramdisk_addr  0x%08x' % ramdisk_addr)
print('  tags_addr     0x%08x' % tags_addr)
cmdline = fields[10].split(b'\0')[0].decode(errors='replace')
print('  cmdline      ', cmdline)
if magic != b'ANDROID!':
    sys.exit('  !! not an Android boot image')
EOF
fi

echo
if [ "$fail" -ne 0 ]; then
  echo "RESULT: problems found"
  exit 1
fi
echo "RESULT: OK"
