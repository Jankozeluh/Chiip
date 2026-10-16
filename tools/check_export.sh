#!/usr/bin/env bash
# Checks that shooting works in an exported release build (v0.1.1 hotfix, D-159): bullets must
# hurt a bot, and a bot's bullets the player. v0.1.0 shipped with every hit zone empty, which only
# an exported build showed.
#
#     bash tools/check_export.sh                       # exports a macOS release build into a
#                                                      # temporary folder, then checks it
#     APP=builds/macos/Chiip.app bash tools/check_export.sh   # checks a build you exported
#     PACK=builds/windows/Chiip.exe bash tools/check_export.sh # checks the Windows or Linux build's
#                                                      # game data (its embedded pack) with this
#                                                      # Mac's Godot (--main-pack, M16)
#
# It runs the game headless with `--check-hits` (debug/hit_check.gd: practice on the Shooting
# Range, an enemy bot 5 m ahead, one shot each way) and exits with its result: 0 when both shots
# hit and hurt. The temporary build is deleted afterwards; nothing goes into builds/. The game runs
# with a home folder of its own (an empty user://), so it never touches your settings or logs.
# tools/package_release.sh runs the same check on builds/macos before it packs a release.

set -euo pipefail

PROJECT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
TEMP=""

HOME_DIR="$(mktemp -d "${TMPDIR:-/tmp}/chiip-export-home.XXXXXX")"
trap 'rm -rf "$HOME_DIR" ${TEMP:+"$TEMP"}' EXIT

if [ -n "${PACK:-}" ]; then
	[ -f "$PACK" ] || { echo "No pack at $PACK" >&2; exit 66; }
	GAME_COMMAND=("$GODOT" --main-pack "$PACK")
elif [ -z "${APP:-}" ]; then
	TEMP="$(mktemp -d "${TMPDIR:-/tmp}/chiip-export-check.XXXXXX")"
	trap 'rm -rf "$HOME_DIR" "$TEMP"' EXIT
	APP="$TEMP/Chiip.app"
	echo "Exporting a macOS release build into $TEMP ..."
	"$GODOT" --headless --path "$PROJECT" --export-release "macOS" "$APP" >"$TEMP/export.log" 2>&1 || {
		echo "The export failed; see $TEMP/export.log" >&2
		trap 'rm -rf "$HOME_DIR"' EXIT
		exit 2
	}
fi
if [ -z "${PACK:-}" ]; then
	BINARY="$APP/Contents/MacOS/Chiip"
	if [ ! -x "$BINARY" ]; then
		echo "No game at $BINARY" >&2
		exit 66
	fi
	GAME_COMMAND=("$BINARY")
fi

set +e
OUTPUT="$(HOME="$HOME_DIR" "${GAME_COMMAND[@]}" --headless --quit-after 1500 -- --no-settings --check-hits 2>&1)"
CODE=$?
set -e
echo "$OUTPUT" | grep "Chiip hit check" || echo "Chiip hit check: no result (the game quit without one)"
if [ "$CODE" -ne 0 ] || ! echo "$OUTPUT" | grep -q "Chiip hit check: PASS"; then
	exit 1
fi
