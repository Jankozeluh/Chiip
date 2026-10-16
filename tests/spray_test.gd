extends Node
## Automated checks for spray practice (M14, D-208, D-209). Run without a window:
##
##     Godot --headless --path . --fixed-fps 128 --quit-after 100000 res://tests/spray_test.tscn
##
## The maths of [SprayChart] against numbers worked out by hand (the ghost of a pattern on a wall at
## a distance, the drift, the control, the gaps of shots that missed the wall). Then, on the Shooting
## Range through the real game scene, with real shots from 6 m: the wall's frame (normal, right,
## which points are on it); the pattern hangs on its middle before you shoot; a spray held still
## puts its holes where the ghost says (within 2 cm) and has about no control; a spray that pulls
## against the recoil keeps its holes around the first one and has a high control; a finished spray of
## 10 shots or more with some control is saved as a personal best, and a worse one doesn't replace
## it; a short spray saves nothing; shooting the reset plate (or the console's `spray_reset`) clears the wall
## without leaving a hole; a shotgun has no pattern to draw. The wall saves into a book of its own,
## never your stats file (the last check). Quits with the number of failed checks as the exit code.

const MAIN_SCENE := preload("res://main.tscn")
## Where the player stands: in the spray wall's lane, 6 m from it.
const STAND := Vector3(-12.0, 0.0, -4.0)

var _failures: int = 0
var _real_file_md5: String = ""
var _main: Node
var _player: Character
var _wall: RangeSprayWall
var _book := StatsBook.new()
var _saved: Array = []


func _ready() -> void:
	_real_file_md5 = _real_md5()
	Weapon.silent = true
	_test_chart()
	await _start_range()
	if _wall != null:
		await _test_wall_frame()
		await _test_hold_still()
		await _test_pull_down()
		await _test_bests_and_short_sprays()
		await _test_reset()
		await _test_shotgun()
	_free_main()
	_check("The tests never touched your real stats file or the shared book", _real_md5() == _real_file_md5 and not StatsBook.get_instance().is_loaded(),
			"checksum '%s'" % _real_md5())
	Weapon.silent = false
	if _failures == 0:
		print("\nAll checks passed.")
	else:
		print("\n%d check(s) FAILED." % _failures)
	get_tree().quit(_failures)


# --- The maths ---


func _test_chart() -> void:
	var pattern := PackedVector2Array([Vector2(0.5, 1.0), Vector2(1.5, 3.0), Vector2(-0.5, 6.0)])
	var ghost := SprayChart.ghost(pattern, 10.0, 4)
	_check("The ghost is the pattern from the first shot, as the angle times the distance: (0, 0), then 1 degree right and 2 up at 10 m, and a long spray repeats the last entry",
			ghost.size() == 4 and ghost[0] == Vector2.ZERO and ghost[1].is_equal_approx(Vector2(10.0 * tan(deg_to_rad(1.0)), 10.0 * tan(deg_to_rad(2.0))))
			and ghost[2].is_equal_approx(Vector2(10.0 * tan(deg_to_rad(-1.0)), 10.0 * tan(deg_to_rad(5.0)))) and ghost[3] == ghost[2],
			"%s" % [ghost])
	_check("A gun without a pattern has no ghost", SprayChart.ghost(PackedVector2Array(), 10.0, 5).is_empty(), "")
	var points: Array = [Vector2.ZERO, Vector2(0.3, 0.4), Vector2(0.0, 1.0)]
	_check("Drift is the average distance from the first point over the others: (0.5 + 1.0) / 2 = 0.75; points that missed the wall are skipped; fewer than two points have none",
			is_equal_approx(SprayChart.drift(points), 0.75) and is_equal_approx(SprayChart.drift([Vector2.ZERO, null, Vector2(0.0, 1.0)]), 1.0)
			and SprayChart.drift([Vector2.ZERO]) == 0.0 and SprayChart.drift([]) == 0.0 and SprayChart.drift([null, Vector2.ONE]) == 0.0, "")
	_check("Control is 100 for no drift, 0 for as much drift as the pattern (or more), 50 for half, and 0 where the pattern has none",
			SprayChart.control(0.0, 0.5) == 100.0 and SprayChart.control(0.5, 0.5) == 0.0 and SprayChart.control(1.0, 0.5) == 0.0
			and is_equal_approx(SprayChart.control(0.25, 0.5), 50.0) and SprayChart.control(0.1, 0.0) == 0.0, "")
	var ghost_points := SprayChart.ghost(pattern, 10.0, 3)
	var holes: Array = [Vector2(1.0, 1.0), null, Vector2(1.0, 2.0)]
	_check("A spray that missed the wall once is compared with the ghost over the shots that landed: one hole 1 m from the first against the pattern's third shot",
			is_equal_approx(SprayChart.spray_control(holes, ghost_points), SprayChart.control(1.0, ghost_points[2].length())), "%.1f" % SprayChart.spray_control(holes, ghost_points))


# --- The range ---


func _start_range() -> void:
	_free_main()
	_main = MAIN_SCENE.instantiate()
	_main.set("load_settings", false)
	_main.set("loading_screen", false)
	_main.set("mode", 1)
	_main.set("map_scene", load(Settings.DEFAULT_MAP))
	add_child(_main)
	# These checks are about the props themselves: their in-world readouts and a shot at the pad starting a run at once
	# (the game's 2D training screens have their own checks in ui_test and layout_test, D-236).
	TrainingHub.hud_active = false
	TrainingHub.menu = null
	await _wait_ticks(8)
	(_main.get_node("ClassMenu") as ClassMenu).close()
	_player = _main.call("get_player") as Character
	var walls: Array = (_main.call("get_map") as Node).find_children("*", "RangeSprayWall", true, false)
	_check("The Shooting Range has one spray wall", walls.size() == 1, "%d" % walls.size())
	if walls.is_empty():
		return
	_wall = walls[0]
	_wall.book = _book
	_wall.best_saved.connect(func(weapon_id: StringName, control: float) -> void: _saved.append([weapon_id, control]))
	_give_rifle(true)
	_player.respawn(STAND, 0.0)
	await _wait_seconds(0.6)
	_player.aim_at(_wall.global_position)
	await _wait_seconds(0.6)


## A rifle in hand; with [param perfect] its random spread is switched off (the pattern stays).
func _give_rifle(perfect: bool) -> void:
	var rifle := WeaponData.find(&"rifle")
	var loadout: Array[WeaponData] = [rifle]
	_player.inventory.set_loadout(loadout)
	var weapon := _player.inventory.find(rifle)
	if perfect:
		var data := rifle.duplicate() as WeaponData
		data.standing_inaccuracy = 0.0
		data.spray_inaccuracy_per_shot = 0.0
		data.max_spray_inaccuracy = 0.0
		weapon.data = data
	_player.inventory.hold(weapon, true)


func _test_wall_frame() -> void:
	_check("The wall faces the shooters (toward +Z here), is 3.2 m wide and 3 m tall, at about (-12, 1.5, -10)",
			_wall.get_normal().is_equal_approx(Vector3(0, 0, 1)) and _wall.get_right().is_equal_approx(Vector3(1, 0, 0)) and _wall.width == 3.2 and _wall.height == 3.0
			and _wall.global_position.distance_to(Vector3(-12.0, 1.5, -10.0)) < 0.1, "normal %s, at %s" % [_wall.get_normal(), _wall.global_position])
	var middle: Variant = _wall.wall_point(_wall.global_position)
	var right_up: Variant = _wall.wall_point(_wall.global_position + Vector3(1.0, 0.5, 0.0))
	_check("A point of the wall is (right, up) from its middle: the middle is (0, 0), 1 m to the right and 0.5 up is (1, 0.5); a point outside the edge, or 2 m in front of the wall, is not on it",
			middle != null and (middle as Vector2).is_equal_approx(Vector2.ZERO) and right_up != null and (right_up as Vector2).is_equal_approx(Vector2(1.0, 0.5))
			and _wall.wall_point(_wall.global_position + Vector3(1.7, 0.0, 0.0)) == null and _wall.wall_point(_wall.global_position + Vector3(0.0, 0.0, 2.0)) == null, "")
	var ghost := _wall.get_ghost()
	var pattern := WeaponData.find(&"rifle").spray_pattern
	_check("Before a spray the gun's whole pattern hangs on the wall's middle, sized for the distance (6 m), and the sign says to spray at the middle",
			not _wall.is_spray_active() and ghost.size() == pattern.size() and ghost[0].is_equal_approx(Vector2.ZERO)
			and absf(_wall.get_distance() - _player.get_eye_position().distance_to(_wall.global_position)) < 0.2
			and _wall.get_sign_text().contains("RAM") and _wall.get_sign_text().contains("SPRAY AT THE MIDDLE"),
			"%d points, %.1f m, '%s'" % [ghost.size(), _wall.get_distance(), _wall.get_sign_text().replace("\n", " | ")])


func _test_hold_still() -> void:
	await _spray(12)
	var holes := _wall.get_holes()
	var ghost := _wall.get_ghost()
	var worst := 0.0
	for index in mini(holes.size(), ghost.size()):
		if holes[index] == null:
			worst = INF
			break
		worst = maxf(worst, (holes[index] as Vector2).distance_to(ghost[index]))
	_check("A spray held still leaves 12 holes exactly where the ghost says (within 2 cm), and the ghost sits on the first hole",
			holes.size() == 12 and worst < 0.02 and _wall.is_spray_active() and _wall.get_ghost()[0].is_equal_approx(holes[0]) and _wall.get_mark_count() == 12,
			"%d holes, worst %.3f m, %d marks" % [holes.size(), worst, _wall.get_mark_count()])
	_check("Holding still gives about no control (below 5 %), and the sign shows the drift against the pattern's",
			_wall.get_control() >= 0.0 and _wall.get_control() < 5.0 and _wall.get_sign_text().contains("CONTROL") and _wall.get_sign_text().contains("12 SHOTS"),
			"control %.1f, '%s'" % [_wall.get_control(), _wall.get_sign_text().replace("\n", " | ")])
	await _wait_seconds(1.2)
	_check("The spray ends a moment after the last shot; a spray with no control saves no best", not _wall.is_spray_active() and _saved.is_empty()
			and _book.get_best_score(RangeSprayWall.best_key(&"rifle")) == 0.0, "saved %d" % _saved.size())


func _test_pull_down() -> void:
	await _spray(14, true)
	var holes := _wall.get_holes()
	var first: Vector2 = holes[0] if not holes.is_empty() and holes[0] != null else Vector2.ZERO
	var farthest := 0.0
	for hole in holes:
		farthest = maxf(farthest, first.distance_to(hole as Vector2) if hole != null else INF)
	_check("A spray that pulls against the recoil keeps all 14 holes within 12 cm of the first one, and its control is high (above 80 %)",
			holes.size() == 14 and farthest < 0.12 and _wall.get_control() > 80.0, "%d holes, farthest %.3f m, control %.1f" % [holes.size(), farthest, _wall.get_control()])
	var live_control := _wall.get_control()
	await _wait_seconds(1.2)
	var key := RangeSprayWall.best_key(&"rifle")
	_check("Finished, that spray is the new best control for the gun, saved with its shots and drifts",
			_saved.size() == 1 and _saved[0][0] == &"rifle" and is_equal_approx(_book.get_best_score(key), snappedf(live_control, 0.1))
			and int(_book.get_best(key)["shots"]) == 14 and _book.get_best(key).has("drift_cm") and _book.get_best(key).has("pattern_cm"),
			"best %.1f, saved %s" % [_book.get_best_score(key), _saved])
	_check("The earlier spray's holes stay as dim ones: 12 + 14 holes on the wall", _wall.get_mark_count() == 26, "%d marks" % _wall.get_mark_count())


func _test_bests_and_short_sprays() -> void:
	var key := RangeSprayWall.best_key(&"rifle")
	var best := _book.get_best_score(key)
	var saved_before := _saved.size()
	# Holding still again: no control, nothing replaces the best.
	await _spray(12)
	await _wait_seconds(1.2)
	_check("A worse spray doesn't replace the best", _saved.size() == saved_before and is_equal_approx(_book.get_best_score(key), best), "best %.1f" % _book.get_best_score(key))
	# Five shots pulled down well are too few to count.
	await _spray(5, true)
	await _wait_seconds(1.2)
	_check("A spray of fewer than 10 shots saves nothing (and shows no control)", _saved.size() == saved_before and _wall.get_control() < 0.0, "%d saved" % _saved.size())


func _test_reset() -> void:
	_check("There are holes on the wall to clear", _wall.get_mark_count() > 0, "%d" % _wall.get_mark_count())
	var plate := _wall.local_to_world(Vector2(_wall.width * 0.5 - 0.1 - 0.35, _wall.height * 0.5 - 0.1 - 0.2))
	await _tap_at(plate)
	_check("Shooting the reset plate clears the wall: no marks, no spray, the ghost back on the middle, and no hole for that shot",
			_wall.get_mark_count() == 0 and not _wall.is_spray_active() and _wall.get_holes().is_empty() and _wall.get_ghost()[0].is_equal_approx(Vector2.ZERO),
			"%d marks" % _wall.get_mark_count())
	await _spray(4)
	var after_spray := _wall.get_mark_count()
	var console := _main.get_node("DevConsole") as DevConsole
	console.run("spray_reset")
	_check("The console's `spray_reset` clears it too", after_spray == 4 and _wall.get_mark_count() == 0, "%d marks before, %d after" % [after_spray, _wall.get_mark_count()])
	await _wait_seconds(1.0)


func _test_shotgun() -> void:
	var shotgun := WeaponData.find(&"shotgun")
	var loadout: Array[WeaponData] = [shotgun]
	_player.inventory.set_loadout(loadout)
	_player.inventory.hold(_player.inventory.find(shotgun), true)
	await _wait_seconds(1.0)
	_player.aim_at(_wall.global_position)
	await _tap_at(_wall.global_position)
	_check("A shotgun has no pattern to draw: no ghost, no holes, and the sign says one bullet at a time",
			_wall.get_ghost().is_empty() and _wall.get_mark_count() == 0 and _wall.get_sign_text().contains("ONE BULLET AT A TIME"),
			"'%s'" % _wall.get_sign_text().replace("\n", " | "))


# --- Helpers ---


## Fires [param count] shots by holding the trigger from where the first one is aimed at the wall's
## middle. With [param pull], after each shot the aim is moved to where the next shot's recoil is
## cancelled (a perfect pull against the pattern).
func _spray(count: int, pull: bool = false) -> void:
	await _wait_seconds(1.0)
	_give_rifle(true)
	await _wait_seconds(0.5)
	_player.aim_at(_wall.global_position)
	var shots := [0]
	var weapon := _player.weapon
	var on_fired := func(_number: int) -> void:
		shots[0] += 1
		if pull and shots[0] < count:
			var holes := _wall.get_holes()
			var ghost := _wall.get_ghost()
			if not holes.is_empty() and holes[0] != null and shots[0] < ghost.size():
				var first: Vector2 = holes[0]
				_player.aim_at(_wall.local_to_world(first * 2.0 - ghost[shots[0]]))
		if shots[0] >= count:
			Input.action_release("shoot")
	weapon.fired.connect(on_fired)
	Input.action_press("shoot")
	await _wait_until(func() -> bool: return shots[0] >= count, 4.0)
	Input.action_release("shoot")
	weapon.fired.disconnect(on_fired)
	await _wait_ticks(2)


func _free_main() -> void:
	if _main != null:
		remove_child(_main)
		_main.queue_free()
		_main = null
	Input.action_release("shoot")
	MenuState.reset()


func _tap_at(point: Vector3) -> void:
	_player.aim_at(point)
	Input.action_press("shoot")
	await _wait_ticks(2)
	Input.action_release("shoot")
	await _wait_seconds(0.2)


func _wait_until(condition: Callable, seconds: float) -> bool:
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
