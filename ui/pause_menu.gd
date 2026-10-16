class_name PauseMenu
extends CanvasLayer
## The pause menu (M5 task 12, D-065): Esc pauses the game, and this panel
## offers Resume, Settings and Leave match (it reads "Leave practice" in the
## bot arena).
##
## **It pauses the whole game.** [method open] sets [member SceneTree.paused],
## so every node in the tree that has the default process mode (the map, the
## characters and bots, the [RoundManager] and its timer, weapons, tweens, the
## HUD and kill feed, footstep and gun sounds) stops until [method close] sets it
## back. The nodes that must keep running while the game is paused have
## [code]process_mode = Always[/code] in their scenes: this menu, the
## [SettingsMenu] it opens, the [DevConsole] and the hold-Tab [Scoreboard] (which
## has to see that a menu is open to hide itself). That is single-player only:
## in multiplayer (M9) nobody can stop the other players, so this becomes an
## overlay that doesn't pause (D-065).
##
## Esc is handled here, not by the player controller: with nothing else open it
## opens the menu, and with the menu on top it resumes. Every other case belongs
## to someone else because input reaches the nodes at the end of the tree first
## (see "Menus and the mouse" in docs/ARCHITECTURE.md): the console and the
## settings menu come later in [code]main.tscn[/code] and take Esc when they are
## open, and the match-end screen comes later too and swallows it. The menu
## registers with [MenuState] while it is open, so the player's controls
## ignore the keyboard and mouse and the mouse is shown, and closing it gives
## the mouse back.
##
## **Online (M9, D-109) it doesn't pause** ([method set_online]): nobody can stop the other
## players' game. It is an overlay then: it still registers with [MenuState], so your character
## stands still and doesn't shoot while it is open, and the mouse is free; the game goes on.
##
## It only reports button clicks: [code]main.gd[/code] opens the settings menu
## on [signal settings_pressed] and leaves for the main menu on
## [signal leave_pressed]. Its look is the mockup's (D-137): the game dimmed by
## a [code]BackdropPanel[/code] and, on it, a centred column with the title
## "Paused" and three menu items 352 px wide. The item that has the focus or the
## mouse is filled with the accent and shows the chip, a small ink square, next
## to its text, the two centred together as in the mockup. (A button draws its
## icon at its left edge, so the item's own icon is only an invisible spacer that
## moves the text over, and this script puts the [code]Chip[/code] panel beside
## the text.) Its look comes from the UI theme (D-057): no colors, sizes or
## styleboxes of its own, and [method set_ui_scale] gives it the theme scaled for
## the window like the other menus.

## Emitted when the player presses Settings. The menu hides itself, so the
## settings menu has the screen to itself; main.gd opens that menu, and calls
## [method settings_closed] when it closes.
signal settings_pressed
## Emitted when the player presses the leave button (it does not unpause: the
## owner leaves the scene, see [code]Main.return_to_menu()[/code]).
signal leave_pressed
## Emitted when the player presses "Report a bug" (M16, D-224): main.gd packs the report
## ([BugReport]) and calls [method show_bug_report_result].
signal bug_report_pressed

## The footer button's text before a report is made.
const BUG_REPORT_TEXT := "Report a bug"

## Online (M9): the menu is an overlay and never pauses the game. main.gd sets it on every map load.
var online: bool = false

@onready var _column: VBoxContainer = $Column
@onready var _background: Panel = $Background
@onready var _title: Label = %Title
@onready var _resume_button: Button = %ResumeButton
@onready var _settings_button: Button = %SettingsButton
@onready var _leave_button: Button = %LeaveButton
@onready var _online_note: Label = %OnlineNote
@onready var _build_label: Label = %Build
@onready var _bug_report_button: Button = %BugReportButton
## The menu items that the mouse is over (Button → true). The button's own
## hover state isn't updated yet when it emits [signal Control.mouse_entered].
var _hovered: Dictionary = {}


func _ready() -> void:
	visible = false
	_resume_button.pressed.connect(close)
	_settings_button.pressed.connect(_on_settings_pressed)
	_leave_button.pressed.connect(leave_pressed.emit)
	_bug_report_button.pressed.connect(bug_report_pressed.emit)
	# The footer (M16): the build, as in the main menu, and "Report a bug".
	_build_label.text = "Build %s" % BuildInfo.describe()
	for item in _items():
		item.focus_entered.connect(_update_chip.bind(item))
		item.focus_exited.connect(_update_chip.bind(item))
		item.mouse_entered.connect(_set_hovered.bind(item, true))
		item.mouse_exited.connect(_set_hovered.bind(item, false))
		item.resized.connect(_update_chip.bind(item))
	_refresh_chips()


func _exit_tree() -> void:
	# Freed or removed while open (the game scene changes under it): don't leave
	# the next scene paused, or the game waiting for a menu.
	if MenuState.is_open(self) and not online:
		get_tree().paused = false
	MenuState.close(self)


func _input(event: InputEvent) -> void:
	if not event.is_action_pressed("pause") or MenuState.capturing_input:
		return
	# Esc ends an aim trainer run instead of pausing (v0.2, D-236: "Esc stop").
	if not is_open() and TrainingHub.is_running() and not MenuState.blocks_gameplay():
		TrainingHub.stop_run()
		get_viewport().set_input_as_handled()
		return
	if is_open():
		# Only the menu on top resumes (the settings menu and the console, which
		# take Esc before this node does, are over it when they are open).
		if MenuState.is_top(self):
			close()
			get_viewport().set_input_as_handled()
	elif can_open():
		open()
		get_viewport().set_input_as_handled()


## Pauses the game and shows the menu with the mouse, with Resume focused.
## Does nothing when it is already open.
func open() -> void:
	if is_open():
		return
	visible = true
	_bug_report_button.text = BUG_REPORT_TEXT
	MenuState.open(self)
	if not online:
		get_tree().paused = true
	_resume_button.grab_focus()


## Hides the menu, hands the mouse back (if it was the last menu open) and
## resumes the game. Does nothing when it isn't open. The Resume button and Esc
## do this.
func close() -> void:
	if not is_open():
		return
	visible = false
	MenuState.close(self)
	if not online:
		get_tree().paused = false


## Online (M9): [param on] makes the menu an overlay that doesn't pause the game (offline it
## pauses). The title says "Menu" instead of "Paused" then, and the mockup's line "Online ·
## the match keeps running" shows under the items ([method set_online_note_visible]).
func set_online(on: bool) -> void:
	if is_open():
		close()
	online = on
	_title.text = "Menu" if on else "Paused"
	set_online_note_visible(on)


## True while the game is paused by this menu (also while the settings menu is
## over it and this panel is hidden).
func is_open() -> bool:
	return MenuState.is_open(self)


## True when Esc may open the menu: it is closed and no other menu or the
## console is open.
func can_open() -> bool:
	return not is_open() and not MenuState.blocks_gameplay()


## Brings the column back after the settings menu it opened has closed, with the
## Settings button focused. Does nothing when this menu isn't open any more.
func settings_closed() -> void:
	if not is_open():
		return
	visible = true
	_settings_button.grab_focus()


## Sets the text of the leave button: "Leave match" in a match, "Leave practice"
## in the bot arena. main.gd sets it whenever a map is loaded.
func set_leave_text(text: String) -> void:
	_leave_button.text = text
	_update_chip(_leave_button)


## Shows or hides the mockup's line under the items, "Online · the match keeps
## running". It is hidden: in single player the pause really stops the match.
## [method set_online] (M9) turns it on, since the match goes on there (D-065).
func set_online_note_visible(shown: bool) -> void:
	_online_note.visible = shown


## Says on the footer button whether the report was saved ([param saved]): "Report saved · folder
## opened" or "Couldn't save the report". Back to "Report a bug" when the menu opens again.
func show_bug_report_result(saved: bool) -> void:
	_bug_report_button.text = "Report saved · folder opened" if saved else "Couldn't save the report"


## Scales the layout; 1.0 is the size it's designed for (a 720-pixel-tall window).
## Gives the menu the theme scaled for the window ([UiTheme]), and the chip the
## size the theme now has.
func set_ui_scale(factor: float) -> void:
	UiTheme.apply(self, factor)
	_refresh_chips()


func _on_settings_pressed() -> void:
	# The settings menu is a big page with a dim background of its own; showing
	# this one under it would dim the game twice. It stays open (and the game
	# paused): settings_closed() shows it again.
	visible = false
	settings_pressed.emit()


## The three menu items, top to bottom.
func _items() -> Array[Button]:
	return [_resume_button, _settings_button, _leave_button]


func _set_hovered(item: Button, hovered: bool) -> void:
	_hovered[item] = hovered
	_update_chip(item)


## While the item has the focus or the mouse its chip shows beside the text and
## the text moves over to make room: the item's icon (the theme's chip at the
## scale of the theme, invisible) is set, which shifts the text by half of the icon
## and the gap, and the chip panel goes to the left of the text, so that chip,
## gap and text are centred as one group. A resting item has no icon and no chip,
## and its text is centred on its own.
func _update_chip(item: Button) -> void:
	var chip := item.get_node_or_null("Chip") as Control
	if chip == null:
		return
	var lit: bool = item.has_focus() or _hovered.get(item, false)
	item.icon = UiIcons.get_icon(item, UiIcons.CHIP) if lit else null
	chip.visible = lit
	if not lit:
		return
	var font := item.get_theme_font("font")
	var text_width := font.get_string_size(item.text, HORIZONTAL_ALIGNMENT_LEFT, -1, item.get_theme_font_size("font_size")).x
	var chip_size := chip.get_combined_minimum_size()
	var group_width := chip_size.x + item.get_theme_constant("h_separation") + text_width
	chip.position = Vector2(roundf((item.size.x - group_width) / 2.0), roundf((item.size.y - chip_size.y) / 2.0))


func _refresh_chips() -> void:
	for item in _items():
		_update_chip(item)


# --- Test hooks ---


## The Resume button.
func get_resume_button() -> Button:
	return _resume_button


## The Settings button.
func get_settings_button() -> Button:
	return _settings_button


## The leave button ("Leave match" or "Leave practice").
func get_leave_button() -> Button:
	return _leave_button


## The centred column with the title, the three items and the online line.
func get_column() -> VBoxContainer:
	return _column


## The title, "Paused".
func get_title() -> Label:
	return _title


## The line "Online · the match keeps running" (hidden in single player).
func get_online_note() -> Label:
	return _online_note


## The footer's "Report a bug" button (M16).
func get_bug_report_button() -> Button:
	return _bug_report_button


## The footer's build line, "Build 0.1.1 (26776e1)" (M16).
func get_build_label() -> Label:
	return _build_label


## The full-screen dimmed background that keeps clicks from reaching the game.
func get_background() -> Panel:
	return _background
