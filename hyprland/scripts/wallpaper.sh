#!/bin/bash

WALLPAPER_DIR="$HOME/wallpapers"
CHOOSER_FILE="/tmp/wallpaper_selected"
MONITOR="HDMI-A-1"  # Replace with your actual monitor name from `hyprctl monitors`

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

    else
        notify-send "Wallpaper not applied" "Invalid file selected."
    fi
else
    notify-send "Wallpaper picker cancelled" "No file was selected."
fi

