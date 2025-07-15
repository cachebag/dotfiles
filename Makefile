# Makefile for dotfiles management

.PHONY: install backup update clean test help

# Default target
help:
	@echo "Cachebag's Dotfiles Management"
	@echo ""
	@echo "Available targets:"
	@echo "  install  - Install dotfiles and dependencies"
	@echo "  backup   - Backup current configurations"
	@echo "  update   - Update dotfiles and packages"
	@echo "  clean    - Clean up old backups and cache"
	@echo "  test     - Test installation script"
	@echo "  help     - Show this help message"

install:
	@chmod +x install.sh
	@./install.sh

backup:
	@chmod +x scripts/backup.sh
	@./scripts/backup.sh

update:
	@chmod +x scripts/update.sh
	@./scripts/update.sh

clean:
	@chmod +x scripts/clean.sh
	@./scripts/clean.sh

test:
	@echo "Testing installation script syntax..."
	@bash -n install.sh
	@echo "Testing file structure..."
	@test -d nvim || (echo "nvim directory missing" && exit 1)
	@test -f nvim/init.lua || (echo "nvim/init.lua missing" && exit 1)
	@echo "All tests passed!"

# Install development tools
dev-setup:
	@echo "Setting up development environment..."
	@sudo pacman -S --needed shellcheck
	@echo "Development setup complete!"
