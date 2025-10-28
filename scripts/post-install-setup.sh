#!/bin/bash

# Post-install setup script - Configure monitor and finalize setup
# Run this after first reboot into Hyprland

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

DOTFILES_DIR="$HOME/dotfiles"

echo -e "${BLUE}Post-Install Setup${NC}"
echo ""

# Check if running in Hyprland
if [ -z "$HYPRLAND_INSTANCE_SIGNATURE" ]; then
    echo -e "${YELLOW}Warning: Not running in Hyprland session${NC}"
    echo "Please run this script after logging into Hyprland"
    exit 1
fi

# Step 1: Detect monitors
echo -e "${GREEN}Step 1: Detecting monitors${NC}"
echo ""
hyprctl monitors

echo ""
echo "Available monitors:"
mapfile -t MONITOR_NAMES < <(hyprctl monitors -j | jq -r '.[].name')

if [ ${#MONITOR_NAMES[@]} -eq 0 ]; then
    echo "No monitors detected."
    exit 1
fi

for i in "${!MONITOR_NAMES[@]}"; do
    echo "  $((i+1)). ${MONITOR_NAMES[$i]}"
done

echo ""
read -p "Select your primary monitor (1-${#MONITOR_NAMES[@]}): " monitor_choice

if [[ ! "$monitor_choice" =~ ^[0-9]+$ ]] || [ "$monitor_choice" -lt 1 ] || [ "$monitor_choice" -gt ${#MONITOR_NAMES[@]} ]; then
    echo "Invalid choice. Using first monitor."
    monitor_choice=1
fi

PRIMARY_MONITOR="${MONITOR_NAMES[$((monitor_choice-1))]}"
echo "Selected monitor: $PRIMARY_MONITOR"

# Step 2: Get monitor resolution
echo ""
echo -e "${GREEN}Step 2: Getting monitor resolution${NC}"
RESOLUTION=$(hyprctl monitors -j | jq -r ".[] | select(.name==\"$PRIMARY_MONITOR\") | \"\(.width)x\(.height)\"")
REFRESH_RATE=$(hyprctl monitors -j | jq -r ".[] | select(.name==\"$PRIMARY_MONITOR\") | .refreshRate" | cut -d'.' -f1)

echo "Detected: ${RESOLUTION}@${REFRESH_RATE}Hz"
echo ""
read -p "Use this resolution? (y/n): " use_detected

if [ "$use_detected" != "y" ] && [ "$use_detected" != "Y" ]; then
    read -p "Enter custom resolution (e.g., 1920x1080): " RESOLUTION
    read -p "Enter refresh rate (e.g., 60): " REFRESH_RATE
fi

# Step 3: Update monitors.conf
echo ""
echo -e "${GREEN}Step 3: Updating monitor configuration${NC}"

cat > "$DOTFILES_DIR/hyprland/monitors.conf" << EOF
monitor = $PRIMARY_MONITOR, ${RESOLUTION}@${REFRESH_RATE}, 0x0, 1
# Add additional monitors below if needed
# monitor = HDMI-A-1, 2560x1440@165, 1920x0, 1
EOF

echo "Updated monitors.conf"

# Step 4: Initialize pywal colors
echo ""
echo -e "${GREEN}Step 4: Initializing color scheme${NC}"

if [ -d "$HOME/wallpapers" ] && [ "$(ls -A $HOME/wallpapers)" ]; then
    FIRST_WALLPAPER=$(find "$HOME/wallpapers" -type f \( -iname "*.jpg" -o -iname "*.png" \) | head -n 1)
    
    if [ -n "$FIRST_WALLPAPER" ]; then
        echo "Generating color scheme from wallpaper..."
        wal -q -n -i "$FIRST_WALLPAPER"
        
        # Convert colors for Hyprland
        if [ -f "$DOTFILES_DIR/scripts/convert-pywal-colors.sh" ]; then
            chmod +x "$DOTFILES_DIR/scripts/convert-pywal-colors.sh"
            "$DOTFILES_DIR/scripts/convert-pywal-colors.sh"
        fi
        
        # Set initial wallpaper
        cat > "$HOME/.config/hypr/hyprpaper.conf" << EOF
ipc = on
preload = $FIRST_WALLPAPER
wallpaper = $PRIMARY_MONITOR,$FIRST_WALLPAPER
EOF
        
        echo "$FIRST_WALLPAPER" > "$HOME/.config/hypr/current_wallpaper"
        echo "Color scheme initialized"
    else
        echo "No wallpapers found, creating default colors..."
        "$DOTFILES_DIR/scripts/convert-pywal-colors.sh"
    fi
else
    echo "No wallpapers directory, creating default colors..."
    "$DOTFILES_DIR/scripts/convert-pywal-colors.sh"
fi

# Step 5: Reload Hyprland config
echo ""
echo -e "${GREEN}Step 5: Reloading Hyprland configuration${NC}"
hyprctl reload

# Step 6: Restart waybar
echo ""
echo -e "${GREEN}Step 6: Restarting waybar${NC}"
pkill waybar 2>/dev/null || true
sleep 0.5
nohup waybar >/dev/null 2>&1 &

# Step 7: Start hyprpaper
if [ -f "$HOME/.config/hypr/current_wallpaper" ]; then
    echo ""
    echo -e "${GREEN}Step 7: Starting hyprpaper${NC}"
    pkill hyprpaper 2>/dev/null || true
    sleep 0.5
    nohup hyprpaper >/dev/null 2>&1 &
fi

# Mark setup as complete
touch "$HOME/.config/hypr/.setup_complete"

echo ""
echo -e "${GREEN}Setup complete.${NC}"
echo ""
echo "Configuration:"
echo "  Monitor: $PRIMARY_MONITOR"
echo "  Resolution: ${RESOLUTION}@${REFRESH_RATE}Hz"
echo "  Colors: $([ -f ~/.cache/wal/colors-hyprland.conf ] && echo 'Configured' || echo 'Default')"
echo ""
echo "Keybindings:"
echo "  SUPER+SHIFT+W - Change wallpaper"
echo "  SUPER+Q - Launch applications"
echo "  SUPER+ENTER - Open terminal"
echo ""
read -p "Press Enter to close this window..."
echo -e "${GREEN}╚════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}Configuration Summary:${NC}"
echo -e "  Monitor: $PRIMARY_MONITOR"
echo -e "  Resolution: ${RESOLUTION}@${REFRESH_RATE}Hz"
echo -e "  Colors: $([ -f ~/.cache/wal/colors-hyprland.conf ] && echo 'Configured' || echo 'Default')"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "  • Press SUPER+SHIFT+W to change wallpaper"
echo "  • Press SUPER+Q to launch applications"
echo "  • Press SUPER+ENTER to open terminal"
echo ""
echo "Enjoy your Hyprland setup! 🚀"
