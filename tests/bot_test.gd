extends Node3D
## Automated bot tests. Run without a window:
##
##     Godot --headless --path . --fixed-fps 128 res://tests/bot_test.tscn
##
## Builds an open floor with one wall, bakes a navigation mesh for it, and puts
## bots against a player that stands still (no keyboard input). Bots hold their
## position (like holding an angle) except in the walking check. Checks walking,
## vision, gradual noticing, hearing, reaction time, never shooting through
## walls, that bots can win, that difficulty matters, dying, friendly fire
## (off: teammates take no damage and bullets pass through them; on: a third),
## and holding fire while a teammate is in the line of fire.
## Random numbers are seeded, so every run gives the same results. Quits with the number of failed checks as
## the exit code (0 means everything passed).

const PLAYER_SCENE := preload("res://player/player.tscn")
const BOT_SCENE := preload("res://bots/bot.tscn")
## The wall's front face (toward the open area) is at z = WALL_Z.
const WALL_Z := -20.0

var _player: Character
var _failures: int = 0


func _ready() -> void:
	_build_level()
	await _bake_navigation()
	_player = PLAYER_SCENE.instantiate()
	_silence(_player)
	add_child(_player)
	await _wait_ticks(4)
	await _run_all()
	if _failures == 0:
		print("\nAll checks passed.")
	else:
		print("\n%d check(s) FAILED." % _failures)
	get_tree().quit(_failures)


func _run_all() -> void:
	await _test_walks_to_a_point()
	await _test_vision()
	await _test_noticing_takes_time()
	await _test_hearing()
	await _test_reaction_time()
	await _test_no_shooting_through_walls()
	await _test_normal_bot_wins()
	await _test_difficulty_matters()
	await _test_dies_at_100_damage()
	await _test_friendly_fire_off()
	await _test_friendly_fire_on()
	await _test_holds_fire_for_teammates()
	await _test_bullets_pass_through_teammates()


func _test_walks_to_a_point() -> void:
	# The only patrol point on the map, 40 m away: a patrolling bot must walk there.
	var goal := Marker3D.new()
	goal.position = Vector3(20, 0, 20)
	goal.add_to_group(BotController.PATROL_GROUP)
	add_child(goal)
	# Hide the player behind the wall, so the bot only walks and doesn't stop to fight.
	await _place_player(Vector3(0, 0, WALL_Z - 5.0))
	var bot := await _add_bot(Vector3(-20, 0, 20), Vector3(0, 1.6, 20), "normal", 1, false)
	var ticks := 0
	var miss := INF
	while ticks < 128 * 15:
		await get_tree().physics_frame
		ticks += 1
		miss = Vector2(bot.global_position.x - goal.position.x, bot.global_position.z - goal.position.z).length()
		if miss < 1.0:
			break
	_check("Bot patrols to a point 40 m away", miss < 1.0,
			"within 1 m of the patrol point after %.1f s" % (ticks / 128.0) if miss < 1.0 else "still %.1f m away after 15 s" % miss)
	await _remove(bot)
	goal.queue_free()


func _test_vision() -> void:
	await _place_player(Vector3(0, 0, 0))
	var bot := await _add_bot(Vector3(0, 0, 10), Vector3(0, 1.6, 0), "normal", 1)
	var senses := _senses(bot)
	_player.god_mode = true
	await _wait_seconds(1.0)
	_check("Notices the player in the open, in front", senses.visible_enemy == _player, "10 m away, facing the player, after 1 s")
	await _remove(bot)

	bot = await _add_bot(Vector3(0, 0, 10), Vector3(0, 1.6, 30), "normal", 1)
	senses = _senses(bot)
	await _wait_seconds(1.0)
	_check("Doesn't see the player behind its back", senses.visible_enemy == null, "facing away")
	await _remove(bot)

	await _place_player(Vector3(0, 0, WALL_Z - 5.0))
	bot = await _add_bot(Vector3(0, 0, WALL_Z + 10.0), Vector3(0, 1.6, WALL_Z - 5.0), "normal", 1)
	senses = _senses(bot)
	await _wait_seconds(1.0)
	_check("Doesn't see the player behind a wall", senses.visible_enemy == null, "facing the wall, player 5 m behind it")
	await _remove(bot)
	_player.god_mode = false


func _test_noticing_takes_time() -> void:
	_player.god_mode = true
	var times := {}
	for case in [["10 m, straight ahead", Vector3(0, 0, 10), Vector3(0, 1.6, 0)],
			["40 m, straight ahead", Vector3(0, 0, 40), Vector3(0, 1.6, 0)],
			["10 m, edge of vision", Vector3(0, 0, 10), Vector3(-9, 1.6, 2)]]:
		await _place_player(Vector3(0, 0, 0))
		var bot := await _add_bot(case[1], case[2], "normal", 1)
		var senses := _senses(bot)
		var ticks := 0
		while senses.visible_enemy != _player and ticks < 128 * 6:
			await get_tree().physics_frame
			ticks += 1
		times[case[0]] = ticks / 128.0
		await _remove(bot)
	_player.god_mode = false
	var near: float = times["10 m, straight ahead"]
	var far: float = times["40 m, straight ahead"]
	var side: float = times["10 m, edge of vision"]
	_check("Noticing takes longer far away and at the edge of vision", near < far and near < side and near >= 0.25,
			"Normal bot notices: 10 m ahead %.2f s, 40 m ahead %.2f s, 10 m at the edge %.2f s" % [near, far, side])


func _test_hearing() -> void:
	await _place_player(Vector3(0, 0, 0))
	var bot := await _add_bot(Vector3(0, 0, 10), Vector3(0, 1.6, 30), "normal", 1)
	var senses := _senses(bot)
	_player.god_mode = true
	for case in [["walk", false], ["", true]]:
		await _place_player(Vector3(0, 0, 0))
		senses.reset()
		if case[0] != "":
			Input.action_press(case[0])
		Input.action_press("move_right")
		await _wait_seconds(1.5)
		Input.action_release("move_right")
		if case[0] != "":
			Input.action_release(case[0])
		var heard := senses.has_lead()
		_check("Hears running, not walking" if case[1] else "Doesn't hear walking (Shift)", heard == case[1],
				"%s behind the bot: heard = %s" % ["running" if case[1] else "walking", heard])
	_player.god_mode = false
	await _remove(bot)


func _test_reaction_time() -> void:
	await _place_player(Vector3(0, 0, 0))
	_player.god_mode = true
	var bot := await _add_bot(Vector3(0, 0, 10), Vector3(0, 1.6, 0), "normal", 2)
	var timing := {"spotted": -1, "first_shot": -1, "tick": 0}
	_senses(bot).enemy_spotted.connect(func(_enemy: Character) -> void:
		if timing.spotted < 0: timing.spotted = timing.tick)
	bot.weapon.fired.connect(func(_n: int) -> void:
		if timing.first_shot < 0: timing.first_shot = timing.tick)
	while timing.first_shot < 0 and timing.tick < 128 * 3:
		await get_tree().physics_frame
		timing.tick += 1
	var reaction: float = (timing.first_shot - timing.spotted) / 128.0
	var minimum := _brain(bot).difficulty.reaction_time * 0.8
	_check("Waits its reaction time before shooting", timing.first_shot >= 0 and reaction >= minimum,
			"first shot %.2f s after spotting (Normal: at least %.2f s)" % [reaction, minimum])
	_player.god_mode = false
	await _remove(bot)


func _test_no_shooting_through_walls() -> void:
	await _place_player(Vector3(0, 0, WALL_Z - 5.0))
	var bot := await _add_bot(Vector3(0, 0, WALL_Z + 10.0), Vector3(0, 1.6, WALL_Z - 5.0), "hard", 1)
	var shots := [0]
	bot.weapon.fired.connect(func(_n: int) -> void: shots[0] += 1)
	await _wait_seconds(3.0)
	_check("Never shoots through a wall", shots[0] == 0 and _player.health == _player.max_health,
			"Hard bot, player behind the wall for 3 s: %d shots, player at %d HP" % [shots[0], ceili(_player.health)])
	await _remove(bot)


func _test_normal_bot_wins() -> void:
	var kills := 0
	var details: PackedStringArray = []
	for seed in [1, 2, 3]:
		var seconds := await _duel("normal", seed)
		if seconds <= 5.0:
			kills += 1
		details.append("%.2f s" % seconds if seconds < INF else "no kill")
	_check("A Normal bot kills a standing player at 10 m within 5 s (most runs)", kills >= 2,
			"seeds 1–3: %s" % ", ".join(details))


func _test_difficulty_matters() -> void:
	var totals := {}
	for level in ["easy", "hard"]:
		var total := 0.0
		for seed in [1, 2, 3]:
			total += minf(await _duel(level, seed), 6.0)
		totals[level] = total / 3.0
	_check("Hard bots kill faster than Easy bots", totals.hard < totals.easy,
			"average time to kill a standing player at 10 m: Easy %.2f s, Hard %.2f s" % [totals.easy, totals.hard])


func _test_dies_at_100_damage() -> void:
	var bot := await _add_bot(Vector3(10, 0, 30), Vector3(10, 1.6, 40), "normal", 1)
	var deaths := []
	bot.died.connect(func(killer: Character) -> void: deaths.append(killer))
	bot.take_damage(99.0, Hitbox.Zone.CHEST, _player)
	var alive_at_99 := bot.is_alive()
	bot.take_damage(1.0, Hitbox.Zone.CHEST, _player)
	_check("Dies at exactly 100 damage, killer reported", alive_at_99 and not bot.is_alive() and deaths == [_player],
			"alive after 99: %s, alive after 100: %s, died signals: %d" % [alive_at_99, bot.is_alive(), deaths.size()])
	await _remove(bot)


func _test_friendly_fire_off() -> void:
	Teams.friendly_fire = false
	# Out of the bots' sight, so they only stand there.
	await _place_player(Vector3(0, 0, WALL_Z - 5.0))
	var victim := await _add_bot(Vector3(10, 0, 30), Vector3(10, 1.6, 40), "normal", 1)
	var mate := await _add_bot(Vector3(16, 0, 30), Vector3(16, 1.6, 40), "normal", 2)
	var damage_events := []
	victim.damaged.connect(func(amount: float, _zone: Hitbox.Zone, _attacker: Character) -> void: damage_events.append(amount))
	victim.take_damage(36.0, Hitbox.Zone.CHEST, mate)
	_check("Friendly fire off: teammates take no damage",
			victim.health == victim.max_health and damage_events.is_empty(),
			"a teammate's 36 damage: %d HP left, %d damaged signals" % [ceili(victim.health), damage_events.size()])
	await _remove(victim)
	await _remove(mate)


func _test_friendly_fire_on() -> void:
	Teams.friendly_fire = true
	await _place_player(Vector3(0, 0, WALL_Z - 5.0))
	var victim := await _add_bot(Vector3(10, 0, 30), Vector3(10, 1.6, 40), "normal", 1)
	var mate := await _add_bot(Vector3(16, 0, 30), Vector3(16, 1.6, 40), "normal", 2)
	victim.take_damage(36.0, Hitbox.Zone.CHEST, mate)
	# The player is on the other team, so the same hit counts in full.
	mate.take_damage(36.0, Hitbox.Zone.CHEST, _player)
	_check("Friendly fire on: teammates take a third",
			is_equal_approx(victim.health, 88.0) and is_equal_approx(mate.health, 64.0),
			"36 damage: from a teammate %.1f HP left (expected 88), from an enemy %.1f HP left (expected 64)" % [victim.health, mate.health])
	Teams.friendly_fire = false
	await _remove(victim)
	await _remove(mate)


func _test_bullets_pass_through_teammates() -> void:
	# The player shoots from the origin toward -Z at a teammate 6 m away, with an
	# enemy 12 m away directly behind the teammate. Both stand still and have no
	# brain, so nothing else shoots.
	var results := {}
	for friendly_fire in [true, false]:
		Teams.friendly_fire = friendly_fire
		await _place_player(Vector3(0, 0, 0))
		var mate := await _add_target(Vector3(0, 0, -6), 0)
		var enemy := await _add_target(Vector3(0, 0, -12), 1)
		_player.weapon.rng.seed = 1
		_player.aim_at(enemy.global_position + Vector3.UP * 1.2)
		Input.action_press("shoot")
		await _wait_ticks(2)
		Input.action_release("shoot")
		results[friendly_fire] = [mate.health < mate.max_health, enemy.health < enemy.max_health]
		await _remove(mate)
		await _remove(enemy)
	Teams.friendly_fire = false
	var control: Array = results[true]
	var test: Array = results[false]
	# With friendly fire on the teammate stops the bullet (so the setup really
	# has him in the line of fire); with it off the bullet reaches the enemy.
	_check("Friendly fire off: bullets pass through teammates",
			control == [true, false] and test == [false, true],
			"teammate in front, enemy behind. Friendly fire on: teammate hit = %s, enemy hit = %s. Off: teammate hit = %s, enemy hit = %s" % [
					control[0], control[1], test[0], test[1]])


func _test_holds_fire_for_teammates() -> void:
	# A bot faces the player 10 m away with a teammate standing right between
	# them. It must not shoot until the teammate steps 3 m aside.
	await _place_player(Vector3(0, 0, 0))
	_player.god_mode = true
	var bot := await _add_bot(Vector3(0, 0, 10), Vector3(0, 1.6, 0), "normal", 3)
	var mate := await _add_target(Vector3(0, 0, 5), bot.team)
	var shots := [0]
	bot.weapon.fired.connect(func(_spray_shot: int) -> void: shots[0] += 1)
	await _wait_seconds(2.5)
	var engaged := _brain(bot).state == BotController.State.ENGAGE
	var while_blocked: int = shots[0]
	mate.respawn(Vector3(3, 0, 5), 0.0)
	await _wait_seconds(2.5)
	_check("Holds fire while a teammate is in the line of fire", engaged and while_blocked == 0 and shots[0] > 0,
			"fighting the player: %s; shots with the teammate in the way: %d, after it stepped aside: %d" % [
					engaged, while_blocked, shots[0] - while_blocked])
	_player.god_mode = false
	await _remove(bot)
	await _remove(mate)


# --- Helpers ---


## A bot of [param level] 10 m from a standing player; returns seconds until the
## player dies, or INF if the player survives 6 s.
func _duel(level: String, seed: int) -> float:
	await _place_player(Vector3(0, 0, 0))
	var bot := await _add_bot(Vector3(0, 0, 10), Vector3(1.5, 1.6, 0), level, seed)
	var ticks := 0
	while _player.is_alive() and ticks < 128 * 6:
		await get_tree().physics_frame
		ticks += 1
	var seconds := ticks / 128.0 if not _player.is_alive() else INF
	await _remove(bot)
	return seconds


## Adds a bot at [param spot] looking at [param look_at_point]. With [param hold]
## it stays put and watches (like holding an angle) instead of patrolling.
func _add_bot(spot: Vector3, look_at_point: Vector3, level: String, seed: int, hold: bool = true) -> Character:
	var bot: Character = BOT_SCENE.instantiate()
	bot.position = spot
	_silence(bot)
	var brain: BotController = bot.get_node("BotController")
	brain.difficulty = load("res://bots/difficulty_%s.tres" % level)
	brain.rng.seed = seed
	brain.hold_position = hold
	bot.weapon.rng.seed = seed
	add_child(bot)
	await _wait_ticks(2)
	bot.aim_at(look_at_point)
	return bot


## A character that just stands at [param spot] on [param team]: the bot's body
## and hit zones, but no brain, so it neither moves nor shoots.
func _add_target(spot: Vector3, team: int) -> Character:
	var target: Character = BOT_SCENE.instantiate()
	target.get_node("BotController").free()
	target.get_node("BotSenses").free()
	target.team = team
	target.position = spot
	_silence(target)
	add_child(target)
	await _wait_ticks(2)
	return target


func _remove(bot: Character) -> void:
	bot.queue_free()
	await _wait_ticks(2)


## Puts the player at a spot, alive with full health, keys released.
func _place_player(spot: Vector3) -> void:
	for action in ["move_forward", "move_back", "move_left", "move_right", "crouch", "walk", "shoot"]:
		Input.action_release(action)
	_player.respawn(spot, 0.0)
	await _wait_ticks(4)


## Headless runs have no audio device; sounds that never finish "playing" would
## be reported as leaks when Godot exits.
func _silence(character: Character) -> void:
	character.footstep_sound = null
	var weapon: Weapon = character.get_node(character.get_path_to(character.weapon)) if character.weapon else null
	if weapon != null:
		var data := weapon.data.duplicate() as WeaponData
		data.shot_sound = null
		data.dry_fire_sound = null
		data.reload_sound = null
		weapon.data = data


func _brain(bot: Character) -> BotController:
	return bot.get_node("BotController")


func _senses(bot: Character) -> BotSenses:
	return bot.get_node("BotSenses")


func _wait_seconds(seconds: float) -> void:
	await _wait_ticks(roundi(seconds * Engine.physics_ticks_per_second))


func _wait_ticks(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _check(check_name: String, passed: bool, detail: String) -> void:
	print("%s  %s: %s" % ["PASS" if passed else "FAIL", check_name, detail])
	if not passed:
		_failures += 1


## An 80 × 80 m floor and a 20 m wide, 4 m tall wall across it at WALL_Z.
func _build_level() -> void:
	_add_box(Vector3(0, -0.5, 0), Vector3(80, 1, 80))
	_add_box(Vector3(0, 2, WALL_Z - 0.5), Vector3(20, 4, 1))


func _add_box(center: Vector3, size: Vector3) -> void:
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	var body := StaticBody3D.new()
	body.position = center
	body.add_child(collision)
	body.add_to_group("navigation_source")
	add_child(body)


## Bakes a navigation mesh for the test level, with the same settings as the test map.
func _bake_navigation() -> void:
	var region := NavigationRegion3D.new()
	region.navigation_mesh = load("res://maps/test_map_navmesh.tres").duplicate()
	add_child(region)
	await _wait_ticks(2)
	region.bake_navigation_mesh(false)
	await _wait_ticks(2)
