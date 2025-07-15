#!/bin/bash

# Backup script for dotfiles
# Creates a timestamped backup of current configurations

set -e

BACKUP_DIR="$HOME/.config/dotfiles_backup_$(date +%Y%m%d_%H%M%S)"
CONFIGS=("hypr" "waybar" "rofi" "nvim")

echo "Creating backup at: $BACKUP_DIR"
mkdir -p "$BACKUP_DIR"

for config in "${CONFIGS[@]}"; do
    if [[ -d "$HOME/.config/$config" ]]; then
        echo "Backing up $config..."
        cp -r "$HOME/.config/$config" "$BACKUP_DIR/"
    fi
done

echo "Backup completed: $BACKUP_DIR"
