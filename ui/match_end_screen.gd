class_name MatchEndScreen
extends CanvasLayer
## The screen shown when a match is over: "Victory" or "Defeat" for your team,
## the final score and a scoreboard of both teams (a [ScoreboardTable]), with
## "Play again" and "Main menu" buttons. Hidden until the [RoundManager] emits
## [signal RoundManager.match_ended].
##
## It only shows state and reports button clicks; [code]main.gd[/code] reacts to
## [signal play_again_pressed] and [signal main_menu_pressed]. Teams have no names:
## your team (from [member Teams.viewer_team]) is blue and listed first, the
## enemy team red. Its look comes from the UI theme (D-057): the panel, title,
## scores and buttons use theme type variations.

## Emitted when the player clicks "Play again".
signal play_again_pressed
## Emitted when the player clicks "Main menu".
signal main_menu_pressed

var _manager: RoundManager

@onready var _title: Label = $Panel/Margin/Content/Title
@onready var _your_score: Label = $Panel/Margin/Content/Score/YourScore
@onready var _dash: Label = $Panel/Margin/Content/Score/Dash
@onready var _enemy_score: Label = $Panel/Margin/Content/Score/EnemyScore
@onready var _table: ScoreboardTable = $Panel/Margin/Content/Table
@onready var _play_again: Button = $Panel/Margin/Content/Buttons/PlayAgain
@onready var _main_menu: Button = $Panel/Margin/Content/Buttons/MainMenu


func _ready() -> void:
	visible = false
	_play_again.pressed.connect(play_again_pressed.emit)
	_main_menu.pressed.connect(main_menu_pressed.emit)


func _input(event: InputEvent) -> void:
	# Esc would hand the mouse back to the player controls; the buttons need it free.
	if visible and event.is_action_pressed("toggle_mouse"):
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	# Closing the developer console captures the mouse again.
	if visible and Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


## Shows the end of the match played by [param manager]. Call it whenever a map
## is loaded, with null when the map has no match: it hides the screen and stops
## listening to the previous round manager.
func set_round_manager(manager: RoundManager) -> void:
	visible = false
	_table.show_match(null)
	if is_instance_valid(_manager) and _manager.match_ended.is_connected(_on_match_ended):
		_manager.match_ended.disconnect(_on_match_ended)
	_manager = manager
	if _manager != null:
		_manager.match_ended.connect(_on_match_ended)


## Scales the layout; 1.0 is the size it's designed for (a 720-pixel-tall window).
## Gives the screen the theme scaled for the window ([UiTheme]); the table is
## handed the factor too, because its rows come and go and it scales those itself.
func set_ui_scale(factor: float) -> void:
	UiTheme.apply(self, factor)
	_table.set_ui_scale(factor)


func _on_match_ended(winner: int) -> void:
	var you := Teams.viewer_team
	var them := Teams.other(you)
	var won := winner == you
	_title.text = "Victory" if won else "Defeat"
	_title.add_theme_color_override("font_color", _text_color(you if won else them))
	_your_score.text = str(_manager.score[you])
	_your_score.add_theme_color_override("font_color", _text_color(you))
	_dash.text = "-"
	_enemy_score.text = str(_manager.score[them])
	_enemy_score.add_theme_color_override("font_color", _text_color(them))
	# Final numbers: the table doesn't dim the players who died in the last round.
	_table.show_match(_manager)
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_play_again.grab_focus()


## Text in a team's color, lightened so it stays readable on the dark panel.
func _text_color(team: int) -> Color:
	return Teams.color_for(team).lightened(0.35)
