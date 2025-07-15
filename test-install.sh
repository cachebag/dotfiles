#!/bin/bash

# Test version of install script - DRY RUN MODE
# Shows what would be done without actually doing it

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

DRY_RUN=true

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_dry_run() {
    echo -e "${PURPLE}[DRY RUN]${NC} Would execute: $1"
}

# Test package installation
test_install_dependencies() {
    log_info "Testing dependency installation..."
    
    local pacman_packages=(
        "hyprland" "waybar" "rofi-wayland" "neovim" "git" "curl" "wget"
        "ripgrep" "fd" "nodejs" "npm" "python" "python-pip" "python-virtualenv"
        "ttf-fira-code" "ttf-font-awesome" "wl-clipboard" "kitty" "dunst" "yazi"
    )
    
    echo "Checking installed packages:"
    for pkg in "${pacman_packages[@]}"; do
        if pacman -Qi "$pkg" &>/dev/null; then
            log_success "✓ $pkg (already installed)"
        else
            log_warning "✗ $pkg (would be installed)"
        fi
    done
    
    log_dry_run "sudo pacman -S --needed --noconfirm [packages]"
    log_dry_run "yay -S --needed --noconfirm hyprpaper swaylock-effects wlogout hypridle"
}

# Test directory creation
test_create_directories() {
    log_info "Testing directory creation..."
    
    local dirs=(
        "$HOME/.config" "$HOME/.config/hypr" "$HOME/.config/waybar"
        "$HOME/.config/rofi" "$HOME/.config/nvim" "$HOME/.local/share/applications"
        "$HOME/.local/bin" "$HOME/wallpapers"
    )
    
    for dir in "${dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            log_success "✓ $dir (exists)"
        else
            log_warning "✗ $dir (would be created)"
            log_dry_run "mkdir -p $dir"
        fi
    done
}

# Test backup process
test_backup_configs() {
    log_info "Testing backup process..."
    
    local backup_dir="$HOME/.config/dotfiles_backup_test_$(date +%Y%m%d_%H%M%S)"
    local configs=("hypr" "waybar" "rofi" "nvim")
    
    log_dry_run "mkdir -p $backup_dir"
    
    for config in "${configs[@]}"; do
        if [[ -d "$HOME/.config/$config" ]] && [[ ! -L "$HOME/.config/$config" ]]; then
            log_warning "Would backup existing $config configuration (directory)"
            log_dry_run "mv $HOME/.config/$config $backup_dir/"
        elif [[ -L "$HOME/.config/$config" ]]; then
            log_info "$config is already a symlink (would remove and recreate)"
            log_dry_run "rm -rf $HOME/.config/$config"
        else
            log_info "No existing $config configuration found"
        fi
    done
}

# Test symlink creation - FIXED to use correct directory names
test_create_symlinks() {
    log_info "Testing symlink creation..."
    
    local dotfiles_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    
    # Updated to match your actual directory structure
    local configs=(
        "hyprland:$HOME/.config/hypr"
        "waybar:$HOME/.config/waybar"
        "rofi:$HOME/.config/rofi"
        "nvim:$HOME/.config/nvim"
    )
    
    for config in "${configs[@]}"; do
        local src="${config%%:*}"
        local dest="${config##*:}"
        
        if [[ -d "$dotfiles_dir/$src" ]]; then
            log_success "✓ Source exists: $dotfiles_dir/$src"
            if [[ -L "$dest" ]]; then
                local current_target=$(readlink "$dest")
                log_info "Current symlink: $dest -> $current_target"
            elif [[ -d "$dest" ]]; then
                log_warning "Directory exists (would backup): $dest"
            fi
            log_dry_run "ln -sf $dotfiles_dir/$src $dest"
        else
            log_error "✗ Source missing: $dotfiles_dir/$src"
        fi
    done
}

# Test Python environment
test_neovim_python() {
    log_info "Testing Neovim Python environment..."
    
    local nvim_env_dir="$HOME/.config/nvim/env"
    
    if [[ -d "$nvim_env_dir" ]]; then
        log_success "✓ Python venv exists: $nvim_env_dir"
        if [[ -f "$nvim_env_dir/bin/python3" ]]; then
            local python_version=$("$nvim_env_dir/bin/python3" --version 2>/dev/null || echo "Unable to get version")
            log_info "Python version: $python_version"
        fi
        if [[ -f "$nvim_env_dir/bin/pip" ]]; then
            local pynvim_installed=$("$nvim_env_dir/bin/pip" list | grep pynvim || echo "not installed")
            log_info "pynvim status: $pynvim_installed"
        fi
    else
        log_warning "✗ Python venv missing (would be created)"
        log_dry_run "python -m venv $nvim_env_dir"
    fi
    
    log_dry_run "pip install --upgrade pip pynvim"
}

# Test file structure
test_file_structure() {
    log_info "Testing dotfiles file structure..."
    
    local dotfiles_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local required_files=(
        "nvim/init.lua"
        "nvim/lua/cachebag/plugins"
        "hyprland/hyprland.conf"
        "waybar"
        "rofi"
        "README.md"
        "install.sh"
    )
    
    for file in "${required_files[@]}"; do
        if [[ -e "$dotfiles_dir/$file" ]]; then
            log_success "✓ $file"
        else
            log_error "✗ Missing: $file"
        fi
    done
}

# Test wallpapers setup
test_wallpapers() {
    log_info "Testing wallpapers setup..."
    
    if [[ -d "$HOME/wallpapers" ]]; then
        local count=$(ls -1 "$HOME/wallpapers" 2>/dev/null | wc -l)
        log_success "✓ Wallpapers directory exists ($count files)"
    else
        log_warning "✗ Wallpapers directory missing (would be created)"
        log_dry_run "mkdir -p $HOME/wallpapers"
        log_dry_run "wget sample wallpaper"
    fi
}

# Main test function
main() {
    echo -e "${BLUE}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║              Dotfiles Installation Test (DRY RUN)           ║"
    echo "║                                                              ║"
    echo "║  This will test the installation without making changes     ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    test_file_structure
    echo
    test_install_dependencies
    echo
    test_create_directories
    echo
    test_backup_configs
    echo
    test_create_symlinks
    echo
    test_neovim_python
    echo
    test_wallpapers
    
    echo -e "${GREEN}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                      Test Complete!                         ║"
    echo "║                                                              ║"
    echo "║  The script now correctly maps:                             ║"
    echo "║  • hyprland/ -> ~/.config/hypr/                             ║"
    echo "║  • waybar/ -> ~/.config/waybar/                             ║"
    echo "║  • rofi/ -> ~/.config/rofi/                                 ║"
    echo "║  • nvim/ -> ~/.config/nvim/                                 ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

main "$@"
