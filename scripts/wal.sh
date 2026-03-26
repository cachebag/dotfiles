#!/usr/bin/env bash
# Sync Pywal colors with your current Hyprland wallpaper

# Location of the "current wallpaper" symlink
WALLPAPER_LINK="$HOME/dotfiles/hyprland/current_wallpaper"

# Fallback if the symlink doesn't exist
WALL_FILE="${1:-$WALLPAPER_LINK}"

# If the file contains a path (text file), read it; otherwise use it directly
if [[ -f "$WALL_FILE" ]]; then
    # Check if it's a text file containing a path (not an image)
    if file "$WALL_FILE" 2>/dev/null | grep -q "text\|ASCII"; then
        WALL=$(cat "$WALL_FILE")
    else
        WALL="$WALL_FILE"
    fi
else
    echo "Wallpaper file not found: $WALL_FILE"
    exit 1
fi

if [[ ! -f "$WALL" ]]; then
    echo "Wallpaper image not found: $WALL"
    exit 1
fi

# Run pywal to generate colors (use python -m pywal to avoid recursion)
python -m pywal -q -n --saturate 0.8 -i "$WALL"

# Wait for pywal to finish generating files
sleep 0.3

# Reload hyprland to pick up new colors
hyprctl reload 2>/dev/null || true

# Reload Waybar to pick up the new palette (kill and restart for reliability)
pkill waybar 2>/dev/null
sleep 0.3
nohup waybar >/dev/null 2>&1 &

# Apply colors to all kitty instances
kitty @ set-colors --all ~/.cache/wal/colors-kitty.conf 2>/dev/null || true

# Export to a file Hyprland can source
cp ~/.cache/wal/colors-hyprland.conf ~/.config/hypr/colors.conf 2>/dev/null

echo "Pywal applied from $WALL"
