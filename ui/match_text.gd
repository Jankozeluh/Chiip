class_name MatchText
extends RefCounted
## The words about a match that the Tab scoreboard and the match-end screen
## share (D-137, the mockups' "15 Scoreboard" and "16 Match end"): the mode and
## the map ("Team Deathmatch · Depot"), and the clock line under them ("First
## to 50 · 7:42", "Round 3 · 1:12"). Read-only: it looks at a [RoundManager]
## and changes nothing.

## The mode's name on the Play screen: team respawn is Team Deathmatch, every
## match of rounds is Bomb (also on a map without bomb sites, where the Play
## screen offers the same card).
const TEAM_DEATHMATCH := "Team Deathmatch"
const BOMB := "Bomb"
## What the clock line says when there is no time to show: the tied end of a
## Team Deathmatch (the next kill wins), a planted bomb (the round clock has
## stopped, as the round HUD's "BOMB") and a round that is over.
const OVERTIME := "Overtime"
const PLANTED := "Planted"
const ROUND_OVER := "Over"


## The title of the map [param manager] runs on ("Depot"), or "" when its map
## isn't a scene file (a test's hand-made map).
static func map_title(manager: RoundManager) -> String:
	var map := manager.get_parent() if manager != null else null
	if map == null or map.scene_file_path.is_empty():
		return ""
	return GameLaunch.map_title(map.scene_file_path)


## The mode and the map, "Team Deathmatch · Depot" or "Bomb · Depot"; just the
## mode when the map has no title. Empty without a [param manager].
static func mode_line(manager: RoundManager) -> String:
	if manager == null:
		return ""
	var mode := TEAM_DEATHMATCH if manager.is_team_respawn() else BOMB
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
