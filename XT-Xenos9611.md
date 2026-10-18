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
| Project | KernelSU-Next (`https://github.com/KernelSU-Next/KernelSU-Next`) |
| Tag | `v3.4.2-legacy-susfs-v2` (official v3.4.2 + SUSFS v2 glue, manual hook) |
| Commit | `465490a266` (official; SUSFS glue from sidex15 `d999a2aff115`) |
| Reported version | `33355` (matches the v3.4.2 manager) |
| UAPI version | `5` (matches the KernelSU-Next v3.4.2 manager) |
| Location | `drivers/kernelsu/` (vendored, not a submodule) |
| Hook mode | `CONFIG_KSU_MANUAL_HOOK=y` |

The rebase is additive-only: `git diff 465490a266 3323ee36` is exactly
11 files / 500 insertions / 0 deletions (the SUSFS glue), plus two local
build fixes (see CHANGELOG §8). History: the previous pin was the
v3.3.0-legacy-susfs-v2 line (UAPI 2, version 33214), whose manager was the
only working one at the time; the v3.4.2 manager (UAPI 5) now pairs with
this build. The earlier v3.4.0 attempt is obsolete.

## SUSFS

| Field | Value |
|---|---|
| Version | `v2.3.0` (NON-GKI) |
| Source | `sidex15/android_kernel_lge_sm8150`, branch `OpenELA-4.14.y-susfs` |
|       | HEAD `929a8eac7` (2026-09-13) — files verified byte-identical 2026-10-18 |
| Files | `fs/susfs.c`, `include/linux/susfs.h`, `include/linux/susfs_def.h` |
| Module target | `sidex15/susfs4ksu-module` (v1.5.2-R28, needs SUSFS >= 1.5.2) |

## COMPATIBILITY

Why this exact pair and not "newest of everything":

- Upstream `simonpunk/susfs4ksu` tops out at **v1.5.5** for 4.14 (tags
  `1.4.2-kernel-4.14`, branch `kernel-4.14`); there is **no** upstream v2.x
  4.14 patch. The v2.x 4.14 implementation exists only in sidex15's SM8150
  tree, which is a real, working 4.14 + KSUN + SUSFS v2.3.0 integration.
- The non-GKI v2.3.0 tracks sidex15's branch HEAD (2026-09-13), i.e. the
  current upstream non-GKI version — it includes the OPEN_REDIRECT
  UAF/deadlock fixes, the SUS_MOUNT minor-dev gap fix, the SUS_MOUNT /
  SUS_KSTAT / OPEN_REDIRECT spoofing refactor and the NULL-deref fix.
  Upstream's GKI v2.3.0 (`gki-android*` dev branches) uses a different
  mechanism (thread_info `TIF_*` flags vs inode `i_state` bits here) and
  is not a drop-in.
- `legacy-susfs-v2` requires the **v2.0.0+** SUSFS supercall API
  (`CMD_SUSFS_ADD_SUS_PATH_LOOP`, `susfs_extra_works`, `susfs_run_sus_path_loop`,
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
`security/selinux/{hooks,selinuxfs,objsec.h,xfrm}.c`. It also probes the
tree for backports (`KSU_HAS_*` / `KSU_OPTIONAL_*` defines, e.g.
`KSU_HAS_POLL_T` for this vendor tree's backported `__poll_t`).

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

## NOMOUNT (REMOVED)

The in-tree NoMount VFS path-redirection subsystem (maxsteeel/nomount v20,
`fs/nomount/`) was **removed** in the v3.4.2 rebase: `fs/nomount/` deleted
(88 KB), its `fs/Makefile` / `fs/Kconfig` lines dropped, and
`CONFIG_NOMOUNT=y` removed from all seven defconfigs. CI no longer asserts
the symbol or the `nomount` key-type string. KernelSU-Next's own mount
handling mounts modules again (see MODULE MOUNTING).

The history is kept because it produced this device's worst bootloop, and
the lesson applies to any mounter: a module shipping **character-device
nodes** (`crw-rw---- 0,0`) was converted to **whiteouts**, so
`lineage_hide` hid `/system/framework/org.lineageos.platform-res.apk` and
its odex/vdex **from the system itself** - the framework could not load -
bootloop. Proven by clearing the rules and watching the three files
reappear (301322 / 822912 / 7064 bytes). Full diagnosis: CHANGELOG §6.

On-device follow-up after flashing the new kernel: the NoMount metamodule
(`/data/adb/modules/nomount` plus the `/data/adb/metamodule` symlink) is
now inert - remove it so KSUN handles mounting for every module, then
confirm the firmware overlay is visible (`ls /vendor/firmware/rtlwifi/`).

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

**Kernel-side stealth additions (this build).** `CONFIG_KSU_SUSFS_SUS_MAP`
(already on) hides mmapped real files from
`/proc/<pid>/{maps,smaps,smaps_rollup,map_files,mem,pagemap}`.
`CONFIG_KSU_SUSFS_SUS_MEMFD` is **not implementable** in SUSFS v2.3.0 —
only the KSU-side Kconfig/supercall reference the symbol, the kernel side
has none, and enabling it breaks the build (see CHANGELOG.md §3). Memory
hiding is delivered by `SUS_MAP` instead. `CONFIG_KSU_SUSFS_ENABLE_LOG` is
**off**: SUSFS logging writes its own activity into the kernel log, which
is itself a detection surface. CI asserts all nine *implemented* SUSFS
features are `=y`, that logging stays disabled, and that SUS_MEMFD stays
**off**.

**Userspace side (on-device, not the kernel).** SUSFS is driven by the **`brene`**
module, which reads **`/data/adb/brene/`** — *not* `/data/adb/susfs4ksu/`. That second
directory is a leftover from the old `susfs4ksu` module, which `brene/customize.sh`
explicitly disables (`touch .../susfs4ksu/disable`); editing it has **no effect**.

`/data/adb/brene/config.sh` holds the feature flags, and four lists are consumed by
`boot-completed.sh`:

| File | Registered via |
|---|---|
| `custom_sus_path.txt` | `add_sus_path` (weaker — does not re-flag at spawn) |
| `custom_sus_path_loop.txt` | `add_sus_path_loop` (**prefer this**) |
| `custom_sus_map.txt` | `add_sus_map` |
| `custom_kernel_umount.txt` | `ksud kernel umount add` |

The pattern brene itself uses for every path it hides is **both** `add_sus_map` *and*
`add_sus_path_loop`; using only the plain `add_sus_path` is why a path can appear to be
configured yet stay visible. In use here: `hide_cusrom`, `hide_vendor_sepolicy`,
`hide_compat_matrix`, `hide_loops`, `avc_log_spoofing`, `force_hide_lsposed`,
`spoof_cmdline`, `susfs_log=0`, the three LineageOS file traces in both
`custom_sus_path_loop.txt` and `custom_sus_map.txt`, and the Zygisk/injection libraries
in `custom_sus_map.txt`.

Two things to know before trusting a result:

- `config_hide_framework_res_apk` matches `*framework-res.apk`, so it does **not**
  cover this ROM's `org.lineageos.platform-res.apk`. It also calls only `sus_map`,
  which hides a path from `/proc/<pid>/maps` but not from existence.
- Hiding is gated in `fs/susfs.c` on `susfs_is_current_proc_umounted_app()` plus the
  inode owner differing from the caller's uid. A `su <uid> -c ...` process runs in the
  `u:r:ksu:s0` context and is **not** a valid probe — a "still visible" result from one
  proves nothing. Validate with a real app.

Verified on device: `ksud susfs features` reports SUSFS v2.3.0 (NON-GKI) with 9/9
features, `brene`'s own status reads
`[Status: Active ✅ | SuSFS: v2.3.0 (NON-GKI) | SuSFS Features: 9/9 enabled]`, the
`susfs` CLI accepts every registration with `rc=0`, and a scan of running app processes
found **0** leaked `/data/adb`, zygisk or magisk references in `/proc/<pid>/maps`.

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

Use the **KernelSU-Next (KSUN) manager v3.4.2** —
`KernelSU_Next_v3.4.2-spoofed_33355-release.apk`. Not the original KernelSU
manager and not APatch.

The kernel is pinned to tag `v3.4.2-legacy-susfs-v2`, so it reports version
`33355` and `KERNEL_SU_UAPI_VERSION = 5`, matching that manager exactly.

Because `drivers/kernelsu` is vendored without `.git`, the build pins
`KSU_VERSION_OVERRIDE=33355` / `KSU_VERSION_TAG_OVERRIDE=v3.4.2-legacy-susfs-v2`
(the vendored Kbuild accepts those variables). Verified: the tag string is
embedded in `Image` (CI hard-fails if the assertion finds nothing).

Manager compatibility, verified from the APK bytes and the manager sources:

- The manager cert must be 998 bytes, sha256
  `79e590113c4c4c0c222978e413a5faa801666957b1212a328e46c00c69821bf7`
  (identical across the spoofed v3.3.0 and v3.4.x APKs).
- The discriminator is `kernelUAPIVersion == managerUAPIVersion`: the v3.4.2
  manager is UAPI **5**; the previous v3.3.0 pin was UAPI 2 (see CHANGELOG
  §2/§8). The obsolete v3.4.0 attempt was UAPI 4 / version 33225.
- Both manager generations also require `version >= 33188`; `33355` passes.

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
  `HIDE_KSU_SUSFS_SYMBOLS` — nine features, matching brene's 9/9.
- `CONFIG_KSU_SUSFS_ENABLE_LOG` is deliberately **off** (kernel-log
  detection surface). `CONFIG_KSU_SUSFS_SUS_MEMFD` is **not implementable**
  in SUSFS v2.3.0 — the kernel side has no symbol; enabling it breaks the
  build.

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

- Status: **success** (upstream catch-up merge)
- Run: `39133066014` (merge `518fd077b`, catch-up with upstream
  `lineage-24.0`); previous: `39126533696` (`64e6f0900`, v3.4.2 rebase);
  the first v3.4.2 attempt (`39125207801`) failed on the `__poll_t` clash
  fixed by `64e6f0900` (CHANGELOG §8).
- Result: `Image` 37 MB, packaged as `XT-Line-KSUN_m31_<date>.zip` (~17 MB)
- Effective config confirmed: `CONFIG_KSU=y`, `CONFIG_KSU_MANUAL_HOOK=y`,
  `CONFIG_KSU_SUSFS=y`, all nine implemented SUSFS features `=y`, plus every
  external-wifi/gadget symbol (the workflow fails the build if any is missing).
- Upstream catch-up (CHANGELOG §10): NFC now enabled —
  `CONFIG_SAMSUNG_NFC=y`, `CONFIG_SEC_NFC=y`, `CONFIG_SEC_NFC_LOGGER=y`
  in `exynos9611-m21/m31_defconfig`.
- Embedded markers verified in `Image`: `apply_kernelsu`,
  `susfs_sus_kstat_spoof_proc_fd_seq_show`, `linux version 4.14.357-XT-Line-AOSP`,
  `v3.4.2-legacy-susfs-v2`.

CI run summary: the upstream `lineage-24.0` catch-up merged with no
conflicts (upstream had rebased — content parity confirmed by probes, the
only real delta was the NFC enable) and built green in one shot; the
v3.4.2 rebase compiled after one integration fix (`__poll_t` tree-probe);
the earlier v3.3.0 line built with zero rejected hunks.

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
- `Image` contains `apply_kernelsu`, `susfs_sus_kstat_spoof_proc_fd_seq_show`
  and the `v3.4.2-legacy-susfs-v2` tag string.

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

Pinned revisions: baseline `1500b70ea`; KernelSU-Next official `465490a266`
plus SUSFS glue from sidex15 `d999a2aff115` (merged in the port repo as
`3323ee36`); SUSFS v2.3.0 @ `929a8eac7` (OpenELA-4.14.y-susfs HEAD).
Upstream `lineage-24.0` catch-up merged as `518fd077b` (2026-10-18; brought
in the NFC enable; upstream rebases its branch, so commit IDs there are not
stable across syncs — compare **content**, not SHAs).
