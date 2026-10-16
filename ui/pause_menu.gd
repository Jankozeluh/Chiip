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
## It only reports button clicks: [code]main.gd[/code] opens the settings menu
## on [signal settings_pressed] and leaves for the main menu on
## [signal leave_pressed]. Its look comes from the UI theme (D-057): no colors,
## sizes or styleboxes of its own, and [method set_ui_scale] gives it the theme
## scaled for the window like the other menus.

## Emitted when the player presses Settings. The menu hides itself, so the
## settings menu has the screen to itself; main.gd opens that menu, and calls
## [method settings_closed] when it closes.
signal settings_pressed
## Emitted when the player presses the leave button (it does not unpause: the
## owner leaves the scene, see [code]Main.return_to_menu()[/code]).
signal leave_pressed

@onready var _panel: PanelContainer = $Panel
@onready var _background: Panel = $Background
@onready var _resume_button: Button = %ResumeButton
@onready var _settings_button: Button = %SettingsButton
@onready var _leave_button: Button = %LeaveButton


func _ready() -> void:
	visible = false
	_resume_button.pressed.connect(close)
	_settings_button.pressed.connect(_on_settings_pressed)
	_leave_button.pressed.connect(leave_pressed.emit)


func _exit_tree() -> void:
	# Freed or removed while open (the game scene changes under it): don't leave
	# the next scene paused, or the game waiting for a menu.
	if MenuState.is_open(self):
		get_tree().paused = false
	MenuState.close(self)


func _input(event: InputEvent) -> void:
	if not event.is_action_pressed("pause") or MenuState.capturing_input:
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
	_panel.visible = true
	MenuState.open(self)
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
	get_tree().paused = false


## True while the game is paused by this menu (also while the settings menu is
## over it and this panel is hidden).
func is_open() -> bool:
	return MenuState.is_open(self)


## True when Esc may open the menu: it is closed and no other menu or the
## console is open.
func can_open() -> bool:
	return not is_open() and not MenuState.blocks_gameplay()


## Brings the panel back after the settings menu it opened has closed, with the
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


## Scales the layout; 1.0 is the size it's designed for (a 720-pixel-tall window).
## Gives the menu the theme scaled for the window ([UiTheme]).
func set_ui_scale(factor: float) -> void:
	UiTheme.apply(self, factor)


func _on_settings_pressed() -> void:
	# The settings menu is a big panel with a dim background of its own; showing
	# this one under it would dim the game twice. It stays open (and the game
	# paused): settings_closed() shows it again.
	visible = false
	settings_pressed.emit()


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


## The panel with the title and the buttons.
func get_panel() -> PanelContainer:
	return _panel


## The full-screen dimmed background that keeps clicks from reaching the game.
func get_background() -> Panel:
	return _background
