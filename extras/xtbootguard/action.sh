#!/system/bin/sh
#
# XT Boot Guard - module action (run from the KernelSU manager)
#
# Re-enables every module disabled by the guard (or by the user) and reports
# how many were re-enabled.

n=0
for m in /data/adb/modules/*; do
    [ -e "$m/disable" ] || continue
    if rm -f "$m/disable"; then
        n=$((n + 1))
    fi
done

echo "xtbootguard: re-enabled $n module(s)"
log -t xtbootguard "action: re-enabled $n module(s)"
