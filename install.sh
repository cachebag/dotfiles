#!/bin/bash
# Cachebag's Dotfiles Installation Script

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $1"; }

DOTFILES_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE_FILE="$HOME/.dotfiles_install_state"

save_state() {
    echo "$1" > "$STATE_FILE"
}

get_state() {
    [[ -f "$STATE_FILE" ]] && cat "$STATE_FILE" || echo "start"
}

check_arch() {
    if [[ ! -f /etc/arch-release ]]; then
        log_error "This script requires Arch Linux"
        exit 1
    fi
}

check_user() {
    if [[ $EUID -eq 0 ]]; then
        log_error "Do not run this script as root"
        exit 1
    fi
}

cleanup_on_error() {
    log_error "Installation failed. State saved. Run script again to continue."
    exit 1
}

trap cleanup_on_error ERR

install_dependencies() {
    log_info "Installing system dependencies..."
    local pacman_pkgs=(
        hyprland waybar rofi-wayland dunst kitty neovim
        git curl wget ripgrep fd fzf fastfetch yazi
        nodejs npm python python-pip python-virtualenv python-pynvim
        python-pywal jq
        ttf-fira-code ttf-font-awesome ttf-jetbrains-mono-nerd
        wl-clipboard grim slurp swappy
        xdg-desktop-portal-hyprland qt5-wayland qt6-wayland
        pipewire pipewire-alsa pipewire-pulse pavucontrol
        polkit-gnome brightnessctl playerctl
        zsh zsh-autosuggestions zsh-syntax-highlighting
        sddm qt5-graphicaleffects qt5-quickcontrols2
        network-manager-applet bluez bluez-utils
        thunar thunar-archive-plugin file-roller
        firefox dolphin wofi obsidian
        base-devel cmake make gcc unzip
    )
    
    sudo pacman -Syu --needed --noconfirm "${pacman_pkgs[@]}"

    if ! command -v yay &>/dev/null; then
        log_info "Installing yay AUR helper..."
        cd /tmp
        git clone https://aur.archlinux.org/yay.git
        cd yay && makepkg -si --noconfirm
        cd "$DOTFILES_ROOT"
    fi

    local aur_pkgs=(hyprpaper swaylock-effects wlogout hypridle hyprshot)
    yay -S --needed --noconfirm "${aur_pkgs[@]}"
    
    log_success "Dependencies installed"
    save_state "dependencies_done"
}

create_directories() {
    log_info "Creating config directories..."
    local dirs=(
        "$HOME/.config/hypr" "$HOME/.config/waybar" "$HOME/.config/rofi"
        "$HOME/.config/nvim" "$HOME/.config/kitty" "$HOME/.config/dunst"
        "$HOME/.config/yazi" "$HOME/.config/fastfetch" "$HOME/.config/sddm"
        "$HOME/.local/share/applications" "$HOME/.local/bin" "$HOME/.local/share/fonts"
        "$HOME/Pictures/screenshots" "$HOME/.cache/wal"
    )
    for d in "${dirs[@]}"; do 
        mkdir -p "$d"
    done
    log_success "Directories created"
    save_state "directories_done"
}

backup_configs() {
    log_info "Backing up existing configurations..."
    local backup_dir="$HOME/.config/dotfiles_backup_$(date +%Y%m%d_%H%M%S)"
    local configs=(hypr waybar rofi nvim kitty dunst yazi fastfetch)
    local backup_needed=false
    
    for config in "${configs[@]}"; do
        local config_path="$HOME/.config/$config"
        if [[ -d "$config_path" && ! -L "$config_path" ]]; then
            [[ "$backup_needed" == false ]] && mkdir -p "$backup_dir"
            mv "$config_path" "$backup_dir/"
            log_warning "Backed up $config to $backup_dir"
            backup_needed=true
        fi
    done
    
    for file in .zshrc .zsh_history; do
        if [[ -f "$HOME/$file" && ! -L "$HOME/$file" ]]; then
            [[ "$backup_needed" == false ]] && mkdir -p "$backup_dir"
            cp "$HOME/$file" "$backup_dir/"
            backup_needed=true
        fi
    done
    
    [[ "$backup_needed" == false ]] && [[ -d "$backup_dir" ]] && rmdir "$backup_dir"
    log_success "Backup completed"
    save_state "backup_done"
}

# --- Symlinks -----------------------------------------------------------

create_symlinks() {
    log_info "Creating symlinks..."

    local core_configs=(
        "hyprland:$HOME/.config/hypr"
        "waybar:$HOME/.config/waybar" 
        "nvim:$HOME/.config/nvim"
        "kitty:$HOME/.config/kitty"
        "rofi:$HOME/.config/rofi"
    )

    for mapping in "${core_configs[@]}"; do
        local src="${mapping%:*}"
        local dst="${mapping#*:}"
        if [[ -d "$DOTFILES_ROOT/$src" ]]; then
            [[ -e "$dst" ]] && rm -rf "$dst"
            ln -sf "$DOTFILES_ROOT/$src" "$dst"
            log_info "Linked $src → $dst"
        fi
    done

    local optional_configs=(
        "dunst:$HOME/.config/dunst"
        "yazi:$HOME/.config/yazi"
        "fastfetch:$HOME/.config/fastfetch"
    )

    for mapping in "${optional_configs[@]}"; do
        local src="${mapping%:*}"
        local dst="${mapping#*:}"
        if [[ -d "$DOTFILES_ROOT/$src" ]]; then
            [[ -e "$dst" ]] && rm -rf "$dst"
            ln -sf "$DOTFILES_ROOT/$src" "$dst"
            log_info "Linked $src → $dst"
        fi
    done

    if [[ -f "$DOTFILES_ROOT/zsh/zshrc" ]]; then
        [[ -f "$HOME/.zshrc" && ! -L "$HOME/.zshrc" ]] && rm -f "$HOME/.zshrc"
        ln -sf "$DOTFILES_ROOT/zsh/zshrc" "$HOME/.zshrc"
        log_info "Linked zshrc"
    fi

    if [[ -f "$DOTFILES_ROOT/zsh/zsh_history" ]]; then
        [[ -f "$HOME/.zsh_history" && ! -L "$HOME/.zsh_history" ]] && rm -f "$HOME/.zsh_history"
        ln -sf "$DOTFILES_ROOT/zsh/zsh_history" "$HOME/.zsh_history"
        log_info "Linked zsh_history"
    fi

    if [[ -d "$DOTFILES_ROOT/scripts" ]]; then
        chmod +x "$DOTFILES_ROOT/scripts/"*.sh
        for script in "$DOTFILES_ROOT/scripts/"*.sh; do
            local script_name=$(basename "$script")
            ln -sf "$script" "$HOME/.local/bin/${script_name%.sh}"
        done
        log_info "Linked utility scripts to ~/.local/bin"
    fi

    if [[ -d "$DOTFILES_ROOT/applications" ]]; then
        ln -sfn "$DOTFILES_ROOT/applications"/* "$HOME/.local/share/applications/"
        log_info "Linked .desktop applications"
    fi

    log_success "Symlinks created"
    save_state "symlinks_done"
}

setup_sddm() {
    log_info "Setting up SDDM theme..."
    if [[ -d "$DOTFILES_ROOT/sddm/themes" ]]; then
        sudo mkdir -p /usr/share/sddm/themes/cachebag-theme
        sudo cp -r "$DOTFILES_ROOT/sddm/themes/"* /usr/share/sddm/themes/cachebag-theme/
        
        if [[ -f "$DOTFILES_ROOT/sddm/conf.d/theme.conf" ]]; then
            sudo mkdir -p /etc/sddm.conf.d/
            sudo cp "$DOTFILES_ROOT/sddm/conf.d/theme.conf" /etc/sddm.conf.d/
        elif [[ -f "$DOTFILES_ROOT/sddm/theme.conf" ]]; then
            sudo mkdir -p /etc/sddm.conf.d/
            sudo cp "$DOTFILES_ROOT/sddm/theme.conf" /etc/sddm.conf.d/
        fi
        
        sudo systemctl enable sddm
        log_success "SDDM theme installed"
    else
        log_warning "SDDM theme directory not found, skipping theme setup"
        sudo systemctl enable sddm
        log_info "SDDM enabled with default theme"
    fi
    save_state "sddm_done"
}

setup_fonts() {
    log_info "Installing fonts..."
    local font_dir="$HOME/.local/share/fonts"
    
    if [[ ! -f "$font_dir/FiraCodeNerdFont-Regular.ttf" ]]; then
        cd /tmp
        wget -q https://github.com/ryanoasis/nerd-fonts/releases/download/v3.0.2/FiraCode.zip
        unzip -q -o FiraCode.zip -d "$font_dir"
        rm -f FiraCode.zip
    fi
    
    if [[ ! -f "$font_dir/JetBrainsMonoNerdFont-Regular.ttf" ]]; then
        cd /tmp
        wget -q https://github.com/ryanoasis/nerd-fonts/releases/download/v3.0.2/JetBrainsMono.zip
        unzip -q -o JetBrainsMono.zip -d "$font_dir"
        rm -f JetBrainsMono.zip
    fi
    
    fc-cache -fv > /dev/null 2>&1
    log_success "Fonts installed"
    save_state "fonts_done"
}

setup_wallpapers() {
    log_info "Setting up wallpapers..."
    
    if [[ ! -d "$HOME/wallpapers" ]]; then
        log_info "Cloning wallpapers repository..."
        git clone https://github.com/cachebag/wallpapers.git "$HOME/wallpapers" || {
            log_warning "Failed to clone wallpapers repo, creating empty directory"
            mkdir -p "$HOME/wallpapers"
        }
    elif [[ -d "$HOME/wallpapers/.git" ]]; then
        log_info "Updating wallpapers repository..."
        cd "$HOME/wallpapers" && git pull --quiet || log_warning "Failed to update wallpapers"
        cd "$DOTFILES_ROOT"
    fi
    
    if [[ -z "$(ls -A "$HOME/wallpapers" 2>/dev/null)" ]]; then
        log_warning "No wallpapers found, downloading sample..."
        cd /tmp
        wget -q -O sample-wallpaper.jpg "https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=2560&h=1440&fit=crop" || \
        wget -q -O sample-wallpaper.jpg "https://picsum.photos/2560/1440" || {
            log_warning "Failed to download sample wallpaper"
        }
        [[ -f sample-wallpaper.jpg ]] && mv sample-wallpaper.jpg "$HOME/wallpapers/"
        cd "$DOTFILES_ROOT"
    fi
    
    log_success "Wallpapers setup complete"
    save_state "wallpapers_done"
}

setup_services() {
    log_info "Enabling system services..."
    sudo systemctl enable bluetooth NetworkManager
    sudo usermod -aG video,input,audio "$USER"
    
    if [[ -d "$DOTFILES_ROOT/hyprland/scripts" ]]; then
        chmod +x "$DOTFILES_ROOT/hyprland/scripts/"*.sh
    fi
    
    log_success "Services configured"
    save_state "services_done"
}

setup_neovim() {
    log_info "Setting up Neovim environment..."
    
    if command -v python &>/dev/null; then
        log_info "Installing Python pynvim..."
        python -m pip install --user --upgrade pynvim > /dev/null 2>&1 || log_warning "Failed to install pynvim"
    fi
    
    if command -v npm &>/dev/null; then
        log_info "Installing Node.js neovim package..."
        sudo npm install -g neovim > /dev/null 2>&1 || log_warning "Failed to install neovim npm package"
    fi
    
    log_info "Installing Neovim plugins..."
    if timeout 30 nvim --headless "+qa" 2>/dev/null; then
        log_info "Neovim starts successfully, proceeding with plugin installation..."
        timeout 120 nvim --headless "+Lazy! sync" +qa 2>/dev/null || {
            log_warning "Plugin install timed out or failed - you can run ':Lazy sync' manually later"
            save_state "neovim_done"
            return 0
        }
    else
        log_warning "Neovim failed to start - skipping plugin installation"
        save_state "neovim_done"
        return 0
    fi
    
    log_info "Rebuilding telescope-nvim and fzf-native..."
    local telescope_dir="$HOME/.local/share/nvim/lazy/telescope.nvim"
    local fzf_dir="$HOME/.local/share/nvim/lazy/telescope-fzf-native.nvim"
    
    if [[ -d "$telescope_dir" ]]; then
        cd "$telescope_dir"
        if [[ -f "Makefile" ]]; then
            make clean > /dev/null 2>&1 || true
            make > /dev/null 2>&1 || log_warning "Failed to rebuild telescope - may need manual rebuild"
            log_info "Telescope rebuilt successfully"
        fi
    else
        log_warning "Telescope directory not found - plugins may need manual installation"
    fi
    
    if [[ -d "$fzf_dir" ]]; then
        cd "$fzf_dir"
        if [[ -f "Makefile" ]]; then
            make clean > /dev/null 2>&1 || true
            make > /dev/null 2>&1 || log_warning "Failed to rebuild fzf-native - may need manual rebuild"
            log_info "FZF-native rebuilt successfully"
        fi
    fi
    
    cd "$DOTFILES_ROOT"
    log_success "Neovim setup completed"
    save_state "neovim_done"
}

setup_zsh() {
    log_info "Configuring Zsh..."
    if [[ "$SHELL" != "/usr/bin/zsh" && "$SHELL" != "/bin/zsh" ]]; then
        log_info "Changing default shell to Zsh..."
        chsh -s /usr/bin/zsh
        log_warning "Shell changed - logout/login required for full effect"
    fi
    save_state "zsh_done"
}

fix_paths() {
    log_info "Fixing hardcoded paths in configs..."
    local files_to_fix=(
        "$HOME/.config/hypr/hyprpaper.conf"
        "$HOME/.config/hypr/autostart.conf"
        "$HOME/.config/hypr/keybinds.conf" 
        "$HOME/.config/hypr/hypridle.conf"
    )
    
    for file in "${files_to_fix[@]}"; do
        if [[ -f "$file" ]]; then
            sed -i "s|/home/cachebag|$HOME|g" "$file"
        fi
    done
    
    log_success "Paths updated"
    save_state "paths_done"
}

post_install() {
    log_info "Running post-installation tasks..."
    
    if [[ ! -d "$HOME/.local/bin" ]]; then
        mkdir -p "$HOME/.local/bin"
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
    fi
    
    log_info "Installation complete"
    echo ""
    echo -e "${GREEN}=== INSTALLATION SUMMARY ===${NC}"
    echo "✓ Dependencies installed"
    echo "✓ Configurations symlinked" 
    echo "✓ Fonts installed"
    echo "✓ Wallpapers repository cloned"
    echo "✓ SDDM theme configured"
    echo "✓ Services enabled"
    echo "✓ Neovim plugins installed"
    echo "✓ Zsh configured as default shell"
    echo ""
    echo -e "${YELLOW}KEYBINDS:${NC}"
    echo "Super+Return: Terminal"
    echo "Super+A: App launcher (Rofi)"
    echo "Super+Q: Close window"
    echo "Super+E: File manager"
    echo "Super+W: Wallpaper picker"
    echo "Super+Shift+W: Change wallpaper"
    echo "Super+S: Screenshot"
    echo "Super+P: Power menu"
    echo "Super+L: Lock screen"
    echo ""
    echo -e "${YELLOW}NEXT STEPS:${NC}"
    echo "1. Reboot your system"
    echo "2. Log into Hyprland from SDDM"
    echo "3. Post-install setup will run automatically"
    echo "4. Select your monitor and configuration"
    echo ""
    
    rm -f "$STATE_FILE"
    
    read -p "Reboot now? (y/N): " -n1 reboot_choice
    echo
    if [[ $reboot_choice =~ ^[Yy]$ ]]; then
        sudo reboot
    else
        log_info "Remember to reboot before using Hyprland"
    fi
}

main() {
    echo -e "${BLUE}╔══════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║    Cachebag's Dotfiles Installer     ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════╝${NC}"
    echo ""
    echo "This will install and configure:"
    echo "• Hyprland (Wayland compositor)"
    echo "• Waybar (Status bar)"
    echo "• Rofi (Application launcher)"
    echo "• Kitty (Terminal)"
    echo "• Neovim (Editor with plugins)"
    echo "• SDDM (Display manager theme)"
    echo "• Firefox, Dolphin, Obsidian"
    echo "• Various utilities and fonts"
    echo ""
    
    read -p "Continue with installation? (y/N): " -n1 choice
    echo
    [[ $choice =~ ^[Yy]$ ]] || { log_info "Installation cancelled"; exit 0; }

    check_arch
    check_user

    local current_state=$(get_state)
    log_info "Resuming from state: $current_state"

    case "$current_state" in
        "start")
            install_dependencies
            ;&
        "dependencies_done")
            create_directories
            ;&
        "directories_done")
            backup_configs
            ;&
        "backup_done")
            create_symlinks
            ;&
        "symlinks_done")
            setup_sddm
            ;&
        "sddm_done")
            setup_fonts
            ;&
        "fonts_done")
            setup_wallpapers
            ;&
        "wallpapers_done")
            setup_services
            ;&
        "services_done")
            setup_neovim
            ;&
        "neovim_done")
            setup_zsh
            ;&
        "zsh_done")
            fix_paths
            ;&
        "paths_done")
            post_install
            ;;
        *)
            log_error "Unknown state: $current_state"
            exit 1
            ;;
    esac
}

main "$@"