#!/system/bin/sh
#
# XT Boot Guard - late_start service stage
#
# Waits (in the background, so other module services are not delayed) for
# sys.boot_completed=1 and clears the incomplete-boot counter.

DIR=/data/adb/xtbootguard
mkdir -p "$DIR"

(
    i=0
    while [ "$i" -lt 180 ]; do
        if [ "$(getprop sys.boot_completed)" = "1" ]; then
            rm -f "$DIR/fails"
            log -t xtbootguard "boot completed; counter cleared"
            exit 0
        fi
        sleep 1
        i=$((i + 1))
    done
    log -t xtbootguard "boot_completed not seen in 180s; counter kept"
) &
