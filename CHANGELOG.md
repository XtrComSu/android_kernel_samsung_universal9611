# CHANGELOG & design rationale

Every commit on this branch, **why** it exists, and how to tell whether it is still
correct. Ordered oldest → newest. Read this before reverting anything: several
entries look like arbitrary tuning but are load-bearing.

Legend: `[cfg]` configuration · `[src]` kernel source · `[ci]` build · `[docs]` ·
`[fix]` bug fix · `[revert]` undoing an earlier change.

---

## 1. Baseline

### `454d6dd9d` — baseline: lineage-24.0 universal9611
The vendor/LineageOS base for exynos9611. Everything below is layered on this.
**Invariant:** keep this as the first parent; do not rebase the fork onto a different
base without re-validating every assertion in CI.

### `1500b70ea` — ARM64: configs: enable CONFIG_SCSC_WLAN_SILENT_RECOVERY
Vendor Wi-Fi (Samsung SLSI) silent-recovery. Present in the base config; left on.

---

## 2. KernelSU-Next

### `10055c025` `[src]` — integrate KernelSU-Next (legacy-susfs-v2) with manual hook
Brings KSUN into `drivers/kernelsu/`. **Manual hook** is used deliberately: it is the
hook method that works on 4.14 here (kprobes-based hooking is unreliable on this
vendor kernel).

### `710c0d8c3` `[fix]` — downgrade KSUN to v3.3.0-legacy-susfs-v2
The newer KSUN did not match the working manager build. This pin is the pairing that
was validated end-to-end. **Do not "upgrade" KSUN without re-checking the manager**.

### `486fbfd3e` / `52322046e` `[fix]` — version reporting
KSUN was reporting a borrowed version to the manager. It now reports the real
`33225`, later overridden per-build via `KSU_VERSION_OVERRIDE=33214` +
`KSU_VERSION_TAG_OVERRIDE=v3.3.0-legacy-susfs-v2` in CI. **Why it matters:** a
mismatched version makes the manager refuse or mis-handle the kernel.

### `ef9e54226` `[fix]` — suppress `-Wmisleading-indentation` in KSUN v3.3 sources
`-Werror` would otherwise fail the build on vendored KSUN code.

### `6f1284f64` `[fix]` — resolve build errors in KSU uapi headers and task_mmu externs
Ported fixes needed to compile the KSUN glue against 4.14's headers.

---

## 3. SUSFS

### `de0975a58` `[src]` — integrate SUSFS v2.3.0 (non-GKI, 4.14)
`fs/susfs.c` + `include/linux/susfs.h`, wired to KSUN's supercall dispatcher. Every
`CMD_SUSFS_*` in `supercall.c` reaches a real implementation. **No version gate exists
between the KSU glue and the kernel side.**

### `e455b0d8d` `[fix]` — remove `/proc/config.gz` leak
`CONFIG_IKCONFIG` + `CONFIG_IKCONFIG_PROC` exposed the entire kernel config to any app,
including `CONFIG_KSU=y` and `CONFIG_KSU_SUSFS=y`. Both disabled. **This is a real
detection vector** — do not re-enable for convenience.

### `ca9d60b2c` → `4789d8c70` → `ed1241b9a` `[revert]` — the SUS_MEMFD episode
Worth reading in full, because it is the exact trap a future agent will fall into:

1. `ca9d60b2c` enabled `CONFIG_KSU_SUSFS_SUS_MEMFD` (it looked like the missing
   memory-hiding feature) and disabled `SUSFS_ENABLE_LOG`.
2. `4789d8c70` fixed a **duplicate defconfig key** — the file already contained
   `# CONFIG_KSU_SUSFS_SUS_MEMFD is not set` *below* the new `=y`, and kconfig honours
   the **last** occurrence, so the feature had been silently off.
3. With the duplicate gone the build **failed**:
   ```
   supercall.c:157: error: use of undeclared identifier 'CMD_SUSFS_ADD_SUS_MEMFD'
   supercall.c:158: error: implicit declaration of 'susfs_add_sus_memd'
   ```
   Root cause: `Kconfig` and `supercall.c` are leftovers from a **newer SUSFS line**,
   but this tree ships SUSFS **v2.3.0**, whose `fs/susfs.c` / `susfs.h` define neither
   the symbol nor the command. **`SUS_MEMFD` is simply not implementable here.**
4. `ed1241b9a` reverted it and made CI assert the option stays **off**.

**Net result:** `SUSFS_ENABLE_LOG` off (stealth) is kept; `SUS_MEMFD` stays off.
Memory hiding is delivered by `SUS_MAP` (`CONFIG_KSU_SUSFS_SUS_MAP=y`, implemented)
plus the on-device `custom_sus_map.txt` list.

---

## 4. Configuration

### `ca92cde1c` `[cfg]` — enable KernelSU + SUSFS in `exynos9611-m31_defconfig`
Only **m31** carries the KSU/SUSFS block; the other six `exynos9611-*` defconfigs do
not, and only m31 is built.

### `a30cf2364` `[cfg]` — `CONFIG_OVERLAY_FS_REDIRECT_DIR`
Required for overlayfs-based module mounting (KSUN's magic mount) to behave correctly.
Predates the NoMount work and is still correct.

### `3fba5ebb1` `[cfg]` — BFQ, NetHunter extras, stealth hardening, KPROBES
Adds BFQ, USB serial/RNDIS, mass-storage/UAC gadget functions, joystick input, and
`CONFIG_KPROBES`. Stealth: `CONFIG_SECURITY_DMESG_RESTRICT`.

### `3154a1b65` `[cfg]` — keep `mq-deadline` as the I/O default
BFQ is available but **opt-in**; making it the default was a behavioural regression.
**Do not flip the default without a measured reason.**

### `bad439e33` `[cfg]` — vendor GPU interactive boost
Non-radical DVFS tweak only. See `XT-Xenos9611.md` §"DVFS / voltage" for why there is
deliberately **no** undervolt.

### `ec1e49b81` `[cfg]` — "conservative gaming pass" (superseded)
This is the commit that introduced the TCP regression (below). Kept in history for
context; its network part is undone.

### `560b845e7` `[revert]` — restore `bic` as the default TCP congestion control
`ec1e49b81` had flipped **both** the choice symbol and the derived string:
```
-CONFIG_DEFAULT_BIC=y                  +# CONFIG_DEFAULT_BIC is not set
-# CONFIG_DEFAULT_CUBIC is not set     +CONFIG_DEFAULT_CUBIC=y
-CONFIG_DEFAULT_TCP_CONG="bic"         +CONFIG_DEFAULT_TCP_CONG="cubic"   (+ BBR on)
```
All three restored, BBR off. **Flipping only the symbol and not the string is the trap**
— kconfig keeps the stale string. CI now asserts `BIC=y`, `CUBIC` not set, and
`DEFAULT_TCP_CONG="bic"`.

---

## 5. Networking / NetHunter / Wi-Fi

### `30fb38830` — rename to **XT-Line**; external Wi-Fi / NetHunter capabilities
Renamed from `-Everline-AOSP` (see `CONFIG_LOCALVERSION="XT-Line-AOSP"`). Adds
mac80211/cfg80211 and a wide set of USB Wi-Fi drivers.

### `f7f632789` `[fix]` — drop `CONFIG_BT`
The vendor-neutered HCI socket ops do not compile. Bluetooth is out of scope here.

### `c1f61cef0` `[fix]` — add `RT2X00`/`ATH10K` parents
Without the parent symbols, `rt2800usb` and `ath10k_usb` silently never build.

### `06ba35807` `[src]` — build **r8188eu** for RTL8188EU/EUS adapters
Staging driver built as a module. **The kmod's CRC is tied to the kernel build** —
rebuild and re-copy `/data/adb/r8188eu/r8188eu.ko` after every kernel change, or it
will refuse to load.

### `83488dec4`, `50e565a04` `[fix]` — make r8188eu compile under clang `-Werror`
Clang-safe warning suppressions.

### Firmware (device side, not in this repo)
The ROM ships **no** Realtek firmware, so `rtlwifi/rtl8188eufw.bin` is provided as a
**systemless** KernelSU overlay (`/data/adb/modules/r8188eu_firmware`) — no `/vendor`
write, therefore no AVB risk. Symptom of a regression:
`Direct firmware load for rtlwifi/rtl8188eufw.bin failed with error -2`.

---

## 6. NoMount

### `c6709b0ac` `[src]` — add NoMount VFS path-redirection subsystem, built-in
Vendored `maxsteeel/nomount` `v20` into `fs/nomount/`, wired via `fs/Kconfig` +
`fs/Makefile` + `CONFIG_NOMOUNT=y`.

**Why in-tree and not a `.ko`:** NoMount's shipped modules exist only for GKI
5.10/5.15/6.1/6.6/6.12. Below 5.10 the internal VFS symbols it needs are **not
exported to modules**, so on this 4.14 kernel it must be compiled in. Upstream's
`setup.sh` symlinks `fs/nomount` to an out-of-tree clone, which would break CI — hence
vendoring the source instead (`master` and `dev` kernel sources are byte-identical).

**No kernel patches were required:** the source already carries the pre-4.11
`getattr` signature, the empty `IDMAP_*` branch (< 5.12), `NM_ACTOR_RET`/`FLAGS_ARG`
shims, a `DCACHE_DONTCACHE` stub, and `MODULE_IMPORT_NS` guarded by
`>= KERNEL_VERSION(5,0,0)`.

### Behaviour worth knowing
- NoMount **replaces** KSUN's magic mount; only **one** metamodule may be active.
- The "Internal API" the installer probes is a **registered key type named `nomount`**
  (from `fs_initcall`), hence `CONFIG_KEYS=y`. `add_key` returning **`-125`/`ECANCELED`
  is by design** — it is the userspace→kernel command channel, not an error. A genuinely
  missing type returns `-ENODEV`.
- `nm` rules live **only in RAM**; `metamount.sh` re-registers them every boot. The only
  persistent state is `module.prop`'s `metamodule=true`.

### Bootloop root cause (diagnosed on-device, `8c7d03ede`)
`metamount.sh` converts **character-device nodes** (`-type c`, i.e. `crw-rw---- 0,0`)
found in a module into **whiteouts**. `lineage_hide` shipped such nodes for
`/system/framework/org.lineageos.platform-res.apk`,
`.../oat/arm64/org.lineageos.platform.odex` and `.../org.lineageos.platform.vdex`, so
NoMount hid the LineageOS framework resource APK and its odex/vdex **from the system
itself** → framework could not load → bootloop.

**Proof:** clearing the rules made all three files reappear
(301 322 / 822 912 / 7 064 bytes). These were the *only* system-critical paths NoMount
touched; everything else was Wi-Fi firmware.

**Fix:** disable such modules, and hide the same traces the safe way with SUSFS
`sus_path`/`sus_map`, which only affect app processes. With `lineage_hide` disabled,
NoMount's entire rule set is one benign file.

**Also resolved a red herring:** "doesn't load all modules" was not a NoMount bug. Only
`lineage_hide` and `r8188eu_firmware` have a `system/` tree at all; every other module
(`brene`, `rezygisk`, `tricky_store`, `teesim`, `COPG`, `treat_wheel`,
`zygisk_vector`, `disable_logging`, `r8188eu_loader`) loads via Zygisk/scripts and
never needed redirection. The appearance of breakage was collateral from the failed boot.

---

## 7. Build / CI

### `21d1f22eb` `[ci]` — GitHub Actions kernel build workflow
`.github/workflows/build-kernel.yml`: fetches the pinned clang, runs
`build_kernel.py`, packages AnyKernel3, then runs **Post-build verification** — the
assertion gate described in `AGENTS.md` §2. **Treat that step as the source of truth.**

### `38a8f8196` `[docs]` — XT-Xenos9611 integration manifest
Became `XT-Xenos9611.md`, the deep technical reference.

### `[docs]` commits (`ab7df684a`, `ca1258854`, `97a00bb0d`, `45e7c299a`, `e6819b223`,
`7a4622861`, `c5a4618c6`, `3fb12ae06`, `1969e66cb`, `408035c01`, `5351160d6`,
`8c7d03ede`)
Record build run IDs and findings. They carry `[skip ci]` so they do not trigger builds.

---

## 8. Current steady state

- Last green build: run **37161746408** at commit `ed1241b9a`.
- CI asserts: `BIC`/`CUBIC`/`DEFAULT_TCP_CONG="bic"`, `NOMOUNT=y`, `KEYS=y`,
  literal `nomount` in `Image`, all nine implemented SUSFS features `=y`,
  `SUSFS_ENABLE_LOG` off, `SUS_MEMFD` **off**.
- Device verified: NoMount boots clean (`[OK] Boot phase completed safely`), one rule
  only, `nm version` = 20, `ksud susfs` reports v2.3.0 NON-GKI 9/9 features.

### Open / known risks
1. **f2fs `nobarrier`** on `/data` can still zero-fill files on an unclean shutdown
   (`nomount/module.prop` has been lost twice). Reflash the NoMount zip to restore.
2. **SUSFS hiding requires a real app to validate** — `su <uid>` is not a valid probe.
3. Any module that ships **whiteout markers for framework paths** will bootloop the
   device again; `lineage_hide` is currently disabled for exactly this reason.
