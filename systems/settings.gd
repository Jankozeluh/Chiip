class_name Settings
extends RefCounted
## The player's settings: mouse and field of view, video, audio, crosshair and
## key bindings. They are saved to [code]user://settings.cfg[/code] and applied
## the moment they change (D-058).
##
## This is a plain class with one shared instance ([method get_instance], a
## static variable like [Noises]) rather than an autoload, because autoloads
## aren't loaded when Godot runs a [code]--script[/code] and tests would break.
##
## Nothing reads the disk until the game calls [method load_from_disk] (the main
## menu at startup, or main.gd when it is started directly). A new instance starts with the defaults,
## which equal the project's behaviour before there were settings, so tests run
## on defaults and never touch the player's real file. Saving starts with that
## call too: after it, every change is written to the file it loaded.
##
## Reading: typed properties ([member sensitivity]...) or [method get_value].
## Writing: assign the property or call [method set_value]. Values are clamped
## to their range, a change emits [signal changed] and applies the global
## settings (window, frame rate, audio buses, key bindings), so whatever shows
## a value just listens to [signal changed] and applies it. The player
## controller applies the mouse and field of view, the crosshair its style and
## main.gd the pixel settings.
##
## The key bindings of the gameplay actions work the same way ([method
## get_binding], [method set_binding], [method reset_bindings]); a change
## reports the key [code]&"bindings"[/code].
##
## Settings are local to this computer and never game rules (they are not part
## of a match, so M9's host won't send them).
##
## The [code][match][/code] section is not a preference but a memory: the last
## choices made in the main menu's match setup (team sizes, bot difficulty, match
## length, friendly fire, map, D-064), so the next start offers the same match.
## They are stored, clamped and saved like every other setting;
## [method GameLaunch.match_settings_from] turns them into the [MatchSettings]
## a match is played by.

## Emitted after a setting changed and was applied. [param key] is the
## setting's name, e.g. [code]&"sensitivity"[/code], or [code]&"bindings"[/code]
## when a key binding changed.
signal changed(key: StringName)

## Where the game keeps its settings: in Godot's user data folder (on macOS
## [code]~/Library/Application Support/Godot/app_userdata/Chiip/settings.cfg[/code]).
const SETTINGS_PATH := "user://settings.cfg"

## The audio buses of [code]default_bus_layout.tres[/code]. Master is the final
## mix, Effects (footsteps, shots) and Interface (menus) send to it.
const BUS_MASTER := &"Master"
const BUS_EFFECTS := &"Effects"
const BUS_INTERFACE := &"Interface"

## The world image heights the pixel resolution can take; other values snap to the nearest.
const PIXEL_HEIGHTS: Array[int] = [270, 360, 480, 540, 720]
## The frame rate limits the menu offers (0 = unlimited). Any value from 30 to 1000 works.
const FPS_CAPS: Array[int] = [0, 60, 120, 144, 240]
## The match lengths match setup offers: rounds a team must win (D-044).
const MATCH_LENGTHS: Array[int] = [5, 10, 15]
## The bot difficulties match setup offers: the names of bots/difficulty_*.tres, easiest first.
const DIFFICULTIES: Array[String] = ["easy", "normal", "hard"]
## The modes match setup offers (D-087): "rounds" (bomb rounds on maps with bomb
## sites) and "respawn" (team respawn, D-082).
const MATCH_MODES: Array[String] = ["rounds", "respawn"]
## The kill limits match setup offers for team respawn (D-083: 50 is about 4 minutes with bots).
const KILL_LIMITS: Array[int] = [30, 50, 75]
## The map match setup starts with, and the one the main menu flies over.
const DEFAULT_MAP := "res://maps/test_map.tscn"
## How many keys or buttons one action can have (primary and secondary).
const BINDING_SLOTS := 2
## CS's field of view is measured across a 4:3 screen: 90° there. [method vertical_fov] converts.
const REFERENCE_ASPECT := 4.0 / 3.0

## The actions whose keys can be changed. Esc ([code]pause[/code]) is fixed.
const BINDABLE_ACTIONS: Array[StringName] = [
	&"move_forward", &"move_back", &"move_left", &"move_right", &"jump", &"crouch", &"walk",
	&"shoot", &"aim", &"reload", &"use", &"scoreboard", &"class_menu", &"toggle_debug", &"toggle_console",
	&"slot_primary", &"slot_pistol", &"slot_knife", &"slot_grenade", &"last_weapon", &"drop_weapon", &"buy_menu",
]

## Every setting: its section in the file, its default and its limits. The
## defaults are today's behaviour (D-016, D-048, D-021). A value outside
## [code]min[/code]..[code]max[/code] is clamped; [code]choices[/code] snaps to
## the nearest listed value (a text setting's [code]choices[/code] must match one
## of them, else it falls back to the default); [code]off[/code] is the value
## that means "no limit" (anything at or below it). In the file the section's name is dropped from
## the key (the crosshair's [code]crosshair_gap[/code] is [code]gap[/code]).
const SCHEMA := {
	&"sensitivity": {"section": "game", "default": 1.0, "min": 0.05, "max": 10.0},
	&"invert_y": {"section": "game", "default": false},
	&"fov": {"section": "game", "default": 90.0, "min": 70.0, "max": 110.0},
	&"fullscreen": {"section": "video", "default": false},
	&"vsync": {"section": "video", "default": true},
	&"fps_cap": {"section": "video", "default": 0, "min": 30, "max": 1000, "off": 0},
	&"pixel_height": {"section": "video", "default": 480, "choices": PIXEL_HEIGHTS},
	&"palette_effect": {"section": "video", "default": true},
	&"pixelate_hud": {"section": "video", "default": false},
	&"master_volume": {"section": "audio", "default": 1.0, "min": 0.0, "max": 1.0},
	&"effects_volume": {"section": "audio", "default": 1.0, "min": 0.0, "max": 1.0},
	&"interface_volume": {"section": "audio", "default": 1.0, "min": 0.0, "max": 1.0},
	&"crosshair_color": {"section": "crosshair", "default": Color(0.2, 1.0, 0.2)},
	&"crosshair_length": {"section": "crosshair", "default": 7.0, "min": 1.0, "max": 30.0},
	&"crosshair_gap": {"section": "crosshair", "default": 4.0, "min": 0.0, "max": 20.0},
	&"crosshair_thickness": {"section": "crosshair", "default": 2.0, "min": 1.0, "max": 8.0},
	&"crosshair_outline": {"section": "crosshair", "default": true},
	&"crosshair_dot": {"section": "crosshair", "default": false},
	&"crosshair_dynamic": {"section": "crosshair", "default": false},
	# The last match setup (D-064). The defaults are D-041's: 3v3, Normal, first to 5, friendly fire off.
	&"match_team_size": {"section": "match", "default": 3, "min": 1, "max": 5},
	&"match_enemy_team_size": {"section": "match", "default": 3, "min": 1, "max": 5},
	&"match_difficulty": {"section": "match", "default": "normal", "choices": DIFFICULTIES},
	&"match_rounds_to_win": {"section": "match", "default": 5, "choices": MATCH_LENGTHS},
	&"match_friendly_fire": {"section": "match", "default": false},
	&"match_map": {"section": "match", "default": DEFAULT_MAP},
	# M8 (D-087): the mode, team respawn's kill limit, and playing the quick maps in rotation.
	&"match_mode": {"section": "match", "default": "rounds", "choices": MATCH_MODES},
	&"match_kill_limit": {"section": "match", "default": 50, "choices": KILL_LIMITS},
	&"match_rotation": {"section": "match", "default": false},
}

## The names of the mouse buttons a binding can use, by button index (for menus).
const MOUSE_BUTTON_NAMES := {
	MOUSE_BUTTON_LEFT: "Left Mouse", MOUSE_BUTTON_RIGHT: "Right Mouse", MOUSE_BUTTON_MIDDLE: "Middle Mouse",
	MOUSE_BUTTON_WHEEL_UP: "Wheel Up", MOUSE_BUTTON_WHEEL_DOWN: "Wheel Down",
	MOUSE_BUTTON_WHEEL_LEFT: "Wheel Left", MOUSE_BUTTON_WHEEL_RIGHT: "Wheel Right",
	MOUSE_BUTTON_XBUTTON1: "Mouse 4", MOUSE_BUTTON_XBUTTON2: "Mouse 5",
}

## Names for keys that [method OS.get_keycode_string] spells in a way a menu
## shouldn't show ("QuoteLeft" for the key left of 1, "Kp 1" for the keypad).
const KEY_NAMES := {
	KEY_QUOTELEFT: "`", KEY_MINUS: "-", KEY_EQUAL: "=", KEY_BRACKETLEFT: "[", KEY_BRACKETRIGHT: "]",
	KEY_BACKSLASH: "\\", KEY_SEMICOLON: ";", KEY_APOSTROPHE: "'", KEY_COMMA: ",", KEY_PERIOD: ".", KEY_SLASH: "/",
	KEY_PAGEUP: "Page Up", KEY_PAGEDOWN: "Page Down", KEY_CAPSLOCK: "Caps Lock",
	KEY_KP_0: "Num 0", KEY_KP_1: "Num 1", KEY_KP_2: "Num 2", KEY_KP_3: "Num 3", KEY_KP_4: "Num 4",
	KEY_KP_5: "Num 5", KEY_KP_6: "Num 6", KEY_KP_7: "Num 7", KEY_KP_8: "Num 8", KEY_KP_9: "Num 9",
	KEY_KP_ENTER: "Num Enter", KEY_KP_ADD: "Num +", KEY_KP_SUBTRACT: "Num -", KEY_KP_MULTIPLY: "Num *",
	KEY_KP_DIVIDE: "Num /", KEY_KP_PERIOD: "Num .",
}

## Where changes are saved ([code]""[/code]: nowhere). Set by [method load_from_disk].
var save_path: String = ""
## True for the shared instance: changes also reach the engine (window, frame
## rate limit, audio buses, key bindings). A separate [code]Settings.new()[/code]
## only holds values, which is what tests use to try saving and loading.
var applies_to_engine: bool = false

## The shared instance's project defaults of the bindable actions, read from the
## InputMap once, before anything changed it: action → [BINDING_SLOTS] entries,
## each an InputEvent or null.
static var _default_bindings: Dictionary = {}
static var _instance: Settings

## Setting name → current value.
var _values: Dictionary = {}
## Action → [BINDING_SLOTS] entries, each an InputEvent or null.
var _bindings: Dictionary = {}
## While above 0, changes are not saved one by one (set by reset and load).
var _batch_depth: int = 0
## True when something changed that isn't saved yet.
var _dirty: bool = false

## Mouse sensitivity on CS's scale: each mouse count turns sensitivity × 0.022° (D-016). 0.05 to 10.
var sensitivity: float:
	get: return _values[&"sensitivity"]
	set(value): set_value(&"sensitivity", value)
## Flip vertical mouse look.
var invert_y: bool:
	get: return _values[&"invert_y"]
	set(value): set_value(&"invert_y", value)
## Field of view the way CS says it: degrees across a 4:3 screen, 90 by default
## (70 to 110). [method vertical_fov] turns it into the camera's value.
var fov: float:
	get: return _values[&"fov"]
	set(value): set_value(&"fov", value)

## Fullscreen window instead of a window.
var fullscreen: bool:
	get: return _values[&"fullscreen"]
	set(value): set_value(&"fullscreen", value)
## Wait for the screen's refresh before showing a frame (no tearing).
var vsync: bool:
	get: return _values[&"vsync"]
	set(value): set_value(&"vsync", value)
## Frame rate limit, CS's fps_max: 0 is unlimited, otherwise 30 to 1000.
var fps_cap: int:
	get: return _values[&"fps_cap"]
	set(value): set_value(&"fps_cap", value)
## Height of the 3D world image in pixels (D-048): one of [constant PIXEL_HEIGHTS].
var pixel_height: int:
	get: return _values[&"pixel_height"]
	set(value): set_value(&"pixel_height", value)
## Limit the world's colors with the retro palette effect (D-030).
var palette_effect: bool:
	get: return _values[&"palette_effect"]
	set(value): set_value(&"palette_effect", value)
## Pixelate the HUD too, by rendering the whole window at the low resolution (D-027).
var pixelate_hud: bool:
	get: return _values[&"pixelate_hud"]
	set(value): set_value(&"pixelate_hud", value)

## Volume of everything, 0 to 1 (linear; the bus gets [method @GlobalScope.linear_to_db] of it).
var master_volume: float:
	get: return _values[&"master_volume"]
	set(value): set_value(&"master_volume", value)
## Volume of the Effects bus (footsteps and shots), 0 to 1.
var effects_volume: float:
	get: return _values[&"effects_volume"]
	set(value): set_value(&"effects_volume", value)
## Volume of the Interface bus (menus), 0 to 1. Nothing plays on it yet.
var interface_volume: float:
	get: return _values[&"interface_volume"]
	set(value): set_value(&"interface_volume", value)

## Crosshair line color (CS green by default); its alpha fades the whole crosshair.
var crosshair_color: Color:
	get: return _values[&"crosshair_color"]
	set(value): set_value(&"crosshair_color", value)
## Length of each crosshair line in pixels at 720p (CS calls it size), 1 to 30.
var crosshair_length: float:
	get: return _values[&"crosshair_length"]
	set(value): set_value(&"crosshair_length", value)
## Distance from the center to where the lines start, in pixels at 720p, 0 to 20.
var crosshair_gap: float:
	get: return _values[&"crosshair_gap"]
	set(value): set_value(&"crosshair_gap", value)
## Crosshair line thickness in pixels at 720p, 1 to 8.
var crosshair_thickness: float:
	get: return _values[&"crosshair_thickness"]
	set(value): set_value(&"crosshair_thickness", value)
## Draw a dark outline around the crosshair.
var crosshair_outline: bool:
	get: return _values[&"crosshair_outline"]
	set(value): set_value(&"crosshair_outline", value)
## Draw a dot in the center of the crosshair.
var crosshair_dot: bool:
	get: return _values[&"crosshair_dot"]
	set(value): set_value(&"crosshair_dot", value)
## Open the crosshair's gap to show the current inaccuracy (CS's dynamic crosshair).
var crosshair_dynamic: bool:
	get: return _values[&"crosshair_dynamic"]
	set(value): set_value(&"crosshair_dynamic", value)

## Players on your team in the next match, you included, 1 to 5 (match setup).
var match_team_size: int:
	get: return _values[&"match_team_size"]
	set(value): set_value(&"match_team_size", value)
## Bots on the enemy team in the next match, 1 to 5.
var match_enemy_team_size: int:
	get: return _values[&"match_enemy_team_size"]
	set(value): set_value(&"match_enemy_team_size", value)
## How well the bots fight: one of [constant DIFFICULTIES] ("easy", "normal" or "hard").
var match_difficulty: String:
	get: return _values[&"match_difficulty"]
	set(value): set_value(&"match_difficulty", value)
## Rounds a team must win: one of [constant MATCH_LENGTHS].
var match_rounds_to_win: int:
	get: return _values[&"match_rounds_to_win"]
	set(value): set_value(&"match_rounds_to_win", value)
## Teammates hurt each other in the next match.
var match_friendly_fire: bool:
	get: return _values[&"match_friendly_fire"]
	set(value): set_value(&"match_friendly_fire", value)
## The map scene of the next match, e.g. [constant DEFAULT_MAP]. Nothing checks
## that it still exists: match setup falls back to the default map when it doesn't.
var match_map: String:
	get: return _values[&"match_map"]
	set(value): set_value(&"match_map", value)
## How the match is played: one of [constant MATCH_MODES] ("rounds" or "respawn").
var match_mode: String:
	get: return _values[&"match_mode"]
	set(value): set_value(&"match_mode", value)
## Kills a team needs to win a team respawn match: one of [constant KILL_LIMITS].
var match_kill_limit: int:
	get: return _values[&"match_kill_limit"]
	set(value): set_value(&"match_kill_limit", value)
## Play the quick maps one after the other ([method GameLaunch.rotation_maps])
## instead of [member match_map] only.
var match_rotation: bool:
	get: return _values[&"match_rotation"]
	set(value): set_value(&"match_rotation", value)


func _init() -> void:
	for key: StringName in SCHEMA:
		_values[key] = SCHEMA[key]["default"]
	_read_default_bindings()
	for action in BINDABLE_ACTIONS:
		_bindings[action] = (_default_bindings[action] as Array).duplicate()


## The shared instance: what the game's systems read and listen to.
static func get_instance() -> Settings:
	if _instance == null:
		_instance = Settings.new()
		_instance.applies_to_engine = true
	return _instance


## The camera's vertical field of view, in degrees, that shows
## [param horizontal_degrees] across a screen with width / height [param aspect].
## With the default 4:3, 90° gives 73.74°, which is what CS's 90 means. A wider
## screen then shows more to the sides at the same vertical angle, as in CS.
static func vertical_fov(horizontal_degrees: float, aspect: float = REFERENCE_ASPECT) -> float:
	return rad_to_deg(2.0 * atan(tan(deg_to_rad(horizontal_degrees) / 2.0) / aspect))


## The opposite of [method vertical_fov].
static func horizontal_fov(vertical_degrees: float, aspect: float = REFERENCE_ASPECT) -> float:
	return rad_to_deg(2.0 * atan(tan(deg_to_rad(vertical_degrees) / 2.0) * aspect))


## The default value of the setting [param key].
static func get_default(key: StringName) -> Variant:
	return SCHEMA[key]["default"]


## The smallest and largest value of a number setting (x = smallest, y = largest),
## or [constant Vector2.ZERO] for the others. For sliders.
static func get_range(key: StringName) -> Vector2:
	var entry: Dictionary = SCHEMA[key]
	if entry.has("min"):
		return Vector2(entry["min"], entry["max"])
	if entry.has("choices") and typeof(entry["default"]) == TYPE_INT:
		var choices: Array = entry["choices"]
		return Vector2(choices.min(), choices.max())
	return Vector2.ZERO


## True if [param key] names a setting.
static func has_setting(key: StringName) -> bool:
	return SCHEMA.has(key)


## The text of a key or mouse button binding, for menus: "W", "Space", "`",
## "Num 1", "Left Mouse". Empty for null and other kinds of events.
static func binding_text(event: InputEvent) -> String:
	if event is InputEventKey:
		var code := (event as InputEventKey).physical_keycode
		# Shows what is printed on the key in the player's layout (Z on a Czech
		# keyboard's Y position). Headless runs have no keyboard layout.
		if DisplayServer.get_name() != "headless":
			var label := DisplayServer.keyboard_get_label_from_physical(code)
			if label != KEY_NONE:
				code = label
		return KEY_NAMES.get(code, OS.get_keycode_string(code))
	if event is InputEventMouseButton:
		var button := (event as InputEventMouseButton).button_index
		return MOUSE_BUTTON_NAMES.get(button, "Mouse %d" % button)
	return ""


## The current value of the setting [param key] (null, with an error, if there is no such setting).
func get_value(key: StringName) -> Variant:
	if not SCHEMA.has(key):
		push_error("Unknown setting '%s'." % key)
		return null
	return _values[key]


## Changes the setting [param key]. The value is clamped to the setting's range
## (wrong types fall back to the default), so [method get_value] may return
## something else afterwards. If it differs from before, it is applied,
## [signal changed] is emitted and the file is saved.
func set_value(key: StringName, value: Variant) -> void:
	if not SCHEMA.has(key):
		push_error("Unknown setting '%s'." % key)
		return
	var clean: Variant = _sanitize(key, value)
	if clean == _values[key]:
		return
	_values[key] = clean
	_apply(key)
	changed.emit(key)
	_mark_dirty()


## Puts every setting and every key binding back to its default.
func reset_to_defaults() -> void:
	_batch_depth += 1
	for key: StringName in SCHEMA:
		set_value(key, SCHEMA[key]["default"])
	reset_bindings()
	_batch_depth -= 1
	_flush()


## The key or mouse button in slot [param slot] (0 primary, 1 secondary) of
## [param action], or null if it has none. A copy: change bindings with [method set_binding].
func get_binding(action: StringName, slot: int = 0) -> InputEvent:
	if not _bindings.has(action) or slot < 0 or slot >= BINDING_SLOTS:
		return null
	var event: InputEvent = _bindings[action][slot]
	return event.duplicate() if event != null else null


## Binds [param event] (a key, by its physical position, or a mouse button) to
## slot [param slot] of [param action], replacing what was there. Returns false
## if the action can't be rebound or the event is neither a key nor a mouse button.
## It does not unbind the same key from other actions: see [method find_action_using].
func set_binding(action: StringName, event: InputEvent, slot: int = 0) -> bool:
	if not _bindings.has(action) or slot < 0 or slot >= BINDING_SLOTS:
		return false
	var clean := _clean_event(event)
	if clean == null:
		return false
	if _event_to_text(_bindings[action][slot]) != _event_to_text(clean):
		_bindings[action][slot] = clean
		_bindings_changed()
	return true


## True if [param event] is something a binding can hold: a key or one of the
## mouse buttons (the wheel included). The settings menu asks before it binds.
static func can_bind(event: InputEvent) -> bool:
	return _clean_event(event) != null


## Binds [param event] to slot [param slot] of [param action] and takes it away
## from every other slot that holds it, so a key or button belongs to one
## action only: the later bind wins, as CS's [code]bind[/code] does (D-059).
## Returns what lost it, as an array of [code][action, slot][/code] pairs (the
## other slot of the same action included), empty if nothing did. Does nothing
## and returns an empty array when the event can't be bound ([method can_bind])
## or the action or slot is wrong. Saved once, and the key is never bound twice
## in the [InputMap] in between.
func bind_exclusive(action: StringName, event: InputEvent, slot: int = 0) -> Array:
	var lost: Array = []
	if not _bindings.has(action) or slot < 0 or slot >= BINDING_SLOTS or not can_bind(event):
		return lost
	var wanted := _event_to_text(_clean_event(event))
	_batch_depth += 1
	for other in BINDABLE_ACTIONS:
		for other_slot in BINDING_SLOTS:
			if (other != action or other_slot != slot) and _event_to_text(_bindings[other][other_slot]) == wanted:
				clear_binding(other, other_slot)
				lost.append([other, other_slot])
	set_binding(action, event, slot)
	_batch_depth -= 1
	_flush()
	return lost


## Leaves slot [param slot] of [param action] without a key.
func clear_binding(action: StringName, slot: int = 0) -> void:
	if not _bindings.has(action) or slot < 0 or slot >= BINDING_SLOTS or _bindings[action][slot] == null:
		return
	_bindings[action][slot] = null
	_bindings_changed()


## The action that [param event] is bound to, other than [param except], or
## [code]&""[/code] if it is free. A menu uses it to warn about a clash.
func find_action_using(event: InputEvent, except: StringName = &"") -> StringName:
	var wanted := _event_to_text(_clean_event(event))
	if wanted == "":
		return &""
	for action in BINDABLE_ACTIONS:
		if action == except:
			continue
		for slot in BINDING_SLOTS:
			if _event_to_text(_bindings[action][slot]) == wanted:
				return action
	return &""


## Puts one action's keys back to the project's defaults.
func reset_binding(action: StringName) -> void:
	if not _bindings.has(action) or _same_slots(_bindings[action], _default_bindings[action]):
		return
	_bindings[action] = (_default_bindings[action] as Array).duplicate()
	_bindings_changed()


## Puts every action's keys back to the project's defaults.
func reset_bindings() -> void:
	var different := false
	for action in BINDABLE_ACTIONS:
		different = different or not _same_slots(_bindings[action], _default_bindings[action])
		_bindings[action] = (_default_bindings[action] as Array).duplicate()
	if different:
		_bindings_changed()


## Reads the settings file at [param path] and applies everything, and from now
## on saves every change to that file. A missing file is no error: the defaults
## stay (the file appears with the first change). Unknown keys are ignored,
## missing keys keep their default, values outside their range are clamped and
## values of the wrong type fall back to the default, so a hand-edited file can't
## break the game. A file that can't be parsed at all leaves everything on
## defaults. Returns the file's error: [constant OK],
## [constant ERR_FILE_NOT_FOUND] or [constant ERR_PARSE_ERROR].
func load_from_disk(path: String = SETTINGS_PATH) -> Error:
	save_path = path
	var file := ConfigFile.new()
	var result := file.load(path)
	if result != OK:
		apply_all()
		return result
	_batch_depth += 1
	for key: StringName in SCHEMA:
		var entry: Dictionary = SCHEMA[key]
		set_value(key, file.get_value(entry["section"], _file_key(key), entry["default"]))
	_load_bindings(file)
	_batch_depth -= 1
	# What was just read is already in the file; clamped values wait for the next change.
	_dirty = false
	apply_all()
	return OK


## True once [method load_from_disk] has run (a missing file counts: the defaults
## stay). The main menu and main.gd both load the settings at startup and use this
## to read the file only once.
func is_loaded() -> bool:
	return save_path != ""


## Writes every setting and key binding to [param path], or to [member save_path]
## if no path is given. Done automatically after each change once [method
## load_from_disk] has set the path.
func save_to_disk(path: String = "") -> Error:
	var target := path if path != "" else save_path
	if target == "":
		return ERR_UNCONFIGURED
	var file := ConfigFile.new()
	for key: StringName in SCHEMA:
		file.set_value(SCHEMA[key]["section"], _file_key(key), _values[key])
	for action in BINDABLE_ACTIONS:
		# A plain Array, so the file reads ["key:87", ""] and not Array[String](...).
		var texts: Array = []
		for event: InputEvent in _bindings[action]:
			texts.append(_event_to_text(event))
		file.set_value("controls", action, texts)
	return file.save(target)


## Applies the settings that reach the engine (window, frame rate, audio buses,
## key bindings), whatever their value. Does nothing on an instance that doesn't
## [member applies_to_engine].
func apply_all() -> void:
	for key in [&"fullscreen", &"vsync", &"fps_cap", &"master_volume", &"effects_volume", &"interface_volume", &"bindings"]:
		_apply(key)


# --- Applying ---


## Sends one setting to the engine. The settings that only things in the scene
## use (sensitivity, field of view, crosshair, pixel settings) have nothing to
## do here: those nodes listen to [signal changed].
func _apply(key: StringName) -> void:
	if not applies_to_engine:
		return
	match key:
		&"fullscreen":
			_apply_fullscreen()
		&"vsync":
			if DisplayServer.get_name() != "headless":
				DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
		&"fps_cap":
			Engine.max_fps = fps_cap
		&"master_volume":
			_apply_volume(BUS_MASTER, master_volume)
		&"effects_volume":
			_apply_volume(BUS_EFFECTS, effects_volume)
		&"interface_volume":
			_apply_volume(BUS_INTERFACE, interface_volume)
		&"bindings":
			_apply_bindings()


## Switches between window and fullscreen, only when the window isn't already
## in the wanted state (so a game started with --fullscreen isn't forced out of it).
func _apply_fullscreen() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var mode := DisplayServer.window_get_mode()
	var is_fullscreen := mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	if fullscreen != is_fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)


## Sets a bus's volume from a 0 to 1 slider value: 1 is 0 dB (as made), 0 mutes the bus.
func _apply_volume(bus_name: StringName, linear: float) -> void:
	var bus := AudioServer.get_bus_index(bus_name)
	if bus < 0:
		return
	AudioServer.set_bus_mute(bus, linear <= 0.0)
	if linear > 0.0:
		AudioServer.set_bus_volume_db(bus, linear_to_db(linear))


## Gives every bindable action in the InputMap exactly the keys of these settings.
## The events get device -1 (all devices), like bindings made in the editor.
func _apply_bindings() -> void:
	for action in BINDABLE_ACTIONS:
		if not InputMap.has_action(action):
			continue
		InputMap.action_erase_events(action)
		for event: InputEvent in _bindings[action]:
			if event != null:
				InputMap.action_add_event(action, event.duplicate())


# --- Saving and loading ---


func _mark_dirty() -> void:
	_dirty = true
	if _batch_depth == 0:
		_flush()


## Saves if something changed and the settings have a file.
func _flush() -> void:
	if not _dirty or save_path == "":
		return
	_dirty = false
	var result := save_to_disk()
	if result != OK:
		push_warning("Chiip: could not save the settings to %s (error %d)." % [save_path, result])


func _bindings_changed() -> void:
	_apply(&"bindings")
	changed.emit(&"bindings")
	_mark_dirty()


## Reads the [controls] section. An action without an entry, or with an entry
## that holds nothing usable, keeps its default; an entry that is empty
## (["", ""]) unbinds it.
func _load_bindings(file: ConfigFile) -> void:
	var changed_any := false
	for action in BINDABLE_ACTIONS:
		var slots: Array = []
		if file.has_section_key("controls", action):
			slots = _slots_from_stored(file.get_value("controls", action))
		if slots.is_empty():
			slots = (_default_bindings[action] as Array).duplicate()
		if not _same_slots(slots, _bindings[action]):
			_bindings[action] = slots
			changed_any = true
	if changed_any:
		_bindings_changed()


## The BINDING_SLOTS events stored for an action, or an empty array when the
## stored value is not a list, or is a list of text where none can be read.
func _slots_from_stored(stored: Variant) -> Array:
	if not (stored is Array or stored is PackedStringArray):
		return []
	var texts: Array = Array(stored)
	var slots: Array = []
	var readable := 0
	var filled := 0
	for text: Variant in texts:
		var event := _event_from_text(text) if text is String else null
		if text is String and text != "":
			filled += 1
		if event != null:
			readable += 1
		if slots.size() < BINDING_SLOTS:
			slots.append(event)
	if filled > 0 and readable == 0:
		return []
	while slots.size() < BINDING_SLOTS:
		slots.append(null)
	return slots


## True if two lists of binding slots hold the same keys and buttons.
static func _same_slots(a: Array, b: Array) -> bool:
	for slot in BINDING_SLOTS:
		if _event_to_text(a[slot]) != _event_to_text(b[slot]):
			return false
	return true


## The file's name for a setting: its section's name is dropped from the front.
static func _file_key(key: StringName) -> String:
	return String(key).trim_prefix(str(SCHEMA[key]["section"]) + "_")


# --- Checking values and keys ---


## Turns whatever was given (from code, the console or a file) into a valid
## value for [param key]: clamped, snapped, or the default if it is the wrong type.
static func _sanitize(key: StringName, value: Variant) -> Variant:
	var entry: Dictionary = SCHEMA[key]
	var fallback: Variant = entry["default"]
	match typeof(fallback):
		TYPE_BOOL:
			return value if typeof(value) == TYPE_BOOL else fallback
		TYPE_FLOAT:
			if not _is_number(value):
				return fallback
			return clampf(float(value), entry["min"], entry["max"])
		TYPE_INT:
			if not _is_number(value):
				return fallback
			var number := roundi(float(value))
			if entry.has("choices"):
				return _nearest(entry["choices"], number)
			if entry.has("off") and number <= entry["off"]:
				return entry["off"]
			return clampi(number, entry["min"], entry["max"])
		TYPE_STRING:
			if typeof(value) != TYPE_STRING:
				return fallback
			if entry.has("choices") and not (entry["choices"] as Array).has(value):
				return fallback
			return value
		TYPE_COLOR:
			if typeof(value) != TYPE_COLOR:
				return fallback
			var color: Color = value
			return Color(clampf(color.r, 0.0, 1.0), clampf(color.g, 0.0, 1.0), clampf(color.b, 0.0, 1.0), clampf(color.a, 0.0, 1.0))
	return fallback


## True for an int or a float that is a real number (not NaN or infinite).
static func _is_number(value: Variant) -> bool:
	return (typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT) and is_finite(float(value))


## The entry of [param choices] closest to [param number].
static func _nearest(choices: Array, number: int) -> int:
	var best: int = choices[0]
	for choice: int in choices:
		if absi(choice - number) < absi(best - number):
			best = choice
	return best


## Reads the InputMap's actions as they are in project.godot, once. Later
## calls (and other instances) keep what was read first.
static func _read_default_bindings() -> void:
	if not _default_bindings.is_empty():
		return
	for action in BINDABLE_ACTIONS:
		var slots: Array = []
		if InputMap.has_action(action):
			for event in InputMap.action_get_events(action):
				var clean := _clean_event(event)
				if clean != null and slots.size() < BINDING_SLOTS:
					slots.append(clean)
		while slots.size() < BINDING_SLOTS:
			slots.append(null)
		_default_bindings[action] = slots


## A clean copy of a key (by physical position) or mouse button event, with
## device -1 (all devices) and nothing else set; null for anything else.
static func _clean_event(event: InputEvent) -> InputEvent:
	if event is InputEventKey:
		var key := event as InputEventKey
		var code := key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
		if code == KEY_NONE:
			return null
		var clean := InputEventKey.new()
		clean.device = -1
		clean.physical_keycode = code
		return clean
	if event is InputEventMouseButton:
		var button := (event as InputEventMouseButton).button_index
		if button < MOUSE_BUTTON_LEFT or button > MOUSE_BUTTON_XBUTTON2:
			return null
		var clean := InputEventMouseButton.new()
		clean.device = -1
		clean.button_index = button
		return clean
	return null


## "key:87" or "mouse:5" for a clean event, "" for null. How bindings are written in the file.
static func _event_to_text(event: InputEvent) -> String:
	if event is InputEventKey:
		return "key:%d" % (event as InputEventKey).physical_keycode
	if event is InputEventMouseButton:
		return "mouse:%d" % (event as InputEventMouseButton).button_index
	return ""


## The event for text written by [method _event_to_text], or null if it isn't one.
static func _event_from_text(text: String) -> InputEvent:
	var parts := text.split(":")
	if parts.size() != 2 or not parts[1].is_valid_int():
		return null
	var number := parts[1].to_int()
	var event: InputEvent = null
	if parts[0] == "key":
		var key := InputEventKey.new()
		key.physical_keycode = number as Key
		event = key
	elif parts[0] == "mouse":
		var button := InputEventMouseButton.new()
		button.button_index = number as MouseButton
		event = button
	return _clean_event(event) if event != null else null
