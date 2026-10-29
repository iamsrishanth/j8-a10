# Signing builds with your own keys

Android decides whether `/data` is usable by the **platform signing
identity**. Flashing a build signed with different keys than the currently
installed ROM forces a **factory reset**. Plan for it.

This repository contains **no key material**, and never should.

## 1. Generate the key set

Two helper scripts automate everything below:

```bash
# generate a key set (once)
OUT=~/secure/j8os-keys ./scripts/make-keys.sh

# sign a built target-files package and emit a release OTA
KEYS=~/secure/j8os-keys ./scripts/sign-ota.sh
```

The long form, if you prefer to do it by hand:

```bash
mkdir -p ~/secure/j8os-keys && cd ~/secure/j8os-keys
export SUBJECT='/C=IN/ST=State/L=City/O=Your Org/OU=Android/CN=Your Name/emailAddress=you@example.com'

for k in releasekey platform shared media verity networkstack nfc; do
  ../../android/lineage-17.1/development/tools/make_key "$k" "$SUBJECT"
done
```

You get, per name, a `*.pk8` private key and a `*.x509.pem` certificate.
`make_key` prompts for a password unless you pass `no` as an extra argument —
a password-protected key is not usable by the non-interactive release tools.

Store them outside the source tree (in the example: `~/secure/`), never in
git, never on a shared drive, and back them up offline. Losing them means you
can never update your own device without another wipe.

## 2. Build the target files

```bash
cd ~/android/lineage-17.1
source build/envsetup.sh
breakfast lineage_j8y18lte

m -j8 target-files-package otatools
```

Output: `out/target/product/j8y18lte/obj/PACKAGING/target_files_intermediates/*.zip`

## 3. Sign and package

```bash
export KEYS=~/secure/j8os-keys
TARGET_FILES=$(ls -t out/target/product/j8y18lte/obj/PACKAGING/target_files_intermediates/*.zip | head -1)

sign_target_files_apks -o -d "$KEYS" \
  "$TARGET_FILES" signed-target_files.zip

ota_from_target_files -k "$KEYS/releasekey" --block --backup=true \
  signed-target_files.zip signed-ota.zip
```

Or simply: `KEYS=~/secure/j8os-keys ./scripts/sign-ota.sh`, which also checks
that the OTA certificate matches your release key before declaring success.

`--backup=true` keeps `system/bin/backuptool.sh` usable for addon.d scripts.
Do not pass `--no_prereq` or strip the OTA assertions — `TARGET_OTA_ASSERT_DEVICE :=
j8y18lte` is your protection against flashing the wrong phone.

Verify:

```bash
unzip -p signed-ota.zip META-INF/com/android/otacert | \
  openssl x509 -inform PEM -noout -fingerprint -sha256
openssl x509 -in "$KEYS/releasekey.x509.pem" -noout -fingerprint -sha256
```

The two fingerprints must match.

## 4. What signing does *not* do on this device

- **No AVB.** This tree sets no `BOARD_AVB_ENABLE` and the 3.18 kernel has no
  AVB support. The OTA is JAR-signed, but there is no verified-boot chain.
  See [integrity.md](integrity.md).
- **No dm-verity.** `PRODUCT_SUPPORTS_VERITY` is never set, so no hash tree is
  appended and `misc_info.txt` has no `verity=` key.
- **No re-signing of APEX containers** on 17.1's documented flow. `OsuLogin`
  and `ServiceWifiResources` keep their source test certificates, and
  `CtsShimPrebuilt` stays unsigned. That is fine for a bring-up build and not
  fine for something you ship to other people.

## 5. Key hygiene

- Never commit `*.pk8`, `*.x509.pem`, keystores, or `~/.android/`.
- Never paste a key into an issue, a log, or a chat.
- Keep keys out of the phone image — they are *for* signing, not *for* the
  device.
- If you suspect exposure: generate a new key set and re-sign. Rotation costs
  a data wipe on every device, which is the correct price.
- The vendored device tree and the OTA artifacts in this repository contain no
  secrets; keep it that way when you contribute back
  ([CONTRIBUTING.md](../CONTRIBUTING.md)).
