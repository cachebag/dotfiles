#!/usr/bin/env bash
set -uo pipefail
COLORS="$HOME/.cache/wal/colors.sh"
PROFILE_BASE="org.gnome.Terminal.Legacy.Profile"
PROFILE_PATH="/org/gnome/terminal/legacy/profiles:"
TRANSPARENCY_PERCENT=20
command -v gsettings >/dev/null 2>&1 || exit 0
gsettings list-schemas 2>/dev/null | grep -q "^org.gnome.Terminal.ProfilesList$" || exit 0
if [[ ! -f "$COLORS" ]]; then
    echo "No pywal colors at $COLORS -- run wal.sh first." >&2
    exit 1
fi
: "${FZF_DEFAULT_OPTS:=}"
: "${LS_COLORS:=}"
source "$COLORS"
palette="['$color0', '$color1', '$color2', '$color3', \
'$color4', '$color5', '$color6', '$color7', \
'$color8', '$color9', '$color10', '$color11', \
'$color12', '$color13', '$color14', '$color15']"
profiles=$(gsettings get org.gnome.Terminal.ProfilesList list 2>/dev/null \
    | tr -d "[]' " | tr ',' '\n')
[[ -z "$profiles" ]] && exit 0
count=0
while read -r uuid; do
    [[ -z "$uuid" ]] && continue
    target="${PROFILE_BASE}:${PROFILE_PATH}/:${uuid}/"
    gsettings set "$target" use-theme-colors false
    gsettings set "$target" background-color "$background"
    gsettings set "$target" foreground-color "$foreground"
    gsettings set "$target" palette "$palette"
    gsettings set "$target" cursor-colors-set true
    gsettings set "$target" cursor-background-color "$cursor"
    gsettings set "$target" cursor-foreground-color "$background"
    gsettings set "$target" use-transparent-background true
    gsettings set "$target" background-transparency-percent "$TRANSPARENCY_PERCENT"
    count=$((count + 1))
done <<< "$profiles"
echo "Applied pywal palette to $count gnome-terminal profile(s)"
