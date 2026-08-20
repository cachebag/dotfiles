# cachebag's dotfiles

<p align="center">
  <strong>my personal arch + hyprland config</strong>
</p>

<img width="2560" height="1440" alt="image" src="https://github.com/user-attachments/assets/ab4d8f56-2991-4840-897e-b58e7c2fef19" />
<img width="2560" height="1440" alt="image" src="https://github.com/user-attachments/assets/45823ebd-072c-4938-aa0d-2f2c3072c26d" />


#

## Components

| Category | Tool |
|----------|------|
| Compositor | [Hyprland](https://hyprland.org) |
| Bar | [Waybar](https://github.com/Alexays/Waybar) |
| Launcher | [Rofi](https://github.com/davatorium/rofi) |
| Terminal | [Kitty](https://sw.kovidgoyal.net/kitty/) |
| Editor | [Neovim](https://neovim.io) |
| Shell | [Zsh](https://www.zsh.org) + [Zinit](https://github.com/zdharma-continuum/zinit) + [Spaceship](https://spaceship-prompt.sh) |
| Multiplexer | [tmux](https://github.com/tmux/tmux) |
| File Manager | [Dolphin](https://apps.kde.org/dolphin/) / [Yazi](https://yazi-rs.github.io) |
| Display Manager | [SDDM](https://github.com/sddm/sddm) + [Silent](https://github.com/uiriansan/SilentSDDM) theme |
| Notifications | [Dunst](https://dunst-project.org) |
| Wallpaper | [Hyprpaper](https://github.com/hyprwm/hyprpaper) + [Pywal](https://github.com/dylanaraps/pywal) |
| Lock | [Swaylock-effects](https://github.com/jirutka/swaylock-effects) |
| Idle | [Hypridle](https://github.com/hyprwm/hypridle) |
| Logout | [Wlogout](https://github.com/ArtsyMacaw/wlogout) |
| Screenshot | [grim](https://sr.ht/~emersion/grim/) + [slurp](https://github.com/emersion/slurp) |
| Fetch | [Fastfetch](https://github.com/fastfetch-cli/fastfetch) |
| Network UI | [nmrs](https://github.com/cachebag/nmrs) |

## Installation

> Requires Arch Linux. Do not run as root.

1. Clone the repository:

```bash
git clone https://github.com/cachebag/dotfiles.git ~/dotfiles
cd ~/dotfiles
```

2. Run the installation script:

```bash
chmod +x install.sh
./install.sh
```

The installer is resumable — if it fails mid-way, just run it again and it picks up where it left off.

3. Reboot and select **Hyprland** from SDDM.

## Keybindings

### Applications

| Key | Action |
|-----|--------|
| `Super + Return` | Terminal (Kitty) |
| `Super + A` | App launcher (Rofi) |
| `Super + B` | Firefox |
| `Super + E` | File manager (Thunar) |
| `Super + D` | ChatGPT |
| `Super + I` | WhatsApp |
| `Super + O` | Obsidian |
| `Super + W` | Wallpaper picker |
| `Super + S` | Screenshot (region -> clipboard) |
| `Super + P` | Power menu (wlogout) |
| `Super + L` | Lock screen |
| `Super + Y` | Restart Waybar |

### Screenshots

##### **Rofi**
<img width="2560" height="1440" alt="image" src="https://github.com/user-attachments/assets/13bd2ff7-1229-422a-8d84-e89cc977dcb0" />

##### **Wallpaper picker (yazi)**
<img width="2560" height="1440" alt="image" src="https://github.com/user-attachments/assets/af5602fd-13aa-4172-b870-0022bd9d0cb6" />

##### **ChatGPT**
<img width="2560" height="1440" alt="image" src="https://github.com/user-attachments/assets/29fcf560-7947-4b49-9191-9c5b0bd602ae" />

#### **blurs (bluetooth applet)**
<img width="1304" height="590" alt="image" src="https://github.com/user-attachments/assets/bedffcec-671b-4592-a1ba-e3cb795a3116" />

### Window Management

## Keybinds

| Key | Action |
|-----|--------|
| `Super + Return` | Terminal (kitty) |
| `Super + A` | App launcher (Rofi) |
| `Super + B` | Firefox |
| `Super + E` | File manager (Thunar) |
| `Super + O` | Obsidian |
| `Super + D` | ChatGPT (Chromium app) |
| `Super + I` | WhatsApp (Chromium app) |
| `Super + W` | Wallpaper picker |
| `Super + S` | Screenshot region → clipboard |
| `Super + L` | Lock screen |
| `Super + P` | Power menu |
| `Super + Y` | Restart Waybar |
| `Super + Q` | Close window |
| `Super + M` | Exit Hyprland |
| `Super + V` | Toggle floating |
| `Super + K` | Toggle pseudotile |
| `Super + 1-0` | Switch workspace 1–10 |
| `Super + Shift + 1-0` | Move window to workspace 1–10 |
| `Super + Ctrl + Left/Right` | Previous/Next workspace |
| `Super + Arrow Keys` | Move focus |
| `Super + Shift + Arrow Keys` | Resize window |
| `Super + Mouse Left` | Move window |
| `Super + Mouse Right` | Resize window |

---

**Note**: This configuration is optimized for my personal workflow. I am not responsible for anything that happens to your machine if you use these dotfiles.
