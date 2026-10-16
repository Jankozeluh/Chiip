class_name PadGlyphs
extends RefCounted
## The gamepad button glyphs of the v0.2 design (D-230): 16 × 16 pixel pictures of every button of an Xbox, a
## PlayStation and a generic pad, in assets/ui/glyphs/<style>/<button>.png (the face buttons in the pad's own
## colours) and <button>_mono.png (white, to tint). They come from tools/make_pad_glyphs.py, the port of the
## designer's Glyph component. Show them at whole multiples (16 px, 32 px) with nearest filtering ([UiTheme] sets
## that on every control it handles).
##
## A glyph is named by the button's place, not by a pad's label, so one binding shows the right picture on every
## pad: [code]south[/code] is A on Xbox, Cross on PlayStation, the bottom dot on a generic pad.

## The pad styles, in the order of the Controller tab's "Button prompts" row (after "auto").
const STYLES: Array[String] = ["xbox", "ps", "generic"]
## The setting's choices: "auto" picks the style of the pad plugged in.
const CHOICES: Array[String] = Settings.PAD_PROMPTS
## Where the pictures are.
const FOLDER := "res://assets/ui/glyphs/"
## Words in a controller's name that mean it is a PlayStation or an Xbox pad.
const PS_NAMES: Array[String] = ["playstation", "ps3", "ps4", "ps5", "dualshock", "dualsense", "sony"]
const XBOX_NAMES: Array[String] = ["xbox", "xinput", "microsoft"]
## The glyph name of each gamepad button (a [enum JoyButton] value).
const BUTTON_NAMES := {
	JOY_BUTTON_A: "south", JOY_BUTTON_B: "east", JOY_BUTTON_X: "west", JOY_BUTTON_Y: "north",
	JOY_BUTTON_BACK: "select", JOY_BUTTON_START: "start", JOY_BUTTON_LEFT_STICK: "l3", JOY_BUTTON_RIGHT_STICK: "r3",
	JOY_BUTTON_LEFT_SHOULDER: "lb", JOY_BUTTON_RIGHT_SHOULDER: "rb",
	JOY_BUTTON_DPAD_UP: "dup", JOY_BUTTON_DPAD_DOWN: "ddown", JOY_BUTTON_DPAD_LEFT: "dleft", JOY_BUTTON_DPAD_RIGHT: "dright",
}
## The glyph name of a stick or trigger movement (an [enum JoyAxis] value).
const AXIS_NAMES := {
	JOY_AXIS_LEFT_X: "ls", JOY_AXIS_LEFT_Y: "ls", JOY_AXIS_RIGHT_X: "rs", JOY_AXIS_RIGHT_Y: "rs",
	JOY_AXIS_TRIGGER_LEFT: "lt", JOY_AXIS_TRIGGER_RIGHT: "rt",
}

## Pictures already loaded, by "style/button[_mono]".
static var _cache: Dictionary = {}


## The pad style to draw for the setting [param choice] ("auto", "xbox", "ps" or "generic"): "auto" looks at the
## name of the first pad plugged in (a PlayStation pad gets PlayStation glyphs, an Xbox pad Xbox ones, any other
## pad the generic ones) and answers "xbox" with no pad at all.
static func style_for(choice: String) -> String:
	if choice in STYLES:
		return choice
	var pads := Input.get_connected_joypads()
	if pads.is_empty():
		return "xbox"
	var pad_name := Input.get_joy_name(pads[0]).to_lower()
	for word in PS_NAMES:
		if pad_name.contains(word):
			return "ps"
	for word in XBOX_NAMES:
		if pad_name.contains(word):
			return "xbox"
	return "generic"


## The glyph name ("south", "lt", "ls"...) of a gamepad [param event] (a button press or a stick or trigger
## movement), or "" for anything else.
static func button_for_event(event: InputEvent) -> String:
	if event is InputEventJoypadButton:
		return BUTTON_NAMES.get((event as InputEventJoypadButton).button_index, "")
	if event is InputEventJoypadMotion:
		return AXIS_NAMES.get((event as InputEventJoypadMotion).axis, "")
	return ""


## The picture of [param button] on a pad of [param style] ("xbox", "ps" or "generic"), or null for a button
## with none. With [param mono] it is white, to tint with [code]modulate[/code].
static func get_texture(style: String, button: String, mono: bool = false) -> Texture2D:
	var key := "%s/%s%s" % [style, button, "_mono" if mono else ""]
	if not _cache.has(key):
		var path := "%s%s.png" % [FOLDER, key]
		_cache[key] = load(path) as Texture2D if ResourceLoader.exists(path) else null
	return _cache[key]


## Every glyph name there is, as the designer's component lists them.
static func all_buttons() -> Array[String]:
	return ["south", "east", "west", "north", "lb", "rb", "lt", "rt", "ls", "rs", "l3", "r3",
			"dup", "ddown", "dleft", "dright", "d", "start", "select"]
