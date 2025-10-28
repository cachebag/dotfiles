#!/bin/bash

# Purge script - Remove all dotfiles and restore system to defaults

set -e

RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m'

echo -e "${RED}DOTFILES PURGE - WARNING${NC}"
echo ""
echo -e "${YELLOW}This will remove all dotfiles configurations and symlinks.${NC}"
echo "Your system will be restored to default state."
echo ""
echo "The following will be removed:"
echo "  • ~/.config/hypr"
echo "  • ~/.config/waybar"
echo "  • ~/.config/rofi"
echo "  • ~/.config/nvim"
echo "  • ~/.config/kitty"
echo "  • ~/.config/dunst"
echo "  • ~/.config/yazi"
echo "  • ~/.config/fastfetch"
echo "  • ~/.zshrc"
echo "  • ~/.local/share/applications (symlink)"
echo "  • ~/.cache/wal"
echo "  • ~/wallpapers (if empty)"
echo ""
read -p "Type 'PURGE' to confirm: " confirm

if [ "$confirm" != "PURGE" ]; then
    echo "Cancelled."
    exit 0
fi

echo ""
read -p "Type 'YES' to proceed: " final_confirm

if [ "$final_confirm" != "YES" ]; then
    echo "Cancelled."
    exit 0
fi

echo ""
echo "Starting purge..."

safe_remove() {
    local path=$1
    if [ -L "$path" ]; then
        echo "  Removing symlink: $path"
        rm "$path"
    elif [ -d "$path" ]; then
        echo "  Removing directory: $path"
        rm -rf "$path"
    elif [ -f "$path" ]; then
        echo "  Removing file: $path"
        rm "$path"
    fi
}

echo ""
echo "Removing configuration directories..."
safe_remove "$HOME/.config/hypr"
safe_remove "$HOME/.config/waybar"
safe_remove "$HOME/.config/rofi"
safe_remove "$HOME/.config/nvim"
safe_remove "$HOME/.config/kitty"
safe_remove "$HOME/.config/dunst"
safe_remove "$HOME/.config/yazi"
safe_remove "$HOME/.config/fastfetch"

echo ""
echo "Removing shell configurations..."
safe_remove "$HOME/.zshrc"
safe_remove "$HOME/.zsh_history"

echo ""
echo "Removing applications symlink..."
safe_remove "$HOME/.local/share/applications"

echo ""
echo "Removing pywal cache..."
safe_remove "$HOME/.cache/wal"

echo ""
if [ -d "$HOME/wallpapers" ]; then
    if [ -d "$HOME/wallpapers/.git" ]; then
        read -p "Remove wallpapers git repository? (y/n): " remove_wallpapers
        if [ "$remove_wallpapers" = "y" ] || [ "$remove_wallpapers" = "Y" ]; then
            echo "Removing wallpapers repository..."
            rm -rf "$HOME/wallpapers"
        else
            echo "Keeping wallpapers repository."
        fi
    elif [ -z "$(ls -A $HOME/wallpapers)" ]; then
        echo "Removing empty wallpapers directory..."
        rmdir "$HOME/wallpapers"
    else
        echo "Wallpapers directory not empty, skipping."
    fi
fi

if [ -d "$HOME/Pictures/screenshots" ]; then
    if [ -z "$(ls -A $HOME/Pictures/screenshots)" ]; then
        echo "Removing empty screenshots directory..."
        rmdir "$HOME/Pictures/screenshots"
    else
        echo "Screenshots directory not empty, skipping."
    fi
fi

echo ""
read -p "Restore default shell to bash? (y/n): " restore_shell
if [ "$restore_shell" = "y" ] || [ "$restore_shell" = "Y" ]; then
    echo "Restoring default shell..."
    chsh -s /bin/bash
fi

echo ""
read -p "Disable Hyprland-related services? (y/n): " disable_services
if [ "$disable_services" = "y" ] || [ "$disable_services" = "Y" ]; then
    echo "Disabling services..."
    sudo systemctl disable sddm 2>/dev/null || true
fi

echo ""
echo -e "${GREEN}Purge complete.${NC}"
echo "System restored to defaults."
echo "To reinstall: make install"
echo -e "${GREEN}║  Purge complete!                      ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}System has been restored to defaults.${NC}"
echo -e "${YELLOW}You may want to reboot your system.${NC}"
echo ""
echo "To reinstall dotfiles, run: make install"
