class_name StatsMenu
extends CanvasLayer
## The Stats screen (M14, D-204): your lifetime numbers, your weapons, your match history and your
## training bests, read from the [StatsBook] on your computer. It opens from the main menu's Stats
## button.
##
## Four tabs:
## - **Overview:** tiles for K/D, ADR, HS %, accuracy, win %, matches, kills, deaths, damage and time
##   played, then the wins per mode and per map as bars.
## - **Weapons:** per gun the bullets fired, the hits, the accuracy and the share of hits by body zone.
## - **History:** your last [constant HISTORY_ROWS] matches, newest first: when, mode and map, result,
##   score, K, D, K/D, ADR (round matches only), HS % and accuracy.
## - **Training:** the personal bests of the Shooting Range's aim trainer and spray practice.
## The footer has **Export CSV** (the history as a spreadsheet file in your user folder), **Reset
## stats** (asks twice) and Back.
##
## What each tab shows is made by static functions of plain numbers ([method tile_values],
## [method weapon_rows], [method history_rows], [method win_rows]) so the tests can check the text
## without a window; the menu only puts it on screen. Like every menu it registers with [MenuState]
## while open, takes its look from the UI theme (type variations only, no overrides, D-057) and has
## [code]process_mode = Always[/code]. The tables are rows of labels like the scoreboard's.

## Emitted when the screen closes (Back or Esc).
signal closed

## The tabs, in order.
const TAB_NAMES: Array[String] = ["Overview", "Weapons", "History", "Training"]
## The most matches the History tab lists (newest first).
const HISTORY_ROWS := 100
## Where Export CSV writes (the user folder, next to the stats file).
const EXPORT_PATH := "user://stats_history.csv"
## Seconds the Reset button waits for its second press before it forgets the first.
const RESET_WINDOW := 4.0
const RESET_TEXT := "Reset stats"
const RESET_CONFIRM_TEXT := "Press again to delete"
## Width (design pixels) of the column that holds a weapon's icon, and the height of a History row
## (a dense table shows more matches at once than the scoreboard's 40).
const ICON_COLUMN_WIDTH := 48.0
const HISTORY_ROW_HEIGHT := 32.0
## Mode ids in the file → what the screen calls them.
const MODE_NAMES := {"rounds": "Bomb", "respawn": "Team Deathmatch"}
## Result ids → their words.
const RESULT_NAMES := {"win": "Win", "loss": "Loss", "draw": "Draw"}
## Training key prefixes → their names. The aim trainer and the spray wall add theirs (D-205, D-208).
const TRAINING_NAMES := {"aim_flick": "Aim trainer", "spray": "Spray practice"}
## How a detail saved with a best reads on the Training tab (a key not listed is made readable).
const DETAIL_NAMES := {"reaction_ms": "Reaction ms", "accuracy": "Accuracy %", "drift_cm": "Drift cm", "pattern_cm": "Pattern cm"}

## The book shown; the shared one ([method StatsBook.get_instance]) when left empty.
var book: StatsBook

var _ui_scale: float = 1.0
var _reset_armed: bool = false
var _reset_timer: SceneTreeTimer

@onready var _tabs: TabContainer = %Tabs
@onready var _status: Label = %Status
@onready var _export_button: Button = %ExportButton
@onready var _reset_button: Button = %ResetButton
@onready var _back_button: Button = %BackButton


func _ready() -> void:
	visible = false
	_tabs.tab_changed.connect(_on_tab_changed)
	_export_button.pressed.connect(export_csv)
	_reset_button.pressed.connect(press_reset)
	_back_button.pressed.connect(close)


func _exit_tree() -> void:
	# Freed or removed while open: don't leave the game waiting for a menu.
	MenuState.close(self)


func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("pause") and MenuState.is_top(self):
		close()
		get_viewport().set_input_as_handled()


## Shows the screen with the numbers as they are now, on the Overview tab, with the mouse.
func open() -> void:
	visible = true
	MenuState.open(self)
	_tabs.current_tab = 0
	_disarm_reset()
	_status.text = ""
	refresh()
	_back_button.grab_focus()


## Hides the screen, hands the mouse back (if it was the last menu open) and emits [signal closed].
## Does nothing when it isn't open.
func close() -> void:
	if not visible:
		return
	visible = false
	_disarm_reset()
	MenuState.close(self)
	closed.emit()


## True while the screen is shown.
func is_open() -> bool:
	return visible


## Scales the screen; 1.0 is the size it is designed for (a 720-pixel-tall window).
func set_ui_scale(factor: float) -> void:
	_ui_scale = factor
	UiTheme.apply(self, factor)
	if is_node_ready():
		refresh()


## The tabs (for the tests and the layout check).
func get_tabs() -> TabContainer:
	return _tabs


## The line above the footer's buttons (what Export CSV or Reset just did).
func get_status() -> String:
	return _status.text


func get_export_button() -> Button:
	return _export_button


func get_reset_button() -> Button:
	return _reset_button


func get_back_button() -> Button:
	return _back_button


## Builds every tab again from the book, so a tab is always up to date when it is shown.
func refresh() -> void:
	var shown := _book()
	_fill(_tab(0), _build_overview(shown))
	_fill(_tab(1), _build_weapons(shown))
	_fill(_tab(2), _build_history(shown))
	_fill(_tab(3), _build_training(shown))


## Writes the history as a CSV file ([constant EXPORT_PATH]) and says where it went.
func export_csv() -> void:
	var result := _book().export_csv(EXPORT_PATH)
	_status.text = "Saved %s" % ProjectSettings.globalize_path(EXPORT_PATH) if result == OK else "Couldn't write the file (error %d)." % result


## The Reset button: the first press asks ([constant RESET_CONFIRM_TEXT]), a second press within
## [constant RESET_WINDOW] seconds deletes the history, totals and bests (the file is rewritten empty).
func press_reset() -> void:
	if not _reset_armed:
		_reset_armed = true
		_reset_button.text = RESET_CONFIRM_TEXT
		_reset_timer = get_tree().create_timer(RESET_WINDOW)
		_reset_timer.timeout.connect(_disarm_reset)
		return
	_disarm_reset()
	_book().clear()
	_status.text = "Stats deleted."
	refresh()


## True after the first press of Reset, until the second press or the time runs out.
func is_reset_armed() -> bool:
	return _reset_armed


# --- What the tabs show (plain text from plain numbers) ---


## The Overview's tiles as [caption, value] pairs.
static func tile_values(totals: StatsTotals) -> Array:
	return [
		["K/D", "%.2f" % totals.kd()],
		["ADR", "%d" % roundi(totals.adr()) if totals.rounds > 0 else "-"],
		["HS %", "%d %%" % roundi(totals.hs_percent())],
		["Accuracy", "%d %%" % roundi(totals.accuracy() * 100.0)],
		["Wins", "%d %%" % roundi(totals.win_percent())],
		["Matches", str(totals.matches)],
		["Kills", str(totals.kills)],
		["Deaths", str(totals.deaths)],
		["Damage", str(roundi(totals.damage))],
		["Played", format_duration(totals.duration)],
	]


## Wins per mode or per map as [name, wins, played] sorted by the matches played (most first).
## [param table] is [member StatsTotals.modes] or [member StatsTotals.maps]; [param names] turns a
## key into the words shown.
static func win_rows(table: Dictionary, names: Callable) -> Array:
	var rows: Array = []
	for key: String in table:
		rows.append([String(names.call(key)), StatsTotals.won_in(table, key), StatsTotals.played_in(table, key)])
	rows.sort_custom(func(a: Array, b: Array) -> bool: return a[2] > b[2] if a[2] != b[2] else String(a[0]) < String(b[0]))
	return rows


## The Weapons table as rows [id, name, shots, hits, accuracy %, head %, chest %, stomach %, arms %,
## legs %] (texts), the most fired gun first. The zone columns are the share of that gun's hits.
static func weapon_rows(totals: StatsTotals) -> Array:
	var rows: Array = []
	var ids: Array = totals.weapons.keys()
	ids.sort_custom(func(a: String, b: String) -> bool:
		var shots_a := (totals.weapons[a] as StatsWeapon).shots
		var shots_b := (totals.weapons[b] as StatsWeapon).shots
		return shots_a > shots_b if shots_a != shots_b else a < b)
	for id: String in ids:
		var weapon := totals.weapons[id] as StatsWeapon
		var row: Array = [id, weapon_name(id), str(weapon.shots), str(weapon.hits), _percent_text(weapon.accuracy())]
		for zone in StatsWeapon.ZONES:
			row.append(_percent_text(weapon.zone_share(zone)))
		rows.append(row)
	return rows


## The History table as rows of texts, newest first, at most [param limit]: [when, mode · map,
## result, score, K, D, K/D, ADR, HS %, accuracy].
static func history_rows(matches: Array[StatsMatch], limit: int = HISTORY_ROWS) -> Array:
	var rows: Array = []
	for index in range(matches.size() - 1, maxi(matches.size() - 1 - limit, -1), -1):
		var record := matches[index]
		rows.append([
			format_date(record.date),
			"%s · %s" % [MODE_NAMES.get(record.mode, record.mode), map_name(record.map)],
			RESULT_NAMES.get(record.result, record.result),
			"%d : %d" % [record.score_us, record.score_them],
			str(record.kills), str(record.deaths), "%.2f" % record.kd(),
			"%d" % roundi(record.adr()) if record.rounds > 0 else "-",
			"%d %%" % roundi(record.hs_percent()), _percent_text(record.accuracy()),
		])
	return rows


## The Training tab's rows [name, best, when, details] for every saved best, sorted by name.
static func training_rows(training: Dictionary) -> Array:
	var rows: Array = []
	var keys: Array = training.keys()
	keys.sort()
	for key: String in keys:
		var entry: Dictionary = training[key]
		var details := PackedStringArray()
		for detail: String in entry:
			if detail != "score" and detail != "date":
				details.append("%s %s" % [DETAIL_NAMES.get(detail, detail.capitalize()), _number_text(float(entry[detail]))])
		rows.append([training_title(key), _number_text(float(entry.get("score", 0.0))), format_date(int(entry.get("date", 0))), ", ".join(details)])
	return rows


## What a training key is called on screen: a name from [constant TRAINING_NAMES], or the key made readable.
static func training_title(key: String) -> String:
	for prefix: String in TRAINING_NAMES:
		if key == prefix or key.begins_with(prefix + "_"):
			var weapon := key.trim_prefix(prefix).trim_prefix("_")
			return TRAINING_NAMES[prefix] if weapon == "" else "%s · %s" % [TRAINING_NAMES[prefix], weapon_name(weapon)]
	return key.capitalize()


## The weapon with [param id] by its name, or the id made readable when there is no such weapon.
static func weapon_name(id: String) -> String:
	var data := WeaponData.find(StringName(id))
	return data.display_name if data != null else id.capitalize()


## A map's short name ("depot") as a title ("Depot"); the test map, hidden from the player, shows as is.
static func map_name(map_id: String) -> String:
	return GameLaunch.map_title(map_id) if map_id != "" else "-"


## A date (unix seconds) in your own time zone as "2026-10-16 14:03", or "-" for none.
static func format_date(unix_time: int) -> String:
	if unix_time <= 0:
		return "-"
	var local := unix_time + int(Time.get_time_zone_from_system().get("bias", 0)) * 60
	var parts := Time.get_datetime_dict_from_unix_time(local)
	return "%04d-%02d-%02d %02d:%02d" % [parts["year"], parts["month"], parts["day"], parts["hour"], parts["minute"]]


## Seconds as "2:05 h" ("45 min" under an hour, "0 min" for none).
static func format_duration(seconds: float) -> String:
	var minutes := roundi(seconds / 60.0)
	if minutes < 60:
		return "%d min" % minutes
	return "%d:%02d h" % [minutes / 60, minutes % 60]


static func _percent_text(fraction: float) -> String:
	return "%d %%" % roundi(fraction * 100.0)


## A number without a useless ".0": 4200 → "4200", 87.5 → "87.5".
static func _number_text(value: float) -> String:
	return str(roundi(value)) if is_equal_approx(value, roundf(value)) else "%.1f" % value


# --- Building the tabs ---


func _book() -> StatsBook:
	return book if book != null else StatsBook.get_instance()


## The scroll box of tab [param index]; its first child is the column the content goes into.
func _tab(index: int) -> VBoxContainer:
	return _tabs.get_child(index).get_child(0) as VBoxContainer


## Replaces what a tab column shows with [param content] and sizes it for the screen's scale.
func _fill(column: VBoxContainer, content: Array[Control]) -> void:
	for child in column.get_children():
		column.remove_child(child)
		child.queue_free()
	for control in content:
		column.add_child(control)
	UiTheme.apply_sizes(column, _ui_scale)


func _build_overview(shown: StatsBook) -> Array[Control]:
	var content: Array[Control] = []
	var totals := shown.lifetime
	if totals.matches == 0:
		content.append(_note("No matches yet. Finish a match (Play, then Team Deathmatch or Bomb, with bots or friends) and your numbers appear here. Practice doesn't count."))
		return content
	content.append(_header("Lifetime · %d matches" % totals.matches))
	var tiles := HFlowContainer.new()
	tiles.theme_type_variation = &"FlowBox"
	tiles.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for pair: Array in tile_values(totals):
		tiles.add_child(_tile(pair[0], pair[1]))
	content.append(tiles)
	content.append(_header("Wins by mode"))
	for row: Array in win_rows(totals.modes, func(key: String) -> String: return MODE_NAMES.get(key, key)):
		content.append(_win_bar(row[0], row[1], row[2]))
	content.append(_header("Wins by map"))
	for row: Array in win_rows(totals.maps, map_name):
		content.append(_win_bar(row[0], row[1], row[2]))
	content.append(_note("ADR is the damage per round in bomb matches (Team Deathmatch has no rounds). Accuracy counts a shotgun's pellets one by one."))
	return content


func _build_weapons(shown: StatsBook) -> Array[Control]:
	var content: Array[Control] = []
	var rows := weapon_rows(shown.lifetime)
	if rows.is_empty():
		content.append(_note("No shots recorded yet. Your guns' accuracy shows here after your first finished match."))
		return content
	content.append(_header("Accuracy by weapon"))
	var widths: Array[float] = [0.0, 96.0, 96.0, 128.0, 80.0, 80.0, 112.0, 80.0, 80.0]
	content.append(_table_row(["Weapon", "Shots", "Hits", "Accuracy", "Head", "Chest", "Stomach", "Arms", "Legs"], widths, &"RowPanel", &"MuteLabel"))
	for row: Array in rows:
		# The row's first cell is the name, with the gun's icon in front when there is one.
		var cells: Array[String] = [row[1]]
		cells.append_array(row.slice(2))
		content.append(_table_row(cells, widths, &"RowPanel", &"", UiIcons.get_icon(_tabs, StringName(row[0]))))
	content.append(_note("Head to Legs are each zone's share of that gun's hits."))
	return content


func _build_history(shown: StatsBook) -> Array[Control]:
	var content: Array[Control] = []
	var rows := history_rows(shown.history)
	if rows.is_empty():
		content.append(_note("Your finished matches are listed here, newest first."))
		return content
	content.append(_header("Last %d of %d matches" % [rows.size(), shown.lifetime.matches] if shown.lifetime.matches > rows.size() else "%d matches" % rows.size()))
	var widths: Array[float] = [232.0, 0.0, 80.0, 96.0, 48.0, 48.0, 72.0, 64.0, 80.0, 80.0]
	content.append(_table_row(["When", "Mode · map", "Result", "Score", "K", "D", "K/D", "ADR", "HS %", "Acc"], widths, &"RowPanel", &"MuteLabel", null, 2, HISTORY_ROW_HEIGHT))
	for row: Array in rows:
		var cells: Array[String] = []
		cells.assign(row)
		content.append(_table_row(cells, widths, &"RowPanel", &"BrightLabel" if row[2] == "Win" else &"", null, 2, HISTORY_ROW_HEIGHT))
	return content


func _build_training(shown: StatsBook) -> Array[Control]:
	var content: Array[Control] = []
	var rows := training_rows(shown.training)
	if rows.is_empty():
		content.append(_note("No training results yet. The Shooting Range (Practice in the main menu) has an aim trainer and a spray wall; your best scores are kept here."))
		return content
	content.append(_header("Personal bests"))
	var widths: Array[float] = [0.0, 128.0, 192.0, 320.0]
	content.append(_table_row(["Training", "Best", "When", "Details"], widths, &"RowPanel", &"MuteLabel"))
	for row: Array in rows:
		var cells: Array[String] = []
		cells.assign(row)
		content.append(_table_row(cells, widths, &"RowPanel", &""))
	return content


func _header(text: String) -> Label:
	var label := Label.new()
	label.theme_type_variation = &"HeaderLabel"
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _note(text: String) -> Label:
	var label := Label.new()
	label.theme_type_variation = &"DimLabel"
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


## A tile of the Overview: a big number over its caption.
func _tile(caption: String, value: String) -> PanelContainer:
	var tile := PanelContainer.new()
	tile.name = caption.replace(" ", "").replace("%", "Percent")
	tile.theme_type_variation = &"InsetPanel"
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.custom_minimum_size = Vector2(208, 88)
	var margin := MarginContainer.new()
	margin.theme_type_variation = &"PanelMargin"
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(margin)
	var stack := VBoxContainer.new()
	stack.theme_type_variation = &"StackBox"
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(stack)
	var number := Label.new()
	number.name = "Value"
	number.theme_type_variation = &"ScoreLabel"
	number.text = value
	number.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(number)
	var name_label := Label.new()
	name_label.name = "Caption"
	name_label.theme_type_variation = &"MuteLabel"
	name_label.text = caption
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(name_label)
	return tile


## A row for one mode or map: its name, a bar of the share won and "5 of 8 · 63 %".
func _win_bar(name_text: String, wins: int, played: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.theme_type_variation = &"RowBox"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var name_label := Label.new()
	name_label.text = name_text
	name_label.custom_minimum_size.x = 224.0
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(name_label)
	var bar := ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = 100.0
	bar.value = StatsMath.percent(float(wins), float(played))
	bar.show_percentage = false
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.custom_minimum_size = Vector2(0, 16)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(bar)
	var value_label := Label.new()
	value_label.text = "%d of %d · %d %%" % [wins, played, roundi(StatsMath.percent(float(wins), float(played)))]
	value_label.custom_minimum_size.x = 224.0
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(value_label)
	return row


## One table line like the scoreboard's: [param cells] side by side. A cell whose entry in
## [param widths] is 0 takes the free width, the others are that wide (design pixels). The first
## [param left_count] cells are left-aligned, the rest right-aligned (numbers). [param icon], when
## given, goes in front of the first cell. The look is named: [param panel_variation] for the
## background and [param label_variation] for the text.
func _table_row(cells: Array[String], widths: Array[float], panel_variation: StringName, label_variation: StringName,
		icon: Texture2D = null, left_count: int = 1, height: float = 40.0) -> PanelContainer:
	var row := PanelContainer.new()
	row.theme_type_variation = panel_variation
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var margin := MarginContainer.new()
	margin.theme_type_variation = &"CellMargin"
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(margin)
	var line := HBoxContainer.new()
	line.theme_type_variation = &"FlushRow"
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(line)
	for index in cells.size():
		if index == 0 and icon != null:
			var icon_cell := TextureRect.new()
			icon_cell.texture = icon
			icon_cell.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			icon_cell.stretch_mode = TextureRect.STRETCH_KEEP
			icon_cell.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			icon_cell.custom_minimum_size.x = ICON_COLUMN_WIDTH
			icon_cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
			line.add_child(icon_cell)
		var label := Label.new()
		label.theme_type_variation = label_variation
		label.text = cells[index]
		label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if widths[index] <= 0.0:
			label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			label.clip_text = true
		else:
			label.custom_minimum_size.x = widths[index]
		if index >= left_count:
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		line.add_child(label)
	row.custom_minimum_size.y = height
	return row


func _on_tab_changed(_index: int) -> void:
	_status.text = ""


func _disarm_reset() -> void:
	_reset_armed = false
	if _reset_timer != null and _reset_timer.timeout.is_connected(_disarm_reset):
		_reset_timer.timeout.disconnect(_disarm_reset)
	_reset_timer = null
	if is_node_ready():
		_reset_button.text = RESET_TEXT
