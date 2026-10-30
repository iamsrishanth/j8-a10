#!/usr/bin/env bash
#
# Read-only device validation over ADB.
#
#   ./scripts/validate-device.sh [serial] [output-dir]
#
# Produces a report you can attach to a validation cycle, and prints a summary
# of the things that most often go wrong on this device: boot completion,
# SELinux mode, HAL services, radios, sensors, cameras and AVC denials.
#
set -uo pipefail

SERIAL=${1:-}
OUT=${2:-validation-$(date +%Y%m%d-%H%M%S)}
ADB=${ADB:-adb}

if [ -n "$SERIAL" ]; then ADB="$ADB -s $SERIAL"; fi

mkdir -p "$OUT"
cd "$OUT" || exit 1

have_device() { $ADB get-state 2>/dev/null | grep -q '^device$'; }

echo "==> adb"
$ADB devices -l | tee devices.txt
have_device || { echo "!! no device in 'device' state - stopping" >&2; exit 1; }

getprop() { $ADB shell getprop "$1" 2>/dev/null | tr -d '\r'; }

echo "==> identity"
{
  for p in ro.product.device ro.product.model ro.build.version.release \
           ro.build.version.sdk ro.build.type ro.build.tags ro.lineage.version \
           ro.product.cpu.abilist ro.zygote sys.boot_completed; do
    printf '%-32s %s\n' "$p" "$(getprop "$p")"
  done
  echo
  echo "fingerprint (see docs/device.md about the stock ODM override):"
  echo "  ro.build.fingerprint = $(getprop ro.build.fingerprint)"
  echo "  ro.system.build.fingerprint = $(getprop ro.system.build.fingerprint)"
} | tee identity.txt

echo "==> selinux"
{
  echo "getenforce: $($ADB shell getenforce 2>/dev/null | tr -d '\r')"
  echo "cmdline: $($ADB shell cat /proc/cmdline 2>/dev/null | tr -d '\r')"
} | tee selinux.txt

echo "==> services"
$ADB shell 'init.svc=; for s in zygote audioserver cameraserver media ril-daemon ril-daemon1 netd; do printf "%-14s %s\n" "$s" "$(getprop init.svc.$s)"; done' \
  2>/dev/null | tr -d '\r' | tee services.txt

echo "==> partitions"
$ADB shell 'for p in boot recovery system vendor cache userdata; do printf "%-9s %s\n" "$p" "$(blockdev --getsize64 /dev/block/by-name/$p 2>/dev/null)"; done; df -h /data /cache 2>/dev/null' \
  2>/dev/null | tr -d '\r' | tee partitions.txt

echo "==> radio"
{ getprop gsm.version.ril-impl; getprop gsm.sim.state; getprop gsm.network.type; } \
  | tee -a radio.txt

echo "==> sensors / cameras"
{ $ADB shell dumpsys sensorservice 2>/dev/null | head -30; } > sensors.txt
{ $ADB shell dumpsys media.camera 2>/dev/null | grep -iE 'number of camera|device version|facing' | head -20; } > camera.txt

echo "==> connectivity"
$ADB shell 'ip addr show wlan0 2>/dev/null; getprop bluetooth_address' 2>/dev/null | tr -d '\r' > connectivity.txt

echo "==> logs"
$ADB shell dmesg 2>/dev/null > dmesg.txt
$ADB logcat -d -b all 2>/dev/null > logcat.txt
grep -c 'avc: denied' dmesg.txt > avc-dmesg-count.txt 2>/dev/null || echo 0 > avc-dmesg-count.txt
grep -E 'FATAL EXCEPTION|Watchdog' logcat.txt | head -20 > crashes.txt 2>/dev/null || true

echo
echo "==> summary"
{
  echo "device            : $(getprop ro.product.device)"
  echo "build             : $(getprop ro.build.version.release) / SDK $(getprop ro.build.version.sdk)"
  echo "boot_completed    : $(getprop sys.boot_completed)"
  echo "selinux           : $($ADB shell getenforce 2>/dev/null | tr -d '\r')"
  echo "avc denials (dmesg): $(cat avc-dmesg-count.txt)"
  echo "crashes           : $(wc -l < crashes.txt 2>/dev/null || echo 0)"
} | tee summary.txt

echo
echo "Report written to $OUT"
