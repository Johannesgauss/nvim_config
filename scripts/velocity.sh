#!/usr/bin/env bash
# ==============================================================================
# Host Input & Terminal Velocity Manager (velocity)
# ==============================================================================
# Standalone script to switch keyboard repeat rate and terminal cursor velocity
# across Niri, Kitty, Alacritty, Ghostty, and Foot without coupling Neovim to
# desktop/compositor dotfiles.
#
# Usage:
#   velocity 0 | default                  -> Niri/Kitty stock defaults (250ms, 50/s)
#   velocity 1 | fast                     -> Fast preset (175ms, 95/s, decay 0.04 0.12)
#   velocity 2 | custom [delay] [rate]    -> Custom preset (default: 190ms, 70/s)
#   velocity status                       -> Show active Niri & Kitty velocity settings
# ==============================================================================
set -euo pipefail

NIRI_CONF="${HOME}/.config/niri/config.d/10-input-and-cursor.kdl"
KITTY_CONF="${HOME}/.config/kitty/kitty.conf"
ALACRITTY_CONF="${HOME}/.config/alacritty/alacritty.toml"
GHOSTTY_CONF="${HOME}/.config/ghostty/config"
FOOT_CONF="${HOME}/.config/foot/foot.ini"

CUSTOM_DELAY=190
CUSTOM_RATE=70
CUSTOM_TRAIL=1
CUSTOM_DECAY="0.04 0.12"

show_status() {
    echo "=== Host Velocity Status ==="
    if [[ -f "$NIRI_CONF" ]]; then
        echo "[Niri]  $(grep -E 'repeat-(delay|rate)' "$NIRI_CONF" | xargs)"
    fi
    if [[ -f "$KITTY_CONF" ]]; then
        echo "[Kitty] $(grep -E '^(cursor_trail|repaint_delay|input_delay)' "$KITTY_CONF" | tr '\n' ' ')"
        echo ""
    fi
}

apply_niri() {
    local delay="$1"
    local rate="$2"
    if [[ -f "$NIRI_CONF" ]]; then
        sed -i -E \
            -e "s/(repeat-delay[[:space:]]+)[0-9]+/\1${delay}/" \
            -e "s/(repeat-rate[[:space:]]+)[0-9]+/\1${rate}/" \
            "$NIRI_CONF"
        echo "[Niri]  repeat-delay=${delay}ms, repeat-rate=${rate}/s (live reloaded)"
    fi
}

apply_kitty() {
    local trail="$1"
    local decay="$2"
    if [[ -f "$KITTY_CONF" ]]; then
        sed -i -E "s/^cursor_trail[[:space:]]+[0-9]+/cursor_trail ${trail}/" "$KITTY_CONF"
        if grep -qE "^cursor_trail_decay[[:space:]]+" "$KITTY_CONF"; then
            sed -i -E "s/^cursor_trail_decay[[:space:]]+.*/cursor_trail_decay ${decay}/" "$KITTY_CONF"
        else
            sed -i "/^cursor_trail[[:space:]]/a cursor_trail_decay ${decay}" "$KITTY_CONF"
        fi
        pkill -USR1 -x kitty 2>/dev/null || true
        echo "[Kitty] cursor_trail=${trail}, cursor_trail_decay='${decay}' (SIGUSR1 sent)"
    fi
}

apply_other_terminals() {
    # Hooks for Alacritty / Ghostty / Foot when present
    if [[ -f "$GHOSTTY_CONF" ]]; then
        pkill -USR2 -x ghostty 2>/dev/null || true
    fi
}

MODE="${1:-status}"

case "$MODE" in
    0|default)
        apply_niri 250 50
        apply_kitty 1 "0.1 0.4"
        apply_other_terminals
        ;;
    1|fast)
        apply_niri 175 95
        apply_kitty 1 "0.04 0.12"
        apply_other_terminals
        ;;
    2|custom)
        DELAY="${2:-$CUSTOM_DELAY}"
        RATE="${3:-$CUSTOM_RATE}"
        TRAIL="${4:-$CUSTOM_TRAIL}"
        DECAY="${5:-$CUSTOM_DECAY}"
        apply_niri "$DELAY" "$RATE"
        apply_kitty "$TRAIL" "$DECAY"
        apply_other_terminals
        ;;
    status|-s|--status)
        show_status
        ;;
    *)
        echo "Usage: velocity {0|default | 1|fast | 2|custom [delay] [rate] | status}" >&2
        exit 1
        ;;
esac
