# Cachebag's Dotfiles

A minimal dotfiles config.

## Config covers...

- **Hyprland**
- **Waybar**
- **Rofi**
- **Neovim**

## Install

1. **Clone the repository**:
   ```bash
   git clone https://github.com/cachebag/dotfiles.git ~/.dotfiles
   cd ~/.dotfiles
   ```

2. **Run the installation script**:
   ```bash
   chmod +x install.sh
   ./install.sh
   ```

3. **Log out and select Hyprland** as your session when logging back in.

## Manual Installation

If you prefer to install manually or want to understand what the script does:

### 1. Install Dependencies

```bash
# Core packages
sudo pacman -S hyprland waybar rofi-wayland neovim git curl ripgrep fd nodejs npm python python-pip python-virtualenv ttf-fira-code ttf-font-awesome wl-clipboard

# AUR packages (install yay first if needed)
yay -S hyprpaper swaylock-effects wlogout
```

### 2. Backup Existing Configs

```bash
mkdir -p ~/.config/dotfiles_backup_$(date +%Y%m%d)
mv ~/.config/{hypr,waybar,rofi,nvim} ~/.config/dotfiles_backup_$(date +%Y%m%d)/ 2>/dev/null || true
```

### 3. Create Symlinks

```bash
ln -sf ~/.dotfiles/hypr ~/.config/hypr
ln -sf ~/.dotfiles/waybar ~/.config/waybar
ln -sf ~/.dotfiles/rofi ~/.config/rofi
ln -sf ~/.dotfiles/nvim ~/.config/nvim
```

### 4. Setup Neovim Environment

```bash
# Create Python virtual environment for Neovim
python -m venv ~/.config/nvim/env
source ~/.config/nvim/env/bin/activate
pip install pynvim
deactivate

# Install Node.js support
npm install -g neovim

# Install Neovim plugins
nvim --headless "+Lazy! sync" +qa
```
### Hyprland (Super key)

| Keybinding | Action |
|------------|--------|
| `Super + Return` | Open terminal |
| `Super + D` | Launch Rofi |
| `Super + Q` | Close window |
| `Super + M` | Exit Hyprland |
| `Super + V` | Toggle floating |
| `Super + F` | Toggle fullscreen |
| `Super + 1-9` | Switch to workspace |
| `Super + Shift + 1-9` | Move window to workspace |

### Neovim

| Keybinding | Action |
|------------|--------|
| `Space` | Leader key |
| `<leader>e` | Toggle file explorer |
| `<leader>ff` | Find files |
| `<leader>fw` | Live grep |
| `<leader>b` | Switch buffers |
| `gd` | Go to definition |
| `K` | Show hover info |

## 🛠️ Troubleshooting

### Common Issues

1. **Hyprland won't start**
   - Check GPU drivers: `lspci -k | grep -A 2 -E "(VGA|3D)"`
   - Verify Wayland support: `echo $XDG_SESSION_TYPE`

2. **Fonts look wrong**
   - Install font: `sudo pacman -S ttf-fira-code`
   - Refresh font cache: `fc-cache -fv`

3. **Neovim plugins not working**
   - Reinstall plugins: `:Lazy sync`
   - Check Python path: `:checkhealth`

4. **Waybar not showing**
   - Restart waybar: `killall waybar && waybar &`
   - Check config syntax: `waybar -t`

---

**Note**: This configuration is optimized for my personal workflow. 
