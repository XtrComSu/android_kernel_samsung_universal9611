#!/system/bin/sh
#
# XT Boot Guard - post-fs-data stage
#
# Progressive bootloop fallback (every step is written to boot.log):
#   3 incomplete boots -> disable all other KernelSU modules (safe boot)
#   6 incomplete boots -> write a report and reboot to recovery
#   9 incomplete boots -> restore the newest boot-image backup (size-checked)
#                         and reboot; fall back to recovery if impossible

MODDIR=${0%/*}
DIR=/data/adb/xtbootguard
SAFE_AT=3
RECOVERY_AT=6
RESTORE_AT=9
BOOT_IMG=/dev/block/platform/13520000.ufs/by-name/boot
BACKUP_GLOB="/sdcard/Download/boot-backup-*.img"

mkdir -p "$DIR"

xtlog() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $*" >> "$DIR/boot.log"
    log -t xtbootguard "$*"
    if [ "$(wc -l < "$DIR/boot.log" 2>/dev/null || echo 0)" -gt 200 ]; then
        tail -n 200 "$DIR/boot.log" > "$DIR/boot.log.tmp" && mv -f "$DIR/boot.log.tmp" "$DIR/boot.log"
    fi
}

bootinfo() {
    echo "kernel=$(uname -r) bootreason=$(getprop ro.boot.bootreason) last_reason=$(getprop persist.sys.boot.reason.history 2>/dev/null | tr '\n' ' ' | cut -c1-80)"
}

CNT=$(cat "$DIR/fails" 2>/dev/null)
case "$CNT" in
''|*[!0-9]*) CNT=0 ;;
esac
CNT=$((CNT + 1))
echo "$CNT" > "$DIR/fails"

MODCOUNT=$(ls -1d /data/adb/modules/*/ 2>/dev/null | wc -l)
xtlog "POST_FS_DATA fails=$CNT modules=$MODCOUNT $(bootinfo)"

if [ "$CNT" -eq "$SAFE_AT" ]; then
    n=0
    for m in /data/adb/modules/*; do
        [ -d "$m" ] || continue
        [ "$m" = "/data/adb/modules/xtbootguard" ] && continue
        [ -e "$m/disable" ] && continue
        if touch "$m/disable"; then
            n=$((n + 1))
        fi
    done
    echo "safe mode at boot $CNT: disabled $n module(s)" > "$DIR/last"
    xtlog "SAFE_MODE disabled=$n after=$CNT incomplete boots"
fi

if [ "$CNT" -eq "$RECOVERY_AT" ]; then
    echo "desperation at boot $CNT: rebooting to recovery" > "$DIR/last"
    {
        echo "XT Boot Guard: $CNT incomplete boots."
        echo "Modules were disabled at $SAFE_AT incomplete boots."
        echo "You are being sent to recovery; flash the kernel zip or a boot backup."
        echo "Boot backups:"
        ls -1t /sdcard/Download/boot-backup-*.img 2>/dev/null | head -5
    } > /sdcard/Download/XTBOOTGUARD-README.txt 2>/dev/null
    xtlog "DESPERATE_RECOVERY after=$CNT incomplete boots"
    sync
    setprop sys.powerctl "reboot,recovery"
    exit 0
fi

if [ "$CNT" -ge "$RESTORE_AT" ]; then
    if [ -e "$DIR/restore_done" ]; then
        xtlog "DESPERATE_RECOVERY after=$CNT (boot restore already attempted)"
        setprop sys.powerctl "reboot,recovery"
        exit 0
    fi

    BACKUP=$(ls -1t $BACKUP_GLOB 2>/dev/null | head -1)
    if [ -n "$BACKUP" ] && [ -b "$BOOT_IMG" ]; then
        BSIZE=$(wc -c < "$BACKUP" 2>/dev/null)
        DEVNAME=$(readlink -f "$BOOT_IMG" 2>/dev/null)
        PART=$(basename "$DEVNAME" 2>/dev/null)
        SEC=$(cat "/sys/class/block/$PART/size" 2>/dev/null)
        PSIZE=$((SEC * 512))
        if [ -n "$SEC" ] && [ "$BSIZE" = "$PSIZE" ]; then
            xtlog "RESTORE backup=$BACKUP bytes=$BSIZE after=$CNT incomplete boots"
            if dd if="$BACKUP" of="$BOOT_IMG" bs=1048576 conv=fsync 2>/dev/null; then
                sync
                touch "$DIR/restore_done"
                echo "restored $BACKUP at boot $CNT" > "$DIR/last"
                xtlog "RESTORE_OK rebooting system"
                setprop sys.powerctl "reboot"
                exit 0
            else
                xtlog "RESTORE_FAILED writing $BOOT_IMG"
            fi
        else
            xtlog "RESTORE_SKIPPED backup=$BACKUP bytes=$BSIZE partition=$PSIZE"
        fi
    else
        xtlog "RESTORE_UNAVAILABLE no size-checked backup at $BACKUP_GLOB"
    fi

    xtlog "DESPERATE_RECOVERY after=$CNT (restore unavailable)"
    setprop sys.powerctl "reboot,recovery"
    exit 0
fi
