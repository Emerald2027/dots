#!/bin/bash

# Wallpaper Switcher with Rofi and swww
# This script displays wallpapers from ~/Pictures/wallpapers/ in rofi and sets the selected one using swww

WALLPAPER_DIR="$HOME/Pictures/wallpapers"
PW16SCRIPT="$HOME/.config/themes/scripts/pywal16"

# Check if wallpaper directory exists
if [ ! -d "$WALLPAPER_DIR" ]; then
    notify-send "Wallpaper Switcher" "Error: $WALLPAPER_DIR does not exist" -u critical
    exit 1
fi

# Check if swww is installed
if ! command -v swww &> /dev/null; then
    notify-send "Wallpaper Switcher" "Error: swww is not installed" -u critical
    exit 1
fi

# Check if swww daemon is running, start it if not
if ! pgrep -x swww-daemon > /dev/null; then
    swww-daemon &
    sleep 1
fi

# Check if directory has any images
if [ -z "$(ls -A "$WALLPAPER_DIR" 2>/dev/null)" ]; then
    notify-send "Wallpaper Switcher" "Error: No wallpapers found in $WALLPAPER_DIR" -u critical
    exit 1
fi

# Get list of image files (common formats)
cd "$WALLPAPER_DIR" || exit 1
WALLPAPERS=$(find . -maxdepth 1 -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" -o -iname "*.bmp" -o -iname "*.gif" \) -printf "%f\n" | sort)

if [ -z "$WALLPAPERS" ]; then
    notify-send "Wallpaper Switcher" "No image files found in $WALLPAPER_DIR" -u critical
    exit 1
fi

# Show rofi menu and get selection with thumbnails
CACHE_DIR="$HOME/.cache/wallpaper-switcher"
mkdir -p "$CACHE_DIR"

# Generate thumbnails if they don't exist
while IFS= read -r wallpaper; do
    THUMB_PATH="$CACHE_DIR/${wallpaper}.thumb.jpg"
    if [ ! -f "$THUMB_PATH" ]; then
        if command -v convert &> /dev/null; then
            convert "$WALLPAPER_DIR/$wallpaper" -thumbnail 960x600^ -gravity center -extent 960x600 "$THUMB_PATH" 2>/dev/null
        fi
    fi
done <<< "$WALLPAPERS"

# Create list with thumbnail paths for rofi
MENU=""
while IFS= read -r wallpaper; do
    THUMB_PATH="$CACHE_DIR/${wallpaper}.thumb.jpg"
    if [ -f "$THUMB_PATH" ]; then
        MENU+="${wallpaper}\x00icon\x1f${THUMB_PATH}\n"
    else
        MENU+="${wallpaper}\n"
    fi
done <<< "$WALLPAPERS"

# Show rofi menu with image previews
SELECTED=$(echo -e "$MENU" | rofi -dmenu -i -p "Select Wallpaper" \
    -show-icons \
    -theme-str 'window {width: 60%;}' \
    -theme-str 'listview {columns: 3; lines: 4;}' \
    -theme-str 'element {orientation: vertical; padding: 10px;}' \
    -theme-str 'element-icon {size: 12em;}' \
    -theme-str 'element-text {horizontal-align: 0.5;}')
# Exit if nothing selected
if [ -z "$SELECTED" ]; then
    exit 0
fi

WALLPAPER_PATH="$WALLPAPER_DIR/$SELECTED"


# Generate colors with pywal
wal -i "$WALLPAPER_PATH" -n --backend colorz -o $PW16SCRIPT
#ln -sf "$WALLPAPER_PATH" $TEMPIMG > /dev/null 2>&1

# Set wallpaper using swww
swww img "$WALLPAPER_PATH" --transition-type wipe --transition-fps 60 --transition-duration 2

# Send notification
notify-send "Wallpaper Changed" "$SELECTED_FILE" -i "$WALLPAPER_PATH"

ln -sf $WALLPAPER_PATH ~/.config/themes/current_wallpaper.jpg

cat > ~/.config/themes/current_wallpaper.txt << EOF
$WALLPAPER_PATH
EOF
