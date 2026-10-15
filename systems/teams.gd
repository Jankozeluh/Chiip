class_name Teams
extends RefCounted
## Teams, sides and team colors, shared by every character and every map.
##
## There are two teams, numbered 0 and 1, with no names (D-041/D-042). The
## number is a character's stable identity for the whole match. Which team
## attacks and which defends is a separate thing, called the [enum Side]: it
## decides the spawn ends now, and bot behaviour and the time-out winner later.
## It swaps at half time, while the team numbers stay the same.
##
## Colors are relative to whoever is looking: you always see your own team in
## blue and the enemies in red, so enemies stand out for every player, also in
## multiplayer. See [member viewer_team].
##
## This is a plain class with static members rather than an autoload, because
## autoloads aren't loaded when Godot runs a [code]--script[/code] (our tools
## and checks), and those load maps that contain characters. Same pattern as
## [Noises].

## The two ends of the map. The attacking team pushes toward the other end; the
## defending team holds it, and wins when the round runs out of time.
enum Side { ATTACKING, DEFENDING }

## How many teams there are. Teams are the numbers 0 and 1.
const COUNT := 2

## What your own team looks like to you (the player's blue).
const FRIENDLY_COLOR := Color(0.25, 0.4, 0.7)
## What the enemy team looks like to you (the bots' red).
const ENEMY_COLOR := Color(0.72, 0.22, 0.18)

## Group of the spawn markers at the attackers' end of a map.
const ATTACK_SPAWN_GROUP := "attack_spawns"
## Group of the spawn markers at the defenders' end of a map.
const DEFEND_SPAWN_GROUP := "defend_spawns"

## The share of damage a teammate takes when friendly fire is on (CS competitive: a third).
const FRIENDLY_FIRE_DAMAGE := 1.0 / 3.0

## Whether teammates can hurt each other (a match setting, console: mp_friendlyfire).
## Off by default; bullets then pass through teammates (see [Weapon]).
static var friendly_fire: bool = false

## The team of the person at this computer. Their team is drawn blue and the
## other one red. Change it with [method set_viewer_team].
static var viewer_team: int = 0


## The name of the group holding the spawn markers of [param side].
static func spawn_group(side: Side) -> String:
	return ATTACK_SPAWN_GROUP if side == Side.ATTACKING else DEFEND_SPAWN_GROUP


## Sets the team of the person at this computer and recolors every character
## already in the world (new characters pick the right color when they appear).
static func set_viewer_team(team: int) -> void:
	viewer_team = team
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	for node in tree.get_nodes_in_group("characters"):
		(node as Character).update_team_color()


## The opposing team of [param team].
static func other(team: int) -> int:
	return 1 - team


## The clothes color of [param team] as seen by the viewer: blue for the
## viewer's own team, red for the other one.
static func color_for(team: int) -> Color:
	return FRIENDLY_COLOR if team == viewer_team else ENEMY_COLOR


## How much of an attack's damage reaches [param victim]: 1.0 for enemies, for
## yourself and for damage without an attacker. A teammate takes
## [constant FRIENDLY_FIRE_DAMAGE] if [member friendly_fire] is on, otherwise nothing.
static func damage_factor(victim: Character, attacker: Character) -> float:
	if attacker == null or attacker == victim or attacker.team != victim.team:
		return 1.0
	return FRIENDLY_FIRE_DAMAGE if friendly_fire else 0.0
