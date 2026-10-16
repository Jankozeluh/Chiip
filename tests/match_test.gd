extends Node
## Automated full-match check (M5 task 13). Run without a window:
##
##     Godot --headless --path . --fixed-fps 128 --quit-after 200000 res://tests/match_test.tscn
##
## Plays one whole 3v3 match, first to 5, through the real game scene: the test
## starts main.tscn the way the main menu's Start button does (a [GameLaunch]
## description) on the test map, with the real HUD, scoreboard and match-end
## screen. You stand still (no keyboard) and die or survive like anyone else; the
## other five are bots on Normal. Freeze time and the round-end pause are 1 s
## and a round lasts up to 90 s, so most rounds are decided by fighting. The
## round manager's generator and every bot's brain and weapon are seeded, so
## every run plays the same match.
##
## When the match is over it checks the whole of it: [signal
## RoundManager.match_ended] came exactly once, the winner has exactly
## [member MatchSettings.rounds_to_win] rounds and the loser fewer, the number of
## rounds is possible (5 to 9), the sides swapped exactly once, after round 4,
## every round has one winner and a reason, the winner is the right one for that
## reason (the attackers when the defenders are wiped out, the defenders for
## everything else), the stats add up (kills, deaths, damage, no more deaths in a
## round than players), the round HUD shows the final score, the match-end
## screen is up with Victory or Defeat for your team, and everyone stays frozen.
## Before the checks it prints one informational line per round (who won, why,
## how long it was live); those lines are not checks. Never touches the real
## [code]user://settings.cfg[/code] (main.gd's [code]load_settings[/code] is off;
## the last check compares its checksum). Quits with the number of failed checks
## as the exit code (0 means everything passed).

const MAIN_SCENE := preload("res://main.tscn")
const TEAM_SIZE := 3
const ROUNDS_TO_WIN := 5
const FREEZE_TIME := 1.0
## Long enough that most rounds are decided by fighting (a defender hold lasts the whole round).
const ROUND_TIME := 90.0
const ROUND_END_TIME := 1.0
## Seeds: the round manager's generator, and (plus the participant's number) each bot's brain and each weapon.
const ROUND_SEED := 2026
## Extra seconds on top of nine full rounds before the test gives up waiting for the match to end.
const SLACK_SECONDS := 10.0

var _main: Node
var _rounds: RoundManager
var _player: Character
var _failures: int = 0
## Physics ticks since the test started, and the tick the current round went live.
var _tick: int = 0
var _live_start_tick: int = 0
## One entry per round, in order: number, attacker (the attacking team that round),
## winner (-1 until the round ends), reason, live (seconds), ended (how many
## round_ended signals came), alive (players left per team at the end), score
## (score after the round).
var _log: Array[Dictionary] = []
## One entry per death: round, victim, killer (may be null), victim_team, killer_team (-1 for none).
var _deaths: Array[Dictionary] = []
## The round number at every sides_swapped signal.
var _swaps: Array[int] = []
## The winner of every match_ended signal.
var _match_ends: Array[int] = []
## The MD5 of the real settings file when the test started ("" if there was none).
var _real_file_md5: String = ""


func _ready() -> void:
	_real_file_md5 = _settings_md5()
	await _start_match()
	var budget := roundi((2 * ROUNDS_TO_WIN - 1) * (FREEZE_TIME + ROUND_TIME + ROUND_END_TIME) + SLACK_SECONDS) * Engine.physics_ticks_per_second
	while _match_ends.is_empty() and _tick < budget:
		await get_tree().physics_frame
	_print_summary()
	if _match_ends.is_empty():
		_check("The match ends", false, "no match_ended after %d s of game time (round %d, score %s)" % [
				_tick / Engine.physics_ticks_per_second, _rounds.round_number, _rounds.score])
	else:
		await _test_match()
	if _failures == 0:
		print("\nAll checks passed.")
	else:
		print("\n%d check(s) FAILED." % _failures)
	get_tree().quit(_failures)


func _physics_process(_delta: float) -> void:
	_tick += 1


## Starts the match the way the main menu's Start does, listens to the round
## manager, and seeds and silences everyone once they have joined.
func _start_match() -> void:
	var rules := MatchSettings.new()
	rules.team_size = TEAM_SIZE
	rules.enemy_team_size = TEAM_SIZE
	rules.rounds_to_win = ROUNDS_TO_WIN
	rules.freeze_time = FREEZE_TIME
	rules.round_time = ROUND_TIME
	rules.round_end_time = ROUND_END_TIME
	GameLaunch.start_match(Settings.DEFAULT_MAP, rules)
	_main = MAIN_SCENE.instantiate()
	# Never read or write the player's real settings file.
	_main.load_settings = false
	add_child(_main)
	_player = _main.get_map().get_node("Player") as Character
	_rounds = _main.get_map().get_node("RoundManager") as RoundManager
	# The match starts at the end of this frame, so the seed and the signals are in time.
	_rounds.rng.seed = ROUND_SEED
	_rounds.round_started.connect(_on_round_started)
	_rounds.phase_changed.connect(_on_phase_changed)
	_rounds.round_ended.connect(_on_round_ended)
	_rounds.sides_swapped.connect(func() -> void: _swaps.append(_rounds.round_number))
	_rounds.match_ended.connect(func(winner: int) -> void: _match_ends.append(winner))
	_rounds.character_killed.connect(_on_character_killed)
	for i in 3:
		await get_tree().physics_frame
	# Freeze time of round 1 is running: nobody has fired a shot or made a random choice that counts yet.
	var participants := _rounds.get_participants()
	for i in participants.size():
		var character := participants[i]
		_silence(character)
		character.weapon.rng.seed = i + 1
		var brain := character.get_node_or_null("BotController") as BotController
		if brain != null:
			brain.rng.seed = i + 1


func _on_round_started(round_number: int) -> void:
	_log.append({
		"number": round_number, "attacker": _rounds.attacking_team, "winner": -1, "reason": -1,
		"live": 0.0, "ended": 0, "alive": [0, 0], "score": [0, 0],
	})


func _on_phase_changed(phase: RoundManager.Phase) -> void:
	if phase == RoundManager.Phase.LIVE:
		_live_start_tick = _tick


func _on_round_ended(winner: int, reason: RoundManager.EndReason) -> void:
	var entry: Dictionary = _log.back()
	entry["winner"] = winner
	entry["reason"] = reason
	entry["live"] = float(_tick - _live_start_tick) / Engine.physics_ticks_per_second
	entry["ended"] += 1
	entry["alive"] = [_rounds.get_alive_count(0), _rounds.get_alive_count(1)]
	entry["score"] = [_rounds.score[0], _rounds.score[1]]


func _on_character_killed(victim: Character, killer: Character, _headshot: bool) -> void:
	_deaths.append({
		"round": _rounds.round_number, "victim": victim, "killer": killer, "victim_team": victim.team,
		"killer_team": killer.team if killer != null else -1,
	})


# --- The report (information, not checks) ---


## One line per round: who attacked, who won and why, how long it was live, who was left.
func _print_summary() -> void:
	print("Match played on %s, first to %d, %dv%d, you are team %d (round time %.0f s, freeze %.0f s, end pause %.0f s):" % [
			Settings.DEFAULT_MAP, ROUNDS_TO_WIN, TEAM_SIZE, TEAM_SIZE, _player.team, ROUND_TIME, FREEZE_TIME, ROUND_END_TIME])
	for entry in _log:
		if entry["winner"] < 0:
			print("  round %d: team %d attacks, not finished" % [entry["number"], entry["attacker"]])
			continue
		var attacker: int = entry["attacker"]
		var winner: int = entry["winner"]
		var round_deaths := _deaths.filter(func(death: Dictionary) -> bool: return death["round"] == entry["number"]).size()
		print("  round %d: team %d attacks, team %d wins (%s) by %s, live %.1f s, left %d vs %d, %d deaths, score %d-%d" % [
				entry["number"], attacker, winner, "attackers" if winner == attacker else "defenders",
				_reason_name(entry["reason"]), entry["live"], entry["alive"][0], entry["alive"][1], round_deaths,
				entry["score"][0], entry["score"][1]])
	if not _match_ends.is_empty():
		print("  match over after %d rounds: team %d wins %d-%d, %.0f s of game time\n" % [
				_log.size(), _match_ends[0], _rounds.score[_match_ends[0]], _rounds.score[Teams.other(_match_ends[0])],
				float(_tick) / Engine.physics_ticks_per_second])


func _reason_name(reason: int) -> String:
	return "elimination" if reason == RoundManager.EndReason.ELIMINATION else ("time-out" if reason == RoundManager.EndReason.TIME else "?")


# --- Checks ---


func _test_match() -> void:
	_test_match_end_signal()
	_test_rounds_and_swap()
	_test_round_results()
	_test_stats()
	await _test_screens_and_freeze()
	_check("The real settings file was not touched", _settings_md5() == _real_file_md5,
			"checksum before %s, after %s" % [_real_file_md5, _settings_md5()])


func _test_match_end_signal() -> void:
	var winner: int = _match_ends[0] if not _match_ends.is_empty() else -1
	var wins := [0, 0]
	for entry in _log:
		if entry["winner"] >= 0:
			wins[entry["winner"]] += 1
	var loser := Teams.other(winner) if winner >= 0 else -1
	_check("match_ended came exactly once, and the manager agrees on the winner",
			_match_ends.size() == 1 and _rounds.winner == winner and _rounds.phase == RoundManager.Phase.MATCH_END,
			"match_ended %d time(s), winner %d, manager's winner %d, phase %s" % [
					_match_ends.size(), winner, _rounds.winner, RoundManager.Phase.keys()[_rounds.phase]])
	_check("The winner has exactly %d rounds and the loser fewer, as the score and the round results say" % ROUNDS_TO_WIN,
			winner >= 0 and _rounds.score[winner] == ROUNDS_TO_WIN and _rounds.score[loser] < ROUNDS_TO_WIN
					and wins == [_rounds.score[0], _rounds.score[1]],
			"score %d-%d, rounds won per the round_ended signals %s" % [_rounds.score[0], _rounds.score[1], wins])


func _test_rounds_and_swap() -> void:
	var rounds := _log.size()
	_check("The match took %d to %d rounds, one round_started and one round_ended for each" % [ROUNDS_TO_WIN, 2 * ROUNDS_TO_WIN - 1],
			rounds >= ROUNDS_TO_WIN and rounds <= 2 * ROUNDS_TO_WIN - 1 and _rounds.round_number == rounds
					and _log.all(func(entry: Dictionary) -> bool: return entry["ended"] == 1),
			"%d rounds, the manager is at round %d, round_ended counts %s" % [
					rounds, _rounds.round_number, _log.map(func(entry: Dictionary) -> int: return entry["ended"])])
	var first_attacker: int = _log[0]["attacker"] if not _log.is_empty() else -1
	var swap_after := ROUNDS_TO_WIN - 1
	var sides_ok := true
	for entry in _log:
		var expected := first_attacker if entry["number"] <= swap_after else Teams.other(first_attacker)
		sides_ok = sides_ok and entry["attacker"] == expected
	_check("The sides swapped exactly once, after round %d, and the teams kept their sides before and after" % swap_after,
			rounds > swap_after and _swaps == [swap_after] and sides_ok,
			"%d swap(s) after round(s) %s; attackers per round %s" % [
					_swaps.size(), _swaps, _log.map(func(entry: Dictionary) -> int: return entry["attacker"])])


## Every round has one winner and a valid reason, and the winner is the right one for it.
func _test_round_results() -> void:
	var valid := true
	var right := true
	var detail := ""
	for entry in _log:
		var winner: int = entry["winner"]
		var reason: int = entry["reason"]
		var attacker: int = entry["attacker"]
		var defender := Teams.other(attacker)
		var attackers_left: int = entry["alive"][attacker]
		var defenders_left: int = entry["alive"][defender]
		if winner < 0 or winner >= Teams.COUNT or not (reason == RoundManager.EndReason.ELIMINATION or reason == RoundManager.EndReason.TIME):
			valid = false
			detail += "round %d has winner %d and reason %d; " % [entry["number"], winner, reason]
			continue
		var expected: int
		var consistent: bool
		if reason == RoundManager.EndReason.ELIMINATION:
			# The attackers win by wiping the defenders out; a wiped-out attacking team (or both) loses.
			consistent = attackers_left == 0 or defenders_left == 0
			expected = attacker if (defenders_left == 0 and attackers_left > 0) else defender
		else:
			# Time ran out with both teams alive: the defenders hold.
			consistent = attackers_left > 0 and defenders_left > 0
			expected = defender
		if not consistent or winner != expected:
			right = false
			detail += "round %d: %s, team %d won, expected %d, left %d (attack) vs %d (defend); " % [
					entry["number"], _reason_name(reason), winner, expected, attackers_left, defenders_left]
	var eliminations := _log.filter(func(entry: Dictionary) -> bool: return entry["reason"] == RoundManager.EndReason.ELIMINATION).size()
	_check("Every round has a winner and a reason", valid and not _log.is_empty(),
			"%d rounds, %d by elimination, %d by time-out%s" % [_log.size(), eliminations, _log.size() - eliminations, "; " + detail if not valid else ""])
	_check("Every round went to the right team for its reason (the attackers only by eliminating the defenders, otherwise the defenders)",
			right, "all %d rounds as expected" % _log.size() if right else detail)


## The scoreboard numbers add up to the deaths that were announced.
func _test_stats() -> void:
	var participants := _rounds.get_participants()
	var kills := 0
	var deaths := 0
	var damage := 0.0
	var stats_ok := participants.size() == 2 * TEAM_SIZE
	var per_character_ok := true
	var detail := ""
	for character in participants:
		var stats := _rounds.get_stats(character)
		if stats == null:
			stats_ok = false
			continue
		kills += stats.kills
		deaths += stats.deaths
		damage += stats.damage
		var announced := _deaths.filter(func(death: Dictionary) -> bool: return death["victim"] == character).size()
		var credited := _deaths.filter(func(death: Dictionary) -> bool: return death["killer"] == character and death["killer_team"] != death["victim_team"]).size()
		if stats.deaths != announced or stats.kills != credited or stats.assists < 0:
			per_character_ok = false
			detail += "%s: %d deaths (%d announced), %d kills (%d credited); " % [character.name, stats.deaths, announced, stats.kills, credited]
	_check("Stats add up: 6 players, kills never exceed deaths, and each player's deaths and kills match the kill events",
			stats_ok and kills <= deaths and deaths == _deaths.size() and per_character_ok,
			"%d players, kills %d, deaths %d, kill events %d%s" % [participants.size(), kills, deaths, _deaths.size(), "; " + detail if not per_character_ok else ""])
	_check("The damage dealt covers every death (100 health each)", damage >= 100.0 * deaths - 0.01,
			"damage %.0f, deaths %d" % [damage, deaths])
	var too_many := ""
	for entry in _log:
		for team in Teams.COUNT:
			var team_deaths := _deaths.filter(func(death: Dictionary) -> bool: return death["round"] == entry["number"] and death["victim_team"] == team)
			var victims := {}
			for death in team_deaths:
				victims[death["victim"]] = true
			if team_deaths.size() > TEAM_SIZE or victims.size() != team_deaths.size():
				too_many += "round %d team %d: %d deaths of %d players; " % [entry["number"], team, team_deaths.size(), victims.size()]
	_check("In every round each team lost at most %d players, nobody died twice" % TEAM_SIZE, too_many.is_empty(),
			"deaths per round %s" % [_log.map(func(entry: Dictionary) -> int: return _deaths.filter(func(death: Dictionary) -> bool: return death["round"] == entry["number"]).size())]
			if too_many.is_empty() else too_many)


## The HUD and the match-end screen show the result, and nobody moves, fires or dies afterwards.
func _test_screens_and_freeze() -> void:
	var winner: int = _match_ends[0]
	var results_before := _log.size()
	var kills_before := _deaths.size()
	await get_tree().process_frame
	var you := Teams.viewer_team
	var them := Teams.other(you)
	var hud_yours := (_main.get_node("HUD/RoundHud/TopBar/YourBox/Margin/Content/Score") as Label).text
	var hud_theirs := (_main.get_node("HUD/RoundHud/TopBar/EnemyBox/Margin/Content/Score") as Label).text
	_check("The round HUD's score labels show the final score (yours on the left)",
			hud_yours == str(_rounds.score[you]) and hud_theirs == str(_rounds.score[them]) and you == _player.team,
			"HUD %s-%s, score %d-%d, you are team %d" % [hud_yours, hud_theirs, _rounds.score[you], _rounds.score[them], you])
	var screen := _main.get_node("MatchEndScreen") as MatchEndScreen
	var title := (screen.get_node("Panel/Margin/Content/Title") as Label).text
	var screen_yours := (screen.get_node("Panel/Margin/Content/Score/YourScore") as Label).text
	var screen_theirs := (screen.get_node("Panel/Margin/Content/Score/EnemyScore") as Label).text
	var expected_title := "Victory" if winner == you else "Defeat"
	_check("The match-end screen is up with %s and the final score" % expected_title,
			screen.visible and title == expected_title and screen_yours == str(_rounds.score[you]) and screen_theirs == str(_rounds.score[them]),
			"visible %s, title '%s', score %s-%s (expected %s, %d-%d)" % [
					screen.visible, title, screen_yours, screen_theirs, expected_title, _rounds.score[you], _rounds.score[them]])
	# Survivors may still be sliding to a stop when the match ends: let them settle, then watch for 1 s.
	await _wait_seconds(0.5)
	var before := _snapshot()
	await _wait_seconds(1.0)
	var after := _snapshot()
	var moved := 0.0
	var fired := false
	for character: Character in before:
		moved = maxf(moved, (after[character]["position"] as Vector3).distance_to(before[character]["position"]))
		fired = fired or after[character]["weapon"] != before[character]["weapon"] or after[character]["rounds"] < before[character]["rounds"]
	var all_frozen := _rounds.get_participants().all(func(character: Character) -> bool: return character.frozen)
	_check("Everyone is frozen at the match end: nobody moves, fires or dies, and no round starts",
			all_frozen and moved < 0.01 and not fired and _log.size() == results_before and _deaths.size() == kills_before
					and _rounds.phase == RoundManager.Phase.MATCH_END and _match_ends.size() == 1,
			"all frozen %s, largest movement %.3f m, fired %s, rounds %d -> %d, deaths %d -> %d, phase %s" % [
					all_frozen, moved, fired, results_before, _log.size(), kills_before, _deaths.size(), RoundManager.Phase.keys()[_rounds.phase]])


## Character → {position, magazine} for everyone playing.
func _snapshot() -> Dictionary:
	var snapshot := {}
	for character in _rounds.get_participants():
		# Rounds left in all: a reload only moves them from the reserve into the magazine (frozen
		# characters may reload, as in CS's freeze time), a shot or a throw uses one up.
		snapshot[character] = {"position": character.global_position, "rounds": character.weapon.magazine + character.weapon.reserve,
				"weapon": character.weapon}
	return snapshot


# --- Helpers ---


func _settings_md5() -> String:
	return FileAccess.get_md5(Settings.SETTINGS_PATH) if FileAccess.file_exists(Settings.SETTINGS_PATH) else ""


func _wait_seconds(seconds: float) -> void:
	for i in roundi(seconds * Engine.physics_ticks_per_second):
		await get_tree().physics_frame


## Headless runs have no audio device; sounds that never finish "playing" would
## be reported as leaks when Godot exits.
func _silence(character: Character) -> void:
	character.footstep_sound = null
	if character.weapon != null:
		var data := character.weapon.data.duplicate() as WeaponData
		data.shot_sound = null
		data.dry_fire_sound = null
		data.reload_sound = null
		character.weapon.data = data


func _check(check_name: String, passed: bool, detail: String) -> void:
	print("%s  %s: %s" % ["PASS" if passed else "FAIL", check_name, detail])
	if not passed:
		_failures += 1
