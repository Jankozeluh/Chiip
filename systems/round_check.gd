class_name RoundCheck
extends Node
## A self-check of a whole round that runs in the real game, also in an exported release build
## (M16, D-223): [code]Chiip --headless --fixed-fps 128 -- --no-settings --check-round[/code] plays a
## short 2v2 match on Depot (the player stands still, the bots fight) and waits for the first round
## to end with a winner and the second to start, with every bot having walked at least
## [constant MIN_WALK] metres in the live round (bots that can't find their way, a navmesh lost in
## the export, would stand at their spawn). It prints [code]Chiip round check: PASS[/code] or
## [code]FAIL[/code] with what happened and quits with exit code 0 or 1.
## Exported builds don't run [code]--script[/code], so this is how a build is checked
## (tools/check_release.sh), like [HitCheck]. [code]main.gd[/code] adds it for the flag.

## Emitted with the result, before quitting (if [member quit_when_done]).
signal finished(passed: bool, detail: String)

## The flag that asks for it.
const FLAG := "--check-round"
## The longest the check waits, in seconds of game time: a whole round of [method rules] with time to spare.
const MAX_SECONDS := 90.0
## Metres every bot must walk in the live round of round 1.
const MIN_WALK := 5.0

## Quit the game with the result as the exit code (off in tests, which run it too).
var quit_when_done: bool = true

var _rounds: RoundManager
var _kills: int = 0
var _ended: Array = []
var _ticks: int = 0
## Each bot's walk in round 1's live phase: [Character] → [code][last position, metres][/code].
var _walks: Dictionary = {}
var _done: bool = false


## The match the check plays: 2v2 (the player and a bot against two bots), short freeze and round
## end, a 60 s round, and the bots don't shop, so every round looks alike.
static func rules() -> MatchSettings:
	var settings := MatchSettings.new()
	settings.team_size = 2
	settings.enemy_team_size = 2
	settings.freeze_time = 1.0
	settings.round_time = 60.0
	settings.round_end_time = 1.0
	settings.bots_buy = false
	return settings


func _ready() -> void:
	Weapon.silent = true
	_find_rounds.call_deferred()


func _find_rounds() -> void:
	var map := get_parent().call("get_map") as Node
	_rounds = map.get_node_or_null("RoundManager") as RoundManager if map != null else null
	if _rounds == null:
		_finish(false, "no round manager on the map")
		return
	_rounds.character_killed.connect(func(_victim: Character, _killer: Character, _headshot: bool) -> void: _kills += 1)
	_rounds.round_ended.connect(func(winner: int, reason: RoundManager.EndReason) -> void: _ended.append([winner, reason]))
	_rounds.round_started.connect(_on_round_started)


func _physics_process(_delta: float) -> void:
	if _done or _rounds == null:
		return
	_ticks += 1
	if _rounds.phase == RoundManager.Phase.LIVE and _ended.is_empty():
		_track_walks()
	if _ticks > MAX_SECONDS * Engine.physics_ticks_per_second:
		_finish(false, "no round ended within %.0f s of game time (round %d, %d kills)" % [
				MAX_SECONDS, _rounds.round_number, _kills])


func _on_round_started(round_number: int) -> void:
	if round_number < 2 or _done:
		return
	var winner: int = _ended[0][0] if not _ended.is_empty() else -1
	var reason: int = _ended[0][1] if not _ended.is_empty() else -1
	var shortest := INF
	for walk: Array in _walks.values():
		shortest = minf(shortest, walk[1])
	_finish(winner >= 0 and _walks.size() >= 3 and shortest >= MIN_WALK,
			"round 1 won by team %d (%s) with %d kills, %d bots walked at least %.1f m, round 2 started after %.1f s" % [
					winner, RoundManager.EndReason.keys()[reason] if reason >= 0 else "no end", _kills, _walks.size(),
					shortest if _walks.size() > 0 else 0.0, float(_ticks) / Engine.physics_ticks_per_second])


## Adds this tick's steps of every living bot to [member _walks].
func _track_walks() -> void:
	var player := get_parent().call("get_player") as Character
	for character in _rounds.get_participants():
		if character == player or not character.is_alive():
			continue
		var walk: Array = _walks.get(character, [character.global_position, 0.0])
		walk[1] += character.global_position.distance_to(walk[0])
		walk[0] = character.global_position
		_walks[character] = walk


func _finish(passed: bool, detail: String) -> void:
	_done = true
	print("Chiip round check: %s (%s)" % ["PASS" if passed else "FAIL", detail])
	finished.emit(passed, detail)
	if quit_when_done:
		get_tree().quit(0 if passed else 1)
