# Build logs

Trimmed logs from the real build host, kept as evidence for
[`../STATUS.md`](../STATUS.md), [`../VALIDATION.md`](../VALIDATION.md) and
[`../docs/build-troubleshooting.md`](../docs/build-troubleshooting.md).

| File | What it shows |
|---|---|
| `2026-10-30-bacon-success.log` | First complete build: `Package Complete: …-UNOFFICIAL-j8y18lte.zip`, `#### build completed successfully ####` (test-key signed at that point) |
| `2026-10-30-bacon-enforcing.log` | The enforcing build after dropping `androidboot.selinux=permissive` from the cmdline |
| `2026-10-30-sign-ota.log` | `sign_target_files_apks` + `ota_from_target_files` with the project release keys |
| `2026-10-26-e2fsdroid-firmware-failure.log` | The system-image failure: `set_selinux_xattr … searching for label "/firmware"` |
| `2026-10-30-property-contexts-failure.log` | `vendor_property_contexts` rejecting the merged file after the missing-newline corruption |

Host-specific paths in these logs have been rewritten (`/home/<builder>/…`,
`…/logs/…`) and build-user names genericised; nothing else was altered. ANSI
colour codes from the build were stripped.

## How to read them

```bash
# did it work?
grep -n -E 'Package Complete|build completed successfully' 2026-10-30-bacon-success.log

# what failed, first?
grep -n -E '^FAILED|error:' 2026-10-26-e2fsdroid-firmware-failure.log | head

# which cmdline was baked in?
grep -n -E 'androidboot.selinux' 2026-10-30-bacon-enforcing.log | head
```

The interesting failure is always the **first** `FAILED:` line.
`ninja: build stopped` is the summary, not the cause.

Full, untrimmed logs are not committed: they are 1–9 MB each and add nothing
that these excerpts do not already show.
