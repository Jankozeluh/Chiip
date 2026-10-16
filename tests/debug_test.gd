extends Node
## Automated checks of M16's tools for finding bugs (D-222 to D-229). Run without a window:
##
##     Godot --headless --path . --fixed-fps 128 --quit-after 100000 res://tests/debug_test.tscn
##
## Logs and bug reports (D-224): the version and build ([BuildInfo]) and where they show (the main
## menu's footer, the pause menu's), the engine's rotating log file in user://logs (project
## settings), the export plugin that writes the build into exports, "Report a bug" (the zip's files,
## the settings without the online address, the home folder's path left out, old reports pruned)
## from the pause menu and the console, and the GitHub issue template. Reports go to a folder of the
## test's own, deleted afterwards. The console's debug commands (D-225): debug_hitboxes draws every
## zone of every body in its zone's colour and lists them ("no hit zones" for an empty body, v0.1.0's
## bug), and stops again; debug_perf shows the frame-time graph for this run only; net_stats gives ping,
## loss and snapshot size on a host and a client (a session in this process, tests/net_harness.gd), and
## debug_hitboxes is refused online. Quits with the number of failed checks as the exit code.

const MAIN_SCENE := preload("res://main.tscn")
const MENU_SCENE := preload("res://ui/main_menu.tscn")
const PAUSE_SCENE := preload("res://ui/pause_menu.tscn")
## The test's own report folder ([member BugReport.folder]); deleted at the end.
const REPORT_FOLDER := "user://test_bug_reports"
const NET_MAP := preload("res://maps/test_map.tscn")

var _failures: int = 0


func _ready() -> void:
	Weapon.silent = true
	BugReport.folder = REPORT_FOLDER
	_clear_reports()
	_test_build_info()
	_test_log_settings()
	_test_bug_report()
	_test_issue_template()
	await _test_pause_menu_footer()
	await _test_main_menu_footer()
	await _test_fallback_map()
	await _test_in_game()
	await _test_online()
	_clear_reports()
	BugReport.folder = BugReport.FOLDER
	if _failures == 0:
		print("\nAll checks passed.")
	else:
		print("\n%d check(s) FAILED." % _failures)
	get_tree().quit(_failures)


# --- Logs and bug reports (D-224) ---


func _test_build_info() -> void:
	var commit := BuildInfo.get_build_hash()
	_check("The version is project.godot's and the build is this checkout's git commit",
			BuildInfo.get_version() == ProjectSettings.get_setting("application/config/version")
					and commit.length() >= 7 and commit.is_valid_hex_number()
					and BuildInfo.describe() == "%s (%s)" % [BuildInfo.get_version(), commit],
			BuildInfo.describe())
	var plugins: PackedStringArray = ProjectSettings.get_setting("editor_plugins/enabled", PackedStringArray())
	var exporter := FileAccess.get_file_as_string("res://addons/chiip_build_info/build_hash_export.gd")
	_check("An export plugin writes the build into every export (enabled in project.godot)",
			plugins.has("res://addons/chiip_build_info/plugin.cfg") and exporter.contains("add_file(BuildInfo.HASH_FILE")
					and exporter.contains("_export_begin"), "%s" % [plugins])
	_check("The computer and the engine are described for the log and the report",
			BuildInfo.get_platform().begins_with(OS.get_name()) and BuildInfo.get_engine().begins_with("Godot 4."),
			"%s · %s" % [BuildInfo.get_platform(), BuildInfo.get_engine()])


func _test_log_settings() -> void:
	_check("The game writes a log file per run in user://logs, keeping the last five, each line written at once",
			ProjectSettings.get_setting("debug/file_logging/enable_file_logging") == true
					and ProjectSettings.get_setting("debug/file_logging/log_path") == "user://logs/godot.log"
					and ProjectSettings.get_setting("debug/file_logging/max_log_files") == 5
					and ProjectSettings.get_setting("application/run/flush_stdout_on_print") == true, "")
	BuildInfo.log_startup()
	var log_text := FileAccess.get_file_as_string("user://logs/godot.log")
	_check("This run's log starts with the version, the build and the computer",
			log_text.contains("Chiip %s · %s" % [BuildInfo.describe(), BuildInfo.get_platform()]),
			"%d characters in user://logs/godot.log" % log_text.length())


func _test_bug_report() -> void:
	var settings := Settings.get_instance()
	var address := settings.online_address
	settings.online_address = "100.101.102.103"
	var recent := settings.online_recent
	settings.online_recent = RecentHosts.remember("", "100.101.102.104", 26000, "Anna")
	print("A line that names the address 100.101.102.103 and the folder %s" % OS.get_environment("HOME"))
	var path := BugReport.create(PackedStringArray(["Game: a test at 100.101.102.103"]))
	var files := _zip_files(path)
	_check("A bug report is one zip in the user folder: info.txt, settings.cfg and this run's log",
			path.begins_with(REPORT_FOLDER + "/chiip-bug-%s-" % BuildInfo.get_version()) and path.ends_with(".zip")
					and files.has("info.txt") and files.has("settings.cfg") and files.has("logs/godot.log"),
			"%s: %s" % [path, files.keys()])
	var info: String = files.get("info.txt", "")
	_check("info.txt has the version, the build, the computer, the engine, the screen and the game",
			info.contains("Version: %s" % BuildInfo.describe()) and info.contains("Platform: %s" % BuildInfo.get_platform())
					and info.contains("Engine: Godot") and info.contains("Screen: ") and info.contains("Game: a test at"),
			info.replace("\n", " | "))
	var config := ConfigFile.new()
	var parsed := config.parse(files.get("settings.cfg", ""))
	_check("settings.cfg is the settings the game uses, as the settings file holds them, without the online address and the recent hosts",
			parsed == OK and config.get_value("online", "address", "") == BugReport.REMOVED and config.get_value("online", "recent", "") == BugReport.REMOVED
					and config.get_value("game", "sensitivity", -1.0) == settings.sensitivity and config.has_section("controls"),
			"parse %d, address %s" % [parsed, config.get_value("online", "address", "?")])
	var everything := "".join(files.values())
	var home := OS.get_environment("HOME")
	_check("Nothing in the report names the online address or the home folder (an issue is public)",
			not everything.contains("100.101.102.103") and not everything.contains("100.101.102.104") and (home.length() < 2 or not everything.contains(home))
					and String(files.get("logs/godot.log", "")).contains("names the address (removed) and the folder ~"),
			"")
	settings.online_address = address
	settings.online_recent = recent
	# Old reports are pruned: the oldest go first.
	for i in BugReport.KEEP + 2:
		var old := FileAccess.open(REPORT_FOLDER.path_join("chiip-bug-0.0.0-2000-01-%02d-000000.zip" % (i + 1)), FileAccess.WRITE)
		old.close()
	var newest := BugReport.create()
	var kept := DirAccess.get_files_at(REPORT_FOLDER)
	_check("At most %d reports are kept, the oldest deleted first" % BugReport.KEEP,
			kept.size() == BugReport.KEEP and kept.has(newest.get_file()) and not kept.has("chiip-bug-0.0.0-2000-01-01-000000.zip"),
			"%d kept" % kept.size())


func _test_issue_template() -> void:
	var template := FileAccess.get_file_as_string("res://.github/ISSUE_TEMPLATE/bug_report.md")
	_check("The GitHub issue template asks for steps, the build, the system and the bug report zip",
			template.begins_with("---\nname: Bug report") and template.contains("Steps to reproduce")
					and template.contains("Build:") and template.contains("System:") and template.contains("Report a bug")
					and template.contains("bug_report") and template.contains(".zip"), "%d characters" % template.length())


func _test_pause_menu_footer() -> void:
	var menu := PAUSE_SCENE.instantiate() as PauseMenu
	add_child(menu)
	await get_tree().process_frame
	var pressed := [0]
	menu.bug_report_pressed.connect(func() -> void: pressed[0] += 1)
	menu.open()
	var button := menu.get_bug_report_button()
	button.pressed.emit()
	menu.show_bug_report_result(true)
	var saved_text := button.text
	menu.close()
	menu.open()
	_check("The pause menu's footer shows the build and \"Report a bug\", which asks main.gd for a report and says it was saved",
			menu.get_build_label().text == "Build %s" % BuildInfo.describe() and pressed[0] == 1
					and saved_text.begins_with("Report saved") and button.text == PauseMenu.BUG_REPORT_TEXT
					and button.theme_type_variation == &"TextButton" and menu.get_build_label().theme_type_variation == &"MuteLabel",
			"%s; %s, then %s" % [menu.get_build_label().text, saved_text, button.text])
	menu.close()
	get_tree().paused = false
	menu.queue_free()
	await get_tree().process_frame


func _test_main_menu_footer() -> void:
	var menu := MENU_SCENE.instantiate()
	menu.load_settings = false
	add_child(menu)
	await get_tree().process_frame
	var label := menu.get_node("%Build") as Label
	_check("The main menu's footer shows the build", label.text == "Build %s · Divocakos" % BuildInfo.describe(), label.text)
	remove_child(menu)
	menu.queue_free()
	await get_tree().process_frame


## The game scene with nothing choosing a map (as `-- --match` starts it) plays the fallback map. A
## preload of it in main.gd came back empty once `Main` had a class (a load cycle, M16).
func _test_fallback_map() -> void:
	GameLaunch.clear()
	var main := MAIN_SCENE.instantiate() as Main
	main.load_settings = false
	main.loading_screen = false
	add_child(main)
	for i in 5:
		await get_tree().physics_frame
	var map := main.get_map()
	_check("The game scene started without a map choice plays the fallback map, with its player",
			map != null and map.scene_file_path == Main.FALLBACK_MAP and main.get_player() != null,
			map.scene_file_path if map != null else "no map")
	remove_child(main)
	main.queue_free()
	await get_tree().process_frame


func _test_in_game() -> void:
	GameLaunch.start_practice(Settings.DEFAULT_MAP, GameLaunch.difficulty_named("normal"))
	var main := MAIN_SCENE.instantiate()
	main.load_settings = false
	main.loading_screen = false
	add_child(main)
	for i in 30:
		await get_tree().physics_frame
	var console := main.get_node("DevConsole") as DevConsole
	var before := DirAccess.get_files_at(REPORT_FOLDER).size()
	console.run("bug_report")
	var after := Array(DirAccess.get_files_at(REPORT_FOLDER))
	after.sort()
	var files := _zip_files(REPORT_FOLDER.path_join(after[-1])) if not after.is_empty() else {}
	_check("The console's bug_report saves a report with the game in it and says where",
			console.get_command_names().has("bug_report") and (after.size() > before or after.size() == BugReport.KEEP)
					and String(files.get("info.txt", "")).contains("Game: practice on %s" % Settings.DEFAULT_MAP)
					and console.get_output_text().contains("Bug report saved: "),
			String(files.get("info.txt", "")).get_slice("Game:", 1).strip_edges())
	main.get_pause_menu().open()
	main.get_pause_menu().get_bug_report_button().pressed.emit()
	_check("The pause menu's \"Report a bug\" in the game saves one and says so",
			main.get_pause_menu().get_bug_report_button().text.begins_with("Report saved"),
			main.get_pause_menu().get_bug_report_button().text)
	main.get_pause_menu().close()
	get_tree().paused = false
	await _test_debug_hitboxes(main, console)
	await _test_debug_perf(main, console)
	console.run("net_stats")
	_check("net_stats offline says it needs a game online", console.get_output_text().ends_with("Not online. Multiplayer is in the main menu."), "")
	remove_child(main)
	main.queue_free()
	GameLaunch.clear()
	await get_tree().process_frame


# --- Debug commands (D-225) ---


func _test_debug_hitboxes(main: Node, console: DevConsole) -> void:
	console.run("bot_add normal enemy")
	for i in 20:
		await get_tree().physics_frame
	var map: Node = main.get_map()
	var bots := Character.all_in_world(map).filter(func(c: Character) -> bool: return c != main.get_player())
	console.run("debug_hitboxes")
	await get_tree().process_frame
	var debug := map.get_node_or_null(HitboxDebug.NODE_NAME) as HitboxDebug
	var wires: Array[MeshInstance3D] = debug.get_wires() if debug != null else []
	var shapes := 0
	var colours_right := true
	for bot: Character in bots:
		for hitbox in bot.body.get_hitboxes():
			for child in hitbox.get_children():
				if child is CollisionShape3D:
					shapes += 1
					var wire := child.get_node_or_null(HitboxDebug.WIRE_NAME) as MeshInstance3D
					if wire == null or (wire.material_override as StandardMaterial3D).albedo_color != Color(HitboxDebug.ZONE_COLORS[hitbox.zone], HitboxDebug.WIRE_ALPHA) \
							or not (wire.material_override as StandardMaterial3D).no_depth_test or not wire.visible:
						colours_right = false
	var output := console.get_output_text()
	_check("debug_hitboxes draws every zone of every bot in its zone's colour, through walls, and lists them",
			not bots.is_empty() and shapes >= 6 * bots.size() and wires.size() == shapes and colours_right
					and output.contains("Hit zones drawn") and output.contains("%s: %d zones (head " % [bots[0].name, shapes / bots.size()]),
			"%d bots, %d shapes, %d wires" % [bots.size(), shapes, wires.size()])
	# A body that lost its zones (v0.1.0's export) is named in the list.
	var bot: Character = bots[0]
	var saved := {}
	for hitbox in bot.body.get_hitboxes():
		var shape := hitbox.get_node("Shape") as CollisionShape3D
		saved[shape] = shape.shape
		shape.shape = null
	var empty := HitboxDebug.describe([bot] as Array[Character])
	for shape: CollisionShape3D in saved:
		shape.shape = saved[shape]
	_check("A body without hit zones is listed as \"no hit zones\" (what v0.1.0's builds would have shown)",
			empty.size() == 1 and empty[0] == "%s: no hit zones" % bot.name, "%s" % [empty])
	console.run("debug_hitboxes")
	await get_tree().process_frame
	var left := 0
	for wire in wires:
		if is_instance_valid(wire) and not wire.is_queued_for_deletion():
			left += 1
	_check("debug_hitboxes again hides them: the node and every wire are gone",
			map.get_node_or_null(HitboxDebug.NODE_NAME) == null and left == 0 and console.get_output_text().ends_with("Hit zones hidden."),
			"%d wires left" % left)


func _test_debug_perf(main: Node, console: DevConsole) -> void:
	var overlay: DebugOverlay = main.get_debug_overlay()
	var saved := Settings.get_instance().fps_counter
	console.run("debug_perf")
	await get_tree().process_frame
	var shown := overlay.get_mode() == "developer" and overlay.get_graph().is_visible_in_tree()
	var printed := console.get_output_text().get_slice("\n", console.get_output_text().count("\n"))
	console.run("debug_perf")
	await get_tree().process_frame
	_check("debug_perf shows the frame-time graph (F3's developer panel) and the engine's timings; again hides it; the F3 setting stays",
			shown and printed.begins_with("Frame ") and printed.contains("physics tick") and printed.contains("draw calls")
					and overlay.get_mode() == ("off" if saved == "developer" else saved) and Settings.get_instance().fps_counter == saved,
			printed)


## A host and a client in this process (as the network suites do): net_stats on both, and
## debug_hitboxes refused online.
func _test_online() -> void:
	var harness := NetHarness.new()
	add_child(harness)
	var host_session := harness.start_host("Host", "Host")
	var client_session := harness.start_client("Client", "Jan")
	var games: Array[Node] = []
	if await harness.wait_until(client_session.is_active):
		var rules := MatchSettings.new()
		rules.team_size = 1
		rules.enemy_team_size = 1
		games.append(harness.start_game(host_session.get_parent(), host_session, NET_MAP, rules))
		await harness.wait_ticks(10)
		games.append(harness.start_game(client_session.get_parent(), client_session, NET_MAP, rules))
		for game in games:
			harness.silence(game.get_player())
		var client := games[1].get_net_game() as NetClient
		await harness.wait_until(func() -> bool: return client.is_welcomed() and client.snapshot_rate > 0.0, 900)
	if games.size() < 2:
		_check("A host and a client start a match for the online checks", false, "the client didn't join")
	else:
		var lines: Array[String] = []
		for game in games:
			var console := game.get_node("DevConsole") as DevConsole
			console.run("net_stats")
			lines.append(console.get_output_text())
		var host := games[0].get_net_game() as NetHost
		var client := games[1].get_net_game() as NetClient
		_check("net_stats on the host: each friend's ping and the snapshots' size",
				host.snapshot_bytes > 20 and lines[0].contains("Hosting: 1 friend(s)") and lines[0].contains("Jan")
						and lines[0].contains("Snapshot   %d B" % host.snapshot_bytes),
				lines[0].get_slice("net_stats", 1).strip_edges().replace("\n", " | "))
		_check("net_stats on the client: ping, loss and the size of the snapshots it receives (the host's)",
				client.snapshot_bytes > 20 and lines[1].contains("Ping ") and lines[1].contains("Loss ")
						and lines[1].contains("Snapshot   %d B" % client.snapshot_bytes) and absi(client.snapshot_bytes - host.snapshot_bytes) < 64,
				lines[1].get_slice("net_stats", 1).strip_edges().replace("\n", " | "))
		var client_console := games[1].get_node("DevConsole") as DevConsole
		client_console.run("debug_hitboxes")
		_check("debug_hitboxes is refused online (it would show everyone through walls)",
				client_console.get_output_text().ends_with("debug_hitboxes only works offline.")
						and games[1].get_map().get_node_or_null(HitboxDebug.NODE_NAME) == null, "")
	for game in games:
		game.get_parent().remove_child(game)
		game.queue_free()
	for session in [client_session, host_session]:
		if is_instance_valid(session):
			session.close()
	remove_child(harness)
	harness.queue_free()
	for i in 5:
		await get_tree().physics_frame


# --- Helpers ---


## The files in the zip at [param path] as name → text ({} if it can't be read).
func _zip_files(path: String) -> Dictionary:
	var files := {}
	var zip := ZIPReader.new()
	if path.is_empty() or zip.open(path) != OK:
		return files
	for file_name in zip.get_files():
		files[file_name] = zip.read_file(file_name).get_string_from_utf8()
	zip.close()
	return files


func _clear_reports() -> void:
	if not DirAccess.dir_exists_absolute(REPORT_FOLDER):
		return
	for file_name in DirAccess.get_files_at(REPORT_FOLDER):
		DirAccess.remove_absolute(REPORT_FOLDER.path_join(file_name))
	DirAccess.remove_absolute(REPORT_FOLDER)


func _check(check_name: String, passed: bool, detail: String) -> void:
	print("%s  %s: %s" % ["PASS" if passed else "FAIL", check_name, detail])
	if not passed:
		_failures += 1
