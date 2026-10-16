class_name SettingsMenu
extends CanvasLayer
## The settings menu (D-059): tabs for Game, Video, Audio, Crosshair (with a
## live preview) and Controls (click a key slot, then press the new key).
##
## One reusable scene, [code]ui/settings_menu.tscn[/code]: it hides itself until
## [method open] is called and tells the owner with [signal closed] when the
## player leaves it (Back or Esc). The main menu (task 11, which holds an
## instance of its own) and the console command [code]settings[/code] in a game
## open this scene, and so does the pause menu (task 12), over which it opens and
## to which Esc or Back returns. While it is open it registers with [MenuState],
## so the player's controls ignore the keyboard and mouse and the mouse is shown.
## It has [code]process_mode = Always[/code] (D-065), so it works while the game
## is paused behind the pause menu.
##
## It has no Apply button. Every control writes to [Settings] the moment it
## changes (the class clamps, applies and saves), and the menu follows
## [signal Settings.changed], so a console command that changes the sensitivity
## while the menu is open moves the slider. The controls are built in code from
## one small table of rows per tab; the scene holds the frame, the tabs and the
## crosshair preview. Its look comes from the UI theme (D-057): no colors, sizes
## or styleboxes of its own, and [method set_ui_scale] gives it the theme scaled
## for the window like the other menus.
##
## Rebinding a key: clicking a slot calls [method start_listening]; the next key
## or mouse button press is bound ([method listen]), Esc cancels, Backspace
## clears the slot. A key belongs to one action only: binding it takes it from
## whatever had it ([method Settings.bind_exclusive]) and a line under the list
## says what lost it. While waiting, [member MenuState.capturing_input] is true,
## so the console key and Esc don't react.

## Emitted when the menu closes (Back or Esc).
signal closed

## The names the Controls tab shows for the bindable actions (all of
## [constant Settings.BINDABLE_ACTIONS]).
const ACTION_NAMES := {
	&"move_forward": "Move forward", &"move_back": "Move back", &"move_left": "Move left",
	&"move_right": "Move right", &"jump": "Jump", &"crouch": "Crouch", &"walk": "Walk (silent)",
	&"shoot": "Shoot", &"aim": "Aim", &"reload": "Reload", &"use": "Use: plant, defuse, swap gun",
	&"scoreboard": "Scoreboard (hold)", &"class_menu": "Class menu",
	&"toggle_debug": "Debug overlay", &"toggle_console": "Console",
	&"slot_primary": "Primary weapon", &"slot_pistol": "Pistol", &"slot_knife": "Knife",
	&"slot_grenade": "Grenades (again: next)", &"last_weapon": "Last weapon", &"drop_weapon": "Drop weapon", &"buy_menu": "Buy menu",
}
## The crosshair colors offered as swatches: name and color (the opacity is kept).
const CROSSHAIR_COLORS: Array = [
	["Green", Color(0.2, 1.0, 0.2)], ["Yellow", Color(1.0, 1.0, 0.2)], ["Cyan", Color(0.2, 1.0, 1.0)],
	["Red", Color(1.0, 0.2, 0.2)], ["Magenta", Color(1.0, 0.3, 1.0)], ["White", Color(1.0, 1.0, 1.0)],
]
## What the Controls tab shows for a slot without a key.
const EMPTY_SLOT_TEXT := "—"
## What a slot shows while it waits for the next key.
const LISTENING_TEXT := "Press a key…"
## Widths (at 720p; the menu scales them) of a row's label, slider, number field and binding slot.
const LABEL_WIDTH := 200.0
const SLIDER_WIDTH := 160.0
const FIELD_WIDTH := 96.0
const SLOT_WIDTH := 220.0
## The width of an option button (frame rate limit, pixel resolution).
const CHOICE_WIDTH := 280.0
## The preview's dynamic crosshair opens up to this many degrees, once every few seconds.
const PREVIEW_SPREAD_DEGREES := 3.0
const PREVIEW_PULSE_SECONDS := 2.4

var _settings: Settings
## Setting key → Callables that bring the controls of that setting up to date.
var _refreshers: Dictionary = {}
## Tab name → keys of the settings on that tab (what "Reset tab" puts back).
var _tab_keys: Dictionary = {}
## The name of the tab being built.
var _tab_name: String = ""
var _sliders: Dictionary = {}
var _fields: Dictionary = {}
var _checks: Dictionary = {}
var _options: Dictionary = {}
var _swatches: Array[Button] = []
var _hex_field: LineEdit
## Action → its binding slot buttons.
var _binding_buttons: Dictionary = {}
## The action and slot waiting for a key (the action is empty when none is).
var _listening_action: StringName = &""
var _listening_slot: int = 0
## The frame in which listening began: a mouse press in that frame is the click that started it.
var _listen_frame: int = -1
var _preview_time: float = 0.0

@onready var _tabs: TabContainer = %Tabs
@onready var _game_rows: VBoxContainer = %GameRows
@onready var _video_rows: VBoxContainer = %VideoRows
@onready var _audio_rows: VBoxContainer = %AudioRows
@onready var _crosshair_rows: VBoxContainer = %CrosshairRows
@onready var _controls_rows: VBoxContainer = %ControlsRows
@onready var _preview: Crosshair = %PreviewCrosshair
@onready var _notice: Label = %Notice
@onready var _reset_button: Button = %ResetButton
@onready var _back_button: Button = %BackButton


func _ready() -> void:
	visible = false
	_settings = Settings.get_instance()
	_build_game_tab()
	_build_video_tab()
	_build_audio_tab()
	_build_crosshair_tab()
	_build_controls_tab()
	_settings.changed.connect(_on_setting_changed)
	_reset_button.pressed.connect(_on_reset_pressed)
	_back_button.pressed.connect(close)
	_refresh_all()


func _exit_tree() -> void:
	# Freed or removed while open: don't leave the game waiting for a menu.
	if _listening_action != &"":
		_listening_action = &""
		MenuState.capturing_input = false
	MenuState.close(self)


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if _listening_action != &"":
		if listen(event):
			get_viewport().set_input_as_handled()
	elif event.is_action_pressed("pause") and MenuState.is_top(self):
		close()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	# The dynamic crosshair of the preview breathes, so the setting can be judged.
	if visible and _preview.dynamic:
		_preview_time += delta
		_preview.fallback_fov = Settings.vertical_fov(_settings.fov)
		_preview.spread_degrees = PREVIEW_SPREAD_DEGREES * (0.5 - 0.5 * cos(_preview_time * TAU / PREVIEW_PULSE_SECONDS))
		_preview.queue_redraw()


## Shows the menu over the game with the current settings, and the mouse. The
## menu stays open until the player closes it ([signal closed]).
func open() -> void:
	visible = true
	MenuState.open(self)
	_notice.text = ""
	_refresh_all()
	_tabs.get_tab_bar().grab_focus()


## Hides the menu, hands the mouse back (if it was the last menu open) and emits
## [signal closed]. Does nothing when it isn't open.
func close() -> void:
	if not visible:
		return
	stop_listening()
	var focused := get_viewport().gui_get_focus_owner()
	if focused != null and is_ancestor_of(focused):
		# Leaving a number field takes what was typed in it.
		focused.release_focus()
	visible = false
	MenuState.close(self)
	closed.emit()


## True while the menu is shown.
func is_open() -> bool:
	return visible


## Scales the menu; 1.0 is the size it is designed for (a 720-pixel-tall
## window). Hands it the theme scaled for the window ([UiTheme]); the crosshair
## preview is not themed and takes the factor itself.
func set_ui_scale(factor: float) -> void:
	UiTheme.apply(self, factor)
	_preview.set_ui_scale(factor)


## The text a menu shows for an action: "Move forward", "Crouch"...
static func action_name(action: StringName) -> String:
	return ACTION_NAMES.get(action, String(action).capitalize())


## The number in what a player typed into a number field ("1.5", "1,5", "75%",
## "7 px"), or NAN if there is none. Commas count as decimal points (Czech keyboards).
static func parse_number(text: String) -> float:
	var cleaned := ""
	for character in text.strip_edges().replace(",", "."):
		if character in "0123456789.-":
			cleaned += character
	return cleaned.to_float() if cleaned.is_valid_float() else NAN


# --- Rebinding ---


## Makes slot [param slot] of [param action] wait for the next key or mouse
## button (what clicking it does). Another slot that was waiting stops.
func start_listening(action: StringName, slot: int) -> void:
	_listening_action = action
	_listening_slot = slot
	_listen_frame = Engine.get_process_frames()
	MenuState.capturing_input = true
	_notice.text = ""
	_refresh_bindings()


## Stops waiting for a key without changing anything.
func stop_listening() -> void:
	if _listening_action == &"":
		return
	_listening_action = &""
	MenuState.capturing_input = false
	_refresh_bindings()


## True while a slot waits for a key.
func is_listening() -> bool:
	return _listening_action != &""


## Gives the menu an input event while a slot is waiting. A key press (not a
## repeat) is bound, except Esc, which cancels, and Backspace, which clears the
## slot; a mouse button press is bound, except the press in the frame that
## started the waiting (the click on the slot itself). Everything else, key
## releases and mouse movement included, is left alone. Returns true when the
## event was used, so it shouldn't go anywhere else.
func listen(event: InputEvent) -> bool:
	if _listening_action == &"":
		return false
	if event is InputEventKey:
		var key := event as InputEventKey
		if not key.pressed or key.echo:
			return false
		if event.is_action_pressed("pause"):
			stop_listening()
			return true
		if key.keycode == KEY_BACKSPACE or key.physical_keycode == KEY_BACKSPACE:
			var action := _listening_action
			var slot := _listening_slot
			stop_listening()
			_settings.clear_binding(action, slot)
			_notice.text = "%s: slot %d cleared." % [action_name(action), slot + 1]
			return true
		_bind(event)
		return true
	if event is InputEventMouseButton:
		if not (event as InputEventMouseButton).pressed:
			return false
		if Engine.get_process_frames() == _listen_frame:
			return true
		_bind(event)
		return true
	return false


## Binds [param event] to the waiting slot and takes it from whatever had it.
func _bind(event: InputEvent) -> void:
	if not Settings.can_bind(event):
		_notice.text = "That key can't be used."
		return
	var action := _listening_action
	var slot := _listening_slot
	stop_listening()
	var lost := _settings.bind_exclusive(action, event, slot)
	var text := "%s: %s." % [action_name(action), Settings.binding_text(_settings.get_binding(action, slot))]
	var others: Array[String] = []
	for entry: Array in lost:
		var name_lost := action_name(entry[0])
		if entry[0] != action and not others.has(name_lost):
			others.append(name_lost)
	if not others.is_empty():
		text += " %s no longer has it." % " and ".join(others)
	_notice.text = text


# --- Building the tabs ---


func _build_game_tab() -> void:
	_tab_name = "Game"
	_add_slider_row(_game_rows, &"sensitivity", {
		"label": "Mouse sensitivity", "step": 0.01, "format": "%.2f",
		"tip": "CS's scale: your CS number feels the same at the same mouse DPI."})
	_add_check_row(_game_rows, &"invert_y", "Invert mouse Y")
	_add_slider_row(_game_rows, &"fov", {
		"label": "Field of view", "step": 1.0, "format": "%d",
		"tip": "Degrees across a 4:3 screen, like CS: 90 here is CS's 90. A wider window shows more to the sides."})
	_add_note(_game_rows, "Sensitivity is on CS's scale (0.022° per mouse count at 1.0). Field of view is measured across a 4:3 screen, like CS.")


func _build_video_tab() -> void:
	_tab_name = "Video"
	_add_check_row(_video_rows, &"fullscreen", "Fullscreen")
	_add_check_row(_video_rows, &"vsync", "V-Sync", "Wait for the screen's refresh: no tearing, a little more delay.")
	_add_choice_row(_video_rows, &"fps_cap", "Frame rate limit", Settings.FPS_CAPS,
			func(value: int) -> String: return "Unlimited" if value == 0 else "%d fps" % value,
			"CS's fps_max. Also set from the console: fps_max.")
	_add_choice_row(_video_rows, &"pixel_height", "Pixel resolution", Settings.PIXEL_HEIGHTS,
			func(value: int) -> String: return "%d lines" % value,
			"The height of the 3D image in pixels; it is scaled up with sharp pixels. Fewer lines = chunkier.")
	_add_check_row(_video_rows, &"palette_effect", "Palette effect", "Limit the world's colors, with light dithering.")
	_add_check_row(_video_rows, &"pixelate_hud", "Pixelated HUD", "Draw the HUD at the low resolution too.")
	_add_note(_video_rows, "Pixel resolution is the height of the 3D image; the HUD stays sharp unless Pixelated HUD is on.")


func _build_audio_tab() -> void:
	_tab_name = "Audio"
	for entry: Array in [[&"master_volume", "Master volume"], [&"effects_volume", "Effects volume"], [&"interface_volume", "Interface volume"]]:
		_add_slider_row(_audio_rows, entry[0], {"label": entry[1], "step": 0.01, "scale": 100.0, "format": "%d%%"})
	_add_note(_audio_rows, "Effects are footsteps and shots, Interface is for menu sounds (there are none yet). Master scales both.")


func _build_crosshair_tab() -> void:
	_tab_name = "Crosshair"
	_add_color_row(_crosshair_rows)
	_add_slider_row(_crosshair_rows, &"crosshair_opacity", {
		"key": &"crosshair_color", "label": "Opacity", "min": 0.0, "max": 1.0, "step": 0.01, "scale": 100.0, "format": "%d%%",
		"get": _get_opacity, "set": _set_opacity})
	_add_slider_row(_crosshair_rows, &"crosshair_length", {"label": "Size (line length)", "step": 1.0, "format": "%d"})
	_add_slider_row(_crosshair_rows, &"crosshair_gap", {"label": "Gap", "step": 1.0, "format": "%d"})
	_add_slider_row(_crosshair_rows, &"crosshair_thickness", {"label": "Thickness", "step": 1.0, "format": "%d"})
	_add_check_row(_crosshair_rows, &"crosshair_outline", "Outline", "A dark border, so the lines show on light backgrounds.")
	_add_check_row(_crosshair_rows, &"crosshair_dot", "Center dot")
	_add_check_row(_crosshair_rows, &"crosshair_dynamic", "Dynamic", "The gap opens with your inaccuracy: moving and shooting. The preview breathes to show it.")
	_add_note(_crosshair_rows, "Sizes are pixels at 720p and grow with the window.")


func _build_controls_tab() -> void:
	_tab_name = "Controls"
	var header := HBoxContainer.new()
	header.theme_type_variation = &"FormRow"
	_controls_rows.add_child(header)
	var action_header := Label.new()
	action_header.theme_type_variation = &"HeaderLabel"
	action_header.text = "Action"
	action_header.custom_minimum_size = Vector2(LABEL_WIDTH, 0)
	header.add_child(action_header)
	for title in ["Primary", "Secondary"]:
		var slot_header := Label.new()
		slot_header.theme_type_variation = &"HeaderLabel"
		slot_header.text = title
		slot_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		slot_header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slot_header.custom_minimum_size = Vector2(SLOT_WIDTH, 0)
		header.add_child(slot_header)
	for action in Settings.BINDABLE_ACTIONS:
		var row := _add_row(_controls_rows, action_name(action))
		var buttons: Array[Button] = []
		for slot in Settings.BINDING_SLOTS:
			var button := Button.new()
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			button.custom_minimum_size = Vector2(SLOT_WIDTH, 0)
			# Lit (pressed look) while it waits for a key.
			button.toggle_mode = true
			button.pressed.connect(start_listening.bind(action, slot))
			row.add_child(button)
			buttons.append(button)
		_binding_buttons[action] = buttons


# --- Row builders ---


## A row with the label [param label_text] on the left, and a tooltip if [param tip] is given. Add the controls to the result.
func _add_row(parent: Control, label_text: String, tip: String = "") -> HBoxContainer:
	var row := HBoxContainer.new()
	row.theme_type_variation = &"FormRow"
	parent.add_child(row)
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(LABEL_WIDTH, 0)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if tip != "":
		# A label ignores the mouse by default, so it would never show its tooltip.
		label.mouse_filter = Control.MOUSE_FILTER_PASS
		label.tooltip_text = tip
	row.add_child(label)
	return row


## A line of secondary text under the rows.
func _add_note(parent: Control, text: String) -> void:
	var note := Label.new()
	note.theme_type_variation = &"DimLabel"
	note.text = text
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(note)


## A slider with an exact number field beside it. [param id] names the row (for
## [method get_slider] and [method get_field]); [param spec] holds the label
## and what differs from the plain case, which is a number setting named [param id]:
## "min" and "max" (default: the setting's range), "step", "scale" (the field shows the
## value times this, 100 for percent), "format" (for the shown number), "key" (the setting
## that refreshes the row), "get" and "set" (for a value that is a part of a setting) and "tip".
func _add_slider_row(parent: Control, id: StringName, spec: Dictionary) -> void:
	var key: StringName = spec.get("key", id)
	var unit: float = spec.get("scale", 1.0)
	var step: float = spec.get("step", 1.0)
	var format: String = spec.get("format", "%d")
	var limits := Vector2(spec["min"], spec["max"]) if spec.has("min") else Settings.get_range(key)
	var getter: Callable = func() -> float: return _settings.get_value(id)
	var setter: Callable = func(value: float) -> void: _settings.set_value(id, value)
	if spec.has("get"):
		getter = spec["get"]
		setter = spec["set"]
	var row := _add_row(parent, spec["label"], spec.get("tip", ""))
	var slider := HSlider.new()
	slider.min_value = limits.x
	slider.max_value = limits.y
	slider.step = step
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.custom_minimum_size = Vector2(SLIDER_WIDTH, 0)
	# The mouse wheel scrolls the page (when it has to), it doesn't turn a slider by accident.
	slider.scrollable = false
	row.add_child(slider)
	var field := LineEdit.new()
	field.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	field.custom_minimum_size = Vector2(FIELD_WIDTH, 0)
	row.add_child(field)
	# True once the player typed something that wasn't taken yet.
	var typed := [false]
	var commit := func(text: String) -> void:
		typed[0] = false
		var number := parse_number(text)
		if not is_nan(number):
			setter.call(clampf(snappedf(number / unit, step), limits.x, limits.y))
		# Show what the setting really took (clamped, or the old value if the text was no number).
		field.text = _number_text(format, float(getter.call()) * unit)
	slider.value_changed.connect(func(value: float) -> void: setter.call(value))
	field.text_changed.connect(func(_text: String) -> void: typed[0] = true)
	field.text_submitted.connect(func(text: String) -> void:
		commit.call(text)
		field.release_focus())
	field.focus_exited.connect(func() -> void:
		if typed[0]:
			commit.call(field.text))
	_add_refresher(key, func() -> void:
		var value: float = getter.call()
		slider.set_value_no_signal(value)
		if not field.has_focus():
			field.text = _number_text(format, value * unit))
	_sliders[id] = slider
	_fields[id] = field
	_track(key)


## [param number] in [param format] ("%.2f", "%d%%"). A whole-number format
## rounds: 0.29 × 100 is 28.999999999999996, which should read 29%, not 28%.
static func _number_text(format: String, number: float) -> String:
	return format % (roundi(number) if format.contains("%d") else number)


## A yes/no setting, as a label and a check box.
func _add_check_row(parent: Control, key: StringName, label_text: String, tip: String = "") -> void:
	var row := _add_row(parent, label_text, tip)
	var box := CheckBox.new()
	box.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	row.add_child(box)
	box.toggled.connect(func(on: bool) -> void: _settings.set_value(key, on))
	_add_refresher(key, func() -> void: box.set_pressed_no_signal(_settings.get_value(key)))
	_checks[key] = box
	_track(key)


## A setting with a few allowed values, as an option button. [param values] are
## the setting's values and [param text_of] turns one into its text. A value
## the file holds that isn't in the list (a hand-edited frame limit) gets an
## entry of its own, marked "(custom)".
func _add_choice_row(parent: Control, key: StringName, label_text: String, values: Array[int], text_of: Callable, tip: String = "") -> void:
	var row := _add_row(parent, label_text, tip)
	var option := OptionButton.new()
	option.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	option.custom_minimum_size = Vector2(CHOICE_WIDTH, 0)
	row.add_child(option)
	option.item_selected.connect(func(index: int) -> void: _settings.set_value(key, option.get_item_id(index)))
	_add_refresher(key, func() -> void:
		var current: int = _settings.get_value(key)
		var wanted: Array[int] = values.duplicate()
		if not wanted.has(current):
			wanted.append(current)
			wanted.sort()
		var shown: Array[int] = []
		for index in option.item_count:
			shown.append(option.get_item_id(index))
		if shown != wanted:
			# Only rebuilt when the list differs: never from inside a choice the player is making.
			option.clear()
			for value in wanted:
				option.add_item(text_of.call(value) + ("" if values.has(value) else " (custom)"), value)
		option.select(option.get_item_index(current)))
	_options[key] = option
	_track(key)


## The crosshair color: swatches of the usual colors and a field for any "#RRGGBB".
func _add_color_row(parent: Control) -> void:
	var row := _add_row(parent, "Color", "Pick a color, or type any #RRGGBB. The opacity below is kept.")
	var swatches := HBoxContainer.new()
	swatches.add_theme_constant_override("separation", 6)
	row.add_child(swatches)
	for entry: Array in CROSSHAIR_COLORS:
		var swatch := Button.new()
		swatch.toggle_mode = true
		swatch.tooltip_text = entry[0]
		swatch.custom_minimum_size = Vector2(32, 32)
		# The color sits in the button as a margin around a ColorRect, so the
		# button keeps its themed frame, hover and focus ring.
		var margin := MarginContainer.new()
		margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
			margin.add_theme_constant_override(side, 6)
		var fill := ColorRect.new()
		fill.color = entry[1]
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		margin.add_child(fill)
		swatch.add_child(margin)
		swatch.pressed.connect(_set_crosshair_rgb.bind(entry[1]))
		swatches.add_child(swatch)
		_swatches.append(swatch)
	_hex_field = LineEdit.new()
	_hex_field.custom_minimum_size = Vector2(FIELD_WIDTH + 16, 0)
	_hex_field.max_length = 9
	_hex_field.placeholder_text = "#RRGGBB"
	_hex_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hex_field.text_submitted.connect(func(text: String) -> void:
		_commit_hex(text)
		_hex_field.release_focus())
	_hex_field.focus_exited.connect(func() -> void: _commit_hex(_hex_field.text))
	row.add_child(_hex_field)
	_add_refresher(&"crosshair_color", func() -> void:
		var color := _settings.crosshair_color
		for index in _swatches.size():
			_swatches[index].set_pressed_no_signal(_same_color(color, CROSSHAIR_COLORS[index][1]))
		if not _hex_field.has_focus():
			_hex_field.text = "#" + color.to_html(false).to_upper())
	_track(&"crosshair_color")


## The crosshair's opacity: the alpha of its color.
func _get_opacity() -> float:
	return _settings.crosshair_color.a


func _set_opacity(value: float) -> void:
	var color := _settings.crosshair_color
	color.a = value
	_settings.crosshair_color = color


## Sets the crosshair's color to [param rgb], keeping its opacity.
func _set_crosshair_rgb(rgb: Color) -> void:
	var color := rgb
	color.a = _settings.crosshair_color.a
	_settings.crosshair_color = color
	# A toggle button flips when it is clicked; show which color is really chosen.
	_run_refreshers(&"crosshair_color")


## Takes "#RRGGBB" typed into the color field (anything else puts the old color back).
func _commit_hex(text: String) -> void:
	var cleaned := text.strip_edges()
	if cleaned != "" and Color.html_is_valid(cleaned):
		_set_crosshair_rgb(Color.html(cleaned))
	_run_refreshers(&"crosshair_color")


## True if two colors have the same red, green and blue (to what a hex code can say).
static func _same_color(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < 0.004 and absf(a.g - b.g) < 0.004 and absf(a.b - b.b) < 0.004


# --- Keeping the controls and the settings in step ---


func _add_refresher(key: StringName, refresher: Callable) -> void:
	var list: Array = _refreshers.get_or_add(key, [])
	list.append(refresher)


## Remembers that [param key] is on the tab being built (for "Reset tab").
func _track(key: StringName) -> void:
	var list: Array = _tab_keys.get_or_add(_tab_name, [])
	if not list.has(key):
		list.append(key)


func _run_refreshers(key: StringName) -> void:
	for refresher: Callable in _refreshers.get(key, []):
		refresher.call()


## Reads every control's value from the settings (when the menu opens).
func _refresh_all() -> void:
	for key: StringName in _refreshers:
		_run_refreshers(key)
	_refresh_bindings()


func _on_setting_changed(key: StringName) -> void:
	if key == &"bindings":
		_refresh_bindings()
	else:
		_run_refreshers(key)


## Shows each slot's key (or "—"), and "Press a key…" on the one that waits.
func _refresh_bindings() -> void:
	for action: StringName in _binding_buttons:
		var buttons: Array = _binding_buttons[action]
		for slot in buttons.size():
			var button: Button = buttons[slot]
			var waiting := action == _listening_action and slot == _listening_slot
			var text := Settings.binding_text(_settings.get_binding(action, slot))
			button.text = LISTENING_TEXT if waiting else (text if text != "" else EMPTY_SLOT_TEXT)
			button.set_pressed_no_signal(waiting)


func _on_reset_pressed() -> void:
	var tab := _tabs.get_current_tab_control()
	if tab != null:
		reset_tab(String(tab.name))


## Puts the settings of one tab ("Game", "Video", "Audio", "Crosshair" or
## "Controls", whose keys all go back) to their defaults.
func reset_tab(tab_name: String) -> void:
	stop_listening()
	if tab_name == "Controls":
		_settings.reset_bindings()
		_notice.text = "Keys are back to their defaults."
		return
	for key: StringName in _tab_keys.get(tab_name, []):
		_settings.set_value(key, Settings.get_default(key))


# --- Test hooks ---


## The tab pages' names, in order.
func get_tab_names() -> Array[String]:
	var names: Array[String] = []
	for index in _tabs.get_tab_count():
		names.append(String(_tabs.get_tab_control(index).name))
	return names


## The slider of a number row ([param id]: the setting's key, or "crosshair_opacity").
func get_slider(id: StringName) -> HSlider:
	return _sliders.get(id)


## The number field beside a slider.
func get_field(id: StringName) -> LineEdit:
	return _fields.get(id)


## The check box of a yes/no setting.
func get_check(key: StringName) -> CheckBox:
	return _checks.get(key)


## The option button of a setting with a few values (frame rate limit, pixel resolution).
func get_option(key: StringName) -> OptionButton:
	return _options.get(key)


## The button of slot [param slot] of [param action] in the Controls tab.
func get_binding_button(action: StringName, slot: int) -> Button:
	var buttons: Array = _binding_buttons.get(action, [])
	return buttons[slot] if slot >= 0 and slot < buttons.size() else null


## The crosshair color swatches, in the order of [constant CROSSHAIR_COLORS].
func get_swatches() -> Array[Button]:
	return _swatches


## The hex field beside the swatches.
func get_hex_field() -> LineEdit:
	return _hex_field


## The line under the key list that says what the last rebinding did.
func get_notice() -> String:
	return _notice.text


## The tab container.
func get_tabs() -> TabContainer:
	return _tabs


## The crosshair preview: a real [Crosshair] control.
func get_preview() -> Crosshair:
	return _preview


## The "Reset tab to defaults" button.
func get_reset_button() -> Button:
	return _reset_button


## The "Back" button.
func get_back_button() -> Button:
	return _back_button
