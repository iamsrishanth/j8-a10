#!/usr/bin/env bash
#
# Apply the local device-tree patches on top of the pinned tree.
#
#   SRC=~/android/lineage-17.1 ./scripts/apply-patches.sh
#
# Idempotent: a patch already present is reported and skipped.
#
set -euo pipefail

SRC=${SRC:-$HOME/android/lineage-17.1}
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
DT="$SRC/device/samsung/j8y18lte"

[ -d "$DT" ] || { echo "error: device tree not found at $DT" >&2; exit 1; }
[ -d "$HERE/patches" ] || { echo "error: patches/ not found next to this script" >&2; exit 1; }

cd "$DT"

shopt -s nullglob
patches=("$HERE"/patches/*.patch)
if [ ${#patches[@]} -eq 0 ]; then
  echo "no patches found in $HERE/patches"
  exit 0
fi

for p in "${patches[@]}"; do
  name=$(basename "$p")
  if git apply --reverse --check "$p" >/dev/null 2>&1; then
    echo "already applied : $name"
  elif git apply --check "$p" >/dev/null 2>&1; then
    git apply "$p"
    echo "applied         : $name"
  else
    echo "FAILED to apply : $name" >&2
    echo "  The device tree is not in the expected state. Inspect with:" >&2
    echo "    git -C $DT status" >&2
    echo "    git -C $DT diff" >&2
    echo "  Do not force it; resolve the difference first." >&2
    exit 1
  fi
done

echo
echo "==> resulting device-tree diff"
git --no-pager diff --stat
echo
echo "==> untracked files (expected: none)"
git status --porcelain | grep '^??' || true
