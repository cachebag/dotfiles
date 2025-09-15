#!/usr/bin/env bash
# Sync Pywal colors with your current Hyprland wallpaper

# Location of the "current wallpaper" symlink
WALLPAPER_LINK="$HOME/dotfiles/hyprland/current_wallpaper"

# Fallback if the symlink doesn’t exist
WALL="${1:-$WALLPAPER_LINK}"

if [[ ! -f "$WALL" ]]; then
    echo "Wallpaper not found: $WALL"
    exit 1
fi

# Run pywal to generate colors
wal -q -n -i "$WALL"

# Optionally reload Waybar & Kitty to pick up the new palette
pkill -USR1 waybar 2>/dev/null
kitty @ set-colors --all ~/.cache/wal/colors-kitty.conf 2>/dev/null

# Export to a file Hyprland can source
cp ~/.cache/wal/colors-hyprland.conf ~/.config/hypr/colors.conf 2>/dev/null

echo "Pywal applied from $WALL"
