class_name LastInput
extends RefCounted
## Which kind of device the player used last, keyboard and mouse or gamepad (M15, D-213), so prompts
## can name the right button ("Hold LB · defuse" or "Hold E · defuse").
##
## A static class with static state, like [Settings] and [MenuState]: no node, no autoload. Something
## has to feed it: [PadInput] (a node in the game and in the main menu) passes every input event to
## [method note]. Anything that shows a prompt asks [method prompt_for] when it shows it.

## True while the gamepad is the last device used. Starts false: a keyboard and mouse game.
static var gamepad: bool = false

## How far a stick or trigger must move to count as "the gamepad is being used": it drifts a little at rest.
const AXIS_THRESHOLD := 0.5
## How far (in pixels) the mouse must move to count as being used.
const MOUSE_THRESHOLD := 2.0


## Updates [member gamepad] from [param event]: a gamepad button, or a stick or trigger pushed past
## [constant AXIS_THRESHOLD], switches to the pad; a key, a mouse button or a real mouse movement back.
static func note(event: InputEvent) -> void:
	if event is InputEventJoypadButton:
		if (event as InputEventJoypadButton).pressed:
			gamepad = true
	elif event is InputEventJoypadMotion:
		if absf((event as InputEventJoypadMotion).axis_value) > AXIS_THRESHOLD:
			gamepad = true
	elif event is InputEventKey:
		if (event as InputEventKey).pressed:
			gamepad = false
	elif event is InputEventMouseButton:
		if (event as InputEventMouseButton).pressed:
			gamepad = false
	elif event is InputEventMouseMotion:
		if (event as InputEventMouseMotion).relative.length() > MOUSE_THRESHOLD:
			gamepad = false


## The text of the button or key that does [param action] on the device used last: "RT" or "Left Mouse",
## "LB" or "E". The first bound key of the action when the pad has none, and "" when nothing is bound.
## Movement and looking are the sticks on a pad: "L-Stick" and "R-Stick".
static func prompt_for(action: StringName, settings: Settings = null) -> String:
	if settings == null:
		settings = Settings.get_instance()
	if gamepad:
		if action.begins_with("move_"):
			return "L-Stick"
		var pad_text := Settings.pad_text(settings.get_pad_binding(action))
		if pad_text != "":
			return pad_text
	for slot in Settings.BINDING_SLOTS:
		var text := Settings.binding_text(settings.get_binding(action, slot))
		if text != "":
			return text
	return ""
