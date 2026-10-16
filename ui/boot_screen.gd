class_name BootScreen
extends CanvasLayer
## The boot screen (M11, D-153), the mockup's "01 Boot": the studio logo (224 × 224, pixel art, drawn
## with nearest filtering) centred on the deepest dark, a row of eight squares that fill while it shows
## and "Any key to skip" at the bottom. The main menu shows it once per run, before the menu appears
## ([method MainMenu._show_boot_screen]); any key or mouse click skips it, and it hides itself after
## [member hold_time] seconds.
##
## **The logo is a file you provide:** [code]res://assets/ui/studio_logo.png[/code] (a square PNG; the
## mockup's was a web link that never reached the project, D-138). Until the file exists the screen
## shows the game's name in its place, so it never breaks, and the main menu's small mark
## (bottom right, 56 × 56) stays hidden. Drop the file in and open the editor (or run the import
## command) and both pick it up.
##
## It swallows every input event while it shows, like [LoadingScreen]: it is the last node of the main
## menu, so input reaches it first, and the key that skips it never also presses a menu item.

## Emitted once, when the screen has hidden itself (by timeout or by a key).
signal finished

## Where the studio logo is. Static so a test can point it at another picture.
static var logo_path: String = "res://assets/ui/studio_logo.png"

## Global switch. Tests and headless runs never show the screen; the game does once per run.
static var enabled: bool = true
## True once a boot screen has shown in this run: the menu comes back from a match without it.
static var _shown: bool = false

## How long the screen stays up, in seconds. The squares fill evenly over it.
@export var hold_time: float = 2.5

## Seconds counted since [method show_screen].
var _elapsed: float = 0.0
## How many squares are done now.
var _done: int = 0
## True while the screen is up.
var _active: bool = false

@onready var _logo: TextureRect = %Logo
@onready var _wordmark: Label = %Wordmark
@onready var _chip_row: HBoxContainer = %Chips


func _ready() -> void:
	visible = false
	set_process(false)
	_show_logo_or_wordmark()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton:
		if event.is_pressed() and not event.is_echo():
			finish()
	# Everything is swallowed, also the key that skips.
	get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	advance(delta)


## True if a boot screen should show now: enabled, not shown yet in this run and not a headless run.
static func is_due() -> bool:
	return enabled and not _shown and DisplayServer.get_name() != "headless"


## The studio logo, or null while the file isn't in the project.
static func load_logo() -> Texture2D:
	if not ResourceLoader.exists(logo_path):
		return null
	return load(logo_path) as Texture2D


## Shows the screen and starts counting the hold time.
func show_screen() -> void:
	_shown = true
	_active = true
	_elapsed = 0.0
	_show_logo_or_wordmark()
	_update_chips()
	visible = true
	set_process(true)


## Counts [param seconds] more as passed and moves the squares; hides the screen when the time is over.
## [code]_process[/code] calls it every frame; tests call it to skip ahead. Does nothing while hidden.
func advance(seconds: float) -> void:
	if not _active:
		return
	_elapsed += seconds
	_update_chips()
	if _elapsed >= hold_time:
		finish()


## Hides the screen at once and says so ([signal finished]). Does nothing when it isn't showing.
func finish() -> void:
	if not _active:
		return
	_active = false
	visible = false
	set_process(false)
	finished.emit()


## Scales the layout; 1.0 is the size it's designed for (a 1280 × 720 window).
func set_ui_scale(factor: float) -> void:
	UiTheme.apply(self, factor)


## Gives the logo slot the picture, or the game's name when there is none.
func _show_logo_or_wordmark() -> void:
	var texture := load_logo()
	_logo.texture = texture
	_logo.visible = texture != null
	_wordmark.visible = texture == null


## Gives every square its role: done ones TextChip, the rest LineChip.
func _update_chips() -> void:
	var chips := _chip_row.get_children()
	var count := chips.size()
	_done = count if hold_time <= 0.0 else mini(floori(_elapsed / hold_time * count), count)
	for i in count:
		(chips[i] as Panel).theme_type_variation = &"TextChip" if i < _done else &"LineChip"


# --- Test hooks ---


## True while the screen is up.
func is_showing() -> bool:
	return _active


## How many squares are done.
func get_done_chips() -> int:
	return _done


## The logo's picture slot (hidden while there is no logo file).
func get_logo() -> TextureRect:
	return _logo


## The game's name that stands in for a missing logo.
func get_wordmark() -> Label:
	return _wordmark


## The row of squares.
func get_chip_row() -> HBoxContainer:
	return _chip_row
