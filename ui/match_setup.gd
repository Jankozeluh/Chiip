class_name MatchSetup
extends CanvasLayer
## The Play screen (M5 task 11, D-064; the mockup's "03 Play" since M10, D-135):
## the main menu's Play opens it. Three mode cards, **Team Deathmatch** (first,
## the default), **Bomb** and **Practice**: a click on the picked card plays it
## ("click to play"), a click on another card picks that one. Under them
## **Custom** shows the picked mode's options as rows of segments: the map (the
## three quick maps or the rotation), the kill limit or the rounds to win, the
## teams (a chip per player on each side), Team Deathmatch's time limit, the bots'
## difficulty and friendly fire. The big **Play** button plays the picked mode;
## Back or Esc closes the screen.
##
## It only collects the choices and reports [signal started] and
## [signal closed]; the main menu starts the game ([GameLaunch]) for
## [method get_picked_mode]. Every choice is written to [Settings] (its
## [code][match][/code] section) the moment it changes, so the next start offers
## the same match; picking Team Deathmatch or Bomb stores the mode too. The
## screen follows [signal Settings.changed]. [member settings] is the shared
## instance unless a test hands in its own before the screen enters the tree.
##
## A card is a container holding a [Button] (the click, the focus, the frame) and
## its labels on top, which ignore the mouse. A segment row is a frame around
## toggle buttons in a [ButtonGroup] (the chosen one is filled); the team chips
## are toggle buttons too, the pressed one standing for the team's size. The
## screen registers with [MenuState] while it is open and Esc closes it when it
## is on top. Its look comes from the UI theme (D-057, D-134): no colours, sizes
## or styleboxes of its own; [method set_ui_scale] gives it the theme scaled for
## the window like the other menus.

## Emitted when the player plays the picked mode (the Play button, or a click on the picked card).
signal started
## Emitted when the screen closes (Back or Esc).
signal closed

## The modes on offer, in order: the [member Settings.match_mode] value ("practice"
## is not stored) → its card's name, description and the line under it when not picked.
const MODES := {
	"respawn": {"name": "Team\nDeathmatch", "title": "Team Deathmatch", "text": "Respawn in 3 s. Most kills wins."},
	"rounds": {"name": "Bomb", "title": "Bomb", "text": "One life a round. Plant or defuse."},
	"practice": {"name": "Practice", "title": "Practice", "text": "Bot arena. No rounds, no clock."},
}
## What the picked card's last line says.
const PLAY_HINT := "Click to play"
## The value of the map row that stands for the rotation of the quick maps.
const ROTATION := "rotation"
## The height of a mode card and of a custom row (at 720p; the screen scales them).
const CARD_HEIGHT := 192.0
const ROW_HEIGHT := 40.0
## The size of a team chip.
const CHIP_SIZE := 16.0
## Which rows each mode shows (setting keys; the map row is &"match_map").
const MODE_ROWS := {
	"respawn": [&"match_map", &"match_kill_limit", &"match_team_size", &"match_time_limit", &"match_difficulty", &"match_friendly_fire"],
	"rounds": [&"match_map", &"match_rounds_to_win", &"match_team_size", &"match_difficulty", &"match_friendly_fire"],
	"practice": [&"match_difficulty"],
}

## Where the choices are stored. The shared [Settings] when null (set before the screen is in the tree).
var settings: Settings

## The picked mode: "respawn", "rounds" or "practice".
var _picked: String = "respawn"
## Mode → its card's button, and its last line.
var _cards: Dictionary = {}
var _card_lines: Dictionary = {}
## Setting key → the buttons of its row, in the order of [member _segment_values].
var _segments: Dictionary = {}
## Setting key → the value each button of its row stands for.
var _segment_values: Dictionary = {}
## Setting key → its whole row.
var _rows_by_key: Dictionary = {}
## The "3 V 3" between the team chips.
var _teams_label: Label
## The line that sums up the choices (the Play button's tooltip, and for tests).
var _summary: String = ""

@onready var _cards_box: HBoxContainer = %Cards
@onready var _rows: GridContainer = %Rows
@onready var _mode_name: Label = %ModeName
@onready var _back_button: Button = %BackButton
@onready var _start_button: Button = %StartButton


func _ready() -> void:
	visible = false
	if settings == null:
		settings = Settings.get_instance()
	_picked = settings.match_mode
	_build_cards()
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


## Shows the screen with the stored choices, the stored mode picked and its card focused.
func open() -> void:
	_picked = settings.match_mode
	visible = true
	MenuState.open(self)
	_refresh()
	(_cards[_picked] as Button).grab_focus()


## Hides the screen, hands the mouse back (if it was the last menu open) and emits
## [signal closed]. Does nothing when it isn't open. Playing doesn't close it: the
## game scene replaces the menu.
func close() -> void:
	if not visible:
		return
	visible = false
	MenuState.close(self)
	closed.emit()


## True while the screen is shown.
func is_open() -> bool:
	return visible


## Scales the screen; 1.0 is the size it is designed for (a 720-pixel-tall
## window). Hands it the theme scaled for the window ([UiTheme]).
func set_ui_scale(factor: float) -> void:
	UiTheme.apply(self, factor)


## Picks [param mode] ("respawn", "rounds" or "practice"): its card is framed,
## Custom shows its rows, and a match mode is stored as the last one chosen.
func pick(mode: String) -> void:
	_picked = mode
	if mode != "practice":
		settings.match_mode = mode
	_refresh()


## The picked mode: "respawn" (Team Deathmatch), "rounds" (Bomb) or "practice".
func get_picked_mode() -> String:
	return _picked


## The [MatchSettings] for the stored choices (what Play plays): the team sizes,
## the bots' difficulty, the length, friendly fire and the mode; the timings stay at their defaults.
func build_match_settings() -> MatchSettings:
	return GameLaunch.match_settings_from(settings)


## The scene path of the chosen map (with the rotation: the map it starts on).
func get_map_path() -> String:
	if GameLaunch.ROTATION_MAPS.has(settings.match_map):
		return settings.match_map
	return Settings.DEFAULT_MATCH_MAP


## The maps Play plays one after the other: the rotation, starting at the chosen
## map when it is one of the quick maps; empty for a single map.
func get_rotation_maps() -> Array[String]:
	if not settings.match_rotation:
		return []
	return GameLaunch.rotation_maps(get_map_path())


## The maps the map row offers, as scene paths, in order (the rotation is the last choice).
func get_map_paths() -> Array[String]:
	return GameLaunch.rotation_maps()


## The line that sums up the choices ("Team Deathmatch: You and 2 bots against 3 bots...").
func get_summary() -> String:
	return _summary


# --- Building the cards and the rows ---


func _build_cards() -> void:
	for mode: String in MODES:
		var card := MarginContainer.new()
		card.name = mode.capitalize()
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.custom_minimum_size = Vector2(0, CARD_HEIGHT)
		_cards_box.add_child(card)
		var button := Button.new()
		button.name = "Button"
		button.theme_type_variation = &"ModeButton"
		button.pressed.connect(_on_card_pressed.bind(mode))
		card.add_child(button)
		var text := MarginContainer.new()
		text.name = "Text"
		text.theme_type_variation = &"ModeMargin"
		text.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(text)
		var lines := VBoxContainer.new()
		lines.theme_type_variation = &"ModeText"
		lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
		text.add_child(lines)
		var top := HBoxContainer.new()
		top.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lines.add_child(top)
		var title := Label.new()
		title.name = "Title"
		title.theme_type_variation = &"ModeTitleLabel"
		title.text = MODES[mode]["name"]
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top.add_child(title)
		if mode == "respawn":
			var tag := Label.new()
			tag.name = "Default"
			tag.theme_type_variation = &"TagLabel"
			tag.text = "Default"
			tag.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
			top.add_child(tag)
		var spacer := Control.new()
		spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
		spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lines.add_child(spacer)
		var description := Label.new()
		description.name = "Description"
		description.theme_type_variation = &"ModeDetailLabel"
		description.text = MODES[mode]["text"]
		lines.add_child(description)
		var last := Label.new()
		last.name = "Action"
		lines.add_child(last)
		_cards[mode] = button
		_card_lines[mode] = last


func _build_rows() -> void:
	var map_texts: Array = []
	var map_values: Array = []
	for path in GameLaunch.rotation_maps():
		map_texts.append(GameLaunch.map_title(path))
		map_values.append(path)
	map_texts.append("Rotation")
	map_values.append(ROTATION)
	_add_segmented_row(&"match_map", "Map", map_texts, map_values)
	_add_segmented_row(&"match_kill_limit", "Kill limit", Settings.KILL_LIMITS.map(func(limit: int) -> String: return str(limit)),
			Settings.KILL_LIMITS)
	_add_segmented_row(&"match_rounds_to_win", "Rounds to win", Settings.MATCH_LENGTHS.map(func(rounds: int) -> String: return str(rounds)),
			Settings.MATCH_LENGTHS)
	_add_teams_row()
	_add_segmented_row(&"match_time_limit", "Match length", Settings.TIME_LIMITS.map(func(minutes: int) -> String: return "%d min" % minutes),
			Settings.TIME_LIMITS)
	_add_segmented_row(&"match_difficulty", "Bots", ["Easy", "Normal", "Hard"], Settings.DIFFICULTIES)
	_add_segmented_row(&"match_friendly_fire", "Friendly fire", ["Off", "On"], [false, true])


## A row with [param label_text] on the left and room on the right; add the controls to the result.
func _add_row(key: StringName, label_text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = String(key)
	row.theme_type_variation = &"RowBox"
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.custom_minimum_size = Vector2(0, ROW_HEIGHT)
	_rows.add_child(row)
	var label := Label.new()
	label.text = label_text
	label.theme_type_variation = &"DimLabel"
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(label)
	_rows_by_key[key] = row
	return row


## A choice among a few values: toggle buttons side by side in one frame, the
## chosen one filled. [param texts] are the buttons' texts and [param values]
## what each stands for (the value the setting [param key] takes).
func _add_segmented_row(key: StringName, label_text: String, texts: Array, values: Array) -> void:
	var row := _add_row(key, label_text)
	var frame := PanelContainer.new()
	frame.theme_type_variation = &"SegmentFrame"
	frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(frame)
	var strip := HBoxContainer.new()
	strip.theme_type_variation = &"SegmentRow"
	frame.add_child(strip)
	var group := ButtonGroup.new()
	var buttons: Array[Button] = []
	for index in texts.size():
		var button := Button.new()
		button.text = texts[index]
		button.theme_type_variation = &"SegmentButton"
		button.toggle_mode = true
		button.button_group = group
		var value: Variant = values[index]
		button.toggled.connect(func(on: bool) -> void:
			if on:
				_choose(key, value))
		strip.add_child(button)
		buttons.append(button)
	_segments[key] = buttons
	_segment_values[key] = values


## The teams: a chip per player on each side (yours in your colour, the enemy's
## in theirs), filled up to the team's size, with "3 V 3" between them. A chip is
## a toggle button: clicking the third makes the team three strong.
func _add_teams_row() -> void:
	var row := _add_row(&"match_team_size", "Teams")
	var teams := HBoxContainer.new()
	teams.theme_type_variation = &"RowBox"
	teams.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(teams)
	for key: StringName in [&"match_team_size", &"match_enemy_team_size"]:
		var chips := HBoxContainer.new()
		chips.theme_type_variation = &"TeamChipRow"
		var group := ButtonGroup.new()
		var buttons: Array[Button] = []
		for size in range(1, 6):
			var chip := Button.new()
			chip.custom_minimum_size = Vector2(CHIP_SIZE, CHIP_SIZE)
			chip.toggle_mode = true
			chip.button_group = group
			chip.tooltip_text = "%d %s" % [size, "on your team (you included)" if key == &"match_team_size" else "enemy bots"]
			chip.toggled.connect(func(on: bool) -> void:
				if on:
					settings.set_value(key, size))
			chips.add_child(chip)
			buttons.append(chip)
		_segments[key] = buttons
		_segment_values[key] = [1, 2, 3, 4, 5]
		if key == &"match_team_size":
			teams.add_child(chips)
			_teams_label = Label.new()
			teams.add_child(_teams_label)
		else:
			teams.add_child(chips)


## Stores a choice of the row [param key]. The map row stands for two settings: a
## quick map plays it alone, the rotation plays all three.
func _choose(key: StringName, value: Variant) -> void:
	if key == &"match_map":
		if value == ROTATION:
			settings.match_rotation = true
		else:
			settings.match_rotation = false
			settings.match_map = value
		return
	settings.set_value(key, value)


# --- Keeping the controls and the settings in step ---


## Shows the stored choices: the picked card framed, its rows shown with each
## row's value pressed, the team chips filled, and the summary.
func _refresh() -> void:
	for mode: String in _cards:
		var picked := mode == _picked
		(_cards[mode] as Button).theme_type_variation = &"ModeButtonPicked" if picked else &"ModeButton"
		var line := _card_lines[mode] as Label
		line.text = PLAY_HINT if picked else _card_line(mode)
		line.theme_type_variation = &"HeaderLabel" if picked else &"MuteLabel"
	_mode_name.text = MODES[_picked]["title"]
	var shown: Array = MODE_ROWS[_picked]
	for key: StringName in _rows_by_key:
		(_rows_by_key[key] as Control).visible = shown.has(key)
	for key: StringName in _segments:
		var buttons: Array = _segments[key]
		var values: Array = _segment_values[key]
		var current: Variant = _row_value(key)
		for index in buttons.size():
			(buttons[index] as Button).set_pressed_no_signal(values[index] == current)
	_refresh_chips(&"match_team_size", &"FriendlyChipButton")
	_refresh_chips(&"match_enemy_team_size", &"EnemyChipButton")
	_teams_label.text = "%d v %d" % [settings.match_team_size, settings.match_enemy_team_size]
	_summary = _summary_text()
	_start_button.tooltip_text = _summary


## The value a row shows: the map row shows the rotation or the map.
func _row_value(key: StringName) -> Variant:
	if key == &"match_map":
		return ROTATION if settings.match_rotation else settings.match_map
	return settings.get_value(key)


## Fills a team's chips up to its size.
func _refresh_chips(key: StringName, filled: StringName) -> void:
	var size: int = settings.get_value(key)
	var chips: Array = _segments[key]
	for index in chips.size():
		(chips[index] as Button).theme_type_variation = filled if index < size else &"EmptyChipButton"


## The last line of a card that isn't picked: what it would play.
func _card_line(mode: String) -> String:
	match mode:
		"respawn":
			return "First to %d · %d min" % [settings.match_kill_limit, settings.match_time_limit]
		"rounds":
			return "First to %d rounds" % settings.match_rounds_to_win
	return "Any class, any time"


func _summary_text() -> String:
	if _picked == "practice":
		return "Practice: bots respawn on the %s. %s bots." % [GameLaunch.map_title(Settings.DEFAULT_MAP), settings.match_difficulty.capitalize()]
	var respawn := _picked == "respawn"
	var goal := "first to %d kills or %d minutes" % [settings.match_kill_limit, settings.match_time_limit] if respawn \
			else "first to %d rounds" % settings.match_rounds_to_win
	var text := "%s: You and %s against %s. %s bots, %s, friendly fire %s." % [
			MODES[_picked]["title"], _bots_text(settings.match_team_size - 1), _bots_text(settings.match_enemy_team_size),
			settings.match_difficulty.capitalize(), goal, "on" if settings.match_friendly_fire else "off"]
	var rotation := get_rotation_maps()
	if not rotation.is_empty():
		text += " Maps in rotation: %s." % ", ".join(rotation.map(func(path: String) -> String: return GameLaunch.map_title(path)))
	else:
		text += " Map: %s." % GameLaunch.map_title(get_map_path())
	return text


## "no bots", "1 bot", "3 bots".
static func _bots_text(count: int) -> String:
	if count <= 0:
		return "no bots"
	return "1 bot" if count == 1 else "%d bots" % count


func _on_card_pressed(mode: String) -> void:
	if mode == _picked:
		started.emit()
	else:
		pick(mode)


func _on_setting_changed(key: StringName) -> void:
	if String(key).begins_with("match_"):
		if key == &"match_mode" and _picked != "practice":
			_picked = settings.match_mode
		_refresh()


# --- Test hooks ---


## The buttons of the row for the setting [param key] (e.g. [code]&"match_kill_limit"[/code];
## the team sizes' chips under [code]&"match_team_size"[/code] and [code]&"match_enemy_team_size"[/code];
## the map row under [code]&"match_map"[/code]), in order.
func get_segment_buttons(key: StringName) -> Array:
	return _segments.get(key, [])


## True while the row of [param key] is shown (each mode shows its own rows).
func is_row_shown(key: StringName) -> bool:
	return _rows_by_key.has(key) and (_rows_by_key[key] as Control).visible


## The mode cards' buttons: Team Deathmatch, Bomb, Practice.
func get_mode_cards() -> Array[Button]:
	var cards: Array[Button] = []
	for mode: String in MODES:
		cards.append(_cards[mode])
	return cards


## The last line of a mode's card ("Click to play" on the picked one).
func get_card_line(mode: String) -> String:
	return (_card_lines[mode] as Label).text


## The "Play" button.
func get_start_button() -> Button:
	return _start_button


## The "Back" button.
func get_back_button() -> Button:
	return _back_button
