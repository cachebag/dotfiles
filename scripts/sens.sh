#!/bin/bash
# Tune the pointer live, nothing saved:
#   sens                 show the current sensitivity and acceleration profile
#   sens 0.35            sensitivity, -1 (slowest) .. 1 (fastest); 0 = libinput default
#   sens flat [0.5]      constant speed: cursor moves a fixed multiple of the finger
#   sens adaptive [0.2]  libinput's accelerating curve (the default)
# When one feels right, put it in ~/dotfiles/hyprland/input.lua to keep it.
set -e
lua() { hyprctl dispatch "function() hl.config({ input = { $1 } }) end" >/dev/null; }
case "${1:-}" in
    "") ;;
    flat|adaptive) lua "accel_profile = \"$1\""; [[ -n ${2:-} ]] && lua "sensitivity = $2" ;;
    *) lua "sensitivity = $1" ;;
esac
printf 'sensitivity %s   accel_profile %s\n' \
    "$(hyprctl getoption input:sensitivity | head -1 | cut -d' ' -f2)" \
    "$(hyprctl getoption input:accel_profile | head -1 | sed 's/str: //; s/\[\[EMPTY\]\]/adaptive (default)/')"
