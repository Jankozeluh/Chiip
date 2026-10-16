extends Node
## Automated checks for the team respawn mode (M8, D-082). Run without a window:
##
##     Godot --headless --path . --fixed-fps 128 --quit-after 100000 res://tests/respawn_test.tscn
##
## Plays short team respawn matches on Depot (kill limit 5, 20 s, 1 s to
## respawn). The bots are frozen once the match goes live, so they neither move
## nor shoot; the test decides the fights by dealing damage directly. Checks:
## the start (both team ends, freeze time, no bomb, the clock), kills scoring
## for the killer's team and nothing else, coming back after the respawn delay
## with full health at a respawn point, the choice of respawn point (away from
## the enemies and out of their sight), the kill limit, the time limit with a
## leader, overtime on a tie, the HUD's texts, and that the main scene runs the
## mode from the match settings with spectating off. The respawn countdown (M10,
## D-133) is checked through the real main scene: after you die in a team respawn
## match the round HUD says "Respawning in 3" and counts down to your return,
## and hides it when the round ends; practice still says "Respawning..." in the
## death message, and a rounds match has no countdown. Then bots-only matches
## check the bots' hunting (D-083): groups of about two, followers staying with
## their leader, sightings answered by the groups near them only, and groups
## coming back together after a respawn. Quits with the number of failed checks
## as the exit code.

const MAP_SCENE := preload("res://maps/depot.tscn")
const HUD_SCENE := preload("res://ui/hud.tscn")
const SCOREBOARD_SCENE := preload("res://ui/scoreboard.tscn")
const MAIN_SCENE := preload("res://main.tscn")
## The practice check plays the test map's bot arena.
const PRACTICE_MAP_SCENE := preload("res://maps/test_map.tscn")
const KILL_LIMIT := 5
const TIME_LIMIT := 20.0
const RESPAWN_DELAY := 1.0

var _map: Node3D
var _rounds: RespawnMatch
var _player: Character
var _hud: Node
var _failures: int = 0
## [winner, reason] for every round_ended signal, and the winner of every match_ended.
var _results: Array = []
var _match_ends: Array = []


func _ready() -> void:
	await _test_start()
	await _test_kills_and_respawns()
	await _test_spawn_choice()
	await _test_kill_limit()
	await _test_time_limit()
	await _test_overtime()
	await _test_main_scene()
	await _test_respawn_countdown()
	await _test_hunting_groups()
	await _test_sightings()
	_free_match()
	if _failures == 0:
		print("\nAll checks passed.")
	else:
		print("\n%d check(s) FAILED." % _failures)
	get_tree().quit(_failures)


# --- The checks ---


func _test_start() -> void:
	await _new_match()
	var at_ends := _rounds.get_participants().all(func(member: Character) -> bool:
		var group := Teams.spawn_group(_rounds.get_side(member.team))
		return _markers(group).any(func(marker: Node3D) -> bool: return _flat(marker.global_position, member.global_position) < 0.5))
	_check("A team respawn match starts like a round: both teams at their ends, frozen, no bomb",
			_rounds.is_team_respawn() and _rounds.phase == RoundManager.Phase.FREEZE and at_ends and _rounds.bomb == null
			and _player.frozen and _rounds.score == [0, 0],
			"phase %s, at their ends %s, bomb %s, score %s" % [RoundManager.Phase.keys()[_rounds.phase], at_ends, _rounds.bomb, _rounds.score])
	_check("The freeze time says what wins", _center() == ["Team respawn · starts in 1", "First team to %d kills wins" % KILL_LIMIT], str(_center()))
	await _go_live()
	_check("Live: the clock runs the time limit and the top bar says what wins",
			_rounds.phase == RoundManager.Phase.LIVE and absf(_rounds.time_left - TIME_LIMIT) < 0.1 and _round_label() == "First to %d" % KILL_LIMIT
			and _timer_text() == "0:20",
			"time left %.1f, label '%s', timer '%s'" % [_rounds.time_left, _round_label(), _timer_text()])


func _test_kills_and_respawns() -> void:
	var enemy := _rounds.get_members(1)[0]
	var mate := _rounds.get_members(0)[1]
	enemy.take_damage(500.0, Hitbox.Zone.HEAD, _player)
	await _wait_ticks(2)
	_check("A kill of an enemy is a point for the killer's team, shown in the top bar",
			_rounds.score == [1, 0] and _bar_score(0) == "1" and _bar_score(1) == "0", "score %s" % [_rounds.score])
	var round_hud := _hud.get_node("RoundHud") as RoundHud
	var your_fill := round_hud.get_node("%TdmYourFill") as Control
	var enemy_fill := round_hud.get_node("%TdmEnemyFill") as Control
	_check("The Team Deathmatch top bar is the one showing (not the chips): your bar fills from the right edge toward the timer by kills over the limit (1 of %d), the enemy's is empty" % KILL_LIMIT,
			round_hud.is_tdm_bar() and round_hud.get_node("%TdmBar").visible and not round_hud.get_node("%BombBar").visible
			and is_equal_approx(your_fill.anchor_left, 1.0 - 1.0 / KILL_LIMIT) and your_fill.anchor_right == 1.0 and your_fill.visible and not enemy_fill.visible,
			"your fill %.2f to %.2f (visible %s), enemy fill visible %s" % [your_fill.anchor_left, your_fill.anchor_right, your_fill.visible, enemy_fill.visible])
	_rounds.score[1] = 2
	await _wait_ticks(2)
	var enemy_bar := enemy_fill.anchor_left == 0.0 and is_equal_approx(enemy_fill.anchor_right, 2.0 / KILL_LIMIT) and enemy_fill.visible
	_rounds.score[1] = 0
	await _wait_ticks(2)
	_check("The enemy's bar fills from the left edge toward the timer (2 of %d)" % KILL_LIMIT, enemy_bar, "enemy fill %.2f to %.2f" % [enemy_fill.anchor_left, enemy_fill.anchor_right])
	mate.take_damage(500.0, Hitbox.Zone.CHEST, null)
	await _wait_ticks(2)
	_check("A death without an enemy killer scores nothing", _rounds.score == [1, 0], "score %s" % [_rounds.score])
	await _wait_seconds(RESPAWN_DELAY - 0.2)
	var still_dead := not enemy.is_alive() and _rounds.get_respawn_time_left(enemy) > 0.0
	await _wait_seconds(0.4)
	var on_marker := _markers(RespawnMatch.RESPAWN_GROUP).any(func(marker: Node3D) -> bool: return _flat(marker.global_position, enemy.global_position) < 0.5)
	_check("The dead come back after the respawn delay, with full health, at a respawn point",
			still_dead and enemy.is_alive() and enemy.health == enemy.max_health and on_marker and mate.is_alive()
			and _rounds.get_respawn_time_left(enemy) < 0.0,
			"dead at 0.8 s: %s, alive at 1.2 s: %s (%.0f HP), on a respawn point: %s" % [still_dead, enemy.is_alive(), enemy.health, on_marker])
	var stats := _rounds.get_stats(_player)
	_check("The scoreboard numbers count as in rounds", stats.kills == 1 and _rounds.get_stats(enemy).deaths == 1,
			"your kills %d, the enemy's deaths %d" % [stats.kills, _rounds.get_stats(enemy).deaths])


func _test_spawn_choice() -> void:
	var enemies := _rounds.get_members(1)
	var victim := _rounds.get_members(0)[2]
	# All enemies at the north end: the victim should come back at the south end, and the other way round.
	var picks := []
	for zone in ["North", "South"]:
		for i in enemies.size():
			await _teleport(enemies[i], _map.get_node("Respawns/%s%d" % [zone, i + 1]).global_position)
		var spot := _rounds.pick_spawn(victim).origin
		var nearest := INF
		var seen := false
		for enemy in enemies:
			nearest = minf(nearest, _flat(enemy.global_position, spot))
			seen = seen or _rounds._can_see_spot(enemy, spot, victim)
		picks.append([zone, _marker_name_at(spot), nearest, seen])
	# Every spot 40 m or more from the nearest enemy counts as equally safe (RespawnMatch.SAFE_DISTANCE).
	var ok: bool = picks.all(func(pick: Array) -> bool: return pick[2] >= 35.0 and not pick[3]) \
			and not String(picks[0][1]).begins_with("North") and not String(picks[1][1]).begins_with("South")
	_check("A respawn point is chosen away from the enemies (35 m or more here) and out of their sight",
			ok, ", ".join(picks.map(func(pick: Array) -> String: return "enemies %s → %s (%.0f m, seen %s)" % pick)))
	# A spot someone stands on is skipped.
	var free_spot := _rounds.pick_spawn(victim).origin
	var blocker := _rounds.get_members(0)[1]
	await _teleport(blocker, free_spot)
	var second := _rounds.pick_spawn(victim).origin
	_check("A respawn point someone stands on is skipped", _flat(second, free_spot) > 1.0,
			"%s taken, chose %s" % [_marker_name_at(free_spot), _marker_name_at(second)])


func _test_kill_limit() -> void:
	await _new_match()
	await _go_live()
	var killer := _rounds.get_members(1)[0]
	var victims := _rounds.get_members(0)
	for i in KILL_LIMIT:
		victims[i % victims.size()].take_damage(500.0, Hitbox.Zone.CHEST, killer)
		await _wait_seconds(RESPAWN_DELAY + 0.2 if i < KILL_LIMIT - 1 else 0.1)
	_check("The first team to the kill limit wins: the banner says who and why",
			_results == [[1, RoundManager.EndReason.KILL_LIMIT]] and _rounds.score == [0, KILL_LIMIT]
			and _center()[0] == "The enemy team wins" and _center()[1] == "First to %d kills" % KILL_LIMIT,
			"results %s, score %s, banner %s" % [_results, _rounds.score, _center()])
	await _wait_seconds(1.1)
	_check("After the round-end pause the match ends", _match_ends == [1] and _rounds.phase == RoundManager.Phase.MATCH_END,
			"match ends %s, phase %s" % [_match_ends, RoundManager.Phase.keys()[_rounds.phase]])


func _test_time_limit() -> void:
	await _new_match()
	await _go_live()
	_rounds.get_members(1)[0].take_damage(500.0, Hitbox.Zone.CHEST, _player)
	await _wait_seconds(TIME_LIMIT + 0.2)
	_check("When time runs out, the team with more kills wins",
			_results == [[0, RoundManager.EndReason.TIME_LIMIT]] and _center()[0] == "Your team wins"
			and _center()[1] == "Most kills when time ran out",
			"results %s, banner %s" % [_results, _center()])


func _test_overtime() -> void:
	await _new_match()
	await _go_live()
	await _wait_seconds(TIME_LIMIT + 0.2)
	await _wait_ticks(2)
	_check("A tie when time runs out goes to overtime: the clock shows OT and the next kill wins",
			_rounds.overtime and _rounds.phase == RoundManager.Phase.LIVE and _results.is_empty()
			and _timer_text() == RoundHud.OVERTIME_TIMER_TEXT and _round_label() == "Next kill wins" and _center()[0] == "Overtime",
			"overtime %s, phase %s, timer '%s', label '%s', center %s" % [_rounds.overtime, RoundManager.Phase.keys()[_rounds.phase], _timer_text(), _round_label(), _center()])
	await _wait_seconds(2.0)
	var still := _rounds.phase == RoundManager.Phase.LIVE
	_rounds.get_members(0)[0].take_damage(500.0, Hitbox.Zone.CHEST, _rounds.get_members(1)[1])
	await _wait_ticks(2)
	_check("In overtime the next kill decides the match", still and _results == [[1, RoundManager.EndReason.TIME_LIMIT]],
			"still live after 2 s: %s, results %s" % [still, _results])


## The main scene plays a team respawn match when the match settings say so,
## without spectating, and without the practice mode's "Respawning..." hint
## (the round HUD counts the seconds instead).
func _test_main_scene() -> void:
	_free_match()
	var main := MAIN_SCENE.instantiate()
	# Never read or write the player's settings file (M5's Settings; a no-op before it exists).
	main.set("load_settings", false)
	main.set("map_scene", MAP_SCENE)
	var settings := MatchSettings.new()
	settings.game_mode = MatchSettings.GameMode.TEAM_RESPAWN
	main.set("match_settings", settings)
	add_child(main)
	await _wait_ticks(3)
	var map: Node = main.call("get_map")
	var rules := map.get_node_or_null("RespawnMatch") as RespawnMatch
	if rules != null:
		for member in rules.get_participants():
			_silence(member)
	var controller := map.get_node("Player/PlayerController") as PlayerController
	var hud := main.get_node("HUD")
	_check("The main scene runs team respawn from the match settings, with no spectating and without the practice hint (the countdown is in the round HUD)",
			rules != null and map.get_node_or_null("RoundManager") == null and not controller.spectating_enabled
			and hud.get("respawn_hint") == false,
			"rules %s, spectating %s, respawn hint %s" % [rules, controller.spectating_enabled, hud.get("respawn_hint")])
	remove_child(main)
	main.queue_free()


## The respawn countdown (M10, D-133, D-141) in the real main scene: team respawn says
## "Respawning in 3" (the default delay) on the death plate under the big 3, counts down to 2
## and 1 and is gone after the respawn; it is hidden at the round end and the match
## end while you are still dead; practice keeps "Respawning..." on the plate and shows
## no countdown; a rounds match has none either.
func _test_respawn_countdown() -> void:
	var settings := MatchSettings.new()
	settings.game_mode = MatchSettings.GameMode.TEAM_RESPAWN
	settings.freeze_time = 0.3
	settings.round_end_time = 0.5
	settings.kill_limit = 2
	var main := await _new_main(settings)
	var rules := main.call("get_map").get_node("RespawnMatch") as RespawnMatch
	var player := main.call("get_map").get_node("Player") as Character
	var hud := main.get_node("HUD")
	await _go_live_in(rules)
	var enemies := rules.get_members(1)
	var mate := rules.get_members(0).filter(func(member: Character) -> bool: return member != player)[0] as Character
	_check("Alive in a live team respawn match: no countdown, the death view is hidden and the corners show", hud.call("get_respawn_text") == "" and _is_default_delay(rules)
			and not _node(hud, "DeathColumn").visible and _node(hud, "BottomLeft").visible and not _node(hud, "DeadTint").visible,
			"text '%s', delay %.1f s" % [hud.call("get_respawn_text"), rules.settings.respawn_delay])
	var hp_before := ceili(enemies[0].health)
	player.take_damage(500.0, Hitbox.Zone.CHEST, enemies[0])
	await _wait_ticks(2)
	var killed := _node(hud, "KilledLabel") as Label
	var killer := _node(hud, "KillerLabel") as Label
	var countdown := _node(hud, "Countdown") as Label
	var respawn := _node(hud, "RespawnLabel") as Label
	_check("You die in a team respawn match: the world is tinted, the corners hide, a big '3' counts down over a plate saying 'Killed by', the killer's name and weapon, '·' and 'Respawning in 3', and under it the killer's health",
			hud.call("get_respawn_text") == "Respawning in 3" and _node(hud, "DeathColumn").visible and _node(hud, "DeadTint").visible
			and not _node(hud, "BottomLeft").visible and not _node(hud, "BottomRight").visible
			and killed.text == "Killed by" and killer.text == String(enemies[0].name) and (_node(hud, "KillerIcon") as Control).visible
			and countdown.visible and countdown.text == "3" and respawn.visible and respawn.text == "Respawning in 3" and _node(hud, "DeathDot").visible
			and (_node(hud, "KillerHp") as Label).text == "%s · %d HP left" % [enemies[0].name, hp_before],
			"countdown '%s' / '%s', plate '%s' '%s' '%s', hp '%s'" % [hud.call("get_respawn_text"), countdown.text, killed.text, killer.text, respawn.text, (_node(hud, "KillerHp") as Label).text])
	await _wait_seconds(1.0)
	var after_one: String = hud.call("get_respawn_text")
	await _wait_seconds(1.0)
	var after_two: String = hud.call("get_respawn_text")
	_check("The countdown follows the manager's clock, the seconds rounded up: 3, then 2 a second later, then 1; the big number and the plate say the same",
			after_one == "Respawning in 2" and after_two == "Respawning in 1" and countdown.text == "1" and respawn.text == "Respawning in 1",
			"after 1 s '%s', after 2 s '%s' (manager says %.2f s left), big '%s'" % [after_one, after_two, rules.get_respawn_time_left(player), countdown.text])
	await _wait_seconds(1.2)
	_check("After the respawn the countdown and the death view are gone, the corners are back, and you are alive again",
			player.is_alive() and hud.call("get_respawn_text") == "" and not _node(hud, "DeathColumn").visible and not _node(hud, "DeadTint").visible
			and _node(hud, "BottomLeft").visible,
			"alive %s, countdown '%s', death view visible %s" % [player.is_alive(), hud.call("get_respawn_text"), _node(hud, "DeathColumn").visible])
	# The deciding kill while you are dead: first to 2 kills. You die with no killer (no point for
	# anyone), then your teammate kills two enemies (2 for your team).
	player.take_damage(500.0, Hitbox.Zone.CHEST, null)
	await _wait_ticks(2)
	var counting: bool = hud.call("get_respawn_text") == "Respawning in 3"
	var no_killer := killed.text == "You died" and not killer.visible and not (_node(hud, "KillerHp") as Label).visible
	enemies[0].take_damage(500.0, Hitbox.Zone.CHEST, mate)
	enemies[1].take_damage(500.0, Hitbox.Zone.CHEST, mate)
	await _wait_ticks(3)
	var round_hud := main.get_node("HUD/RoundHud") as RoundHud
	_check("A death with no killer says 'You died'; the round end hides the countdown at once, although the manager still has you waiting",
			counting and no_killer and rules.phase == RoundManager.Phase.ROUND_END and rules.get_respawn_time_left(player) > 0.0
			and hud.call("get_respawn_text") == "" and not countdown.visible and not respawn.visible,
			"counting before %s, no killer line %s, phase %s, manager %.2f s, countdown '%s'" % [counting, no_killer, RoundManager.Phase.keys()[rules.phase],
					rules.get_respawn_time_left(player), hud.call("get_respawn_text")])
	await _wait_seconds(0.7)
	_check("At the match end there is no countdown either",
			rules.phase == RoundManager.Phase.MATCH_END and hud.call("get_respawn_text") == "" and round_hud.get_round_text() != "",
			"phase %s, countdown '%s'" % [RoundManager.Phase.keys()[rules.phase], hud.call("get_respawn_text")])
	_remove_main(main)

	# Practice: the arena brings you back, and the plate still says so; the round HUD is not shown.
	var practice_settings := MatchSettings.new()
	main = await _new_main(practice_settings, true, PRACTICE_MAP_SCENE)
	var arena := main.call("get_map").get_node("ArenaRules") as ArenaRules
	player = main.call("get_map").get_node("Player") as Character
	for bot in arena.get_bots():
		bot.frozen = true
	round_hud = main.get_node("HUD/RoundHud") as RoundHud
	hud = main.get_node("HUD")
	player.take_damage(500.0, Hitbox.Zone.CHEST, arena.get_bots()[0])
	await _wait_ticks(3)
	_check("Practice: the plate says 'Killed by' and who, then 'Respawning...', and there is no countdown",
			(_node(hud, "KilledLabel") as Label).text == "Killed by" and (_node(hud, "KillerLabel") as Label).text == String(arena.get_bots()[0].name)
			and (_node(hud, "RespawnLabel") as Label).text == "Respawning..." and (_node(hud, "RespawnLabel") as Label).visible
			and not (_node(hud, "Countdown") as Label).visible and hud.call("get_respawn_text") == "" and not round_hud.visible and hud.get("respawn_hint") == true,
			"plate '%s' '%s', countdown '%s', round HUD visible %s" % [(_node(hud, "KilledLabel") as Label).text, (_node(hud, "RespawnLabel") as Label).text,
					hud.call("get_respawn_text"), round_hud.visible])
	_remove_main(main)

	# A rounds match: the dead wait for the next round, so no countdown and no "Respawning" anywhere.
	var rounds_settings := MatchSettings.new()
	rounds_settings.freeze_time = 0.3
	main = await _new_main(rounds_settings)
	var round_rules := main.call("get_map").get_node("RoundManager") as RoundManager
	player = main.call("get_map").get_node("Player") as Character
	hud = main.get_node("HUD")
	await _go_live_in(round_rules)
	player.take_damage(500.0, Hitbox.Zone.CHEST, round_rules.get_members(1)[0])
	await _wait_ticks(3)
	_check("A rounds match: no countdown and no 'Respawning' on the plate after you die (the dead wait for the next round)",
			hud.call("get_respawn_text") == "" and not (_node(hud, "RespawnLabel") as Label).visible and not (_node(hud, "Countdown") as Label).visible
			and hud.get("respawn_hint") == false,
			"countdown '%s', respawn visible %s, hint %s" % [hud.call("get_respawn_text"), (_node(hud, "RespawnLabel") as Label).visible, hud.get("respawn_hint")])
	_remove_main(main)


## A named part of the HUD ("%Name" inside the HUD scene).
func _node(hud: Node, node_name: String) -> Node:
	return hud.get_node("%" + node_name)


# --- Bots hunting ---


func _test_hunting_groups() -> void:
	await _new_match(false)
	var sizes := []
	for team in Teams.COUNT:
		var plan := _rounds.get_hunt_plan(team)
		var team_sizes := plan.groups.map(func(group: Array) -> int: return group.size())
		team_sizes.sort()
		sizes.append(team_sizes)
	var hunting := _rounds.get_participants().all(func(member: Character) -> bool:
		return (member.get_node("BotController") as BotController).role == BotController.Role.HUNT)
	_check("Every bot hunts, each team in groups of about two (3 bots: a pair and a single)",
			hunting and sizes == [[1, 2], [1, 2]], "hunting %s, group sizes %s" % [hunting, sizes])
	# Without enemies to fight, team 0's pair roams the map. No map weapons: this checks that the
	# pair keeps together, not the detours a bot makes for a gun (D-098, D-099).
	_rounds.map_weapons.clear()
	_rounds.map_weapons.count = 0
	await _go_live(false)
	_remove_team(1)
	var plan := _rounds.get_hunt_plan(0)
	var pair: Array = plan.groups.filter(func(group: Array) -> bool: return group.size() == 2)[0]
	var distances: Array[float] = []
	var moved := 0.0
	var start: Vector3 = (pair[0] as BotController).character.global_position
	for i in 30:
		await _wait_seconds(0.5)
		var leader := plan.get_leader(pair[0])
		var follower: BotController = pair[1] if leader == pair[0] else pair[0]
		if follower.state == BotController.State.PATROL and leader.character.is_alive() and follower.character.is_alive():
			distances.append(_flat(leader.character.global_position, follower.character.global_position))
		moved = maxf(moved, _flat(start, leader.character.global_position))
	distances.sort()
	var median := distances[distances.size() / 2] if not distances.is_empty() else INF
	_check("A follower stays within about 6 m of its leader while the pair roams the map, never straggling past 12 m",
			distances.size() >= 20 and median <= 7.0 and distances[-1] <= 12.0 and moved >= 15.0,
			"median %.1f m over %d samples (largest %.1f m), the leader got %.0f m from its start" % [median, distances.size(), distances[-1] if not distances.is_empty() else -1.0, moved])


func _test_sightings() -> void:
	await _new_match(false)
	await _go_live(false)
	_remove_team(1)
	var plan := _rounds.get_hunt_plan(0)
	var pair_leader := plan.get_leader((plan.groups.filter(func(group: Array) -> bool: return group.size() == 2)[0] as Array)[0])
	var single: BotController = (plan.groups.filter(func(group: Array) -> bool: return group.size() == 1)[0] as Array)[0]
	# Put the single far from the pair, then call out a sighting near the pair only.
	for bot: BotController in [single] + plan.get_partners(pair_leader) + [pair_leader]:
		var at: Vector3 = _map.get_node("Respawns/West1" if bot == single else "Respawns/East1").global_position
		await _teleport(bot.character, at + Vector3(0.0, 0.0, 2.0 if bot != pair_leader and bot != single else 0.0))
		# Respawning reset its orders, as it does in a match; the match gives them back.
		bot.hunt(plan)
	var lead := NavigationServer3D.map_get_closest_point(_map.get_world_3d().navigation_map, pair_leader.character.global_position + Vector3(0.0, 0.0, -12.0))
	plan.report(lead)
	await _wait_seconds(0.3)
	_check("A teammate's sighting is answered by the group near it, not by one across the map",
			plan.get_goal(pair_leader).is_equal_approx(lead) and not plan.get_goal(single).is_equal_approx(lead),
			"pair heading for the sighting: %s, single heading for it: %s (%.0f m away)" % [plan.get_goal(pair_leader).is_equal_approx(lead), plan.get_goal(single).is_equal_approx(lead), _flat(single.character.global_position, lead)])
	var before := _flat(pair_leader.character.global_position, lead)
	await _wait_seconds(2.0)
	var after := _flat(pair_leader.character.global_position, lead)
	_check("The group runs to the sighting", after < before - 5.0, "%.1f m → %.1f m" % [before, after])


# --- Helpers ---


## The real main scene with [param settings] on Depot (or [param map_scene]), in practice with
## [param practice]; the class menu is closed and everyone is silenced, so only the test acts.
func _new_main(settings: MatchSettings, practice: bool = false, map_scene: PackedScene = MAP_SCENE) -> Node:
	_free_match()
	var main := MAIN_SCENE.instantiate()
	# Never read or write the player's settings file.
	main.set("load_settings", false)
	main.set("map_scene", map_scene)
	main.set("match_settings", settings)
	if practice:
		main.set("mode", 1)
	add_child(main)
	await _wait_ticks(3)
	(main.get_node("ClassMenu") as ClassMenu).close()
	for character: Character in main.call("get_map").find_children("*", "Character", true, false):
		_silence(character)
	return main


func _remove_main(main: Node) -> void:
	remove_child(main)
	main.queue_free()
	MenuState.reset()


## Waits for the live phase of [param rules], then freezes every bot so none moves or shoots.
func _go_live_in(rules: RoundManager) -> void:
	var ticks := 0
	while rules.phase != RoundManager.Phase.LIVE and ticks < 128 * 5:
		await get_tree().physics_frame
		ticks += 1
	for member in rules.get_participants():
		if not member.is_local_player():
			member.frozen = true
	await _wait_ticks(2)


## True while the match uses MatchSettings' own respawn delay (3 s), not a test value.
func _is_default_delay(rules: RoundManager) -> bool:
	return is_equal_approx(rules.settings.respawn_delay, MatchSettings.new().respawn_delay)


## A fresh team respawn match on Depot with the short test rules, a HUD, and
## every bot silenced. Without [param with_player] the map's Player is removed
## (a bots-only match, every bot seeded; no HUD).
func _new_match(with_player: bool = true) -> void:
	_free_match()
	_results.clear()
	_match_ends.clear()
	_map = MAP_SCENE.instantiate()
	_player = _map.get_node("Player")
	if not with_player:
		_player.free()
		_player = null
	add_child(_map)
	if not with_player:
		await _wait_ticks(30)
	else:
		_silence(_player)
	var settings := MatchSettings.new()
	settings.game_mode = MatchSettings.GameMode.TEAM_RESPAWN
	settings.freeze_time = 0.5
	settings.round_end_time = 1.0
	settings.kill_limit = KILL_LIMIT
	settings.time_limit = TIME_LIMIT
	settings.respawn_delay = RESPAWN_DELAY
	_rounds = RespawnMatch.new()
	_rounds.settings = settings
	_rounds.rng.seed = 5
	_rounds.round_ended.connect(func(winner: int, reason: RoundManager.EndReason) -> void: _results.append([winner, reason]))
	_rounds.match_ended.connect(func(winner: int) -> void: _match_ends.append(winner))
	_map.add_child(_rounds)
	await _wait_ticks(2)
	var participants := _rounds.get_participants()
	for i in participants.size():
		_silence(participants[i])
		var brain := participants[i].get_node_or_null("BotController") as BotController
		if brain != null:
			brain.rng.seed = i + 1
			participants[i].weapon.rng.seed = i + 1
	if _player == null:
		return
	Teams.set_viewer_team(_player.team)
	_hud = HUD_SCENE.instantiate()
	add_child(_hud)
	_hud.call("set_player", _player)
	_hud.call("set_round_manager", _rounds)
	await _wait_ticks(2)


func _free_match() -> void:
	if _hud != null:
		remove_child(_hud)
		_hud.queue_free()
		_hud = null
	if _map != null:
		remove_child(_map)
		_map.queue_free()
		_map = null


## Waits for the live phase, then (with [param freeze_bots]) freezes every bot, so none of them moves or shoots.
func _go_live(freeze_bots: bool = true) -> void:
	var ticks := 0
	while _rounds.phase != RoundManager.Phase.LIVE and ticks < 128 * 5:
		await get_tree().physics_frame
		ticks += 1
	if freeze_bots:
		for member in _rounds.get_participants():
			if member != _player:
				member.frozen = true
	await _wait_ticks(2)


func _teleport(character: Character, at: Vector3) -> void:
	character.respawn(at, character.rotation.y)
	await _wait_ticks(3)


## Takes [param team]'s bots out of the match, so the other team's bots have nobody to fight.
func _remove_team(team: int) -> void:
	for member in _rounds.get_members(team):
		member.get_parent().remove_child(member)
		member.queue_free()
	await _wait_ticks(1)


func _markers(group: String) -> Array:
	return get_tree().get_nodes_in_group(group).filter(func(node: Node) -> bool: return _map.is_ancestor_of(node))


func _marker_name_at(spot: Vector3) -> String:
	for marker: Node3D in _markers(RespawnMatch.RESPAWN_GROUP):
		if _flat(marker.global_position, spot) < 0.1:
			return marker.name
	return str(spot)


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _round_label() -> String:
	return (_hud.get_node("RoundHud") as RoundHud).get_round_text()


func _timer_text() -> String:
	return (_hud.get_node("RoundHud") as RoundHud).get_timer_text()


## Your score (team 0) or theirs (team 1) as the top bar shows it.
func _bar_score(team: int) -> String:
	return (_hud.get_node("RoundHud") as RoundHud).get_score_text(team == Teams.viewer_team)


func _center() -> Array:
	var lines := []
	for label_name in ["Title", "Line1"]:
		var label := _hud.get_node("RoundHud/Center/" + label_name) as Label
		lines.append(label.text if label.visible else "")
	return lines


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
