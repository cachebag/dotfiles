#!/bin/bash

# Update script for dotfiles
# Pulls latest changes and updates symlinks

set -e

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "Updating dotfiles..."
cd "$DOTFILES_DIR"

# Pull latest changes
git pull origin main

# Update Neovim plugins
echo "Updating Neovim plugins..."
nvim --headless "+Lazy! sync" +qa

# Update system packages
echo "Updating system packages..."
sudo pacman -Syu --noconfirm
yay -Syu --noconfirm

echo "Update completed!"
