extends Node
## Automated arsenal checks (M7 task 2, D-090, D-091). Run without a window:
##
##     Godot --headless --path . --fixed-fps 128 --quit-after 60000 res://tests/arsenal_test.tscn
##
## Checks the eleven weapon data files (every path loads, ids match the file names and are
## unique, slots, categories, the numbers every gun needs, the rifle's unchanged M2 values),
## [Armor] against the CS reference cases (which gun's headshot kills through a helmet, how much
## health and armor one hit costs, the Bulwark's perk factors), and that the committed balancing
## table docs/weapons.csv still equals [method WeaponTable.csv_text], so it can't drift from the
## data (when it fails, run tools/export_weapon_table.gd). Needs no scene: it only loads
## resources. Quits with the number of failed checks as the exit code (0 means everything passed).

const CSV_PATH := "res://docs/weapons.csv"
const EXPORT_COMMAND := "/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --quit-after 100 --script res://tools/export_weapon_table.gd"

var _failures: int = 0
## Every weapon by id, loaded from [constant WeaponData.PATHS].
var _weapons: Dictionary = {}


func _ready() -> void:
	_run_all()
	if _failures == 0:
		print("\nAll checks passed.")
	else:
		print("\n%d check(s) FAILED." % _failures)
	get_tree().quit(_failures)


func _run_all() -> void:
	_test_files()
	_test_slots_and_categories()
	_test_numbers()
	_test_rifle_is_unchanged()
	_test_armor_reference_cases()
	_test_armor_formulas()
	_test_table_math()
	_test_csv_file()
	_test_csv_content()
	_test_models_and_icons()


func _test_files() -> void:
	var loaded_ok := WeaponData.PATHS.size() == 11
	var ids_ok := true
	var detail := ""
	var seen: Dictionary = {}
	for path in WeaponData.PATHS:
		var data := load(path) as WeaponData
		if data == null:
			loaded_ok = false
			detail += " %s does not load as WeaponData;" % path
			continue
		var base_name := path.get_file().get_basename()
		if data.id != StringName(base_name):
			ids_ok = false
			detail += " %s has id '%s';" % [path, data.id]
		if seen.has(data.id):
			ids_ok = false
			detail += " id '%s' is used twice;" % data.id
		seen[data.id] = true
		_weapons[data.id] = data
	_check("WeaponData.PATHS lists 11 files that all load as WeaponData", loaded_ok,
			"%d paths%s" % [WeaponData.PATHS.size(), detail])
	_check("Every weapon's id equals its file's base name, and the ids are unique", ids_ok and seen.size() == 11,
			"%d distinct ids%s" % [seen.size(), detail])
	var all := WeaponData.all()
	var order_ok := all.size() == WeaponData.PATHS.size()
	for i in mini(all.size(), WeaponData.PATHS.size()):
		order_ok = order_ok and all[i] != null and all[i].resource_path == WeaponData.PATHS[i]
	_check("WeaponData.all() gives the weapons in PATHS order and find() finds one by id",
			order_ok and WeaponData.find(&"sniper") == _weapons.get(&"sniper") and WeaponData.find(&"nothing") == null,
			"%d weapons" % all.size())


func _test_slots_and_categories() -> void:
	var wanted_slots := {
		&"rifle": WeaponData.Slot.PRIMARY, &"carbine": WeaponData.Slot.PRIMARY,
		&"smg": WeaponData.Slot.PRIMARY, &"shotgun": WeaponData.Slot.PRIMARY,
		&"sniper": WeaponData.Slot.PRIMARY,
		&"pistol": WeaponData.Slot.PISTOL, &"hand_cannon": WeaponData.Slot.PISTOL,
		&"knife": WeaponData.Slot.KNIFE,
		&"frag": WeaponData.Slot.GRENADE, &"flashbang": WeaponData.Slot.GRENADE,
		&"smoke": WeaponData.Slot.GRENADE,
	}
	var slots_ok := true
	var detail := ""
	for id in wanted_slots:
		var data := _weapon(id)
		if data == null or data.slot != wanted_slots[id]:
			slots_ok = false
			detail += " %s is in slot %s;" % [id, data.slot if data != null else "?"]
	_check("The rifle, carbine, SMG, shotgun and sniper are primaries, the pistol and hand cannon pistols, the knife the knife and the three grenades grenades",
			slots_ok, detail if detail != "" else "all 11 slots as wanted")
	var grenades_ok := true
	var melee_ids: Array[StringName] = []
	var scope_ids: Array[StringName] = []
	for data: WeaponData in _weapons.values():
		if data.slot == WeaponData.Slot.GRENADE:
			grenades_ok = grenades_ok and data.category == WeaponData.Category.GRENADE and data.is_grenade()
		else:
			grenades_ok = grenades_ok and data.category != WeaponData.Category.GRENADE and not data.is_grenade()
		if data.is_melee():
			melee_ids.append(data.id)
		if data.has_scope():
			scope_ids.append(data.id)
	_check("Every GRENADE-slot weapon has the grenade category (and no other weapon has)", grenades_ok, "")
	_check("Only the knife is melee, and only the sniper has a scope",
			melee_ids == [&"knife"] and scope_ids == [&"sniper"], "melee %s, scoped %s" % [melee_ids, scope_ids])


func _test_numbers() -> void:
	var guns_ok := true
	var detail := ""
	for data: WeaponData in _weapons.values():
		if data.is_grenade() or data.is_melee():
			continue
		var gun_ok: bool = data.magazine_size > 0 and data.fire_rate_rpm > 0.0 and data.reload_time > 0.0 \
				and data.draw_time > 0.0 and data.armor_penetration > 0.0 and data.armor_penetration <= 1.0 \
				and data.price > 0
		if not gun_ok:
			guns_ok = false
			detail += " %s (magazine %d, %s rpm, reload %s, draw %s, penetration %s, price %d);" % [data.id,
					data.magazine_size, data.fire_rate_rpm, data.reload_time, data.draw_time,
					data.armor_penetration, data.price]
	_check("Every gun has a magazine, a fire rate, reload and draw times, a penetration in (0, 1] and a price",
			guns_ok, detail if detail != "" else "all 7 guns")
	var knife := _weapon(&"knife")
	_check("The knife is never sold (price 0) and pays $500 for a kill (D-090)",
			knife != null and knife.price == 0 and knife.kill_reward == 500,
			"price %d, reward %d" % [knife.price, knife.kill_reward] if knife != null else "no knife")
	var shotgun := _weapon(&"shotgun")
	_check("The shotgun fires 9 pellets and loads shell by shell",
			shotgun != null and shotgun.pellets == 9 and shotgun.reload_per_shell,
			"%d pellets, per shell %s" % [shotgun.pellets, shotgun.reload_per_shell] if shotgun != null else "no shotgun")
	var semi_ok := true
	for id in [&"pistol", &"hand_cannon", &"shotgun", &"sniper"]:
		var data := _weapon(id)
		semi_ok = semi_ok and data != null and not data.automatic
	_check("The pistol, hand cannon, shotgun and sniper are not automatic", semi_ok, "")
	var flashbang := _weapon(&"flashbang")
	_check("A player can carry 2 flashbangs", flashbang != null and flashbang.max_carried == 2,
			"max_carried %d" % flashbang.max_carried if flashbang != null else "no flashbang")


func _test_rifle_is_unchanged() -> void:
	var rifle := _weapon(&"rifle")
	if rifle == null:
		_check("The rifle keeps its M2 numbers", false, "no rifle")
		return
	var ok := is_equal_approx(rifle.damage, 36.0) and is_equal_approx(rifle.fire_rate_rpm, 600.0) \
			and rifle.magazine_size == 30 and rifle.reserve_ammo == 90 \
			and is_equal_approx(rifle.reload_time, 2.5) and is_equal_approx(rifle.max_speed_units, 215.0) \
			and rifle.spray_pattern.size() == 30
	_check("The rifle keeps its M2 numbers: damage 36, 600 rpm, 30 + 90 rounds, reload 2.5 s, 215 u/s, a 30-entry spray",
			ok, "damage %s, %s rpm, %d + %d, reload %s, %s u/s, %d entries" % [rifle.damage, rifle.fire_rate_rpm,
			rifle.magazine_size, rifle.reserve_ammo, rifle.reload_time, rifle.max_speed_units, rifle.spray_pattern.size()])


func _test_armor_reference_cases() -> void:
	var head := Hitbox.Zone.HEAD
	var head_multiplier: float = Hitbox.MULTIPLIERS[head]
	# A rifle headshot at point-blank range: 36 * 4 * 0.775 = 111.6.
	var rifle := _weapon(&"rifle")
	var rifle_hit := Armor.apply(rifle.damage_at(0.0) * head_multiplier, rifle.armor_penetration, 100.0, true, head)
	_check("A rifle headshot (36 x 4 x 0.775 = 111.6) kills through a helmet",
			_near(rifle_hit.health, 111.6) and rifle_hit.health >= 100.0,
			"%.2f damage to health" % rifle_hit.health)
	var carbine := _weapon(&"carbine")
	var carbine_hit := Armor.apply(carbine.damage_at(0.0) * head_multiplier, carbine.armor_penetration, 100.0, true, head)
	_check("A carbine headshot (33 x 4 x 0.7 = 92.4) doesn't kill through a helmet",
			_near(carbine_hit.health, 92.4) and carbine_hit.health < 100.0,
			"%.2f damage to health" % carbine_hit.health)
	var cannon := _weapon(&"hand_cannon")
	var cannon_hit := Armor.apply(cannon.damage_at(0.0) * head_multiplier, cannon.armor_penetration, 100.0, true, head)
	_check("A hand cannon headshot kills through a helmet", cannon_hit.health >= 100.0,
			"%.2f damage to health" % cannon_hit.health)
	var pistol := _weapon(&"pistol")
	var pistol_bare := Armor.apply(pistol.damage_at(0.0) * head_multiplier, pistol.armor_penetration, 0.0, false, head)
	var pistol_helmet := Armor.apply(pistol.damage_at(0.0) * head_multiplier, pistol.armor_penetration, 100.0, true, head)
	_check("A pistol headshot kills without a helmet but not with one",
			pistol_bare.health >= 100.0 and pistol_helmet.health < 100.0,
			"%.2f without, %.2f with a helmet" % [pistol_bare.health, pistol_helmet.health])
	var sniper := _weapon(&"sniper")
	var chest_multiplier: float = Hitbox.MULTIPLIERS[Hitbox.Zone.CHEST]
	var sniper_hit := Armor.apply(sniper.damage_at(0.0) * chest_multiplier, sniper.armor_penetration, 100.0, false, Hitbox.Zone.CHEST)
	_check("A sniper body shot (chest) kills through armor", sniper_hit.health >= 100.0,
			"%.2f damage to health" % sniper_hit.health)


func _test_armor_formulas() -> void:
	_check("Legs are never covered, even with armor and a helmet",
			not Armor.covers(Hitbox.Zone.LEGS, 100.0, true), "")
	_check("A head hit without a helmet isn't covered, with one it is; the chest is covered by any armor but not by none",
			not Armor.covers(Hitbox.Zone.HEAD, 100.0, false) and Armor.covers(Hitbox.Zone.HEAD, 100.0, true)
			and Armor.covers(Hitbox.Zone.CHEST, 1.0, false) and not Armor.covers(Hitbox.Zone.CHEST, 0.0, true), "")
	var hit := Armor.apply(36.0, 0.775, 100.0, false, Hitbox.Zone.CHEST)
	_check("A rifle hit on the chest (36 damage, penetration 0.775, 100 armor) costs 27.9 health and 4.05 armor",
			_near(hit.health, 27.9) and _near(hit.armor, 100.0 - 4.05),
			"health %.3f, armor %.3f" % [hit.health, hit.armor])
	var worn_out := Armor.apply(100.0, 0.5, 10.0, false, Hitbox.Zone.CHEST)
	_check("A hit that would wear more than the armor left lets the rest through: 100 damage on 10 armor costs 80 health and all the armor",
			_near(worn_out.health, 80.0) and _near(worn_out.armor, 0.0),
			"health %.3f, armor %.3f" % [worn_out.health, worn_out.armor])
	var plated := Armor.apply(36.0, 0.775, 100.0, false, Hitbox.Zone.CHEST, 0.9, 0.7)
	_check("The Bulwark's Plated perk (0.9 damage, 0.7 wear) turns that hit into 27.9 x 0.9 health and 4.05 x 0.7 armor",
			_near(plated.health, 27.9 * 0.9) and _near(plated.armor, 100.0 - 4.05 * 0.7),
			"health %.3f, armor %.3f" % [plated.health, plated.armor])
	var legs_armored := Armor.apply(30.0, 0.5, 100.0, false, Hitbox.Zone.LEGS, 0.9, 0.7)
	var legs_bare := Armor.apply(30.0, 0.5, 0.0, false, Hitbox.Zone.LEGS, 0.9, 0.7)
	_check("The damage factor applies to a legs hit while there is armor (not covering them, not wearing it), and not at 0 armor",
			_near(legs_armored.health, 30.0 * 0.9) and _near(legs_armored.armor, 100.0) \
			and _near(legs_bare.health, 30.0) and _near(legs_bare.armor, 0.0),
			"with armor %.2f, without %.2f" % [legs_armored.health, legs_bare.health])


func _test_table_math() -> void:
	# The table counts shots with WeaponTable.shots_to_kill: for a one-pellet gun it must agree with
	# Armor.hits_to_kill, the game's own count.
	var agree := true
	var detail := ""
	for data: WeaponData in _weapons.values():
		if data.is_grenade() or data.is_melee() or data.pellets != 1:
			continue
		for distance in WeaponTable.DISTANCES:
			var damage := data.damage_at(distance)
			var bare := WeaponTable.shots_to_kill(data, distance, Hitbox.Zone.CHEST)
			var armored := WeaponTable.shots_to_kill(data, distance, Hitbox.Zone.CHEST, 100.0, true)
			if bare != Armor.hits_to_kill(damage, data.armor_penetration, Hitbox.Zone.CHEST) \
					or armored != Armor.hits_to_kill(damage, data.armor_penetration, Hitbox.Zone.CHEST, 100.0, 100.0, true):
				agree = false
				detail += " %s at %d m (%d / %d);" % [data.id, distance, bare, armored]
	_check("WeaponTable's shots to kill agrees with Armor.hits_to_kill for every one-pellet gun at 10 and 30 m",
			agree, detail if detail != "" else "all 6 one-pellet guns")


func _test_csv_file() -> void:
	var expected := WeaponTable.csv_text()
	if not FileAccess.file_exists(CSV_PATH):
		_check("docs/weapons.csv equals WeaponTable.csv_text()", false,
				"%s is missing: run %s" % [CSV_PATH, EXPORT_COMMAND])
		return
	var committed := FileAccess.get_file_as_string(CSV_PATH)
	var detail := "identical, %d bytes" % committed.length()
	if committed != expected:
		var committed_lines := committed.split("\n")
		var expected_lines := expected.split("\n")
		var line := 0
		while line < mini(committed_lines.size(), expected_lines.size()) and committed_lines[line] == expected_lines[line]:
			line += 1
		detail = "line %d differs (file has %d lines, the data gives %d); the file says '%s', the data '%s'. Re-run the export tool: %s" % [
				line + 1, committed_lines.size(), expected_lines.size(),
				committed_lines[line] if line < committed_lines.size() else "(nothing)",
				expected_lines[line] if line < expected_lines.size() else "(nothing)", EXPORT_COMMAND]
	_check("docs/weapons.csv equals WeaponTable.csv_text(), so the table matches the weapon files",
			committed == expected, detail)


func _test_csv_content() -> void:
	var text := WeaponTable.csv_text()
	var lines := text.trim_suffix("\n").split("\n")
	var header := lines[0].split(",")
	var fields_ok := true
	for line in lines:
		fields_ok = fields_ok and line.split(",").size() == header.size()
	_check("The CSV is one header plus 11 weapon lines, ends with a line break, and has a field for every column on every line",
			text.ends_with("\n") and lines.size() == 12 and header == WeaponTable.columns() and fields_ok,
			"%d lines, %d columns" % [lines.size(), header.size()])
	var rows := WeaponTable.rows()
	var rifle_row := _row(rows, &"rifle")
	var carbine_row := _row(rows, &"carbine")
	_check("The rifle's headshot kills through a helmet in the table (head_kill_helmet_10m = yes), the carbine's doesn't",
			rifle_row.get("head_kill_helmet_10m", "") == "yes" and carbine_row.get("head_kill_helmet_10m", "") == "no",
			"rifle '%s', carbine '%s'" % [rifle_row.get("head_kill_helmet_10m", "?"), carbine_row.get("head_kill_helmet_10m", "?")])
	var knife_row := _row(rows, &"knife")
	var smoke_row := _row(rows, &"smoke")
	_check("The knife's row lists only its slash damage among the derived columns, and a smoke grenade's has none",
			knife_row.get("body_damage_10m", "") == "40" and knife_row.get("dps_10m", "x") == ""
			and knife_row.get("reward_per_price", "x") == "" and smoke_row.get("body_damage_10m", "x") == "",
			"knife '%s', smoke '%s'" % [knife_row.get("body_damage_10m", "?"), smoke_row.get("body_damage_10m", "?")])


## The weapon with this id from the loaded files (null when it's missing).
func _weapon(id: StringName) -> WeaponData:
	return _weapons.get(id) as WeaponData


## The table row of the weapon with this id (empty when there is none).
func _row(rows: Array[Dictionary], id: StringName) -> Dictionary:
	for row in rows:
		if row["id"] == String(id):
			return row
	return {}


## True when two numbers differ by less than 0.01.
func _near(a: float, b: float) -> bool:
	return absf(a - b) < 0.01


## Every weapon has its generated model, buy-menu icon and kill-feed icon (D-092); the icons have
## the sizes the menus expect; the guns' muzzles sit at the front of their models.
func _test_models_and_icons() -> void:
	var missing: Array[String] = []
	var sizes_ok := true
	for data in WeaponData.all():
		if data.model == null or data.icon == null or data.kill_icon == null:
			missing.append(String(data.id))
			continue
		sizes_ok = sizes_ok and data.icon.get_size() == Vector2(128, 48) and data.kill_icon.get_height() == 16 \
				and data.kill_icon.get_width() <= 64
		var model := data.model.instantiate() as Node3D
		model.free()
	_check("Every weapon has its model, a 128 × 48 buy icon and a 16 px kill-feed icon", missing.is_empty() and sizes_ok,
			"missing: %s" % ", ".join(missing))
	var muzzles_ok := true
	for id in [&"rifle", &"carbine", &"smg", &"shotgun", &"sniper", &"pistol", &"hand_cannon"]:
		var data := WeaponData.find(id)
		muzzles_ok = muzzles_ok and data.muzzle_point.z < -0.1
	var kit := load("res://assets/models/weapons/defuse_kit.glb") as PackedScene
	var gear_icons := ResourceLoader.exists("res://assets/ui/weapons/armor.png") and ResourceLoader.exists("res://assets/ui/weapons/armor_helmet.png") \
			and ResourceLoader.exists("res://assets/ui/weapons/defuse_kit.png")
	_check("The guns' muzzles are in front of the grip; the defuse kit's model and the gear icons exist", muzzles_ok and kit != null and gear_icons,
			"muzzles %s, kit %s, gear icons %s" % [muzzles_ok, kit != null, gear_icons])


func _check(check_name: String, passed: bool, detail: String) -> void:
	print("%s  %s: %s" % ["PASS" if passed else "FAIL", check_name, detail])
	if not passed:
		_failures += 1
