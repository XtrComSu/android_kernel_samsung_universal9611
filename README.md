# XT-Line — custom kernel for Samsung Galaxy M31 (exynos9611)

A **Linux 4.14.357** kernel for the Galaxy M31, built around KernelSU-Next with SUSFS,
an in-tree NoMount VFS path-redirection subsystem, and a broad set of external USB
Wi-Fi / NetHunter drivers.

> **Contributors and AI agents: read [`AGENTS.md`](./AGENTS.md) first.**
> It lists the invariants CI enforces and the traps that have already caused a device
> bootloop. Change-by-change rationale lives in [`CHANGELOG.md`](./CHANGELOG.md), and
> the deep technical reference is [`XT-Xenos9611.md`](./XT-Xenos9611.md).

---

## What's in it

| | |
|---|---|
| Kernel | 4.14.357, `CONFIG_LOCALVERSION="-XT-Line-AOSP"` |
| Root | **KernelSU-Next** `v3.3.0-legacy-susfs-v2` (manual hook) |
| Hiding | **SUSFS v2.3.0** (NON-GKI) — 9 implemented features, kernel logging off |
| Module mounting | **NoMount** in-tree (`fs/nomount/`), replaces magic mount / overlayfs |
| Wi-Fi | `r8188eu` (RTL8188EU/EUS), plus mac80211/cfg80211, mt7601u, ath9k_htc, rt2800usb, rtl8192cu, ath10k_usb |
| Extras | WireGuard, BFQ (opt-in), USB serial, RNDIS, mass-storage/UAC gadgets |
| Device | Samsung Galaxy M31 (exynos9611), LineageOS 24.0 base |

## Building

The supported path is CI:

```sh
gh workflow run build-kernel.yml --repo XtrComSu/android_kernel_samsung_universal9611
```

It builds `exynos9611-m31_defconfig` with a pinned clang, then runs a
**Post-build verification** step that asserts every invariant listed in `AGENTS.md`
§2. A build that "compiles" but fails that step is a failure — it has already caught a
silently-dropped feature once.

Locally, the same thing is driven by `build_kernel.py`. Only the **m31** defconfig
carries the KernelSU/SUSFS block; the other six `exynos9611-*` defconfigs are inert.

Artifacts: an AnyKernel3 flashable zip, plus `kmods/r8188eu.ko`.

## Installing

1. Flash the zip from a custom recovery / KernelSU manager.
2. **Re-copy `r8188eu.ko`** to `/data/adb/r8188eu/` if you use the Wi-Fi adapter — its
   CRC is tied to the kernel build and it will refuse to load otherwise.
3. The RTL8188EU firmware is shipped as a **systemless** overlay
   (`rtl8188eu_firmware` module) because the stock ROM contains no Realtek firmware.
   Nothing is written to `/vendor`, so AVB is untouched.

## Verifying a boot

```sh
su -c '
  uname -r
  /data/adb/modules/nomount/bin/nm version      # 20 = kernel API alive
  /data/adb/modules/nomount/bin/nm rule list    # expect ONLY the rtl8188eufw rule
  cat /data/adb/nomount/nomount.log             # "[OK] Boot phase completed safely"
  ksud susfs support && ksud susfs features     # Supported + 9 features
'
```

A healthy NoMount rule set is **one** redirection. Any rule touching `/system/framework`,
`/system/etc` or `/system/bin` is a bootloop risk.

## SUSFS configuration on device

SUSFS is driven by the `brene` module, which reads **`/data/adb/brene/`**:

| File | Purpose |
|---|---|
| `config.sh` | feature flags (`hide_cusrom`, `config_selinux_hide`, …) |
| `custom_sus_path_loop.txt` | paths hidden via `add_sus_path_loop` — **prefer this** |
| `custom_sus_path.txt` | paths hidden via the weaker plain `add_sus_path` |
| `custom_sus_map.txt` | paths hidden from `/proc/<pid>/maps` via `add_sus_map` |
| `custom_kernel_umount.txt` | mounts to kernel-umount |

The reliable pattern brene itself uses is **both** `add_sus_map` *and*
`add_sus_path_loop` for a given path.

> `/data/adb/susfs4ksu/` is **not used** — it is a leftover from the old `susfs4ksu`
> module, which brene disables on install. Editing it has no effect.

SUSFS hiding only applies to **umounted app processes**, so it cannot be validated with
`su <uid> -c ...` from a root shell — use a real app.

## Known limitations

- **SUSFS cannot hide installed packages.** It is a kernel-only, VFS-level feature: it
  hides *files*, `/proc/<pid>/maps` entries, mounts and `stat` results — and needs no
  Zygisk. But a detector that enumerates packages through `PackageManager` (this ROM
  ships 13 packages matching `lineage`, incl. the framework package
  `lineageos.platform`) cannot be defeated by SUSFS at any configuration. Package
  hiding requires a **Zygisk/Xposed** module, which reintroduces in-memory injection
  artifacts. That trade-off is real and unavoidable.
- **`/data` is f2fs with `fsync_mode=nobarrier`.** An unclean shutdown can zero-fill
  recently-written files while preserving their size. This has already destroyed
  NoMount's `module.prop` (twice) and one module's payload. Reflash to repair.
- **NoMount whiteout hazard:** a module shipping character-device nodes (`crw-rw---- 0,0`)
  causes those paths to be whiteouted *system-wide*. Doing that to framework files
  bootloops the device — that is exactly what happened with `lineage_hide`.
- **`CONFIG_KSU_SUSFS_SUS_MEMFD` cannot be enabled**: SUSFS v2.3.0 does not implement
  it, and enabling it fails the build. Memory hiding uses `SUS_MAP` instead.
- **SUSFS hiding also requires the target to be an umounted app**: a process with root
  granted is never marked umounted, so hiding is skipped for it. Keep detector apps
  un-rooted.
- Kernel logs are restricted and SUSFS logging is off; debugging hiding behaviour
  requires temporarily re-enabling it.

## License

Kernel source is GPL-2.0 as inherited from the upstream/vendor tree. NoMount is vendored
from [maxsteeel/nomount](https://github.com/maxsteeel/nomount); see `fs/nomount/`.
