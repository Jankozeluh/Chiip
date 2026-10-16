extends Node3D
## Automated checks of a character's gear (M7): armor and helmet (D-093), and the inventory:
## slots, loadouts, switching, dropping and picking up (D-094). Run without a window:
##
##     Godot --headless --path . --fixed-fps 128 --quit-after 60000 res://tests/gear_test.tscn
##
## Armor on real characters: what a hit through the hit zones does to health and armor with
## and without a helmet, legs never covered, armor giving out, the Bulwark's Plated perk, the
## bomb's damage ignoring armor, death taking the gear away, a real bullet passing its weapon on,
## the HUD's armor number and shield, and the console's armor command in the real game scene.
## The inventory: what fits in which slot, switching through the real keys with draw times (the
## Rifleman's Quick Hands), Q, grenades cycling, G dropping a gun with its ammo, walking over a gun,
## E swapping for one, the best gun dropping on death, the HUD and the body following the weapon
## in hand, and the loadouts the rules hand out (a fresh one every round, the class's in team
## respawn and practice).
## Quits with the number of failed checks as the exit code (0 means everything passed).

const PLAYER_SCENE := preload("res://player/player.tscn")
const CHARACTER_SCENE := preload("res://characters/character.tscn")
const HUD_SCENE := preload("res://ui/hud.tscn")
const MAIN_SCENE := preload("res://main.tscn")
const BOT_SCENE := preload("res://bots/bot.tscn")
## How long the HUD's slot list takes to fade out after a change (shows 2.5 s, fades in the last 0.5 s).
const HUD_SLOTS_TIME := 2.7
const RIFLE := preload("res://weapons/rifle.tres")
const CARBINE := preload("res://weapons/carbine.tres")
const BULWARK := preload("res://characters/crew/classes/bulwark.tres")
const SCOUT := preload("res://characters/crew/classes/scout.tres")
const PISTOL := preload("res://weapons/pistol.tres")
const KNIFE := preload("res://weapons/knife.tres")
const SMG := preload("res://weapons/smg.tres")
const FRAG := preload("res://weapons/frag.tres")
const FLASHBANG := preload("res://weapons/flashbang.tres")
const SMOKE := preload("res://weapons/smoke.tres")
const MAP_SCENE := preload("res://maps/test_map.tscn")

var _failures: int = 0
var _player: Character


func _ready() -> void:
	Weapon.silent = true
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
	await _test_slots()
	await _test_switching()
	await _test_dropping_and_picking_up()
	await _test_hud_and_body_follow()
	await _test_console()
	await _test_round_loadouts()
	await _test_respawn_and_practice_loadouts()
	await _test_weapon_spots()
	await _test_scavenging()


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
	var label := hud.get_node("%ArmorLabel") as Label
	var icon := hud.get_node("%ArmorIcon") as TextureRect
	var block := hud.get_node("%ArmorBlock") as Control
	_player.set_armor(0.0, false)
	var empty := not block.visible
	_player.set_armor(100.0, true)
	var full := label.text == "100" and block.visible and icon.visible and icon.texture == UiIcons.get_icon(icon, &"helmet")
	_player.set_armor(100.0, false)
	var plain := icon.texture == UiIcons.get_icon(icon, &"armor") and icon.texture != UiIcons.get_icon(icon, &"helmet")
	_player.set_armor(100.0, true)
	_player.take_damage(36.0, Hitbox.Zone.CHEST, null, 0.775)
	var worn := label.text == "96"
	_check("The HUD shows the armor (its whole block hidden at 0), the helmet's icon when one is worn and the armor icon when not, and the armor wearing down",
			empty and full and plain and worn and icon.mouse_filter == Control.MOUSE_FILTER_IGNORE,
			"empty %s, full %s, plain %s, after a hit '%s'" % [empty, full, plain, label.text])
	hud.set_ui_scale(1.5)
	var scaled := icon.custom_minimum_size
	var base: Vector2 = icon.texture.get_size() * (hud.get_node("%ArmorIcon").get_theme_constant("icon_scale", "Hud"))
	_check("...and the icon scales with the HUD (2 times the 16 px icon, 1.5 times as big at 1.5)", scaled == (base * 1.5).round(), "icon %s, expected %s" % [scaled, (base * 1.5).round()])
	hud.queue_free()
	_player.set_armor(0.0, false)
	await _wait_ticks(2)


# --- The inventory (D-094) ---


func _test_slots() -> void:
	var inventory := _player.inventory
	var starts := inventory.get_in_slot(WeaponData.Slot.PRIMARY) == _player.weapon and _player.weapon.data.id == &"rifle"
	var pistol := inventory.give(PISTOL)
	var knife := inventory.give(KNIFE)
	var second_pistol := inventory.give(PISTOL)
	var frag := inventory.give(FRAG)
	var flash := inventory.give(FLASHBANG)
	var flash_again := inventory.give(FLASHBANG)
	var third_flash := inventory.give(FLASHBANG)
	var second_frag := inventory.give(FRAG)
	var smoke := inventory.give(SMOKE)
	_check("The scene's rifle is the primary in hand; a pistol, the knife and grenades go into their slots, and nothing more than fits",
			starts and pistol != null and knife != null and second_pistol == null and frag != null and flash == flash_again
					and flash.magazine == 2 and third_flash == null and second_frag == null and smoke != null
					and inventory.get_grenade_count() == 4 and _player.weapon.data.id == &"rifle",
			"in hand %s, flashbangs %d, grenades %d" % [_player.weapon.data.id, flash.magazine, inventory.get_grenade_count()])
	_check("Weapons not in hand are hidden and idle",
			not pistol.visible and pistol.process_mode == Node.PROCESS_MODE_DISABLED and _player.weapon.visible,
			"pistol visible %s" % pistol.visible)


func _test_switching() -> void:
	var inventory := _player.inventory
	var rifle := _player.weapon
	var pistol := inventory.get_in_slot(WeaponData.Slot.PISTOL)
	await _wait_ticks(2)
	_press("slot_pistol")
	await _wait_ticks(2)
	var drawing := _player.weapon == pistol and pistol.is_drawing()
	var shots := [0]
	pistol.fired.connect(func(_n: int) -> void: shots[0] += 1)
	Input.action_press("shoot")
	await _wait_ticks(20)
	Input.action_release("shoot")
	var during_draw: int = shots[0]
	var draw_time := inventory.get_draw_time(PISTOL)
	await _wait_seconds(draw_time)
	Input.action_press("shoot")
	await _wait_ticks(3)
	Input.action_release("shoot")
	await _wait_ticks(3)
	_check("Key 2 takes out the pistol: it can't fire for its draw time (%.2f s), then it does" % draw_time,
			drawing and during_draw == 0 and shots[0] == 1, "drawing %s, shots during the draw %d, after %d" % [drawing, during_draw, shots[0]])
	_check("The Rifleman's Quick Hands draws 15% faster than the Scout",
			_near(draw_time, PISTOL.draw_time * 0.85) and _player.class_data.id == &"rifleman", "%.3f s" % draw_time)
	_press("last_weapon")
	await _wait_ticks(2)
	var back := _player.weapon == rifle
	_press("slot_grenade")
	await _wait_ticks(2)
	var first := _player.weapon.data.id
	_press("slot_grenade")
	await _wait_ticks(2)
	var second := _player.weapon.data.id
	_press("slot_grenade")
	await _wait_ticks(2)
	var third := _player.weapon.data.id
	_press("slot_grenade")
	await _wait_ticks(2)
	_check("Q goes back to the last weapon; 4 cycles through the grenades",
			back and first == &"frag" and second == &"flashbang" and third == &"smoke" and _player.weapon.data.id == &"frag",
			"back %s, grenades %s %s %s %s" % [back, first, second, third, _player.weapon.data.id])
	_press("slot_knife")
	await _wait_ticks(2)
	_check("Key 3 takes out the knife", _player.weapon.data.id == &"knife", "in hand %s" % _player.weapon.data.id)
	_press("slot_primary")
	await _wait_seconds(1.0)


func _test_dropping_and_picking_up() -> void:
	var inventory := _player.inventory
	_player.global_position = Vector3.ZERO
	_player.aim_at(_player.get_eye_position() + Vector3(0, 0, -5))
	await _wait_ticks(2)
	var rifle := _player.weapon
	rifle.magazine = 17
	_press("drop_weapon")
	await _wait_ticks(2)
	var pickups := _pickups()
	var pickup: WeaponPickup = pickups[0] if pickups.size() == 1 else null
	var dropped := pickup != null and pickup.data.id == &"rifle" and pickup.magazine == 17 and pickup.reserve == 90 \
			and inventory.get_in_slot(WeaponData.Slot.PRIMARY) == null and _player.weapon.data.id == &"pistol"
	await _wait_seconds(0.6)
	_check("G drops the rifle in front of you with its ammo, and the pistol comes out",
			dropped and pickup.has_landed() and _player.weapon.data.id == &"pistol",
			"pickups %d, landed %s, in hand %s" % [pickups.size(), pickup.has_landed() if pickup else false, _player.weapon.data.id])
	# Walking over it within a second doesn't take it back; after that, it does.
	_player.global_position = pickup.global_position * Vector3(1, 0, 1)
	await _wait_ticks(4)
	var kept_off := inventory.get_in_slot(WeaponData.Slot.PRIMARY) == null
	await _wait_seconds(0.6)
	var primary := inventory.get_in_slot(WeaponData.Slot.PRIMARY)
	_check("You can't take back a gun you just dropped for a second; then walking over it takes it, ammo and all, without switching",
			kept_off and primary != null and primary.magazine == 17 and _pickups().is_empty() and _player.weapon.data.id == &"pistol",
			"kept off %s, primary %s, in hand %s" % [kept_off, primary.data.id if primary else &"none", _player.weapon.data.id])
	# A gun on the floor doesn't go into a full slot by walking over it; E swaps.
	var smg_pickup := WeaponPickup.spawn(self, SMG, 30, 120, Vector3(0, 0.5, -1.2), 0.0)
	_player.global_position = Vector3(0, 0, -1.2)
	await _wait_seconds(0.4)
	var not_taken := _pickups().size() == 1 and inventory.get_in_slot(WeaponData.Slot.PRIMARY).data.id == &"rifle"
	_player.global_position = Vector3.ZERO
	await _wait_ticks(2)
	_player.aim_at(smg_pickup.global_position)
	await _wait_ticks(1)
	Input.action_press("use")
	await _wait_ticks(2)
	Input.action_release("use")
	await _wait_ticks(2)
	var after := _pickups()
	_check("Walking over a gun doesn't take it into a full slot; E while looking at it swaps: it's in hand and your rifle is on the floor",
			not_taken and _player.weapon.data.id == &"smg" and after.size() == 1 and (after[0] as WeaponPickup).data.id == &"rifle"
					and (after[0] as WeaponPickup).magazine == 17,
			"walked over %s, in hand %s, on the floor %s" % [not_taken, _player.weapon.data.id, after.map(func(p: WeaponPickup) -> StringName: return p.data.id)])
	for node in _pickups():
		node.queue_free()
	await _wait_ticks(2)
	# Death: the best gun falls where the character was.
	var victim := await _add_target(Vector3(4, 0, 0))
	victim.inventory.give(PISTOL)
	victim.inventory.give(SMG)
	victim.take_damage(500.0, Hitbox.Zone.CHEST, _player)
	await _wait_ticks(3)
	var left := _pickups()
	_check("Dying drops your best gun (the primary) where you fell; the pistol and the rest are lost with you",
			left.size() == 1 and (left[0] as WeaponPickup).data.id == &"smg" and (left[0] as WeaponPickup).global_position.distance_to(victim.global_position) < 1.5,
			"on the floor %s" % [left.map(func(p: WeaponPickup) -> StringName: return p.data.id)])
	for node in _pickups():
		node.queue_free()
	victim.queue_free()
	await _wait_ticks(2)


func _test_hud_and_body_follow() -> void:
	var hud := HUD_SCENE.instantiate()
	add_child(hud)
	hud.set_player(_player)
	# A character without a brain: a bot's would take its pistol back out of the knife (D-099).
	var bot := CHARACTER_SCENE.instantiate() as Character
	bot.team = 1
	bot.position = Vector3(-6, 0, 0)
	add_child(bot)
	await _wait_ticks(2)
	bot.inventory.set_loadout([KNIFE, PISTOL] as Array[WeaponData])
	await _wait_ticks(2)
	var body_gun := bot.body.get_gun_model()
	var body_ok := _shows_model(body_gun, PISTOL)
	bot.inventory.hold(bot.inventory.get_in_slot(WeaponData.Slot.KNIFE))
	await _wait_ticks(2)
	_check("A body holds the model of the weapon in hand, and follows a switch",
			body_ok and _shows_model(bot.body.get_gun_model(), KNIFE), "pistol shown %s" % body_ok)
	_player.inventory.hold(_player.inventory.get_in_slot(WeaponData.Slot.PISTOL), true)
	await _wait_ticks(2)
	var ammo := hud.get_node("%MagLabel") as Label
	var reserve := hud.get_node("%ReserveLabel") as Label
	var ammo_row := hud.get_node("%AmmoRow") as Control
	var name_label := hud.get_node("%WeaponLabel") as Label
	var weapon_icon := hud.get_node("%WeaponIcon") as TextureRect
	var slots := hud.get_node("SlotsLabel") as Label
	var held_pistol := _player.weapon
	var shows_pistol: bool = ammo.text == "%d" % held_pistol.magazine and reserve.text == "/ %d" % held_pistol.reserve and name_label.text == PISTOL.display_name \
			and weapon_icon.visible and weapon_icon.texture == UiIcons.get_icon(weapon_icon, PISTOL.id)
	_player.weapon.magazine = 3
	_player.weapon.ammo_changed.emit(3, 45)
	var follows := ammo.text == "3" and reserve.text == "/ 45"
	var low: bool = ammo.get_theme_color("font_color") == hud.get_node("%BottomRight").get_theme_color("alert", "Palette")
	_check("The HUD follows the weapon in hand: its ammo (magazine and reserve, the magazine in the alert colour when low), its name and icon, and the slot list (kept, hidden) with it marked",
			shows_pistol and follows and low and not slots.visible and slots.text.contains("» 2  " + PISTOL.display_name) and slots.text.contains("1  ") and slots.modulate.a > 0.9,
			"ammo '%s %s', name '%s', slots '%s'" % [ammo.text, reserve.text, name_label.text, slots.text.replace("\n", " | ")])
	var feed := KillFeed.new()
	add_child(feed)
	feed.add_kill(bot, _player, true, SMG)
	feed.add_kill(bot, _player, false)
	var odd := SMG.duplicate() as WeaponData
	odd.id = &"no_such_slot"
	feed.add_kill(bot, _player, false, odd)
	odd.kill_icon = null
	feed.add_kill(bot, _player, false, odd)
	var icon := feed.get_child(0).find_child("Weapon", true, false) as TextureRect
	var plain := feed.get_child(1).find_child("Separator", true, false) as Label
	var rendered := feed.get_child(2).find_child("Weapon", true, false) as TextureRect
	var named := feed.get_child(3).find_child("Weapon", true, false) as Label
	_check("The kill feed shows the killing weapon's UI icon (by its id) between the names; without a slot for it M7's rendered icon, then its name; \">\" without a weapon",
			icon != null and icon.texture == UiIcons.get_icon(feed, SMG.id) and icon.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST
					and plain != null and plain.text == ">" and rendered != null and rendered.texture == SMG.kill_icon
					and named != null and named.text == odd.display_name,
			"icon %s, plain '%s', rendered %s, named %s" % [icon != null, plain.text if plain else "", rendered != null, named != null])
	feed.queue_free()
	_player.inventory.hold(_player.inventory.get_in_slot(WeaponData.Slot.KNIFE), true)
	await _wait_ticks(2)
	_check("...the knife shows no ammo row and its icon", not ammo_row.visible and name_label.text == "Knife" and weapon_icon.visible, "ammo '%s'" % ammo.text)
	await _wait_seconds(HUD_SLOTS_TIME)
	_check("...and the slot list fades out a few seconds after a change", slots.modulate.a < 0.05, "alpha %.2f" % slots.modulate.a)
	hud.queue_free()
	bot.queue_free()
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
	console.run("armor 75 helmet")
	var set_ok := _near(player.armor, 75.0) and player.has_helmet and console.get_output_text().contains("Armor 75 with a helmet.")
	console.run("armor 50")
	_check("The console's armor command sets and shows your armor and helmet",
			set_ok and _near(player.armor, 50.0) and not player.has_helmet, "armor %.1f, helmet %s" % [player.armor, player.has_helmet])
	main.queue_free()
	await _wait_ticks(2)


func _test_round_loadouts() -> void:
	var map := MAP_SCENE.instantiate()
	add_child(map)
	var player := map.get_node("Player") as Character
	_silence(player)
	var rounds := RoundManager.new()
	rounds.settings = _settings()
	rounds.rng.seed = 3
	map.add_child(rounds)
	await _wait_ticks(3)
	var everyone_ok := rounds.get_participants().all(func(c: Character) -> bool:
		return c.inventory.get_weapons().map(func(w: Weapon) -> StringName: return w.data.id) == [&"knife", &"pistol"] and c.weapon.data.id == &"pistol")
	_check("A round starts everyone with the knife and the Sparrow in hand, nothing else (D-090)", everyone_ok,
			"you: %s" % [player.inventory.get_weapons().map(func(w: Weapon) -> StringName: return w.data.id)])
	await _wait_for_live(rounds)
	player.inventory.give(SMG)
	player.set_armor(100.0, true)
	WeaponPickup.spawn(map, SMG, 10, 0, player.global_position + Vector3(3, 1, 0), 0.0)
	rounds.get_members(1)[0].take_damage(500.0, Hitbox.Zone.CHEST, player)
	for mate in rounds.get_members(1):
		mate.take_damage(500.0, Hitbox.Zone.CHEST, player)
	await _wait_for_phase(rounds, RoundManager.Phase.FREEZE)
	await _wait_ticks(2)
	var fresh := player.inventory.get_weapons().map(func(w: Weapon) -> StringName: return w.data.id) == [&"knife", &"pistol"] \
			and player.armor == 0.0 and not player.has_helmet
	var floor_clear := _pickups(map).is_empty()
	_check("The next round starts fresh: the bought SMG and armor are gone, and so are the guns on the floor",
			fresh and floor_clear, "you: %s, armor %.0f, guns on the floor %d" % [
				player.inventory.get_weapons().map(func(w: Weapon) -> StringName: return w.data.id), player.armor, _pickups(map).size()])
	remove_child(map)
	map.queue_free()
	await _wait_ticks(2)


func _test_respawn_and_practice_loadouts() -> void:
	var map := MAP_SCENE.instantiate()
	map.get_node("Player").free()
	add_child(map)
	var match_rules := RespawnMatch.new()
	match_rules.settings = _settings()
	match_rules.rng.seed = 4
	map.add_child(match_rules)
	await _wait_ticks(3)
	var by_class := match_rules.get_participants().all(func(c: Character) -> bool:
		return c.weapon != null and c.weapon.data == c.class_data.loadout[0] and c.inventory.get_weapons().size() == 4)
	var scout: Character = null
	for c in match_rules.get_participants():
		if c.class_data == SCOUT:
			scout = c
	_check("Team respawn: everyone spawns with their class's loadout (the Scout: Hornet, Sparrow, knife, Flashbang)",
			by_class and scout != null and scout.inventory.get_weapons().map(func(w: Weapon) -> StringName: return w.data.id) == [&"smg", &"pistol", &"knife", &"flashbang"],
			"Scout: %s" % [scout.inventory.get_weapons().map(func(w: Weapon) -> StringName: return w.data.id) if scout else []])
	remove_child(map)
	map.queue_free()
	await _wait_ticks(2)
	var practice_map := MAP_SCENE.instantiate()
	add_child(practice_map)
	_silence(practice_map.get_node("Player"))
	var arena := ArenaRules.new()
	arena.bot_count = 2
	practice_map.add_child(arena)
	await _wait_ticks(3)
	var practice_player := practice_map.get_node("Player") as Character
	var practice_ok := arena.get_bots().all(func(c: Character) -> bool: return c.weapon != null and c.weapon.data == c.class_data.loadout[0])
	_check("Practice: you and the bots get your classes' loadouts", practice_ok and practice_player.weapon.data.id == &"rifle"
			and practice_player.inventory.get_weapons().size() == 4, "you: %s" % [practice_player.inventory.get_weapons().map(func(w: Weapon) -> StringName: return w.data.id)])
	remove_child(practice_map)
	practice_map.queue_free()
	await _wait_ticks(2)


## M7 tasks 9 and 16 (D-098): a map weapon floats over its ring with a beam, a walk over takes it
## and the spot goes away; the round manager puts out new ones at random places every round (none
## replaced during a round), and Team Deathmatch replaces a taken one somewhere else after a while.
func _test_weapon_spots() -> void:
	var map := MAP_SCENE.instantiate()
	add_child(map)
	var player := map.get_node("Player") as Character
	_silence(player)
	var spot := (load("res://weapons/weapon_spot.tscn") as PackedScene).instantiate() as WeaponSpot
	spot.weapon = load("res://weapons/sniper.tres")
	map.add_child(spot)
	spot.global_position = player.global_position + Vector3(4, 0, 0)
	var taken_by: Array = []
	spot.taken.connect(func(by: Character) -> void: taken_by.append(by))
	await _wait_ticks(3)
	var pickup := spot.get_pickup()
	var out := pickup != null and pickup.floating and pickup.data.id == &"sniper" and pickup.magazine == 5 \
			and pickup.global_position.y > spot.global_position.y + 0.5 and spot.get_node_or_null("Beam") != null
	player.inventory.set_loadout([KNIFE, PISTOL] as Array[WeaponData])
	player.global_position = spot.global_position
	await _wait_ticks(3)
	var taken := player.inventory.get_in_slot(WeaponData.Slot.PRIMARY) != null \
			and player.inventory.get_in_slot(WeaponData.Slot.PRIMARY).data.id == &"sniper"
	_check("A map weapon shows a floating Heron with a beam; walking over it takes it, and the spot tells who and goes away",
			out and taken and taken_by == [player] and not is_instance_valid(spot),
			"out %s, taken %s, by %s, spot still there %s" % [out, taken, taken_by, is_instance_valid(spot)])
	# Rounds: two at random places, away from the spawns; a taken one isn't replaced until the next round.
	var settings := _settings()
	settings.team_size = 1
	settings.enemy_team_size = 1
	var rounds := RoundManager.new()
	rounds.settings = settings
	rounds.rng.seed = 5
	map.add_child(rounds)
	await _wait_ticks(3)
	var first := rounds.map_weapons.get_spots()
	var first_places: Array[Vector3] = []
	var far := true
	for each in first:
		first_places.append(each.global_position)
		for group in [Teams.ATTACK_SPAWN_GROUP, Teams.DEFEND_SPAWN_GROUP]:
			for marker in get_tree().get_nodes_in_group(group):
				var gap := (marker as Node3D).global_position - each.global_position
				far = far and Vector2(gap.x, gap.z).length() >= 15.0
	_check("A round puts out two map weapons, each at least 15 m from every spawn",
			first.size() == 2 and far, "%d out, far %s, at %s" % [first.size(), far, first_places])
	var placed: Array = []
	rounds.map_weapons.weapon_placed.connect(func(new_spot: WeaponSpot) -> void: placed.append(new_spot))
	await _wait_for_live(rounds)
	player.inventory.set_loadout([KNIFE, PISTOL] as Array[WeaponData])
	player.global_position = first[0].global_position
	await _wait_ticks(3)
	var took := player.inventory.get_in_slot(WeaponData.Slot.PRIMARY) != null
	await _wait_seconds(2.5)
	var none_new := placed.is_empty()
	for enemy in rounds.get_members(1):
		enemy.take_damage(500.0, Hitbox.Zone.CHEST, player)
	await _wait_for_phase(rounds, RoundManager.Phase.FREEZE)
	await _wait_ticks(2)
	var second := rounds.map_weapons.get_spots()
	var moved := second.size() == 2 and second.all(func(each: WeaponSpot) -> bool: return not first_places.has(each.global_position))
	_check("In rounds a taken one isn't replaced during the round; the next round has two new ones at other places",
			took and none_new and moved, "took %s, none new %s, moved %s" % [took, none_new, moved])
	remove_child(map)
	map.queue_free()
	await _wait_ticks(2)
	# Team Deathmatch: three out, a taken one replaced somewhere else after the replace time.
	map = MAP_SCENE.instantiate()
	add_child(map)
	player = map.get_node("Player") as Character
	_silence(player)
	settings = _settings()
	settings.team_size = 1
	settings.enemy_team_size = 1
	settings.map_weapon_replace_time = 1.0
	var respawn := RespawnMatch.new()
	respawn.settings = settings
	respawn.rng.seed = 5
	map.add_child(respawn)
	await _wait_ticks(3)
	var three := respawn.map_weapons.get_spots().size()
	await _wait_for_live(respawn)
	var target := respawn.map_weapons.get_spots()[0]
	var old_place := target.global_position
	player.inventory.set_loadout([KNIFE, PISTOL] as Array[WeaponData])
	player.global_position = old_place
	await _wait_ticks(3)
	var two := respawn.map_weapons.get_spots().size()
	await _wait_seconds(1.1)
	var again := respawn.map_weapons.get_spots()
	var elsewhere := again.size() == 3 and again.all(func(each: WeaponSpot) -> bool: return each.global_position != old_place)
	_check("Team Deathmatch keeps three out: a taken one comes back somewhere else after the replace time",
			three == 3 and two == 2 and elsewhere, "%d, then %d, then %d (elsewhere %s)" % [three, two, again.size(), elsewhere])
	remove_child(map)
	map.queue_free()
	await _wait_ticks(2)


## M7 task 18: walking over a dropped gun of a kind you carry takes its ammo into your reserve (up
## to full), and a gun left empty goes; a map weapon is never scavenged; in Team Deathmatch guns
## dropped more than 30 s ago go away.
func _test_scavenging() -> void:
	var map := MAP_SCENE.instantiate()
	add_child(map)
	var player := map.get_node("Player") as Character
	_silence(player)
	player.inventory.set_loadout([KNIFE, PISTOL, RIFLE] as Array[WeaponData])
	var rifle := player.inventory.get_in_slot(WeaponData.Slot.PRIMARY)
	rifle.reserve = 30
	var scavenged: Array = []
	player.inventory.ammo_scavenged.connect(func(weapon: Weapon, amount: int) -> void: scavenged.append([weapon.data.id, amount]))
	var dropped := WeaponPickup.spawn(map, RIFLE, 25, 20, player.global_position + Vector3(3, 0.5, 0), 0.0)
	await _wait_ticks(20)
	player.global_position = dropped.global_position
	await _wait_ticks(3)
	var took_all := rifle.reserve == 75 and not is_instance_valid(dropped) and scavenged == [[&"rifle", 45]]
	var second := WeaponPickup.spawn(map, RIFLE, 30, 60, player.global_position + Vector3(3, 0.5, 0), 0.0)
	await _wait_ticks(20)
	player.global_position = second.global_position
	await _wait_ticks(3)
	var topped_up := rifle.reserve == RIFLE.reserve_ammo and is_instance_valid(second) and second.reserve + second.magazine == 75
	_check("Walking over a dropped Ram while carrying one takes its ammo into your reserve (all 45, and the empty gun goes; then just the 15 that fit, the rest stays)",
			took_all and topped_up, "reserve %d, first gone %s, second left %d, signals %s" % [rifle.reserve, not is_instance_valid(dropped),
			second.reserve + second.magazine if is_instance_valid(second) else -1, scavenged])
	second.queue_free()
	rifle.reserve = 0
	var spot := (load("res://weapons/weapon_spot.tscn") as PackedScene).instantiate() as WeaponSpot
	spot.weapon = RIFLE
	map.add_child(spot)
	spot.global_position = player.global_position + Vector3(0, 0, 5)
	await _wait_ticks(3)
	player.global_position = spot.global_position
	await _wait_ticks(3)
	_check("A map weapon of the kind you carry stays where it is: it isn't scavenged",
			rifle.reserve == 0 and spot.has_weapon(), "reserve %d, still out %s" % [rifle.reserve, spot.has_weapon()])
	remove_child(map)
	map.queue_free()
	await _wait_ticks(2)
	# Team Deathmatch clears old guns.
	map = MAP_SCENE.instantiate()
	add_child(map)
	player = map.get_node("Player") as Character
	_silence(player)
	var settings := _settings()
	settings.team_size = 1
	settings.enemy_team_size = 1
	var respawn := RespawnMatch.new()
	respawn.settings = settings
	respawn.rng.seed = 5
	map.add_child(respawn)
	await _wait_for_live(respawn)
	var old_gun := WeaponPickup.spawn(map, SMG, 30, 0, player.global_position + Vector3(0, 0.5, 20), 0.0)
	var new_gun := WeaponPickup.spawn(map, SMG, 30, 0, player.global_position + Vector3(0, 0.5, 24), 0.0)
	old_gun.age = RespawnMatch.DROPPED_GUN_LIFETIME - 0.5
	await _wait_seconds(1.0)
	var map_weapons_out := respawn.map_weapons.get_spots().size()
	_check("Team Deathmatch takes away a gun dropped 30 s ago, keeps a newer one and the map weapons",
			not is_instance_valid(old_gun) and is_instance_valid(new_gun) and map_weapons_out == 3,
			"old gone %s, new kept %s, map weapons %d" % [not is_instance_valid(old_gun), is_instance_valid(new_gun), map_weapons_out])
	remove_child(map)
	map.queue_free()
	await _wait_ticks(2)


# --- Helpers ---


func _settings() -> MatchSettings:
	var settings := MatchSettings.new()
	settings.freeze_time = 0.5
	settings.round_time = 30.0
	settings.round_end_time = 0.5
	settings.rounds_to_win = 15
	settings.bomb_rounds = false
	settings.bots_buy = false
	return settings


## Every gun lying on the floor (under [param root], or anywhere in this test), not counting the
## map weapons floating over their rings.
func _pickups(root: Node = null) -> Array:
	return get_tree().get_nodes_in_group(WeaponPickup.GROUP).filter(func(node: Node) -> bool:
		return not node.is_queued_for_deletion() and (node as WeaponPickup).spot == null and (root == null or root.is_ancestor_of(node)))


## True if [param model] is [param data]'s model (or there's none when the weapon has no model yet).
func _shows_model(model: Node3D, data: WeaponData) -> bool:
	if data.model == null:
		return model == null
	return model != null and model.scene_file_path == data.model.resource_path


## Sends an action press and release the way a key does (through the input system).
func _press(action: String) -> void:
	for pressed in [true, false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = pressed
		Input.parse_input_event(event)


func _wait_seconds(seconds: float) -> void:
	await _wait_ticks(ceili(seconds * Engine.physics_ticks_per_second) + 1)


func _wait_for_live(manager: RoundManager) -> void:
	var ticks := 0
	while manager.phase != RoundManager.Phase.LIVE and ticks < 128 * 10:
		await get_tree().physics_frame
		ticks += 1


func _wait_for_phase(manager: RoundManager, phase: RoundManager.Phase) -> void:
	var ticks := 0
	while manager.phase != phase and ticks < 128 * 10:
		await get_tree().physics_frame
		ticks += 1


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
