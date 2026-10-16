extends Node
## Automated bomb checks (M8, D-080). Run without a window:
##
##     Godot --headless --path . --fixed-fps 128 --quit-after 100000 res://tests/bomb_test.tscn
##
## Plays short 3v3 matches on Depot with fast bomb timings. The bots are frozen
## once each round goes live, so they neither move nor shoot; the test moves
## you (the map's Player) around and holds the Use key through the real input
## path, and moves bots by respawning them where it needs them. Checks: a bomb
## only on maps with bomb sites, an attacker carries it from the round start,
## planting only inside a site and only in the live round, the plant locking
## movement and starting over when Use is let go, the round clock stopping at
## the plant, the explosion (who it hurts) and the round going to the
## attackers, dropping on death and picking up (attackers only), defusing (only
## next to the bomb, starting over when let go, the kit hook), the attackers'
## deaths not ending a planted round, the defenders' deaths ending it, and what
## the HUD shows for each step. Then bots-only matches check that bots play the
## objective (D-081): the carrier takes the bomb to the team's target site and
## plants it, the nearest attacker fetches a dropped bomb, attackers guard the
## planted bomb, defenders retake and defuse it while the others cover, and a
## defender only keeps defusing under fire when it is nearly done. Quits with
## the number of failed checks as the exit code.

const MAP_SCENE := preload("res://maps/depot.tscn")
const TEST_MAP_SCENE := preload("res://maps/test_map.tscn")
const HUD_SCENE := preload("res://ui/hud.tscn")
const PLANT_TIME := 1.0
const DEFUSE_TIME := 2.0
const KIT_DEFUSE_TIME := 1.0
const FUSE_TIME := 3.0

var _map: Node3D
var _rounds: RoundManager
var _player: Character
var _hud: Node
var _failures: int = 0
## [winner, reason] for every round_ended signal.
var _results: Array = []


func _ready() -> void:
	await _test_where_the_bomb_exists()
	await _test_carry_and_plant()
	await _test_explosion()
	await _test_drop_and_pickup()
	await _test_defuse()
	await _test_after_the_plant()
	await _test_bots_plant()
	await _test_bots_fetch()
	await _test_bots_retake()
	await _test_bots_stick()
	Input.action_release("use")
	if _failures == 0:
		print("\nAll checks passed.")
	else:
		print("\n%d check(s) FAILED." % _failures)
	get_tree().quit(_failures)


# --- The checks ---


func _test_where_the_bomb_exists() -> void:
	await _new_match(TEST_MAP_SCENE, 0, true)
	var on_test_map := _rounds.bomb
	await _new_match(MAP_SCENE, 0, true, false)
	var switched_off := _rounds.bomb
	await _new_match(MAP_SCENE, 0, true)
	_check("Only maps with bomb sites have a bomb (and not with bomb rounds off)",
			on_test_map == null and switched_off == null and _rounds.bomb != null and _rounds.bomb.is_in_group(Bomb.GROUP),
			"test map: %s, Depot with bomb rounds off: %s, Depot: %s" % [on_test_map, switched_off, _rounds.bomb])
	var bomb := _rounds.bomb
	var sites := bomb.get_sites()
	_check("The map's two bomb sites are found and switched on",
			sites.size() == 2 and sites.all(func(site: Area3D) -> bool: return site.monitoring),
			"%d sites: %s" % [sites.size(), ", ".join(sites.map(func(site: Area3D) -> String: return "%s (monitoring %s)" % [Bomb.site_letter(site), site.monitoring]))])
	var carrier := bomb.carrier
	_check("At the round start an attacker carries the bomb, on their back",
			bomb.state == Bomb.State.CARRIED and carrier != null and carrier.team == _rounds.attacking_team
			and bomb.attacking_team == _rounds.attacking_team
			and bomb.global_position.distance_to(carrier.global_transform * Bomb.BACK_OFFSET) < 0.01,
			"state %s, carrier %s (team %d, attackers %d)" % [Bomb.State.keys()[bomb.state], carrier, carrier.team if carrier else -1, _rounds.attacking_team])
	var side_line: String = _center()[1]
	_check("Freeze time says what to do in a bomb round",
			side_line == "You attack: plant the bomb at A or B" or side_line == "You defend: guard A and B", side_line)


func _test_carry_and_plant() -> void:
	await _new_match(MAP_SCENE, 0, true)
	var bomb := _rounds.bomb
	var site_a := _site("A")
	bomb.start_round(_player, _rounds.attacking_team)
	await _teleport(_player, _site_floor(site_a))
	Input.action_press("use")
	await _wait_seconds(0.3)
	_check("No planting in freeze time", bomb.state == Bomb.State.CARRIED and bomb.progress == 0.0 and not _player.busy,
			"phase %s, progress %.2f" % [RoundManager.Phase.keys()[_rounds.phase], bomb.progress])
	Input.action_release("use")
	await _go_live()
	await _wait_ticks(3)
	_check("Your HUD: the BOMB tag, and 'Hold E to plant' inside a site",
			_bomb_hud().is_carry_shown() and _bomb_hud().get_prompt() == "Hold E to plant",
			"tag %s, prompt '%s'" % [_bomb_hud().is_carry_shown(), _bomb_hud().get_prompt()])

	# Outside a site, Use does nothing.
	await _teleport(_player, _site_floor(site_a) + Vector3(0.0, 0.0, 9.0))
	Input.action_press("use")
	await _wait_seconds(0.3)
	_check("Outside a site, holding Use doesn't plant", bomb.progress == 0.0 and bomb.actor == null and not _player.busy,
			"progress %.2f, in a site: %s" % [bomb.progress, bomb.get_site_of(_player)])
	Input.action_release("use")

	# Half a plant, then let go.
	await _teleport(_player, _site_floor(site_a))
	Input.action_press("use")
	Input.action_press("move_forward")
	await _wait_seconds(PLANT_TIME * 0.5)
	var half := bomb.progress
	var speed := Vector2(_player.velocity.x, _player.velocity.z).length()
	_check("Planting: progress grows, you can't move, the HUD shows 'Planting' and the bar",
			absf(half - 0.5) < 0.05 and _player.busy and speed < 0.01 and bomb.is_planting(_player)
			and _bomb_hud().get_prompt() == "Planting" and absf(_bomb_hud().get_progress_shown() - half) < 0.05,
			"progress %.2f, busy %s, speed %.2f with W held, prompt '%s', bar %.2f" % [half, _player.busy, speed, _bomb_hud().get_prompt(), _bomb_hud().get_progress_shown()])
	Input.action_release("use")
	Input.action_release("move_forward")
	await _wait_ticks(2)
	_check("Letting go of Use stops the plant: progress back to 0, you can move again",
			bomb.progress == 0.0 and not _player.busy and bomb.state == Bomb.State.CARRIED,
			"progress %.2f, busy %s" % [bomb.progress, _player.busy])

	# A full plant.
	var time_before := _rounds.time_left
	var spot := _player.global_position
	Input.action_press("use")
	await _wait_seconds(PLANT_TIME + 0.1)
	Input.action_release("use")
	_check("Holding Use for the plant time plants the bomb at your feet, in site A",
			bomb.state == Bomb.State.PLANTED and bomb.site == site_a and bomb.carrier == null and not _player.busy
			and Vector2(bomb.global_position.x - spot.x, bomb.global_position.z - spot.z).length() < 0.4
			and absf(bomb.global_position.y - spot.y) < 0.2,
			"state %s, site %s, bomb at %s, you at %s" % [Bomb.State.keys()[bomb.state], Bomb.site_letter(bomb.site), bomb.global_position, spot])
	var at_plant := _rounds.time_left
	await _wait_seconds(0.5)
	await _wait_ticks(1)
	var round_hud := _hud.get_node("RoundHud") as RoundHud
	var plate := round_hud.get_node("%PlantedPlate") as Control
	_check("The plant stops the round clock; an alert plate saying 'Bomb' takes the timer's place and everyone is told the site",
			_rounds.time_left == at_plant and at_plant < time_before and _timer_text() == RoundHud.BOMB_TIMER_TEXT
			and plate.visible and not (round_hud.get_node("%Timer") as Control).visible
			and (plate.get_theme_stylebox("panel") as StyleBoxFlat).bg_color == round_hud.get_theme_color("alert", "Palette")
			and _bomb_hud().get_message() == "Bomb planted at A" and _rounds.phase == RoundManager.Phase.LIVE,
			"time %.2f → %.2f, timer '%s', message '%s'" % [at_plant, _rounds.time_left, _timer_text(), _bomb_hud().get_message()])


## Continues the round from [method _test_carry_and_plant]: the bomb is planted at A.
func _test_explosion() -> void:
	var bomb := _rounds.bomb
	var defenders := _rounds.get_members(_rounds.get_defending_team())
	var near := defenders[0]
	var far := defenders[1]
	await _teleport(near, bomb.global_position + Vector3(10.0, 0.0, 0.0))
	await _teleport(far, bomb.global_position + Vector3(28.0, 0.0, 0.0))
	await _teleport(_player, bomb.global_position + Vector3(0.0, 0.0, 1.5))
	var beeps := [0]
	bomb.beeped.connect(func() -> void: beeps[0] += 1)
	_results.clear()
	var waited := 0
	while bomb.state == Bomb.State.PLANTED and waited < 128 * 10:
		await _wait_ticks(1)
		waited += 1
	await _wait_ticks(2)
	_check("The fuse runs out and the bomb explodes, beeping faster and faster on the way",
			bomb.state == Bomb.State.EXPLODED and beeps[0] >= 5,
			"state %s after %.1f s, %d beeps" % [Bomb.State.keys()[bomb.state], waited / 128.0, beeps[0]])
	_check("The explosion wins the round for the attackers",
			_results.size() == 1 and _results[0] == [_rounds.attacking_team, RoundManager.EndReason.BOMB_EXPLODED]
			and _center()[1] == "The bomb exploded",
			"results %s, banner '%s'" % [_results, _center()[1]])
	_check("The blast kills you next to it and a defender 10 m away, but not one 28 m away",
			not _player.is_alive() and not near.is_alive() and far.is_alive() and far.health == far.max_health
			and bomb.get_blast_damage(10.0) > 100.0 and bomb.get_blast_damage(28.0) < 1.0,
			"you %.0f HP, 10 m: %.0f HP, 28 m: %.0f HP; damage at 10 m %.0f, 28 m %.2f"
					% [_player.health, near.health, far.health, bomb.get_blast_damage(10.0), bomb.get_blast_damage(28.0)])


func _test_drop_and_pickup() -> void:
	await _new_match(MAP_SCENE, 0, true)
	var bomb := _rounds.bomb
	await _go_live()
	var mates := _rounds.get_members(_player.team).filter(func(member: Character) -> bool: return member != _player)
	var carrier: Character = mates[0]
	bomb.start_round(carrier, _rounds.attacking_team)
	var spot := _site_floor(_site("B")) + Vector3(0.0, 0.0, 6.0)
	await _teleport(carrier, spot)
	carrier.take_damage(500.0, Hitbox.Zone.CHEST, null)
	await _wait_ticks(3)
	_check("A dying carrier drops the bomb on the floor where they fell; your team is told",
			bomb.state == Bomb.State.DROPPED and bomb.carrier == null
			and Vector2(bomb.global_position.x - spot.x, bomb.global_position.z - spot.z).length() < 0.2
			and absf(bomb.global_position.y - spot.y) < 0.2 and _bomb_hud().get_message() == "The bomb was dropped",
			"state %s at %s (died at %s), message '%s'" % [Bomb.State.keys()[bomb.state], bomb.global_position, spot, _bomb_hud().get_message()])
	_check("Attackers see the dropped bomb's marker", (bomb.get_node("Marker") as Label3D).visible, "")
	var defender := _rounds.get_members(_rounds.get_defending_team())[0]
	await _teleport(defender, bomb.global_position)
	await _wait_ticks(5)
	_check("A defender standing on it can't pick it up", bomb.state == Bomb.State.DROPPED, Bomb.State.keys()[bomb.state])
	await _teleport(defender, spot + Vector3(0.0, 0.0, 8.0))
	await _teleport(_player, bomb.global_position + Vector3(0.6, 0.0, 0.0))
	await _wait_ticks(3)
	_check("An attacker who walks over it picks it up",
			bomb.state == Bomb.State.CARRIED and bomb.carrier == _player and _bomb_hud().is_carry_shown()
			and _bomb_hud().get_message() == "You have the bomb",
			"state %s, carrier %s, message '%s'" % [Bomb.State.keys()[bomb.state], bomb.carrier, _bomb_hud().get_message()])


func _test_defuse() -> void:
	await _new_match(MAP_SCENE, 0, false)
	var bomb := _rounds.bomb
	await _go_live()
	var attackers := _rounds.get_members(_rounds.attacking_team)
	var site_b := _site("B")
	await _teleport(attackers[0], _site_floor(site_b))
	bomb.start_round(attackers[0], _rounds.attacking_team)
	# Long enough for the slow defuse steps below.
	_rounds.settings.bomb_fuse_time = 30.0
	bomb.plant(site_b, attackers[0])
	for attacker in attackers:
		attacker.take_damage(500.0, Hitbox.Zone.CHEST, null)
	await _wait_ticks(3)
	_check("With the bomb planted, killing every attacker doesn't end the round",
			_rounds.phase == RoundManager.Phase.LIVE and _results.is_empty() and bomb.is_planted(),
			"phase %s, results %s" % [RoundManager.Phase.keys()[_rounds.phase], _results])

	await _teleport(_player, bomb.global_position + Vector3(0.0, 0.0, 5.0))
	Input.action_press("use")
	await _wait_seconds(0.3)
	_check("Too far away, holding Use doesn't defuse", bomb.actor == null and bomb.progress == 0.0 and _bomb_hud().get_prompt() == "",
			"progress %.2f, prompt '%s'" % [bomb.progress, _bomb_hud().get_prompt()])
	Input.action_release("use")
	await _teleport(_player, bomb.global_position + Vector3(0.0, 0.0, 1.0))
	await _wait_ticks(2)
	var prompt: String = _bomb_hud().get_prompt()
	Input.action_press("use")
	await _wait_seconds(DEFUSE_TIME * 0.5)
	_check("Next to the bomb: 'Hold E to defuse', then defusing locks you in place and fills the bar",
			prompt == "Hold E to defuse" and bomb.is_defusing(_player) and _player.busy and absf(bomb.progress - 0.5) < 0.05
			and _bomb_hud().get_prompt() == "Defusing",
			"prompt before '%s', after '%s', progress %.2f, busy %s" % [prompt, _bomb_hud().get_prompt(), bomb.progress, _player.busy])
	Input.action_release("use")
	await _wait_ticks(2)
	_check("Letting go starts the defuse over", bomb.progress == 0.0 and bomb.actor == null and not _player.busy,
			"progress %.2f" % bomb.progress)
	var no_kit := bomb.get_defuse_time(_player)
	bomb.kit_check = func(defuser: Character) -> bool: return defuser == _player
	var with_kit := bomb.get_defuse_time(_player)
	bomb.kit_check = func(_defuser: Character) -> bool: return false
	_check("The defuse-kit hook: 2 s without a kit, 1 s with one (everyone has none until M7)",
			no_kit == DEFUSE_TIME and with_kit == KIT_DEFUSE_TIME, "%.1f s / %.1f s" % [no_kit, with_kit])
	Input.action_press("use")
	await _wait_seconds(DEFUSE_TIME + 0.1)
	Input.action_release("use")
	await _wait_ticks(2)
	_check("A full defuse wins the round for the defenders",
			bomb.state == Bomb.State.DEFUSED and _results == [[_rounds.get_defending_team(), RoundManager.EndReason.BOMB_DEFUSED]]
			and _center()[0] == "Round won" and _center()[1] == "The bomb was defused" and not _player.busy,
			"state %s, results %s, banner %s" % [Bomb.State.keys()[bomb.state], _results, _center()])


func _test_after_the_plant() -> void:
	await _new_match(MAP_SCENE, 0, false)
	var bomb := _rounds.bomb
	await _go_live()
	var planter := bomb.carrier
	bomb.plant(_site("A"), planter)
	for defender in _rounds.get_members(_rounds.get_defending_team()):
		defender.take_damage(500.0, Hitbox.Zone.CHEST, null)
	await _wait_ticks(3)
	_check("With the bomb planted, killing every defender wins the round for the attackers at once",
			_results == [[_rounds.attacking_team, RoundManager.EndReason.ELIMINATION]],
			str(_results))
	Input.action_press("use")
	await _teleport(_player, bomb.global_position + Vector3(0.5, 0.0, 0.0))
	await _wait_ticks(5)
	Input.action_release("use")
	_check("Once the round is over nobody can defuse (the bomb still ticks)",
			bomb.actor == null and bomb.is_planted(), "actor %s, state %s" % [bomb.actor, Bomb.State.keys()[bomb.state]])


# --- Bots and the objective ---


func _test_bots_plant() -> void:
	await _new_bot_match()
	var bomb := _rounds.bomb
	await _wait_for_live()
	# Leave one defender, frozen at the attackers' spawn: nobody meets it while the attackers take a site.
	var defenders := _rounds.get_members(_rounds.get_defending_team())
	defenders[0].take_damage(500.0, Hitbox.Zone.CHEST, null)
	defenders[1].take_damage(500.0, Hitbox.Zone.CHEST, null)
	defenders[2].frozen = true
	await _teleport(defenders[2], _marker_position(Teams.ATTACK_SPAWN_GROUP, 0))
	var carrier := bomb.carrier
	var target := (carrier.get_node("BotController") as BotController).get_target_site()
	var planted_at := [-1.0]
	bomb.planted.connect(func(_site: Area3D, _planter: Character) -> void: planted_at[0] = _rounds.settings.round_time - _rounds.time_left)
	await _wait_until(func() -> bool: return bomb.is_planted(), 40.0)
	_check("The carrier bot takes the bomb to its team's target site and plants it",
			bomb.is_planted() and target != null and bomb.site == target and planted_at[0] > 0.0 and planted_at[0] < 30.0,
			"planted %s at %s after %.1f s (target %s)" % [bomb.is_planted(), Bomb.site_letter(bomb.site), planted_at[0], Bomb.site_letter(target)])
	await _wait_seconds(10.0)
	var guards := _rounds.get_members(_rounds.attacking_team).filter(func(member: Character) -> bool: return member.is_alive())
	var distances := guards.map(func(member: Character) -> float: return _flat(member.global_position, bomb.global_position))
	_check("After the plant the attackers guard the bomb from a few metres away",
			guards.size() == 3 and distances.all(func(distance: float) -> bool: return distance <= BotController.GUARD_MAX * 1.3),
			"distances %s m" % [", ".join(distances.map(func(distance: float) -> String: return "%.1f" % distance))])


func _test_bots_fetch() -> void:
	await _new_bot_match()
	var bomb := _rounds.bomb
	await _wait_for_live()
	var first := bomb.carrier
	first.take_damage(500.0, Hitbox.Zone.CHEST, null)
	await _wait_until(func() -> bool: return bomb.state == Bomb.State.CARRIED and bomb.carrier != first, 8.0)
	_check("When the carrier dies, another attacker bot picks the bomb up",
			bomb.state == Bomb.State.CARRIED and bomb.carrier != first and bomb.carrier.team == _rounds.attacking_team,
			"state %s, carrier %s (first carrier %s)" % [Bomb.State.keys()[bomb.state], bomb.carrier, first.name])


func _test_bots_retake() -> void:
	await _new_bot_match()
	var bomb := _rounds.bomb
	await _wait_for_live()
	var attackers := _rounds.get_members(_rounds.attacking_team)
	var site_a := _site("A")
	await _teleport(attackers[0], _site_floor(site_a))
	bomb.start_round(attackers[0], _rounds.attacking_team)
	bomb.plant(site_a, attackers[0])
	for attacker in attackers:
		attacker.take_damage(500.0, Hitbox.Zone.CHEST, null)
	var covering := [0]
	await _wait_until(func() -> bool:
		if bomb.actor != null:
			# While one defuses, how many teammates stand close by?
			var near := _rounds.get_members(_rounds.get_defending_team()).filter(func(member: Character) -> bool:
				return member != bomb.actor and member.is_alive() and _flat(member.global_position, bomb.global_position) <= BotController.COVER_DISTANCE + 2.0)
			covering[0] = maxi(covering[0], near.size())
		return bomb.state != Bomb.State.PLANTED, 40.0)
	_check("Defender bots retake the planted bomb and defuse it; the others cover the defuser",
			bomb.state == Bomb.State.DEFUSED and _results == [[_rounds.get_defending_team(), RoundManager.EndReason.BOMB_DEFUSED]]
			and covering[0] >= 1,
			"state %s, results %s, at most %d teammates covering" % [Bomb.State.keys()[bomb.state], _results, covering[0]])


## A defender far into its defuse keeps going when an enemy shows up; early in it, it stops and fights.
func _test_bots_stick() -> void:
	for nearly_done in [true, false]:
		await _new_bot_match()
		var bomb := _rounds.bomb
		await _wait_for_live()
		var attackers := _rounds.get_members(_rounds.attacking_team)
		var site_a := _site("A")
		await _teleport(attackers[0], _site_floor(site_a))
		bomb.start_round(attackers[0], _rounds.attacking_team)
		bomb.plant(site_a, attackers[0])
		# One frozen attacker stays alive (it can't shoot) and waits out of sight.
		for attacker in attackers.slice(1):
			attacker.take_damage(500.0, Hitbox.Zone.CHEST, null)
		var enemy := attackers[0]
		enemy.frozen = true
		await _teleport(enemy, _marker_position(Teams.ATTACK_SPAWN_GROUP, 0))
		var defenders := _rounds.get_members(_rounds.get_defending_team())
		var defuser: Character = defenders[0]
		for other in defenders.slice(1):
			other.take_damage(500.0, Hitbox.Zone.CHEST, null)
		await _wait_until(func() -> bool: return bomb.actor == defuser, 20.0)
		var wanted := 0.8 if nearly_done else 0.2
		await _wait_until(func() -> bool: return bomb.progress >= wanted, 12.0)
		# The enemy steps out in front of the defuser, 6 m away.
		var view := Basis.from_euler(Vector3(0.0, defuser.get_aim_angles().x, 0.0))
		await _teleport(enemy, defuser.global_position + view * Vector3(0.0, 0.0, -6.0))
		await _wait_seconds(1.5)
		var state := (defuser.get_node("BotController") as BotController).state
		if nearly_done:
			_check("A defender 80% into the defuse keeps defusing when an enemy shows up",
					state == BotController.State.ENGAGE and (bomb.actor == defuser or bomb.state == Bomb.State.DEFUSED),
					"bot state %s, actor %s, bomb %s" % [BotController.State.keys()[state], bomb.actor, Bomb.State.keys()[bomb.state]])
		else:
			_check("A defender 20% into the defuse stops to fight an enemy who shows up",
					state == BotController.State.ENGAGE and bomb.actor == null and bomb.is_planted(),
					"bot state %s, actor %s, bomb %s" % [BotController.State.keys()[state], bomb.actor, Bomb.State.keys()[bomb.state]])


# --- Helpers ---


## A bots-only 3v3 on Depot (the map's Player removed), every bot seeded.
func _new_bot_match() -> void:
	_free_map()
	_results.clear()
	_map = MAP_SCENE.instantiate()
	_map.get_node("Player").free()
	add_child(_map)
	await _wait_ticks(30)
	var settings := MatchSettings.new()
	settings.freeze_time = 0.5
	settings.round_end_time = 2.0
	_rounds = RoundManager.new()
	_rounds.settings = settings
	_rounds.rng.seed = 3
	_rounds.round_ended.connect(func(winner: int, reason: RoundManager.EndReason) -> void: _results.append([winner, reason]))
	_map.add_child(_rounds)
	await _wait_ticks(2)
	var participants := _rounds.get_participants()
	for i in participants.size():
		_silence(participants[i])
		(participants[i].get_node("BotController") as BotController).rng.seed = i + 1
		participants[i].weapon.rng.seed = i + 1
	for property in ["beep_sound", "plant_sound", "defuse_sound", "explosion_sound"]:
		_rounds.bomb.set(property, null)


func _wait_for_live() -> void:
	await _wait_until(func() -> bool: return _rounds.phase == RoundManager.Phase.LIVE, 5.0)


## Waits until [param condition] is true, at most [param seconds].
func _wait_until(condition: Callable, seconds: float) -> void:
	var ticks := 0
	while not condition.call() and ticks < seconds * Engine.physics_ticks_per_second:
		await get_tree().physics_frame
		ticks += 1


func _marker_position(group: String, index: int) -> Vector3:
	var markers := get_tree().get_nodes_in_group(group).filter(func(node: Node) -> bool: return _map.is_ancestor_of(node))
	return (markers[index] as Node3D).global_position


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


## Starts a match on a fresh copy of [param scene] in which you attack (or
## defend), with fast bomb timings, a HUD, and every bot silenced.
func _new_match(scene: PackedScene, seed_start: int, you_attack: bool, bomb_rounds: bool = true) -> void:
	for attempt in 20:
		_free_map()
		_results.clear()
		_map = scene.instantiate()
		add_child(_map)
		_player = _map.get_node("Player")
		_silence(_player)
		var settings := MatchSettings.new()
		settings.freeze_time = 0.5
		settings.round_time = 60.0
		settings.round_end_time = 2.0
		settings.plant_time = PLANT_TIME
		settings.defuse_time = DEFUSE_TIME
		settings.kit_defuse_time = KIT_DEFUSE_TIME
		settings.bomb_fuse_time = FUSE_TIME
		settings.bomb_rounds = bomb_rounds
		_rounds = RoundManager.new()
		_rounds.settings = settings
		_rounds.rng.seed = seed_start + attempt
		_rounds.round_ended.connect(func(winner: int, reason: RoundManager.EndReason) -> void: _results.append([winner, reason]))
		_map.add_child(_rounds)
		await _wait_ticks(2)
		if (_rounds.attacking_team == _player.team) == you_attack:
			break
	for character in _rounds.get_participants():
		_silence(character)
	if _rounds.bomb != null:
		for property in ["beep_sound", "plant_sound", "defuse_sound", "explosion_sound"]:
			_rounds.bomb.set(property, null)
	Teams.set_viewer_team(_player.team)
	_hud = HUD_SCENE.instantiate()
	add_child(_hud)
	_hud.call("set_player", _player)
	_hud.call("set_round_manager", _rounds)


func _free_map() -> void:
	Input.action_release("use")
	if _hud != null:
		remove_child(_hud)
		_hud.queue_free()
		_hud = null
	if _map != null:
		remove_child(_map)
		_map.queue_free()
		_map = null


## Waits for the live phase, then freezes every bot, so none of them moves or shoots.
func _go_live() -> void:
	var ticks := 0
	while _rounds.phase != RoundManager.Phase.LIVE and ticks < 128 * 5:
		await get_tree().physics_frame
		ticks += 1
	for member in _rounds.get_participants():
		if member != _player:
			member.frozen = true


## Moves [param character] (alive, full health) to [param at] and waits until it stands there.
func _teleport(character: Character, at: Vector3) -> void:
	character.respawn(at, character.rotation.y)
	await _wait_ticks(4)


func _site(letter: String) -> Area3D:
	for site in _rounds.bomb.get_sites():
		if Bomb.site_letter(site) == letter:
			return site
	return null


## The floor at the middle of [param site] (its area stands 3 m tall on the floor).
func _site_floor(site: Area3D) -> Vector3:
	return site.global_position + Vector3.DOWN * 1.5


func _bomb_hud() -> BombHud:
	return _hud.get_node("BombHud") as BombHud


func _timer_text() -> String:
	return (_hud.get_node("RoundHud") as RoundHud).get_timer_text()


## The round HUD's center lines as [title, line 1, line 2, line 3]; a hidden line counts as empty.
func _center() -> Array:
	var lines := []
	for label_name in ["Title", "Line1", "Line2", "Line3"]:
		var label := _hud.get_node("RoundHud/Center/" + label_name) as Label
		lines.append(label.text if label.visible else "")
	return lines


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


func _wait_seconds(seconds: float) -> void:
	await _wait_ticks(roundi(seconds * Engine.physics_ticks_per_second))


func _wait_ticks(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _check(check_name: String, passed: bool, detail: String) -> void:
	print("%s  %s: %s" % ["PASS" if passed else "FAIL", check_name, detail])
	if not passed:
		_failures += 1
