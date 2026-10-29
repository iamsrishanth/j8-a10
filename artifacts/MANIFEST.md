# Artifact manifest

Binaries are **not** stored in this repository. This file records exactly what
was produced, its size and hash, and how it relates to the others.

## 1. Current build — LineageOS 17.1 (Android 10)

Produced by `m -j16 bacon` on the pinned tree with the two patches in
[`../patches/`](../patches/). Build log:
[`../logs/2026-10-30-bacon-success.log`](../logs/2026-10-30-bacon-success.log).

| File | Bytes | SHA-256 |
|---|---:|---|
| `lineage-17.1-20261029-UNOFFICIAL-j8y18lte.zip` | 543,395,513 | `f3c520dc0307af653d0f867d881008932c8a538e8a119eb017bdba1e32958940` |
| `boot.img` | 13,064,192 | `b335f5611d2329dfad1df6182d8bce7606ac85b6a0be07c2a704a7e57afcffe3` |
| `system.img` | 1,078,473,140 | `e3cecf2b21494595b1441034d698eb239038f145b041c0e317df4a0a2a1a3742` |
| `vendor.img` | 248,877,228 | `41816c1ca3d12c4072487d21e9c4c4c3a04dcca9b61c0223cf0f8aba93f8ecc3` |
| `recovery.img` | 22,284,288 | `9910c42bda21239bbaa99985222f06cdd05b6ef91aba1b2d636eb8a994b60d37` |

`system.img` and `vendor.img` are **Android sparse** images (`file` reports
`Android sparse image, version: 1.0`). Convert before raw-writing:

```bash
out/host/linux-x86/bin/simg2img system.img system-raw.img
```

Signing state: the OTA is signed with the **AOSP testkey** — its
`META-INF/com/android/otacert` is
`C=US, ST=California, O=Android, CN=Android`, SHA-256 fingerprint
`A4:0D:A8:0A:59:D1:70:CA:A9:50:CF:15:C1:8C:45:4D:47:A3:9B:26:98:9D:8B:64:0E:CD:74:5B:A7:1B:F5:DC`.
Project release keys were **not** applied to this build.

## 2. Published release hashes (if you mirror them)

To mirror the artifacts, verify against the list above and re-publish with the
same names. Do not rename images: the install instructions depend on which
file goes to which partition.

## 3. Diagnostic images (earlier, raw)

These were produced **before** the system image built normally, as a
permissive boot-test set. They are recorded for provenance and must not be
confused with the current build.

| File | Bytes | SHA-256 | Notes |
|---|---:|---|---|
| `boot.img` | 13,064,192 | `b335f5611d2329dfad1df6182d8bce7606ac85b6a0be07c2a704a7e57afcffe3` | identical to the current boot image |
| `system-raw.img` | 3,397,386,240 | `d071d4b81ab7354866ceec4da91fe714ade314f894078c7d930680cf2c082863` | built by hand with a minimal `u:object_r:rootfs:s0` label set — **not a release image** |
| `vendor-raw.img` | 503,316,480 | `11aab794a42f7815ccef081433d528ba0cdeaa60ccadcc4c26708323884ef820` | raw conversion of the sparse vendor image |
| `vendor.img` (sparse) | 248,783,020 | `4d7ce4cf6ecc92c8d72ad1112e41a307170c2bb9af46b640e27bd98f9c4a825c` | older sparse build |

The manual system image was created with:

```bash
out/host/linux-x86/bin/mke2fs -O ^has_journal -L / -I 256 -M / -m 0 \
  -E android_sparse -t ext4 -b 4096 system-sparse.img 829440
printf '/.* u:object_r:rootfs:s0\n' > /tmp/min_fc
out/host/linux-x86/bin/e2fsdroid -p out/target/product/j8y18lte/system \
  -S /tmp/min_fc -f out/target/product/j8y18lte/system -a / \
  system-sparse.img
out/host/linux-x86/bin/simg2img system-sparse.img system-raw.img
```

`scripts/build-images-manual.sh` automates it. Use it only to test whether a
boot reaches `init`; it is explicitly a diagnostic artifact.

## 4. Build output map

```text
out/target/product/j8y18lte/
├── boot.img                                  kernel + ramdisk
├── recovery.img                              Lineage recovery (not in the OTA)
├── system.img                                sparse system image
├── vendor.img                                sparse vendor image
├── lineage_j8y18lte-ota-eng.<builder>.zip    OTA (same bytes as below)
└── lineage-17.1-<date>-UNOFFICIAL-j8y18lte.zip   installable OTA ZIP
```
