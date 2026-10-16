class_name ScoreboardTable
extends VBoxContainer
## The two-team table of a scoreboard, as the mockups draw it (D-137, "15
## Scoreboard" and "16 Match end"): the column titles (a space for the class
## icon, PLAYER, K, D, A, DMG) in MUTE, then a 2 px line in your team's colour
## and your team's rows, then a 2 px line in the enemy's colour and theirs. A
## row has the player's class icon in the team colour, the name, kills, deaths,
## assists and damage (rounded), best first (kills, then damage, then the order
## they joined), and your own row is raised and framed in the accent. With
## [member dim_dead] a dead player's row is muted (MUTE text, the icon in LINE),
## so you see who is still alive.
##
## Used by the match-end screen ([MatchEndScreen], [member compact]) and by the
## hold-Tab overlay ([Scoreboard]). It is a pure view of a [RoundManager]:
## [method show_match] hands it the match, [method refresh] reads the current
## numbers and changes nothing in the game. Teams have no names, so "your team"
## is [member Teams.viewer_team] and its colour is the UI's friendly one.
##
## M7 added a money column, which the mockup doesn't draw: with [member
## show_money] your own team's money shows after the damage (the enemy's stays
## hidden, as in CS), and your team's defuse kits are marked in the name.
##
## Its look comes from the UI theme (D-057): the rows, the lines and the
## labels pick theme type variations ("RowPanel", "YouRowPanel",
## "TeamHeaderFriendly", "MuteLabel"...) instead of carrying styles of their
## own, so they scale with the theme. Row heights and column widths are plain
## minimum sizes (design pixels, scaled by [UiTheme]); the class icons come from
## the theme's icon slots ([UiIcons]) and are tinted with the palette's team
## colours.
##
## Nothing in the table takes mouse clicks (every control uses [constant
## Control.MOUSE_FILTER_IGNORE]), so it can sit on top of the game.

## Width (design pixels) of the column that holds the class icon.
const ICON_COLUMN_WIDTH := 32.0
## Width of the kills, deaths and assists columns.
const NUMBER_COLUMN_WIDTH := 64.0
## Width of the damage column, and of the money column when it is shown (ADR is a number column).
const WIDE_COLUMN_WIDTH := 96.0
## The titles of the columns after the player's name.
const STAT_TITLES: Array[String] = ["K", "D", "A", "DMG"]
## The title of the name column, of the ADR column (rounds matches only, M14, D-201) and of the money column.
const PLAYER_TITLE := "Player"
const ADR_TITLE := "ADR"
const MONEY_TITLE := "Money"
## The height of the titles and of a player's row on the Tab scoreboard.
const TITLES_HEIGHT := 32.0
const ROW_HEIGHT := 40.0
## The same on the match-end screen ([member compact]).
const COMPACT_TITLES_HEIGHT := 28.0
const COMPACT_ROW_HEIGHT := 36.0

## Mute the rows of players who are dead (MUTE text, the icon in LINE). The hold-Tab
## overlay wants that (who is still alive this round); the match-end screen shows
## final numbers and turns it off.
@export var dim_dead: bool = true
## Show a money column for your own team (the Tab overlay in a match with an economy, D-098); the
## enemy's money stays hidden, as in CS.
@export var show_money: bool = false
## The match-end screen's tighter table: 28 high titles and 36 high rows with nothing between
## them, and 12 px above the enemy's line, where the Tab scoreboard has 32, 40, 8 and 16.
@export var compact: bool = false

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
	if compact:
		theme_type_variation = &"StackBox"


## Shows the match run by [param manager] (null empties the table) and reads its
## numbers at once. Call [method refresh] later to follow changes.
func show_match(manager: RoundManager) -> void:
	_manager = manager
	_signature = []
	refresh()


## Reads the current numbers from the round manager. The rows are rebuilt only
## when something they show has changed (a stat, a death, a respawn, a class, a
## new player), so calling it every frame is cheap.
func refresh() -> void:
	if not is_instance_valid(_manager):
		_signature = []
		_clear()
		return
	var order: Array[int] = [Teams.viewer_team, Teams.other(Teams.viewer_team)]
	var sorted_members := {}
	var signature: Array = [_manager.get_participants().size(), _manager.get_rounds_played()]
	for team in order:
		var members := _sorted_members(team)
		sorted_members[team] = members
		for member in members:
			var stats := _manager.get_stats(member)
			signature.append([member, String(member.name), stats.kills, stats.deaths, stats.assists,
					roundi(stats.damage), member.is_alive(), member.is_local_player(), _money_text(member), member.has_defuse_kit,
					_class_id(member)])
	signature.append(order)
	if signature == _signature:
		return
	_signature = signature
	_clear()
	add_child(_make_titles())
	for team in order:
		_add_team(team, sorted_members[team])
	# The new rows' own sizes (heights, column widths); the theme they inherit is already scaled.
	UiTheme.apply_sizes(self, _ui_scale)


## Scales the table; 1.0 is the size it is designed for (a 720-pixel-tall
## window). Rows built later are scaled too, and the rows are built again now
## so that the class icons are the ones of the scaled theme.
func set_ui_scale(factor: float) -> void:
	_ui_scale = factor
	UiTheme.apply(self, factor)
	_signature = []
	refresh()


## The row of [param character], or null when the table doesn't show them.
func get_row(character: Character) -> PanelContainer:
	return _rows.get(character)


## The players of [param team] in the order they are shown (best first).
func get_displayed(team: int) -> Array[Character]:
	var shown: Array[Character] = []
	shown.assign(_displayed.get(team, []))
	return shown


## True when [param character]'s row is drawn as a dead player's: muted text
## and a LINE-coloured icon. False for a living player, and for a row that the
## table doesn't mute ([member dim_dead] off) or doesn't show.
func is_muted(character: Character) -> bool:
	var row: PanelContainer = _rows.get(character)
	if row == null:
		return false
	var name_label := _name_label(row)
	return name_label != null and name_label.theme_type_variation == &"MuteLabel"


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


## The column titles: PLAYER, K, D, A and DMG (and Money) in MUTE, over a space the width of the icon column.
func _make_titles() -> PanelContainer:
	var cells: Array[String] = [PLAYER_TITLE]
	cells.append_array(STAT_TITLES)
	if _shows_adr():
		cells.append(ADR_TITLE)
	if _shows_money():
		cells.append(MONEY_TITLE)
	var titles := _make_row(cells, &"RowPanel", &"MuteLabel", COMPACT_TITLES_HEIGHT if compact else TITLES_HEIGHT, null, Color.WHITE)
	titles.name = "Titles"
	return titles


## Adds a team's line (2 px in its colour) and one row per player.
func _add_team(team: int, members: Array[Character]) -> void:
	var yours := team == Teams.viewer_team
	var box := VBoxContainer.new()
	box.name = "Team%d" % team
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.theme_type_variation = &"StackBox" if compact else &"TeamBox"
	add_child(box)
	# Blue for your team, red for the enemy, as the theme says (the enemy's line also leaves room above it).
	var line := PanelContainer.new()
	line.name = "Header"
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if yours:
		line.theme_type_variation = &"TeamHeaderFriendly"
	else:
		line.theme_type_variation = &"TeamHeaderEnemyTight" if compact else &"TeamHeaderEnemy"
	box.add_child(line)
	_displayed[team] = members
	for member in members:
		var stats := _manager.get_stats(member)
		var is_you := member.is_local_player()
		var muted := dim_dead and not member.is_alive()
		var shown_name := "%s (you)" % member.name if is_you else String(member.name)
		# Your team's defuse kits show, as in CS (D-098).
		if member.has_defuse_kit and yours:
			shown_name += "  · kit"
		var cells: Array[String] = [
				shown_name,
				str(stats.kills), str(stats.deaths), str(stats.assists), str(roundi(stats.damage))]
		if _shows_adr():
			cells.append(str(roundi(StatsMath.average_damage_per_round(stats.damage, maxi(_manager.get_rounds_played(), 1)))))
		if _shows_money():
			cells.append(_money_text(member))
		# A living player's icon is in their team's colour, a dead player's in LINE.
		var tint := get_theme_color(&"line", "Palette") if muted else Teams.ui_color_for(member.team)
		var row := _make_row(cells, &"YouRowPanel" if is_you else &"RowPanel", &"MuteLabel" if muted else &"",
				COMPACT_ROW_HEIGHT if compact else ROW_HEIGHT, _class_icon(member), tint)
		row.name = String(member.name)
		box.add_child(row)
		_rows[member] = row


## True if the table has an ADR column: in a rounds match (Team respawn is one long round, D-201).
## The first round's ADR is its damage so far; after that it is the damage over the rounds played.
func _shows_adr() -> bool:
	return is_instance_valid(_manager) and not _manager.is_team_respawn()


## True if the table has a money column (the overlay, in a match with money).
func _shows_money() -> bool:
	return show_money and is_instance_valid(_manager) and _manager.has_economy()


## A player's money as the table shows it: yours and your teammates', empty for the enemy.
func _money_text(member: Character) -> String:
	if not _shows_money() or member.team != Teams.viewer_team:
		return ""
	return "$%d" % _manager.get_money(member)


## The id of [param member]'s class ("rifleman"), which is also the name of its icon slot; empty without a class.
func _class_id(member: Character) -> StringName:
	return member.class_data.id if member.class_data != null else &""


## [param member]'s class icon from the theme, or null while its slot is empty.
func _class_icon(member: Character) -> Texture2D:
	var id := _class_id(member)
	return UiIcons.get_icon(self, id) if id != &"" else null


## One line, [param height] high: a background, then the icon column (the
## class icon in [param tint], or just room for it), then the [param cells] side
## by side. The first cell (the name) takes the free width, the others are
## fixed-width numbers (the damage and the money are wider). The look is named,
## not built: [param panel_variation] for the background and [param
## label_variation] for the text (empty = the plain label).
func _make_row(cells: Array[String], panel_variation: StringName, label_variation: StringName, height: float,
		icon: Texture2D, tint: Color) -> PanelContainer:
	var row := PanelContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.theme_type_variation = panel_variation
	row.custom_minimum_size.y = height
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.theme_type_variation = &"CellMargin"
	row.add_child(margin)
	var line := HBoxContainer.new()
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.theme_type_variation = &"FlushRow"
	margin.add_child(line)
	# The icon is drawn at its own size at the left of its column, centred up and down.
	var icon_cell := TextureRect.new()
	icon_cell.name = "Icon"
	icon_cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_cell.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon_cell.stretch_mode = TextureRect.STRETCH_KEEP
	icon_cell.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon_cell.custom_minimum_size.x = ICON_COLUMN_WIDTH
	icon_cell.texture = icon
	icon_cell.modulate = tint
	line.add_child(icon_cell)
	for i in cells.size():
		var label := Label.new()
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.theme_type_variation = label_variation
		label.text = cells[i]
		label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		if i == 0:
			label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		else:
			label.custom_minimum_size.x = _column_width(cells, i)
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		line.add_child(label)
	return row


## The width of cell [param index] of a row made of [param cells]: kills, deaths, assists and ADR are
## numbers, the damage and the money are wider. The cells in a row are the name, K, D, A, DMG, then ADR and
## Money when they are shown, so the row's length tells which of them are there.
func _column_width(cells: Array[String], index: int) -> float:
	var money_index := cells.size() - 1 if _shows_money() else -1
	var adr_index := STAT_TITLES.size() + 1 if _shows_adr() else -1
	if index == adr_index:
		return NUMBER_COLUMN_WIDTH
	if index == money_index or index == STAT_TITLES.size():
		return WIDE_COLUMN_WIDTH
	return NUMBER_COLUMN_WIDTH


## The label with the player's name in [param row] (the first label of its line).
func _name_label(row: Control) -> Label:
	var labels := row.find_children("*", "Label", true, false)
	return labels[0] as Label if not labels.is_empty() else null
