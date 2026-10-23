#!/bin/sh
# audio-fix.sh [bt-address]
#
# With an address: drop and re-establish the Bluetooth link. This is the only
# thing that clears a stale A2DP transport owner in bluetoothd (Acquire then
# fails with NotAuthorized and the sink sits "running" at quantum 0) —
# restarting PipeWire alone does not.
#
# Without one: restart the PipeWire stack.

if [ -n "$1" ]; then
    bluetoothctl disconnect "$1" >/dev/null 2>&1
    sleep 2
    bluetoothctl connect "$1"
else
    systemctl --user restart wireplumber pipewire pipewire-pulse
fi
