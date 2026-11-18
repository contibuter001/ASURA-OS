#!/bin/sh
# First end-4 login for a user: give end-4's desktop what it expects to find in
# the home directory, without overwriting anything the user already has.
# Run by AsuraBridge.qml once end-4's config has loaded.
#
# 1. ~/.config/matugen/config.toml, the config end-4's switchwall.sh runs
#    matugen with (the shell's palette comes from it).
# 2. A palette: with none generated yet, run end-4's own switchwall.sh on the
#    user's ASURA wallpaper (or ASURA's first background), so the desktop starts
#    in the wallpaper's colours instead of end-4's placeholder purple.
set -u

HERE=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
SHELL_DIR=$(dirname "$HERE")
CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}"
STATE="${XDG_STATE_HOME:-$HOME/.local/state}"
LOG="$STATE/asura/end4-first-run.log"
mkdir -p "$STATE/asura"
exec >>"$LOG" 2>&1
echo "== $(date) first-run"

if [ ! -f "$CONFIG/matugen/config.toml" ]; then
	mkdir -p "$CONFIG/matugen"
	cp "$SHELL_DIR/matugen/config.toml" "$CONFIG/matugen/config.toml"
	echo "seeded $CONFIG/matugen/config.toml"
fi

if [ ! -s "$STATE/quickshell/user/generated/colors.json" ]; then
	if ! command -v matugen >/dev/null 2>&1; then
		echo "matugen is not installed; end-4 keeps its default palette (sudo xbps-install -S matugen)"
		exit 0
	fi
	wp=$(gsettings get org.asura.shell wallpaper-path 2>/dev/null | tr -d "'")
	if [ ! -f "$wp" ]; then
		for f in /usr/share/asura/backgrounds/*; do
			[ -f "$f" ] && { wp=$f; break; }
		done
	fi
	if [ -f "$wp" ]; then
		echo "generating the palette from $wp"
		bash "$SHELL_DIR/scripts/colors/switchwall.sh" --image "$wp"
	else
		echo "no wallpaper found; end-4 keeps its default palette"
	fi
fi
