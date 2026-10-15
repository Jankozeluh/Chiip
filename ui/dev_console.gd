class_name DevConsole
extends CanvasLayer
## Developer console, like CS's: open it with the key left of 1 (` / ~),
## type a command and press Enter. "help" lists the commands.
##
## While it's open, the player's controls ignore the keyboard and mouse: it
## registers with [MenuState] like the menus do. Up and down recall earlier
## commands; Esc or the console key closes it (Esc closes only the console, even
## over the pause menu). It works while the game is paused too
## ([code]process_mode = Always[/code], D-065). The output shows the last
## [constant VISIBLE_LINES] lines; the mouse wheel and Page Up / Page Down
## scroll back through the last [constant HISTORY_LINES], so a long answer such
## as [code]help[/code] is never lost.

## How many output lines show at once. The panel is as tall as this many lines
## need: [code]help[/code] (one line per command, plus the echo of the command) fits.
const VISIBLE_LINES := 17
## How many output lines are kept to scroll back through.
const HISTORY_LINES := 200
## How many lines the mouse wheel scrolls per notch.
const WHEEL_LINES := 3
const MAPS_FOLDER := "res://maps/"
const DIFFICULTY_PATH := "res://bots/difficulty_%s.tres"

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
## How many lines the output is scrolled back from the newest (0 = showing the end).
var _scroll_back: int = 0

@onready var _panel: PanelContainer = $Panel
@onready var _output: Label = $Panel/Margin/Box/Output
@onready var _input_line: LineEdit = $Panel/Margin/Box/Input


func _ready() -> void:
	visible = false
	is_open = false
	_input_line.text_submitted.connect(_on_text_submitted)
	_output.max_lines_visible = VISIBLE_LINES
	_register_commands()
	print_line("Chiip console. Type 'help' for the list of commands (mouse wheel or Page Up scrolls back).")


func _input(event: InputEvent) -> void:
	# A menu waiting for a key to bind would lose it to the console key.
	if MenuState.capturing_input:
		return
	if event.is_action_pressed("toggle_console") or (is_open and event.is_action_pressed("pause")):
		set_open(not is_open)
		get_viewport().set_input_as_handled()
	elif is_open and event is InputEventKey and event.is_pressed():
		var key := (event as InputEventKey).keycode
		if key == KEY_UP or key == KEY_DOWN:
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


## Adds a line to the console output (and scrolls down to it).
func print_line(text: String) -> void:
	_lines.append(text)
	while _lines.size() > HISTORY_LINES:
		_lines.pop_front()
	_scroll_back = 0
	_refresh_output()


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


## The lines the output shows right now, oldest first (for tests).
func get_visible_lines() -> Array[String]:
	var first := maxi(0, _lines.size() - VISIBLE_LINES - _scroll_back)
	return _lines.slice(first, first + VISIBLE_LINES)


## Shows the last [constant VISIBLE_LINES] lines, or the ones [member _scroll_back] lines before them.
func _refresh_output() -> void:
	var hidden := maxi(0, _lines.size() - VISIBLE_LINES)
	_scroll_back = clampi(_scroll_back, 0, hidden)
	_output.text = "\n".join(_lines)
	_output.lines_skipped = hidden - _scroll_back


## Runs one command line, e.g. "bot_add hard". Public so tests can use it.
func run(command_line: String) -> void:
	var parts := command_line.strip_edges().split(" ", false)
	if parts.is_empty():
		return
	print_line("> " + command_line.strip_edges())
	var command_name := parts[0].to_lower()
	if not _commands.has(command_name):
		print_line("Unknown command '%s'. Type 'help'." % command_name)
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


# --- Commands ---


func _register_commands() -> void:
	register_command("help", _cmd_help, "help", "List all commands")
	register_command("clear", func(_args: Array) -> void: _lines.clear(); _refresh_output(), "clear", "Clear the console")
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
	register_command("disconnect", _cmd_disconnect, "disconnect", "Leave the game for the main menu")


func _cmd_help(_args: Array) -> void:
	for command_name in get_command_names():
		print_line("%-40s %s" % [_commands[command_name][1], _commands[command_name][2]])


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
	if args[0] != "0" and args[0] != "1":
		print_line("Usage: mp_friendlyfire [0|1]")
		return
	Teams.friendly_fire = args[0] == "1"
	print_line("Friendly fire %s." % ("on: teammates take a third of the damage" if Teams.friendly_fire else "off"))


func _cmd_god(_args: Array) -> void:
	var player := _get_player()
	if player != null:
		player.god_mode = not player.god_mode
		print_line("God mode %s." % ("on" if player.god_mode else "off"))


func _cmd_noclip(_args: Array) -> void:
	var player := _get_player()
	if player != null:
		player.noclip = not player.noclip
		print_line("Noclip %s." % ("on" if player.noclip else "off"))


func _cmd_map(args: Array) -> void:
	if args.is_empty():
		print_line("Maps: " + ", ".join(_list_maps()))
		return
	var path: String = args[0] if args[0].begins_with("res://") else MAPS_FOLDER + args[0] + ".tscn"
	if not ResourceLoader.exists(path):
		print_line("No map '%s'. Maps: %s" % [args[0], ", ".join(_list_maps())])
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
			print_line("Usage: %s [value]" % command_name)
			return
		settings.set_value(key, text.to_float())
	print_line("%s = %s" % [command_name, settings.get_value(key)])


## Opens the settings menu over the game and closes the console, so the menu has
## the keyboard and the mouse. The main menu's and the pause menu's Settings buttons open it too.
func _cmd_settings(_args: Array) -> void:
	if main == null:
		print_line("There is no game to open the settings menu in.")
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
		print_line("There is no game to leave.")
		return
	main.return_to_menu()


# --- Helpers ---


func _get_map() -> Node:
	return main.get_map() if main != null else null


func _get_player() -> Character:
	var map := _get_map()
	return map.get_node_or_null("Player") as Character if map != null else null


func _get_arena() -> ArenaRules:
	var map := _get_map()
	var arena := map.get_node_or_null("ArenaRules") as ArenaRules if map != null else null
	if arena == null:
		print_line("Bot commands work in practice mode only (bots in a match are part of the teams).")
	return arena


func _load_difficulty(level: String) -> BotDifficulty:
	var path := DIFFICULTY_PATH % level.to_lower()
	if not ResourceLoader.exists(path):
		print_line("Unknown difficulty '%s'. Use easy, normal or hard." % level)
		return null
	return load(path)


## Map scenes in maps/ and its subfolders, as names the map command accepts.
func _list_maps() -> PackedStringArray:
	var maps := PackedStringArray()
	for folder in ["", "comparison/"]:
		for file in DirAccess.get_files_at(MAPS_FOLDER + folder):
			if file.ends_with(".tscn"):
				maps.append(folder + file.trim_suffix(".tscn"))
	return maps
