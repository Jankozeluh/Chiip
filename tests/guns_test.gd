extends Node3D
## Automated checks of how each kind of weapon works (M7 task 6, D-095). Run without a window:
##
##     Godot --headless --path . --fixed-fps 128 --quit-after 60000 res://tests/guns_test.tscn
##
## On a flat floor with a wall and stand-in characters: the semi-automatic pistol (one shot per
## click), the shotgun (nine pellets in their cone, a one-shot kill up close and not far away,
## shell-by-shell reloads that firing interrupts), the reload perk (the Rifleman's 15%), the
## sniper rifle's scope (zoom steps on the aim button, the camera and the mouse following it,
## accuracy only once scoped in and still, the Marksman's faster scope-in and recovery, dropping
## out after a shot and back in when the next is ready, 100 u/s scoped, the HUD's scope view and
## no crosshair), and the knife (flat slash and stab damage on any zone, through armor, harder
## from behind, nothing out of reach). Quits with the number of failed checks as the exit code.

const PLAYER_SCENE := preload("res://player/player.tscn")
const CHARACTER_SCENE := preload("res://characters/character.tscn")
const HUD_SCENE := preload("res://ui/hud.tscn")
const PISTOL := preload("res://weapons/pistol.tres")
const SHOTGUN := preload("res://weapons/shotgun.tres")
const SNIPER := preload("res://weapons/sniper.tres")
const KNIFE := preload("res://weapons/knife.tres")
const RIFLE := preload("res://weapons/rifle.tres")
const SCOUT := preload("res://characters/crew/classes/scout.tres")
const MARKSMAN := preload("res://characters/crew/classes/marksman.tres")
const RIFLEMAN := preload("res://characters/crew/classes/rifleman.tres")
## The wall the pellets are counted on, this far in front of the player.
const WALL_DISTANCE := 12.0

var _failures: int = 0
var _player: Character
var _controller: PlayerController


func _ready() -> void:
	Weapon.silent = true
	_add_box(Vector3(0, -0.5, 0), Vector3(200, 1, 200))
	_add_box(Vector3(30, 5, -WALL_DISTANCE - 0.5), Vector3(20, 10, 1))
	_player = PLAYER_SCENE.instantiate()
	_player.footstep_sound = null
	add_child(_player)
	_controller = _player.get_node("PlayerController") as PlayerController
	await _wait_ticks(2)
	await _run_all()
	if _failures == 0:
		print("\nAll checks passed.")
	else:
		print("\n%d check(s) FAILED." % _failures)
	get_tree().quit(_failures)


func _run_all() -> void:
	await _test_pistol()
	await _test_shotgun()
	await _test_shell_reload()
	await _test_reload_perk()
	await _test_scope()
	await _test_scope_perk()
	await _test_scoped_shot()
	await _test_scope_on_screen()
	await _test_knife()


func _test_pistol() -> void:
	var pistol := _take(PISTOL)
	var shots := _count_shots(pistol)
	_player.aim_at(_player.get_eye_position() + Vector3(0, 0, -10))
	Input.action_press("shoot")
	await _wait_seconds(1.0)
	Input.action_release("shoot")
	var held: int = shots[0]
	for i in 4:
		await _wait_seconds(0.2)
		Input.action_press("shoot")
		await _wait_ticks(2)
		Input.action_release("shoot")
	await _wait_ticks(4)
	_check("The Sparrow fires once per click: holding the trigger for a second fires one shot, four clicks four more",
			held == 1 and shots[0] == 5, "held: %d, after four clicks: %d" % [held, shots[0]])


func _test_shotgun() -> void:
	var shotgun := _take(SHOTGUN)
	shotgun.rng.seed = 11
	var hits: Array[Dictionary] = []
	shotgun.hit_landed.connect(func(hit: Dictionary) -> void: hits.append(hit.duplicate()))
	_player.global_position = Vector3(30, 0, 0)
	await _wait_ticks(2)
	var aim_point := _player.get_eye_position() + Vector3(0, 0, -WALL_DISTANCE)
	_player.aim_at(aim_point)
	await _fire_once()
	var in_cone := hits.all(func(hit: Dictionary) -> bool:
		return rad_to_deg((hit.position - _player.get_eye_position()).angle_to(aim_point - _player.get_eye_position())) <= SHOTGUN.pellet_spread + SHOTGUN.standing_inaccuracy + 0.05)
	_check("A Breaker shot is nine pellets, all inside its %.1f° cone" % SHOTGUN.pellet_spread,
			hits.size() == 9 and in_cone, "%d pellets, in the cone: %s" % [hits.size(), in_cone])
	_player.global_position = Vector3.ZERO
	await _wait_seconds(1.0)
	var near := await _add_target(Vector3(0, 0, -5))
	_player.aim_at(near.get_chest_position())
	await _fire_once()
	var near_dead := not near.is_alive()
	near.queue_free()
	await _wait_seconds(1.0)
	var far := await _add_target(Vector3(0, 0, -25))
	_player.aim_at(far.get_chest_position())
	await _fire_once()
	_check("Up close (5 m) one blast kills; at 25 m the spread and falloff leave the target alive",
			near_dead and far.is_alive(), "5 m dead: %s, 25 m health %.0f" % [near_dead, far.health])
	far.queue_free()
	await _wait_ticks(2)


func _test_shell_reload() -> void:
	var shotgun := _player.weapon
	shotgun.magazine = 3
	shotgun.ammo_changed.emit(3, shotgun.reserve)
	var counts: Array[int] = []
	shotgun.ammo_changed.connect(func(mag: int, _spare: int) -> void: counts.append(mag))
	shotgun.reload()
	var factor := RIFLEMAN.reload_time_factor
	await _wait_seconds((SHOTGUN.reload_start_time + SHOTGUN.reload_time * 2.0) * factor + 0.02)
	var two_in := shotgun.magazine == 5 and shotgun.is_reloading()
	var shots := _count_shots(shotgun)
	Input.action_press("shoot")
	await _wait_ticks(3)
	Input.action_release("shoot")
	await _wait_ticks(3)
	_check("The Breaker loads one shell at a time (3, 4, 5...) and firing stops the reload once a shell is in",
			two_in and counts.slice(0, 2) == [4, 5] and shots[0] == 1 and not shotgun.is_reloading() and shotgun.magazine == 4,
			"after two shells: %s, magazine counts %s, shot %d, magazine %d" % [two_in, counts, shots[0], shotgun.magazine])
	await _wait_seconds(1.0)


func _test_reload_perk() -> void:
	_player.class_data = SCOUT
	var scout_rifle := _take(RIFLE)
	var scout_time := scout_rifle.get_reload_time()
	_player.class_data = RIFLEMAN
	var rifle := _player.weapon
	rifle.magazine = 10
	rifle.reload()
	await _wait_seconds(RIFLE.reload_time * 0.85 + 0.02)
	_check("The Rifleman's Quick Hands reloads the Ram in %.3f s instead of %.1f s" % [RIFLE.reload_time * 0.85, scout_time],
			not rifle.is_reloading() and rifle.magazine == 30 and is_equal_approx(scout_time, RIFLE.reload_time),
			"reloading after %.3f s: %s" % [RIFLE.reload_time * 0.85, rifle.is_reloading()])


func _test_scope() -> void:
	_player.class_data = SCOUT
	var sniper := _take(SNIPER)
	_player.global_position = Vector3.ZERO
	await _wait_seconds(0.3)
	var unscoped := sniper.get_inaccuracy()
	var normal_fov := _player.get_camera().fov
	var yaw_unscoped := _turn_for(100)
	await _press_aim()
	var level_one := sniper.zoom_level
	var just_in := sniper.get_inaccuracy()
	await _wait_ticks(2)
	var fov_one := _player.get_camera().fov
	var yaw_one := _turn_for(100)
	await _wait_seconds(SNIPER.scope_in_time + 0.02)
	var settled := sniper.get_inaccuracy()
	await _press_aim()
	var level_two := sniper.zoom_level
	await _wait_ticks(2)
	var fov_two := _player.get_camera().fov
	await _press_aim()
	var back := sniper.zoom_level
	_check("The aim button steps the Heron's scope: 1, 2, then out; each step narrows the camera",
			level_one == 1 and level_two == 2 and back == 0 and fov_one < normal_fov and fov_two < fov_one,
			"fov %.1f → %.1f → %.1f" % [normal_fov, fov_one, fov_two])
	var expected_ratio := tan(deg_to_rad(Settings.vertical_fov(90.0 * SNIPER.zoom_levels[0])) / 2.0) / tan(deg_to_rad(Settings.vertical_fov(90.0)) / 2.0)
	_check("Scoped, the same mouse movement turns the view less, in step with the zoom",
			absf(yaw_one / yaw_unscoped - expected_ratio) < 0.001, "ratio %.3f (expected %.3f)" % [yaw_one / yaw_unscoped, expected_ratio])
	_check("It's accurate only scoped in: %.1f° unscoped, %.2f° on zooming, %.3f° after the scope-in time" % [unscoped, just_in, settled],
			unscoped >= 4.0 and just_in > 1.0 and settled < 0.03, "")
	await _scope_to(1)
	await _wait_seconds(SNIPER.scope_in_time + 0.02)
	_check("Scoped it moves at 100 u/s (200 unscoped)", is_equal_approx(_player.get_max_speed(), 100.0 * Character.UNITS_TO_METRES),
			"%.0f u/s" % (_player.get_max_speed() / Character.UNITS_TO_METRES))
	# Run, stop, and see the accuracy come back only over the recovery time.
	Input.action_press("move_right")
	await _wait_seconds(0.6)
	Input.action_release("move_right")
	await _wait_until_still()
	var right_after := sniper.get_inaccuracy()
	await _wait_seconds(SNIPER.scoped_recovery_time + 0.05)
	var recovered := sniper.get_inaccuracy()
	_check("After moving, scoped accuracy takes its recovery time to come back (%.2f° on stopping, %.3f° later)" % [right_after, recovered],
			right_after > 0.5 and recovered < 0.03, "")


func _test_scope_perk() -> void:
	var sniper := _player.weapon
	_player.class_data = SCOUT
	var scout := await _scope_timings(sniper)
	_player.class_data = MARKSMAN
	var marksman := await _scope_timings(sniper)
	_check("The Marksman's Steady: scoped accuracy recovers 30%% faster (%.3f s vs %.3f s) and scoping in takes 20%% less (%.3f s vs %.3f s)" % [
			marksman.y, scout.y, marksman.x, scout.x],
			absf(marksman.y - scout.y / 1.3) < 0.02 and absf(marksman.x - scout.x * 0.8) < 0.02
					and absf(scout.x - SNIPER.scope_in_time) < 0.02 and absf(scout.y - SNIPER.scoped_recovery_time) < 0.02, "")
	_player.class_data = SCOUT


## Seconds to scope in (x: from the zoom step until fully accurate) and to recover from a full
## running penalty while scoped and still (y), for the player's current class.
func _scope_timings(sniper: Weapon) -> Vector2:
	await _scope_to(0)
	await _wait_ticks(4)
	var target := SNIPER.scoped_inaccuracy + 0.001
	var ticks := 0
	Input.action_press("aim")
	await _wait_ticks(1)
	while sniper.get_inaccuracy() > target and ticks < 256:
		await _wait_ticks(1)
		ticks += 1
	Input.action_release("aim")
	var scope_in := float(ticks) / Engine.physics_ticks_per_second
	# As if it had just stopped from a full run: the whole moving penalty, wearing off.
	sniper.set("_move_memory", SNIPER.moving_inaccuracy)
	ticks = 0
	while sniper.get_inaccuracy() > target and ticks < 256:
		await _wait_ticks(1)
		ticks += 1
	return Vector2(scope_in, float(ticks) / Engine.physics_ticks_per_second)


func _test_scoped_shot() -> void:
	var sniper := _player.weapon
	await _scope_to(1)
	await _wait_seconds(0.5)
	var level := sniper.zoom_level
	await _fire_once()
	var out := sniper.zoom_level == 0
	await _wait_seconds(SNIPER.get_shot_interval() + 0.05)
	_check("A scoped shot drops out of the scope, and it comes back once the bolt is worked",
			level == 1 and out and sniper.zoom_level == 1, "before %d, right after out: %s, later %d" % [level, out, sniper.zoom_level])


func _test_scope_on_screen() -> void:
	var hud := HUD_SCENE.instantiate()
	add_child(hud)
	hud.set_player(_player)
	await _wait_ticks(2)
	var overlay := hud.get_node("ScopeOverlay") as Control
	var crosshair := hud.get_node("Crosshair") as Control
	var scoped_view := overlay.visible and not crosshair.visible
	await _scope_to(0)
	await _wait_ticks(2)
	var unscoped_view := not overlay.visible and not crosshair.visible
	var pistol := _player.inventory.get_in_slot(WeaponData.Slot.PISTOL)
	_player.inventory.hold(pistol, true)
	await _wait_ticks(2)
	_check("The HUD shows the scope's view while scoped, and no crosshair with the Heron in hand; the pistol has one",
			scoped_view and unscoped_view and crosshair.visible and not overlay.visible and overlay.mouse_filter == Control.MOUSE_FILTER_IGNORE,
			"scoped %s, unscoped %s" % [scoped_view, unscoped_view])
	hud.queue_free()
	await _wait_ticks(2)


func _test_knife() -> void:
	_player.class_data = RIFLEMAN
	var knife := _take(KNIFE)
	_player.global_position = Vector3.ZERO
	await _wait_seconds(0.6)
	var facing_you := await _add_target(Vector3(0, 0, -1.0), PI)
	_player.aim_at(facing_you.get_chest_position())
	await _attack("shoot")
	var slash := 100.0 - facing_you.health
	await _wait_seconds(0.5)
	_player.aim_at(facing_you.get_head_position())
	await _attack("shoot")
	var head_slash := 100.0 - slash - facing_you.health
	facing_you.queue_free()
	var armored := await _add_target(Vector3(0, 0, -1.0), PI)
	armored.set_armor(100.0, true)
	await _wait_seconds(0.5)
	_player.aim_at(armored.get_chest_position())
	await _attack("aim")
	var stab := 100.0 - armored.health
	armored.queue_free()
	_check("The knife slashes for 40 on any zone (the head too) and stabs for 65, 85% of it through armor",
			absf(slash - 40.0) < 0.01 and absf(head_slash - 40.0) < 0.01 and absf(stab - 65.0 * 0.85) < 0.01,
			"slash %.1f, on the head %.1f, stab through armor %.2f" % [slash, head_slash, stab])
	var back_turned := await _add_target(Vector3(0, 0, -1.0), 0.0)
	await _wait_seconds(1.0)
	_player.aim_at(back_turned.get_chest_position())
	await _attack("shoot")
	var backstab: float = 100.0 - back_turned.health
	back_turned.queue_free()
	var stabbed := await _add_target(Vector3(0, 0, -1.0), 0.0)
	await _wait_seconds(1.0)
	_player.aim_at(stabbed.get_chest_position())
	await _attack("aim")
	_check("From behind a slash does 90 and a stab kills (180)", absf(backstab - 90.0) < 0.01 and not stabbed.is_alive(),
			"slash %.1f, stab left %.1f" % [backstab, stabbed.health])
	stabbed.queue_free()
	var out_of_reach := await _add_target(Vector3(0, 0, -2.3), PI)
	await _wait_seconds(1.0)
	_player.aim_at(out_of_reach.get_chest_position())
	var swings := _count_shots(knife)
	await _attack("shoot")
	_check("A knife swings at nothing beyond its reach (1.5 m)", out_of_reach.health == 100.0 and swings[0] == 1,
			"health %.1f, swings %d" % [out_of_reach.health, swings[0]])
	out_of_reach.queue_free()
	await _wait_ticks(2)
	# Frozen (freeze time, a match end): the knife's stab and a lobbed grenade stay put too.
	var frozen_target := await _add_target(Vector3(0, 0, -1.0), PI)
	await _wait_seconds(1.0)
	_player.aim_at(frozen_target.get_chest_position())
	_player.frozen = true
	var stabs := _count_shots(knife)
	await _attack("aim")
	var frag := _take(load("res://weapons/frag.tres"))
	await _wait_seconds(0.8)
	Input.action_press("aim")
	await _wait_seconds(0.6)
	var priming := frag.is_priming()
	Input.action_release("aim")
	await _wait_seconds(0.6)
	_player.frozen = false
	_check("A frozen player can't stab or lob a grenade (aim does nothing but zoom a scope)",
			stabs[0] == 0 and frozen_target.health == 100.0 and not priming and is_instance_valid(frag) and frag.magazine == 1,
			"stabs %d, health %.1f, priming %s" % [stabs[0], frozen_target.health, priming])
	frozen_target.queue_free()
	await _wait_ticks(2)


# --- Helpers ---


## Gives the player [param data] (dropping what's in that slot) and takes it out at once.
func _take(data: WeaponData) -> Weapon:
	var old := _player.inventory.get_in_slot(data.slot)
	if old != null:
		_player.inventory.remove(old)
	var weapon := _player.inventory.give(data)
	_player.inventory.hold(weapon, true)
	return weapon


## A counter of [param weapon]'s shots (an Array, so lambdas can change it).
func _count_shots(weapon: Weapon) -> Array:
	var shots := [0]
	weapon.fired.connect(func(_n: int) -> void: shots[0] += 1)
	return shots


func _fire_once() -> void:
	Input.action_press("shoot")
	await _wait_ticks(2)
	Input.action_release("shoot")
	await _wait_ticks(4)


## One knife attack with [param action] ("shoot" slashes, "aim" stabs).
func _attack(action: String) -> void:
	Input.action_press(action)
	await _wait_ticks(2)
	Input.action_release(action)
	await _wait_ticks(4)


## A fresh press of the aim button (the scope's next step).
func _press_aim() -> void:
	Input.action_press("aim")
	await _wait_ticks(2)
	Input.action_release("aim")
	await _wait_ticks(2)


## How far the view turns for [param counts] mouse counts sideways, in radians (the view is
## turned back afterwards).
func _turn_for(counts: int) -> float:
	var before: float = _controller.get("_yaw")
	_controller._look(Vector2(counts, 0))
	var after: float = _controller.get("_yaw")
	_controller._look(Vector2(-counts, 0))
	return absf(after - before)


## Presses the aim button until the scope is at zoom step [param level].
func _scope_to(level: int) -> void:
	var presses := 0
	while _player.weapon.zoom_level != level and presses < 4:
		await _press_aim()
		presses += 1


## Waits until the player has slowed below the accurate speed (34% of top speed).
func _wait_until_still() -> void:
	var ticks := 0
	while Vector2(_player.velocity.x, _player.velocity.z).length() > 0.05 and ticks < 256:
		await _wait_ticks(1)
		ticks += 1


## A character without a controller (it stands still) on team 1 at [param at], facing [param yaw].
func _add_target(at: Vector3, yaw: float = 0.0) -> Character:
	var target := CHARACTER_SCENE.instantiate() as Character
	target.team = 1
	target.position = at
	target.rotation.y = yaw
	target.footstep_sound = null
	add_child(target)
	await _wait_ticks(3)
	return target


func _add_box(center: Vector3, size: Vector3) -> void:
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	var body := StaticBody3D.new()
	body.position = center
	body.add_child(collision)
	add_child(body)


func _wait_seconds(seconds: float) -> void:
	await _wait_ticks(ceili(seconds * Engine.physics_ticks_per_second) + 1)


func _wait_ticks(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _check(check_name: String, passed: bool, detail: String) -> void:
	print("%s  %s: %s" % ["PASS" if passed else "FAIL", check_name, detail])
	if not passed:
		_failures += 1
