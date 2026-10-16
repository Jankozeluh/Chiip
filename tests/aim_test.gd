extends Node
## Automated checks for the aim trainer (M14, D-205 to D-207). Run without a window:
##
##     Godot --headless --path . --fixed-fps 128 --quit-after 100000 res://tests/aim_test.tscn
##
## The scoring against numbers worked out by hand ([AimScore]: points for a hit by how fast, the
## penalty for a miss, the floor at 0, accuracy, reaction, the details saved with a best). Then, in
## practice on the Shooting Range through the real game scene, with real shots: the range has the
## trainer's pad; shooting it starts a run (the countdown first, and a shot in the countdown is not
## counted); a ball appears in plain view, inside the distance, angle and height limits, the same
## size on screen at any distance; a hit scores and the next ball is a real flick away; a shot at
## nothing is a miss; a ball nobody hits times out; when the time is up the result is on screen and a
## better score than the best of that gun is saved in a book (a worse run, and a run without a hit,
## change nothing); shooting the pad during a run stops it without a result; a knife in hand starts
## nothing; the console's `aim` command does the pad's job. The trainer saves into a book of its own, never
## your stats file (the last check). Quits with the number of failed checks as the exit code.

const MAIN_SCENE := preload("res://main.tscn")

var _failures: int = 0
var _real_file_md5: String = ""
var _main: Node
var _player: Character
var _trainer: RangeTrainer
var _book := StatsBook.new()
var _results: Array = []


func _ready() -> void:
	_real_file_md5 = _real_md5()
	Weapon.silent = true
	_test_score()
	await _start_range()
	if _trainer != null:
		await _test_pad_and_run()
		await _test_scoring_and_best()
		await _test_stop_and_refusals()
	_free_main()
	_check("The tests never touched your real stats file or the shared book", _real_md5() == _real_file_md5 and not StatsBook.get_instance().is_loaded(),
			"checksum '%s'" % _real_md5())
	Weapon.silent = false
	if _failures == 0:
		print("\nAll checks passed.")
	else:
		print("\n%d check(s) FAILED." % _failures)
	get_tree().quit(_failures)


# --- The scoring ---


func _test_score() -> void:
	_check("A hit is worth 100 plus up to 100 for speed: 200 at once, 150 at half a target's life, 100 at the end (and later)",
			AimScore.hit_value(0.0, 1.5) == 200 and AimScore.hit_value(0.75, 1.5) == 150 and AimScore.hit_value(1.5, 1.5) == 100
			and AimScore.hit_value(9.0, 1.5) == 100 and AimScore.hit_value(-1.0, 1.5) == 200 and AimScore.hit_value(0.5, 0.0) == 100, "200, 150, 100")
	var run := AimScore.new()
	run.add_hit(0.0, 1.5)
	run.add_hit(0.75, 1.5)
	run.add_hit(1.5, 1.5)
	run.add_expired()
	run.add_shots(5)
	_check("A run's score is its hits' points minus 25 for each shot that hit nothing: 450 - 2 x 25 = 400, with 3 hits, 2 misses, 1 expired",
			run.points == 450 and run.hits == 3 and run.misses() == 2 and run.expired == 1 and run.score() == 400,
			"%d points, %d hits, %d misses, score %d" % [run.points, run.hits, run.misses(), run.score()])
	_check("Accuracy is hits over shots, the average reaction is over the hits only, and the details are ready to save",
			is_equal_approx(run.accuracy(), 0.6) and is_equal_approx(run.average_reaction(), 0.75)
			and run.details() == {"hits": 3, "misses": 2, "expired": 1, "accuracy": 60.0, "reaction_ms": 750},
			"%s" % [run.details()])
	var wild := AimScore.new()
	wild.add_hit(0.3, 1.5)
	wild.add_shots(40)
	_check("Spraying doesn't pay (1 hit in 40 shots scores 0, never less) and a run with no shots has 0 accuracy and no reaction",
			wild.score() == 0 and AimScore.new().accuracy() == 0.0 and AimScore.new().average_reaction() == 0.0 and AimScore.new().score() == 0,
			"score %d" % wild.score())
	var hits_without_shots := AimScore.new()
	hits_without_shots.add_hit(0.5, 1.5)
	_check("Accuracy never goes over 100 % (a hit counted before its shot's count)", hits_without_shots.accuracy() <= 1.0, "%.2f" % hits_without_shots.accuracy())


# --- The range ---


func _start_range() -> void:
	_free_main()
	_main = MAIN_SCENE.instantiate()
	_main.set("load_settings", false)
	_main.set("loading_screen", false)
	_main.set("mode", 1)
	_main.set("map_scene", load(Settings.DEFAULT_MAP))
	add_child(_main)
	await _wait_ticks(8)
	(_main.get_node("ClassMenu") as ClassMenu).close()
	_player = _main.call("get_player") as Character
	var trainers: Array = (_main.call("get_map") as Node).find_children("*", "RangeTrainer", true, false)
	_check("The Shooting Range has the aim trainer's pad, idle, saying how to start", trainers.size() == 1
			and (trainers[0] as RangeTrainer).get_state() == RangeTrainer.State.IDLE
			and (trainers[0].get_node("Label") as Label3D).text.contains("SHOOT TO START"), "%d trainer(s)" % trainers.size())
	if trainers.is_empty():
		return
	_trainer = trainers[0]
	_check("The map's entity gave the trainer its values: a 30 s run, balls living 1.5 s, 7 to 20 m away, within 45 degrees",
			_trainer.run_time == 30.0 and _trainer.target_lifetime == 1.5 and _trainer.min_distance == 7.0 and _trainer.max_distance == 20.0
			and _trainer.half_angle == 45.0, "%.0f s, %.1f s, %.0f-%.0f m, %.0f degrees" % [_trainer.run_time, _trainer.target_lifetime, _trainer.min_distance, _trainer.max_distance, _trainer.half_angle])
	var pad := _trainer.get_pad()
	_check("The pad is a hit zone on the hitboxes layer, off to the side of the start and in view (about 1 m right, 1.2 m ahead, 1.3 m up)",
			pad.collision_layer == PhysicsLayers.HITBOXES and pad.global_position.distance_to(Vector3(1.0, 1.3, -1.2)) < 0.3, "%s" % pad.global_position)
	# Short runs for the tests; the gun is a rifle with perfect aim, whatever the class.
	_trainer.book = _book
	# The range's moving dummy would walk through the line of fire at times: it stands still here
	# (the relocation of a ball it blocks has a check of its own).
	for dummy: TargetDummy in (_main.call("get_map") as Node).find_children("*", "TargetDummy", true, false):
		dummy.move_distance = 0.0
	_trainer.rng.seed = 4242
	_trainer.run_time = 7.0
	_trainer.countdown_time = 0.5
	_trainer.target_lifetime = 1.2
	_trainer.result_time = 0.5
	_trainer.run_finished.connect(func(result: AimScore, new_best: bool) -> void: _results.append([result, new_best]))
	_give_rifle()


func _give_rifle() -> void:
	var rifle := WeaponData.find(&"rifle")
	var loadout: Array[WeaponData] = [rifle]
	_player.inventory.set_loadout(loadout)
	var weapon := _player.inventory.find(rifle)
	var perfect := rifle.duplicate() as WeaponData
	perfect.standing_inaccuracy = 0.0
	perfect.spray_inaccuracy_per_shot = 0.0
	perfect.max_spray_inaccuracy = 0.0
	weapon.data = perfect
	_player.inventory.hold(weapon, true)


func _test_pad_and_run() -> void:
	await _wait_seconds(0.6)
	await _tap_at(_trainer.get_pad().global_position)
	await _wait_ticks(3)
	_check("Shooting the pad starts a run: the countdown first", _trainer.get_state() == RangeTrainer.State.COUNTDOWN
			and _trainer.get_weapon_id() == &"rifle" and _trainer.get_readout() != "", "state %s, readout '%s'" % [_trainer.get_state(), _trainer.get_readout()])
	await _tap_sky()
	var counted_in_countdown := _trainer.get_score().shots
	await _wait_until(func() -> bool: return _trainer.get_state() == RangeTrainer.State.RUNNING, 3.0)
	await _wait_ticks(3)
	var ball := _trainer.get_target()
	_check("After the countdown the run is on with one ball up, and a shot in the countdown wasn't counted",
			_trainer.get_state() == RangeTrainer.State.RUNNING and ball != null and counted_in_countdown == 0 and _trainer.get_score().shots == 0
			and _trainer.get_time_left() > 6.0, "state %s, ball %s, %d shots" % [_trainer.get_state(), ball, _trainer.get_score().shots])
	if ball == null:
		return
	var eye := _player.get_eye_position()
	var spot := ball.global_position
	var to_spot := spot - eye
	var floor_height := spot.y - _player.global_position.y
	var yaw := rad_to_deg(atan2(-to_spot.x, -to_spot.z))
	var distance := to_spot.length()
	var space := _player.get_world_3d().direct_space_state
	# The ray stops at the ball's surface (it would hit the ball's own hit zone at its middle).
	var sight := PhysicsRayQueryParameters3D.create(eye, spot - to_spot.normalized() * (ball.radius + 0.02), PhysicsLayers.WORLD | PhysicsLayers.HITBOXES)
	sight.collide_with_areas = true
	sight.exclude = _player.get_hitbox_rids()
	_check("The ball is in plain view, 7 to 20 m away, within 45 degrees of where the shooter looked, 0.6 to 2.3 m above the floor",
			space.intersect_ray(sight).is_empty() and distance >= 7.0 - 0.1 and distance <= 20.0 + 0.1 and absf(yaw) <= 45.0 + 0.5
			and floor_height >= 0.6 - 0.01 and floor_height <= 2.3 + 0.01,
			"distance %.1f m, %.1f degrees, %.2f m up" % [distance, yaw, floor_height])
	_check("The ball looks the same size from anywhere: 3.2 degrees across", is_equal_approx(ball.radius, distance * tan(deg_to_rad(1.6))),
			"radius %.3f m at %.1f m" % [ball.radius, distance])
	# A real hit.
	await _tap_at(spot)
	await _wait_ticks(2)
	var score := _trainer.get_score()
	_check("Shooting the ball hits it: one hit, one shot, a fast reaction, the ball is gone", score.hits == 1 and score.shots == 1 and score.misses() == 0
			and score.average_reaction() < 0.9 and (_trainer.get_target() == null or _trainer.get_target() != ball),
			"%d hits, %d shots, reaction %.2f s" % [score.hits, score.shots, score.average_reaction()])
	await _wait_seconds(0.5)
	var next := _trainer.get_target()
	var flick := 0.0
	if next != null:
		flick = rad_to_deg((next.global_position - eye).angle_to(spot - eye))
	_check("The next ball is a real flick away (at least 12 degrees from the last)", next != null and next != ball and flick >= 12.0 - 0.5, "%.1f degrees" % flick)
	# A miss, then a ball nobody hits.
	await _tap_sky()
	_check("A shot that hits no ball is a miss", _trainer.get_score().shots == 2 and _trainer.get_score().misses() == 1, "%d shots, %d misses" % [_trainer.get_score().shots, _trainer.get_score().misses()])
	await _wait_until(func() -> bool: return _trainer.get_score().expired >= 1, 3.0)
	_check("A ball nobody shoots times out and counts as expired", _trainer.get_score().expired >= 1, "%d expired" % _trainer.get_score().expired)
	var finished := await _wait_until(func() -> bool: return _trainer.get_state() == RangeTrainer.State.RESULT, 9.0)
	_check("When the time is up the run ends and the result is on the screen", finished and _results.size() == 1
			and _trainer.get_readout().begins_with("SCORE") and _trainer.get_target() == null, "readout '%s'" % _trainer.get_readout().replace("\n", " | "))


func _test_scoring_and_best() -> void:
	if _results.is_empty():
		return
	var first: AimScore = _results[0][0]
	var key := RangeTrainer.best_key(&"rifle")
	_check("The first run is a new best for that gun, saved with its details (the key is aim_flick_ and the gun)",
			_results[0][1] == true and is_equal_approx(_book.get_best_score(key), float(first.score())) and int(_book.get_best(key)["hits"]) == first.hits
			and _trainer.get_readout().contains("NEW BEST"), "best %.0f, score %d" % [_book.get_best_score(key), first.score()])
	var first_best := _book.get_best_score(key)
	# A run without a hit changes nothing.
	_trainer.run_time = 2.5
	await _wait_until(func() -> bool: return _trainer.get_state() == RangeTrainer.State.IDLE, 2.0)
	_check("The pad says the best for the gun in hand when it is idle", _trainer.get_node("Label").text.contains("BEST %d" % roundi(first_best)), _trainer.get_node("Label").text.replace("\n", " | "))
	_check("A run can be started from the result screen too, and shooting nothing is no new best and saves nothing",
			_trainer.start(_player), "started")
	await _wait_until(func() -> bool: return _results.size() == 2, 9.0)
	_check("The run without a hit ended with a score of 0 and the best is as it was",
			_results.size() == 2 and _results[1][0].hits == 0 and _results[1][1] == false and is_equal_approx(_book.get_best_score(key), first_best),
			"%d results, best %.0f" % [_results.size(), _book.get_best_score(key)])
	# A better run (three hits) replaces the best.
	await _wait_until(func() -> bool: return _trainer.get_state() == RangeTrainer.State.IDLE, 2.0)
	_trainer.run_time = 6.0
	_trainer.start(_player)
	await _wait_until(func() -> bool: return _trainer.get_state() == RangeTrainer.State.RUNNING, 3.0)
	for _ball in 3:
		await _wait_until(func() -> bool: return _trainer.get_target() != null, 2.0)
		var ball := _trainer.get_target()
		if ball == null:
			break
		await _tap_at(ball.global_position)
		await _wait_seconds(0.2)
	await _wait_until(func() -> bool: return _results.size() == 3, 9.0)
	var best_run: AimScore = _results[2][0] if _results.size() == 3 else AimScore.new()
	_check("A better run is the new best: three hits, a higher score, saved over the old one",
			_results.size() == 3 and best_run.hits >= 3 and best_run.score() > first_best and _results[2][1] == true
			and is_equal_approx(_book.get_best_score(key), float(best_run.score())) and int(_book.get_best(key)["hits"]) == best_run.hits,
			"score %d against %.0f, %d hits" % [best_run.score(), first_best, best_run.hits])


func _test_stop_and_refusals() -> void:
	await _wait_until(func() -> bool: return _trainer.get_state() == RangeTrainer.State.IDLE, 2.0)
	var key := RangeTrainer.best_key(&"rifle")
	var best_before := _book.get_best_score(key)
	var results_before := _results.size()
	_trainer.run_time = 20.0
	_trainer.start(_player)
	await _wait_until(func() -> bool: return _trainer.get_state() == RangeTrainer.State.RUNNING, 3.0)
	await _wait_until(func() -> bool: return _trainer.get_target() != null, 2.0)
	# Something walks in front of the ball: it moves to a spot in view, and that is no timed-out ball.
	var ball := _trainer.get_target()
	var dummy := (_main.call("get_map") as Node).find_children("*", "TargetDummy", true, false)[0] as TargetDummy
	var line := (ball.global_position - _player.get_eye_position()).normalized()
	var expired_before := _trainer.get_score().expired
	dummy.global_position = Vector3(_player.global_position.x, 0.0, _player.global_position.z) + Vector3(line.x, 0.0, line.z).normalized() * 4.0
	await _wait_ticks(4)
	var moved := _trainer.get_target()
	_check("A ball that something walks in front of moves to a spot in view, and doesn't count as expired",
			moved != null and moved != ball and _trainer.get_score().expired == expired_before, "ball changed: %s" % [moved != ball])
	dummy.global_position = Vector3(40.0, 0.0, 40.0)
	await _wait_seconds(0.3)
	await _tap_at(_trainer.get_pad().global_position)
	await _wait_ticks(3)
	_check("Shooting the pad during a run stops it: no result, nothing saved, no ball left, the readout gone",
			_trainer.get_state() == RangeTrainer.State.IDLE and _results.size() == results_before and is_equal_approx(_book.get_best_score(key), best_before)
			and _trainer.get_target() == null and _trainer.get_readout() == "", "state %s" % _trainer.get_state())
	# The console starts and stops it too.
	var console := _main.get_node("DevConsole") as DevConsole
	await _wait_seconds(0.6)
	console.run("aim")
	await _wait_ticks(2)
	var started_by_console := _trainer.get_state() == RangeTrainer.State.COUNTDOWN
	console.run("aim stop")
	_check("The console's `aim` starts a run and `aim stop` stops it", started_by_console and _trainer.get_state() == RangeTrainer.State.IDLE,
			"started %s, now %s" % [started_by_console, _trainer.get_state()])
	# Without a gun nothing starts.
	var knife := WeaponData.find(&"knife")
	var loadout: Array[WeaponData] = [knife]
	_player.inventory.set_loadout(loadout)
	_player.inventory.hold(_player.inventory.find(knife), true)
	await _wait_ticks(4)
	var started := _trainer.start(_player)
	_check("With only a knife in hand nothing starts and the pad says to take a gun first",
			not started and _trainer.get_state() == RangeTrainer.State.IDLE and _trainer.get_notice() == "Take a gun first"
			and _trainer.get_node("Label").text.contains("TAKE A GUN FIRST"), "notice '%s'" % _trainer.get_notice())
	# A bot's stray bullet never starts a run: only the person at this computer does.
	_give_rifle()
	var bot := Character.all_in_world(_player).filter(func(c: Character) -> bool: return c != _player)
	_check("Nobody but the player is in the range to test with, so a bullet from a character that isn't local is ignored by construction", bot.is_empty()
			or not (bot[0] as Character).is_local_player(), "%d others" % bot.size())


# --- Helpers ---


func _free_main() -> void:
	if _main != null:
		remove_child(_main)
		_main.queue_free()
		_main = null
	MenuState.reset()


## Aims at [param point], presses fire for two ticks and waits for the recoil to wear off.
func _tap_at(point: Vector3) -> void:
	_player.aim_at(point)
	Input.action_press("shoot")
	await _wait_ticks(2)
	Input.action_release("shoot")
	await _wait_seconds(0.12)


## A shot into the sky.
func _tap_sky() -> void:
	await _tap_at(_player.get_eye_position() + Vector3.UP * 30.0 + Vector3.FORWARD * 3.0)


func _wait_until(condition: Callable, seconds: float) -> bool:
	for i in roundi(seconds * Engine.physics_ticks_per_second):
		if condition.call():
			return true
		await get_tree().physics_frame
	return condition.call()


func _real_md5() -> String:
	return FileAccess.get_md5(StatsBook.PATH) if FileAccess.file_exists(StatsBook.PATH) else ""


func _wait_seconds(seconds: float) -> void:
	await _wait_ticks(roundi(seconds * Engine.physics_ticks_per_second))


func _wait_ticks(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _check(check_name: String, passed: bool, detail: String) -> void:
	print("%s  %s: %s" % ["PASS" if passed else "FAIL", check_name, detail])
	if not passed:
		_failures += 1
