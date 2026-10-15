extends Node3D
## Automated weapon tests for the Rifle. Run without a window:
##
##     Godot --headless --path . --fixed-fps 128 res://tests/weapon_test.tscn
##
## Builds a floor, a tall wall and two target dummies, fires the player's rifle
## through the real input path, and checks fire rate, ammo, reloads, accuracy,
## damage per zone, falloff, the spray pattern and recoil recovery. Spread uses
## a fixed seed, so every run gives the same shots. Quits with the number of
## failed checks as the exit code (0 means everything passed).

const PLAYER_SCENE := preload("res://player/player.tscn")
const DUMMY_SCENE := preload("res://maps/props/target_dummy.tscn")
const U := Character.UNITS_TO_METRES
## The wall's front face is this far straight ahead of the player.
const WALL_DISTANCE := 30.0
## A dummy close by (off to the right, in front of the wall) and one far away (past the wall's end).
const NEAR_DUMMY_SPOT := Vector3(5, 0, -5)
const FAR_DUMMY_SPOT := Vector3(20, 0, -40)
## Pause after a single shot, long enough for recoil to wear off completely.
const TAP_PAUSE := 0.4

var _player: Character
var _weapon: Weapon
var _rifle: WeaponData
var _near_dummy: TargetDummy
var _far_dummy: TargetDummy
## Physics tick of every shot fired.
var _shot_ticks: Array[int] = []
var _tick: int = 0
var _failures: int = 0


func _ready() -> void:
	_build_level()
	_player = PLAYER_SCENE.instantiate()
	add_child(_player)
	_near_dummy = _add_dummy(NEAR_DUMMY_SPOT)
	_far_dummy = _add_dummy(FAR_DUMMY_SPOT)
	_weapon = _player.weapon
	# A silent copy of the rifle: headless runs have no audio device, and sounds
	# that never finish "playing" would be reported as leaks when Godot exits.
	_rifle = _weapon.data.duplicate() as WeaponData
	_rifle.shot_sound = null
	_rifle.dry_fire_sound = null
	_rifle.reload_sound = null
	_weapon.data = _rifle
	_weapon.rng.seed = 12345
	_weapon.fired.connect(func(_spray_shot: int) -> void: _shot_ticks.append(_tick))
	get_tree().physics_frame.connect(func() -> void: _tick += 1)
	await _run_all()
	if _failures == 0:
		print("\nAll checks passed.")
	else:
		print("\n%d check(s) FAILED." % _failures)
	get_tree().quit(_failures)


func _run_all() -> void:
	await _test_fire_rate()
	await _test_magazine_and_auto_reload()
	await _test_manual_reload()
	await _test_inaccuracy_by_stance()
	await _test_first_shot_accuracy()
	await _test_zone_damage()
	await _test_damage_falloff()
	await _test_spray_pattern_and_recovery()


func _test_fire_rate() -> void:
	await _reset()
	Input.action_press("shoot")
	while _shot_ticks.size() < 11:
		await get_tree().physics_frame
	Input.action_release("shoot")
	var seconds := (_shot_ticks[10] - _shot_ticks[0]) / float(Engine.physics_ticks_per_second)
	_check("Fire rate 600 rpm", absf(seconds - 1.0) <= 1.0 / Engine.physics_ticks_per_second,
			"10 shot intervals took %.3f s (expected 1.000 s, ± 1 tick)" % seconds)


func _test_magazine_and_auto_reload() -> void:
	await _reset()
	Input.action_press("shoot")
	await _wait_seconds(4.0)
	_check("Magazine holds 30 rounds", _shot_ticks.size() == 30 and _weapon.magazine == 0,
			"%d shots fired, %d left" % [_shot_ticks.size(), _weapon.magazine])
	Input.action_release("shoot")
	await _wait_ticks(1)
	_check("Letting go of an empty gun starts a reload", _weapon.is_reloading(), "auto-reload, like CS")
	await _wait_seconds(2.4)
	var magazine_before_end := _weapon.magazine
	await _wait_seconds(0.2)
	_check("Reload takes 2.5 s", magazine_before_end == 0 and _weapon.magazine == 30 and _weapon.reserve == 60,
			"magazine %d at 2.4 s, %d at 2.6 s; reserve %d" % [magazine_before_end, _weapon.magazine, _weapon.reserve])


func _test_manual_reload() -> void:
	await _reset()
	Input.action_press("shoot")
	while _shot_ticks.size() < 5:
		await get_tree().physics_frame
	Input.action_release("shoot")
	_send_action("reload")
	await _wait_seconds(2.6)
	_check("R reloads a partly used magazine", _weapon.magazine == 30 and _weapon.reserve == 85,
			"magazine %d, reserve %d after firing 5" % [_weapon.magazine, _weapon.reserve])


func _test_inaccuracy_by_stance() -> void:
	await _reset()
	var expected := _rifle.standing_inaccuracy
	_check("Standing inaccuracy", is_equal_approx(_weapon.get_inaccuracy(), expected),
			"%.2f° (expected %.2f°)" % [_weapon.get_inaccuracy(), expected])

	Input.action_press("crouch")
	await _wait_seconds(0.3)
	expected = _rifle.crouching_inaccuracy
	_check("Crouched inaccuracy", is_equal_approx(_weapon.get_inaccuracy(), expected),
			"%.2f° (expected %.2f°)" % [_weapon.get_inaccuracy(), expected])
	Input.action_release("crouch")
	await _wait_seconds(0.3)

	Input.action_press("move_right")
	await _wait_seconds(1.5)
	expected = _rifle.standing_inaccuracy + _rifle.moving_inaccuracy
	_check("Running inaccuracy", is_equal_approx(_weapon.get_inaccuracy(), expected),
			"%.2f° at full speed (expected %.2f°)" % [_weapon.get_inaccuracy(), expected])
	Input.action_release("move_right")
	await _wait_seconds(1.0)

	_send_action("jump")
	await _wait_ticks(10)
	expected = _rifle.standing_inaccuracy + _rifle.air_inaccuracy
	_check("In-air inaccuracy", _weapon.get_inaccuracy() >= expected,
			"%.2f° (at least %.2f°)" % [_weapon.get_inaccuracy(), expected])
	await _wait_seconds(1.0)


func _test_first_shot_accuracy() -> void:
	await _reset()
	var worst := 0.0
	for i in 20:
		var aim_point := _player.get_eye_position() + Vector3(0, 0, -WALL_DISTANCE)
		var hit := await _tap_at(aim_point)
		worst = maxf(worst, _angle_between(aim_point, hit.get("position", Vector3.ZERO)))
	var cone := _rifle.standing_inaccuracy
	_check("First shots land inside the standing cone", worst <= cone + 0.001,
			"worst of 20 taps: %.3f° off (cone %.2f°)" % [worst, cone])


func _test_zone_damage() -> void:
	await _reset()
	_use_perfect_accuracy()
	var head_damage := 0.0
	for part in ["Head", "Stomach", "Chest", "LeftArm", "LeftLeg"]:
		var hitbox: Hitbox = _near_dummy.get_node("Hitboxes/" + part)
		var hit := await _tap_at(hitbox.global_position)
		var multiplier: float = Hitbox.MULTIPLIERS[hitbox.zone]
		var expected := _rifle.damage * _falloff(hit.get("distance", 0.0)) * multiplier
		var damage: float = hit.get("damage", 0.0)
		_check("%s damage ×%s" % [hitbox.get_zone_name(), multiplier],
				hit.get("zone", "") == hitbox.get_zone_name() and is_equal_approx(damage, expected),
				"%.2f at %.1f m (expected %.2f)" % [damage, hit.get("distance", 0.0), expected])
		if hitbox.zone == Hitbox.Zone.HEAD:
			head_damage = damage
	_check("A headshot kills an unarmored player", head_damage >= 100.0, "%.1f damage vs. 100 HP" % head_damage)


func _test_damage_falloff() -> void:
	await _reset()
	_use_perfect_accuracy()
	var near := await _tap_at(_near_dummy.get_node("Hitboxes/Chest").global_position)
	var far := await _tap_at(_far_dummy.get_node("Hitboxes/Chest").global_position)
	var extra_units: float = (far.get("distance", 0.0) - near.get("distance", 0.0)) / U
	var expected_ratio := pow(_rifle.range_modifier, extra_units / 500.0)
	var ratio: float = far.get("damage", 0.0) / maxf(near.get("damage", 0.0), 0.001)
	_check("Damage falls off ×0.98 per 500 units", absf(ratio - expected_ratio) < 0.0001,
			"chest %.2f at %.1f m vs. %.2f at %.1f m (ratio %.4f, expected %.4f)" % [
			near.get("damage", 0.0), near.get("distance", 0.0), far.get("damage", 0.0), far.get("distance", 0.0), ratio, expected_ratio])


func _test_spray_pattern_and_recovery() -> void:
	await _reset()
	_use_perfect_accuracy()
	var eye := _player.get_eye_position()
	_player.aim_at(eye + Vector3(0, 0, -WALL_DISTANCE))
	var hits: Array[Vector3] = []
	_weapon.hit_landed.connect(func(hit: Dictionary) -> void: hits.append(hit.position))
	Input.action_press("shoot")
	while hits.size() < 10:
		await get_tree().physics_frame
	Input.action_release("shoot")
	var worst := 0.0
	for i in hits.size():
		var direction := (hits[i] - eye).normalized()
		var offset := Vector2(rad_to_deg(atan2(direction.x, -direction.z)), rad_to_deg(asin(direction.y)))
		worst = maxf(worst, offset.distance_to(_rifle.spray_pattern[i]))
	_check("Spray follows the pattern", worst < 0.001,
			"first 10 shots, largest difference %.4f° (random spread off)" % worst)
	_check("The view kicks during a spray", _weapon.view_punch.y > 1.0,
			"view kicked %.2f° up after 10 shots" % _weapon.view_punch.y)
	await _wait_seconds(1.0)
	_check("Recoil wears off after a pause", _weapon.get_spray_shot() == 1 and _weapon.view_punch.length() < 0.05,
			"after 1 s: next shot is spray shot #%d, view kick %.3f°" % [_weapon.get_spray_shot(), _weapon.view_punch.length()])


# --- Helpers ---


## Releases all keys, puts the player at the start facing the wall, refills
## the rifle and waits until reloads and recoil are over.
func _reset() -> void:
	for action in ["move_forward", "move_back", "move_left", "move_right", "crouch", "walk", "shoot"]:
		Input.action_release(action)
	while _weapon.is_reloading():
		await get_tree().physics_frame
	_weapon.data = _rifle
	_player.global_position = Vector3.ZERO
	_player.velocity = Vector3.ZERO
	_player.reset_physics_interpolation()
	await _wait_seconds(0.5)
	_player.aim_at(_player.get_eye_position() + Vector3(0, 0, -WALL_DISTANCE))
	_weapon.magazine = _rifle.magazine_size
	_weapon.reserve = _rifle.reserve_ammo
	await _wait_seconds(2.5)
	_shot_ticks.clear()


## Swaps in a copy of the rifle data with no random spread, so shots go exactly where aimed.
func _use_perfect_accuracy() -> void:
	var perfect := _rifle.duplicate() as WeaponData
	perfect.standing_inaccuracy = 0.0
	perfect.spray_inaccuracy_per_shot = 0.0
	perfect.max_spray_inaccuracy = 0.0
	_weapon.data = perfect


## Aims at a point, fires one shot, waits for recoil to wear off and returns the hit.
func _tap_at(point: Vector3) -> Dictionary:
	_player.aim_at(point)
	_weapon.last_hit = {}
	Input.action_press("shoot")
	await _wait_ticks(2)
	Input.action_release("shoot")
	await _wait_seconds(TAP_PAUSE)
	return _weapon.last_hit.duplicate()


func _falloff(distance: float) -> float:
	return pow(_rifle.range_modifier, distance / U / 500.0)


## Angle in degrees between the directions from the eyes to two points.
func _angle_between(a: Vector3, b: Vector3) -> float:
	var eye := _player.get_eye_position()
	return rad_to_deg((a - eye).angle_to(b - eye))


## Sends an action press and release the same way a real key press arrives.
func _send_action(action: String) -> void:
	for pressed in [true, false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = pressed
		Input.parse_input_event(event)
	Input.flush_buffered_events()


func _wait_seconds(seconds: float) -> void:
	await _wait_ticks(roundi(seconds * Engine.physics_ticks_per_second))


func _wait_ticks(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _check(check_name: String, passed: bool, detail: String) -> void:
	print("%s  %s: %s" % ["PASS" if passed else "FAIL", check_name, detail])
	if not passed:
		_failures += 1


## A big floor, and a 40 m wide, 10 m tall wall whose front face is WALL_DISTANCE ahead.
func _build_level() -> void:
	_add_box(Vector3(0, -0.5, 0), Vector3(200, 1, 200))
	_add_box(Vector3(-10, 5, -WALL_DISTANCE - 0.5), Vector3(40, 10, 1))


func _add_box(center: Vector3, size: Vector3) -> void:
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	var body := StaticBody3D.new()
	body.position = center
	body.add_child(collision)
	add_child(body)


func _add_dummy(spot: Vector3) -> TargetDummy:
	var dummy: TargetDummy = DUMMY_SCENE.instantiate()
	dummy.position = spot
	add_child(dummy)
	return dummy
