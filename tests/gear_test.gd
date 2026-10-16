extends Node3D
## Automated checks of a character's gear (M7): armor and helmet (D-093). Run without a window:
##
##     Godot --headless --path . --fixed-fps 128 --quit-after 60000 res://tests/gear_test.tscn
##
## Armor on real characters: what a hit through the hit zones does to health and armor with
## and without a helmet, legs never covered, armor giving out, the Bulwark's Plated perk, the
## bomb's damage ignoring armor, death taking the gear away, a real bullet passing its weapon on,
## the HUD's armor number and shield, and the console's armor command in the real game scene.
## Quits with the number of failed checks as the exit code (0 means everything passed).

const PLAYER_SCENE := preload("res://player/player.tscn")
const CHARACTER_SCENE := preload("res://characters/character.tscn")
const HUD_SCENE := preload("res://ui/hud.tscn")
const MAIN_SCENE := preload("res://main.tscn")
const RIFLE := preload("res://weapons/rifle.tres")
const CARBINE := preload("res://weapons/carbine.tres")
const BULWARK := preload("res://characters/crew/classes/bulwark.tres")

var _failures: int = 0
var _player: Character


func _ready() -> void:
	_add_box(Vector3(0, -0.5, 0), Vector3(100, 1, 100))
	_player = PLAYER_SCENE.instantiate()
	_silence(_player)
	add_child(_player)
	await _wait_ticks(2)
	await _run_all()
	if _failures == 0:
		print("\nAll checks passed.")
	else:
		print("\n%d check(s) FAILED." % _failures)
	get_tree().quit(_failures)


func _run_all() -> void:
	await _test_armor_on_hits()
	await _test_bulwark_and_bomb()
	await _test_death_takes_gear()
	await _test_real_bullet()
	await _test_hud()
	await _test_console()


# --- Armor (D-093) ---


func _test_armor_on_hits() -> void:
	var target := await _add_target(Vector3(3, 0, -4))
	target.set_armor(100.0, false)
	_zone_box(target, Hitbox.Zone.CHEST).receive_hit(36.0, Vector3.ZERO, _player, RIFLE)
	_check("A rifle hit on an armored chest: 77.5% of it reaches health and the armor loses half of the rest",
			_near(target.health, 100.0 - 27.9) and _near(target.armor, 100.0 - 4.05),
			"health %.2f, armor %.2f" % [target.health, target.armor])
	var legs_before := target.armor
	_zone_box(target, Hitbox.Zone.LEGS).receive_hit(36.0, Vector3.ZERO, _player, RIFLE)
	_check("Legs are never covered: the full 27 gets through and the armor is untouched",
			_near(target.health, 100.0 - 27.9 - 27.0) and _near(target.armor, legs_before),
			"health %.2f, armor %.2f" % [target.health, target.armor])
	target.queue_free()

	var no_helmet := await _add_target(Vector3(-3, 0, -4))
	no_helmet.set_armor(100.0, false)
	_zone_box(no_helmet, Hitbox.Zone.HEAD).receive_hit(33.0, Vector3.ZERO, _player, CARBINE)
	_check("Without a helmet a carbine headshot (132) kills through a vest", not no_helmet.is_alive(),
			"health %.2f" % no_helmet.health)
	no_helmet.queue_free()

	var helmet := await _add_target(Vector3(-3, 0, -6))
	helmet.set_armor(100.0, true)
	_zone_box(helmet, Hitbox.Zone.HEAD).receive_hit(33.0, Vector3.ZERO, _player, CARBINE)
	var carbine_ok := helmet.is_alive() and _near(helmet.health, 100.0 - 92.4)
	var helmet_health := helmet.health
	_zone_box(helmet, Hitbox.Zone.HEAD).receive_hit(36.0, Vector3.ZERO, _player, RIFLE)
	_check("A helmet saves you from a carbine headshot (92.4), not from a rifle one (111.6)",
			carbine_ok and not helmet.is_alive(), "after the carbine %.2f, alive after the rifle: %s" % [helmet_health, helmet.is_alive()])
	helmet.queue_free()

	var thin := await _add_target(Vector3(0, 0, -8))
	thin.set_armor(10.0, true)
	thin.take_damage(100.0, Hitbox.Zone.CHEST, _player, 0.5)
	_check("Worn-out armor stops only what its last points can (2 damage a point) and the helmet goes with it",
			_near(thin.health, 20.0) and thin.armor == 0.0 and not thin.has_helmet,
			"health %.2f, armor %.2f, helmet %s" % [thin.health, thin.armor, thin.has_helmet])
	thin.queue_free()
	await _wait_ticks(2)


func _test_bulwark_and_bomb() -> void:
	var bulwark := await _add_target(Vector3(3, 0, -6), BULWARK)
	bulwark.set_armor(100.0, false)
	_zone_box(bulwark, Hitbox.Zone.CHEST).receive_hit(36.0, Vector3.ZERO, _player, RIFLE)
	_check("The Bulwark's Plated: 10% less to health and 30% less wear while armored",
			_near(bulwark.health, 100.0 - 27.9 * 0.9) and _near(bulwark.armor, 100.0 - 4.05 * 0.7),
			"health %.2f, armor %.2f" % [bulwark.health, bulwark.armor])
	bulwark.set_armor(0.0, false)
	var before := bulwark.health
	bulwark.take_damage(20.0, Hitbox.Zone.CHEST, _player, 0.775)
	_check("...and nothing without armor", _near(bulwark.health, before - 20.0), "lost %.2f" % (before - bulwark.health))
	bulwark.queue_free()

	var target := await _add_target(Vector3(0, 0, -10))
	target.set_armor(100.0, true)
	target.take_damage(60.0, Hitbox.Zone.CHEST, null)
	_check("The bomb's blast (penetration 1.0) goes through armor and doesn't wear it",
			_near(target.health, 40.0) and _near(target.armor, 100.0), "health %.2f, armor %.2f" % [target.health, target.armor])
	target.queue_free()
	await _wait_ticks(2)


func _test_death_takes_gear() -> void:
	var target := await _add_target(Vector3(2, 0, -10))
	target.set_armor(80.0, true)
	target.set_defuse_kit(true)
	var signals := [0]
	target.gear_changed.connect(func() -> void: signals[0] += 1)
	target.take_damage(500.0, Hitbox.Zone.LEGS, _player)
	_check("Dying loses the armor, the helmet and the kit, and says so",
			target.armor == 0.0 and not target.has_helmet and not target.has_defuse_kit and signals[0] >= 1,
			"armor %.1f, helmet %s, kit %s, %d signal(s)" % [target.armor, target.has_helmet, target.has_defuse_kit, signals[0]])
	target.queue_free()
	await _wait_ticks(2)


func _test_real_bullet() -> void:
	var target := await _add_target(Vector3(0, 0, -5))
	target.set_armor(100.0, false)
	_player.global_position = Vector3.ZERO
	await _wait_ticks(2)
	_player.aim_at(target.get_chest_position())
	_player.weapon.rng.seed = 7
	Input.action_press("shoot")
	await _wait_ticks(2)
	Input.action_release("shoot")
	await _wait_ticks(20)
	var hit_zone: String = _player.weapon.last_hit.get("zone", "")
	_check("A real bullet hands its weapon on: the victim knows what hit it, and its armor took a share",
			target.last_damage_source != null and target.last_damage_source.id == &"rifle" and target.armor < 100.0 and target.health < 100.0,
			"zone %s, source %s, health %.2f, armor %.2f" % [hit_zone, target.last_damage_source.id if target.last_damage_source else &"none", target.health, target.armor])
	target.queue_free()
	await _wait_ticks(2)


func _test_hud() -> void:
	var hud := HUD_SCENE.instantiate()
	add_child(hud)
	hud.set_player(_player)
	var label := hud.get_node("ArmorLabel") as Label
	var icon := hud.get_node("ArmorIcon") as ArmorIcon
	_player.set_armor(0.0, false)
	var empty := label.text == "0" and icon.points == 0.0 and not icon.helmet and label.modulate.a < 1.0
	_player.set_armor(100.0, true)
	var full := label.text == "100" and icon.points == 100.0 and icon.helmet and label.modulate.a == 1.0
	_player.take_damage(36.0, Hitbox.Zone.CHEST, null, 0.775)
	var worn := label.text == "96"
	_check("The HUD shows the armor (dimmed at 0), the helmet's mark, and the armor wearing down",
			empty and full and worn and icon.mouse_filter == Control.MOUSE_FILTER_IGNORE,
			"empty %s, full %s, after a hit '%s'" % [empty, full, label.text])
	hud.set_ui_scale(1.5)
	_check("...and scales with the HUD", is_equal_approx(icon.size.y, 54.0), "icon %s" % icon.size)
	hud.queue_free()
	_player.set_armor(0.0, false)
	await _wait_ticks(2)


func _test_console() -> void:
	_player.queue_free()
	await _wait_ticks(2)
	var main := MAIN_SCENE.instantiate()
	main.load_settings = false
	main.mode = main.Mode.PRACTICE
	add_child(main)
	await _wait_ticks(4)
	var player := main.get_map().get_node("Player") as Character
	_silence(player)
	var console := main.get_node("DevConsole") as DevConsole
	var output := console.get_node("Panel/Margin/Box/Output") as Label
	console.run("armor 75 helmet")
	var set_ok := _near(player.armor, 75.0) and player.has_helmet and output.text.contains("Armor 75 with a helmet.")
	console.run("armor 50")
	_check("The console's armor command sets and shows your armor and helmet",
			set_ok and _near(player.armor, 50.0) and not player.has_helmet, "armor %.1f, helmet %s" % [player.armor, player.has_helmet])
	main.queue_free()
	await _wait_ticks(2)


# --- Helpers ---


## A character without a controller (it stands still) on team 1, with the class [param data].
func _add_target(at: Vector3, data: ClassData = null) -> Character:
	var target := CHARACTER_SCENE.instantiate() as Character
	target.team = 1
	target.position = at
	if data != null:
		target.class_data = data
	target.footstep_sound = null
	add_child(target)
	await _wait_ticks(2)
	return target


func _zone_box(character: Character, zone: Hitbox.Zone) -> Hitbox:
	for hitbox in character.body.get_hitboxes():
		if hitbox.zone == zone:
			return hitbox
	return null


func _add_box(center: Vector3, size: Vector3) -> void:
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	var body := StaticBody3D.new()
	body.position = center
	body.add_child(collision)
	add_child(body)


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


func _near(a: float, b: float) -> bool:
	return absf(a - b) < 0.01


func _wait_ticks(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _check(check_name: String, passed: bool, detail: String) -> void:
	print("%s  %s: %s" % ["PASS" if passed else "FAIL", check_name, detail])
	if not passed:
		_failures += 1
