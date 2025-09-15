#!/bin/bash

WALLPAPER_DIR="$HOME/wallpapers"
CHOOSER_FILE="/tmp/wallpaper_selected"
MONITOR="HDMI-A-1"

rm -f "$CHOOSER_FILE"

# Launch yazi to select wallpaper
yazi "$WALLPAPER_DIR" --chooser-file="$CHOOSER_FILE"

# If file was selected
if [[ -f "$CHOOSER_FILE" ]]; then
    selected=$(<"$CHOOSER_FILE")

    if [[ -n "$selected" && -f "$selected" ]]; then
        # Apply wallpaper immediately
        hyprctl hyprpaper preload "$selected"
        sleep 0.5
        hyprctl hyprpaper wallpaper "$MONITOR,$selected"
        notify-send "Wallpaper Changed" "$(basename "$selected")" -i "$selected"

        # Save path for future use
        echo "$selected" > ~/.config/hypr/current_wallpaper

        # Generate persistent hyprpaper.conf
        cat > ~/.config/hypr/hyprpaper.conf <<EOF
ipc = on
preload = $selected
wallpaper = $MONITOR,$selected
EOF

        if command -v wal &>/dev/null; then
            wal -q -n -i "$selected"    # build palette from wallpaper
            # Optionally reload apps that understand wal:
            pkill -USR1 waybar 2>/dev/null
            kitty @ set-colors --all ~/.cache/wal/colors-kitty.conf 2>/dev/null
        fi

    else
        notify-send "Wallpaper not applied" "Invalid file selected."
    fi
else
    notify-send "Wallpaper picker cancelled" "No file was selected."
fi

