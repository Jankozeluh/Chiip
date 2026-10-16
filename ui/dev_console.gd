class_name DevConsole
extends CanvasLayer
## Developer console, like CS's: open it with the key left of 1 (` / ~),
## type a command and press Enter. "help" lists the commands.
##
## A strip across the top of the screen as in mockup 17 (M10 task 13): the output, bottom-aligned
## and in four colours by kind of line (normal text, echoed commands dimmed, the opening
## banner muted, errors in the alert colour), over an input row with a lime prompt and a
## hint. The colours come from the UI theme as type variations of the line labels, not from
## the script.
##
## While it's open, the player's controls ignore the keyboard and mouse: it
## registers with [MenuState] like the menus do. Up and down recall earlier
## commands, Tab completes a command's name (to the only command that starts that way, or as
## far as all the matching ones agree; a second Tab lists them), Esc or the console key
## closes it (Esc closes only the console, even over the pause menu). It works while the game
## is paused too ([code]process_mode = Always[/code], D-065). The output shows the last
## [constant VISIBLE_LINES] lines; the mouse wheel and Page Up / Page Down scroll back
## through the last [constant HISTORY_LINES], so a long answer such as [code]help[/code]
## is never lost.

## How many output lines show at once: the ones that fit the 384 px strip (mockup 17). The scene
## has one line label, copied to this many in [method _ready].
const VISIBLE_LINES := 11
## How many output lines are kept to scroll back through.
const HISTORY_LINES := 200
## How many lines the mouse wheel scrolls per notch.
const WHEEL_LINES := 3
const MAPS_FOLDER := "res://maps/"
const DIFFICULTY_PATH := "res://bots/difficulty_%s.tres"
## The theme roles (type variations of [Label]) a line is drawn with: normal output, an echoed
## command, a note (the opening banner) and an error.
const ROLE_NORMAL := &"ConsoleLabel"
const ROLE_ECHO := &"DimLabel"
const ROLE_NOTE := &"MuteLabel"
const ROLE_ERROR := &"ConsoleErrorLabel"
## The milestone shown in the opening banner.
const BANNER_MILESTONE := "M10"

## True while the console is open. Read by the player's controls, so they stop
## reacting to keys and the mouse.
static var is_open: bool = false

## The main scene, set by main.gd. Used to find the current map and change maps.
var main: Node

## Command name → [callable taking the arguments, usage text, description].
var _commands: Dictionary = {}
var _history: Array[String] = []
var _history_index: int = 0
var _lines: Array[String] = []
## The theme role each of [member _lines] is drawn with (one of the ROLE_ constants).
var _roles: Array[StringName] = []
## The line labels, top to bottom: [constant VISIBLE_LINES] of them, the unused ones hidden.
var _line_labels: Array[Label] = []
## How many lines the output is scrolled back from the newest (0 = showing the end).
var _scroll_back: int = 0

@onready var _panel: PanelContainer = $Panel
@onready var _lines_box: VBoxContainer = $Panel/Box/OutputMargin/Lines
@onready var _input_line: LineEdit = $Panel/Box/InputRow/Row/Input


func _ready() -> void:
	visible = false
	is_open = false
	_input_line.text_submitted.connect(_on_text_submitted)
	_build_line_labels()
	_register_commands()
	var version := Engine.get_version_info()
	print_line("Chiip %s · Godot %d.%d.%d · type help" % [BANNER_MILESTONE, version.major, version.minor, version.patch], ROLE_NOTE)


func _input(event: InputEvent) -> void:
	# A menu waiting for a key to bind would lose it to the console key.
	if MenuState.capturing_input:
		return
	if event.is_action_pressed("toggle_console") or (is_open and event.is_action_pressed("pause")):
		set_open(not is_open)
		get_viewport().set_input_as_handled()
	elif is_open and event is InputEventKey and event.is_pressed():
		var key := (event as InputEventKey).keycode
		if key == KEY_TAB:
			_complete_input()
			get_viewport().set_input_as_handled()
		elif key == KEY_UP or key == KEY_DOWN:
			_browse_history(-1 if key == KEY_UP else 1)
			get_viewport().set_input_as_handled()
		elif key == KEY_PAGEUP or key == KEY_PAGEDOWN:
			scroll_output(VISIBLE_LINES - 2 if key == KEY_PAGEUP else 2 - VISIBLE_LINES)
			get_viewport().set_input_as_handled()
	elif is_open and event is InputEventMouseButton and event.is_pressed() and _panel.get_global_rect().has_point((event as InputEventMouseButton).position):
		var button := (event as InputEventMouseButton).button_index
		if button == MOUSE_BUTTON_WHEEL_UP or button == MOUSE_BUTTON_WHEEL_DOWN:
			scroll_output(WHEEL_LINES if button == MOUSE_BUTTON_WHEEL_UP else -WHEEL_LINES)
			get_viewport().set_input_as_handled()


## Opens or closes the console. It registers with [MenuState], so the mouse is
## shown while it is open and captured again when the last menu closes.
func set_open(open: bool) -> void:
	is_open = open
	visible = open
	if open:
		MenuState.open(self)
		_input_line.clear()
		_input_line.grab_focus()
	else:
		_input_line.release_focus()
		MenuState.close(self)


## Scales the console; 1.0 is the size it's designed for (a 720-pixel-tall
## window). Its look comes from the UI theme (D-057), scaled by [UiTheme].
func set_ui_scale(factor: float) -> void:
	UiTheme.apply(self, factor)


## Adds a line to the console output (and scrolls down to it). [param role] is the theme role it
## is drawn with: [constant ROLE_NORMAL] unless it is an echo, a note or an error.
func print_line(text: String, role: StringName = ROLE_NORMAL) -> void:
	_lines.append(text)
	_roles.append(role)
	while _lines.size() > HISTORY_LINES:
		_lines.pop_front()
		_roles.pop_front()
	_scroll_back = 0
	_refresh_output()


## Adds a line in the alert colour: a command that failed or was used wrongly.
func print_error(text: String) -> void:
	print_line(text, ROLE_ERROR)


## Scrolls the output back ([param lines] > 0, towards older lines) or forward
## (< 0), as far as there are lines. Page Up, Page Down and the mouse wheel do this.
func scroll_output(lines: int) -> void:
	_scroll_back += lines
	_refresh_output()


## The names of all commands, sorted (what [code]help[/code] lists).
func get_command_names() -> Array:
	var names := _commands.keys()
	names.sort()
	return names


## Every line kept, oldest first, joined by newlines (for tests).
func get_output_text() -> String:
	return "\n".join(_lines)


## The lines the output shows right now, oldest first (for tests).
func get_visible_lines() -> Array[String]:
	var first := maxi(0, _lines.size() - VISIBLE_LINES - _scroll_back)
	return _lines.slice(first, first + VISIBLE_LINES)


## Makes [constant VISIBLE_LINES] line labels out of the one the scene has (they scale with the
## console like it, because [method _ready] runs before the first [method set_ui_scale]).
func _build_line_labels() -> void:
	var first := _lines_box.get_child(0) as Label
	_line_labels.append(first)
	for i in range(1, VISIBLE_LINES):
		var copy := first.duplicate() as Label
		_lines_box.add_child(copy)
		_line_labels.append(copy)


## Shows the last [constant VISIBLE_LINES] lines, or the ones [member _scroll_back] lines before
## them, each in its role's colour. The labels below the last line are hidden, so the lines stay
## at the bottom of the strip.
func _refresh_output() -> void:
	var hidden := maxi(0, _lines.size() - VISIBLE_LINES)
	_scroll_back = clampi(_scroll_back, 0, hidden)
	var first := hidden - _scroll_back
	for i in _line_labels.size():
		var label := _line_labels[i]
		var index := first + i
		label.visible = index < _lines.size()
		if label.visible:
			label.text = _lines[index]
			if label.theme_type_variation != _roles[index]:
				label.theme_type_variation = _roles[index]


## Runs one command line, e.g. "bot_add hard". Public so tests can use it.
func run(command_line: String) -> void:
	var parts := command_line.strip_edges().split(" ", false)
	if parts.is_empty():
		return
	print_line("> " + command_line.strip_edges(), ROLE_ECHO)
	var command_name := parts[0].to_lower()
	if not _commands.has(command_name):
		print_error("Unknown command: %s" % command_name)
		return
	(_commands[command_name][0] as Callable).call(Array(parts.slice(1)))


## Adds a command. [param action] receives the arguments as an Array of Strings.
func register_command(command_name: String, action: Callable, usage: String, description: String) -> void:
	_commands[command_name] = [action, usage, description]


func _on_text_submitted(text: String) -> void:
	if text.strip_edges() != "":
		_history.append(text)
	_history_index = _history.size()
	_input_line.clear()
	run(text)


func _browse_history(step: int) -> void:
	if _history.is_empty():
		return
	_history_index = clampi(_history_index + step, 0, _history.size())
	_input_line.text = _history[_history_index] if _history_index < _history.size() else ""
	_input_line.caret_column = _input_line.text.length()


## The command names that start with [param prefix] (case does not matter), sorted.
func get_matches(prefix: String) -> Array:
	var start := prefix.strip_edges(true, false).to_lower()
	return get_command_names().filter(func(command_name: String) -> bool: return command_name.begins_with(start))


## What Tab makes of [param text]: the only command whose name starts with it (and a space,
## ready for the arguments), or as much of the name as all the matching commands share, or the
## text unchanged when none matches, when it is empty or when it already has an argument.
func complete(text: String) -> String:
	var typed := text.strip_edges(true, false)
	if typed == "" or typed.contains(" "):
		return text
	var matches := get_matches(typed)
	if matches.is_empty():
		return text
	if matches.size() == 1:
		return matches[0] + " "
	var common := String(matches[0])
	for command_name: String in matches:
		while not command_name.begins_with(common):
			common = common.left(-1)
	return common if common.length() > typed.length() else text


## Tab in the input line: puts the completion there; when it can't go further because several
## commands match, lists them in the output (like a shell's second Tab).
func _complete_input() -> void:
	var before := _input_line.text
	var after := complete(before)
	if after != before:
		_input_line.text = after
		_input_line.caret_column = after.length()
	elif before.strip_edges() != "" and not before.strip_edges().contains(" ") and get_matches(before).size() > 1:
		print_line("  ".join(get_matches(before)))


# --- Commands ---


func _register_commands() -> void:
	register_command("help", _cmd_help, "help", "List all commands")
	register_command("clear", func(_args: Array) -> void: _lines.clear(); _roles.clear(); _refresh_output(), "clear", "Clear the console")
	register_command("bot_add", _cmd_bot_add, "bot_add [easy|normal|hard] [ally|enemy]", "Add a bot (ally = on your team)")
	register_command("bot_kick", _cmd_bot_kick, "bot_kick [all]", "Remove the newest bot, or all bots")
	register_command("bot_difficulty", _cmd_bot_difficulty, "bot_difficulty <easy|normal|hard>", "Set the skill of all bots, including new ones")
	register_command("god", _cmd_god, "god", "Toggle taking no damage")
	register_command("noclip", _cmd_noclip, "noclip", "Toggle flying through walls")
	register_command("mp_friendlyfire", _cmd_friendly_fire, "mp_friendlyfire [0|1]", "Teammates can hurt each other (no argument: show)")
	register_command("map", _cmd_map, "map <name>", "Load a map, e.g. map test_map (no name: list maps)")
	register_command("sensitivity", _cmd_setting.bind(&"sensitivity", "sensitivity"), "sensitivity [0.05-10]", "Mouse sensitivity, CS scale (no value: show)")
	register_command("fov", _cmd_setting.bind(&"fov", "fov"), "fov [70-110]", "Field of view across a 4:3 screen, like CS (no value: show)")
	register_command("volume", _cmd_setting.bind(&"master_volume", "volume"), "volume [0-1]", "Master volume (no value: show)")
	register_command("fps_max", _cmd_setting.bind(&"fps_cap", "fps_max"), "fps_max [0|30-1000]", "Frame rate limit, 0 = unlimited (no value: show)")
	register_command("settings", _cmd_settings, "settings", "Open the settings menu (Esc closes it)")
	register_command("settings_reset", _cmd_settings_reset, "settings_reset", "Put every setting, key and the match setup back to its default")
	register_command("disconnect", _cmd_disconnect, "disconnect", "Leave the game for the main menu (online: leave the session)")
	register_command("class", _cmd_class, "class [name]", "List the classes, or take one (in a match: during freeze time)")
	register_command("armor", _cmd_armor, "armor [0-100] [helmet]", "Set your armor, with or without a helmet (no value: show)")
	register_command("money", _cmd_money, "money [amount]", "Set your money in a match (no value: show)")
	register_command("status", _cmd_status, "status", "Online: the session, the players, ping, loss and corrections")
	register_command("net_fakelag", _cmd_fake.bind("lag"), "net_fakelag [ms]", "Online: delay everything this computer receives (no value: show)")
	register_command("net_fakeloss", _cmd_fake.bind("loss"), "net_fakeloss [percent]", "Online: drop this share of the snapshots or commands received (no value: show)")


func _cmd_help(_args: Array) -> void:
	for command_name in get_command_names():
		print_line("%s · %s" % [_commands[command_name][1], _commands[command_name][2]])


## bot_add takes a difficulty and a side in either order: "bot_add hard ally", "bot_add ally".
func _cmd_bot_add(args: Array) -> void:
	var arena := _get_arena()
	if arena == null:
		return
	var level: String = arena.bot_difficulty.display_name
	var ally := false
	for arg: String in args:
		match arg.to_lower():
			"ally":
				ally = true
			"enemy":
				ally = false
			_:
				level = arg
	var difficulty := _load_difficulty(level)
	if difficulty == null:
		return
	var player := _get_player()
	var player_team := player.team if player != null else 0
	var bot := arena.add_bot(difficulty, player_team if ally else Teams.other(player_team))
	print_line("Added %s (%s, %s)." % [bot.name, difficulty.display_name, "ally" if ally else "enemy"])


func _cmd_bot_kick(args: Array) -> void:
	var arena := _get_arena()
	if arena == null:
		return
	var kicked := 0
	while arena.remove_bot():
		kicked += 1
		if args.is_empty() or args[0] != "all":
			break
	print_line("Removed %d bot(s)." % kicked if kicked > 0 else "There are no bots.")


func _cmd_bot_difficulty(args: Array) -> void:
	var arena := _get_arena()
	if arena == null:
		return
	if args.is_empty():
		print_line("Bots are %s. Usage: bot_difficulty <easy|normal|hard>" % arena.bot_difficulty.display_name)
		return
	var difficulty := _load_difficulty(args[0])
	if difficulty == null:
		return
	arena.bot_difficulty = difficulty
	for bot in arena.get_bots():
		(bot.get_node("BotController") as BotController).difficulty = difficulty
	print_line("Bots are now %s." % difficulty.display_name)


func _cmd_friendly_fire(args: Array) -> void:
	if args.is_empty():
		print_line("mp_friendlyfire = %d" % (1 if Teams.friendly_fire else 0))
		return
	if _refuse_online("mp_friendlyfire"):
		return
	if args[0] != "0" and args[0] != "1":
		print_error("Usage: mp_friendlyfire [0|1]")
		return
	Teams.friendly_fire = args[0] == "1"
	print_line("Friendly fire %s." % ("on: teammates take a third of the damage" if Teams.friendly_fire else "off"))


func _cmd_god(_args: Array) -> void:
	if _refuse_online("god"):
		return
	var player := _get_player()
	if player != null:
		player.god_mode = not player.god_mode
		print_line("God mode %s." % ("on" if player.god_mode else "off"))


func _cmd_armor(args: Array) -> void:
	var player := _get_player()
	if player == null:
		return
	if not args.is_empty():
		if _refuse_online("armor"):
			return
		player.set_armor(float(args[0]), args.size() > 1 and String(args[1]) == "helmet")
	print_line("Armor %d%s." % [ceili(player.armor), " with a helmet" if player.has_helmet else ""])


func _cmd_money(args: Array) -> void:
	var player := _get_player()
	var rules := _get_rules() as RoundManager
	if player == null or rules == null or not rules.has_economy():
		print_error("There is no money here (only in a match with rounds).")
		return
	if not args.is_empty():
		if _refuse_online("money"):
			return
		rules.add_money(player, int(args[0]) - rules.get_money(player), "Console")
	print_line("You have $%d." % rules.get_money(player))


func _cmd_noclip(_args: Array) -> void:
	if _refuse_online("noclip"):
		return
	var player := _get_player()
	if player != null:
		player.noclip = not player.noclip
		print_line("Noclip %s." % ("on" if player.noclip else "off"))


func _cmd_map(args: Array) -> void:
	if args.is_empty():
		print_line("Maps: " + ", ".join(_list_maps()))
		return
	if _refuse_online("map"):
		return
	var path: String = args[0] if args[0].begins_with("res://") else MAPS_FOLDER + args[0] + ".tscn"
	if not ResourceLoader.exists(path):
		print_error("No map '%s'. Maps: %s" % [args[0], ", ".join(_list_maps())])
		return
	main.change_map(path)
	print_line("Loaded %s." % path)


## Shows or changes a number setting: [param command_name] is what the player
## typed, [param key] the setting behind it. The shown value is the one the
## setting really took (it is clamped to its range).
func _cmd_setting(args: Array, key: StringName, command_name: String) -> void:
	var settings := Settings.get_instance()
	if not args.is_empty():
		var text: String = args[0]
		if not text.is_valid_float():
			print_error("Usage: %s [value]" % command_name)
			return
		settings.set_value(key, text.to_float())
	print_line("%s = %s" % [command_name, settings.get_value(key)])


## Opens the settings menu over the game and closes the console, so the menu has
## the keyboard and the mouse. The main menu's and the pause menu's Settings buttons open it too.
func _cmd_settings(_args: Array) -> void:
	if main == null:
		print_error("There is no game to open the settings menu in.")
		return
	main.open_settings()
	# Opened first: the mouse stays free for the menu when the console closes.
	set_open(false)


func _cmd_settings_reset(_args: Array) -> void:
	Settings.get_instance().reset_to_defaults()
	print_line("All settings, keys and the match setup are back to their defaults.")


## Leaves the game for the main menu, like CS's disconnect (D-064). The current
## match is dropped; the menu's Play starts a new one.
func _cmd_disconnect(_args: Array) -> void:
	if main == null:
		print_error("There is no game to leave.")
		return
	if main.get("net_session") != null:
		# Online: leave the session (the host ends it for everyone), like CS's disconnect.
		main.leave_online()
		return
	main.return_to_menu()


## Online (M9): the session's state, from the network code of the game ([method NetHost.get_status_lines]
## or [method NetClient.get_status_lines]).
func _cmd_status(_args: Array) -> void:
	var net_game: Node = main.get_net_game() if main != null and main.has_method("get_net_game") else null
	if net_game == null:
		print_line("Not online. Multiplayer is in the main menu.")
		return
	for line: String in net_game.get_status_lines():
		print_line(line)


## net_fakelag and net_fakeloss: make this computer's connection worse on purpose, like CS's.
func _cmd_fake(args: Array, which: String) -> void:
	var session: NetSession = main.get("net_session") if main != null else null
	if session == null or not is_instance_valid(session):
		print_line("Not online.")
		return
	if args.is_empty():
		if which == "lag":
			print_line("net_fakelag = %d ms" % roundi(session.fake_lag_ms))
		else:
			print_line("net_fakeloss = %d%%" % roundi(session.fake_loss * 100.0))
		return
	if not String(args[0]).is_valid_float():
		print_line("Usage: net_fake%s <number>" % which)
		return
	var value := float(args[0])
	if which == "lag":
		session.fake_lag_ms = clampf(value, 0.0, 1000.0)
		print_line("Everything this computer receives now waits %d ms longer." % roundi(session.fake_lag_ms))
	else:
		session.fake_loss = clampf(value / 100.0, 0.0, 0.9)
		print_line("%d%% of the unreliable packets this computer receives are dropped." % roundi(session.fake_loss * 100.0))


## Online, a cheat or a change to the match would be unfair or fight the host (D-109): says so
## and returns true. Offline returns false.
func _refuse_online(command_name: String) -> bool:
	if main != null and main.get("net_session") != null:
		print_line("%s only works offline." % command_name)
		return true
	return false


## class lists the classes and tells which one you are; class bulwark asks the game rules for
## that class (a match allows one of your two drafted classes during freeze time only, practice
## mode any class any time).
func _cmd_class(args: Array) -> void:
	var player := _get_player()
	if player == null:
		return
	if args.is_empty():
		for data in ClassData.all():
			print_line("%s · %.2f m · %s: %s" % [data.id, data.height, data.perk_name, data.perk_description])
		print_line("You are the %s." % (player.class_data.display_name if player.class_data != null else "?"))
		return
	var data := ClassData.find(StringName(String(args[0]).to_lower()))
	if data == null:
		print_error("Unknown class '%s'. Classes: %s" % [args[0], ", ".join(ClassData.all().map(func(c: ClassData) -> String: return String(c.id)))])
		return
	var rules := _get_rules()
	var accepted := true
	if rules is RoundManager:
		accepted = (rules as RoundManager).request_class(player, data)
	elif rules is ArenaRules:
		accepted = (rules as ArenaRules).request_class(player, data)
	else:
		player.class_data = data
	if accepted:
		print_line("You are the %s now." % data.display_name)
	elif rules is RoundManager and not (rules as RoundManager).is_drafted(player, data):
		var draft := (rules as RoundManager).get_draft(player).map(func(c: ClassData) -> String: return c.display_name)
		print_error("Your draft this match is %s." % " or ".join(draft))
	else:
		print_error("You can change class only during freeze time.")


# --- Helpers ---


func _get_map() -> Node:
	return main.get_map() if main != null else null


func _get_player() -> Character:
	if main != null and main.has_method("get_player") and main.get_player() != null:
		# Online the player's node is named after them (M9).
		return main.get_player()
	var map := _get_map()
	return map.get_node_or_null("Player") as Character if map != null else null


## The map's game rules: the match ([RoundManager]) or practice mode ([ArenaRules]), or null.
func _get_rules() -> Node:
	var map := _get_map()
	if map == null:
		return null
	var rounds := map.get_node_or_null("RoundManager")
	return rounds if rounds != null else map.get_node_or_null("ArenaRules")


func _get_arena() -> ArenaRules:
	var map := _get_map()
	var arena := map.get_node_or_null("ArenaRules") as ArenaRules if map != null else null
	if arena == null:
		print_error("Bot commands work in practice mode only (bots in a match are part of the teams).")
	return arena


func _load_difficulty(level: String) -> BotDifficulty:
	var path := DIFFICULTY_PATH % level.to_lower()
	if not ResourceLoader.exists(path):
		print_error("Unknown difficulty '%s'. Use easy, normal or hard." % level)
		return null
	return load(path)


## Map scenes in maps/ and its subfolders, as names the map command accepts.
## Uses ResourceLoader's listing, which also works in an exported game, where
## scenes are stored converted (DirAccess would only see "depot.tscn.remap").
func _list_maps() -> PackedStringArray:
	var maps := PackedStringArray()
	for folder in ["", "comparison/"]:
		for file in ResourceLoader.list_directory(MAPS_FOLDER + folder):
			if file.ends_with(".tscn"):
				maps.append(folder + file.trim_suffix(".tscn"))
	return maps
