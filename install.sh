#!/bin/bash
# Cachebag's Dotfiles Installation Script
# Automated setup for Hyprland + Neovim configuration

set -e

#DRY_RUN=true   # set to true to avoid making changes

# [[ $DRY_RUN == true ]] && {
  #  set -x       # print every command
   # trap "echo 'Dry run finished'; exit 0" EXIT
# }

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging helpers
log_info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $1"; }

# --- Checks -------------------------------------------------------------

check_arch() {
    if [[ ! -f /etc/arch-release ]]; then
        log_error "This script is designed for Arch Linux systems"
        exit 1
    fi
}

check_user() {
    if [[ $EUID -eq 0 ]]; then
        log_error "Do not run this as root"
        exit 1
    fi
}

# --- Dependencies -------------------------------------------------------

install_dependencies() {
    log_info "Installing system dependencies..."
    local pacman_pkgs=(
        hyprland waybar rofi-wayland neovim git curl wget ripgrep fd
        nodejs npm python python-pip python-virtualenv
        ttf-fira-code ttf-font-awesome wl-clipboard
        xdg-desktop-portal-hyprland qt5-wayland qt6-wayland
        kitty dunst yazi zsh fastfetch fzf
    )
    sudo pacman -S --needed --noconfirm "${pacman_pkgs[@]}"

    if ! command -v yay &>/dev/null; then
        log_info "Installing yay..."
        cd /tmp && git clone https://aur.archlinux.org/yay.git
        cd yay && makepkg -si --noconfirm && cd -
    fi

    local aur_pkgs=(hyprpaper swaylock-effects wlogout hypridle)
    yay -S --needed --noconfirm "${aur_pkgs[@]}"
    log_success "Dependencies installed"
}

# --- Directories --------------------------------------------------------

create_directories() {
    log_info "Creating config directories..."
    local dirs=(
        "$HOME/.config" "$HOME/.config/hypr" "$HOME/.config/waybar"
        "$HOME/.config/rofi" "$HOME/.config/nvim" "$HOME/.config/kitty"
        "$HOME/.local/share/applications" "$HOME/.local/bin"
        "$HOME/wallpapers" "$HOME/.local/share/zinit"
    )
    for d in "${dirs[@]}"; do mkdir -p "$d"; done
    log_success "Directories created"
}

# --- Backup -------------------------------------------------------------

backup_configs() {
    log_info "Backing up old configs..."
    local bdir="$HOME/.config/dotfiles_backup_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$bdir"
    for c in hypr waybar rofi nvim kitty; do
        if [[ -d "$HOME/.config/$c" && ! -L "$HOME/.config/$c" ]]; then
            mv "$HOME/.config/$c" "$bdir/"
            log_warning "Backed up $c"
        fi
    done
    [[ -f "$HOME/.zshrc" && ! -L "$HOME/.zshrc" ]] && cp "$HOME/.zshrc" "$bdir/"
    [[ -f "$HOME/.zsh_history" && ! -L "$HOME/.zsh_history" ]] && cp "$HOME/.zsh_history" "$bdir/"
    [[ -n "$(ls -A "$bdir")" ]] || rmdir "$bdir"
}

# --- Symlinks -----------------------------------------------------------

create_symlinks() {
    log_info "Creating symlinks..."
    local root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

    # Core configs that live in ~/.config
    declare -A map=(
        [hyprland]="$HOME/.config/hypr"
        [waybar]="$HOME/.config/waybar"
        [rofi]="$HOME/.config/rofi"
        [nvim]="$HOME/.config/nvim"
        [kitty]="$HOME/.config/kitty"
    )

    # Zsh files
    if [[ -f "$root/zsh/zshrc" ]]; then
        [[ -f "$HOME/.zshrc" && ! -L "$HOME/.zshrc" ]] && \
            mv "$HOME/.zshrc" "$HOME/.zshrc.bak.$(date +%s)"
        ln -sf "$root/zsh/zshrc" "$HOME/.zshrc"
    fi
    if [[ -f "$root/zsh/zsh_history" ]]; then
        [[ -f "$HOME/.zsh_history" && ! -L "$HOME/.zsh_history" ]] && \
            mv "$HOME/.zsh_history" "$HOME/.zsh_history.bak.$(date +%s)"
        ln -sf "$root/zsh/zsh_history" "$HOME/.zsh_history"
    fi

    # Link the main configs
    for src in "${!map[@]}"; do
        [[ -d "$root/$src" ]] && rm -rf "${map[$src]}" && \
            ln -sf "$root/$src" "${map[$src]}"
    done

    # --- Extra symlinks for major components ----------------------------
    declare -A extras=(
        [alacritty]="$HOME/.config/alacritty"
        [fastfetch]="$HOME/.config/fastfetch"
        [yazi]="$HOME/.config/yazi"
        [dunst]="$HOME/.config/dunst"
    )

    for src in "${!extras[@]}"; do
        if [[ -d "$root/$src" ]]; then
            [[ -e "${extras[$src]}" && ! -L "${extras[$src]}" ]] && \
                mv "${extras[$src]}" "${extras[$src]}.bak.$(date +%s)"
            ln -snf "$root/$src" "${extras[$src]}"
            log_info "Linked $src → ${extras[$src]}"
        fi
    done

    log_success "Symlinks created"
}

# --- Neovim / Node ------------------------------------------------------

setup_neovim_python() {
    log_info "Setting up Neovim Python env..."
    local venv="$HOME/.config/nvim/env"
    [[ -d "$venv" ]] || python -m venv "$venv"
    source "$venv/bin/activate"
    pip install --upgrade pip pynvim
    deactivate
}

setup_node_dependencies() {
    log_info "Ensuring npm & neovim package..."
    sudo npm install -g npm   # <--- ensure npm itself is updated
    sudo npm install -g neovim
}

setup_neovim_plugins() {
    log_info "Installing Neovim plugins..."
    nvim --headless "+Lazy! sync" +qa
}

# --- Fonts / Wallpapers -------------------------------------------------

setup_fonts() {
    log_info "Installing fonts..."
    local fontdir="$HOME/.local/share/fonts"
    mkdir -p "$fontdir"
    if [[ ! -f "$fontdir/FiraCodeNerdFont-Regular.ttf" ]]; then
        cd /tmp
        wget https://github.com/ryanoasis/nerd-fonts/releases/download/v3.0.2/FiraCode.zip
        unzip -o FiraCode.zip -d "$fontdir"
        rm FiraCode.zip
        fc-cache -fv
    fi
}

setup_wallpapers() {
    mkdir -p "$HOME/wallpapers"
    if [[ -z "$(ls -A "$HOME/wallpapers")" ]]; then
        wget -O "$HOME/wallpapers/sample-wallpaper.jpg" \
            "https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=2560&h=1440&fit=crop"
    fi
}

# --- Shell / Post -------------------------------------------------------

setup_zsh() {
    if [[ "$SHELL" != "/usr/bin/zsh" && "$SHELL" != "/bin/zsh" ]]; then
        chsh -s /usr/bin/zsh
    fi
}

post_install() {
    sudo usermod -aG video,input "$USER"
    local root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    [[ -d "$root/hyprland/scripts" ]] && chmod +x "$root/hyprland/scripts/"*.sh
    [[ -f "$HOME/.config/hypr/hyprpaper.conf" ]] && sed -i "s|/home/cachebag|$HOME|g" "$HOME/.config/hypr/hyprpaper.conf"
    [[ -f "$HOME/.config/hypr/autostart.conf" ]] && sed -i "s|/home/cachebag|$HOME|g" "$HOME/.config/hypr/autostart.conf"

    # --- Telescope rebuild helper --------------------------------------
    echo
    read -p "If Telescope fails on first Neovim launch, rebuild now? (y/N): " -n1 ans
    echo
    if [[ $ans =~ ^[Yy]$ ]]; then
        tele_dir="$HOME/.local/share/nvim/lazy/telescope.nvim"
        if [[ -d "$tele_dir" ]]; then
            log_info "Rebuilding Telescope..."
            cd "$tele_dir"
            make clean && make
            log_success "Telescope rebuilt"
        else
            log_warning "telescope.nvim not found in $tele_dir"
        fi
    fi
}

# --- Main ---------------------------------------------------------------

main() {
    echo -e "${BLUE}Cachebag's Dotfiles Installer${NC}"
    read -p "Continue installation? (y/N): " -n1 ans; echo
    [[ $ans =~ ^[Yy]$ ]] || { log_info "Cancelled"; exit 0; }

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
    setup_zsh
    setup_neovim_plugins
    post_install

    echo -e "${GREEN}Installation complete!${NC}"
    echo "Log out, select Hyprland, and enjoy."
}

main "$@"

