class_name MatchEndScreen
extends CanvasLayer
## The screen shown when a match is over: "Victory" or "Defeat" for your team,
## the final score and a scoreboard of both teams, with "Play again" and "Quit"
## buttons. Hidden until the [RoundManager] emits [signal RoundManager.match_ended].
##
## It only shows state and reports button clicks; [code]main.gd[/code] reacts to
## [signal play_again_pressed] and [signal quit_pressed]. Teams have no names:
## your team (from [member Teams.viewer_team]) is blue and listed first, the
## enemy team red.

## Emitted when the player clicks "Play again".
signal play_again_pressed
## Emitted when the player clicks "Quit".
signal quit_pressed

## Font size (at the 720-pixel design height) of the scoreboard rows.
const ROW_FONT_SIZE := 16
## Width (design pixels) of each number column of the scoreboard.
const STAT_COLUMN_WIDTH := 96.0
## Background of your own row in the scoreboard.
const YOU_ROW_COLOR := Color(1, 1, 1, 0.16)
## Meta key under which a control's unscaled values are remembered.
const BASE_META := "match_end_base"
## Theme constants that make up a container's spacing, scaled with the UI.
const SPACING_CONSTANTS: Array[String] = [
	"separation", "margin_left", "margin_top", "margin_right", "margin_bottom",
]

var _manager: RoundManager
var _ui_scale: float = 1.0

@onready var _title: Label = $Panel/Margin/Content/Title
@onready var _your_score: Label = $Panel/Margin/Content/Score/YourScore
@onready var _dash: Label = $Panel/Margin/Content/Score/Dash
@onready var _enemy_score: Label = $Panel/Margin/Content/Score/EnemyScore
@onready var _teams: VBoxContainer = $Panel/Margin/Content/Teams
@onready var _play_again: Button = $Panel/Margin/Content/Buttons/PlayAgain
@onready var _quit: Button = $Panel/Margin/Content/Buttons/Quit


func _ready() -> void:
	visible = false
	_play_again.pressed.connect(play_again_pressed.emit)
	_quit.pressed.connect(quit_pressed.emit)


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
	if is_instance_valid(_manager) and _manager.match_ended.is_connected(_on_match_ended):
		_manager.match_ended.disconnect(_on_match_ended)
	_manager = manager
	if _manager != null:
		_manager.match_ended.connect(_on_match_ended)


## Scales the layout; 1.0 is the size it's designed for (a 720-pixel-tall window).
func set_ui_scale(factor: float) -> void:
	_ui_scale = factor
	_scale_tree(self)


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
	for child in _teams.get_children():
		_teams.remove_child(child)
		child.queue_free()
	_add_team(you)
	_add_team(them)
	_scale_tree(_teams)
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_play_again.grab_focus()


## Text in a team's color, lightened so it stays readable on the dark panel.
func _text_color(team: int) -> Color:
	return Teams.color_for(team).lightened(0.35)


## Adds a team's colored header and one row per player, best first.
func _add_team(team: int) -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	_teams.add_child(box)
	var title := "Your team" if team == Teams.viewer_team else "Enemy team"
	var header_background := StyleBoxFlat.new()
	header_background.bg_color = Teams.color_for(team)
	box.add_child(_make_row([title, "Kills", "Deaths", "Assists", "Damage"], Color.WHITE, header_background))
	var members := _manager.get_members(team)
	var join_order := _manager.get_participants()
	members.sort_custom(func(a: Character, b: Character) -> bool:
		var stats_a := _manager.get_stats(a)
		var stats_b := _manager.get_stats(b)
		if stats_a.kills != stats_b.kills:
			return stats_a.kills > stats_b.kills
		if not is_equal_approx(stats_a.damage, stats_b.damage):
			return stats_a.damage > stats_b.damage
		return join_order.find(a) < join_order.find(b))
	for member in members:
		var stats := _manager.get_stats(member)
		var is_you := member.is_local_player()
		var row_background: StyleBox = StyleBoxEmpty.new()
		if is_you:
			var highlight := StyleBoxFlat.new()
			highlight.bg_color = YOU_ROW_COLOR
			row_background = highlight
		box.add_child(_make_row([
				"%s (you)" % member.name if is_you else String(member.name),
				str(stats.kills), str(stats.deaths), str(stats.assists), str(roundi(stats.damage))],
				Color.WHITE if is_you else Color(0.8, 0.8, 0.8), row_background))


## One scoreboard line: a background, then the [param cells] side by side. The
## first cell (the name) takes the free width, the others are fixed-width numbers.
func _make_row(cells: Array[String], font_color: Color, background: StyleBox) -> PanelContainer:
	var row := PanelContainer.new()
	row.add_theme_stylebox_override("panel", background)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 2)
	margin.add_theme_constant_override("margin_bottom", 2)
	row.add_child(margin)
	var line := HBoxContainer.new()
	margin.add_child(line)
	for i in cells.size():
		var label := Label.new()
		label.text = cells[i]
		label.add_theme_font_size_override("font_size", ROW_FONT_SIZE)
		label.add_theme_color_override("font_color", font_color)
		if i == 0:
			label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		else:
			label.custom_minimum_size.x = STAT_COLUMN_WIDTH
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		line.add_child(label)
	return row


## Scales [param node] and everything below it: font sizes, minimum sizes and
## container spacing. Containers place their children themselves, so unlike the
## HUD there are no offsets to scale. A control's original values are
## remembered on first use, so this can run again with another factor.
func _scale_tree(node: Node) -> void:
	if node is Control:
		_scale_control(node as Control)
	for child in node.get_children():
		_scale_tree(child)


func _scale_control(control: Control) -> void:
	if not control.has_meta(BASE_META):
		var original := {"minimum_size": control.custom_minimum_size, "constants": {}}
		if control is Label or control is Button:
			original["font_size"] = control.get_theme_font_size("font_size")
		for constant_name in SPACING_CONSTANTS:
			if control.has_theme_constant(constant_name):
				original["constants"][constant_name] = control.get_theme_constant(constant_name)
		control.set_meta(BASE_META, original)
	var base: Dictionary = control.get_meta(BASE_META)
	var minimum_size: Vector2 = base["minimum_size"]
	control.custom_minimum_size = (minimum_size * _ui_scale).round()
	if base.has("font_size"):
		control.add_theme_font_size_override("font_size", maxi(1, roundi(int(base["font_size"]) * _ui_scale)))
	var constants: Dictionary = base["constants"]
	for constant_name: String in constants:
		control.add_theme_constant_override(constant_name, roundi(int(constants[constant_name]) * _ui_scale))
