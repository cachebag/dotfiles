#!/usr/bin/env bash
# Switches the desktop between light and dark.
#
# pywal regenerates the palette from the current wallpaper in the chosen mode.
# The bar repaints on its own because Theme.qml watches colors.json; GTK apps
# follow the gsettings keys below.
#
# Usage: theme-mode.sh [toggle|light|dark|status]

MODE_FILE="$HOME/.cache/wal/mode"

current_mode() {
    if [[ -r $MODE_FILE ]]; then
        cat "$MODE_FILE"
    else
        echo dark
    fi
}

case "${1:-toggle}" in
    status)
        current_mode
        exit 0
        ;;
    light) target=light ;;
    dark) target=dark ;;
    toggle)
        if [[ $(current_mode) == dark ]]; then target=light; else target=dark; fi
        ;;
    *)
        echo "usage: ${0##*/} [toggle|light|dark|status]" >&2
        exit 2
        ;;
esac

mkdir -p "$(dirname "$MODE_FILE")"
printf '%s\n' "$target" > "$MODE_FILE"

# wal.sh reads MODE_FILE, so this repaints in the new mode.
if ! "$HOME/dotfiles/scripts/wal.sh" >/dev/null; then
    echo "wal.sh failed; theme not applied" >&2
    exit 1
fi

# color-scheme drives GTK4/libadwaita; the -dark theme name drives GTK3.
theme=$(gsettings get org.gnome.desktop.interface gtk-theme 2>/dev/null | tr -d "'")
base=${theme%-dark}

if [[ $target == light ]]; then
    gsettings set org.gnome.desktop.interface color-scheme prefer-light 2>/dev/null || true
    want=$base
else
    gsettings set org.gnome.desktop.interface color-scheme prefer-dark 2>/dev/null || true
    want=$base-dark
fi

# Only switch if that variant exists, otherwise leave the GTK theme alone.
if [[ -n $base ]] && { [[ -d /usr/share/themes/$want ]] || [[ -d $HOME/.themes/$want ]]; }; then
    gsettings set org.gnome.desktop.interface gtk-theme "$want" 2>/dev/null || true
fi

notify-send "Theme" "$target mode" 2>/dev/null || true
