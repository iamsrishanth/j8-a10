# Build logs

Trimmed logs from the real build host, kept as evidence for
[`../STATUS.md`](../STATUS.md) and
[`../docs/build-troubleshooting.md`](../docs/build-troubleshooting.md).

| File | What it shows |
|---|---|
| `2026-10-30-bacon-success.log` | The build that completed: `#### build completed successfully ####` and `Package Complete: …-UNOFFICIAL-j8y18lte.zip` |
| `2026-10-26-e2fsdroid-firmware-failure.log` | The system-image failure: `set_selinux_xattr … searching for label "/firmware"` |
| `2026-10-30-property-contexts-failure.log` | `vendor_property_contexts` rejecting the merged file after the missing-newline corruption |

Host-specific paths in these logs have been rewritten
(`/home/<builder>/…`, `…/logs/…`); nothing else was altered. ANSI colour codes
from the build were stripped.

## How to read them

```bash
grep -n -E '^FAILED|error:' 2026-10-26-e2fsdroid-firmware-failure.log | head
grep -n 'Package Complete' 2026-10-30-bacon-success.log
```

The interesting failure is always the **first** `FAILED:` line. `ninja: build
stopped` is the summary, not the cause.

Full, untrimmed logs are not committed: they are 1–9 MB each and add nothing
that the excerpts here do not already show.
