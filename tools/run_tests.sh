#!/usr/bin/env bash
# Runs every Chiip test suite, one at a time, and prints a summary table.
#
#     bash tools/run_tests.sh                  # all thirty-one suites
#     bash tools/run_tests.sh round ui         # only the named suites (movement weapon bot
#                                              # round tactics ui settings match bomb respawn
#                                              # sound maps crew class zone perf rotation arsenal gear guns grenade economy botgear kit range
#                                              # net netplay netjoin netstress netrespawn netarsenal)
#     GODOT=/path/to/Godot bash tools/run_tests.sh   # another Godot binary
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
# ${TMPDIR:-/tmp}/chiip-tests/<name>.log until the next run. Needs only bash 3.2
# and the Godot binary; it never runs --import and never touches git.

GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
PROJECT="$(cd "$(dirname "$0")/.." && pwd)"
LOG_DIR="${TMPDIR:-/tmp}"
LOG_DIR="${LOG_DIR%/}/chiip-tests"

# name:frames for --quit-after, the safety net. Every suite finishes in at most a
# third of its frames (the match needs about 65000 of its 200000); a headless run
# at 128 fixed fps goes through roughly 3500 frames a second.
SUITES="movement:60000 weapon:60000 bot:100000 round:200000 tactics:200000 ui:60000 settings:60000 match:200000 bomb:100000 respawn:100000 sound:20000 maps:400000 crew:60000 class:200000 zone:60000 perf:100000 rotation:60000 arsenal:60000 gear:60000 guns:60000 grenade:60000 economy:100000 botgear:100000 kit:60000 range:60000 holds:100000 net:60000 netplay:200000 netjoin:200000 netstress:300000 netrespawn:200000 netarsenal:200000"

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

rows=""
problems=""
failed_suites=0
total_pass=0
total_fail=0
total_seconds=0

for entry in $SUITES; do
	name="${entry%%:*}"
	frames="${entry##*:}"
	if [ -n "$wanted" ]; then
		case " $wanted " in
			*" $name "*) ;;
			*) continue ;;
		esac
	fi
	log="$LOG_DIR/$name.log"
	printf 'Running %s ... ' "$name" >&2
	start=$SECONDS
	"$GODOT" --headless --path "$PROJECT" --fixed-fps 128 --quit-after "$frames" "res://tests/${name}_test.tscn" >"$log" 2>&1
	code=$?
	seconds=$((SECONDS - start))
	pass=$(grep -c '^PASS' "$log")
	fail=$(grep -c '^FAIL' "$log")
	reasons=""
	if [ "$fail" -gt 0 ]; then reasons="$reasons; $fail FAIL line(s)"; fi
	if [ "$pass" -eq 0 ]; then reasons="$reasons; no PASS lines"; fi
	if grep -q 'SCRIPT ERROR' "$log"; then reasons="$reasons; SCRIPT ERROR (see log)"; fi
	if ! grep -q 'All checks passed\.\|check(s) FAILED\.' "$log"; then reasons="$reasons; never finished (hit --quit-after $frames?)"; fi
	if [ "$code" -ne 0 ] && [ "$fail" -eq 0 ]; then reasons="$reasons; exit code $code"; fi
	if [ -z "$reasons" ]; then
		status="PASS"
	else
		status="FAIL"
		failed_suites=$((failed_suites + 1))
		problems="$problems  $name: ${reasons#; } -> $log
"
	fi
	printf '%s\n' "$status" >&2
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
if [ -n "$problems" ]; then
	echo
	echo "Problems:"
	printf '%s' "$problems"
fi
exit "$failed_suites"
