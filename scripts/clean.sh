#!/bin/bash

# Clean script for dotfiles
# Removes old backups and cleans up temporary files

set -e

echo "Cleaning up dotfiles..."

# Remove old backups (older than 30 days)
find "$HOME/.config" -name "dotfiles_backup_*" -type d -mtime +30 -exec rm -rf {} + 2>/dev/null || true

# Clean Neovim cache
if [[ -d "$HOME/.local/share/nvim" ]]; then
    echo "Cleaning Neovim cache..."
    rm -rf "$HOME/.local/share/nvim/swap/"*
    rm -rf "$HOME/.local/share/nvim/shada/"*
fi

# Clean package cache
echo "Cleaning package cache..."
sudo pacman -Sc --noconfirm
yay -Sc --noconfirm

echo "Cleanup completed!"
