class_name MatchSetup
extends CanvasLayer
## Match setup (M5 task 11, D-064): the panel the main menu's Play opens. You
## choose the mode (rounds or team respawn, D-087), the size of your team (you
## included, 1 to 5) and of the enemy team (1 to 5), the bots' difficulty, the
## match length (first to 5, 10 or 15 rounds; for team respawn first to 30, 50
## or 75 kills), friendly fire, one map or the rotation of the quick maps, and
## the map, then press Start, or Back to return to the menu.
##
## It only collects the choices and reports [signal started] and
## [signal closed]; the main menu starts the game ([GameLaunch]). Every choice is
## written to [Settings] (its [code][match][/code] section) the moment it
## changes, like the settings menu does, so the next start offers the same
## match; the Settings class clamps the values and saves them. The menu follows
## [signal Settings.changed]. [member settings] is the shared instance unless a
## test hands in its own before the panel enters the tree.
##
## The rows are segmented buttons (a [ButtonGroup] of toggle buttons: the chosen
## one looks pressed) built from one table; the map is an [OptionButton] listing
## the scenes in res://maps/ ([method GameLaunch.list_maps]), so a new map
## appears by itself. The panel registers with [MenuState] while it is open and
## Esc closes it when it is on top. Its look comes from the UI theme (D-057):
## no colors, sizes or styleboxes of its own, and [method set_ui_scale] gives it
## the theme scaled for the window like the other menus.

## Emitted when the player presses Start.
signal started
## Emitted when the panel closes (Back or Esc).
signal closed

## Widths (at 720p; the panel scales them) of a row's label and of the buttons of a segmented row.
const LABEL_WIDTH := 200.0
const NUMBER_BUTTON_WIDTH := 56.0
const WORD_BUTTON_WIDTH := 112.0
const LENGTH_BUTTON_WIDTH := 152.0
## The width of the map's option button.
const MAP_WIDTH := 360.0
## The width of the mode and maps buttons ("Team respawn", "Rotation").
const MODE_BUTTON_WIDTH := 200.0

## Where the choices are stored. The shared [Settings] when null (set before the panel is in the tree).
var settings: Settings

## Setting key → the buttons of its row, in the order of [member _segment_values].
var _segments: Dictionary = {}
## Setting key → the value each button of its row stands for.
var _segment_values: Dictionary = {}
## Setting key → its whole row (the length rows are shown for their mode only).
var _segment_rows: Dictionary = {}
## The maps the option button lists, as scene paths.
var _map_paths: Array[String] = []
var _map_option: OptionButton

@onready var _rows: VBoxContainer = %Rows
@onready var _summary: Label = %Summary
@onready var _back_button: Button = %BackButton
@onready var _start_button: Button = %StartButton


func _ready() -> void:
	visible = false
	if settings == null:
		settings = Settings.get_instance()
	_build_rows()
	settings.changed.connect(_on_setting_changed)
	_back_button.pressed.connect(close)
	_start_button.pressed.connect(started.emit)
	_refresh()


func _exit_tree() -> void:
	# Freed or removed while open (the game starts under it): don't leave the game waiting for a menu.
	MenuState.close(self)


func _input(event: InputEvent) -> void:
	if visible and MenuState.is_top(self) and event.is_action_pressed("pause"):
		close()
		get_viewport().set_input_as_handled()


## Shows the panel with the stored choices and the mouse. It stays open until
## Start or Back ([signal started], [signal closed]).
func open() -> void:
	visible = true
	MenuState.open(self)
	_refresh()
	_start_button.grab_focus()


## Hides the panel, hands the mouse back (if it was the last menu open) and emits
## [signal closed]. Does nothing when it isn't open. Start doesn't close it: the
## game scene replaces the menu.
func close() -> void:
	if not visible:
		return
	visible = false
	MenuState.close(self)
	closed.emit()


## True while the panel is shown.
func is_open() -> bool:
	return visible


## Scales the panel; 1.0 is the size it is designed for (a 720-pixel-tall
## window). Hands it the theme scaled for the window ([UiTheme]).
func set_ui_scale(factor: float) -> void:
	UiTheme.apply(self, factor)


## The [MatchSettings] for the stored choices (what Start plays): the team sizes,
## the bots' difficulty, the match length and friendly fire; the timings stay at their defaults.
func build_match_settings() -> MatchSettings:
	return GameLaunch.match_settings_from(settings)


## The scene path of the chosen map.
func get_map_path() -> String:
	return _map_paths[maxi(0, _map_option.selected)]


## The maps Start plays one after the other: the rotation, starting at the
## chosen map when it is one of the quick maps; empty for a single map.
func get_rotation_maps() -> Array[String]:
	if not settings.match_rotation:
		return []
	return GameLaunch.rotation_maps(get_map_path())


## The maps on offer, as scene paths, in the order the option button lists them.
func get_map_paths() -> Array[String]:
	return _map_paths


## The line that sums up the choices ("You and 2 bots against 3 bots...").
func get_summary() -> String:
	return _summary.text


# --- Building the rows ---


func _build_rows() -> void:
	_add_segmented_row(&"match_mode", "Mode", ["Rounds", "Team respawn"], Settings.MATCH_MODES, MODE_BUTTON_WIDTH,
			"Rounds: one life each; on maps with bomb sites the attackers plant the bomb. Team respawn: back after 3 s, first team to the kill limit wins.")
	_add_segmented_row(&"match_team_size", "Your team", ["1", "2", "3", "4", "5"], [1, 2, 3, 4, 5],
			NUMBER_BUTTON_WIDTH, "Players on your side, you included: 3 means you and two bot teammates.")
	_add_segmented_row(&"match_enemy_team_size", "Enemy team", ["1", "2", "3", "4", "5"], [1, 2, 3, 4, 5],
			NUMBER_BUTTON_WIDTH, "Bots on the other side.")
	_add_segmented_row(&"match_difficulty", "Bot difficulty", ["Easy", "Normal", "Hard"], Settings.DIFFICULTIES,
			WORD_BUTTON_WIDTH, "How well every bot fights, your teammates too. Practice uses it as well.")
	var lengths: Array = []
	for rounds in Settings.MATCH_LENGTHS:
		lengths.append("First to %d" % rounds)
	_add_segmented_row(&"match_rounds_to_win", "Match length", lengths, Settings.MATCH_LENGTHS,
			LENGTH_BUTTON_WIDTH, "Rounds a team must win. The sides swap at half time.")
	var kills: Array = []
	for limit in Settings.KILL_LIMITS:
		kills.append("%d kills" % limit)
	_add_segmented_row(&"match_kill_limit", "Match length", kills, Settings.KILL_LIMITS,
			LENGTH_BUTTON_WIDTH, "Kills a team needs to win. After 10 minutes the team with more kills wins.")
	_add_segmented_row(&"match_friendly_fire", "Friendly fire", ["Off", "On"], [false, true],
			WORD_BUTTON_WIDTH, "On: teammates take a third of the damage. Off: bullets pass through them.")
	_add_segmented_row(&"match_rotation", "Maps", ["One map", "Rotation"], [false, true], MODE_BUTTON_WIDTH,
			"Rotation: Depot, Square and Spillway one after the other, starting with the map below if it is one of them. \"Next map\" moves on after a match.")
	_add_map_row()


## A row with the label [param label_text] on the left. Add the controls to the result.
func _add_row(label_text: String, tip: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.theme_type_variation = &"FormRow"
	_rows.add_child(row)
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(LABEL_WIDTH, 0)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# A label ignores the mouse by default, so it would never show its tooltip.
	label.mouse_filter = Control.MOUSE_FILTER_PASS
	label.tooltip_text = tip
	row.add_child(label)
	return row


## A choice among a few values as a row of toggle buttons, one pressed. [param texts]
## are the buttons' texts and [param values] what each stands for (the value
## the setting [param key] takes).
func _add_segmented_row(key: StringName, label_text: String, texts: Array, values: Array, button_width: float, tip: String) -> void:
	var row := _add_row(label_text, tip)
	var strip := HBoxContainer.new()
	# A small gap, so the buttons read as one strip.
	strip.add_theme_constant_override("separation", 4)
	row.add_child(strip)
	var group := ButtonGroup.new()
	var buttons: Array[Button] = []
	for index in texts.size():
		var button := Button.new()
		button.text = texts[index]
		button.toggle_mode = true
		button.button_group = group
		button.custom_minimum_size = Vector2(button_width, 0)
		var value: Variant = values[index]
		button.toggled.connect(func(on: bool) -> void:
			if on:
				settings.set_value(key, value))
		strip.add_child(button)
		buttons.append(button)
	_segments[key] = buttons
	_segment_values[key] = values
	_segment_rows[key] = row


func _add_map_row() -> void:
	var row := _add_row("Map", "The level to play: every scene in res://maps/.")
	_map_option = OptionButton.new()
	_map_option.custom_minimum_size = Vector2(MAP_WIDTH, 0)
	_map_option.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	row.add_child(_map_option)
	_map_paths = GameLaunch.list_maps()
	for path in _map_paths:
		_map_option.add_item(GameLaunch.map_title(path))
	_map_option.item_selected.connect(func(index: int) -> void: settings.match_map = _map_paths[index])


# --- Keeping the controls and the settings in step ---


## Shows the stored choices: the button of each row's value pressed (and the
## others not), the stored map selected (the default map, or the first, when it
## is gone), and the summary.
func _refresh() -> void:
	for key: StringName in _segments:
		var buttons: Array = _segments[key]
		var values: Array = _segment_values[key]
		var current: Variant = settings.get_value(key)
		for index in buttons.size():
			(buttons[index] as Button).set_pressed_no_signal(values[index] == current)
	var shown := _map_paths.find(settings.match_map)
	if shown < 0:
		shown = maxi(0, _map_paths.find(Settings.DEFAULT_MAP))
	_map_option.select(shown)
	# The match length counts rounds, or kills in team respawn.
	var respawn := settings.match_mode == "respawn"
	(_segment_rows[&"match_rounds_to_win"] as Control).visible = not respawn
	(_segment_rows[&"match_kill_limit"] as Control).visible = respawn
	var goal := "first to %d kills" % settings.match_kill_limit if respawn else "first to %d rounds" % settings.match_rounds_to_win
	_summary.text = "%sYou and %s against %s. %s bots, %s, friendly fire %s." % [
			"Team respawn: " if respawn else "", _bots_text(settings.match_team_size - 1), _bots_text(settings.match_enemy_team_size),
			settings.match_difficulty.capitalize(), goal, "on" if settings.match_friendly_fire else "off"]
	var rotation := get_rotation_maps()
	if not rotation.is_empty():
		_summary.text += " Maps in rotation: %s." % ", ".join(rotation.map(func(path: String) -> String: return GameLaunch.map_title(path)))


## "no bots", "1 bot", "3 bots".
static func _bots_text(count: int) -> String:
	if count <= 0:
		return "no bots"
	return "1 bot" if count == 1 else "%d bots" % count


func _on_setting_changed(key: StringName) -> void:
	if String(key).begins_with("match_"):
		_refresh()


# --- Test hooks ---


## The buttons of the row for the setting [param key] (e.g. [code]&"match_team_size"[/code]), in order.
func get_segment_buttons(key: StringName) -> Array:
	return _segments.get(key, [])


## The map's option button.
func get_map_option() -> OptionButton:
	return _map_option


## The "Start" button.
func get_start_button() -> Button:
	return _start_button


## The "Back" button.
func get_back_button() -> Button:
	return _back_button
