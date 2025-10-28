#!/bin/bash

# Convert pywal colors from colors-waybar.css to Hyprland format
# Source: ~/.cache/wal/colors-waybar.css
# Output: ~/.cache/wal/colors-hyprland.conf

WAYBAR_COLORS="$HOME/.cache/wal/colors-waybar.css"
HYPRLAND_COLORS="$HOME/.cache/wal/colors-hyprland.conf"
WAL_DIR="$HOME/.cache/wal"

# Create .cache/wal directory if it doesn't exist
mkdir -p "$WAL_DIR"

# If waybar colors don't exist, create default ones
if [ ! -f "$WAYBAR_COLORS" ]; then
    echo "Creating default pywal colors..."
    cat > "$WAYBAR_COLORS" << 'EOF'
@define-color foreground #adb4b8;
@define-color background #121313;
@define-color cursor #adb4b8;

@define-color color0 #121313;
@define-color color1 #51534D;
@define-color color2 #5C625C;
@define-color color3 #696150;
@define-color color4 #5E6464;
@define-color color5 #646D6F;
@define-color color6 #8F775C;
@define-color color7 #adb4b8;
@define-color color8 #797d80;
@define-color color9 #51534D;
@define-color color10 #5C625C;
@define-color color11 #696150;
@define-color color12 #5E6464;
@define-color color13 #646D6F;
@define-color color14 #8F775C;
@define-color color15 #adb4b8;
EOF
fi

# Read colors from waybar CSS and convert
echo "# Generated from pywal colors" > "$HYPRLAND_COLORS"
echo "" >> "$HYPRLAND_COLORS"

# Parse the CSS file and extract colors
while IFS= read -r line; do
    if [[ $line =~ @define-color[[:space:]]+([a-zA-Z0-9]+)[[:space:]]+\#([0-9a-fA-F]+) ]]; then
        var_name="${BASH_REMATCH[1]}"
        hex_color="${BASH_REMATCH[2]}"
        
        # Convert to Hyprland format
        if [[ $var_name == "foreground" ]]; then
            echo "\$foregroundCol = 0xff$hex_color" >> "$HYPRLAND_COLORS"
        elif [[ $var_name == "background" ]]; then
            echo "\$backgroundCol = 0xff$hex_color" >> "$HYPRLAND_COLORS"
        elif [[ $var_name =~ color([0-9]+) ]]; then
            echo "\$${var_name} = 0xff$hex_color" >> "$HYPRLAND_COLORS"
        fi
    fi
done < "$WAYBAR_COLORS"

echo "Converted pywal colors to Hyprland format: $HYPRLAND_COLORS"
