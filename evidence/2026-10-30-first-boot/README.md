# Boot evidence — 2026-10-30

Raw material captured from the device during the first successful Android 10
boot, kept so the claims in [`../../VALIDATION.md`](../../VALIDATION.md) can be
checked without taking anyone's word for it.

| File | What it is |
|---|---|
| `getprop.txt` | Full `getprop` dump from the booted system |
| `dmesg-boot.txt` | Kernel log from that boot, with permissive-mode `avc: denied` lines removed |
| `avc-denials-summary.txt` | The removed denials, aggregated by process and target class |
| `logcat-errors.txt` | logcat: error-level lines, fatal exceptions and AVC denials |
| `screenshots/` | Setup Wizard (04:33), Setup Wizard (09:59), lock screen (11:17) |

Redactions: the device serial, the Samsung `em.did` / `ap_serial` values and
all MAC addresses were replaced with placeholders. Nothing else was altered.

## Reading it

```bash
# boot identity
grep -E 'ro\.(build\.version|lineage|product\.cpu)' getprop.txt | head

# uptime and boot completion
grep -E 'sys.boot_completed|ro.boottime' getprop.txt | head

# the fingerprint defect described in docs/device.md
grep -E 'build\.fingerprint' getprop.txt

# how noisy permissive mode is
head -40 avc-denials-summary.txt
```

## Context

- Build: `lineage_j8y18lte-userdebug 10 QQ3A.200805.001`, release-keys signed,
  SELinux **permissive** (diagnostic build).
- OTA: `j8os-17.1-20261030-0507-signed-ota.zip`,
  sha256 `d105a267a8979b2b634b02aa48f5094f898f6ed0537a35e0bf3be0817592fd91`.
- The screenshots are the device's own framebuffer at 720×1480, captured over
  ADB while the Setup Wizard and then the lock screen were on screen.
