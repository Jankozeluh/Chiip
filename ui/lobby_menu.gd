class_name LobbyMenu
extends CanvasLayer
## The multiplayer screens (M9, D-108): the main menu's Host and Join items open this panel,
## where you host a game or join one, and then wait in the lobby for the match to start.
##
## [b]Two pages[/b] in one panel, one shown at a time. The [b]connect page[/b] has your name, the
## host's address and the port (each written to [Settings] the moment you edit it, like the other
## menus: [code]online_name[/code], [code]online_address[/code], [code]online_port[/code]) and the
## buttons Host game, Join and Back, with a status line for "Connecting to ...", errors and the
## reason the last online game ended ([member GameLaunch.notice], shown once). The [b]lobby page[/b]
## shows the two teams side by side with the players in each (you are "(you)", the host
## "(host)"), "Bot" rows for the slots nobody has taken, a Join Team button under each team, and
## the host's summary of the match. The host also gets Match settings (the [MatchSetup] panel,
## whose Start button reads "Done" here) and Start match; a client sees "Waiting for the host to
## start the match...". Leave ends your part of the session (the host ends it for everyone).
##
## The panel only drives a [NetSession] and its [NetLobby]: [method host_game] and
## [method join_game] open the session at the root of the tree ([method NetSession.open]), the
## host publishes the lobby's info (summary, slots, map) whenever the lobby opens, somebody
## joins or leaves, a team changes or a match setting changes, and [method start_match] asks
## [method NetLobby.start_match], after which every computer changes to the game scene by itself.
## Coming back from an online match the main menu opens this panel again: on the lobby page when
## the session is still up, otherwise on the connect page with the reason. The panel registers with
## [MenuState] while it is open; Esc leaves the lobby, or closes the connect page. Its look comes
## from the UI theme (D-057): theme type variations only, and [method set_ui_scale] gives it the
## theme scaled for the window like the other menus. [member settings] is the shared instance
## unless a test hands in its own ([method set_settings]).

## Emitted when the panel closes (Back or Esc on the connect page).
signal closed

## The pages of the panel.
enum Page {
	## Name, address, port and the Host game / Join buttons.
	CONNECT,
	## The teams, the players, and the match.
	LOBBY,
}

const MATCH_SETUP_SCENE := preload("res://ui/match_setup.tscn")

## Where the choices are stored. The shared [Settings] when null (set before the panel is in the tree).
var settings: Settings

var _page: Page = Page.CONNECT
## The session this panel drives: hosting, connected, or connecting. Null on the connect page.
var _session: NetSession
## True between [method join_game] and the host's answer.
var _connecting: bool = false
## Why a join failed (the status shows it; the session's closing follows with its own text).
var _join_failure: String = ""
## The factor [method set_ui_scale] was last given, for rows added later.
var _ui_scale: float = 1.0
## The match settings panel (host only), made when first needed.
var _setup: MatchSetup
## The addresses friends can join the host at, found when the lobby opens.
var _addresses: Array[String] = []
## The session that is still closing after [method leave]: a host with friends gives them a moment
## to hear it ([method NetSession.close]). Every session at the root shares the tree's one
## multiplayer, so hosting or joining again before it is gone would be torn down by its closing;
## Host game and Join wait.
var _closing_session: NetSession
## The host's team when the lobby info was last published (-1: not yet); the slots depend on it.
var _published_host_team: int = -1

@onready var _title: Label = %Title
@onready var _connect_page: Control = %ConnectPage
@onready var _lobby_page: Control = %LobbyPage
@onready var _name_field: LineEdit = %NameField
@onready var _address_field: LineEdit = %AddressField
@onready var _port_field: LineEdit = %PortField
@onready var _status: Label = %Status
@onready var _back_button: Button = %BackButton
@onready var _join_button: Button = %JoinButton
@onready var _host_button: Button = %HostButton
@onready var _info_label: Label = %Info
@onready var _header_panels: Array[PanelContainer] = [%Header0, %Header1]
@onready var _lists: Array[Control] = [%List0, %List1]
@onready var _join_team_buttons: Array[Button] = [%JoinTeamButton0, %JoinTeamButton1]
@onready var _summary_label: Label = %Summary
@onready var _waiting_label: Label = %Waiting
@onready var _leave_button: Button = %LeaveButton
@onready var _settings_button: Button = %SettingsButton
@onready var _start_button: Button = %StartButton


func _ready() -> void:
	visible = false
	if settings == null:
		settings = Settings.get_instance()
	settings.changed.connect(_on_setting_changed)
	_name_field.text_changed.connect(func(text: String) -> void: settings.online_name = text)
	_address_field.text_changed.connect(func(text: String) -> void: settings.online_address = text)
	_port_field.text_changed.connect(_on_port_text_changed)
	_port_field.focus_exited.connect(_show_stored_port)
	_host_button.pressed.connect(host_game)
	_join_button.pressed.connect(join_game)
	_back_button.pressed.connect(close)
	_leave_button.pressed.connect(leave)
	_settings_button.pressed.connect(open_match_settings)
	_start_button.pressed.connect(start_match)
	for team in Teams.COUNT:
		_join_team_buttons[team].pressed.connect(join_team.bind(team))
	_refresh_fields()
	_show_connect_page()
	UiSounds.attach(self)


func _exit_tree() -> void:
	# Freed or removed while open (the game starts under it): don't leave the game waiting for a menu.
	MenuState.close(self)


func _input(event: InputEvent) -> void:
	# Only the menu on top reacts to Esc: with the match settings open, they are on top.
	if visible and MenuState.is_top(self) and event.is_action_pressed("pause"):
		if _page == Page.LOBBY:
			leave()
		else:
			close()
		get_viewport().set_input_as_handled()


## Shows the panel with the mouse: the lobby page when a session is running (coming back from a
## match), otherwise the connect page, with the reason the last online game ended if there is one.
func open() -> void:
	visible = true
	MenuState.open(self)
	var running := NetLobby.find_session(get_tree())
	if running != null and running.is_active():
		if _session != running:
			_adopt(running)
		_show_lobby_page()
		return
	if running != null and running != _session:
		# A session that ended (or never got going) and nobody freed.
		running.close()
	_refresh_fields()
	if _session == null:
		_show_connect_page()
		if not GameLaunch.notice.is_empty():
			_set_status(GameLaunch.notice)
			GameLaunch.notice = ""


## Hides the panel, hands the mouse back (if it was the last menu open) and emits [signal closed].
## A connection attempt or session this panel started ends with it ([method leave]). Does nothing
## when the panel isn't open.
func close() -> void:
	if not visible:
		return
	leave()
	visible = false
	MenuState.close(self)
	closed.emit()


## True while the panel is shown.
func is_open() -> bool:
	return visible


## Scales the panel; 1.0 is the size it is designed for (a 720-pixel-tall window). Hands it the
## theme scaled for the window ([UiTheme]); the match settings panel it holds is scaled with it.
func set_ui_scale(factor: float) -> void:
	_ui_scale = factor
	UiTheme.apply(self, factor)


## Uses [param new_settings] instead of the shared [Settings] (tests hand in a [code]Settings.new()[/code]).
func set_settings(new_settings: Settings) -> void:
	if settings != null and is_node_ready():
		settings.changed.disconnect(_on_setting_changed)
	settings = new_settings
	if is_node_ready():
		settings.changed.connect(_on_setting_changed)
		if _setup != null:
			remove_child(_setup)
			_setup.queue_free()
			_setup = null
		_refresh_fields()


## Starts hosting on the port in the port field as the name in the name field, and shows the
## lobby. Returns OK, or the error (the status line says what went wrong: a port that is in use).
func host_game() -> Error:
	if _session != null:
		return ERR_ALREADY_IN_USE
	if _is_closing_session():
		_set_status("Still closing the last game, one moment.")
		return ERR_BUSY
	_store_fields()
	var port := settings.online_port
	var session := _open_session()
	var result := session.host_game(settings.online_name, port)
	if result != OK:
		session.close()
		_set_status("Port %d is in use." % port if result == ERR_CANT_CREATE
				else "Couldn't host on port %d (error %d)." % [port, result])
		return result
	_adopt(session)
	_show_lobby_page()
	return OK


## Connects to the host in the address field (at the port in the port field) as the name in the
## name field. Returns OK when the attempt started: the status says "Connecting to ..." and the
## lobby follows once the host accepts; a refusal or a failure shows its reason here instead.
func join_game() -> Error:
	if _session != null:
		return ERR_ALREADY_IN_USE
	if _is_closing_session():
		_set_status("Still closing the last game, one moment.")
		return ERR_BUSY
	_store_fields()
	var address := settings.online_address
	var port := settings.online_port
	if address.is_empty():
		_set_status("Type the host's address first.")
		return ERR_INVALID_PARAMETER
	var session := _open_session()
	var result := session.join_game(address, settings.online_name, port)
	if result != OK:
		session.close()
		_set_status("Couldn't find \"%s\"." % address if result == ERR_CANT_RESOLVE
				else "Couldn't connect to %s:%d (error %d)." % [address, port, result])
		return result
	_connecting = true
	_adopt(session)
	_set_connect_enabled(false)
	_set_status("Connecting to %s:%d…" % [address, port])
	# The buttons are off; Back cancels.
	_back_button.grab_focus()
	return OK


## Leaves the session (the host ends it for everyone) and returns to the connect page at once;
## the session finishes closing by itself (a host gives its friends a moment to hear it, see
## [method NetSession.close]). On the connect page it cancels a connection attempt.
func leave() -> void:
	var session := _release_session()
	if session != null:
		session.close()
		if is_instance_valid(session) and not session.is_queued_for_deletion():
			_closing_session = session
			session.tree_exited.connect(_on_closing_session_gone, CONNECT_ONE_SHOT)
	if _setup != null and _setup.is_open():
		_setup.close()
	_show_connect_page()


## Moves you to [param team] (0 or 1). The host decides: a full team refuses.
func join_team(team: int) -> void:
	if _session != null:
		_session.request_team(team)


## Host only: opens the match settings (the [MatchSetup] panel, its Start button reads "Done").
func open_match_settings() -> void:
	if _session != null and _session.is_host():
		_get_setup().open()


## Host only: starts the match the lobby describes, on every computer: the map (or the rotation,
## starting with it) and the rules are the stored match choices ([method NetLobby.start_match]).
func start_match() -> void:
	if _session == null or not _session.is_host():
		return
	var rotation := _chosen_rotation()
	var map := rotation[0] if not rotation.is_empty() else _chosen_map()
	NetLobby.of(_session).start_match(map, GameLaunch.match_settings_from(settings), rotation)


## The one-line summary of the match the stored choices make, as the host publishes it:
## "Rounds · Depot · first to 5 rounds · Normal bots".
func build_summary() -> String:
	var respawn := settings.match_mode == "respawn"
	var parts: Array[String] = ["Team respawn" if respawn else "Rounds"]
	var rotation := _chosen_rotation()
	if rotation.is_empty():
		parts.append(GameLaunch.map_title(_chosen_map()))
	else:
		parts.append("Rotation: %s" % ", ".join(rotation.map(func(path: String) -> String: return GameLaunch.map_title(path))))
	parts.append("first to %d kills" % settings.match_kill_limit if respawn else "first to %d rounds" % settings.match_rounds_to_win)
	parts.append("%s bots" % settings.match_difficulty.capitalize())
	if settings.match_friendly_fire:
		parts.append("friendly fire")
	return " · ".join(PackedStringArray(parts))


## The scene path of the map the stored choices name: the stored map, or the default one when it
## is gone (what [MatchSetup] shows).
func _chosen_map() -> String:
	var maps := GameLaunch.list_maps()
	if maps.has(settings.match_map):
		return settings.match_map
	return Settings.DEFAULT_MAP if maps.has(Settings.DEFAULT_MAP) else maps[0]


## The maps played one after the other, starting at the chosen one; empty for a single map.
func _chosen_rotation() -> Array[String]:
	if not settings.match_rotation:
		return []
	return GameLaunch.rotation_maps(_chosen_map())


## This computer's IPv4 addresses a friend on the same network can join at (not 127.x, not
## link-local, no IPv6).
static func local_addresses() -> Array[String]:
	var found: Array[String] = []
	for address: String in IP.get_local_addresses():
		if address.contains(":") or not address.contains("."):
			continue
		if address.begins_with("127.") or address.begins_with("169.254.") or address == "0.0.0.0":
			continue
		if not found.has(address):
			found.append(address)
	return found


# --- The pages ---


func _show_connect_page() -> void:
	_page = Page.CONNECT
	_title.text = "Multiplayer"
	_connect_page.visible = true
	_lobby_page.visible = false
	_set_connect_enabled(not _connecting)
	_set_status("")
	if visible:
		_host_button.grab_focus()


func _show_lobby_page() -> void:
	_page = Page.LOBBY
	_title.text = "Lobby"
	_connect_page.visible = false
	_lobby_page.visible = true
	var host := _session.is_host()
	_settings_button.visible = host
	_start_button.visible = host
	_waiting_label.visible = not host
	if host:
		_addresses = local_addresses()
		_publish()
	_refresh_lobby()
	if visible:
		(_start_button if host else _leave_button).grab_focus()


## Fills the lobby page from the session's roster and the host's published info.
func _refresh_lobby() -> void:
	if _page != Page.LOBBY or _session == null:
		return
	var host := _session.is_host()
	if host:
		_info_label.text = "Hosting on port %d" % settings.online_port
		if not _addresses.is_empty():
			_info_label.text += " · friends join at %s" % ", ".join(PackedStringArray(_addresses))
	else:
		_info_label.text = "Connected to %s" % settings.online_address
	var info := NetLobby.of(_session).info
	var slots: Array = info.get("slots", [])
	_summary_label.text = String(info.get("summary", ""))
	var my_team := _session.get_team(_session.local_peer_id)
	var players := _session.get_players()
	for team in Teams.COUNT:
		# Colors are relative to you: your team is blue, the other one red.
		_header_panels[team].theme_type_variation = &"TeamHeaderFriendly" if team == my_team else &"TeamHeaderEnemy"
		var list := _lists[team]
		for row in list.get_children():
			list.remove_child(row)
			row.queue_free()
		var members := 0
		for player in players:
			if int(player["team"]) != team:
				continue
			members += 1
			var is_you := int(player["peer_id"]) == _session.local_peer_id
			var text := String(player["name"])
			if is_you:
				text += " (you)"
			if int(player["peer_id"]) == 1:
				text += " (host)"
			_add_row(list, text, &"YouRowPanel" if is_you else &"RowPanel", &"BrightLabel" if is_you else &"")
		var known := slots.size() == Teams.COUNT
		if known:
			for _bot in maxi(0, int(slots[team]) - members):
				_add_row(list, "Bot", &"RowPanel", &"DimLabel")
		UiTheme.apply_sizes(list, _ui_scale)
		_join_team_buttons[team].text = "Join Team %d" % (team + 1)
		_join_team_buttons[team].disabled = team == my_team or (known and members >= int(slots[team]))


## One line of a team's list: a panel row with the [param text] in it.
func _add_row(list: Control, text: String, panel_variation: StringName, label_variation: StringName) -> void:
	var row := PanelContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.theme_type_variation = panel_variation
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.theme_type_variation = &"RowMargin"
	row.add_child(margin)
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.theme_type_variation = label_variation
	label.text = text
	# A long name is cut instead of widening its column.
	label.clip_text = true
	margin.add_child(label)
	list.add_child(row)


# --- The session ---


## A new session at the root of the tree, with its lobby (made first, so it hears the session's
## closing before this panel does).
func _open_session() -> NetSession:
	# A session that is closing (a host waits a moment for its friends to hear it) still holds the
	# node name; the new one must get exactly this name, or the RPCs between computers wouldn't
	# find each other's session node and NetLobby.find_session() would never find it.
	var stale := get_tree().root.get_node_or_null(NetSession.NODE_NAME) as NetSession
	if stale != null and not stale.is_active():
		stale.name = "%sClosing" % NetSession.NODE_NAME
	var session := NetSession.open(get_tree())
	NetLobby.of(session)
	return session


## Starts driving [param session]: follows its roster, its lobby info and its end.
func _adopt(session: NetSession) -> void:
	_session = session
	var lobby := NetLobby.of(session)
	if not session.joined.is_connected(_on_joined):
		session.joined.connect(_on_joined)
		session.join_failed.connect(_on_join_failed)
		session.roster_changed.connect(_on_roster_changed)
		session.closed.connect(_on_session_closed)
	if not lobby.info_changed.is_connected(_on_info_changed):
		lobby.info_changed.connect(_on_info_changed)


## Stops driving the session without ending it: forgets it and drops this panel's connections to
## it. Returns it (null if there was none).
func _release_session() -> NetSession:
	var session := _session
	_session = null
	_connecting = false
	_join_failure = ""
	_published_host_team = -1
	if session != null and is_instance_valid(session):
		for connection: Array in [[session.joined, _on_joined], [session.join_failed, _on_join_failed],
				[session.roster_changed, _on_roster_changed], [session.closed, _on_session_closed]]:
			if (connection[0] as Signal).is_connected(connection[1]):
				(connection[0] as Signal).disconnect(connection[1])
		var lobby := session.get_node_or_null("NetLobby") as NetLobby
		if lobby != null and lobby.info_changed.is_connected(_on_info_changed):
			lobby.info_changed.disconnect(_on_info_changed)
	return session


## The host tells everyone what the match is: the summary line, the slots of each team (the host's
## team gets "your team"'s size, the other one the enemy team's) and the map.
func _publish() -> void:
	if _session == null or not _session.is_host() or not _session.is_active():
		return
	var host_team := _session.get_team(_session.local_peer_id)
	_published_host_team = host_team
	var slots: Array = [0, 0]
	slots[host_team] = settings.match_team_size
	slots[Teams.other(host_team)] = settings.match_enemy_team_size
	NetLobby.of(_session).publish(build_summary(), slots, _chosen_map())


func _on_joined() -> void:
	_connecting = false
	_show_lobby_page()


func _on_join_failed(reason: String) -> void:
	_connecting = false
	_join_failure = reason
	_set_connect_enabled(true)
	_set_status(reason)


func _on_roster_changed() -> void:
	# The host's own team decides which slots are whose: moving to the other team swaps them.
	# (Newcomers get the lobby's info from the lobby itself.)
	if _session != null and _session.is_host() and _session.get_team(_session.local_peer_id) != _published_host_team:
		_publish()
	_refresh_lobby()


func _on_info_changed() -> void:
	_refresh_lobby()


## The session ended without this panel asking: the host left, the connection was lost, or a
## join failed (the status shows why).
func _on_session_closed(reason: String) -> void:
	# The lobby kept the reason as the main menu's notice; this panel shows it right away.
	GameLaunch.notice = ""
	var shown := _join_failure if not _join_failure.is_empty() else reason
	var session := _release_session()
	if session != null:
		session.close()
	if _setup != null and _setup.is_open():
		_setup.close()
	if is_inside_tree():
		_show_connect_page()
		_set_status(shown)


func _on_setting_changed(key: StringName) -> void:
	if String(key).begins_with("match_") and _page == Page.LOBBY and _session != null and _session.is_host():
		_publish()


# --- The match settings (host only) ---


## The match settings panel, made when first needed: the same [MatchSetup] as the main menu's
## Play, with its Start button reading "Done".
func _get_setup() -> MatchSetup:
	if _setup == null:
		_setup = MATCH_SETUP_SCENE.instantiate() as MatchSetup
		_setup.settings = settings
		# Above this panel.
		_setup.layer = layer + 1
		add_child(_setup)
		_setup.set_start_text("Done")
		_setup.started.connect(_on_setup_done)
		_setup.closed.connect(_on_setup_closed)
		_setup.set_ui_scale(_ui_scale)
		UiSounds.attach(_setup)
	return _setup


func _on_setup_done() -> void:
	_setup.close()


func _on_setup_closed() -> void:
	_publish()
	if visible and _page == Page.LOBBY:
		_settings_button.grab_focus()


# --- The connect page's fields ---


## Shows the stored name, address and port in the fields.
func _refresh_fields() -> void:
	_name_field.text = settings.online_name
	_address_field.text = settings.online_address
	_port_field.text = str(settings.online_port)


## Reads the fields into the settings (what hosting and joining use) and shows what was kept: a
## port outside the allowed range is clamped, an empty one is the default.
func _store_fields() -> void:
	settings.online_name = _name_field.text.strip_edges()
	settings.online_address = _address_field.text.strip_edges()
	var digits := _digits_only(_port_field.text)
	settings.online_port = int(digits) if not digits.is_empty() else NetSession.DEFAULT_PORT
	_refresh_fields()


func _on_port_text_changed(text: String) -> void:
	var digits := _digits_only(text)
	if digits != text:
		var caret := _port_field.caret_column
		_port_field.text = digits
		_port_field.caret_column = clampi(caret - (text.length() - digits.length()), 0, digits.length())
	if not digits.is_empty():
		settings.online_port = int(digits)


## After editing the port: shows the value that was kept (clamped, or the old one if emptied).
func _show_stored_port() -> void:
	_port_field.text = str(settings.online_port)


## [param text] without anything but the digits 0 to 9.
static func _digits_only(text: String) -> String:
	var digits := ""
	for character in text:
		if character >= "0" and character <= "9":
			digits += character
	return digits


func _set_status(text: String) -> void:
	_status.text = text


## Host game and Join are off while a connection attempt is under way, or the last session is closing.
func _set_connect_enabled(enabled: bool) -> void:
	_host_button.disabled = not enabled or _is_closing_session()
	_join_button.disabled = not enabled or _is_closing_session()


## True while the session [method leave] closed is still in the tree.
func _is_closing_session() -> bool:
	return _closing_session != null and is_instance_valid(_closing_session) and _closing_session.is_inside_tree()


func _on_closing_session_gone() -> void:
	_closing_session = null
	if _page == Page.CONNECT and not _connecting:
		_set_connect_enabled(true)


# --- Test hooks ---


## The session this panel drives (hosting, connected or connecting), or null.
func get_session() -> NetSession:
	return _session


## The page that is showing.
func get_page() -> Page:
	return _page


## The name field.
func get_name_field() -> LineEdit:
	return _name_field


## The host's address field.
func get_address_field() -> LineEdit:
	return _address_field


## The port field.
func get_port_field() -> LineEdit:
	return _port_field


## The status line of the connect page.
func get_status_label() -> Label:
	return _status


## The "Host game" button.
func get_host_button() -> Button:
	return _host_button


## The "Join" button.
func get_join_button() -> Button:
	return _join_button


## The connect page's "Back" button.
func get_back_button() -> Button:
	return _back_button


## The line under the lobby's title (where the host's friends can join, or who you are connected to).
func get_info_label() -> Label:
	return _info_label


## The rows of [param team]'s column (0 or 1), top to bottom.
func get_team_list(team: int) -> Control:
	return _lists[team]


## The texts of the rows of [param team]'s column ("Jan (you) (host)", "Bot").
func get_team_texts(team: int) -> Array[String]:
	var texts: Array[String] = []
	for row in _lists[team].get_children():
		texts.append((row.find_children("*", "Label", true, false)[0] as Label).text)
	return texts


## The header bar of [param team]'s column.
func get_team_header(team: int) -> PanelContainer:
	return _header_panels[team]


## The "Join Team" button under [param team]'s column.
func get_join_team_button(team: int) -> Button:
	return _join_team_buttons[team]


## The line with the host's summary of the match.
func get_summary_label() -> Label:
	return _summary_label


## The "Waiting for the host..." line a client sees.
func get_waiting_label() -> Label:
	return _waiting_label


## The "Leave" button.
func get_leave_button() -> Button:
	return _leave_button


## The host's "Match settings…" button.
func get_settings_button() -> Button:
	return _settings_button


## The host's "Start match" button.
func get_start_button() -> Button:
	return _start_button


## The match settings panel (made if it wasn't yet).
func get_match_setup() -> MatchSetup:
	return _get_setup()
