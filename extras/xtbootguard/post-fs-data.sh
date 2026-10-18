#!/system/bin/sh
#
# XT Boot Guard - post-fs-data stage
#
# Counts boots that did not reach sys.boot_completed=1 (see service.sh).
# After 3 consecutive incomplete boots, disable every other KernelSU module
# so the next boot comes up with a clean module set. The module action
# (action.sh, run from the manager) re-enables them.

MODDIR=${0%/*}
DIR=/data/adb/xtbootguard
mkdir -p "$DIR"

CNT=$(cat "$DIR/fails" 2>/dev/null)
case "$CNT" in
''|*[!0-9]*) CNT=0 ;;
esac
CNT=$((CNT + 1))

if [ "$CNT" -ge 3 ]; then
    n=0
    for m in /data/adb/modules/*; do
        [ -d "$m" ] || continue
        [ "$m" = "/data/adb/modules/xtbootguard" ] && continue
        [ -e "$m/disable" ] && continue
        if touch "$m/disable"; then
            n=$((n + 1))
        fi
    done
    echo "disabled $n module(s) after $CNT incomplete boots" > "$DIR/last"
    log -t xtbootguard "auto-disabled $n module(s) after $CNT incomplete boots"
    rm -f "$DIR/fails"
else
    echo "$CNT" > "$DIR/fails"
    log -t xtbootguard "incomplete-boot counter: $CNT/3"
fi
