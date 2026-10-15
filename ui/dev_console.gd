class_name DevConsole
extends CanvasLayer
## Developer console, like CS's: open it with the key left of 1 (` / ~),
## type a command and press Enter. "help" lists the commands.
##
## While it's open, the player's controls ignore the keyboard and mouse.
## Up and down recall earlier commands; Esc or the console key closes it.

## How many output lines are kept on screen.
const MAX_LINES := 14
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

@onready var _output: Label = $Panel/Margin/Box/Output
@onready var _input_line: LineEdit = $Panel/Margin/Box/Input


func _ready() -> void:
	visible = false
	is_open = false
	_input_line.text_submitted.connect(_on_text_submitted)
	_register_commands()
	print_line("Chiip console. Type 'help' for the list of commands.")


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_console") or (is_open and event.is_action_pressed("toggle_mouse")):
		set_open(not is_open)
		get_viewport().set_input_as_handled()
	elif is_open and event is InputEventKey and event.is_pressed():
		var key := (event as InputEventKey).keycode
		if key == KEY_UP or key == KEY_DOWN:
			_browse_history(-1 if key == KEY_UP else 1)
			get_viewport().set_input_as_handled()


## Opens or closes the console.
func set_open(open: bool) -> void:
	is_open = open
	visible = open
	if open:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_input_line.clear()
		_input_line.grab_focus()
	else:
		_input_line.release_focus()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## Scales the console; 1.0 is the size it's designed for (a 720-pixel-tall
## window). Its look comes from the UI theme (D-057), scaled by [UiTheme].
func set_ui_scale(factor: float) -> void:
	UiTheme.apply(self, factor)


## Adds a line to the console output.
func print_line(text: String) -> void:
	_lines.append(text)
	while _lines.size() > MAX_LINES:
		_lines.pop_front()
	_output.text = "\n".join(_lines)


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
	register_command("clear", func(_args: Array) -> void: _lines.clear(); _output.text = "", "clear", "Clear the console")
	register_command("bot_add", _cmd_bot_add, "bot_add [easy|normal|hard] [ally|enemy]", "Add a bot (ally = on your team)")
	register_command("bot_kick", _cmd_bot_kick, "bot_kick [all]", "Remove the newest bot, or all bots")
	register_command("bot_difficulty", _cmd_bot_difficulty, "bot_difficulty <easy|normal|hard>", "Set the skill of all bots, including new ones")
	register_command("god", _cmd_god, "god", "Toggle taking no damage")
	register_command("noclip", _cmd_noclip, "noclip", "Toggle flying through walls")
	register_command("mp_friendlyfire", _cmd_friendly_fire, "mp_friendlyfire [0|1]", "Teammates can hurt each other (no argument: show)")
	register_command("map", _cmd_map, "map <name>", "Load a map, e.g. map test_map (no name: list maps)")


func _cmd_help(_args: Array) -> void:
	var names := _commands.keys()
	names.sort()
	for command_name in names:
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
