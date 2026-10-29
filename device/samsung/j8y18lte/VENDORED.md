# Vendored device tree

This is a **verbatim copy** of
[`goldfish07/android_device_samsung_j8y18lte`](https://github.com/goldfish07/android_device_samsung_j8y18lte)
at commit `1b4f25eff98554feac5c0ab945c70be6589c3693`, plus the two local fixes
in [`../../../patches/`](../../../patches/):

- the last line of `BoardConfig.mk` is
  `BOARD_SEPOLICY_DIRS += device/samsung/j8y18lte/sepolicy` (explicit path
  instead of `$(LOCAL_PATH)`), with a final newline;
- `sepolicy/property_contexts` ends with a newline.

Upstream is the source of truth. This copy exists so the ROM configuration is
readable without syncing 120 GB of AOSP. See
[`../../../docs/sources.md`](../../../docs/sources.md) for the pins and
licensing.

To prove this copy is reproducible:

```bash
git clone https://github.com/goldfish07/android_device_samsung_j8y18lte /tmp/dt
git -C /tmp/dt checkout 1b4f25eff98554feac5c0ab945c70be6589c3693
cd /tmp/dt
git apply /path/to/j8-a10/patches/0001-*.patch
git apply /path/to/j8-a10/patches/0002-*.patch
diff -r /tmp/dt /path/to/j8-a10/device/samsung/j8y18lte --exclude=.git --exclude=VENDORED.md
```

An empty diff means pin + patches == this directory.

Licensed Apache-2.0, per the headers in the files and upstream's license.
