#!/usr/bin/env bash
# Runs every Chiip test suite, several at a time, and prints a summary table.
#
#     bash tools/run_tests.sh                  # all forty-five suites (about 1.5 minutes)
#     bash tools/run_tests.sh round ui         # only the named suites (movement weapon bot
#                                              # round tactics ui settings match bomb respawn
#                                              # sound maps crew class zone perf rotation arsenal gear guns grenade economy botgear kit range layout holds
#                                              # net netplay netjoin netstress netrespawn netarsenal release qa netsec stats statsrec aim spray access wallbang squad debug scheme)
#     GODOT=/path/to/Godot bash tools/run_tests.sh   # another Godot binary
#     JOBS=1 bash tools/run_tests.sh           # one suite at a time (as before M16)
#
# Suites run in parallel (M16, D-222): JOBS headless Godot processes at once, half the CPU
# count and at most 6 unless JOBS says otherwise, the longest suites first. `perf` runs alone
# at the end (it times the CPU). Each suite has its own log, its own user:// and its own
# block of network ports (CHIIP_TEST_PORT, read by tests/net_harness.gd), so they can't collide.
#
# Each suite is a headless Godot run of tests/<name>_test.tscn at 128 fixed fps
# with its own --quit-after safety net (macOS has no `timeout` command; a script
# error can leave Godot running forever). A suite counts as failed when it
# prints a FAIL line, no PASS line (a parse error makes a suite exit with code 0
# and print nothing, which looks like a pass), a "SCRIPT ERROR", never reaches
# its final "All checks passed." line (the safety net ended it), or exits with a
# non-zero code. A plain "ERROR:" line does not count: the settings suite prints
# one expected "ConfigFile parse error" from its unreadable-file check.
#
# Exit code: the number of failed suites (0 = everything passed; 64 = unknown
# suite name, 127 = no Godot binary). Each suite's full output is kept in
# ${TMPDIR:-/tmp}/chiip-tests/<name>.log until the next run. Each suite gets an empty user://
# folder of its own, deleted at the end (HOME points at a temporary folder). Needs only bash 3.2
# and the Godot binary; it never runs --import and never touches git.

GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
PROJECT="$(cd "$(dirname "$0")/.." && pwd)"
LOG_DIR="${TMPDIR:-/tmp}"
LOG_DIR="${LOG_DIR%/}/chiip-tests"

# name:frames for --quit-after, the safety net. Every suite finishes in at most a
# third of its frames (the match needs about 65000 of its 200000); a headless run
# at 128 fixed fps goes through roughly 3500 frames a second.
SUITES="movement:60000 weapon:60000 bot:100000 round:200000 tactics:200000 ui:60000 settings:60000 match:200000 bomb:100000 respawn:100000 sound:20000 maps:400000 crew:60000 class:200000 zone:60000 perf:100000 rotation:60000 arsenal:60000 gear:60000 guns:60000 grenade:60000 economy:100000 botgear:100000 kit:60000 range:60000 layout:60000 holds:100000 net:60000 netplay:200000 netjoin:200000 netstress:300000 netrespawn:200000 netarsenal:200000 release:60000 qa:200000 netsec:200000 stats:60000 statsrec:200000 aim:100000 spray:100000 access:60000 wallbang:60000 squad:200000 debug:100000 ffa:200000 killcam:120000 browser:60000 chat:60000 vote:60000 scheme:100000"

if [ ! -x "$GODOT" ]; then
	echo "Godot not found at $GODOT (set GODOT=/path/to/Godot)" >&2
	exit 127
fi

# Which suites to run: the arguments, or all of them.
wanted="$*"
if [ -n "$wanted" ]; then
	for name in $wanted; do
		case " $SUITES " in
			*" $name:"*) ;;
			*) echo "Unknown suite '$name'. Suites:$(for s in $SUITES; do printf ' %s' "${s%%:*}"; done)" >&2; exit 64 ;;
		esac
	done
fi

mkdir -p "$LOG_DIR"
cd "$PROJECT" || exit 64

# Every suite runs with a home folder of its own (macOS and Linux put user:// under $HOME), so its
# user:// (settings, stats, logs) starts empty and is never the player's or another worktree's
# (M16: a game or a test elsewhere on the computer could change a shared file mid-run).
RUN_HOME="$(mktemp -d "${TMPDIR:-/tmp}/chiip-home.XXXXXX")" || exit 64
trap 'rm -rf "$RUN_HOME"' EXIT
trap 'kill $(jobs -p) 2>/dev/null; exit 130' INT TERM

# How many suites run at once.
if [ -z "${JOBS:-}" ]; then
	cpus="$(sysctl -n hw.ncpu 2>/dev/null || nproc 2>/dev/null || echo 4)"
	JOBS=$((cpus / 2))
	[ "$JOBS" -gt 6 ] && JOBS=6
fi
[ "$JOBS" -lt 1 ] && JOBS=1
# Suites that run alone, after the others: they measure time.
ALONE="perf"
# The longest suites, started first so they don't finish last (the rest follow by their frames).
FIRST="maps netstress qa match layout netplay tactics"

# Runs one suite and judges it; writes "<status> <pass> <fail> <seconds> <reasons>" to
# <name>.result next to its log. Arguments: name, frames, port block.
run_suite() {
	local name="$1" frames="$2" port="$3" log="$LOG_DIR/$1.log" start=$SECONDS code pass fail reasons status
	mkdir -p "$RUN_HOME/$name"
	HOME="$RUN_HOME/$name" CHIIP_TEST_PORT="$port" "$GODOT" --headless --path "$PROJECT" --fixed-fps 128 \
			--quit-after "$frames" "res://tests/${name}_test.tscn" >"$log" 2>&1
	code=$?
	pass=$(grep -c '^PASS' "$log")
	fail=$(grep -c '^FAIL' "$log")
	reasons=""
	if [ "$fail" -gt 0 ]; then reasons="$reasons; $fail FAIL line(s)"; fi
	if [ "$pass" -eq 0 ]; then reasons="$reasons; no PASS lines"; fi
	if grep -q 'SCRIPT ERROR' "$log"; then reasons="$reasons; SCRIPT ERROR (see log)"; fi
	if ! grep -q 'All checks passed\.\|check(s) FAILED\.' "$log"; then reasons="$reasons; never finished (hit --quit-after $frames?)"; fi
	if [ "$code" -ne 0 ] && [ "$fail" -eq 0 ]; then reasons="$reasons; exit code $code"; fi
	if [ -z "$reasons" ]; then status="PASS"; else status="FAIL"; fi
	printf '%s %d %d %d %s\n' "$status" "$pass" "$fail" $((SECONDS - start)) "${reasons#; }" > "$LOG_DIR/$name.result"
	printf '%-10s %s (%d s)\n' "$name" "$status" $((SECONDS - start)) >&2
}

# The suites to run, each with its port block (30000 + 10 per place in SUITES), longest first
# (the safety net's frames say how long a suite is).
selected=""
index=0
for entry in $SUITES; do
	name="${entry%%:*}"
	index=$((index + 1))
	if [ -n "$wanted" ]; then
		case " $wanted " in
			*" $name "*) ;;
			*) continue ;;
		esac
	fi
	rm -f "$LOG_DIR/$name.result"
	selected="$selected $entry:$((30000 + index * 10))"
done
ordered=""
for name in $FIRST; do
	for entry in $selected; do
		[ "${entry%%:*}" = "$name" ] && ordered="$ordered $entry"
	done
done
for entry in $(printf '%s\n' $selected | sort -t: -k2,2nr); do
	case " $FIRST " in *" ${entry%%:*} "*) ;; *) ordered="$ordered $entry" ;; esac
done

started=$SECONDS
echo "Running $(printf '%s\n' $selected | grep -c .) suite(s), $JOBS at a time ..." >&2
for entry in $ordered; do
	name="${entry%%:*}"
	case " $ALONE " in *" $name "*) continue ;; esac
	while [ "$(jobs -pr | wc -l)" -ge "$JOBS" ]; do sleep 0.2; done
	rest="${entry#*:}"
	run_suite "$name" "${rest%%:*}" "${rest##*:}" &
done
wait
for entry in $ordered; do
	name="${entry%%:*}"
	case " $ALONE " in *" $name "*) ;; *) continue ;; esac
	rest="${entry#*:}"
	run_suite "$name" "${rest%%:*}" "${rest##*:}"
done

rows=""
problems=""
failed_suites=0
total_pass=0
total_fail=0
total_seconds=0
for entry in $SUITES; do
	name="${entry%%:*}"
	[ -f "$LOG_DIR/$name.result" ] || continue
	read -r status pass fail seconds reasons < "$LOG_DIR/$name.result"
	if [ "$status" != "PASS" ]; then
		failed_suites=$((failed_suites + 1))
		problems="$problems  $name: $reasons -> $LOG_DIR/$name.log
"
	fi
	rows="$rows$(printf '%-10s %5d %5d  %-6s %5d' "$name" "$pass" "$fail" "$status" "$seconds")
"
	total_pass=$((total_pass + pass))
	total_fail=$((total_fail + fail))
	total_seconds=$((total_seconds + seconds))
done

echo
printf '%-10s %5s %5s  %-6s %5s\n' "suite" "pass" "fail" "status" "sec"
printf '%-10s %5s %5s  %-6s %5s\n' "-----" "----" "----" "------" "---"
printf '%s' "$rows"
printf '%-10s %5s %5s  %-6s %5s\n' "-----" "----" "----" "------" "---"
if [ "$failed_suites" -eq 0 ]; then overall="PASS"; else overall="FAIL"; fi
printf '%-10s %5d %5d  %-6s %5d\n' "total" "$total_pass" "$total_fail" "$overall" "$total_seconds"
echo "($JOBS at a time: $((SECONDS - started)) s on the clock)"
if [ -n "$problems" ]; then
	echo
	echo "Problems:"
	printf '%s' "$problems"
fi
exit "$failed_suites"
