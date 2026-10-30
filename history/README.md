# History and earlier reports

Preserved reports from every stage of this device's ROM attempts. They are kept
because their failures explain the shape of the Android 10 work — not because
their conclusions still hold.

> **Sanitisation:** host names, IP addresses, user names, absolute paths, the
> device serial number and MAC addresses have been replaced with generic
> placeholders. No key material, credentials or personal data was ever part of
> these files, and none is reproduced here. Wording and numbers are otherwise
> unchanged.

| File | Stage | Why keep it |
|---|---|---|
| [`handover-2026-10-24-android12.md`](handover-2026-10-24-android12.md) | LineageOS 19.0 / Android 12 plan | The original plan and the measured environment it was written against |
| [`build-spec-android12.md`](build-spec-android12.md) | Android 12 specification | Device parameters, partition table, risk register — still useful reference |
| [`c0-android11-viability.md`](c0-android11-viability.md) | LineageOS 18.1 / Android 11 | Why Android 11 with Android 10 blobs never finished booting |
| [`c0-boot-failure.md`](c0-boot-failure.md) | Android 11 boot failure | The concrete audio-policy failure |
| [`handover-2026-10-26-android10.md`](handover-2026-10-26-android10.md) | LineageOS 17.1 / Android 10 | State of the bring-up when it was handed over |
| [`android10-build-status-2026-10-26.md`](android10-build-status-2026-10-26.md) | Android 10 | The `e2fsdroid` failure as it was first understood (later corrected) |
| [`avb-verity-analysis-2026-10-29.md`](avb-verity-analysis-2026-10-29.md) | Android 10 | Full AVB / dm-verity / SELinux investigation |
| [`handover-2026-10-30-android10.md`](handover-2026-10-30-android10.md) | Android 10 | The handover where the ROM boots |
| [`master-repair-status-2026-10-30.md`](master-repair-status-2026-10-30.md) | Android 10 | Evidence ledger for the session that fixed and flashed the build |
| [`android10-build-fix-2026-10-30.md`](android10-build-fix-2026-10-30.md) | Android 10 | The actual root cause and fix, with instrumented make output |
| [`android10-validation-2026-10-30.md`](android10-validation-2026-10-30.md) | Android 10 | Per-test results from the device |
| [`install-and-rollback-plan-2026-10-30.md`](install-and-rollback-plan-2026-10-30.md) | Android 10 | The reviewed write sequence and its authorisation scope |
| [`usb-odin-diagnosis-2026-10-30.md`](usb-odin-diagnosis-2026-10-30.md) | Android 10 | USB/ADB authorisation work; why Odin was never needed |

## The short version of the story

1. **Android 12** was the plan. Blocked: the 3.18 kernel has no eBPF, and
   `bpfloader`/`netd` are fatal without it.
2. **Android 11 (C0)** built and installed, then never finished booting: the
   vendor audio HAL never published `media.audio_policy`, because the framework
   was Android 11 against Android 10-era blobs.
3. **Android 10 (LineageOS 17.1)** matches the blobs. It builds, signs, installs
   and boots — see [`../STATUS.md`](../STATUS.md) and
   [`../VALIDATION.md`](../VALIDATION.md).

The wider narrative, including scope decisions, is in
[`../docs/history.md`](../docs/history.md).

## Reading an old report

These documents were written at different times and disagree in places (for
example about whether SELinux was enforcing in a given build, or which path the
`e2fsdroid` failure hit first). When they conflict:

- prefer the measurement with a command and a timestamp attached,
- prefer the newer report,
- and verify against the current tree before acting on either.

The 2026-10-26 build status is a good example: it blamed root-folder and
`.keep` handling. The 2026-10-30 build-fix report shows the real cause was a
sepolicy directory that never reached `BOARD_VENDOR_SEPOLICY_DIRS`.
