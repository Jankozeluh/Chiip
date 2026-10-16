class_name RoundHud
extends Control
## The round part of the HUD, shown only in a match (mockups 09, 11, 12 and 13): a top bar, the
## freeze-time countdown with your side, the round-end banner, and the kill feed ([KillFeed], top right).
##
## The top bar comes in two kinds. A team respawn match ([RespawnMatch], D-082), Team Deathmatch,
## shows your kills in the team's colour on the left and the enemy's on the right, each with a bar
## under it that fills toward the clock as the team nears the kill limit, and the time with "First to
## 50" in the middle. A rounds match shows one chip per player of each team (filled while they live,
## a frame when dead), the score of each team and, in the middle, the time over the round number;
## once the bomb is planted an alert plate says "Bomb" in place of the time.
##
## It is a pure view of the [RoundManager]: it connects to its signals and
## reads its state, and never changes it (docs/ARCHITECTURE.md, "Keeping
## multiplayer possible"). Colors are relative to the viewer, [member
## Teams.viewer_team]: your team is blue, the enemy red, and teams have no names.
## [method set_round_manager] hands it the manager when a map loads, or null in
## practice mode, which hides everything. All of it ignores the mouse, so clicks
## still reach the player controls.
##
## The banners in the middle are one 48 px headline (the countdown in freeze time, the result at the
## round end, "Overtime") and a 16 px line under it (your side, why the round ended). What is only news
## ("Switching sides", "Match point", "Enemy match point", a teammate bot's "Enemy spotted near A") is a toast ([ToastStack], handed over with
## [method set_toasts]). The respawn countdown of a team respawn match is part of the death view
## ([code]hud.gd[/code]).
##
## The look comes from the UI theme (D-133): the scene's controls pick roles (type variations
## such as [code]HudFriendlyScoreLabel[/code] and [code]HudScoreBarBack[/code]) for sizes, shadows,
## boxes and spacing, the sizes of the drawn parts (a chip, a bar, a column) are read from the
## theme's custom type "Hud" when it starts, and the colours of game states (the timer in the last
## seconds, a notice) from the same type. A team's colour is the palette's UI colour for it
## ("friendly_text", "enemy_text"). Nothing here is a colour or a size of its own.

## Seconds left at or below which the round timer turns to the alert colour.
const LOW_TIME := 10.0
## The theme type that holds the HUD's state colours and sizes (see tools/make_ui_theme.gd).
const THEME_TYPE := &"Hud"
## The theme type that holds the palette's named colours.
const PALETTE_TYPE := &"Palette"
## The toasts' texts.
const SWITCHING_TEXT := "Switching sides"
const MATCH_POINT_TEXT := "Match point"
const ENEMY_MATCH_POINT_TEXT := "Enemy match point"
const MATCH_POINT_BOTH_TEXT := "Match point for both teams"
const ATTACK_TEXT := "You attack: push to the far end"
const DEFEND_TEXT := "You defend: hold your end"
## The side lines in bomb rounds; %s is the sites, e.g. "A or B".
const ATTACK_BOMB_TEXT := "You attack: plant the bomb at %s"
const DEFEND_BOMB_TEXT := "You defend: guard %s"
## What the timer shows once the bomb is planted (the alert plate's word; the round clock has stopped, and as in CS the fuse isn't shown).
const BOMB_TIMER_TEXT := "Bomb"
## What the timer shows in a team respawn match's overtime.
const OVERTIME_TIMER_TEXT := "OT"
## The roles of a player's chip in the top bar: filled while alive, a frame when dead.
const PIP_FRIENDLY_ALIVE := &"HudFriendlyPipAlive"
const PIP_FRIENDLY_DEAD := &"HudFriendlyPipDead"
const PIP_ENEMY_ALIVE := &"HudEnemyPipAlive"
const PIP_ENEMY_DEAD := &"HudEnemyPipDead"

var _manager: RoundManager
var _ui_scale: float = 1.0
## True from the half-time swap until the next round goes live.
var _just_swapped: bool = false
## The theme colour the timer shows now ("alert"), or "" for its usual one.
var _timer_state: StringName = &""
## The alert plate ("Bomb") shows instead of the time (the bomb is planted).
var _planted_shown: bool = false
## The toasts this part of the HUD announces on (null: none).
var _toasts: ToastStack

@onready var _tdm_bar: HBoxContainer = %TdmBar
@onready var _tdm_your_score: Label = %TdmYourScore
@onready var _tdm_enemy_score: Label = %TdmEnemyScore
@onready var _tdm_your_bar: Panel = %TdmYourBar
@onready var _tdm_enemy_bar: Panel = %TdmEnemyBar
@onready var _tdm_your_fill: Panel = %TdmYourFill
@onready var _tdm_enemy_fill: Panel = %TdmEnemyFill
@onready var _tdm_timer: Label = %TdmTimer
@onready var _tdm_round: Label = %TdmRound
@onready var _bomb_bar: HBoxContainer = %BombBar
@onready var _your_score: Label = %YourScore
@onready var _enemy_score: Label = %EnemyScore
@onready var _your_pips: HBoxContainer = %YourPips
@onready var _enemy_pips: HBoxContainer = %EnemyPips
@onready var _bomb_centre: VBoxContainer = %BombCentre
@onready var _timer: Label = %Timer
@onready var _planted_plate: PanelContainer = %PlantedPlate
@onready var _round_label: Label = %RoundLabel
@onready var _lift: Control = %Lift
@onready var _title: Label = $Center/Title
@onready var _line1: Label = $Center/Line1
@onready var _kill_feed: KillFeed = $KillFeed


func _ready() -> void:
	_apply_sizes()
	_clear_messages()
	_tdm_bar.visible = false
	_bomb_bar.visible = false
	visible = false
	set_process(false)


## The sizes of the drawn parts come from the theme's "Hud" type (tools/ui_palette.gd), not from the scene.
func _apply_sizes() -> void:
	var bar := Vector2(_theme_size(&"bar_width"), _theme_size(&"bar_height"))
	_tdm_your_bar.custom_minimum_size = bar
	_tdm_enemy_bar.custom_minimum_size = bar
	_your_score.custom_minimum_size.x = _theme_size(&"score_width")
	_enemy_score.custom_minimum_size.x = _theme_size(&"score_width")
	_bomb_centre.custom_minimum_size.x = _theme_size(&"centre_width")
	_planted_plate.custom_minimum_size.y = _theme_size(&"alert_plate_height")


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
	_planted_shown = false
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


## The toasts this node announces half time and match point on (null: no toasts).
func set_toasts(toasts: ToastStack) -> void:
	_toasts = toasts


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


## How many of [param team]'s chips in the top bar are filled (players alive, as shown).
func get_alive_shown(team: int) -> int:
	var pips := _your_pips if team == Teams.viewer_team else _enemy_pips
	var lit := 0
	for pip in pips.get_children():
		if pip.theme_type_variation in [PIP_FRIENDLY_ALIVE, PIP_ENEMY_ALIVE]:
			lit += 1
	return lit


## The score the top bar shows for your team ([param yours] true) or the enemy's.
func get_score_text(yours: bool) -> String:
	if _is_tdm():
		return (_tdm_your_score if yours else _tdm_enemy_score).text
	return (_your_score if yours else _enemy_score).text


## The time the top bar shows ("Bomb" while the alert plate stands in for it).
func get_timer_text() -> String:
	if _is_tdm():
		return _tdm_timer.text
	return BOMB_TIMER_TEXT if _planted_shown else _timer.text


## The line under the time: the round number, or what wins a team respawn match.
func get_round_text() -> String:
	return (_tdm_round if _is_tdm() else _round_label).text


## True while the top bar of a team respawn match (Team Deathmatch) is the one showing.
func is_tdm_bar() -> bool:
	return _is_tdm()


func _process(_delta: float) -> void:
	# Visual state only, read from the round manager every frame; the signals
	# below handle the moments that need a message.
	if not is_instance_valid(_manager):
		return
	_refresh()
	if _manager.phase == RoundManager.Phase.FREEZE:
		_title.text = _countdown_text()


func _manager_connections() -> Array[Array]:
	return [
		[_manager.phase_changed, _on_phase_changed],
		[_manager.round_started, _on_round_started],
		[_manager.round_ended, _on_round_ended],
		[_manager.sides_swapped, _on_sides_swapped],
		[_manager.character_killed, _on_character_killed],
		[_manager.callout_made, _on_callout],
	]


## A bot on your team called out an enemy (M15, D-216): a line in the kill feed says where ("Bot3  ENEMY NEAR A"); the
## compass hangs a tag on the bearing (D-232).
func _on_callout(team: int, caller: Character, _point: Vector3, place: String) -> void:
	if team == Teams.viewer_team:
		_kill_feed.add_callout(caller, ("ENEMY NEAR %s" if place.length() == 1 else "ENEMY %s") % place)


func _is_tdm() -> bool:
	return is_instance_valid(_manager) and _manager.is_team_respawn()


# --- Top bar ---


## Brings the scores, bars or chips, round label and timer in line with the manager.
func _refresh() -> void:
	var started := _manager.round_number > 0
	var tdm := _is_tdm()
	_tdm_bar.visible = started and tdm
	_bomb_bar.visible = started and not tdm
	if not started:
		return
	var you := Teams.viewer_team
	var them := Teams.other(you)
	var your_score: int = _manager.score[you]
	var enemy_score: int = _manager.score[them]
	_tdm_your_score.text = str(your_score)
	_tdm_enemy_score.text = str(enemy_score)
	_your_score.text = str(your_score)
	_enemy_score.text = str(enemy_score)
	if tdm:
		var limit := maxf(1.0, _manager.settings.kill_limit)
		_set_fill(_tdm_your_fill, 1.0 - clampf(your_score / limit, 0.0, 1.0), 1.0)
		_set_fill(_tdm_enemy_fill, 0.0, clampf(enemy_score / limit, 0.0, 1.0))
	else:
		_refresh_pips(_your_pips, you)
		_refresh_pips(_enemy_pips, them)
	var round_text := _round_text()
	_tdm_round.text = round_text
	_round_label.text = round_text
	match _manager.phase:
		RoundManager.Phase.FREEZE:
			_planted_shown = false
			_set_timer(_manager.time_left, &"")
		RoundManager.Phase.LIVE:
			_planted_shown = false
			if _is_overtime():
				_set_timer_text(OVERTIME_TIMER_TEXT, &"alert")
				_show_overtime()
			elif _manager.is_bomb_planted():
				# The round clock has stopped: the alert plate takes the timer's place.
				_planted_shown = true
			else:
				_set_timer(_manager.time_left, &"alert" if _manager.time_left <= LOW_TIME else &"")
		# At the round end and the match end the timer keeps what it showed.
	_timer.visible = not _planted_shown
	_planted_plate.visible = _planted_shown


## Makes a bar's fill cover from [param from] to [param to] of the bar's width (0 to 1).
func _set_fill(fill: Panel, from: float, to: float) -> void:
	fill.anchor_left = from
	fill.anchor_right = to
	fill.visible = to > from


## Shows [param seconds] on the timer, in the theme colour named [param state] ("" for the usual one).
func _set_timer(seconds: float, state: StringName) -> void:
	_set_timer_text(format_time(seconds), state)


func _set_timer_text(text: String, state: StringName) -> void:
	_tdm_timer.text = text
	_timer.text = text
	if _timer_state == state:
		return
	_timer_state = state
	for label in [_tdm_timer, _timer]:
		if state.is_empty():
			label.remove_theme_color_override("font_color")
		else:
			label.add_theme_color_override("font_color", _theme_color(state))


## One chip per player of [param team]: filled (with a shadow, in the team's colour) for each one
## alive, a frame in the team's colour for each one dead.
func _refresh_pips(pips: HBoxContainer, team: int) -> void:
	var members := _manager.get_members(team).size()
	while pips.get_child_count() < members:
		var pip := Panel.new()
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var pip_size := _theme_size(&"pip_size")
		pip.custom_minimum_size = Vector2(pip_size, pip_size)
		pip.theme_type_variation = _pip_role(team, true)
		pips.add_child(pip)
		UiScale.apply_tree(pip, _ui_scale)
	while pips.get_child_count() > members:
		var extra := pips.get_child(pips.get_child_count() - 1)
		pips.remove_child(extra)
		extra.queue_free()
	var alive := _manager.get_alive_count(team)
	for i in pips.get_child_count():
		var pip := pips.get_child(i) as Panel
		var role := _pip_role(team, i < alive)
		if pip.theme_type_variation != role:
			pip.theme_type_variation = role
			UiScale.apply_tree(pip, _ui_scale)


## The theme role of a chip of [param team] (alive or not): the UI's friendly or enemy colour.
func _pip_role(team: int, alive: bool) -> StringName:
	if team == Teams.viewer_team:
		return PIP_FRIENDLY_ALIVE if alive else PIP_FRIENDLY_DEAD
	return PIP_ENEMY_ALIVE if alive else PIP_ENEMY_DEAD


## A colour of the HUD's theme type (game states; see [constant THEME_TYPE]).
func _theme_color(color_name: StringName) -> Color:
	return get_theme_color(color_name, THEME_TYPE)


## A size of the HUD's theme type (see [constant THEME_TYPE]).
func _theme_size(constant_name: StringName) -> int:
	return get_theme_constant(constant_name, THEME_TYPE)


## The UI colour of [param team]: friendly for the viewer's team, enemy for the other (the
## colour-blind scheme's, D-210, when it is on).
func _team_color(team: int) -> Color:
	return Teams.ui_color_for(team)


# --- Messages in the middle: freeze time, round end, half time ---


func _on_phase_changed(_phase: RoundManager.Phase) -> void:
	if _manager.phase == RoundManager.Phase.LIVE:
		_just_swapped = false
		Music.play_stinger(Music.ROUND_START)
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
	Music.play_stinger(Music.stinger_for_round(won, reason))
	_clear_messages()
	if _manager.is_team_respawn():
		_set_tinted_message(_title, "Your team wins" if won else "The enemy team wins", _team_color(winner))
		_set_message(_line1, _reason_text(won, reason))
		return
	_set_tinted_message(_title, "Round won" if won else "Round lost", _team_color(winner))
	_set_message(_line1, _reason_text(won, reason))
	if reason == RoundManager.EndReason.TIME:
		_set_timer(0.0, &"")


func _on_character_killed(victim: Character, killer: Character, headshot: bool) -> void:
	# A death with no killer is the bomb's when it has gone off (nothing else kills without one).
	var from_bomb := _manager.bomb != null and _manager.bomb.state == Bomb.State.EXPLODED
	_kill_feed.add_kill(victim, killer, headshot, victim.last_damage_source, &"bomb" if from_bomb else &"")
	_refresh()


## What the center shows for the current phase: the countdown during freeze
## time (the headline, a little lower than a result), nothing otherwise (the
## round-end banner arrives with [signal RoundManager.round_ended], which comes
## after the phase change, and before round 1 starts there is nothing to show yet).
func _show_phase_message() -> void:
	_clear_messages()
	if _manager.round_number == 0 or _manager.phase != RoundManager.Phase.FREEZE:
		return
	_lift.visible = true
	_set_message(_title, _countdown_text())
	if _manager.is_team_respawn():
		_set_message(_line1, "First team to %d kills wins" % _manager.settings.kill_limit)
		return
	var attacking := _manager.get_side(Teams.viewer_team) == Teams.Side.ATTACKING
	_set_message(_line1, _side_text(attacking))
	if _just_swapped:
		_toast(ToastStack.Kind.NEUTRAL, SWITCHING_TEXT)
	_show_match_point()


## "Round 3 · starts in 4" ("Team respawn · starts in 4").
func _countdown_text() -> String:
	var what := "Team respawn" if _manager.is_team_respawn() else "Round %d" % _manager.round_number
	return "%s · starts in %d" % [what, maxi(0, ceili(_manager.time_left))]


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


## A toast when a team is one round from winning the match.
func _show_match_point() -> void:
	var to_win := _manager.settings.rounds_to_win
	if to_win < 2:
		return
	var you := Teams.viewer_team
	var them := Teams.other(you)
	var you_on_point := _manager.score[you] == to_win - 1
	var them_on_point := _manager.score[them] == to_win - 1
	if you_on_point and them_on_point:
		_toast(ToastStack.Kind.MATCH_POINT, MATCH_POINT_BOTH_TEXT)
	elif you_on_point:
		_toast(ToastStack.Kind.MATCH_POINT, MATCH_POINT_TEXT)
	elif them_on_point:
		_toast(ToastStack.Kind.MATCH_POINT, ENEMY_MATCH_POINT_TEXT)


func _toast(kind: ToastStack.Kind, text: String) -> void:
	if _toasts != null:
		_toasts.show_toast(kind, text)


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
	for label in [_title, _line1]:
		_set_message(label, "")
	_lift.visible = false


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
