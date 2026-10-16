extends Node3D
## Automated checks of the light economy (M7 tasks 10–12, D-098). Run without a window:
##
##     Godot --headless --path . --fixed-fps 128 --quit-after 100000 res://tests/economy_test.tscn
##
## Money in a real match on the test map with short timings: the starting money, round wins and
## losses with the growing loss money (and a win starting the count again), kill rewards by weapon
## (the knife's $500), the teamkill penalty, the cap, the plant and defuse money, the reset at half
## time, no money in team respawn; the HUD's money and reward lines, the Tab scoreboard's money
## column (your team only), and the console's money command. Quits with the number of failed checks.

const MAP_SCENE := preload("res://maps/test_map.tscn")
const MAIN_SCENE := preload("res://main.tscn")
const HUD_SCENE := preload("res://ui/hud.tscn")
const SCOREBOARD_SCENE := preload("res://ui/scoreboard.tscn")
const PISTOL := preload("res://weapons/pistol.tres")
const KNIFE := preload("res://weapons/knife.tres")

var _failures: int = 0
var _map: Node3D
var _rounds: RoundManager
var _player: Character


func _ready() -> void:
	Weapon.silent = true
	await _run_all()
	if _failures == 0:
		print("\nAll checks passed.")
	else:
		print("\n%d check(s) FAILED." % _failures)
	get_tree().quit(_failures)


func _run_all() -> void:
	await _test_round_money()
	await _test_kill_money()
	await _test_bomb_money_and_cap()
	await _test_half_time()
	await _test_no_money_in_team_respawn()
	await _test_hud_and_scoreboard()
	await _test_console()


func _test_round_money() -> void:
	await _new_match(_settings())
	var everyone := _rounds.get_participants()
	var start_ok := everyone.all(func(c: Character) -> bool: return _rounds.get_money(c) == 1000)
	_check("A match starts everyone with $1,000", start_ok and _rounds.has_economy(), "you: $%d" % _rounds.get_money(_player))
	var enemy: Character = _rounds.get_members(1)[0]
	await _win_round(0)
	var won := _rounds.get_money(_player) == 1000 + 3000 and _rounds.get_money(enemy) == 1000 + 1500
	await _win_round(0)
	var second := _rounds.get_money(enemy) == 2500 + 2000
	await _win_round(0)
	var third := _rounds.get_money(enemy) == 4500 + 2500
	await _win_round(1)
	var won_back := _rounds.get_money(enemy) == 7000 + 3000 and _rounds.get_loss_money(1) == 1500 and _rounds.get_loss_money(0) == 2000
	_check("A win pays $3,000; losses pay $1,500, $2,000, $2,500 in a row; a win starts the count again",
			won and second and third and won_back, "after round 1: you $%d, them $%d; their losses %s %s; after their win %s" % [
				_rounds.get_money(_player), _rounds.get_money(enemy), second, third, won_back])


func _test_kill_money() -> void:
	await _new_match(_settings())
	await _wait_for_live()
	var enemies := _rounds.get_members(1)
	var before := _rounds.get_money(_player)
	enemies[0].take_damage(500.0, Hitbox.Zone.CHEST, _player, 1.0, PISTOL)
	var pistol_kill := _rounds.get_money(_player) - before
	enemies[1].take_damage(500.0, Hitbox.Zone.CHEST, _player, 1.0, KNIFE)
	var knife_kill := _rounds.get_money(_player) - before - pistol_kill
	Teams.friendly_fire = true
	var mate: Character = _rounds.get_members(0)[1]
	var before_teamkill := _rounds.get_money(_player)
	mate.take_damage(500.0, Hitbox.Zone.CHEST, _player, 1.0, PISTOL)
	mate.take_damage(500.0, Hitbox.Zone.CHEST, _player, 1.0, PISTOL)
	mate.take_damage(500.0, Hitbox.Zone.CHEST, _player, 1.0, PISTOL)
	var teamkill := _rounds.get_money(_player) - before_teamkill
	Teams.friendly_fire = false
	_check("A kill pays $200 ($500 with the knife); killing a teammate costs $200",
			pistol_kill == 200 and knife_kill == 500 and teamkill == -200, "pistol +%d, knife +%d, teamkill %d" % [pistol_kill, knife_kill, teamkill])


func _test_bomb_money_and_cap() -> void:
	await _new_match(_settings())
	await _wait_for_live()
	var attackers := _rounds.get_members(_rounds.attacking_team)
	var defender: Character = _rounds.get_members(_rounds.get_defending_team())[0]
	var before: int = _rounds.get_money(attackers[0])
	_rounds._on_bomb_planted(null, attackers[0])
	var plant_ok := attackers.all(func(c: Character) -> bool: return _rounds.get_money(c) == before + 200)
	var defender_before := _rounds.get_money(defender)
	_rounds._on_bomb_defused(defender)
	# The defuse also wins the round: $200 for the defuse and $3,000 for the win.
	_check("A plant pays every attacker $200, a defuse the defuser $200 (and the round's $3,000)",
			plant_ok and _rounds.get_money(defender) == defender_before + 200 + 3000, "attacker $%d, defuser $%d" % [_rounds.get_money(attackers[0]), _rounds.get_money(defender)])
	_rounds.add_money(_player, 50000, "Test")
	_check("Nobody has more than $10,000", _rounds.get_money(_player) == 10000, "$%d" % _rounds.get_money(_player))


func _test_half_time() -> void:
	var settings := _settings()
	settings.rounds_to_win = 2
	await _new_match(settings)
	var seen := [0, 0]
	_rounds.round_ended.connect(func(_w: int, _r: RoundManager.EndReason) -> void: seen[0] = _rounds.get_money(_player))
	_rounds.sides_swapped.connect(func() -> void: seen[1] = _rounds.get_money(_player))
	await _win_round(0)
	_check("Half time puts everyone back to $1,000", seen[0] == 4000 and seen[1] == 1000 and _rounds.get_money(_player) == 1000,
			"after round 1 $%d, at the swap $%d" % [seen[0], seen[1]])


func _test_no_money_in_team_respawn() -> void:
	var settings := _settings()
	settings.game_mode = MatchSettings.GameMode.TEAM_RESPAWN
	await _new_match(settings, RespawnMatch.new())
	_check("Team respawn has no money", not _rounds.has_economy() and _rounds.get_money(_player) == 0, "$%d" % _rounds.get_money(_player))


func _test_hud_and_scoreboard() -> void:
	await _new_match(_settings())
	var hud := HUD_SCENE.instantiate()
	add_child(hud)
	hud.set_round_manager(_rounds)
	hud.set_player(_player)
	var money := hud.get_node("MoneyLabel") as Label
	var rewards := hud.get_node("RewardLabel") as Label
	var shown := money.visible and money.text == "$ 1000"
	await _win_round(0)
	var after := money.text == "$ 4000" and rewards.text.contains("+$3000  Round won")
	var board := SCOREBOARD_SCENE.instantiate() as Scoreboard
	add_child(board)
	board.set_round_manager(_rounds)
	Input.action_press("scoreboard")
	await _wait_ticks(3)
	Input.action_release("scoreboard")
	var table := board.find_child("Table", true, false) as ScoreboardTable
	var your_row := table.get_row(_player)
	var enemy_row := table.get_row(_rounds.get_members(1)[0])
	var your_cells := _cells(your_row)
	var enemy_cells := _cells(enemy_row)
	_check("The HUD shows your money and a line for each reward; the Tab scoreboard shows your team's money, not the enemy's",
			shown and after and your_cells.size() == 6 and your_cells[5] == "$4000" and enemy_cells[5] == "",
			"label '%s', rewards '%s', your row %s, enemy row %s" % [money.text, rewards.text.replace("\n", " | "), your_cells, enemy_cells])
	await _new_match(_settings(), RespawnMatch.new())
	hud.set_round_manager(_rounds)
	hud.set_player(_player)
	_check("...and no money on the HUD where there is none", not money.visible, "visible %s" % money.visible)
	hud.queue_free()
	board.queue_free()
	await _wait_ticks(2)


func _test_console() -> void:
	_remove_map()
	var main := MAIN_SCENE.instantiate()
	main.load_settings = false
	main.match_settings = _settings()
	add_child(main)
	await _wait_ticks(4)
	var console := main.get_node("DevConsole") as DevConsole
	var output := console.get_node("Panel/Margin/Box/Output") as Label
	var rounds := main.get_map().get_node("RoundManager") as RoundManager
	var player := main.get_map().get_node("Player") as Character
	console.run("money 2500")
	_check("The console's money command sets and shows your money", rounds.get_money(player) == 2500 and output.text.contains("You have $2500."),
			"$%d" % rounds.get_money(player))
	main.queue_free()
	await _wait_ticks(2)


# --- Helpers ---


func _settings() -> MatchSettings:
	var settings := MatchSettings.new()
	settings.freeze_time = 0.3
	settings.round_time = 30.0
	settings.round_end_time = 0.3
	settings.rounds_to_win = 15
	return settings


func _new_match(settings: MatchSettings, rules: RoundManager = null) -> void:
	_remove_map()
	_map = MAP_SCENE.instantiate()
	add_child(_map)
	_player = _map.get_node("Player") as Character
	_player.footstep_sound = null
	_rounds = rules if rules != null else RoundManager.new()
	_rounds.settings = settings
	_rounds.rng.seed = 2
	_map.add_child(_rounds)
	await _wait_ticks(3)
	for character in _rounds.get_participants():
		character.footstep_sound = null


func _remove_map() -> void:
	if _map != null:
		remove_child(_map)
		_map.queue_free()
		_map = null
	Teams.friendly_fire = false


## Plays a round to its end with [param team] winning by elimination, until the next freeze time.
func _win_round(team: int) -> void:
	await _wait_for_live()
	for loser in _rounds.get_members(Teams.other(team)):
		loser.take_damage(500.0, Hitbox.Zone.CHEST, null)
	await _wait_for_phase(RoundManager.Phase.ROUND_END)
	await _wait_for_phase(RoundManager.Phase.FREEZE)


func _cells(row: Control) -> Array[String]:
	var cells: Array[String] = []
	if row == null:
		return cells
	for node in row.find_children("*", "Label", true, false):
		cells.append((node as Label).text)
	return cells


func _wait_for_live() -> void:
	await _wait_for_phase(RoundManager.Phase.LIVE)


func _wait_for_phase(phase: RoundManager.Phase) -> void:
	var ticks := 0
	while _rounds.phase != phase and ticks < 128 * 20:
		await get_tree().physics_frame
		ticks += 1


func _wait_ticks(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _check(check_name: String, passed: bool, detail: String) -> void:
	print("%s  %s: %s" % ["PASS" if passed else "FAIL", check_name, detail])
	if not passed:
		_failures += 1
