class_name NetChat
extends Node
## Text chat of an online session (M17, D-243): one place for the lobby's chat box and the match's
## HUD feed, alive as long as the [NetSession] (a child of it, found with [method of] like [NetLobby]).
##
## [b]The host decides everything.[/b] A player says something with [method send]; a client sends
## [code]{"chat": text}[/code] to the host ([method NetSession.send_to_host], so the session's own limits
## already apply: a few short entries, texts of at most [constant NetSession.MAX_MESSAGE_TEXT_LENGTH]
## characters, a number of messages a second), the host's own words take the same path locally. The host
## drops what is not a text, makes the text plain ([method clean]: control characters and the invisible
## ones that change how text reads out, whitespace collapsed, trimmed), drops it when nothing is left,
## cuts it to [constant MAX_CHAT_LENGTH] characters, refuses the sender who already sent
## [constant RATE_MESSAGES] lines within [constant RATE_WINDOW] seconds (a sliding window: only that
## sender gets a private [signal notice], "Slow down: 3 messages every 5 seconds"), and then sends
## [code]{"chat": text, "from": peer_id, "name": name}[/code] to every player in the roster, itself
## included. [b]The id and the name always come from the host's roster[/b], never from the message: a
## client's [code]"from"[/code] and [code]"name"[/code] are ignored. A client takes chat lines only from
## the host (peer 1, [member NetSession.match_message_sender]) and makes them plain again.
##
## The text is never markup: the views show it in a [Label] (never a RichTextLabel with BBCode), so
## "[b]x[/b]" is just characters. [member lines] keeps the last [constant MAX_LINES] lines for views that
## open later (the HUD feed after the lobby's talk), each with the [member time] it arrived at.

## Emitted on every computer for every line the host accepted (also the host's own).
signal line_received(peer_id: int, name: String, text: String)
## Emitted for something that is for you alone: the host refused your line ("Slow down...").
signal notice(text: String)

## A line is cut to this many characters (the host does it).
const MAX_CHAT_LENGTH := 100
## At most this many lines per sender within [constant RATE_WINDOW] seconds.
const RATE_MESSAGES := 3
const RATE_WINDOW := 5.0
## What a refused sender is told.
const SLOW_DOWN_TEXT := "Slow down: 3 messages every 5 seconds"
## The lines kept for views.
const MAX_LINES := 50
## The node's name under the session.
const NODE_NAME := "NetChat"
## The most the host reads of a text before it cleans it (its own words can be long; a client's are cut to
## [constant NetSession.MAX_MESSAGE_TEXT_LENGTH] by the session).
const MAX_READ_LENGTH := 1024

## The session this chat belongs to.
var session: NetSession
## The last [constant MAX_LINES] lines, oldest first: each a Dictionary with [code]peer_id[/code], [code]name[/code],
## [code]text[/code] and [code]time[/code] ([member time] when it arrived).
var lines: Array[Dictionary] = []
## Seconds this chat has lived: counted in physics ticks, so a line's age and the rate limit are tick counts
## (the session never pauses online). Views read a line's age from it.
var time: float = 0.0

## The host: per sender, the times (see [member time]) of the lines it let through in the last window.
var _sent: Dictionary = {}

static var _spaces: RegEx


## The chat of [param game_session], made on first use.
static func of(game_session: NetSession) -> NetChat:
	var chat := game_session.get_node_or_null(NODE_NAME) as NetChat
	if chat == null:
		chat = NetChat.new()
		chat.name = NODE_NAME
		chat.session = game_session
		game_session.add_child(chat)
	return chat


## [param text] made plain for the chat: control characters and the invisible ones that reverse or hide text
## become spaces ([method PlainText.clean]), runs of whitespace one space, trimmed, at most
## [constant MAX_CHAT_LENGTH] characters. "" when nothing printable is left.
static func clean(text: String) -> String:
	if _spaces == null:
		_spaces = RegEx.create_from_string("\\s+")
	var plain := PlainText.clean(text, MAX_READ_LENGTH)
	return _spaces.sub(plain, " ", true).left(MAX_CHAT_LENGTH).strip_edges()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if session == null:
		session = get_parent() as NetSession
	session.match_message.connect(_on_match_message)
	session.player_left.connect(_on_player_left)


func _physics_process(delta: float) -> void:
	time += delta


## Says [param text] to everyone in the session. The host's own line goes through the host's checks like
## anyone's; a client sends it to the host, cut to what a session message may hold.
func send(text: String) -> void:
	if session == null or not session.is_active():
		return
	if session.is_host():
		_handle_request(session.local_peer_id, text)
	else:
		session.send_to_host({"chat": text.left(NetSession.MAX_MESSAGE_TEXT_LENGTH)})


## The seconds since [param line] (one of [member lines]) arrived.
func age_of(line: Dictionary) -> float:
	return time - float(line["time"])


# --- The host ---


## The host: [param text] was said by [param peer_id] (a client's, or the host's own). Does everything in the class description.
func _handle_request(peer_id: int, text: Variant) -> void:
	if not (text is String or text is StringName) or not session.is_host():
		return
	var entry := session.get_player(peer_id)
	if entry.is_empty():
		return
	var line := clean(String(text))
	if line.is_empty():
		return
	if not _allow(peer_id):
		_tell(peer_id, SLOW_DOWN_TEXT)
		return
	var name_text: String = entry["name"]
	var data := {"chat": line, "from": peer_id, "name": name_text}
	for player in session.get_players():
		var other: int = player["peer_id"]
		if other != session.local_peer_id:
			session.send_to(other, data)
	_add_line(peer_id, name_text, line)


## The host: true when [param peer_id] may say one more line now, and counts it (a refused line isn't counted,
## so waiting out the window is enough).
func _allow(peer_id: int) -> bool:
	var times: Array = _sent.get(peer_id, [])
	times = times.filter(func(sent: float) -> bool: return time - sent < RATE_WINDOW)
	if times.size() >= RATE_MESSAGES:
		_sent[peer_id] = times
		return false
	times.append(time)
	_sent[peer_id] = times
	return true


## The host: a private note for [param peer_id] (a client gets it as a message, the host's own is local).
func _tell(peer_id: int, text: String) -> void:
	if peer_id == session.local_peer_id:
		notice.emit(text)
	else:
		session.send_to(peer_id, {"chat_notice": text})


func _on_player_left(peer_id: int) -> void:
	_sent.erase(peer_id)


# --- Everyone ---


func _on_match_message(data: Dictionary) -> void:
	if session.is_host():
		# What reaches the host is a client's request: only the text counts, who it is comes from the roster.
		if data.has("chat") and data.has("from"):
			_handle_request(int(data["from"]), data["chat"])
		return
	# A client: lines and notices come from the host (peer 1) alone.
	if session.match_message_sender != 1:
		return
	if data.has("chat"):
		var text: Variant = data["chat"]
		var author: Variant = data.get("from", 0)
		var name_text: Variant = data.get("name", "")
		if text is String and author is int and name_text is String:
			var line := clean(text)
			if not line.is_empty():
				_add_line(author, PlainText.clean(name_text, NetSession.MAX_NAME_LENGTH), line)
	elif data.has("chat_notice") and data["chat_notice"] is String:
		var note := PlainText.clean(data["chat_notice"], NetSession.MAX_MESSAGE_TEXT_LENGTH)
		if not note.is_empty():
			notice.emit(note)


func _add_line(peer_id: int, name_text: String, text: String) -> void:
	lines.append({"peer_id": peer_id, "name": name_text, "text": text, "time": time})
	while lines.size() > MAX_LINES:
		lines.pop_front()
	line_received.emit(peer_id, name_text, text)
