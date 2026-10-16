extends Node3D
## Automated checks for wallbangs (M15, D-214, D-215). Run without a window:
##
##     Godot --headless --path . --fixed-fps 128 --quit-after 60000 res://tests/wallbang_test.tscn
##
## A rifleman shoots at a stand-in character 10 m away with a wall in between (a box with a surface kind,
## in a convex and in a concave version, like the map kit's props and CSG test maps):
## - What a bullet keeps going through a wall: 1 - thickness / (reach of the material × the weapon's
##   penetration): wood, metal and concrete, a slanted wall (thicker along the path), two walls in a row.
## - A wall thicker than the reach stops the bullet, a concave one too (a hit from inside a closed
##   mesh is not a way out), a weapon with no penetration stops at the first wall.
## - More penetration goes further: the sniper through 25 cm of concrete, the shotgun and pistol not.
## - Holes: a bullet that goes through leaves one on each side, plus the one on the target; a stopped one
##   leaves one. A bullet that leaves the far side and hits nothing reports where it left (walls = 1), and a
##   computer replaying the shot from that report ([method Weapon.play_remote_shot]) draws the same holes.
## - Bots (D-215): one that just heard an enemy behind thin cover turns to the sound and shoots through the
##   wall when its bullets would keep damage; not through a wall that stops them, with no wall (it would
##   see), with no wallbang chance, or for a gun that can't (the sniper rifle, the shotgun).
## - The arsenal's numbers: every weapon has a penetration, the order is sniper, hand cannon, rifle, carbine,
##   SMG and pistol, shotgun, and knife and grenades have none.
##
## Quits with the number of failed checks as the exit code (0 means everything passed).

const PLAYER_SCENE := preload("res://player/player.tscn")
const CHARACTER_SCENE := preload("res://characters/character.tscn")
const BOT_SCENE := preload("res://bots/bot.tscn")
## Where the target stands (it faces the shooter's side), and where the wall is: between them.
const TARGET_Z := -10.0
const WALL_Z := -5.0
## How close a measured damage share must be to the expected one.
const TOLERANCE := 0.03

var _failures: int = 0
var _player: Character
var _weapon: Weapon
## The damage of one unobstructed rifle shot at the target's chest, measured first.
var _baseline: float = 0.0


func _ready() -> void:
	Weapon.silent = true
	_add_box(Vector3(0, -0.5, 0), Vector3(200, 1, 200), "hard", false)
	_player = PLAYER_SCENE.instantiate()
	_player.footstep_sound = null
	add_child(_player)
	await _wait_ticks(3)
	_weapon = _player.weapon
	await _run_all()
	if _failures == 0:
		print("\nAll checks passed.")
	else:
		print("\n%d check(s) FAILED." % _failures)
	get_tree().quit(_failures)


func _run_all() -> void:
	await _test_damage_through_walls()
	await _test_stopped()
	await _test_penetration_power()
	await _test_holes()
	await _test_bots()
	_test_arsenal()


## The share of an unobstructed shot's damage that reaches a fresh target through [param walls]: a list of
## [kind, thickness, convex, yaw_degrees] entries, shot with a rifle whose penetration is [param power].
func _share(walls: Array, power: float = 1.0) -> float:
	var body_list: Array[Node] = []
	for index in walls.size():
		var wall: Array = walls[index]
		body_list.append(_add_box(Vector3(0, 1, WALL_Z - index * 1.0), Vector3(4.0, 4.0, wall[1]), wall[0], wall[2], wall[3]))
	var target := await _add_target()
	var damage := await _shoot_at(target, power)
	target.free()
	for body in body_list:
		body.free()
	await _wait_ticks(2)
	return damage / _baseline if _baseline > 0.0 else damage


## One bullet from the player's eye at [param target]'s chest; the damage it deals.
func _shoot_at(target: Character, power: float = 1.0) -> float:
	var data := _weapon.data.duplicate() as WeaponData
	data.penetration = power
	_weapon.data = data
	var aim := target.get_chest_position() - _player.get_eye_position()
	var before := target.health
	_weapon._shoot_bullet(aim.normalized())
	return before - target.health


func _test_damage_through_walls() -> void:
	var target := await _add_target()
	_baseline = await _shoot_at(target)
	target.free()
	_check("An unobstructed rifle shot hurts the target (the baseline the others are shares of)", _baseline > 20.0, "%.1f" % _baseline)
	var cases := [
		["0.1 m of wood keeps 80 %", [["wood", 0.1, true, 0.0]], 0.8],
		["... a concave (trimesh) wall too", [["wood", 0.1, false, 0.0]], 0.8],
		["0.05 m of metal keeps 58 %", [["metal", 0.05, true, 0.0]], 1.0 - 0.05 / 0.12],
		["0.1 m of concrete keeps half", [["hard", 0.1, true, 0.0]], 0.5],
		["... a concave one too", [["hard", 0.1, false, 0.0]], 0.5],
		["0.1 m of wood turned 45° is longer along the path: keeps 72 %", [["wood", 0.1, true, 45.0]], 1.0 - 0.1 / cos(deg_to_rad(45.0)) / 0.5],
		["Two 0.1 m wooden walls in a row keep 64 %", [["wood", 0.1, true, 0.0], ["wood", 0.1, true, 0.0]], 0.64],
		["Gravel (0.1 m) keeps 71 %", [["gravel", 0.1, true, 0.0]], 1.0 - 0.1 / 0.35],
	]
	for case: Array in cases:
		var share := await _share(case[1])
		_check("A rifle bullet through %s" % case[0], absf(share - case[2]) < TOLERANCE, "%.3f of the damage (expected %.3f)" % [share, case[2]])


func _test_stopped() -> void:
	var cases := [
		["25 cm of concrete (reach 20 cm)", [["hard", 0.25, true, 0.0]], 1.0],
		["... a concave (trimesh) one: a hit from inside the mesh is no way out", [["hard", 0.25, false, 0.0]], 1.0],
		["1 m of wood (a crate)", [["wood", 1.0, true, 0.0]], 1.0],
		["... a concave crate", [["wood", 1.0, false, 0.0]], 1.0],
		["Four 0.1 m wooden walls (the bullet goes through at most three)", [["wood", 0.1, true, 0.0], ["wood", 0.1, true, 0.0],
				["wood", 0.1, true, 0.0], ["wood", 0.1, true, 0.0]], 1.0],
		["Any wall for a weapon with no penetration", [["wood", 0.02, true, 0.0]], 0.0],
	]
	for case: Array in cases:
		var share := await _share(case[1], case[2])
		_check("Stopped: %s" % case[0], share == 0.0, "%.3f of the damage got through" % share)


func _test_penetration_power() -> void:
	var sniper := await _share([["hard", 0.25, true, 0.0]], 2.5)
	var shotgun := await _share([["wood", 0.1, true, 0.0]], 0.3)
	var shotgun_concrete := await _share([["hard", 0.1, true, 0.0]], 0.3)
	var pistol_concrete := await _share([["hard", 0.1, true, 0.0]], 0.5)
	var smg := await _share([["wood", 0.1, true, 0.0]], 0.5)
	_check("The sniper rifle (2.5) goes through 25 cm of concrete and keeps half; the pistol (0.5) and the shotgun (0.3) don't get through 10 cm of it",
			absf(sniper - 0.5) < TOLERANCE and pistol_concrete == 0.0 and shotgun_concrete == 0.0,
			"sniper %.3f, pistol %.3f, shotgun %.3f" % [sniper, pistol_concrete, shotgun_concrete])
	_check("Less power keeps less: the shotgun keeps 33 % and the SMG 60 % of a bullet through 10 cm of wood",
			absf(shotgun - (1.0 - 0.1 / 0.15)) < TOLERANCE and absf(smg - 0.6) < TOLERANCE, "shotgun %.3f, SMG %.3f" % [shotgun, smg])


func _test_holes() -> void:
	var wall := _add_box(Vector3(0, 1, WALL_Z), Vector3(4.0, 4.0, 0.1), "wood", true)
	var target := await _add_target()
	var landed: Array[Dictionary] = []
	var on_hit := func(hit: Dictionary) -> void: landed.append(hit)
	_weapon.hit_landed.connect(on_hit)
	var before := _weapon._impacts.size()
	_shoot_target_default(target)
	var through_holes := _weapon._impacts.size() - before
	var through_hit: Dictionary = landed.back() if not landed.is_empty() else {}
	_check("A bullet through a wall into the target leaves three holes (near side, far side, the body) and reports one wall",
			through_holes == 3 and through_hit.get("walls", 0) == 1 and through_hit.get("zone", "") != "",
			"%d holes, hit %s" % [through_holes, through_hit])
	# The same shot replayed on another computer from the host's report: the same three holes.
	var replay_before := _weapon._impacts.size()
	_weapon.play_remote_shot(true, through_hit.get("position", Vector3.ZERO))
	var replay_holes := _weapon._impacts.size() - replay_before
	_check("A computer replaying that shot from the reported hit draws the same three holes", replay_holes == 3, "%d holes" % replay_holes)
	target.free()
	# Out the far side and into nothing.
	landed.clear()
	before = _weapon._impacts.size()
	# Aimed up and past the target, so that nothing but the sky is beyond the wall.
	var past := Vector3(0, 3, TARGET_Z) - _player.get_eye_position()
	_weapon._shoot_bullet(past.normalized())
	var out_holes := _weapon._impacts.size() - before
	var out_hit: Dictionary = landed.back() if not landed.is_empty() else {}
	var left_at: Vector3 = out_hit.get("position", Vector3.ZERO)
	_check("A bullet that goes through and hits nothing leaves two holes and reports where it left the wall (walls = 1, no zone, at the far face)",
			out_holes == 2 and out_hit.get("walls", 0) == 1 and out_hit.get("zone", "x") == "" and absf(left_at.z - (WALL_Z - 0.05)) < 0.02,
			"%d holes, left at z %.3f, hit %s" % [out_holes, left_at.z, out_hit])
	var replay_out_before := _weapon._impacts.size()
	_weapon.play_remote_shot(true, left_at)
	_check("... and a computer replaying it draws those two holes", _weapon._impacts.size() - replay_out_before == 2,
			"%d holes" % (_weapon._impacts.size() - replay_out_before))
	# A wall that stops the bullet: one hole, reported at the near face.
	wall.free()
	var thick := _add_box(Vector3(0, 1, WALL_Z), Vector3(4.0, 4.0, 1.0), "hard", true)
	landed.clear()
	before = _weapon._impacts.size()
	_weapon._shoot_bullet(past.normalized())
	var stop_hit: Dictionary = landed.back() if not landed.is_empty() else {}
	_check("A bullet stopped by a wall leaves one hole, at the near face, with no walls passed",
			_weapon._impacts.size() - before == 1 and stop_hit.get("walls", -1) == 0 and absf((stop_hit.get("position", Vector3.ZERO) as Vector3).z - (WALL_Z + 0.5)) < 0.02,
			"%d holes, hit %s" % [_weapon._impacts.size() - before, stop_hit])
	_weapon.hit_landed.disconnect(on_hit)
	thick.free()
	await _wait_ticks(2)


func _shoot_target_default(target: Character) -> void:
	_shoot_at(target)


## Whether a bot at the origin facing -Z, which heard an enemy at the target's spot, shoots at the sound
## within a second, with [param walls] in between ([kind, thickness] entries) and [param chance] for the roll.
func _bot_fires_at_sound(walls: Array, chance: float, penetration: float = 1.0) -> bool:
	var bot := BOT_SCENE.instantiate() as Character
	bot.footstep_sound = null
	bot.team = 0
	add_child(bot)
	await _wait_ticks(3)
	var controller := bot.get_node("BotController") as BotController
	var difficulty := controller.difficulty.duplicate() as BotDifficulty
	difficulty.wallbang_chance = chance
	controller.difficulty = difficulty
	var data := bot.weapon.data.duplicate() as WeaponData
	data.penetration = penetration
	bot.weapon.data = data
	var bodies: Array[Node] = []
	for index in walls.size():
		bodies.append(_add_box(Vector3(0, 1, WALL_Z - index), Vector3(4.0, 4.0, walls[index][1]), walls[index][0], true))
	var senses := bot.get_node("BotSenses") as BotSenses
	senses.last_known_position = Vector3(0, 0, TARGET_Z)
	senses._time_since_lead = 0.0
	var fired := false
	for tick in 200:
		var input := CharacterInput.new()
		senses._time_since_lead = 0.0
		if controller._wallbang(input, 1.0 / 128.0):
			fired = fired or input.shoot
		elif tick == 0:
			break
	bot.free()
	for body in bodies:
		body.free()
	await _wait_ticks(2)
	return fired


func _test_bots() -> void:
	var through_wood := await _bot_fires_at_sound([["wood", 0.1]], 1.0)
	var through_concrete := await _bot_fires_at_sound([["hard", 0.25]], 1.0)
	var open := await _bot_fires_at_sound([], 1.0)
	var no_chance := await _bot_fires_at_sound([["wood", 0.1]], 0.0)
	var weak_gun := await _bot_fires_at_sound([["wood", 0.1]], 1.0, 0.0)
	var thin_wall_weak := await _bot_fires_at_sound([["hard", 0.1]], 1.0, 0.5)
	_check("A bot that heard an enemy behind 0.1 m of wood turns to the sound and shoots through the wall",
			through_wood, "fired %s" % through_wood)
	_check("... but not through a wall that stops its bullets (25 cm of concrete), not with nothing in between, not with no wallbang chance, not with a gun of no penetration",
			not through_concrete and not open and not no_chance and not weak_gun, "concrete %s, open %s, no chance %s, weak gun %s" % [through_concrete, open, no_chance, weak_gun])
	_check("... and not when the bullet would keep too little (a pistol's 0.5 through 10 cm of concrete is nothing)", not thin_wall_weak, "fired %s" % thin_wall_weak)


func _test_arsenal() -> void:
	var powers := {}
	var missing: Array[String] = []
	for path: String in WeaponData.PATHS:
		var data := load(path) as WeaponData
		if data == null:
			missing.append(path)
			continue
		powers[data.id] = data.penetration
	_check("Every weapon has a penetration: sniper 2.5, hand cannon 1.3, rifle 1, carbine 0.8, SMG and pistol 0.5, shotgun 0.3, knife and grenades 0",
			missing.is_empty() and powers.get(&"sniper") == 2.5 and powers.get(&"hand_cannon") == 1.3 and powers.get(&"rifle") == 1.0
			and powers.get(&"carbine") == 0.8 and powers.get(&"smg") == 0.5 and powers.get(&"pistol") == 0.5 and powers.get(&"shotgun") == 0.3
			and powers.get(&"knife") == 0.0 and powers.get(&"frag") == 0.0 and powers.get(&"flashbang") == 0.0 and powers.get(&"smoke") == 0.0,
			"%s" % [powers])
	var reaches: Array[float] = []
	for kind: Surfaces.Kind in Surfaces.REACH:
		reaches.append(Surfaces.reach(kind))
	_check("Every surface kind has a reach, concrete the least wood-like (0.2 m) and wood the most (0.5 m)",
			Surfaces.REACH.size() == Surfaces.Kind.size() and Surfaces.reach(Surfaces.Kind.WOOD) == 0.5 and Surfaces.reach(Surfaces.Kind.HARD) == 0.2,
			"%s" % [reaches])


# --- Helpers ---


## A wall: a box [param size] at [param center], of [param surface] ("hard", "wood", "metal", "gravel"), its collision a
## convex box or, when [param convex] is false, a closed trimesh; turned [param yaw] degrees about Y.
func _add_box(center: Vector3, size: Vector3, surface: String, convex: bool, yaw: float = 0.0) -> StaticBody3D:
	var collision := CollisionShape3D.new()
	if convex:
		var shape := BoxShape3D.new()
		shape.size = size
		collision.shape = shape
	else:
		var mesh := BoxMesh.new()
		mesh.size = size
		collision.shape = mesh.create_trimesh_shape()
	var body := StaticBody3D.new()
	body.position = center
	body.rotation_degrees.y = yaw
	body.set_meta(Surfaces.PROP_META_KEY, surface)
	body.add_child(collision)
	add_child(body)
	return body


func _add_target() -> Character:
	var target := CHARACTER_SCENE.instantiate() as Character
	target.team = 1
	target.position = Vector3(0, 0, TARGET_Z)
	target.footstep_sound = null
	add_child(target)
	await _wait_ticks(3)
	return target


func _wait_ticks(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _check(check_name: String, passed: bool, detail: String) -> void:
	print("%s  %s: %s" % ["PASS" if passed else "FAIL", check_name, detail])
	if not passed:
		_failures += 1
