#!/usr/bin/env bash
#
# Generate the signing key set for this project.
#
#   OUT=~/secure/j8os-keys ./scripts/make-keys.sh
#
# Produces, per key name, a private key (*.pk8) and a certificate
# (*.x509.pem). Private keys must never enter a git repository.
#
set -euo pipefail

OUT=${OUT:-$HOME/secure/j8os-keys}
SRC=${SRC:-$HOME/android/lineage-17.1}
SUBJECT=${SUBJECT:-'/C=IN/ST=State/L=City/O=J8 Project/OU=Android/CN=J8 Release/emailAddress=release@example.com'}
KEYS=${KEYS:-"releasekey platform shared media verity networkstack nfc"}

MAKE_KEY="$SRC/development/tools/make_key"
[ -x "$MAKE_KEY" ] || { echo "error: make_key not found at $MAKE_KEY" >&2; exit 1; }

mkdir -p "$OUT"
chmod 700 "$OUT"

for k in $KEYS; do
  if [ -f "$OUT/$k.pk8" ] && [ -f "$OUT/$k.x509.pem" ]; then
    echo "exists  : $k"
    continue
  fi
  echo "generate: $k"
  # third argument 'no' = no password (non-interactive release tooling)
  "$MAKE_KEY" "$k" "$SUBJECT" no >/dev/null
  mv -f "$k.pk8" "$k.x509.pem" "$OUT/"
done

chmod 600 "$OUT"/*.pk8
chmod 644 "$OUT"/*.x509.pem

echo
echo "==> $OUT"
ls -l "$OUT"
echo
echo "Back these up offline, keep them out of git, and record the certificate"
echo "fingerprints somewhere durable:"
echo
for c in "$OUT"/*.x509.pem; do
  printf '%-24s %s\n' "$(basename "$c")" \
    "$(openssl x509 -in "$c" -noout -fingerprint -sha256 | cut -d= -f2)"
done
