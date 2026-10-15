class_name Scoreboard
extends CanvasLayer
## The hold-Tab scoreboard (action [code]scoreboard[/code]), like CS: while you
## hold the key, a panel shows the round number, the score (yours in blue,
## theirs in red) and a [ScoreboardTable] of both teams with kills, deaths,
## assists and damage, the players who are dead dimmed. Let go and it is gone.
##
## It is a pure view of the [RoundManager]: it never changes the game, and it
## polls instead of listening to signals, because damage (which changes the
## numbers) has no round-manager signal. It doesn't pause anything or block
## movement, and no part of it takes mouse clicks (clicks must still reach
## [PlayerController]). It shows only in a match: [method set_round_manager]
## gets the manager from [code]main.gd[/code], or null in practice mode, where
## it never appears. It stays hidden while the developer console is open and
## once the match is over (the [MatchEndScreen] shows the final table then).

var _manager: RoundManager
var _ui_scale: float = 1.0

@onready var _round_label: Label = $Center/Panel/Margin/Content/RoundLabel
@onready var _your_score: Label = $Center/Panel/Margin/Content/Score/YourScore
@onready var _enemy_score: Label = $Center/Panel/Margin/Content/Score/EnemyScore
@onready var _table: ScoreboardTable = $Center/Panel/Margin/Content/Table


func _ready() -> void:
	visible = false


func _process(_delta: float) -> void:
	var should_show := _should_show()
	if should_show and not visible:
		_apply_team_colors()
	visible = should_show
	if should_show:
		_refresh()


## Shows the scoreboard of the match run by [param manager], or nothing when it
## is null (practice mode). Call it whenever a map is loaded: the previous
## manager is simply replaced (there are no connections to drop) and the panel
## hides until Tab is held again.
func set_round_manager(manager: RoundManager) -> void:
	_manager = manager
	visible = false
	_table.show_match(manager)


## Scales the layout; 1.0 is the size it is designed for (a 720-pixel-tall window).
func set_ui_scale(factor: float) -> void:
	_ui_scale = factor
	UiScale.apply_tree(self, factor)
	_table.set_ui_scale(factor)


## True while Tab is held in a match that is under way, with the console closed.
func _should_show() -> bool:
	return is_instance_valid(_manager) \
			and _manager.round_number > 0 \
			and _manager.phase != RoundManager.Phase.MATCH_END \
			and not DevConsole.is_open \
			and Input.is_action_pressed("scoreboard")


## Brings the header and the table in line with the manager.
func _refresh() -> void:
	var you := Teams.viewer_team
	_round_label.text = "Round %d" % _manager.round_number
	_your_score.text = str(_manager.score[you])
	_enemy_score.text = str(_manager.score[Teams.other(you)])
	_table.refresh()


## Colors the two scores by team (yours blue, theirs red). Done when the panel
## appears, not every frame: changing a theme override makes the control redo its style.
func _apply_team_colors() -> void:
	var you := Teams.viewer_team
	_your_score.add_theme_color_override("font_color", Teams.text_color_for(you))
	_enemy_score.add_theme_color_override("font_color", Teams.text_color_for(Teams.other(you)))
