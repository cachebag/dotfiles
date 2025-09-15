#!/usr/bin/env bash
src="$HOME/.cache/wal/colors.json"
dst="$HOME/.cache/wal/colors-waybar.css"

jq -r '
  ".waybar-colors {\n" +
  "  background-color: \(.special.background);\n" +
  "  color: \(.special.foreground);\n" +
  "}\n" +
  "#clock { background-color: \(.colors.color2); }\n" +
  "#cpu { background-color: \(.colors.color3); }\n" +
  "#memory { background-color: \(.colors.color4); }"
' "$src" > "$dst"
