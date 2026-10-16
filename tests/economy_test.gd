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
	await _test_buy_menu()


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


func _test_buy_menu() -> void:
	# Freeze time is the buy time: long enough for every step below.
	var settings := _settings()
	settings.freeze_time = 5.0
	await _new_match(settings)
	# A pause menu before the buy menu in the tree takes Esc only when the buy menu lets it through.
	var pause := load("res://ui/pause_menu.tscn").instantiate() as PauseMenu
	add_child(pause)
	var menu := load("res://ui/buy_menu.tscn").instantiate() as BuyMenu
	add_child(menu)
	menu.set_rules(_rounds, _player)
	var money_label := menu.get_node("Panel/Margin/Content/TopRow/Money") as Label
	var time_label := menu.get_node("Panel/Margin/Content/TopRow/BuyTime") as Label
	var message_label := menu.get_node("Panel/Margin/Content/Message") as Label
	var columns := menu.get_node("Panel/Margin/Content/Columns") as HBoxContainer

	# 1. B opens it in freeze time.
	var closed_before := not menu.is_open() and menu.can_open()
	_press_action("buy_menu")
	await _wait_ticks(3)
	_check("B opens the buy menu in freeze time: registered as a menu, with your money and the buy time",
			closed_before and menu.is_open() and MenuState.is_open(menu) and money_label.text == "$ 1000" and time_label.visible
			and time_label.text.begins_with("Buy time"),
			"open %s, money '%s', time '%s'" % [menu.is_open(), money_label.text, time_label.text])

	# 2. Every shop item is there with its price, in five columns.
	var listed := true
	var in_columns := columns.get_child_count() == Shop.CATEGORY_NAMES.size()
	var pistol_ids: Array[StringName] = []
	for item in Shop.items():
		var button := menu.get_item_button(item.id)
		listed = listed and button != null and button.text.contains("$%d" % item.price) and button.text.contains(item.name) \
				and button.icon != null
		if item.category == Shop.Category.PISTOLS:
			pistol_ids.append(item.id)
	for category in Shop.CATEGORY_NAMES.size():
		var expected := Shop.items().filter(func(item: Dictionary) -> bool: return item.category == category).size()
		var buttons := columns.get_child(category).get_children().filter(func(node: Node) -> bool: return node is Button).size()
		in_columns = in_columns and buttons == expected
	_check("It lists every shop item with its icon and price (the Ram's $2500) in five columns",
			listed and in_columns and menu.get_item_button(&"rifle").text.contains("$2500"),
			"%d columns, Ram button '%s'" % [columns.get_child_count(), menu.get_item_button(&"rifle").text.replace("\n", " | ")])

	# 3. The Verdict ($500) by keys: the category, then its number in the category.
	var verdict_key := (KEY_1 + pistol_ids.find(&"hand_cannon")) as Key
	var sparrow_before := _player.inventory.get_in_slot(WeaponData.Slot.PISTOL).data.id == &"pistol"
	_tap_key(KEY_1)
	await _wait_ticks(2)
	var pistols_header := columns.get_child(Shop.Category.PISTOLS).get_child(0) as Label
	var selected := menu.get_selected_category() == Shop.Category.PISTOLS and pistols_header.theme_type_variation == &"BrightLabel"
	_tap_key(verdict_key)
	await _wait_ticks(2)
	var pistol := _player.inventory.get_in_slot(WeaponData.Slot.PISTOL)
	var sparrow_on_floor := get_tree().get_nodes_in_group(WeaponPickup.GROUP).any(func(node: Node) -> bool:
			return _map.is_ancestor_of(node) and (node as WeaponPickup).data.id == &"pistol")
	_check("Keys 1 then 2 buy the Verdict: it is in the pistol slot, $1000 becomes $500, and the Sparrow it replaced lies on the floor",
			sparrow_before and selected and pistol != null and pistol.data.id == &"hand_cannon" and _rounds.get_money(_player) == 500
			and sparrow_on_floor and menu.is_open() and menu.get_selected_category() == -1,
			"pistol %s, $%d, selected %s, Sparrow on the floor %s" % [pistol.data.id if pistol != null else &"none", _rounds.get_money(_player), selected, sparrow_on_floor])

	# 4. Not enough money: the answer, the reason line, a disabled button, the money unchanged.
	var ram := menu.get_item_button(&"rifle")
	ram.pressed.emit()
	var clicked_reason := menu.get_message()
	var clicked_line := message_label.text
	var reason := menu.buy(&"rifle")
	_check("A purchase you can't afford fails with 'Not enough money': shown at the bottom, the Ram's button disabled, money unchanged",
			reason == "Not enough money" and clicked_reason == "Not enough money" and clicked_line == "Not enough money"
			and ram.disabled and ram.tooltip_text == "Not enough money" and _rounds.get_money(_player) == 500
			and _player.inventory.get_in_slot(WeaponData.Slot.PRIMARY) == null,
			"answer '%s', line '%s', disabled %s, $%d" % [reason, clicked_line, ram.disabled, _rounds.get_money(_player)])

	# 5. A vest ($500): armor on, the button disabled, the money gone, the menu still open.
	var vest := menu.get_item_button(&"vest")
	var vest_was_enabled := not vest.disabled
	var vest_reason := menu.buy(&"vest")
	_check("A vest buys $500 of armor and its button is disabled afterwards (the menu stays open)",
			vest_was_enabled and vest_reason == "" and _player.armor == Armor.MAX_ARMOR and vest.disabled
			and vest.tooltip_text == "You have a vest" and _rounds.get_money(_player) == 0 and menu.is_open()
			and money_label.text == "$ 0",
			"armor %.0f, vest disabled %s ('%s'), $%d" % [_player.armor, vest.disabled, vest.tooltip_text, _rounds.get_money(_player)])

	# 6. It closes when the round goes live, and B then does nothing.
	await _wait_for_live()
	var closed_live := not menu.is_open() and not MenuState.is_any_open()
	_press_action("buy_menu")
	await _wait_ticks(3)
	_check("The menu closes when freeze time ends, and B does nothing during the round",
			closed_live and not menu.is_open() and not menu.can_open() and not MenuState.is_any_open(),
			"closed at live %s, open after B %s" % [closed_live, menu.is_open()])

	# 7. Esc closes it, and the pause menu behind doesn't take the same press.
	await _new_match(settings)
	menu.set_rules(_rounds, _player)
	_press_action("buy_menu")
	await _wait_ticks(3)
	var opened := menu.is_open()
	_press_action("pause")
	await _wait_ticks(3)
	_check("Esc closes the buy menu and nothing else opens (the pause menu doesn't take that press)",
			opened and not menu.is_open() and not MenuState.is_any_open() and not pause.is_open() and not get_tree().paused,
			"was open %s, open now %s, pause menu open %s" % [opened, menu.is_open(), pause.is_open()])
	get_tree().paused = false

	# 8. Team respawn has no money and so no buy menu: B does nothing.
	var respawn_settings := _settings()
	respawn_settings.game_mode = MatchSettings.GameMode.TEAM_RESPAWN
	respawn_settings.freeze_time = 5.0
	await _new_match(respawn_settings, RespawnMatch.new())
	menu.set_rules(_rounds, _player)
	_press_action("buy_menu")
	await _wait_ticks(3)
	_check("In team respawn B does nothing: there is no money, so no buy menu",
			not _rounds.has_economy() and not menu.is_open() and not menu.can_open() and not MenuState.is_any_open(),
			"economy %s, open %s" % [_rounds.has_economy(), menu.is_open()])

	# 9. Practice: any time, everything free.
	_remove_map()
	_map = MAP_SCENE.instantiate()
	add_child(_map)
	_player = _map.get_node("Player") as Character
	_player.footstep_sound = null
	var arena := ArenaRules.new()
	arena.bot_count = 0
	_map.add_child(arena)
	await _wait_ticks(3)
	menu.set_rules(arena, _player)
	_press_action("buy_menu")
	await _wait_ticks(3)
	var ram_text := menu.get_item_button(&"rifle").text
	var free_prices := ram_text.contains("FREE") and not ram_text.contains("$") and not time_label.visible \
			and money_label.text == "Free in practice"
	var sniper_bought := menu.buy(&"sniper")
	var primary := _player.inventory.get_in_slot(WeaponData.Slot.PRIMARY)
	var again := menu.buy(&"sniper")
	var shown_again := message_label.text == "You have it" and menu.get_message() == "You have it"
	_check("In practice the menu opens at any time, prices say FREE, and the Heron is yours for nothing",
			menu.is_open() and free_prices and sniper_bought == "" and primary != null and primary.data.id == &"sniper"
			and again == "You have it" and menu.get_item_button(&"sniper").disabled and shown_again,
			"open %s, Ram '%s', bought '%s', primary %s, again '%s'" % [menu.is_open(), ram_text.replace("\n", " | "), sniper_bought,
					primary.data.id if primary != null else &"none", again])
	# The reason goes away by itself after a couple of seconds.
	var waited := 0
	while menu.get_message() != "" and waited < 128 * 4:
		await get_tree().physics_frame
		waited += 1
	_check("A refusal's reason leaves the bottom line by itself after about two seconds",
			menu.get_message() == "" and waited > 128 and waited < 128 * 3 and message_label.text != "You have it",
			"gone after %d ticks, line '%s'" % [waited, message_label.text])
	_press_action("buy_menu")
	await _wait_ticks(3)
	_check("B closes it again", not menu.is_open() and not MenuState.is_any_open(), "open %s" % menu.is_open())

	# Leave nothing open behind.
	menu.close()
	remove_child(menu)
	menu.queue_free()
	remove_child(pause)
	pause.queue_free()
	MenuState.reset()
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


## Sends an action's press and release through the input system, as a key would.
func _press_action(action: String) -> void:
	for pressed in [true, false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = pressed
		Input.parse_input_event(event)


## Sends a key press and release (by physical key), as the keyboard would.
func _tap_key(key: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = key
		event.keycode = key
		event.pressed = pressed
		Input.parse_input_event(event)
