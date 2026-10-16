extends Node3D
## Automated checks of the grenades (M7 task 8, D-097). Run without a window:
##
##     Godot --headless --path . --fixed-fps 128 --quit-after 60000 res://tests/grenade_test.tscn
##
## On a flat floor with a wall: pulling the pin and throwing (fire) or lobbing (aim), the throw's
## speed and angle, the last grenade leaving the inventory for the weapon held before, switching
## away with the pin pulled; bounces and coming to rest; the frag's falloff, walls stopping it,
## armor's share and the thrower's kill; the flashbang's strength by facing and distance, walls,
## the white screen and blinded bots; the smoke cloud blocking bots' sight, greying a camera inside
## it and going away after 18 s. Quits with the number of failed checks as the exit code.

const PLAYER_SCENE := preload("res://player/player.tscn")
const CHARACTER_SCENE := preload("res://characters/character.tscn")
const BOT_SCENE := preload("res://bots/bot.tscn")
const HUD_SCENE := preload("res://ui/hud.tscn")
const FRAG := preload("res://weapons/frag.tres")
const FLASHBANG := preload("res://weapons/flashbang.tres")
const SMOKE := preload("res://weapons/smoke.tres")
const PISTOL := preload("res://weapons/pistol.tres")
## A wall at x = 20, from z = -10 to 10, 4 m high and half a metre thick.
const WALL_X := 20.0

var _failures: int = 0
var _player: Character


func _ready() -> void:
	Weapon.silent = true
	Smokes.clear()
	_add_box(Vector3(0, -0.5, 0), Vector3(300, 1, 300))
	_add_box(Vector3(WALL_X, 2, 0), Vector3(0.5, 4, 20))
	_player = PLAYER_SCENE.instantiate()
	_player.footstep_sound = null
	add_child(_player)
	await _wait_ticks(2)
	await _run_all()
	if _failures == 0:
		print("\nAll checks passed.")
	else:
		print("\n%d check(s) FAILED." % _failures)
	get_tree().quit(_failures)


func _run_all() -> void:
	await _test_throwing()
	await _test_flight()
	await _test_frag()
	await _test_flashbang()
	await _test_smoke()


func _test_throwing() -> void:
	var inventory := _player.inventory
	inventory.give(PISTOL)
	var rifle := _player.weapon
	inventory.give(FRAG)
	inventory.select_slot(WeaponData.Slot.GRENADE)
	await _wait_seconds(0.8)
	var frag := _player.weapon
	_player.global_position = Vector3(-50, 0, 0)
	await _wait_ticks(2)
	_player.aim_at(_player.get_eye_position() + Vector3(0, 0, -10))
	Input.action_press("shoot")
	await _wait_seconds(0.6)
	var held_back := _grenades().is_empty() and frag.is_priming()
	Input.action_release("shoot")
	await _wait_ticks(2)
	var flying := _grenades()
	var grenade: Grenade = flying[0] if flying.size() == 1 else null
	var expected := Grenade.throw_velocity(_player.get_aim_angles(), FRAG.throw_speed, Vector3.ZERO)
	var angle := rad_to_deg(asin(expected.normalized().y))
	_check("Fire pulls the pin and holds it while held; letting go throws the frag at 15 m/s, 10° above a level aim",
			held_back and grenade != null and grenade.velocity.length() > 14.0 and absf(angle - 10.0) < 0.5,
			"held back %s, speed %.1f m/s, angle %.1f°" % [held_back, grenade.velocity.length() if grenade else 0.0, angle])
	await _wait_seconds(0.6)
	_check("It was the last frag: it leaves the inventory and the weapon held before comes out",
			inventory.get_grenades().is_empty() and _player.weapon == rifle, "in hand %s" % (_player.weapon.data.id if _player.weapon else &"none"))
	await _wait_seconds(2.0)
	_clear_effects()
	inventory.give(FLASHBANG)
	inventory.give(FLASHBANG)
	inventory.select_slot(WeaponData.Slot.GRENADE)
	await _wait_seconds(0.8)
	Input.action_press("aim")
	await _wait_seconds(0.4)
	Input.action_release("aim")
	await _wait_ticks(2)
	var lobbed: Grenade = _grenades()[0] if _grenades().size() == 1 else null
	await _wait_seconds(0.6)
	var second_out := _player.weapon != null and _player.weapon.data.id == &"flashbang" and _player.weapon.magazine == 1
	_check("Aim lobs gently (7 m/s); with a flashbang left, the next one comes out",
			lobbed != null and absf(lobbed.velocity.length() - FLASHBANG.lob_speed) < 1.0 and second_out,
			"lob %.1f m/s, next out %s" % [lobbed.velocity.length() if lobbed else 0.0, second_out])
	await _wait_seconds(2.0)
	_clear_effects()
	Input.action_press("shoot")
	await _wait_seconds(0.2)
	inventory.select_slot(WeaponData.Slot.PISTOL)
	Input.action_release("shoot")
	await _wait_seconds(0.5)
	_check("Switching away with the pin pulled puts the grenade back: nothing is thrown",
			_grenades().is_empty() and inventory.get_grenades().size() == 1 and inventory.get_grenades()[0].magazine == 1,
			"grenades in flight %d" % _grenades().size())
	inventory.remove(inventory.get_grenades()[0])
	await _wait_ticks(2)


func _test_flight() -> void:
	var dud := WeaponData.new()
	dud.id = &"dud"
	var dropped := Grenade.throw(self, dud, Vector3(-40, 3, 30), Vector3.ZERO, null)
	var bounced := false
	var last_speed := 0.0
	for i in 400:
		await _wait_ticks(1)
		if not is_instance_valid(dropped):
			break
		if dropped.velocity.y > 0.0:
			bounced = true
		last_speed = dropped.velocity.length()
		if dropped.resting:
			break
	var rested := is_instance_valid(dropped) and dropped.resting and dropped.global_position.y < 0.2
	_check("A dropped grenade bounces on the floor and comes to rest on it", bounced and rested,
			"bounced %s, at rest %s" % [bounced, rested])
	_clear_effects()
	var thrown := Grenade.throw(self, FRAG, Vector3(WALL_X - 5, 1.5, 0), Vector3(12, 0, 0), null)
	await _wait_seconds(0.6)
	_check("Thrown at a wall it bounces back", is_instance_valid(thrown) and thrown.velocity.x < 0.0 and thrown.global_position.x < WALL_X,
			"x %.2f, vx %.2f" % [thrown.global_position.x if is_instance_valid(thrown) else 0.0, thrown.velocity.x if is_instance_valid(thrown) else 0.0])
	await _wait_seconds(1.5)
	_clear_effects()


func _test_frag() -> void:
	var near := await _add_target(Vector3(40, 0, -1))
	near.take_damage(40.0, Hitbox.Zone.LEGS, null)
	var middle := await _add_target(Vector3(40, 0, -4))
	var far := await _add_target(Vector3(40, 0, -11))
	var armored := await _add_target(Vector3(42, 0, 0))
	armored.set_armor(100.0, false)
	var hidden := await _add_target(Vector3(WALL_X + 2, 0, 0))
	var thrower := await _add_target(Vector3(0, 0, 40))
	thrower.team = 0
	var killers := [null]
	near.died.connect(func(killer: Character) -> void: killers[0] = killer)
	var at := Vector3(40, 0.1, 0)
	var grenade := Grenade.throw(self, FRAG, at, Vector3.ZERO, thrower)
	grenade.resting = true
	await _wait_seconds(Grenade.FRAG_FUSE + 0.1)
	var blast := at + Vector3.UP * 0.15
	var expected_middle := Grenade.frag_damage_at(98.0, blast.distance_to(middle.get_chest_position()))
	_check("The frag kills a hurt player next to it (98 at most: alone it can't kill a full one, as in CS) and falls off with distance (a bell curve, nothing past 9 m)",
			not near.is_alive() and absf((100.0 - middle.health) - expected_middle) < 0.5 and far.health == 100.0,
			"at 1 m dead: %s, at 4 m lost %.1f (expected %.1f), at 11 m %.0f" % [not near.is_alive(), 100.0 - middle.health, expected_middle, far.health])
	var armored_expected := Grenade.frag_damage_at(98.0, blast.distance_to(armored.get_chest_position())) * FRAG.armor_penetration
	_check("Armor takes its share (57.5% gets through); a wall stops the blast",
			absf((100.0 - armored.health) - armored_expected) < 0.5 and armored.armor < 100.0 and hidden.health == 100.0,
			"armored lost %.1f (expected %.1f), behind the wall %.0f" % [100.0 - armored.health, armored_expected, hidden.health])
	_check("The kill is the thrower's, with the frag", killers[0] == thrower and near.last_damage_source == FRAG,
			"killer %s" % (killers[0].name if killers[0] else "none"))
	for target in [near, middle, far, armored, hidden, thrower]:
		target.queue_free()
	await _wait_seconds(0.5)
	_clear_effects()


func _test_flashbang() -> void:
	var at := Vector3(60, 1.5, 0)
	var facing := await _add_target(Vector3(60, 0, -5), 0.0)
	facing.aim_at(at)
	var away := await _add_target(Vector3(64, 0, 0), 0.0)
	away.aim_at(Vector3(80, away.get_eye_position().y, 0))
	var distant := await _add_target(Vector3(60, 0, -38), 0.0)
	distant.aim_at(at)
	var full_amount := Grenade.get_flash_amount(facing, at)
	var away_amount := Grenade.get_flash_amount(away, at)
	var distant_amount := Grenade.get_flash_amount(distant, at)
	_check("A flash blinds fully in your face, much less when you look away, less from far off",
			is_equal_approx(full_amount, 1.0) and away_amount <= 0.25 and distant_amount < 0.6 and distant_amount > 0.3,
			"facing %.2f, looking away %.2f, at 38 m %.2f" % [full_amount, away_amount, distant_amount])
	var behind_wall := await _add_target(Vector3(WALL_X + 3, 0, 0), 0.0)
	behind_wall.aim_at(Vector3(WALL_X - 5, 1.5, 0))
	_check("A wall between you and the flash: nothing", Grenade.get_flash_amount(behind_wall, Vector3(WALL_X - 5, 1.5, 0)) == 0.0, "")
	# A bot facing it is blinded and can't see an enemy right in front of it.
	var bot := BOT_SCENE.instantiate() as Character
	bot.team = 1
	bot.footstep_sound = null
	bot.position = Vector3(60, 0, 6)
	add_child(bot)
	await _wait_ticks(3)
	var enemy := await _add_target(Vector3(60, 0, 1), 0.0)
	enemy.team = 0
	enemy.god_mode = true  # The bot shoots at it; it must stay there to be seen.
	bot.aim_at(enemy.get_chest_position())
	await _wait_ticks(2)
	var senses := bot.get_node("BotSenses") as BotSenses
	var sees_before := senses.can_see(enemy)
	var hud := HUD_SCENE.instantiate()
	add_child(hud)
	hud.set_player(_player)
	_player.global_position = Vector3(60, 0, 8)
	await _wait_ticks(2)
	_player.aim_at(at)
	var grenade := Grenade.throw(self, FLASHBANG, at, Vector3.ZERO, null)
	grenade.resting = true
	await _wait_seconds(Grenade.FLASH_FUSE + 0.1)
	var overlay := hud.get_node("FlashOverlay") as ColorRect
	var white := overlay.visible and overlay.color.a > 0.99
	bot.aim_at(enemy.get_chest_position())
	var blind := not senses.can_see(enemy) and bot.get_flash_alpha() == 1.0
	await _wait_seconds(Grenade.FLASH_MAX + 0.2)
	bot.aim_at(enemy.get_chest_position())
	_check("The flash whites out your screen and blinds a bot that faces it (it sees nobody), and both wear off",
			sees_before and white and blind and facing.get_flash_alpha() == 0.0 and not overlay.visible and senses.can_see(enemy),
			"saw before %s, your screen white %s, bot blind %s, later sees again %s" % [sees_before, white, blind, senses.can_see(enemy)])
	for node in [facing, away, distant, behind_wall, bot, enemy, hud]:
		node.queue_free()
	await _wait_ticks(2)
	_clear_effects()


func _test_smoke() -> void:
	var grenade := Grenade.throw(self, SMOKE, Vector3(80, 0.1, 0), Vector3.ZERO, null)
	grenade.resting = true
	await _wait_seconds(Grenade.SMOKE_MIN_FUSE + 0.1)
	var clouds := get_tree().get_nodes_in_group("smoke_clouds")
	var cloud: SmokeCloud = clouds[0] if clouds.size() == 1 else null
	await _wait_seconds(SmokeCloud.GROW_TIME)
	var bot := BOT_SCENE.instantiate() as Character
	bot.team = 1
	bot.footstep_sound = null
	bot.position = Vector3(80, 0, 8)
	add_child(bot)
	var enemy := await _add_target(Vector3(80, 0, -8), 0.0)
	enemy.team = 0
	enemy.god_mode = true
	await _wait_ticks(3)
	bot.aim_at(enemy.get_chest_position())
	await _wait_ticks(2)
	var senses := bot.get_node("BotSenses") as BotSenses
	var hidden := cloud != null and not senses.can_see(enemy)
	var beside := not Smokes.blocks(Vector3(74, 1.6, 8), Vector3(74, 1.6, -8))
	var hud := HUD_SCENE.instantiate()
	add_child(hud)
	hud.set_player(_player)
	_player.global_position = Vector3(80, 0, 0)
	await _wait_ticks(3)
	var grey := (hud.get_node("SmokeOverlay") as ColorRect).visible and (hud.get_node("SmokeOverlay") as ColorRect).color.a > 0.9
	_check("A smoke pops where it rests: a bot can't see an enemy through it, a line beside it is clear, and a camera inside sees grey",
			hidden and beside and grey, "cloud %s, hidden %s, beside clear %s, grey %s" % [cloud != null, hidden, beside, grey])
	_player.global_position = Vector3(-60, 0, 0)
	await _wait_seconds(SmokeCloud.LIFETIME - SmokeCloud.GROW_TIME)
	_check("After 18 s the cloud is gone and the bot sees again", not is_instance_valid(cloud) and senses.can_see(enemy) and Smokes.get_clouds().is_empty(),
			"cloud left %s" % is_instance_valid(cloud))
	for node in [bot, enemy, hud]:
		node.queue_free()
	await _wait_ticks(2)


# --- Helpers ---


func _grenades() -> Array:
	return get_tree().get_nodes_in_group("grenades").filter(func(node: Node) -> bool: return not node.is_queued_for_deletion())


## Removes grenades still flying and smoke clouds still up.
func _clear_effects() -> void:
	for node in _grenades():
		node.queue_free()
	for node in get_tree().get_nodes_in_group("smoke_clouds"):
		node.queue_free()
	Smokes.clear()
	await _wait_ticks(1)


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
