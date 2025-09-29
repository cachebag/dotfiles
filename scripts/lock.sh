#!/bin/bash
WALLPAPER_DIR="$HOME/wallpapers"
CACHE_DIR="$HOME/.cache/lockscreen"

mkdir -p "$CACHE_DIR"
IMG=$(find "$WALLPAPER_DIR" -type f | shuf -n 1)
HASH=$(sha1sum "$IMG" | cut -d' ' -f1)
BLURRED="$CACHE_DIR/${HASH}.png"

if [[ ! -f "$BLURRED" ]]; then
    convert "$IMG" -blur 0x8 -brightness-contrast -10x-10 "$BLURRED"
fi

swaylock \
  --image "$BLURRED" \
  --clock \
  --indicator \
  --indicator-radius 130 \
  --indicator-thickness 10 \
  --inside-color 282828cc \
  --ring-color 83a598ff \
  --key-hl-color b8bb26ff \
  --bs-hl-color fb4934ff \
  --line-color 00000000 \
  --text-color ebdbb2ff \
  --fade-in 0.3

