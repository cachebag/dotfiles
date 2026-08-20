#!/bin/bash

set -Eeuo pipefail
shopt -s nullglob

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info()    { echo -e "${BLUE}[INFO]${NC} ${1-}"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} ${1-}"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} ${1-}"; }
log_error()   { echo -e "${RED}[ERROR]${NC} ${1-}"; }

DOTFILES_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE_FILE="$HOME/.dotfiles_install_state"

save_state() {
    echo "$1" > "$STATE_FILE"
}

get_state() {
    if [[ -f "$STATE_FILE" ]]; then cat "$STATE_FILE"; else echo "start"; fi
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
    local exit_code=$?
    log_error "Installation failed (line ${BASH_LINENO[0]}, exit $exit_code). State saved. Run script again to continue."
    exit "$exit_code"
}

trap cleanup_on_error ERR

read_pkg_list() {
    local section="$1" file="$DOTFILES_ROOT/dependencies.yml"
    [[ -f "$file" ]] || return 1
    awk -v want="$section:" '
        /^[a-zA-Z_]+:/ { inside = ($0 == want); next }
        inside && /^[[:space:]]*-[[:space:]]+/ {
            sub(/^[[:space:]]*-[[:space:]]+/, "")
            sub(/[[:space:]]*#.*$/, "")
            gsub(/[[:space:]]+$/, "")
            if (length($0)) print
        }
    ' "$file"
}

install_dependencies() {
    log_info "Installing system dependencies..."

    local pacman_pkgs=() aur_pkgs=()
    mapfile -t pacman_pkgs < <(read_pkg_list arch_packages)
    mapfile -t aur_pkgs   < <(read_pkg_list aur_packages)

    if [[ ${#pacman_pkgs[@]} -eq 0 ]]; then
        log_error "No packages parsed from $DOTFILES_ROOT/dependencies.yml"
        exit 1
    fi
    log_info "${#pacman_pkgs[@]} pacman packages, ${#aur_pkgs[@]} AUR packages from dependencies.yml"

    sudo pacman -Syu --needed --noconfirm "${pacman_pkgs[@]}" ||
        log_warning "Some pacman packages failed to install — check output above"

    if ! command -v yay &>/dev/null; then
        log_info "Installing yay AUR helper..."
        rm -rf /tmp/yay
        git clone https://aur.archlinux.org/yay.git /tmp/yay
        (cd /tmp/yay && makepkg -si --noconfirm)
    fi

    if [[ ${#aur_pkgs[@]} -gt 0 ]]; then
        yay -S --needed --noconfirm "${aur_pkgs[@]}" ||
            log_warning "Some AUR packages failed to install — check output above"
    fi

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
        "$HOME/Pictures/screenshots"
    )
    local d
    for d in "${dirs[@]}"; do
        mkdir -p "$d"
    done
    log_success "Directories created"
    save_state "directories_done"
}

backup_configs() {
    log_info "Backing up existing configurations..."
    local backup_dir
    backup_dir="$HOME/.config/dotfiles_backup_$(date +%Y%m%d_%H%M%S)"
    local configs=(hypr waybar rofi nvim kitty dunst yazi fastfetch)
    local backup_needed=false
    local config config_path file

    for config in "${configs[@]}"; do
        config_path="$HOME/.config/$config"
        if [[ -d "$config_path" && ! -L "$config_path" ]]; then
            mkdir -p "$backup_dir"
            mv "$config_path" "$backup_dir/"
            log_warning "Backed up $config to $backup_dir"
            backup_needed=true
        fi
    done

    for file in .zshrc .zsh_history .tmux.conf; do
        if [[ -f "$HOME/$file" && ! -L "$HOME/$file" ]]; then
            mkdir -p "$backup_dir"
            cp "$HOME/$file" "$backup_dir/"
            log_warning "Backed up $file to $backup_dir"
            backup_needed=true
        fi
    done

    if [[ "$backup_needed" == false && -d "$backup_dir" ]]; then
        rmdir "$backup_dir" 2>/dev/null || true
    fi
    log_success "Backup completed"
    save_state "backup_done"
}

link_dir() {
    local src="$1" dst="$2"
    [[ -d "$DOTFILES_ROOT/$src" ]] || return 0
    mkdir -p "$(dirname "$dst")"
    rm -rf "$dst"
    ln -sfn "$DOTFILES_ROOT/$src" "$dst"
    log_info "Linked $src → $dst"
}

link_file() {
    local src="$1" dst="$2"
    [[ -f "$DOTFILES_ROOT/$src" ]] || return 0
    mkdir -p "$(dirname "$dst")"
    [[ -e "$dst" && ! -L "$dst" ]] && rm -f "$dst"
    ln -sfn "$DOTFILES_ROOT/$src" "$dst"
    log_info "Linked $src → $dst"
}

create_symlinks() {
    log_info "Creating symlinks..."

    local dir_map=(
        "hyprland:$HOME/.config/hypr"
        "waybar:$HOME/.config/waybar"
        "nvim:$HOME/.config/nvim"
        "kitty:$HOME/.config/kitty"
        "rofi:$HOME/.config/rofi"
        "dunst:$HOME/.config/dunst"
        "yazi:$HOME/.config/yazi"
        "fastfetch:$HOME/.config/fastfetch"
        "blurs/dist:$HOME/.config/blurs"
    )
    local mapping
    for mapping in "${dir_map[@]}"; do
        link_dir "${mapping%%:*}" "${mapping#*:}"
    done

    link_file "starship/starship.toml" "$HOME/.config/starship.toml"
    link_file "zsh/zshrc"              "$HOME/.zshrc"
    link_file "tmux/tmux.conf"         "$HOME/.tmux.conf"

    local script script_name
    for script in "$DOTFILES_ROOT/scripts/"*.sh; do
        chmod +x "$script"
        script_name=$(basename "$script")
        ln -sfn "$script" "$HOME/.local/bin/${script_name%.sh}"
    done

    local app
    for app in "$DOTFILES_ROOT/applications/"*.desktop; do
        ln -sfn "$app" "$HOME/.local/share/applications/"
    done

    log_success "Symlinks created"
    save_state "symlinks_done"
}

setup_sddm() {
    log_info "Setting up SDDM..."

    if [[ ! -d /usr/share/sddm/themes/silent ]]; then
        log_info "Installing Silent SDDM theme..."
        local tmp_dir
        tmp_dir=$(mktemp -d)
        if git clone --depth 1 https://github.com/uiriansan/SilentSDDM.git "$tmp_dir/silent"; then
            sudo mkdir -p /usr/share/sddm/themes/silent
            sudo cp -rf "$tmp_dir/silent/." /usr/share/sddm/themes/silent/
            sudo cp -r /usr/share/sddm/themes/silent/fonts/{redhat,redhat-vf} /usr/share/fonts/ 2>/dev/null || true
            log_success "Silent theme installed"
        else
            log_warning "Failed to clone Silent SDDM theme — SDDM will use default theme"
        fi
        rm -rf "$tmp_dir"
    else
        log_info "Silent SDDM theme already installed"
    fi

    if [[ -f "$DOTFILES_ROOT/sddm/conf.d/theme.conf" ]]; then
        sudo mkdir -p /etc/sddm.conf.d/
        sudo cp "$DOTFILES_ROOT/sddm/conf.d/theme.conf" /etc/sddm.conf.d/
        log_info "Copied SDDM config to /etc/sddm.conf.d/"
    fi

    if [[ ! -f /etc/sddm.conf ]] || ! grep -q 'Current=silent' /etc/sddm.conf 2>/dev/null; then
        sudo tee /etc/sddm.conf > /dev/null <<'SDDMCONF'
[General]
InputMethod=qtvirtualkeyboard
GreeterEnvironment=QML2_IMPORT_PATH=/usr/share/sddm/themes/silent/components/,QT_IM_MODULE=qtvirtualkeyboard

[Theme]
Current=silent
SDDMCONF
        log_info "Wrote /etc/sddm.conf"
    fi

    if ! systemctl is-enabled display-manager.service &>/dev/null; then
        sudo systemctl enable sddm
    else
        log_warning "Display manager already configured, skipping SDDM enable"
    fi

    log_success "SDDM configured"
    save_state "sddm_done"
}

install_nerd_font() {
    local name="$1" probe="$2"
    local font_dir="$HOME/.local/share/fonts"
    [[ -f "$font_dir/$probe" ]] && return 0

    local url="https://github.com/ryanoasis/nerd-fonts/releases/download/v3.0.2/${name}.zip"
    if wget -q -O "/tmp/${name}.zip" "$url"; then
        unzip -q -o "/tmp/${name}.zip" -d "$font_dir"
        rm -f "/tmp/${name}.zip"
        log_info "Installed $name Nerd Font"
    else
        log_warning "Failed to download $name Nerd Font — install manually later"
    fi
}

setup_fonts() {
    log_info "Installing fonts..."
    mkdir -p "$HOME/.local/share/fonts"
    install_nerd_font FiraCode      FiraCodeNerdFont-Regular.ttf
    install_nerd_font JetBrainsMono JetBrainsMonoNerdFont-Regular.ttf
    fc-cache -f > /dev/null 2>&1 || true
    log_success "Fonts installed"
    save_state "fonts_done"
}

github_ssh_ok() {
    local out
    out=$(ssh -o StrictHostKeyChecking=accept-new -o BatchMode=yes -T git@github.com 2>&1 || true)
    [[ "$out" == *"successfully authenticated"* ]]
}

setup_git_ssh() {
    log_info "Setting up Git identity and GitHub SSH access..."

    local name="" email=""
    if ! git config --global user.name >/dev/null 2>&1; then
        read -rp "Git user.name: " name || true
        [[ -n "$name" ]] && git config --global user.name "$name"
    fi
    if ! git config --global user.email >/dev/null 2>&1; then
        read -rp "Git user.email: " email || true
        [[ -n "$email" ]] && git config --global user.email "$email"
    fi
    email=$(git config --global user.email 2>/dev/null || echo "$USER@$(uname -n)")

    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"
    local key="$HOME/.ssh/id_ed25519"

    if [[ -f "$key" ]]; then
        log_info "Using existing SSH key at $key"
    else
        log_info "Generating an ed25519 SSH key. Leave the passphrase empty for unattended cloning."
        if ! ssh-keygen -t ed25519 -C "$email" -f "$key"; then
            log_warning "ssh-keygen failed — skipping GitHub SSH setup"
            save_state "git_ssh_done"
            return 0
        fi
    fi
    chmod 600 "$key"
    chmod 644 "$key.pub"

    if [[ -z "${SSH_AUTH_SOCK:-}" ]]; then
        eval "$(ssh-agent -s)" >/dev/null 2>&1 || true
    fi
    ssh-add "$key" >/dev/null 2>&1 || log_warning "Could not add key to ssh-agent"

    if ! grep -q "Host github.com" "$HOME/.ssh/config" 2>/dev/null; then
        cat >> "$HOME/.ssh/config" <<SSHCONF
Host github.com
    HostName github.com
    User git
    IdentityFile $key
    AddKeysToAgent yes
SSHCONF
        chmod 600 "$HOME/.ssh/config"
        log_info "Added github.com block to ~/.ssh/config"
    fi

    if github_ssh_ok; then
        log_success "GitHub SSH already working"
        save_state "git_ssh_done"
        return 0
    fi

    if command -v gh &>/dev/null; then
        gh auth status >/dev/null 2>&1 || gh auth login --hostname github.com --git-protocol ssh ||
            log_warning "gh auth login did not complete"
        gh ssh-key add "$key.pub" --title "$(uname -n)" >/dev/null 2>&1 ||
            log_warning "Could not upload key via gh — it may already be registered"
    else
        log_warning "gh CLI unavailable — add this key at https://github.com/settings/ssh/new"
        echo
        cat "$key.pub"
        echo
        read -rp "Press Enter once the key is added to GitHub..." || true
    fi

    if github_ssh_ok; then
        log_success "GitHub SSH authentication verified"
    else
        log_warning "GitHub SSH not verified — SSH clones will fall back to HTTPS"
    fi

    save_state "git_ssh_done"
}

setup_wallpapers() {
    log_info "Setting up wallpapers..."
    if [[ -d "$HOME/wallpapers/.git" ]]; then
        git -C "$HOME/wallpapers" pull || log_warning "Failed to pull wallpapers — using existing copy"
    else
        rm -rf "$HOME/wallpapers"
        if ! git clone git@github.com:cachebag/wallpapers.git "$HOME/wallpapers" 2>/dev/null; then
            log_warning "SSH clone failed, trying HTTPS..."
            if ! git clone https://github.com/cachebag/wallpapers.git "$HOME/wallpapers"; then
                log_warning "Failed to clone wallpapers repo — create ~/wallpapers manually later"
                mkdir -p "$HOME/wallpapers"
            fi
        fi
    fi
    log_success "Wallpapers set up"
    save_state "wallpapers_done"
}

setup_services() {
    log_info "Enabling system services..."
    sudo systemctl enable NetworkManager || log_warning "Failed to enable NetworkManager"
    sudo systemctl enable bluetooth 2>/dev/null || log_warning "Bluetooth service not found — skipping"
    sudo usermod -aG video,input,audio "$USER" || log_warning "Failed to add user to groups"

    local script
    for script in "$DOTFILES_ROOT/hyprland/scripts/"*.sh; do
        chmod +x "$script"
    done

    log_success "Services configured"
    save_state "services_done"
}

rebuild_lazy_plugin() {
    local dir="$HOME/.local/share/nvim/lazy/$1"
    [[ -f "$dir/Makefile" ]] || return 0
    make -C "$dir" clean > /dev/null 2>&1 || true
    if make -C "$dir" > /dev/null 2>&1; then
        log_info "Rebuilt $1"
    else
        log_warning "Failed to rebuild $1 — may need manual rebuild"
    fi
}

setup_neovim() {
    log_info "Setting up Neovim environment..."

    if command -v python &>/dev/null; then
        python -m pip install --user --upgrade pynvim > /dev/null 2>&1 ||
            log_warning "Failed to install pynvim"
    fi

    if command -v bun &>/dev/null; then
        bun install -g neovim > /dev/null 2>&1 ||
            log_warning "Failed to install neovim package via bun"
    elif command -v npm &>/dev/null; then
        sudo npm install -g neovim > /dev/null 2>&1 ||
            log_warning "Failed to install neovim package via npm"
    fi

    if ! timeout 30 nvim --headless "+qa" 2>/dev/null; then
        log_warning "Neovim failed to start — skipping plugin installation"
        save_state "neovim_done"
        return 0
    fi

    if ! timeout 120 nvim --headless "+Lazy! sync" +qa 2>/dev/null; then
        log_warning "Plugin install timed out or failed — run ':Lazy sync' manually later"
        save_state "neovim_done"
        return 0
    fi

    rebuild_lazy_plugin telescope.nvim
    rebuild_lazy_plugin telescope-fzf-native.nvim

    log_success "Neovim setup completed"
    save_state "neovim_done"
}

setup_zsh() {
    log_info "Configuring Zsh..."
    local zsh_path current_shell
    zsh_path=$(command -v zsh || echo /usr/bin/zsh)
    current_shell=$(getent passwd "$USER" | cut -d: -f7)

    if [[ "$current_shell" != "$zsh_path" ]]; then
        if chsh -s "$zsh_path"; then
            log_warning "Shell changed — logout/login required for full effect"
        else
            log_warning "Failed to change shell — run 'chsh -s $zsh_path' manually"
        fi
    fi
    save_state "zsh_done"
}

fix_paths() {
    log_info "Fixing hardcoded paths in configs..."
    local files=(
        "$HOME/.config/hypr/hyprpaper.conf"
        "$HOME/.config/hypr/hypridle.conf"
    )
    local file real
    for file in "${files[@]}"; do
        [[ -f "$file" ]] || continue
        grep -q /home/cachebag "$file" 2>/dev/null || continue
        real=$(readlink -f "$file")
        if [[ "$real" == "$DOTFILES_ROOT"/* ]]; then
            log_warning "$(basename "$file") holds a /home/cachebag path but resolves into the repo ($real) — edit it there instead of letting the installer dirty tracked files"
            continue
        fi
        sed -i "s|/home/cachebag|$HOME|g" "$file"
        log_info "Rewrote paths in $(basename "$file")"
    done

    log_success "Paths updated"
    save_state "paths_done"
}

post_install() {
    echo -e "${GREEN}=== INSTALLATION SUMMARY ===${NC}"
    echo "✓ Dependencies installed"
    echo "✓ Configurations symlinked"
    echo "✓ Fonts installed"
    echo "✓ SDDM theme configured"
    echo "✓ Services enabled"
    echo "✓ Neovim plugins installed"
    echo "✓ Zsh configured as default shell"
    echo "✓ GitHub SSH key configured"
    echo ""
    echo -e "${YELLOW}NEXT STEPS:${NC}"
    echo "1. Run 'hyprctl monitors' and edit ~/.config/hypr/monitors.lua to match your displays"
    echo "2. Reboot and select 'Hyprland' from your display manager"
    echo ""
    echo -e "${BLUE}KEYBINDS:${NC}"
    echo "Super+Return: Terminal"
    echo "Super+A: App launcher (Rofi)"
    echo "Super+R: Alternative launcher (Wofi)"
    echo "Super+Q: Close window"
    echo "Super+E: File manager (Dolphin)"
    echo "Super+W: Wallpaper picker"
    echo "Super+S: Screenshot"
    echo "Super+P: Power menu"
    echo "Super+L: Lock screen"
    echo ""

    rm -f "$STATE_FILE"

    local reboot_choice=""
    read -rp "Reboot now? (y/N): " -n1 reboot_choice || true
    echo
    if [[ $reboot_choice =~ ^[Yy]$ ]]; then
        sudo reboot
    fi
}

main() {
    check_arch
    check_user

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

    if [[ "${DEPS_ONLY:-}" == "true" ]]; then
        log_info "DEPS_ONLY set — installing dependencies then stopping"
        install_dependencies
        exit 0
    fi

    local choice=""
    read -rp "Continue with installation? (y/N): " -n1 choice || true
    echo
    [[ $choice =~ ^[Yy]$ ]] || { log_info "Installation cancelled"; exit 0; }

    local current_state
    current_state=$(get_state)
    log_info "Resuming from state: $current_state"

    case "$current_state" in
        start)             install_dependencies ;&
        dependencies_done) create_directories   ;&
        directories_done)  backup_configs       ;&
        backup_done)       create_symlinks      ;&
        symlinks_done)     setup_sddm           ;&
        sddm_done)         setup_fonts          ;&
        fonts_done)        setup_git_ssh        ;&
        git_ssh_done)      setup_wallpapers     ;&
        wallpapers_done)   setup_services       ;&
        services_done)     setup_neovim         ;&
        neovim_done)       setup_zsh            ;&
        zsh_done)          fix_paths            ;&
        paths_done)        post_install         ;;
        *)
            log_error "Unknown state: $current_state"
            exit 1
            ;;
    esac
}

main "$@"
