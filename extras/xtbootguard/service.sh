#!/system/bin/sh
#
# XT Boot Guard - late_start service stage
#
# Logs the boot, waits (in the background) for sys.boot_completed=1 and then
# clears the incomplete-boot counter.

DIR=/data/adb/xtbootguard
mkdir -p "$DIR"

xtlog() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $*" >> "$DIR/boot.log"
    log -t xtbootguard "$*"
}

CNT=$(cat "$DIR/fails" 2>/dev/null)
case "$CNT" in
''|*[!0-9]*) CNT=0 ;;
esac
xtlog "SERVICE_START fails=$CNT kernel=$(uname -r) bootreason=$(getprop ro.boot.bootreason)"

(
    i=0
    while [ "$i" -lt 180 ]; do
        if [ "$(getprop sys.boot_completed)" = "1" ]; then
            xtlog "BOOT_COMPLETED fails=$CNT modules=$(ls -1d /data/adb/modules/*/ 2>/dev/null | wc -l)"
            rm -f "$DIR/fails" "$DIR/restore_done"
            exit 0
        fi
        sleep 1
        i=$((i + 1))
    done
    xtlog "BOOT_NOT_COMPLETED_IN_180S fails=$CNT (counter kept)"
) &
