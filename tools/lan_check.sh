#!/usr/bin/env bash
# Two (then three) real game processes play one online match on this computer (M12, D-178):
# the host, a first friend who joins and leaves, and a second friend who joins the running match.
#
#     bash tools/lan_check.sh                  # joins the host at this computer's LAN address
#     bash tools/lan_check.sh 127.0.0.1 28800  # another address and port
#     GAME=builds/macos/Chiip.app/Contents/MacOS/Chiip bash tools/lan_check.sh   # an exported build
#                                              # (tools/check_release.sh does this, M16)
#
# It runs headless and takes about a minute. The friends join through a real network address, not
# in-process like the netplay suites, so it is what two computers do, minus the network cable (and
# Tailscale: a Tailscale address is just another network interface). Checks, from the games' own
# "Chiip online" log lines: the match starts with the first friend loaded, the first friend is
# welcomed, the second friend is welcomed into the running match after the first left, and no game
# printed a SCRIPT ERROR. Exit code = the number of failed checks. Logs: ${TMPDIR:-/tmp}/chiip-lan/.
# Each game runs with a home folder of its own (an empty user://, deleted at the end), so none of
# them reads or writes your settings, stats or logs.

GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
PROJECT="$(cd "$(dirname "$0")/.." && pwd)"
ADDRESS="${1:-$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || hostname -I 2>/dev/null | cut -d' ' -f1)}"
ADDRESS="${ADDRESS:-127.0.0.1}"
PORT="${2:-28791}"
LOGS="${TMPDIR:-/tmp}"
LOGS="${LOGS%/}/chiip-lan"

if [ ! -x "$GODOT" ]; then
	echo "Godot not found at $GODOT (set GODOT=/path/to/Godot)" >&2
	exit 127
fi
mkdir -p "$LOGS"
cd "$PROJECT" || exit 64
rm -f "$LOGS"/*.log
HOMES="$(mktemp -d "${TMPDIR:-/tmp}/chiip-lan-home.XXXXXX")" || exit 64
trap 'rm -rf "$HOMES"' EXIT
# The game: an exported build ($GAME), or this project in the editor's binary.
if [ -n "${GAME:-}" ]; then
	GAME_COMMAND=("$GAME")
else
	GAME_COMMAND=("$GODOT" --path .)
fi

run() { # name, frames, extra game arguments...
	local name="$1" frames="$2"
	shift 2
	mkdir -p "$HOMES/$name"
	HOME="$HOMES/$name" "${GAME_COMMAND[@]}" --headless --verbose --quit-after "$frames" -- --no-settings --name "$name" --port "$PORT" "$@" > "$LOGS/$name.log" 2>&1
}

echo "Host on port $PORT, friends join at $ADDRESS ..."
run Host 8000 --host --start 2 &
host_pid=$!
sleep 6
run Ana 2200 --join "$ADDRESS"
echo "Ana left, Bob joins the running match ..."
sleep 3
run Bob 1800 --join "$ADDRESS"
wait "$host_pid"

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
has() { grep -q "$2" "$LOGS/$1.log"; }
no_script_errors() { ! grep -q "SCRIPT ERROR" "$LOGS"/*.log; }

check "The host started the match with the first friend loaded" has Host "Chiip online: the match started with .* 1 friend(s) loaded"
check "Ana joined and was welcomed" has Ana "Chiip online: welcomed as Ana"
check "Bob joined the running match after Ana left and was welcomed" has Bob "Chiip online: welcomed as Bob"
check "No game printed a SCRIPT ERROR" no_script_errors

echo "$failed check(s) failed. Logs in $LOGS"
exit "$failed"
