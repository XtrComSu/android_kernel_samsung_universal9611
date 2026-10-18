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

## 8. KSUN v3.4.2 rebase + NoMount removal (2026-10-18)

### `a95e833fc` `[src]` — rebase vendored KernelSU-Next onto official v3.4.2 + SUSFS glue
The vendored `drivers/kernelsu/` was rebased onto the official KernelSU-Next
tree at `465490a266` (v3.4.2, UAPI 5) plus the SUSFS glue on top: 11 files,
500 insertions / 0 deletions against the official commit (audited in the port
repo as `3323ee36`). Glue source: sidex15 `d999a2aff115`
(`v3.4.0-legacy-susfs-v2`). This supersedes the v3.3.0 downgrade (§2,
`710c0d8c3`) and its version pin.

Version pins: `KSU_VERSION_OVERRIDE=33355` /
`KSU_VERSION_TAG_OVERRIDE=v3.4.2-legacy-susfs-v2` in `build_kernel.py` and
CI, and the post-build check **hard-fails** unless the tag string is found
in `Image`. Manager pairing:
`KernelSU_Next_v3.4.2-spoofed_33355-release.apk` (see `XT-Xenos9611.md`
§MANAGER).

NoMount removed in the same change: `fs/nomount/` (88 KB) deleted, its
`fs/Makefile` / `fs/Kconfig` lines dropped, `CONFIG_NOMOUNT=y` removed from
all seven defconfigs, and every NoMount CI assertion (symbol, `CONFIG_KEYS`,
`nomount` string) deleted. Module mounting is KernelSU-Next's own mechanism
again. History + bootloop lesson: §6.

Also re-applied: `-Wno-misleading-indentation` in the vendored Kbuild (§2,
`ef9e54226`).

### `64e6f0900` `[fix]` — `__poll_t` clash with the vendor tree's backport
`infra/event_queue.h` re-typedefs `__poll_t` below 4.16, but this vendor 4.14
tree already has it in `include/uapi/linux/types.h` →
`-Werror,-Wtypedef-redefinition`; the first v3.4.2 build (run `39125207801`)
failed here. Fix follows the official Kbuild backport-probe pattern: a
`grep` probe adds `-DKSU_HAS_POLL_T` and the fallback typedef is skipped when
it is set. **Do not "simplify" this back to a plain version check.**

Kernel-side SUSFS verified byte-identical to sidex15 branch HEAD `929a8eac7`
(2026-09-13) during this rebase: already the newest non-GKI v2.3.0
(OPEN_REDIRECT UAF/deadlock fixes, SUS_MOUNT minor-dev gap fix, spoofing
refactor, NULL-deref fix).

---

## 9. Current steady state

- Last green build: run **39140557770** at `e77b66d8a` (CPU pass, §12);
  previous: run `39137640082` at `4ab0eb8f2` (gaming pass, §11), run
  `39133066014` at merge `518fd077b` (upstream catch-up, §10), and run
  `39126533696` at `64e6f0900` (v3.4.2 rebase).
- CI asserts: `BIC`/`DEFAULT_TCP_CONG="bic"`, the tag string
  `v3.4.2-legacy-susfs-v2` in `Image`, all nine implemented SUSFS features
  `=y`, `SUSFS_ENABLE_LOG` off, `SUS_MEMFD` **off**, plus the
  external-wifi/gadget and tuning symbol sets (the old NoMount entries are
  gone).
- Device-side (pending flash of the v3.4.2 build): expect `ksud susfs` to
  report v2.3.0 NON-GKI 9/9, the firmware overlay at
  `/vendor/firmware/rtlwifi/rtl8188eufw.bin` (KSUN mounts it natively now),
  and NoMount's metamodule to be removed/inert.

### Open / known risks
1. **f2fs `nobarrier`** on `/data` can still zero-fill files on an unclean
   shutdown (module files have been lost this way). Reflash/restore to repair.
2. **SUSFS hiding requires a real app to validate** — `su <uid>` is not a valid probe.
3. Any module that ships **whiteout markers for framework paths** can bootloop the
   device; `lineage_hide` is currently disabled for exactly this reason.
4. **On-device flash of the v3.4.2 build is still pending** — the current
   flash target is the catch-up build (`518fd077b`, run `39133066014`);
   device-verified statements elsewhere refer to the last flashed build
   (v3.3.0, `ed1241b9a`).

---

## 10. Upstream catch-up — lineage-24.0 merge (2026-10-18)

### `518fd077b` `[src]` — merge upstream `lineage-24.0` into `ksun-susfs`
Parbindar's branch had been **rebased** (commit IDs changed, content mostly
identical). Content probes confirmed the clone3 / CAP_CHECKPOINT_RESTORE
series, the tipc/NFC-LLCP fixes and the `dev_recursion_level` `this_cpu`
fix were already present in our tree. The **only** real delta the merge
brought in is the NFC enable in the two defconfigs upstream changed:
`CONFIG_SAMSUNG_NFC=y`, `CONFIG_SEC_NFC=y`, `CONFIG_SEC_NFC_LOGGER=y`
(`exynos9611-m21_defconfig`, `exynos9611-m31_defconfig`).

Merge was conflict-free. Fixes from our older chain that the upstream
rebase dropped (e.g. the `mm/zsmalloc.c` compaction locking fix) are
preserved on our side. Post-merge checks: `KSU_HAS_POLL_T` guard + Kbuild
probe intact, `CONFIG_KSU=y` / `CONFIG_KSU_SUSFS=y` intact, `fs/nomount`
still absent, `XT-Line` naming intact.

Build: run `39133066014` (push, head `518fd077b`) — **green**. Artifact
re-verified: `v3.4.2-legacy-susfs-v2` tag present, `nomount` count 0.

**Lesson:** upstream rewrites its branch history, so "N commits behind" is
not a content signal. Probe actual content before assuming a catch-up is a
big job.

---

## 11. Gaming performance pass (2026-10-18)

### `4ab0eb8f2` `[cfg]` — GPU DVFS hysteresis fix + touch boosts
Sustained-load analysis of the vendor GPU DVFS found the top OPP pair
unstable: 1053 MHz dropped below 95% utilization with a stay-count of 1,
while 949 MHz only climbed above 90%. Sustained GPU loads in the 90-95%
band therefore bounced between the top two OPPs every poll (the 10 ms
timer is 3 jiffies at HZ=250, so ~12 ms), sawtoothing frame times exactly
in the range heavy games sit in.

DTS changes (`exynos9610.dts`):
- 1053 MHz: down threshold 95→75, stay 1→3 (~36 ms below 75% before
  dropping).
- 949/839/764 MHz: up threshold 90→80; stays 1→2 at 949/839.
- interactive `highspeed` jump 764→839 MHz at 70% util (this doubles as
  the lock clock for the interactive-boost workaround).
The pairs are chosen so `up(949)=80 > down(1053)=75`: a 75-80% band is
stable at 1053 MHz instead of oscillating. Do not restore 95/90 without
re-checking this.

Input booster (`exynos9610-inputbooster.dtsi`; the vendor booster in
`drivers/input/input.c` was already active):
- TOUCH/MULTITOUCH head: BIG min 1.14→1.456 GHz, LITTLE min
  0.806→0.936 GHz, MIF 1.014→1.352 GHz; TOUCH tail 936→1.053 GHz
  (head 130 ms / tail 500 ms unchanged).

GPU touch boost (new code):
- `gpexwa_interactive_boost_set()` was only reachable from the vendor UMD
  ioctl `MALI_EXYNOS_IOCTL_INTERACTIVE_BOOST`, which LineageOS never
  sends, so `CONFIG_MALI_EXYNOS_INTERACTIVE_BOOST=y` was inert.
- The input booster now calls an exported `mali_exynos_touch_boost()`
  (new `include/linux/mali_exynos_boost.h`), gated on GPU power via
  `gpex_pm_get_status(false)`, which locks the GPU at the highspeed clock
  for 500 ms per input event while the GPU is active.

Build: run `39137640082` (push, head `4ab0eb8f2`) — green; artifact
re-verified (tag present, `nomount`=0, `mali_exynos_touch_boost` in
`Image`).

---

## 12. CPU performance pass (2026-10-18)

### `aab2df28a` + `e77b66d8a` `[cfg]` — hot-path debug accounting removed
Audit of the CPU side (schedutil, WALT, EMS, ACME, UFC, idle) found no
oscillation-class defect, unlike the GPU table. Three debug features were
still charging the hot path and are now off:

- `CONFIG_DEBUG_PREEMPT` — turns `smp_processor_id()` into a checked call
  and enables preempt-count debug checks in scheduling/IPI/net paths.
- `CONFIG_DEBUG_LIST` — validates list_add/list_del on every list
  operation kernel-wide.
- `CONFIG_DEBUG_SNAPSHOT_LOGGING_SMC` — wrapped every `exynos_smc()` call
  (cal-if power sequences) with two `cpu_clock()` reads, latency math and
  a spinlock above the threshold. Only the Samsung eng log is lost.

CI now asserts all three stay off.

**Do not disable `CONFIG_TASK_DELAY_ACCT` without patching
`drivers/samsung/debug/sec_debug.c` first.** It was briefly turned off,
but `TASK_DELAY_ACCT` **selects `SCHED_INFO`**, which owns
`struct sched_info`'s four members; `sec_debug.c` registers those member
offsets unconditionally and the build failed with 8 errors (run
`39139505797`). `e77b66d8a` restored it. Consequence: with `SCHEDSTATS`
off, `delayacct_on` stays 1 and `sched_info_on()` returns 1, so the
per-enqueue/dequeue/context-switch accounting remains — a known,
documented cost, not an accident.

Verified and deliberately unchanged (no defect found):
`freqvar` upscale ratios (LITTLE 60/80 split at 910 MHz, BIG 80 =
mainline 1.25x), 5 ms up/down rate limits (= ACME `TRANSITION_LATENCY`),
schedutil shared-policy aggregation and `sugov_cpu_is_busy()` anti-drop,
WALT 20 ms tick-aligned window with `prev_runnable_sum` as the freq util
source, 936 MHz BIG floor (`min-freq` is a deliberate floor, not a cap),
UFC being sysfs-only/inert, LBT 80% and ontime 68/17 boundaries.
Note: the input booster's `kpp_request()` calls have **no consumer** in
this scheduler (`kpp_status()` is only exposed via sysfs); placement
boosts are driven by uclamp, not KPP.

Build: run `39140557770` (push, head `e77b66d8a`) — green; artifact
re-verified (tag, `nomount`=0, touch-boost symbol, zip hash).
