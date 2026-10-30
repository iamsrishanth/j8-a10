#!/usr/bin/env bash
#
# Pull boot.img out of an OTA ZIP and inspect it.
#
#   ./scripts/extract-boot-from-ota.sh j8os-17.1-*-signed-ota.zip [outdir]
#
# Prints the SHA-256 of the boot image and its kernel cmdline, which is how you
# tell a permissive build from an enforcing one.
#
set -euo pipefail

ZIP=${1:-}
OUT=${2:-boot-from-ota}

[ -n "$ZIP" ] || { echo "usage: $0 <ota.zip> [outdir]" >&2; exit 2; }
[ -f "$ZIP" ] || { echo "error: no such file: $ZIP" >&2; exit 1; }

mkdir -p "$OUT"
unzip -o -q "$ZIP" boot.img -d "$OUT"

python3 - "$OUT/boot.img" <<'EOF'
import struct, sys
p = sys.argv[1]
d = open(p, 'rb').read(2048)
(magic, ksize, kaddr, rsize, raddr, ssize, saddr,
 tags, page, hdr_ver, os_ver) = struct.unpack('<8s10I', d[:48])
cmdline = d[64:576].split(b'\0')[0].decode(errors='replace')
print('boot.img      :', p)
print('magic         :', magic)
print('kernel_size   :', ksize)
print('ramdisk_size  :', rsize)
print('page_size     :', page)
print('kernel_addr   :', hex(kaddr))
print('ramdisk_addr  :', hex(raddr))
print('tags_addr     :', hex(tags))
print('cmdline       :', cmdline)
print('selinux mode  :', 'permissive' if 'androidboot.selinux=permissive' in cmdline else 'enforcing (no permissive arg)')
if magic != b'ANDROID!':
    sys.exit('not an Android boot image')
EOF

echo
sha256sum "$OUT/boot.img"

echo
echo "==> OTA metadata"
unzip -p "$ZIP" META-INF/com/android/metadata 2>/dev/null | head -10 || true
