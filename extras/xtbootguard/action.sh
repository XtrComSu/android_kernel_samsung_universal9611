#!/system/bin/sh
#
# XT Boot Guard - module action (run from the KernelSU manager)
#
# Re-enables every module disabled by the guard (or by the user), clears the
# incomplete-boot counter and the restore marker, and logs the action.

DIR=/data/adb/xtbootguard
mkdir -p "$DIR"

n=0
for m in /data/adb/modules/*; do
    [ -e "$m/disable" ] || continue
    if rm -f "$m/disable"; then
        n=$((n + 1))
    fi
done

rm -f "$DIR/fails" "$DIR/restore_done"
echo "$(date '+%Y-%m-%d %H:%M:%S') ACTION reenabled=$n" >> "$DIR/boot.log"
log -t xtbootguard "action: re-enabled $n module(s), counters cleared"

echo "xtbootguard: re-enabled $n module(s), counters cleared"
