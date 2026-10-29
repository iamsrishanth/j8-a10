#!/usr/bin/env bash
#
# Collect boot logs and device state after flashing.
#
#   ./scripts/collect-bootlogs.sh /path/to/evidence
#
# Works against whatever single device `adb` sees. Run it immediately after
# the first boot attempt, and again once the system settles.
#
set -uo pipefail

OUT=${1:-evidence-$(date +%Y%m%d-%H%M%S)}
mkdir -p "$OUT"
cd "$OUT"

ADB=${ADB:-adb}

echo "==> adb devices"
$ADB devices -l | tee devices.txt

if ! grep -q 'device$' <($ADB devices | awk 'NR>1 && $2=="device"{print}'); then
  echo "!! no adb device online — if the phone is in recovery, check authorisation"
fi

echo "==> props"
$ADB shell getprop > props.txt 2>&1
$ADB shell getenforce > selinux.txt 2>&1

echo "==> kernel + logcat"
$ADB shell dmesg > dmesg.txt 2>&1
$ADB logcat -d -b all > logcat.txt 2>&1
$ADB shell cat /proc/last_kmsg > last_kmsg.txt 2>&1
$ADB shell cat /sys/fs/pstore/console-ramoops-0 > pstore.txt 2>&1

echo "==> subsystems"
for s in media.camera sensorservice telephony.registry wifi SurfaceFlinger; do
  $ADB shell dumpsys "$s" > "dumpsys-${s//./-}.txt" 2>&1
done
$ADB shell df -h > df.txt 2>&1
$ADB shell ip addr > ip.txt 2>&1

echo "==> summary"
{
  echo "boot_completed=$( $ADB shell getprop sys.boot_completed | tr -d '\r' )"
  echo "selinux=$( tr -d '\r' < selinux.txt )"
  echo "avc_denied_dmesg=$( grep -c 'avc: denied' dmesg.txt || true )"
  echo "avc_denied_logcat=$( grep -c 'avc: denied' logcat.txt || true )"
  echo "fatal_exceptions=$( grep -c 'FATAL EXCEPTION' logcat.txt || true )"
  echo "watchdog=$( grep -c 'Watchdog' logcat.txt || true )"
} | tee summary.txt

echo
echo "Evidence written to $OUT"
echo "Fill in docs/validation.md with these results."
