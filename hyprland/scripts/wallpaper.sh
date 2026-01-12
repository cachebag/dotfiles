#!/bin/bash

WALLPAPER_DIR="$HOME/wallpapers"
CHOOSER_FILE="/tmp/wallpaper_selected"

rm -f "$CHOOSER_FILE"

yazi "$WALLPAPER_DIR" --chooser-file="$CHOOSER_FILE"

if [[ -f "$CHOOSER_FILE" ]]; then
    selected=$(<"$CHOOSER_FILE")

    if [[ -n "$selected" && -f "$selected" ]]; then
        # Get all active monitors
        monitors=$(hyprctl monitors -j | jq -r '.[].name')

        hyprctl hyprpaper preload "$selected"
        sleep 0.5

        # Set wallpaper on all monitors
        for monitor in $monitors; do
            hyprctl hyprpaper wallpaper "$monitor,$selected"
        done

        notify-send "Wallpaper Changed" "$(basename "$selected")" -i "$selected"

        echo "$selected" > ~/.config/hypr/current_wallpaper

        # Generate hyprpaper.conf with all active monitors
        cat > ~/.config/hypr/hyprpaper.conf <<EOF
ipc = on
splash = false

EOF

        # Add wallpaper entry for each monitor
        for monitor in $monitors; do
            cat >> ~/.config/hypr/hyprpaper.conf <<EOF
wallpaper {
  monitor = $monitor
  path = $selected
  fit_mode = cover
}

EOF
        done

        if command -v wal &>/dev/null; then
            wal -q -n -i "$selected" # build palette from wallpaper
            hyprctl reload
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
