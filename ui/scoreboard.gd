class_name Scoreboard
extends CanvasLayer
## The hold-Tab scoreboard (action [code]scoreboard[/code]), like CS: while you
## hold the key, a panel shows the score (yours in blue at the left, theirs in
## red at the right), the mode and the map and what is left of the match
## between them ("Team Deathmatch · Depot", "First to 50 · 7:42"; "Bomb ·
## Depot", "Round 3 · 1:12"), and a [ScoreboardTable] of both teams with class
## icons, kills, deaths, assists and damage, the players who are dead muted. In a free-for-all
## (M17, D-240) the header's scores are your kills and the best other player's and the table is one
## list of everyone, best first.
## Let go and it is gone. The panel is the mockup's (D-137): 880 wide, 64 px from
## the top, ink at 88%.
##
## It is a pure view of the [RoundManager]: it never changes the game, and it
## polls instead of listening to signals, because damage (which changes the
## numbers) has no round-manager signal. It doesn't pause anything or block
## movement, and no part of it takes mouse clicks (clicks must still reach
## [PlayerController]). It shows only in a match: [method set_round_manager]
## gets the manager from [code]main.gd[/code], or null in practice mode, where
## it never appears. It stays hidden while the developer console or a menu is
## open ([MenuState]), under the [LoadingScreen] and once the match is over (the [MatchEndScreen] shows
## the final table then).
##
## It keeps running while the game is paused ([code]process_mode = Always[/code],
## D-065): a paused node's [code]_process[/code] stops, and a scoreboard that was
## up when Esc was pressed would stay on screen over the pause menu. Running, it
## sees that a menu is open and hides.
##
## Its look comes from the UI theme (D-057): the panel, the header and the
## scores use theme type variations (your score is a "FriendlyScoreLabel" and
## theirs an "EnemyScoreLabel", since you always see your team in the friendly
## colour), and [method set_ui_scale] hands the menu a theme scaled for the
## window ([UiTheme]). The words of the header come from [MatchText].

var _manager: RoundManager

@onready var _panel: PanelContainer = $Panel
@onready var _mode_label: Label = %ModeLabel
@onready var _clock_label: Label = %ClockLabel
@onready var _your_score: Label = %YourScore
@onready var _enemy_score: Label = %EnemyScore
@onready var _table: ScoreboardTable = %Table


func _ready() -> void:
	visible = false


func _process(_delta: float) -> void:
	var should_show := _should_show()
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
	UiTheme.apply(self, factor)
	_table.set_ui_scale(factor)


## True while Tab is held in a match that is under way, with the console and the menus closed.
func _should_show() -> bool:
	return is_instance_valid(_manager) \
			and _manager.round_number > 0 \
			and _manager.phase != RoundManager.Phase.MATCH_END \
			and not MenuState.blocks_gameplay() \
			and not LoadingScreen.is_showing() \
			and Input.is_action_pressed("scoreboard")


## Brings the header and the table in line with the manager.
func _refresh() -> void:
	var you := Teams.viewer_team
	_mode_label.text = MatchText.mode_line(_manager)
	_clock_label.text = MatchText.clock_line(_manager)
	if _manager.is_free_for_all():
		# Nobody has a team: your kills against the best of the others, as on the round HUD.
		var kills := MatchText.ffa_scores(_manager, Teams.viewer)
		_your_score.text = str(kills.x)
		_enemy_score.text = str(kills.y)
	else:
		_your_score.text = str(_manager.score[you])
		_enemy_score.text = str(_manager.score[Teams.other(you)])
	_table.refresh()


# --- Test hooks ---


## The panel (880 wide, 64 px from the top).
func get_panel() -> PanelContainer:
	return _panel


## The table of both teams.
func get_table() -> ScoreboardTable:
	return _table


## The header's first centred line, the mode and the map.
func get_mode_label() -> Label:
	return _mode_label


## The header's second centred line, the kill limit or the round and the time left.
func get_clock_label() -> Label:
	return _clock_label


## Your score, at the left of the header.
func get_your_score_label() -> Label:
	return _your_score


## The enemy's score, at the right of the header.
func get_enemy_score_label() -> Label:
	return _enemy_score

