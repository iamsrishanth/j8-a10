# Contributing

This repository is the working record of an Android 10 port to the Samsung
Galaxy J8. Corrections backed by evidence are very welcome — the project's
value is in being accurate, not in looking finished.

## What helps most

- **Reproductions.** A build log excerpt that shows a failure (or success) on
  the pinned tree, with the exact command and the `git rev-parse HEAD` of the
  device tree.
- **Fixes with evidence.** Patches to the device tree that make
  `m bacon` complete, with the e2fsprogs/e2fsdroid version and the resulting
  image hash.
- **Runtime evidence.** `dmesg`, `logcat`, `getprop` dumps and a filled-in
  [validation matrix](docs/validation.md) from a real device.
- **Documentation fixes.** Wrong file paths, stale hashes, unclear steps.

## What to avoid

- Do **not** attach multi-gigabyte images, vendor blobs, kernel tarballs or
  any signing material (`.pk8`, `*.x509.pem`, keystores) to issues or pull
  requests.
- Do **not** post logs containing IMEI, serial numbers, MAC addresses, Wi-Fi
  keys or account identifiers.
- Do **not** open pull requests that add GApps, root solutions, debloat lists
  or tuning tweaks. Those are explicitly out of scope for this branch.

## Patch format

```bash
cd device/samsung/j8y18lte
git format-patch -1 --stdout > ../../patches/000N-short-description.patch
```

Keep the subject line short, the body explanatory, and state how the change
was tested. A patch that "should work" belongs in an issue, not in
`patches/`.

## Licence

By contributing you agree that your contribution is licensed under
Apache-2.0, matching the rest of the repository.
