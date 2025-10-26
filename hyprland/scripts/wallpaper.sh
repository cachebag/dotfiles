#!/bin/bash

# Simple Hyprland wallpaper selector for one or more monitors

WALLPAPER_DIR="$HOME/wallpapers"
CHOOSER_FILE="/tmp/wallpaper_selected"
CURRENT_FILE="$HOME/.config/hypr/current_wallpaper"

MONITORS=$(hyprctl monitors -j | jq -r '.[].name')

rm -f "$CHOOSER_FILE"
yazi "$WALLPAPER_DIR" --chooser-file="$CHOOSER_FILE"

if [[ -f "$CHOOSER_FILE" ]]; then
    selected=$(<"$CHOOSER_FILE")

    if [[ -n "$selected" && -f "$selected" ]]; then
        hyprctl hyprpaper preload "$selected"
        sleep 0.5

        for mon in $MONITORS; do
            hyprctl hyprpaper wallpaper "$mon,$selected"
        done

        notify-send "Wallpaper Changed" "$(basename "$selected")" -i "$selected"
        echo "$selected" > "$CURRENT_FILE"

        # Update hyprpaper.conf
        {
            echo "ipc = on"
            echo "preload = $selected"
            for mon in $MONITORS; do
                echo "wallpaper = $mon,$selected"
            done
        } > ~/.config/hypr/hyprpaper.conf

        if command -v wal &>/dev/null; then
            wal -q -n -i "$selected"
            pkill waybar 
            sleep 0.2
            nohup waybar >/dev/null 2>&1 &
            kitty @ set-colors --all ~/.cache/wal/colors-kitty.conf 2>/dev/null
        fi

    else
        notify-send "Wallpaper not applied" "Invalid file selected."
    fi
else
    notify-send "No wallpaper selected" "No file chosen in yazi."
fi
