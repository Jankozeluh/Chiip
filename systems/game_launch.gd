class_name GameLaunch
extends RefCounted
## What the game should start with: the description the main menu leaves for
## [code]main.gd[/code] when it changes to the game scene (D-064).
##
## Changing scenes frees the old one, so the menu can't hand anything over
## through its own nodes. A static variable survives the change (a static class
## like [Settings] and [MenuState]: no node, no autoload, so tests and tools can
## use it). The menu fills it in with [method start_match] or
## [method start_practice] right before it calls
## [code]change_scene_to_file(GAME_SCENE)[/code]; main.gd reads it in
## [code]_ready()[/code] with [method is_pending] and empties it again with
## [method clear], so a description is used exactly once. When nothing is
## pending (the game scene started directly, as the tests and the command-line
## shortcuts do), main.gd falls back to its own exported values and the command
## line.
##
## It also knows the two scenes the game moves between and which maps exist.

## The game: the map, the rules, the HUD and the in-game menus.
const GAME_SCENE := "res://main.tscn"
## The main menu, the project's main scene.
const MENU_SCENE := "res://ui/main_menu.tscn"
## Where the maps are: every [code].tscn[/code] directly in this folder is offered
## by match setup (and by the console's [code]map[/code] command, which also lists
## subfolders).
const MAPS_FOLDER := "res://maps/"
## Where the bot difficulties are; [code]%s[/code] is easy, normal or hard.
const DIFFICULTY_PATH := "res://bots/difficulty_%s.tres"

## The map scene to play, e.g. [code]res://maps/test_map.tscn[/code].
static var map_path: String = Settings.DEFAULT_MAP
## True for practice (the respawning bot arena), false for a match.
static var practice: bool = false
## The rules of the match (practice only reads its bot difficulty).
static var match_settings: MatchSettings = null

## True between [method start_match] / [method start_practice] and [method clear].
static var _pending: bool = false


## Describes a match on [param map] played by [param rules].
static func start_match(map: String, rules: MatchSettings) -> void:
	map_path = map
	practice = false
	match_settings = rules
	_pending = true


## Describes practice on [param map] with bots of the given [param difficulty]
## (the respawning arena of [ArenaRules]; the other rules don't apply).
static func start_practice(map: String, difficulty: BotDifficulty) -> void:
	var rules := MatchSettings.new()
	rules.bot_difficulty = difficulty
	map_path = map
	practice = true
	match_settings = rules
	_pending = true


## True while a description waits for main.gd.
static func is_pending() -> bool:
	return _pending


## Forgets the description. main.gd calls it once it has read it; tests call it
## to leave nothing behind.
static func clear() -> void:
	map_path = Settings.DEFAULT_MAP
	practice = false
	match_settings = null
	_pending = false


## The [MatchSettings] for the choices stored in [param settings]: team sizes,
## bot difficulty, match length and friendly fire. The round timings stay at
## their defaults. Used by match setup's Start.
static func match_settings_from(settings: Settings) -> MatchSettings:
	var rules := MatchSettings.new()
	rules.team_size = settings.match_team_size
	rules.enemy_team_size = settings.match_enemy_team_size
	rules.bot_difficulty = difficulty_named(settings.match_difficulty)
	rules.rounds_to_win = settings.match_rounds_to_win
	rules.friendly_fire = settings.match_friendly_fire
	return rules


## The [BotDifficulty] called [param level] ("easy", "normal" or "hard"); normal
## for any other name.
static func difficulty_named(level: String) -> BotDifficulty:
	var path := DIFFICULTY_PATH % level
	if not Settings.DIFFICULTIES.has(level) or not ResourceLoader.exists(path):
		path = DIFFICULTY_PATH % "normal"
	return load(path) as BotDifficulty


## The map scenes match setup offers: every [code].tscn[/code] directly in
## [constant MAPS_FOLDER], as paths, sorted by name; never empty.
static func list_maps() -> Array[String]:
	var maps: Array[String] = []
	for file in DirAccess.get_files_at(MAPS_FOLDER):
		# An exported game lists scenes as "name.tscn.remap".
		var scene := file.trim_suffix(".remap")
		if scene.ends_with(".tscn"):
			maps.append(MAPS_FOLDER + scene)
	maps.sort()
	if maps.is_empty():
		maps.append(Settings.DEFAULT_MAP)
	return maps
