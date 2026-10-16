class_name MatchEndScreen
extends CanvasLayer
## The screen shown when a match is over, as the mockup draws it (D-137, "16
## Match end"): a full ink page with "Victory" or "Defeat" in 96 px, the final
## score on either side of the mode and the map ("50  Team Deathmatch · Depot
## 43"), the final table of both teams (a compact [ScoreboardTable], nobody
## muted) and, at the bottom, "Play again", "Next map · Square" when the maps are
## played in rotation (D-087) and "Main menu". Hidden until the [RoundManager]
## emits [signal RoundManager.match_ended].
##
## It only shows state and reports button clicks; [code]main.gd[/code] reacts to
## [signal play_again_pressed] and [signal main_menu_pressed]. Teams have no names:
## your team (from [member Teams.viewer_team]) is blue and listed first, the
## enemy team red. Its look comes from the UI theme (D-057): the page, title,
## scores and buttons use theme type variations. The result picks "VictoryLabel"
## or "DefeatLabel" by name (your team's colour or the enemy's), and the two scores
## are a "FriendlyLargeLabel" and an "EnemyLargeLabel" in the scene.

## Emitted when the player clicks "Play again".
signal play_again_pressed
## Emitted when the player clicks "Main menu".
signal main_menu_pressed
## Emitted when the player clicks "Next map" (only shown in a map rotation).
signal next_map_pressed

var _manager: RoundManager

@onready var _title: Label = %Result
@onready var _your_score: Label = %YourScore
@onready var _mode_label: Label = %ModeLabel
@onready var _enemy_score: Label = %EnemyScore
@onready var _table: ScoreboardTable = %Table
@onready var _play_again: Button = %PlayAgain
@onready var _main_menu: Button = %MainMenu
@onready var _next_map: Button = %NextMap


func _ready() -> void:
	visible = false
	_next_map.visible = false
	_play_again.pressed.connect(play_again_pressed.emit)
	_main_menu.pressed.connect(main_menu_pressed.emit)
	_next_map.pressed.connect(next_map_pressed.emit)
	_refresh_chip()


## Offers "Next map · <title>" after the match, or no such button with an empty
## [param title] (no rotation). main.gd calls it whenever a map is loaded.
func set_next_map(title: String) -> void:
	_next_map.text = "Next map · %s" % title
	_next_map.visible = not title.is_empty()


# --- Test hooks ---


## The "Next map" button (hidden without a rotation).
func get_next_map_button() -> Button:
	return _next_map


## The "Play again" button, the filled one with the chip.
func get_play_again_button() -> Button:
	return _play_again


## The "Main menu" button.
func get_main_menu_button() -> Button:
	return _main_menu


## The result, "Victory" or "Defeat".
func get_result_label() -> Label:
	return _title


## The final score of your team (32 px, in its colour).
func get_your_score_label() -> Label:
	return _your_score


## The final score of the enemy team.
func get_enemy_score_label() -> Label:
	return _enemy_score


## The mode and the map between the scores, "Team Deathmatch · Depot".
func get_mode_label() -> Label:
	return _mode_label


## The final table.
func get_table() -> ScoreboardTable:
	return _table


func _input(event: InputEvent) -> void:
	# Esc would open the pause menu (it comes before this screen in main.tscn, and
	# later nodes see input first, so this screen swallows Esc): the match is over,
	# there is nothing to pause.
	if visible and event.is_action_pressed("pause"):
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
	_refresh_chip()


## Puts the theme's chip (at the scale of the theme now) on the filled button.
func _refresh_chip() -> void:
	_play_again.icon = UiIcons.get_icon(_play_again, UiIcons.CHIP)


func _on_match_ended(winner: int) -> void:
	var you := Teams.viewer_team
	var them := Teams.other(you)
	var won := winner == you
	_title.text = "Victory" if won else "Defeat"
	_title.theme_type_variation = &"VictoryLabel" if won else &"DefeatLabel"
	_your_score.text = str(_manager.score[you])
	_mode_label.text = MatchText.mode_line(_manager)
	_enemy_score.text = str(_manager.score[them])
	# Final numbers: the table doesn't dim the players who died in the last round.
	_table.show_match(_manager)
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# In a rotation the next map is what you'd usually want.
	(_next_map if _next_map.visible else _play_again).grab_focus()

