# AGENTS.md — read this first

Orientation for any AI agent (or human) working on this kernel. It exists so that
**every change is understandable without re-deriving it from scratch**, and so the
hard-won invariants below are not accidentally broken.

Deep technical reference: [`XT-Xenos9611.md`](./XT-Xenos9611.md)
Change-by-change rationale: [`CHANGELOG.md`](./CHANGELOG.md)
User-facing overview: [`README.md`](./README.md)

---

## 1. What this is

A custom **Linux 4.14.357** kernel for the **Samsung Galaxy M31 (exynos9611)**,
carrying:

| Component | Version / form | Where |
|---|---|---|
| KernelSU-Next | `v3.4.2-legacy-susfs-v2`, reports version 33355 | `drivers/kernelsu/` |
| SUSFS | `v2.3.0`, NON-GKI (sidex15 HEAD) | `fs/susfs.c`, `include/linux/susfs.h` |
| NoMount | **removed** in the v3.4.2 rebase | (was `fs/nomount/`) |
| WireGuard | in-tree | `drivers/net/wireguard/` |
| r8188eu | RTL8188EU/EUS USB Wi-Fi, built as `r8188eu.ko` | `drivers/staging/r8188eu/` |

Branch: **`ksun-susfs`**. Target defconfig: **`arch/arm64/configs/exynos9611-m31_defconfig`**
(the other six `exynos9611-*` defconfigs have **no** KSU/SUSFS block — only m31 is built).

---

## 2. Hard invariants — CI fails if these drift

The workflow `.github/workflows/build-kernel.yml` asserts all of the following on
every build. **Do not "clean these up" without understanding why they are there.**

| Invariant | Why |
|---|---|
| `CONFIG_DEFAULT_BIC=y` and `CONFIG_DEFAULT_TCP_CONG="bic"` | BBR/cubic was an accidental behavioural change; `bic` is the stock exynos9611 default and was explicitly restored. |
| `v3.4.2-legacy-susfs-v2` string inside the built `Image` | The kernel must report version `33355` / UAPI 5 to pair with the v3.4.2 manager; CI hard-fails if the tag string is missing. |
| `CONFIG_KSU_SUSFS_ENABLE_LOG` **is not set** | SUSFS logging writes hidden-path activity into the kernel log — a detection surface. |
| `CONFIG_KSU_SUSFS_SUS_MEMFD` **is not set** | **Trap:** `Kconfig` offers it and `supercall/supercall.c` calls `susfs_add_sus_memfd()`, but SUSFS v2.3.0 does **not implement** it (`fs/susfs.c` / `susfs.h` have no such symbol or `CMD_SUSFS_ADD_SUS_MEMFD`). Enabling it **breaks the build**. |
| exactly one occurrence of each option in the defconfig | kconfig honours the **last** occurrence. A duplicate silently negated SUS_MEMFD once already. |
| `CONFIG_IKCONFIG=y` + `CONFIG_IKCONFIG_PROC=y`, with **no** `CONFIG_KSU`/`CONFIG_SUSFS` lines in the embedded blob | Infinity-X 3.12's framework aborts `system_server` when `/proc/config.gz` is unreadable (b/151092221). The blob is filtered in `kernel/Makefile`; CI checks both presence and leak-freeness. |

---

## 3. Gotchas that have already bitten

1. **Duplicate defconfig keys silently win/lose by position.** `# CONFIG_X is not set`
   *below* `CONFIG_X=y` means X is **off**. Always grep for duplicates after editing
   a defconfig.

2. **A mounter that whiteouts framework paths bootloops the device.** This already
   happened once with the (now removed) NoMount subsystem: `metamount.sh` converted
   character-device nodes (`crw-rw---- 0,0`) into **whiteouts**, and `lineage_hide`
   shipped such nodes for `/system/framework/org.lineageos.platform-res.apk` and its
   `.odex`/`.vdex` — hiding the framework resource APK **from the system itself** →
   system_server could not load → bootloop. NoMount is gone; the lesson stands for
   any mounter. See `CHANGELOG.md` §6.

3. **`/data` is f2fs with `fsync_mode=nobarrier`.** An unclean shutdown can zero-fill
   recently-written files *while keeping their size*. This has already destroyed
   module files (including NoMount's `module.prop`), `lineage_hide`'s payload,
   `tricky_store` caches and several webroot assets. When something behaves
   impossibly, check for a file that is the right size but entirely NUL bytes:
   ```sh
   LC_ALL=C tr -d '\000' < FILE | wc -c   # 0 => the file is all NULs
   ```

4. **SUSFS hiding only applies to umounted app processes.** `fs/susfs.c` gates
   `susfs_is_inode_sus_path()` on `susfs_is_current_proc_umounted_app()` and on the
   inode's owner differing from the caller's uid. Consequence: you **cannot** validate
   hiding with `su <uid> -c ...` from a root shell and conclude it is broken — that
   process is in the `u:r:ksu:s0` context. Verify with a real app.

5. **This vendor 4.14 tree backports modern kernel types.** `__poll_t` exists in
   `include/uapi/linux/types.h` even though mainline only gained it in 4.16, so
   KSU-side version-guarded fallback typedefs can collide
   (`-Werror,-Wtypedef-redefinition`). Compat must *probe the tree* through the
   `KSU_HAS_*` Kbuild defines (see §2 / `CHANGELOG.md` §8), not version-check alone.

---

## 4. What SUSFS can and cannot hide (read before chasing a "SUSFS is broken" report)

**SUSFS is kernel-only — it does not use Zygisk, and does not need it.** It works in
the VFS: `sus_path` hides paths, `sus_map` hides mmapped files, `sus_mount`/`try_umount`
hide mounts, `sus_kstat` spoofs stat, `open_redirect` redirects opens. All of it is
gated on `susfs_is_current_proc_umounted_app()` (see §3.4).

That design draws a hard line:

| Trace type | Can SUSFS hide it? | How |
|---|---|---|
| Files on `/system`, `/system_ext`, `/vendor`, `/product` | **Yes** | `sus_path` / `sus_path_loop` |
| Files in `/proc/<pid>/maps` | **Yes** | `sus_map` |
| Suspicious mounts | **Yes** | `sus_mount`, `try_umount` |
| Paths shown by `stat` | **Yes** | `sus_kstat` |
| **Installed packages via `PackageManager`** | **No** | Kernel cannot intercept `pm list packages` |
| **System properties** | **No** | Userspace — needs resetprop / PIF |
| App-private in-memory state | **No** | Needs Zygisk/Xposed hooks |

**Consequence:** a detector that enumerates *installed packages* (Duck Detector does —
this ROM ships **13** matching `lineage`, including the framework package
`lineageos.platform`) cannot be defeated by SUSFS, no matter how the path lists are
configured. Hiding packages requires a **Zygisk/Xposed** module (`targetedhide`, HMA),
which is a userspace hook that SUSFS deliberately is not.

Diagnostic signature seen on this device: `targetedhide`, `zygisk_vector`,
`onyxzygisk` and `hma_oss_zygisk` all *enabled*, yet the detector's own process shows
**0** `/data/adb` or zygisk paths in `/proc/<pid>/maps` — i.e. it is **not injected**,
so every Zygisk-based hiding module is inert for it. Enabling Zygisk fixes package
hiding but reintroduces the in-memory injection artifacts that Zygisk-off was avoiding.
That is a genuine trade-off, not a bug — present it as one.

Before blaming SUSFS, check in this order:
1. Is the config in `/data/adb/brene/` (not the inert `susfs4ksu`)? (§5)
2. Is the path registered with **both** `add_sus_map` and `add_sus_path_loop`?
3. Is the target an **app** process (uid ≥ 10000) and not root-granted?
4. Is the trace a **file** at all — or is it a package / property / memory artifact?

---

## 5. Device-side state (NOT in this repo — back it up before wiping)

| Path | Meaning |
|---|---|
| `/data/adb/brene/` | **The live SUSFS userspace config.** `config.sh` + `custom_sus_path.txt`, `custom_sus_path_loop.txt`, `custom_sus_map.txt`, `custom_kernel_umount.txt`. |
| `/data/adb/susfs4ksu/` | **INERT.** Leftover from the old `susfs4ksu` module, which `brene/customize.sh` disables. Editing it does nothing. A `README.INERT` marks this on-device. |
| `/data/adb/modules/nomount/` | The NoMount metamodule — **inert** since the kernel subsystem was removed. Remove it (and the symlink below) after flashing the new kernel. |
| `/data/adb/metamodule` | Symlink → `/data/adb/modules/nomount`. Delete it so KSUN mounts modules natively again. |
| `/data/adb/modules/r8188eu_firmware/` | Systemless overlay providing `rtlwifi/rtl8188eufw.bin` (the ROM ships **no** Realtek firmware). |
| `/data/adb/r8188eu/r8188eu.ko` | The Wi-Fi module. **Its CRC is tied to the kernel build** — refresh it after every rebuild. |
| `/data/adb/xtbootguard/` | XT Boot Guard state: `boot.log`, `fails` counter, `last`, `restore_done`. The module is auto-installed on every kernel flash (3 fails → modules off, 6 → recovery, 9 → boot-image restore). |

### The working SUSFS hiding pattern
brene hides a path by calling **both**:
```sh
susfs add_sus_map       "$path"   # hide from /proc/<pid>/{maps,...}
susfs add_sus_path_loop "$path"   # hide from existence, re-flagged at zygote spawn
```
`add_sus_path` (the plain variant) is **weaker** — it does not re-flag at spawn, which is
why paths placed only in `custom_sus_path.txt` appear not to work.
Note `config_hide_framework_res_apk` matches `*framework-res.apk` and therefore does
**not** cover `org.lineageos.platform-res.apk`.

---

## 6. Build & verify

```sh
# CI entry point (this is the supported path)
gh workflow run build-kernel.yml --repo XtrComSu/android_kernel_samsung_universal9611
# then watch the "Post-build verification" step — it is the real gate
```

`build_kernel.py` runs `make O=out exynos9611-${TARGET}_defconfig` then builds with
the toolchain pinned in `XT-Xenos9611.md` (REPRODUCIBILITY section).

Device-side verification after flashing:

```sh
su -c '
  uname -r                                         # kernel actually booted
  ls -l /vendor/firmware/rtlwifi/rtl8188eufw.bin   # KSUN-mounted firmware overlay
  ksud susfs support; ksud susfs features          # expect Supported + 9 features
'
```

Module mounting is done by KernelSU-Next itself since NoMount was removed; the
firmware file above is the one overlay that must be present for the USB Wi-Fi
adapter.

---

## 7. Do not

- Do not enable `SUS_MEMFD` (build breaks; see §2).
- Do not add `CONFIG_X=y` above an existing `# CONFIG_X is not set` (see §3.1).
- Do not hide framework paths from the system (see §3.2).
- Do not leave the NoMount metamodule enabled after flashing this kernel — remove it
  and the `/data/adb/metamodule` symlink so KSUN mounts modules natively.
- Do not "verify" hiding with `su <uid>`; use a real app (§3.4).
- Do not commit to `xtrcomsu-*` remote branches that may not exist — push to `fork`.
- Do not disable `IKCONFIG`/`IKCONFIG_PROC` "for stealth" — the ROM's
  `system_server` aborts without `/proc/config.gz` (b/151092221). The blob is
  filtered in `kernel/Makefile`; extend the filter if new secret options appear.
- Do not trust app-side `uname`: SUSFS `spoof_uname` can fake it. Check the
  real kernel with `su -c 'cat /proc/version'`.
