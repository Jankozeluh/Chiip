#!/usr/bin/env bash
# The release-build checks (M16, D-223): exports the three release builds and runs smoke checks on
# what was exported, because some bugs exist only there (v0.1.0 shipped with empty hit zones, D-159).
#
#     bash tools/check_release.sh                          # exports into a temporary folder,
#                                                          # checks, then deletes it
#     BUILDS=builds bash tools/check_release.sh            # exports into builds/ (the release
#                                                          # routine; tools/package_release.sh packs them)
#     SKIP_EXPORT=1 BUILDS=builds bash tools/check_release.sh   # checks builds you exported
#
# The checks, each printed as PASS or FAIL:
#   1. each of the three exports (the Windows, Linux and macOS presets) succeeds;
#   2. shooting hits in each build (tools/check_export.sh: the game's own --check-hits): the Mac app
#      itself, and the Windows and Linux builds' embedded game data with this Mac's Godot
#      (--main-pack; the game data is the part an export converts, the rest is Godot's own template);
#   3. a full round in the Mac app (--check-round, debug/round_check.gd: the bots walk, round 1
#      ends with a winner, round 2 starts);
#   4. a LAN join with the Mac app (tools/lan_check.sh with GAME=<the app>: a host and two friends
#      as three processes on 127.0.0.1);
#   5. chat with the Mac build's game data (tools/check_chat.gd, D-248: a friend's line with BBCode and a
#      direction mark reaches the host and back as plain text; an exported game ignores --script, so this
#      Mac's Godot runs the script on the build's pack).
# Exit code = the number of failed checks. About two minutes. Export builds only when the owner
# asks for them (CLAUDE.md). Every game runs with an empty user:// of its own. Logs:
# ${TMPDIR:-/tmp}/chiip-release-check/.

set -uo pipefail

PROJECT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
LOGS="${TMPDIR:-/tmp}"
LOGS="${LOGS%/}/chiip-release-check"
PORT="${PORT:-28795}"

if [ ! -x "$GODOT" ]; then
	echo "Godot not found at $GODOT (set GODOT=/path/to/Godot)" >&2
	exit 127
fi
cd "$PROJECT" || exit 64
mkdir -p "$LOGS"
rm -f "$LOGS"/*.log

if [ -n "${BUILDS:-}" ]; then
	mkdir -p "$BUILDS" && touch "$BUILDS/.gdignore"
	TEMP=""
else
	TEMP="$(mktemp -d "${TMPDIR:-/tmp}/chiip-release-builds.XXXXXX")" || exit 64
	BUILDS="$TEMP"
fi
HOMES="$(mktemp -d "${TMPDIR:-/tmp}/chiip-release-home.XXXXXX")" || exit 64
trap 'rm -rf "$HOMES" ${TEMP:+"$TEMP"}' EXIT

failed=0
check() { # description, command...
	local description="$1"
	shift
	if "$@"; then
		echo "PASS  $description"
	else
		echo "FAIL  $description"
		failed=$((failed + 1))
	fi
}

# 1. The exports.
export_one() { # preset, path inside $BUILDS
	mkdir -p "$(dirname "$BUILDS/$2")"
	"$GODOT" --headless --path "$PROJECT" --export-release "$1" "$BUILDS/$2" > "$LOGS/export-$1.log" 2>&1 && [ -e "$BUILDS/$2" ]
}
if [ -z "${SKIP_EXPORT:-}" ]; then
	echo "Exporting the three release builds into $BUILDS ..."
	check "The Windows build exports" export_one Windows windows/Chiip.exe
	check "The Linux build exports" export_one Linux linux/Chiip.x86_64
	check "The macOS build exports" export_one macOS macos/Chiip.app
fi
APP_BINARY="$BUILDS/macos/Chiip.app/Contents/MacOS/Chiip"

# 2. Shooting hits in each build.
hits() { # a log name, then APP=… or PACK=…
	local name="$1"
	shift
	env "$@" GODOT="$GODOT" bash tools/check_export.sh > "$LOGS/hits-$name.log" 2>&1
}
check "Shooting hits in the macOS build (--check-hits)" hits macos APP="$BUILDS/macos/Chiip.app"
check "Shooting hits with the Windows build's game data (--main-pack)" hits windows PACK="$BUILDS/windows/Chiip.exe"
check "Shooting hits with the Linux build's game data (--main-pack)" hits linux PACK="$BUILDS/linux/Chiip.x86_64"

# 3. A full round in the Mac app.
round() {
	mkdir -p "$HOMES/round"
	HOME="$HOMES/round" "$APP_BINARY" --headless --fixed-fps 128 --quit-after 30000 -- --no-settings --check-round \
			> "$LOGS/round.log" 2>&1 && grep -q "Chiip round check: PASS" "$LOGS/round.log"
}
check "A full round plays in the macOS build (--check-round)" round

# 4. A LAN join with the Mac app.
lan() {
	GAME="$APP_BINARY" TMPDIR="$LOGS" bash tools/lan_check.sh 127.0.0.1 "$PORT" > "$LOGS/lan.log" 2>&1
}
check "Two friends join a host over the network in the macOS build (tools/lan_check.sh)" lan

# 5. Chat, with the Mac build's game data (from a folder that is not the project, so only the pack is the game).
chat() {
	mkdir -p "$HOMES/chat" "$HOMES/chat-cwd"
	( cd "$HOMES/chat-cwd" && HOME="$HOMES/chat" "$GODOT" --headless --main-pack "$BUILDS/macos/Chiip.app/Contents/Resources/Chiip.pck" \
			--quit-after 4000 --script "$PROJECT/tools/check_chat.gd" > "$LOGS/chat.log" 2>&1 ) && grep -q "Chiip chat check: PASS" "$LOGS/chat.log"
}
check "Chat works with the macOS build's game data (tools/check_chat.gd)" chat

grep -h "Chiip hit check\|Chiip round check\|Chiip chat check" "$LOGS"/hits-*.log "$LOGS/round.log" "$LOGS/chat.log" 2>/dev/null | sed 's/^/      /'
grep -h "^FAIL" "$LOGS/lan.log" 2>/dev/null | sed 's/^/      lan: /'
echo "$failed check(s) failed. Logs in $LOGS"
exit "$failed"
