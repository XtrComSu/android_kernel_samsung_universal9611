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
| Branch | `legacy-susfs-v2` (newest legacy line with SUSFS glue) |
| Commit | `d999a2aff11575c6e2f520129ecffb7c6058fb02` |
| Location | `drivers/kernelsu/` (vendored, not a submodule) |
| Hook mode | `CONFIG_KSU_MANUAL_HOOK=y` |

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

## BUILD

Built on GitHub Actions (`ubuntu-22.04`) with ZyCromerZ Clang 16.0.6 (full
LLVM binutils), matching the repo's `LLVM=1` build. Workflow:
`.github/workflows/build-kernel.yml`.

- Status: _(pending first run)_
- Run: _(pending)_

## PACKAGE

AnyKernel3 (`AnyKernel3/`), packaged by `build_kernel.py` as
`Everline-KSUN_m31_<date>.zip` containing `Image`, `dtbo.img`, `dtb`.

## VALIDATION

_(pending build + flash)_

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
