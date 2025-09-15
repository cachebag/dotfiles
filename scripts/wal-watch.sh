#!/usr/bin/env bash
# ~/dotfiles/scripts/wal-watch.sh

while inotifywait -e close_write,create,modify,move ~/dotfiles/hyprland/current_wallpaper; do
    ~/dotfiles/scripts/wal.sh
done

