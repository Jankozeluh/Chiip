class_name NetLobby
extends Node
## The lobby of an online session and the way between it and the game (M9, D-108).
##
## It lives as a child of the [NetSession] (so it survives scene changes too) and keeps what
## everyone needs to know before a match: the host's [member info] (the match's summary for
## the lobby screen, each team's number of slots, the map). The host decides:
## - [method publish] sends the lobby's [member info] to everyone (the lobby screen shows it);
##   the slots also become the session's team limits, so a full team refuses newcomers.
## - [method start_match] starts a match on every computer: each one leaves a [GameLaunch]
##   description with the session in it and changes to the game scene (D-064), the host's
##   game waits for the others to load. Play again and Next map at the end of a match use it
##   too, so everyone comes along.
## - [method return_to_lobby] takes everyone back to the main menu's lobby.
## When the session ends while you are in the lobby or a match (the host left, the connection
## was lost) everyone left goes back to the main menu, which shows why
## ([member GameLaunch.notice]). Someone who joins while a match is being played is sent that
## match at once and takes over a bot when they have loaded it (D-110, [NetHost]).
##
## [b]The host advertises the game on the local network[/b] (M17, D-242): while it hosts, a
## [LanDiscovery] beacon tells everyone on the network the host's name, port, mode, map, how many
## are in and whether a match is running, so a friend's Join page lists the game. It starts when the
## lobby is first published ([method publish]), follows the roster, the lobby's settings and the
## match's start and end, and stops when the session closes ([member discovery]).
##
## Its sibling [NetChat] (M17, D-243) carries the text chat of the lobby and of the match; [method of] makes it too.
##
## The match travels as a Dictionary ([method settings_to_dict]): every stored property of the
## [MatchSettings], with the bot difficulty by its file. The class each player plays is not in
## it: every player picks their own in the game (D-078).

## Emitted on every computer when the host's lobby info changed.
signal info_changed
## Emitted on every computer right before it changes to the game scene for a match.
signal match_starting

## The session this lobby belongs to.
var session: NetSession
## The host's description of the coming match: [code]summary[/code] (a line for people),
## [code]slots[/code] ([team 0, team 1]), [code]map[/code] (a scene path), and optionally
## [code]facts[/code] (the lobby footer's [code]mode[/code], [code]map[/code] and [code]limit[/code]
## as ready-made texts). Empty until published.
var info: Dictionary = {}
## True between a match's start and the return to the lobby.
var in_game: bool = false
## What changes scenes: [method SceneTree.change_scene_to_file] by default. Tests replace it to
## see where the lobby would go without leaving the test.
var change_scene: Callable

## The host's LAN beacon (M17, D-242), made when the lobby is first published, or null.
var discovery: LanDiscovery

## The host: the start message of the match being played, for latecomers.
var _current_start: Dictionary = {}
## The host: what the beacon says besides the roster: the mode id ([method LanDiscovery.mode_id]),
## the map's title and the match's slots in all. [member _published] once [method publish] was called.
var _advert_mode: String = "tdm"
var _advert_map: String = ""
var _advert_slots: int = LanDiscovery.MAX_PLAYERS
var _published: bool = false


## The lobby of [param game_session], made on first use.
static func of(game_session: NetSession) -> NetLobby:
	var lobby := game_session.get_node_or_null("NetLobby") as NetLobby
	if lobby == null:
		lobby = NetLobby.new()
		lobby.name = "NetLobby"
		lobby.session = game_session
		game_session.add_child(lobby)
		# The session's chat lives beside its lobby from the start, so no line said in the lobby is missed.
		NetChat.of(game_session)
	return lobby


## The session at the root of [param tree] (the one the main menu opened), or null.
static func find_session(tree: SceneTree) -> NetSession:
	var session := tree.root.get_node_or_null(NetSession.NODE_NAME) as NetSession
	return session if session != null and not session.is_queued_for_deletion() else null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if session == null:
		session = get_parent() as NetSession
	if not change_scene.is_valid():
		change_scene = func(path: String) -> void: get_tree().change_scene_to_file(path)
	session.match_message.connect(_on_match_message)
	session.closed.connect(_on_closed)
	session.player_joined.connect(_on_player_joined)
	session.roster_changed.connect(_refresh_advertisement)


## The host only: tells everyone what the coming match is: [param summary] (a line for the lobby
## screen), [param slots] per team ([team 0, team 1]), the [param map] and the [param facts] the
## lobby footer shows (ready-made texts, may be empty). The slots also limit who can join which team.
## [param mode] is the match's mode in the settings' words ("respawn", "ffa", "rounds"); it, the
## map's title and the slots go into the LAN beacon, which starts with the first call (see the class description).
func publish(summary: String, slots: Array, map: String, facts: Dictionary = {}, mode: String = "respawn") -> void:
	if not session.is_host():
		return
	session.team_limits = [int(slots[0]), int(slots[1])]
	session.send_to_all({"lobby": {"summary": summary, "slots": [int(slots[0]), int(slots[1])], "map": map, "facts": facts}})
	_published = true
	_advert_mode = LanDiscovery.mode_id(mode)
	_advert_map = GameLaunch.map_title(map)
	_advert_slots = clampi(int(slots[0]) + int(slots[1]), 1, LanDiscovery.MAX_PLAYERS)
	_refresh_advertisement()


## The host only: starts a match on [param map] by [param rules] on every computer (and the
## rotation [param maps], first map first, or none). Everyone changes to the game scene.
func start_match(map: String, rules: MatchSettings, maps: Array[String] = []) -> void:
	if not session.is_host():
		return
	session.send_to_all({"start": {"map": map, "rules": settings_to_dict(rules), "rotation": maps}})


## The host only: everyone goes back to the main menu's lobby.
func return_to_lobby() -> void:
	if session.is_host():
		session.send_to_all({"to_lobby": true})


func _on_match_message(data: Dictionary) -> void:
	if data.has("lobby"):
		info = data["lobby"]
		info_changed.emit()
	elif data.has("start"):
		var start: Dictionary = data["start"]
		_current_start = start
		var maps: Array[String] = []
		for path: Variant in start.get("rotation", []):
			maps.append(String(path))
		GameLaunch.start_match(String(start["map"]), settings_from_dict(start["rules"]), maps)
		GameLaunch.net_session = session
		in_game = true
		_refresh_advertisement()
		match_starting.emit()
		change_scene.call(GameLaunch.GAME_SCENE)
	elif data.has("to_lobby"):
		in_game = false
		_current_start = {}
		_refresh_advertisement()
		GameLaunch.clear()
		change_scene.call(GameLaunch.MENU_SCENE)


func _on_player_joined(peer_id: int) -> void:
	if session.is_host() and in_game and not _current_start.is_empty():
		session.send_to(peer_id, {"start": _current_start})
	elif session.is_host() and not info.is_empty():
		session.send_to(peer_id, {"lobby": info})


func _on_closed(reason: String) -> void:
	if discovery != null:
		discovery.stop_advertising()
	GameLaunch.notice = reason
	var was_in_game := in_game
	in_game = false
	if was_in_game and is_inside_tree():
		GameLaunch.clear()
		get_tree().paused = false
		change_scene.call(GameLaunch.MENU_SCENE)


## The host: starts the LAN beacon on the first call after [method publish] and keeps it current:
## the players in the roster, the match's slots, the mode and map, and whether a match is running.
## Does nothing before the first publish, or once the session is over.
func _refresh_advertisement() -> void:
	if not _published or session == null or not session.is_host() or not session.is_active() or not is_inside_tree():
		return
	var players := session.get_players().size()
	var beacon := {
		"name": session.local_name,
		"port": session.game_port,
		"mode": _advert_mode,
		"map": _advert_map,
		"players": players,
		"max_players": maxi(_advert_slots, players),
		"in_game": in_game,
	}
	if discovery == null:
		discovery = LanDiscovery.new()
		discovery.name = "LanDiscovery"
		add_child(discovery)
	if discovery.is_advertising():
		discovery.update(beacon)
	else:
		discovery.advertise(beacon)


# --- The match as a Dictionary ---


## Every stored property of [param rules] (the exported ones), the bot difficulty by its file
## and without the player's class.
static func settings_to_dict(rules: MatchSettings) -> Dictionary:
	var data := {}
	for property in rules.get_property_list():
		if property["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE == 0 or property["usage"] & PROPERTY_USAGE_STORAGE == 0:
			continue
		var key: String = property["name"]
		var value: Variant = rules.get(key)
		if key == "player_class":
			continue
		if value is Resource:
			data[key] = (value as Resource).resource_path
		else:
			data[key] = value
	return data


## The [MatchSettings] of a Dictionary made by [method settings_to_dict]. Unknown keys are
## ignored, missing ones keep their defaults.
static func settings_from_dict(data: Dictionary) -> MatchSettings:
	var rules := MatchSettings.new()
	for property in rules.get_property_list():
		var key: String = property["name"]
		if not data.has(key) or key == "player_class":
			continue
		if key == "bot_difficulty":
			var path := String(data[key])
			if path.begins_with("res://bots/") and ResourceLoader.exists(path):
				rules.bot_difficulty = load(path) as BotDifficulty
			continue
		var current: Variant = rules.get(key)
		if typeof(data[key]) == typeof(current) or (current is float and data[key] is int):
			rules.set(key, data[key])
	return rules
