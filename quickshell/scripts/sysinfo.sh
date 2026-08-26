#!/usr/bin/env bash
# Emits "<cpu%> <mem%>" for Resources.qml.
# CPU is averaged since the previous run rather than sampled with a sleep,
# so the widget's own poll interval sets the window.

state="${XDG_RUNTIME_DIR:-/tmp}/qs-sysinfo.state"

read -r _ user nice sys idle iowait irq softirq steal _ < /proc/stat
idle_all=$((idle + iowait))
total=$((user + nice + sys + idle + iowait + irq + softirq + steal))

cpu=0
if [[ -r $state ]]; then
    read -r prev_total prev_idle < "$state"
    dt=$((total - prev_total))
    di=$((idle_all - prev_idle))
    if ((dt > 0)); then
        cpu=$(((100 * (dt - di) + dt / 2) / dt))
        ((cpu < 0)) && cpu=0
        ((cpu > 100)) && cpu=100
    fi
fi
printf '%s %s\n' "$total" "$idle_all" > "$state"

# MemAvailable, not MemFree: cache and reclaimable slab are not "used".
mem_total=0
mem_avail=0
while read -r key value _; do
    case $key in
        MemTotal:) mem_total=$value ;;
        MemAvailable:)
            mem_avail=$value
            break
            ;;
    esac
done < /proc/meminfo

mem=0
((mem_total > 0)) && mem=$(((100 * (mem_total - mem_avail) + mem_total / 2) / mem_total))

printf '%d %d\n' "$cpu" "$mem"
