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
## Loadouts (D-090, D-094): every round starts with a fresh loadout for everyone,
## [member MatchSettings.round_loadout] (the knife and the Sparrow), no armor and no kit, and the
## guns left on the floor last round are gone. Whatever is bought or picked up lasts one round.
##
## Money (D-090, D-098), when [member MatchSettings.economy] is on: everyone starts each half
## with [member MatchSettings.start_money]; a round pays the winners
## [member MatchSettings.win_money] and the losers by how many rounds in a row they have lost
## ([member MatchSettings.loss_money]); a kill pays its weapon's [member WeaponData.kill_reward]
## (a teamkill costs [member MatchSettings.teamkill_penalty]); the plant pays every attacker and the
## defuse the defuser. Money carries over between rounds, gear doesn't. [method spend] is how the
## buy menu pays (task 11), through [method request_buy].
##
## Classes (D-052, D-078, D-099): the class draft ([member MatchSettings.class_draft]) offers
## everyone two random classes when the match starts ([method get_draft]); every offer has a class
## the team doesn't have yet while there is one, and bots take the one their team has fewer of, so
## each team gets a mix. You start as your first ([member MatchSettings.player_class] if set), and
## [method request_class] changes between your two during freeze time only.
##
## This is authority code (docs/ARCHITECTURE.md, "Keeping multiplayer
## possible"): in M9 only the host runs it, and the clients show what it
## announces. Add it as a child of the map, with [member settings] set first.
##
## Online (M9): on the host the friends' characters join first ([member extra_players]) and the
## match starts when everyone has loaded ([member autostart] off, [method start]). On a client
## it is a [member replica] (D-105): the same fields and signals, filled in by the network code
## from the host's snapshots and events with the [code]replica_*[/code] methods, and no
## decisions of its own.

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
## Emitted when a bot of [param team] calls out an enemy it just spotted (M15, D-216); [param text] says where
## ([method BotSquad.callout_text], seen from this computer's player when on that team). Host and offline only.
signal callout(team: int, text: String)
## Emitted when [method request_class] gave [param character] another class.
signal class_changed(character: Character, data: ClassData)
## Emitted when the match starts and [param character] has been offered [param classes] (the
## class draft, two classes).
signal class_drafted(character: Character, classes: Array[ClassData])
## Emitted when [param character]'s money changes by [param amount] (negative when spent), for
## [param reason]: "Round won", "Round lost", "Kill", "Teamkill", "Bomb planted", "Bomb defused",
## "Bought", "New half". [method get_money] has the new total.
signal money_changed(character: Character, amount: int, reason: String)
## Emitted when [param character] bought [param item_id] ([Shop]).
signal item_bought(character: Character, item_id: StringName)

const BOT_SCENE := preload("res://bots/bot.tscn")
## How many classes the draft offers each player (D-099).
const DRAFT_SIZE := 2
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
## Start the match by itself once the map is ready. Online the host turns it off and calls
## [method start] when every friend has loaded the map.
@export var autostart: bool = true
## Online, on a client (M9, D-105): a copy that shows the host's match and decides nothing. The
## network code fills in its fields and emits its signals; the clock only counts down between
## the host's updates, so the timer runs smoothly. Set before the node enters the tree.
@export var replica: bool = false

## Online, on the host (M9): the friends' characters (already on the map, each with its
## [member Character.team]). They join right after the host's player, before the bots that fill
## the rest of each team. Set before the match starts.
var extra_players: Array[Character] = []
## Online, on a client: what [method request_class] does instead of deciding (asks the host).
var class_request: Callable
## Online, on a client: what [method request_buy] does instead of buying (asks the host, D-113).
var buy_request: Callable

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
## The guns that appear at random places on the map (D-098): a child of this node, made when the
## match starts.
var map_weapons: MapWeapons

## Every participant's money: Character → int.
var _money: Dictionary = {}
## Rounds lost in a row by each team (index = team number), for the loss money.
var _loss_streak: Array[int] = [0, 0]
## Randomness for the bots' class mix. It is seeded from [member rng] without drawing from it,
## so the mix doesn't change the spawn spots and the starting sides a seed gives.
var _class_rng := RandomNumberGenerator.new()
## The class draft: Character → its two classes this match (Array[ClassData]).
var _drafts: Dictionary = {}

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
	if replica or not autostart:
		return
	# Wait for the whole map (navigation, spawn markers) to be ready.
	_start_match.call_deferred()


## Starts the match now (when [member autostart] is off; online the host waits for everyone to
## load). Does nothing once the match has started.
func start() -> void:
	if round_number == 0 and score.is_empty() and not replica:
		_start_match()


func _physics_process(delta: float) -> void:
	if round_number == 0 or phase == Phase.MATCH_END:
		return
	if replica:
		# Only the clock, between the host's updates; the host decides when a phase ends.
		if not (phase == Phase.LIVE and _clock_stopped()):
			time_left = maxf(time_left - delta, 0.0)
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


## Changes the class of [param character] to [param data], if the rules allow it: only during
## freeze time (and before the first round has started), and only to a class of its draft
## ([method get_draft]). Returns true if the character now has that class, false when refused (a
## live round, a round end, the end of the match, a class it wasn't offered) or when there is
## nothing to change to. Emits [signal class_changed] when the class was another one.
## The class menu and the console's [code]class[/code] command ask here; nobody sets
## [member Character.class_data] of a player in a match directly (authority code, D-078).
func request_class(character: Character, data: ClassData) -> bool:
	if phase != Phase.FREEZE or data == null or not is_instance_valid(character) or not is_drafted(character, data):
		return false
	if replica:
		# Online, on a client: the host decides; its answer comes back as a class change.
		if class_request.is_valid():
			class_request.call(character, data)
		return true
	if character.class_data != data:
		character.class_data = data
		class_changed.emit(character, data)
	return true


## The classes [param character] was offered this match (the class draft, D-099): two, or every
## class when the draft is off or it has none.
func get_draft(character: Character) -> Array[ClassData]:
	if _drafts.has(character):
		return _drafts[character]
	return ClassData.all()


## True if [param character] may play [param data] this match (it is one of its draft).
func is_drafted(character: Character, data: ClassData) -> bool:
	return get_draft(character).has(data)


# --- Match and round flow ---


func _start_match() -> void:
	Teams.friendly_fire = settings.friendly_fire
	_class_rng.seed = rng.seed
	if settings.class_draft:
		_join_drafted()
	else:
		_join_in_turn()
	attacking_team = rng.randi_range(0, Teams.COUNT - 1)
	score.clear()
	for team in Teams.COUNT:
		score.append(0)
	winner = -1
	_reset_money()
	_add_bomb()
	_add_map_weapons()
	_start_round()


func _start_round() -> void:
	round_number += 1
	_last_hit_zone.clear()
	_damage_this_life.clear()
	for team in Teams.COUNT:
		_spawn_team(team)
	_clear_floor()
	_place_map_weapons()
	for character in _participants:
		if is_instance_valid(character):
			_give_loadout(character)
	if bomb != null:
		bomb.start_round(_pick_bomb_carrier(), attacking_team)
	_plan_bots()
	_set_frozen(true)
	_set_phase(Phase.FREEZE, _freeze_time())
	# The bots shop as the freeze time begins, by their team's money (D-099).
	if settings.bots_buy:
		for team in Teams.COUNT:
			BotBuyer.buy_for_team(self, team, _class_rng)
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
	_pay_round(round_winner)
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
		# A new half: everyone back to the starting money, as in CS, and the bots choose again.
		_reset_money()
		_rechoose_bot_classes()
		sides_swapped.emit()
	_start_round()


# Steps a variant of the match ([RespawnMatch]) replaces.


## Gives the bots their orders for the round that is starting.
func _plan_bots() -> void:
	BotTactics.plan_round(get_members(attacking_team), get_members(get_defending_team()), get_parent(), rng, settings.round_time)


## The weapons [param character] gets at a round start: the same fresh loadout for everyone.
func _loadout_for(_character: Character) -> Array[WeaponData]:
	return settings.round_loadout


## Seconds of freeze time at a round start (the buy time, D-098).
func _freeze_time() -> float:
	return settings.freeze_time


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
	bomb.replica = replica
	map.add_child(bomb)
	if replica:
		# The host ends the rounds; the replica only shows them.
		return
	bomb.planted.connect(_on_bomb_planted)
	bomb.exploded.connect(_on_bomb_exploded)
	bomb.defused.connect(_on_bomb_defused)
	# A defuse kit halves the defuse (D-080's hook, filled in M7: D-098).
	bomb.kit_check = func(defuser: Character) -> bool: return defuser.has_defuse_kit


## A random attacker, as in CS (seeded, so tests can repeat it).
func _pick_bomb_carrier() -> Character:
	var attackers := get_members(attacking_team)
	if attackers.is_empty():
		return null
	return attackers[rng.randi_range(0, attackers.size() - 1)]


func _on_bomb_planted(_site: Area3D, _planter: Character) -> void:
	for attacker in get_members(attacking_team):
		add_money(attacker, settings.plant_money, "Bomb planted")
	# If the attackers were already all dead, nothing changes: the defenders must defuse.
	_check_elimination.call_deferred()


func _on_bomb_exploded() -> void:
	if phase == Phase.LIVE:
		_end_round(attacking_team, EndReason.BOMB_EXPLODED)


func _on_bomb_defused(defuser: Character) -> void:
	add_money(defuser, settings.defuse_money, "Bomb defused")
	if phase == Phase.LIVE:
		_end_round(get_defending_team(), EndReason.BOMB_DEFUSED)


# --- Money (D-098) ---


## True if [param character] may shop now: a match with money, in freeze time (D-098), alive.
## The buy menu asks before it opens.
func can_buy_now(character: Character) -> bool:
	return has_economy() and phase == Phase.FREEZE and round_number > 0 and is_instance_valid(character) \
			and character.is_alive() and _participants.has(character)


## Seconds of buy time left (the freeze time's), 0 when buying is over.
func get_buy_time_left() -> float:
	return time_left if phase == Phase.FREEZE else 0.0


## What [param item_id] costs [param character] now ([method Shop.price_for]).
func get_price(character: Character, item_id: StringName) -> int:
	return Shop.price_for(character, item_id)


## Why [param character] can't buy [param item_id] now, or "" if it can: the time, the money, or
## what it carries ([method Shop.refusal]; a kit is for defenders on a map with the bomb).
func get_buy_refusal(character: Character, item_id: StringName) -> String:
	if not has_economy():
		return "No buying in this mode"
	if not can_buy_now(character):
		return "Buying is over" if phase != Phase.FREEZE else "You can't buy now"
	var reason := Shop.refusal(character, item_id, get_side(character.team) == Teams.Side.DEFENDING, bomb != null)
	if reason != "":
		return reason
	if get_money(character) < get_price(character, item_id):
		return "Not enough money"
	return ""


## Buys [param item_id] for [param character] if the rules allow it: pays and hands it over
## ([method Shop.give]). Returns "" when bought, else why not. The buy menu and the bots ask here
## (authority code: in M9 the host decides every purchase).
func request_buy(character: Character, item_id: StringName) -> String:
	var reason := get_buy_refusal(character, item_id)
	if reason != "":
		return reason
	if replica:
		# Online, on a client: the host decides; the money and what you carry come back from it.
		if buy_request.is_valid():
			buy_request.call(character, item_id)
		return ""
	spend(character, get_price(character, item_id))
	Shop.give(character, item_id)
	item_bought.emit(character, item_id)
	return ""


## True if this match has money (rounds with [member MatchSettings.economy] on).
func has_economy() -> bool:
	return settings.economy and not is_team_respawn()


## How much money [param character] has (0 without an economy).
func get_money(character: Character) -> int:
	return _money.get(character, 0)


## Gives [param character] [param amount] (negative takes it away), capped at
## [member MatchSettings.max_money] and never below 0, and says why. Does nothing without an
## economy. Returns the change actually made.
func add_money(character: Character, amount: int, reason: String) -> int:
	if not has_economy() or not _money.has(character):
		return 0
	var before: int = _money[character]
	var after := clampi(before + amount, 0, settings.max_money)
	_money[character] = after
	if after != before:
		money_changed.emit(character, after - before, reason)
	return after - before


## Takes [param amount] from [param character] if it has that much. Returns true if it paid.
func spend(character: Character, amount: int) -> bool:
	if not has_economy() or get_money(character) < amount:
		return false
	add_money(character, -amount, "Bought")
	return true


## How much [param team] gets for losing the next round now (by its losses in a row).
func get_loss_money(team: int) -> int:
	var table := settings.loss_money
	if table.is_empty():
		return 0
	return table[mini(_loss_streak[team], table.size() - 1)]


## Everyone back to the starting money, no losses in a row (the match start and half time).
func _reset_money() -> void:
	_loss_streak = [0, 0]
	if not has_economy():
		return
	for character in _participants:
		var before: int = _money.get(character, 0)
		_money[character] = settings.start_money
		money_changed.emit(character, settings.start_money - before, "New half")


## Pays a round: the winners the win money, the losers by their losses in a row.
func _pay_round(round_winner: int) -> void:
	var loser := Teams.other(round_winner)
	var loss := get_loss_money(loser)
	for character in get_members(round_winner):
		add_money(character, settings.win_money, "Round won")
	for character in get_members(loser):
		add_money(character, loss, "Round lost")
	_loss_streak[loser] += 1
	_loss_streak[round_winner] = 0


## A kill pays the killer its weapon's reward ($200, $500 with the knife); a teamkill costs.
func _pay_kill(victim: Character, killer: Character) -> void:
	if killer == null or killer == victim or not _money.has(killer) or phase == Phase.MATCH_END:
		return
	if killer.team == victim.team:
		add_money(killer, -settings.teamkill_penalty, "Teamkill")
		return
	var weapon := victim.last_damage_source
	add_money(killer, weapon.kill_reward if weapon != null else 200, "Kill")


# --- Players ---


func _add_bot(team: int, data: ClassData) -> Character:
	var bot: Character = BOT_SCENE.instantiate()
	_bots_made += 1
	bot.name = "Bot%d" % _bots_made
	bot.team = team
	bot.class_data = data
	(bot.get_node("BotController") as BotController).difficulty = settings.bot_difficulty
	get_parent().add_child(bot)
	_join(bot)
	return bot


func _join(character: Character) -> void:
	_participants.append(character)
	_stats[character] = Stats.new()
	_money[character] = 0
	character.damaged.connect(_on_damaged.bind(character))
	character.died.connect(_on_died.bind(character))
	var brain := character.get_node_or_null("BotController") as BotController
	if brain != null:
		brain.called_out.connect(_on_called_out.bind(character))


## Without the draft (M6): each team's bots cycle through the classes from a random one, so three
## bots are three classes; the player keeps the map Player's class or [member MatchSettings.player_class].
func _join_in_turn() -> void:
	var classes := ClassData.all()
	var class_offsets: Array[int] = []
	for team in Teams.COUNT:
		class_offsets.append(_class_rng.randi_range(0, classes.size() - 1))
	var bots_on_player_team := settings.team_size
	var bots_on_enemy_team := settings.enemy_team_size
	if _player != null:
		if settings.player_class != null:
			_player.class_data = settings.player_class
		_join(_player)
		bots_on_player_team -= 1
	# Online: the friends fill their teams' slots before the bots do (D-108).
	for other in extra_players:
		_join(other)
		if other.team == player_team:
			bots_on_player_team -= 1
		else:
			bots_on_enemy_team -= 1
	for i in bots_on_player_team:
		_add_bot(player_team, classes[(class_offsets[player_team] + i) % classes.size()])
	for i in bots_on_enemy_team:
		_add_bot(Teams.other(player_team), classes[(class_offsets[Teams.other(player_team)] + i) % classes.size()])


## The class draft (D-099): you first, then your team's bots, then the enemy's, each offered two
## classes ([method _draw_offer]). You start as the first of yours (or
## [member MatchSettings.player_class], which then is one of the two); a bot takes the one its team
## has fewer of.
func _join_drafted() -> void:
	var on_team: Array = [[], []]
	var bots_on_player_team := settings.team_size
	if _player != null:
		var offer := _draw_offer(on_team[player_team])
		if settings.player_class != null and not offer.has(settings.player_class):
			offer[1 if offer[0] == settings.player_class else 0] = settings.player_class
		if settings.player_class != null:
			_player.class_data = settings.player_class
		else:
			_player.class_data = offer[0]
		on_team[player_team].append(_player.class_data)
		_drafts[_player] = offer
		_join(_player)
		class_drafted.emit(_player, offer)
		bots_on_player_team -= 1
	# Online: the friends are drafted like you, before the bots (D-108).
	var bots_on_enemy_team := settings.enemy_team_size
	for other in extra_players:
		var friend_offer := _draw_offer(on_team[other.team])
		other.class_data = friend_offer[0]
		on_team[other.team].append(other.class_data)
		_drafts[other] = friend_offer
		_join(other)
		class_drafted.emit(other, friend_offer)
		if other.team == player_team:
			bots_on_player_team -= 1
		else:
			bots_on_enemy_team -= 1
	var teams: Array[int] = [player_team, Teams.other(player_team)]
	var counts: Array[int] = [bots_on_player_team, bots_on_enemy_team]
	for t in teams.size():
		var team := teams[t]
		for i in counts[t]:
			var offer := _draw_offer(on_team[team])
			var pick := _less_played(offer, on_team[team])
			on_team[team].append(pick)
			var bot := _add_bot(team, pick)
			_drafts[bot] = offer
			class_drafted.emit(bot, offer)


## Two different random classes, at least one of them a class [param on_team] doesn't have yet
## (while there is one), so a team always gets a mix.
func _draw_offer(on_team: Array) -> Array[ClassData]:
	var classes := ClassData.all()
	var offer: Array[ClassData] = []
	while offer.size() < mini(DRAFT_SIZE, classes.size()):
		var data := classes[_class_rng.randi_range(0, classes.size() - 1)]
		if not offer.has(data):
			offer.append(data)
	var missing := classes.filter(func(data: ClassData) -> bool: return not on_team.has(data))
	if not missing.is_empty() and not offer.any(func(data: ClassData) -> bool: return missing.has(data)):
		offer[offer.size() - 1] = missing[_class_rng.randi_range(0, missing.size() - 1)]
	return offer


## True for a bot (the player and, online, the friends pick their own classes).
static func _is_bot(member: Character) -> bool:
	return member.get_node_or_null("BotController") is BotController


## The class of [param offer] that [param on_team] has fewer of (the first on a tie).
func _less_played(offer: Array[ClassData], on_team: Array) -> ClassData:
	var best := offer[0]
	for data in offer:
		if on_team.count(data) < on_team.count(best):
			best = data
	return best


## At half time a bot may change class (D-099). With the draft, each bot switches to its other
## drafted class unless a teammate already plays more of that one than of its current class, so
## the team keeps its mix; without it, still one of each before any repeats, from a new random
## start. Either way a bot mostly plays the second half as something else.
func _rechoose_bot_classes() -> void:
	if not _drafts.is_empty():
		_redraft_bots()
		return
	var classes := ClassData.all()
	for team in Teams.COUNT:
		# The same shift for every bot of the team keeps their classes different from each other.
		var offset := _class_rng.randi_range(1, classes.size() - 1)
		for member in get_members(team):
			if not _is_bot(member):
				continue
			var current := classes.find(member.class_data)
			var data := classes[(maxi(current, 0) + offset) % classes.size()]
			if data != member.class_data:
				member.class_data = data
				class_changed.emit(member, data)


func _redraft_bots() -> void:
	for team in Teams.COUNT:
		var members := get_members(team)
		for member in members:
			if not _is_bot(member) or not _drafts.has(member):
				continue
			var others: Array = members.filter(func(other: Character) -> bool: return other != member).map(
					func(other: Character) -> ClassData: return other.class_data)
			for data: ClassData in _drafts[member]:
				if data != member.class_data and others.count(data) <= others.count(member.class_data):
					member.class_data = data
					class_changed.emit(member, data)
					break


## Puts every member of [param team] on its own spawn marker of the team's side.
func _spawn_team(team: int) -> void:
	var map := get_parent()
	var markers := get_tree().get_nodes_in_group(Teams.spawn_group(get_side(team))).filter(
			func(node: Node) -> bool: return map.is_ancestor_of(node))
	if markers.is_empty():
		push_error("RoundManager: the map has no '%s' markers." % Teams.spawn_group(get_side(team)))
		return
	_shuffle(markers)
	var members := get_members(team)
	for i in members.size():
		var marker := markers[i % markers.size()] as Node3D
		members[i].respawn(marker.global_position, marker.global_rotation.y)


## Gives [param character] its loadout ([method _loadout_for]) and takes away armor and kit.
func _give_loadout(character: Character) -> void:
	var loadout := _loadout_for(character)
	if not loadout.is_empty():
		character.inventory.set_loadout(loadout)
	character.set_armor(0.0, false)
	character.set_defuse_kit(false)


## Makes [member map_weapons] (D-098): [member MatchSettings.map_weapons] guns each round, away
## from the team spawns and off the bomb sites, drawn from a generator seeded from [member rng]
## (so placing them doesn't change the spawn spots a seed gives).
func _add_map_weapons() -> void:
	map_weapons = MapWeapons.new()
	map_weapons.name = "MapWeapons"
	map_weapons.rng.seed = rng.seed + 7919
	_set_up_map_weapons(map_weapons)
	add_child(map_weapons)


## The rounds' map weapons: a new set every round, none replaced during it.
func _set_up_map_weapons(weapons: MapWeapons) -> void:
	weapons.count = settings.map_weapons
	weapons.replace_time = -1.0
	weapons.avoid_bomb_sites = bomb != null


## Every round start: the last round's map weapons go, new ones appear somewhere else.
func _place_map_weapons() -> void:
	if map_weapons != null:
		map_weapons.replace_all()


## Removes every gun lying on the map's floor (a new round starts clean).
func _clear_floor() -> void:
	var map := get_parent()
	for node in WeaponPickup.all_in_world(map):
		if map.is_ancestor_of(node) and not (node as WeaponPickup).spot:
			node.remove_from_group(WeaponPickup.GROUP)
			node.queue_free()


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
	_pay_kill(victim, killer)
	_score_kill(victim, killer)
	if phase == Phase.LIVE and killer != null and killer.team != victim.team:
		# A trade (D-216): the victim's teammates close by go for the killer.
		BotSquad.call_team(victim, killer.global_position)
	character_killed.emit(victim, killer, _last_hit_zone.get(victim, -1) == Hitbox.Zone.HEAD)
	_check_elimination.call_deferred()


## A bot spotted an enemy at [param enemy_position] (D-216): its free teammates close by go and look, and its
## team hears where ([signal callout]).
func _on_called_out(enemy_position: Vector3, caller: Character) -> void:
	if phase != Phase.LIVE:
		return
	BotSquad.call_team(caller, enemy_position)
	var listener: Character = _player if is_instance_valid(_player) and _player.team == caller.team else caller
	callout.emit(caller.team, BotSquad.callout_text(enemy_position, get_parent(), listener))


# --- Online: the replica on a client (M9, D-105) ---


## Sets the replica up for the host's match: the friendly-fire rule (bullets pass through
## teammates in your own predicted shots too), an empty score and, on maps with bomb sites, the
## replica bomb. Call it once, before the first state arrives.
func replica_start() -> void:
	Teams.friendly_fire = settings.friendly_fire
	score.clear()
	for team in Teams.COUNT:
		score.append(0)
	_add_bomb()


## Adds [param character] to the match as the host's does (the host's join order).
func replica_join(character: Character) -> void:
	if not _participants.has(character):
		_participants.append(character)
		_stats[character] = Stats.new()
		_money[character] = 0


## The host's money of [param character]: [param total] now, changed by [param amount] for
## [param reason]. Emits [signal money_changed] (the HUD's reward lines) when it changed.
func replica_set_money(character: Character, total: int, amount: int, reason: String) -> void:
	if not _participants.has(character):
		return
	_money[character] = total
	if amount != 0:
		money_changed.emit(character, amount, reason)


## The classes the host's draft offered [param character]: emits [signal class_drafted].
func replica_drafted(character: Character, classes: Array[ClassData]) -> void:
	_drafts[character] = classes
	class_drafted.emit(character, classes)


## Drops [param character] from the match (it left the game).
func replica_leave(character: Character) -> void:
	_participants.erase(character)
	_stats.erase(character)


## Sets the scoreboard numbers of [param character] to the host's.
func replica_set_stats(character: Character, kills: int, deaths: int, assists: int, damage: float) -> void:
	var stats: Stats = _stats.get(character)
	if stats == null:
		return
	stats.kills = kills
	stats.deaths = deaths
	stats.assists = assists
	stats.damage = damage


## The host's match state: the phase with its clock, the round, the sides and the score.
## Emits [signal phase_changed] when the phase changed.
func replica_set_state(new_phase: Phase, new_time_left: float, new_round: int, attackers: int, new_score: Array) -> void:
	var changed := new_phase != phase or new_round != round_number
	round_number = new_round
	attacking_team = attackers
	score.assign(new_score)
	if changed:
		_set_phase(new_phase, new_time_left)
	else:
		time_left = new_time_left


## Corrects the clock to the host's (snapshots carry it).
func replica_set_clock(new_time_left: float) -> void:
	time_left = new_time_left


## The host's round started: emits [signal round_started].
func replica_round_started(new_round: int) -> void:
	round_number = new_round
	round_started.emit(new_round)


## The host's round ended: the score already counts it. Emits [signal round_ended].
func replica_round_ended(round_winner: int, reason: EndReason, new_score: Array) -> void:
	score.assign(new_score)
	round_ended.emit(round_winner, reason)


## The host swapped the sides: emits [signal sides_swapped].
func replica_sides_swapped(attackers: int) -> void:
	attacking_team = attackers
	sides_swapped.emit()


## The host's match ended: emits [signal match_ended].
func replica_match_ended(match_winner: int, new_score: Array) -> void:
	winner = match_winner
	score.assign(new_score)
	_set_phase(Phase.MATCH_END, 0.0)
	match_ended.emit(match_winner)


## Someone died on the host: emits [signal character_killed] (the kill feed).
func replica_killed(victim: Character, killer: Character, headshot: bool) -> void:
	character_killed.emit(victim, killer, headshot)


## The host gave [param character] another class: swaps it here and emits [signal class_changed].
func replica_class_changed(character: Character, data: ClassData) -> void:
	if character.class_data != data:
		character.class_data = data
	class_changed.emit(character, data)

