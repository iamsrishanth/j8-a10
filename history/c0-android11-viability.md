<!-- Archived report. Host names, IP addresses, user names, paths and the device serial have been genericised; wording and figures are otherwise unchanged. -->

﻿# Android 11 Viability Decision — j8os C0

Date: 2026-10-25
Device: SM-J810G / j8y18lte / a7d4xxxx

## Verdict

Android 11 **is not viable with the available Android 10-era vendor blob set** without a substantial vendor port/shim project. The C0 system boots far enough to start SurfaceFlinger, but `system_server` cannot complete boot.

This is a system/vendor compatibility failure, not a signing, partition, or boot-image failure.

## Evidence

- C0 system: Android 11, userdebug/test-keys, 32-bit.
- C0 vendor: built from the same tree, but the proprietary blobs are Android 10-era.
- C0 boot: correct image and load addresses; enforcing boot hangs at Samsung logo; permissive boot reaches the LineageOS boot animation.
- HWC/display:
  - `android.hardware.graphics.composer@2.1-service` runs.
  - SurfaceFlinger eventually initializes the 720×1480 display.
  - The earlier `failed to create composer client` was transient during service startup.
- Audio:
  - `android.hardware.audio.service` aborts with `Could not register Audio Effect API`.
  - Disabling the vendor audio HAL let `audioserver` run, but `system_server` still stopped at `StartAudioService`.
  - NOPing the assert at `main+0x90e` left the audio service running, but `system_server` still hung at `StartAudioService`.
  - Disabling the system `audioserver` for a boot test could not be completed because TWRP's shell reboot did not leave recovery.
- Media:
  - `android.hardware.media.omx@1.0-service` cannot locate `android::MediaCodecsXmlParser::getDefaultXmlNames()`.
- RIL:
  - `libsec-ril.so`/`libsec-ril-dsds.so` cannot locate `google::protobuf::internal::empty_string_`; RIL exits.
- Keymaster:
  - `android.hardware.keymaster@3.0-impl.so` cannot locate `ecdsaOperationFactory::CreateOperation(...)`.

## Build-environment limitation

No Android build tree or NDK is available in the current environment:

- `build-host` is unreachable.
- `builder-deb:/mnt/d` contains docs/artifacts only, not the LineageOS source tree.
- The controller has no Android SDK/NDK.
- The old WSL VHDX/source is not available.

Binary patching alone cannot provide the missing C++/HIDL shims for media, RIL, keymaster, and audio effects.

## Current device state

- C0 system/vendor remain installed.
- Data is formatted.
- Original vendor audio files and system audioserver restored from `/sdcard`.
- Boot partition restored to the original C0 enforcing image (SHA-256 `39f8c744…c366`).
- TWRP remains available.
- No working Android system and no flashable Android 10/rollback image.

## Recommendation

1. Build LineageOS 17.1 / Android 10 with the same vendor blobs; this is the compatibility path most likely to produce a usable phone.
2. Or obtain the full source tree plus NDK and undertake a deliberate vendor-shim/HWC/audio port for Android 11.
3. Do not treat C0 Android 11 as a daily driver.

TWRP remains the recovery route. No GApps, root, debloat, or tuning changes were made.
