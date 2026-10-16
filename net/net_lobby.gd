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
## [code]slots[/code] ([team 0, team 1]), [code]map[/code] (a scene path). Empty until published.
var info: Dictionary = {}
## True between a match's start and the return to the lobby.
var in_game: bool = false
## What changes scenes: [method SceneTree.change_scene_to_file] by default. Tests replace it to
## see where the lobby would go without leaving the test.
var change_scene: Callable

## The host: the start message of the match being played, for latecomers.
var _current_start: Dictionary = {}


## The lobby of [param game_session], made on first use.
static func of(game_session: NetSession) -> NetLobby:
	var lobby := game_session.get_node_or_null("NetLobby") as NetLobby
	if lobby == null:
		lobby = NetLobby.new()
		lobby.name = "NetLobby"
		lobby.session = game_session
		game_session.add_child(lobby)
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


## The host only: tells everyone what the coming match is: [param summary] (a line for the lobby
## screen), [param slots] per team ([team 0, team 1]) and the [param map]. The slots also limit
## who can join which team.
func publish(summary: String, slots: Array, map: String) -> void:
	if not session.is_host():
		return
	session.team_limits = [int(slots[0]), int(slots[1])]
	session.send_to_all({"lobby": {"summary": summary, "slots": [int(slots[0]), int(slots[1])], "map": map}})


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
		match_starting.emit()
		change_scene.call(GameLaunch.GAME_SCENE)
	elif data.has("to_lobby"):
		in_game = false
		_current_start = {}
		GameLaunch.clear()
		change_scene.call(GameLaunch.MENU_SCENE)


func _on_player_joined(peer_id: int) -> void:
	if session.is_host() and in_game and not _current_start.is_empty():
		session.send_to(peer_id, {"start": _current_start})
	elif session.is_host() and not info.is_empty():
		session.send_to(peer_id, {"lobby": info})


func _on_closed(reason: String) -> void:
	GameLaunch.notice = reason
	var was_in_game := in_game
	in_game = false
	if was_in_game and is_inside_tree():
		GameLaunch.clear()
		get_tree().paused = false
		change_scene.call(GameLaunch.MENU_SCENE)


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
