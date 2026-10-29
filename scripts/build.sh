#!/usr/bin/env bash
#
# Build LineageOS 17.1 for j8y18lte.
#
#   ./scripts/build.sh                 # m -j16 bacon
#   JOBS=8 ./scripts/build.sh          # less memory pressure
#   TARGET=bootimage ./scripts/build.sh
#
# Environment:
#   SRC      source tree   (default: ~/android/lineage-17.1)
#   LOG_DIR  log directory (default: $SRC/../logs)
#   JOBS     parallelism   (default: 16)
#   TARGET   ninja target  (default: bacon)
#
set -u

SRC=${SRC:-$HOME/android/lineage-17.1}
LOG_DIR=${LOG_DIR:-$SRC/../logs}
JOBS=${JOBS:-16}
TARGET=${TARGET:-bacon}

cd "$SRC" || { echo "error: no source tree at $SRC" >&2; exit 1; }
mkdir -p "$LOG_DIR"

export CCACHE_DIR=${CCACHE_DIR:-$HOME/.ccache}
export USE_CCACHE=1
export CCACHE_EXEC=${CCACHE_EXEC:-/usr/bin/ccache}
export JAVA_HOME=${JAVA_HOME:-/usr/lib/jvm/java-11-openjdk-amd64}

# shellcheck disable=SC1091
source build/envsetup.sh >/dev/null 2>&1
lunch lineage_j8y18lte-userdebug >/dev/null 2>&1 || {
  echo "error: lunch lineage_j8y18lte-userdebug failed — is the device tree synced?" >&2
  exit 1
}

LOG="$LOG_DIR/build-17.1-$(date +%Y%m%d-%H%M%S).log"
echo "tree   : $SRC"
echo "target : $TARGET (-j$JOBS)"
echo "log    : $LOG"
echo

m -j"$JOBS" "$TARGET" 2>&1 | tee "$LOG"
status=${PIPESTATUS[0]}

echo
echo "exit=$status"
if [ "$status" -ne 0 ]; then
  echo "--- first failures ---"
  grep -n -E '^FAILED|error:|ERROR' "$LOG" | head -20
  exit "$status"
fi

echo "--- produced ---"
ls -l out/target/product/j8y18lte/*.img out/target/product/j8y18lte/*.zip 2>/dev/null
