#!/usr/bin/env bash
#
# Switch the built image between SELinux permissive and enforcing.
#
#   ./scripts/set-selinux-mode.sh permissive
#   ./scripts/set-selinux-mode.sh enforcing
#
# The mode is a kernel-cmdline argument baked into boot.img, so this edits
# BoardConfig.mk and you must rebuild afterwards.
#
set -euo pipefail

MODE=${1:-}
SRC=${SRC:-$HOME/android/lineage-17.1}
BC="$SRC/device/samsung/j8y18lte/BoardConfig.mk"

case "$MODE" in
  permissive|enforcing) ;;
  *) echo "usage: $0 {permissive|enforcing}" >&2; exit 2 ;;
esac

[ -f "$BC" ] || { echo "error: BoardConfig.mk not found at $BC" >&2; exit 1; }

current=$(grep -c 'androidboot\.selinux=permissive' "$BC" || true)

if [ "$MODE" = permissive ]; then
  if [ "$current" -gt 0 ]; then
    echo "already permissive"
  else
    sed -i 's/^\(BOARD_KERNEL_CMDLINE := .*\)$/\1 androidboot.selinux=permissive/' "$BC"
    echo "set permissive"
  fi
else
  if [ "$current" -eq 0 ]; then
    echo "already enforcing"
  else
    sed -i 's/ androidboot\.selinux=permissive//' "$BC"
    echo "set enforcing"
  fi
fi

echo
echo "==> BOARD_KERNEL_CMDLINE now:"
grep '^BOARD_KERNEL_CMDLINE' "$BC"
echo
echo "Rebuild (m bacon) and confirm inside the image:"
echo "  strings out/target/product/j8y18lte/boot.img | grep -o 'androidboot.selinux=[a-z]*' || echo 'no permissive arg (enforcing)'"
