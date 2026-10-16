class_name PadInput
extends Node
## Makes menus work with a gamepad (M15, D-211, D-213). One of these sits in the game scene and in
## the main menu; it never handles an event, it only watches them (an [code]_input[/code] that
## sets nothing as handled).
##
## - It tells [LastInput] about every event, so prompts follow the device used last.
## - Godot's own menu navigation (D-pad or left stick moves the focus, A presses, B is
##   [code]ui_cancel[/code]) works by itself once something has focus. Chiip's menus close on the
##   [code]pause[/code] action, which is Esc and the pad's Start; B (crouch in the game) is turned
##   into a [code]pause[/code] press while a menu is open, so B backs out of any menu like Esc.
## - A pad press while a menu is open but nothing has focus gives the focus to the menu's first
##   button, so the D-pad has somewhere to start.

## Pressed once to turn B into Esc, then released the next frame.
var _release_pending: bool = false


func _ready() -> void:
	ensure_menu_buttons()


## Gives Godot's [code]ui_accept[/code] the pad's A and [code]ui_cancel[/code] its B, if they have no
## gamepad button yet (this engine build only brings the D-pad and the left stick), so A presses the
## focused button in every menu. Safe to call again.
static func ensure_menu_buttons() -> void:
	for pair: Array in [[&"ui_accept", JOY_BUTTON_A], [&"ui_cancel", JOY_BUTTON_B]]:
		var action: StringName = pair[0]
		if not InputMap.has_action(action):
			continue
		var has_button := false
		for event in InputMap.action_get_events(action):
			has_button = has_button or event is InputEventJoypadButton
		if not has_button:
			var button := InputEventJoypadButton.new()
			button.device = -1
			button.button_index = pair[1]
			InputMap.action_add_event(action, button)


func _input(event: InputEvent) -> void:
	LastInput.note(event)
	if not (event is InputEventJoypadButton or event is InputEventJoypadMotion):
		return
	if not MenuState.is_any_open() or MenuState.capturing_input:
		return
	if event is InputEventJoypadButton and event.is_pressed() and event.is_action(&"ui_cancel"):
		_press_pause()
		return
	if _wants_focus(event):
		var owner_control := get_viewport().gui_get_focus_owner()
		if owner_control == null or not owner_control.is_visible_in_tree():
			_focus_first(MenuState.get_top())


## True for the first push of a stick or button that navigates a menu.
func _wants_focus(event: InputEvent) -> bool:
	if event is InputEventJoypadButton:
		return event.is_pressed()
	return absf((event as InputEventJoypadMotion).axis_value) > LastInput.AXIS_THRESHOLD


## Sends a [code]pause[/code] press, as Esc would.
func _press_pause() -> void:
	var press := InputEventAction.new()
	press.action = &"pause"
	press.pressed = true
	Input.parse_input_event(press)
	_release_pending = true


func _process(_delta: float) -> void:
	if _release_pending:
		_release_pending = false
		var release := InputEventAction.new()
		release.action = &"pause"
		release.pressed = false
		Input.parse_input_event(release)


## Gives the focus to the first focusable, visible control at or below [param node] (depth first).
## Returns true when something took it.
func _focus_first(node: Node) -> bool:
	if node == null:
		return false
	if node is Control:
		var control := node as Control
		if not control.visible:
			return false
		if control.focus_mode == Control.FOCUS_ALL and control.is_visible_in_tree():
			if not (control is BaseButton and (control as BaseButton).disabled):
				control.grab_focus()
				return true
	for child in node.get_children():
		if _focus_first(child):
			return true
	return false
