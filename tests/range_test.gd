extends Node
## Automated checks for the Shooting Range, the practice map (M10, D-141, D-142). Run without a
## window:
##
##     Godot --headless --path . --fixed-fps 128 --quit-after 60000 res://tests/range_test.tscn
##
## The map scene: it starts practice with no bots, has no team spawns, and has its targets at
## 5, 10, 20 and 40 m (and a moving one), a gun stand for every gun, distance signs, bot spawns
## and patrol points, all reachable from where the player stands. Then the game (main.tscn,
## started the way the main menu's Practice does, never touching the real settings file): no
## bots at first; the console's bot_add, bot_difficulty and bot_kick add, change and remove them;
## a moving target moves; a taken gun comes back on its stand; the console lists the maps without
## the hidden test map, which still loads by name. Quits with the number of failed checks as the
## exit code.

const MAIN_SCENE := preload("res://main.tscn")
const TEST_MAP := "res://maps/test_map.tscn"
## The distances the static targets must cover, in metres (their titles start with them).
const DISTANCES: Array[String] = ["5 m", "10 m", "20 m", "40 m"]
## A marker counts as reachable when a path ends this close to it (metres).
const REACH := 0.8
## Bots appear at least this far from the player's start (metres).
const BOT_SPAWN_DISTANCE := 20.0

var _failures: int = 0
var _main: Node


func _ready() -> void:
	await _test_scene()
	await _test_practice()
	_free_main()
	GameLaunch.clear()
	MenuState.reset()
	await get_tree().process_frame
	if _failures == 0:
		print("\nAll checks passed.")
	else:
		print("\n%d check(s) FAILED." % _failures)
	get_tree().quit(_failures)


# --- The map scene ---


func _test_scene() -> void:
	var map := (load(Settings.DEFAULT_MAP) as PackedScene).instantiate() as Node3D
	var player := map.get_node_or_null("Player") as Character
	var has_player := player != null
	# The root stands at the origin, so the player's own position is where they start.
	var start := player.position if has_player else Vector3.ZERO
	if has_player:
		player.free()
	add_child(map)
	await _wait_for_navigation(map)

	var spawns := _in_map(map, Teams.ATTACK_SPAWN_GROUP).size() + _in_map(map, Teams.DEFEND_SPAWN_GROUP).size()
	_check("The range is a practice map: its scene starts practice with no bots, it has a player and no team spawns, and match setup doesn't offer it",
			int(map.get_meta(ArenaRules.START_BOTS_META, -1)) == 0 and has_player and spawns == 0
					and not GameLaunch.list_maps().has(Settings.DEFAULT_MAP),
			"practice_bots %s, player %s, team spawns %d" % [map.get_meta(ArenaRules.START_BOTS_META, "none"), has_player, spawns])

	var dummies: Array[TargetDummy] = []
	for node in map.find_children("*", "Node3D", true, false):
		if node is TargetDummy:
			dummies.append(node)
	var titles: Array[String] = []
	var moving := 0
	for dummy in dummies:
		titles.append(dummy.title)
		if dummy.move_distance > 0.0:
			moving += 1
	var missing_distances := DISTANCES.filter(func(distance: String) -> bool:
		return not titles.any(func(title: String) -> bool: return title.begins_with(distance + " ") or title == distance))
	_check("Targets stand at 5, 10, 20 and 40 m, and one moves (built from range_target entities)",
			missing_distances.is_empty() and moving >= 1, "%d targets %s, %d moving" % [dummies.size(), titles, moving])

	var stands: Array[KitWeaponStand] = []
	for node in map.find_children("*", "Node3D", true, false):
		if node is KitWeaponStand:
			stands.append(node)
	var on_stands: Array[StringName] = []
	for stand in stands:
		on_stands.append(stand.weapon_id)
	var untried: Array[String] = []
	for data in WeaponData.all():
		if data.id != &"knife" and not on_stands.has(data.id):
			untried.append(String(data.id))
	var spots_out := stands.filter(func(stand: KitWeaponStand) -> bool: return stand.get_spot() != null and stand.get_spot().has_weapon()).size()
	_check("Every gun of the arsenal (all but the knife you always carry) has a stand, and each stand has its gun out",
			untried.is_empty() and spots_out == stands.size() and not stands.is_empty(),
			"stands %s, missing %s, %d of %d out" % [on_stands, untried, spots_out, stands.size()])

	var sign_texts: Array[String] = []
	for node in map.find_children("*", "Label3D", true, false):
		if node is KitTextSign:
			sign_texts.append((node as KitTextSign).text)
	var unsigned := DISTANCES.filter(func(distance: String) -> bool: return not sign_texts.has(distance))
	var bot_hint := sign_texts.any(func(text: String) -> bool: return text.contains("bot_add") and text.contains("bot_kick"))
	_check("Signs mark the distances (5, 10, 20, 40 m) and tell how to add bots with the console",
			unsigned.is_empty() and bot_hint, "%d signs, distances without one %s, bot hint %s" % [sign_texts.size(), unsigned, bot_hint])

	var bot_spawns := _in_map(map, ArenaRules.BOT_SPAWN_GROUP)
	var patrols := _in_map(map, "patrol_points")
	var player_spawns := _in_map(map, ArenaRules.PLAYER_SPAWN_GROUP)
	var unreachable: Array[String] = []
	var too_close: Array[String] = []
	for marker in bot_spawns + patrols:
		var at := (marker as Node3D).global_position
		var path := NavigationServer3D.map_get_path(map.get_world_3d().navigation_map, start, at, true)
		if path.is_empty() or path[path.size() - 1].distance_to(at) > REACH:
			unreachable.append(String(marker.name))
		if marker in bot_spawns and Vector2(at.x, at.z).distance_to(Vector2(start.x, start.z)) < BOT_SPAWN_DISTANCE:
			too_close.append(String(marker.name))
	_check("Bots have 6 or more spawns at least 20 m from the player and 6 or more patrol points, all reachable from where the player stands; the player has no spawn points (comes back where they started)",
			bot_spawns.size() >= 6 and patrols.size() >= 6 and unreachable.is_empty() and too_close.is_empty() and player_spawns.is_empty(),
			"%d bot spawns, %d patrol points, unreachable %s, too close %s, player spawns %d" % [bot_spawns.size(), patrols.size(), unreachable, too_close, player_spawns.size()])
	remove_child(map)
	map.free()
	await get_tree().physics_frame


# --- Practice on it ---


func _test_practice() -> void:
	GameLaunch.start_practice(Settings.DEFAULT_MAP, GameLaunch.difficulty_named("normal"))
	_main = MAIN_SCENE.instantiate()
	# Never read or write the player's real settings file.
	_main.load_settings = false
	add_child(_main)
	for i in 10:
		await get_tree().physics_frame
	var map := _main.get_map() as Node3D
	var arena := map.get_node_or_null("ArenaRules") as ArenaRules
	var console := _main.get_node("DevConsole") as DevConsole
	var player := map.get_node("Player") as Character
	_check("Practice plays the range with no bots, no rounds and no random map weapons",
			arena != null and arena.get_bots().is_empty() and map.get_node_or_null("RoundManager") == null
					and get_tree().get_nodes_in_group(WeaponSpot.GROUP).size() == _count_stand_spots(map),
			"arena %s, bots %d" % [arena != null, arena.get_bots().size() if arena != null else -1])
	if arena == null:
		return

	console.run("bot_add hard enemy")
	console.run("bot_add easy ally")
	await get_tree().physics_frame
	var bots := arena.get_bots()
	var enemy: Character = bots[0] if bots.size() > 0 else null
	var ally: Character = bots[1] if bots.size() > 1 else null
	var far := bots.all(func(bot: Character) -> bool: return bot.global_position.distance_to(player.global_position) >= BOT_SPAWN_DISTANCE)
	_check("The console adds bots: bot_add hard enemy and bot_add easy ally give a hard enemy and an easy teammate, away from the player",
			bots.size() == 2 and enemy.team != player.team and ally.team == player.team and far
					and _difficulty(enemy) == "hard" and _difficulty(ally) == "easy",
			"%d bots: %s" % [bots.size(), bots.map(func(bot: Character) -> String: return "%s team %d %s at %.0f m" % [bot.name, bot.team, _difficulty(bot), bot.global_position.distance_to(player.global_position)])])
	console.run("bot_difficulty normal")
	console.run("bot_add")
	await get_tree().physics_frame
	bots = arena.get_bots()
	var all_normal := bots.all(func(bot: Character) -> bool: return _difficulty(bot) == "normal")
	_check("bot_difficulty normal makes every bot normal, and the next bot_add (no arguments) is a normal enemy",
			bots.size() == 3 and all_normal and bots[2].team != player.team, "%d bots, all normal %s" % [bots.size(), all_normal])
	console.run("bot_kick")
	await get_tree().physics_frame
	var after_one := arena.get_bots().size()
	console.run("bot_kick all")
	await get_tree().physics_frame
	_check("bot_kick removes the newest bot, bot_kick all the rest", after_one == 2 and arena.get_bots().is_empty(),
			"after bot_kick %d, after bot_kick all %d" % [after_one, arena.get_bots().size()])

	var mover: TargetDummy = null
	for node in map.find_children("*", "Node3D", true, false):
		if node is TargetDummy and (node as TargetDummy).move_distance > 0.0:
			mover = node
			break
	var before := mover.global_position if mover != null else Vector3.ZERO
	for i in 64:
		await get_tree().physics_frame
	_check("A moving target moves (half a second later it stands elsewhere)",
			mover != null and mover.global_position.distance_to(before) > 0.3,
			"moved %.2f m" % (mover.global_position.distance_to(before) if mover != null else -1.0))

	# Take a gun from its stand: it's gone, then back after the stand's refill time.
	var stand: KitWeaponStand = null
	for node in map.find_children("*", "Node3D", true, false):
		if node is KitWeaponStand and (node as KitWeaponStand).weapon_id == &"smg":
			stand = node
			break
	var primary := player.inventory.get_in_slot(WeaponData.Slot.PRIMARY)
	if primary != null:
		player.inventory.remove(primary)
	var taken: Weapon = null
	if stand != null and stand.get_spot() != null:
		taken = player.inventory.take(stand.get_spot().get_pickup())
	await get_tree().physics_frame
	var gone := stand != null and stand.get_spot() == null
	for i in int((stand.refill_time if stand != null else 0.0) * 128.0) + 32:
		await get_tree().physics_frame
	var back := stand != null and stand.get_spot() != null and stand.get_spot().has_weapon() and stand.get_spot().weapon.id == &"smg"
	_check("Taking the Hornet from its stand gives it to you; the stand is empty, and the gun is back after its refill time",
			taken != null and taken.data.id == &"smg" and gone and back, "taken %s, gone %s, back %s" % [taken.data.id if taken != null else "nothing", gone, back])

	# The console lists the maps without the hidden test map, which still loads by name.
	console.run("map")
	var listing := ""
	for line in console.get_visible_lines():
		if line.begins_with("Maps: "):
			listing = line
	_check("The console's map list has the quick maps and the range, not the hidden test map",
			listing.contains("depot") and listing.contains("shooting_range") and not listing.contains("test_map"), listing)
	console.run("map test_map")
	for i in 5:
		await get_tree().physics_frame
	var loaded: String = _main.get_map().scene_file_path
	console.run("map shooting_range")
	for i in 5:
		await get_tree().physics_frame
	var again := _main.get_map().get_node_or_null("ArenaRules") as ArenaRules
	for i in 5:
		await get_tree().physics_frame
	_check("map test_map still loads the hidden test map, and map shooting_range comes back to an empty range",
			loaded == TEST_MAP and _main.get_map().scene_file_path == Settings.DEFAULT_MAP and again != null and again.get_bots().is_empty(),
			"loaded %s, then %s with %d bots" % [loaded, _main.get_map().scene_file_path, again.get_bots().size() if again != null else -1])


# --- Helpers ---


func _difficulty(bot: Character) -> String:
	return (bot.get_node("BotController") as BotController).difficulty.display_name


## How many stands of [param map] have their gun out (all the weapon spots there are, when
## nothing else puts guns out).
func _count_stand_spots(map: Node) -> int:
	var count := 0
	for node in map.find_children("*", "Node3D", true, false):
		if node is KitWeaponStand and (node as KitWeaponStand).get_spot() != null:
			count += 1
	return count


func _in_map(map: Node, group: String) -> Array[Node]:
	return get_tree().get_nodes_in_group(group).filter(func(node: Node) -> bool: return map.is_ancestor_of(node))


func _wait_for_navigation(map: Node3D) -> void:
	var region := map.find_children("*", "NavigationRegion3D", true, false)[0] as NavigationRegion3D
	var nav := map.get_world_3d().navigation_map
	var synced_from := -1
	for i in 120:
		await get_tree().physics_frame
		var regions := NavigationServer3D.map_get_regions(nav)
		if regions.size() != 1 or regions[0] != region.get_rid():
			continue
		if synced_from < 0:
			synced_from = NavigationServer3D.map_get_iteration_id(nav)
		elif NavigationServer3D.map_get_iteration_id(nav) >= synced_from + 2:
			return


func _free_main() -> void:
	if _main != null:
		remove_child(_main)
		_main.queue_free()
		_main = null
	MenuState.reset()


func _check(check_name: String, passed: bool, detail: String) -> void:
	print("%s  %s: %s" % ["PASS" if passed else "FAIL", check_name, detail])
	if not passed:
		_failures += 1
