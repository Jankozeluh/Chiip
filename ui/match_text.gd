class_name MatchText
extends RefCounted
## The words about a match that the Tab scoreboard and the match-end screen
## share (D-137, the mockups' "15 Scoreboard" and "16 Match end"): the mode and
## the map ("Team Deathmatch · Depot"), and the clock line under them ("First
## to 50 · 7:42", "Round 3 · 1:12"). Read-only: it looks at a [RoundManager]
## and changes nothing. It also builds the three lines of the loading screen
## (D-138, "07 Loading") from the match's rules, before there is a match to look at,
## and the words of a free-for-all (M17, D-240): who wins, your place, and the score the
## bars show when the teams' score stays 0–0.

## The mode's name on the Play screen: team respawn is Team Deathmatch, every
## match of rounds is Bomb (also on a map without bomb sites, where the Play
## screen offers the same card).
const TEAM_DEATHMATCH := "Team Deathmatch"
const FREE_FOR_ALL := "Free-for-all"
const BOMB := "Bomb"
## What a free-for-all's winner banner says when it is you ("You win"), and the end of it when it is
## somebody else ("Bot2 wins").
const YOU_WIN := "You win"
const WINS := "%s wins"
## What the clock line says when there is no time to show: the tied end of a
## Team Deathmatch (the next kill wins), a planted bomb (the round clock has
## stopped, as the round HUD's "BOMB") and a round that is over.
const OVERTIME := "Overtime"
const PLANTED := "Planted"
const ROUND_OVER := "Over"
## The loading screen's lines about practice: the kicker, and the mode line's words.
const PRACTICE := "Practice"
const PRACTICE_RULES := "bots respawn"


## The title of the map [param manager] runs on ("Depot"), or "" when its map
## isn't a scene file (a test's hand-made map).
static func map_title(manager: RoundManager) -> String:
	var map := manager.get_parent() if manager != null else null
	if map == null or map.scene_file_path.is_empty():
		return ""
	return GameLaunch.map_title(map.scene_file_path)


## The mode and the map, "Team Deathmatch · Depot", "Free-for-all · Depot" or "Bomb · Depot"; just the
## mode when the map has no title. Empty without a [param manager].
static func mode_line(manager: RoundManager) -> String:
	if manager == null:
		return ""
	var mode := _mode_of(manager)
	var map := map_title(manager)
	return mode if map.is_empty() else "%s · %s" % [mode, map]


## What is left of the match, "First to 50 · 7:42" in Team Deathmatch (the kill
## limit and the time left) and "Round 3 · 1:12" in rounds (the round and the
## time left in it; the freeze time counts down the same way, as it does on the
## round HUD). Empty without a [param manager].
static func clock_line(manager: RoundManager) -> String:
	if manager == null:
		return ""
	if manager.is_team_respawn():
		var respawn := manager as RespawnMatch
		var left := OVERTIME if respawn != null and respawn.overtime else RoundHud.format_time(manager.time_left)
		return "First to %d · %s" % [manager.settings.kill_limit, left]
	var round_left: String
	if manager.is_bomb_planted():
		round_left = PLANTED
	elif manager.phase == RoundManager.Phase.ROUND_END or manager.phase == RoundManager.Phase.MATCH_END:
		round_left = ROUND_OVER
	else:
		round_left = RoundHud.format_time(manager.time_left)
	return "Round %d · %s" % [manager.round_number, round_left]


## The kills [param you] has and the most kills of anybody else (the leader's, or the second's when
## you lead) in a free-for-all: the "score" the top bar and the Tab scoreboard show there, because the
## teams' score stays 0–0 ([FreeForAllMatch]). x is yours, y theirs; both 0 for any other match, or
## without [param you].
static func ffa_scores(manager: RoundManager, you: Character) -> Vector2i:
	var ffa := manager as FreeForAllMatch
	if ffa == null or not is_instance_valid(you):
		return Vector2i.ZERO
	var best := 0
	for character in ffa.get_standings():
		if character != you:
			best = ffa.get_kills(character)
			break
	return Vector2i(ffa.get_kills(you), best)


## [param you]'s place in a free-for-all, 1 for the best; 0 when [param manager] isn't one or you aren't in it.
static func ffa_place(manager: RoundManager, you: Character) -> int:
	var ffa := manager as FreeForAllMatch
	if ffa == null or not is_instance_valid(you):
		return 0
	return ffa.get_standings().find(you) + 1


## "1st", "2nd", "3rd", "4th", "11th", "21st".
static func ordinal(place: int) -> String:
	var tens := place % 100
	if tens >= 11 and tens <= 13:
		return "%dth" % place
	match place % 10:
		1:
			return "%dst" % place
		2:
			return "%dnd" % place
		3:
			return "%drd" % place
	return "%dth" % place


## "You placed 3rd of 6": your place among everybody in a free-for-all; empty when you aren't in it.
static func ffa_place_text(manager: RoundManager, you: Character) -> String:
	var place := ffa_place(manager, you)
	if place == 0:
		return ""
	return "You placed %s of %d" % [ordinal(place), (manager as FreeForAllMatch).get_standings().size()]


## Who won a free-for-all, said for the person at this computer: "You win" for [param you], otherwise
## "Bot2 wins". Empty without a [param winner].
static func ffa_winner_text(winner: Character, you: Character) -> String:
	if not is_instance_valid(winner):
		return ""
	return YOU_WIN if winner == you else WINS % String(winner.name)


## The three lines of the loading screen, top to bottom: [method loading_kicker],
## the map's title ("Square") and [method loading_mode_line]. [param map_path]
## is the scene's path; [param rotation_index] and [param rotation_size] say
## which map of the rotation it is (a size of 0: no rotation).
static func loading_lines(settings: MatchSettings, practice: bool, map_path: String, rotation_index: int = 0,
		rotation_size: int = 0) -> PackedStringArray:
	return PackedStringArray([loading_kicker(settings, practice, rotation_index, rotation_size),
			GameLaunch.map_title(map_path), loading_mode_line(settings, practice)])


## The small line over the map's name: "Map 2 of 3 · Rotation" when the maps are
## played in rotation (D-087; [param rotation_index] counts from 0), otherwise
## "Practice" or just the mode's name ("Team Deathmatch", "Bomb").
static func loading_kicker(settings: MatchSettings, practice: bool, rotation_index: int = 0, rotation_size: int = 0) -> String:
	if rotation_size > 0:
		return "Map %d of %d · Rotation" % [rotation_index + 1, rotation_size]
	return PRACTICE if practice else _mode_name(settings)


## The line under the map's name: the mode and its limit, "Team Deathmatch ·
## first to 50" (the kill limit), "Free-for-all · first to 20", "Bomb · first to 5 rounds" (the rounds to win)
## or "Practice · bots respawn".
static func loading_mode_line(settings: MatchSettings, practice: bool) -> String:
	if practice:
		return "%s · %s" % [PRACTICE, PRACTICE_RULES]
	var rules := settings if settings != null else MatchSettings.new()
	if rules.game_mode == MatchSettings.GameMode.TEAM_RESPAWN or rules.game_mode == MatchSettings.GameMode.FREE_FOR_ALL:
		return "%s · first to %d" % [_mode_name(rules), rules.kill_limit]
	return "%s · first to %d rounds" % [BOMB, rules.rounds_to_win]


## The mode's name: Team Deathmatch for team respawn, Free-for-all, Bomb for rounds.
static func _mode_name(settings: MatchSettings) -> String:
	if settings != null and settings.game_mode == MatchSettings.GameMode.FREE_FOR_ALL:
		return FREE_FOR_ALL
	return TEAM_DEATHMATCH if settings != null and settings.game_mode == MatchSettings.GameMode.TEAM_RESPAWN else BOMB


## The name of the mode [param manager] plays.
static func _mode_of(manager: RoundManager) -> String:
	if manager.is_free_for_all():
		return FREE_FOR_ALL
	return TEAM_DEATHMATCH if manager.is_team_respawn() else BOMB
