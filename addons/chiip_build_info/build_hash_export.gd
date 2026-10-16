@tool
extends EditorExportPlugin
## Writes the git commit an export is made from into the game's data as
## [code]res://build_hash.txt[/code] ([constant BuildInfo.HASH_FILE]; M16, D-224), without
## touching the project folder. An [EditorExportPlugin] is Godot's hook into exporting, like a
## Unity [code]IPreprocessBuildWithReport[/code]. A folder without git gets "unknown".


func _get_name() -> String:
	return "ChiipBuildInfo"


func _export_begin(_features: PackedStringArray, _is_debug: bool, _path: String, _flags: int) -> void:
	var commit := BuildInfo.git_hash(ProjectSettings.globalize_path("res://"))
	add_file(BuildInfo.HASH_FILE, (commit if not commit.is_empty() else "unknown").to_utf8_buffer(), false)
