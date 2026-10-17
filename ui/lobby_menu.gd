class_name LobbyMenu
extends CanvasLayer
## The multiplayer screens (M9, D-108; the mockup's "06 Lobby" since M10): the main menu's Host and
## Join items open this page, where you host a game or join one, and then wait in the lobby for the
## match to start.
##
## [b]Two pages[/b] in one frame (an ink page like the Play screen: the title and Esc / Back or Leave
## in the header, a left column, the teams, a footer), one shown at a time. The [b]connect page[/b]
## ("Join") has the left column only: your name, "Join by IP" (the host's address and the port, each
## written to [Settings] the moment you edit it, like the other menus: [code]online_name[/code],
## [code]online_address[/code], [code]online_port[/code]) with the Join button, a status line under it
## for "Connecting to ...", errors and the reason the last online game ended
## ([member GameLaunch.notice], shown once), and "Or host a game" with the Host game button. The
## [b]lobby page[/b] ("Lobby") shows "Hosted by you · address:port" or "Connected to address:port" in
## the header, your name and (for the host) the addresses friends join at on the left (the host's
## Tailscale address first, with a Copy button, M12 D-173; then the same-network ones), the two teams
## side by side (a header with the team's name and its players out of its slots, then a row per player:
## you on a raised row with a lime chip, the host marked "Host", and an "Empty / Bot" row for every
## slot nobody has taken), a Switch team button, and the footer: the match's mode, map and limit as the
## host published them, then for the host Edit setup (the [MatchSetup] panel, whose Start button reads
## "Done" and which offers no Practice) and Start; a client sees "Waiting for the host to start". Leave
## ends your part of the session (the host ends it for everyone). There is no Ready state: the host
## starts when it likes. In a free-for-all (M17, D-240) there are no teams to show: one list under
## "Everyone for themselves" holds every player and every open slot, and the Switch team button is
## hidden (the teams still exist underneath; the host publishes the mode as the fact [code]ffa[/code]).
##
## [b]The game browser[/b] (M17, D-242): the connect page's right half lists the games on your network
## ("Games on your network": the host's name, map, mode, players out of slots, whether a match is
## running, and a Join button per game; "Looking for games…" while there are none) and the hosts you
## joined lately ("Recent", newest first, each with Join and a small X that forgets it). The games come
## from a [LanDiscovery] that listens while this page shows (it starts when the page shows and stops
## when it hides or the lobby takes over); when its port is taken a line says so. Join on a row fills
## the address and port fields and joins through [method join_game] (so does everything else); a host
## that runs another version of the game is listed with Join off. Every successful join puts its address
## and port at the front of [member Settings.online_recent] ([RecentHosts]; Tailscale hosts are found
## there, since a broadcast doesn't cross it). The right half scrolls when the lists are long.
##
## [b]The chat[/b] (M17, D-243): under the addresses on the left of the lobby page, a box with the lines said so far (the
## newest at the bottom, the box scrolls; each line's name is in your team's colour, or the enemy's, and a line is a plain
## [Label]: markup in it is just characters), and a text field with a Send button. Enter in the field sends too. The words
## go through the session's [NetChat], which keeps its history, so coming back from a match shows the talk again; what the
## host refuses ("Slow down...") shows as a dim line. Esc in the field leaves the field (a second Esc leaves the lobby).
##
## The panel only drives a [NetSession] and its [NetLobby]: [method host_game] and
## [method join_game] open the session at the root of the tree ([method NetSession.open]), the
## host publishes the lobby's info (summary, slots, map, footer facts) whenever the lobby opens,
## somebody joins or leaves, a team changes or a match setting changes, and [method start_match] asks
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
## The height of a lobby row (the mockup's 40; the page scales it) and the side of the lime chip on your row.
const ROW_HEIGHT := 40.0
const CHIP_SIZE := 8.0
## The facts the footer shows, in order: the keys of the lobby info's [code]facts[/code] (see [method build_facts]).
const FACT_KEYS: Array[String] = ["mode", "map", "limit"]
## The header of the one list of a free-for-all lobby.
const EVERYONE_TEXT := "Everyone for themselves"
## The Tailscale address's button, and what it says for a moment after copying (M12, D-173).
const COPY_TEXT := "Copy"
const COPIED_TEXT := "Copied"
const COPIED_MILLISECONDS := 1500
## The game browser's text (M17, D-242).
const LOOKING_TEXT := "Looking for games…"
const RECENT_EMPTY_TEXT := "Hosts you join are kept here."
const OTHER_VERSION_TEXT := "Other version"
const IN_GAME_TEXT := "In game"
const LOBBY_STATE_TEXT := "Lobby"
## A game row's columns, as [width at 720p, share of the spare room] (0 = a fixed width): the widths are the least a
## column gets (its text is cut to it), the shares divide what is left over, so the rows line up and the page
## still fits a window, or a UI scale, that leaves less room than 1280 × 720 does.
const GAME_NAME_COLUMN := [96.0, 3.0]
const GAME_MAP_COLUMN := [72.0, 2.0]
const GAME_MODE_COLUMN := [120.0, 4.0]
const GAME_PLAYERS_COLUMN := [64.0, 0.0]
const GAME_STATE_COLUMN := [110.0, 3.0]
## The lines the chat box keeps (the same as [constant NetChat.MAX_LINES]).
const CHAT_LINES := 50
## The width of a recent host's name and address columns.
const RECENT_NAME_WIDTH := 96.0
const RECENT_ADDRESS_WIDTH := 200.0

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
## Where the host's addresses come from: a [Callable] returning a [PackedStringArray], or none for
## this computer's own ([method IP.get_local_addresses]). Tests set it to pretend to have a
## Tailscale address.
var address_source: Callable = Callable()
## The addresses friends can join the host at, found when the lobby opens: those on the same
## network, and the Tailscale ones (M12, D-173).
var _addresses: Array[String] = []
var _tailscale: Array[String] = []
## The clipboard text of the Copy button (the Tailscale address with the port) and how many times
## it was pressed, so only the last press resets the button's text.
var _copy_text: String = ""
var _copy_presses: int = 0
## The session that is still closing after [method leave]: a host with friends gives them a moment
## to hear it ([method NetSession.close]). Every session at the root shares the tree's one
## multiplayer, so hosting or joining again before it is gone would be torn down by its closing;
## Host game and Join wait.
var _closing_session: NetSession
## The host's team when the lobby info was last published (-1: not yet); the slots depend on it.
var _published_host_team: int = -1
## The LAN game browser (M17, D-242): made when the connect page first shows, listening while it does.
var _discovery: LanDiscovery
## What [method LanDiscovery.listen] answered the last time the page started it ([constant OK] or why not).
var _listen_error: int = OK
## False while a join is under way (or the last session is closing): the Join buttons of the lists are off too.
var _join_enabled: bool = true
## The Join buttons of the games and of the recent hosts, and the X buttons of the recent ones.
var _game_join_buttons: Array[Button] = []
var _recent_join_buttons: Array[Button] = []
var _recent_remove_buttons: Array[Button] = []

@onready var _title: Label = %Title
@onready var _info_label: Label = %Info
@onready var _back_button: Button = %BackButton
@onready var _leave_button: Button = %LeaveButton
@onready var _name_field: LineEdit = %NameField
@onready var _connect_box: Control = %ConnectBox
@onready var _address_field: LineEdit = %AddressField
@onready var _port_field: LineEdit = %PortField
@onready var _join_button: Button = %JoinButton
@onready var _status: Label = %Status
@onready var _host_button: Button = %HostButton
@onready var _browser: ScrollContainer = %BrowserScroll
@onready var _games_empty: Label = %GamesEmpty
@onready var _games_list: VBoxContainer = %GamesList
@onready var _recent_empty: Label = %RecentEmpty
@onready var _recent_list: VBoxContainer = %RecentList
@onready var _friends_box: Control = %FriendsBox
@onready var _chat_box: Control = %ChatBox
@onready var _chat_scroll: ScrollContainer = %ChatScroll
@onready var _chat_lines: VBoxContainer = %ChatLines
@onready var _chat_field: LineEdit = %ChatField
@onready var _chat_send_button: Button = %ChatSendButton
@onready var _addresses_box: VBoxContainer = %Addresses
@onready var _tailscale_box: Control = %TailscaleBox
@onready var _tailscale_address_label: Label = %TailscaleAddress
@onready var _copy_button: Button = %CopyButton
@onready var _lan_label: Label = %LanLabel
@onready var _teams_box: Control = %Teams
@onready var _columns: Array[Control] = [%Team0, %Team1]
@onready var _header_panels: Array[PanelContainer] = [%Header0, %Header1]
@onready var _header_names: Array[Label] = [%HeaderName0, %HeaderName1]
@onready var _header_counts: Array[Label] = [%HeaderCount0, %HeaderCount1]
@onready var _lists: Array[Control] = [%List0, %List1]
@onready var _switch_button: Button = %SwitchButton
@onready var _footer: Control = %Footer
@onready var _fact_labels: Array[Label] = [%ModeValue, %MapValue, %LimitValue]
@onready var _edit_button: Button = %EditButton
@onready var _waiting_label: Label = %Waiting
@onready var _start_button: Button = %StartButton


func _ready() -> void:
	visible = false
	if settings == null:
		settings = Settings.get_instance()
	settings.changed.connect(_on_setting_changed)
	_name_field.text_changed.connect(func(text: String) -> void: settings.online_name = text)
	_copy_button.pressed.connect(copy_tailscale_address)
	_address_field.text_changed.connect(func(text: String) -> void: settings.online_address = text)
	_port_field.text_changed.connect(_on_port_text_changed)
	_port_field.focus_exited.connect(_show_stored_port)
	_host_button.pressed.connect(host_game)
	_join_button.pressed.connect(join_game)
	_back_button.pressed.connect(close)
	_leave_button.pressed.connect(leave)
	_edit_button.pressed.connect(open_match_settings)
	_start_button.pressed.connect(start_match)
	_switch_button.pressed.connect(switch_team)
	_chat_field.text_submitted.connect(func(_text: String) -> void: send_chat())
	_chat_send_button.pressed.connect(send_chat)
	# New lines grow the box's content: stay at the bottom, where the newest line is.
	_chat_scroll.get_v_scroll_bar().changed.connect(_follow_chat)
	_refresh_fields()
	_show_connect_page()
	UiSounds.attach(self)


func _exit_tree() -> void:
	# Freed or removed while open (the game starts under it): don't leave the game waiting for a menu.
	MenuState.close(self)


func _input(event: InputEvent) -> void:
	# Only the menu on top reacts to Esc: with the match settings open, they are on top.
	if visible and MenuState.is_top(self) and event.is_action_pressed("pause"):
		if _page == Page.LOBBY and _chat_field.has_focus():
			# Esc ends the typing first; leaving the lobby takes a second one.
			_chat_field.release_focus()
		elif _page == Page.LOBBY:
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
	_update_browsing()


## Hides the panel, hands the mouse back (if it was the last menu open) and emits [signal closed].
## A connection attempt or session this panel started ends with it ([method leave]). Does nothing
## when the panel isn't open.
func close() -> void:
	if not visible:
		return
	leave()
	visible = false
	_update_browsing()
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
		_refresh_recent()


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
	_name_field.editable = false
	_set_status("Connecting to %s:%d…" % [address, port], false)
	# The buttons are off; Back cancels.
	_back_button.grab_focus()
	return OK


## The Join button of a row in the browser: puts [param address] and [param port] in the fields and
## joins them, as a click on Join would. Returns what [method join_game] returns.
func join_listed(address: String, port: int) -> Error:
	if _session != null:
		return ERR_ALREADY_IN_USE
	_address_field.text = address
	_port_field.text = str(port)
	return join_game()


## Shows [param games] in the "Games on your network" list, as [method LanDiscovery.get_games] lists
## them (the browser calls it whenever the discovery's list changes; tests call it with games of
## their own).
func show_games(games: Array[Dictionary]) -> void:
	_game_join_buttons.clear()
	_clear_list(_games_list)
	for game in games:
		_add_game_row(game)
	_games_empty.visible = games.is_empty()
	_games_empty.text = LOOKING_TEXT if _listen_error == OK else _listen_failure_text()
	_games_empty.theme_type_variation = &"MuteLabel"
	UiTheme.apply_sizes(_games_list, _ui_scale)
	UiSounds.attach(_games_list)
	_refresh_join_buttons()


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


## Moves you to the other team (the Switch team button); the host decides, so a full team refuses.
func switch_team() -> void:
	if _session != null:
		join_team(Teams.other(_session.get_team(_session.local_peer_id)))


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
	var ffa := settings.match_mode == "ffa"
	var respawn := settings.match_mode != "rounds"
	var parts: Array[String] = ["Free-for-all" if ffa else "Team respawn" if respawn else "Rounds"]
	var rotation := _chosen_rotation()
	if rotation.is_empty():
		parts.append(GameLaunch.map_title(_chosen_map()))
	else:
		parts.append("Rotation: %s" % ", ".join(rotation.map(func(path: String) -> String: return GameLaunch.map_title(path))))
	parts.append("first to %d kills" % settings.match_kill_limit if respawn else "first to %d rounds" % settings.match_rounds_to_win)
	parts.append("%s bots" % settings.match_difficulty.capitalize())
	if settings.match_friendly_fire and not ffa:
		parts.append("friendly fire")
	return " · ".join(PackedStringArray(parts))


## The facts of the match the stored choices make, as the footer shows them (ready-made texts the host
## publishes with the lobby info, so a client shows the same): [code]mode[/code] ("Team Deathmatch",
## "Free-for-all" or "Bomb"), [code]map[/code] ("Depot", or "Rotation · Depot" for the rotation starting there) and
## [code]limit[/code] ("50 kills · 10 min", or "First to 5 rounds"). A free-for-all adds [code]ffa[/code]: true,
## which tells a client's lobby to show one list instead of the two teams.
func build_facts() -> Dictionary:
	var respawn := settings.match_mode != "rounds"
	var rotation := _chosen_rotation()
	var facts := {
		"mode": MatchSetup.MODES[settings.match_mode]["title"],
		"map": "Rotation · %s" % GameLaunch.map_title(rotation[0]) if not rotation.is_empty() else GameLaunch.map_title(_chosen_map()),
		"limit": "%d kills · %d min" % [settings.match_kill_limit, settings.match_time_limit] if respawn
				else "First to %d rounds" % settings.match_rounds_to_win,
	}
	if settings.match_mode == "ffa":
		facts["ffa"] = true
	return facts


## The scene path of the map the stored choices name: the stored map, or the default one when it
## is gone (what [MatchSetup] shows).
func _chosen_map() -> String:
	var maps := GameLaunch.list_maps()
	if maps.has(settings.match_map):
		return settings.match_map
	return Settings.DEFAULT_MATCH_MAP if maps.has(Settings.DEFAULT_MATCH_MAP) else maps[0]


## The maps played one after the other, starting at the chosen one; empty for a single map.
func _chosen_rotation() -> Array[String]:
	if not settings.match_rotation:
		return []
	return GameLaunch.rotation_maps(_chosen_map())


## This computer's IPv4 addresses a friend on the same network can join at (not 127.x, not
## link-local, no IPv6, and not a Tailscale address: [method tailscale_addresses] has those).
## [param found] is the list to filter, this computer's by default (tests give their own).
static func local_addresses(found: PackedStringArray = IP.get_local_addresses()) -> Array[String]:
	var result: Array[String] = []
	for address: String in found:
		if address.contains(":") or not address.contains("."):
			continue
		if address.begins_with("127.") or address.begins_with("169.254.") or address == "0.0.0.0":
			continue
		if is_tailscale_address(address):
			continue
		if not result.has(address):
			result.append(address)
	return result


## This computer's Tailscale addresses: the IPv4 addresses in 100.64.0.0/10 (carrier-grade NAT
## space, which Tailscale hands out to its devices, M12, D-173). A computer without Tailscale has
## none. [param found] is the list to filter, this computer's by default.
static func tailscale_addresses(found: PackedStringArray = IP.get_local_addresses()) -> Array[String]:
	var result: Array[String] = []
	for address: String in found:
		if is_tailscale_address(address) and not result.has(address):
			result.append(address)
	return result


## True for an IPv4 address in 100.64.0.0/10: first number 100, second 64 to 127.
static func is_tailscale_address(address: String) -> bool:
	var parts := address.split(".")
	if parts.size() != 4:
		return false
	for part in parts:
		if part.is_empty() or _digits_only(part) != part or int(part) > 255:
			return false
	return int(parts[0]) == 100 and int(parts[1]) >= 64 and int(parts[1]) <= 127


## Splits "address:port" (what the lobby's Copy button puts on the clipboard) into
## [code]{"address": ..., "port": ...}[/code]; without a valid port (1 to 65535) after exactly one
## colon there is no [code]port[/code] key and the address is kept whole (a host name, an IPv6 address).
static func split_address(text: String) -> Dictionary:
	var address := text.strip_edges()
	if address.count(":") == 1:
		var parts := address.split(":")
		var host := parts[0].strip_edges()
		var digits := parts[1].strip_edges()
		if not host.is_empty() and not digits.is_empty() and _digits_only(digits) == digits and int(digits) >= 1 and int(digits) <= 65535:
			return {"address": host, "port": int(digits)}
	return {"address": address}


## What the lobby's header names the host by: the first same-network address, else the Tailscale
## one, with the [param port] (just the port when there is no address).
func host_label_address(port: int) -> String:
	if not _addresses.is_empty():
		return "%s:%d" % [_addresses[0], port]
	if not _tailscale.is_empty():
		return "%s:%d" % [_tailscale[0], port]
	return "port %d" % port


## Puts the host's Tailscale address and port ("100.x.y.z:26000") on the clipboard, for pasting in
## a friend's Join by IP field, and says "Copied" on the button for a moment. Does nothing without
## a Tailscale address.
func copy_tailscale_address() -> void:
	if _copy_text.is_empty():
		return
	DisplayServer.clipboard_set(_copy_text)
	_copy_button.text = COPIED_TEXT
	_copy_presses += 1
	var press := _copy_presses
	await get_tree().create_timer(COPIED_MILLISECONDS / 1000.0).timeout
	# A later press restarted the wait, and the lobby may be gone by now.
	if is_instance_valid(self) and press == _copy_presses:
		_copy_button.text = COPY_TEXT


# --- The pages ---


func _show_connect_page() -> void:
	_page = Page.CONNECT
	_title.text = "Join"
	_info_label.visible = false
	_back_button.visible = true
	_leave_button.visible = false
	_connect_box.visible = true
	_browser.visible = true
	_friends_box.visible = false
	_chat_box.visible = false
	_teams_box.visible = false
	_footer.visible = false
	# Your name is the one the session was opened with: it can only be changed before connecting.
	_name_field.editable = not _connecting
	_set_connect_enabled(not _connecting)
	_set_status("")
	_refresh_recent()
	_update_browsing()
	if visible:
		_host_button.grab_focus()


func _show_lobby_page() -> void:
	_page = Page.LOBBY
	_title.text = "Lobby"
	_info_label.visible = true
	_back_button.visible = false
	_leave_button.visible = true
	_connect_box.visible = false
	_browser.visible = false
	_teams_box.visible = true
	_chat_box.visible = true
	_footer.visible = true
	_name_field.editable = false
	_set_status("")
	_update_browsing()
	var host := _session.is_host()
	_edit_button.visible = host
	_start_button.visible = host
	_waiting_label.visible = not host
	if host:
		var found: PackedStringArray = address_source.call() if address_source.is_valid() else IP.get_local_addresses()
		_addresses = local_addresses(found)
		_tailscale = tailscale_addresses(found)
		_fill_addresses()
		_publish()
	_friends_box.visible = host and (not _addresses.is_empty() or not _tailscale.is_empty())
	_refresh_lobby()
	if visible:
		(_start_button if host else _leave_button).grab_focus()


## The host's addresses under "Friends join at": the Tailscale one first, with its Copy button,
## then the same-network ones, one line each, with the port.
func _fill_addresses() -> void:
	_copy_text = "%s:%d" % [_tailscale[0], settings.online_port] if not _tailscale.is_empty() else ""
	_tailscale_box.visible = not _tailscale.is_empty()
	_tailscale_address_label.text = _copy_text
	_lan_label.visible = not _tailscale.is_empty() and not _addresses.is_empty()
	_copy_button.text = COPY_TEXT
	for line in _addresses_box.get_children():
		_addresses_box.remove_child(line)
		line.queue_free()
	for address in _addresses:
		var label := Label.new()
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.text = "%s:%d" % [address, settings.online_port]
		_addresses_box.add_child(label)


## Fills the lobby page from the session's roster and the host's published info.
func _refresh_lobby() -> void:
	if _page != Page.LOBBY or _session == null:
		return
	var host := _session.is_host()
	var port := settings.online_port
	if host:
		_info_label.text = "Hosted by you · %s" % host_label_address(port)
	else:
		_info_label.text = "Connected to %s:%d" % [settings.online_address, port]
	var info := NetLobby.of(_session).info
	var slots: Array = info.get("slots", [])
	var known := slots.size() == Teams.COUNT
	var facts: Dictionary = info.get("facts", {})
	for index in FACT_KEYS.size():
		_fact_labels[index].text = String(facts.get(FACT_KEYS[index], ""))
		(_fact_labels[index].get_parent() as Control).visible = not facts.is_empty()
	var my_team := _session.get_team(_session.local_peer_id)
	var players := _session.get_players()
	var ffa := bool(facts.get("ffa", false))
	_columns[1].visible = not ffa
	_switch_button.visible = not ffa
	if ffa:
		_refresh_everyone(players, slots, known)
		return
	var members_of: Array[int] = [0, 0]
	for team in Teams.COUNT:
		# Colors are relative to you: your team is blue, the other one red.
		var yours := team == my_team
		_header_panels[team].theme_type_variation = &"TeamTitleFriendly" if yours else &"TeamTitleEnemy"
		_header_names[team].text = "Your team" if yours else "Enemy team"
		for label in [_header_names[team], _header_counts[team]]:
			(label as Label).theme_type_variation = &"FriendlyLabel" if yours else &"EnemyLabel"
		var list := _lists[team]
		for row in list.get_children():
			list.remove_child(row)
			row.queue_free()
		for player in players:
			if int(player["team"]) != team:
				continue
			members_of[team] += 1
			var is_you := int(player["peer_id"]) == _session.local_peer_id
			_add_player_row(list, "You" if is_you else String(player["name"]), is_you, int(player["peer_id"]) == 1)
		if known:
			for _bot in maxi(0, int(slots[team]) - members_of[team]):
				_add_empty_row(list)
		_header_counts[team].text = "%d / %d" % [members_of[team], int(slots[team])] if known else str(members_of[team])
		UiTheme.apply_sizes(list, _ui_scale)
	var other := Teams.other(my_team)
	_switch_button.disabled = known and members_of[other] >= int(slots[other])


## The lobby of a free-for-all: one list ([constant EVERYONE_TEXT]) with every player in the order they
## joined and an "Empty / Bot" row for each open slot (both teams' slots together), in your colour's header.
func _refresh_everyone(players: Array, slots: Array, known: bool) -> void:
	_header_panels[0].theme_type_variation = &"TeamTitleFriendly"
	_header_names[0].text = EVERYONE_TEXT
	for label in [_header_names[0], _header_counts[0]]:
		(label as Label).theme_type_variation = &"FriendlyLabel"
	var list := _lists[0]
	for row in list.get_children():
		list.remove_child(row)
		row.queue_free()
	for player in players:
		var is_you := int(player["peer_id"]) == _session.local_peer_id
		_add_player_row(list, "You" if is_you else String(player["name"]), is_you, int(player["peer_id"]) == 1)
	var total := int(slots[0]) + int(slots[1]) if known else players.size()
	if known:
		for _bot in maxi(0, total - players.size()):
			_add_empty_row(list)
	_header_counts[0].text = "%d / %d" % [players.size(), total] if known else str(players.size())
	UiTheme.apply_sizes(list, _ui_scale)


## A row of a team's list: a panel, [constant ROW_HEIGHT] high, with its parts in a row.
## Returns the row of parts to fill.
func _add_row(list: Control, panel_variation: StringName) -> HBoxContainer:
	var row := PanelContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.theme_type_variation = panel_variation
	row.custom_minimum_size = Vector2(0, ROW_HEIGHT)
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.theme_type_variation = &"SlotMargin"
	row.add_child(margin)
	var parts := HBoxContainer.new()
	parts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parts.theme_type_variation = &"SlotRow"
	margin.add_child(parts)
	list.add_child(row)
	return parts


## A player's row: you on a raised row with a lime chip before the name, the others on a plain row
## with room for the chip, and "Host" at the end of the host's.
func _add_player_row(list: Control, text: String, is_you: bool, is_host: bool) -> void:
	var parts := _add_row(list, &"RaisedPanel" if is_you else &"RowPanel")
	var chip: Control
	if is_you:
		chip = Panel.new()
		chip.theme_type_variation = &"AccentChip"
	else:
		chip = Control.new()
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.custom_minimum_size = Vector2(CHIP_SIZE, CHIP_SIZE)
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	parts.add_child(chip)
	var name_label := _add_label(parts, text, &"")
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# A long name is cut instead of widening its column.
	name_label.clip_text = true
	if is_host:
		_add_label(parts, "Host", &"DimLabel")


## A slot nobody has taken: "Empty" on the left, "Bot" on the right (a bot plays it), in a LINE frame.
func _add_empty_row(list: Control) -> void:
	var parts := _add_row(list, &"EmptySlotPanel")
	_add_label(parts, "Empty", &"MuteLabel").size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_add_label(parts, "Bot", &"MuteLabel")


## A label in [param parts], centred in the row's height.
func _add_label(parts: Control, text: String, variation: StringName) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.theme_type_variation = variation
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	label.text = text
	parts.add_child(label)
	return label


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
	var chat := NetChat.of(session)
	if not chat.line_received.is_connected(_on_chat_line):
		chat.line_received.connect(_on_chat_line)
		chat.notice.connect(_on_chat_notice)
		# What was said before this panel looked (the talk of an earlier lobby, before a match).
		_clear_chat()
		for line in chat.lines:
			_add_chat_line(int(line["peer_id"]), String(line["name"]), String(line["text"]))


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
		var chat := session.get_node_or_null(NetChat.NODE_NAME) as NetChat
		if chat != null and chat.line_received.is_connected(_on_chat_line):
			chat.line_received.disconnect(_on_chat_line)
			chat.notice.disconnect(_on_chat_notice)
	_clear_chat()
	return session


# --- The chat ---


## Sends what the chat field holds to the session's [NetChat] (the host decides what becomes of it) and clears the
## field. Enter in the field and the Send button call it. Nothing happens for an empty field or without a session.
func send_chat() -> void:
	var text := _chat_field.text
	if _session == null or not _session.is_active() or text.strip_edges().is_empty():
		return
	_chat_field.clear()
	NetChat.of(_session).send(text)
	# The button took the focus: back to the field, for the next line.
	if visible and _chat_field.is_visible_in_tree():
		_chat_field.grab_focus()


func _on_chat_line(peer_id: int, name_text: String, text: String) -> void:
	_add_chat_line(peer_id, name_text, text)


func _on_chat_notice(text: String) -> void:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.theme_type_variation = &"DimLabel"
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text = text
	_push_chat_row(label)


## A line of the chat box: the name in its team's colour (yours: friendly, the other: enemy, everyone in a free-for-all
## and a player who left: plain), then the words, wrapped. Both are labels, so what was said is never markup.
func _add_chat_line(peer_id: int, name_text: String, text: String) -> void:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.theme_type_variation = &"FieldRow"
	var who := _add_label(row, "%s:" % name_text, _chat_name_role(peer_id))
	who.name = "Name"
	who.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var words := _add_label(row, text, &"")
	words.name = "Text"
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_push_chat_row(row)


## The role of a chat line's name label: see [method _add_chat_line].
func _chat_name_role(peer_id: int) -> StringName:
	if _session == null:
		return &"DimLabel"
	if bool((NetLobby.of(_session).info.get("facts", {}) as Dictionary).get("ffa", false)):
		return &"BrightLabel"
	var team := _session.get_team(peer_id)
	if team < 0:
		return &"DimLabel"
	return &"FriendlyLabel" if team == _session.get_team(_session.local_peer_id) else &"EnemyLabel"


## Adds [param row] at the bottom of the chat box, forgetting the oldest lines past [constant CHAT_LINES].
func _push_chat_row(row: Control) -> void:
	_chat_lines.add_child(row)
	UiTheme.apply_sizes(row, _ui_scale)
	while _chat_lines.get_child_count() > CHAT_LINES:
		var oldest := _chat_lines.get_child(0)
		_chat_lines.remove_child(oldest)
		oldest.queue_free()


func _clear_chat() -> void:
	for row in _chat_lines.get_children():
		_chat_lines.remove_child(row)
		row.queue_free()


## The box's content grew: show its bottom.
func _follow_chat() -> void:
	_chat_scroll.scroll_vertical = int(_chat_scroll.get_v_scroll_bar().max_value)


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
	NetLobby.of(_session).publish(build_summary(), slots, _chosen_map(), build_facts(), settings.match_mode)


func _on_joined() -> void:
	_connecting = false
	_remember_host()
	_show_lobby_page()


func _on_join_failed(reason: String) -> void:
	_connecting = false
	_join_failure = reason
	_name_field.editable = true
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
	if key == &"online_recent":
		_refresh_recent()
	if String(key).begins_with("match_") and _page == Page.LOBBY and _session != null and _session.is_host():
		_publish()


# --- The game browser (M17, D-242) ---


## Listens for games while the connect page shows, and stops when it doesn't (the page hides, or the lobby
## takes over). A port that can't be bound is remembered and the list says so.
func _update_browsing() -> void:
	var wanted := visible and _page == Page.CONNECT
	if wanted:
		if _discovery == null:
			_discovery = LanDiscovery.new()
			_discovery.name = "LanDiscovery"
			_discovery.games_changed.connect(_refresh_games)
			add_child(_discovery)
		if not _discovery.is_listening():
			_listen_error = _discovery.listen()
			_refresh_games()
	elif _discovery != null and _discovery.is_listening():
		_discovery.stop_listening()


func _refresh_games() -> void:
	var games: Array[Dictionary] = []
	if _discovery != null:
		games = _discovery.get_games()
	show_games(games)


## What the list says when the discovery couldn't listen.
func _listen_failure_text() -> String:
	var port := _discovery.port if _discovery != null else LanDiscovery.default_port
	return "Can't look for games: UDP port %d is busy (another Chiip on this computer?). Recent and Join by IP still work." % port


## A game's row: the host's name, the map, the mode, the players out of the slots, "Lobby" or
## "In game", and Join.
func _add_game_row(game: Dictionary) -> void:
	var parts := _add_row(_games_list, &"RowPanel")
	var match_mode := LanDiscovery.match_mode_of(String(game["mode"]))
	var mode_text := String(MatchSetup.MODES[match_mode]["title"]) if match_mode != "" else String(game["mode"])
	_add_column(parts, String(game["name"]), &"", GAME_NAME_COLUMN)
	_add_column(parts, String(game["map"]), &"DimLabel", GAME_MAP_COLUMN)
	_add_column(parts, mode_text, &"DimLabel", GAME_MODE_COLUMN)
	_add_column(parts, "%d/%d" % [game["players"], game["max_players"]], &"", GAME_PLAYERS_COLUMN)
	var compatible := int(game["version"]) == NetProtocol.VERSION
	var state_text := OTHER_VERSION_TEXT if not compatible else IN_GAME_TEXT if bool(game["in_game"]) else LOBBY_STATE_TEXT
	_add_column(parts, state_text, &"AlertLabel" if not compatible else &"MuteLabel", GAME_STATE_COLUMN)
	var join := Button.new()
	join.text = "Join"
	join.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	join.tooltip_text = "Join %s's game at %s:%d." % [game["name"], game["address"], game["port"]] if compatible \
			else "This host runs another version of Chiip (%d, yours is %d)." % [game["version"], NetProtocol.VERSION]
	join.set_meta("blocked", not compatible)
	join.pressed.connect(join_listed.bind(String(game["address"]), int(game["port"])))
	parts.add_child(join)
	_game_join_buttons.append(join)


## A label for a browser row: [param text] cut to its column ([param column]: see [constant GAME_NAME_COLUMN]).
func _add_column(parts: Control, text: String, variation: StringName, column: Array) -> Label:
	var label := _add_label(parts, text, variation)
	label.clip_text = true
	label.custom_minimum_size.x = column[0]
	if column[1] > 0.0:
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.size_flags_stretch_ratio = column[1]
	return label


## Shows the recent hosts ([member Settings.online_recent]) in the "Recent" list.
func _refresh_recent() -> void:
	if _recent_list == null or settings == null:
		return
	_recent_join_buttons.clear()
	_recent_remove_buttons.clear()
	_clear_list(_recent_list)
	var recent := RecentHosts.parse(settings.online_recent)
	for entry in recent:
		_add_recent_row(entry)
	_recent_empty.visible = recent.is_empty()
	_recent_empty.text = RECENT_EMPTY_TEXT
	UiTheme.apply_sizes(_recent_list, _ui_scale)
	UiSounds.attach(_recent_list)
	_refresh_join_buttons()


## A recent host's row: its name (or its address when no name is known), the address and port, Join and X (forget).
func _add_recent_row(entry: Dictionary) -> void:
	var address := "%s:%d" % [entry["address"], entry["port"]]
	var parts := _add_row(_recent_list, &"RowPanel")
	var has_name := not String(entry["name"]).is_empty()
	_add_column(parts, String(entry["name"]) if has_name else address, &"", [RECENT_NAME_WIDTH, 1.0])
	if has_name:
		_add_column(parts, address, &"DimLabel", [RECENT_ADDRESS_WIDTH, 0.0])
	var join := Button.new()
	join.text = "Join"
	join.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	join.tooltip_text = "Join %s." % address
	join.pressed.connect(join_listed.bind(String(entry["address"]), int(entry["port"])))
	parts.add_child(join)
	_recent_join_buttons.append(join)
	var remove := Button.new()
	remove.text = "X"
	remove.theme_type_variation = &"DimButton"
	remove.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	remove.tooltip_text = "Forget %s." % address
	remove.pressed.connect(forget_recent.bind(String(entry["address"]), int(entry["port"])))
	parts.add_child(remove)
	_recent_remove_buttons.append(remove)


## Takes the host [param address]:[param port] off the recent list (the X button).
func forget_recent(address: String, port: int) -> void:
	settings.online_recent = RecentHosts.forget(settings.online_recent, address, port)


## Puts the host this panel just joined at the front of the recent list, with its name.
func _remember_host() -> void:
	var host_name := String(_session.get_player(1).get("name", "")) if _session != null else ""
	settings.online_recent = RecentHosts.remember(settings.online_recent, settings.online_address, settings.online_port, host_name)


## The Join buttons are off while a join is under way, and one that is blocked for good (a host of
## another version) stays off.
func _refresh_join_buttons() -> void:
	for button in _game_join_buttons + _recent_join_buttons:
		button.disabled = not _join_enabled or bool(button.get_meta("blocked", false))


## Removes every row of [param list].
func _clear_list(list: Control) -> void:
	for row in list.get_children():
		list.remove_child(row)
		row.queue_free()


# --- The match settings (host only) ---


## The match settings panel, made when first needed: the same [MatchSetup] as the main menu's
## Play, online (no Practice, "Picked" instead of "Click to play") and with its Start button reading "Done".
func _get_setup() -> MatchSetup:
	if _setup == null:
		_setup = MATCH_SETUP_SCENE.instantiate() as MatchSetup
		_setup.settings = settings
		# Above this panel.
		_setup.layer = layer + 1
		add_child(_setup)
		_setup.set_online(true)
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
		_edit_button.grab_focus()


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
	# "address:port" (what the host's Copy button copies) fills both fields.
	var target := split_address(_address_field.text)
	settings.online_address = target["address"]
	var digits := _digits_only(_port_field.text)
	if target.has("port"):
		settings.online_port = target["port"]
	else:
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


## Shows [param text] under Join by IP (nothing hides the line): in the ALERT colour when it is a problem,
## dim when it is only news ("Connecting to ...").
func _set_status(text: String, alert: bool = true) -> void:
	_status.text = text
	_status.visible = not text.is_empty()
	_status.theme_type_variation = &"AlertLabel" if alert else &"DimLabel"


## Host game and Join are off while a connection attempt is under way, or the last session is closing.
func _set_connect_enabled(enabled: bool) -> void:
	_host_button.disabled = not enabled or _is_closing_session()
	_join_button.disabled = not enabled or _is_closing_session()
	_join_enabled = not _host_button.disabled
	_refresh_join_buttons()


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


## The status line of the connect page (hidden while empty).
func get_status_label() -> Label:
	return _status


## The page's title ("Join" or "Lobby").
func get_title_label() -> Label:
	return _title


## The "Host game" button.
func get_host_button() -> Button:
	return _host_button


## The "Join" button.
func get_join_button() -> Button:
	return _join_button


## The connect page's "Back" button (in the header; the lobby page has Leave there instead).
func get_back_button() -> Button:
	return _back_button


## The text at the right of the header: "Hosted by you · address:port" or "Connected to address:port".
func get_info_label() -> Label:
	return _info_label


## The addresses under "Friends join at" (the host's own, with the port), top to bottom.
func get_address_texts() -> Array[String]:
	var texts: Array[String] = []
	for line in _addresses_box.get_children():
		texts.append((line as Label).text)
	return texts


## The "Friends join at" group (a host with a network address sees it).
func get_friends_box() -> Control:
	return _friends_box


## The left column's connect group (Join by IP and Or host a game), shown on the connect page.
func get_connect_box() -> Control:
	return _connect_box


## The two teams' area (the columns and Switch team), shown on the lobby page.
func get_teams_box() -> Control:
	return _teams_box


## The whole column of [param team] (0 or 1): its header and its rows.
func get_team_column(team: int) -> Control:
	return _columns[team]


## The rows of [param team]'s column (0 or 1), top to bottom.
func get_team_list(team: int) -> Control:
	return _lists[team]


## The texts of the rows of [param team]'s column, the parts of a row joined by a space: "You Host",
## "Anna", "Empty Bot".
func get_team_texts(team: int) -> Array[String]:
	var texts: Array[String] = []
	for row in _lists[team].get_children():
		var parts: Array[String] = []
		for label in row.find_children("*", "Label", true, false):
			parts.append((label as Label).text)
		texts.append(" ".join(PackedStringArray(parts)))
	return texts


## The header of [param team]'s column (the line under it is the team's colour).
func get_team_header(team: int) -> PanelContainer:
	return _header_panels[team]


## The texts of [param team]'s header: its name ("Your team", "Enemy team") and its count ("3 / 5").
func get_team_header_texts(team: int) -> Array[String]:
	return [_header_names[team].text, _header_counts[team].text]


## The "Switch team" button under the columns.
func get_switch_team_button() -> Button:
	return _switch_button


## The footer's facts as caption → text ("Mode" → "Team Deathmatch", "Map", "Limit").
func get_footer_facts() -> Dictionary:
	var facts := {}
	for index in FACT_KEYS.size():
		var pair := _fact_labels[index].get_parent()
		facts[(pair.get_child(0) as Label).text] = _fact_labels[index].text
	return facts


## The footer, shown on the lobby page.
func get_footer() -> Control:
	return _footer


## The "Waiting for the host to start" line a client sees.
func get_waiting_label() -> Label:
	return _waiting_label


## The "Leave" button in the header of the lobby page.
func get_leave_button() -> Button:
	return _leave_button


## The host's "Edit setup" button.
func get_settings_button() -> Button:
	return _edit_button


## The host's "Start" button.
func get_start_button() -> Button:
	return _start_button


## The match settings panel (made if it wasn't yet).
func get_match_setup() -> MatchSetup:
	return _get_setup()


## The chat box on the lobby page (Chat, its lines and the field with Send).
func get_chat_box() -> Control:
	return _chat_box


## The chat's text field and its Send button.
func get_chat_field() -> LineEdit:
	return _chat_field


func get_chat_send_button() -> Button:
	return _chat_send_button


## The scroll box around the chat's lines.
func get_chat_scroll() -> ScrollContainer:
	return _chat_scroll


## The chat's lines as shown, oldest first: "Name: words" for a line somebody said, the plain text of a note.
func get_chat_texts() -> Array[String]:
	var texts: Array[String] = []
	for row in _chat_lines.get_children():
		if row is Label:
			texts.append((row as Label).text)
		else:
			texts.append("%s %s" % [(row.get_node("Name") as Label).text, (row.get_node("Text") as Label).text])
	return texts


## The theme role of the name label of the chat line at [param index] ("" when there is no such line).
func get_chat_name_role(index: int) -> StringName:
	if index < 0 or index >= _chat_lines.get_child_count() or _chat_lines.get_child(index) is Label:
		return &""
	return (_chat_lines.get_child(index).get_node("Name") as Label).theme_type_variation


## The Tailscale group of "Friends join at" (shown when this computer has a Tailscale address).
func get_tailscale_box() -> Control:
	return _tailscale_box


## The Tailscale address with its port, as shown (empty without one).
func get_tailscale_text() -> String:
	return _tailscale_address_label.text if _tailscale_box.visible else ""


## The button that copies the Tailscale address.
func get_copy_button() -> Button:
	return _copy_button


## The "Same network" caption above the other addresses (only next to a Tailscale one).
func get_lan_label() -> Label:
	return _lan_label


## True while the session [method leave] closed is still going away (Host game and Join wait for it).
func is_closing_session() -> bool:
	return _is_closing_session()


## The game browser's scrolling right half (the connect page only).
func get_browser() -> ScrollContainer:
	return _browser


## The LAN game browser's [LanDiscovery], or null before the connect page first showed.
func get_discovery() -> LanDiscovery:
	return _discovery


## The line over the games list: "Looking for games…" while there are none, or why it can't look. Hidden when games are listed.
func get_games_note() -> Label:
	return _games_empty


## Each listed game's row as its texts joined with " | " (name, map, mode, players, state).
func get_game_texts() -> Array[String]:
	return _row_texts(_games_list)


## The Join buttons of the listed games, in row order.
func get_game_join_buttons() -> Array[Button]:
	return _game_join_buttons


## Each recent host's row as its texts joined with " | " (name, address, when a name is known).
func get_recent_texts() -> Array[String]:
	return _row_texts(_recent_list)


## The Join buttons of the recent hosts, in row order.
func get_recent_join_buttons() -> Array[Button]:
	return _recent_join_buttons


## The X buttons of the recent hosts, in row order.
func get_recent_remove_buttons() -> Array[Button]:
	return _recent_remove_buttons


## The line under "Recent" when nothing is remembered yet.
func get_recent_note() -> Label:
	return _recent_empty


## The texts of every label in each row of [param list], joined with " | ".
func _row_texts(list: Control) -> Array[String]:
	var rows: Array[String] = []
	for row in list.get_children():
		if row.is_queued_for_deletion():
			continue
		var texts := PackedStringArray()
		for label in row.find_children("*", "Label", true, false):
			texts.append((label as Label).text)
		rows.append(" | ".join(texts))
	return rows
