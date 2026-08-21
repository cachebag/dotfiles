#!/bin/bash

WALLPAPER_DIR="$HOME/wallpapers"
CHOOSER_FILE="/tmp/wallpaper_selected"
MONITOR="eDP-1"

selected="${1:-}"

if [[ -z "$selected" ]]; then
    rm -f "$CHOOSER_FILE"
    yazi "$WALLPAPER_DIR" --chooser-file="$CHOOSER_FILE"

    if [[ ! -f "$CHOOSER_FILE" ]]; then
        notify-send "Wallpaper picker cancelled" "No file was selected."
        exit 0
    fi

    selected=$(<"$CHOOSER_FILE")
fi

if [[ -z "$selected" || ! -f "$selected" ]]; then
    notify-send "Wallpaper not applied" "Invalid file selected."
    exit 1
fi

hyprctl hyprpaper preload "$selected"
sleep 0.5
hyprctl hyprpaper wallpaper "$MONITOR,$selected"
notify-send "Wallpaper Changed" "$(basename "$selected")" -i "$selected"

echo "$selected" > ~/.config/hypr/current_wallpaper
echo "$selected" > ~/dotfiles/hyprland/current_wallpaper

cat > ~/.config/hypr/hyprpaper.conf <<EOF
ipc = on
splash = false

wallpaper {
  monitor = $MONITOR
  path = $selected
  fit_mode = cover
}
EOF

if command -v python &>/dev/null && python -m pywal --help &>/dev/null; then
    python -m pywal -q -n -i "$selected"

    sleep 0.3

    hyprctl reload

    if pgrep -x waybar >/dev/null; then
        pkill waybar
        sleep 0.3
        nohup waybar >/dev/null 2>&1 &
    fi

    kitty @ set-colors --all ~/.cache/wal/colors-kitty.conf 2>/dev/null || true

    notify-send "Colors Updated" "Pywal colors applied"
fi
