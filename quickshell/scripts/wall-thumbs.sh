#!/bin/bash
# Build 400x250 thumbnails for ~/wallpapers into ~/.cache/quickshell/wall-thumbs.
# Only missing or outdated thumbnails are (re)built, so it is cheap to run often.
src="$HOME/wallpapers"
out="$HOME/.cache/quickshell/wall-thumbs"
mkdir -p "$out"

find "$src" -maxdepth 1 -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) -print0 |
    while IFS= read -r -d '' f; do
        t="$out/$(basename "$f").jpg"
        [[ -f "$t" && "$t" -nt "$f" ]] || printf '%s\0' "$f"
    done |
    xargs -0 -r -P "$(nproc)" -I{} sh -c 'magick -quiet "$1[0]" -thumbnail 400x250^ -gravity center -extent 400x250 -quality 82 "$2/$(basename "$1").jpg"' _ {} "$out"
