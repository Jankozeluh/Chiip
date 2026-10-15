class_name RoundHud
extends Control
## The round part of the HUD, shown only in a match: a top bar (your score on
## the left in blue, the round timer in the middle, the enemy's score on the
## right in red, and one small square per player under each score, lit while
## they live), the freeze-time countdown with your side, the round-end banner,
## and the kill feed ([KillFeed], top right).
##
## It is a pure view of the [RoundManager]: it connects to its signals and
## reads its state, and never changes it (docs/ARCHITECTURE.md, "Keeping
## multiplayer possible"). Colors are relative to the viewer, [member
## Teams.viewer_team]: your team is blue, the enemy red, and teams have no names.
## [method set_round_manager] hands it the manager when a map loads, or null in
## practice mode, which hides everything. All of it ignores the mouse, so clicks
## still reach the player controls.

## The timer's color during freeze time.
const FREEZE_TIMER_COLOR := Color(1.0, 0.85, 0.4)
## The timer's color in the last [constant LOW_TIME] seconds of a round.
const LOW_TIME_COLOR := Color(1.0, 0.4, 0.3)
## Seconds left at or below which the round timer turns red.
const LOW_TIME := 10.0
## A square of a player who is dead.
const PIP_DEAD_COLOR := Color(0.22, 0.23, 0.26)
## Side of a player square (at the 720-pixel design height).
const PIP_SIZE := 12
## Background of the timer box.
const TIMER_BOX_COLOR := Color(0.06, 0.07, 0.09, 0.85)
## Opacity of a score box, and how much its team color is darkened.
const SCORE_BOX_ALPHA := 0.9
const SCORE_BOX_DARKEN := 0.55
const SWITCHING_COLOR := Color(1.0, 0.85, 0.4)
const ATTACK_TEXT := "You attack: push to the far end"
const DEFEND_TEXT := "You defend: hold your end"

var _manager: RoundManager
var _ui_scale: float = 1.0
## True from the half-time swap until the next round goes live.
var _just_swapped: bool = false
var _timer_color := Color.WHITE

@onready var _top_bar: HBoxContainer = $TopBar
@onready var _your_box: PanelContainer = $TopBar/YourBox
@onready var _your_score: Label = $TopBar/YourBox/Margin/Content/Score
@onready var _your_pips: HBoxContainer = $TopBar/YourBox/Margin/Content/Pips
@onready var _timer_box: PanelContainer = $TopBar/TimerBox
@onready var _timer: Label = $TopBar/TimerBox/Margin/Content/Timer
@onready var _round_label: Label = $TopBar/TimerBox/Margin/Content/RoundLabel
@onready var _enemy_box: PanelContainer = $TopBar/EnemyBox
@onready var _enemy_score: Label = $TopBar/EnemyBox/Margin/Content/Score
@onready var _enemy_pips: HBoxContainer = $TopBar/EnemyBox/Margin/Content/Pips
@onready var _title: Label = $Center/Title
@onready var _line1: Label = $Center/Line1
@onready var _line2: Label = $Center/Line2
@onready var _line3: Label = $Center/Line3
@onready var _kill_feed: KillFeed = $KillFeed


func _ready() -> void:
	_your_box.add_theme_stylebox_override("panel", _box_style(Color(Teams.FRIENDLY_COLOR.darkened(SCORE_BOX_DARKEN), SCORE_BOX_ALPHA)))
	_timer_box.add_theme_stylebox_override("panel", _box_style(TIMER_BOX_COLOR))
	_enemy_box.add_theme_stylebox_override("panel", _box_style(Color(Teams.ENEMY_COLOR.darkened(SCORE_BOX_DARKEN), SCORE_BOX_ALPHA)))
	_clear_messages()
	_top_bar.visible = false
	visible = false
	set_process(false)


## Shows the match run by [param manager], or hides the round HUD when it is
## null (practice mode). Call it whenever a map is loaded: it stops listening to
## the previous round manager and empties the kill feed and the messages. If the
## match is already running it shows the current state at once.
func set_round_manager(manager: RoundManager) -> void:
	if is_instance_valid(_manager):
		for pair in _manager_connections():
			var signal_to_drop: Signal = pair[0]
			if signal_to_drop.is_connected(pair[1]):
				signal_to_drop.disconnect(pair[1])
	_manager = manager
	_kill_feed.clear()
	_just_swapped = false
	_clear_messages()
	visible = manager != null
	set_process(manager != null)
	if manager == null:
		return
	for pair in _manager_connections():
		var signal_to_use: Signal = pair[0]
		signal_to_use.connect(pair[1])
	_refresh()
	_show_phase_message()


## Scales the layout; 1.0 is the size it is designed for (a 720-pixel-tall window).
func set_ui_scale(factor: float) -> void:
	_ui_scale = factor
	UiScale.apply_tree(self, factor)
	_kill_feed.set_ui_scale(factor)


## Seconds as m:ss, counting a started second as a whole one: 115.0 and 114.2
## are "1:55", 0.3 is "0:01" and only zero is "0:00" (what a countdown shows).
static func format_time(seconds: float) -> String:
	var total := maxi(0, ceili(seconds))
	@warning_ignore("integer_division")
	var minutes := total / 60
	return "%d:%02d" % [minutes, total % 60]


## How many of [param team]'s squares in the top bar are lit (players alive, as shown).
func get_alive_shown(team: int) -> int:
	var pips := _your_pips if team == Teams.viewer_team else _enemy_pips
	var lit := 0
	for pip in pips.get_children():
		if (pip as ColorRect).color != PIP_DEAD_COLOR:
			lit += 1
	return lit


func _process(_delta: float) -> void:
	# Visual state only, read from the round manager every frame; the signals
	# below handle the moments that need a message.
	if not is_instance_valid(_manager):
		return
	_refresh()
	if _manager.phase == RoundManager.Phase.FREEZE:
		_line1.text = _countdown_text()


func _manager_connections() -> Array[Array]:
	return [
		[_manager.phase_changed, _on_phase_changed],
		[_manager.round_started, _on_round_started],
		[_manager.round_ended, _on_round_ended],
		[_manager.sides_swapped, _on_sides_swapped],
		[_manager.character_killed, _on_character_killed],
	]


# --- Top bar ---


## Brings the score, player squares, round label and timer in line with the manager.
func _refresh() -> void:
	var started := _manager.round_number > 0
	_top_bar.visible = started
	if not started:
		return
	var you := Teams.viewer_team
	var them := Teams.other(you)
	_your_score.text = str(_manager.score[you])
	_enemy_score.text = str(_manager.score[them])
	_refresh_pips(_your_pips, you)
	_refresh_pips(_enemy_pips, them)
	_round_label.text = "Round %d" % _manager.round_number
	match _manager.phase:
		RoundManager.Phase.FREEZE:
			_set_timer(_manager.time_left, FREEZE_TIMER_COLOR)
		RoundManager.Phase.LIVE:
			_set_timer(_manager.time_left, LOW_TIME_COLOR if _manager.time_left <= LOW_TIME else Color.WHITE)
		# At the round end and the match end the timer keeps what it showed.


func _set_timer(seconds: float, color: Color) -> void:
	_timer.text = format_time(seconds)
	if _timer_color != color:
		_timer_color = color
		_timer.add_theme_color_override("font_color", color)


## One square per player of [param team]: lit (in the team's color) for each one alive.
func _refresh_pips(pips: HBoxContainer, team: int) -> void:
	var members := _manager.get_members(team).size()
	while pips.get_child_count() < members:
		var pip := ColorRect.new()
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pip.custom_minimum_size = Vector2(PIP_SIZE, PIP_SIZE)
		pips.add_child(pip)
		UiScale.apply_tree(pip, _ui_scale)
	while pips.get_child_count() > members:
		var extra := pips.get_child(pips.get_child_count() - 1)
		pips.remove_child(extra)
		extra.queue_free()
	var alive := _manager.get_alive_count(team)
	var lit_color := Teams.text_color_for(team)
	for i in pips.get_child_count():
		var pip := pips.get_child(i) as ColorRect
		var color := lit_color if i < alive else PIP_DEAD_COLOR
		if pip.color != color:
			pip.color = color


func _box_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	return style


# --- Messages in the middle: freeze time, round end, half time ---


func _on_phase_changed(_phase: RoundManager.Phase) -> void:
	if _manager.phase == RoundManager.Phase.LIVE:
		_just_swapped = false
	_refresh()
	_show_phase_message()


func _on_round_started(_round_number: int) -> void:
	# The feed starts empty in every round, as in CS.
	_kill_feed.clear()


func _on_sides_swapped() -> void:
	# Comes right before the next round's freeze time, which shows the notice.
	_just_swapped = true


func _on_round_ended(winner: int, reason: RoundManager.EndReason) -> void:
	var won := winner == Teams.viewer_team
	_clear_messages()
	_set_message(_title, "Round won" if won else "Round lost", Teams.text_color_for(winner))
	_set_message(_line1, _reason_text(won, reason), Color.WHITE)
	if reason == RoundManager.EndReason.TIME:
		_set_timer(0.0, Color.WHITE)


func _on_character_killed(victim: Character, killer: Character, headshot: bool) -> void:
	_kill_feed.add_kill(victim, killer, headshot)
	_refresh()


## What the center shows for the current phase: the countdown during freeze
## time, nothing otherwise (the round-end banner arrives with [signal
## RoundManager.round_ended], which comes after the phase change, and before
## round 1 starts there is nothing to show yet).
func _show_phase_message() -> void:
	_clear_messages()
	if _manager.round_number == 0 or _manager.phase != RoundManager.Phase.FREEZE:
		return
	if _just_swapped:
		_set_message(_title, "Switching sides", SWITCHING_COLOR)
	_set_message(_line1, _countdown_text(), Color.WHITE)
	var attacking := _manager.get_side(Teams.viewer_team) == Teams.Side.ATTACKING
	_set_message(_line2, ATTACK_TEXT if attacking else DEFEND_TEXT, Color.WHITE)
	_show_match_point()


## "Round 3  ·  starts in 4".
func _countdown_text() -> String:
	return "Round %d  ·  starts in %d" % [_manager.round_number, maxi(0, ceili(_manager.time_left))]


## A third line when a team is one round from winning the match.
func _show_match_point() -> void:
	var to_win := _manager.settings.rounds_to_win
	if to_win < 2:
		return
	var you := Teams.viewer_team
	var them := Teams.other(you)
	var you_on_point := _manager.score[you] == to_win - 1
	var them_on_point := _manager.score[them] == to_win - 1
	if you_on_point and them_on_point:
		_set_message(_line3, "Match point for both teams", Color.WHITE)
	elif you_on_point:
		_set_message(_line3, "Match point", Teams.text_color_for(you))
	elif them_on_point:
		_set_message(_line3, "Enemy match point", Teams.text_color_for(them))


## Why the round ended, said for your side. A time-out always goes to the defenders.
func _reason_text(won: bool, reason: RoundManager.EndReason) -> String:
	if reason == RoundManager.EndReason.ELIMINATION:
		return "Enemy team eliminated" if won else "Your team was eliminated"
	return "Time ran out: you held your end" if won else "Time ran out: the defenders held their end"


func _clear_messages() -> void:
	for label in [_title, _line1, _line2, _line3]:
		_set_message(label, "", Color.WHITE)


## Sets a message line and shows it, or hides it when the text is empty so the
## lines below close the gap.
func _set_message(label: Label, text: String, color: Color) -> void:
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.visible = not text.is_empty()
