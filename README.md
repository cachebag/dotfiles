# cachebag's dotfiles

<p align="center">
  <strong>my personal arch + hyprland config</strong>
</p>

<img width="2560" height="1440" alt="image" src="https://github.com/user-attachments/assets/bd617a5f-924e-474d-bdef-f29fd93e7695" />
<img width="2560" height="1440" alt="image" src="https://github.com/user-attachments/assets/4093b85e-07a2-4071-b795-f1cbdbb1aa57" />

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
| `Super + E` | File manager (Dolphin) |
| `Super + D` | ChatGPT |
| `Super + I` | WhatsApp |
| `Super + O` | Obsidian |
| `Super + W` | Wallpaper picker |
| `Super + S` | Screenshot (region → clipboard) |
| `Super + P` | Power menu (wlogout) |
| `Super + L` | Lock screen |
| `Super + Y` | Restart Waybar |
| `Super + H` | Toggle blur |
| `Super + Shift + M` | nmrs dev layout (tmux) |

### Screenshots

##### **Rofi**
<img width="2560" height="1440" alt="image" src="https://github.com/user-attachments/assets/7a66ed3a-1f57-46a7-ab4a-083ff216176b" />

##### **Wallpaper picker (yazi)**
<img width="2560" height="1440" alt="image" src="https://github.com/user-attachments/assets/5898fd8d-5500-4560-a7a9-50dd91ae3ba3" />

##### **ChatGPT**
<img width="2560" height="1440" alt="image" src="https://github.com/user-attachments/assets/a108d069-aac0-4019-8fd8-cf4e90505bb7" />

### Window Management

| Key | Action |
|-----|--------|
| `Super + Q` | Close window |
| `Super + M` | Exit Hyprland |
| `Super + V` | Toggle floating |
| `Super + J` | Toggle split |
| `Super + 1-0` | Switch workspace 1–10 |
| `Super + Shift + 1-0` | Move window to workspace 1–10 |
| `Super + Ctrl + Left/Right` | Previous/Next workspace |
| `Super + Arrow Keys` | Move focus |
| `Super + Shift + Arrow Keys` | Resize window |
| `Super + Mouse Left` | Move window |
| `Super + Mouse Right` | Resize window |

### Tmux

| Key | Action |
|-----|--------|
| `Ctrl + Left/Right` | Previous/Next window |
| `Ctrl + X` | New window |
| `Ctrl + Up/Down` | Select pane |

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

---

**Note**: This configuration is optimized for my personal workflow. I am not responsible for anything that happens to your machine if you use these dotfiles.
