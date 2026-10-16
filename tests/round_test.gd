extends Node
## Automated round checks. Run without a window:
##
##     Godot --headless --path . --fixed-fps 128 --quit-after 60000 res://tests/round_test.tscn
##
## Loads the real test map and plays a 3v3 match on it with short timings: you
## (standing still, no keyboard) plus two bot teammates against three bots.
## Bots hold their spawn after freeze time, so nobody meets, and the test
## decides the fights by dealing damage directly. Checks freeze time, spawns,
## winning by elimination and on time-out, that the dead stay dead until the
## next round, and the kill, assist and damage stats. Then the same match goes
## on to its end (first to 5 by default): the score, the half-time side swap
## and the match end. Finally two tiny matches (first to 1 and first to 2) check
## the edges of those rules. The last part is spectating (D-046): a player who
## dies in a match sees through a living teammate's eyes, switches teammates, is
## moved on when that teammate dies, keeps the last view when nobody is left,
## and is back in their own view in the next round; with spectating off
## (practice mode) nothing changes. The last part is the round HUD (task 6): the
## real ui/hud.tscn listens to the round manager, and the test reads what it
## shows: the timer (freeze countdown, then the round time, frozen at the round
## end), the score and players alive, the countdown with your side, the kill
## feed (names, team colors, headshot mark, your own lines highlighted, at most 5
## lines, fading out), the round-end banners for a win and a loss by elimination
## and on time-out, "Switching sides" and match point, and that the HUD can be
## handed another round manager (or none, as in practice mode) without
## duplicates and never blocks the mouse. The last part is the scoreboard (task
## 7): the Tab action, the table of both teams (your team first, rows with the
## stats from the round manager, sorted by kills then damage, dead rows dimmed,
## your row highlighted, rebuilt only on changes), and the hold-Tab overlay (shows
## only while the key is held in a match, follows the match, hides while the
## console is open or the match is over, never takes the mouse, scales, copes
## with a replaced or missing round manager), and the match-end screen that uses
## the same table. The HUD's look (M10, D-133) is checked against the design
## tokens: every label's size, outline and colour, the spacing, the boxes, the
## squares and the timer's state colours, at scale 1.0 and exactly 1.5. Quits
## with the number of failed checks as the exit code (0 means everything passed).

## The design tokens the theme is built from; the HUD checks compare with them, not with numbers.
const Tokens := preload("res://tools/ui_palette.gd")
const MAP_SCENE := preload("res://maps/test_map.tscn")
const HUD_SCENE := preload("res://ui/hud.tscn")
const TABLE_SCENE := preload("res://ui/scoreboard_table.tscn")
const SCOREBOARD_SCENE := preload("res://ui/scoreboard.tscn")
const MATCH_END_SCENE := preload("res://ui/match_end_screen.tscn")
const FREEZE_TIME := 0.5
const ROUND_TIME := 2.0
const ROUND_END_TIME := 0.5
## The spectating checks need one long round and a long pause after it.
const SPECTATE_ROUND_TIME := 30.0
const SPECTATE_ROUND_END_TIME := 8.0
## The HUD checks that read the round timer need a round of the real length.
const HUD_ROUND_TIME := 115.0
const HUD_HEADLINES: Array[String] = ["Title", "Line1", "Line2", "Line3"]
const HUD_ATTACK_TEXT := "You attack: push to the far end"
const HUD_DEFEND_TEXT := "You defend: hold your end"

var _map: Node3D
var _rounds: RoundManager
var _player: Character
var _failures: int = 0
## [winner, reason] for every round_ended signal.
var _results: Array = []
## [victim, killer, headshot] for every character_killed signal.
var _kills: Array = []
## The score as [team 0, team 1] at the moment of every round_ended signal.
var _score_at_signal: Array = []
## How many times sides_swapped was emitted.
var _swaps: int = 0
## The winner of every match_ended signal.
var _match_ends: Array = []


func _ready() -> void:
	await _new_match(MatchSettings.new().rounds_to_win)
	await _run_all()
	if _failures == 0:
		print("\nAll checks passed.")
	else:
		print("\n%d check(s) FAILED." % _failures)
	get_tree().quit(_failures)


## Starts a match first to [param rounds_to_win] on a fresh copy of the test
## map (an earlier map is removed), with the short test timings (or the given
## round and round-end lengths), and waits until everyone has joined.
func _new_match(rounds_to_win: int, round_time: float = ROUND_TIME, round_end_time: float = ROUND_END_TIME) -> void:
	if _map != null:
		remove_child(_map)
		_map.queue_free()
	_results.clear()
	_kills.clear()
	_score_at_signal.clear()
	_swaps = 0
	_match_ends.clear()
	_map = MAP_SCENE.instantiate()
	add_child(_map)
	_player = _map.get_node("Player")
	_silence(_player)
	var settings := MatchSettings.new()
	settings.freeze_time = FREEZE_TIME
	settings.round_time = round_time
	settings.round_end_time = round_end_time
	settings.rounds_to_win = rounds_to_win
	_rounds = RoundManager.new()
	_rounds.settings = settings
	_rounds.rng.seed = 7
	_rounds.round_ended.connect(func(winner: int, reason: RoundManager.EndReason) -> void:
		_results.append([winner, reason])
		_score_at_signal.append([_rounds.score[0], _rounds.score[1]]))
	_rounds.character_killed.connect(func(victim: Character, killer: Character, headshot: bool) -> void: _kills.append([victim, killer, headshot]))
	_rounds.sides_swapped.connect(func() -> void: _swaps += 1)
	_rounds.match_ended.connect(func(winner: int) -> void: _match_ends.append(winner))
	_map.add_child(_rounds)
	# The match starts at the end of the first frame.
	await _wait_ticks(2)
	for character in _rounds.get_participants():
		_silence(character)


func _run_all() -> void:
	await _test_round_start()
	await _test_freeze_time()
	await _test_elimination()
	await _test_time_out()
	await _test_score()
	await _test_half_time()
	await _test_match_end()
	await _test_short_matches()
	await _test_spectating()
	await _test_round_hud()
	await _test_scoreboard()


func _test_round_start() -> void:
	var members := _rounds.get_participants()
	var at_spawn := members.all(func(member: Character) -> bool: return _distance_to_own_spawn(member) < 0.5)
	var full := members.all(func(member: Character) -> bool:
		return member.health == member.max_health and member.weapon.magazine == member.weapon.data.magazine_size)
	_check("A 3v3 match starts: you plus 2 bot teammates against 3 bots",
			_rounds.get_members(0).size() == 3 and _rounds.get_members(1).size() == 3 and _player.team == 0,
			"team sizes %d and %d, you on team %d" % [_rounds.get_members(0).size(), _rounds.get_members(1).size(), _player.team])
	_check("Round 1 starts in freeze time, everyone at their side's spawn with full health and ammo",
			_rounds.round_number == 1 and _rounds.phase == RoundManager.Phase.FREEZE and at_spawn and full,
			"round %d, phase %s, all on own spawn: %s, all full: %s" % [
					_rounds.round_number, RoundManager.Phase.keys()[_rounds.phase], at_spawn, full])


func _test_freeze_time() -> void:
	# Bots still patrol during freeze time and you hold forward and shoot: nobody may move or fire.
	var start_positions := {}
	for member in _rounds.get_participants():
		start_positions[member] = member.global_position
	Input.action_press("move_forward")
	Input.action_press("shoot")
	await _wait_seconds(FREEZE_TIME * 0.6)
	var moved := 0.0
	for member: Character in start_positions:
		moved = maxf(moved, member.global_position.distance_to(start_positions[member]))
	var fired := _player.weapon.magazine < _player.weapon.data.magazine_size
	_check("Freeze time: nobody can move or shoot", moved < 0.05 and not fired,
			"largest movement %.3f m, you fired: %s" % [moved, fired])
	Input.action_release("shoot")
	# From now on the bots hold their spawn, so the teams never meet.
	for member in _rounds.get_participants():
		if member != _player:
			(member.get_node("BotController") as BotController).hold_position = true
	await _wait_for_phase(RoundManager.Phase.LIVE)
	var live_start := _player.global_position
	await _wait_seconds(0.3)
	Input.action_release("move_forward")
	_check("After freeze time the round goes live and you can move",
			_rounds.phase == RoundManager.Phase.LIVE and _player.global_position.distance_to(live_start) > 0.5,
			"phase %s, moved %.2f m in 0.3 s" % [RoundManager.Phase.keys()[_rounds.phase], _player.global_position.distance_to(live_start)])


func _test_elimination() -> void:
	var enemies := _rounds.get_members(1)
	enemies[0].take_damage(500.0, Hitbox.Zone.HEAD, _player)
	enemies[1].take_damage(500.0, Hitbox.Zone.CHEST, _player)
	await _wait_ticks(2)
	var going_on := _results.is_empty() and _rounds.phase == RoundManager.Phase.LIVE
	enemies[2].take_damage(500.0, Hitbox.Zone.CHEST, _player)
	await _wait_ticks(2)
	_check("Killing the whole enemy team wins the round (not before)",
			going_on and _results == [[0, RoundManager.EndReason.ELIMINATION]] and _rounds.phase == RoundManager.Phase.ROUND_END,
			"after 2 of 3 kills the round went on: %s; results %s" % [going_on, _results])
	var stats := _rounds.get_stats(_player)
	_check("Kills are credited, a headshot is flagged",
			stats.kills == 3 and _kills.size() == 3 and _kills[0] == [enemies[0], _player, true] and _kills[1][2] == false,
			"your kills %d, kill events %d, first headshot: %s" % [stats.kills, _kills.size(), _kills[0][2] if not _kills.is_empty() else null])
	await _wait_seconds(ROUND_END_TIME * 0.6)
	var still_dead := enemies.all(func(enemy: Character) -> bool: return not enemy.is_alive())
	await _wait_for_phase(RoundManager.Phase.FREEZE)
	var back := enemies.all(func(enemy: Character) -> bool: return enemy.is_alive() and enemy.health == enemy.max_health)
	_check("The dead stay dead until the next round, then everyone is back",
			still_dead and back and _rounds.round_number == 2,
			"dead during round end: %s; round %d, all back with full health: %s" % [still_dead, _rounds.round_number, back])


func _test_time_out() -> void:
	await _wait_for_phase(RoundManager.Phase.LIVE)
	# An assist: you deal 50 to an enemy that your teammate finishes off.
	var enemy := _rounds.get_members(1)[0]
	var mate := _rounds.get_members(0).filter(func(member: Character) -> bool: return member != _player)[0] as Character
	enemy.take_damage(50.0, Hitbox.Zone.STOMACH, _player)
	enemy.take_damage(100.0, Hitbox.Zone.CHEST, mate)
	var you := _rounds.get_stats(_player)
	var them := _rounds.get_stats(mate)
	# Your damage counts health actually removed: 3 × 100 in round 1 (not 3 × 500), plus 50.
	_check("Assists and damage: you deal 50, a teammate finishes the enemy",
			you.assists == 1 and them.kills == 1 and is_equal_approx(them.damage, 50.0) and is_equal_approx(you.damage, 350.0),
			"your assists %d and damage %.0f (expected 1 and 350); teammate's kills %d and damage %.0f (expected 1 and 50)" % [
					you.assists, you.damage, them.kills, them.damage])
	var results_before := _results.size()
	await _wait_for_phase(RoundManager.Phase.ROUND_END)
	var defenders := _rounds.get_defending_team()
	_check("When time runs out, the defending side wins",
			_results.size() == results_before + 1 and _results.back() == [defenders, RoundManager.EndReason.TIME],
			"defending team %d, result %s" % [defenders, _results.back() if _results.size() > results_before else "none"])


## Score: the match so far is at the end of round 2 (round 1 went to your team,
## round 2 to whoever defended). The enemy wins round 3 and you win round 4, so
## the score isn't one-sided.
func _test_score() -> void:
	await _win_round(1)
	await _win_round(0)
	var running := [0, 0]
	var expected_at_signal := []
	for result: Array in _results:
		running[result[0]] += 1
		expected_at_signal.append(running.duplicate())
	_check("The score counts each round's winner and is already updated when round_ended is emitted",
			_results.size() == 4 and _rounds.score == running and _score_at_signal == expected_at_signal and running[1] >= 1,
			"round winners %s, score %s (expected %s), score at each round_ended %s (expected %s)" % [
					_results.map(func(result: Array) -> int: return result[0]), _rounds.score, running, _score_at_signal, expected_at_signal])


## Half time: after round (rounds_to_win - 1) the sides swap, before the next round.
func _test_half_time() -> void:
	var to_win := _rounds.settings.rounds_to_win
	var attacker_before := _rounds.attacking_team
	var swaps_in_pause := _swaps
	var round_before := _rounds.round_number
	await _wait_for_phase(RoundManager.Phase.FREEZE)
	_check("Half time: after round %d the sides swap once, in time for the next round" % (to_win - 1),
			round_before == to_win - 1 and swaps_in_pause == 0 and _swaps == 1 and _rounds.round_number == to_win
					and _rounds.attacking_team == Teams.other(attacker_before),
			"round %d -> %d, swaps %d -> %d, attacking team %d -> %d" % [
					round_before, _rounds.round_number, swaps_in_pause, _swaps, attacker_before, _rounds.attacking_team])
	# The ends are 112 m apart; everyone must stand on a marker of the new end.
	var on_other_end := true
	var detail := ""
	for member in _rounds.get_participants():
		var old_side := Teams.Side.ATTACKING if member.team == attacker_before else Teams.Side.DEFENDING
		var near_new := _distance_to_group(member, Teams.spawn_group(_rounds.get_side(member.team)))
		var near_old := _distance_to_group(member, Teams.spawn_group(old_side))
		if near_new > 0.5 or near_old < 10.0:
			on_other_end = false
			detail += "%s (team %d): %.1f m from the new end's marker, %.1f m from the old end's; " % [member.name, member.team, near_new, near_old]
	_check("After half time each team stands on the other end's spawn markers", on_other_end,
			"everyone is on a marker of the new end" if on_other_end else detail)


## Match end: the enemy wins every round from now on until it reaches rounds_to_win.
func _test_match_end() -> void:
	var to_win := _rounds.settings.rounds_to_win
	while _rounds.score[1] < to_win:
		await _win_round(1)
	var rounds_played := _rounds.round_number
	_check("The last round's pause still runs before the match ends",
			_rounds.phase == RoundManager.Phase.ROUND_END and _rounds.score == [_rounds.score[0], to_win]
					and _match_ends.is_empty() and _rounds.winner == -1,
			"phase %s, score %s, match_ended count %d, winner %d" % [
					RoundManager.Phase.keys()[_rounds.phase], _rounds.score, _match_ends.size(), _rounds.winner])
	await _wait_for_phase(RoundManager.Phase.MATCH_END)
	var all_frozen := _rounds.get_participants().all(func(member: Character) -> bool: return member.frozen)
	_check("Match end: the phase is MATCH_END, match_ended came once with the winner, everyone is frozen",
			_rounds.phase == RoundManager.Phase.MATCH_END and _match_ends == [1] and _rounds.winner == 1
					and _rounds.score[0] < to_win and all_frozen and _rounds.round_number == rounds_played,
			"phase %s, match_ended %s, winner %d, score %s, all frozen: %s, %d rounds (at most %d), %d half-time swap(s)" % [
					RoundManager.Phase.keys()[_rounds.phase], _match_ends, _rounds.winner, _rounds.score, all_frozen,
					rounds_played, 2 * to_win - 1, _swaps])
	await _wait_seconds(FREEZE_TIME + ROUND_TIME + ROUND_END_TIME)
	var still_frozen := _rounds.get_participants().all(func(member: Character) -> bool: return member.frozen)
	_check("Nothing happens after the match ends: no new round, no second signal, still frozen",
			_rounds.round_number == rounds_played and _rounds.phase == RoundManager.Phase.MATCH_END
					and _match_ends.size() == 1 and _results.size() == rounds_played and still_frozen and _swaps == 1,
			"round %d (was %d), phase %s, match_ended count %d, still frozen: %s" % [
					_rounds.round_number, rounds_played, RoundManager.Phase.keys()[_rounds.phase], _match_ends.size(), still_frozen])


## The edges of the rules: a match first to 1 has no half time, one first to 2
## swaps after round 1 and lasts at most 2 × 2 - 1 = 3 rounds.
func _test_short_matches() -> void:
	await _new_match(1)
	_hold_bots()
	await _win_round(1)
	await _wait_for_phase(RoundManager.Phase.MATCH_END)
	_check("First to 1: the match ends after round 1, with no half-time swap",
			_match_ends == [1] and _rounds.round_number == 1 and _swaps == 0 and _rounds.score == [0, 1],
			"match_ended %s after %d round(s), %d swap(s), score %s" % [_match_ends, _rounds.round_number, _swaps, _rounds.score])
	await _new_match(2)
	_hold_bots()
	await _win_round(1)
	await _win_round(0)
	var tied_and_going := _rounds.score == [1, 1] and _match_ends.is_empty() and _rounds.phase == RoundManager.Phase.ROUND_END
	await _win_round(0)
	await _wait_for_phase(RoundManager.Phase.MATCH_END)
	_check("First to 2: sides swap once after round 1, a 1-1 tie plays on, round 3 decides",
			tied_and_going and _swaps == 1 and _match_ends == [0] and _rounds.round_number == 3 and _rounds.score == [2, 1],
			"tied after round 2 and going on: %s, swaps %d, match_ended %s after %d round(s), score %s" % [
					tied_and_going, _swaps, _match_ends, _rounds.round_number, _rounds.score])


## Spectating: you are on team 0 with the bots Bot1 and Bot2; the enemies hold
## their spawn. Nobody can hurt you here, so the test kills you (and then your
## teammates) with direct damage from an enemy.
func _test_spectating() -> void:
	# Spectating is off unless main.gd switches it on (practice mode): nothing happens.
	await _new_match(MatchSettings.new().rounds_to_win, SPECTATE_ROUND_TIME, SPECTATE_ROUND_END_TIME)
	_hold_bots()
	var controller := _player.get_node("PlayerController") as PlayerController
	await _wait_for_phase(RoundManager.Phase.LIVE)
	var enemies := _rounds.get_members(1)
	_player.take_damage(500.0, Hitbox.Zone.CHEST, enemies[0])
	await _wait_seconds(controller.spectate_delay + 0.5)
	_check("With spectating off (practice mode) a dead player never leaves their own view",
			not controller.spectating_enabled and controller.get_view_target() == _player and not controller.is_spectating(),
			"spectating enabled: %s, view target is you: %s" % [controller.spectating_enabled, controller.get_view_target() == _player])

	# The same again with spectating on, as in a match.
	await _new_match(MatchSettings.new().rounds_to_win, SPECTATE_ROUND_TIME, SPECTATE_ROUND_END_TIME)
	_hold_bots()
	controller = _player.get_node("PlayerController") as PlayerController
	controller.spectating_enabled = true
	var camera := _player.get_camera()
	var views: Array[Character] = []
	controller.view_target_changed.connect(func(target: Character) -> void: views.append(target))
	await _wait_for_phase(RoundManager.Phase.LIVE)
	enemies = _rounds.get_members(1)
	var mates := _rounds.get_members(0).filter(func(member: Character) -> bool: return member != _player)
	var mate_a: Character = mates[0]
	var mate_b: Character = mates[1]
	_player.take_damage(500.0, Hitbox.Zone.CHEST, enemies[0])
	await _wait_seconds(controller.spectate_delay - 0.3)
	var killcam := controller.get_view_target() == _player and views.is_empty()
	await _wait_seconds(0.6)
	var watched := controller.get_view_target()
	var teammate_alive := watched != _player and watched.team == _player.team and watched.is_alive()
	await _wait_ticks(2)
	_check("After dying you first see your own view, after about %.0f s a living teammate's eyes" % controller.spectate_delay,
			killcam and teammate_alive and views == [watched] and controller.is_spectating(),
			"own view at %.1f s: %s; then %s (teammate alive: %s), view changes %s" % [
					controller.spectate_delay - 0.3, killcam, watched.name, teammate_alive, views.map(func(view: Character) -> String: return view.name)])
	_check("The view is exactly their eyes: the camera sits at their head and looks along their aim",
			_view_matches(camera, watched),
			_view_detail(camera, watched))
	_check("The teammate's body and your own rifle are hidden while you watch (their rifle stays: it is their viewmodel)",
			not watched.body.visible and watched.weapon.visible and not _player.weapon.visible,
			"their body visible: %s, their rifle visible: %s, your rifle visible: %s" % [watched.body.visible, watched.weapon.visible, _player.weapon.visible])

	# Switching: spectate_next() moves to the other living teammate and restores the first one.
	var first := watched
	controller.spectate_next()
	await _wait_ticks(2)
	var second := controller.get_view_target()
	_check("spectate_next() switches to the other living teammate, whose view replaces the first (shown again)",
			second != first and second != _player and second.team == _player.team and second.is_alive()
					and first.body.visible and not second.body.visible and _view_matches(camera, second),
			"%s -> %s; %s's body visible again: %s; camera at %s's head: %s" % [
					first.name, second.name, first.name, first.body.visible, second.name, _view_matches(camera, second)])

	# A click switches (the real input path). With the mouse not captured, which is
	# always the case in a headless run, a click only recaptures the mouse and must not count.
	var captured := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	await _click()
	var after_click := controller.get_view_target()
	_check("A click switches teammates only if it isn't the click that recaptures the mouse (mouse %s)" % ("captured" if captured else "free, as in headless runs"),
			(after_click != second) == captured,
			"mouse captured: %s, view %s -> %s" % [captured, second.name, after_click.name])
	var dying := after_click
	var last_alive := mate_a if dying == mate_b else mate_b

	# The teammate you watch dies: after about 1.5 s the view moves on to the last living one.
	dying.take_damage(500.0, Hitbox.Zone.CHEST, enemies[1])
	await _wait_seconds(controller.spectate_switch_delay - 0.4)
	var stays := controller.get_view_target() == dying
	await _wait_seconds(0.8)
	await _wait_ticks(2)
	_check("When the watched teammate dies the view moves on to the last living one after about %.1f s" % controller.spectate_switch_delay,
			stays and controller.get_view_target() == last_alive and not _player.weapon.visible
					and dying.body.visible and not last_alive.body.visible and _view_matches(camera, last_alive),
			"still on %s at %.1f s: %s; later on %s (expected %s); %s's body visible again: %s; camera at the new view: %s" % [
					dying.name, controller.spectate_switch_delay - 0.4, stays, controller.get_view_target().name, last_alive.name,
					dying.name, dying.body.visible, _view_matches(camera, last_alive)])

	# The last teammate dies too: nobody is left, so the view stays where it is.
	var before := camera.global_position
	last_alive.take_damage(500.0, Hitbox.Zone.CHEST, enemies[2])
	await _wait_seconds(1.0)
	var one_second := camera.global_position
	await _wait_seconds(controller.spectate_switch_delay + 1.5)
	var much_later := camera.global_position
	var sideways := Vector2(much_later.x - before.x, much_later.z - before.z).length()
	_check("With no teammate left the view stays on the last one, where they fell (the camera doesn't jump)",
			controller.get_view_target() == last_alive and sideways < 0.05 and one_second.distance_to(much_later) < 0.001
					and _rounds.phase == RoundManager.Phase.ROUND_END and _view_matches(camera, last_alive),
			"view on %s, moved sideways %.3f m, moved %.4f m in the last %.1f s, phase %s" % [
					controller.get_view_target().name, sideways, one_second.distance_to(much_later),
					controller.spectate_switch_delay + 1.5, RoundManager.Phase.keys()[_rounds.phase]])

	# The next round: you are alive again, in your own view, and nothing stays hidden.
	await _wait_for_phase(RoundManager.Phase.FREEZE)
	await _wait_ticks(2)
	var own_head := _player.head.global_position
	var all_shown := _rounds.get_participants().all(func(member: Character) -> bool:
		return member.weapon.visible and (member == _player or member.body.visible))
	_check("In the next round you are back in your own view, and everything hidden is visible again",
			_player.is_alive() and controller.get_view_target() == _player and not controller.is_spectating() and all_shown
					and camera.global_position.distance_to(own_head) < 0.05 and views.back() == _player,
			"alive: %s, view on you: %s, everything visible: %s, camera %.3f m from your head, last view change %s" % [
					_player.is_alive(), controller.get_view_target() == _player, all_shown, camera.global_position.distance_to(own_head), views.back().name])


## The round HUD (task 6). The real ui/hud.tscn is handed the round manager the
## way main.gd does it, and the checks read what its labels, squares and kill
## feed show. One short match for each part; the bots hold their spawn, and the
## test decides the fights with direct damage.
func _test_round_hud() -> void:
	await _test_hud_timer_and_feed()
	await _test_hud_banners()
	await _test_hud_match_point()
	await _test_hud_wiring()
	_test_hud_look()
	await _test_hud_states()


## Timer, countdown, side line, score, players alive and the kill feed's lines,
## in a match with a round of the real length (1:55).
func _test_hud_timer_and_feed() -> void:
	await _new_match(MatchSettings.new().rounds_to_win, HUD_ROUND_TIME)
	_hold_bots()
	var hud := _new_hud()
	var formats := [RoundHud.format_time(115.0), RoundHud.format_time(114.2), RoundHud.format_time(59.5),
			RoundHud.format_time(5.0), RoundHud.format_time(0.3), RoundHud.format_time(0.0), RoundHud.format_time(-1.0)]
	_check("The timer shows m:ss and counts a started second as a whole one",
			formats == ["1:55", "1:55", "1:00", "0:05", "0:01", "0:00", "0:00"], str(formats))
	await _wait_ticks(2)
	var side_text := HUD_ATTACK_TEXT if _rounds.get_side(Teams.viewer_team) == Teams.Side.ATTACKING else HUD_DEFEND_TEXT
	var bar := _bar(hud)
	_check("Freeze time: the timer shows the freeze countdown, the center says when round 1 starts and which side you play",
			bar[1] == "0:01" and bar[3] == "Round 1" and _center(hud) == ["", "Round 1  ·  starts in 1", side_text, ""],
			"timer %s, round label %s, center %s (your side line should be '%s')" % [bar[1], bar[3], _center(hud), side_text])
	_check("The top bar starts at 0 - 0 with all 3 players alive on each side",
			bar[0] == "0" and bar[2] == "0" and bar[4] == 3 and bar[5] == 3,
			"score %s - %s, alive %s and %s" % [bar[0], bar[2], bar[4], bar[5]])
	await _wait_for_phase(RoundManager.Phase.LIVE)
	await _wait_ticks(2)
	bar = _bar(hud)
	_check("Live: the timer shows the round time (1:55) and the countdown is gone",
			bar[1] == "1:55" and _center(hud) == ["", "", "", ""], "timer %s, center %s" % [bar[1], _center(hud)])

	# Deaths: your headshot on an enemy, an enemy's kill of a teammate, a death with no killer.
	var feed := _feed(hud)
	var enemies := _rounds.get_members(1)
	var mates := _rounds.get_members(0).filter(func(member: Character) -> bool: return member != _player)
	var blue := Teams.FRIENDLY_COLOR.lightened(Teams.TEXT_LIGHTEN)
	var red := Teams.ENEMY_COLOR.lightened(Teams.TEXT_LIGHTEN)
	enemies[0].take_damage(500.0, Hitbox.Zone.HEAD, _player)
	await _wait_ticks(2)
	var yours := _read_line(feed.get_child(0))
	_check("Your headshot kill is one line: you (blue) > the victim (red), 'HS', highlighted as your own",
			feed.get_line_count() == 1 and yours == {"killer": String(_player.name), "killer_color": blue, "separator": ">",
					"victim": String(enemies[0].name), "victim_color": red, "headshot": true, "highlighted": true},
			"%d line(s): %s" % [feed.get_line_count(), yours])
	mates[0].take_damage(500.0, Hitbox.Zone.CHEST, enemies[1])
	mates[1].take_damage(500.0, Hitbox.Zone.CHEST, null)
	await _wait_ticks(2)
	var theirs := _read_line(feed.get_child(1))
	var nobody := _read_line(feed.get_child(2))
	_check("An enemy's kill is 'enemy (red) > teammate (blue)' with no headshot mark and no highlight; a death without a killer shows only the victim; newest at the bottom",
			feed.get_line_count() == 3
			and theirs == {"killer": String(enemies[1].name), "killer_color": red, "separator": ">", "victim": String(mates[0].name),
					"victim_color": blue, "headshot": false, "highlighted": false}
			and nobody == {"killer": "", "killer_color": Color(0, 0, 0, 0), "separator": "", "victim": String(mates[1].name),
					"victim_color": blue, "headshot": false, "highlighted": false},
			"%d line(s): %s / %s" % [feed.get_line_count(), theirs, nobody])
	bar = _bar(hud)
	_check("Players alive follows the deaths: yourself alone on your side, 2 enemies left, score still 0 - 0",
			bar[4] == 1 and bar[5] == 2 and bar[0] == "0" and bar[2] == "0",
			"alive %s and %s, score %s - %s" % [bar[4], bar[5], bar[0], bar[2]])

	# Winning the round: banner, score, and the timer stays where the round ended.
	enemies[1].take_damage(500.0, Hitbox.Zone.CHEST, _player)
	enemies[2].take_damage(500.0, Hitbox.Zone.CHEST, _player)
	await _wait_for_phase(RoundManager.Phase.ROUND_END)
	await _wait_ticks(2)
	bar = _bar(hud)
	_check("Winning by elimination: 'Round won' in blue, 'Enemy team eliminated', score 1 - 0, nobody alive on their side, and the timer stays at the round's time",
			_center(hud) == ["Round won", "Enemy team eliminated", "", ""] and _center_color(hud, "Title") == blue
					and bar[0] == "1" and bar[2] == "0" and bar[4] == 1 and bar[5] == 0 and bar[1] == "1:55",
			"center %s, score %s - %s, alive %s and %s, timer %s" % [_center(hud), bar[0], bar[2], bar[4], bar[5], bar[1]])
	await _wait_for_phase(RoundManager.Phase.FREEZE)
	await _wait_ticks(2)
	bar = _bar(hud)
	_check("The next round starts clean: empty kill feed, everyone alive again, the score kept (1 - 0), the round 2 countdown",
			feed.get_line_count() == 0 and bar[4] == 3 and bar[5] == 3 and bar[0] == "1" and bar[2] == "0" and bar[3] == "Round 2"
					and _center(hud)[1] == "Round 2  ·  starts in 1",
			"%d feed line(s), alive %s and %s, score %s - %s, %s, center %s" % [feed.get_line_count(), bar[4], bar[5], bar[0], bar[2], bar[3], _center(hud)])
	_free_hud(hud)


## The round-end banners for all four outcomes (won and lost, by elimination and
## on time-out) and the half-time notice, in a match first to 3 with short rounds:
## round 1 your team is wiped out, rounds 2 and 3 run out of time (the sides swap
## in between, so the defenders are one of your team and one of theirs), round 4
## you win by elimination.
func _test_hud_banners() -> void:
	await _new_match(3)
	_hold_bots()
	var hud := _new_hud()
	var outcomes := {}
	await _wait_for_phase(RoundManager.Phase.LIVE)
	var first_side := _rounds.get_side(Teams.viewer_team)
	var killer := _rounds.get_members(1)[0]
	for victim in _rounds.get_members(0):
		victim.take_damage(500.0, Hitbox.Zone.CHEST, killer)
	await _wait_for_phase(RoundManager.Phase.ROUND_END)
	await _wait_ticks(2)
	_check_banner(hud, "round 1, your team wiped out", outcomes)
	await _wait_for_phase(RoundManager.Phase.LIVE)
	await _wait_for_phase(RoundManager.Phase.ROUND_END)
	await _wait_ticks(2)
	_check_banner(hud, "round 2, time ran out", outcomes)
	# Half time came after round 2 (first to 3): round 3's freeze time says so.
	await _wait_for_phase(RoundManager.Phase.FREEZE)
	await _wait_ticks(2)
	var new_side_text := HUD_DEFEND_TEXT if first_side == Teams.Side.ATTACKING else HUD_ATTACK_TEXT
	var center := _center(hud)
	var point_text := "Enemy match point" if _rounds.score == [0, 2] else ""
	_check("Half time: round 3's freeze time says 'Switching sides' and shows your new side (match point only if the enemy has 2 rounds)",
			_rounds.get_side(Teams.viewer_team) != first_side and center == ["Switching sides", "Round 3  ·  starts in 1", new_side_text, point_text],
			"center %s, expected side line '%s', score %s" % [center, new_side_text, _rounds.score])
	await _wait_for_phase(RoundManager.Phase.LIVE)
	await _wait_for_phase(RoundManager.Phase.ROUND_END)
	await _wait_ticks(2)
	_check_banner(hud, "round 3, time ran out after the swap", outcomes)
	await _wait_for_phase(RoundManager.Phase.FREEZE)
	await _wait_ticks(2)
	center = _center(hud)
	_check("Round 4 (score %s): the half-time notice is gone and the enemy, one round from winning, is on match point" % [_rounds.score],
			_rounds.score == [1, 2] and center == ["", "Round 4  ·  starts in 1", new_side_text, "Enemy match point"]
					and _center_color(hud, "Line3") == Teams.ENEMY_COLOR.lightened(Teams.TEXT_LIGHTEN),
			"center %s, score %s" % [center, _rounds.score])
	await _win_round(0)
	await _wait_ticks(2)
	_check_banner(hud, "round 4, enemy team wiped out", outcomes)
	_check("Those rounds showed all four banners: won and lost, by elimination and on time-out",
			outcomes.size() == 4, "seen: %s" % [outcomes.keys()])
	_free_hud(hud)


## Match point in a match first to 2: you win round 1 (so the sides swap and you
## are on match point), then the enemy wins round 2 (both teams on match point).
func _test_hud_match_point() -> void:
	await _new_match(2)
	_hold_bots()
	var hud := _new_hud()
	await _wait_for_phase(RoundManager.Phase.LIVE)
	var first_side := _rounds.get_side(Teams.viewer_team)
	await _win_round(0)
	await _wait_for_phase(RoundManager.Phase.FREEZE)
	await _wait_ticks(2)
	var new_side_text := HUD_DEFEND_TEXT if first_side == Teams.Side.ATTACKING else HUD_ATTACK_TEXT
	_check("You lead 1 - 0 in a match to 2: the freeze time says 'Switching sides' and 'Match point' (in your color)",
			_center(hud) == ["Switching sides", "Round 2  ·  starts in 1", new_side_text, "Match point"]
					and _center_color(hud, "Line3") == Teams.FRIENDLY_COLOR.lightened(Teams.TEXT_LIGHTEN),
			"center %s, score %s" % [_center(hud), _rounds.score])
	await _win_round(1)
	await _wait_for_phase(RoundManager.Phase.FREEZE)
	await _wait_ticks(2)
	_check("At 1 - 1 both teams are on match point, and round 3 has no half-time notice",
			_rounds.score == [1, 1] and _center(hud) == ["", "Round 3  ·  starts in 1", new_side_text, "Match point for both teams"],
			"center %s, score %s" % [_center(hud), _rounds.score])
	_free_hud(hud)


## How the HUD is handed a round manager (or none), and the kill feed's own
## rules (at most 5 lines, fading out, highlights, colors relative to the viewer).
func _test_hud_wiring() -> void:
	await _new_match(MatchSettings.new().rounds_to_win, HUD_ROUND_TIME)
	_hold_bots()
	var hud := _new_hud()
	var round_hud := _round_hud(hud)
	var feed := _feed(hud)
	await _wait_for_phase(RoundManager.Phase.LIVE)
	var enemies := _rounds.get_members(1)
	var mate := _rounds.get_members(0)[1]
	var blue := Teams.FRIENDLY_COLOR.lightened(Teams.TEXT_LIGHTEN)
	var red := Teams.ENEMY_COLOR.lightened(Teams.TEXT_LIGHTEN)

	# No round manager (practice mode): nothing shows, and the old manager's signals no longer reach the HUD.
	hud.set_round_manager(null)
	enemies[0].take_damage(500.0, Hitbox.Zone.CHEST, _player)
	await _wait_ticks(2)
	var listening := _listeners(_rounds, round_hud)
	_check("Without a round manager (practice mode) the round HUD is hidden and no longer listens to the old one",
			not round_hud.visible and feed.get_line_count() == 0 and listening == 0,
			"visible %s, %d feed line(s), %d connection(s) to the old manager" % [round_hud.visible, feed.get_line_count(), listening])
	# Handing a manager over twice (a reload, a second map) must not double anything.
	hud.set_round_manager(_rounds)
	hud.set_round_manager(_rounds)
	enemies[1].take_damage(500.0, Hitbox.Zone.CHEST, _player)
	await _wait_ticks(2)
	listening = _listeners(_rounds, round_hud)
	_check("Handing over the same round manager again shows the HUD, with one connection per signal and one line per kill",
			round_hud.visible and feed.get_line_count() == 1 and listening == 5,
			"visible %s, %d feed line(s), %d connection(s) (expected 5)" % [round_hud.visible, feed.get_line_count(), listening])

	# Scaling: existing and new lines, the top bar and the center follow the UI scale.
	hud.set_ui_scale(1.5)
	feed.add_kill(enemies[2], _player, false)
	var line_sizes := feed.get_children().map(func(line: Node) -> int: return (line.find_child("Victim", true, false) as Label).get_theme_font_size("font_size"))
	var score_size := (round_hud.get_node("TopBar/YourBox/Margin/Content/Score") as Label).get_theme_font_size("font_size")
	var title_size := (round_hud.get_node("Center/Title") as Label).get_theme_font_size("font_size")
	_check("UI scale 1.5 scales the kill-feed lines (old and new), the scores and the center messages",
			line_sizes == [24, 24] and score_size == 48 and title_size == 72,
			"line font sizes %s (expected 24), score %d (48), title %d (72)" % [line_sizes, score_size, title_size])
	hud.set_ui_scale(1.0)

	# The cap: 7 deaths leave the newest 5, newest at the bottom.
	feed.clear()
	var everyone := _rounds.get_participants()
	var victims: Array[String] = []
	for i in 7:
		victims.append(String(everyone[i % everyone.size()].name))
		feed.add_kill(everyone[i % everyone.size()], enemies[0], false)
	var shown := feed.get_children().map(func(line: Node) -> String: return (line.find_child("Victim", true, false) as Label).text)
	_check("The kill feed shows at most 5 lines: after 7 deaths the oldest two are gone and the newest is at the bottom",
			feed.get_line_count() == KillFeed.MAX_LINES and shown == victims.slice(2),
			"%d line(s): %s (expected %s)" % [feed.get_line_count(), shown, victims.slice(2)])

	# Highlights and colors relative to the viewer.
	feed.clear()
	feed.add_kill(_player, enemies[0], false)
	feed.add_kill(enemies[1], mate, false)
	var you_died := _read_line(feed.get_child(0))
	var others := _read_line(feed.get_child(1))
	_check("Lines that involve you, also your own death, are highlighted; lines between others are not",
			you_died["highlighted"] == true and you_died["victim_color"] == blue and others["highlighted"] == false,
			"your death: %s, others: %s" % [you_died, others])
	Teams.set_viewer_team(1)
	feed.clear()
	feed.add_kill(mate, enemies[0], false)
	var flipped := _read_line(feed.get_child(0))
	Teams.set_viewer_team(0)
	_check("Name colors are relative to the viewer: seen from team 1, team 1 is blue and team 0 red",
			flipped["killer_color"] == blue and flipped["victim_color"] == red, str(flipped))
	var blocking: Array[String] = []
	for control: Control in hud.find_children("*", "Control", true, false):
		if control.mouse_filter != Control.MOUSE_FILTER_IGNORE:
			blocking.append(String(control.name))
	_check("No part of the HUD takes mouse clicks, so they still reach the player controls",
			blocking.is_empty(), "controls that would take clicks: %s" % [blocking])

	# Fading: fully visible at half the lifetime, fading around its end, gone soon after.
	feed.clear()
	feed.add_kill(enemies[0], _player, false)
	await _wait_seconds(KillFeed.LINE_LIFETIME * 0.5)
	var early := feed.get_line_count() == 1 and is_equal_approx((feed.get_child(0) as Control).modulate.a, 1.0)
	await _wait_seconds(KillFeed.LINE_LIFETIME * 0.5 + KillFeed.FADE_TIME * 0.5)
	var fading := feed.get_line_count() == 1 and (feed.get_child(0) as Control).modulate.a < 0.9
	await _wait_seconds(KillFeed.FADE_TIME * 0.5 + 0.2)
	_check("A kill-feed line stays fully visible for %.0f s, then fades out and is removed" % KillFeed.LINE_LIFETIME,
			early and fading and feed.get_line_count() == 0,
			"fully visible at %.1f s: %s, fading at %.2f s: %s, lines left at %.1f s: %d" % [
					KillFeed.LINE_LIFETIME * 0.5, early, KillFeed.LINE_LIFETIME + KillFeed.FADE_TIME * 0.5, fading,
					KillFeed.LINE_LIFETIME + KillFeed.FADE_TIME + 0.2, feed.get_line_count()])
	_free_hud(hud)

## The HUD's look comes from the theme (M10, D-133): a HUD with no match has, for
## every label, the size, outline and colour of its role's tokens, the spacing and
## boxes of the top bar, the bomb's bar and the state colours; scaled by 1.5 every
## size and spacing is exactly 1.5 times as big (UiScale), and back at 1.0 it is
## the same again.
func _test_hud_look() -> void:
	var hud := HUD_SCENE.instantiate()
	add_child(hud)
	var labels := {
		"WeaponLabel": [Tokens.HUD_SIZE_TEXT, Tokens.HUD_OUTLINE_TEXT, Tokens.HUD_TEXT],
		"AmmoLabel": [Tokens.HUD_SIZE_VALUE, Tokens.HUD_OUTLINE_VALUE, Tokens.HUD_TEXT],
		"HealthLabel": [Tokens.HUD_SIZE_VALUE, Tokens.HUD_OUTLINE_VALUE, Tokens.HUD_TEXT],
		"DeathLabel": [Tokens.HUD_SIZE_HEADLINE, Tokens.HUD_OUTLINE_HEADLINE, Tokens.HUD_ALERT],
		"SpectateLabel": [Tokens.HUD_SIZE_SPECTATE, Tokens.HUD_OUTLINE_SPECTATE, Tokens.HUD_TEXT],
		"RoundHud/TopBar/YourBox/Margin/Content/Score": [Tokens.HUD_SIZE_SCORE, Tokens.HUD_OUTLINE_SCORE, Tokens.HUD_TEXT],
		"RoundHud/TopBar/EnemyBox/Margin/Content/Score": [Tokens.HUD_SIZE_SCORE, Tokens.HUD_OUTLINE_SCORE, Tokens.HUD_TEXT],
		"RoundHud/TopBar/TimerBox/Margin/Content/Timer": [Tokens.HUD_SIZE_SCORE, Tokens.HUD_OUTLINE_SCORE, Tokens.HUD_TEXT_BRIGHT],
		"RoundHud/TopBar/TimerBox/Margin/Content/RoundLabel": [Tokens.HUD_SIZE_SMALL, Tokens.HUD_OUTLINE_SCORE, Tokens.HUD_TEXT_DIM],
		"RoundHud/Center/Title": [Tokens.HUD_SIZE_TITLE, Tokens.HUD_OUTLINE_TITLE, Tokens.HUD_TEXT_BRIGHT],
		"RoundHud/Center/Line1": [Tokens.HUD_SIZE_HEADLINE, Tokens.HUD_OUTLINE_HEADLINE, Tokens.HUD_TEXT_BRIGHT],
		"RoundHud/Center/Line2": [Tokens.HUD_SIZE_TEXT, Tokens.HUD_OUTLINE_TEXT, Tokens.HUD_TEXT_BRIGHT],
		"RoundHud/Center/Line3": [Tokens.HUD_SIZE_TEXT, Tokens.HUD_OUTLINE_TEXT, Tokens.HUD_TEXT_BRIGHT],
		"RoundHud/Respawn": [Tokens.HUD_SIZE_TEXT, Tokens.HUD_OUTLINE_TEXT, Tokens.HUD_TEXT_BRIGHT],
		"BombHud/CarryLabel": [Tokens.HUD_SIZE_TEXT, Tokens.HUD_OUTLINE_TEXT, Tokens.HUD_GOLD],
		"BombHud/Prompt": [Tokens.HUD_SIZE_TEXT, Tokens.HUD_OUTLINE_TEXT, Tokens.HUD_TEXT],
		"BombHud/Message": [Tokens.HUD_SIZE_TEXT, Tokens.HUD_OUTLINE_TEXT, Tokens.HUD_GOLD],
	}
	var wrong_at_1: Array[String] = []
	var wrong_at_1_5: Array[String] = []
	var wrong_back: Array[String] = []
	for path: String in labels:
		var want: Array = labels[path]
		var label := hud.get_node(path) as Label
		if not _label_looks_like(label, want[0], want[1], want[2], 1.0):
			wrong_at_1.append(path)
	hud.call("set_ui_scale", 1.5)
	for path: String in labels:
		var want: Array = labels[path]
		if not _label_looks_like(hud.get_node(path) as Label, want[0], want[1], want[2], 1.5):
			wrong_at_1_5.append(path)
	hud.call("set_ui_scale", 1.0)
	for path: String in labels:
		var want: Array = labels[path]
		if not _label_looks_like(hud.get_node(path) as Label, want[0], want[1], want[2], 1.0):
			wrong_back.append(path)
	_check("Every one of the HUD's %d labels takes its size, outline and colour from its role's tokens at 1.0, sizes and outlines are exactly 1.5 times as big after set_ui_scale(1.5), and the same again at 1.0" % labels.size(),
			wrong_at_1.is_empty() and wrong_at_1_5.is_empty() and wrong_back.is_empty(),
			"wrong at 1.0: %s, at 1.5: %s, back at 1.0: %s" % [wrong_at_1, wrong_at_1_5, wrong_back])

	# Spacing: the top bar, its boxes and the centre messages, scaled the same way.
	var spacing := {
		"RoundHud/TopBar": [&"separation", Tokens.HUD_BAR_GAP],
		"RoundHud/TopBar/YourBox/Margin": [&"margin_left", Tokens.HUD_BOX_PAD_X],
		"RoundHud/TopBar/TimerBox/Margin": [&"margin_top", Tokens.HUD_BOX_PAD_TOP],
		"RoundHud/TopBar/EnemyBox/Margin": [&"margin_bottom", Tokens.HUD_BOX_PAD_BOTTOM],
		"RoundHud/TopBar/YourBox/Margin/Content": [&"separation", Tokens.HUD_BOX_GAP],
		"RoundHud/TopBar/EnemyBox/Margin/Content/Pips": [&"separation", Tokens.HUD_PIP_GAP],
		"RoundHud/Center": [&"separation", Tokens.HUD_MESSAGE_GAP],
		"RoundHud/KillFeed": [&"separation", Tokens.HUD_FEED_GAP],
	}
	var wrong_spacing: Array[String] = []
	for factor: float in [1.0, 1.5]:
		hud.call("set_ui_scale", factor)
		for path: String in spacing:
			var control := hud.get_node(path) as Control
			var item: Array = spacing[path]
			if control.get_theme_constant(item[0]) != roundi(int(item[1]) * factor):
				wrong_spacing.append("%s at %s: %d" % [path, factor, control.get_theme_constant(item[0])])
	hud.call("set_ui_scale", 1.0)
	_check("The top bar, its boxes, the centre messages and the kill feed take their spacing from the tokens, exactly 1.5 times as big at scale 1.5",
			wrong_spacing.is_empty(), "wrong: %s" % [wrong_spacing])

	# The boxes: each team's colour from Teams, darkened and a little see-through; the timer's own.
	var your_box := (hud.get_node("RoundHud/TopBar/YourBox") as Control).get_theme_stylebox("panel") as StyleBoxFlat
	var enemy_box := (hud.get_node("RoundHud/TopBar/EnemyBox") as Control).get_theme_stylebox("panel") as StyleBoxFlat
	var timer_box := (hud.get_node("RoundHud/TopBar/TimerBox") as Control).get_theme_stylebox("panel") as StyleBoxFlat
	_check("The top bar's boxes: your box is the friendly colour and the enemy's the enemy colour (from Teams), darkened by the token and at its opacity, the timer's box its own colour, none with a border",
			your_box.bg_color == Color(Teams.FRIENDLY_COLOR.darkened(Tokens.HUD_SCORE_BOX_DARKEN), Tokens.HUD_SCORE_BOX_ALPHA)
					and enemy_box.bg_color == Color(Teams.ENEMY_COLOR.darkened(Tokens.HUD_SCORE_BOX_DARKEN), Tokens.HUD_SCORE_BOX_ALPHA)
					and timer_box.bg_color == Tokens.HUD_TIMER_BOX
					and your_box.border_width_left == 0 and enemy_box.border_width_top == 0 and timer_box.border_width_right == 0,
			"yours %s, theirs %s, timer %s" % [your_box.bg_color, enemy_box.bg_color, timer_box.bg_color])

	# The bomb's progress bar and the state colours code reads from the theme.
	var back := (hud.get_node("BombHud/Bar/Back") as Control).get_theme_stylebox("panel") as StyleBoxFlat
	var fill := (hud.get_node("BombHud/Bar/Fill") as Control).get_theme_stylebox("panel") as StyleBoxFlat
	var round_hud := _round_hud(hud)
	_check("The bomb's progress bar takes its colours from the theme (the strip behind, the gold fill), and the theme's Hud type holds the state colours and the square's size",
			back.bg_color == Tokens.HUD_BAR_BACK and fill.bg_color == Tokens.HUD_BAR_FILL
					and round_hud.get_theme_color("freeze_timer", "Hud") == Tokens.HUD_FREEZE_TIMER and round_hud.get_theme_color("alert", "Hud") == Tokens.HUD_ALERT
					and round_hud.get_theme_color("notice", "Hud") == Tokens.HUD_NOTICE and round_hud.get_theme_color("gold", "Hud") == Tokens.HUD_GOLD
					and round_hud.get_theme_color("pip_dead", "Hud") == Tokens.HUD_PIP_DEAD and round_hud.get_theme_constant("pip_size", "Hud") == Tokens.HUD_PIP_SIZE,
			"strip %s, fill %s, pip size %d" % [back.bg_color, fill.bg_color, round_hud.get_theme_constant("pip_size", "Hud")])
	_free_hud(hud)


## True if [param label] has the size [param size] and outline [param outline] (both
## times [param factor], rounded as UiScale rounds), a black outline colour and [param color].
func _label_looks_like(label: Label, size: int, outline: int, color: Color, factor: float) -> bool:
	return label.get_theme_font_size("font_size") == roundi(size * factor) \
			and label.get_theme_constant("outline_size") == roundi(outline * factor) \
			and label.get_theme_color("font_color") == color \
			and label.get_theme_color("font_outline_color") == Tokens.HUD_OUTLINE


## The HUD's game-state colours and squares in a real match: the timer is the
## freeze colour in freeze time, its usual colour in the live round, the alert
## colour in the last 10 seconds; a team's squares are its colour while alive and
## the dead colour after; the squares have the token's size, 1.5 times as big
## at scale 1.5; the notices ("Switching sides") use the notice colour.
func _test_hud_states() -> void:
	await _new_match(2, HUD_ROUND_TIME)
	_hold_bots()
	var hud := _new_hud()
	await _wait_ticks(2)
	var timer := hud.get_node("RoundHud/TopBar/TimerBox/Margin/Content/Timer") as Label
	var freeze_color := timer.get_theme_color("font_color")
	await _wait_for_phase(RoundManager.Phase.LIVE)
	await _wait_ticks(2)
	var live_color := timer.get_theme_color("font_color")
	_rounds.time_left = RoundHud.LOW_TIME - 1.0
	await _wait_ticks(2)
	var low_color := timer.get_theme_color("font_color")
	_check("The timer's colour is a game state read from the theme: the freeze colour in freeze time, its usual bright text in the live round, the alert colour in the last %d seconds" % roundi(RoundHud.LOW_TIME),
			freeze_color == Tokens.HUD_FREEZE_TIMER and live_color == Tokens.HUD_TEXT_BRIGHT and low_color == Tokens.HUD_ALERT,
			"freeze %s, live %s, low time %s" % [freeze_color, live_color, low_color])
	var enemies := _rounds.get_members(1)
	enemies[0].take_damage(500.0, Hitbox.Zone.CHEST, _player)
	await _wait_ticks(2)
	var pips := hud.get_node("RoundHud/TopBar/EnemyBox/Margin/Content/Pips")
	var yours := hud.get_node("RoundHud/TopBar/YourBox/Margin/Content/Pips")
	var enemy_pips: Array[Color] = []
	for pip in pips.get_children():
		enemy_pips.append((pip as ColorRect).color)
	var lit_enemy := Teams.text_color_for(Teams.other(Teams.viewer_team))
	var lit_yours := Teams.text_color_for(Teams.viewer_team)
	_check("The squares: a living player's is the team's colour (relative to you), a dead player's the theme's dead colour; one square per player",
			pips.get_child_count() == 3 and enemy_pips.count(Tokens.HUD_PIP_DEAD) == 1 and enemy_pips.count(lit_enemy) == 2
					and yours.get_children().all(func(pip: Node) -> bool: return (pip as ColorRect).color == lit_yours),
			"enemy squares %s" % [enemy_pips])
	var size_at_1 := (pips.get_child(0) as Control).custom_minimum_size
	hud.call("set_ui_scale", 1.5)
	var size_at_1_5 := (pips.get_child(0) as Control).custom_minimum_size
	hud.call("set_ui_scale", 1.0)
	_check("A square has the token's size (HUD_PIP_SIZE), exactly 1.5 times as big at scale 1.5",
			size_at_1 == Vector2(Tokens.HUD_PIP_SIZE, Tokens.HUD_PIP_SIZE) and size_at_1_5 == Vector2(Tokens.HUD_PIP_SIZE, Tokens.HUD_PIP_SIZE) * 1.5,
			"%s at 1.0, %s at 1.5" % [size_at_1, size_at_1_5])
	# Half time: the "Switching sides" title is in the notice colour (round 1 won by killing the rest).
	enemies[1].take_damage(500.0, Hitbox.Zone.CHEST, _player)
	enemies[2].take_damage(500.0, Hitbox.Zone.CHEST, _player)
	await _wait_for_phase(RoundManager.Phase.ROUND_END)
	await _wait_for_phase(RoundManager.Phase.FREEZE)
	await _wait_ticks(2)
	_check("'Switching sides' (the notice at half time) is drawn in the theme's notice colour",
			_center(hud)[0] == "Switching sides" and _center_color(hud, "Title") == Tokens.HUD_NOTICE,
			"center %s, title colour %s" % [_center(hud), _center_color(hud, "Title")])
	_free_hud(hud)


## The scoreboard (task 7): the input action, the table of both teams, the
## hold-Tab overlay, and the match-end screen that now uses the same table.
func _test_scoreboard() -> void:
	await _test_scoreboard_action()
	await _test_scoreboard_table()
	await _test_scoreboard_overlay()
	await _test_scoreboard_in_match_end_screen()


func _test_scoreboard_action() -> void:
	var events := InputMap.action_get_events("scoreboard") if InputMap.has_action("scoreboard") else []
	var key := events[0] as InputEventKey if events.size() == 1 else null
	_check("The 'scoreboard' action exists and is bound to Tab, by physical key and for all devices",
			key != null and key.physical_keycode == KEY_TAB and key.keycode == KEY_NONE and key.device == -1,
			"%d event(s); physical key %s, device %s" % [events.size(),
					key.physical_keycode if key != null else "none", key.device if key != null else "none"])
	# And it really answers to the key: a Tab press and release through the input path.
	var states: Array[bool] = []
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = KEY_TAB
		event.pressed = pressed
		Input.parse_input_event(event)
		await _wait_ticks(2)
		states.append(Input.is_action_pressed("scoreboard"))
	_check("Pressing the Tab key holds the action and releasing it lets go", states == [true, false], "held after press / release: %s" % [states])


## The table on its own: layout, stats, sorting, dimming, highlight, rebuilding.
## One 3v3 match with a long round; the test deals the damage directly (Bot1 and
## Bot2 are your teammates, Bot3 to Bot5 the enemies).
func _test_scoreboard_table() -> void:
	await _new_match(MatchSettings.new().rounds_to_win, HUD_ROUND_TIME)
	_hold_bots()
	var table := TABLE_SCENE.instantiate() as ScoreboardTable
	add_child(table)
	table.show_match(_rounds)

	# Layout: both teams, yours first under a blue header, theirs under a red one.
	var team_boxes := table.get_children().map(func(box: Node) -> String: return String(box.name))
	var your_header := _row_cells(table.get_node("Team0/Header"))
	var their_header := _row_cells(table.get_node("Team1/Header"))
	_check("The table lists both teams, yours first under a blue 'Your team' header, then the enemy under a red one, 3 rows each",
			team_boxes == ["Team0", "Team1"] and your_header == ["Your team", "Kills", "Deaths", "Assists", "Damage"]
					and their_header[0] == "Enemy team" and _header_color(table, 0) == _ui_team_color(true)
					and _header_color(table, 1) == _ui_team_color(false)
					and table.get_displayed(0).size() == 3 and table.get_displayed(1).size() == 3
					and table.get_displayed(0).all(func(member: Character) -> bool: return member.team == 0),
			"boxes %s, headers %s / %s, rows %d and %d" % [team_boxes, your_header, their_header,
					table.get_displayed(0).size(), table.get_displayed(1).size()])
	Teams.set_viewer_team(1)
	table.refresh()
	team_boxes = table.get_children().map(func(box: Node) -> String: return String(box.name))
	var flipped_title: String = _row_cells(table.get_node("Team1/Header"))[0]
	var flipped_color := _header_color(table, 1)
	Teams.set_viewer_team(0)
	table.refresh()
	_check("Seen from team 1, team 1 comes first under the blue header and team 0 follows in red",
			team_boxes == ["Team1", "Team0"] and flipped_title == "Your team" and flipped_color == _ui_team_color(true),
			"boxes %s, team 1's title '%s' and color %s" % [team_boxes, flipped_title, flipped_color])

	# Stats: Bot1 hurts both Bot3 and Bot4 by 80, Bot2 finishes them (kills 2,
	# damage 20 + 20, and Bot1 gets 2 assists); you hurt Bot5 by 20.6 and Bot5
	# hurts you by 30. Bot5 and the three on your side live.
	await _wait_for_phase(RoundManager.Phase.LIVE)
	var mates := _rounds.get_members(0).filter(func(member: Character) -> bool: return member != _player)
	var bot1: Character = mates[0]
	var bot2: Character = mates[1]
	var enemies := _rounds.get_members(1)
	var bot3: Character = enemies[0]
	var bot4: Character = enemies[1]
	var bot5: Character = enemies[2]
	bot3.take_damage(80.0, Hitbox.Zone.STOMACH, bot1)
	bot4.take_damage(80.0, Hitbox.Zone.STOMACH, bot1)
	bot3.take_damage(500.0, Hitbox.Zone.CHEST, bot2)
	bot4.take_damage(500.0, Hitbox.Zone.CHEST, bot2)
	bot5.take_damage(20.6, Hitbox.Zone.CHEST, _player)
	_player.take_damage(30.0, Hitbox.Zone.CHEST, bot5)
	await _wait_ticks(2)
	table.refresh()
	# name, kills, deaths, assists, damage (rounded)
	var expected := {
		_player: [_player.name + " (you)", "0", "0", "0", "21"],
		bot1: [bot1.name, "0", "0", "2", "160"],
		bot2: [bot2.name, "2", "0", "0", "40"],
		bot3: [bot3.name, "0", "1", "0", "0"],
		bot4: [bot4.name, "0", "1", "0", "0"],
		bot5: [bot5.name, "0", "0", "0", "30"],
	}
	var wrong := ""
	for member: Character in expected:
		var stats := _rounds.get_stats(member)
		var from_stats := [member.name + " (you)" if member == _player else String(member.name),
				str(stats.kills), str(stats.deaths), str(stats.assists), str(roundi(stats.damage))]
		var shown := _row_cells(table.get_row(member))
		var wanted: Array = (expected[member] as Array).map(func(cell: Variant) -> String: return String(cell))
		if shown != wanted or shown != from_stats:
			wrong += "%s shows %s (expected %s, get_stats() says %s); " % [member.name, shown, wanted, from_stats]
	_check("Every row shows name, kills, deaths, assists and rounded damage, as get_stats() has them (you are marked '(you)', 20.6 damage reads 21)",
			wrong.is_empty(), "all six rows match" if wrong.is_empty() else wrong)
	_check("Rows are sorted by kills, then damage, then join order: Bot2 (2 kills) before Bot1 (more damage) before you; Bot5 (30 damage) before Bot3 and Bot4",
			_names(table.get_displayed(0)) == _names([bot2, bot1, _player]) and _names(table.get_displayed(1)) == _names([bot5, bot3, bot4]),
			"your team %s, enemies %s" % [_names(table.get_displayed(0)), _names(table.get_displayed(1))])
	var dimmed := _rounds.get_participants().filter(func(member: Character) -> bool: return table.get_row(member).modulate.a < 1.0)
	_check("Dead players' rows are dimmed (Bot3 and Bot4), the rows of the living are not",
			_names(dimmed) == _names([bot3, bot4]) and is_equal_approx(table.get_row(bot3).modulate.a, ThemeDB.get_project_theme().get_color("dead_row", "Palette").a),
			"dimmed rows: %s" % [_names(dimmed)])
	var highlighted := _rounds.get_participants().filter(func(member: Character) -> bool: return _is_highlighted(table.get_row(member)))
	_check("Only your own row is highlighted",
			_names(highlighted) == _names([_player]), "highlighted rows: %s" % [_names(highlighted)])

	# Refreshing: nothing changed means the same rows; a change shows up.
	var row_before := table.get_row(_player)
	table.refresh()
	var kept := table.get_row(_player) == row_before
	bot5.take_damage(10.0, Hitbox.Zone.CHEST, _player)
	table.refresh()
	var damage_now: String = _row_cells(table.get_row(_player))[4]
	_check("refresh() leaves the rows alone when nothing changed and shows new damage when it did (31 after 10 more)",
			kept and damage_now == "31", "rows kept: %s, your damage now '%s'" % [kept, damage_now])

	# The next round: everyone is back, so nothing is dimmed; the stats stay.
	bot5.take_damage(500.0, Hitbox.Zone.CHEST, _player)
	await _wait_for_phase(RoundManager.Phase.FREEZE)
	await _wait_ticks(2)
	table.refresh()
	dimmed = _rounds.get_participants().filter(func(member: Character) -> bool: return table.get_row(member).modulate.a < 1.0)
	var yours := _row_cells(table.get_row(_player))
	_check("In the next round everyone is alive again and nothing is dimmed, while the numbers carry over (you: 1 kill, 100 damage; Bot2 still first)",
			_rounds.round_number == 2 and dimmed.is_empty() and yours == [_player.name + " (you)", "1", "0", "0", "100"]
					and _names(table.get_displayed(0)) == _names([bot2, _player, bot1]),
			"round %d, dimmed %s, your row %s, your team %s" % [_rounds.round_number, _names(dimmed), yours, _names(table.get_displayed(0))])
	remove_child(table)
	table.queue_free()


## The hold-Tab overlay, in a match with a long round.
func _test_scoreboard_overlay() -> void:
	await _new_match(MatchSettings.new().rounds_to_win, HUD_ROUND_TIME)
	_hold_bots()
	var board := SCOREBOARD_SCENE.instantiate() as Scoreboard
	add_child(board)
	board.set_round_manager(_rounds)
	var table := board.get_node("Center/Panel/Margin/Content/Table") as ScoreboardTable
	await _wait_ticks(2)
	var before := board.visible
	Input.action_press("scoreboard")
	await _wait_ticks(2)
	var held := board.visible
	Input.action_release("scoreboard")
	await _wait_ticks(2)
	_check("The overlay is hidden until Tab is held, shows while it is held and hides when it is let go",
			not before and held and not board.visible, "before %s, held %s, after release %s" % [before, held, board.visible])

	Input.action_press("scoreboard")
	await _wait_ticks(2)
	var header := _board_header(board)
	var blue := _ui_team_color(true)
	var red := _ui_team_color(false)
	_check("The header shows the round and the score, yours in blue and theirs in red, above the table of both teams",
			header["round"] == "Round 1" and header["yours"] == "0" and header["theirs"] == "0"
					and header["yours_color"] == blue and header["theirs_color"] == red
					and table.get_child_count() == 2 and table.get_displayed(0).size() == 3 and table.get_displayed(1).size() == 3,
			"header %s, %d team box(es)" % [header, table.get_child_count()])

	# It follows the match while held, with no refresh call: damage, a kill, a dead row.
	await _wait_for_phase(RoundManager.Phase.LIVE)
	var enemies := _rounds.get_members(1)
	enemies[0].take_damage(40.0, Hitbox.Zone.CHEST, _player)
	await _wait_ticks(2)
	var after_damage := _row_cells(table.get_row(_player))
	enemies[0].take_damage(500.0, Hitbox.Zone.CHEST, _player)
	await _wait_ticks(2)
	var after_kill := _row_cells(table.get_row(_player))
	_check("While it is held the table follows the match without being asked: damage (40), then a kill (1 kill, 100 damage) and the victim's row dimmed",
			after_damage[4] == "40" and after_kill[1] == "1" and after_kill[4] == "100"
					and table.get_row(enemies[0]).modulate.a < 1.0 and table.get_row(enemies[1]).modulate.a == 1.0,
			"after the damage %s, after the kill %s, victim's row alpha %.2f" % [after_damage, after_kill, table.get_row(enemies[0]).modulate.a])

	# It doesn't block movement or pause the game.
	var start := _player.global_position
	Input.action_press("move_forward")
	await _wait_seconds(0.3)
	Input.action_release("move_forward")
	var moved := _player.global_position.distance_to(start)
	_check("It doesn't pause or block anything: with the overlay up you still walk (moved %.1f m in 0.3 s)" % moved,
			board.visible and moved > 0.5 and not get_tree().paused, "visible %s, moved %.2f m, paused %s" % [board.visible, moved, get_tree().paused])

	# The developer console owns the keyboard while it is open.
	DevConsole.is_open = true
	await _wait_ticks(2)
	var with_console := board.visible
	DevConsole.is_open = false
	await _wait_ticks(2)
	_check("Tab is ignored while the developer console is open (and counts again when it closes)",
			not with_console and board.visible, "visible with the console open: %s, after closing it: %s" % [with_console, board.visible])

	# Nothing in it takes a click.
	var blocking: Array[String] = []
	for control: Control in board.find_children("*", "Control", true, false):
		if control.mouse_filter != Control.MOUSE_FILTER_IGNORE:
			blocking.append(String(control.name))
	_check("No part of the overlay takes mouse clicks, so they still reach the player controls",
			blocking.is_empty(), "controls that would take clicks: %s" % [blocking])

	# Scaling: the panel and the rows, also rows built after the scale was set.
	board.set_ui_scale(1.5)
	var panel := board.get_node("Center/Panel") as Control
	var width_scaled := panel.custom_minimum_size.x
	var font_scaled := _row_font_size(table.get_row(_player))
	enemies[1].take_damage(10.0, Hitbox.Zone.CHEST, _player)
	await _wait_ticks(2)
	var font_rebuilt := _row_font_size(table.get_row(_player))
	board.set_ui_scale(1.0)
	var font_back := _row_font_size(table.get_row(_player))
	_check("UI scale 1.5 scales the panel (640 -> 960) and the rows, also rows rebuilt afterwards (font 16 -> 24); 1.0 restores them",
			width_scaled == 960.0 and font_scaled == 24 and font_rebuilt == 24 and font_back == 16 and panel.custom_minimum_size.x == 640.0,
			"panel %.0f, row font %d, after a rebuild %d, back at 1.0: %d" % [width_scaled, font_scaled, font_rebuilt, font_back])

	# After a round: the score and the next round's number.
	await _win_round(0)
	await _wait_ticks(2)
	header = _board_header(board)
	var round_one_won: bool = header["round"] == "Round 1" and header["yours"] == "1" and header["theirs"] == "0"
	await _wait_for_phase(RoundManager.Phase.FREEZE)
	await _wait_ticks(2)
	var next_header := _board_header(board)
	_check("After winning round 1 the header reads 'Round 1' and 1 - 0; the next round it reads 'Round 2' with the score kept",
			round_one_won and next_header["round"] == "Round 2" and next_header["yours"] == "1" and next_header["theirs"] == "0",
			"after the round: %s; next round: %s" % [header, next_header])

	# A replaced round manager (Play again loads a new map) shows nothing until the new one arrives; null (practice) never shows.
	await _new_match(MatchSettings.new().rounds_to_win, HUD_ROUND_TIME)
	await _wait_ticks(2)
	var stale := board.visible
	board.set_round_manager(_rounds)
	await _wait_ticks(2)
	var new_header := _board_header(board)
	var fresh: bool = board.visible and new_header["round"] == "Round 1" and new_header["yours"] == "0" and table.get_displayed(0).size() == 3
	board.set_round_manager(null)
	await _wait_ticks(2)
	var practice := board.visible
	_check("A replaced round manager (Play again) is never read: the overlay stays hidden until the new one is handed over, then shows the new match; with none (practice mode) it never shows",
			not stale and fresh and not practice,
			"visible with the old manager gone: %s, with the new one: %s (%s), with none: %s" % [stale, fresh, new_header, practice])
	Input.action_release("scoreboard")

	# The match is over: the end screen shows the final table instead.
	await _new_match(1)
	_hold_bots()
	board.set_round_manager(_rounds)
	Input.action_press("scoreboard")
	await _win_round(0)
	await _wait_ticks(2)
	var last_pause := board.visible and _rounds.phase == RoundManager.Phase.ROUND_END
	await _wait_for_phase(RoundManager.Phase.MATCH_END)
	await _wait_ticks(2)
	var at_match_end := board.visible
	Input.action_release("scoreboard")
	_check("It still shows in the last round's pause, and hides once the match is over (the match-end screen takes over)",
			last_pause and not at_match_end, "in the last pause: %s, at the match end: %s" % [last_pause, at_match_end])
	remove_child(board)
	board.queue_free()


## The match-end screen builds its scoreboard from the same table, with the
## final numbers (nobody dimmed, although the losers are dead).
func _test_scoreboard_in_match_end_screen() -> void:
	await _new_match(1)
	_hold_bots()
	var screen := MATCH_END_SCENE.instantiate() as MatchEndScreen
	add_child(screen)
	screen.set_round_manager(_rounds)
	await _win_round(0)
	await _wait_for_phase(RoundManager.Phase.MATCH_END)
	await _wait_ticks(2)
	var table := screen.get_node("Panel/Margin/Content/Table") as ScoreboardTable
	var title := screen.get_node("Panel/Margin/Content/Title") as Label
	var team_boxes := table.get_children().map(func(box: Node) -> String: return String(box.name))
	var dead := _rounds.get_participants().filter(func(member: Character) -> bool: return not member.is_alive())
	var dimmed := _rounds.get_participants().filter(func(member: Character) -> bool: return table.get_row(member).modulate.a < 1.0)
	var yours := _row_cells(table.get_row(_player))
	_check("The match-end screen shows 'Victory' and the same table: your team first, 3 rows each, your row marked with 3 kills and 300 damage, and nobody dimmed although the 3 enemies are dead",
			screen.visible and title.text == "Victory" and team_boxes == ["Team0", "Team1"] and table.get_displayed(0).size() == 3
					and table.get_displayed(1).size() == 3 and yours == [_player.name + " (you)", "3", "0", "0", "300"]
					and _is_highlighted(table.get_row(_player)) and dead.size() == 3 and dimmed.is_empty(),
			"visible %s, title '%s', boxes %s, your row %s, %d dead, dimmed %s" % [screen.visible, title.text, team_boxes, yours, dead.size(), _names(dimmed)])
	screen.set_ui_scale(2.0)
	var font_scaled := _row_font_size(table.get_row(_player))
	screen.set_ui_scale(1.0)
	var font_back := _row_font_size(table.get_row(_player))
	screen.set_round_manager(null)
	_check("The screen scales the table's rows with itself (font 16 -> 32 -> 16), and handing it no round manager hides it and empties the table",
			font_scaled == 32 and font_back == 16 and not screen.visible and table.get_child_count() == 0,
			"row font at 2.0: %d, back at 1.0: %d, visible %s, %d team box(es) left" % [font_scaled, font_back, screen.visible, table.get_child_count()])
	remove_child(screen)
	screen.queue_free()



# --- Helpers ---


## A HUD (the real ui/hud.tscn) for the current player and round manager, set up as main.gd does.
func _new_hud() -> Node:
	var hud := HUD_SCENE.instantiate()
	add_child(hud)
	hud.call("set_player", _player)
	hud.call("set_round_manager", _rounds)
	return hud


func _free_hud(hud: Node) -> void:
	remove_child(hud)
	hud.queue_free()


func _round_hud(hud: Node) -> RoundHud:
	return hud.get_node("RoundHud") as RoundHud


func _feed(hud: Node) -> KillFeed:
	return hud.get_node("RoundHud/KillFeed") as KillFeed


## The top bar as [your score, timer, their score, round label, your players alive, their players alive].
func _bar(hud: Node) -> Array:
	var round_hud := _round_hud(hud)
	return [
		(hud.get_node("RoundHud/TopBar/YourBox/Margin/Content/Score") as Label).text,
		(hud.get_node("RoundHud/TopBar/TimerBox/Margin/Content/Timer") as Label).text,
		(hud.get_node("RoundHud/TopBar/EnemyBox/Margin/Content/Score") as Label).text,
		(hud.get_node("RoundHud/TopBar/TimerBox/Margin/Content/RoundLabel") as Label).text,
		round_hud.get_alive_shown(Teams.viewer_team),
		round_hud.get_alive_shown(Teams.other(Teams.viewer_team)),
	]


## The center messages as [title, line 1, line 2, line 3]; a hidden line counts as empty.
func _center(hud: Node) -> Array:
	var lines := []
	for label_name in HUD_HEADLINES:
		var label := hud.get_node("RoundHud/Center/" + label_name) as Label
		lines.append(label.text if label.visible else "")
	return lines


func _center_color(hud: Node, label_name: String) -> Color:
	return (hud.get_node("RoundHud/Center/" + label_name) as Label).get_theme_color("font_color")


## What a kill-feed line shows: names and colors (empty when there is no killer), the headshot mark and whether it is highlighted.
func _read_line(line: Node) -> Dictionary:
	var killer := line.find_child("Killer", true, false) as Label
	var separator := line.find_child("Separator", true, false) as Label
	var victim := line.find_child("Victim", true, false) as Label
	var panel := (line as Control).get_theme_stylebox("panel") as StyleBoxFlat
	return {
		"killer": killer.text if killer != null else "",
		"killer_color": killer.get_theme_color("font_color") if killer != null else Color(0, 0, 0, 0),
		"separator": separator.text if separator != null else "",
		"victim": victim.text,
		"victim_color": victim.get_theme_color("font_color"),
		"headshot": line.find_child("Headshot", true, false) != null,
		"highlighted": panel.border_width_left > 0,
	}


## How many of the round manager's signals are connected to [param node].
func _listeners(manager: RoundManager, node: Node) -> int:
	var count := 0
	for connected_signal: Signal in [manager.phase_changed, manager.round_started, manager.round_ended,
			manager.sides_swapped, manager.character_killed]:
		for connection in connected_signal.get_connections():
			if (connection["callable"] as Callable).get_object() == node:
				count += 1
	return count


## Checks the banner against what the last round_ended announced (the last
## entry of _results), phrased for your side and colored blue (won) or red (lost);
## after a time-out the timer reads 0:00. Notes the outcome in [param outcomes].
func _check_banner(hud: Node, label: String, outcomes: Dictionary) -> void:
	var result: Array = _results.back()
	var won: bool = result[0] == Teams.viewer_team
	var by_time: bool = result[1] == RoundManager.EndReason.TIME
	var reason_text: String
	if by_time:
		reason_text = "Time ran out: you held your end" if won else "Time ran out: the defenders held their end"
	else:
		reason_text = "Enemy team eliminated" if won else "Your team was eliminated"
	var color := (Teams.FRIENDLY_COLOR if won else Teams.ENEMY_COLOR).lightened(Teams.TEXT_LIGHTEN)
	var center := _center(hud)
	var timer := (_bar(hud))[1] as String
	outcomes["%s by %s" % ["won" if won else "lost", "time-out" if by_time else "elimination"]] = true
	_check("Round-end banner (%s): %s by %s" % [label, "won" if won else "lost", "time-out" if by_time else "elimination"],
			center == ["Round won" if won else "Round lost", reason_text, "", ""] and _center_color(hud, "Title") == color
					and (not by_time or timer == "0:00"),
			"center %s, title color %s (expected %s), timer %s" % [center, _center_color(hud, "Title"), color, timer])


## The text of every label in a scoreboard row or header, left to right.
func _row_cells(row: Node) -> Array:
	return row.find_children("*", "Label", true, false).map(func(label: Node) -> String: return (label as Label).text)


## The colour of the line under a team's column titles (D-134: a 2 px line in the UI's team colour).
func _header_color(table: ScoreboardTable, team: int) -> Color:
	return ((table.get_node("Team%d/Header" % team) as Control).get_theme_stylebox("panel") as StyleBoxFlat).border_color


## The UI's team colour (D-134) from the theme: yours ([param friendly]) or the enemy's.
func _ui_team_color(friendly: bool) -> Color:
	return ThemeDB.get_project_theme().get_color("friendly_text" if friendly else "enemy_text", "Palette")


## True if the row has the highlight background of your own row (the theme's "YouRowPanel").
func _is_highlighted(row: Control) -> bool:
	var background := row.get_theme_stylebox("panel") as StyleBoxFlat
	var highlight := ThemeDB.get_project_theme().get_stylebox("panel", "YouRowPanel") as StyleBoxFlat
	return background != null and highlight != null and background.bg_color == highlight.bg_color


func _row_font_size(row: Node) -> int:
	return (row.find_children("*", "Label", true, false)[0] as Label).get_theme_font_size("font_size")


func _names(characters: Array) -> Array:
	return characters.map(func(character: Character) -> String: return String(character.name))


## What the overlay's header shows: the round label, both scores and their colors.
func _board_header(board: Scoreboard) -> Dictionary:
	var your_score := board.get_node("Center/Panel/Margin/Content/Score/YourScore") as Label
	var their_score := board.get_node("Center/Panel/Margin/Content/Score/EnemyScore") as Label
	return {
		"round": (board.get_node("Center/Panel/Margin/Content/RoundLabel") as Label).text,
		"yours": your_score.text,
		"theirs": their_score.text,
		"yours_color": your_score.get_theme_color("font_color"),
		"theirs_color": their_score.get_theme_color("font_color"),
	}


func _distance_to_own_spawn(member: Character) -> float:
	var closest := INF
	for marker in get_tree().get_nodes_in_group(Teams.spawn_group(_rounds.get_side(member.team))):
		closest = minf(closest, member.global_position.distance_to((marker as Node3D).global_position))
	return closest


func _distance_to_group(member: Character, group: String) -> float:
	var closest := INF
	for marker in get_tree().get_nodes_in_group(group):
		closest = minf(closest, member.global_position.distance_to((marker as Node3D).global_position))
	return closest


## Makes the bots hold their spawn, so the teams never meet.
func _hold_bots() -> void:
	for member in _rounds.get_participants():
		if member != _player:
			(member.get_node("BotController") as BotController).hold_position = true


## Plays a round to its end: waits for the live phase, then [param team] kills
## the whole other team, and waits for the round-end pause.
func _win_round(team: int) -> void:
	await _wait_for_phase(RoundManager.Phase.LIVE)
	var killer := _rounds.get_members(team)[0]
	for victim in _rounds.get_members(Teams.other(team)):
		victim.take_damage(500.0, Hitbox.Zone.CHEST, killer)
	await _wait_for_phase(RoundManager.Phase.ROUND_END)


## True if the camera sits at the head of [param character] and looks along their aim.
func _view_matches(camera: Camera3D, character: Character) -> bool:
	var aim := character.get_aim_angles()
	var aim_direction := -Basis.from_euler(Vector3(aim.y, aim.x, 0.0)).z
	var looking := -camera.global_transform.basis.z
	return camera.global_position.distance_to(character.head.global_position) < 0.05 \
			and looking.angle_to(aim_direction) < deg_to_rad(1.0)


func _view_detail(camera: Camera3D, character: Character) -> String:
	var aim := character.get_aim_angles()
	var aim_direction := -Basis.from_euler(Vector3(aim.y, aim.x, 0.0)).z
	return "camera %.3f m from %s's head, %.2f° off their aim" % [
			camera.global_position.distance_to(character.head.global_position), character.name,
			rad_to_deg((-camera.global_transform.basis.z).angle_to(aim_direction))]


## Clicks the left mouse button (press, then release) through the real input path.
func _click() -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		Input.parse_input_event(event)
		await _wait_ticks(1)


## Waits until the round manager reaches [param phase] (at most 10 s).
func _wait_for_phase(phase: RoundManager.Phase) -> void:
	var ticks := 0
	while _rounds.phase != phase and ticks < 128 * 10:
		await get_tree().physics_frame
		ticks += 1


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


func _wait_seconds(seconds: float) -> void:
	await _wait_ticks(roundi(seconds * Engine.physics_ticks_per_second))


func _wait_ticks(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _check(check_name: String, passed: bool, detail: String) -> void:
	print("%s  %s: %s" % ["PASS" if passed else "FAIL", check_name, detail])
	if not passed:
		_failures += 1
