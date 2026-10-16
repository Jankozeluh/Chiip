class_name StatsMenu
extends CanvasLayer
## The Stats screen (M14, D-204; the designer's "18 Stats" and "19 Stats match detail" since v0.2, D-235): your lifetime
## numbers, your weapons, your wins and your match history on one page, read from the [StatsBook] on your computer. It
## opens from the main menu's Stats button.
##
## **The page:** the lifetime row (K/D, ADR, HS %, accuracy, wins, losses), the K/D of your last 20 matches as bars with
## the 1.00 line, the accuracy and head-shot share per weapon, the wins per mode and per map and against bots, and the
## match history on the right, newest first. **The filter** at the top right (All, TDM, Bomb, Vs bots) narrows the
## numbers to those matches (All is the lifetime totals; the others are counted from the last
## [constant StatsBook.MAX_HISTORY] matches); **Training** swaps the page for the personal bests of the Shooting Range's aim
## trainer and spray practice.
## **A click on a match** opens its detail: the result and score, your line (kills, deaths, assists, ADR, HS %,
## accuracy, damage), a table per weapon (kills, accuracy, head share, damage) and a chart of your kills and deaths per
## minute. Esc, or Back, goes back to the page.
## The footer has **Export CSV** (the history as a spreadsheet file in your user folder), **Reset stats** (asks twice)
## and Back.
##
## What the page shows is made by static functions of plain numbers ([method lifetime_values], [method accuracy_rows],
## [method win_lines], [method history_entries], [method match_values]) so the tests can check the text without a
## window; the menu only puts it on screen. Like every menu it registers with [MenuState] while open, takes its look
## from the UI theme (type variations only, no overrides, D-057) and has [code]process_mode = Always[/code].

## Emitted when the screen closes (Back or Esc on the page).
signal closed

## The filters, in order: id → the words on the segment.
const FILTERS := {"all": "All", "respawn": "TDM", "rounds": "Bomb", "bots": "Vs bots", "training": "Training"}
## The most matches the history lists (newest first).
const HISTORY_ROWS := 100
## How many matches the K/D bars show.
const SPARK_MATCHES := 20
## Where Export CSV writes (the user folder, next to the stats file).
const EXPORT_PATH := "user://stats_history.csv"
## Seconds the Reset button waits for its second press before it forgets the first.
const RESET_WINDOW := 4.0
const RESET_TEXT := "Reset stats"
const RESET_CONFIRM_TEXT := "Press again to delete"
## The footer's line while a match's detail shows.
const DETAIL_NOTE := "Esc back to stats"
## Design pixels: a bar's height at a K/D of 2 and its smallest, a list row, the history column's width, the weapon icon's column.
const SPARK_HEIGHT := 44.0
const SPARK_BASE := 2.0
const ROW_HEIGHT := 36.0
const HISTORY_COLUMN_WIDTH := 368.0
const HISTORY_ITEM_HEIGHT := 48.0
const NAME_COLUMN_WIDTH := 104.0
const ICON_COLUMN_WIDTH := 48.0
## The accuracy that fills a weapon's bar (the page draws 50 % as a full bar).
const ACCURACY_FULL := 0.5
## Design pixels per kill and per death in a minute of the detail's chart, and the chart's two halves.
const KILL_UNIT := 28.0
const DEATH_UNIT := 20.0
const CHART_UP := 96.0
const CHART_DOWN := 48.0
## Mode ids in the file → what the screen calls them.
const MODE_NAMES := {"rounds": "Bomb", "respawn": "Team Deathmatch"}
## ...and the short form of the history rows.
const MODE_SHORT := {"rounds": "BOMB", "respawn": "TDM"}
## Result ids → their words.
const RESULT_NAMES := {"win": "Win", "loss": "Loss", "draw": "Draw"}
## The detail's headline for each result.
const RESULT_WORDS := {"win": "VICTORY", "loss": "DEFEAT", "draw": "DRAW"}
## Training key prefixes → their names. The aim trainer and the spray wall add theirs (D-205, D-208).
const TRAINING_NAMES := {"aim_flick": "Aim trainer", "spray": "Spray practice"}
## How a detail saved with a best reads on the Training page (a key not listed is made readable).
const DETAIL_NAMES := {"reaction_ms": "Reaction ms", "accuracy": "Accuracy %", "drift_cm": "Drift cm", "pattern_cm": "Pattern cm", "best_streak": "Best streak"}
## Month names for the short dates ("16 OCT").
const MONTHS: Array[String] = ["JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"]

## The book shown; the shared one ([method StatsBook.get_instance]) when left empty.
var book: StatsBook

var _ui_scale: float = 1.0
var _reset_armed: bool = false
var _reset_timer: SceneTreeTimer
## The filter in use (a key of [constant FILTERS]) and the match open in the detail (an index into the book's
## history, or -1 for none; the page shows the highlighted one too).
var _filter: String = "all"
var _selected: int = -1
var _detail_open: bool = false
var _filter_buttons: Dictionary = {}

@onready var _title_box: Control = %TitleBox
@onready var _filter_box: HBoxContainer = %Filters
@onready var _overview: HBoxContainer = %Overview
@onready var _detail: VBoxContainer = %Detail
@onready var _training: VBoxContainer = %Training
@onready var _status: Label = %Status
@onready var _export_button: Button = %ExportButton
@onready var _reset_button: Button = %ResetButton
@onready var _back_button: Button = %BackButton


func _ready() -> void:
	visible = false
	_build_filters()
	_export_button.pressed.connect(export_csv)
	_reset_button.pressed.connect(press_reset)
	_back_button.pressed.connect(_on_back)


func _exit_tree() -> void:
	# Freed or removed while open: don't leave the game waiting for a menu.
	MenuState.close(self)


func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("pause") and MenuState.is_top(self):
		_on_back()
		get_viewport().set_input_as_handled()


## Shows the screen with the numbers as they are now, on the page with the filter All, with the mouse.
func open() -> void:
	visible = true
	MenuState.open(self)
	_filter = "all"
	_detail_open = false
	_selected = -1
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


## Back goes from the detail to the page, and from the page out of the screen.
func _on_back() -> void:
	if _detail_open:
		_detail_open = false
		refresh()
		_back_button.grab_focus()
	else:
		close()


## The line left of the footer's buttons (what Export CSV or Reset just did, else how many matches there are).
func get_status() -> String:
	return _status.text


func get_reset_button() -> Button:
	return _reset_button


func get_back_button() -> Button:
	return _back_button


## The filter in use ("all", "respawn", "rounds", "bots" or "training").
func get_filter() -> String:
	return _filter


## Picks a filter (what a click on its segment does) and shows the page again.
func set_filter(filter: String) -> void:
	if not FILTERS.has(filter):
		return
	_filter = filter
	_detail_open = false
	_selected = -1
	refresh()


## Opens the detail of the match at [param index] of the book's history (what a click on its row does).
func open_match(index: int) -> void:
	var matches := _book().history
	if index < 0 or index >= matches.size():
		return
	_selected = index
	_detail_open = true
	refresh()


## True while the match detail shows.
func is_detail_open() -> bool:
	return _detail_open


## The page, the detail and the Training page (for the tests and the layout check).
func get_overview() -> HBoxContainer:
	return _overview


func get_detail() -> VBoxContainer:
	return _detail


func get_training_page() -> VBoxContainer:
	return _training


## The segments of the filter, by id.
func get_filter_buttons() -> Dictionary:
	return _filter_buttons


## Builds what is on screen again from the book, so it is always up to date when it is shown.
func refresh() -> void:
	var shown := _book()
	var matches := _filtered(shown)
	if _selected >= shown.history.size():
		_selected = -1
	_overview.visible = not _detail_open and _filter != "training"
	_detail.visible = _detail_open
	_training.visible = not _detail_open and _filter == "training"
	_filter_box.visible = not _detail_open
	for id: String in _filter_buttons:
		(_filter_buttons[id] as Button).set_pressed_no_signal(id == _filter)
	if _detail_open and _selected >= 0:
		_fill(_detail, _build_detail(shown.history[_selected]))
	elif _filter == "training":
		_fill(_training, _build_training(shown))
	else:
		_fill_overview(shown, matches)
	_title_box.visible = not _detail_open
	if _status.text == "" or _status.text.ends_with("matches") or _status.text == DETAIL_NOTE:
		if _detail_open:
			_status.text = DETAIL_NOTE
		else:
			_status.text = "%d matches" % shown.lifetime.matches if shown.lifetime.matches > 0 else ""


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
	_selected = -1
	_detail_open = false
	_status.text = "Stats deleted."
	refresh()


## True after the first press of Reset, until the second press or the time runs out.
func is_reset_armed() -> bool:
	return _reset_armed


# --- What the page shows (plain text from plain numbers) ---


## The lifetime row as [caption, value] pairs: K/D, ADR, HS %, ACC, WINS, LOSSES.
static func lifetime_values(totals: StatsTotals) -> Array:
	return [
		["K/D", "%.2f" % totals.kd()],
		["ADR", "%d" % roundi(totals.adr()) if totals.rounds > 0 else "-"],
		["HS %", "%d%%" % roundi(totals.hs_percent())],
		["ACC", "%d%%" % roundi(totals.accuracy() * 100.0)],
		["WINS", str(totals.wins)],
		["LOSSES", str(totals.losses)],
	]


## The K/D of the last [param count] matches of [param matches] (oldest first), one number each.
static func spark_values(matches: Array[StatsMatch], count: int = SPARK_MATCHES) -> Array[float]:
	var values: Array[float] = []
	for record in matches.slice(maxi(matches.size() - count, 0)):
		values.append(record.kd())
	return values


## The height of the K/D bar for [param kd] in design pixels: [constant SPARK_HEIGHT] at a K/D of 2 (and beyond), plus a floor.
static func spark_height(kd: float) -> float:
	return roundf(minf(kd, 2.0) / 2.0 * SPARK_HEIGHT) + SPARK_BASE


## The accuracy list as rows [id, name, accuracy 0-1, "27%", "44%" (the share of hits to the head)], the most fired gun first.
static func accuracy_rows(totals: StatsTotals) -> Array:
	var rows: Array = []
	var ids: Array = totals.weapons.keys()
	ids.sort_custom(func(a: String, b: String) -> bool:
		var shots_a := (totals.weapons[a] as StatsWeapon).shots
		var shots_b := (totals.weapons[b] as StatsWeapon).shots
		return shots_a > shots_b if shots_a != shots_b else a < b)
	for id: String in ids:
		var weapon := totals.weapons[id] as StatsWeapon
		if weapon.shots <= 0:
			continue
		rows.append([id, weapon_name(id), weapon.accuracy(), _short_percent(weapon.accuracy()), _short_percent(weapon.head_share())])
	return rows


## Wins per mode or per map as [name, wins, played] sorted by the matches played (most first).
## [param table] is [member StatsTotals.modes] or [member StatsTotals.maps]; [param names] turns a
## key into the words shown.
static func win_rows(table: Dictionary, names: Callable) -> Array:
	var rows: Array = []
	for key: String in table:
		rows.append([String(names.call(key)), StatsTotals.won_in(table, key), StatsTotals.played_in(table, key)])
	rows.sort_custom(func(a: Array, b: Array) -> bool: return a[2] > b[2] if a[2] != b[2] else String(a[0]) < String(b[0]))
	return rows


## The wins list as [name, wins, losses, rule_above]: the two modes, then the maps (a rule between the groups), then
## the matches against bots only. [param matches] are the matches counted for "Vs bots" (offline ones).
static func win_lines(totals: StatsTotals, matches: Array[StatsMatch]) -> Array:
	var lines: Array = []
	for mode: String in ["respawn", "rounds"]:
		var played := StatsTotals.played_in(totals.modes, mode)
		var won := StatsTotals.won_in(totals.modes, mode)
		lines.append([MODE_SHORT[mode], won, played - won, false])
	var first_map := true
	for row in win_rows(totals.maps, map_name):
		lines.append([String(row[0]).to_upper(), row[1], row[2] - row[1], first_map])
		first_map = false
	var bot_wins := 0
	var bot_matches := 0
	for record in matches:
		if not record.online:
			bot_matches += 1
			bot_wins += 1 if record.result == StatsMatch.WIN else 0
	lines.append(["VS BOTS", bot_wins, bot_matches - bot_wins, true])
	return lines


## The history as entries, newest first, at most [param limit]: {"index" (into [param all]), "won", "result" ("W", "L", "D"),
## "map", "line" ("TDM · 16 OCT"), "kd" ("24-15")}.
static func history_entries(matches: Array[StatsMatch], all: Array[StatsMatch], limit: int = HISTORY_ROWS) -> Array:
	var entries: Array = []
	for index in range(matches.size() - 1, maxi(matches.size() - 1 - limit, -1), -1):
		var record := matches[index]
		entries.append({
			"index": all.find(record), "won": record.result == StatsMatch.WIN,
			"result": {"win": "W", "loss": "L", "draw": "D"}.get(record.result, "D"),
			"map": map_name(record.map).to_upper(), "line": "%s · %s" % [MODE_SHORT.get(record.mode, record.mode.to_upper()), short_date(record.date)],
			"kd": "%d-%d" % [record.kills, record.deaths],
		})
	return entries


## The detail's numbers for [param record]: {"title" ("DEPOT"), "meta" ("TDM · 16 OCT · 10:00"), "word" ("VICTORY"),
## "result" (the file's id), "score" ("50 – 43"), "line" ([caption, value] pairs), "guns" (rows [id, name, kills,
## accuracy, head share, damage] as texts), "kills" and "deaths" (per minute)}.
static func match_values(record: StatsMatch) -> Dictionary:
	var guns: Array = []
	var ids: Array = record.weapons.keys()
	ids.sort_custom(func(a: String, b: String) -> bool:
		var kills_a := (record.weapons[a] as StatsWeapon).kills
		var kills_b := (record.weapons[b] as StatsWeapon).kills
		return kills_a > kills_b if kills_a != kills_b else a < b)
	for id: String in ids:
		var weapon := record.weapons[id] as StatsWeapon
		guns.append([id, weapon_name(id).to_upper(), str(weapon.kills), _short_percent(weapon.accuracy()), _short_percent(weapon.head_share()), str(roundi(weapon.damage))])
	return {
		"title": map_name(record.map).to_upper(),
		"meta": "%s · %s · %s" % [MODE_SHORT.get(record.mode, record.mode.to_upper()), short_date(record.date), format_clock(record.duration)],
		"word": RESULT_WORDS.get(record.result, "DRAW"), "result": record.result,
		"score": "%d – %d" % [record.score_us, record.score_them],
		"line": [["KILLS", str(record.kills)], ["DEATHS", str(record.deaths)], ["ASSISTS", str(record.assists)],
				["ADR", str(roundi(record.adr())) if record.rounds > 0 else "-"], ["HS %", "%d%%" % roundi(record.hs_percent())],
				["ACC", _short_percent(record.accuracy())], ["DAMAGE", str(roundi(record.damage))]],
		"guns": guns, "kills": record.kills_per_minute, "deaths": record.deaths_per_minute,
	}


## The Training page's rows [name, best, when, details] for every saved best, sorted by name.
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
			# A run of a chosen length ends in its seconds: "rifle_60" (D-236).
			var seconds := ""
			var split := weapon.rfind("_")
			if split > 0 and weapon.substr(split + 1).is_valid_int():
				seconds = " · %s s" % weapon.substr(split + 1)
				weapon = weapon.substr(0, split)
			return TRAINING_NAMES[prefix] if weapon == "" else "%s · %s%s" % [TRAINING_NAMES[prefix], weapon_name(weapon), seconds]
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


## A date as the page writes it: "16 OCT", or "-" for none.
static func short_date(unix_time: int) -> String:
	if unix_time <= 0:
		return "-"
	var local := unix_time + int(Time.get_time_zone_from_system().get("bias", 0)) * 60
	var parts := Time.get_datetime_dict_from_unix_time(local)
	return "%d %s" % [parts["day"], MONTHS[clampi(int(parts["month"]) - 1, 0, 11)]]


## Seconds as "2:05 h" ("45 min" under an hour, "0 min" for none).
static func format_duration(seconds: float) -> String:
	var minutes := roundi(seconds / 60.0)
	if minutes < 60:
		return "%d min" % minutes
	return "%d:%02d h" % [minutes / 60, minutes % 60]


## Seconds as a clock, "10:00" or "24:12".
static func format_clock(seconds: float) -> String:
	var whole := roundi(seconds)
	return "%d:%02d" % [whole / 60, whole % 60]


static func _short_percent(fraction: float) -> String:
	return "%d%%" % roundi(fraction * 100.0)


## A number without a useless ".0": 4200 → "4200", 87.5 → "87.5".
static func _number_text(value: float) -> String:
	return str(roundi(value)) if is_equal_approx(value, roundf(value)) else "%.1f" % value


# --- Building the page ---


func _book() -> StatsBook:
	return book if book != null else StatsBook.get_instance()


## The matches the filter keeps, oldest first ("all" keeps every one in the history).
func _filtered(shown: StatsBook) -> Array[StatsMatch]:
	var matches: Array[StatsMatch] = []
	for record in shown.history:
		if _filter == "all" or _filter == "training" or (_filter == "bots" and not record.online) or record.mode == _filter:
			matches.append(record)
	return matches


## The totals of the filter: the lifetime ones for All, else counted from the matches the filter keeps.
func _filtered_totals(shown: StatsBook, matches: Array[StatsMatch]) -> StatsTotals:
	if _filter == "all":
		return shown.lifetime
	var totals := StatsTotals.new()
	for record in matches:
		totals.add_match(record)
	return totals


func _build_filters() -> void:
	var frame := PanelContainer.new()
	frame.theme_type_variation = &"SegmentFrame"
	_filter_box.add_child(frame)
	var strip := HBoxContainer.new()
	strip.theme_type_variation = &"SegmentRow"
	frame.add_child(strip)
	var group := ButtonGroup.new()
	for id: String in FILTERS:
		var button := Button.new()
		button.text = FILTERS[id]
		button.theme_type_variation = &"WideSegmentButton"
		button.toggle_mode = true
		button.button_group = group
		button.toggled.connect(func(on: bool) -> void:
			if on:
				set_filter(id))
		strip.add_child(button)
		_filter_buttons[id] = button


## Empties [param container] and fills it with [param content], scaled like the screen.
func _fill(container: Control, content: Array[Control]) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
	for control in content:
		container.add_child(control)
	UiTheme.apply_sizes(container, _ui_scale)


func _fill_overview(shown: StatsBook, matches: Array[StatsMatch]) -> void:
	var totals := _filtered_totals(shown, matches)
	var left := VBoxContainer.new()
	left.theme_type_variation = &"StatStack"
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var right := VBoxContainer.new()
	right.theme_type_variation = &"TightBox"
	right.custom_minimum_size.x = HISTORY_COLUMN_WIDTH
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if totals.matches == 0 and matches.is_empty():
		var empty: Array[Control] = [_note("No matches yet. Finish a match (Play, then Team Deathmatch or Bomb, with bots or friends) and your numbers appear here. Practice doesn't count.")]
		_fill(_overview, empty)
		return
	left.add_child(_lifetime_row(totals))
	left.add_child(_spark_block(matches))
	var lower := HBoxContainer.new()
	lower.theme_type_variation = &"StatColumns"
	lower.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lower.add_child(_accuracy_block(totals))
	lower.add_child(_wins_block(totals, matches))
	left.add_child(lower)
	right.add_child(_list_header("MATCH HISTORY", "K-D"))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	var list := VBoxContainer.new()
	list.theme_type_variation = &"TightBox"
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	right.add_child(scroll)
	for entry: Dictionary in history_entries(matches, shown.history):
		list.add_child(_history_item(entry))
	var content: Array[Control] = [left, right]
	_fill(_overview, content)


func _lifetime_row(totals: StatsTotals) -> Control:
	var grid := HBoxContainer.new()
	grid.theme_type_variation = &"FormRow"
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for pair: Array in lifetime_values(totals):
		var cell := VBoxContainer.new()
		cell.theme_type_variation = &"TightBox"
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(_label(pair[0], &"DimLabel"))
		cell.add_child(_label(pair[1], &"ScoreLabel"))
		grid.add_child(cell)
	return grid


## The K/D of the last matches as bars (a TEXT bar for a K/D of 1 or more, a MUTE one under it) on a rule, with the 1.00 line.
func _spark_block(matches: Array[StatsMatch]) -> Control:
	var block := VBoxContainer.new()
	block.theme_type_variation = &"TightBox"
	block.mouse_filter = Control.MOUSE_FILTER_IGNORE
	block.add_child(_list_header("K/D · LAST %d MATCHES" % SPARK_MATCHES, "1.00 LINE"))
	var holder := Control.new()
	holder.custom_minimum_size.y = SPARK_HEIGHT + SPARK_BASE + 2.0
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	block.add_child(holder)
	var bars := HBoxContainer.new()
	bars.theme_type_variation = &"TeamChipRow"
	bars.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(bars)
	for value in spark_values(matches):
		var bar := Panel.new()
		bar.theme_type_variation = &"StatBarFill" if value >= 1.0 else &"StatBarMute"
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.size_flags_vertical = Control.SIZE_SHRINK_END
		bar.custom_minimum_size.y = spark_height(value)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bars.add_child(bar)
	var line := Panel.new()
	line.theme_type_variation = &"StatBarLine"
	line.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	line.offset_top = -SPARK_HEIGHT / 2.0 - 2.0
	line.offset_bottom = -SPARK_HEIGHT / 2.0
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(line)
	var rule := Panel.new()
	rule.theme_type_variation = &"StatBarLine"
	rule.custom_minimum_size.y = 2.0
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	block.add_child(rule)
	return block


func _accuracy_block(totals: StatsTotals) -> Control:
	var block := VBoxContainer.new()
	block.theme_type_variation = &"TightBox"
	block.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	block.mouse_filter = Control.MOUSE_FILTER_IGNORE
	block.add_child(_list_header("ACCURACY PER WEAPON", "HS"))
	for row: Array in accuracy_rows(totals):
		var line := _row_line()
		line.add_child(_icon_cell(String(row[0])))
		line.add_child(_label(String(row[1]), &"DimLabel", false, NAME_COLUMN_WIDTH, true))
		line.add_child(_bar(float(row[2]) / ACCURACY_FULL))
		line.add_child(_label(String(row[3]), &"Label", true, 40.0))
		line.add_child(_label(String(row[4]), &"MuteLabel", true, 40.0))
		block.add_child(line)
	return block


func _wins_block(totals: StatsTotals, matches: Array[StatsMatch]) -> Control:
	var block := VBoxContainer.new()
	block.theme_type_variation = &"TightBox"
	block.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	block.mouse_filter = Control.MOUSE_FILTER_IGNORE
	block.add_child(_list_header("WINS · MODE AND MAP", "W-L"))
	for entry: Array in win_lines(totals, matches):
		if entry[3]:
			var rule := Panel.new()
			rule.theme_type_variation = &"StatBarLine"
			rule.custom_minimum_size.y = 2.0
			rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
			block.add_child(rule)
		var line := _row_line()
		line.add_child(_label(String(entry[0]), &"DimLabel", false, NAME_COLUMN_WIDTH, true))
		var played: int = entry[1] + entry[2]
		line.add_child(_bar(float(entry[1]) / played if played > 0 else 0.0, true))
		line.add_child(_label("%d-%d" % [entry[1], entry[2]], &"Label", true, 64.0))
		block.add_child(line)
	return block


## A history row: a button over its contents (the result chip, the map, the mode and day, the kills-deaths).
func _history_item(entry: Dictionary) -> Control:
	var item := MarginContainer.new()
	item.custom_minimum_size.y = HISTORY_ITEM_HEIGHT
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var button := Button.new()
	button.theme_type_variation = &"HistoryItemPicked" if entry["index"] == _selected else &"HistoryItem"
	button.focus_mode = Control.FOCUS_ALL
	var index: int = entry["index"]
	button.pressed.connect(func() -> void: open_match(index))
	item.add_child(button)
	var margin := MarginContainer.new()
	margin.theme_type_variation = &"HistoryMargin"
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item.add_child(margin)
	var row := HBoxContainer.new()
	row.theme_type_variation = &"FormRow"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(row)
	var chip := PanelContainer.new()
	chip.theme_type_variation = &"StatResultWin" if entry["won"] else &"StatResultLoss"
	chip.custom_minimum_size = Vector2(24, 24)
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var letter := _label(entry["result"], &"BrightInkLabel" if entry["won"] else &"DimLabel")
	letter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	letter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	chip.add_child(letter)
	row.add_child(chip)
	var names := VBoxContainer.new()
	names.theme_type_variation = &"FlushRow"
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.mouse_filter = Control.MOUSE_FILTER_IGNORE
	names.add_child(_label(entry["map"], &"Label"))
	names.add_child(_label(entry["line"], &"MuteLabel"))
	row.add_child(names)
	row.add_child(_label(entry["kd"], &"Label"))
	return item


# --- The match detail ---


func _build_detail(record: StatsMatch) -> Array[Control]:
	var values := match_values(record)
	var content: Array[Control] = []
	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var left := VBoxContainer.new()
	left.theme_type_variation = &"TightBox"
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.add_child(_label(values["meta"], &"DimLabel"))
	left.add_child(_label(values["title"], &"TitleLabel"))
	head.add_child(left)
	var right := VBoxContainer.new()
	right.theme_type_variation = &"TightBox"
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var word := _label(values["word"], &"ScoreLabel")
	word.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	word.modulate = _result_color(String(values["result"]))
	right.add_child(word)
	var score := _label(values["score"], &"DimLabel")
	score.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(score)
	head.add_child(right)
	content.append(head)
	var line := PanelContainer.new()
	line.theme_type_variation = &"RaisedPanel"
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cells := HBoxContainer.new()
	cells.theme_type_variation = &"FormRow"
	cells.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(cells)
	for pair: Array in values["line"]:
		var cell := VBoxContainer.new()
		cell.theme_type_variation = &"TightBox"
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(_label(pair[0], &"DimLabel"))
		cell.add_child(_label(pair[1], &"ScoreLabel"))
		cells.add_child(cell)
	content.append(line)
	var lower := HBoxContainer.new()
	lower.theme_type_variation = &"StatColumns"
	lower.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lower.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lower.add_child(_gun_table(values["guns"]))
	lower.add_child(_minute_chart(values["kills"], values["deaths"], String(values["meta"]).get_slice(" · ", 2)))
	content.append(lower)
	return content


func _result_color(result: String) -> Color:
	match result:
		StatsMatch.WIN:
			return Teams.ui_color_for(Teams.viewer_team)
		StatsMatch.LOSS:
			return Teams.ui_color_for(Teams.other(Teams.viewer_team))
	return Color.WHITE


## The per-weapon table of a match: weapon, kills, accuracy, head share, damage.
func _gun_table(guns: Array) -> Control:
	var table := VBoxContainer.new()
	table.theme_type_variation = &"TightBox"
	table.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	table.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var header := _row_line()
	header.add_child(_label("WEAPON", &"MuteLabel", false, 0.0, true))
	for column: Array in [["KILLS", 72.0], ["ACC", 72.0], ["HS", 72.0], ["DMG", 88.0]]:
		header.add_child(_label(column[0], &"MuteLabel", true, column[1]))
	table.add_child(header)
	for gun: Array in guns:
		var row := _row_line()
		row.add_child(_icon_cell(String(gun[0])))
		row.add_child(_label(String(gun[1]), &"DimLabel", false, 0.0, true))
		for cell in [[gun[2], 72.0], [gun[3], 72.0], [gun[4], 72.0], [gun[5], 88.0]]:
			row.add_child(_label(String(cell[0]), &"Label", true, cell[1]))
		table.add_child(row)
	return table


## The kills (up, TEXT) and the deaths (down, MUTE) of each minute as bars either side of a rule.
func _minute_chart(kills: Array, deaths: Array, length: String) -> Control:
	var chart := VBoxContainer.new()
	chart.theme_type_variation = &"TightBox"
	chart.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chart.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chart.add_child(_list_header("KILLS AND DEATHS · PER MINUTE", length))
	var minutes := maxi(kills.size(), deaths.size())
	if minutes == 0:
		chart.add_child(_label("Not recorded for this match.", &"MuteLabel"))
		return chart
	for half: Array in [[kills, CHART_UP, KILL_UNIT, &"StatBarFill", Control.SIZE_SHRINK_END], [deaths, CHART_DOWN, DEATH_UNIT, &"StatBarMute", Control.SIZE_SHRINK_BEGIN]]:
		if half[0] == deaths:
			var rule := Panel.new()
			rule.theme_type_variation = &"StatBarLine"
			rule.custom_minimum_size.y = 2.0
			rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
			chart.add_child(rule)
		var bars := HBoxContainer.new()
		bars.theme_type_variation = &"ChipRow"
		bars.custom_minimum_size.y = half[1]
		bars.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for minute in minutes:
			var count: int = (half[0] as Array)[minute] if minute < (half[0] as Array).size() else 0
			var bar := Panel.new()
			bar.theme_type_variation = half[3]
			bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			bar.size_flags_vertical = half[4]
			bar.custom_minimum_size.y = minf(count * half[2], half[1])
			bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
			bars.add_child(bar)
		chart.add_child(bars)
	var legend := HBoxContainer.new()
	legend.theme_type_variation = &"FormRow"
	legend.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for key: Array in [["KILLS", &"StatBarFill"], ["DEATHS", &"StatBarMute"]]:
		var swatch := Panel.new()
		swatch.theme_type_variation = key[1]
		swatch.custom_minimum_size = Vector2(8, 8)
		swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
		legend.add_child(swatch)
		legend.add_child(_label(key[0], &"MuteLabel"))
	chart.add_child(legend)
	return chart


# --- The Training page ---


func _build_training(shown: StatsBook) -> Array[Control]:
	var content: Array[Control] = []
	var rows := training_rows(shown.training)
	if rows.is_empty():
		content.append(_note("No training bests yet. Play the aim trainer or spray practice on the Shooting Range (Practice) and your best scores are kept here."))
		return content
	content.append(_list_header("TRAINING · PERSONAL BESTS", "BEST"))
	for row: Array in rows:
		var line := _row_line()
		line.add_child(_label(String(row[0]), &"DimLabel", false, 0.0, true))
		line.add_child(_label(String(row[2]), &"MuteLabel", true, 160.0))
		line.add_child(_label(String(row[3]), &"MuteLabel", true, 320.0))
		line.add_child(_label(String(row[1]), &"Label", true, 96.0))
		content.append(line)
	return content


# --- Small parts ---


## A label of [param role]; [param min_width] 0 leaves the width alone, [param clip] shortens a long text instead of widening the row.
func _label(text: String, role: StringName, right: bool = false, min_width: float = 0.0, expand_clip: bool = false) -> Label:
	var label := Label.new()
	label.theme_type_variation = role
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if right:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	if min_width > 0.0:
		label.custom_minimum_size.x = min_width
	if expand_clip:
		label.clip_text = true
		if min_width <= 0.0:
			label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label


func _note(text: String) -> Label:
	var label := _label(text, &"DimLabel")
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label


## A list's header: its name left, a column's name right, both muted.
func _list_header(left: String, right: String) -> Control:
	var row := HBoxContainer.new()
	row.theme_type_variation = &"FlushRow"
	row.custom_minimum_size.y = ROW_HEIGHT - 4.0
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var name_label := _label(left, &"MuteLabel")
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)
	row.add_child(_label(right, &"MuteLabel", true))
	return row


## A row of a list: [constant ROW_HEIGHT] tall, its parts in a line.
func _row_line() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.theme_type_variation = &"FormRow"
	row.custom_minimum_size.y = ROW_HEIGHT
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return row


## A weapon's icon in a column of its own (blank when there is none).
func _icon_cell(weapon_id: String) -> Control:
	var cell := Control.new()
	cell.custom_minimum_size = Vector2(ICON_COLUMN_WIDTH - 16.0, 0)
	cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon := UiIcons.get_icon(_overview, StringName(weapon_id))
	if icon != null:
		var rect := TextureRect.new()
		rect.texture = icon
		rect.stretch_mode = TextureRect.STRETCH_KEEP
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rect.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
		cell.add_child(rect)
	return cell


## A bar: [param fraction] (0 to 1) of it filled with TEXT, the rest the track (a bar of the wins list leaves a small gap).
func _bar(fraction: float, gap: bool = false) -> Control:
	var bar := HBoxContainer.new()
	bar.theme_type_variation = &"TeamChipRow" if gap else &"SegmentRow"
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var share := clampf(fraction, 0.0, 1.0)
	var fill := Panel.new()
	fill.theme_type_variation = &"StatBarFill"
	fill.custom_minimum_size.y = 8.0
	fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fill.size_flags_stretch_ratio = maxf(share, 0.0001)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(fill)
	var rest := Panel.new()
	rest.theme_type_variation = &"StatBarLine" if gap else &"StatBarTrack"
	rest.custom_minimum_size.y = 8.0
	rest.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rest.size_flags_stretch_ratio = maxf(1.0 - share, 0.0001)
	rest.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(rest)
	return bar


func _disarm_reset() -> void:
	_reset_armed = false
	if _reset_timer != null and _reset_timer.timeout.is_connected(_disarm_reset):
		_reset_timer.timeout.disconnect(_disarm_reset)
	_reset_timer = null
	if is_node_ready():
		_reset_button.text = RESET_TEXT
