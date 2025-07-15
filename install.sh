#!/bin/bash

# Automated setup for Hyprland + Neovim configuration

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# Check if running on Arch Linux
check_arch() {
    if [[ ! -f /etc/arch-release ]]; then
        log_error "This script is designed for Arch Linux systems"
        exit 1
    fi
}

# Check if user is not root
check_user() {
    if [[ $EUID -eq 0 ]]; then
        log_error "This script should not be run as root"
        exit 1
    fi
}

# Install packages using pacman and yay
install_dependencies() {
    log_info "Installing system dependencies..."
    
    # Core packages
    local pacman_packages=(
        "hyprland"
        "waybar"
        "rofi-wayland"
        "neovim"
        "git"
        "curl"
        "wget"
        "ripgrep"
        "fd"
        "nodejs"
        "npm"
        "python"
        "python-pip"
        "python-virtualenv"
        "ttf-fira-code"
        "ttf-font-awesome"
        "wl-clipboard"
        "xdg-desktop-portal-hyprland"
        "qt5-wayland"
        "qt6-wayland"
        "kitty"
        "dunst"
        "yazi"
    )
    
    log_info "Installing packages with pacman..."
    sudo pacman -S --needed --noconfirm "${pacman_packages[@]}"
    
    # Check if yay is installed
    if ! command -v yay &> /dev/null; then
        log_info "Installing yay AUR helper..."
        cd /tmp
        git clone https://aur.archlinux.org/yay.git
        cd yay
        makepkg -si --noconfirm
        cd -
    fi
    
    # AUR packages
    local aur_packages=(
        "hyprpaper"
        "swaylock-effects"
        "wlogout"
        "hypridle"
    )
    
    log_info "Installing AUR packages with yay..."
    yay -S --needed --noconfirm "${aur_packages[@]}"
    
    log_success "System dependencies installed successfully"
}

# Create necessary directories
create_directories() {
    log_info "Creating configuration directories..."
    
    local dirs=(
        "$HOME/.config"
        "$HOME/.config/hypr"
        "$HOME/.config/waybar"
        "$HOME/.config/rofi"
        "$HOME/.config/nvim"
        "$HOME/.local/share/applications"
        "$HOME/.local/bin"
        "$HOME/wallpapers"
    )
    
    for dir in "${dirs[@]}"; do
        mkdir -p "$dir"
        log_info "Created directory: $dir"
    done
    
    log_success "Directories created successfully"
}

# Backup existing configurations
backup_configs() {
    log_info "Backing up existing configurations..."
    
    local backup_dir="$HOME/.config/dotfiles_backup_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$backup_dir"
    
    local configs=("hypr" "waybar" "rofi" "nvim")
    
    for config in "${configs[@]}"; do
        if [[ -d "$HOME/.config/$config" ]] && [[ ! -L "$HOME/.config/$config" ]]; then
            log_warning "Backing up existing $config configuration"
            mv "$HOME/.config/$config" "$backup_dir/"
        fi
    done
    
    if [[ -n "$(ls -A "$backup_dir" 2>/dev/null)" ]]; then
        log_success "Existing configurations backed up to: $backup_dir"
    else
        rmdir "$backup_dir"
        log_info "No existing configurations found to backup"
    fi
}

# Create symlinks
create_symlinks() {
    log_info "Creating symbolic links..."
    
    local dotfiles_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    
    # Configuration symlinks - using your actual directory structure
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
            # Remove existing symlink or directory
            if [[ -L "$dest" ]] || [[ -d "$dest" ]]; then
                rm -rf "$dest"
            fi
            ln -sf "$dotfiles_dir/$src" "$dest"
            log_success "Linked $src -> $dest"
        else
            log_warning "Source directory $dotfiles_dir/$src not found"
        fi
    done
}

# Setup Neovim Python environment
setup_neovim_python() {
    log_info "Setting up Neovim Python environment..."
    
    local nvim_env_dir="$HOME/.config/nvim/env"
    
    if [[ ! -d "$nvim_env_dir" ]]; then
        python -m venv "$nvim_env_dir"
        log_success "Created Python virtual environment for Neovim"
    fi
    
    # Activate and install packages
    source "$nvim_env_dir/bin/activate"
    pip install --upgrade pip
    pip install pynvim
    deactivate
    
    log_success "Neovim Python environment configured"
}

# Install Node.js dependencies for Neovim plugins
setup_node_dependencies() {
    log_info "Installing Node.js dependencies for Neovim plugins..."
    
    # Global packages needed by some plugins
    npm install -g neovim
    
    log_success "Node.js dependencies installed"
}

# Setup Lazy.nvim and install plugins
setup_neovim_plugins() {
    log_info "Setting up Neovim plugins..."
    
    # Lazy.nvim will be installed automatically when Neovim starts
    # We'll just create a script to install plugins headlessly
    nvim --headless "+Lazy! sync" +qa
    
    log_success "Neovim plugins installed"
}

# Set up fonts
setup_fonts() {
    log_info "Setting up fonts..."
    
    local font_dir="$HOME/.local/share/fonts"
    mkdir -p "$font_dir"
    
    # Download and install Nerd Fonts if not already installed
    if [[ ! -f "$font_dir/FiraCodeNerdFont-Regular.ttf" ]]; then
        log_info "Downloading FiraCode Nerd Font..."
        cd /tmp
        wget https://github.com/ryanoasis/nerd-fonts/releases/download/v3.0.2/FiraCode.zip
        unzip -o FiraCode.zip -d "$font_dir"
        rm FiraCode.zip
        fc-cache -fv
        log_success "FiraCode Nerd Font installed"
    fi
}

# Setup wallpapers directory with sample
setup_wallpapers() {
    log_info "Setting up wallpapers..."
    
    # Create wallpapers directory if it doesn't exist
    mkdir -p "$HOME/wallpapers"
    
    # Download a sample wallpaper if directory is empty
    if [[ -z "$(ls -A "$HOME/wallpapers" 2>/dev/null)" ]]; then
        log_info "Downloading sample wallpaper..."
        cd "$HOME/wallpapers"
        wget -O sample-wallpaper.jpg "https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=2560&h=1440&fit=crop"
        log_success "Sample wallpaper downloaded"
    fi
}

# Post-installation steps
post_install() {
    log_info "Running post-installation steps..."
    
    # Add user to necessary groups
    sudo usermod -aG video,input "$USER"
    
    # Make scripts executable
    local dotfiles_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    if [[ -d "$dotfiles_dir/hyprland/scripts" ]]; then
        chmod +x "$dotfiles_dir/hyprland/scripts/"*.sh
        log_success "Made Hyprland scripts executable"
    fi
    
    # Update hyprpaper config with correct user path
    if [[ -f "$HOME/.config/hypr/hyprpaper.conf" ]]; then
        sed -i "s|/home/cachebag|$HOME|g" "$HOME/.config/hypr/hyprpaper.conf"
        log_success "Updated hyprpaper config paths"
    fi
    
    log_success "Post-installation steps completed"
}

# Main installation function
main() {
    echo -e "${BLUE}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                 Cachebag's Dotfiles Installer               ║"
    echo "║                                                              ║"
    echo "║  This will install and configure:                           ║"
    echo "║  • Hyprland (Wayland compositor)                            ║"
    echo "║  • Waybar (Status bar)                                      ║"
    echo "║  • Rofi (Application launcher)                              ║"
    echo "║  • Neovim (Text editor with plugins)                       ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    read -p "Do you want to continue? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Installation cancelled"
        exit 0
    fi
    
    # Run installation steps
    check_arch
    check_user
    install_dependencies
    create_directories
    backup_configs
    create_symlinks
    setup_neovim_python
    setup_node_dependencies
    setup_fonts
    setup_wallpapers
    setup_neovim_plugins
    post_install
    
    echo -e "${GREEN}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                    Installation Complete!                   ║"
    echo "║                                                              ║"
    echo "║  Next steps:                                                 ║"
    echo "║  1. Log out and log back in                                  ║"
    echo "║  2. Select Hyprland as your session                         ║"
    echo "║  3. Enjoy your new setup!                                   ║"
    echo "║                                                              ║"
    echo "║  For issues: https://github.com/cachebag/dotfiles/issues    ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# Run main function
main "$@"
