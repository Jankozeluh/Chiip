class_name BugReport
extends RefCounted
## "Report a bug" (M16, D-224): packs what a bug report needs into one zip in the user folder, for
## the player to attach to a GitHub issue (.github/ISSUE_TEMPLATE/bug_report.md): this run's log
## and the one before it (from [constant LOG_FOLDER], where the engine writes them), the version and
## build ([BuildInfo]), the computer and screen, what was being played and the settings. An issue is
## public, so the online address is left out of the settings and the logs, and the home folder's
## path is shortened to "~". The pause menu's "Report a bug" and the console's
## [code]bug_report[/code] make one and open its folder.

## Where the reports go.
const FOLDER := "user://bug_reports"
## Where the engine writes its log files (project.godot, debug/file_logging; one per run, the last
## five kept).
const LOG_FOLDER := "user://logs"
## The log of the run that is going on.
const CURRENT_LOG := "godot.log"
## How many reports are kept; the oldest go first.
const KEEP := 10
## What stands in the report instead of the online address.
const REMOVED := "(removed)"

## Where [method create] writes: [constant FOLDER]; tests point it at a folder of their own.
static var folder: String = FOLDER


## Packs a report into [member folder] and returns its path
## ([code]user://bug_reports/chiip-bug-<version>-<date>.zip[/code]),
## or "" if it couldn't be written. [param context]: lines about the game (map, mode, online) that
## go into info.txt.
static func create(context: PackedStringArray = PackedStringArray()) -> String:
	DirAccess.make_dir_recursive_absolute(folder)
	var stamp := Time.get_datetime_string_from_system().replace(":", "").replace("T", "-")
	var path := folder.path_join("chiip-bug-%s-%s.zip" % [BuildInfo.get_version(), stamp])
	var zip := ZIPPacker.new()
	var result := zip.open(path)
	if result != OK:
		push_warning("Chiip: the bug report couldn't be written to %s (error %d)." % [path, result])
		return ""
	_add(zip, "info.txt", info_text(context))
	_add(zip, "settings.cfg", settings_text())
	for log_path in latest_logs():
		_add(zip, "logs/" + log_path.get_file(), scrub(FileAccess.get_file_as_string(log_path)))
	zip.close()
	_prune()
	print("Chiip: bug report saved to %s" % scrub(ProjectSettings.globalize_path(path)))
	return path


## Shows the report at [param path] in the system's file manager (Finder, Explorer); not in a
## headless run.
static func show_in_folder(path: String) -> void:
	if DisplayServer.get_name() != "headless":
		OS.shell_show_in_file_manager(ProjectSettings.globalize_path(path))


## The text of info.txt: version, build, computer, engine, screen and [param context].
static func info_text(context: PackedStringArray = PackedStringArray()) -> String:
	var screen := DisplayServer.screen_get_size()
	var window := DisplayServer.window_get_size()
	var lines := PackedStringArray([
		"Chiip bug report",
		"Version: %s" % BuildInfo.describe(),
		"Platform: %s" % BuildInfo.get_platform(),
		"Engine: %s" % BuildInfo.get_engine(),
		"Screen: %d x %d at %.0f Hz, window %d x %d%s" % [screen.x, screen.y, DisplayServer.screen_get_refresh_rate(),
				window.x, window.y, ", fullscreen" if DisplayServer.window_get_mode() >= DisplayServer.WINDOW_MODE_FULLSCREEN else ""],
		"Language: %s" % OS.get_locale(),
		"Made: %s" % Time.get_datetime_string_from_system(),
	])
	for line in context:
		lines.append(scrub(line))
	return "\n".join(lines) + "\n"


## The settings the game uses now, as the settings file holds them, without the online address.
static func settings_text() -> String:
	var config := Settings.get_instance().to_config()
	config.set_value("online", "address", REMOVED)
	return config.encode_to_text()


## This run's log and the newest one before it, if they exist (oldest first).
static func latest_logs() -> PackedStringArray:
	var found := PackedStringArray()
	var older := Array(DirAccess.get_files_at(LOG_FOLDER)).filter(
			func(file: String) -> bool: return file.get_extension() == "log" and file != CURRENT_LOG)
	older.sort()
	if not older.is_empty():
		found.append(LOG_FOLDER.path_join(older[-1]))
	if FileAccess.file_exists(LOG_FOLDER.path_join(CURRENT_LOG)):
		found.append(LOG_FOLDER.path_join(CURRENT_LOG))
	return found


## [param text] without the home folder's path ("~" instead) and the online address.
static func scrub(text: String) -> String:
	var home := OS.get_environment("USERPROFILE") if OS.get_name() == "Windows" else OS.get_environment("HOME")
	if home.length() > 1:
		text = text.replace(home, "~")
	var address := Settings.get_instance().online_address
	if not address.is_empty() and address != "127.0.0.1" and address != "localhost":
		text = text.replace(address, REMOVED)
	return text


static func _add(zip: ZIPPacker, file_name: String, text: String) -> void:
	zip.start_file(file_name)
	zip.write_file(text.to_utf8_buffer())
	zip.close_file()


## Deletes the oldest reports beyond [constant KEEP].
static func _prune() -> void:
	var reports := Array(DirAccess.get_files_at(folder)).filter(func(file: String) -> bool: return file.get_extension() == "zip")
	reports.sort()
	for i in maxi(reports.size() - KEEP, 0):
		DirAccess.remove_absolute(folder.path_join(reports[i]))
