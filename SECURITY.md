# Security notes

## This is a bring-up build, not a security-hardened ROM

The Android 10 images produced by this tree so far are:

- `userdebug`, with `ro.debuggable=1` semantics,
- **SELinux permissive** (`androidboot.selinux=permissive` in `BoardConfig.mk`),
- signed with AOSP test keys (no project release keys applied),
- built with **no** AVB and **no** dm-verity (see [docs/integrity.md](docs/integrity.md)),
- unencrypted `/data` as configured by the shipped fstab.

Treat any image from this repository as a **diagnostic artifact**. Do not put
personal accounts, banking apps, or work data on a device running it.

## Reporting

Open an issue for anything in this repository — build scripts, patches,
documentation, or the device tree. Please do not include:

- IMEI / MEID, device serial numbers, MAC addresses,
- Wi-Fi credentials, Google account identifiers,
- keystore files or private keys,
- full `logcat` dumps without scanning them first.

## Keys

No signing key material is stored here, and none should ever be. See
[docs/signing.md](docs/signing.md) for how to generate and use your own
release keys locally.

## Upstream vulnerabilities

Security patches in this tree follow whatever the pinned LineageOS 17.1
branch contains. The pins in [`manifests/j8y18lte.xml`](manifests/j8y18lte.xml)
are old relative to current Android security bulletins; a production-oriented
build should re-pin and re-sync against a maintained branch.
