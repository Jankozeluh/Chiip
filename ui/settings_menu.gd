class_name SettingsMenu
extends CanvasLayer
## The settings menu (D-059; the mockup's "05 Settings" since M10, D-137): a full
## ink screen with the tabs Game, Video, Audio, Crosshair (with a live preview on
## a dark and a light square) and Controls (click a key, then press the new one).
## A Licences button in the footer opens the [LicensesMenu] (M12, D-170).
##
## One reusable scene, [code]ui/settings_menu.tscn[/code]: it hides itself until
## [method open] is called and tells the owner with [signal closed] when the
## player leaves it (Back or Esc). The main menu (which holds an instance of its
## own) and the console command [code]settings[/code] in a game open this scene,
## and so does the pause menu, over which it opens and to which Esc or Back
## returns. While it is open it registers with [MenuState], so the player's
## controls ignore the keyboard and mouse and the mouse is shown. It has
## [code]process_mode = Always[/code] (D-065), so it works while the game is
## paused behind the pause menu.
##
## It has no Apply button. Every control writes to [Settings] the moment it
## changes (the class clamps, applies and saves), and the menu follows
## [signal Settings.changed], so a console command that changes the sensitivity
## while the menu is open moves the slider. The controls are built in code from
## one small table of rows per tab; the scene holds the page, the tabs, the
## crosshair preview and the footer. A number is a slider with a value box (or,
## on the crosshair tab, the number as plain text), a yes / no setting or a few
## choices are segments (a frame around the choices, the chosen one filled), the
## crosshair colour is a row of swatches. Its look comes from the UI theme (D-057):
## no colours, sizes or styleboxes of its own (a row's height and a label's width
## are layout and scale with the menu), and [method set_ui_scale] gives it the
## theme scaled for the window like the other menus.
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
## The crosshair colours offered as swatches (the mockup's): name and colour (the opacity is kept).
const CROSSHAIR_COLORS: Array = [
	["Green", Color("36d07a")], ["White", Color("ffffff")], ["Yellow", Color("ffe14a")],
	["Pink", Color("ff5ad1")], ["Cyan", Color("48f0e0")],
]
## What the Controls tab shows for a slot without a key.
const EMPTY_SLOT_TEXT := "-"
## What the Pad column shows for the movement actions: they are the left stick and can't be changed.
const STICK_TEXT := "L-Stick"
## The slot number the Pad column uses in [method start_listening]: after the keys' slots.
const PAD_SLOT := Settings.BINDING_SLOTS
## The Pad column's width: narrower than a key column, its names are short.
const PAD_COLUMN_WIDTH := 120.0
## What a slot shows while it waits for the next key.
const LISTENING_TEXT := "Press a key..."
## The Pad column's, shorter to fit its narrow box.
const PAD_LISTENING_TEXT := "Press..."
## What the line under the key list says when there is nothing else to tell.
const CONTROLS_HINT := "Click a key or Pad box, then press the new key or button. Esc cancels, Backspace clears."
## The sizes of the layout, in pixels for a 720-pixel-tall window (the mockup's; the menu scales them).
## A settings row is 48 high with a 400 px label, then the control; the crosshair tab's label is 240 px.
const ROW_HEIGHT := 48.0
const LABEL_WIDTH := 400.0
const CROSSHAIR_LABEL_WIDTH := 240.0
## A slider with its number: 480 px wide, the value box 80 px (the pixel resolution's 112), and the crosshair tab's
## plain number 48 px. The crosshair tab's groups take what the 640 px column leaves after the label (400 px
## in the mockup's 1280 px window), so the column can be narrower in a narrow window.
const SLIDER_GROUP_WIDTH := 480.0
const VALUE_BOX_WIDTH := 80.0
const WIDE_VALUE_BOX_WIDTH := 112.0
const NUMBER_WIDTH := 48.0
## A swatch's colour is 28 px; its cell adds the room for the frame (SwatchMargin in the theme: a 2 px gap and the 2 px outline).
const SWATCH_SIZE := 28.0
const SWATCH_FRAME := 4.0
## The hex field after the swatches.
const HEX_BOX_WIDTH := 112.0
## The Controls tab: a table row is 34 high (a 2 px line and 32), the two key columns 240 px each.
const TABLE_ROW_HEIGHT := 34.0
const KEY_COLUMN_WIDTH := 220.0
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
## Row id → its row, the slider of a number row, the value box beside it (a [LineEdit]) and
## whatever shows its number (a value box, or a plain [Label] on the crosshair tab).
var _rows: Dictionary = {}
var _sliders: Dictionary = {}
var _fields: Dictionary = {}
var _value_nodes: Dictionary = {}
## Setting key → the OFF / ON segments of a yes / no setting, and the segments of a setting with a few
## values (frame limit), with the extra segment that shows a value the list doesn't have.
var _toggles: Dictionary = {}
var _choices: Dictionary = {}
var _custom_segments: Dictionary = {}
var _swatches: Array[Button] = []
var _hex_field: LineEdit
## Action → its binding slot buttons, and its name in the table.
var _binding_buttons: Dictionary = {}
var _action_labels: Dictionary = {}
## The action and slot waiting for a key (the action is empty when none is).
var _listening_action: StringName = &""
var _listening_slot: int = 0
## The frame in which listening began: a mouse press in that frame is the click that started it.
var _listen_frame: int = -1
## What the line under the key list tells (empty: it shows the hint).
var _notice_text: String = ""
var _preview_time: float = 0.0
## The two live crosshairs: on the dark square, then on the light one.
var _previews: Array[Crosshair] = []

@onready var _tabs: TabContainer = %Tabs
@onready var _game_rows: VBoxContainer = %Game
@onready var _video_rows: VBoxContainer = %Video
@onready var _audio_rows: VBoxContainer = %Audio
@onready var _crosshair_rows: VBoxContainer = %CrosshairRows
@onready var _controls_rows: VBoxContainer = %ControlsRows
@onready var _dark_preview: Crosshair = %DarkCrosshair
@onready var _light_preview: Crosshair = %LightCrosshair
@onready var _notice: Label = %Notice
@onready var _reset_button: Button = %ResetButton
@onready var _back_button: Button = %BackButton
@onready var _licenses_button: Button = %LicensesButton
@onready var _licenses: LicensesMenu = $LicensesMenu


func _ready() -> void:
	visible = false
	_settings = Settings.get_instance()
	_previews.assign([_dark_preview, _light_preview])
	_build_game_tab()
	_build_video_tab()
	_build_audio_tab()
	_build_crosshair_tab()
	_build_controls_tab()
	_settings.changed.connect(_on_setting_changed)
	_reset_button.pressed.connect(_on_reset_pressed)
	_back_button.pressed.connect(close)
	_licenses_button.pressed.connect(_licenses.open)
	_licenses.closed.connect(_licenses_button.grab_focus)
	_set_notice("")
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
	if visible and _previews[0].dynamic:
		_preview_time += delta
		var spread := PREVIEW_SPREAD_DEGREES * (0.5 - 0.5 * cos(_preview_time * TAU / PREVIEW_PULSE_SECONDS))
		for preview in _previews:
			preview.fallback_fov = Settings.vertical_fov(_settings.fov)
			preview.spread_degrees = spread
			preview.queue_redraw()


## Shows the menu over the game with the current settings, and the mouse. The
## menu stays open until the player closes it ([signal closed]).
func open() -> void:
	visible = true
	MenuState.open(self)
	_set_notice("")
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
## previews are not themed and take the factor themselves.
func set_ui_scale(factor: float) -> void:
	UiTheme.apply(self, factor)
	for preview in _previews:
		preview.set_ui_scale(factor)


## The text a menu shows for an action: "Move forward", "Crouch"...
static func action_name(action: StringName) -> String:
	return ACTION_NAMES.get(action, String(action).capitalize())


## The number in what a player typed into a number field ("1.5", "1,5", "75%",
## "480 L"), or NAN if there is none. Commas count as decimal points (Czech keyboards).
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
	_set_notice("")
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
			if slot == PAD_SLOT:
				_settings.clear_pad_binding(action)
				_set_notice("%s: the pad button is cleared." % action_name(action))
			else:
				_settings.clear_binding(action, slot)
				_set_notice("%s: slot %d cleared." % [action_name(action), slot + 1])
			return true
		if _listening_slot == PAD_SLOT:
			return true
		_bind(event)
		return true
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		if _listening_slot != PAD_SLOT:
			return false
		if event is InputEventJoypadButton and not (event as InputEventJoypadButton).pressed:
			return false
		if event is InputEventJoypadMotion and absf((event as InputEventJoypadMotion).axis_value) < Settings.PAD_TRIGGER_THRESHOLD:
			return false
		_bind_pad(event)
		return true
	if event is InputEventMouseButton:
		if not (event as InputEventMouseButton).pressed:
			return false
		if Engine.get_process_frames() == _listen_frame:
			return true
		if _listening_slot == PAD_SLOT:
			return true
		_bind(event)
		return true
	return false


## Binds [param event] to the waiting slot and takes it from whatever had it.
func _bind(event: InputEvent) -> void:
	if not Settings.can_bind(event):
		_set_notice("That key can't be used.")
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
	_set_notice(text)


## Binds a gamepad [param event] to the waiting action and takes it from whatever had it. Sticks and Start
## can't be bound (a stick's push is not a press: only a trigger pulled in counts).
func _bind_pad(event: InputEvent) -> void:
	if not Settings.can_bind_pad(event):
		if event is InputEventJoypadMotion:
			return # A stick moving: wait for a button or a trigger instead of complaining.
		_set_notice("That button can't be used.")
		return
	var action := _listening_action
	stop_listening()
	var lost := _settings.bind_pad_exclusive(action, event)
	var text := "%s: %s." % [action_name(action), Settings.pad_text(_settings.get_pad_binding(action))]
	var others: Array[String] = []
	for other in lost:
		others.append(action_name(other))
	if not others.is_empty():
		text += " %s no longer has it." % " and ".join(others)
	_set_notice(text)


## Sets the line under the key list: what the last rebinding did, or the hint when there is nothing to say.
func _set_notice(text: String) -> void:
	_notice_text = text
	_notice.text = text if text != "" else CONTROLS_HINT
	_notice.theme_type_variation = &"DimLabel" if text != "" else &"MuteLabel"


# --- Building the tabs ---


func _build_game_tab() -> void:
	_tab_name = "Game"
	_add_slider_row(_game_rows, &"sensitivity", {
		"label": "Sensitivity", "step": 0.01, "format": "%.2f",
		"tip": "CS's scale: 0.022° per mouse count at 1.0, so your CS number feels the same at the same mouse DPI."})
	_add_toggle_row(_game_rows, &"invert_y", "Invert Y")
	_add_slider_row(_game_rows, &"fov", {
		"label": "Field of view", "step": 1.0, "format": "%d",
		"tip": "Degrees across a 4:3 screen, like CS: 90 here is CS's 90. A wider window shows more to the sides."})
	# M15 (D-212): the gamepad's look.
	_add_slider_row(_game_rows, &"pad_sensitivity", {
		"label": "Pad sensitivity", "step": 0.05, "format": "%.2f",
		"tip": "How fast the right stick turns the view at a full push. 1.00 is a quarter turn a second."})
	_add_slider_row(_game_rows, &"pad_deadzone", {
		"label": "Stick dead zone", "step": 0.01, "scale": 100.0, "format": "%d",
		"tip": "How far (in percent) a stick must be pushed before it does anything. Raise it if the view or you drift by themselves."})
	_add_slider_row(_game_rows, &"pad_curve", {
		"label": "Look curve", "step": 0.1, "format": "%.1f",
		"tip": "1.0 is straight: the turn follows the push. Higher turns slowly for small pushes (fine aim) and still turns fast at a full push."})
	_add_toggle_row(_game_rows, &"pad_invert_y", "Invert pad Y")


func _build_video_tab() -> void:
	_tab_name = "Video"
	_add_toggle_row(_video_rows, &"fullscreen", "Fullscreen")
	_add_toggle_row(_video_rows, &"vsync", "V-Sync", "Wait for the screen's refresh: no tearing, a little more delay.")
	# The frame limit's choices as segments, with "None" (0, no limit) last.
	var caps: Array[int] = []
	for cap in Settings.FPS_CAPS:
		if cap != 0:
			caps.append(cap)
	caps.append(0)
	_add_choice_row(_video_rows, &"fps_cap", "Frame-rate limit", caps,
			func(value: int) -> String: return "None" if value == 0 else str(value),
			"CS's fps_max. Also set from the console: fps_max.")
	_add_slider_row(_video_rows, &"pixel_height", {
		"label": "Pixel resolution", "format": "%d L", "values": Settings.PIXEL_HEIGHTS, "box_width": WIDE_VALUE_BOX_WIDTH,
		"tip": "The height of the 3D image in lines; it is scaled up with sharp pixels. Fewer lines = chunkier."})
	_add_toggle_row(_video_rows, &"palette_effect", "Palette effect", "Limit the world's colours, with light dithering.")
	_add_toggle_row(_video_rows, &"pixelate_hud", "Pixelated HUD", "Draw the HUD at the low resolution too.")
	_add_choice_row(_video_rows, &"ui_scale", "UI scale", Settings.UI_SCALES,
			func(value: int) -> String: return "Auto" if value == 0 else "%d %%" % value,
			"Auto: the biggest even step that fits the window. 100 % fills it exactly, 75 % and 50 % are smaller.")
	# M15 (D-210): the two teams in blue and orange, apart for every kind of colour blindness.
	var team_row := _add_row(_video_rows, &"team_colors", "Team colours",
			"Standard is blue against red. Colour-blind safe is a dark blue against a light orange: it stays apart for red-green and blue-yellow colour blindness, and in greyscale.")
	_choices[&"team_colors"] = _add_segments(team_row, &"team_colors", ["Standard", "Colour-blind safe"], Teams.SCHEME_NAMES)
	_track(&"team_colors")


func _build_audio_tab() -> void:
	_tab_name = "Audio"
	var tips := {
		&"master_volume": "Scales both of the others.",
		&"effects_volume": "Footsteps and shots.",
		&"interface_volume": "Menu sounds (there are none yet).",
	}
	for entry: Array in [[&"master_volume", "Master"], [&"effects_volume", "Effects"], [&"interface_volume", "Interface"]]:
		_add_slider_row(_audio_rows, entry[0], {"label": entry[1], "step": 0.01, "scale": 100.0, "format": "%d", "tip": tips[entry[0]]})


func _build_crosshair_tab() -> void:
	_tab_name = "Crosshair"
	_add_color_row(_crosshair_rows)
	# On this tab the number is plain text after the slider (the mockup has no value boxes here).
	var plain := {"box": false, "label_width": CROSSHAIR_LABEL_WIDTH, "expand": true}
	_add_slider_row(_crosshair_rows, &"crosshair_opacity", plain.merged({
		"key": &"crosshair_color", "label": "Opacity", "min": 0.0, "max": 1.0, "step": 0.01, "scale": 100.0, "format": "%d",
		"get": _get_opacity, "set": _set_opacity}))
	_add_slider_row(_crosshair_rows, &"crosshair_length", plain.merged({
		"label": "Size", "step": 1.0, "format": "%d", "tip": "The length of each line. Sizes are pixels at 720p and grow with the window."}))
	_add_slider_row(_crosshair_rows, &"crosshair_gap", plain.merged({"label": "Gap", "step": 1.0, "format": "%d"}))
	_add_slider_row(_crosshair_rows, &"crosshair_thickness", plain.merged({"label": "Thickness", "step": 1.0, "format": "%d"}))
	_add_toggle_row(_crosshair_rows, &"crosshair_outline", "Outline", "A dark border, so the lines show on light backgrounds.", CROSSHAIR_LABEL_WIDTH)
	_add_toggle_row(_crosshair_rows, &"crosshair_dot", "Centre dot", "", CROSSHAIR_LABEL_WIDTH)
	_add_toggle_row(_crosshair_rows, &"crosshair_dynamic", "Dynamic",
			"The gap opens with your inaccuracy: moving and shooting. The preview breathes to show it.", CROSSHAIR_LABEL_WIDTH)


func _build_controls_tab() -> void:
	_tab_name = "Controls"
	for action in Settings.BINDABLE_ACTIONS:
		# A table row: a 2 px line along its top, the action's name, then the two key columns.
		var panel := PanelContainer.new()
		panel.theme_type_variation = &"TableRowPanel"
		panel.custom_minimum_size = Vector2(0, TABLE_ROW_HEIGHT)
		_controls_rows.add_child(panel)
		var row := HBoxContainer.new()
		row.theme_type_variation = &"FlushRow"
		panel.add_child(row)
		var label := Label.new()
		label.theme_type_variation = &"DimLabel"
		label.text = action_name(action)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(label)
		_action_labels[action] = label
		var buttons: Array[Button] = []
		for slot in Settings.BINDING_SLOTS:
			var cell := HBoxContainer.new()
			cell.theme_type_variation = &"FlushRow"
			cell.custom_minimum_size = Vector2(KEY_COLUMN_WIDTH, 0)
			cell.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(cell)
			var button := Button.new()
			button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			# Lit (pressed look) while it waits for a key.
			button.toggle_mode = true
			button.pressed.connect(start_listening.bind(action, slot))
			cell.add_child(button)
			buttons.append(button)
		# The gamepad's column (D-211): a button or trigger; movement is the left stick and fixed.
		var pad_cell := HBoxContainer.new()
		pad_cell.theme_type_variation = &"FlushRow"
		pad_cell.custom_minimum_size = Vector2(PAD_COLUMN_WIDTH, 0)
		pad_cell.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(pad_cell)
		var pad_button := Button.new()
		pad_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		pad_button.toggle_mode = true
		if Settings.PAD_BINDABLE_ACTIONS.has(action):
			pad_button.pressed.connect(start_listening.bind(action, PAD_SLOT))
		else:
			pad_button.disabled = true
		pad_cell.add_child(pad_button)
		buttons.append(pad_button)
		_binding_buttons[action] = buttons


# --- Row builders ---


## A row with the label [param label_text] on the left, and a tooltip if [param tip] is given. Add the controls to the result.
## [param id] names it (for [method get_row]).
func _add_row(parent: Control, id: StringName, label_text: String, tip: String = "", label_width: float = LABEL_WIDTH) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.theme_type_variation = &"FlushRow"
	row.custom_minimum_size = Vector2(0, ROW_HEIGHT)
	parent.add_child(row)
	var label := Label.new()
	label.theme_type_variation = &"DimLabel"
	label.text = label_text
	label.custom_minimum_size = Vector2(label_width, 0)
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if tip != "":
		# A label ignores the mouse by default, so it would never show its tooltip.
		label.mouse_filter = Control.MOUSE_FILTER_PASS
		label.tooltip_text = tip
	row.add_child(label)
	_rows[id] = row
	return row


## A number setting as a slider with its number beside it. [param id] names the row (for
## [method get_slider] and [method get_field]); [param spec] holds the label and what differs
## from the plain case, which is a number setting named [param id]:
## "min" and "max" (default: the setting's range), "step", "scale" (the number shown is the
## value times this, 100 for percent), "format" (for the shown number), "key" (the setting
## that refreshes the row), "get" and "set" (for a value that is a part of a setting), "tip",
## "values" (a few allowed values: the slider steps through them and the number is the value),
## "box" (false: the number is plain text, not a box you can type in), "box_width",
## "label_width" and "group_width" (the sizes of the layout), "expand" (the group takes the room the row has left, instead of a width).
func _add_slider_row(parent: Control, id: StringName, spec: Dictionary) -> void:
	var key: StringName = spec.get("key", id)
	var unit: float = spec.get("scale", 1.0)
	var step: float = spec.get("step", 1.0)
	var format: String = spec.get("format", "%d")
	var values: Array = spec.get("values", [])
	var limits: Vector2
	if not values.is_empty():
		limits = Vector2(0.0, values.size() - 1)
		step = 1.0
	elif spec.has("min"):
		limits = Vector2(spec["min"], spec["max"])
	else:
		limits = Settings.get_range(key)
	var getter: Callable = func() -> float: return _settings.get_value(id)
	var setter: Callable = func(value: float) -> void: _settings.set_value(id, value)
	# The slider's position → the number the player reads, and the number typed → a position.
	var shown: Callable = func(position: float) -> float: return position * unit
	var parse: Callable = func(number: float) -> float: return clampf(snappedf(number / unit, step), limits.x, limits.y)
	if not values.is_empty():
		getter = func() -> float: return float(maxi(0, values.find(_settings.get_value(id))))
		setter = func(position: float) -> void: _settings.set_value(id, values[roundi(position)])
		shown = func(position: float) -> float: return float(values[roundi(position)])
		parse = func(number: float) -> float:
			var nearest := 0
			for index in values.size():
				if absf(float(values[index]) - number) < absf(float(values[nearest]) - number):
					nearest = index
			return float(nearest)
	elif spec.has("get"):
		getter = spec["get"]
		setter = spec["set"]
	var row := _add_row(parent, id, spec["label"], spec.get("tip", ""), spec.get("label_width", LABEL_WIDTH))
	var group := HBoxContainer.new()
	group.theme_type_variation = &"RowBox"
	if spec.get("expand", false):
		group.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	else:
		group.custom_minimum_size = Vector2(spec.get("group_width", SLIDER_GROUP_WIDTH), 0)
	group.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(group)
	var slider := HSlider.new()
	slider.min_value = limits.x
	slider.max_value = limits.y
	slider.step = step
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# The mouse wheel scrolls the page (when it has to), it doesn't turn a slider by accident.
	slider.scrollable = false
	group.add_child(slider)
	var field: LineEdit = null
	var number_label: Label = null
	if spec.get("box", true):
		field = LineEdit.new()
		field.alignment = HORIZONTAL_ALIGNMENT_CENTER
		field.custom_minimum_size = Vector2(spec.get("box_width", VALUE_BOX_WIDTH), 0)
		field.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		group.add_child(field)
		_fields[id] = field
		_value_nodes[id] = field
	else:
		number_label = Label.new()
		number_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		number_label.custom_minimum_size = Vector2(NUMBER_WIDTH, 0)
		group.add_child(number_label)
		_value_nodes[id] = number_label
	slider.value_changed.connect(func(value: float) -> void: setter.call(value))
	if field != null:
		# True once the player typed something that wasn't taken yet.
		var typed := [false]
		var commit := func(text: String) -> void:
			typed[0] = false
			var number := parse_number(text)
			if not is_nan(number):
				setter.call(parse.call(number))
			# Show what the setting really took (clamped, or the old value if the text was no number).
			field.text = _number_text(format, shown.call(getter.call()))
		field.text_changed.connect(func(_text: String) -> void: typed[0] = true)
		field.text_submitted.connect(func(text: String) -> void:
			commit.call(text)
			field.release_focus())
		field.focus_exited.connect(func() -> void:
			if typed[0]:
				commit.call(field.text))
	_add_refresher(key, func() -> void:
		var position: float = getter.call()
		slider.set_value_no_signal(position)
		var text := _number_text(format, shown.call(position))
		if field == null:
			number_label.text = text
		elif not field.has_focus():
			field.text = text)
	_sliders[id] = slider
	_track(key)


## [param number] in [param format] ("%.2f", "%d L"). A whole-number format
## rounds: 0.29 × 100 is 28.999999999999996, which should read 29, not 28.
static func _number_text(format: String, number: float) -> String:
	return format % (roundi(number) if format.contains("%d") else number)


## A yes / no setting, as a label and OFF / ON segments.
func _add_toggle_row(parent: Control, key: StringName, label_text: String, tip: String = "", label_width: float = LABEL_WIDTH) -> void:
	var row := _add_row(parent, key, label_text, tip, label_width)
	_toggles[key] = _add_segments(row, key, ["Off", "On"], [false, true])
	_track(key)


## A setting with a few allowed values, as segments. [param values] are the setting's
## values and [param text_of] turns one into its text. A value the file holds that isn't
## in the list (a hand-edited frame limit) gets a segment of its own, marked "(custom)",
## while it is the value.
func _add_choice_row(parent: Control, key: StringName, label_text: String, values: Array[int], text_of: Callable, tip: String = "") -> void:
	var row := _add_row(parent, key, label_text, tip)
	var texts: Array[String] = []
	for value in values:
		texts.append(text_of.call(value))
	_choices[key] = _add_segments(row, key, texts, values, func(value: int) -> String: return "%s (custom)" % text_of.call(value))
	_track(key)


## OFF / ON, or a few choices, as buttons side by side in one frame, the chosen one filled
## (a [ButtonGroup] of toggle buttons: [param texts] are their texts and [param values] what
## each stands for). Choosing one writes the value to the setting [param key]. If
## [param custom_text] (value → text) is given, a hidden extra segment shows up for a value that
## isn't in the list. Returns the buttons in order, without that extra one.
func _add_segments(row: HBoxContainer, key: StringName, texts: Array, values: Array, custom_text: Callable = Callable()) -> Array[Button]:
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
		var button := _segment_button(texts[index], group)
		var value: Variant = values[index]
		button.toggled.connect(func(on: bool) -> void:
			if on:
				_settings.set_value(key, value))
		strip.add_child(button)
		buttons.append(button)
	var custom: Button = null
	if custom_text.is_valid():
		custom = _segment_button("", group)
		custom.visible = false
		strip.add_child(custom)
		_custom_segments[key] = custom
	_add_refresher(key, func() -> void:
		var current: Variant = _settings.get_value(key)
		var matched := false
		for index in buttons.size():
			var on: bool = values[index] == current
			matched = matched or on
			buttons[index].set_pressed_no_signal(on)
		if custom != null:
			custom.visible = not matched
			custom.set_pressed_no_signal(not matched)
			if not matched:
				custom.text = custom_text.call(current))
	return buttons


## One segment: a toggle button in [param group].
func _segment_button(text: String, group: ButtonGroup) -> Button:
	var button := Button.new()
	button.text = text
	button.theme_type_variation = &"WideSegmentButton"
	button.toggle_mode = true
	button.button_group = group
	return button


## The crosshair colour: swatches of the usual colours and a field for any "#RRGGBB".
func _add_color_row(parent: Control) -> void:
	# The first colour sits where the other rows' controls start: the label gives up the frame's room.
	var row := _add_row(parent, &"crosshair_color", "Colour", "Pick a colour, or type any #RRGGBB. The opacity below is kept.",
			CROSSHAIR_LABEL_WIDTH - SWATCH_FRAME)
	var group := HBoxContainer.new()
	group.theme_type_variation = &"RowBox"
	group.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(group)
	var swatches := HBoxContainer.new()
	swatches.theme_type_variation = &"SwatchRow"
	group.add_child(swatches)
	for entry: Array in CROSSHAIR_COLORS:
		var swatch := Button.new()
		swatch.theme_type_variation = &"SwatchButton"
		swatch.toggle_mode = true
		swatch.tooltip_text = entry[0]
		swatch.custom_minimum_size = Vector2.ONE * (SWATCH_SIZE + 2.0 * SWATCH_FRAME)
		# The colour sits in the button as a margin around a ColorRect, so the
		# button keeps its themed frame (the chosen one's outline), hover and focus ring.
		var margin := MarginContainer.new()
		margin.theme_type_variation = &"SwatchMargin"
		margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var fill := ColorRect.new()
		fill.color = entry[1]
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		margin.add_child(fill)
		swatch.add_child(margin)
		swatch.pressed.connect(_set_crosshair_rgb.bind(entry[1]))
		swatches.add_child(swatch)
		_swatches.append(swatch)
	_hex_field = LineEdit.new()
	_hex_field.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hex_field.custom_minimum_size = Vector2(HEX_BOX_WIDTH, 0)
	_hex_field.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_hex_field.max_length = 9
	_hex_field.placeholder_text = "#RRGGBB"
	_hex_field.text_submitted.connect(func(text: String) -> void:
		_commit_hex(text)
		_hex_field.release_focus())
	_hex_field.focus_exited.connect(func() -> void: _commit_hex(_hex_field.text))
	group.add_child(_hex_field)
	_add_refresher(&"crosshair_color", func() -> void:
		var color := _settings.crosshair_color
		for index in _swatches.size():
			_swatches[index].set_pressed_no_signal(_same_color(color, CROSSHAIR_COLORS[index][1]))
		if not _hex_field.has_focus():
			_hex_field.text = "#" + color.to_html(false).to_upper())
	_track(&"crosshair_color")


## The crosshair's opacity: the alpha of its colour.
func _get_opacity() -> float:
	return _settings.crosshair_color.a


func _set_opacity(value: float) -> void:
	var color := _settings.crosshair_color
	color.a = value
	_settings.crosshair_color = color


## Sets the crosshair's colour to [param rgb], keeping its opacity.
func _set_crosshair_rgb(rgb: Color) -> void:
	var color := rgb
	color.a = _settings.crosshair_color.a
	_settings.crosshair_color = color
	# A toggle button flips when it is clicked; show which colour is really chosen.
	_run_refreshers(&"crosshair_color")


## Takes "#RRGGBB" typed into the colour field (anything else puts the old colour back).
func _commit_hex(text: String) -> void:
	var cleaned := text.strip_edges()
	if cleaned != "" and Color.html_is_valid(cleaned):
		_set_crosshair_rgb(Color.html(cleaned))
	_run_refreshers(&"crosshair_color")


## True if two colours have the same red, green and blue (to what a hex code can say).
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


## Shows each slot's key (or "-"), and "Press a key..." on the one that waits (lime,
## and its action's name brighter).
func _refresh_bindings() -> void:
	for action: StringName in _binding_buttons:
		var buttons: Array = _binding_buttons[action]
		for slot in buttons.size():
			var button: Button = buttons[slot]
			var waiting := action == _listening_action and slot == _listening_slot
			var text := Settings.binding_text(_settings.get_binding(action, slot)) if slot < Settings.BINDING_SLOTS \
					else Settings.pad_text(_settings.get_pad_binding(action))
			if slot == PAD_SLOT and not Settings.PAD_BINDABLE_ACTIONS.has(action):
				text = STICK_TEXT
			button.text = (PAD_LISTENING_TEXT if slot == PAD_SLOT else LISTENING_TEXT) if waiting else (text if text != "" else EMPTY_SLOT_TEXT)
			button.set_pressed_no_signal(waiting)
			# The first key is a key cap, the others plain text.
			button.theme_type_variation = &"ListeningKeyButton" if waiting else (&"KeyCapButton" if slot == 0 else &"KeySlotButton")
		(_action_labels[action] as Label).theme_type_variation = &"BrightLabel" if action == _listening_action else &"DimLabel"


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
		_set_notice("Keys are back to their defaults.")
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


## The row of a setting ([param id]: the setting's key, or "crosshair_opacity"): its label is the first child.
func get_row(id: StringName) -> HBoxContainer:
	return _rows.get(id)


## The slider of a number row ([param id]: the setting's key, or "crosshair_opacity").
## The pixel resolution's slider steps through [constant Settings.PIXEL_HEIGHTS] (0 to 4).
func get_slider(id: StringName) -> HSlider:
	return _sliders.get(id)


## The value box beside a slider (none on the crosshair tab, where the number is plain text).
func get_field(id: StringName) -> LineEdit:
	return _fields.get(id)


## The number a slider's row shows, from its value box or its plain text.
func get_value_text(id: StringName) -> String:
	var node: Control = _value_nodes.get(id)
	return "" if node == null else str(node.get("text"))


## The OFF and ON segments of a yes / no setting, in that order.
func get_toggle(key: StringName) -> Array[Button]:
	var buttons: Array[Button] = []
	buttons.assign(_toggles.get(key, []))
	return buttons


## The segments of a setting with a few values (the frame limit: 60, 120, 144, 240, None), in order.
func get_option(key: StringName) -> Array[Button]:
	var buttons: Array[Button] = []
	buttons.assign(_choices.get(key, []))
	return buttons


## The extra segment of a choice that shows a value the list doesn't have ("75 (custom)"); hidden otherwise.
func get_custom_segment(key: StringName) -> Button:
	return _custom_segments.get(key)


## The button of slot [param slot] of [param action] in the Controls tab.
func get_binding_button(action: StringName, slot: int) -> Button:
	var buttons: Array = _binding_buttons.get(action, [])
	return buttons[slot] if slot >= 0 and slot < buttons.size() else null


## The label with the name of [param action] in the Controls tab.
func get_action_label(action: StringName) -> Label:
	return _action_labels.get(action)


## The crosshair colour swatches, in the order of [constant CROSSHAIR_COLORS].
func get_swatches() -> Array[Button]:
	return _swatches


## The hex field beside the swatches.
func get_hex_field() -> LineEdit:
	return _hex_field


## The line under the key list that says what the last rebinding did (empty when it shows the hint).
func get_notice() -> String:
	return _notice_text


## The tab container.
func get_tabs() -> TabContainer:
	return _tabs


## The crosshair preview on the dark square: a real [Crosshair] control.
func get_preview() -> Crosshair:
	return _previews[0]


## Both previews: the dark square's crosshair, then the light square's.
func get_previews() -> Array[Crosshair]:
	return _previews


## The "Reset tab to defaults" button.
func get_reset_button() -> Button:
	return _reset_button


## The "Back" button.
func get_back_button() -> Button:
	return _back_button


## The Licences button at the right of the footer (opens the [LicensesMenu], M12 D-170).
func get_licenses_button() -> Button:
	return _licenses_button


## The Licences screen the footer's button opens.
func get_licenses_menu() -> LicensesMenu:
	return _licenses
