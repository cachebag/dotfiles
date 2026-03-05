#!/usr/bin/env bash
# ~/dotfiles/scripts/wal-watch.sh
# Watch for wallpaper changes and apply pywal colors

# Watch both possible locations
while inotifywait -e close_write,create,modify,move ~/dotfiles/hyprland/current_wallpaper ~/.config/hypr/current_wallpaper 2>/dev/null; do
    # Use the dotfiles location as primary, fallback to hypr config location
    if [[ -f ~/dotfiles/hyprland/current_wallpaper ]]; then
        ~/dotfiles/scripts/wal.sh ~/dotfiles/hyprland/current_wallpaper
    elif [[ -f ~/.config/hypr/current_wallpaper ]]; then
        ~/dotfiles/scripts/wal.sh ~/.config/hypr/current_wallpaper
    fi
    sleep 0.5
done

