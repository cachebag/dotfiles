#!/usr/bin/env bash
WALLPAPER_LINK="$HOME/dotfiles/hyprland/current_wallpaper"
WALL_FILE="${1:-$WALLPAPER_LINK}"
if [[ -f "$WALL_FILE" ]]; then
    if file "$WALL_FILE" 2>/dev/null | grep -q "text\|ASCII"; then
        WALL=$(cat "$WALL_FILE")
    else
        WALL="$WALL_FILE"
    fi
else
    echo "Wallpaper file not found: $WALL_FILE"
    exit 1
fi
if [[ ! -f "$WALL" ]]; then
    echo "Wallpaper image not found: $WALL"
    exit 1
fi
WAL_BIN="$HOME/.local/share/pipx/venvs/pywal16/bin/wal"
[[ -x "$WAL_BIN" ]] || WAL_BIN=$(command -v wal || true)
if [[ ! -x "$WAL_BIN" ]]; then
    echo "pywal not found. Install it with: pipx install pywal16"
    notify-send "Colors not updated" "pywal is not installed" 2>/dev/null || true
    exit 1
fi
"$WAL_BIN" -q -n --saturate 0.8 -i "$WALL"
sleep 0.3
hyprctl reload 2>/dev/null || true
pkill waybar 2>/dev/null
sleep 0.3
nohup waybar >/dev/null 2>&1 &
kitty @ set-colors --all ~/.cache/wal/colors-kitty.conf 2>/dev/null || true
"$HOME/dotfiles/scripts/wal-gnome-terminal.sh" >/dev/null 2>&1 || true
cp ~/.cache/wal/colors-hyprland.conf ~/.config/hypr/colors.conf 2>/dev/null
echo "Pywal applied from $WALL"
