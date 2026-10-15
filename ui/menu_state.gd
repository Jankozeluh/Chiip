class_name MenuState
extends RefCounted
## One shared answer to "is a menu open?" (D-059): the settings menu, the
## developer console and, in tasks 11 and 12, the main and pause menus all
## register here, and everything that must stop reacting while a menu is up
## asks here. The player controller ignores movement, shooting and looking, the
## hold-Tab scoreboard stays hidden, and the mouse is shown while the first menu
## opens and captured again when the last one closes.
##
## A static class with a static list, like [Settings], [Teams] and [Noises]:
## no node, no autoload, so tests and tools can use it. A menu calls
## [method open] when it appears and [method close] when it goes away (also
## when it is freed while open: dead entries are dropped by themselves).
##
## The mouse rule is "the last menu to close gives the mouse back to the game".
## The main menu (task 11) registers too, so closing the settings menu on top of
## it leaves the mouse visible; it is only captured when the main menu closes
## because a game starts.
##
## Typical use in a menu:
## [codeblock]
## func open() -> void:
##     visible = true
##     MenuState.open(self)
##
## func close() -> void:
##     visible = false
##     MenuState.close(self)
##
## func _input(event: InputEvent) -> void:
##     # Only the menu on top reacts to Esc.
##     if visible and MenuState.is_top(self) and event.is_action_pressed("toggle_mouse"):
##         close()
##         get_viewport().set_input_as_handled()
## [/codeblock]

## True while a menu waits for the next key or mouse button to bind to an action
## (the settings menu's Controls tab). The console key and Esc must not react
## then: the key they would have taken is the new binding.
static var capturing_input: bool = false

## The open menus, oldest first: the last one is on top. Untyped on purpose: a
## menu freed while open stays in the list as a dead object until it is dropped.
static var _open: Array = []


## Registers [param menu] as open (it is on top now) and shows the mouse.
## Opening a menu that is already open brings it to the top.
static func open(menu: Node) -> void:
	_drop_freed()
	_open.erase(menu)
	_open.append(menu)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


## Unregisters [param menu]. When it was the last one open, the mouse is
## captured again. Closing a menu that isn't open does nothing.
static func close(menu: Node) -> void:
	if not _open.has(menu):
		return
	_open.erase(menu)
	_drop_freed()
	if _open.is_empty():
		capturing_input = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## True if [param menu] is registered as open.
static func is_open(menu: Node) -> bool:
	_drop_freed()
	return _open.has(menu)


## True while at least one menu (the console counts) is open.
static func is_any_open() -> bool:
	_drop_freed()
	return not _open.is_empty()


## True if [param menu] is the one opened last, the one on top. Only that menu
## should react to Esc.
static func is_top(menu: Node) -> bool:
	_drop_freed()
	return not _open.is_empty() and _open[-1] == menu


## True when the player's controls should ignore the keyboard and mouse: a
## menu is open, or [member DevConsole.is_open] is set (the console registers
## here too, the flag also covers code that sets it directly).
static func blocks_gameplay() -> bool:
	return is_any_open() or DevConsole.is_open


## Forgets every open menu and the key capture, without touching the mouse.
## For tests that leave menus open.
static func reset() -> void:
	_open.clear()
	capturing_input = false


## Drops menus that were freed while they were open.
static func _drop_freed() -> void:
	var index := _open.size() - 1
	while index >= 0:
		if not is_instance_valid(_open[index]):
			_open.remove_at(index)
		index -= 1
