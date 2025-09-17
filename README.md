# Cachebag's Dotfiles


## Components

- **Hyprland** 
- **Waybar** 
- **Rofi** -
- **Neovim** 

## Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/cachebag/dotfiles.git ~/.dotfiles
   cd ~/.dotfiles
   ```

2. Run the installation script:
   ```bash
   chmod +x install.sh
   ./install.sh
   ```

3. Log out and select Hyprland as your session.

## Manual Installation

### Dependencies

```bash
# Core packages
sudo pacman -S hyprland waybar rofi-wayland neovim git curl ripgrep fd nodejs npm python python-pip python-virtualenv ttf-fira-code ttf-font-awesome wl-clipboard

# AUR packages (install yay first if needed)
yay -S hyprpaper swaylock-effects wlogout
```

### Configuration

```bash
# Backup existing configs
mkdir -p ~/.config/dotfiles_backup_$(date +%Y%m%d)
mv ~/.config/{hypr,waybar,rofi,nvim} ~/.config/dotfiles_backup_$(date +%Y%m%d)/ 2>/dev/null || true

# Create symlinks
ln -sf ~/.dotfiles/hypr ~/.config/hypr
ln -sf ~/.dotfiles/waybar ~/.config/waybar
ln -sf ~/.dotfiles/rofi ~/.config/rofi
ln -sf ~/.dotfiles/nvim ~/.config/nvim
```

### Neovim Setup

```bash
# Python environment
python -m venv ~/.config/nvim/env
source ~/.config/nvim/env/bin/activate
pip install pynvim
deactivate

# Node.js support
npm install -g neovim

# Install plugins
nvim --headless "+Lazy! sync" +qa
```

## Keybindings

### Hyprland

| Key | Action |
|-----|--------|
| `Super + Return` | Terminal |
| `Super + D` | Rofi launcher |
| `Super + Q` | Close window |
| `Super + M` | Exit |
| `Super + V` | Toggle floating |
| `Super + F` | Toggle fullscreen |
| `Super + 1-9` | Switch workspace |
| `Super + Shift + 1-9` | Move window to workspace |

### Neovim

| Key | Action |
|-----|--------|
| `Space` | Leader key |
| `<leader>e` | File explorer |
| `<leader>ff` | Find files |
| `<leader>fw` | Live grep |
| `<leader>b` | Switch buffers |
| `gd` | Go to definition |
| `K` | Show documentation |

## Troubleshooting

### Hyprland startup issues
- Check GPU drivers: `lspci -k | grep -A 2 -E "(VGA|3D)"`
- Verify Wayland: `echo $XDG_SESSION_TYPE`

### Font issues
- Install fonts: `sudo pacman -S ttf-fira-code`
- Refresh cache: `fc-cache -fv`

### Neovim problems
- Reinstall plugins: `:Lazy sync`
- Check health: `:checkhealth`

### Waybar not visible
- Restart: `killall waybar && waybar &`
- Check syntax: `waybar -t`
4. **Waybar not showing**
   - Restart waybar: `killall waybar && waybar &`
   - Check config syntax: `waybar -t`

---

**Note**: This configuration is optimized for my personal workflow. 
