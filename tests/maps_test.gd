extends Node
## Automated checks for the quick maps (M8, D-049). Run without a window:
##
##     Godot --headless --path . --fixed-fps 128 --quit-after 400000 res://tests/maps_test.tscn
##
## Add [code]-- --map res://maps/depot.tscn[/code] to check one map only.
##
## For every map in [constant MAPS]: checks that it has everything a match, the
## bots and the later modes need (spawns, attack routes, hold spots, bomb sites,
## respawn points, patrol points), that every marker stands on the navigation
## mesh, and that both spawns can walk to both bomb sites. Then it plays a seeded
## bots-only 3v3 on the map and measures the time from the round going live to
## first contact (the first bot to notice an enemy), which should be 5–10 s,
## and how rounds end. The rounds are bomb rounds (D-080), so it also counts
## the bots' plants, explosions and defuses (D-081). Quits with the number of
## failed checks as the exit code.

const MAPS: Array[String] = ["res://maps/depot.tscn", "res://maps/square.tscn", "res://maps/spillway.tscn"]
## Rounds to play on each map.
const ROUNDS_TO_PLAY := 4
## First contact should come this many seconds after the round goes live (D-049).
const CONTACT_MIN := 5.0
const CONTACT_MAX := 10.0
## A marker counts as on the navigation mesh within this distance (metres).
const ON_MESH_DISTANCE := 0.8

var _map: Node3D
var _rounds: RoundManager
var _failures: int = 0
var _live_ticks: int = 0
## Per round: {"contact": s or -1, "damage": s or -1, "length": s, "reason": EndReason,
## and "plant": "A at 23 s" if the bomb was planted}.
var _results: Array[Dictionary] = []
## Plants over all maps, and rounds won by the bomb (exploded or defused).
var _plants_total: int = 0
var _bomb_endings_total: int = 0
var _current: Dictionary = {}


func _ready() -> void:
	var maps := MAPS
	var args := OS.get_cmdline_user_args()
	var map_arg := args.find("--map")
	if map_arg >= 0 and map_arg + 1 < args.size():
		maps = [args[map_arg + 1]]
	for path in maps:
		await _check_map(path)
	if maps.size() == MAPS.size():
		_check("Bots play the objective: they plant in some rounds, and some rounds end with the bomb",
				_plants_total >= 2 and _bomb_endings_total >= 1,
				"%d plants, %d rounds ended by the bomb exploding or being defused, over %d rounds" % [_plants_total, _bomb_endings_total, ROUNDS_TO_PLAY * MAPS.size()])
	if _failures == 0:
		print("\nAll checks passed.")
	else:
		print("\n%d check(s) FAILED." % _failures)
	get_tree().quit(_failures)


func _physics_process(_delta: float) -> void:
	if _rounds != null and _rounds.phase == RoundManager.Phase.LIVE:
		_live_ticks += 1


func _check_map(path: String) -> void:
	print("\n=== %s ===" % path)
	_map = (load(path) as PackedScene).instantiate()
	var has_player := _map.get_node_or_null("Player") is Character
	if has_player:
		_map.get_node("Player").free()
	add_child(_map)
	await _wait_for_navigation()
	_check_structure(has_player)
	_check_on_mesh()
	_check_reachable()
	await _play_rounds()
	_rounds = null
	_map.queue_free()
	await get_tree().physics_frame


func _check_structure(has_player: bool) -> void:
	var routes := _in_map(BotTactics.ROUTE_GROUP)
	var short_routes := routes.filter(func(route: Node) -> bool: return route.get_child_count() < 3).size()
	var sites := _in_map("bomb_sites")
	var areas := sites.filter(func(site: Node) -> bool: return site is Area3D).size()
	var counts := {
		"defend spawns": _in_map(Teams.DEFEND_SPAWN_GROUP).size(),
		"attack spawns": _in_map(Teams.ATTACK_SPAWN_GROUP).size(),
		"attack routes": routes.size(),
		"hold spots": _in_map(BotTactics.HOLD_GROUP).size(),
		"bomb sites": areas,
		"respawn points": _in_map("respawn_points").size(),
		"patrol points": _in_map(BotController.PATROL_GROUP).size(),
	}
	var detail := ", ".join(counts.keys().map(func(key: String) -> String: return "%d %s" % [counts[key], key]))
	_check("Has a Player, 5 spawns per side, 3 routes, 5+ hold spots, 2 bomb sites, 8+ respawn and patrol points",
			has_player and counts["defend spawns"] == 5 and counts["attack spawns"] == 5 and counts["attack routes"] == 3
			and short_routes == 0 and counts["hold spots"] >= 5 and counts["bomb sites"] == 2
			and counts["respawn points"] >= 8 and counts["patrol points"] >= 8,
			detail + (", %d routes with < 3 points" % short_routes if short_routes > 0 else ""))


func _check_on_mesh() -> void:
	var markers: Array[Node3D] = []
	for group in [Teams.DEFEND_SPAWN_GROUP, Teams.ATTACK_SPAWN_GROUP, BotTactics.HOLD_GROUP, "respawn_points", BotController.PATROL_GROUP]:
		for node in _in_map(group):
			markers.append(node as Node3D)
	for route in _in_map(BotTactics.ROUTE_GROUP):
		for point in route.get_children():
			markers.append(point as Node3D)
	var off: Array[String] = []
	for marker in markers:
		var closest := NavigationServer3D.map_get_closest_point(_navigation_map(), marker.global_position)
		var gap := Vector2(closest.x - marker.global_position.x, closest.z - marker.global_position.z).length()
		if gap > ON_MESH_DISTANCE or absf(closest.y - marker.global_position.y) > 1.0:
			off.append("%s (%.1f m off)" % [_map.get_path_to(marker), gap])
	_check("Every marker stands on the navigation mesh", off.is_empty(),
			"%d markers checked%s" % [markers.size(), "; off: " + ", ".join(off) if not off.is_empty() else ""])


func _check_reachable() -> void:
	var lines: Array[String] = []
	var reachable := true
	for group in [Teams.ATTACK_SPAWN_GROUP, Teams.DEFEND_SPAWN_GROUP]:
		var start := (_in_map(group)[2] as Node3D).global_position
		for site in _in_map("bomb_sites"):
			# The site's area stands 3 m tall on its floor; probe at floor level, not on the crates.
			var floor_centre := (site as Node3D).global_position + Vector3.DOWN * 1.5
			var goal := NavigationServer3D.map_get_closest_point(_navigation_map(), floor_centre)
			var nav_path := NavigationServer3D.map_get_path(_navigation_map(), start, goal, true)
			var ok := not nav_path.is_empty() and nav_path[-1].distance_to(goal) < 1.0
			reachable = reachable and ok
			lines.append("%s → %s: %s" % [group.trim_suffix("_spawns"), site.name.trim_prefix("BombSite"),
					"%.0f m" % _path_length(nav_path) if ok else "NO PATH"])
	_check("Both spawns can walk to both bomb sites", reachable, ", ".join(lines))


func _play_rounds() -> void:
	var settings := MatchSettings.new()
	settings.freeze_time = 0.5
	settings.round_end_time = 0.5
	settings.rounds_to_win = 15
	_rounds = RoundManager.new()
	_rounds.settings = settings
	_rounds.rng.seed = 7
	_results.clear()
	_rounds.phase_changed.connect(func(phase: RoundManager.Phase) -> void:
		if phase == RoundManager.Phase.LIVE:
			_live_ticks = 0
			_current = {"contact": -1.0, "damage": -1.0})
	_rounds.round_ended.connect(func(_winner: int, reason: RoundManager.EndReason) -> void:
		_current["length"] = _live_ticks / 128.0
		_current["reason"] = reason
		_results.append(_current.duplicate()))
	_map.add_child(_rounds)
	for i in 2:
		await get_tree().physics_frame
	if _rounds.bomb != null:
		for property in ["beep_sound", "plant_sound", "defuse_sound", "explosion_sound"]:
			_rounds.bomb.set(property, null)
		_rounds.bomb.planted.connect(func(site: Area3D, _planter: Character) -> void:
			_current["plant"] = "%s at %.0f s" % [Bomb.site_letter(site), _live_ticks / 128.0])
	var participants := _rounds.get_participants()
	for i in participants.size():
		var character := participants[i]
		_silence(character)
		(character.get_node("BotController") as BotController).rng.seed = i + 1
		character.weapon.rng.seed = i + 1
		(character.get_node("BotSenses") as BotSenses).enemy_spotted.connect(func(enemy: Character) -> void:
			if _mark("contact"):
				_current["where"] = "%s %s at (%.0f, %.0f) saw %s at (%.0f, %.0f)" % [
						_side_name(character), character.name, character.global_position.x, character.global_position.z,
						enemy.name, enemy.global_position.x, enemy.global_position.z])
		character.damaged.connect(func(_amount: float, _zone: Hitbox.Zone, _attacker: Character) -> void: _mark("damage"))
	var ticks := 0
	while _results.size() < ROUNDS_TO_PLAY and ticks < 128 * 130 * ROUNDS_TO_PLAY:
		await get_tree().physics_frame
		ticks += 1
	var contacts: Array[float] = []
	var lines: Array[String] = []
	var decided := 0
	for result in _results:
		contacts.append(result["contact"])
		if result["reason"] != RoundManager.EndReason.TIME:
			decided += 1
		if result.has("plant"):
			_plants_total += 1
		if result["reason"] == RoundManager.EndReason.BOMB_EXPLODED or result["reason"] == RoundManager.EndReason.BOMB_DEFUSED:
			_bomb_endings_total += 1
		lines.append("contact %.1f s, first hit %.1f s, round %.0f s (%s%s): %s" % [result["contact"], result["damage"], result["length"],
				RoundManager.EndReason.keys()[result["reason"]].to_lower(), ", planted " + result["plant"] if result.has("plant") else "",
				result.get("where", "no contact")])
	print("  " + "\n  ".join(lines))
	contacts.sort()
	var median := (contacts[contacts.size() / 2] + contacts[(contacts.size() - 1) / 2]) / 2.0 if not contacts.is_empty() else -1.0
	_check("First contact %.0f–%.0f s after the round goes live (median of %d rounds)" % [CONTACT_MIN, CONTACT_MAX, ROUNDS_TO_PLAY],
			_results.size() == ROUNDS_TO_PLAY and median >= CONTACT_MIN and median <= CONTACT_MAX,
			"median %.1f s; every round: %s" % [median, ", ".join(contacts.map(func(c: float) -> String: return "%.1f" % c))])
	_check("Rounds are decided by fighting or the bomb, not by running out the clock",
			_results.size() == ROUNDS_TO_PLAY and decided >= ROUNDS_TO_PLAY - 1,
			"%d of %d rounds ended by elimination or the bomb" % [decided, _results.size()])


## Notes the live time of the first [param kind] event ("contact" or "damage")
## this round. Returns true if this was the first.
func _mark(kind: String) -> bool:
	if _rounds.phase == RoundManager.Phase.LIVE and _current.get(kind, 0.0) < 0.0:
		_current[kind] = _live_ticks / 128.0
		return true
	return false


func _side_name(character: Character) -> String:
	return "attacker" if character.team == _rounds.attacking_team else "defender"


# --- Helpers ---


## The navigation map takes a few physics frames to drop the previous map's
## mesh and pick up the new one; queries before that answer for the wrong mesh
## (or the origin). Waits until this map's region is the only one and the
## navigation map has synchronized twice since.
func _wait_for_navigation() -> void:
	var region := _map.find_children("*", "NavigationRegion3D", true, false)[0] as NavigationRegion3D
	var nav := _navigation_map()
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


func _in_map(group: String) -> Array[Node]:
	return get_tree().get_nodes_in_group(group).filter(func(node: Node) -> bool: return _map.is_ancestor_of(node))


func _navigation_map() -> RID:
	return _map.get_world_3d().navigation_map


func _path_length(nav_path: PackedVector3Array) -> float:
	var length := 0.0
	for i in range(1, nav_path.size()):
		length += nav_path[i - 1].distance_to(nav_path[i])
	return length


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


func _check(check_name: String, passed: bool, detail: String) -> void:
	print("%s  %s: %s" % ["PASS" if passed else "FAIL", check_name, detail])
	if not passed:
		_failures += 1
