#!/bin/bash

WALLPAPER_DIR="$HOME/wallpapers"
CHOOSER_FILE="/tmp/wallpaper_selected"
MONITOR="DP-2"
MONITOR2="HDMI-A-1"

rm -f "$CHOOSER_FILE"

yazi "$WALLPAPER_DIR" --chooser-file="$CHOOSER_FILE"

if [[ -f "$CHOOSER_FILE" ]]; then
    selected=$(<"$CHOOSER_FILE")

    if [[ -n "$selected" && -f "$selected" ]]; then
        hyprctl hyprpaper preload "$selected"
        sleep 0.5
        hyprctl hyprpaper wallpaper "$MONITOR,$selected"
        hyprctl hyprpaper wallpaper "$MONITOR2,$selected"
        notify-send "Wallpaper Changed" "$(basename "$selected")" -i "$selected"

        # Update wallpaper path files (for both hypr config and wal-watch script)
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

wallpaper {
  monitor = $MONITOR2
  path = $selected 
  fit_mode = cover 
}
EOF

        if command -v python &>/dev/null && python -m pywal --help &>/dev/null; then
            # Run pywal to generate colors from wallpaper (use python -m pywal directly)
            python -m pywal -q -n -i "$selected"
            
            # Wait a moment for pywal to finish generating files
            sleep 0.3
            
            # Reload hyprland to pick up new colors
            hyprctl reload
            
            # Reload waybar to pick up new colors
            pkill waybar
            sleep 0.3
            nohup waybar >/dev/null 2>&1 &
            
            # Apply colors to all kitty instances
            kitty @ set-colors --all ~/.cache/wal/colors-kitty.conf 2>/dev/null || true
            
            notify-send "Colors Updated" "Pywal colors applied to waybar and kitty"
        fi

    else
        notify-send "Wallpaper not applied" "Invalid file selected."
    fi
else
    notify-send "Wallpaper picker cancelled" "No file was selected."
fi

