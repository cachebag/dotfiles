# Makefile for dotfiles management

.PHONY: install backup update clean test help deps check-deps verify dev-setup lint purge post-setup

# Default target
help:
	@echo "╔══════════════════════════════════════╗"
	@echo "║     Cachebag's Dotfiles Management   ║"
	@echo "╚══════════════════════════════════════╝"
	@echo ""
	@echo "Available targets:"
	@echo "  install     - Full dotfiles installation"
	@echo "  post-setup  - Configure monitor after first boot"
	@echo "  deps        - Install only dependencies"
	@echo "  check-deps  - Check if dependencies are installed"
	@echo "  backup      - Backup current configurations"
	@echo "  update      - Update dotfiles and packages"
	@echo "  clean       - Clean up old backups and cache"
	@echo "  verify      - Verify installation integrity"
	@echo "  test        - Test installation script"
	@echo "  lint        - Lint shell scripts"
	@echo "  dev-setup   - Setup development environment"
	@echo "  purge       - Remove ALL dotfiles (DANGER!)"
	@echo "  help        - Show this help message"

# Full installation
install:
	@echo "Starting full dotfiles installation..."
	@chmod +x install.sh
	@./install.sh

# Install only dependencies (useful for CI/testing)
deps:
	@echo "Installing dependencies only..."
	@chmod +x install.sh
	@DEPS_ONLY=true ./install.sh

# Check if dependencies are installed
check-deps:
	@echo "Checking dependencies..."
	@command -v hyprland >/dev/null 2>&1 || (echo "[INFO] Hyprland not installed" && exit 1)
	@command -v waybar >/dev/null 2>&1 || (echo "[INFO] Waybar not installed" && exit 1)
	@command -v rofi >/dev/null 2>&1 || (echo "[INFO] Rofi not installed" && exit 1)
	@command -v kitty >/dev/null 2>&1 || (echo "[INFO] Kitty not installed" && exit 1)
	@command -v nvim >/dev/null 2>&1 || (echo "[INFO] Neovim not installed" && exit 1)
	@command -v git >/dev/null 2>&1 || (echo "[INFO] Git not installed" && exit 1)
	@echo "[SUCCESS] Core dependencies installed"

# Backup configurations
backup:
	@echo "Backing up configurations..."
	@chmod +x scripts/backup.sh
	@./scripts/backup.sh

# Update system and dotfiles
update:
	@echo "Updating dotfiles and system..."
	@chmod +x scripts/update.sh
	@./scripts/update.sh

# Clean up old files
clean:
	@echo "Cleaning up old backups and cache..."
	@chmod +x scripts/clean.sh
	@./scripts/clean.sh

# Verify installation
verify:
	@echo "Verifying installation..."
	@test -L ~/.config/hypr || (echo "[INFO] Hyprland config not symlinked" && exit 1)
	@test -L ~/.config/waybar || (echo "[INFO] Waybar config not symlinked" && exit 1)
	@test -L ~/.config/nvim || (echo "[INFO] Neovim config not symlinked" && exit 1)
	@test -L ~/.config/kitty || (echo "[INFO] Kitty config not symlinked" && exit 1)
	@test -L ~/.zshrc || (echo "[INFO] Zshrc not symlinked" && exit 1)
	@test -L ~/.local/share/applications || (echo "[INFO] Applications not symlinked" && exit 1)
	@test -d ~/wallpapers || (echo "[INFO] Wallpapers directory missing" && exit 1)
	@test -d ~/.cache/wal || (echo "[INFO] Pywal cache directory missing" && exit 1)
	@test -f ~/.cache/wal/colors-hyprland.conf || (echo "[WARNING] Pywal colors not converted, run: ./scripts/convert-pywal-colors.sh")
	@echo "[SUCCESS] Installation verified"

# Test installation script
test:
	@echo "Testing installation script..."
	@bash -n install.sh || (echo "[ERROR] Syntax error in install.sh" && exit 1)
	@echo "Testing file structure..."
	@test -d hyprland || (echo "[INFO] hyprland directory missing" && exit 1)
	@test -d waybar || (echo "[INFO] waybar directory missing" && exit 1)
	@test -d nvim || (echo "[INFO] nvim directory missing" && exit 1)
	@test -d kitty || (echo "[INFO] kitty directory missing" && exit 1)
	@test -d rofi || (echo "[INFO] rofi directory missing" && exit 1)
	@test -f nvim/init.lua || (echo "[INFO] nvim/init.lua missing" && exit 1)
	@test -f dependencies.yml || (echo "[INFO] dependencies.yml missing" && exit 1)
	@echo "[SUCCESS] All tests passed!"

# Lint shell scripts
lint:
	@echo "Linting shell scripts..."
	@command -v shellcheck >/dev/null 2>&1 || (echo "Installing shellcheck..." && sudo pacman -S --needed shellcheck)
	@shellcheck install.sh || echo "[WARNING] Shellcheck warnings in install.sh"
	@find scripts -name "*.sh" -exec shellcheck {} \; || echo "[WARNING] Shellcheck warnings in scripts"
	@echo "[SUCCESS] Linting complete"

# Setup development environment
dev-setup:
	@echo "Setting up development environment..."
	@sudo pacman -S --needed shellcheck yamllint
	@echo "[SUCCESS] Development setup complete!"

# Quick status check
status:
	@echo "[INFO] Dotfiles Status:"
	@echo "==================="
	@echo -n "Shell: "; echo $$SHELL
	@echo -n "Hyprland: "; command -v hyprland >/dev/null && echo "[SUCCESS]" || echo "[ERROR]"
	@echo -n "Waybar: "; command -v waybar >/dev/null && echo "[SUCCESS]" || echo "[ERROR]"
	@echo -n "Neovim: "; command -v nvim >/dev/null && echo "[SUCCESS]" || echo "[ERROR]"
	@echo -n "Configs symlinked: "; test -L ~/.config/hypr && echo "[SUCCESS]" || echo "[ERROR]"

purge:
	@echo "⚠️  WARNING: This will remove ALL dotfiles!"
	@chmod +x scripts/purge.sh
	@./scripts/purge.sh

# Post-install setup - run after first boot
post-setup:
	@echo "Starting post-install setup..."
	@chmod +x scripts/post-install-setup.sh
	@./scripts/post-install-setup.sh
