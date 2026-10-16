extends Node3D
## Automated checks of how bots buy and use the arsenal (M7 task 14, D-099). Run without a window:
##
##     Godot --headless --path . --fixed-fps 128 --quit-after 100000 res://tests/botgear_test.tscn
##
## The team's buying plan (pistol round, full buy, force buy, save) and what each class buys with
## it, through the round manager's own rules; then on a flat floor with a navigation mesh: a bot
## switching to the pistol when its rifle is empty, scoping the Heron before it shoots, going for a
## better gun lying near it, throwing a frag at an enemy it heard, and the throw's arc landing where
## it aims. Quits with the number of failed checks as the exit code (0 means everything passed).

const MAP_SCENE := preload("res://maps/test_map.tscn")
const BOT_SCENE := preload("res://bots/bot.tscn")
const RIFLE := preload("res://weapons/rifle.tres")
const SNIPER := preload("res://weapons/sniper.tres")
const PISTOL := preload("res://weapons/pistol.tres")
const KNIFE := preload("res://weapons/knife.tres")
const FRAG := preload("res://weapons/frag.tres")

var _failures: int = 0


func _ready() -> void:
	Weapon.silent = true
	await _run_all()
	if _failures == 0:
		print("\nAll checks passed.")
	else:
		print("\n%d check(s) FAILED." % _failures)
	get_tree().quit(_failures)


func _run_all() -> void:
	await _test_plans()
	await _test_purchases()
	_add_box(Vector3(0, -0.5, 0), Vector3(80, 1, 80))
	_add_box(Vector3(0, 2, -20.5), Vector3(20, 4, 1))
	await _bake_navigation()
	await _test_pistol_switch()
	await _test_scope()
	await _test_pickup()
	await _test_grenade()
	await _test_throw_arc()


# --- Buying (in a real match) ---


func _test_plans() -> void:
	var rules := await _new_match()
	var pistol_round := BotBuyer.plan_for(rules, 1)
	rules.round_number = 3
	for member in rules.get_members(1):
		rules.add_money(member, 4000 - rules.get_money(member), "Test")
	var full := BotBuyer.plan_for(rules, 1)
	for member in rules.get_members(1):
		rules.add_money(member, 1500 - rules.get_money(member), "Test")
	var eco := BotBuyer.plan_for(rules, 1)
	rules.score[0] = rules.settings.rounds_to_win - 1
	var force := BotBuyer.plan_for(rules, 1)
	_check("The team's plan: a pistol round first, a full buy with $4,000 each, a save with $1,500, a force buy when a team is on match point",
			pistol_round == BotBuyer.Plan.PISTOL and full == BotBuyer.Plan.FULL and eco == BotBuyer.Plan.ECO and force == BotBuyer.Plan.FORCE,
			"%s %s %s %s" % [pistol_round, full, eco, force])
	_remove(rules)


func _test_purchases() -> void:
	var rules := await _new_match()
	# The first freeze time is a pistol round: the bots have already shopped.
	var by_class := {}
	for bot in rules.get_members(1):
		by_class[bot.class_data.id] = bot
	var scout: Character = by_class.get(&"scout")
	var others_vest := rules.get_members(1).filter(func(b: Character) -> bool: return b.class_data.id != &"scout").all(
			func(b: Character) -> bool: return b.armor == 100.0)
	_check("A pistol round: the Scout buys a Hornet, the others a vest (the Marksman a Verdict too)",
			scout != null and scout.inventory.get_in_slot(WeaponData.Slot.PRIMARY) != null
					and scout.inventory.get_in_slot(WeaponData.Slot.PRIMARY).data.id == &"smg" and others_vest,
			"classes %s" % [by_class.keys()])
	# A full buy in freeze time, with plenty of money.
	await _wait_for_live(rules)
	for member in rules.get_members(1):
		member.take_damage(500.0, Hitbox.Zone.CHEST, null)
	await _wait_for_phase(rules, RoundManager.Phase.FREEZE)
	for member in rules.get_members(1):
		member.inventory.set_loadout([KNIFE, PISTOL] as Array[WeaponData])
		member.set_armor(0.0, false)
		rules.add_money(member, 6000 - rules.get_money(member), "Test")
	BotBuyer.buy_for_team(rules, 1, RandomNumberGenerator.new())
	var lines: Array[String] = []
	var rifles_ok := true
	for bot in rules.get_members(1):
		var primary := bot.inventory.get_in_slot(WeaponData.Slot.PRIMARY)
		var id: StringName = primary.data.id if primary != null else &"none"
		lines.append("%s: %s, armor %.0f%s, $%d" % [bot.class_data.id, id, bot.armor, " + helmet" if bot.has_helmet else "", rules.get_money(bot)])
		rifles_ok = rifles_ok and primary != null and bot.has_helmet
		if bot.class_data.id == &"marksman":
			rifles_ok = rifles_ok and id == &"sniper"
		if bot.class_data.id == &"rifleman":
			rifles_ok = rifles_ok and id == &"rifle"
	var kits := rules.get_members(1).filter(func(b: Character) -> bool: return b.has_defuse_kit).size()
	var defending := rules.get_side(1) == Teams.Side.DEFENDING
	_check("A full buy: each class its gun (the Marksman the Heron, the Rifleman the Ram), a vest and a helmet, kits for defenders",
			rifles_ok and (kits > 0) == (defending and rules.bomb != null), "; ".join(lines) + "; kits %d" % kits)
	_remove(rules)


# --- Using the arsenal (a flat floor) ---


func _test_pistol_switch() -> void:
	var bot := await _add_bot(Vector3(0, 0, 10))
	bot.inventory.set_loadout([KNIFE, PISTOL, RIFLE] as Array[WeaponData])
	var rifle := bot.inventory.get_in_slot(WeaponData.Slot.PRIMARY)
	rifle.magazine = 0
	rifle.reserve = 0
	await _wait_seconds(1.5)
	_check("A bot whose rifle is empty takes out its pistol", bot.weapon != null and bot.weapon.data.id == &"pistol",
			"in hand %s" % (bot.weapon.data.id if bot.weapon else &"none"))
	bot.queue_free()
	await _wait_ticks(2)


func _test_scope() -> void:
	var bot := await _add_bot(Vector3(0, 0, 15))
	(bot.get_node("BotController") as BotController).hold_position = true
	bot.inventory.set_loadout([KNIFE, PISTOL, SNIPER] as Array[WeaponData])
	var enemy := await _add_target(Vector3(0, 0, -5), 0)
	enemy.god_mode = true
	bot.aim_at(enemy.get_chest_position())
	var first_shot_scoped := [null]
	var heron := bot.inventory.get_in_slot(WeaponData.Slot.PRIMARY)
	heron.fired.connect(func(_n: int) -> void:
		if first_shot_scoped[0] == null:
			first_shot_scoped[0] = heron.zoom_level > 0 or heron.get("_rezoom_level") > 0)
	await _wait_seconds(3.0)
	_check("A bot scopes the Heron and shoots it only scoped", first_shot_scoped[0] == true,
			"first shot scoped: %s" % first_shot_scoped[0])
	bot.queue_free()
	enemy.queue_free()
	await _wait_ticks(2)


func _test_pickup() -> void:
	var bot := await _add_bot(Vector3(10, 0, 0))
	bot.inventory.set_loadout([KNIFE, PISTOL] as Array[WeaponData])
	var marker := Marker3D.new()
	marker.position = Vector3(25, 0, 25)
	marker.add_to_group(BotController.PATROL_GROUP)
	add_child(marker)
	WeaponPickup.spawn(self, RIFLE, 30, 90, Vector3(16, 0.5, 2), 0.0)
	await _wait_seconds(5.0)
	var primary := bot.inventory.get_in_slot(WeaponData.Slot.PRIMARY)
	_check("A bot goes for a better gun lying near it and takes it", primary != null and primary.data.id == &"rifle",
			"primary %s" % (primary.data.id if primary else &"none"))
	bot.queue_free()
	marker.queue_free()
	await _wait_ticks(2)


func _test_grenade() -> void:
	var bot := await _add_bot(Vector3(-5, 0, -2))
	bot.inventory.set_loadout([KNIFE, PISTOL, RIFLE, FRAG] as Array[WeaponData])
	(bot.get_node("BotController") as BotController).set("_grenade_wait", 0.0)
	var enemy := await _add_target(Vector3(-5, 0, -24), 0)
	enemy.god_mode = true
	await _wait_ticks(2)
	# The bot hears the enemy behind the wall (a gunshot from there), 22 m away.
	Noises.make_noise(enemy.global_position + Vector3.UP, Noises.GUNSHOT_RANGE, enemy)
	var thrown := [false]
	get_tree().node_added.connect(func(node: Node) -> void:
		if node is Grenade:
			thrown[0] = true)
	var ticks := 0
	while not thrown[0] and ticks < 128 * 6:
		await _wait_ticks(1)
		ticks += 1
	await _wait_seconds(1.0)
	_check("A bot searching for an enemy it heard throws its frag that way", thrown[0] and bot.inventory.get_grenades().is_empty(),
			"thrown %s after %.1f s" % [thrown[0], ticks / 128.0])
	bot.queue_free()
	enemy.queue_free()
	await _wait_seconds(2.5)


func _test_throw_arc() -> void:
	var from := Vector3(20, 1.6, 20)
	var misses: Array[String] = []
	var ok := true
	for target in [Vector3(20, 0.3, 8), Vector3(32, 0.3, 20), Vector3(5, 0.3, 28)]:
		var aim := BotController.throw_aim(from, target, FRAG.throw_speed)
		var velocity := Grenade.throw_velocity(aim, FRAG.throw_speed, Vector3.ZERO)
		var dud := WeaponData.new()
		dud.id = &"dud"
		var grenade := Grenade.throw(self, dud, from, velocity, null)
		var landed := Vector3.INF
		var falling := false
		for i in 400:
			await _wait_ticks(1)
			if grenade.velocity.y < 0.0:
				falling = true
			elif falling or grenade.resting:
				# The first bounce: where it touched the floor.
				landed = grenade.global_position
				break
		var miss := Vector2(landed.x - target.x, landed.z - target.z).length()
		misses.append("%.1f m" % miss)
		ok = ok and miss < 1.5
		grenade.queue_free()
	_check("A bot's throw lands where it aims (12–18 m away, first touch within 1.5 m)", ok, ", ".join(misses))


# --- Helpers ---


func _new_match() -> RoundManager:
	var map := MAP_SCENE.instantiate()
	map.get_node("Player").free()
	add_child(map)
	var rules := RoundManager.new()
	var settings := MatchSettings.new()
	settings.freeze_time = 1.0
	settings.round_time = 60.0
	settings.round_end_time = 0.3
	rules.settings = settings
	rules.rng.seed = 4
	map.add_child(rules)
	await _wait_ticks(4)
	for bot in rules.get_participants():
		bot.footstep_sound = null
	return rules


func _remove(rules: RoundManager) -> void:
	var map := rules.get_parent()
	remove_child(map)
	map.queue_free()
	await _wait_ticks(2)


func _add_bot(spot: Vector3) -> Character:
	var bot: Character = BOT_SCENE.instantiate()
	bot.position = spot
	bot.footstep_sound = null
	bot.team = 1
	(bot.get_node("BotController") as BotController).rng.seed = 3
	add_child(bot)
	await _wait_ticks(3)
	return bot


## A character that just stands at [param spot] on [param team]: no brain.
func _add_target(spot: Vector3, team: int) -> Character:
	var target: Character = BOT_SCENE.instantiate()
	target.get_node("BotController").free()
	target.get_node("BotSenses").free()
	target.team = team
	target.position = spot
	target.footstep_sound = null
	add_child(target)
	await _wait_ticks(2)
	return target


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


func _bake_navigation() -> void:
	var region := NavigationRegion3D.new()
	region.navigation_mesh = load("res://maps/test_map_navmesh.tres").duplicate()
	add_child(region)
	await _wait_ticks(2)
	region.bake_navigation_mesh(false)
	await _wait_ticks(10)


func _wait_for_live(rules: RoundManager) -> void:
	await _wait_for_phase(rules, RoundManager.Phase.LIVE)


func _wait_for_phase(rules: RoundManager, phase: RoundManager.Phase) -> void:
	var ticks := 0
	while rules.phase != phase and ticks < 128 * 20:
		await get_tree().physics_frame
		ticks += 1


func _wait_seconds(seconds: float) -> void:
	await _wait_ticks(ceili(seconds * Engine.physics_ticks_per_second) + 1)


func _wait_ticks(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _check(check_name: String, passed: bool, detail: String) -> void:
	print("%s  %s: %s" % ["PASS" if passed else "FAIL", check_name, detail])
	if not passed:
		_failures += 1
