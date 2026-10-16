extends Node
## Automated checks for the killcam (M17, D-241). Run without a window:
##
##     Godot --headless --path . --fixed-fps 128 --quit-after 120000 res://tests/killcam_test.tscn
##
## Offline, a Team Deathmatch on Square with you and five bots: the recorder keeps everyone's last
## seconds; after your death the replay starts a beat later at your killer's eyes as they were before the
## kill (not where they are now), with their gun in first person, ghosts without hit zones for everyone
## else and the real bodies hidden; your respawn waits for the replay, and skipping it (or having it
## off) gives the plain delay back; everything is put back afterwards. The HUD's overlay (the title, the
## killer and weapon, the bar, the skip hint) shows while it plays and the death view, corners and crosshair
## give way and come back; main.tscn wires the HUD to it and the Killcam setting turns it on and off. Online (in this process,
## [NetHarness]): a client's replay comes from its own recorder, and its skip shortens the host's wait.
## Quits with the number of failed checks as the exit code.

const MAP_SCENE := preload("res://maps/square.tscn")
const HUD_SCENE := preload("res://ui/hud.tscn")
const MAIN_SCENE := preload("res://main.tscn")
const RESPAWN_DELAY := 2.0

var _map: Node3D
var _rounds: RespawnMatch
var _player: Character
var _recorder: KillcamRecorder
var _killcam: Killcam
var _failures: int = 0


func _ready() -> void:
	Weapon.silent = true
	await _test_recording()
	await _test_replay()
	await _test_skip()
	await _test_off()
	await _test_hud()
	await _test_main()
	_free_match()
	await _test_online()
	Weapon.silent = false
	if _failures == 0:
		print("\nAll checks passed.")
	else:
		print("\n%d check(s) FAILED." % _failures)
	get_tree().quit(_failures)


func _test_recording() -> void:
	await _new_match()
	await _wait_seconds(2.0)
	var now := _recorder.get_time()
	var frames := _recorder.get_frames(now - 1.0, now)
	var everyone := frames.all(func(frame: KillcamRecorder.Frame) -> bool: return frame.poses.size() == _rounds.get_participants().size())
	var rate := frames.size() / 1.0
	_check("The recorder keeps everyone's pose, about 64 a second", everyone and rate >= 60.0 and rate <= 66.0,
			"%d notes in the last second, everyone in each: %s" % [frames.size(), everyone])
	await _wait_seconds(KillcamRecorder.SECONDS + 0.5)
	var oldest := _recorder.get_frames(-INF, INF)[0].time
	_check("It keeps only the last %.0f s" % KillcamRecorder.SECONDS, _recorder.get_time() - oldest <= KillcamRecorder.SECONDS + 0.05,
			"oldest %.2f s ago" % (_recorder.get_time() - oldest))


func _test_replay() -> void:
	await _new_match()
	await _wait_seconds(Killcam.BEFORE + 0.5)
	var killer := _enemy_bot()
	_player.take_damage(500.0, Hitbox.Zone.CHEST, killer)
	var died_at := _recorder.get_time()
	# The killer is somewhere else at once: the replay must show where it was, not where it is.
	var away := _rounds.pick_spawn(killer).origin
	killer.respawn(away, killer.rotation.y)
	await _wait_ticks(2)
	var wait := _rounds.get_respawn_time_left(_player)
	var bot_wait := -1.0
	var victim_bot := _rounds.get_participants().filter(func(member: Character) -> bool: return member != _player and member != killer)[0] as Character
	victim_bot.take_damage(500.0, Hitbox.Zone.CHEST, killer)
	await _wait_ticks(1)
	bot_wait = _rounds.get_respawn_time_left(victim_bot)
	_check("Your respawn waits for the killcam; a bot's doesn't", absf(wait - Killcam.TOTAL) < 0.1 and absf(bot_wait - RESPAWN_DELAY) < 0.1,
			"you %.2f s, a bot %.2f s" % [wait, bot_wait])
	var waiting := _killcam.is_active() and not _killcam.is_playing()
	await _wait_seconds(Killcam.BEAT + 0.05)
	var camera := get_viewport().get_camera_3d()
	var frames := _recorder.get_frames(died_at - Killcam.BEFORE, died_at + Killcam.AFTER)
	var first: KillcamRecorder.Pose = frames[0].poses[killer]
	var expected_eye := first.position + Vector3.UP * first.eye_height
	_check("A beat after your death the replay starts, at your killer's eyes as they were %.0f s before the kill" % Killcam.BEFORE,
			waiting and _killcam.is_playing() and camera == _killcam.get_camera() and _killcam.get_killer() == killer
			and camera.global_position.distance_to(expected_eye) < 0.3 and camera.global_position.distance_to(killer.get_eye_position()) > 3.0,
			"waited first %s, playing %s, camera is the killcam's %s, %.2f m from the recorded eye" % [waiting, _killcam.is_playing(),
					camera == _killcam.get_camera(), camera.global_position.distance_to(expected_eye) if camera != null else -1.0])
	var ghosts_ok := true
	for member in _rounds.get_participants():
		var ghost := _killcam.get_ghost(member)
		if member == killer:
			ghosts_ok = ghosts_ok and ghost == null
		else:
			ghosts_ok = ghosts_ok and ghost != null and ghost.get_hitboxes().is_empty()
	var live_hidden := _rounds.get_participants().all(func(member: Character) -> bool: return not member.body.visible)
	var gun := camera.get_children().filter(func(node: Node) -> bool: return node is Weapon)
	_check("Everyone else is a ghost without hit zones, the real bodies hide, and the killer's gun shows in first person",
			ghosts_ok and live_hidden and gun.size() == 1 and (gun[0] as Weapon).data == killer.weapon.data,
			"ghosts %s, live bodies hidden %s, guns under the camera %d" % [ghosts_ok, live_hidden, gun.size()])
	await _wait_seconds(Killcam.BEFORE + Killcam.AFTER - 0.2)
	var still_dead := not _player.is_alive()
	await _wait_seconds(0.4)
	var bodies_back := _rounds.get_participants().filter(func(member: Character) -> bool: return member != _player).all(
			func(member: Character) -> bool: return member.body.visible)
	_check("The replay plays to its end, then you come back and everything is as before",
			still_dead and not _killcam.is_active() and _player.is_alive() and get_viewport().get_camera_3d() != _killcam.get_camera()
			and bodies_back and _killcam.get_child_count() == 0,
			"dead until the end %s, active %s, alive %s, bodies back %s, nodes left %d" % [still_dead, _killcam.is_active(), _player.is_alive(), bodies_back, _killcam.get_child_count()])


func _test_skip() -> void:
	await _new_match()
	await _wait_seconds(Killcam.BEFORE + 0.5)
	_player.take_damage(500.0, Hitbox.Zone.CHEST, _enemy_bot())
	await _wait_seconds(Killcam.BEAT + 0.5)
	var playing := _killcam.is_playing()
	var before := _rounds.get_respawn_time_left(_player)
	_killcam.skip()
	await _wait_ticks(2)
	var after := _rounds.get_respawn_time_left(_player)
	var expected := RESPAWN_DELAY - Killcam.BEAT - 0.5
	_check("Skipping stops the replay and gives the plain respawn delay back",
			playing and not _killcam.is_active() and absf(after - expected) < 0.1 and before > after,
			"playing %s, %.2f s left before, %.2f after (expected %.2f)" % [playing, before, after, expected])
	await _wait_seconds(expected + 0.2)
	_check("…and you come back after it", _player.is_alive(), "alive %s" % _player.is_alive())


func _test_off() -> void:
	await _new_match()
	_killcam.enabled = false
	await _wait_seconds(1.0)
	_player.take_damage(500.0, Hitbox.Zone.CHEST, _enemy_bot())
	await _wait_ticks(2)
	var wait := _rounds.get_respawn_time_left(_player)
	await _wait_seconds(Killcam.BEAT + 0.2)
	_check("With the killcam off there is no replay and the plain respawn delay", not _killcam.is_active() and absf(wait - RESPAWN_DELAY) < 0.1,
			"active %s, wait %.2f s" % [_killcam.is_active(), wait])


# --- The HUD overlay ---


## The killcam overlay of the HUD (title, killer, weapon, bar, skip hint) shows while the replay plays and the death view,
## corners, crosshair and compass give way; skipping brings the death view and its countdown back, and so does the replay's end.
func _test_hud() -> void:
	await _new_match()
	# A longer plain delay, so there is still a countdown to show after a skip.
	_rounds.settings.respawn_delay = 4.0
	var hud := HUD_SCENE.instantiate()
	add_child(hud)
	hud.set_round_manager(_rounds)
	hud.set_player(_player)
	hud.set_killcam(_killcam)
	await _wait_seconds(Killcam.BEFORE + 0.5)
	var alive_ok := _hud_view_is_alive(hud)
	_check("Alive: the killcam overlay is hidden and the corners, the crosshair and the compass show",
			alive_ok and not hud.is_killcam_shown() and hud.get_killcam_killer_text() == "" and hud.get_killcam_progress_shown() == -1.0,
			"overlay %s, view alive %s" % [hud.is_killcam_shown(), alive_ok])
	var killer := _enemy_bot()
	_player.take_damage(500.0, Hitbox.Zone.CHEST, killer)
	await _wait_ticks(4)
	var beat_ok: bool = not hud.is_killcam_shown() and hud.get_respawn_text().begins_with("Respawning in") and (hud.get_node("%DeathColumn") as Control).visible
	_check("In the beat before the replay the death view shows as usual (the countdown, the plate) and the overlay doesn't",
			beat_ok, "overlay %s, text '%s'" % [hud.is_killcam_shown(), hud.get_respawn_text()])
	await _wait_seconds(Killcam.BEAT + 0.3)
	var skip_text: String = hud.get_killcam_skip_text()
	var name_label := hud.get_node("%KillcamName") as Label
	var first_fill: float = hud.get_killcam_progress_shown()
	await _wait_seconds(0.4)
	var later_fill: float = hud.get_killcam_progress_shown()
	var click_through := true
	for node in (hud.get_node("%KillcamOverlay") as Control).find_children("*", "Control", true, false):
		click_through = click_through and (node as Control).mouse_filter == Control.MOUSE_FILTER_IGNORE
	_check("While it plays the overlay shows the killer's name in their team's colour, their weapon, the skip hint with the Jump key, and a bar that fills with the replay (and ignores the mouse)",
			_killcam.is_playing() and hud.is_killcam_shown() and hud.get_killcam_killer_text() == String(killer.name)
			and name_label.get_theme_color("font_color") == Teams.ui_color_of(killer)
			and hud.get_killcam_weapon_text() == killer.weapon.data.display_name
			and skip_text != "" and skip_text == LastInput.prompt_for(&"jump")
			and first_fill >= 0.0 and later_fill > first_fill and later_fill < 1.0 and click_through,
			"killer '%s', weapon '%s', skip '%s', bar %.2f → %.2f, click-through %s" % [hud.get_killcam_killer_text(),
					hud.get_killcam_weapon_text(), skip_text, first_fill, later_fill, click_through])
	var hidden_ok: bool = not (hud.get_node("Crosshair") as Control).visible and not (hud.get_node("%BottomLeft") as Control).visible \
			and not (hud.get_node("%BottomRight") as Control).visible and not (hud.get_node("%DeathColumn") as Control).visible \
			and not (hud.get_node("%DeadTint") as Control).visible and not (hud.get_node("%Compass") as Control).visible
	_check("Meanwhile the crosshair, the health and ammo corners, the compass, the death tint and the 'Killed by / Respawning in' plate are hidden",
			hidden_ok and hud.get_respawn_text() == "", "hidden %s, respawn text '%s'" % [hidden_ok, hud.get_respawn_text()])
	_killcam.skip()
	await _wait_ticks(4)
	var dead_back: bool = not hud.is_killcam_shown() and hud.get_respawn_text().begins_with("Respawning in") \
			and (hud.get_node("%DeathColumn") as Control).visible and (hud.get_node("%DeadTint") as Control).visible \
			and not (hud.get_node("Crosshair") as Control).visible and not (hud.get_node("%BottomLeft") as Control).visible
	_check("After a skip the overlay is gone and the death view with its countdown is back (the crosshair and the corners stay hidden while you are dead)",
			dead_back, "overlay %s, text '%s'" % [hud.is_killcam_shown(), hud.get_respawn_text()])
	var plain_wait := _rounds.get_respawn_time_left(_player)
	await _wait_seconds(plain_wait + 0.3)
	await _wait_ticks(4)
	_check("When you respawn the corners, the crosshair and the compass are back and the death view is gone",
			_player.is_alive() and _hud_view_is_alive(hud) and hud.get_respawn_text() == "" and not hud.is_killcam_shown(),
			"alive %s, view alive %s" % [_player.is_alive(), _hud_view_is_alive(hud)])
	# Again, played to its end.
	_player.take_damage(500.0, Hitbox.Zone.CHEST, _enemy_bot())
	await _wait_seconds(Killcam.BEAT + 0.3)
	var again: bool = hud.is_killcam_shown()
	await _wait_seconds(Killcam.TOTAL - Killcam.BEAT + 0.4)
	await _wait_ticks(4)
	_check("A replay played to its end (and your respawn at its end) puts the view back as well",
			again and not hud.is_killcam_shown() and _player.is_alive() and _hud_view_is_alive(hud),
			"showed %s, overlay now %s, alive %s" % [again, hud.is_killcam_shown(), _player.is_alive()])
	# A new map's killcam replaces the old one: the overlay never sticks.
	hud.set_killcam(null)
	_check("set_killcam(null) clears the overlay", not hud.is_killcam_shown(), "overlay %s" % hud.is_killcam_shown())
	remove_child(hud)
	hud.queue_free()


## True while the HUD shows the living player's view: the crosshair, the corners and the compass, and nothing of the death view or the killcam.
func _hud_view_is_alive(hud: Node) -> bool:
	return (hud.get_node("Crosshair") as Control).visible and (hud.get_node("%BottomLeft") as Control).visible \
			and (hud.get_node("%BottomRight") as Control).visible and (hud.get_node("%Compass") as Control).visible \
			and not (hud.get_node("%DeathColumn") as Control).visible and not (hud.get_node("%DeadTint") as Control).visible \
			and not (hud.get_node("%KillcamOverlay") as Control).visible


## main.tscn adds the killcam and hands it to the HUD, and the Killcam setting (the shared instance, never loaded from disk)
## turns it on and off in a running match.
func _test_main() -> void:
	_free_match()
	var main := MAIN_SCENE.instantiate()
	# Never read or write the player's settings file.
	main.set("load_settings", false)
	main.set("map_scene", MAP_SCENE)
	main.set("match_settings", _settings())
	add_child(main)
	await _wait_ticks(3)
	(main.get_node("ClassMenu") as ClassMenu).close()
	var killcam := main.call("get_killcam") as Killcam
	var hud := main.get_node("HUD")
	var settings := Settings.get_instance()
	var on_at_first := killcam != null and killcam.enabled
	settings.killcam = false
	var turned_off := not killcam.enabled
	settings.killcam = true
	var turned_on := killcam.enabled
	_check("The Killcam setting reaches the running match's killcam at once, both ways (on by default)",
			on_at_first and turned_off and turned_on, "on at first %s, off %s, on again %s" % [on_at_first, turned_off, turned_on])
	var player := (main.call("get_map") as Node).get_node("Player") as Character
	var rules := (main.call("get_map") as Node).get_node("RespawnMatch") as RespawnMatch
	var ticks := 0
	while rules.phase != RoundManager.Phase.LIVE and ticks < 128 * 5:
		await get_tree().physics_frame
		ticks += 1
	var killer: Character = null
	for member in rules.get_participants():
		if member != player:
			member.frozen = true
			if member.team != player.team:
				killer = member
	await _wait_seconds(Killcam.BEFORE + 0.5)
	player.take_damage(500.0, Hitbox.Zone.CHEST, killer)
	await _wait_seconds(Killcam.BEAT + 0.3)
	_check("In a real match (main.tscn) the HUD shows the killcam overlay with the killer's name while the replay plays, and hides it when you skip",
			killcam.is_playing() and hud.is_killcam_shown() and hud.get_killcam_killer_text() == String(killer.name),
			"playing %s, overlay %s, killer '%s'" % [killcam.is_playing(), hud.is_killcam_shown(), hud.get_killcam_killer_text()])
	killcam.skip()
	await _wait_ticks(4)
	_check("…and after the skip the overlay is hidden and the plain countdown shows", not hud.is_killcam_shown() and hud.get_respawn_text().begins_with("Respawning in"),
			"overlay %s, text '%s'" % [hud.is_killcam_shown(), hud.get_respawn_text()])
	settings.reset_to_defaults()
	remove_child(main)
	main.queue_free()
	MenuState.reset()
	await _wait_ticks(5)


# --- Online ---


func _test_online() -> void:
	var harness := NetHarness.new()
	add_child(harness)
	var host_session := harness.start_host("Host", "Host")
	var client_session := harness.start_client("Client", "Jan")
	await harness.wait_until(client_session.is_active)
	var rules := _settings()
	var host_main := harness.start_game(host_session.get_parent(), host_session, MAP_SCENE, rules)
	var client_main := harness.start_game(client_session.get_parent(), client_session, MAP_SCENE, rules)
	var host := host_main.get_net_game() as NetHost
	var client := client_main.get_net_game() as NetClient
	var both := func() -> bool: return host.is_started() and client.is_welcomed()
	await harness.wait_until(both, 1200)
	var live := func() -> bool: return host.rules.phase == RoundManager.Phase.LIVE
	await harness.wait_until(live, 1200)
	for character in host.rules.get_participants():
		NetHarness.silence(character)
		if character.get_node_or_null("BotController") != null:
			character.frozen = true
	var killcam := client_main.get_killcam() as Killcam
	var own: Character = client.player
	var friend := host.get_character(own.net_id)
	var killer: Character = null
	for character in host.rules.get_participants():
		if character.team != friend.team and character.get_node_or_null("BotController") != null:
			killer = character
	await harness.wait_ticks(128 * 2)
	friend.take_damage(500.0, Hitbox.Zone.CHEST, killer)
	var started := func() -> bool: return killcam != null and killcam.is_playing()
	var played := await harness.wait_until(started, 128 * 3)
	var shown := killcam.get_killer() if killcam != null else null
	_check("Online: the client's replay plays from its own recorder, at the killer's puppet",
			played and shown != null and shown.net_id == killer.net_id,
			"killcam %s, playing %s, killer shown %s" % [killcam != null, played, shown.net_id if shown != null else -1])
	var before := (host.rules as RespawnMatch).get_respawn_time_left(friend)
	if killcam != null:
		killcam.skip()
	var shortened := func() -> bool: return (host.rules as RespawnMatch).get_respawn_time_left(friend) < before - 2.0
	var skipped := await harness.wait_until(shortened, 128)
	_check("Online: skipping on the client shortens the host's wait", skipped,
			"host's wait %.2f s → %.2f s" % [before, (host.rules as RespawnMatch).get_respawn_time_left(friend)])
	for main in [client_main, host_main]:
		main.get_parent().remove_child(main)
		main.queue_free()
	for session in [client_session, host_session]:
		session.close()
	for i in 40:
		await get_tree().physics_frame
	remove_child(harness)
	harness.queue_free()
	for i in 5:
		await get_tree().physics_frame


# --- Helpers ---


func _settings() -> MatchSettings:
	var settings := MatchSettings.new()
	settings.game_mode = MatchSettings.GameMode.TEAM_RESPAWN
	settings.team_size = 3
	settings.enemy_team_size = 3
	settings.freeze_time = 0.5
	settings.round_end_time = 1.0
	settings.kill_limit = 50
	settings.time_limit = 300.0
	settings.respawn_delay = RESPAWN_DELAY
	settings.bots_buy = false
	return settings


## A Team Deathmatch on Square: you and five bots, held still, with the killcam's recorder and replay
## as main.gd adds them.
func _new_match() -> void:
	_free_match()
	_map = MAP_SCENE.instantiate()
	_player = _map.get_node("Player")
	add_child(_map)
	await _wait_ticks(30)
	_rounds = RespawnMatch.new()
	_rounds.settings = _settings()
	_rounds.rng.seed = 3
	_map.add_child(_rounds)
	_recorder = KillcamRecorder.new()
	_map.add_child(_recorder)
	_killcam = Killcam.new()
	_map.add_child(_killcam)
	_killcam.setup(_rounds, _player, _recorder)
	await _wait_ticks(2)
	for member in _rounds.get_participants():
		member.footstep_sound = null
	Teams.set_viewer(_player)
	var ticks := 0
	while _rounds.phase != RoundManager.Phase.LIVE and ticks < 128 * 5:
		await get_tree().physics_frame
		ticks += 1
	for member in _rounds.get_participants():
		if member != _player:
			member.frozen = true


func _free_match() -> void:
	if _map != null:
		remove_child(_map)
		_map.queue_free()
		_map = null


func _enemy_bot() -> Character:
	for member in _rounds.get_participants():
		if member.team != _player.team:
			return member
	return null


func _wait_seconds(seconds: float) -> void:
	await _wait_ticks(roundi(seconds * Engine.physics_ticks_per_second))


func _wait_ticks(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _check(check_name: String, passed: bool, detail: String) -> void:
	if passed:
		print("PASS  ", check_name, "  (", detail, ")")
	else:
		_failures += 1
		print("FAIL  ", check_name, "  (", detail, ")")
