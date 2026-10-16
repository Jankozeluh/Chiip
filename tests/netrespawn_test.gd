extends Node
## Automated checks for an online team respawn match (M9, D-082 online). Run without a window:
##
##     Godot --headless --path . --fixed-fps 128 --quit-after 200000 res://tests/netrespawn_test.tscn
##
## A host and a client play a 3v3 team respawn match on Square, first to 15 kills, in this one
## process ([NetHarness]). First, with the bots held, Team Deathmatch's own rules (M7, D-094,
## D-099): the respawn loadout with the primary in hand, a class picked while alive (it comes
## with the next respawn), ammo scavenged from a gun on the floor, a dropped gun that times out.
## Then the client's player runs around and fights back with taps at the nearest enemy it sees.
## Checked: the client's replica is a respawn match too; every kill and the score follow the
## host's; the dead come back on the client as on the host (the puppets and your own player, at
## the host's spot); the match ends with the same winner and score. Quits with the number of
## failed checks as the exit code.

const MAP := preload("res://maps/square.tscn")

var _harness: NetHarness
var _failures: int = 0
var _host_main: Node
var _client_main: Node
var _host_session: NetSession
var _client_session: NetSession
var _host_kills: Array = []
var _client_kills: Array = []
var _host_respawns: int = 0
var _client_respawns: int = 0
var _own_respawn_errors: Array[float] = []


func _ready() -> void:
	_harness = NetHarness.new()
	add_child(_harness)
	await _test()
	for main in [_client_main, _host_main]:
		if main != null and is_instance_valid(main):
			main.get_parent().remove_child(main)
			main.queue_free()
	for session in [_client_session, _host_session]:
		if session != null and is_instance_valid(session):
			session.close()
	for i in 40:
		await get_tree().physics_frame
	remove_child(_harness)
	_harness.queue_free()
	for i in 5:
		await get_tree().physics_frame
	if _failures == 0:
		print("\nAll checks passed.")
	else:
		print("\n%d check(s) FAILED." % _failures)
	get_tree().quit(_failures)


func _rules() -> MatchSettings:
	var rules := MatchSettings.new()
	rules.game_mode = MatchSettings.GameMode.TEAM_RESPAWN
	rules.team_size = 3
	rules.enemy_team_size = 3
	rules.kill_limit = 15
	rules.time_limit = 240.0
	rules.freeze_time = 1.0
	rules.round_end_time = 1.0
	rules.respawn_delay = 2.0
	return rules


func _test() -> void:
	_host_session = _harness.start_host("Host", "Host")
	_client_session = _harness.start_client("Client", "Jan")
	await _harness.wait_until(_client_session.is_active)
	_host_main = _harness.start_game(_host_session.get_parent(), _host_session, MAP, _rules())
	_harness.silence(_host_main.get_player())
	_client_main = _harness.start_game(_client_session.get_parent(), _client_session, MAP, _rules())
	_harness.silence(_client_main.get_player())
	var host := _host_main.get_net_game() as NetHost
	var client := _client_main.get_net_game() as NetClient
	var both := func() -> bool: return host.is_started() and client.is_welcomed()
	var started := await _harness.wait_until(both, 1200)
	var host_rules := host.rules
	var client_rules := client.rules
	_check("Online team respawn: the client's replica is a respawn match too", started and client_rules is RespawnMatch and host_rules is RespawnMatch, "")
	if not started:
		return
	for character in host_rules.get_participants():
		_harness.silence(character)
	await _test_team_deathmatch(host, client)
	for character in host_rules.get_participants():
		character.weapon.rng.seed = character.net_id
		var brain := character.get_node_or_null("BotController") as BotController
		if brain != null:
			brain.rng.seed = character.net_id * 7
	host_rules.character_killed.connect(func(victim: Character, killer: Character, _headshot: bool) -> void:
		_host_kills.append([victim.net_id, killer.net_id if killer != null else 0, host_rules.score.duplicate()]))
	client_rules.character_killed.connect(func(victim: Character, killer: Character, _headshot: bool) -> void:
		_client_kills.append([victim.net_id, killer.net_id if killer != null else 0, client_rules.score.duplicate()]))
	for character in host_rules.get_participants():
		character.respawned.connect(func() -> void: _host_respawns += 1)
	var own: Character = client.player
	for character in client_rules.get_participants():
		character.respawned.connect(func() -> void:
			_client_respawns += 1
			if character == own:
				var original := host.get_character(own.net_id)
				_own_respawn_errors.append(own.global_position.distance_to(original.global_position)))
	# The client's player hunts: runs at the nearest enemy puppet it can see and taps at its chest.
	var count := [0]
	client.command_source = func(_delta: float) -> CharacterInput:
		count[0] += 1
		var command := CharacterInput.new()
		var target: Character = null
		var best := INF
		for other in client_rules.get_participants():
			if other.team != own.team and other.is_alive() and other.visible:
				var distance := other.global_position.distance_to(own.global_position)
				if distance < best:
					best = distance
					target = other
		if target != null:
			var direction := (target.get_chest_position() - own.get_eye_position()).normalized()
			command.yaw = atan2(-direction.x, -direction.z)
			command.pitch = asin(clampf(direction.y, -1.0, 1.0))
			command.move = Vector2(0.0, -1.0) if best > 8.0 else Vector2.ZERO
			command.shoot = best < 30.0 and count[0] % 32 == 0
		else:
			command.yaw = own.get_aim_angles().x
		return command
	# How far the host's bots get from where the match play starts (a diagnosis for a match without kills).
	var starts := {}
	for character in host_rules.get_participants():
		if character.get_node_or_null("BotController") != null:
			starts[character] = character.global_position
	var farthest := [0.0]
	var over := func() -> bool:
		for character: Character in starts:
			farthest[0] = maxf(farthest[0], character.global_position.distance_to(starts[character]))
		return host_rules.phase == RoundManager.Phase.MATCH_END and client_rules.phase == RoundManager.Phase.MATCH_END
	var ended := await _harness.wait_until(over, 120000)
	await _harness.wait_ticks(30)
	client.command_source = Callable()
	_check("The match ends on both sides with the same winner and score (first to 15)",
			ended and client_rules.winner == host_rules.winner and client_rules.score == host_rules.score and host_rules.score.max() >= 15,
			"ended %s, host %d %s, client %d %s; host phase %s with %.1f s left, client phase %s, tree paused %s, %d of %d frozen on the host" % [
					ended, host_rules.winner, host_rules.score, client_rules.winner, client_rules.score,
					RoundManager.Phase.keys()[host_rules.phase], host_rules.time_left, RoundManager.Phase.keys()[client_rules.phase],
					get_tree().paused, host_rules.get_participants().filter(func(c: Character) -> bool: return c.frozen).size(),
					host_rules.get_participants().size()])
	var nav_map := host_rules.get_viewport().find_world_3d().navigation_map
	_check("Every kill reaches the client in order, with the score after it", _client_kills == _host_kills and _host_kills.size() >= 15,
			"host %d kills, client %d; the host's bots got at most %.1f m from where they stood, its navigation map has %d region(s)" % [
					_host_kills.size(), _client_kills.size(), farthest[0], NavigationServer3D.map_get_regions(nav_map).size()])
	_check("The dead come back on the client as on the host (every respawn)", _client_respawns == _host_respawns and _host_respawns >= 15,
			"host %d, client %d" % [_host_respawns, _client_respawns])
	var worst := 0.0
	for error in _own_respawn_errors:
		worst = maxf(worst, error)
	_check("Your own player comes back where the host put it", worst < 0.01, "%d respawns, worst %.3f m" % [_own_respawn_errors.size(), worst])
	print("      (score %s, %d kills, %d respawns, your player respawned %d times, %d corrections)" % [
			host_rules.score, _host_kills.size(), _host_respawns, _own_respawn_errors.size(), client.corrections])


## Team Deathmatch's own rules online, with the bots held still.
func _test_team_deathmatch(host: NetHost, client: NetClient) -> void:
	var host_rules := host.rules as RespawnMatch
	var client_rules := client.rules as RespawnMatch
	var own: Character = client.player
	var friend := host.get_character(own.net_id)
	var live := func() -> bool: return host_rules.phase == RoundManager.Phase.LIVE and client_rules.phase == RoundManager.Phase.LIVE
	await _harness.wait_until(live, 600)
	_hold_bots(host_rules, true)
	await _harness.wait_ticks(30)
	_check("Team Deathmatch's loadout is the same on both: the class's own guns, the primary in hand",
			_ids(own) == _ids(friend) and _held(own) == _held(friend) and _primary_in_hand(friend),
			"host %s holding %s, client %s holding %s" % [_ids(friend), _held(friend), _ids(own), _held(own)])

	# A class picked while alive: it waits for the next respawn, which brings its loadout.
	var other: ClassData = null
	for data in client_rules.get_draft(own):
		if data != own.class_data:
			other = data
			break
	client_rules.request_class(own, other)
	await _harness.wait_ticks(30)
	var waited := own.class_data != other and friend.class_data != other \
			and client_rules.get_next_class(own) == other and host_rules.get_next_class(friend) == other
	var died_at := friend.global_position
	friend.take_damage(1000.0, Hitbox.Zone.CHEST, null)
	var back := func() -> bool:
		return own.is_alive() and friend.is_alive() and own.class_data == other and friend.class_data == other \
				and _ids(own) == _ids(friend) and _held(own) == _held(friend)
	var respawned := await _harness.wait_until(back, 900)
	await _harness.wait_ticks(30)
	_check("A class picked on the client while alive waits for the next respawn, then it is the class on both, with its loadout",
			other != null and waited and respawned and _primary_in_hand(friend) and client_rules.get_next_class(own) == other,
			"waited %s, now host %s %s, client %s %s" % [waited, friend.class_data.id, _ids(friend), own.class_data.id, _ids(own)])

	# The gun the friend dropped when it died lies on both floors, then times out on both.
	var host_gun := _floor_gun_near(host_rules.get_parent(), died_at)
	var client_gun_shown := func() -> bool: return _floor_gun_near(client_rules.get_parent(), died_at) != null
	var shown := await _harness.wait_until(client_gun_shown, 120)
	var dropped := host_gun != null
	if dropped:
		host_gun.age = RespawnMatch.DROPPED_GUN_LIFETIME + 1.0
	var client_gun_gone := func() -> bool: return _floor_gun_near(client_rules.get_parent(), died_at) == null
	var gone := await _harness.wait_until(client_gun_gone, 120)
	_check("A gun dropped in Team Deathmatch lies on the client's floor too and vanishes there when it times out on the host",
			dropped and shown and gone and not is_instance_valid(host_gun),
			"host gun %s, shown %s, gone %s" % [dropped, shown, gone])

	# Scavenging: walking over a dropped Sparrow tops up yours, which isn't in your hand.
	var sparrow := WeaponData.find(&"pistol")
	var host_sparrow := friend.inventory.find(sparrow)
	var own_sparrow := own.inventory.find(sparrow)
	var scavenged := false
	if host_sparrow != null and own_sparrow != null and friend.weapon != host_sparrow:
		host_sparrow.reserve = 4
		friend.inventory.changed.emit()
		await _harness.wait_until(func() -> bool: return own_sparrow.reserve == 4, 120)
		WeaponPickup.spawn(host_rules.get_parent(), sparrow, 0, 12, friend.global_position + Vector3.UP * 0.3, 0.0)
		var topped_up := func() -> bool: return host_sparrow.reserve == 16 and own_sparrow.reserve == 16
		scavenged = await _harness.wait_until(topped_up, 240)
	_check("Ammo scavenged from a gun on the floor reaches the client, also for a gun that isn't in hand",
			scavenged, "host %d, client %d" % [host_sparrow.reserve if host_sparrow != null else -1, own_sparrow.reserve if own_sparrow != null else -1])
	var host_spots := _spots(host_rules.get_parent())
	var client_spots := _spots(client_rules.get_parent())
	_check("Team Deathmatch's map weapons are the same on the client: as many, the same guns, at the same places",
			host_spots.size() == host_rules.settings.respawn_map_weapons and client_spots == host_spots,
			"host %s, client %s" % [host_spots, client_spots])
	_hold_bots(host_rules, false)


## The map weapons in [param map]'s world: [gun, place] each, sorted.
func _spots(map: Node) -> Array:
	var spots := []
	var world := map.get_viewport().find_world_3d()
	for node in map.get_tree().get_nodes_in_group(WeaponSpot.GROUP):
		var spot := node as WeaponSpot
		if spot != null and spot.get_viewport().find_world_3d() == world and not spot.is_queued_for_deletion():
			spots.append([String(spot.weapon.id), spot.global_position.snapped(Vector3.ONE * 0.01)])
	spots.sort()
	return spots


func _hold_bots(rules: RoundManager, hold: bool) -> void:
	for character in rules.get_participants():
		if character.get_node_or_null("BotController") != null:
			character.frozen = hold


func _ids(character: Character) -> Array:
	return character.inventory.get_weapons().map(func(weapon: Weapon) -> StringName: return weapon.data.id)


func _held(character: Character) -> StringName:
	return character.weapon.data.id if character.weapon != null else &""


## True if [param character] holds its primary, or carries none.
func _primary_in_hand(character: Character) -> bool:
	var has_primary := character.inventory.get_weapons().any(func(weapon: Weapon) -> bool: return weapon.data.slot == WeaponData.Slot.PRIMARY)
	return character.weapon != null and (character.weapon.data.slot == WeaponData.Slot.PRIMARY or not has_primary)


## A gun lying on the floor (not a map weapon) within 2 m of [param at] in [param map]'s world.
func _floor_gun_near(map: Node, at: Vector3) -> WeaponPickup:
	for pickup in WeaponPickup.all_in_world(map):
		if not pickup.floating and not pickup.is_queued_for_deletion() and pickup.global_position.distance_to(at) < 2.0:
			return pickup
	return null


func _check(description: String, passed: bool, detail: String) -> void:
	if passed:
		print("PASS  ", description)
	else:
		_failures += 1
		print("FAIL  ", description, "  (", detail, ")")
