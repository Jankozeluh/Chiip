extends SceneTree
## Tool (M13, D-194): a table of every generated sound's levels, read from the .wav files
## by [SoundLevels]: peak, short-term loudness, length, audible length, the level of its
## last 5 ms and its energy per band. Run from the project folder:
##
##     Godot --headless --path . --quit-after 100 --script res://tools/sound_report.gd [-- <name filter>]

const FOLDER := "res://assets/sounds/"


func _init() -> void:
	var filter := ""
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		filter = args[0]
	print("%-28s %7s %7s %6s %6s %7s  %s" % ["file", "peak", "short", "secs", "aud.", "end", "bands <250 / -1k / -4k / >4k %"])
	for file_name in DirAccess.get_files_at(FOLDER):
		if not file_name.ends_with(".wav") or (filter != "" and not file_name.contains(filter)):
			continue
		var levels := SoundLevels.measure(FOLDER + file_name)
		if levels.is_empty():
			print("%-28s unreadable" % file_name)
			continue
		var bands: PackedFloat32Array = levels.bands
		print("%-28s %7.1f %7.1f %6.2f %6.2f %7.1f  %2d / %2d / %2d / %2d" % [file_name, levels.peak_db,
				levels.short_term_db, levels.seconds, levels.audible_seconds, levels.end_db,
				roundi(bands[0] * 100.0), roundi(bands[1] * 100.0), roundi(bands[2] * 100.0), roundi(bands[3] * 100.0)])
	quit()
