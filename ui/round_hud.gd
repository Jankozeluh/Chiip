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
##
## A team respawn match ([RespawnMatch], D-082) is one long round: the scores
## are kills, "First to 30" replaces the round number, the freeze time says
## what wins, the timer shows "OT" in overtime, and the banner after the
## deciding kill says which team won and why. While you are dead and waiting
## to come back, "Respawning in 3" counts the seconds under the death message.
##
## The look comes from the UI theme (D-133): the scene's controls pick roles
## (type variations such as [code]HudTimerLabel[/code] and [code]HudFriendlyBox[/code])
## for sizes, outlines, boxes and spacing, and the colours of game states (the
## timer in freeze time and in the last seconds, a notice, a dead player's
## square) and the size of a player's square are read from the theme's custom
## type "Hud". Nothing here is a colour or a size of its own.

## Seconds left at or below which the round timer turns red.
const LOW_TIME := 10.0
## The theme type that holds the HUD's state colours and sizes (see tools/make_ui_theme.gd).
const THEME_TYPE := &"Hud"
const ATTACK_TEXT := "You attack: push to the far end"
const DEFEND_TEXT := "You defend: hold your end"
## The side lines in bomb rounds; %s is the sites, e.g. "A or B".
const ATTACK_BOMB_TEXT := "You attack: plant the bomb at %s"
const DEFEND_BOMB_TEXT := "You defend: guard %s"
## What the timer shows once the bomb is planted (the round clock has stopped; as in CS, the fuse isn't shown).
const BOMB_TIMER_TEXT := "BOMB"
## What the timer shows in a team respawn match's overtime.
const OVERTIME_TIMER_TEXT := "OT"
## What the countdown under the death message says; %d is the seconds left.
const RESPAWN_TEXT := "Respawning in %d"

var _manager: RoundManager
var _ui_scale: float = 1.0
## True from the half-time swap until the next round goes live.
var _just_swapped: bool = false
## The theme colour the timer shows now ("freeze_timer", "alert"), or "" for its usual one.
var _timer_state: StringName = &""
## A dead player's square, from the theme (read once; the theme doesn't change while playing).
var _pip_dead: Color
## The player at this computer, found among the manager's participants (null until then).
var _player: Character

@onready var _top_bar: HBoxContainer = $TopBar
@onready var _your_score: Label = $TopBar/YourBox/Margin/Content/Score
@onready var _your_pips: HBoxContainer = $TopBar/YourBox/Margin/Content/Pips
@onready var _timer: Label = $TopBar/TimerBox/Margin/Content/Timer
@onready var _round_label: Label = $TopBar/TimerBox/Margin/Content/RoundLabel
@onready var _enemy_score: Label = $TopBar/EnemyBox/Margin/Content/Score
@onready var _enemy_pips: HBoxContainer = $TopBar/EnemyBox/Margin/Content/Pips
@onready var _title: Label = $Center/Title
@onready var _line1: Label = $Center/Line1
@onready var _line2: Label = $Center/Line2
@onready var _line3: Label = $Center/Line3
@onready var _respawn: Label = $Respawn
@onready var _kill_feed: KillFeed = $KillFeed


func _ready() -> void:
	_pip_dead = _theme_color(&"pip_dead")
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
	_player = null
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
		if (pip as ColorRect).color != _pip_dead:
			lit += 1
	return lit


## The text of the respawn countdown, or "" while it is hidden. For tests.
func get_respawn_text() -> String:
	return _respawn.text if _respawn.visible else ""


func _process(_delta: float) -> void:
	# Visual state only, read from the round manager every frame; the signals
	# below handle the moments that need a message.
	if not is_instance_valid(_manager):
		return
	_refresh()
	if _manager.phase == RoundManager.Phase.FREEZE:
		_line1.text = _countdown_text()
	_refresh_respawn()


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
	_round_label.text = _round_text()
	match _manager.phase:
		RoundManager.Phase.FREEZE:
			_set_timer(_manager.time_left, &"freeze_timer")
		RoundManager.Phase.LIVE:
			if _is_overtime():
				_set_timer_text(OVERTIME_TIMER_TEXT, &"alert")
				_show_overtime()
			elif _manager.is_bomb_planted():
				_set_timer_text(BOMB_TIMER_TEXT, &"alert")
			else:
				_set_timer(_manager.time_left, &"alert" if _manager.time_left <= LOW_TIME else &"")
		# At the round end and the match end the timer keeps what it showed.


## Shows [param seconds] on the timer, in the theme colour named [param state] ("" for the usual one).
func _set_timer(seconds: float, state: StringName) -> void:
	_set_timer_text(format_time(seconds), state)


func _set_timer_text(text: String, state: StringName) -> void:
	_timer.text = text
	if _timer_state == state:
		return
	_timer_state = state
	if state.is_empty():
		_timer.remove_theme_color_override("font_color")
	else:
		_timer.add_theme_color_override("font_color", _theme_color(state))


## One square per player of [param team]: lit (in the team's color) for each one alive.
func _refresh_pips(pips: HBoxContainer, team: int) -> void:
	var members := _manager.get_members(team).size()
	while pips.get_child_count() < members:
		var pip := ColorRect.new()
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var pip_size := get_theme_constant(&"pip_size", THEME_TYPE)
		pip.custom_minimum_size = Vector2(pip_size, pip_size)
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
		var color := lit_color if i < alive else _pip_dead
		if pip.color != color:
			pip.color = color


## A colour of the HUD's theme type (game states; see [constant THEME_TYPE]).
func _theme_color(color_name: StringName) -> Color:
	return get_theme_color(color_name, THEME_TYPE)


# --- Messages in the middle: freeze time, round end, half time ---


func _on_phase_changed(_phase: RoundManager.Phase) -> void:
	if _manager.phase == RoundManager.Phase.LIVE:
		_just_swapped = false
		UiSounds.play(UiSounds.ROUND_START)
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
	UiSounds.play(UiSounds.ROUND_WON if won else UiSounds.ROUND_LOST)
	_clear_messages()
	if _manager.is_team_respawn():
		_set_tinted_message(_title, "Your team wins" if won else "The enemy team wins", Teams.text_color_for(winner))
		_set_message(_line1, _reason_text(won, reason))
		return
	_set_tinted_message(_title, "Round won" if won else "Round lost", Teams.text_color_for(winner))
	_set_message(_line1, _reason_text(won, reason))
	if reason == RoundManager.EndReason.TIME:
		_set_timer(0.0, &"")


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
	if _manager.is_team_respawn():
		_set_message(_line1, _countdown_text())
		_set_message(_line2, "First team to %d kills wins" % _manager.settings.kill_limit)
		return
	if _just_swapped:
		_set_tinted_message(_title, "Switching sides", _theme_color(&"notice"))
	_set_message(_line1, _countdown_text())
	var attacking := _manager.get_side(Teams.viewer_team) == Teams.Side.ATTACKING
	_set_message(_line2, _side_text(attacking))
	_show_match_point()


## "Round 3  ·  starts in 4" ("Team respawn  ·  starts in 4").
func _countdown_text() -> String:
	var what := "Team respawn" if _manager.is_team_respawn() else "Round %d" % _manager.round_number
	return "%s  ·  starts in %d" % [what, maxi(0, ceili(_manager.time_left))]


## Under the timer: the round number, or what wins a team respawn match.
func _round_text() -> String:
	if not _manager.is_team_respawn():
		return "Round %d" % _manager.round_number
	return "Next kill wins" if _is_overtime() else "First to %d" % _manager.settings.kill_limit


func _is_overtime() -> bool:
	var respawn := _manager as RespawnMatch
	return respawn != null and respawn.overtime


## The overtime notice in the middle, for as long as overtime lasts.
func _show_overtime() -> void:
	if _title.text != "Overtime":
		_set_tinted_message(_title, "Overtime", _theme_color(&"notice"))
		_set_message(_line1, "Next kill wins")


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
		_set_message(_line3, "Match point for both teams")
	elif you_on_point:
		_set_tinted_message(_line3, "Match point", Teams.text_color_for(you))
	elif them_on_point:
		_set_tinted_message(_line3, "Enemy match point", Teams.text_color_for(them))


## What your side has to do this half: push or hold, or in bomb rounds plant or guard the sites.
func _side_text(attacking: bool) -> String:
	if _manager.bomb == null:
		return ATTACK_TEXT if attacking else DEFEND_TEXT
	var letters: Array[String] = []
	for site in _manager.bomb.get_sites():
		letters.append(Bomb.site_letter(site))
	letters.sort()
	if attacking:
		return ATTACK_BOMB_TEXT % " or ".join(letters)
	return DEFEND_BOMB_TEXT % " and ".join(letters)


## Why the round ended, said for your side. A time-out always goes to the defenders.
func _reason_text(won: bool, reason: RoundManager.EndReason) -> String:
	match reason:
		RoundManager.EndReason.ELIMINATION:
			return "Enemy team eliminated" if won else "Your team was eliminated"
		RoundManager.EndReason.BOMB_EXPLODED:
			return "The bomb exploded"
		RoundManager.EndReason.BOMB_DEFUSED:
			return "The bomb was defused"
		RoundManager.EndReason.KILL_LIMIT:
			return "First to %d kills" % _manager.settings.kill_limit
		RoundManager.EndReason.TIME_LIMIT:
			return "Most kills when time ran out"
	return "Time ran out: you held your end" if won else "Time ran out: the defenders held their end"


func _clear_messages() -> void:
	for label in [_title, _line1, _line2, _line3]:
		_set_message(label, "")
	_respawn.visible = false


## Sets a message line in its role's usual colour and shows it, or hides it when
## the text is empty so the lines below close the gap.
func _set_message(label: Label, text: String) -> void:
	label.text = text
	label.remove_theme_color_override("font_color")
	label.visible = not text.is_empty()


## Like [method _set_message], in [param color] (a team's colour or a theme colour).
func _set_tinted_message(label: Label, text: String, color: Color) -> void:
	_set_message(label, text)
	label.add_theme_color_override("font_color", color)


# --- The respawn countdown ---


## Shows "Respawning in 3" while the local player is dead in a live team respawn
## match and waiting to come back; hides it otherwise (also in rounds, practice,
## the round end and the match end). The seconds come from the manager every
## frame and are rounded up, so the last second says 1 and never 0.
func _refresh_respawn() -> void:
	var left := _respawn_time_left()
	_respawn.visible = left > 0.0
	if _respawn.visible:
		_respawn.text = RESPAWN_TEXT % ceili(left)


## Seconds until the local player comes back, or -1 when they aren't waiting to.
func _respawn_time_left() -> float:
	var respawn_match := _manager as RespawnMatch
	if respawn_match == null or _manager.phase != RoundManager.Phase.LIVE:
		return -1.0
	if not is_instance_valid(_player):
		_player = _find_player()
	if _player == null or _player.is_alive():
		return -1.0
	return respawn_match.get_respawn_time_left(_player)


## The character of the player at this computer among the match's participants, or null.
func _find_player() -> Character:
	for character in _manager.get_participants():
		if character.is_local_player():
			return character
	return null
