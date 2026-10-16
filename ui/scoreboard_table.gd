class_name ScoreboardTable
extends VBoxContainer
## The two-team table of a scoreboard: your team first under a blue header, then
## the enemy team under a red one; one row per player with name, kills, deaths,
## assists and damage, best first (kills, then damage), and your own row
## highlighted. With [member dim_dead] a dead player's row is dimmed, so you see
## who is still alive.
##
## Used by the match-end screen ([MatchEndScreen]) and by the hold-Tab overlay
## ([Scoreboard]). It is a pure view of a [RoundManager]: [method show_match]
## hands it the match, [method refresh] reads the current numbers and changes
## nothing in the game. Teams have no names, so "your team" is [member
## Teams.viewer_team] and the colors come from [method Teams.color_for].
##
## Its look comes from the UI theme (D-057): the rows, headers and labels pick
## theme type variations ("TeamHeaderFriendly", "YouRowPanel", "BrightLabel"...)
## instead of carrying styles of their own, so they scale with the theme.
##
## Nothing in the table takes mouse clicks (every control uses [constant
## Control.MOUSE_FILTER_IGNORE]), so it can sit on top of the game.

## Width (design pixels) of each number column.
const STAT_COLUMN_WIDTH := 96.0
## Background of your own row. The theme's "YouRowPanel" variation (made by
## tools/make_ui_theme.gd) takes this value, so there is one definition.
const YOU_ROW_COLOR := Color(1, 1, 1, 0.16)
## How visible a dead player's row is when [member dim_dead] is on (1 = not dimmed).
const DEAD_ROW_ALPHA := 0.4
## Titles of the number columns.
const STAT_TITLES: Array[String] = ["Kills", "Deaths", "Assists", "Damage"]

## Dim the rows of players who are dead. The hold-Tab overlay wants that (who is
## still alive this round); the match-end screen shows final numbers and turns it off.
@export var dim_dead: bool = true
## Show a money column for your own team (the Tab overlay in a match with an economy, D-098); the
## enemy's money stays hidden, as in CS.
@export var show_money: bool = false

var _manager: RoundManager
var _ui_scale: float = 1.0
## What the table was last built from; it is rebuilt only when this changes.
var _signature: Array = []
## Character → its row (a PanelContainer).
var _rows: Dictionary = {}
## Team number → the characters in the order they are shown.
var _displayed: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Shows the match run by [param manager] (null empties the table) and reads its
## numbers at once. Call [method refresh] later to follow changes.
func show_match(manager: RoundManager) -> void:
	_manager = manager
	_signature = []
	refresh()


## Reads the current numbers from the round manager. The rows are rebuilt only
## when something they show has changed (a stat, a death, a respawn, a new
## player), so calling it every frame is cheap.
func refresh() -> void:
	if not is_instance_valid(_manager):
		_signature = []
		_clear()
		return
	var order: Array[int] = [Teams.viewer_team, Teams.other(Teams.viewer_team)]
	var sorted_members := {}
	var signature: Array = [_manager.get_participants().size()]
	for team in order:
		var members := _sorted_members(team)
		sorted_members[team] = members
		for member in members:
			var stats := _manager.get_stats(member)
			signature.append([member, String(member.name), stats.kills, stats.deaths, stats.assists,
					roundi(stats.damage), member.is_alive(), member.is_local_player(), _money_text(member)])
	signature.append(order)
	if signature == _signature:
		return
	_signature = signature
	_clear()
	for team in order:
		_add_team(team, sorted_members[team])
	# The new rows' own sizes (column widths); the theme they inherit is already scaled.
	UiTheme.apply_sizes(self, _ui_scale)


## Scales the table; 1.0 is the size it is designed for (a 720-pixel-tall
## window). Rows built later are scaled too.
func set_ui_scale(factor: float) -> void:
	_ui_scale = factor
	UiTheme.apply(self, factor)


## The row of [param character], or null when the table doesn't show them.
func get_row(character: Character) -> PanelContainer:
	return _rows.get(character)


## The players of [param team] in the order they are shown (best first).
func get_displayed(team: int) -> Array[Character]:
	var shown: Array[Character] = []
	shown.assign(_displayed.get(team, []))
	return shown


## Everyone on [param team], best first: most kills, then most damage, then the
## order they joined.
func _sorted_members(team: int) -> Array[Character]:
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
	return members


func _clear() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_rows.clear()
	_displayed.clear()


## Adds a team's colored header and one row per player.
func _add_team(team: int, members: Array[Character]) -> void:
	var box := VBoxContainer.new()
	box.name = "Team%d" % team
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.theme_type_variation = &"TeamBox"
	add_child(box)
	var title := "Your team" if team == Teams.viewer_team else "Enemy team"
	var header_cells: Array[String] = [title]
	header_cells.append_array(STAT_TITLES)
	if _shows_money():
		header_cells.append("Money" if team == Teams.viewer_team else "")
	# Blue for your team, red for the enemy, as Teams.color_for() says (the theme copies those colors).
	var header := _make_row(header_cells,
			&"TeamHeaderFriendly" if team == Teams.viewer_team else &"TeamHeaderEnemy", &"BrightLabel")
	header.name = "Header"
	box.add_child(header)
	_displayed[team] = members
	for member in members:
		var stats := _manager.get_stats(member)
		var is_you := member.is_local_player()
		var cells: Array[String] = [
				"%s (you)" % member.name if is_you else String(member.name),
				str(stats.kills), str(stats.deaths), str(stats.assists), str(roundi(stats.damage))]
		if _shows_money():
			cells.append(_money_text(member))
		var row := _make_row(cells, &"YouRowPanel" if is_you else &"RowPanel", &"BrightLabel" if is_you else &"")
		row.name = String(member.name)
		if dim_dead and not member.is_alive():
			row.modulate = Color(1, 1, 1, DEAD_ROW_ALPHA)
		box.add_child(row)
		_rows[member] = row


## True if the table has a money column (the overlay, in a match with money).
func _shows_money() -> bool:
	return show_money and is_instance_valid(_manager) and _manager.has_economy()


## A player's money as the table shows it: yours and your teammates', empty for the enemy.
func _money_text(member: Character) -> String:
	if not _shows_money() or member.team != Teams.viewer_team:
		return ""
	return "$%d" % _manager.get_money(member)


## One line: a background, then the [param cells] side by side. The first cell
## (the name) takes the free width, the others are fixed-width numbers. The
## look is named, not built: [param panel_variation] for the background and
## [param label_variation] for the text (empty = the plain label).
func _make_row(cells: Array[String], panel_variation: StringName, label_variation: StringName) -> PanelContainer:
	var row := PanelContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.theme_type_variation = panel_variation
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.theme_type_variation = &"RowMargin"
	row.add_child(margin)
	var line := HBoxContainer.new()
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(line)
	for i in cells.size():
		var label := Label.new()
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.theme_type_variation = label_variation
		label.text = cells[i]
		if i == 0:
			label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		else:
			label.custom_minimum_size.x = STAT_COLUMN_WIDTH
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		line.add_child(label)
	return row
