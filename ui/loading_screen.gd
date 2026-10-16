class_name LoadingScreen
extends CanvasLayer
## The loading screen (M10 task 15, D-138), as the mockup draws it ("07 Loading /
## Map change"): the game stays visible and an INK band, 240 px high, runs across
## the bottom. On its left stand the small line ("Map 2 of 3 · Rotation"), the
## map's name in 96 px and the mode with its limit ("Team Deathmatch · first to
## 50"); on its right "Loading" over a row of twelve squares that fill while the
## screen is up: done ones in the text colour, the current one in the accent, the
## rest in LINE. The lines come from [method MatchText.loading_lines].
##
## **It owns the pause while it shows.** [method show_screen] pauses the whole
## tree (so the world stands still behind the band and the match clock doesn't
## run, like the pause menu, D-065) and hiding it unpauses. It is
## [code]process_mode = Always[/code] so it can count the time while paused, and it
## counts it in [code]_process[/code] deltas ([member hold_time] seconds), never
## in wall-clock time.
##
## **It swallows every input event** while it shows. It is the last node of
## [code]main.tscn[/code] and input reaches the nodes at the end of the tree first
## (see "Menus and the mouse" in docs/ARCHITECTURE.md), so Esc, the console key,
## B, M and the mouse never reach the pause menu, console, buy menu, class menu or
## the player. It doesn't register with [MenuState]: the mouse isn't its business.
## The class draft of a match start waits for it (D-152: [method ClassMenu.open_if_pending]
## opens it when [signal finished] comes), so nothing is ever drawn under the band. Only the
## polled hold-Tab scoreboard and the class menu need to ask [method is_showing].
##
## [code]main.gd[/code] shows it when a map comes from the main menu and when the
## rotation moves on ([code]next_map()[/code]), and hides the HUD while it is up.

## Emitted when the hold time is over: the screen has hidden itself and unpaused the game.
signal finished

## Global switch. Tests that change scenes the real way (the menu's Play button
## changes to main.tscn, whose [member Main.loading_screen] they can't reach before
## its [code]_ready[/code]) turn it off; the game never does.
static var enabled: bool = true

## The screen that is showing, or null. Static so the polled scoreboard can ask
## without a reference (see [method is_showing]).
static var _active: LoadingScreen = null

## How long the band stays up, in seconds. The squares fill evenly over it.
@export var hold_time: float = 1.5

## Seconds counted since [method show_screen].
var _elapsed: float = 0.0
## How many squares are done now.
var _done: int = 0
## True while a map is about to be loaded under the screen: it stays up until [method map_loaded].
var _map_follows: bool = false

@onready var _band: Panel = $Band
@onready var _left: VBoxContainer = %Left
@onready var _right: VBoxContainer = %Right
@onready var _kicker: Label = %Kicker
@onready var _map_name: Label = %MapName
@onready var _mode_line: Label = %ModeLine
@onready var _chip_row: HBoxContainer = %Chips


func _ready() -> void:
	visible = false
	set_process(false)


func _exit_tree() -> void:
	# Freed or removed while up (the game scene changes under it): don't leave the next scene paused.
	if _active == self:
		_active = null
		get_tree().paused = false


func _input(_event: InputEvent) -> void:
	if visible:
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	advance(delta)


## True while a loading screen is up. The hold-Tab scoreboard (it polls the key
## instead of receiving an event) asks it.
static func is_showing() -> bool:
	return is_instance_valid(_active) and _active.visible


## Shows the band with [param lines] (the three lines of [method MatchText.loading_lines])
## and pauses the game, counting the hold time from now. With [param map_follows]
## the screen stays up after the hold time until [method map_loaded] is called
## (the map is loaded under it, which takes the time it takes).
func show_screen(lines: PackedStringArray, map_follows: bool = false) -> void:
	if lines.size() >= 3:
		_kicker.text = lines[0]
		_map_name.text = lines[1]
		_mode_line.text = lines[2]
	_elapsed = 0.0
	_map_follows = map_follows
	_update_chips()
	visible = true
	_active = self
	set_process(true)
	get_tree().paused = true


## Says that the map is loaded: the screen hides as soon as the hold time is over (at once if it is).
func map_loaded() -> void:
	_map_follows = false
	_finish_when_due()


## Counts [param seconds] more of the hold time as passed and moves the squares.
## [code]_process[/code] calls it with every frame's delta; tests and the
## screenshot tool call it to skip ahead. Does nothing while the screen is hidden.
func advance(seconds: float) -> void:
	if not visible:
		return
	_elapsed += seconds
	_update_chips()
	_finish_when_due()


## Scales the layout; 1.0 is the size it's designed for (a 720-pixel-tall window).
func set_ui_scale(factor: float) -> void:
	UiTheme.apply(self, factor)


func _finish_when_due() -> void:
	if _elapsed < hold_time or _map_follows or not visible:
		return
	visible = false
	set_process(false)
	if _active == self:
		_active = null
	get_tree().paused = false
	finished.emit()


## Gives every square its role: done ones TextChip, the current one AccentChip, the rest LineChip.
func _update_chips() -> void:
	var chips := _chip_row.get_children()
	var count := chips.size()
	_done = count if hold_time <= 0.0 else mini(floori(_elapsed / hold_time * count), count)
	for i in count:
		var role := &"TextChip" if i < _done else (&"AccentChip" if i == _done else &"LineChip")
		(chips[i] as Panel).theme_type_variation = role


# --- Test hooks ---


## The three lines now: the small line, the map's name and the mode line.
func get_lines() -> PackedStringArray:
	return PackedStringArray([_kicker.text, _map_name.text, _mode_line.text])


## How many squares are done (they fill over [member hold_time]).
func get_done_chips() -> int:
	return _done


## The squares, left to right.
func get_chips() -> Array[Panel]:
	var chips: Array[Panel] = []
	for chip in _chip_row.get_children():
		chips.append(chip as Panel)
	return chips


## The INK band across the bottom.
func get_band() -> Panel:
	return _band


## The left column (small line, map's name, mode line).
func get_left_column() -> VBoxContainer:
	return _left


## The right column ("Loading" over the squares).
func get_right_column() -> VBoxContainer:
	return _right


## The map's name label (96 px).
func get_map_name_label() -> Label:
	return _map_name
