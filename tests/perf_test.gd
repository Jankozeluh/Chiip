extends Node
## Performance check: ten animated characters on the test map (M6 task 10). Two modes.
##
## [b]Headless (the automated check).[/b] Run without a window:
##
##     Godot --headless --path . --fixed-fps 128 --quit-after 100000 res://tests/perf_test.tscn
##
## Plays a bots-only 5v5 on the real test map (no player; then team 0 is all bots too) for 20
## seconds of game time (2,560 physics ticks), after one second of settling in that is printed
## but not checked. Rounds are cut to 8 seconds, so that two or three round starts (ten
## respawns, new orders for the bots) fall into the measured time. Every tick is timed from its
## start (the [signal SceneTree.physics_frame] signal) to the start of the frame's process step
## ([signal SceneTree.process_frame]), which covers what the tick costs: every node's physics
## code, the bots, the animation trees and skeletons, and the physics engine's step. The test
## prints the average, the 99th percentile, the maximum and the slowest ticks in milliseconds, and
## checks that there are ten characters, each with a running [AnimationTree], and the limits of
## M11 (D-168): an average tick under 2 ms, 99 ticks in 100 under 3.9 ms (half of a tick's 7.8 ms
## budget), and no tick over 50 ms, round starts included. The play is measured in
## [constant STRETCHES] stretches of [constant PLAY_SECONDS] s, each with at least two round starts,
## and each limit is checked on the median stretch (M16): the times are wall-clock, and a busy
## computer (other suites, a build) can stall one stretch, but not most of them, while a slow part
## of the game shows in every stretch. A
## headless run has a dummy renderer, so this measures the CPU side of the game only. Every random
## number is seeded, so every run plays the same match; the times are real, so they vary a little
## from run to run. Quits with the number of failed checks as the exit code (0 means everything
## passed).
##
## Why not [constant Performance.TIME_PHYSICS_PROCESS]? The engine updates the monitors
## [constant Performance.TIME_PHYSICS_PROCESS] and [constant Performance.TIME_PROCESS] only once
## a second, with the slowest tick (or frame) of that second, so reading them every tick gives the
## same number over and over, and no average or percentile. The test still prints them (once per
## reading) as an upper bound. With [code]--fixed-fps 128[/code] (one tick per frame, no waiting) it
## also times a whole loop iteration, tick and frame together.
##
## [b]Windowed (the frame rate).[/b] Run with a window, and [code]--window[/code] after the
## [code]--[/code] that starts the user arguments:
##
##     Godot --path . --resolution 1920x1080 --quit-after 100000 res://tests/perf_test.tscn -- --window
##
## Adds a camera in a high corner of the map looking at its middle, turns V-Sync off so the
## monitor doesn't cap the frame rate, and plays 15 seconds. Every second after the first three it
## notes [method Engine.get_frames_per_second]; at the end it prints the average, the lowest and
## the list of those. There is no PASS or FAIL for the frame rate, since it depends on the
## computer and its monitor, but the timing checks above still run (with a real renderer, so the
## times include what the skeleton updates cost it), and one more: no shader pipeline was compiled
## in the middle of drawing a frame. No player means nothing captures the mouse.
## The scene quits itself when it is done: keep [code]--quit-after[/code] large, a frame limit
## would cut a fast computer's run short.
##
## Two things can cap the frame rate whatever the V-Sync setting says, so the printout also has
## the CPU work per frame, which no cap hides. On macOS the system compositor presents every
## window in step with the display (the engine's own flag [code]--disable-vsync[/code] says it
## can't override that), so a window reads the monitor's refresh rate, 60 on a 60 Hz one.
## A window that is hidden behind others read a flat 145 FPS in two early runs, which matches the
## engine's 6.9 ms sleep after every frame in that state (as far as I could tell); the test asks for
## the front and prints whether the window is in focus.

const MAP_SCENE := preload("res://maps/test_map.tscn")
## Players on each team: 5v5 is the biggest match the settings allow, ten characters.
const TEAM_SIZE := 5
## Seconds of game time in each measured stretch: at least two round starts (a round lasts at most
## [constant ROUND_SECONDS] plus half a second of freeze time and half a second of round end).
const PLAY_SECONDS := 20.0
## How many stretches are measured; the checks take the median one (M16, against a busy computer).
const STRETCHES := 5
## Seconds of game time that are measured and checked in the windowed run.
const WINDOW_PLAY_SECONDS := 15.0
## How long a live round lasts, so that rounds start a few times during the measured time.
const ROUND_SECONDS := 8.0
## Seconds before the measuring counts: the bodies are built and the first orders planned.
const SETTLE_SECONDS := 1.0
## Seconds into the windowed run before the frame rate is noted (the first seconds load shaders).
const FPS_SKIP_SECONDS := 3.0
## Where the windowed camera stands and what it looks at: a high corner and the middle of the map.
const CAMERA_POSITION := Vector3(-30.0, 25.0, -30.0)
const CAMERA_TARGET := Vector3(0.0, 0.0, 28.0)
## The limits (M11, D-168), from what an Apple M5 measured with a margin of about three for a
## busier computer. A tick's budget is 1 / 128 s = 7.8 ms; the game used 0.6 ms on average,
## 1.0–1.6 ms in 99 ticks of 100, and 17 ms in its slowest tick (a round start, when everyone gets a
## new loadout). Before D-166 the round start took 153 ms: [constant MAX_TICK_MS] catches that.
const MAX_AVERAGE_MS := 2.0
const MAX_P99_MS := 3.9
const MAX_TICK_MS := 50.0
## How many of the slowest ticks are listed, with the round's phase and time when they ran.
const SLOWEST_LISTED := 5

var _map: Node3D
var _rounds: RoundManager
var _failures: int = 0
## True when started with [code]-- --window[/code].
var _windowed: bool = false
var _measuring: bool = false
var _finished: bool = false
## How many physics ticks settle before the measuring counts, and how many are measured.
var _settle_ticks: int = 0
var _play_ticks: int = 0
## When the current tick started, in microseconds, and how many ticks the frame has run so far
## (a slow frame runs several; a fast windowed one none).
var _tick_start_us: int = 0
var _ticks_in_frame: int = 0
## The start of the tick before, for the time of a whole loop iteration (see [member _iteration_ms]).
var _previous_start_us: int = 0
## Milliseconds every tick took (from its start to the start of the next tick or, for the last
## tick of a frame, of the process step), while settling and while measured.
var _settle_ms: Array[float] = []
var _physics_ms: Array[float] = []
## For every measured tick: the round's phase and the seconds left in it ("LIVE 4.2 s").
var _tick_moments: Array[String] = []
## Milliseconds from one tick's start to the next, tick and frame together. Only with
## [code]--fixed-fps[/code] (one tick per frame, no waiting between frames), so not in a windowed run.
var _iteration_ms: Array[float] = []
## The engine's own monitors: each new reading of [constant Performance.TIME_PHYSICS_PROCESS] and
## [constant Performance.TIME_PROCESS], in milliseconds. They change once a second and hold the
## slowest tick (or frame) of that second.
var _monitor_physics_ms: Array[float] = []
var _monitor_process_ms: Array[float] = []
var _last_monitor_physics: float = 0.0
var _last_monitor_process: float = 0.0
## Seconds since the measuring began (frame time, so real time in a windowed run).
var _elapsed: float = 0.0
## Frames per second as the engine reported them, once a second from the start (the trace), and
## the ones after [constant FPS_SKIP_SECONDS] (the samples that count).
var _fps_trace: Array[float] = []
var _fps_samples: Array[float] = []
var _next_fps_sample: float = 1.0
## When the current frame's work began, in microseconds, and the milliseconds from there to the
## start of drawing for every frame (windowed run only): the ticks and the process step, without
## any waiting for the display.
var _frame_start_us: int = 0
var _frame_work_ms: Array[float] = []
## Milliseconds the renderer worked per frame on the CPU and on the GPU (windowed run only).
var _render_cpu_ms: Array[float] = []
var _render_gpu_ms: Array[float] = []


func _ready() -> void:
	_windowed = OS.get_cmdline_user_args().has("--window")
	if _windowed:
		# The monitor must not cap the frame rate, or every computer would measure "60".
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		Engine.max_fps = 0
		# A window hidden behind others read a flat 145 FPS (the engine's 6.9 ms sleep per frame),
		# so ask for the front.
		DisplayServer.window_move_to_foreground()
		# Time the renderer's own work per frame, which no frame limit hides (see _print_frame_rate).
		RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	_map = MAP_SCENE.instantiate()
	_map.get_node("Player").free()
	add_child(_map)
	var settings := MatchSettings.new()
	settings.team_size = TEAM_SIZE
	settings.enemy_team_size = TEAM_SIZE
	settings.freeze_time = 0.5
	settings.round_end_time = 0.5
	# Short rounds, so a few round starts (ten respawns and the bots' new orders) fall into the
	# measured time: those are the heaviest ticks the game has.
	settings.round_time = ROUND_SECONDS
	# Long enough that the match can't end during the test.
	settings.rounds_to_win = 15
	_rounds = RoundManager.new()
	_rounds.settings = settings
	_rounds.rng.seed = 11
	_map.add_child(_rounds)
	if _windowed:
		_add_camera()
	# The match starts at the end of the first frame, in freeze time.
	for i in 2:
		await get_tree().physics_frame
	var participants := _rounds.get_participants()
	for i in participants.size():
		_silence(participants[i])
		(participants[i].get_node("BotController") as BotController).rng.seed = i + 1
		participants[i].weapon.rng.seed = i + 1
	var ticks_per_second := Engine.physics_ticks_per_second
	_settle_ticks = roundi(SETTLE_SECONDS * ticks_per_second)
	_play_ticks = roundi(WINDOW_PLAY_SECONDS * ticks_per_second) if _windowed else roundi(PLAY_SECONDS * ticks_per_second) * STRETCHES
	# The two signals bracket a tick: physics_frame comes first in the tick, process_frame first in
	# the frame's process step, after the last tick of the frame and the physics engine's step.
	get_tree().physics_frame.connect(_on_tick_started)
	get_tree().process_frame.connect(_on_process_step_started)
	if _windowed:
		RenderingServer.frame_pre_draw.connect(_on_drawing_started)
	_measuring = true


func _process(delta: float) -> void:
	if not _measuring or _finished or not _settled():
		return
	_elapsed += delta
	# The first new reading still covers the second before the measuring began (the bodies being
	# built), so it is left out.
	var physics := Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	if physics != _last_monitor_physics:
		if _last_monitor_physics > 0.0:
			_monitor_physics_ms.append(physics)
		_last_monitor_physics = physics
	var process := Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	if process != _last_monitor_process:
		if _last_monitor_process > 0.0:
			_monitor_process_ms.append(process)
		_last_monitor_process = process
	if _windowed:
		var viewport := get_viewport().get_viewport_rid()
		_render_cpu_ms.append(RenderingServer.viewport_get_measured_render_time_cpu(viewport))
		_render_gpu_ms.append(RenderingServer.viewport_get_measured_render_time_gpu(viewport))
	if _windowed and _elapsed >= _next_fps_sample:
		_fps_trace.append(Engine.get_frames_per_second())
		if _next_fps_sample > FPS_SKIP_SECONDS:
			_fps_samples.append(_fps_trace[-1])
		_next_fps_sample += 1.0


func _on_tick_started() -> void:
	if not _measuring or _finished:
		return
	var now := Time.get_ticks_usec()
	if _ticks_in_frame > 0:
		# A slow frame runs several ticks: the one before this ended where this one starts.
		_record_tick((now - _tick_start_us) / 1000.0)
	else:
		_frame_start_us = now
	if not _windowed and _previous_start_us > 0 and _settled():
		_iteration_ms.append((now - _previous_start_us) / 1000.0)
	_previous_start_us = now
	_tick_start_us = now
	_ticks_in_frame += 1


func _on_process_step_started() -> void:
	if not _measuring or _finished:
		return
	if _ticks_in_frame == 0:
		# A frame without a tick: its work starts here.
		_frame_start_us = Time.get_ticks_usec()
		return
	_record_tick((Time.get_ticks_usec() - _tick_start_us) / 1000.0)
	_ticks_in_frame = 0
	if _physics_ms.size() >= _play_ticks:
		_finish()


## The scene is done for this frame and the renderer starts drawing: what the frame cost so far
## is its ticks and its process step. What follows can wait for the display.
func _on_drawing_started() -> void:
	if _measuring and not _finished and _settled() and _frame_start_us > 0:
		_frame_work_ms.append((Time.get_ticks_usec() - _frame_start_us) / 1000.0)
		_frame_start_us = 0


## Files the time of one finished tick under settling or measured.
func _record_tick(milliseconds: float) -> void:
	if _settled():
		_physics_ms.append(milliseconds)
		_tick_moments.append("%s %.1f s" % [RoundManager.Phase.keys()[_rounds.phase], _rounds.time_left])
	else:
		_settle_ms.append(milliseconds)


## True once the settling ticks are over.
func _settled() -> bool:
	return _settle_ms.size() >= _settle_ticks


## Prints the numbers, runs the checks and quits with the number of failures.
func _finish() -> void:
	_finished = true
	var participants := _rounds.get_participants()
	var alive := 0
	var animated := 0
	for character in participants:
		if character.is_alive():
			alive += 1
		var tree := character.body.get_animation_tree()
		if character.body.animated and tree != null and tree.active:
			animated += 1
	var physics := _stats(_physics_ms)
	var stretches := _stretch_stats(1 if _windowed else STRETCHES)
	var budget := 1000.0 / Engine.physics_ticks_per_second
	print("Physics tick: average %.2f ms, 99th percentile %.2f ms, maximum %.2f ms over %d ticks (budget %.2f ms per tick)." % [
			physics.average, physics.p99, physics.maximum, _physics_ms.size(), budget])
	var order := range(_physics_ms.size())
	order.sort_custom(func(a: int, b: int) -> bool: return _physics_ms[a] > _physics_ms[b])
	var slowest: Array[String] = []
	for i: int in order.slice(0, SLOWEST_LISTED):
		slowest.append("%.2f ms (tick %d, %s left)" % [_physics_ms[i], i, _tick_moments[i]])
	print("  The slowest ticks: %s." % ", ".join(slowest))
	print("  Each stretch of %.0f s (the checks take the median): averages %s ms, 99th percentiles %s ms, maxima %s ms." % [
			_physics_ms.size() / float(Engine.physics_ticks_per_second) / stretches.size(),
			_list(stretches, "average"), _list(stretches, "p99"), _list(stretches, "maximum")])
	var settle := _stats(_settle_ms)
	print("  The settling second before it (not checked): average %.2f ms, maximum %.2f ms over %d ticks." % [
			settle.average, settle.maximum, _settle_ms.size()])
	if not _iteration_ms.is_empty():
		var iteration := _stats(_iteration_ms)
		print("Whole loop iteration (tick and frame): average %.2f ms, 99th percentile %.2f ms, maximum %.2f ms over %d frames." % [
				iteration.average, iteration.p99, iteration.maximum, _iteration_ms.size()])
	print("Engine monitors, slowest tick or frame of each second (%d readings): physics %s, process %s." % [
			_monitor_physics_ms.size(), _describe_readings(_monitor_physics_ms), _describe_readings(_monitor_process_ms)])
	print("Characters: %d playing, %d alive, %d with a running animation tree; %d nodes in the game; round %d, score %s." % [
			participants.size(), alive, animated, roundi(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
			_rounds.round_number, _rounds.score])
	if _windowed:
		_print_frame_rate()
	_check("%d characters play, each with a running animation tree" % (TEAM_SIZE * 2),
			participants.size() == TEAM_SIZE * 2 and animated == TEAM_SIZE * 2,
			"%d characters, %d animated" % [participants.size(), animated])
	var average := _median(stretches, "average")
	var p99 := _median(stretches, "p99")
	var maximum := _median(stretches, "maximum")
	_check("The average physics tick takes under %.1f ms (a quarter of a 128 Hz tick; the median stretch)" % MAX_AVERAGE_MS, average < MAX_AVERAGE_MS,
			"median %.2f ms, stretches %s, all %d ticks (%.0f s) %.2f ms" % [average, _list(stretches, "average"), _physics_ms.size(),
					_physics_ms.size() / float(Engine.physics_ticks_per_second), physics.average])
	_check("99 ticks in 100 take under %.1f ms (half a tick; the median stretch)" % MAX_P99_MS, p99 < MAX_P99_MS,
			"median %.2f ms, stretches %s" % [p99, _list(stretches, "p99")])
	_check("No tick takes over %.0f ms, round starts included (the median stretch's slowest)" % MAX_TICK_MS, maximum < MAX_TICK_MS,
			"median %.2f ms, stretches %s" % [maximum, _list(stretches, "maximum")])
	if _windowed:
		var compiled := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_DRAW)
		_check("No shader pipeline is compiled in the middle of drawing a frame (a first-match stutter)", compiled == 0,
				"%d compiled while drawing" % compiled)
	if _failures == 0:
		print("\nAll checks passed.")
	else:
		print("\n%d check(s) FAILED." % _failures)
	get_tree().quit(_failures)


## Prints the frames per second the windowed run saw, and what the renderer drew.
func _print_frame_rate() -> void:
	print("Display: refresh rate %.0f Hz, V-Sync mode %d (0 is disabled), window %s, in focus: %s." % [
			DisplayServer.screen_get_refresh_rate(), DisplayServer.window_get_vsync_mode(), get_window().size,
			DisplayServer.window_is_focused()])
	var trace := _fps_trace.map(func(fps: float) -> String: return "%.0f" % fps)
	print("Frames per second, every second from the start: %s." % ", ".join(trace))
	if _fps_samples.is_empty():
		print("Frame rate: the run was too short to note one (the first sample comes after %.0f s)." % FPS_SKIP_SECONDS)
		return
	var total := 0.0
	var lowest := INF
	for fps in _fps_samples:
		total += fps
		lowest = minf(lowest, fps)
	print("Frame rate after the first %.0f s (V-Sync off in the engine): average %.0f FPS, lowest second %.0f FPS (%d seconds)." % [
			FPS_SKIP_SECONDS, total / _fps_samples.size(), lowest, _fps_samples.size()])
	var render_cpu := _stats(_render_cpu_ms)
	var render_gpu := _stats(_render_gpu_ms)
	print("  The renderer's work per frame, whatever the frame limit: CPU average %.2f ms, 99th percentile %.2f ms, maximum %.2f ms; GPU %s." % [
			render_cpu.average, render_cpu.p99, render_cpu.maximum,
			"not reported by this driver" if render_gpu.maximum == 0.0 else "average %.2f ms, 99th percentile %.2f ms, maximum %.2f ms" % [
					render_gpu.average, render_gpu.p99, render_gpu.maximum]])
	if not _frame_work_ms.is_empty():
		var work := _stats(_frame_work_ms)
		var busy := 0.0
		for milliseconds in _frame_work_ms:
			busy += milliseconds
		for milliseconds in _render_cpu_ms:
			busy += milliseconds
		print("  CPU work per frame without any waiting (the frame's ticks and process step, plus the renderer's CPU time): average %.2f ms, 99th percentile %.2f ms, maximum %.2f ms; the CPU was busy %.0f%% of the %.0f s." % [
				work.average + render_cpu.average, work.p99 + render_cpu.p99, work.maximum + render_cpu.maximum,
				busy / 10.0 / _elapsed, _elapsed])
	print("  The renderer drew %d objects in %d draw calls and %d primitives in the last frame." % [
			roundi(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)),
			roundi(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
			roundi(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))])


# --- Helpers ---


## A camera in a high corner of the map, looking at its middle, and the one the window shows.
func _add_camera() -> void:
	var camera := Camera3D.new()
	camera.name = "OverviewCamera"
	camera.fov = 75.0
	_map.add_child(camera)
	camera.global_position = CAMERA_POSITION
	camera.look_at(CAMERA_TARGET)
	camera.make_current()


## The average, the 99th percentile and the maximum of [param values], as a dictionary with the
## keys [code]average[/code], [code]p99[/code] and [code]maximum[/code] (all 0 for no values).
func _stats(values: Array[float]) -> Dictionary:
	if values.is_empty():
		return {"average": 0.0, "p99": 0.0, "maximum": 0.0}
	var sorted := values.duplicate()
	sorted.sort()
	var total := 0.0
	for value in values:
		total += value
	var rank := clampi(ceili(0.99 * sorted.size()) - 1, 0, sorted.size() - 1)
	return {"average": total / values.size(), "p99": sorted[rank], "maximum": sorted[-1]}


## [method _stats] of each of [param count] equal stretches of the measured ticks, in order.
func _stretch_stats(count: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var length := _physics_ms.size() / count
	for i in count:
		var stretch: Array[float] = []
		stretch.assign(_physics_ms.slice(i * length, (i + 1) * length))
		result.append(_stats(stretch))
	return result


## The median of [param key] over [param stretches] (the middle one of an odd count).
func _median(stretches: Array[Dictionary], key: String) -> float:
	var values: Array[float] = []
	for stats in stretches:
		values.append(stats[key])
	values.sort()
	return values[values.size() / 2]


## "a, b, c": [param key] of every stretch in [param stretches], in milliseconds.
func _list(stretches: Array[Dictionary], key: String) -> String:
	return ", ".join(stretches.map(func(stats: Dictionary) -> String: return "%.2f" % stats[key]))


## "average A, maximum B" for the monitor readings in [param readings] (milliseconds), or "no reading".
func _describe_readings(readings: Array[float]) -> String:
	if readings.is_empty():
		return "no reading"
	var stats := _stats(readings)
	return "average %.2f ms, maximum %.2f ms" % [stats.average, stats.maximum]


## Headless runs have no audio device; sounds that never finish "playing" would
## be reported as leaks when Godot exits.
func _silence(character: Character) -> void:
	character.footstep_sound = null
	if character.weapon != null:
		var data := character.weapon.data.duplicate() as WeaponData
		data.shot_sound = null
		data.dry_fire_sound = null
		data.reload_sound = null
		character.weapon.data = data


func _check(check_name: String, passed: bool, detail: String) -> void:
	print("%s  %s: %s" % ["PASS" if passed else "FAIL", check_name, detail])
	if not passed:
		_failures += 1
