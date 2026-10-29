<!-- Archived report. Host names, IP addresses, user names, paths and the device serial have been genericised; wording and figures are otherwise unchanged. -->

﻿# C0 Boot Failure Report

Date: 2026-10-25
Device: SM-J810G / j8y18lte / a7d4xxxx
Candidate: j8os-18.1-C0-20261024

## Installed state

- system: C0, `lineage_j8y18lte-userdebug 11 RQ3A.211001.001 eng.akshit.20261024.074113`, userdebug/test-keys, 32-bit.
- vendor: C0, same fingerprint/date, 32-bit.
- boot: C0 boot image; header load addresses match TWRP.
- data: formatted.
- ODM: stock Samsung J810GODM6CWH2 (not written by OTA).

## Boot behavior

- Enforcing C0 boot: hangs at Samsung logo.
- Permissive C0 boot: reaches the LineageOS boot animation; ADB comes online as `lineage_j8y18lte`.
- `sys.boot_completed` never becomes 1; boot animation continues.
- SELinux is `Permissive`; many `avc: denied` entries appear.

## Fatal vendor/system mismatches

- `surfaceflinger`: abort `failed to create composer client` in `android::Hwc2::impl::Composer`.
- `android.hardware.audio.service`: abort `Could not register Audio Effect API`.
- `android.hardware.media.omx@1.0-service`: missing symbol `android::MediaCodecsXmlParser::getDefaultXmlNames()`.
- `libsec-ril.so` / `libsec-ril-dsds.so`: missing symbol `google::protobuf::internal::empty_string_`; RIL daemons exit.
- `android.hardware.keymaster@3.0-impl.so`: missing symbol `keymaster::EcdsaOperationFactory::CreateOperation(...)`.

These indicate the Android 11 system is running against older Android 10-era vendor blobs. The display composer failure alone prevents a usable UI.

## Current artifact status

- C0 static validation passed, but the candidate is not bootable as a daily system.
- Enforcing and permissive boot images are preserved locally.
- `/sdcard/boot-full.img` is the original full boot partition backup.

## Options

1. Build LineageOS 17.1 / Android 10 with the same vendor blobs — the compatibility path most likely to boot.
2. Undertake vendor shim/HWC compatibility work for Android 11 — substantial and uncertain.
3. Restore a known-good system image — none was preserved (user waived backups).

No further flash should be attempted until a path is chosen.
