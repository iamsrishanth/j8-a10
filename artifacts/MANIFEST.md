# Artifact manifest

Binaries are **not** stored in this repository (sizes). This file records what
was produced, its size and hash, and which build it belongs to.

## 1. Signed builds (release keys)

Both OTAs are built from the same tree; they differ only in the SELinux cmdline
argument baked into `boot.img`.

| Artifact | Bytes | SHA-256 | State |
|---|---:|---|---|
| `j8os-17.1-20261030-0507-signed-ota.zip` (permissive) | 543,446,412 | `d105a267a8979b2b634b02aa48f5094f898f6ed0537a35e0bf3be0817592fd91` | **installed & booted** |
| `j8os-17.1-20261030-0507-signed-target_files.zip` | 1,293,717,122 | `e48075692dfd0666e71c23af1d6179accfbbae4cb31e32ce982aaf6d9c899072` | — |
| `j8os-17.1-enforcing-20261030-0532-signed-ota.zip` | 543,446,361 | `8f5669c8ae47368e986ae7f9610b94857ee005832ef7e935e6138376f3c98abc` | **ready, not flashed** |
| `j8os-17.1-enforcing-20261030-0532-signed-target_files.zip` | 1,293,716,968 | `0e429f547404203e0cf9d15da82fc97689e57ccc120154c64ec784f4e0ca1263` | — |

OTA identity (both): `lineage_j8y18lte-userdebug 10 QQ3A.200805.001`,
`17.1-20261029-UNOFFICIAL-j8y18lte`, `post-sdk-level=29`,
`post-security-patch-level=2023-02-05`, `ota-type=BLOCK`,
`post-build=…:userdebug/release-keys`.

Both OTAs contain: `boot.img`, `system.new.dat.br`, `vendor.new.dat.br`,
`system/vendor.transfer.list`, `META-INF/…`. **No recovery image** — TWRP
survives the install.

## 2. Boot images

| Image | Bytes | SHA-256 | SELinux cmdline |
|---|---:|---|---|
| permissive (inside the 0507 OTA) | 13,064,192 | `b335f5611d2329dfad1df6182d8bce7606ac85b6a0be07c2a704a7e57afcffe3` | `androidboot.selinux=permissive` |
| enforcing (inside the 0532 OTA) | 13,064,192 | `fc23372e91e90281892cdd979e6affd34c0e3f19146f7fbaf4a6507f521a8e54` | *(no permissive argument)* |

Inspect any of them with
[`../scripts/extract-boot-from-ota.sh`](../scripts/extract-boot-from-ota.sh).

## 3. Recovery

| Item | Bytes | SHA-256 |
|---|---:|---|
| TWRP 3.6.1 recovery image (`twrp-recovery-<serial>.img`) | 33,554,432 | `1b6538d566fd0a0c622ca2e78dedeb1b86a3dbf5f9199e9575ef67de0efd6e05` |

Verified byte-identical in the recovery partition **before and after** the OTA
install, which is what proves the ROM does not touch recovery.

## 4. Device partitions backed up before flashing (2026-10-30)

First time `efs`/modem were ever dumped on this unit. Restore with care; these
carry identity and radio calibration.

| Partition | Bytes | SHA-256 |
|---|---:|---|
| `boot` (permissive Android 10, pre-enforcing) | 33,554,432 | `d3068258ce373060d6ebd4d4a7be967a9c2df377534bf8d92e4883f28c5a886d` |
| `persist` | 33,554,432 | `d061870c25aaccc1156143b83d6a3f6d121d34c0fe3ea3ae9e774f8a7870531a` |
| `efs` | 16,777,216 | `355103dd5a693746166cc6129fb16f68dda76db87892fac45c47e57668c76214` |
| `modemst1` | 4,194,304 | `dec8b6f07f229d7eeabf1e650f55a594ac6e3c7bcac41c5b01f539125378277e` |
| `modemst2` | 4,194,304 | `402884e7976336d23621a53b78e7c603a16b8e9d69b66e4aa9a067274b6e0327` |
| `fsg` | 4,194,304 | `4e3e180a4f50bd3536ae90d8299fdd850be8f6f50107a34fca3e2ea1cdade33f` |
| `misc` | 1,048,576 | `f5f22730aa58099dade8760a2add1bdda5064f7b621c7151e145afcbdde12054` |
| `config` | 1,048,576 | `30e14955ebf1352266dc2ff8067e68104607e750abb9d3b36582b8af909fcb58` |

No `system`/`vendor`/`userdata` images exist off-device, so there is **no full
rollback set** — see [install.md §9](../docs/install.md#9-rollback).

## 5. Build outputs of the first successful `m bacon`

Superseded by the signed builds above, kept because the hashes appear in the
build logs and the troubleshooting write-up.

| File | Bytes | SHA-256 |
|---|---:|---|
| `system.img` (sparse; raw 3,397,386,240) | 1,078,473,140 | `e3cecf2b21494595b1441034d698eb239038f145b041c0e317df4a0a2a1a3742` |
| `vendor.img` (sparse) | 248,877,228 | `41816c1ca3d12c4072487d21e9c4c4c3a04dcca9b61c0223cf0f8aba93f8ecc3` |
| `recovery.img` (Lineage recovery; not shipped in the OTA) | 22,284,288 | `9910c42bda21239bbaa99985222f06cdd05b6ef91aba1b2d636eb8a994b60d37` |

## 6. Diagnostic images from the earlier bring-up (keep, do not ship)

| File | Bytes | SHA-256 | Note |
|---|---:|---|---|
| `boot.img` | 13,064,192 | `b335f5611d2329dfad1df6182d8bce7606ac85b6a0be07c2a704a7e57afcffe3` | same as the permissive OTA's boot |
| `system-raw.img` | 3,397,386,240 | `d071d4b81ab7354866ceec4da91fe714ade314f894078c7d930680cf2c082863` | hand-built, **rootfs-only labels**, flat image — booted `init` then looped `logd` |
| `vendor-raw.img` | 503,316,480 | `11aab794a42f7815ccef081433d528ba0cdeaa60ccadcc4c26708323884ef820` | raw conversion |

That flat image is the "cycle 0" failure described in
[`../VALIDATION.md`](../VALIDATION.md): a system-as-root device needs the
nested `/system` tree, not a flat `/`.

## 7. Verifying what you downloaded

```bash
sha256sum -c SHA256SUMS.txt --ignore-missing
sha256sum j8os-17.1-enforcing-20261030-0532-signed-ota.zip
unzip -p j8os-17.1-enforcing-20261030-0532-signed-ota.zip META-INF/com/android/otacert \
  | openssl x509 -noout -subject -fingerprint -sha256
```

The certificate subject must be your project key's subject, **not**
`CN=Android` (which is the AOSP test key).
