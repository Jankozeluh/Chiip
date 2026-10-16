extends Node
## Pre-release QA, automated (M12, D-178). Run without a window:
##
##     Godot --headless --path . --fixed-fps 128 --quit-after 200000 res://tests/qa_test.tscn
##
## Every mode on every map, started the way a player starts it (a [GameLaunch] description and
## main.tscn, with the player in the game, not a bots-only run): Bomb rounds and Team Deathmatch
## on Depot, Square and Spillway, then Practice on the Shooting Range and on two maps that have
## no team spawns (the kit gallery, the test map). Each game runs for 70 seconds of game time, and
## the checks are what a player would notice if it broke: the right map and rules node, the right
## number of characters, a player who can play, bots that walk and fight, rounds that begin (or
## respawns that happen), and nobody falling through the world. It never touches the real settings
## file. Quits with the number of failed checks as the exit code.

const MAIN_SCENE := preload("res://main.tscn")
const MAPS: Array[String] = ["res://maps/depot.tscn", "res://maps/square.tscn", "res://maps/spillway.tscn"]
const PRACTICE_MAPS: Array[String] = ["res://maps/shooting_range.tscn", "res://maps/kit/kit_gallery.tscn", "res://maps/test_map.tscn"]
## Game seconds each game runs, at the 128 physics ticks a second the test runs at.
const GAME_SECONDS := 70
const TICKS_PER_SECOND := 128
## Below this height something has fallen through the floor.
const FALL_LIMIT := -5.0

var _failures: int = 0
var _main: Node


func _ready() -> void:
	Weapon.silent = true
	for mode in ["rounds", "respawn"]:
		for map in MAPS:
			await _play_match(mode, map)
	for map in PRACTICE_MAPS:
		await _play_practice(map)
	_free_main()
	GameLaunch.clear()
	MenuState.reset()
	await get_tree().process_frame
	if _failures == 0:
		print("\nAll checks passed.")
	else:
		print("\n%d check(s) FAILED." % _failures)
	get_tree().quit(_failures)


## One match of [param mode] ("rounds" or "respawn") on [param map], 3 against 3, Normal bots.
func _play_match(mode: String, map: String) -> void:
	var rules := MatchSettings.new()
	rules.team_size = 3
	rules.enemy_team_size = 3
	rules.bot_difficulty = GameLaunch.difficulty_named("normal")
	rules.game_mode = MatchSettings.GameMode.TEAM_RESPAWN if mode == "respawn" else MatchSettings.GameMode.ROUNDS
	GameLaunch.start_match(map, rules, [])
	await _start_main()
	var manager := _rounds()
	var title := "%s on %s" % ["Team Deathmatch" if mode == "respawn" else "Bomb", GameLaunch.map_title(map)]
	if manager == null:
		_check("%s: the game has a rules node" % title, false, "no RoundManager or RespawnMatch under the map")
		return
	var kills: Array[int] = [0]
	var rounds_begun: Array[int] = [0]
	var respawns: Array[int] = [0]
	var live_seen: Array[bool] = [false]
	manager.character_killed.connect(func(_victim: Character, _killer: Character, _headshot: bool) -> void: kills[0] += 1)
	manager.round_started.connect(func(_number: int) -> void: rounds_begun[0] += 1)
	manager.phase_changed.connect(func(phase: RoundManager.Phase) -> void: live_seen[0] = live_seen[0] or phase == RoundManager.Phase.LIVE)
	for character in manager.get_participants():
		character.respawned.connect(func() -> void: respawns[0] += 1)
	var player := _main.call("get_player") as Character
	var participants := manager.get_participants()
	var start_ok := participants.size() == 6 and player != null and player.is_alive() and player.weapon != null \
			and manager.get_members(player.team).size() == 3 and manager.get_members(Teams.other(player.team)).size() == 3
	var observed := await _run(participants)
	var rules_ok := (manager is RespawnMatch) == (mode == "respawn")
	var game_ok := rounds_begun[0] >= 1 or live_seen[0] if mode == "rounds" else respawns[0] >= 1
	_check("%s: the right map and rules (%s), 3 against 3 with a player who can play" % [title, "RespawnMatch" if mode == "respawn" else "RoundManager"],
			(_main.call("get_map") as Node).scene_file_path == map and rules_ok and start_ok,
			"map '%s', rules %s, %d participants, player %s" % [(_main.call("get_map") as Node).scene_file_path, manager.get_class(), participants.size(), player])
	_check("%s: in %d s the bots walk (%.0f m in all) and fight (%d kills), %s, and nobody falls through the world (lowest point %.1f m)" % [
			title, GAME_SECONDS, observed["walked"], kills[0], "a round went live" if mode == "rounds" else "players respawned (%d)" % respawns[0], observed["lowest"]],
			observed["walked"] > 20.0 and kills[0] >= 1 and game_ok and observed["lowest"] > FALL_LIMIT,
			"walked %.1f m, kills %d, rounds begun %d, live seen %s, respawns %d, lowest %.1f m" % [
					observed["walked"], kills[0], rounds_begun[0], live_seen[0], respawns[0], observed["lowest"]])
	_free_main()


## Practice on [param map]: the Shooting Range starts with no bots, the other maps with two.
func _play_practice(map: String) -> void:
	GameLaunch.start_practice(map, GameLaunch.difficulty_named("normal"))
	await _start_main()
	var title := "Practice on %s" % GameLaunch.map_title(map)
	var player := _main.call("get_player") as Character
	var everyone := Character.all_in_world(_main)
	var bots: Array[Character] = []
	for character in everyone:
		if character != player:
			bots.append(character)
	var expected_bots := 0 if map == Settings.DEFAULT_MAP else 2
	# The player who can play is checked at the start: standing still among bots, he may be shot later.
	var player_ok := player != null and player.is_alive() and player.weapon != null
	var observed := await _run(everyone, GAME_SECONDS / 2)
	var map_node := _main.call("get_map") as Node
	var arena := map_node.get_node_or_null("ArenaRules")
	_check("%s: loads the map, the player can play, the practice rules run, and there are %d bots to start with" % [title, expected_bots],
			map_node.scene_file_path == map and player_ok and bots.size() == expected_bots and arena != null,
			"map '%s', player %s, %d bots, arena %s" % [map_node.scene_file_path, player, bots.size(), arena])
	if map == Settings.DEFAULT_MAP:
		# What the README tells a player to do on the Shooting Range: add bots with the console.
		var console := _main.get_node("DevConsole") as DevConsole
		console.run("bot_add normal enemy")
		console.run("bot_add hard ally")
		await _wait_ticks(4)
		var added := Character.all_in_world(_main)
		added.erase(player)
		var after := await _run(added, 15)
		_check("%s: the console's bot_add puts an enemy and an ally on the range, and they walk (%.0f m)" % [title, after["walked"]],
				added.size() == 2 and added[0].team != added[1].team and after["walked"] > 5.0 and after["lowest"] > FALL_LIMIT,
				"%d bots, walked %.1f m, lowest %.1f m" % [added.size(), after["walked"], after["lowest"]])
		console.run("bot_kick all")
		await _wait_ticks(4)
		var left := Character.all_in_world(_main)
		left.erase(player)
		_check("%s: bot_kick all clears them" % title, left.is_empty(), "%d bots left" % left.size())
	_check("%s: %d s later nobody has fallen through the world (lowest point %.1f m)%s" % [
			title, GAME_SECONDS / 2, observed["lowest"], " and the bots walk (%.0f m)" % observed["walked"] if expected_bots > 0 else ""],
			observed["lowest"] > FALL_LIMIT and (expected_bots == 0 or observed["walked"] > 5.0),
			"lowest %.1f m, walked %.1f m" % [observed["lowest"], observed["walked"]])
	_free_main()


## Starts main.tscn on the pending [GameLaunch] description, like the menu's Play does.
func _start_main() -> void:
	_free_main()
	_main = MAIN_SCENE.instantiate()
	# Never read or write the player's real settings file; a loading screen would only slow the test down.
	_main.set("load_settings", false)
	_main.set("loading_screen", false)
	add_child(_main)
	await _wait_ticks(3)
	for character in Character.all_in_world(_main):
		character.footstep_sound = null


## Runs [param seconds] of game time and reports how far the characters other than the player walked
## in all, and the lowest point any of [param watched] reached.
func _run(watched: Array[Character], seconds: int = GAME_SECONDS) -> Dictionary:
	var player := _main.call("get_player") as Character
	var last: Dictionary = {}
	var walked := 0.0
	var lowest := INF
	for tick in seconds * TICKS_PER_SECOND:
		await get_tree().physics_frame
		for character in watched:
			if not is_instance_valid(character):
				continue
			var position := character.global_position
			lowest = minf(lowest, position.y)
			if character != player and character.is_alive():
				if last.has(character):
					walked += Vector2(position.x - last[character].x, position.z - last[character].z).length()
				last[character] = position
			else:
				last.erase(character)
	return {"walked": walked, "lowest": lowest}


func _rounds() -> RoundManager:
	var map := _main.call("get_map") as Node
	for child in map.get_children():
		if child is RoundManager:
			return child
	return null


func _free_main() -> void:
	if _main != null:
		remove_child(_main)
		_main.queue_free()
		_main = null
	MenuState.reset()


func _wait_ticks(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _check(check_name: String, passed: bool, detail: String) -> void:
	print("%s  %s: %s" % ["PASS" if passed else "FAIL", check_name, detail])
	if not passed:
		_failures += 1
