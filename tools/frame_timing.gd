extends SceneTree
## Tool: measures how fast the real game runs (M8 performance check D-085, M11 D-165).
## Plays a match on a map through main.tscn with V-Sync off and no frame cap,
## lets the bots fight, and reports the frame times once the round is live.
## Run with a window (rendering needs one; it opens briefly):
##
##     Godot --path . --resolution 1920x1080 --disable-vsync --quit-after 40000 --script res://tools/frame_timing.gd -- --map res://maps/depot.tscn --bots 5
##
## Options after [code]--[/code]: [code]--map <scene>[/code], [code]--seconds <n>[/code]
## (how long to measure, 10 by default), [code]--respawn[/code] (team respawn mode), [code]--ffa[/code]
## (free-for-all, M17: [code]--bots 5[/code] is ten players, everyone against everyone),
## [code]--bots <n>[/code] (players per team, 1–5; 5 = 5v5, the most a match has) and
## [code]--lighting ssao|sdfgi[/code] (the lighting variants of tools/map_screenshots.gd), and
## [code]--spike <ms>[/code] (the spike threshold), and [code]--vsync[/code], which keeps V-Sync on as the game's settings do (then the frame rate is the
## display's, and a frame over [constant SPIKE_MS] is one that missed a refresh at 120 Hz). Without
## it, V-Sync is off; on macOS the frame is then sometimes held while the system waits for the
## display, which shows as spikes in "draw" that a player with V-Sync on never gets.
##
## [b]Online[/b] ([code]--lan[/code]): this game hosts through the main menu's lobby and starts a
## second, headless game that joins it over the network on this computer, so the frame times are
## a LAN host's with one friend in the match. The menu reads its own shortcuts, so they go on the
## command line too, and the map and mode get options of their own ([code]--map[/code] and
## [code]--respawn[/code] would make the menu start an offline match):
## [code]-- --lan res://maps/depot.tscn [--lan-respawn | --lan-ffa] --host --start 2 --no-settings --port 28777[/code].
## Online, the report adds the host's own network numbers (the console's [code]net_stats[/code]).
## The match setup (map, mode, team sizes) is set on the shared settings, which a run with
## [code]--no-settings[/code] never saves.
##
## Prints one RESULT line: the average frames per second, the slowest 1% of frames, and for each
## part of a frame its average and 99th percentile in milliseconds: the physics ticks (the
## [code]_physics_process[/code] code, the bots, the animation trees and the physics step), the
## scripts and the scene ([code]_process[/code], the HUD), drawing (preparing and handing the frame
## to the GPU; on macOS this also waits for the display, so it's not only the GPU's time), and the
## rest of the loop (input, audio, waiting). Then the number of draw calls, and the SPIKES: every
## frame over [constant SPIKE_MS], with its parts, the round's phase and how many nodes and
## resources were added since the frame before (a jump means something was built or loaded).
##
## [b]Without a window[/b] ([code]--headless --fixed-fps 128[/code]) it times the CPU side only, as
## fast as the computer can run: ten seconds then cover about a minute of game time, and the
## spikes (say [code]--spike 3[/code]) show which moments of a match cost the most.
##
## Input is kept away from the game like in tools/map_screenshots.gd: the
## console counts as open and the mouse stays free.

const MapScreenshots := preload("res://tools/map_screenshots.gd")
## The CPU's budget for one frame at 120 Hz: physics and scripts together over it make a frame
## late whatever the GPU does (counted as "CPU over").
const CPU_BUDGET_MS := 8.33
## A frame slower than this is listed as a spike (one and a half frames at 120 Hz); --spike changes it.
const SPIKE_MS := 12.5
## At most this many spikes are listed (all of them are counted).
const MAX_SPIKES_LISTED := 25

## Per measured frame, in milliseconds: the whole frame and its parts (see the doc comment).
var _frame_ms: Array[float] = []
var _physics_ms: Array[float] = []
var _process_ms: Array[float] = []
var _draw_ms: Array[float] = []
var _other_ms: Array[float] = []
var _draw_calls: Array[float] = []
var _spikes: Array[String] = []
var _spike_count: int = 0
var _spike_ms: float = SPIKE_MS
var _recording: bool = false
var _started_us: int = 0
## Where the current loop iteration's parts began, in microseconds.
var _physics_begin_us: int = 0
var _process_begin_us: int = 0
var _draw_begin_us: int = 0
var _last_draw_end_us: int = 0
var _headless: bool = false
var _ticks_in_frame: int = 0
var _frame_ticks: int = 0
var _frame_physics_ms: float = 0.0
var _frame_process_ms: float = 0.0
var _last_nodes: int = 0
var _last_resources: int = 0
var _rules: Node
## What was added to the tree since the last frame: scene files, or classes and names.
var _added: Array[String] = []
var _client_pid: int = 0
## The renderer's pipeline compilation counts when the measuring began (see [method _compilations]).
var _compilations_at_start: Dictionary = {}


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var seconds := float(_option(args, "--seconds", "10"))
	_spike_ms = float(_option(args, "--spike", str(SPIKE_MS)))
	# V-Sync off by default, to see how many frames the computer could draw; --vsync keeps it on
	# like the game's default setting, to count the frames that miss the display's refresh.
	if not args.has("--vsync"):
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	process_frame.connect(_keep_input_away)
	var team_size := int(_option(args, "--bots", "3"))
	var main: Node
	if args.has("--lan"):
		main = await _start_online(args, team_size)
		if main == null:
			print("RESULT online: the match didn't start")
			quit(1)
			return
	else:
		main = load("res://main.tscn").instantiate()
		# Measure with the default settings, never the player's file (M5's Settings; a no-op before it exists).
		main.set("load_settings", false)
		var settings := MatchSettings.new()
		settings.team_size = team_size
		settings.enemy_team_size = team_size
		if args.has("--respawn"):
			settings.game_mode = MatchSettings.GameMode.TEAM_RESPAWN
		elif args.has("--ffa"):
			settings.game_mode = MatchSettings.GameMode.FREE_FOR_ALL
		main.set("match_settings", settings)
		root.add_child(main)
	for i in 10:
		await process_frame
	# A covered window is slowed down by macOS: ask for the front (the report says if it got it).
	DisplayServer.window_move_to_foreground()
	var map: Node = main.call("get_map")
	var lighting := _option(args, "--lighting", "")
	if not lighting.is_empty():
		MapScreenshots.apply_lighting(map, lighting)
	var viewport := main.get_node("World/SubViewport") as SubViewport
	# Wait for the round to go live and the bots to meet. Real time: the engine's frame rate reads
	# about 1 while the map loads, which made the M8 version stop waiting at once and measure the
	# freeze time.
	# The rules: a RoundManager, or one of its kinds (RespawnMatch, FreeForAllMatch).
	for child in map.get_children():
		if child is RoundManager:
			_rules = child
			break
	var wait_until := Time.get_ticks_msec() + 40_000
	while _rules != null and _rules.get("phase") != RoundManager.Phase.LIVE and Time.get_ticks_msec() < wait_until:
		await process_frame
	var meet_at := Time.get_ticks_msec() + 2_000
	while Time.get_ticks_msec() < meet_at:
		await process_frame
	physics_frame.connect(_on_physics_frame)
	process_frame.connect(_on_process_frame)
	_headless = DisplayServer.get_name() == "headless"
	if _headless:
		# No drawing without a window (and no draw signals): a frame ends with its scripts.
		var frame_end := FrameEnd.new()
		frame_end.on_end = _on_scripts_done
		frame_end.process_priority = 1_000_000
		frame_end.process_mode = Node.PROCESS_MODE_ALWAYS
		root.add_child(frame_end)
	else:
		RenderingServer.frame_pre_draw.connect(_on_pre_draw)
		RenderingServer.frame_post_draw.connect(_on_post_draw)
	_started_us = Time.get_ticks_usec()
	_last_draw_end_us = _started_us
	_last_nodes = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	_last_resources = int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))
	node_added.connect(_on_node_added)
	_compilations_at_start = _compilations()
	_recording = true
	while Time.get_ticks_usec() - _started_us < seconds * 1_000_000.0:
		await process_frame
	_recording = false
	print("PLAYERS: %d characters in the match" % Character.all_in_world(main.call("get_map")).size())
	var session: Object = main.get("net_session")
	if session != null:
		print("ONLINE: %d players in the session" % session.call("get_players").size())
		var net_game: Object = main.call("get_net_game") if main.has_method("get_net_game") else null
		if net_game != null and net_game.has_method("get_net_stats_lines"):
			for line: String in net_game.call("get_net_stats_lines"):
				print("NET: " + line)
	_report(args, viewport)
	if _client_pid > 0:
		OS.kill(_client_pid)
	quit()


## Hosts through the main menu (which reads --host, --start and --port itself), starts a headless
## game that joins, and returns the game's main node once its map is in, or null after a minute.
func _start_online(args: PackedStringArray, team_size: int) -> Node:
	var settings := Settings.get_instance()
	settings.match_team_size = team_size
	settings.match_enemy_team_size = team_size
	settings.set_value(&"match_mode", "respawn" if args.has("--lan-respawn") else "ffa" if args.has("--lan-ffa") else "rounds")
	settings.set_value(&"match_map", _option(args, "--lan", Settings.DEFAULT_MATCH_MAP))
	settings.set_value(&"match_rotation", false)
	change_scene_to_file(GameLaunch.MENU_SCENE)
	var seconds := float(_option(args, "--seconds", "10"))
	_client_pid = OS.create_process(OS.get_executable_path(), ["--headless", "--path",
			ProjectSettings.globalize_path("res://"), "--max-fps", "128",
			"--quit-after", str(int((seconds + 90.0) * 128.0)), "--", "--no-settings", "--join", "127.0.0.1",
			"--name", "Client", "--port", _option(args, "--port", "28777")])
	var waited := 0
	while waited < 60_000:
		await process_frame
		waited = Time.get_ticks_msec()
		var scene := current_scene
		if scene != null and scene.has_method("get_map") and scene.call("get_map") != null:
			return scene
	return null


## Runs after every other node's [code]_process[/code] (a high priority runs last): the end of a
## frame's scripts in a run without a window.
class FrameEnd extends Node:
	var on_end: Callable

	func _process(_delta: float) -> void:
		on_end.call()


func _on_physics_frame() -> void:
	if _ticks_in_frame == 0:
		_physics_begin_us = Time.get_ticks_usec()
	_ticks_in_frame += 1


func _on_process_frame() -> void:
	_process_begin_us = Time.get_ticks_usec()
	_frame_ticks = _ticks_in_frame
	_frame_physics_ms = (_process_begin_us - _physics_begin_us) / 1000.0 if _ticks_in_frame > 0 else 0.0
	_ticks_in_frame = 0


func _on_pre_draw() -> void:
	_draw_begin_us = Time.get_ticks_usec()
	_frame_process_ms = (_draw_begin_us - _process_begin_us) / 1000.0


func _on_scripts_done() -> void:
	_draw_begin_us = Time.get_ticks_usec()
	_frame_process_ms = (_draw_begin_us - _process_begin_us) / 1000.0
	_on_post_draw()


func _on_post_draw() -> void:
	var now := Time.get_ticks_usec()
	# The first frame after the start began before the hooks were connected: not counted.
	if not _recording or _frame_ms.is_empty() and _last_draw_end_us == _started_us:
		_last_draw_end_us = now
		return
	var frame := (now - _last_draw_end_us) / 1000.0
	var draw := (now - _draw_begin_us) / 1000.0
	var other := maxf(frame - _frame_physics_ms - _frame_process_ms - draw, 0.0)
	_frame_ms.append(frame)
	_physics_ms.append(_frame_physics_ms)
	_process_ms.append(_frame_process_ms)
	_draw_ms.append(draw)
	_other_ms.append(other)
	_draw_calls.append(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
	var nodes := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var resources := int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))
	if frame > _spike_ms:
		_spike_count += 1
		if _spikes.size() < MAX_SPIKES_LISTED:
			_spikes.append("  %6.2f s: %5.1f ms = physics %.1f (%d ticks) + scripts %.1f + draw %.1f + rest %.1f; %s; nodes %+d, resources %+d" % [
					(now - _started_us) / 1_000_000.0, frame, _frame_physics_ms, _frame_ticks, _frame_process_ms,
					draw, other, _phase_name(), nodes - _last_nodes, resources - _last_resources])
			if not _added.is_empty():
				_spikes.append("           added: " + ", ".join(_added))
	_added.clear()
	_last_nodes = nodes
	_last_resources = resources
	_last_draw_end_us = now


func _on_node_added(node: Node) -> void:
	var what := node.scene_file_path.get_file() if not node.scene_file_path.is_empty() else "%s %s" % [node.get_class(), node.name]
	if _added.size() < 8 and not _added.has(what):
		_added.append(what)


func _phase_name() -> String:
	if _rules == null or not "phase" in _rules:
		return "no rules"
	var phase: int = _rules.get("phase")
	return RoundManager.Phase.keys()[phase] if phase >= 0 and phase < RoundManager.Phase.size() else str(phase)


func _report(args: PackedStringArray, viewport: SubViewport) -> void:
	var average := _mean(_frame_ms)
	var low := _slowest_percent(_frame_ms)
	var mode := "lan " if args.has("--lan") else ""
	if args.has("--respawn") or args.has("--lan-respawn"):
		mode += "respawn"
	elif args.has("--ffa") or args.has("--lan-ffa"):
		mode += "ffa"
	else:
		mode += "rounds"
	mode += " vsync" if args.has("--vsync") else ""
	print("RESULT %s %s %s %dv%d world %dx%d: %.0f fps average (%.2f ms), slowest 1%%: %.2f ms (%.0f fps); per frame, average / 99th percentile: physics %.2f / %.2f ms, scripts %.2f / %.2f ms, draw %.2f / %.2f ms, rest %.2f / %.2f ms; %.0f draw calls, %d frames, %d over %.1f ms" % [
			_option(args, "--lan", _option(args, "--map", "test map")).get_file(), mode, _option(args, "--lighting", "realtime"),
			int(_option(args, "--bots", "3")), int(_option(args, "--bots", "3")),
			viewport.size.x, viewport.size.y, 1000.0 / average, average, low, 1000.0 / low,
			_mean(_physics_ms), _percentile(_physics_ms, 0.99), _mean(_process_ms), _percentile(_process_ms, 0.99),
			_mean(_draw_ms), _percentile(_draw_ms, 0.99), _mean(_other_ms), _percentile(_other_ms, 0.99),
			_mean(_draw_calls), _frame_ms.size(), _spike_count, _spike_ms])
	var cpu: Array[float] = []
	var cpu_over := 0
	for i in _frame_ms.size():
		cpu.append(_physics_ms[i] + _process_ms[i])
		if cpu[i] > CPU_BUDGET_MS:
			cpu_over += 1
	print("CPU (physics and scripts) per frame: average %.2f ms, 99th percentile %.2f ms, worst %.2f ms; %d frames over %.2f ms" % [
			_mean(cpu), _percentile(cpu, 0.99), cpu.max() if not cpu.is_empty() else 0.0, cpu_over, CPU_BUDGET_MS])
	var compiled := _compilations()
	var lines: Array[String] = []
	for key: String in compiled:
		lines.append("%s %d (%+d while measured)" % [key, compiled[key], compiled[key] - _compilations_at_start.get(key, 0)])
	print("PIPELINES compiled since the start: " + ", ".join(lines))
	if not _headless:
		print("WINDOW: in focus at the end %s, display %.0f Hz, V-Sync mode %d (0 is off)" % [
				"yes" if DisplayServer.window_is_focused() else "NO (the numbers may be throttled)",
				DisplayServer.screen_get_refresh_rate(), DisplayServer.window_get_vsync_mode()])
	print("SPIKES (%d, the first %d):" % [_spike_count, mini(_spike_count, MAX_SPIKES_LISTED)])
	for line in _spikes:
		print(line)


## The renderer's counts of compiled pipelines (Godot 4.4+). "draw" ones were compiled in the
## middle of drawing a frame, which stalls it the first time on a computer (until the shader
## caches have it): the stutter a first match can have. The others happen in the background or
## while loading.
func _compilations() -> Dictionary:
	return {
		"draw": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_DRAW),
		"specialization": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_SPECIALIZATION),
		"surface": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_SURFACE),
		"mesh": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_MESH),
		"canvas": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_CANVAS),
	}


## The average of the slowest 1% of [param values].
func _slowest_percent(values: Array[float]) -> float:
	var sorted := values.duplicate()
	sorted.sort()
	var slowest: Array = sorted.slice(int(sorted.size() * 0.99))
	var total := 0.0
	for value: float in slowest:
		total += value
	return total / maxf(slowest.size(), 1.0)


func _percentile(values: Array[float], fraction: float) -> float:
	if values.is_empty():
		return 0.0
	var sorted := values.duplicate()
	sorted.sort()
	return sorted[mini(int(sorted.size() * fraction), sorted.size() - 1)]


func _mean(values: Array[float]) -> float:
	var total := 0.0
	for value in values:
		total += value
	return total / maxf(values.size(), 1.0)


func _option(args: PackedStringArray, name: String, default: String) -> String:
	var index := args.find(name)
	return args[index + 1] if index >= 0 and index + 1 < args.size() else default


func _keep_input_away() -> void:
	DevConsole.is_open = true
	if Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
