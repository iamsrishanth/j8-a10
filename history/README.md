# History and earlier reports

Preserved reports from the earlier stages of this device's ROM attempts. They
are kept because their failures are the reason the Android 10 work looks the
way it does — not because their conclusions still hold.

> **Sanitisation:** host names, IP addresses, user names, absolute paths and
> the device serial number have been replaced with generic placeholders.
> No key material, credentials or personal data was ever part of these files,
> and none is reproduced here. Wording and numbers are otherwise unchanged.

| File | Stage | Why keep it |
|---|---|---|
| [`handover-2026-10-24-android12.md`](handover-2026-10-24-android12.md) | LineageOS 19.0 / Android 12 plan | The original plan, and the measured environment it was written against |
| [`build-spec-android12.md`](build-spec-android12.md) | Android 12 specification | Device parameters, partition table, risk register — still useful reference |
| [`c0-android11-viability.md`](c0-android11-viability.md) | LineageOS 18.1 / Android 11 | Why Android 11 with Android 10 blobs never finished booting |
| [`c0-boot-failure.md`](c0-boot-failure.md) | Android 11 boot failure | The concrete audio-policy failure |
| [`handover-2026-10-26-android10.md`](handover-2026-10-26-android10.md) | LineageOS 17.1 / Android 10 | The state of the Android 10 bring-up when it was handed over |
| [`android10-build-status-2026-10-26.md`](android10-build-status-2026-10-26.md) | Android 10 | The `e2fsdroid` failure as it was first understood |
| [`avb-verity-analysis-2026-10-29.md`](avb-verity-analysis-2026-10-29.md) | Android 10 | Full AVB / dm-verity / SELinux investigation of the 17.1 build |

## The short version of the story

1. **Android 12** was the plan. Blocked: the 3.18 kernel has no eBPF, and
   `bpfloader`/`netd` are fatal without it.
2. **Android 11 (C0)** built and installed, then never finished booting: the
   vendor audio HAL never published `media.audio_policy`, because the
   framework was Android 11 against Android 10-era blobs.
3. **Android 10 (LineageOS 17.1)** matches the blobs. It now builds a complete
   OTA — see [`../STATUS.md`](../STATUS.md).

The wider narrative, including the scope decisions, is in
[`../docs/history.md`](../docs/history.md).

## Reading an old report

These documents were written by different people at different times, and they
disagree in places (for example about whether SELinux was enforcing in a given
build, or which file the `e2fsdroid` failure hit first). When they conflict:

- prefer the measurement with a command and a timestamp attached,
- prefer the newer report,
- and verify against the current tree before acting on either.
