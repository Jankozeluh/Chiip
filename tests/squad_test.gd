extends Node3D
## Automated checks for the bots' team play (M15, D-216, D-217; [BotSquad]). Run without a window:
##
##     Godot --headless --path . --fixed-fps 128 --quit-after 200000 res://tests/squad_test.tscn
##
## On an 80 × 80 m floor with a long wall across it (a gap at one end), with a [RoundManager] that isn't
## playing rounds (the live phase is set by hand) so its wiring is the real one:
## - Trades: when a teammate dies, the two nearest free bots go for where the killer stood and look there; a
##   third close one doesn't (at most two), nor one 14 m away in a straight line but behind the wall (too far
##   to walk), nor one fighting an enemy. After a few seconds without finding anyone they're back to orders.
## - Callouts: a bot that spots an enemy calls it out once (the manager's callout signal: its team, "Enemy
##   spotted south" as seen from it), and not again within six seconds; a free teammate gets the lead and
##   goes, a teammate in a fight keeps its own, an enemy bot near the place gets nothing. Near a bomb site the
##   text names the site ("near A").
## - Spreading: of two bots answering one call, the second goes to a point to the side first (then on to the
##   place); the second and third take opposite sides; a side point behind a wall (a long detour) isn't used.
##
## Every random number is seeded. Quits with the number of failed checks as the exit code (0 means everything passed).

const BOT_SCENE := preload("res://bots/bot.tscn")
## Where the wall stands: across the map at z = 0 from x = -40 to x = WALL_END (the gap is beyond it).
const WALL_END := 28.0
## Far from everything, behind the wall: where an enemy goes to be out of the way.
const AWAY := Vector3(35, 0, -35)

var _failures: int = 0
var _manager: RoundManager
## The manager's callouts so far: [team, text] each.
var _callouts: Array[Array] = []
## The characters of the current check, freed by [method _clear].
var _cast: Array[Character] = []


func _ready() -> void:
	Weapon.silent = true
	_add_box(Vector3(0, -0.5, 0), Vector3(80, 1, 80))
	_add_box(Vector3((WALL_END - 40.0) / 2.0, 2, -0.5), Vector3(WALL_END + 40.0, 4, 1))
	await _bake_navigation()
	_manager = RoundManager.new()
	_manager.autostart = false
	_manager.settings = MatchSettings.new()
	_manager.callout.connect(func(team: int, text: String) -> void: _callouts.append([team, text]))
	add_child(_manager)
	_manager.phase = RoundManager.Phase.LIVE
	await _wait_ticks(4)
	await _run_all()
	if _failures == 0:
		print("\nAll checks passed.")
	else:
		print("\n%d check(s) FAILED." % _failures)
	get_tree().quit(_failures)


func _run_all() -> void:
	await _test_trade()
	await _test_callouts()
	await _test_spreading()


func _test_trade() -> void:
	var killer := await _add_target(Vector3(-10, 0, 8), 1)
	var victim := await _add_target(Vector3(-10, 0, 14), 0)
	var looking_south := Vector3(0, 1.5, 40)
	var first := await _add_bot(Vector3(-4, 0, 14), looking_south, 0, 1)
	var second := await _add_bot(Vector3(-16, 0, 16), looking_south, 0, 2)
	var third := await _add_bot(Vector3(-10, 0, 22), looking_south, 0, 3)
	var walled := await _add_bot(Vector3(-10, 0, -6), Vector3(-30, 1.5, -40), 0, 4)
	var enemy := await _add_target(Vector3(-30, 0, 10), 1)
	var fighting := await _add_bot(Vector3(-20, 0, 10), enemy.get_chest_position(), 0, 5, true, false)
	var ticks := 0
	while _brain(fighting).state != BotController.State.ENGAGE and ticks < 3 * 128:
		await _wait_ticks(1)
		ticks += 1
	var spot := killer.global_position
	victim.take_damage(1000.0, Hitbox.Zone.CHEST, killer)
	var answered := [first, second, third, walled, fighting].filter(func(bot: Character) -> bool:
		return _brain(bot).state == BotController.State.SEARCH and _senses(bot).last_known_position.is_equal_approx(spot))
	_check("A teammate killed: the two nearest free bots go for where the killer stood",
			answered == [first, second] and _flat(_target_of(first), spot) < 0.5,
			"answered: %s; the first heads %.1f m from the spot" % [_names(answered), _flat(_target_of(first), spot)])
	_check("... not a third one close by (two at most), nor one behind the wall (14 m away, a long walk)",
			_brain(third).state == BotController.State.PATROL and not _senses(third).has_lead() and not _senses(walled).has_lead(),
			"third: state %d, lead %s; behind the wall: lead %s" % [_brain(third).state, _senses(third).has_lead(), _senses(walled).has_lead()])
	_check("... nor one in a fight: it keeps fighting its own enemy",
			_brain(fighting).state == BotController.State.ENGAGE and _flat(_senses(fighting).last_known_position, enemy.global_position) < 1.0,
			"state %d, lead %.1f m from its enemy" % [_brain(fighting).state, _flat(_senses(fighting).last_known_position, enemy.global_position)])
	var side_point := _target_of(second)
	_check("Spreading: the second to answer goes to a point to the side first, not down the same line",
			_flat(side_point, spot) > BotSquad.FLANK_OFFSET * 0.5 and side_point.x < spot.x,
			"%.1f m from the spot, on its own (west) side: %s" % [_flat(side_point, spot), side_point.x < spot.x])
	# The killer gets away; nobody else is around to find.
	killer.global_position = AWAY
	fighting.queue_free()
	enemy.queue_free()
	var went_on := false
	ticks = 0
	while ticks < roundi((BotSquad.ANSWER_TIME + 1.0) * 128):
		await _wait_ticks(1)
		ticks += 1
		went_on = went_on or _flat(_target_of(second), spot) < 0.5
	_check("... and then on to the place itself", went_on, "")
	_check("After a few seconds with nobody there, both are back to their orders",
			_brain(first).state == BotController.State.PATROL and _brain(second).state == BotController.State.PATROL,
			"states %d and %d" % [_brain(first).state, _brain(second).state])
	# The killer stays in the match (far away), so a team is never wiped out and no round ends.
	_cast.erase(killer)
	await _clear()


func _test_callouts() -> void:
	var enemy := await _add_target(Vector3(-10, 0, 20), 1)
	var fighting := await _add_bot(Vector3(0, 0, 20), enemy.get_chest_position(), 0, 6, true, false)
	var free := await _add_bot(Vector3(18, 0, 16), Vector3(18, 1.5, -40), 0, 7, true)
	var other_team := await _add_bot(Vector3(30, 0, 26), Vector3(60, 1.5, 26), 1, 8)
	var ticks := 0
	while _brain(fighting).state != BotController.State.ENGAGE and ticks < 3 * 128:
		await _wait_ticks(1)
		ticks += 1
	_callouts.clear()
	var caller := await _add_bot(Vector3(10, 0, 20), Vector3(10, 1.5, 40), 0, 9, true)
	var calls := [0]
	_brain(caller).called_out.connect(func(_where: Vector3) -> void: calls[0] += 1)
	var spotted := await _add_target(Vector3(10, 0, 32), 1)
	ticks = 0
	while _callouts.is_empty() and ticks < 3 * 128:
		await _wait_ticks(1)
		ticks += 1
	var spot := spotted.global_position
	_check("A bot that spots an enemy calls it out to its team, with where (seen from it: south)",
			_callouts.size() == 1 and _callouts[0] == [0, BotSquad.DIRECTION_TEXT % "south"], str(_callouts))
	_check("... a free teammate gets the lead and goes there",
			_brain(free).state == BotController.State.SEARCH and _flat(_senses(free).last_known_position, spot) < 0.5
			and _flat(_target_of(free), spot) < 0.5,
			"state %d, lead %.1f m from the enemy" % [_brain(free).state, _flat(_senses(free).last_known_position, spot)])
	_check("... a teammate in a fight keeps its own lead",
			_brain(fighting).state == BotController.State.ENGAGE and _flat(_senses(fighting).last_known_position, enemy.global_position) < 1.0,
			"state %d" % _brain(fighting).state)
	var heard_it := _senses(other_team).has_lead() and _flat(_senses(other_team).last_known_position, spot) < 1.0
	_check("... an enemy bot close to the place doesn't hear it", not heard_it, "lead at the place: %s" % heard_it)
	# Spotting again (seen anew) within six seconds: no new callout; after them, one.
	_spot_again(caller, spotted)
	var after_one: int = calls[0]
	await _wait_ticks(roundi((BotSquad.CALLOUT_WAIT + 0.2) * 128))
	_spot_again(caller, spotted)
	_check("One callout per bot every six seconds at most", after_one == 1 and calls[0] == 2,
			"%d right after the first, %d six seconds later" % [after_one, calls[0]])
	var site := Area3D.new()
	site.name = "BombSiteA"
	site.add_to_group(Bomb.SITE_GROUP)
	add_child(site)
	site.global_position = spot + Vector3(4, 0, 4)
	var near_text := BotSquad.callout_text(spot, self, caller)
	var far_text := BotSquad.callout_text(spot + Vector3(-30, 0, 18), self, caller)
	site.free()
	_check("Near a bomb site the callout names it; farther away a compass direction",
			near_text == BotSquad.SITE_TEXT % "A" and far_text == BotSquad.DIRECTION_TEXT % "south-west",
			"'%s', '%s'" % [near_text, far_text])
	await _clear()


func _test_spreading() -> void:
	var point := Vector3(0, 0, 20)
	var lead_from := Vector3(0, 0, 35)
	var east := await _add_target(Vector3(6, 0, 34), 0)
	var flanks: Array[Vector3] = []
	for rank in 3:
		flanks.append(BotSquad.flank_point(east, point, lead_from, rank))
	_check("The first goes straight in; the second to its own side, the third to the other side",
			flanks[0] == point and flanks[1].x > point.x + 3.5 and flanks[2].x < point.x - 3.5,
			"%s" % [flanks])
	var by_wall := Vector3(0, 0, 2)
	var walker := await _add_target(Vector3(-14, 0, 1.5), 0)
	var behind := BotSquad.flank_point(walker, by_wall, Vector3(-15, 0, 2), 1)
	_check("A side point behind the wall (a long way round) isn't used: straight in instead",
			behind == by_wall, "%s" % behind)
	await _clear()


# --- Helpers ---


## A bot of [param team] at [param spot] looking at [param look_at_point], holding its place unless it gets a
## lead. A [param slow] one takes ages to react, so it fights (engages) without ever firing. One not
## [param in_match] has no callouts (the manager passes them on), so the enemy it fights doesn't send its
## teammates away before a check.
func _add_bot(spot: Vector3, look_at_point: Vector3, team: int, seed: int, slow: bool = false, in_match: bool = true) -> Character:
	var bot: Character = BOT_SCENE.instantiate()
	bot.name = "Bot%d" % seed
	bot.position = spot
	bot.team = team
	bot.footstep_sound = null
	var brain: BotController = bot.get_node("BotController")
	var difficulty := (load("res://bots/difficulty_normal.tres") as BotDifficulty).duplicate() as BotDifficulty
	difficulty.team_play = 1.0
	difficulty.wallbang_chance = 0.0
	if slow:
		difficulty.reaction_time = 1000.0
	brain.difficulty = difficulty
	brain.rng.seed = seed
	brain.hold_position = true
	add_child(bot)
	bot.weapon.rng.seed = seed
	if in_match:
		_manager._join(bot)
	_cast.append(bot)
	await _wait_ticks(2)
	bot.aim_at(look_at_point)
	return bot


## A character of [param team] that just stands at [param spot] (no brain), in the match.
func _add_target(spot: Vector3, team: int) -> Character:
	var target: Character = BOT_SCENE.instantiate()
	target.get_node("BotController").free()
	target.get_node("BotSenses").free()
	target.team = team
	target.position = spot
	target.footstep_sound = null
	add_child(target)
	_manager._join(target)
	_cast.append(target)
	await _wait_ticks(2)
	return target


## Makes [param caller] see [param enemy] anew, as if it had lost and found it.
func _spot_again(caller: Character, enemy: Character) -> void:
	_brain(caller).state = BotController.State.PATROL
	_senses(caller).enemy_spotted.emit(enemy)


## Frees this check's characters.
func _clear() -> void:
	for character in _cast:
		if is_instance_valid(character):
			character.queue_free()
	_cast.clear()
	await _wait_ticks(2)


func _brain(bot: Character) -> BotController:
	return bot.get_node("BotController")


func _senses(bot: Character) -> BotSenses:
	return bot.get_node("BotSenses")


## Where [param bot] is walking to.
func _target_of(bot: Character) -> Vector3:
	return (bot.get_node("NavigationAgent3D") as NavigationAgent3D).target_position


func _names(characters: Array) -> String:
	return ", ".join(characters.map(func(character: Character) -> String: return String(character.name)))


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _wait_ticks(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _check(check_name: String, passed: bool, detail: String) -> void:
	print("%s  %s: %s" % ["PASS" if passed else "FAIL", check_name, detail])
	if not passed:
		_failures += 1


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


## Bakes a navigation mesh for the level, with the same settings as the test map. Baked before the region
## enters the tree: a region baked in place kept giving the navigation map its old polygons.
func _bake_navigation() -> void:
	var mesh := load("res://maps/test_map_navmesh.tres").duplicate() as NavigationMesh
	var source := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(mesh, source, self)
	NavigationServer3D.bake_from_source_geometry_data(mesh, source)
	var region := NavigationRegion3D.new()
	region.navigation_mesh = mesh
	add_child(region)
	await _wait_ticks(4)
