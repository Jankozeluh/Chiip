extends SceneTree
## Tool: writes a "Chiip" game configuration for TrenchBroom (GameConfig.cfg,
## icon and entity definitions), so TrenchBroom can open Chiip's .map files and
## show Chiip's textures. Uses func_godot's TrenchBroom exporter.
##
##     Godot --headless --path . --script res://tools/export_trenchbroom_config.gd -- "<TrenchBroom games folder>/Chiip"
##
## On macOS the games folder is ~/Library/Application Support/TrenchBroom/games.
## Afterwards, in TrenchBroom's Preferences, set Chiip's Game Path to this
## project's folder.


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		printerr("Usage: -- <output folder>")
		quit(1)
		return
	var folder := args[0]
	DirAccess.make_dir_recursive_absolute(folder)

	var config := TrenchBroomGameConfig.new()
	config.game_name = "Chiip"
	config.icon = load("res://icon.svg")
	config.textures_root_folder = "assets/textures"
	config.palette_path = ""
	config.entity_scale = "39.37"

	var icon_image := config.icon.get_image()
	icon_image.resize(32, 32, Image.INTERPOLATE_LANCZOS)
	icon_image.save_png(folder.path_join("icon.png"))

	var file := FileAccess.open(folder.path_join("GameConfig.cfg"), FileAccess.WRITE)
	file.store_string(config._build_class_text())
	file.close()

	var fgd := config.fgd_file.duplicate() as FuncGodotFGDFile
	fgd.do_export_file(FuncGodotFGDFile.FuncGodotTargetMapEditors.TRENCHBROOM, folder)
	print("TrenchBroom game config written to ", folder)
	quit()
