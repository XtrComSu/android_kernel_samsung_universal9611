# XT-Xenos9611

Samsung Galaxy M31 (Exynos 9611) kernel with KernelSU-Next + SUSFS.

Version: `XT-Xenos9611 v0.1.0 — Aegis` (codename provisional)

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

Deferred until after the first successful build + on-device validation.
Guardrails: no thermal/voltage/idle sabotage, no forced frequencies, no
peak-only gains that hurt sustained throughput.

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
- Run: `37062825818` (commit `a30cf236`), branch `ksun-susfs`
- Result: `Image` 37 MB, packaged as `Everline-KSUN_m31_2026-10-02.zip` (16 MB)
- Effective config confirmed: `CONFIG_KSU=y`, `CONFIG_KSU_MANUAL_HOOK=y`,
  `CONFIG_KSU_SUSFS=y`, `CONFIG_KSU_SUSFS_SUS_MOUNT=y`
- Embedded markers verified in `Image`: `apply_kernelsu`,
  `susfs_sus_kstat_spoof_proc_fd_seq_show`

CI run summary: baseline -> KSUN -> SUSFS -> config -> build all compiled with
zero rejected hunks; the only iterations were the toolchain symlink fix and
two integration fixes (vendored `uapi/`, `task_mmu.c` externs).

## PACKAGE

AnyKernel3 (`AnyKernel3/`), packaged by `build_kernel.py` as
`Everline-KSUN_m31_<date>.zip` containing `Image`, `dtbo.img`, `dtb`.
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
