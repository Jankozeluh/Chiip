class_name MapVote
extends Node
## The vote for the next map at the end of a match with a rotation (M17, D-244).
##
## The choices are the next [constant CHOICES] maps of the rotation after the one just played
## ([method pick_choices]). Everyone picks one (and may change it); "Next map" plays the map with the
## most votes, the earlier choice on a tie, and the first choice (the rotation's next map, what "Next
## map" played before the vote) when nobody voted ([method get_winner]).
##
## Offline you are the only voter. Online the host decides, like the chat (D-243): it sends the choices
## to everyone ([code]{"vote_map_0": path, ...}[/code]), a client's pick goes to the host
## ([code]{"vote": index}[/code], checked: a number in range while a vote is on; the voter is whoever
## the session says sent it), the host keeps one vote per player and sends the counts after every change
## ([code]{"vote_count_0": n, ...}[/code]). A client takes choices and counts from the host alone, and
## only maps of the rotation. Every value is a plain one, as session messages must be.

## Emitted when the choices or the counts changed.
signal changed

## How many maps are offered.
const CHOICES := 3

## The maps offered, in order (the first is the rotation's next).
var choices: Array[String] = []
## The session of an online match, or null offline.
var session: NetSession

## Offline and on the host: voter (peer id; 1 offline) → index of the choice.
var _votes: Dictionary = {}
## On a client: the host's counts.
var _counts: Array[int] = []
## This computer's pick, -1 for none.
var _mine: int = -1


## The next [constant CHOICES] maps of [param rotation] after the one at [param current] (wrapping
## round, no map twice; the map just played comes last, and only when the rotation is too short).
static func pick_choices(rotation: Array[String], current: int) -> Array[String]:
	var picked: Array[String] = []
	for step in range(1, rotation.size() + 1):
		var path := rotation[(current + step) % rotation.size()]
		if not picked.has(path):
			picked.append(path)
		if picked.size() == CHOICES:
			break
	return picked


func _ready() -> void:
	if session != null:
		session.match_message.connect(_on_match_message)
		session.player_left.connect(_on_player_left)


## Starts a vote on [param maps] (offline, or the host online: everyone gets the choices).
func start(maps: Array[String]) -> void:
	choices = maps.slice(0, CHOICES)
	_votes.clear()
	_counts.clear()
	_mine = -1
	if session != null and session.is_host():
		var data := {}
		for i in choices.size():
			data["vote_map_%d" % i] = choices[i]
		session.send_to_all(data)
	changed.emit()


## True while there are maps to vote on.
func is_open() -> bool:
	return not choices.is_empty()


## Picks the choice at [param index] for this computer's player.
func vote(index: int) -> void:
	if index < 0 or index >= choices.size():
		return
	_mine = index
	if session == null:
		_cast(1, index)
	elif session.is_host():
		_cast(session.local_peer_id, index)
	else:
		session.send_to_host({"vote": index})
		changed.emit()


## This computer's pick, -1 for none.
func get_my_vote() -> int:
	return _mine


## The votes for each choice, in [member choices] order.
func get_counts() -> Array[int]:
	if session != null and not session.is_host():
		return _counts
	var counts: Array[int] = []
	counts.resize(choices.size())
	counts.fill(0)
	for voter: int in _votes:
		counts[_votes[voter]] += 1
	return counts


## The map to play next: the most votes, the earlier choice on a tie, the first when nobody voted.
## "" without choices.
func get_winner() -> String:
	if choices.is_empty():
		return ""
	var counts := get_counts()
	var best := 0
	for i in counts.size():
		if counts[i] > counts[best]:
			best = i
	return choices[best]


func _cast(voter: int, index: int) -> void:
	_votes[voter] = index
	_send_counts()
	changed.emit()


func _send_counts() -> void:
	if session == null or not session.is_host():
		return
	var data := {}
	var counts := get_counts()
	for i in counts.size():
		data["vote_count_%d" % i] = counts[i]
	session.send_to_all(data)


func _on_player_left(peer_id: int) -> void:
	if _votes.erase(peer_id):
		_send_counts()
		changed.emit()


func _on_match_message(data: Dictionary) -> void:
	if session.is_host():
		# A client's pick: the voter is whoever the session says sent it.
		if data.has("vote") and data.has("from") and data["vote"] is int and int(data["vote"]) >= 0 and int(data["vote"]) < choices.size():
			_cast(int(data["from"]), int(data["vote"]))
		return
	if session.match_message_sender != 1:
		return
	if data.has("vote_map_0"):
		var maps: Array[String] = []
		for i in CHOICES:
			var path: Variant = data.get("vote_map_%d" % i)
			if path is String and GameLaunch.ROTATION_MAPS.has(path):
				maps.append(path)
		choices = maps
		_counts.clear()
		_counts.resize(choices.size())
		_counts.fill(0)
		_mine = -1
		changed.emit()
	elif data.has("vote_count_0"):
		for i in _counts.size():
			var count: Variant = data.get("vote_count_%d" % i, 0)
			_counts[i] = clampi(int(count), 0, NetSession.MAX_CLIENTS + 1) if count is int else 0
		changed.emit()
