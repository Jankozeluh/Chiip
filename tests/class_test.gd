extends Node3D
## Automated class checks (M6 task 8, D-078). Run without a window:
##
##     Godot --headless --path . --fixed-fps 128 --quit-after 200000 res://tests/class_test.tscn
##
## Checks the four [ClassData] resources (names, heights, models, hit zones and the perk factors
## of GAME_DESIGN.md 4.9), that a [Character] swaps its model and its hit zones when its
## class_data changes (before and after it is in the game, alive and dead) and keeps its team
## colour, that a match gives each team's bots different classes from a seeded mix and the player
## their own class (or [member MatchSettings.player_class]), that [method RoundManager.request_class]
## works in freeze time only (and [method ArenaRules.request_class] always), the class menu
## (opens at the start of a match, picks by call, key and click, closes itself when freeze time
## ends, blocks the mouse and the trigger, scales), and, in the real main scene, the console's
## class command. The real test map is used, with short timings. Quits with the number of failed
## checks as the exit code (0 means everything passed).

const MAP_SCENE := preload("res://maps/test_map.tscn")
const BOT_SCENE := preload("res://bots/bot.tscn")
const MENU_SCENE := preload("res://ui/class_menu.tscn")
const MAIN_SCENE := preload("res://main.tscn")
## The classes in menu order: id, name, height in metres.
const CLASSES: Array = [
	[&"rifleman", "Rifleman", 1.82],
	[&"bulwark", "Bulwark", 1.92],
	[&"marksman", "Marksman", 1.88],
	[&"scout", "Scout", 1.72],
]
const FREEZE_TIME := 1.5
const ROUND_TIME := 1.0
const ROUND_END_TIME := 1.0

var _failures: int = 0
var _map: Node3D
var _rounds: RoundManager
var _player: Character
## [character, class id] for every class_changed signal.
var _changes: Array = []


func _ready() -> void:
	await _run_all()
	if _failures == 0:
		print("\nAll checks passed.")
	else:
		print("\n%d check(s) FAILED." % _failures)
	get_tree().quit(_failures)


func _run_all() -> void:
	_test_class_data()
	await _test_swapping_a_class()
	await _test_bot_mix()
	await _test_player_class_setting()
	await _test_request_class()
	await _test_practice_mode()
	await _test_class_menu()
	await _test_main_scene()
	await _test_perks()
	await _test_class_draft()


func _test_class_data() -> void:
	var classes := ClassData.all()
	var ids_ok := classes.size() == 4
	var detail := ""
	for i in mini(classes.size(), CLASSES.size()):
		var data := classes[i]
		var wanted: Array = CLASSES[i]
		var base := "res://assets/models/crew/%s" % wanted[0]
		var class_ok: bool = data != null and data.id == wanted[0] and data.display_name == wanted[1] \
				and is_equal_approx(data.height, wanted[2]) \
				and data.model != null and data.model.resource_path == base + ".glb" \
				and data.hit_zones != null and data.hit_zones.resource_path == base + "_hit_zones.tres" \
				and data.hit_zones.size() == 15
		ids_ok = ids_ok and class_ok
		detail += " %s %s %.2f m, %d zones;" % [data.id, data.display_name, data.height, data.hit_zones.size() if data.hit_zones != null else 0]
	_check("ClassData.all() gives Rifleman, Bulwark, Marksman, Scout with names, heights, models and 15 hit zones each",
			ids_ok, detail)
	var texts_ok := true
	for data in classes:
		texts_ok = texts_ok and data.role != "" and data.signature_weapon != "" and data.look != "" \
				and data.perk_name != "" and data.perk_description != "" and data.arms_model != null \
				and data.arms_model.resource_path == "res://assets/models/crew/%s_arms.glb" % data.id
	_check("Every class has a role, a signature gun, a look, a perk text and its own first-person arms", texts_ok, "")
	_check("ClassData.find() finds a class by id and gives null for an unknown one",
			ClassData.find(&"scout") == classes[3] and ClassData.find(&"nobody") == null,
			"scout is %s" % ClassData.find(&"scout").display_name)
	# The perk factors from GAME_DESIGN.md 4.9; everything not listed stays 1.0.
	var wanted_factors := {
		&"rifleman": {"reload_time_factor": 0.85, "weapon_switch_time_factor": 0.85},
		&"bulwark": {"armor_damage_factor": 0.9, "armor_wear_factor": 0.7},
		&"marksman": {"scoped_recovery_factor": 1.3, "scope_in_time_factor": 0.8},
		&"scout": {"running_footstep_range_factor": 0.7},
	}
	var factor_names: Array[String] = ["reload_time_factor", "weapon_switch_time_factor", "armor_damage_factor",
			"armor_wear_factor", "scoped_recovery_factor", "scope_in_time_factor", "running_footstep_range_factor"]
	var factors_ok := true
	var factor_detail := ""
	for data in classes:
		var wanted: Dictionary = wanted_factors[data.id]
		for factor_name in factor_names:
			var expected: float = wanted.get(factor_name, 1.0)
			if not is_equal_approx(data.get(factor_name), expected):
				factors_ok = false
				factor_detail += " %s.%s is %s, not %s;" % [data.id, factor_name, data.get(factor_name), expected]
	_check("The perk factors are Rifleman reload 0.85, Bulwark armour 0.9 and wear 0.7, Marksman recovery 1.3 and scope-in 0.8, Scout footsteps 0.7, the rest 1.0",
			factors_ok, factor_detail if factor_detail != "" else "all 28 values as in GAME_DESIGN.md 4.9")
	_check("Every class has its own perk name (Quick Hands, Plated, Steady, Light Step)",
			classes.map(func(data: ClassData) -> String: return data.perk_name) == ["Quick Hands", "Plated", "Steady", "Light Step"],
			str(classes.map(func(data: ClassData) -> String: return data.perk_name)))


func _test_swapping_a_class() -> void:
	var floor_body := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(40, 1, 40)
	floor_shape.shape = box
	floor_body.add_child(floor_shape)
	floor_body.position = Vector3(0, -0.5, 0)
	add_child(floor_body)
	var scout := ClassData.find(&"scout")
	var bulwark_class := ClassData.find(&"bulwark")
	# A class set before the character enters the game is built once, in _ready.
	var scout_bot := _add_bot(0, scout, Vector3(-4, 0, 0))
	var rifleman_bot := _add_bot(0, null, Vector3(0, 0, 0))
	var bulwark_bot := _add_bot(0, bulwark_class, Vector3(4, 0, 0))
	await _wait_ticks(3)
	_check("A bot's class set before it enters the game builds that class's model and its 15 hit zones",
			_model_path(scout_bot) == scout.model.resource_path and scout_bot.get_hitbox_rids().size() == 15
			and _model_path(bulwark_bot) == bulwark_class.model.resource_path and bulwark_bot.get_hitbox_rids().size() == 15,
			"%s, %s" % [_model_path(scout_bot), _model_path(bulwark_bot)])
	_check("A character without a class set is the Rifleman",
			rifleman_bot.class_data == ClassData.find(&"rifleman") and _model_path(rifleman_bot) == ClassData.find(&"rifleman").model.resource_path,
			_model_path(rifleman_bot))
	# Change a class in the middle of the game.
	var old_chest := _zone_box(rifleman_bot, Hitbox.Zone.CHEST)
	var old_rids := rifleman_bot.get_hitbox_rids()
	rifleman_bot.class_data = scout
	# Right after the change the old zone no longer reaches the character (it is freed at the end of the frame).
	var health_before := rifleman_bot.health
	old_chest.receive_hit(10.0, Vector3.ZERO, null)
	var old_zone_ignored := rifleman_bot.health == health_before
	await _wait_ticks(40)
	var models := rifleman_bot.body.get_children().filter(func(node: Node) -> bool: return String(node.name).begins_with("Model"))
	var new_rids := rifleman_bot.get_hitbox_rids()
	var rid_overlap := new_rids.any(func(rid: RID) -> bool: return old_rids.has(rid))
	_check("Changing class_data swaps the model: one \"Model\" under the body, now the Scout's",
			models.size() == 1 and models[0].name == &"Model" and _model_path(rifleman_bot) == scout.model.resource_path
			and rifleman_bot.body.model == scout.model and rifleman_bot.body.hit_zones == scout.hit_zones,
			"%d model node(s), %s" % [models.size(), _model_path(rifleman_bot)])
	_check("...and the hit zones: 15 new ones on collision layer 'hitboxes', none of the old, the old zone ignored at once",
			new_rids.size() == 15 and not rid_overlap and old_zone_ignored and not is_instance_valid(old_chest)
			and rifleman_bot.body.get_hitboxes().all(func(hitbox: Hitbox) -> bool: return hitbox.collision_layer == PhysicsLayers.HITBOXES),
			"%d zones, overlap with the old ones: %s, old zone ignored: %s, old zone freed: %s" % [
					new_rids.size(), rid_overlap, old_zone_ignored, not is_instance_valid(old_chest)])
	_check("The animations keep running on the new model",
			rifleman_bot.body.get_animation_tree() != null and rifleman_bot.body.get_animation_tree().active,
			"tree %s" % rifleman_bot.body.get_animation_tree())
	# Taller class, higher head: both stand still on the floor.
	var bulwark_head := bulwark_bot.get_head_position().y - bulwark_bot.global_position.y
	var scout_head := scout_bot.get_head_position().y - scout_bot.global_position.y
	_check("The head zone of a standing Bulwark is at least 10 cm higher than a Scout's",
			bulwark_head - scout_head >= 0.10,
			"Bulwark %.3f m, Scout %.3f m, %.0f cm apart" % [bulwark_head, scout_head, (bulwark_head - scout_head) * 100.0])
	var swapped_head := rifleman_bot.get_head_position().y - rifleman_bot.global_position.y
	_check("A bot that became a Scout has the Scout's head height",
			absf(swapped_head - scout_head) < 0.02, "%.3f m against %.3f m" % [swapped_head, scout_head])
	# A hit on the new chest zone still hurts.
	var chest := _zone_box(rifleman_bot, Hitbox.Zone.CHEST)
	health_before = rifleman_bot.health
	chest.receive_hit(10.0, Vector3.ZERO, null)
	_check("A hit on the new chest zone damages the character",
			rifleman_bot.health == health_before - 10.0, "health %.0f -> %.0f" % [health_before, rifleman_bot.health])
	# The team colour stays.
	rifleman_bot.team = 1
	rifleman_bot.class_data = bulwark_class
	await _wait_ticks(3)
	var mesh := rifleman_bot.body.get_meshes()[0]
	_check("The team colour survives a class change",
			rifleman_bot.body.get_team_color() == Teams.color_for(1)
			and mesh.get_instance_shader_parameter("team_color") == Teams.color_for(1),
			"body colour %s" % rifleman_bot.body.get_team_color())
	# A dead character: its new zones stay off, it is still dead, and respawning switches them on.
	rifleman_bot.take_damage(500.0, Hitbox.Zone.CHEST, scout_bot)
	await _wait_ticks(3)
	rifleman_bot.class_data = ClassData.find(&"marksman")
	await _wait_ticks(5)
	var dead_state: String = rifleman_bot.body.get_animation_tree().get("parameters/Death/current_state")
	var zones_off := rifleman_bot.body.get_hitboxes().all(func(hitbox: Hitbox) -> bool: return hitbox.collision_layer == 0)
	_check("Changing the class of a dead character keeps it dead: new zones off, the death plays on the new body",
			not rifleman_bot.is_alive() and zones_off and rifleman_bot.body.get_hitboxes().size() == 15 and dead_state != "alive",
			"alive: %s, zones off: %s, death state %s" % [rifleman_bot.is_alive(), zones_off, dead_state])
	rifleman_bot.respawn(Vector3(0, 0, 8), 0.0)
	await _wait_ticks(3)
	var zones_on := rifleman_bot.body.get_hitboxes().all(func(hitbox: Hitbox) -> bool: return hitbox.collision_layer == PhysicsLayers.HITBOXES)
	_check("...and respawning brings the new zones back",
			rifleman_bot.is_alive() and zones_on, "alive: %s, zones on: %s" % [rifleman_bot.is_alive(), zones_on])
	for bot: Character in [scout_bot, rifleman_bot, bulwark_bot]:
		bot.queue_free()
	floor_body.queue_free()
	await _wait_ticks(2)


func _test_bot_mix() -> void:
	await _new_match(null)
	var enemies := _class_ids(_rounds.get_members(1))
	var teammates := _class_ids(_rounds.get_members(0).filter(func(member: Character) -> bool: return member != _player))
	_check("In a 3v3 match the three enemy bots have three different classes",
			enemies.size() == 3 and _distinct(enemies) == 3, str(enemies))
	_check("...your two bot teammates two different ones, and you keep the Rifleman",
			teammates.size() == 2 and _distinct(teammates) == 2 and _player.class_data == ClassData.find(&"rifleman"),
			"%s, you: %s" % [teammates, _player.class_data.id])
	var first_mix := enemies + teammates
	# The same seed gives the same mix.
	await _new_match(null)
	var second_mix := _class_ids(_rounds.get_members(1)) + _class_ids(_rounds.get_members(0).filter(func(member: Character) -> bool: return member != _player))
	_check("The mix comes from the seeded random generator: the same seed gives the same classes",
			first_mix == second_mix, "%s and %s" % [first_mix, second_mix])
	# Both teams of bots: three different classes each, and the models match the classes.
	await _new_match(null, false)
	var team_a := _class_ids(_rounds.get_members(0))
	var team_b := _class_ids(_rounds.get_members(1))
	var models_ok := _rounds.get_participants().all(func(member: Character) -> bool: return _model_path(member) == member.class_data.model.resource_path)
	_check("With bots only, each team's three bots have three different classes, and their bodies are those classes",
			team_a.size() == 3 and team_b.size() == 3 and _distinct(team_a) == 3 and _distinct(team_b) == 3 and models_ok,
			"%s and %s, bodies match: %s" % [team_a, team_b, models_ok])
	# The class each team starts at is random: over several seeds it isn't always the same one.
	var starts := {}
	for seed_value in [1, 2, 3, 4, 5, 6]:
		await _new_match(null, false, null, seed_value)
		starts[seed_value] = [_rounds.get_members(0)[0].class_data.id, _rounds.get_members(1)[0].class_data.id]
	_check("The class each team's mix starts at depends on the seed",
			_distinct(starts.values()) > 2, str(starts.values()))


func _test_player_class_setting() -> void:
	var settings := _settings()
	settings.player_class = ClassData.find(&"scout")
	await _new_match(settings)
	_check("MatchSettings.player_class puts the player in that class at the start of the match",
			_player.class_data == ClassData.find(&"scout") and _model_path(_player) == ClassData.find(&"scout").model.resource_path
			and _player.get_hitbox_rids().size() == 15,
			"%s, %s" % [_player.class_data.id, _model_path(_player)])


func _test_request_class() -> void:
	var bulwark := ClassData.find(&"bulwark")
	var scout := ClassData.find(&"scout")
	await _new_match(null)
	_check("The match starts in freeze time", _rounds.phase == RoundManager.Phase.FREEZE and _rounds.round_number == 1,
			"round %d, %s" % [_rounds.round_number, RoundManager.Phase.keys()[_rounds.phase]])
	var accepted := _rounds.request_class(_player, bulwark)
	await _wait_ticks(3)
	_check("In freeze time request_class gives the class, emits class_changed and returns true",
			accepted and _player.class_data == bulwark and _changes == [[_player, &"bulwark"]]
			and _model_path(_player) == bulwark.model.resource_path,
			"accepted %s, class %s, signals %s" % [accepted, _player.class_data.id, _changes.size()])
	_check("Asking for the class you have is accepted without a change signal; asking for nothing is refused",
			_rounds.request_class(_player, bulwark) and not _rounds.request_class(_player, null) and _changes.size() == 1,
			"%d signal(s)" % _changes.size())
	await _wait_for_phase(RoundManager.Phase.LIVE)
	var live := _rounds.request_class(_player, scout)
	_check("Once the round is live, request_class is refused and the class stays",
			not live and _player.class_data == bulwark and _changes.size() == 1,
			"accepted %s, class %s" % [live, _player.class_data.id])
	await _wait_for_phase(RoundManager.Phase.ROUND_END)
	var round_end := _rounds.request_class(_player, scout)
	_check("It is refused at the round end too",
			not round_end and _player.class_data == bulwark, "accepted %s, class %s" % [round_end, _player.class_data.id])
	await _wait_for_phase(RoundManager.Phase.FREEZE)
	var next_freeze := _rounds.request_class(_player, scout)
	_check("The next round's freeze time allows it again (the class stays between rounds until changed)",
			next_freeze and _rounds.round_number == 2 and _player.class_data == scout and _changes.size() == 2,
			"round %d, accepted %s, class %s" % [_rounds.round_number, next_freeze, _player.class_data.id])
	# The end of the match.
	var settings := _settings()
	settings.rounds_to_win = 1
	await _new_match(settings)
	await _wait_for_phase(RoundManager.Phase.MATCH_END)
	var after_match := _rounds.request_class(_player, scout)
	_check("After the match is over it is refused",
			not after_match and _rounds.phase == RoundManager.Phase.MATCH_END and _player.class_data == ClassData.find(&"rifleman"),
			"accepted %s, class %s" % [after_match, _player.class_data.id])


func _test_practice_mode() -> void:
	_remove_map()
	_map = MAP_SCENE.instantiate()
	add_child(_map)
	_player = _map.get_node("Player")
	_silence(_player)
	var arena := ArenaRules.new()
	arena.bot_count = 4
	_map.add_child(arena)
	await _wait_ticks(4)
	var bots := arena.get_bots()
	for bot in bots:
		_silence(bot)
	var ids := _class_ids(bots)
	_check("Practice mode: four bots, four different classes",
			bots.size() == 4 and _distinct(ids) == 4, str(ids))
	var scout := ClassData.find(&"scout")
	var accepted := arena.request_class(_player, scout)
	await _wait_ticks(3)
	_check("Practice mode has no freeze time: request_class always applies",
			accepted and _player.class_data == scout and _model_path(_player) == scout.model.resource_path,
			"accepted %s, class %s" % [accepted, _player.class_data.id])
	_check("...but there must be something to change to", not arena.request_class(_player, null), "")


func _test_class_menu() -> void:
	var settings := _settings()
	var menu := MENU_SCENE.instantiate() as ClassMenu
	add_child(menu)
	await _new_match(settings, true, menu)
	var controller := _player.get_node("PlayerController") as PlayerController
	var cards := menu.get_node("Panel/Margin/Content/Classes").get_children()
	_check("The class menu opens by itself when round 1's freeze time begins",
			menu.is_open() and menu.visible and _rounds.phase == RoundManager.Phase.FREEZE,
			"open %s, visible %s" % [menu.is_open(), menu.visible])
	var names: Array = []
	var current_marked: Array = []
	for card in cards:
		names.append((card.get_node("Margin/Content/Name") as Label).text)
		current_marked.append((card.get_node("Select") as Button).button_pressed)
	_check("It shows the four classes in order, with your current class (the Rifleman) pressed",
			names == ["Rifleman", "Bulwark", "Marksman", "Scout"] and current_marked == [true, false, false, false],
			"%s, pressed %s" % [names, current_marked])
	var focus_on_current := get_viewport().gui_get_focus_owner() == cards[0].get_node("Select")
	var card_text := ""
	for card in cards:
		card_text += (card.get_node("Margin/Content/Perk") as Label).text + (card.get_node("Margin/Content/Height") as Label).text
	_check("Each card has the class's height and its perk text, the title and footer are there, and the current card has the focus",
			focus_on_current and card_text.contains("1.92 m") and card_text.contains("Reloads and weapon switches 15% faster.")
			and (menu.get_node("Panel/Margin/Content/Title") as Label).text == "Choose your class"
			and (menu.get_node("Panel/Margin/Content/Footer") as Label).text == "M: change class during freeze time.",
			"")
	var background := menu.get_node("Background") as Control
	_check("The dimmed background takes every click, and the menu blocks the trigger while it is open",
			background.mouse_filter == Control.MOUSE_FILTER_STOP and controller._shooting_blocked,
			"mouse filter %d, shooting blocked %s" % [background.mouse_filter, controller._shooting_blocked])
	Input.action_press("shoot")
	_check("A held fire button doesn't shoot through the open menu", not controller.get_input(0.0).shoot, "")
	Input.action_release("shoot")
	# Esc closes without a change.
	_press_action("pause")
	await _wait_ticks(2)
	_check("Esc closes the menu without a change", not menu.is_open() and _player.class_data == ClassData.find(&"rifleman"),
			"open %s, class %s" % [menu.is_open(), _player.class_data.id])
	_check("...and the trigger works again", not controller._shooting_blocked, "")
	# M opens it, a number key picks.
	_press_action("class_menu")
	await _wait_ticks(2)
	var opened_by_key := menu.is_open()
	_press_key(KEY_3)
	await _wait_ticks(3)
	_check("In freeze time the class_menu key (M) opens the menu, and pressing 3 makes you the Marksman and closes it",
			opened_by_key and not menu.is_open() and _player.class_data == ClassData.find(&"marksman"),
			"opened %s, open now %s, class %s" % [opened_by_key, menu.is_open(), _player.class_data.id])
	# A click on a card.
	menu.open()
	var select := menu.get_node("Panel/Margin/Content/Classes/Card2/Select") as Button
	var pressed_on_open := (menu.get_node("Panel/Margin/Content/Classes/Card3/Select") as Button).button_pressed
	select.pressed.emit()
	await _wait_ticks(3)
	_check("Clicking the Bulwark's card (it was Marksman before, and its card was pressed) makes you the Bulwark and closes the menu",
			pressed_on_open and not menu.is_open() and _player.class_data == ClassData.find(&"bulwark")
			and _model_path(_player) == ClassData.find(&"bulwark").model.resource_path,
			"was pressed %s, open %s, class %s" % [pressed_on_open, menu.is_open(), _player.class_data.id])
	var focus := get_viewport().gui_get_focus_owner()
	_check("A closed menu leaves no card with the keyboard focus (Space would click it)",
			focus == null or not menu.is_ancestor_of(focus), "focus owner: %s" % focus)
	_check("A pick while the menu is closed does nothing", not menu.pick(3) and _player.class_data == ClassData.find(&"bulwark"), "")
	# pick(1) directly, with the first class again.
	menu.open()
	var picked := menu.pick(0)
	_check("pick(index) returns true, gives the class and closes the menu",
			picked and not menu.is_open() and _player.class_data == ClassData.find(&"rifleman"),
			"picked %s, class %s" % [picked, _player.class_data.id])
	menu.open()
	_check("pick() with a number that is no class is refused and leaves the menu open",
			not menu.pick(4) and not menu.pick(-1) and menu.is_open(), "")
	# The console is typing: the menu stays out of it.
	menu.close()
	DevConsole.is_open = true
	var opened_with_console := menu.open()
	_press_action("class_menu")
	await _wait_ticks(2)
	var key_with_console := menu.is_open()
	DevConsole.is_open = false
	_check("It does not open while the developer console is open (not even with M)",
			not opened_with_console and not key_with_console, "open() %s, M %s" % [opened_with_console, key_with_console])
	# Scaling and theme.
	menu.open()
	var title := menu.get_node("Panel/Margin/Content/Title") as Label
	var card := cards[0] as Control
	var base_size := title.get_theme_font_size("font_size")
	var base_card := card.custom_minimum_size.x
	menu.set_ui_scale(1.5)
	await _wait_ticks(2)
	var scaled_size := title.get_theme_font_size("font_size")
	var scaled_card := card.custom_minimum_size.x
	menu.set_ui_scale(1.0)
	await _wait_ticks(2)
	_check("The menu takes its look from the theme (a ModalPanel and a TitleLabel, no overrides) and scales with it: 48 -> 72 px title, cards 208 -> 312 px",
			(menu.get_node("Panel") as Control).theme_type_variation == &"ModalPanel" and title.theme_type_variation == &"TitleLabel"
			and not title.has_theme_font_size_override("font_size") and base_size == 48 and scaled_size == 72
			and base_card == 208.0 and scaled_card == 312.0 and title.get_theme_font_size("font_size") == 48,
			"title %d -> %d, card %.0f -> %.0f" % [base_size, scaled_size, base_card, scaled_card])
	# Freeze time ends: it closes itself.
	_check("The menu is open late in freeze time", menu.is_open() and _rounds.phase == RoundManager.Phase.FREEZE, "")
	await _wait_for_phase(RoundManager.Phase.LIVE)
	await _wait_ticks(2)
	_check("It closes itself when the round goes live", not menu.is_open() and not menu.visible and not controller._shooting_blocked,
			"open %s, visible %s" % [menu.is_open(), menu.visible])
	var open_live := menu.open()
	_press_action("class_menu")
	await _wait_ticks(2)
	_check("During the live round open() and M do nothing, and a pick is refused",
			not open_live and not menu.is_open() and not menu.pick(3) and _player.class_data == ClassData.find(&"rifleman"),
			"open() %s, M opened it: %s" % [open_live, menu.is_open()])
	await _wait_for_phase(RoundManager.Phase.FREEZE)
	await _wait_ticks(2)
	var auto_opened := menu.is_open()
	var opened_in_round_2 := menu.open()
	_check("Round 2's freeze time doesn't open it by itself, but M does",
			_rounds.round_number == 2 and not auto_opened and opened_in_round_2 and menu.is_open(),
			"round %d, opened by itself %s, by M %s" % [_rounds.round_number, auto_opened, opened_in_round_2])
	# The trigger stays blocked while a click is still held when the menu closes.
	Input.action_press("shoot")
	menu.close()
	var blocked_while_held := controller._shooting_blocked
	Input.action_release("shoot")
	_check("A click that closes the menu is not a shot: the trigger stays blocked until the button is released",
			blocked_while_held and not controller.get_input(0.0).shoot, "blocked while held: %s" % blocked_while_held)
	controller.unblock_shooting()
	# No rules, practice rules.
	menu.set_rules(null, _player)
	_check("With no game rules the menu never opens", not menu.open() and not menu.is_open(), "")
	var arena := ArenaRules.new()
	arena.bot_count = 0
	_map.add_child(arena)
	menu.set_rules(arena, _player)
	var practice_open := menu.open()
	var practice_pick := menu.pick(3)
	_check("In practice mode the menu opens at any time and a pick always works",
			practice_open and practice_pick and _player.class_data == ClassData.find(&"scout"),
			"opened %s, picked %s, class %s" % [practice_open, practice_pick, _player.class_data.id])
	menu.queue_free()


func _test_main_scene() -> void:
	_remove_map()
	var main := MAIN_SCENE.instantiate()
	main.match_settings = _settings()
	add_child(main)
	await _wait_ticks(4)
	var map: Node = main.get_map()
	var rounds := map.get_node("RoundManager") as RoundManager
	var player := map.get_node("Player") as Character
	var menu := main.get_node("ClassMenu") as ClassMenu
	var console := main.get_node("DevConsole") as DevConsole
	for character in rounds.get_participants():
		_silence(character)
	_check("In the real game the class menu opens at the start of the match",
			menu.is_open() and rounds.phase == RoundManager.Phase.FREEZE, "open %s" % menu.is_open())
	var output := console.get_node("Panel/Margin/Box/Output") as Label
	console.run("class")
	var listed := output.text.contains("bulwark") and output.text.contains("You are the Rifleman.")
	console.run("class nobody")
	var unknown := output.text.contains("Unknown class 'nobody'")
	console.run("class Bulwark")
	_check("The console's class command lists the classes, names yours, rejects unknown names and gives you a class in freeze time",
			listed and unknown and player.class_data == ClassData.find(&"bulwark") and output.text.contains("You are the Bulwark now."),
			"listed %s, unknown %s, class %s" % [listed, unknown, player.class_data.id])
	await _wait_for_live(rounds)
	console.run("class scout")
	_check("...and says so when the round is live and refuses",
			player.class_data == ClassData.find(&"bulwark") and output.text.contains("only during freeze time") and not menu.is_open(),
			"class %s" % player.class_data.id)
	main.queue_free()
	await _wait_ticks(2)


## M7 (D-099): every perk works. The Rifleman's, the Bulwark's and the Marksman's have their own
## checks in the guns and gear suites; here the Scout's Light Step, the class menu's loadouts, and
## the class change of team respawn (any time, applied on the next respawn).
func _test_perks() -> void:
	Weapon.silent = true
	_remove_map()
	var scout := _add_bot(1, ClassData.find(&"scout"), Vector3(0, 0, -40))
	var rifleman := _add_bot(1, ClassData.find(&"rifleman"), Vector3(4, 0, -40))
	await _wait_ticks(2)
	var scout_range := scout.get_footstep_range()
	var rifleman_range := rifleman.get_footstep_range()
	_check("The Scout's Light Step: its running steps carry 70% as far (for bots' ears and the sound alike)",
			is_equal_approx(scout_range, Noises.FOOTSTEP_RANGE * 0.7) and is_equal_approx(rifleman_range, Noises.FOOTSTEP_RANGE),
			"Scout %.1f m, Rifleman %.1f m" % [scout_range, rifleman_range])
	scout.queue_free()
	rifleman.queue_free()
	var menu := MENU_SCENE.instantiate() as ClassMenu
	add_child(menu)
	var card_text := (menu.find_child("Weapon", true, false) as Label).text
	_check("The class menu shows each class's loadout (where there's no money)", card_text.begins_with("Loadout: ") and card_text.contains("Sparrow"),
			card_text)
	# Team respawn: a class change in a live round waits for the next respawn, with that class's loadout.
	var settings := _settings()
	settings.game_mode = MatchSettings.GameMode.TEAM_RESPAWN
	settings.freeze_time = 0.5
	settings.time_limit = 60.0
	settings.respawn_delay = 0.5
	_remove_map()
	_map = MAP_SCENE.instantiate()
	add_child(_map)
	_player = _map.get_node("Player")
	_silence(_player)
	var respawn := RespawnMatch.new()
	respawn.settings = settings
	respawn.rng.seed = 3
	_map.add_child(respawn)
	menu.set_rules(respawn, _player)
	await _wait_ticks(3)
	await _wait_for_live(respawn)
	var opens_live := menu.open()
	var accepted := respawn.request_class(_player, ClassData.find(&"marksman"))
	var waits := _player.class_data == ClassData.find(&"rifleman") and respawn.get_next_class(_player) == ClassData.find(&"marksman")
	_player.take_damage(500.0, Hitbox.Zone.CHEST, null)
	await _wait_ticks(int(0.7 * 128))
	var applied := _player.is_alive() and _player.class_data == ClassData.find(&"marksman") and _player.weapon.data.id == &"sniper"
	_check("Team respawn: the class menu opens in the live round, and the new class comes with the next respawn and its loadout",
			opens_live and accepted and waits and applied, "opens %s, accepted %s, waits %s, applied %s" % [opens_live, accepted, waits, applied])
	menu.close()
	menu.queue_free()
	_remove_map()
	Weapon.silent = false
	await _wait_ticks(2)


## M7 task 17 (D-099): the class draft. Everyone is offered two classes when the match starts,
## you start as your first, bots take the one their team has fewer of (every offer has a class the
## team lacks, so a team of three is three classes), only drafted classes are allowed, the class
## menu shows your two cards, and at half time the bots switch within their drafts.
func _test_class_draft() -> void:
	var settings := _settings()
	settings.class_draft = true
	var drafted := {}
	var menu := MENU_SCENE.instantiate() as ClassMenu
	add_child(menu)
	_remove_map()
	_map = MAP_SCENE.instantiate()
	add_child(_map)
	_player = _map.get_node("Player")
	_silence(_player)
	_rounds = RoundManager.new()
	_rounds.settings = settings
	_rounds.rng.seed = 5
	_rounds.class_drafted.connect(func(character: Character, classes: Array[ClassData]) -> void: drafted[character] = classes)
	_map.add_child(_rounds)
	menu.set_rules(_rounds, _player)
	await _wait_ticks(2)
	for character in _rounds.get_participants():
		_silence(character)
	var yours := _rounds.get_draft(_player)
	var everyone_two := _rounds.get_participants().all(func(member: Character) -> bool:
		var offer := _rounds.get_draft(member)
		return offer.size() == 2 and offer[0] != offer[1] and offer.has(member.class_data) and drafted.get(member) == offer)
	_check("The draft offers everyone two different classes (class_drafted tells each), and everyone plays one of theirs; you start as your first",
			everyone_two and drafted.size() == 6 and _player.class_data == yours[0],
			"yours %s, everyone ok %s, signals %d" % [_ids(yours), everyone_two, drafted.size()])
	var teams_mixed := true
	for team in Teams.COUNT:
		teams_mixed = teams_mixed and _distinct(_class_ids(_rounds.get_members(team))) == 3
	_check("Each team of three still has three different classes", teams_mixed,
			"%s and %s" % [_class_ids(_rounds.get_members(0)), _class_ids(_rounds.get_members(1))])
	# Only your two.
	var other := yours[1]
	var not_offered: ClassData = ClassData.all().filter(func(data: ClassData) -> bool: return not yours.has(data))[0]
	var refused := not _rounds.request_class(_player, not_offered) and _player.class_data == yours[0]
	var names: Array = []
	var cards := menu.get_node("Panel/Margin/Content/Classes").get_children()
	for card in cards:
		if (card as Control).visible:
			names.append((card.get_node("Margin/Content/Name") as Label).text)
	var footer := (menu.get_node("Panel/Margin/Content/Footer") as Label).text
	_check("The class menu shows your two cards (the others hidden) and says they're yours this match; a class you weren't offered is refused",
			menu.is_open() and names == [yours[0].display_name, yours[1].display_name] and footer.begins_with("Your two classes")
			and menu.get_classes() == yours and refused,
			"cards %s, footer '%s', refused %s" % [names, footer, refused])
	_press_key(KEY_3)
	await _wait_ticks(2)
	var key_3_nothing := menu.is_open() and _player.class_data == yours[0]
	_press_key(KEY_2)
	await _wait_ticks(3)
	_check("Key 3 does nothing with two cards; key 2 takes your other drafted class",
			key_3_nothing and not menu.is_open() and _player.class_data == other,
			"3 did nothing %s, class now %s" % [key_3_nothing, _player.class_data.id])
	# The same seed gives the same draft; other seeds other drafts.
	var first_draft := _ids(yours)
	var seen := {}
	for seed_value in [1, 2, 3, 4, 5, 6]:
		await _new_match(settings, true, null, seed_value)
		seen[seed_value] = _ids(_rounds.get_draft(_player))
	_check("The draft comes from the seeded generator: seed 5 gives the same draft again, other seeds others",
			seen[5] == first_draft and _distinct(seen.values()) >= 3, str(seen.values()))
	# Half time: bots switch within their drafts and the teams stay mixed.
	settings = _settings()
	settings.class_draft = true
	settings.rounds_to_win = 3
	await _new_match(settings, false, null, 4)
	var before := {}
	for member in _rounds.get_participants():
		before[member] = member.class_data
	for round_number in 2:
		await _wait_for_phase(RoundManager.Phase.LIVE)
		for member in _rounds.get_members(1):
			member.take_damage(500.0, Hitbox.Zone.CHEST, null)
		await _wait_for_phase(RoundManager.Phase.FREEZE)
	var switched := 0
	var within := true
	for member in _rounds.get_participants():
		within = within and _rounds.get_draft(member).has(member.class_data)
		if member.class_data != before[member]:
			switched += 1
	var mixed := _distinct(_class_ids(_rounds.get_members(0))) == 3 and _distinct(_class_ids(_rounds.get_members(1))) == 3
	_check("At half time bots switch to their other drafted class where the team keeps its mix (most do), never outside their draft",
			_rounds.round_number == 3 and switched >= 3 and within and mixed,
			"round %d, %d of 6 switched, within drafts %s, mixed %s" % [_rounds.round_number, switched, within, mixed])
	# Team respawn: only your two as well.
	var respawn_settings := _settings()
	respawn_settings.class_draft = true
	respawn_settings.game_mode = MatchSettings.GameMode.TEAM_RESPAWN
	_remove_map()
	_map = MAP_SCENE.instantiate()
	add_child(_map)
	_player = _map.get_node("Player")
	_silence(_player)
	var respawn := RespawnMatch.new()
	respawn.settings = respawn_settings
	respawn.rng.seed = 5
	_map.add_child(respawn)
	await _wait_ticks(3)
	var respawn_draft := respawn.get_draft(_player)
	var outside: ClassData = ClassData.all().filter(func(data: ClassData) -> bool: return not respawn_draft.has(data))[0]
	_check("Team respawn drafts too: your other class is accepted, one you weren't offered isn't",
			respawn.request_class(_player, respawn_draft[1]) and not respawn.request_class(_player, outside),
			"draft %s" % [_ids(respawn_draft)])
	menu.queue_free()
	_remove_map()
	await _wait_ticks(2)


# --- Helpers ---


## Match settings with the short timings of this test: first to 15, so no round ends the match.
## The class draft is off (the M6 rules: any class, bots one of each in turn); [method _test_class_draft]
## switches it on.
func _settings() -> MatchSettings:
	var settings := MatchSettings.new()
	settings.class_draft = false
	settings.freeze_time = FREEZE_TIME
	settings.round_time = ROUND_TIME
	settings.round_end_time = ROUND_END_TIME
	settings.rounds_to_win = 15
	return settings


## Starts a match on a fresh test map with [param settings] (the defaults of [method _settings] if
## null), with the player on the map unless [param with_player] is false, and [param seed_value] as the seed. A class
## menu is given the rules before the match starts at the end of the first frame.
func _new_match(settings: MatchSettings, with_player: bool = true, menu: ClassMenu = null, seed_value: int = 5) -> void:
	_remove_map()
	_changes.clear()
	_map = MAP_SCENE.instantiate()
	if not with_player:
		_map.get_node("Player").free()
	add_child(_map)
	_player = _map.get_node_or_null("Player")
	if _player != null:
		_silence(_player)
	_rounds = RoundManager.new()
	_rounds.settings = settings if settings != null else _settings()
	_rounds.rng.seed = seed_value
	_rounds.class_changed.connect(func(character: Character, data: ClassData) -> void: _changes.append([character, data.id]))
	_map.add_child(_rounds)
	if menu != null:
		menu.set_rules(_rounds, _player)
	await _wait_ticks(2)
	for character in _rounds.get_participants():
		_silence(character)


func _remove_map() -> void:
	if _map != null:
		remove_child(_map)
		_map.queue_free()
		_map = null


## The class ids of [param characters], in order.
func _class_ids(characters: Array) -> Array:
	return characters.map(func(character: Character) -> StringName: return character.class_data.id)


## How many different values there are in [param values].
## The ids of [param classes] (ClassData resources).
func _ids(classes: Array) -> Array:
	return classes.map(func(data: ClassData) -> StringName: return data.id)


func _distinct(values: Array) -> int:
	var seen := {}
	for value in values:
		seen[value] = true
	return seen.size()


## A bot with the class [param data] (the default class if null) at [param at], with its sounds off.
func _add_bot(team: int, data: ClassData, at: Vector3) -> Character:
	var bot := BOT_SCENE.instantiate() as Character
	bot.team = team
	bot.position = at
	if data != null:
		bot.class_data = data
	_silence(bot)
	add_child(bot)
	return bot


## The file of the model under a character's body.
func _model_path(character: Character) -> String:
	var model := character.body.get_node_or_null("Model")
	return model.scene_file_path if model != null else ""


func _zone_box(character: Character, zone: Hitbox.Zone) -> Hitbox:
	for hitbox in character.body.get_hitboxes():
		if hitbox.zone == zone:
			return hitbox
	return null


## Sends an action press the way the keyboard would (through the input system).
func _press_action(action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)


## Sends a key press by physical key.
func _press_key(key: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = key
	event.keycode = key
	event.pressed = true
	Input.parse_input_event(event)


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


func _wait_for_phase(phase: RoundManager.Phase) -> void:
	var ticks := 0
	while _rounds.phase != phase and ticks < 128 * 10:
		await get_tree().physics_frame
		ticks += 1


func _wait_for_live(manager: RoundManager) -> void:
	var ticks := 0
	while manager.phase != RoundManager.Phase.LIVE and ticks < 128 * 10:
		await get_tree().physics_frame
		ticks += 1


func _wait_ticks(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _check(check_name: String, passed: bool, detail: String) -> void:
	print("%s  %s: %s" % ["PASS" if passed else "FAIL", check_name, detail])
	if not passed:
		_failures += 1
