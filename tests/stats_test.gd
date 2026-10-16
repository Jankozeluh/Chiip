extends Node
## Automated checks for the stats (M14, D-200, D-201). Run without a window:
##
##     Godot --headless --path . --fixed-fps 128 --quit-after 60000 res://tests/stats_test.tscn
##
## The maths (K/D, ADR, HS %, accuracy per weapon and per zone, wins per mode and map) against
## numbers worked out by hand; the lifetime totals against the sum of the matches; the history file:
## a book written by one instance loads into another with the same numbers, a missing file, garbage,
## the wrong shape and a newer version fall back to an empty book (the file kept aside, never lost),
## one bad match inside a good file is skipped, damaged numbers are cleaned, the history is capped
## while the totals keep counting, personal bests keep only the best, and the CSV export. Tests run on
## `user://test_stats.json` (deleted afterwards): the last check makes sure the real `user://stats.json`
## and the shared book were never touched. Quits with the number of failed checks as the exit code.

const TEMP_PATH := "user://test_stats.json"
const BAD_PATH := "user://test_stats.json.bad"
const CSV_PATH := "user://test_stats.csv"
## A date inside StatsMatch's valid range (2026-10-16).
const DATE := 1_792_000_000

var _failures: int = 0
var _real_file_md5: String = ""


func _ready() -> void:
	_real_file_md5 = _real_md5()
	_cleanup()
	_test_math()
	_test_weapon()
	_test_match_and_totals()
	_test_cleaning()
	_test_saving()
	_test_damaged_files()
	_test_history_cap()
	_test_bests()
	_test_csv()
	_test_real_file_untouched()
	_cleanup()
	if _failures == 0:
		print("\nAll checks passed.")
	else:
		print("\n%d check(s) FAILED." % _failures)
	get_tree().quit(_failures)


# --- The maths ---


func _test_math() -> void:
	_check("K/D is kills over deaths, and a match without a death shows its kills",
			is_equal_approx(StatsMath.kill_death_ratio(15, 10), 1.5) and is_equal_approx(StatsMath.kill_death_ratio(7, 0), 7.0)
			and is_equal_approx(StatsMath.kill_death_ratio(0, 0), 0.0), "15/10, 7/0, 0/0")
	_check("ADR is damage over rounds, nothing without rounds; ratio and percent are 0 over 0",
			is_equal_approx(StatsMath.average_damage_per_round(1500.0, 20), 75.0)
			and StatsMath.average_damage_per_round(100.0, 0) == 0.0
			and StatsMath.ratio(3.0, 0.0) == 0.0 and is_equal_approx(StatsMath.percent(1.0, 4.0), 25.0), "1500/20")
	_check("Cleaning turns anything into a safe value: counts clamp and drop NaN, text is cut",
			StatsMath.clean_count(-5) == 0 and StatsMath.clean_count(12.9) == 12 and StatsMath.clean_count("x", 3) == 3
			and StatsMath.clean_count(NAN, 2) == 2 and StatsMath.clean_count(INF, 2) == 2
			and StatsMath.clean_count(1e30) == StatsMath.MAX_COUNT
			and StatsMath.clean_number(-1.0) == 0.0 and StatsMath.clean_number(null, 1.5) == 1.5
			and StatsMath.clean_text("x".repeat(500)).length() == StatsMath.MAX_TEXT and StatsMath.clean_text(5, "no") == "no",
			"counts, numbers, text")


func _test_weapon() -> void:
	var rifle := StatsWeapon.new()
	rifle.add_shots(30)
	for zone: int in [Hitbox.Zone.HEAD, Hitbox.Zone.HEAD, Hitbox.Zone.CHEST, Hitbox.Zone.CHEST, Hitbox.Zone.CHEST,
			Hitbox.Zone.STOMACH, Hitbox.Zone.ARMS, Hitbox.Zone.LEGS]:
		rifle.add_hit(zone)
	_check("A weapon's accuracy is hits over shots and its zones add up to its hits",
			rifle.shots == 30 and rifle.hits == 8 and is_equal_approx(rifle.accuracy(), 8.0 / 30.0)
			and rifle.zone_hits("head") == 2 and rifle.zone_hits("chest") == 3 and rifle.zone_hits("stomach") == 1
			and rifle.zone_hits("arms") == 1 and rifle.zone_hits("legs") == 1 and is_equal_approx(rifle.head_share(), 0.25)
			and is_equal_approx(rifle.zone_share("chest"), 3.0 / 8.0), "accuracy %.3f" % rifle.accuracy())
	_check("Zone names follow the hit zones, and a zone that doesn't exist counts as a hit without a zone",
			StatsWeapon.zone_name(Hitbox.Zone.HEAD) == "head" and StatsWeapon.zone_name(Hitbox.Zone.LEGS) == "legs"
			and StatsWeapon.zone_name(99) == "" and StatsWeapon.ZONES.size() == Hitbox.Zone.size(), "head, legs")
	var other := StatsWeapon.new()
	other.add_shots(10)
	other.add_hit(Hitbox.Zone.HEAD)
	other.add(rifle)
	_check("Adding weapons adds shots, hits and zones", other.shots == 40 and other.hits == 9 and other.zone_hits("head") == 3, "40 shots, 9 hits")
	# A shotgun's nine pellets are nine bullets: one trigger pull can't make accuracy go over 100 %.
	var shotgun := StatsWeapon.new()
	shotgun.add_shots(9)
	for pellet in 9:
		shotgun.add_hit(Hitbox.Zone.CHEST)
	_check("A shotgun shot counts its nine pellets: 9 of 9 is 100 %", is_equal_approx(shotgun.accuracy(), 1.0), "%.2f" % shotgun.accuracy())


# --- Matches and totals ---


func _make_match(mode: String, map: String, result: String, kills: int, deaths: int, damage: float, rounds: int,
		shots: int, hits: int, headshots: int = 0, weapon: String = "rifle") -> StatsMatch:
	var record := StatsMatch.new()
	record.date = DATE
	record.mode = mode
	record.map = map
	record.result = result
	record.rounds = rounds
	record.duration = 600.0
	record.kills = kills
	record.deaths = deaths
	record.damage = damage
	record.headshot_kills = headshots
	var gun := StatsWeapon.new()
	gun.add_shots(shots)
	for hit in hits:
		gun.add_hit(Hitbox.Zone.HEAD if hit < headshots else Hitbox.Zone.CHEST)
	record.weapons[weapon] = gun
	return record


func _test_match_and_totals() -> void:
	var first := _make_match(StatsMatch.MODE_ROUNDS, "depot", StatsMatch.WIN, 12, 8, 1500.0, 20, 200, 60, 4)
	var second := _make_match(StatsMatch.MODE_RESPAWN, "square", StatsMatch.LOSS, 20, 25, 3000.0, 0, 400, 100, 5, "smg")
	var third := _make_match(StatsMatch.MODE_ROUNDS, "depot", StatsMatch.DRAW, 6, 6, 500.0, 10, 100, 30, 1)
	_check("A match's own numbers: K/D, ADR (none without rounds), HS % and accuracy",
			is_equal_approx(first.kd(), 1.5) and is_equal_approx(first.adr(), 75.0) and second.adr() < 0.0
			and is_equal_approx(first.hs_percent(), 100.0 * 4.0 / 12.0) and is_equal_approx(first.accuracy(), 0.3),
			"K/D %.2f, ADR %.1f, HS %.1f %%, accuracy %.2f" % [first.kd(), first.adr(), first.hs_percent(), first.accuracy()])
	var totals := StatsTotals.new()
	for record in [first, second, third]:
		totals.add_match(record)
	_check("The totals add the matches: results, kills, deaths, damage, headshot kills",
			totals.matches == 3 and totals.wins == 1 and totals.losses == 1 and totals.draws == 1
			and totals.kills == 38 and totals.deaths == 39 and is_equal_approx(totals.damage, 5000.0)
			and totals.headshot_kills == 10 and is_equal_approx(totals.kd(), 38.0 / 39.0)
			and is_equal_approx(totals.hs_percent(), 100.0 * 10.0 / 38.0) and is_equal_approx(totals.win_percent(), 100.0 / 3.0),
			"%d matches, %d-%d, K/D %.3f" % [totals.matches, totals.kills, totals.deaths, totals.kd()])
	_check("Lifetime ADR counts only the round matches (2000 damage over 30 rounds), not the respawn one",
			totals.rounds == 30 and is_equal_approx(totals.round_damage, 2000.0) and is_equal_approx(totals.adr(), 2000.0 / 30.0),
			"ADR %.2f" % totals.adr())
	_check("The totals keep the accuracy of every weapon on its own, and overall",
			totals.weapons["rifle"].shots == 300 and totals.weapons["rifle"].hits == 90 and totals.weapons["smg"].shots == 400
			and is_equal_approx(totals.weapons["smg"].accuracy(), 0.25) and is_equal_approx(totals.accuracy(), 190.0 / 700.0),
			"rifle %.2f, smg %.2f, all %.3f" % [totals.weapons["rifle"].accuracy(), totals.weapons["smg"].accuracy(), totals.accuracy()])
	_check("Wins are counted per mode and per map, next to the matches played",
			StatsTotals.played_in(totals.modes, "rounds") == 2 and StatsTotals.won_in(totals.modes, "rounds") == 1
			and StatsTotals.played_in(totals.modes, "respawn") == 1 and StatsTotals.won_in(totals.modes, "respawn") == 0
			and StatsTotals.played_in(totals.maps, "depot") == 2 and StatsTotals.won_in(totals.maps, "depot") == 1
			and StatsTotals.played_in(totals.maps, "square") == 1 and StatsTotals.played_in(totals.maps, "nowhere") == 0,
			"depot 1 of 2")
	# The dictionary form comes back the same, through real JSON (which turns every number into a float).
	var back := StatsTotals.from_dict(JSON.parse_string(JSON.stringify(totals.to_dict())))
	_check("Totals survive being written as JSON and read back",
			back != null and back.matches == 3 and back.kills == 38 and is_equal_approx(back.damage, 5000.0)
			and back.weapons["smg"].hits == 100 and StatsTotals.won_in(back.maps, "depot") == 1
			and back.weapons["rifle"].zone_hits("head") == 5, "round trip")
	var record_back := StatsMatch.from_dict(JSON.parse_string(JSON.stringify(first.to_dict())))
	_check("A match survives being written as JSON and read back",
			record_back != null and record_back.mode == "rounds" and record_back.map == "depot" and record_back.result == "win"
			and record_back.kills == 12 and record_back.rounds == 20 and record_back.date == DATE
			and record_back.weapons["rifle"].hits == 60, "round trip")


func _test_cleaning() -> void:
	var wild := StatsMatch.from_dict({
		"date": DATE, "mode": "rounds", "result": "win", "map": 12, "kills": -4, "deaths": "many", "damage": -50.0,
		"headshot_kills": 99, "rounds": NAN, "weapons": {"rifle": {"shots": 10, "hits": 50, "zones": {"head": 5, "tail": 7}}, "": {}, "bad": 3},
	})
	_check("Damaged numbers are cleaned: negatives and text become 0, hits never exceed shots, headshots never exceed kills, unknown zones go",
			wild != null and wild.kills == 0 and wild.deaths == 0 and wild.damage == 0.0 and wild.headshot_kills == 0 and wild.rounds == 0
			and wild.map == "" and wild.weapons.size() == 1 and wild.weapons["rifle"].hits == 10
			and wild.weapons["rifle"].zone_hits("head") == 5 and not wild.weapons["rifle"].zones.has("tail"),
			"%s" % str(wild.to_dict() if wild != null else null))
	var refused := 0
	for bad: Variant in [null, 5, "x", [], {}, {"date": DATE}, {"date": DATE, "mode": "rounds"}, {"date": 5, "mode": "rounds", "result": "win"},
			{"date": DATE, "mode": "chess", "result": "win"}, {"date": DATE, "mode": "rounds", "result": "won"}]:
		if StatsMatch.from_dict(bad) == null:
			refused += 1
	_check("Things that aren't a match a game could have written are refused (no date, an unknown mode or result, not a dictionary)",
			refused == 10, "%d of 10 refused" % refused)


# --- The file ---


func _test_saving() -> void:
	var book := StatsBook.new()
	_check("A new book is empty and doesn't save: nothing loaded it", not book.is_loaded() and book.history.is_empty()
			and book.save_to_disk() == ERR_UNCONFIGURED, "not loaded")
	book.add_match(_make_match(StatsMatch.MODE_ROUNDS, "depot", StatsMatch.WIN, 12, 8, 1500.0, 20, 200, 60, 4))
	book.add_match(_make_match(StatsMatch.MODE_RESPAWN, "square", StatsMatch.LOSS, 20, 25, 3000.0, 0, 400, 100, 5, "smg"))
	_check("Adding a match to a book that was never loaded writes no file", not FileAccess.file_exists(TEMP_PATH) and book.history.size() == 2,
			"2 matches in memory")
	_check("A missing file is no error: an empty book that saves there from now on",
			book.load_from_disk(TEMP_PATH) == ERR_FILE_NOT_FOUND and book.is_loaded() and book.history.is_empty() and book.lifetime.matches == 0,
			"empty")
	var first := _make_match(StatsMatch.MODE_ROUNDS, "depot", StatsMatch.WIN, 12, 8, 1500.0, 20, 200, 60, 4)
	book.add_match(first)
	book.submit_best("aim_flick", 4200.0, {"hits": 31})
	_check("A loaded book saves the moment something is added", FileAccess.file_exists(TEMP_PATH), "file written")
	_check("A temporary file is never left behind", not FileAccess.file_exists(TEMP_PATH + ".tmp"), "no .tmp")
	var other := StatsBook.new()
	var result := other.load_from_disk(TEMP_PATH)
	_check("A book written by one instance loads into another with the same history, totals and bests",
			result == OK and other.history.size() == 1 and other.history[0].kills == 12 and other.history[0].map == "depot"
			and other.lifetime.matches == 1 and other.lifetime.kills == 12 and other.lifetime.weapons["rifle"].hits == 60
			and is_equal_approx(other.get_best_score("aim_flick"), 4200.0) and int(other.get_best("aim_flick")["hits"]) == 31,
			"%d matches, best %.0f" % [other.history.size(), other.get_best_score("aim_flick")])


func _test_damaged_files() -> void:
	# Garbage, not JSON.
	_write(TEMP_PATH, "this is not json {{{")
	var book := StatsBook.new()
	var result := book.load_from_disk(TEMP_PATH)
	_check("A file that isn't JSON gives an empty book, and is kept aside as .bad",
			result == ERR_PARSE_ERROR and book.history.is_empty() and book.lifetime.matches == 0
			and FileAccess.file_exists(BAD_PATH) and not FileAccess.file_exists(TEMP_PATH)
			and FileAccess.get_file_as_string(BAD_PATH) == "this is not json {{{", "kept: %s" % FileAccess.file_exists(BAD_PATH))
	book.add_match(_make_match(StatsMatch.MODE_RESPAWN, "square", StatsMatch.WIN, 3, 2, 400.0, 0, 20, 8))
	var again := StatsBook.new()
	_check("After the fallback the book saves a fresh file that loads fine",
			again.load_from_disk(TEMP_PATH) == OK and again.history.size() == 1, "%d match" % again.history.size())
	# The wrong shape, and a version from a newer game.
	for text: String in ["[1, 2, 3]", "{}", "{\"version\": 1}", "{\"version\": 1, \"history\": 5}", "{\"version\": 99, \"history\": []}",
			"{\"version\": \"one\", \"history\": []}", "null"]:
		_write(TEMP_PATH, text)
		var odd := StatsBook.new()
		var code := odd.load_from_disk(TEMP_PATH)
		_check("The file '%s' isn't a book of this version: an empty book, the file kept aside" % text,
				code == ERR_PARSE_ERROR and odd.history.is_empty() and FileAccess.file_exists(BAD_PATH), "code %d" % code)
		DirAccess.remove_absolute(BAD_PATH)
	# One bad match inside a good file is skipped; the rest stays.
	var good := _make_match(StatsMatch.MODE_ROUNDS, "depot", StatsMatch.WIN, 10, 5, 1000.0, 15, 100, 30).to_dict()
	var later := good.duplicate()
	later["date"] = DATE + 1000
	_write(TEMP_PATH, JSON.stringify({"version": 1, "history": [later, {"date": "never"}, 7, good], "lifetime": "gone"}))
	var partial := StatsBook.new()
	_check("One bad match is skipped, the good ones stay (in date order), and missing totals are counted again from them",
			partial.load_from_disk(TEMP_PATH) == OK and partial.history.size() == 2 and partial.history[0].date == DATE
			and partial.history[1].date == DATE + 1000 and partial.lifetime.matches == 2 and partial.lifetime.kills == 20,
			"%d matches, lifetime %d" % [partial.history.size(), partial.lifetime.matches])
	_check("A good file is not set aside", not FileAccess.file_exists(BAD_PATH), "no .bad")
	DirAccess.remove_absolute(TEMP_PATH)


func _test_history_cap() -> void:
	var book := StatsBook.new()
	for index in StatsBook.MAX_HISTORY + 5:
		var record := _make_match(StatsMatch.MODE_RESPAWN, "square", StatsMatch.WIN, 1, 1, 10.0, 0, 2, 1)
		record.date = DATE + index
		book.add_match(record)
	_check("The history keeps the newest %d matches while the lifetime totals count all of them" % StatsBook.MAX_HISTORY,
			book.history.size() == StatsBook.MAX_HISTORY and book.history[0].date == DATE + 5
			and book.history[-1].date == DATE + StatsBook.MAX_HISTORY + 4 and book.lifetime.matches == StatsBook.MAX_HISTORY + 5
			and book.lifetime.kills == StatsBook.MAX_HISTORY + 5, "%d kept, %d counted" % [book.history.size(), book.lifetime.matches])
	book.clear()
	_check("Clearing empties the history, the totals and the bests", book.history.is_empty() and book.lifetime.matches == 0
			and book.training.is_empty(), "empty")


func _test_bests() -> void:
	var book := StatsBook.new()
	var changes: Array = [0]
	book.changed.connect(func() -> void: changes[0] += 1)
	var first := book.submit_best("aim_flick", 100.0, {"hits": 5})
	var lower := book.submit_best("aim_flick", 90.0, {"hits": 9})
	var equal := book.submit_best("aim_flick", 100.0, {"hits": 6})
	var higher := book.submit_best("aim_flick", 150.0, {"hits": 7})
	_check("Only a better score replaces a personal best (a first result, then a higher one; not a lower or an equal one)",
			first and not lower and not equal and higher and is_equal_approx(book.get_best_score("aim_flick"), 150.0)
			and int(book.get_best("aim_flick")["hits"]) == 7 and changes[0] == 2, "best %.0f" % book.get_best_score("aim_flick"))
	_check("Another key has its own best, and an unknown key has none",
			book.submit_best("aim_flick_smg", 10.0) and book.get_best_score("aim_flick_smg") == 10.0 and book.get_best("nothing").is_empty()
			and book.get_best_score("nothing") == 0.0 and book.get_best("aim_flick")["date"] > 0, "own keys")
	_write(TEMP_PATH, JSON.stringify({"version": 1, "history": [], "training": {"ok": {"score": 5, "date": 0, "hits": 2, "text": "no"}, "no_score": {"hits": 1}, "bad": 7, "": {"score": 1}}}))
	var read := StatsBook.new()
	read.load_from_disk(TEMP_PATH)
	_check("Bests read from a file keep what is a number and drop what isn't (and entries without a score)",
			read.training.size() == 1 and read.get_best_score("ok") == 5.0 and int(read.get_best("ok")["hits"]) == 2
			and not read.get_best("ok").has("text"), "%s" % str(read.training))
	DirAccess.remove_absolute(TEMP_PATH)


func _test_csv() -> void:
	var book := StatsBook.new()
	book.add_match(_make_match(StatsMatch.MODE_ROUNDS, "depot", StatsMatch.WIN, 12, 8, 1500.0, 20, 200, 60, 4))
	book.add_match(_make_match(StatsMatch.MODE_RESPAWN, "square", StatsMatch.LOSS, 20, 25, 3000.0, 0, 400, 100, 5, "smg"))
	var code := book.export_csv(CSV_PATH)
	var lines := FileAccess.get_file_as_string(CSV_PATH).strip_edges().split("\n")
	var header := lines[0].split(",") if lines.size() > 0 else PackedStringArray()
	var row := lines[1].split(",") if lines.size() > 1 else PackedStringArray()
	var respawn := lines[2].split(",") if lines.size() > 2 else PackedStringArray()
	_check("The CSV export has a header and a row per match; ADR is empty without rounds",
			code == OK and lines.size() == 3 and header[0] == "date" and header.size() == row.size()
			and row[1] == "rounds" and row[2] == "depot" and row[3] == "win" and row[8] == "12" and row[12] == "75.0"
			and respawn[12] == "" and respawn[14] == "25.0", "%d lines" % lines.size())
	DirAccess.remove_absolute(CSV_PATH)


func _test_real_file_untouched() -> void:
	var now := _real_md5()
	_check("The tests never touched your real stats file or the shared book",
			now == _real_file_md5 and not StatsBook.get_instance().is_loaded(), "checksum before '%s', after '%s'" % [_real_file_md5, now])


# --- Helpers ---


func _real_md5() -> String:
	return FileAccess.get_md5(StatsBook.PATH) if FileAccess.file_exists(StatsBook.PATH) else ""


func _write(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _cleanup() -> void:
	for path in [TEMP_PATH, TEMP_PATH + ".tmp", BAD_PATH, CSV_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


func _check(check_name: String, passed: bool, detail: String) -> void:
	print("%s  %s: %s" % ["PASS" if passed else "FAIL", check_name, detail])
	if not passed:
		_failures += 1
