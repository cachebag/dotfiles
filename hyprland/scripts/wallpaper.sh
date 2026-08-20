#!/bin/bash
WALLPAPER_DIR="$HOME/wallpapers"
CHOOSER_FILE="/tmp/wallpaper_selected"
rm -f "$CHOOSER_FILE"
yazi "$WALLPAPER_DIR" --chooser-file="$CHOOSER_FILE"
if [[ -f "$CHOOSER_FILE" ]]; then
    selected=$(<"$CHOOSER_FILE")
    if [[ -n "$selected" && -f "$selected" ]]; then
        while read -r monitor; do
            hyprctl hyprpaper wallpaper "$monitor, $selected, cover"
        done < <(hyprctl monitors -j | jq -r '.[].name')
        notify-send "Wallpaper Changed" "$(basename "$selected")" -i "$selected" 2>/dev/null || true
        echo "$selected" > "$HOME/.config/hypr/current_wallpaper"
        echo "$selected" > "$HOME/dotfiles/hyprland/current_wallpaper"
        {
            echo "ipc = on"
            echo "splash = false"
            echo
            while read -r monitor; do
                cat <<EOF
wallpaper {
    monitor = $monitor
    path = $selected
    fit_mode = cover
}
EOF
            done < <(hyprctl monitors -j | jq -r '.[].name')
        } > "$HOME/.config/hypr/hyprpaper.conf"
        if "$HOME/dotfiles/scripts/wal.sh" "$selected"; then
            notify-send "Colors Updated" "Pywal colors applied to Waybar and Kitty" 2>/dev/null || true
        else
            notify-send "Colors not updated" "wal.sh failed -- see 'pipx install pywal16'" 2>/dev/null || true
        fi
    else
        notify-send "Wallpaper not applied" "Invalid file selected." 2>/dev/null || true
    fi
else
    notify-send "Wallpaper picker cancelled" "No file was selected." 2>/dev/null || true
fi
