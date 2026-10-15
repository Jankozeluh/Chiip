class_name RoundManager
extends Node
## The rules of a match: two teams (you plus bot teammates against bots) play
## round after round. It owns the game state (phase, round timer, who's alive,
## who won the round, everyone's stats) and announces every change with
## signals. The HUD, kill feed, scoreboard and menus only listen and read.
##
## A round:
## 1. [b]Freeze time[/b]: everyone is back at their side's spawn with full
##    health and ammo, and can look around but not move or shoot.
## 2. [b]Live[/b]: the round timer runs. Eliminating the other team wins the
##    round; when time runs out, the defending side wins (as in CS).
## 3. [b]Round end[/b]: a short pause with the winner known and the score
##    updated. Survivors can still move and shoot. Then the next round starts.
##
## On maps with bomb sites a round is also a bomb round (D-080): an attacker
## carries the [Bomb]. Once it is planted the round clock stops: the bomb
## exploding wins it for the attackers, a defuse for the defenders. Killing
## every defender after the plant wins it for the attackers; killing every
## attacker doesn't end it, the defenders still have to defuse.
##
## A match is first to [member MatchSettings.rounds_to_win] rounds (D-041).
## After [code]rounds_to_win - 1[/code] rounds the sides swap ([signal
## sides_swapped]): the teams keep their numbers, only [member attacking_team]
## flips, so each team spawns at the other end. That makes the longest match
## [code]2 × rounds_to_win - 1[/code] rounds, so a draw is impossible. When a
## team reaches [code]rounds_to_win[/code], the last round's pause still runs,
## then the phase becomes [constant Phase.MATCH_END], everyone is frozen and
## [signal match_ended] is emitted. Nothing happens after that: it's up to the
## match-end screen to restart or leave.
##
## Whoever dies stays dead until the next round. Spawns are Marker3D nodes in
## the groups from [method Teams.spawn_group]; each team spawns at its side's
## end of the map.
##
## This is authority code (docs/ARCHITECTURE.md, "Keeping multiplayer
## possible"): in M9 only the host runs it, and the clients show what it
## announces. Add it as a child of the map, with [member settings] set first.

## The parts of a match. [constant MATCH_END] comes once a team has won the
## match and never ends: everyone stays frozen.
enum Phase { FREEZE, LIVE, ROUND_END, MATCH_END }
## Why a round was won. The last two end a team respawn match ([RespawnMatch]).
enum EndReason { ELIMINATION, TIME, BOMB_EXPLODED, BOMB_DEFUSED, KILL_LIMIT, TIME_LIMIT }

## Emitted whenever the phase changes; [member time_left] is already set for it.
signal phase_changed(phase: Phase)
## Emitted when a round's freeze time begins, after everyone has respawned.
signal round_started(round_number: int)
## Emitted once per round with the winning team and why it won. [member score]
## already counts this round.
signal round_ended(winner: int, reason: EndReason)
## Emitted at half time, after the round-end pause and before the next round
## starts: [member attacking_team] has just flipped, and everyone is about to
## respawn at the other end.
signal sides_swapped
## Emitted once, when the match is decided and the round-end pause of the last
## round is over. [param winner] is the team that reached
## [member MatchSettings.rounds_to_win]. The phase is [constant Phase.MATCH_END]
## and everyone is frozen.
signal match_ended(winner: int)
## Emitted for every death. [param killer] may be null; [param headshot] is
## true when the killing bullet hit the head.
signal character_killed(victim: Character, killer: Character, headshot: bool)

const BOT_SCENE := preload("res://bots/bot.tscn")
const BOMB_SCENE := preload("res://bomb/bomb.tscn")
## Damage a player must deal to an enemy killed by someone else to get an
## assist. CS: more than 40.
const ASSIST_DAMAGE := 41.0

## Everyone's numbers for the scoreboard.
class Stats:
	## Enemies killed, minus teammates killed.
	var kills: int = 0
	var deaths: int = 0
	## Kills of enemies this player damaged by at least ASSIST_DAMAGE that someone else finished.
	var assists: int = 0
	## Health taken from enemies (overkill doesn't count).
	var damage: float = 0.0

## The rules this match is played by. Set before the node enters the tree.
@export var settings: MatchSettings = MatchSettings.new()
## Which team you (the map's Player node) play on.
@export var player_team: int = 0

## The current phase. Read-only for other scripts.
var phase: Phase = Phase.FREEZE
## The round being played, from 1. 0 before the first round.
var round_number: int = 0
## Seconds left in the current phase.
var time_left: float = 0.0
## The team on the attacking side this half; the other team defends.
var attacking_team: int = 0
## Rounds won so far by each team (index = team number). Reset when the match
## starts, and counted before [signal round_ended] is emitted.
var score: Array[int] = []
## The team that won the match, or -1 while it is still being played.
var winner: int = -1
## Randomness for spawn spots and the starting sides. Seed it for repeatable tests.
var rng := RandomNumberGenerator.new()
## The bomb of a bomb round, or null on maps without bomb sites (and with
## [member MatchSettings.bomb_rounds] off): rounds are then won by elimination
## and time only.
var bomb: Bomb

## The map's Player node (you), or null on a map without one (then team 0 is all bots).
var _player: Character
## Everyone playing: the player (if the map has one) and the bots, in join order.
var _participants: Array[Character] = []
## Character → Stats.
var _stats: Dictionary = {}
## Victim → the zone of the last bullet that hit it (decides headshot kills).
var _last_hit_zone: Dictionary = {}
## Victim → {attacker: damage this life}, for assists.
var _damage_this_life: Dictionary = {}
var _bots_made: int = 0


func _ready() -> void:
	# Put the player on their team right away, so whoever shows the map
	# (main.gd) colors the teams from your point of view.
	_player = get_parent().get_node_or_null("Player") as Character
	if _player != null:
		_player.team = player_team
	# Wait for the whole map (navigation, spawn markers) to be ready.
	_start_match.call_deferred()


func _physics_process(delta: float) -> void:
	if round_number == 0 or phase == Phase.MATCH_END:
		return
	if phase == Phase.LIVE:
		_live_tick(delta)
		if _clock_stopped():
			return
	time_left -= delta
	if time_left > 0.0:
		return
	match phase:
		Phase.FREEZE:
			_go_live()
		Phase.LIVE:
			_on_time_up()
		Phase.ROUND_END:
			_after_round_end()


## The side [param team] plays this half.
func get_side(team: int) -> Teams.Side:
	return Teams.Side.ATTACKING if team == attacking_team else Teams.Side.DEFENDING


## The team on the defending side this half.
func get_defending_team() -> int:
	return Teams.other(attacking_team)


## Everyone on [param team], alive or not.
func get_members(team: int) -> Array[Character]:
	var members: Array[Character] = []
	for character in _participants:
		if is_instance_valid(character) and character.team == team:
			members.append(character)
	return members


## How many of [param team] are still alive.
func get_alive_count(team: int) -> int:
	return get_members(team).filter(func(member: Character) -> bool: return member.is_alive()).size()


## Everyone playing, in join order.
func get_participants() -> Array[Character]:
	return _participants.duplicate()


## The scoreboard numbers of [param character].
func get_stats(character: Character) -> Stats:
	return _stats.get(character)


## True while this round's bomb is planted and ticking.
func is_bomb_planted() -> bool:
	return bomb != null and bomb.is_planted()


## True for a team respawn match ([RespawnMatch]): one long round in which the
## dead come back, scored in kills.
func is_team_respawn() -> bool:
	return false


# --- Match and round flow ---


func _start_match() -> void:
	Teams.friendly_fire = settings.friendly_fire
	var bots_on_player_team := settings.team_size
	if _player != null:
		_join(_player)
		bots_on_player_team -= 1
	for i in bots_on_player_team:
		_add_bot(player_team)
	for i in settings.enemy_team_size:
		_add_bot(Teams.other(player_team))
	attacking_team = rng.randi_range(0, Teams.COUNT - 1)
	score.clear()
	for team in Teams.COUNT:
		score.append(0)
	winner = -1
	_add_bomb()
	_start_round()


func _start_round() -> void:
	round_number += 1
	_last_hit_zone.clear()
	_damage_this_life.clear()
	for team in Teams.COUNT:
		_spawn_team(team)
	if bomb != null:
		bomb.start_round(_pick_bomb_carrier(), attacking_team)
	_plan_bots()
	_set_frozen(true)
	_set_phase(Phase.FREEZE, settings.freeze_time)
	round_started.emit(round_number)


func _go_live() -> void:
	_set_frozen(false)
	if bomb != null:
		bomb.active = true
	_set_phase(Phase.LIVE, _round_duration())


func _end_round(round_winner: int, reason: EndReason) -> void:
	if bomb != null:
		# No more planting or defusing; a planted bomb still ticks and can explode.
		bomb.active = false
	# Count the round first, so everyone listening to the signals sees the new score.
	_score_round(round_winner)
	_set_phase(Phase.ROUND_END, settings.round_end_time)
	round_ended.emit(round_winner, reason)


## Runs when a round's end pause is over: either the match is decided, or the
## next round starts, after swapping sides if this was the last round before
## half time.
func _after_round_end() -> void:
	for team in Teams.COUNT:
		if score[team] >= settings.rounds_to_win:
			_end_match(team)
			return
	# Nobody can have won yet at this point, so half time never clashes with a match end.
	if round_number == settings.rounds_to_win - 1:
		attacking_team = get_defending_team()
		sides_swapped.emit()
	_start_round()


# Steps a variant of the match ([RespawnMatch]) replaces.


## Gives the bots their orders for the round that is starting.
func _plan_bots() -> void:
	BotTactics.plan_round(get_members(attacking_team), get_members(get_defending_team()), get_parent(), rng, settings.round_time)


## Seconds the live part of a round lasts.
func _round_duration() -> float:
	return settings.round_time


## Runs every tick of the live round, before the clock.
func _live_tick(_delta: float) -> void:
	pass


## True while the round clock doesn't count down: after the plant, the bomb's fuse decides.
func _clock_stopped() -> bool:
	return is_bomb_planted()


## The live round's clock ran out: the defenders held their end.
func _on_time_up() -> void:
	_end_round(get_defending_team(), EndReason.TIME)


## Counts a won round in the team score.
func _score_round(round_winner: int) -> void:
	score[round_winner] += 1


## Counts a kill in the team score; rounds don't (they count rounds won).
## Runs before [signal character_killed] is emitted.
func _score_kill(_victim: Character, _killer: Character) -> void:
	pass


func _end_match(match_winner: int) -> void:
	winner = match_winner
	_set_frozen(true)
	_set_phase(Phase.MATCH_END, 0.0)
	match_ended.emit(match_winner)


## Ends the round when a team has nobody left. Runs at the end of the frame,
## so two last players who kill each other in the same tick are both counted.
## After a plant the defenders must defuse: the attackers dying doesn't end the
## round, and the defenders dying ends it for the attackers.
func _check_elimination() -> void:
	if phase != Phase.LIVE:
		return
	var attackers_alive := get_alive_count(attacking_team)
	var defenders_alive := get_alive_count(get_defending_team())
	var planted := is_bomb_planted()
	if defenders_alive == 0 and (attackers_alive > 0 or planted):
		_end_round(attacking_team, EndReason.ELIMINATION)
	elif attackers_alive == 0 and not planted:
		# Also when both teams are wiped out at once: like a time-out, the defenders hold.
		_end_round(get_defending_team(), EndReason.ELIMINATION)


func _set_phase(new_phase: Phase, duration: float) -> void:
	phase = new_phase
	time_left = duration
	phase_changed.emit(phase)


# --- The bomb ---


## Adds the bomb if this is a bomb match on a map with bomb sites.
func _add_bomb() -> void:
	var map := get_parent()
	var has_sites := get_tree().get_nodes_in_group(Bomb.SITE_GROUP).any(func(node: Node) -> bool: return map.is_ancestor_of(node))
	if not settings.bomb_rounds or not has_sites:
		return
	bomb = BOMB_SCENE.instantiate()
	bomb.settings = settings
	map.add_child(bomb)
	bomb.planted.connect(_on_bomb_planted)
	bomb.exploded.connect(_on_bomb_exploded)
	bomb.defused.connect(_on_bomb_defused)


## A random attacker, as in CS (seeded, so tests can repeat it).
func _pick_bomb_carrier() -> Character:
	var attackers := get_members(attacking_team)
	if attackers.is_empty():
		return null
	return attackers[rng.randi_range(0, attackers.size() - 1)]


func _on_bomb_planted(_site: Area3D, _planter: Character) -> void:
	# If the attackers were already all dead, nothing changes: the defenders must defuse.
	_check_elimination.call_deferred()


func _on_bomb_exploded() -> void:
	if phase == Phase.LIVE:
		_end_round(attacking_team, EndReason.BOMB_EXPLODED)


func _on_bomb_defused(_defuser: Character) -> void:
	if phase == Phase.LIVE:
		_end_round(get_defending_team(), EndReason.BOMB_DEFUSED)


# --- Players ---


func _add_bot(team: int) -> void:
	var bot: Character = BOT_SCENE.instantiate()
	_bots_made += 1
	bot.name = "Bot%d" % _bots_made
	bot.team = team
	(bot.get_node("BotController") as BotController).difficulty = settings.bot_difficulty
	get_parent().add_child(bot)
	_join(bot)


func _join(character: Character) -> void:
	_participants.append(character)
	_stats[character] = Stats.new()
	character.damaged.connect(_on_damaged.bind(character))
	character.died.connect(_on_died.bind(character))


## Puts every member of [param team] on its own spawn marker of the team's side.
func _spawn_team(team: int) -> void:
	var markers := get_tree().get_nodes_in_group(Teams.spawn_group(get_side(team)))
	if markers.is_empty():
		push_error("RoundManager: the map has no '%s' markers." % Teams.spawn_group(get_side(team)))
		return
	_shuffle(markers)
	var members := get_members(team)
	for i in members.size():
		var marker := markers[i % markers.size()] as Node3D
		members[i].respawn(marker.global_position, marker.global_rotation.y)


func _set_frozen(frozen: bool) -> void:
	for character in _participants:
		if is_instance_valid(character):
			character.frozen = frozen


## Fisher–Yates shuffle with the seeded generator (Array.shuffle() uses the global one).
func _shuffle(items: Array) -> void:
	for i in range(items.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap: Variant = items[i]
		items[i] = items[j]
		items[j] = swap


# --- Damage, kills and stats ---


func _on_damaged(amount: float, zone: Hitbox.Zone, attacker: Character, victim: Character) -> void:
	_last_hit_zone[victim] = zone
	if attacker == null or attacker == victim or attacker.team == victim.team:
		return
	(_stats[attacker] as Stats).damage += amount
	var dealt: Dictionary = _damage_this_life.get_or_add(victim, {})
	dealt[attacker] = dealt.get(attacker, 0.0) + amount


func _on_died(killer: Character, victim: Character) -> void:
	(_stats[victim] as Stats).deaths += 1
	if killer != null and killer != victim and _stats.has(killer):
		(_stats[killer] as Stats).kills += -1 if killer.team == victim.team else 1
	var dealt: Dictionary = _damage_this_life.get(victim, {})
	for attacker: Character in dealt:
		if attacker != killer and dealt[attacker] >= ASSIST_DAMAGE and _stats.has(attacker):
			(_stats[attacker] as Stats).assists += 1
	_damage_this_life.erase(victim)
	_score_kill(victim, killer)
	character_killed.emit(victim, killer, _last_hit_zone.get(victim, -1) == Hitbox.Zone.HEAD)
	_check_elimination.call_deferred()
