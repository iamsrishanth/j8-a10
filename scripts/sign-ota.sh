#!/usr/bin/env bash
#
# Sign a built target-files package and produce a release OTA ZIP.
#
#   KEYS=~/secure/j8os-keys ./scripts/sign-ota.sh
#   KEYS=~/secure/j8os-keys ./scripts/sign-ota.sh /path/to/out/target/product/j8y18lte
#
# The default build output is signed with AOSP test keys. This script
# re-signs with *your* keys. Because the platform signature changes,
# flashing the result over any other ROM requires a data wipe.
#
set -euo pipefail

PRODUCT=${1:-${OUT:-$HOME/android/lineage-17.1/out/target/product/j8y18lte}}
SRC=${SRC:-$HOME/android/lineage-17.1}
KEYS=${KEYS:-$HOME/secure/j8os-keys}
TAG=${TAG:-$(date +%Y%m%d-%H%M%S)}

[ -d "$PRODUCT" ] || { echo "error: no product dir at $PRODUCT" >&2; exit 1; }
[ -f "$KEYS/releasekey.pk8" ] || { echo "error: no release keys in $KEYS (run scripts/make-keys.sh)" >&2; exit 1; }

TF=$(ls -t "$PRODUCT"/obj/PACKAGING/target_files_intermediates/*.zip 2>/dev/null | head -1 || true)
if [ -z "${TF:-}" ]; then
  echo "error: no target_files zip. Build one first:" >&2
  echo "  cd $SRC && source build/envsetup.sh && lunch lineage_j8y18lte-userdebug" >&2
  echo "  m -j8 target-files-package otatools" >&2
  exit 1
fi

OUT_DIR="$PRODUCT/signed-$TAG"
mkdir -p "$OUT_DIR"

export PATH="$SRC/out/host/linux-x86/bin:$PATH"

echo "target files : $TF"
echo "keys         : $KEYS"
echo "output       : $OUT_DIR"
echo

echo "==> sign_target_files_apks"
"$SRC/build/make/tools/releasetools/sign_target_files_apks" \
  -o -d "$KEYS" \
  "$TF" "$OUT_DIR/signed-target_files.zip"

echo "==> ota_from_target_files"
"$SRC/build/make/tools/releasetools/ota_from_target_files" \
  -k "$KEYS/releasekey" \
  --block --backup=true \
  "$OUT_DIR/signed-target_files.zip" \
  "$OUT_DIR/lineage-17.1-$TAG-signed-ota.zip"

echo
echo "==> verify"
unzip -p "$OUT_DIR/lineage-17.1-$TAG-signed-ota.zip" META-INF/com/android/otacert \
  | openssl x509 -noout -fingerprint -sha256 > "$OUT_DIR/otacert-fingerprint.txt"
openssl x509 -in "$KEYS/releasekey.x509.pem" -noout -fingerprint -sha256 > "$OUT_DIR/releasekey-fingerprint.txt"
if diff -q "$OUT_DIR/otacert-fingerprint.txt" "$OUT_DIR/releasekey-fingerprint.txt" >/dev/null; then
  echo "OK: OTA certificate matches the release key"
else
  echo "MISMATCH: OTA certificate does not match the release key" >&2
  exit 1
fi

echo
ls -l "$OUT_DIR"
sha256sum "$OUT_DIR"/*.zip
