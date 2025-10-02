#!/bin/bash

WALLPAPER_DIR="$HOME/wallpapers"
CHOOSER_FILE="/tmp/wallpaper_selected"
MONITOR="eDP-1"
CURRENT_FILE="$HOME/.config/hypr/current_wallpaper"
BLACK_FILE="/tmp/black_wallpaper_active"

# If toggle to black is active, restore last wallpaper
if [[ -f "$BLACK_FILE" ]]; then
    if [[ -f "$CURRENT_FILE" ]]; then
        wp=$(<"$CURRENT_FILE")
        if [[ -n "$wp" && -f "$wp" ]]; then
            hyprctl hyprpaper preload "$wp"
            sleep 0.5
            hyprctl hyprpaper wallpaper "$MONITOR,$wp"
            notify-send "Wallpaper Restored" "$(basename "$wp")" -i "$wp"
        fi
    fi
    rm -f "$BLACK_FILE"
    exit 0
fi

# Run wallpaper chooser
rm -f "$CHOOSER_FILE"
yazi "$WALLPAPER_DIR" --chooser-file="$CHOOSER_FILE"

if [[ -f "$CHOOSER_FILE" ]]; then
    selected=$(<"$CHOOSER_FILE")

    if [[ -n "$selected" && -f "$selected" ]]; then
        hyprctl hyprpaper preload "$selected"
        sleep 0.5
        hyprctl hyprpaper wallpaper "$MONITOR,$selected"
        notify-send "Wallpaper Changed" "$(basename "$selected")" -i "$selected"

        echo "$selected" > "$CURRENT_FILE"

        cat > ~/.config/hypr/hyprpaper.conf <<EOF
ipc = on
preload = $selected
wallpaper = $MONITOR,$selected
EOF

        if command -v wal &>/dev/null; then
            wal -q -n -i "$selected"
            pkill -USR1 waybar 2>/dev/null
            kitty @ set-colors --all ~/.cache/wal/colors-kitty.conf 2>/dev/null
        fi

    else
        notify-send "Wallpaper not applied" "Invalid file selected."
    fi
else
    # If chooser was not used, set plain black wallpaper and mark toggle
    hyprctl hyprpaper wallpaper "$MONITOR,#000000"
    touch "$BLACK_FILE"
    notify-send "Wallpaper Set" "Black background"
fi
