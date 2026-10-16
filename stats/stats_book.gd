class_name StatsBook
extends RefCounted
## Your match history, lifetime numbers and training bests, saved on your computer (M14, D-200).
## One file, `user://stats.json`, a plain text JSON file you can open, copy or delete; nothing in it
## ever leaves your computer, online games included (each player keeps their own).
##
## It holds the last [constant MAX_HISTORY] finished matches ([StatsMatch]), the lifetime totals
## ([StatsTotals]; they keep counting after old matches drop out of the list) and the personal
## bests of the Shooting Range's training ([method submit_best]).
##
## Like [Settings] it has one shared instance ([method get_instance]; a static variable like
## [Noises], not an autoload) and saves only after something called [method load_from_disk], so a
## test or a tool that never loads the file can never write yours. A file that can't be read (not
## JSON, the wrong shape, written by a newer game) is kept aside as `stats.json.bad` and replaced
## by an empty book instead of crashing; one bad match inside an otherwise good file is skipped.
## Saving writes a temporary file first and renames it over the real one, so a crash in the
## middle never leaves half a file.

## Emitted when a match or a best was added, or the book was cleared.
signal changed

## Where the shared book lives.
const PATH := "user://stats.json"
## The file format's version; a file with a higher one isn't read (it came from a newer game).
const VERSION := 1
## The history keeps this many matches; the oldest drop out (the totals keep them).
const MAX_HISTORY := 300

static var _instance: StatsBook

## Where [method save_to_disk] writes, set by [method load_from_disk]; empty = never save.
var save_path: String = ""
## The finished matches, oldest first.
var history: Array[StatsMatch] = []
## Everything added up.
var lifetime: StatsTotals = StatsTotals.new()
## Training bests: key (e.g. "aim_flick_rifle") → {"score": n, "date": unix time, ...}.
var training: Dictionary = {}


## The shared book of the running game.
static func get_instance() -> StatsBook:
	if _instance == null:
		_instance = StatsBook.new()
	return _instance


## True once [method load_from_disk] ran: only then does the book save itself.
func is_loaded() -> bool:
	return save_path != ""


## Adds a finished match: to the history (the oldest drop out beyond [constant MAX_HISTORY]) and
## to the lifetime totals, then saves if the book is loaded.
func add_match(record: StatsMatch) -> void:
	history.append(record)
	while history.size() > MAX_HISTORY:
		history.pop_front()
	lifetime.add_match(record)
	changed.emit()
	_save_if_loaded()


## Offers a training result: [param score] is a new personal best for [param key] when it is
## higher than the saved one (or there is none). [param extra] (hits, accuracy...) is saved with it.
## Returns true for a new best.
func submit_best(key: String, score: float, extra: Dictionary = {}) -> bool:
	if get_best_score(key) >= score and training.has(key):
		return false
	var entry := extra.duplicate()
	entry["score"] = score
	entry["date"] = int(Time.get_unix_time_from_system())
	training[key] = entry
	changed.emit()
	_save_if_loaded()
	return true


## The saved best of [param key] (an empty dictionary when there is none).
func get_best(key: String) -> Dictionary:
	return (training.get(key, {}) as Dictionary).duplicate()


## The saved best score of [param key], 0 when there is none.
func get_best_score(key: String) -> float:
	return float((training.get(key, {}) as Dictionary).get("score", 0.0))


## Forgets everything (history, totals and bests) and saves the empty book.
func clear() -> void:
	history.clear()
	lifetime = StatsTotals.new()
	training.clear()
	changed.emit()
	_save_if_loaded()


## Reads the book from [param path]. Returns OK; ERR_FILE_NOT_FOUND when there is no file yet (an
## empty book, which saves there from now on); or ERR_PARSE_ERROR when the file couldn't be read
## (kept aside as `<path>.bad`, an empty book).
func load_from_disk(path: String = PATH) -> Error:
	save_path = path
	_reset()
	if not FileAccess.file_exists(path):
		return ERR_FILE_NOT_FOUND
	var json := JSON.new()
	var text := FileAccess.get_file_as_string(path)
	if json.parse(text) != OK or not _read(json.data):
		_reset()
		_keep_aside(path)
		return ERR_PARSE_ERROR
	return OK


## Writes the book to [param path], or to [member save_path] without one: a temporary file first,
## then a rename over the real file.
func save_to_disk(path: String = "") -> Error:
	var target := path if path != "" else save_path
	if target == "":
		return ERR_UNCONFIGURED
	var temporary := target + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(to_dict(), "\t"))
	file.close()
	return DirAccess.rename_absolute(temporary, target)


## Writes the history as a CSV file (one row per match, newest last) for a spreadsheet: date,
## mode, map, result, score, rounds, kills, deaths, assists, damage, ADR, headshot kills, accuracy.
func export_csv(path: String) -> Error:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_csv_line(PackedStringArray([
			"date", "mode", "map", "result", "score_us", "score_them", "rounds", "online", "kills",
			"deaths", "assists", "damage", "adr", "headshot_kills", "accuracy_percent"]))
	for record in history:
		var when := Time.get_datetime_string_from_unix_time(record.date, true)
		var adr := "" if record.rounds <= 0 else "%.1f" % record.adr()
		file.store_csv_line(PackedStringArray([
				when, record.mode, record.map, record.result, str(record.score_us),
				str(record.score_them), str(record.rounds), str(record.online), str(record.kills),
				str(record.deaths), str(record.assists), "%.0f" % record.damage, adr,
				str(record.headshot_kills), "%.1f" % (record.accuracy() * 100.0)]))
	file.close()
	return OK


func to_dict() -> Dictionary:
	var matches: Array = []
	for record in history:
		matches.append(record.to_dict())
	return {"version": VERSION, "history": matches, "lifetime": lifetime.to_dict(), "training": training.duplicate(true)}


## Fills the book from a parsed file. False when the data isn't a book of this version.
func _read(data: Variant) -> bool:
	if not data is Dictionary:
		return false
	var source: Dictionary = data
	if StatsMath.clean_count(source.get("version"), -1) != VERSION:
		return false
	var matches: Variant = source.get("history")
	if not matches is Array:
		return false
	for entry: Variant in matches:
		var record := StatsMatch.from_dict(entry)
		if record != null:
			history.append(record)
	history.sort_custom(func(a: StatsMatch, b: StatsMatch) -> bool: return a.date < b.date)
	while history.size() > MAX_HISTORY:
		history.pop_front()
	var totals := StatsTotals.from_dict(source.get("lifetime"))
	if totals != null:
		lifetime = totals
	else:
		# The totals are gone but the matches are not: count them again.
		for record in history:
			lifetime.add_match(record)
	var bests: Variant = source.get("training")
	if bests is Dictionary:
		for key: Variant in bests:
			var entry: Variant = (bests as Dictionary)[key]
			var name := StatsMath.clean_text(key)
			if name != "" and entry is Dictionary and _is_number((entry as Dictionary).get("score")):
				training[name] = _clean_best(entry)
	return true


## A best read from a file: the score and date cleaned, the other numbers kept when they are numbers.
static func _clean_best(entry: Dictionary) -> Dictionary:
	var clean := {
		"score": StatsMath.clean_number(entry.get("score")),
		"date": StatsMath.clean_range(entry.get("date"), 0, StatsMatch.MAX_DATE, 0),
	}
	for key: Variant in entry:
		var name := StatsMath.clean_text(key)
		var value: Variant = entry[key]
		if name != "" and not clean.has(name) and _is_number(value):
			clean[name] = value
	return clean


static func _is_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))


func _reset() -> void:
	history.clear()
	lifetime = StatsTotals.new()
	training.clear()


## Moves an unreadable file to `<path>.bad` (replacing an older one) so it is not lost.
func _keep_aside(path: String) -> void:
	var aside := path + ".bad"
	if FileAccess.file_exists(aside):
		DirAccess.remove_absolute(aside)
	DirAccess.rename_absolute(path, aside)
	push_warning("Chiip: the stats file couldn't be read; it was kept as %s and a new one starts." % aside)


func _save_if_loaded() -> void:
	if save_path == "":
		return
	var result := save_to_disk()
	if result != OK:
		push_warning("Chiip: could not save the stats to %s (error %d)." % [save_path, result])
