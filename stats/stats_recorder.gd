class_name StatsRecorder
extends Node
## Records your own numbers in a match and saves them in your history when it ends (M14, D-202).
## [Main] adds one under the match's rules (a [RoundManager]: rounds or Team respawn; practice has
## none) and it is freed with the map.
##
## It watches only **you** (the map's Player):
## - **bullets fired**, from the [signal Weapon.fired] of the gun in your hand (it follows
##   [signal Character.weapon_changed]), a shotgun's pellets counted one by one;
## - **hits**, from [signal Character.damaged] of every other character: a bullet of yours that
##   damaged an enemy counts as a hit of the gun that fired it, in the zone it hit. Offline and on
##   a host that is what the game itself decided; on a client it is **what the host announced**
##   (the host's DAMAGED event names the weapon, D-203), so a hit the host did not count is not a
##   hit in your stats either. Teammates, yourself, the knife and grenades are not counted;
## - **headshot kills**, from [signal RoundManager.character_killed];
## - the time played.
## Kills, deaths, assists and damage come from the rules' own scoreboard numbers at the end
## ([method RoundManager.get_stats]; online the host's), so the stats and the match-end screen
## always agree.
##
## When the rules emit [signal RoundManager.match_ended] it builds a [StatsMatch] and adds it to its
## [StatsBook] (the shared one unless a test gives its own). A match you leave before its end is not
## recorded: the history is for finished matches.

## Emitted after a finished match was added to the book.
signal recorded(record: StatsMatch)

var _rules: RoundManager
var _player: Character
var _book: StatsBook
var _online: bool = false
var _map_name: String = ""
## Weapon id → its numbers this match.
var _weapons: Dictionary[String, StatsWeapon] = {}
var _headshot_kills: int = 0
## Your kills and deaths in each minute so far.
var _kills_per_minute: Array[int] = []
var _deaths_per_minute: Array[int] = []
var _seconds: float = 0.0
var _weapon: Weapon
## The id of the gun that fired last: the credit for a hit whose weapon the host didn't name.
var _last_gun: String = ""
## The gun that did the last damage to an enemy: the kill that follows is its.
var _last_hit_gun: String = ""
## Characters whose damage is already followed.
var _watched: Dictionary = {}
var _done: bool = false


## Starts recording [param player]'s match under [param rules]. [param map_name] is the map's short
## name for the history ("depot"), [param online] marks a joined or hosted game, and [param book] is
## where the finished match goes (the shared [StatsBook] by default).
func setup(rules: RoundManager, player: Character, map_name: String, online: bool, book: StatsBook = null) -> void:
	_rules = rules
	_player = player
	_map_name = map_name
	_online = online
	_book = book if book != null else StatsBook.get_instance()
	player.weapon_changed.connect(_on_weapon_changed)
	_on_weapon_changed(player.weapon)
	rules.participant_joined.connect(_watch)
	for character in rules.get_participants():
		_watch(character)
	rules.character_killed.connect(_on_character_killed)
	rules.match_ended.connect(_on_match_ended)


## Makes the finished match go to [param book] instead of the book it was set up with. For tests
## that run two games in one process, where each side needs a book of its own.
func set_book(book: StatsBook) -> void:
	_book = book


func _physics_process(delta: float) -> void:
	if not _done:
		_seconds += delta


## What this match has so far for [param weapon_id] (an empty [StatsWeapon] if it never fired).
func get_weapon(weapon_id: String) -> StatsWeapon:
	return _weapons.get(weapon_id, StatsWeapon.new())


## The match as it stands, as a [StatsMatch], for the team that won ([param winner], -1 for none).
func build_record(winner: int) -> StatsMatch:
	var record := StatsMatch.new()
	record.date = int(Time.get_unix_time_from_system())
	record.mode = StatsMatch.MODE_RESPAWN if _rules.is_team_respawn() else StatsMatch.MODE_ROUNDS
	record.map = _map_name
	var team := _player.team
	if winner < 0 or winner >= _rules.score.size():
		record.result = StatsMatch.DRAW
	else:
		record.result = StatsMatch.WIN if winner == team else StatsMatch.LOSS
	record.score_us = _rules.score[team] if team < _rules.score.size() else 0
	for other in _rules.score.size():
		if other != team:
			record.score_them = maxi(record.score_them, _rules.score[other])
	record.rounds = _rules.get_rounds_played()
	record.duration = _seconds
	record.online = _online
	var stats := _rules.get_stats(_player)
	if stats != null:
		# A teamkill takes a point off the scoreboard's kills; the history never goes below 0.
		record.kills = maxi(stats.kills, 0)
		record.deaths = stats.deaths
		record.assists = stats.assists
		record.damage = stats.damage
	record.headshot_kills = mini(_headshot_kills, record.kills)
	record.kills_per_minute = _kills_per_minute.duplicate()
	record.deaths_per_minute = _deaths_per_minute.duplicate()
	for id in _weapons:
		if _weapons[id].shots > 0:
			record.weapons[id] = _weapons[id]
	return record


func _watch(character: Character) -> void:
	if character == _player or _watched.has(character):
		return
	_watched[character] = true
	character.damaged.connect(_on_damaged.bind(character))


func _on_weapon_changed(weapon: Weapon) -> void:
	if _weapon != null and is_instance_valid(_weapon) and _weapon.fired.is_connected(_on_fired):
		_weapon.fired.disconnect(_on_fired)
	_weapon = weapon
	if weapon != null:
		weapon.fired.connect(_on_fired)


func _on_fired(_spray_shot: int) -> void:
	if _weapon == null or not _counts(_weapon.data):
		return
	_last_gun = String(_weapon.data.id)
	_weapon_numbers(_last_gun).add_shots(maxi(_weapon.data.pellets, 1))


## One bullet of someone else's damaged [param victim]; [param attacker] is who shot.
func _on_damaged(amount: float, zone: Hitbox.Zone, attacker: Character, victim: Character) -> void:
	if attacker != _player or victim.team == _player.team:
		return
	var source := victim.last_damage_source
	var id := _last_gun if source == null else String(source.id)
	if id == "" or (source != null and not _counts(source)):
		return
	var numbers := _weapon_numbers(id)
	numbers.add_hit(zone)
	numbers.damage += amount
	_last_hit_gun = id


func _on_character_killed(victim: Character, killer: Character, headshot: bool) -> void:
	if killer == _player and victim != _player and victim.team != _player.team:
		_count_minute(_kills_per_minute)
		if headshot:
			_headshot_kills += 1
		# The gun the last bullet came from (a kill by the knife or a grenade has none).
		if _last_hit_gun != "":
			_weapon_numbers(_last_hit_gun).kills += 1
	elif victim == _player:
		_count_minute(_deaths_per_minute)
	_last_hit_gun = ""


## Counts one more in the current minute of [param minutes] (a list of counts per minute, grown as the match goes on).
func _count_minute(minutes: Array[int]) -> void:
	var index := mini(int(_seconds / 60.0), StatsMatch.MAX_MINUTES - 1)
	while minutes.size() <= index:
		minutes.append(0)
	minutes[index] += 1


func _on_match_ended(winner: int) -> void:
	if _done:
		return
	_done = true
	var record := build_record(winner)
	_book.add_match(record)
	recorded.emit(record)


func _weapon_numbers(id: String) -> StatsWeapon:
	if not _weapons.has(id):
		_weapons[id] = StatsWeapon.new()
	return _weapons[id]


## True for the weapons whose shots and hits are counted: guns, not the knife or grenades.
static func _counts(data: WeaponData) -> bool:
	return data != null and data.category != WeaponData.Category.KNIFE and data.category != WeaponData.Category.GRENADE
