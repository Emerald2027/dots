#!/usr/bin/env bash
# hyde-mpris.sh — MPRIS metadata helper for Waybar/Hyprlock
# Supports: Spotify, MPD (via mpd-mpris bridge), and generic MPRIS players

THUMB=/tmp/hyde-mpris
THUMB_BLURRED=/tmp/hyde-mpris-blurred

if [ $# -eq 0 ]; then
    echo "Usage: $0 --title | --artist | --position | --length | --album | --source | --status"
    exit 1
fi

# ---------------------------------------------------------------------------
# Player detection — prefer Spotify, fall back to any active player
# ---------------------------------------------------------------------------
get_active_player() {
    # Try Spotify first
    if playerctl -l 2>/dev/null | grep -qi spotify; then
        echo "spotify"
        return
    fi
    # Then MPD (mpd-mpris exposes it as 'mpd')
    if playerctl -l 2>/dev/null | grep -qi mpd; then
        echo "mpd"
        return
    fi
    # Fall back to whatever playerctl picks as default
    local default
    default=$(playerctl -l 2>/dev/null | head -1)
    if [ -n "$default" ]; then
        echo "$default"
        return
    fi
    echo ""
}

PLAYER=$(get_active_player)

if [ -z "$PLAYER" ]; then
    echo ""
    exit 1
fi

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
get_metadata() {
    playerctl -p "$PLAYER" metadata --format "{{ $1 }}" 2>/dev/null
}

get_position() {
    playerctl -p "$PLAYER" position 2>/dev/null
}

convert_length() {
    local length=$1
    local seconds=$((length / 1000000))
    local minutes=$((seconds / 60))
    local remaining=$((seconds % 60))
    printf "%d:%02d min" "$minutes" "$remaining"
}

convert_position() {
    local position=$1
    local seconds=${position%.*}
    local minutes=$((seconds / 60))
    local remaining=$((seconds % 60))
    printf "%d:%02d" "$minutes" "$remaining"
}

# ---------------------------------------------------------------------------
# Album art fetching — handles https://, http://, and file:// URIs
# ---------------------------------------------------------------------------
fetch_thumb() {
    local artUrl
    artUrl=$(playerctl -p "$PLAYER" metadata --format '{{mpris:artUrl}}' 2>/dev/null)

    [ -z "$artUrl" ] && return 1

    # Skip re-fetch if URL hasn't changed
    [[ "$artUrl" == "$(cat "${THUMB}.inf" 2>/dev/null)" ]] && return 0

    printf "%s\n" "$artUrl" > "${THUMB}.inf"

    if [[ "$artUrl" == file://* ]]; then
        # Local file (MPD / rmpc)
        local filepath="${artUrl#file://}"
        # URL-decode the path (spaces encoded as %20, etc.)
        filepath=$(python3 -c "import urllib.parse,sys; print(urllib.parse.unquote(sys.argv[1]))" "$filepath" 2>/dev/null || echo "$filepath")
        magick "$filepath" -quality 50 "${THUMB}.png" 2>/dev/null || return 1
    elif [[ "$artUrl" == http* ]]; then
        # Remote URL (Spotify, etc.)
        curl -so "${THUMB}.png" "$artUrl" || return 1
        magick "${THUMB}.png" -quality 50 "${THUMB}.png"
    else
        return 1
    fi

    # Blurred wallpaper version for hyprlock
    magick "${THUMB}.png" \
        -blur 200x7 \
        -resize 1920x^ \
        -gravity center \
        -extent 1920x1080\! \
        "${THUMB_BLURRED}.png"

    pkill -USR2 hyprlock 2>/dev/null
}

# Run in background; clean up thumbs on failure
{ fetch_thumb || rm -f "${THUMB}.png" "${THUMB_BLURRED}.png" "${THUMB}.inf"; } &

# ---------------------------------------------------------------------------
# Source detection
# ---------------------------------------------------------------------------
get_source_info() {
    local trackid
    trackid=$(get_metadata "mpris:trackid")
    case "$PLAYER" in
        *spotify*) echo "Spotify " ;;
        *mpd*)     echo "MPD " ;;
        *)         echo "" ;;
    esac
}

# ---------------------------------------------------------------------------
# Argument dispatch
# ---------------------------------------------------------------------------
case "$1" in
--title)
    title=$(get_metadata "xesam:title")
    if [ -z "$title" ]; then
        echo ""
    else
        # Show first 20 chars then ellipsis if longer
        if [ ${#title} -gt 20 ]; then
            echo "${title:0:20}..."
        else
            echo "$title"
        fi
    fi
    ;;

--artist)
    artist=$(get_metadata "xesam:artist")
    if [ -z "$artist" ]; then
        echo ""
    else
        echo "${artist:0:25}"
    fi
    ;;

--position)
    position=$(get_position)
    length=$(get_metadata "mpris:length")
    if [ -z "$position" ] || [ -z "$length" ]; then
        echo ""
    else
        echo "$(convert_position "$position")/$(convert_length "$length")"
    fi
    ;;

--length)
    length=$(get_metadata "mpris:length")
    if [ -z "$length" ]; then
        echo ""
    else
        convert_length "$length"
    fi
    ;;

--status)
    status=$(playerctl -p "$PLAYER" status 2>/dev/null)
    case "$status" in
        Playing) echo "⏸" ;;
        Paused)  echo "▶" ;;
        *)       echo "" ;;
    esac
    ;;

--album)
    album=$(get_metadata "xesam:album")
    if [ -n "$album" ]; then
        echo "$album"
    else
        echo "No album"
    fi
    ;;

--source)
    get_source_info
    ;;

*)
    echo "Invalid option: $1"
    echo "Usage: $0 --title | --artist | --position | --length | --album | --source | --status"
    exit 1
    ;;
esac
