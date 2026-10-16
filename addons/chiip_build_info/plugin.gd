@tool
extends EditorPlugin
## Adds [code]build_hash_export.gd[/code] to the editor's exports (M16, D-224). Enabled in
## project.godot ([code]editor_plugins/enabled[/code]), so a headless
## [code]--export-release[/code] uses it too.

var _export_plugin: EditorExportPlugin


func _enter_tree() -> void:
	_export_plugin = preload("res://addons/chiip_build_info/build_hash_export.gd").new()
	add_export_plugin(_export_plugin)


func _exit_tree() -> void:
	remove_export_plugin(_export_plugin)
	_export_plugin = null
