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
## (practice mode) nothing changes. Quits with the number of failed checks as the
## exit code (0 means everything passed).

const MAP_SCENE := preload("res://maps/test_map.tscn")
const FREEZE_TIME := 0.5
const ROUND_TIME := 2.0
const ROUND_END_TIME := 0.5
## The spectating checks need one long round and a long pause after it.
const SPECTATE_ROUND_TIME := 30.0
const SPECTATE_ROUND_END_TIME := 8.0

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


# --- Helpers ---


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
