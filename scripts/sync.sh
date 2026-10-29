#!/usr/bin/env bash
#
# Initialise and sync the LineageOS 17.1 source tree for j8y18lte.
#
#   SRC=~/android/lineage-17.1 ./scripts/sync.sh
#
# Environment:
#   SRC     target source directory (default: ~/android/lineage-17.1)
#   BRANCH  LineageOS branch          (default: lineage-17.1)
#   JOBS    repo sync parallelism     (default: 8)
#
set -euo pipefail

SRC=${SRC:-$HOME/android/lineage-17.1}
BRANCH=${BRANCH:-lineage-17.1}
JOBS=${JOBS:-8}
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

command -v repo >/dev/null || {
  echo "error: 'repo' not on PATH. See docs/build.md#repo" >&2
  exit 1
}

mkdir -p "$SRC"
cd "$SRC"

if [ ! -d .repo ]; then
  echo "==> repo init ($BRANCH)"
  repo init -u https://github.com/LineageOS/android.git -b "$BRANCH"
else
  echo "==> .repo already present, skipping init"
fi

echo "==> installing local manifests"
mkdir -p .repo/local_manifests
cp "$HERE/manifests/j8y18lte.xml"    .repo/local_manifests/j8y18lte.xml
cp "$HERE/manifests/roomservice.xml" .repo/local_manifests/roomservice.xml

echo "==> repo sync -c -j$JOBS (this is the long step, ~100 GB)"
repo sync -c -j"$JOBS" --force-sync --no-clone-bundle --no-tags

echo
echo "==> pins"
for p in device/samsung/j8y18lte kernel/samsung/j8y18lte vendor/samsung/j8y18lte; do
  printf '%-42s %s\n' "$p" "$(git -C "$p" rev-parse HEAD 2>/dev/null || echo MISSING)"
done

echo
echo "Now run: bash $HERE/scripts/apply-patches.sh"
