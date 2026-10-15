extends SceneTree
## Tool: measures how fast the real game runs (M8 performance check, D-085).
## Plays a match on a map through main.tscn with V-Sync off and no frame cap,
## lets the bots fight, and reports the frame times once the round is live.
## Run with a window (rendering needs one; it opens briefly):
##
##     Godot --path . --resolution 1920x1080 --disable-vsync --quit-after 20000 --script res://tools/frame_timing.gd -- --map res://maps/depot.tscn
##
## Options after [code]--[/code]: [code]--map <scene>[/code], [code]--seconds <n>[/code]
## (how long to measure, 10 by default), [code]--respawn[/code] (team respawn mode),
## [code]--bots <n>[/code] (players per team, 1–5; 5 = 5v5, the most a match has) and
## [code]--lighting ssao|sdfgi[/code] (the lighting variants of tools/map_screenshots.gd).
## Prints the average frames per second, the slowest 1% of frames, the GPU
## time of the world viewport, and the number of draw calls.
##
## Input is kept away from the game like in tools/map_screenshots.gd: the
## console counts as open and the mouse stays free.

const MapScreenshots := preload("res://tools/map_screenshots.gd")

var _frame_times: Array[float] = []
var _gpu_times: Array[float] = []
## Per frame: CPU milliseconds for scripts and the scene ([code]_process[/code]),
## for physics, and for preparing the world's rendering.
var _process_times: Array[float] = []
var _physics_times: Array[float] = []
var _render_cpu_times: Array[float] = []
var _gpu_frame_times: Array[float] = []


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var seconds := float(_option(args, "--seconds", "10"))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	process_frame.connect(_keep_input_away)
	var main: Node = load("res://main.tscn").instantiate()
	# Measure with the default settings, never the player's file (M5's Settings; a no-op before it exists).
	main.set("load_settings", false)
	var team_size := int(_option(args, "--bots", "3"))
	var settings := MatchSettings.new()
	settings.team_size = team_size
	settings.enemy_team_size = team_size
	if args.has("--respawn"):
		settings.game_mode = MatchSettings.GameMode.TEAM_RESPAWN
	main.set("match_settings", settings)
	root.add_child(main)
	for i in 10:
		await process_frame
	var map: Node = main.call("get_map")
	var lighting := _option(args, "--lighting", "")
	if not lighting.is_empty():
		MapScreenshots.apply_lighting(map, lighting)
	var viewport := main.get_node("World/SubViewport") as SubViewport
	RenderingServer.viewport_set_measure_render_time(viewport.get_viewport_rid(), true)
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	# Wait for the round to go live and the bots to meet.
	var rules := map.get_node_or_null("RespawnMatch") if args.has("--respawn") else map.get_node_or_null("RoundManager")
	var waited := 0.0
	while rules != null and rules.get("phase") != RoundManager.Phase.LIVE and waited < 20.0:
		await process_frame
		waited += 1.0 / maxf(Engine.get_frames_per_second(), 1.0)
	for i in 120:
		await process_frame
	var started := Time.get_ticks_usec()
	var last := started
	while Time.get_ticks_usec() - started < seconds * 1_000_000.0:
		await process_frame
		var now := Time.get_ticks_usec()
		_frame_times.append((now - last) / 1000.0)
		_gpu_times.append(RenderingServer.viewport_get_measured_render_time_gpu(viewport.get_viewport_rid()) + RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()))
		_render_cpu_times.append(RenderingServer.viewport_get_measured_render_time_cpu(viewport.get_viewport_rid()))
		_process_times.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
		_physics_times.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
		_gpu_frame_times.append(RenderingServer.get_frame_setup_time_cpu())
		last = now
	_report(args, viewport)
	quit()


func _report(args: PackedStringArray, viewport: SubViewport) -> void:
	var sorted := _frame_times.duplicate()
	sorted.sort()
	var total := 0.0
	for time in _frame_times:
		total += time
	var average := total / _frame_times.size()
	var slowest: Array = sorted.slice(int(sorted.size() * 0.99))
	var low := 0.0
	for time in slowest:
		low += time
	low /= maxf(slowest.size(), 1.0)
	var gpu := _mean(_gpu_times)
	var draw_calls := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	print("RESULT %s %s%s %dv%d world %dx%d: %.0f fps average (%.2f ms), slowest 1%%: %.2f ms (%.0f fps); CPU per frame: process %.2f ms, physics %.2f ms, world render %.2f ms, frame setup %.2f ms; world GPU %.2f ms (0 = not reported); %d draw calls, %d frames" % [
			_option(args, "--map", "test map").get_file(), "respawn " if args.has("--respawn") else "",
			_option(args, "--lighting", "realtime"), int(_option(args, "--bots", "3")), int(_option(args, "--bots", "3")),
			viewport.size.x, viewport.size.y, 1000.0 / average, average, low, 1000.0 / low,
			_mean(_process_times), _mean(_physics_times), _mean(_render_cpu_times), _mean(_gpu_frame_times), gpu, draw_calls, _frame_times.size()])


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
