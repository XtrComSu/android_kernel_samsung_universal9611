### AnyKernel3 Ramdisk Mod Script
## osm0sis @ xda-developers

### AnyKernel setup
# global properties
properties() { '
kernel.string=XT-Line Kernel (Universal Exynos 9611)
do.devicecheck=1
do.modules=0
do.systemless=1
do.cleanup=1
do.cleanuponabort=0
device.name1=a51
device.name2=f41
device.name3=m31s
device.name4=m31
device.name5=m21
device.name6=gta4xl
device.name7=gta4xlwifi
device.name8=m21s
supported.versions=13 - 16
supported.patchlevels=
supported.vendorpatchlevels=
'; } # end properties


### AnyKernel install
## boot files attributes
boot_attributes() {
set_perm_recursive 0 0 755 644 $RAMDISK/*;
set_perm_recursive 0 0 750 750 $RAMDISK/init* $RAMDISK/sbin;
} # end attributes

# boot shell variables
block=/dev/block/platform/13520000.ufs/by-name/boot;
dtboblock=/dev/block/platform/13520000.ufs/by-name/dtbo;
is_slot_device=0;
ramdisk_compression=auto;
patch_vbmeta_flag=auto;

# import functions/variables and setup patching - see for reference (DO NOT REMOVE)
. tools/ak3-core.sh;

# XT-Line installer flair (pure ASCII so every recovery renders it)
xt_header() {
  ui_print " ";
  ui_print "  +==================================================+";
  ui_print "  |                                                  |";
  ui_print "  |        X T - L I N E   K E R N E L               |";
  ui_print "  |                                                  |";
  ui_print "  |   Exynos 9611  |  KernelSU-Next  |  SUSFS        |";
  ui_print "  |   custom build - keep a backup, stay safe        |";
  ui_print "  |                                                  |";
  ui_print "  +==================================================+";
  ui_print " ";
  sleep 1;
}

xt_step() {
  ui_print "  [..] $*";
  sleep 1;
}

xt_header;
xt_step "Unpacking the current boot image";
dump_boot;

# XT-Line fail-safe: keep a copy of the current boot image before patching so a
# bad kernel can be restored from recovery. Best effort: /sdcard may be
# unmounted in some recoveries.
boot_backup() {
  [ -n "$BLOCK" ] || return 0;
  local dir=/sdcard/Download
  [ -d "$dir" ] || dir=/data/local/tmp
  [ -d "$dir" ] || dir=/tmp
  local stamp
  stamp=$(date +%Y%m%d-%H%M%S 2>/dev/null) || stamp=manual
  local out="$dir/boot-backup-$stamp.img"
  if dd if="$BLOCK" of="$out" bs=4096 2>/dev/null; then
    ui_print "  [OK] Boot backup: $out"
  else
    ui_print "  [! ] Boot backup failed (continuing)";
  fi
}
xt_step "Saving a boot image backup";
boot_backup;

# XT-Line boot guard: ship the progressive bootloop guard with the kernel.
xt_install_guard() {
  local src="$PWD/xtbootguard"
  [ -d "$src" ] || src="$(dirname "$0")/xtbootguard"
  if [ ! -d "$src" ]; then
    ui_print "  [! ] Boot guard payload missing (skipping)";
    return 0;
  fi
  [ -d /data/adb ] || mount /data 2>/dev/null || true;
  if [ -d /data/adb ]; then
    local dst=/data/adb/modules/xtbootguard
    mkdir -p "$dst" /data/adb/xtbootguard
    if cp -af "$src"/. "$dst"/ 2>/dev/null; then
      chmod 755 "$dst"/*.sh 2>/dev/null
      ui_print "  [OK] Boot guard auto-installed";
    else
      ui_print "  [! ] Boot guard copy failed";
    fi
  else
    mkdir -p /sdcard/Download/xtbootguard
    cp -af "$src"/. /sdcard/Download/xtbootguard/ 2>/dev/null
    ui_print "  [! ] /data not mounted - guard copied to /sdcard/Download/xtbootguard"
  fi
}
xt_step "Installing boot guard";
xt_install_guard;

xt_step "Patching kernel and ramdisk";
write_boot;
ui_print "  [OK] Kernel installed";
ui_print " ";
ui_print "  ==================================================";
ui_print "     INSTALL COMPLETE  -  REBOOT TO BOOT XT-LINE";
ui_print "     Hold VOL DOWN at boot for KernelSU safe mode";
ui_print "     Boot backup saved in /sdcard/Download";
ui_print "     Guard: 3 fails = modules off, 6 = recovery, 9 = boot restore";
ui_print "  ==================================================";
ui_print "    01011000 01010100 00101101 01001100 01001001 01001110 01000101";
ui_print " ";
## end boot install
ui_print "Installation Done"
