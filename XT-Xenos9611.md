# XT-Line

Samsung Galaxy M31 (Exynos 9611) kernel — KernelSU-Next + SUSFS, with
external Wi-Fi adapter and NetHunter-style gadget capabilities.

Version: `XT-Line v0.2.0 — Aegis`

---

## SOURCE

| Field | Value |
|---|---|
| Repository | `https://github.com/Parbindar7/android_kernel_samsung_universal9611` |
| Branch | `lineage-24.0` |
| Baseline commit | `1500b70ea116c6b460372492ff4dbe4abffa6cf0` |
| Kernel version | Linux 4.14.357 |
| Arch | arm64 |
| Target device | Galaxy M31 / Exynos 9611 (non-GKI vendor kernel) |
| Defconfig | `arch/arm64/configs/exynos9611-m31_defconfig` |
| Build branch | `ksun-susfs` |

The tree is a non-GKI vendor 4.14 kernel. `CONFIG_KPROBES` is **not** set and
there are no RKP / DEFEX / PROCA / FIVE / KDP security dirs.

## KSUN

| Field | Value |
|---|---|
| Project | KernelSU-Next (`https://github.com/sidex15/KernelSU-Next`) |
| Tag | `v3.3.0-legacy-susfs-v2` (v3.3.0 line + SUSFS v2 glue, manual hook) |
| Commit | `36679224f26d03f2bb105c4686cf390eb63178c2` |
| Reported version | `33214` (= 30000 + 3014 commits + 200; matches the v3.3.0 manager) |
| UAPI version | `2` (matches the KernelSU-Next v3.3.0 manager) |
| Location | `drivers/kernelsu/` (vendored, not a submodule) |
| Hook mode | `CONFIG_KSU_MANUAL_HOOK=y` |

History: v3.4.0 was tried first (UAPI 4, version 33225) but its manager
would not connect; the kernel is now pinned to the v3.3.0 legacy+SUSFS line,
whose UAPI (2) and version (33214) match the v3.3.0 manager exactly.
The only difference between the two lines is KSU-side; the SUSFS v2.3.0
kernel integration is unchanged and remains compatible (only the optional
`CMD_SUSFS_ADD_SUS_MEMFD` is absent).

## SUSFS

| Field | Value |
|---|---|
| Version | `v2.3.0` (NON-GKI) |
| Source | `sidex15/android_kernel_lge_sm8150`, branch `OpenELA-4.14.y-susfs` |
|       | `929a8eac7` (a 4.14 tree whose SUSFS API matches `legacy-susfs-v2`) |
| Files | `fs/susfs.c`, `include/linux/susfs.h`, `include/linux/susfs_def.h` |
| Module target | `sidex15/susfs4ksu-module` (v1.5.2-R28, needs SUSFS >= 1.5.2) |

## COMPATIBILITY

Why this exact pair and not "newest of everything":

- Upstream `simonpunk/susfs4ksu` tops out at **v1.5.5** for 4.14 (tags
  `1.4.2-kernel-4.14`, branch `kernel-4.14`); there is **no** upstream v2.x
  4.14 patch. The v2.x 4.14 implementation exists only in sidex15's SM8150
  tree, which is a real, working 4.14 + KSUN + SUSFS v2.3.0 integration.
- `legacy-susfs-v2` requires the **v2.0.0+** SUSFS supercall API
  (`CMD_SUSFS_ADD_SUS_MEMFD`, `susfs_extra_works`, `susfs_run_sus_path_loop`,
  ...). Those are present in the v2.3.0 tree.
- API cross-check: 27 required `susfs_*` symbols and 17 required
  `CMD_SUSFS_*` ids were compared. Everything resolves except
  `susfs_add_sus_memfd` / `CMD_SUSFS_ADD_SUS_MEMFD`, which are optional and
  gated behind `CONFIG_KSU_SUSFS_SUS_MEMFD` (left disabled).

Hook-mode decision:

- 4.14 + `CONFIG_KPROBES=n` => kprobes path (`>=5.10`) and syscall-table path
  (`>=4.17`) are both unusable => `CONFIG_KSU_MANUAL_HOOK`.

## HOOKS

Manual hooks (compiled by KernelSU-Next Kbuild, detected via
`ksu_handle_sys_reboot` in `kernel/reboot.c`):

| File | Call site | Function |
|---|---|---|
| `fs/exec.c` | `__do_execve_file` | `ksu_handle_execveat` / `ksu_handle_execveat_sucompat` |
| `fs/open.c` | `SYSCALL_DEFINE3(faccessat)` | `ksu_handle_faccessat` |
| `fs/stat.c` | `vfs_statx` | `ksu_handle_stat` |
| `fs/read_write.c` | `vfs_read` | `ksu_handle_vfs_read` |
| `kernel/reboot.c` | `SYSCALL_DEFINE4(reboot)` | `ksu_handle_sys_reboot` |

SUSFS hooks (`CONFIG_KSU_SUSFS*`): `fs/namei.c`, `fs/namespace.c`,
`fs/notify/fdinfo.c`, `fs/open.c`, `fs/stat.c`, `fs/statfs.c`, `fs/super.c`,
`fs/readdir.c`, `fs/proc/{base,cmdline,fd,task_mmu,proc_namespace}.c`,
`mm/memory.c`, `kernel/kallsyms.c`, `kernel/sys.c`,
`security/selinux/avc.c`, plus task/mount struct fields in
`include/linux/sched.h` and `include/linux/mount.h`.

`drivers/kernelsu/Kbuild` additionally seds in 4.14 backports at build time:
`fs/namespace.c` (`can_umount`, `path_umount`), `fs/internal.h`,
`include/linux/seccomp.h` (`filter_count`), and SELinux
`selinux_inode`/`selinux_cred` helpers in
`security/selinux/{hooks,selinuxfs,objsec.h,xfrm}.c`.

## PATCHES

The SUSFS kernel-side change set was applied against this tree hunk-by-hunk,
filtered to only the SUSFS logic. Result: **20 files changed, 0 rejected
hunks, no `.rej` files.**

## CONFIG

`arch/arm64/configs/exynos9611-m31_defconfig`:

```
CONFIG_KSU=y
CONFIG_KSU_MANUAL_HOOK=y
CONFIG_KSU_SUSFS=y
CONFIG_KSU_SUSFS_SUS_PATH=y
CONFIG_KSU_SUSFS_SUS_MOUNT=y
CONFIG_KSU_SUSFS_SUS_KSTAT=y
CONFIG_KSU_SUSFS_TRY_UMOUNT=y
CONFIG_KSU_SUSFS_SPOOF_UNAME=y
CONFIG_KSU_SUSFS_ENABLE_LOG=y
CONFIG_KSU_SUSFS_HIDE_KSU_SUSFS_SYMBOLS=y
CONFIG_KSU_SUSFS_SPOOF_CMDLINE_OR_BOOTCONFIG=y
CONFIG_KSU_SUSFS_OPEN_REDIRECT=y
CONFIG_KSU_SUSFS_SUS_MAP=y
# CONFIG_KSU_SUSFS_SUS_MEMFD is not set
```

`make O=out exynos9611-m31_defconfig` resolves every symbol (verified).

## OPTIMIZATION

Applied (v0.1.0 gaming/AI pass — conservative, no guardrail violations):

- Networking: **reverted.** An earlier pass moved the default TCP congestion
  control from `bic` to `cubic` and enabled BBR; both were rolled back at the
  user's request, so the kernel again ships `DEFAULT_BIC=y`,
  `DEFAULT_TCP_CONG="bic"` and `CONFIG_TCP_CONG_BBR` unset. Note that both the
  choice symbol (`DEFAULT_BIC`) and the derived string had to be changed — the
  string alone does nothing. CI now asserts `bic` is the default.
- GPU: disabled `CONFIG_MALI_GATOR_SUPPORT` (Arm Streamline tracing) and
  `CONFIG_MALI_MIDGARD_ENABLE_TRACE` (kbase ktrace) — both are pure
  profiling/instrumentation with per-command overhead on the gaming path and no
  functional effect otherwise.
- GPU (DVFS): enabled `CONFIG_MALI_EXYNOS_INTERACTIVE_BOOST=y` — the vendor's
  bounded, touch-triggered GPU boost (raises GPU frequency for a fixed duration
  on interaction). It was off by default; it is a DVFS response, not a forced
  frequency. Effect depends on the vendor GPU framework invoking the boost API;
  revert by setting it back to `n`.

### DVFS / voltage — why there is no undervolt

Verified against this tree: the CPU/GPU/bus **frequency and voltage tables are
not in the kernel**. There are no `opp` tables for 9610/9611 and no `ect` node;
DVFS is requested from the **ACPM firmware** via `cal_id` (`ACPM_DVFS_CPUCL0/1`,
`MIF`, `INT`, `G3D`, ...), and `MARGIN_LIT/MARGIN_BIG/...` are enum identifiers,
not voltages. Voltage tables are parsed from the signed **ECT** partition.
Consequently a kernel-side undervolt/overclock is not possible without modifying
signed firmware, which is out of scope ("too radical").

The only kernel-side DVFS knobs are the **bus devfreq domains** (`freq_info` in
`exynos9610.dts`, governor `simple_interactive`), and those are tunable at
runtime via `/sys/class/devfreq/*/min_freq|max_freq` (no rebuild). Raising the
MIF/INT floor was deliberately **not** baked in: it trades battery for heat,
which tends to *lower* sustained gaming clocks — the opposite of the goal.

Already in place from the vendor defconfig (kept, not changed):

- CPU: `schedutil` is the default governor; `CONFIG_PREEMPT=y`; WALT load
  tracking; `CONFIG_UCLAMP_TASK=y`; `SIMPLIFIED_ENERGY_MODEL`.
- I/O: `mq-deadline` default (low latency on UFS/eMMC), kyber also built in.
- Memory: ZRAM with LZ4 (fastest), MEMCG swap.
- Exynos: DVFS manager, bus devfreq (`simple_interactive`), page boost.

Deliberately NOT changed (guardrails):

- Thermal protection (`EXYNOS_THERMAL`, `CPU_THERMAL`, ACPM) untouched.
- No voltage/undervolt changes, no forced/over-clocked frequencies.
- CPU idle (`CPU_IDLE_GOV_MENU`) left enabled.
- No peak-only tricks (e.g. `performance` governors or forcing max freq), which
  would raise peak but hurt sustained throughput and thermals.

Optional runtime knobs (not baked in; tune to taste in an init/ksu script):

- `schedutil/*_rate_limit_us`: lower (e.g. 2000) for snappier ramping, higher
  (e.g. 10000) for efficiency.
- Bus DVFS floor: `/sys/class/devfreq/<mif|int>/min_freq` — raise for more
  memory/interconnect headroom at the cost of battery and heat (not baked in;
  `CONFIG_PM_DEVFREQ=y` exposes these).
- GPU boost: now compiled in (`CONFIG_MALI_EXYNOS_INTERACTIVE_BOOST=y`).

## NETWORKING / NETHUNTER CAPABILITIES

Added for external Wi-Fi adapters and NetHunter-style use:

- `CONFIG_MAC80211=y` — **was disabled**. Without it, no softmac USB Wi-Fi
  adapter (monitor mode / packet injection) can work at all; this was the
  single biggest gap.
- USB Wi-Fi drivers available in this 4.14 tree, now enabled: `RTL8XXXU`
  (RTL8188/8192/8723), `MT7601U`, `ATH9K_HTC`, `RT2800USB` (+ RT33/35/3573/
  53/55XX), `RTL8192CU`/`RTLWIFI`, `ATH10K_USB`.
- `CONFIG_USB_CONFIGFS_F_HID=y` — HID gadget, i.e. BadUSB / external
  keyboard-mouse injection (USB configfs was already enabled).
- Bluetooth: **not enabled.** This tree has `CONFIG_BT` unset in every
  exynos9611 defconfig, and turning it on **fails to build** because the vendor
  import neutered the core HCI socket operations: `hci_sock_release`,
  `hci_sock_ioctl`, `hci_sock_bind`, `hci_sock_getname` and `hci_sock_create`
  in `net/bluetooth/hci_sock.c` (plus one function in
  `net/bluetooth/l2cap_core.c`) are stubbed. Their bodies are present but
  wrapped in a `/* ... */` block that is closed early by a nested comment, so
  the code compiles without its declarations. Restoring those functions is
  required before `BT` — and therefore NetHunter USB-BT dongles — can work.

- RTL8188EU/EUS adapters (`0bda:8179`, e.g. TP-Link TL-WN725N): `r8188eu`
  lives in `drivers/staging/rtl8188eu` and its USB table lists `0bda:8179`,
  but its Kconfig is `depends on m` — **module-only, never built-in**. It is
  now built as `CONFIG_R8188EU=m` and shipped as `r8188eu.ko` (vermagic
  `4.14.357-XT-Line-AOSP ... aarch64`). Load it with
  `insmod /path/r8188eu.ko`, or install `r8188eu-loader.zip` in the KernelSU
  manager for auto-load at boot. Building it needed two fixes: a
  `-Wlogical-not-parentheses` rewrite in `rtw_ieee80211.c:309` and
  clang-safe `-Wno-error`/`-Wno-unknown-warning-option` ccflags for the
  driver.

Notes:

- Out-of-tree adapters (RTL8812AU/8814AU/8821AU "rtl88xxau", MT76x0U, RTW88)
  are **not in this 4.14 tree** — those need an out-of-tree driver.
- USB host/OTG is already present (`USB_XHCI_HCD`), so adapters enumerate.
- Monitor mode / injection is a driver + userspace concern (aircrack-ng etc.);
  the kernel now provides the required mac80211/cfg80211 stack.

## TUNING / HOOKS / HARDENING

- I/O scheduler: `CONFIG_IOSCHED_BFQ=y` — BFQ was already in-tree
  (`block/bfq-iosched.c`, registered as `iosched_bfq_mq` with `uses_mq = true`,
  i.e. **blk-mq only**) but disabled, so it was not even selectable. It is now
  available alongside `mq-deadline` and `kyber`.
  The device storage is UFS (`13520000.ufs`) and every queue is blk-mq; the
  active scheduler is `[mq-deadline]`. That stays the **default**: on fast UFS
  mq-deadline/kyber generally beat BFQ, whose advantage is on slow storage.
  BFQ is opt-in per device:
  `echo bfq > /sys/block/sda/queue/scheduler`.
  Note `CONFIG_DEFAULT_IOSCHED` has no prompt, so kconfig always recomputes it
  and the defconfig string is cosmetic.
- `CONFIG_KPROBES=y` — was off, and that is precisely what forced the
  manual-hook KernelSU line. Enabling it makes kprobe infrastructure available
  (a prerequisite for kprobe-based KSU/SUSFS variants and for runtime-probing
  tools). Hook mode is still `CONFIG_KSU_MANUAL_HOOK=y`; switching to kprobe
  hooks is a separate change and needs the matching KSUN branch.
- `CONFIG_SECURITY_DMESG_RESTRICT=y` — dmesg readable by root only.
- CI pins `KBUILD_BUILD_USER=builder` / `KBUILD_BUILD_HOST=localhost` so the
  runner identity no longer leaks into `/proc/version`.
- NetHunter extras: `USB_SERIAL_OPTION` (3G/4G/GPS dongles),
  `USB_NET_RNDIS_HOST`, `USB_CONFIGFS_MASS_STORAGE`,
  `USB_CONFIGFS_F_UAC1`/`UAC2` (USB audio for Y-cables), `INPUT_JOYDEV`.

## MODULE MOUNTING (OVERLAYFS / "HYBRID MOUNT")

Kernel prerequisites are all present: `OVERLAY_FS` (with `REDIRECT_DIR`),
`TMPFS_XATTR`, `TMPFS_POSIX_ACL`, `FUSE_FS`, SELinux and unsigned-module
loading.

If modules mount but their files are not visible inside apps, the usual cause
is **SUSFS hiding KernelSU's own mounts**: `SUS_MOUNT` together with
`hide_sus_mnts_for_non_su_procs` (on by default in the SUSFS userspace module)
makes ksud's overlay mounts invisible to non-su processes. Set
`hide_sus_mnts_for_non_su_procs 0` in the SUSFS module config (or disable
`SUS_MOUNT`) so apps can see mounted module files.

Also keep only one mounter active — KernelSU-Next's built-in magic mount and
the "Hybrid Mount" module should not both mount the same modules.

## NOMOUNT (BUILT-IN VFS PATH REDIRECTION)

`fs/nomount/` carries maxsteeel/nomount **v20**, integrated built-in. This is the
out-of-tree VFS path-redirection subsystem used by the NoMount metamodule for
KernelSU-Next / APatch.

Why built-in rather than the shipped LKM: the metamodule's release ZIP carries
prebuilt `nomount-android*.ko` only for GKI 5.10 / 5.15 / 6.1 / 6.6 / 6.12. On a
legacy kernel those will not load, because the internal VFS symbols the driver
relies on are not exported to modules — upstream's own README states that
legacy (<5.10) kernels must integrate it in-tree. Hence `CONFIG_NOMOUNT=y`.

How presence is detected (the "Internal API" the installer probes for): the
subsystem registers a **key type named `nomount`** from `fs_initcall`, so the
metamodule's kernel-support check succeeds once this kernel is flashed. That
requires `CONFIG_KEYS=y`, which is already set in every defconfig.

4.14 compatibility: the compat layer in `nomount.h` / `nomount.c` already covers
this generation — the pre-4.11 `getattr` signature, the empty `IDMAP_*` branch
(below 5.12), the `NM_ACTOR_RET` / `FLAGS_ARG` shims and a `DCACHE_DONTCACHE`
stub. The `MODULE_IMPORT_NS` block at the end of `nomount.c` is wrapped in
`LINUX_VERSION_CODE >= 5.0`, so it is not compiled on 4.14.

Files: `fs/nomount/{nomount.c,nomount.h,Kconfig,Makefile}` (vendored, *not*
symlinked to an out-of-tree clone as `setup.sh` does, so the CI build stays
reproducible), one line in `fs/Kconfig`, one in `fs/Makefile`, and
`CONFIG_NOMOUNT=y` in all seven exynos9611 defconfigs. CI asserts both the
config symbol and the `nomount` key-type string inside the built Image.

**Troubleshooting — "installed but nothing mounts".** KSUN only treats NoMount
as the mounter while its `module.prop` contains `metamodule=true`. Without that
flag the module still shows up in `ksud module list`, `nm version` still
answers `20`, and `nm rule list` is simply **empty** — `metamount.sh` is never
invoked, so no module file appears under its target path (`/vendor/firmware/…`,
`/system/…`). Diagnosed on this device when an unclean shutdown zero-filled
`module.prop`: the file was exactly the template's 175 bytes, all NUL. Restoring
the flag and re-running `sh /data/adb/modules/nomount/metamount.sh` (absolute
path — a relative `$0` makes `MODDIR` `.` and the loader path `./bin/nm` breaks
once the script `cd`s into a module dir) restores redirection immediately, and
the normal boot path picks it up again after a reboot.

Relevant detail: `/data` is f2fs mounted `fsync_mode=nobarrier`, so an unclean
shutdown can zero-fill recently written files. In this incident it also hit
five `tricky_store/autopif4/*.html` caches plus several logs and 1-byte state
files. `module.prop` is the one that matters — losing `metamodule=true` silently
disables the whole metamodule. `nm` rules live only in RAM, so they are always
re-registered at boot by `metamount.sh`; only the flag is persistent.

## STEALTH (SUSFS) NOTES

SUSFS itself is wired and complete: every `CMD_SUSFS_*` in
`drivers/kernelsu/supercall/supercall.c` dispatches to the kernel
implementation in `fs/susfs.c`, and all features are compiled in (see
CAPABILITIES). No SUSFS version gate exists between the KSU glue and the
kernel side.

What SUSFS hides is **only what you configure** (`sus_path`, `sus_mount`,
`sus_kstat`, `sus_map`, `open_redirect`, `try_umount`), and it applies to
zygote-spawned app processes. It does **not** invent traces to hide.

Therefore "LineageOS traces" that are **system properties**
(`ro.lineage.*`, `ro.build.fingerprint`, `ro.build.type`, ...) are *not* a
SUSFS concern — those are userspace. They must be changed with resetprop /
PlayIntegrityFix / a hiding module, not the kernel.

Kernel-side leak that SUSFS does *not* cover, fixed here:

- `/proc/config.gz` (`CONFIG_IKCONFIG` + `CONFIG_IKCONFIG_PROC`) exposed the
  entire kernel config to any app, including `CONFIG_KSU=y` and
  `CONFIG_KSU_SUSFS=y`. Both are now disabled, so there is no `/proc/config.gz`.
- `CONFIG_LOCALVERSION="-XT-Line-AOSP"` (renamed from `-Everline-AOSP`), which
  shows up in
  `/proc/version` as a custom-kernel string. Rename it if you want a neutral
  kernel identity.
- `CONFIG_KSU_SUSFS_HIDE_KSU_SUSFS_SYMBOLS=y` keeps ksu/susfs out of
  `/proc/kallsyms`.

## UPSTREAMING ASSESSMENT (Exynos 9611 -> 5.15 / 6.x / 7.x)

Checked against a current mainline tree (v7.2 / v7.3-rc): **mainline has no
Exynos 9610/9611 support at all** — no clock driver, no pinctrl, no
`drivers/soc/samsung` support and no DTS entry. Nearby SoCs *are* mainlined
(exynos7870, 7885, 850, 8895, 9810, 990, 2200 and exynosautov9/920), so it is
not impossible in principle, but 9610/9611 specifically has zero upstream
support today.

Scale and blockers in this tree:

- ~631 MB of drivers, ~29.5k files in `drivers/` + `arch/arm64/boot/dts/exynos`.
- Core power/DVFS runs through the Samsung **ACPM firmware** interface
  (`samsung,exynos-acpm*`) — there is no mainline driver for it.
- GPU is the vendor **Mali Bifrost DDK** (`bv_r38p1`); mainline would use
  Panfrost instead.
- Modem, ISP/camera, audio, display and the Samsung security stack are
  vendor-only.

Verdict:

- Full upstream to 5.15/6.2/7.x **as a working phone: not realistic.** It
  requires Samsung's unpublished hardware documentation (ACPM, ISP, modem) and
  is a multi-year, multi-engineer effort, plus mainline review.
- A partial "boots Linux, limited peripherals" bring-up is conceivable but
  would lose the phone stack, and is still months-to-years of work.
- Practical path for a working M31 remains this vendor 4.14 kernel (Samsung
  never released a newer one for 9610/9611). GKI / vendor-module upgrading is
  not available either, because this SoC predates GKI.

## MANAGER

Use the **KernelSU-Next (KSUN) manager v3.3.0** —
`KernelSU_Next_v3.3.0-spoofed_33214-release.apk`. Not the original KernelSU
manager and not APatch.

The kernel is pinned to tag `v3.3.0-legacy-susfs-v2`, so it reports version
`33214` and `KERNEL_SU_UAPI_VERSION = 2`, matching that manager exactly.

Because `drivers/kernelsu` is vendored without `.git`, the build pins
`KSU_VERSION_OVERRIDE=33214` / `KSU_VERSION_TAG_OVERRIDE=v3.3.0-legacy-susfs-v2`
(the vendored Kbuild was extended to accept those variables). Verified: the tag
string is embedded in `Image`.

Manager compatibility, verified from the APK bytes and the manager sources:

- The manager cert must be 998 bytes, sha256
  `79e590113c4c4c0c222978e413a5faa801666957b1212a328e46c00c69821bf7`. BOTH the
  v3.3.0-spoofed and v3.4.0 APKs carry exactly that cert, so the signature is
  not the discriminator.
- The discriminator is `kernelUAPIVersion == managerUAPIVersion`: the v3.3.0
  manager is UAPI **2**, the v3.4.0 manager is UAPI **4**.
- Therefore the kernel is pinned to the v3.3.0 line (UAPI 2) to match the
  working manager. The earlier v3.4.0 attempt used UAPI 4 and a version of
  `33225`; v3.4.0 managers are not used here.
- Both manager generations also require `version >= 33188`; `33214` passes.

## CAPABILITIES

Kernel-side (all confirmed in the built `.config`):

- Modules: `CONFIG_MODULES=y`, `CONFIG_MODULE_UNLOAD=y`, `CONFIG_MODULE_SIG`
  **off** (no signature enforcement, so modules load).
- Mounting: `CONFIG_OVERLAY_FS=y`, `CONFIG_FUSE_FS=y`, `CONFIG_TMPFS=y`,
  `CONFIG_TMPFS_XATTR=y`, `CONFIG_TMPFS_POSIX_ACL=y`.
  (`OVERLAY_FS_REDIRECT_DIR`/`INDEX` remain off, as in the stock vendor config.)
- Security: `CONFIG_SECURITY=y`, `CONFIG_SECURITY_SELINUX=y`,
  `CONFIG_SECURITY_SELINUX_DEVELOP=y`.
- Symbols: `CONFIG_KALLSYMS=y`, `CONFIG_KALLSYMS_ALL=y`.
- KernelSU hook prerequisites: `CONFIG_THREAD_INFO_IN_TASK=y`.

SUSFS features compiled in (what `CMD_SUSFS_SHOW_ENABLED_FEATURES` reports):

- `CONFIG_KSU_SUSFS_SUS_PATH`, `SUS_MOUNT`, `SUS_KSTAT`, `SUS_MAP`,
  `TRY_UMOUNT`, `SPOOF_UNAME`, `SPOOF_CMDLINE_OR_BOOTCONFIG`, `OPEN_REDIRECT`,
  `ENABLE_LOG`, `HIDE_KSU_SUSFS_SYMBOLS`.

Mounting ("magic mount" / overlayfs):

- Magic mount is a **userspace** feature (manager/`ksud`/module), not a kernel
  option; it only needs overlayfs, which is enabled. So magisk-style
  (MetaModule) and overlayfs-based module mounting work with the KernelSU-Next
  manager / ksud / a mount module.
- `CONFIG_KSU_SUSFS_SUS_MOUNT` + `TRY_UMOUNT` are enabled so SUSFS can hide
  suspicious mounts and try-umount paths.

Not available on this branch (would need the `next-susfs` GKI line, which
requires kprobes/LSM hooks this non-kprobes 4.14 kernel cannot use):
`CONFIG_KSU_SUSFS_SUS_OVERLAYFS`, `KSU_SUSFS_HAS_MAGIC_MOUNT`, and the
`AUTO_ADD_SUS_*` auto-hide helpers.

## BUILD

Built on GitHub Actions (`ubuntu-22.04`) with ZyCromerZ Clang 16.0.6 (full
LLVM binutils), matching the repo's `LLVM=1` build. Workflow:
`.github/workflows/build-kernel.yml`.

- Status: **success**
- Run: `37119919894` (commit `c1f61cef`), branch `ksun-susfs`
- Result: `Image` 37 MB, packaged as `XT-Line-KSUN_m31_<date>.zip` (~17 MB)
- Effective config confirmed: `CONFIG_KSU=y`, `CONFIG_KSU_MANUAL_HOOK=y`,
  `CONFIG_KSU_SUSFS=y`, `CONFIG_KSU_SUSFS_SUS_MOUNT=y`, plus every
  external-wifi/gadget symbol (the workflow now fails the build if any is
  missing).
- Embedded markers verified in `Image`: `apply_kernelsu`,
  `susfs_sus_kstat_spoof_proc_fd_seq_show`, `linux version 4.14.357-XT-Line-AOSP`

CI run summary: baseline -> KSUN -> SUSFS -> config -> build all compiled with
zero rejected hunks; the only iterations were the toolchain symlink fix and
two integration fixes (vendored `uapi/`, `task_mmu.c` externs).

## PACKAGE

AnyKernel3 (`AnyKernel3/`), packaged by `build_kernel.py` as
`XT-Line-KSUN_m31_<date>.zip` containing `Image`, `dtbo.img`, `dtb`.
CI artifact: `ksun-susfs-m31` (~31.7 MB, includes Image/dtb/dtbo + zip).

**Flash only after keeping a backup of the current boot image.** AnyKernel3
patches the existing boot image; the original is not modified on-disk until
the zip is flashed.

## VALIDATION

**Build-time (done):**
- Defconfig resolves all KSU/SUSFS symbols.
- Kernel compiles cleanly with KSUN + SUSFS v2.3.0 (all objects built).
- `Image` contains `apply_kernelsu` and `susfs_sus_kstat_spoof_proc_fd_seq_show`.

**On-device (pending flash):** KernelSU/KSUN manager reports version and root
works; `ksud`/module (sidex15/susfs4ksu-module >= v1.5.2) initializes SUSFS;
SELinux enforcing; suspend/resume; Wi-Fi/BT/camera/audio/network; `dmesg`
clean of susfs/ksu faults.

## VERSION

`XT-Xenos9611 v0.1.0 — Aegis`

## LIMITATIONS

- `CONFIG_KSU_SUSFS_SUS_MEMFD` disabled (no 4.14 v2.3.0 kernel-side impl).
- SUSFS v2.3.0 for 4.14 is a downstream backport (sidex15), not upstream.

## REPRODUCIBILITY

```
git clone -b lineage-24.0 \
  https://github.com/Parbindar7/android_kernel_samsung_universal9611
cd android_kernel_samsung_universal9611
git checkout ksun-susfs      # this integration branch
# toolchain (CI uses this exact URL):
#   .../ZyCromerZ/Clang/releases/download/16.0.6-20260807-release/Clang-16.0.6-20260807.tar.gz
python3 build_kernel.py --target m31
```

Pinned revisions: baseline `1500b70ea`, KSUN `d999a2af` (legacy-susfs-v2),
SUSFS v2.3.0 @ `929a8eac` (OpenELA-4.14.y-susfs).
