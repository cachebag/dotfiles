#!/bin/bash

WALLPAPER_DIR="$HOME/wallpapers"
CHOOSER_FILE="/tmp/wallpaper_selected"
MONITOR=""   # empty = all connected outputs

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
            
            pkill waybar
            sleep 0.3
            nohup waybar >/dev/null 2>&1 &
            
            kitty @ set-colors --all ~/.cache/wal/colors-kitty.conf 2>/dev/null || true
            
            notify-send "Colors Updated" "Pywal colors applied to waybar and kitty"
        fi

    else
        notify-send "Wallpaper not applied" "Invalid file selected."
    fi
else
    notify-send "Wallpaper picker cancelled" "No file was selected."
fi
