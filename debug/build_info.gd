class_name BuildInfo
extends RefCounted
## The game's version and build, and the computer it runs on (M16, D-224): what the main menu's
## footer, the pause menu, the log's first line and a bug report show. The version is
## [code]application/config/version[/code] in project.godot; the build is the git commit it was
## made from, which an export writes into the game as [constant HASH_FILE]
## (addons/chiip_build_info, an [EditorExportPlugin]); the editor's build asks git, and says
## "unknown" without it. A plain class with static functions (tools can use it; no autoload).

## The commit an exported build was made from, added to the game's data by the export plugin.
const HASH_FILE := "res://build_hash.txt"

static var _hash: String = ""
static var _logged: bool = false


## The version, e.g. "0.1.1".
static func get_version() -> String:
	return str(ProjectSettings.get_setting("application/config/version", ""))


## The short git commit of the build, e.g. "26776e1", or "unknown".
static func get_build_hash() -> String:
	if _hash.is_empty():
		if FileAccess.file_exists(HASH_FILE):
			_hash = FileAccess.get_file_as_string(HASH_FILE).strip_edges()
		elif OS.has_feature("editor"):
			_hash = git_hash(ProjectSettings.globalize_path("res://"))
		if _hash.is_empty():
			_hash = "unknown"
	return _hash


## The version and build in one, e.g. "0.1.1 (26776e1)".
static func describe() -> String:
	return "%s (%s)" % [get_version(), get_build_hash()]


## The system, its version, the processor and its architecture, e.g.
## "macOS 26.0, Apple M5, arm64".
static func get_platform() -> String:
	return "%s %s, %s, %s" % [OS.get_name(), OS.get_version(), OS.get_processor_name(), Engine.get_architecture_name()]


## The engine and how it draws, e.g. "Godot 4.7.2.stable, forward_plus on Apple M5 (Metal)".
static func get_engine() -> String:
	var adapter := RenderingServer.get_video_adapter_name()
	var api := RenderingServer.get_video_adapter_api_version()
	return "Godot %s, %s%s" % [Engine.get_version_info()["string"],
			ProjectSettings.get_setting("rendering/renderer/rendering_method", "?"),
			"" if adapter.is_empty() else " on %s (%s)" % [adapter, api]]


## Prints the log's first line once per run: "Chiip 0.1.1 (26776e1) · macOS … · Godot …". The
## main menu and main.gd call it at startup (whichever comes first).
static func log_startup() -> void:
	if _logged:
		return
	_logged = true
	print("Chiip %s · %s · %s · started %s" % [describe(), get_platform(), get_engine(), Time.get_datetime_string_from_system()])


## The short commit of the git checkout at [param folder], or "" (no git, not a checkout). Used by
## the editor's build and by the export plugin.
static func git_hash(folder: String) -> String:
	var output: Array = []
	if OS.execute("git", ["-C", folder, "rev-parse", "--short", "HEAD"], output, true) != 0 or output.is_empty():
		return ""
	return str(output[0]).strip_edges()
