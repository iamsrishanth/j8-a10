# Vendored device tree

This is a **verbatim copy** of
[`goldfish07/android_device_samsung_j8y18lte`](https://github.com/goldfish07/android_device_samsung_j8y18lte)
at commit `1b4f25eff98554feac5c0ab945c70be6589c3693`, plus the two local fixes
in [`../../patches/`](../../patches/):

- the last line of `BoardConfig.mk` is
  `BOARD_SEPOLICY_DIRS += device/samsung/j8y18lte/sepolicy` (explicit path
  instead of `$(LOCAL_PATH)`), with a final newline;
- `sepolicy/property_contexts` ends with a newline.

Upstream is the source of truth. This copy exists so the ROM configuration is
readable without syncing 120 GB of AOSP. See
[`../../docs/sources.md`](../../docs/sources.md).

Licensed Apache-2.0, per the headers in the files and upstream's license.
