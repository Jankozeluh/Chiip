extends Node3D
## Automated movement tests for the player. Run without a window:
##
##     Godot --headless --path . --fixed-fps 128 res://tests/movement_test.tscn
##
## Builds a flat floor and a low ceiling, spawns the player, simulates key
## presses and checks the results against CS's movement rules. Prints one line
## per check and quits with the number of failed checks as the exit code
## (0 means everything passed).

const PLAYER_SCENE := preload("res://player/player.tscn")
const U := Player.UNITS_TO_METRES
## CS weapons are accurate below about 34% of top speed; "stopped" means slower than this.
const ACCURATE_SPEED_FACTOR := 0.34
## Where the 1.5 m ceiling is (see _build_level).
const CEILING_SPOT := Vector3(40, 0, 0)
## An open spot next to the ceiling.
const OPEN_SPOT := Vector3(30, 0, 0)

var _player: Player
var _failures: int = 0


func _ready() -> void:
	_build_level()
	_player = PLAYER_SCENE.instantiate()
	add_child(_player)
	await _run_all()
	if _failures == 0:
		print("\nAll checks passed.")
	else:
		print("\n%d check(s) FAILED." % _failures)
	get_tree().quit(_failures)


func _run_all() -> void:
	await _reset()
	_check("Lands on the floor", _player.is_on_floor() and absf(_player.global_position.y) < 0.01,
			"feet at y = %.3f m" % _player.global_position.y)
	await _test_top_speed("Running", [], _player.get_max_speed())
	await _test_top_speed("Walking (Shift)", ["walk"], _player.get_max_speed() * _player.walk_speed_factor)
	await _test_top_speed("Crouching (Ctrl)", ["crouch"], _player.get_max_speed() * _player.crouch_speed_factor)
	await _test_stopping()
	await _test_jump_height()
	await _test_crouch_jump()
	await _test_air_control()
	await _test_bunny_hop_cap()
	await _test_crouch_under_ceiling()


func _test_top_speed(label: String, held_actions: Array[String], expected: float) -> void:
	await _reset()
	for action in held_actions:
		Input.action_press(action)
	Input.action_press("move_forward")
	await _wait_seconds(2.0)
	var speed := _horizontal_speed()
	_check("%s top speed" % label, absf(speed - expected) < 0.01 * expected,
			"%.3f m/s = %.1f u/s (expected %.1f u/s)" % [speed, speed / U, expected / U])


func _test_stopping() -> void:
	var accurate_speed := _player.get_max_speed() * ACCURATE_SPEED_FACTOR

	await _reset()
	Input.action_press("move_right")
	await _wait_seconds(1.5)
	Input.action_release("move_right")
	var release_time := await _seconds_until_slower_than(accurate_speed)

	await _reset()
	Input.action_press("move_right")
	await _wait_seconds(1.5)
	Input.action_release("move_right")
	Input.action_press("move_left")
	var counter_strafe_time := await _seconds_until_slower_than(accurate_speed)

	var detail := "to 34%% speed: counter-strafe %.0f ms, releasing the key %.0f ms" % [
			counter_strafe_time * 1000.0, release_time * 1000.0]
	_check("Counter-strafing stops faster than releasing", counter_strafe_time < release_time, detail)
	_check("Counter-strafe takes under 100 ms", counter_strafe_time < 0.1, detail)


func _test_jump_height() -> void:
	await _reset()
	_press_jump()
	var peak := await _peak_height_of_jump()
	_check("Jump height", absf(peak - _player.jump_height) < 0.02,
			"feet reach %.3f m = %.1f u (expected %.1f u)" % [peak, peak / U, _player.jump_height / U])
	_check("A standing jump can't reach a 64-unit crate", peak < 64.0 * U,
			"%.1f u < 64 u" % (peak / U))


func _test_crouch_jump() -> void:
	await _reset()
	# Jump and crouch on the same tick, like a CS crouch-jump bind.
	Input.action_press("crouch")
	_press_jump()
	var peak := await _peak_height_of_jump()
	_check("Crouch-jump clears a 64-unit crate", peak > 64.0 * U,
			"feet reach %.3f m = %.1f u" % [peak, peak / U])


func _test_air_control() -> void:
	await _reset()
	_press_jump()
	Input.action_press("move_right")
	await _wait_seconds(0.4)
	var speed := _horizontal_speed()
	_check("Air control is limited", speed <= _player.air_speed_cap + 0.01,
			"%.2f m/s sideways after 0.4 s in the air (cap %.2f m/s)" % [speed, _player.air_speed_cap])


func _test_bunny_hop_cap() -> void:
	await _reset()
	_player.velocity = Vector3(10.0, 0.0, 0.0)  # Faster than anyone can run.
	_press_jump()
	await _wait_ticks(2)
	var speed := _horizontal_speed()
	var cap := _player.get_max_speed() * _player.bunny_hop_cap
	_check("Bunny hop speed cap", absf(speed - cap) < 0.01,
			"%.2f m/s after jumping at 10 m/s (cap %.2f m/s)" % [speed, cap])


func _test_crouch_under_ceiling() -> void:
	await _reset(OPEN_SPOT)
	Input.action_press("crouch")
	await _wait_seconds(0.3)
	_teleport(CEILING_SPOT)
	await _wait_ticks(4)
	Input.action_release("crouch")
	await _wait_seconds(0.3)
	_check("Stays crouched under a 1.5 m ceiling", _player.is_crouching, "crouch key released")
	_teleport(OPEN_SPOT)
	await _wait_seconds(0.3)
	_check("Stands up once there's room", not _player.is_crouching, "back in the open")


# --- Helpers ---


## Releases all keys, puts the player at a spot standing still, and waits for them to settle.
func _reset(spot: Vector3 = Vector3.ZERO) -> void:
	for action in ["move_forward", "move_back", "move_left", "move_right", "crouch", "walk"]:
		Input.action_release(action)
	_teleport(spot)
	_player.velocity = Vector3.ZERO
	await _wait_seconds(0.5)


func _teleport(spot: Vector3) -> void:
	_player.global_position = spot
	_player.reset_physics_interpolation()


## Sends a jump press the same way a real key press arrives.
func _press_jump() -> void:
	for pressed in [true, false]:
		var event := InputEventAction.new()
		event.action = "jump"
		event.pressed = pressed
		Input.parse_input_event(event)
	Input.flush_buffered_events()


## Follows a jump that was just started and returns the highest feet position.
func _peak_height_of_jump() -> float:
	await _wait_ticks(2)
	var peak := _player.global_position.y
	while not _player.is_on_floor():
		await get_tree().physics_frame
		peak = maxf(peak, _player.global_position.y)
	return peak


func _seconds_until_slower_than(speed_limit: float) -> float:
	var ticks := 0
	while _horizontal_speed() >= speed_limit and ticks < 1000:
		await get_tree().physics_frame
		ticks += 1
	return ticks / float(Engine.physics_ticks_per_second)


func _horizontal_speed() -> float:
	return Vector2(_player.velocity.x, _player.velocity.z).length()


func _wait_seconds(seconds: float) -> void:
	await _wait_ticks(roundi(seconds * Engine.physics_ticks_per_second))


func _wait_ticks(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _check(check_name: String, passed: bool, detail: String) -> void:
	print("%s  %s: %s" % ["PASS" if passed else "FAIL", check_name, detail])
	if not passed:
		_failures += 1


## Adds the test level: a big floor (top at y = 0) and a block whose underside
## is 1.5 m above the floor at CEILING_SPOT.
func _build_level() -> void:
	_add_box(Vector3(0, -0.5, 0), Vector3(200, 1, 200))
	_add_box(CEILING_SPOT + Vector3(0, 2.25, 0), Vector3(4, 1.5, 4))


func _add_box(center: Vector3, size: Vector3) -> void:
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	var body := StaticBody3D.new()
	body.position = center
	body.add_child(collision)
	add_child(body)
