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
| KernelSU-Next | `v3.3.0-legacy-susfs-v2`, reports version 33214 | `drivers/kernelsu/` |
| SUSFS | `v2.3.0`, NON-GKI | `fs/susfs.c`, `include/linux/susfs.h` |
| NoMount | built **in-tree** (not a `.ko`) | `fs/nomount/` |
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
| `CONFIG_NOMOUNT=y` | NoMount must be **in-tree** on 4.14. Internal VFS symbols are not exported to modules below 5.10, so a `.ko` is impossible. |
| `CONFIG_KEYS=y` | NoMount registers a key type named `nomount`; that key type **is** the "Internal API" the installer probes. |
| literal `nomount` string inside the built `Image` | Proves the driver really linked in, not just that Kconfig was set. |
| `CONFIG_KSU_SUSFS_ENABLE_LOG` **is not set** | SUSFS logging writes hidden-path activity into the kernel log — a detection surface. |
| `CONFIG_KSU_SUSFS_SUS_MEMFD` **is not set** | **Trap:** `Kconfig` offers it and `supercall/supercall.c` calls `susfs_add_sus_memfd()`, but SUSFS v2.3.0 does **not implement** it (`fs/susfs.c` / `susfs.h` have no such symbol or `CMD_SUSFS_ADD_SUS_MEMFD`). Enabling it **breaks the build**. |
| exactly one occurrence of each option in the defconfig | kconfig honours the **last** occurrence. A duplicate silently negated SUS_MEMFD once already. |

---

## 3. Gotchas that have already bitten

1. **Duplicate defconfig keys silently win/lose by position.** `# CONFIG_X is not set`
   *below* `CONFIG_X=y` means X is **off**. Always grep for duplicates after editing
   a defconfig.

2. **NoMount bootloops when a module ships character-device whiteout markers.**
   `metamount.sh` runs `find -L "$partition" \( -type c -o -name .replace \)` and turns
   those into **whiteouts**. `lineage_hide` shipped `crw-rw---- 0,0` nodes for
   `/system/framework/org.lineageos.platform-res.apk` and its `.odex`/`.vdex`, so
   NoMount hid the LineageOS framework resource APK **from the system itself** →
   system_server could not load → bootloop. See `CHANGELOG.md`.

3. **NoMount master has an unbounded `xargs` arg list.** `metamount.sh` registers
   whiteouts and replacements in **separate** `xargs` calls, so an `ARG_MAX` failure
   can leave a path whiteouted with **no replacement**. The `dev` branch adds
   `xargs -0 -r -n 200`; the on-device script uses the `dev` version.

4. **NoMount's bootloop guard must be `sync`ed.** It works by leaving a `.booting`
   semaphore on `/data`; without `sync` that write is lost on an unclean shutdown and
   the guard fails exactly when it is needed (device loops instead of self-disabling).

5. **`/data` is f2fs with `fsync_mode=nobarrier`.** An unclean shutdown can zero-fill
   recently-written files *while keeping their size*. This has already destroyed
   `nomount/module.prop` (twice), `lineage_hide`'s payload, `tricky_store` caches and
   several webroot assets. When something behaves impossibly, check for a file that is
   the right size but entirely NUL bytes:
   ```sh
   LC_ALL=C tr -d '\000' < FILE | wc -c   # 0 => the file is all NULs
   ```

6. **Run `metamount.sh` with an absolute path.** Invoking it as `./metamount.sh` makes
   `$0`-relative logic set `MODDIR=.` and the rule loader then resolves relatively
   after the script `cd`s, producing `xargs: exec ./bin/nm: No such file or directory`
   and **zero rules**. KSUN always invokes it absolutely; manual testing must too.

7. **SUSFS hiding only applies to umounted app processes.** `fs/susfs.c` gates
   `susfs_is_inode_sus_path()` on `susfs_is_current_proc_umounted_app()` and on the
   inode's owner differing from the caller's uid. Consequence: you **cannot** validate
   hiding with `su <uid> -c ...` from a root shell and conclude it is broken — that
   process is in the `u:r:ksu:s0` context. Verify with a real app.

---

## 4. What SUSFS can and cannot hide (read before chasing a "SUSFS is broken" report)

**SUSFS is kernel-only — it does not use Zygisk, and does not need it.** It works in
the VFS: `sus_path` hides paths, `sus_map` hides mmapped files, `sus_mount`/`try_umount`
hide mounts, `sus_kstat` spoofs stat, `open_redirect` redirects opens. All of it is
gated on `susfs_is_current_proc_umounted_app()` (see §3.7).

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
| `/data/adb/modules/nomount/` | The NoMount metamodule: `module.prop` (must contain `metamodule=true`), `metamount.sh`, `service.sh`, `bin/nm`. |
| `/data/adb/metamodule` | Symlink → `/data/adb/modules/nomount`. Its existence is what makes KSUN call `metamount.sh`. |
| `/data/adb/modules/r8188eu_firmware/` | Systemless overlay providing `rtlwifi/rtl8188eufw.bin` (the ROM ships **no** Realtek firmware). |
| `/data/adb/r8188eu/r8188eu.ko` | The Wi-Fi module. **Its CRC is tied to the kernel build** — refresh it after every rebuild. |

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
  uname -r                                     # kernel actually booted
  /data/adb/modules/nomount/bin/nm version      # expect 20 (kernel API alive)
  /data/adb/modules/nomount/bin/nm rule list    # expect ONLY the rtl8188eufw rule
  cat /data/adb/nomount/nomount.log             # expect "[OK] Boot phase completed safely"
  ksud susfs support; ksud susfs features       # expect Supported + 9 features
'
```

A healthy NoMount state has exactly **one** redirection
(`/vendor/firmware/rtlwifi/rtl8188eufw.bin`). Anything touching `/system/framework`,
`/system/etc` or `/system/bin` is a bootloop risk and must be justified.

---

## 7. Do not

- Do not enable `SUS_MEMFD` (build breaks; see §2).
- Do not add `CONFIG_X=y` above an existing `# CONFIG_X is not set` (see §3.1).
- Do not let NoMount whiteout framework paths (see §3.2).
- Do not run a second mounter (Hybrid Mount / overlayfs mounter) alongside NoMount —
  only one metamodule may be active, and NoMount *replaces* KSUN's magic mount.
- Do not "verify" hiding with `su <uid>`; use a real app (§3.7).
- Do not commit to `xtrcomsu-*` remote branches that may not exist — push to `fork`.
