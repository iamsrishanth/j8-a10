# Project history

The Android 10 build did not start as the plan. It is the third target this
device has been tried against, and understanding why the first two failed is
the best argument for why this one is the right one.

## Timeline

### 2026-10-24 — Android 12 plan, then Android 11

The project started with a specification for **LineageOS 19.0 (Android 12L)**
on this device: 32-bit userspace, 64-bit kernel, MindTheGapps, KernelSU on
kernel 3.18, own signing keys, aggressive debloat. That plan was written
before the source tree was inspected.

Two blockers appeared immediately:

- **Android 12 needs eBPF in the kernel.** The `j8y18lte` kernel is 3.18.140.
  `bpfloader` is fatal on failure, and `netd` depends on it. Backporting eBPF
  to 3.18 is not a realistic bring-up task.
- **There is no official Android 12 MindTheGapps**, and the device tree's
  `lineage-19.0` branch looked like a copy of `18.1` (VNDK and sepolicy legacy
  paths unchanged for a tree that was never built).

The target was revised to **LineageOS 18.1 (Android 11)**, which the device
already ran as AICP 11 — evidence that the vendor blobs and kernel support it.

### 2026-10-24 — C0: an Android 11 build

LineageOS 18.1 was synced, patched (SELinux enforcing, insecure props removed,
TEE policy path fixed), built, and signed with project keys. The result — C0 —
was ~1.4 GB of target files and a 568 MB signed OTA. Static validation passed:
correct partition sizes, own-key certificate on the OTA, enforcing SELinux in
the boot cmdline, no recovery image in the OTA (so TWRP would survive).

C0 was never installed during this session. The reports are preserved in
[`history/`](../history/).

### 2026-10-26 — C0 installed; it does not finish booting

With TWRP 3.6.1 working over ADB, C0 was installed. It reached the boot
animation under **permissive** SELinux but `system_server` never completed,
because the vendor audio HAL path never published `media.audio_policy`. The
viability analysis concluded the mismatch is structural: **Android 11 framework
against Android 10-era vendor blobs** — HAL interface, audio policy and
keymaster behaviours do not line up.

Two conclusions came out of that failure:

1. Flashing is not the bottleneck; matching the framework to the blobs is.
2. The device needs an **Android 10** system, because the blobs are Android 10.

### 2026-10-26 — Android 10 (LineageOS 17.1)

A 120 GB `lineage-17.1` tree was synced with device / kernel / vendor pinned to
the `goldfish07` repositories. The build compiled the kernel, boot image,
recovery image and vendor image, then stopped at the system image with
`e2fsdroid` failures around the root directory entries (`/firmware`, `/omr`,
`/config/.keep`).

The failure was initially "fixed" by deleting labels out of `file_contexts`
and `config.fs`. That is the wrong fix: it makes the build pass while leaving
an image whose root paths have no SELinux labels. The edits were reverted from
git, and the real investigation started:

- the compiled `file_contexts.bin` is generated from a merged set of policy
  directories, and the device's own `sepolicy` directory was not reaching the
  aggregation the system image uses;
- the `e2fsprogs` error text — `searching for label "/firmware"` — comes from
  `selabel_lookup()` failing to find *any* matching rule, not from a missing
  file;
- `/firmware` is a **runtime** mount point (`/vendor/firmware_mnt` is the vfat
  firmware partition, mounted with `context=u:object_r:firmware_file:s0`), not
  something that belongs in the system image;
- so a bare `/firmware` entry appearing in the staging tree is a symptom of
  manual workarounds left behind in `out/`, and the correct fix is to keep the
  staging tree clean and make the policy aggregation correct — not to delete
  labels.

### 2026-10-29 → 2026-10-30 — the build is fixed, and the phone boots

The investigation converged on a single wrong variable. `e2fsdroid` was not
tripping over root folders or `.keep` files — it was labelling an image built
from a **file_contexts that never contained the device's own policy**. In
`BoardConfig.mk`, `BOARD_SEPOLICY_DIRS += $(LOCAL_PATH)/sepolicy` was evaluated
when `$(LOCAL_PATH)` had already been rewritten, so the list contained
`system/sepolicy/sepolicy` and every j8y18lte context (`/firmware`, `/omr`,
`/efs`, the block devices, the vendor service domains) was silently dropped.
A forced `$(warning)` dump proved it; using the literal path fixed it, and a
missing trailing newline in `sepolicy/property_contexts` accounted for the
second failure ("Type 'camera blacklist prop readable to everything' is not
valid").

From there the pipeline ran end to end:

1. `m bacon` → permissive OTA; signed with the project's own release keys.
2. Installed through TWRP (`/sbin/twrp install`), data formatted.
3. **Booted**: `sys.boot_completed=1`, Setup Wizard on a 720×1480 display,
   Wi-Fi, Bluetooth, Samsung RIL daemons, 5 sensors, 2 cameras, storage,
   charging all healthy. `setenforce 1` held for 5+ hours.
4. An **enforcing** OTA was built and verified (its boot image simply omits
   `androidboot.selinux=permissive`).

Earlier boot cycle 0 had failed with `logd` exiting 255 in a loop. That image
was *flat* and labelled entirely `rootfs`; this device is system-as-root, so
`/system/bin/*` did not exist as the init scripts expected. The native nested
image with correct labels removed that failure.

Then the session hit a hardware limit, not a software one: after
`adb reboot recovery` the phone went dark and stopped enumerating on USB — the
battery had drained while the host slept. Nothing was being written at the
time. The enforcing image is ready to flash when the device returns.

Current state: [../STATUS.md](../STATUS.md). Measured results:
[../VALIDATION.md](../VALIDATION.md).

## <a name="scope"></a>Why the scope is narrow

Deliberate exclusions, and the reasoning:

| Excluded | Why |
|---|---|
| GApps | Changes the validation surface. A ROM that boots without GApps proves the platform; adding GApps hides platform problems behind Play Services behaviour. Add later, once the base is stable. |
| Magisk / KernelSU | Any root solution changes the boot image and the security model. Debugging a boot failure is much harder when the boot image is patched. Root is a second project. |
| Debloat | Post-boot work; removing packages before the base is validated makes "which removal broke it?" the first question of every bug. |
| Kernel tuning | The kernel is an upstream 3.18 Samsung tree. Tuning it before the ROM boots optimises the wrong thing. |
| Bootloader changes | Irreversible risk on a Knox-tripped device with `flash.locked=1`. |
| VoLTE/VoWiFi | Depends on carrier configs and IMS blobs that are not in this tree. Best-effort at most, never a promise. |

## Lessons worth carrying forward

1. **Match the framework to the blobs.** The vendor blobs are Android 10; the
   system that boots is the one whose HAL expectations they meet.
2. **Never make a build pass by deleting policy.** A missing label is a runtime
   crash waiting to happen, and it hides the real bug.
3. **One change per build cycle, one artifact identity per test.** Two unknown
   variables at once is how days disappear.
4. **A build that flashes is not a ROM.** Identity, HALs, RIL and power
   management only count when measured on hardware.
5. **Keep the recovery route alive.** Broken power button plus no bootable
   recovery equals a brick, and no amount of good source code fixes that.
