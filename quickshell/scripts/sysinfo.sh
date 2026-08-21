#!/bin/bash

read -r _ a b c prev_idle rest < /proc/stat
prev_total=$((a + b + c + prev_idle))
for v in $rest; do prev_total=$((prev_total + v)); done

sleep 0.25

read -r _ a b c idle rest < /proc/stat
total=$((a + b + c + idle))
for v in $rest; do total=$((total + v)); done

d_total=$((total - prev_total))
d_idle=$((idle - prev_idle))
cpu=0
[[ $d_total -gt 0 ]] && cpu=$(((100 * (d_total - d_idle)) / d_total))

mem=$(awk '/MemTotal/{t=$2} /MemAvailable/{a=$2} END{if (t>0) printf "%d", (t-a)*100/t; else print 0}' /proc/meminfo)

echo "$cpu $mem"
