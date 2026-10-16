extends Node
## Automated checks for online matches (M9). Run without a window:
##
##     Godot --headless --path . --fixed-fps 128 --quit-after 200000 res://tests/netplay_test.tscn
##
## A host and a client play a real bomb match on Depot in this one process, each in the real
## game scene with a physics world of its own ([NetHarness], D-111). Checked so far: one match on
## every screen (task 3): the friend's character joins the host's match before the bots, the
## client builds the same characters (names, teams, classes, network ids) as puppets, and its
## replica round manager and bomb follow the host's: phases, rounds, score, kills, the kill
## feed, the scoreboard and the bomb's carrier and state. Server authority (task 4): the
## client's commands move its character on the host, each command runs exactly once (also with
## 25% of the packets lost), a flood of commands can't run faster than the budget, and a shot's
## spread is rolled from its command's number. Snapshots (task 5): a puppet is shown 6 ticks
## behind the newest snapshot, exactly between the host's positions around that moment and
## without jumps; its shots, reloads and footsteps play on the client (also with 5% of the
## snapshots lost); a dead client spectates a teammate's puppet. Prediction (task 6), at 100 ms
## of round trip: the client's player moves at once, runs, jumps and crouches without a single
## correction, ends up exactly where the host has it, recovers from a disagreement (smoothed),
## and predicts and corrects its ammo. Lag compensation (task 7), at 100 ms: the client taps at
## a target strafing 12 m away, aiming where its screen shows it; the host counts the hits with
## lag compensation and, for comparison, without. Menus online (task 9): the pause menu is an
## overlay that doesn't pause either game, the console refuses cheats and shows the session's
## status, the F3 overlay shows ping and corrections, the end screen's choices are the host's.
## Quits with the number of failed checks as the exit code.

const MAP := preload("res://maps/depot.tscn")
## Seconds of each phase.
const FREEZE_TIME := 1.0
## Long enough for every check that plays in the first live round (the lag-compensation taps
## alone take 40 s); the bots end the rounds after that.
const ROUND_TIME := 90.0
const ROUND_END_TIME := 1.0

var _harness: NetHarness
var _failures: int = 0
var _host_session: NetSession
var _client_session: NetSession
var _host_main: Node
var _client_main: Node
var _host: NetHost
var _client: NetClient
var _host_rules: RoundManager
var _client_rules: RoundManager
## What each side's round manager announced: kills [victim name, killer name, headshot] and round ends.
var _host_kills: Array = []
var _client_kills: Array = []
var _host_rounds: Array = []
var _client_rounds: Array = []
## While the puppet test runs: the host player's position by host tick, and the client's puppet
## of it with the render tick it was shown at ([render tick, position]).
var _host_track: Dictionary = {}
var _puppet_track: Array = []
var _tracking: Character
var _tracking_puppet: Character


## Drives a character with commands from a function (the host's own player in the tests).
class ScriptedController extends CharacterController:
	var source: Callable

	func get_input(delta: float) -> CharacterInput:
		return source.call(delta)


func _physics_process(_delta: float) -> void:
	# Runs before the map's characters (this node is above them), so the host's player is where
	# the snapshot of the host's current tick showed it; the client has posed its puppets already.
	if _tracking != null and _host != null:
		_host_track[_host.tick] = _tracking.global_position
		_puppet_track.append([_client.get_render_tick(), _tracking_puppet.global_position])


func _ready() -> void:
	_harness = NetHarness.new()
	add_child(_harness)
	await _start()
	if _host != null and _client != null and _client.is_welcomed():
		# The first snapshots bring the bomb and everyone's place.
		await _harness.wait_ticks(10)
		_test_same_match()
		await _test_commands()
		await _test_prediction()
		await _test_lag_compensation()
		await _test_puppets()
		await _test_spectating()
		await _test_menus_online()
		await _test_rounds()
	_stop()
	for i in 5:
		await get_tree().physics_frame
	if _failures == 0:
		print("\nAll checks passed.")
	else:
		print("\n%d check(s) FAILED." % _failures)
	get_tree().quit(_failures)


func _rules() -> MatchSettings:
	var rules := MatchSettings.new()
	rules.team_size = 2
	rules.enemy_team_size = 2
	rules.rounds_to_win = 2
	rules.freeze_time = FREEZE_TIME
	rules.round_time = ROUND_TIME
	rules.round_end_time = ROUND_END_TIME
	return rules


## A host and one client in the lobby, then the same match started on both.
func _start() -> void:
	_host_session = _harness.start_host("Host", "Host")
	_client_session = _harness.start_client("Client", "Jan")
	var joined := await _harness.wait_until(_client_session.is_active)
	_check("The client joins the host's session", joined, "")
	if not joined:
		return
	_host_main = _harness.start_game(_host_session.get_parent(), _host_session, MAP, _rules())
	_harness.silence(_host_main.get_player())
	_host = _host_main.get_net_game() as NetHost
	_host_rules = _host_main.get_map().get_node("RoundManager") as RoundManager
	await _harness.wait_ticks(10)
	_check("The host waits for the client to load before starting", _host != null and not _host.is_started(), "")
	_client_main = _harness.start_game(_client_session.get_parent(), _client_session, MAP, _rules())
	_harness.silence(_client_main.get_player())
	_client = _client_main.get_net_game() as NetClient
	_client_rules = _client_main.get_map().get_node("RoundManager") as RoundManager
	var started := await _harness.wait_until(func() -> bool: return _host.is_started() and _client.is_welcomed(), 600)
	_check("Once the client has loaded the map the match starts and the client is welcomed", started,
			"started %s, welcomed %s" % [_host.is_started(), _client.is_welcomed()])
	if not started:
		return
	for character in _host_rules.get_participants():
		_harness.silence(character)
	_harness.silence_bomb(_host_rules.bomb)
	_harness.silence_bomb(_client_rules.bomb)
	_host_rules.character_killed.connect(func(victim: Character, killer: Character, headshot: bool) -> void:
		_host_kills.append([String(victim.name), String(killer.name) if killer != null else "", headshot]))
	_client_rules.character_killed.connect(func(victim: Character, killer: Character, headshot: bool) -> void:
		_client_kills.append([String(victim.name), String(killer.name) if killer != null else "", headshot]))
	_host_rules.round_ended.connect(func(winner: int, reason: RoundManager.EndReason) -> void:
		_host_rounds.append([winner, reason, _host_rules.score.duplicate()]))
	_client_rules.round_ended.connect(func(winner: int, reason: RoundManager.EndReason) -> void:
		_client_rounds.append([winner, reason, _client_rules.score.duplicate()]))


func _test_same_match() -> void:
	var host_list := _describe(_host_rules)
	var client_list := _describe(_client_rules)
	var friend := _host.get_character_of(_client_session.local_peer_id)
	_check("The host's match: the host, the friend (on the smaller team, before the bots), then a bot per empty slot",
			host_list.size() == 4 and host_list[0][1] == "Host" and host_list[1][1] == "Jan"
					and friend != null and friend.get_controller() is NetworkController and friend.manual
					and friend.team == 1 and _host_main.get_player().team == 0
					and _host_rules.get_members(0).size() == 2 and _host_rules.get_members(1).size() == 2,
			"%s" % [host_list])
	_check("The client has the same characters: network ids, names, teams and classes, in the same order",
			client_list == host_list, "host %s, client %s" % [host_list, client_list])
	var puppets_remote := true
	for character in _client_rules.get_participants():
		if character != _client_main.get_player() and not (character.remote and character.replica and character.weapon.remote):
			puppets_remote = false
	var own: Character = _client_main.get_player()
	_check("On the client the friend's own character is the map's player, named after them; everyone else is a puppet",
			own.name == "Jan" and own.net_id == friend.net_id and own.replica and not own.remote and puppets_remote
					and own.team == 1 and Teams.viewer_team == 1,
			"own %s (id %d, team %d), puppets remote %s" % [own.name, own.net_id, own.team, puppets_remote])
	_check("The client's replica round manager shows the host's round, phase, sides and score",
			_client_rules.replica and _client_rules.round_number == _host_rules.round_number and _client_rules.phase == _host_rules.phase
					and _client_rules.attacking_team == _host_rules.attacking_team and _client_rules.score == _host_rules.score,
			"host round %d phase %d, client round %d phase %d" % [_host_rules.round_number, _host_rules.phase, _client_rules.round_number, _client_rules.phase])
	var host_bomb := _host_rules.bomb
	var client_bomb := _client_rules.bomb
	_check("The client has a replica bomb with the same carrier",
			host_bomb != null and client_bomb != null and client_bomb.replica and is_instance_valid(client_bomb.carrier)
					and client_bomb.carrier.net_id == host_bomb.carrier.net_id,
			"host carrier %s, client carrier %s" % [host_bomb.carrier.name if host_bomb != null else "-",
					client_bomb.carrier.name if client_bomb != null and client_bomb.carrier != null else "-"])


## The client's commands drive its character on the host (D-103). The bots are held still
## meanwhile, so nobody gets in the way. "Exactly once" is checked on the totals: every command
## the client ever made has run once on the host (the client never stops sending in a real game,
## so a lost last packet is always covered by the next).
func _test_commands() -> void:
	await _harness.wait_until(func() -> bool: return _host_rules.phase == RoundManager.Phase.LIVE, 600)
	_hold_bots(true)
	var friend := _host.get_character_of(_client_session.local_peer_id)
	var controller := friend.get_controller() as NetworkController
	var own: Character = _client_main.get_player()
	var yaw := friend.rotation.y
	var start := friend.global_position
	_client.command_source = func(_delta: float) -> CharacterInput: return _walk(yaw, false)
	await _harness.wait_ticks(128)
	_client.command_source = func(_delta: float) -> CharacterInput: return _walk(yaw, true)
	await _harness.wait_ticks(40)
	# Stop sending for a moment, so nothing is on its way while the two sides are compared.
	_client.set_physics_process(false)
	await _harness.wait_ticks(20)
	var moved := Vector2(friend.global_position.x - start.x, friend.global_position.z - start.z).length()
	_check("The client's commands move its character on the host (a second of running forward: over 3 m)",
			moved > 3.0, "%.2f m" % moved)
	_check("The host runs every command exactly once, in order, and confirms the last one",
			controller.commands_run == _client.command_tick and controller.last_run == _client.command_tick and _client.acked_tick == _client.command_tick,
			"made %d, run %d, last run %d, acked %d" % [_client.command_tick, controller.commands_run, controller.last_run, _client.acked_tick])
	_check("The client shows its character where the host has it", own.global_position.distance_to(friend.global_position) < 0.01,
			"%.3f m apart" % own.global_position.distance_to(friend.global_position))
	_client.set_physics_process(true)

	# A quarter of the client's packets lost: the repeats in every packet still bring every command.
	_host_session.rng.seed = 99
	_host_session.fake_loss = 0.25
	var made_before := _client.command_tick
	var shot_tick := [0]
	_client.command_source = func(_delta: float) -> CharacterInput:
		var command := _walk(yaw + PI, false)
		# One shot, at the 60th command.
		if _client.command_tick - made_before == 59:
			command.shoot = true
			shot_tick[0] = _client.command_tick + 1
		return command
	await _harness.wait_ticks(128)
	_client.command_source = func(_delta: float) -> CharacterInput: return _walk(yaw, true)
	await _harness.wait_ticks(40)
	_host_session.fake_loss = 0.0
	await _harness.wait_ticks(20)
	_client.set_physics_process(false)
	await _harness.wait_ticks(20)
	_check("With 25% of the packets lost, every command still runs exactly once",
			controller.commands_run == _client.command_tick and controller.last_run == _client.command_tick and _host_session.packets_dropped > 10,
			"made %d, run %d, %d packets dropped" % [_client.command_tick, controller.commands_run, _host_session.packets_dropped])
	_check("A shot's spread is rolled from its command's number (the same on both computers)",
			shot_tick[0] > 0 and friend.weapon.rng.seed == hash([friend.net_id, shot_tick[0]]),
			"seed %d, expected %d" % [friend.weapon.rng.seed, hash([friend.net_id, shot_tick[0]])])

	# A flood: 40 new commands in one packet can't all run at once.
	var flood: Array[CharacterInput] = []
	for i in 40:
		var command := _walk(yaw, true)
		command.tick = _client.command_tick + 1 + i
		flood.append(command)
	var run_before := controller.commands_run
	_client_session.send_packet(1, NetProtocol.pack_commands(flood), false)
	await _harness.wait_until(func() -> bool: return controller.commands_run > run_before, 20)
	var first_tick := controller.commands_run - run_before
	await _harness.wait_ticks(60)
	_check("A flood of 40 commands runs no faster than the budget (at most 9 in a tick), then all of them",
			first_tick <= NetworkController.MAX_BUDGET + 1 and controller.commands_run - run_before == 40,
			"%d in the first tick, %d in all" % [first_tick, controller.commands_run - run_before])
	_client.command_tick += 40
	_client.set_physics_process(true)
	_client.command_source = Callable()
	_hold_bots(false)


## Prediction at 100 ms of round trip (D-106): 50 ms of fake lag each way.
func _test_prediction() -> void:
	_hold_bots(true)
	_host_session.fake_lag_ms = 50.0
	_client_session.fake_lag_ms = 50.0
	var friend := _host.get_character_of(_client_session.local_peer_id)
	var own: Character = _client_main.get_player()
	var yaw := own.get_aim_angles().x
	await _harness.wait_ticks(40)
	var host_start := friend.global_position
	var corrections_before := _client.corrections
	var count := [0]
	_client.command_source = func(_delta: float) -> CharacterInput:
		count[0] += 1
		var command := _walk(yaw + sin(count[0] * 0.01), false)
		if count[0] > 128:
			command.move = Vector2(1.0 if (count[0] / 64) % 2 == 0 else -1.0, -1.0).normalized()
		command.jump = count[0] % 90 == 30
		command.crouch = count[0] % 200 > 160
		return command
	await _harness.wait_ticks(3)
	var own_speed := Vector2(own.velocity.x, own.velocity.z).length()
	var host_moved := friend.global_position.distance_to(host_start)
	_check("With prediction your character moves at once, without waiting for the host's answer",
			own_speed > 0.5 and host_moved < 0.001, "%.2f m/s here, host moved %.3f m" % [own_speed, host_moved])
	await _harness.wait_ticks(380)
	_client.command_source = func(_delta: float) -> CharacterInput: return _walk(yaw, true)
	await _harness.wait_ticks(60)
	_check("Running, strafing, jumping and crouching for 3 s at 100 ms: not a single correction",
			_client.corrections == corrections_before, "%d corrections, largest %.3f m" % [_client.corrections - corrections_before, _client.largest_correction])
	_check("The prediction ends exactly where the host has the character", own.global_position.distance_to(friend.global_position) < 0.001,
			"%.4f m apart" % own.global_position.distance_to(friend.global_position))
	_check("The client measures the round trip it feels (50 ms of fake lag each way: about 100 ms, plus up to a snapshot interval)",
			_client.ping_ms >= 95.0 and _client.ping_ms <= 130.0, "%.0f ms" % _client.ping_ms)

	# A disagreement: the host moves the character half a metre (as a push would).
	count[0] = 0
	_client.command_source = func(_delta: float) -> CharacterInput:
		count[0] += 1
		return _walk(yaw, count[0] > 60)
	await _harness.wait_ticks(20)
	corrections_before = _client.corrections
	friend.global_position += Vector3(0.5, 0.0, 0.0)
	await _harness.wait_until(func() -> bool: return _client.corrections > corrections_before, 60)
	var corrected := _client.corrections > corrections_before
	var offset := own.view_offset.length()
	await _harness.wait_ticks(100)
	_check("When the host disagrees, the client corrects and replays: it ends where the host has it",
			corrected and own.global_position.distance_to(friend.global_position) < 0.001,
			"corrected %s, %.4f m apart" % [corrected, own.global_position.distance_to(friend.global_position)])
	_check("The camera hides the correction, then catches up (an offset of the jump that fades)",
			offset > 0.3 and offset <= 1.0 and own.view_offset.length() < 0.01, "%.3f m at first, %.4f m later" % [offset, own.view_offset.length()])

	# Ammo: shots are predicted; the host's count wins when they differ.
	var magazine_before := own.weapon.magazine
	count[0] = 0
	_client.command_source = func(_delta: float) -> CharacterInput:
		count[0] += 1
		var command := _walk(yaw, true)
		command.shoot = count[0] <= 60
		return command
	await _harness.wait_ticks(3)
	var shot_here := magazine_before - own.weapon.magazine
	var shot_there := magazine_before - friend.weapon.magazine
	await _harness.wait_ticks(97)
	_check("Shots are predicted: your magazine drops at once, the host's count follows a round trip later and agrees",
			shot_here >= 1 and shot_there < shot_here and own.weapon.magazine == friend.weapon.magazine,
			"after 3 ticks %d shot here, %d on the host; then %d / %d" % [shot_here, shot_there, own.weapon.magazine, friend.weapon.magazine])
	friend.weapon.refill()
	await _harness.wait_ticks(40)
	_check("When the host's ammo differs (a refill), the client takes the host's count",
			own.weapon.magazine == friend.weapon.magazine and own.weapon.reserve == friend.weapon.reserve,
			"%d / %d here, %d / %d on the host" % [own.weapon.magazine, own.weapon.reserve, friend.weapon.magazine, friend.weapon.reserve])
	_client.command_source = Callable()
	_host_session.fake_lag_ms = 0.0
	_client_session.fake_lag_ms = 0.0
	await _harness.wait_ticks(30)


## The client taps at the host's player strafing 12 m away, at 100 ms of round trip (D-107).
func _test_lag_compensation() -> void:
	_hold_bots(true)
	var friend := _host.get_character_of(_client_session.local_peer_id)
	var own: Character = _client_main.get_player()
	var host_player: Character = _host_main.get_player()
	var puppet := _client.get_character(host_player.net_id)
	# A spot 12 m away with a clear view and floor under it.
	var space := friend.get_world_3d().direct_space_state
	var eye := Vector3.UP * 1.6
	var spot := Vector3.INF
	for i in 16:
		var direction := Vector3.FORWARD.rotated(Vector3.UP, TAU * i / 16.0)
		var candidate := friend.global_position + direction * 12.0
		var floor_ray := PhysicsRayQueryParameters3D.create(candidate + Vector3.UP, candidate + Vector3.DOWN * 0.5, PhysicsLayers.WORLD)
		if space.intersect_ray(floor_ray).is_empty():
			continue
		# The whole strip the target strafes along must be in plain view, at every height a shot may take.
		var side := direction.cross(Vector3.UP)
		var clear := true
		for offset in [-2.5, -1.25, 0.0, 1.25, 2.5]:
			for height in [0.5, 0.9, 1.3, 1.7]:
				var point: Vector3 = candidate + side * offset + Vector3.UP * height
				var sight := PhysicsRayQueryParameters3D.create(friend.global_position + eye, point, PhysicsLayers.WORLD)
				if not space.intersect_ray(sight).is_empty():
					clear = false
			var along := PhysicsRayQueryParameters3D.create(candidate + Vector3.UP * 0.5, candidate + side * offset + Vector3.UP * 0.5, PhysicsLayers.WORLD)
			if not space.intersect_ray(along).is_empty():
				clear = false
		if clear:
			spot = candidate
			break
	if spot == Vector3.INF:
		_check("Lag compensation: a clear spot 12 m away for the target", false, "none found")
		return
	var to_friend := friend.global_position - spot
	host_player.respawn(spot, atan2(-to_friend.x, -to_friend.z))
	host_player.god_mode = true
	var scripted := ScriptedController.new()
	scripted.name = "ScriptedController"
	host_player.add_child(scripted)
	var facing := host_player.rotation.y
	var ticks := [0]
	scripted.source = func(_delta: float) -> CharacterInput:
		ticks[0] += 1
		var command := CharacterInput.new()
		command.yaw = facing
		command.move = Vector2(1.0 if (ticks[0] / 48) % 2 == 0 else -1.0, 0.0)
		return command
	host_player.set_controller(scripted)
	_host_session.fake_lag_ms = 50.0
	_client_session.fake_lag_ms = 50.0
	await _harness.wait_ticks(60)
	var shots := [0]
	var hits := [0]
	var count_shot := func(_shot: int) -> void: shots[0] += 1
	var count_hit := func(hit: Dictionary) -> void: hits[0] += 1 if hit["zone"] != "" else 0
	friend.weapon.fired.connect(count_shot)
	friend.weapon.hit_landed.connect(count_hit)
	var made := [0]
	_client.command_source = func(_delta: float) -> CharacterInput:
		made[0] += 1
		var command := CharacterInput.new()
		var direction := (puppet.get_chest_position() - own.get_eye_position()).normalized()
		command.yaw = atan2(-direction.x, -direction.z)
		command.pitch = asin(direction.y)
		# A tap every half second, so the spray pattern has settled before the next one.
		command.shoot = made[0] % 64 == 0
		return command
	await _harness.wait_ticks(64 * 40 + 30)
	var with_rate := float(hits[0]) / maxf(shots[0], 1.0)
	var with_shots: int = shots[0]
	shots[0] = 0
	hits[0] = 0
	friend.lag_compensation = null
	await _harness.wait_ticks(64 * 40 + 30)
	var without_rate := float(hits[0]) / maxf(shots[0], 1.0)
	friend.lag_compensation = _host.lag_compensation
	_client.command_source = Callable()
	friend.weapon.fired.disconnect(count_shot)
	friend.weapon.hit_landed.disconnect(count_hit)
	_host_session.fake_lag_ms = 0.0
	_client_session.fake_lag_ms = 0.0
	host_player.set_controller(host_player.get_node("PlayerController") as CharacterController)
	host_player.remove_child(scripted)
	scripted.queue_free()
	host_player.god_mode = false
	_check("At 100 ms, taps at a target strafing 12 m away hit where the shooter saw it (lag compensation: 85% or more)",
			with_shots >= 35 and with_rate >= 0.85, "%d shots, %.0f%% hits" % [with_shots, with_rate * 100.0])
	_check("Without lag compensation the same taps mostly miss (you would have to lead the target by your ping)",
			without_rate <= 0.6 and with_rate - without_rate >= 0.3, "%.0f%% hits without, %.0f%% with" % [without_rate * 100.0, with_rate * 100.0])
	print("      (lag compensation: %.0f%% of %d taps hit; without it %.0f%%)" % [with_rate * 100.0, with_shots, without_rate * 100.0])
	await _harness.wait_ticks(30)


## The host's player strafes and shoots; its puppet on the client must follow (D-104).
func _test_puppets() -> void:
	_hold_bots(true)
	var host_player: Character = _host_main.get_player()
	var puppet := _client.get_character(host_player.net_id)
	var scripted := ScriptedController.new()
	scripted.name = "ScriptedController"
	host_player.add_child(scripted)
	var yaw := host_player.rotation.y
	var count := [0]
	scripted.source = func(_delta: float) -> CharacterInput:
		count[0] += 1
		var command := CharacterInput.new()
		command.yaw = yaw + sin(count[0] * 0.02) * 0.6
		command.move = Vector2(1.0 if (count[0] / 96) % 2 == 0 else -1.0, 0.0)
		command.shoot = count[0] % 40 < 20
		command.reload = count[0] == 200
		return command
	host_player.set_controller(scripted)
	var host_shots := [0]
	var puppet_shots := [0]
	var host_reloads := [0]
	var puppet_reloads := [0]
	var host_steps := [0]
	var puppet_steps := [0]
	host_player.weapon.fired.connect(func(_shot: int) -> void: host_shots[0] += 1)
	puppet.weapon.fired.connect(func(_shot: int) -> void: puppet_shots[0] += 1)
	host_player.weapon.reload_started.connect(func() -> void: host_reloads[0] += 1)
	puppet.weapon.reload_started.connect(func() -> void: puppet_reloads[0] += 1)
	host_player.footstep.connect(func(loud: bool) -> void: host_steps[0] += 1 if loud else 0)
	puppet.footstep.connect(func(loud: bool) -> void: puppet_steps[0] += 1 if loud else 0)
	_client_session.rng.seed = 5
	_client_session.fake_loss = 0.05
	_tracking = host_player
	_tracking_puppet = puppet
	await _harness.wait_ticks(320)
	scripted.source = func(_delta: float) -> CharacterInput:
		var command := CharacterInput.new()
		command.yaw = yaw
		return command
	await _harness.wait_ticks(40)
	_tracking = null
	_client_session.fake_loss = 0.0
	host_player.set_controller(host_player.get_node("PlayerController") as CharacterController)
	host_player.remove_child(scripted)
	scripted.queue_free()

	var worst := 0.0
	var worst_step := 0.0
	var compared := 0
	var behind := 0.0
	for i in _puppet_track.size():
		var render: float = _puppet_track[i][0]
		var shown: Vector3 = _puppet_track[i][1]
		var tick := floori(render)
		if i > 0:
			worst_step = maxf(worst_step, shown.distance_to(_puppet_track[i - 1][1]))
		if not _host_track.has(tick) or not _host_track.has(tick + 1):
			continue
		var expected: Vector3 = (_host_track[tick] as Vector3).lerp(_host_track[tick + 1], render - tick)
		worst = maxf(worst, shown.distance_to(expected))
		compared += 1
		behind += float(_client.newest_snapshot) - render
	_check("A puppet is shown exactly between the host's positions around its render tick (within 2 cm, 5% loss)",
			compared > 200 and worst < 0.02, "%d ticks compared, worst %.3f m" % [compared, worst])
	_check("A puppet moves without jumps (at most 6 cm a tick while strafing)", worst_step < 0.06, "%.3f m" % worst_step)
	var clock_lag := float(_client.newest_snapshot) - _client.get_render_tick()
	_check("Puppets are shown about 6 ticks (47 ms) behind the newest snapshot", clock_lag >= 5.0 and clock_lag <= 8.0, "%.1f ticks" % clock_lag)
	_check("Every shot and reload of the host's player plays on its puppet once, also with 5% of the snapshots lost",
			host_shots[0] >= 8 and puppet_shots[0] == host_shots[0] and host_reloads[0] >= 1 and puppet_reloads[0] == host_reloads[0],
			"shots %d / %d, reloads %d / %d" % [host_shots[0], puppet_shots[0], host_reloads[0], puppet_reloads[0]])
	_check("The puppet takes its loud footsteps from its movement (as many as the host's, give or take 2)",
			host_steps[0] > 3 and absi(puppet_steps[0] - host_steps[0]) <= 2, "host %d, puppet %d" % [host_steps[0], puppet_steps[0]])


## The client's player is killed on the host: it dies on the client and watches a teammate's puppet.
func _test_spectating() -> void:
	var friend := _host.get_character_of(_client_session.local_peer_id)
	var own: Character = _client_main.get_player()
	var controller := own.get_node("PlayerController") as PlayerController
	var mates := _client_rules.get_members(own.team).filter(func(c: Character) -> bool: return c != own and c.is_alive())
	friend.take_damage(500.0, Hitbox.Zone.CHEST, null)
	var died := await _harness.wait_until(func() -> bool: return not own.is_alive(), 60)
	await _harness.wait_ticks(roundi(controller.spectate_delay * Engine.physics_ticks_per_second) + 20)
	var watched := controller.get_view_target()
	var hud := _client_main.get_node("HUD")
	_check("Killed on the host, the client's player dies on the client and then watches a teammate's puppet",
			died and not mates.is_empty() and watched != own and watched.remote and watched.team == own.team and hud.shown == watched,
			"died %s, watching %s" % [died, watched.name])
	_hold_bots(false)


## The pause menu, console and overlay online (D-109).
func _test_menus_online() -> void:
	var pause: PauseMenu = _client_main.get_pause_menu()
	var host_pause: PauseMenu = _host_main.get_pause_menu()
	var snapshot_before := _client.newest_snapshot
	var host_tick := _host.tick
	pause.open()
	host_pause.open()
	await _harness.wait_ticks(20)
	_check("Online the pause menu is an overlay: neither game pauses, the snapshots keep coming, your controls are held",
			pause.is_open() and host_pause.is_open() and not get_tree().paused and _client.newest_snapshot > snapshot_before + 5
					and _host.tick > host_tick + 15 and MenuState.blocks_gameplay(),
			"paused %s, snapshots %d -> %d" % [get_tree().paused, snapshot_before, _client.newest_snapshot])
	_check("Its leave button reads \"Back to lobby\" for the host and \"Leave match\" for a client",
			host_pause.get_leave_button().text == "Back to lobby" and pause.get_leave_button().text == "Leave match",
			"%s / %s" % [host_pause.get_leave_button().text, pause.get_leave_button().text])
	pause.close()
	host_pause.close()
	var console := _client_main.get_node("DevConsole") as DevConsole
	console.run("god")
	var refused: bool = String(console.get_visible_lines().back()).contains("only works offline")
	console.run("status")
	var status := "\n".join(console.get_visible_lines())
	console.run("net_fakelag 30")
	var lag := _client_session.fake_lag_ms
	console.run("net_fakelag 0")
	var overlay_lines: Array[String] = _client.get_status_lines()
	_check("Online the console refuses cheats and shows the session (status, net_fakelag); the overlay has ping and corrections",
			refused and status.contains("Ping") and status.contains("corrections") and is_equal_approx(lag, 30.0)
					and _client_session.fake_lag_ms == 0.0 and "\n".join(overlay_lines).contains("Predicted")
					and "\n".join(_host.get_status_lines()).contains("Jan"),
			"refused %s, lag %s, status: %s" % [refused, lag, status.right(200)])


## A command looking along [param yaw], running forward unless [param still].
func _walk(yaw: float, still: bool) -> CharacterInput:
	var command := CharacterInput.new()
	command.yaw = yaw
	command.move = Vector2.ZERO if still else Vector2(0.0, -1.0)
	return command


## Holds the host's bots still (they can't move or shoot) or lets them go again.
func _hold_bots(hold: bool) -> void:
	for character in _host_rules.get_participants():
		if character.get_node_or_null("BotController") != null:
			character.frozen = hold


## Plays rounds (the two players stand still, the bots fight) and compares what both sides saw.
func _test_rounds() -> void:
	var host_bots: Array = _host_rules.get_participants().filter(func(c: Character) -> bool: return c.get_node_or_null("BotController") != null)
	await _harness.wait_until(func() -> bool: return _host_rules.phase == RoundManager.Phase.LIVE, 600)
	await _harness.wait_ticks(256)
	var worst := 0.0
	for bot: Character in host_bots:
		var puppet := _client.get_character(bot.net_id)
		if puppet != null and bot.is_alive():
			worst = maxf(worst, puppet.global_position.distance_to(bot.global_position))
	_check("The client's puppets of the bots are where the host's bots are (within 0.6 m: a snapshot behind)",
			worst <= 0.6, "%.2f m" % worst)
	var both_over := func() -> bool: return _host_rules.phase == RoundManager.Phase.MATCH_END and _client_rules.phase == RoundManager.Phase.MATCH_END
	var ended := await _harness.wait_until(both_over, 60000)
	_check("The match ends on both sides", ended, "host phase %d, client phase %d, rounds %d" % [_host_rules.phase, _client_rules.phase, _host_rules.round_number])
	await _harness.wait_ticks(20)
	_check("Every round ended the same way on the client (winner, reason, score)", _client_rounds == _host_rounds and not _host_rounds.is_empty(),
			"host %s, client %s" % [_host_rounds, _client_rounds])
	_check("The client's kill feed has every kill of the host's, in order (victim, killer, headshot)",
			_client_kills == _host_kills and not _host_kills.is_empty(), "host %s, client %s" % [_host_kills, _client_kills])
	_check("The match's winner and final score are the host's", _client_rules.winner == _host_rules.winner and _client_rules.score == _host_rules.score,
			"host %d %s, client %d %s" % [_host_rules.winner, _host_rules.score, _client_rules.winner, _client_rules.score])
	var same_stats := true
	for character in _host_rules.get_participants():
		var copy := _client.get_character(character.net_id)
		var a := _host_rules.get_stats(character)
		var b := _client_rules.get_stats(copy) if copy != null else null
		if b == null or a.kills != b.kills or a.deaths != b.deaths or a.assists != b.assists or absf(a.damage - b.damage) > 0.01:
			same_stats = false
	_check("The client's scoreboard has the host's kills, deaths, assists and damage", same_stats, "")
	var same_health := true
	for character in _host_rules.get_participants():
		var copy := _client.get_character(character.net_id)
		if copy == null or copy.is_alive() != character.is_alive():
			same_health = false
	_check("Who is alive is the same on both sides", same_health, "")
	var host_end: MatchEndScreen = _host_main.get_node("MatchEndScreen")
	var client_end: MatchEndScreen = _client_main.get_node("MatchEndScreen")
	_check("The end screen's choices are the host's: Play again and Lobby for the host, only Leave for a client",
			host_end.visible and client_end.visible and host_end.get_play_again_button().visible and host_end.get_main_menu_button().text == "Lobby"
					and not client_end.get_play_again_button().visible and not client_end.get_next_map_button().visible
					and client_end.get_main_menu_button().text == "Leave",
			"host %s/%s, client %s/%s" % [host_end.visible, host_end.get_main_menu_button().text, client_end.visible, client_end.get_main_menu_button().text])


func _describe(rules: RoundManager) -> Array:
	return rules.get_participants().map(func(c: Character) -> Array: return [c.net_id, String(c.name), c.team, c.class_data.id])


func _stop() -> void:
	for main in [_client_main, _host_main]:
		if main != null and is_instance_valid(main):
			main.get_parent().remove_child(main)
			main.queue_free()
	for session in [_client_session, _host_session]:
		if session != null and is_instance_valid(session):
			session.close()
	remove_child(_harness)
	_harness.queue_free()


func _check(description: String, passed: bool, detail: String) -> void:
	if passed:
		print("PASS  ", description)
	else:
		_failures += 1
		print("FAIL  ", description, "  (", detail, ")")
