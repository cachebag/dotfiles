 ffw#!/bin/bash

WALLPAPER_DIR="$HOME/wallpapers"
CHOOSER_FILE="/tmp/wallpaper_selected"
MONITOR="DP-1"

rm -f "$CHOOSER_FILE"

yazi "$WALLPAPER_DIR" --chooser-file="$CHOOSER_FILE"

if [[ -f "$CHOOSER_FILE" ]]; then
    selected=$(<"$CHOOSER_FILE")

    if [[ -n "$selected" && -f "$selected" ]]; then
        hyprctl hyprpaper preload "$selected"
        sleep 0.5
        hyprctl hyprpaper wallpaper "$MONITOR,$selected"
        notify-send "Wallpaper Changed" "$(basename "$selected")" -i "$selected"

        echo "$selected" > ~/.config/hypr/current_wallpaper

        cat > ~/.config/hypr/hyprpaper.conf <<EOF
ipc = on
preload = $selected
wallpaper = $MONITOR,$selected
EOF

        if command -v wal &>/dev/null; then
            wal -q -n -i "$selected" # build palette from wallpaper
            pkill waybar
            sleep 0.2
            nohup waybar >/dev/null 2>&1 &
            kitty @ set-colors --all ~/.cache/wal/colors-kitty.conf 2>/dev/null
        fi

    else
        notify-send "Wallpaper not applied" "Invalid file selected."
    fi
else
    notify-send "Wallpaper picker cancelled" "No file was selected."
fi

