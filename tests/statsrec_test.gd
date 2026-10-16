extends Node
## Automated checks for recording stats from matches (M14, D-202, D-203). Run without a window:
##
##     Godot --headless --path . --fixed-fps 128 --quit-after 200000 res://tests/statsrec_test.tscn
##
## Offline, in the real game scene on Depot: a Team respawn match where you tap real shots at a
## still enemy (the rifle with perfect aim: chest, head, a miss into the sky; a shotgun shot counts
## its nine pellets), take hits that must not count (a teammate with friendly fire on, the knife, a
## grenade), and win by two kills, the last of them a headshot; the finished match lands in the
## history with the right mode, map, result, score, kills, damage, headshot kills, bullets and hits by
## zone. A bomb round match records its rounds and ADR; a free-for-all (M17) records a win when you are
## the match's winner and a loss when somebody else is (never a draw), with your kills against the best
## other player's as the score, and the history accepts its mode; a match you leave and practice record
## nothing. Then online (one host and one client in this process): the host damages an enemy in the
## client's name with a named gun, the client's copy of the enemy learns the gun from the host's
## announcement, and the client's own recorder counts its real shots and the hits the host announced,
## and adds the match to its book with the host's kills and damage (what its scoreboard shows). Every
## book is the shared one in memory only (nothing loads it): the last check makes sure your real
## `user://stats.json` was never touched. Quits with the number of failed checks as the exit code.

const MAIN_SCENE := preload("res://main.tscn")
const MAP_SCENE := preload("res://maps/depot.tscn")
const TAP_PAUSE := 0.7

var _failures: int = 0
var _real_file_md5: String = ""
var _main: Node
var _harness: NetHarness


func _ready() -> void:
	_real_file_md5 = _real_md5()
	Weapon.silent = true
	StatsBook.get_instance().clear()
	await _test_respawn_match()
	await _test_rounds_match()
	await _test_ffa_matches()
	await _test_not_recorded()
	await _test_online()
	StatsBook.get_instance().clear()
	_check("The tests never touched your real stats file, and the shared book never loaded it",
			_real_md5() == _real_file_md5 and not StatsBook.get_instance().is_loaded(), "checksum '%s'" % _real_md5())
	Weapon.silent = false
	if _failures == 0:
		print("\nAll checks passed.")
	else:
		print("\n%d check(s) FAILED." % _failures)
	get_tree().quit(_failures)


# --- Offline ---


func _test_respawn_match() -> void:
	var book := StatsBook.get_instance()
	book.clear()
	var settings := MatchSettings.new()
	settings.game_mode = MatchSettings.GameMode.TEAM_RESPAWN
	settings.freeze_time = 0.3
	settings.round_end_time = 0.5
	settings.kill_limit = 2
	await _new_main(settings)
	var rules := _main.call("get_map").get_node("RespawnMatch") as RespawnMatch
	var player := _main.call("get_map").get_node("Player") as Character
	var recorder := rules.get_node_or_null("StatsRecorder") as StatsRecorder
	_check("A match has a stats recorder under its rules", recorder != null, "")
	await _go_live(rules)
	# The same every run: a rifle with perfect aim, then a shotgun, whatever class the draft gave you.
	var gun := WeaponData.find(&"rifle")
	var shotgun := WeaponData.find(&"shotgun")
	var loadout: Array[WeaponData] = [gun]
	player.inventory.set_loadout(loadout)
	var rifle := player.inventory.find(gun)
	var gun_id := String(gun.id)
	var perfect := gun.duplicate() as WeaponData
	perfect.standing_inaccuracy = 0.0
	perfect.spray_inaccuracy_per_shot = 0.0
	perfect.max_spray_inaccuracy = 0.0
	rifle.data = perfect
	player.inventory.hold(rifle, true)
	await _wait_seconds(0.5)
	var enemies := rules.get_members(1)
	var mate := rules.get_members(0).filter(func(member: Character) -> bool: return member != player)[0] as Character
	var target := enemies[0]
	var spot := _clear_spot(player, 8.0)
	_check("A clear spot 8 m from the player for a still enemy", spot != Vector3.INF, "%s" % spot)
	if spot == Vector3.INF or recorder == null:
		_free_main()
		return
	target.respawn(spot, 0.0)
	target.frozen = true
	await _wait_ticks(4)
	target.health = 5000.0
	# Three chest taps, one head tap, one tap into the sky: five bullets, four hits.
	for _tap in 3:
		await _tap_at(player, target.get_chest_position())
	await _tap_at(player, target.get_head_position())
	await _tap_at(player, player.get_eye_position() + Vector3.UP * 20.0 + Vector3.FORWARD * 3.0)
	var numbers := recorder.get_weapon(gun_id)
	_check("Real shots are counted: five bullets, four hits (three on the body, one on the head) for the gun in hand",
			numbers.shots == 5 and numbers.hits == 4 and numbers.zone_hits("head") == 1,
			"%d shots, %d hits, %s" % [numbers.shots, numbers.hits, str(numbers.zones)])
	# The shotgun's pellets count one by one.
	var shotgun_loadout: Array[WeaponData] = [shotgun]
	player.inventory.set_loadout(shotgun_loadout)
	player.inventory.hold(player.inventory.find(shotgun), true)
	await _wait_seconds(0.5)
	await _tap_at(player, target.get_chest_position())
	var pellets := recorder.get_weapon("shotgun")
	_check("One shotgun shot is nine bullets, and its hits can't exceed them",
			pellets.shots == maxi(shotgun.pellets, 1) and pellets.hits >= 1 and pellets.hits <= pellets.shots,
			"%d bullets, %d hits (player alive %s, health %.0f, holding %s)" % [pellets.shots, pellets.hits, player.is_alive(), player.health,
					player.weapon.data.id if player.weapon != null else "nothing"])
	# What must not count: a teammate hit with friendly fire on, the knife, a grenade, and damage to yourself.
	var before := recorder.get_weapon(gun_id).hits
	Teams.friendly_fire = true
	mate.take_damage(10.0, Hitbox.Zone.CHEST, player, 1.0, gun)
	Teams.friendly_fire = false
	target.take_damage(10.0, Hitbox.Zone.CHEST, player, 1.0, WeaponData.find(&"knife"))
	target.take_damage(10.0, Hitbox.Zone.CHEST, player, 1.0, WeaponData.find(&"frag"))
	player.take_damage(1.0, Hitbox.Zone.CHEST, player, 1.0, gun)
	_check("Hits on a teammate, with the knife or a grenade, and on yourself are not counted", recorder.get_weapon(gun_id).hits == before,
			"%d hits before, %d after" % [before, recorder.get_weapon(gun_id).hits])
	_check("The knife and the grenade don't appear among the guns", recorder.get_weapon("knife").shots == 0 and recorder.get_weapon("frag").hits == 0, "")
	# Win with two kills; the second, last one is a headshot.
	target.health = 100.0
	var knife := WeaponData.find(&"knife")
	target.take_damage(500.0, Hitbox.Zone.CHEST, player, 1.0, knife)
	enemies[1].take_damage(500.0, Hitbox.Zone.HEAD, player, 1.0, knife)
	var done := await _wait_for(func() -> bool: return book.history.size() > 0, 12.0)
	_check("The finished match is in the history", done and book.history.size() == 1 and book.lifetime.matches == 1, "%d matches" % book.history.size())
	if book.history.is_empty():
		_free_main()
		return
	var record := book.history[0]
	var stats := rules.get_stats(player)
	_check("It says what happened: Team respawn on Depot, a win 2 to 0, no rounds, offline",
			record.mode == StatsMatch.MODE_RESPAWN and record.map == "depot" and record.result == StatsMatch.WIN
			and record.score_us == 2 and record.score_them == 0 and record.rounds == 0 and not record.online and record.adr() < 0.0
			and record.duration > 1.0, "%s %s %s %d-%d, %.1f s" % [record.mode, record.map, record.result, record.score_us, record.score_them, record.duration])
	_check("And your numbers, the scoreboard's: two kills (one a headshot), no deaths, the damage dealt",
			record.kills == 2 and stats.kills == 2 and record.deaths == 0 and record.headshot_kills == 1
			and record.damage > 0.0 and is_equal_approx(record.damage, stats.damage),
			"%d kills, %d deaths, %d headshot kills, %.0f damage" % [record.kills, record.deaths, record.headshot_kills, record.damage])
	var recorded := record.weapons.get(gun_id) as StatsWeapon
	_check("The history has the gun's bullets, hits and zones, and the shotgun's",
			recorded != null and recorded.shots == 5 and recorded.hits == 4 and recorded.zone_hits("head") == 1 and record.weapons.has("shotgun")
			and not record.weapons.has("knife") and not record.weapons.has("frag"),
			"%s" % str(record.to_dict()["weapons"]))
	_free_main()
	book.clear()


func _test_rounds_match() -> void:
	var book := StatsBook.get_instance()
	book.clear()
	var settings := MatchSettings.new()
	settings.team_size = 1
	settings.enemy_team_size = 1
	settings.rounds_to_win = 1
	settings.freeze_time = 0.3
	settings.round_end_time = 0.5
	settings.bots_buy = false
	await _new_main(settings)
	var rules := _main.call("get_map").get_node("RoundManager") as RoundManager
	var player := _main.call("get_map").get_node("Player") as Character
	await _go_live(rules)
	var enemy := rules.get_members(1)[0]
	enemy.take_damage(60.0, Hitbox.Zone.CHEST, player, 1.0, player.weapon.data)
	enemy.take_damage(500.0, Hitbox.Zone.CHEST, player, 1.0, player.weapon.data)
	var done := await _wait_for(func() -> bool: return book.history.size() > 0, 12.0)
	var record := book.history[0] if not book.history.is_empty() else null
	_check("A bomb round match is recorded too: a round win, one round played, an ADR from the damage",
			done and record != null and record.mode == StatsMatch.MODE_ROUNDS and record.result == StatsMatch.WIN and record.rounds == 1
			and rules.get_rounds_played() == 1 and record.kills == 1 and record.damage >= 60.0 and is_equal_approx(record.adr(), record.damage),
			"%s" % str(record.to_dict() if record != null else null))
	_free_main()
	book.clear()


## Free-for-all (M17, D-240): you win by getting to the kill limit first (a win, your kills against the best
## other's), and lose when a bot does (a loss with its kills as the "them" score, never a draw).
func _test_ffa_matches() -> void:
	var book := StatsBook.get_instance()
	book.clear()
	var settings := MatchSettings.new()
	settings.game_mode = MatchSettings.GameMode.FREE_FOR_ALL
	settings.team_size = 2
	settings.enemy_team_size = 1
	settings.freeze_time = 0.3
	settings.round_end_time = 0.5
	settings.respawn_delay = 0.3
	settings.kill_limit = 2
	await _new_main(settings)
	var rules := _main.call("get_map").get_node("FreeForAllMatch") as FreeForAllMatch
	var player := _main.call("get_map").get_node("Player") as Character
	await _go_live(rules)
	var knife := WeaponData.find(&"knife")
	var bots := rules.get_participants().filter(func(member: Character) -> bool: return member != player)
	bots[0].take_damage(500.0, Hitbox.Zone.CHEST, player, 1.0, knife)
	await _wait_seconds(0.6)
	bots[1].take_damage(500.0, Hitbox.Zone.HEAD, player, 1.0, knife)
	var done := await _wait_for(func() -> bool: return book.history.size() > 0, 12.0)
	var record := book.history[0] if not book.history.is_empty() else null
	_check("A free-for-all you win is recorded: mode 'ffa' on Depot, a win, your 2 kills against the best other's 0, no rounds (no ADR), offline, and the scoreboard's kills",
			done and record != null and record.mode == StatsMatch.MODE_FFA and record.map == "depot" and record.result == StatsMatch.WIN
			and record.score_us == 2 and record.score_them == 0 and record.rounds == 0 and record.adr() < 0.0 and not record.online
			and record.kills == 2 and rules.get_winner() == player and book.lifetime.wins == 1 and StatsTotals.won_in(book.lifetime.modes, "ffa") == 1,
			"%s" % str(record.to_dict() if record != null else null))
	var read_back := StatsMatch.from_dict(record.to_dict()) if record != null else null
	_check("The history accepts the mode: a record of it survives its own dictionary, and a made-up mode is still refused",
			read_back != null and read_back.mode == "ffa" and read_back.result == StatsMatch.WIN
			and StatsMatch.from_dict(_with_mode(record, "battle_royale")) == null,
			"%s" % [read_back.mode if read_back != null else null])
	_free_main()
	book.clear()

	# A bot gets there first: you kill once, it kills you and then the other bot, 2 against your 1.
	await _new_main(settings)
	rules = _main.call("get_map").get_node("FreeForAllMatch") as FreeForAllMatch
	player = _main.call("get_map").get_node("Player") as Character
	await _go_live(rules)
	bots = rules.get_participants().filter(func(member: Character) -> bool: return member != player)
	var victor: Character = bots[0]
	bots[1].take_damage(500.0, Hitbox.Zone.CHEST, player, 1.0, knife)
	player.take_damage(500.0, Hitbox.Zone.CHEST, victor, 1.0, knife)
	await _wait_seconds(0.7)
	bots[1].take_damage(500.0, Hitbox.Zone.CHEST, victor, 1.0, knife)
	done = await _wait_for(func() -> bool: return book.history.size() > 0, 12.0)
	record = book.history[0] if not book.history.is_empty() else null
	_check("A free-for-all a bot wins is a loss (never a draw): your 1 kill against its 2, one death",
			done and record != null and record.mode == StatsMatch.MODE_FFA and record.result == StatsMatch.LOSS and record.score_us == 1 and record.score_them == 2
			and record.kills == 1 and record.deaths == 1 and rules.get_winner() == victor and book.lifetime.losses == 1 and book.lifetime.draws == 0,
			"%s, winner %s" % [str(record.to_dict() if record != null else null), rules.get_winner()])
	_free_main()
	book.clear()


## [param record]'s dictionary with another mode, for the check that the history refuses a mode no game wrote.
func _with_mode(record: StatsMatch, mode: String) -> Dictionary:
	var data := record.to_dict()
	data["mode"] = mode
	return data


func _test_not_recorded() -> void:
	var book := StatsBook.get_instance()
	book.clear()
	# Leaving a match before it ends: nothing is recorded.
	var settings := MatchSettings.new()
	settings.game_mode = MatchSettings.GameMode.TEAM_RESPAWN
	settings.freeze_time = 0.3
	settings.kill_limit = 50
	await _new_main(settings)
	var rules := _main.call("get_map").get_node("RespawnMatch") as RespawnMatch
	await _go_live(rules)
	rules.get_members(1)[0].take_damage(500.0, Hitbox.Zone.CHEST, _main.call("get_player"), 1.0, null)
	await _wait_ticks(10)
	_free_main()
	await _wait_ticks(5)
	_check("A match you leave before its end is not recorded", book.history.is_empty() and book.lifetime.matches == 0, "%d matches" % book.history.size())
	# Practice has no rules to record.
	var practice := MAIN_SCENE.instantiate()
	practice.set("load_settings", false)
	practice.set("loading_screen", false)
	practice.set("mode", 1)
	add_child(practice)
	await _wait_ticks(5)
	var map := practice.call("get_map") as Node
	var found := map.find_children("*", "StatsRecorder", true, false)
	_check("Practice records nothing: no recorder", found.is_empty(), "%d recorders" % found.size())
	remove_child(practice)
	practice.queue_free()
	MenuState.reset()
	await _wait_ticks(3)


# --- Online ---


func _test_online() -> void:
	_harness = NetHarness.new()
	add_child(_harness)
	var rules := MatchSettings.new()
	rules.team_size = 2
	rules.enemy_team_size = 1
	rules.rounds_to_win = 1
	rules.freeze_time = 1.0
	rules.round_time = 60.0
	rules.round_end_time = 1.0
	rules.bots_buy = false
	var host_session := _harness.start_host("Host", "Host")
	var client_session := _harness.start_client("Client", "Jan")
	var joined := await _harness.wait_until(client_session.is_active)
	_check("The client joins the host's session", joined, "")
	if not joined:
		_harness.queue_free()
		return
	# Both people on the first team, against one bot.
	host_session.set_player_team(client_session.local_peer_id, 0)
	await _harness.wait_ticks(20)
	var host_main := _harness.start_game(host_session.get_parent(), host_session, MAP_SCENE, rules)
	await _harness.wait_ticks(10)
	var client_main := _harness.start_game(client_session.get_parent(), client_session, MAP_SCENE, rules)
	var host := host_main.get_net_game() as NetHost
	var client := client_main.get_net_game() as NetClient
	var started := await _harness.wait_until(func() -> bool: return host.is_started() and client.is_welcomed(), 600)
	_check("The online match starts", started, "")
	if not started:
		_harness.queue_free()
		return
	var host_rules := host_main.get_map().get_node("RoundManager") as RoundManager
	var client_rules := client_main.get_map().get_node("RoundManager") as RoundManager
	for character in host_rules.get_participants():
		NetHarness.silence(character)
	NetHarness.silence_bomb(host_rules.bomb)
	NetHarness.silence_bomb(client_rules.bomb)
	var own: Character = client_main.get_player()
	var friend := host.get_character_of(client_session.local_peer_id)
	var client_recorder := client_rules.get_node("StatsRecorder") as StatsRecorder
	# One book for each side: both are in this process, where the shared one would take both matches.
	var host_book := StatsBook.new()
	(host_rules.get_node("StatsRecorder") as StatsRecorder).set_book(host_book)
	var book := StatsBook.new()
	client_recorder.set_book(book)
	await _harness.wait_until(func() -> bool: return client_rules.phase == RoundManager.Phase.LIVE, 1280)
	for member in host_rules.get_participants():
		if member != friend and member != host_main.get_player():
			member.frozen = true
	await _harness.wait_ticks(2)
	var enemy := host_rules.get_members(1)[0]
	var gun := own.weapon.data
	# The client's real shots: three taps into the sky (no hits, so no damage to anyone).
	var shots := [0]
	own.weapon.fired.connect(func(_shot: int) -> void: shots[0] += 1)
	var ticks := [0]
	client.command_source = func(_delta: float) -> CharacterInput:
		ticks[0] += 1
		var command := CharacterInput.new()
		command.pitch = 1.2
		command.shoot = ticks[0] % 48 == 1 and shots[0] < 3
		return command
	await _harness.wait_until(func() -> bool: return shots[0] >= 3, 128 * 8)
	client.command_source = Callable()
	await _harness.wait_ticks(20)
	_check("The client's recorder counts the client's own shots",
			shots[0] == 3 and client_recorder.get_weapon(String(gun.id)).shots == 3 and client_recorder.get_weapon(String(gun.id)).hits == 0,
			"%d fired, %d recorded" % [shots[0], client_recorder.get_weapon(String(gun.id)).shots])
	# The host decides a hit for the client's player with the gun in its hand, in the chest.
	var smg := WeaponData.find(&"smg")
	var enemy_on_client := client.get_character(enemy.net_id)
	enemy.take_damage(20.0, Hitbox.Zone.CHEST, friend, 1.0, smg)
	await _harness.wait_until(func() -> bool: return enemy_on_client.health < 100.0, 256)
	_check("The client's copy of the enemy learns the gun from the host's announcement",
			enemy_on_client.last_damage_source != null and enemy_on_client.last_damage_source.id == &"smg",
			"%s" % (str(enemy_on_client.last_damage_source.id) if enemy_on_client.last_damage_source != null else "none"))
	# A chest hit and a lethal head shot with the client's gun; the lethal one ends the round and the match.
	enemy.take_damage(20.0, Hitbox.Zone.CHEST, friend, 1.0, gun)
	enemy.take_damage(500.0, Hitbox.Zone.HEAD, friend, 1.0, gun)
	var done := await _harness.wait_until(func() -> bool: return book.history.size() > 0 and host_book.history.size() > 0, 128 * 12)
	_check("Each side adds the finished match to its own book", done and book.history.size() == 1 and host_book.history.size() == 1,
			"client %d, host %d matches" % [book.history.size(), host_book.history.size()])
	if not book.history.is_empty():
		var record := book.history[-1]
		var id := String(gun.id)
		var numbers := record.weapons.get(id) as StatsWeapon
		var scoreboard := client_rules.get_stats(own)
		_check("It is an online win with the host's numbers: one kill (a headshot), the damage the host announced, one round",
				record.online and record.result == StatsMatch.WIN and record.kills == 1 and scoreboard.kills == 1 and record.headshot_kills == 1
				and record.rounds == 1 and record.mode == StatsMatch.MODE_ROUNDS and record.map == "depot" and is_equal_approx(record.damage, scoreboard.damage)
				and record.damage >= 40.0, "%s" % str(record.to_dict()))
		_check("And the hits the host announced for the client's gun (chest and head, not the smg's), against its real shots",
				numbers != null and numbers.shots == 3 and numbers.hits == 2 and numbers.zone_hits("chest") >= 1 and numbers.zone_hits("head") == 1,
				"%s" % str(numbers.to_dict() if numbers != null else null))
	for main in [client_main, host_main]:
		main.get_parent().remove_child(main)
		main.queue_free()
	for session in [client_session, host_session]:
		session.close()
	remove_child(_harness)
	_harness.queue_free()
	await _wait_ticks(5)


# --- Helpers ---


func _new_main(settings: MatchSettings) -> void:
	_free_main()
	_main = MAIN_SCENE.instantiate()
	_main.set("load_settings", false)
	_main.set("loading_screen", false)
	_main.set("map_scene", MAP_SCENE)
	_main.set("match_settings", settings)
	add_child(_main)
	await _wait_ticks(3)
	(_main.get_node("ClassMenu") as ClassMenu).close()
	for character: Character in _main.call("get_map").find_children("*", "Character", true, false):
		character.footstep_sound = null


func _free_main() -> void:
	if _main != null:
		remove_child(_main)
		_main.queue_free()
		_main = null
	MenuState.reset()
	Teams.friendly_fire = false


## Waits for the live phase of [param rules], then freezes every bot so none moves or shoots.
func _go_live(rules: RoundManager) -> void:
	var ticks := 0
	while rules.phase != RoundManager.Phase.LIVE and ticks < 128 * 5:
		await get_tree().physics_frame
		ticks += 1
	for member in rules.get_participants():
		if not member.is_local_player():
			member.frozen = true
	await _wait_ticks(2)


## A point [param distance] metres from [param player] on the floor with a clear view of it, or INF.
func _clear_spot(player: Character, distance: float) -> Vector3:
	var space := player.get_world_3d().direct_space_state
	for i in 16:
		var candidate := player.global_position + Vector3.FORWARD.rotated(Vector3.UP, TAU * i / 16.0) * distance
		var floor_ray := PhysicsRayQueryParameters3D.create(candidate + Vector3.UP, candidate + Vector3.DOWN * 0.5, PhysicsLayers.WORLD)
		if space.intersect_ray(floor_ray).is_empty():
			continue
		var clear := true
		for height in [0.3, 0.9, 1.4, 1.8]:
			var sight := PhysicsRayQueryParameters3D.create(player.get_eye_position(), candidate + Vector3.UP * height, PhysicsLayers.WORLD)
			if not space.intersect_ray(sight).is_empty():
				clear = false
		if clear:
			return candidate
	return Vector3.INF


## Aims at [param point], presses fire for two ticks and waits for the recoil to wear off.
func _tap_at(player: Character, point: Vector3) -> void:
	player.aim_at(point)
	Input.action_press("shoot")
	await _wait_ticks(2)
	Input.action_release("shoot")
	await _wait_seconds(TAP_PAUSE)


func _wait_for(condition: Callable, seconds: float) -> bool:
	for i in roundi(seconds * Engine.physics_ticks_per_second):
		if condition.call():
			return true
		await get_tree().physics_frame
	return condition.call()


func _real_md5() -> String:
	return FileAccess.get_md5(StatsBook.PATH) if FileAccess.file_exists(StatsBook.PATH) else ""


func _wait_seconds(seconds: float) -> void:
	await _wait_ticks(roundi(seconds * Engine.physics_ticks_per_second))


func _wait_ticks(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _check(check_name: String, passed: bool, detail: String) -> void:
	print("%s  %s: %s" % ["PASS" if passed else "FAIL", check_name, detail])
	if not passed:
		_failures += 1
