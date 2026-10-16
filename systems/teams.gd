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
## multiplayer. See [member viewer_team]. The colour-blind scheme (M15, D-210)
## swaps red for orange and darkens the blue, so the two teams differ in lightness
## as well as in hue; see [enum ColorScheme] and [method set_color_scheme].
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

## What your own team looks like to you (the player's blue), in the standard scheme.
## Read [method friendly_color] for what is on screen now.
const FRIENDLY_COLOR := Color(0.25, 0.4, 0.7)
## What the enemy team looks like to you (the bots' red), in the standard scheme.
## Read [method enemy_color] for what is on screen now.
const ENEMY_COLOR := Color(0.72, 0.22, 0.18)

## The colour schemes (Settings → Video → Team colours, D-210). STANDARD is blue against red;
## COLORBLIND is blue against orange, picked so the pair stays apart for protan, deutan and
## tritan eyes and in greyscale (the blue is dark, the orange light).
enum ColorScheme { STANDARD, COLORBLIND }

## The setting's names for the schemes, in [enum ColorScheme] order (what the file stores).
const SCHEME_NAMES: Array[String] = ["standard", "colorblind"]

## Every colour of a team that depends on the scheme, per scheme and per role: "friendly" and
## "enemy" are the 3D world's (clothes, arms), "*_text" are the UI's text and icon tints on a dark
## panel, "*_fill" its dark fills. The STANDARD UI colours are tools/ui_palette.gd's FRIENDLY, ENEMY
## and their fills (tools aren't exported, so they are repeated here; the ui suite checks they agree).
const SCHEMES: Array[Dictionary] = [
	{
		&"friendly": FRIENDLY_COLOR, &"enemy": ENEMY_COLOR,
		&"friendly_text": Color("5a94ff"), &"enemy_text": Color("ff4d3d"),
		&"friendly_fill": Color("1f4a9e"), &"enemy_fill": Color("8f2216"),
	},
	{
		&"friendly": Color(0.10, 0.36, 0.76), &"enemy": Color(0.97, 0.55, 0.10),
		&"friendly_text": Color("66b3ff"), &"enemy_text": Color("ff7a1a"),
		&"friendly_fill": Color("0a3d6b"), &"enemy_fill": Color("b86a00"),
	},
]

## Group of the spawn markers at the attackers' end of a map.
const ATTACK_SPAWN_GROUP := "attack_spawns"
## Group of the spawn markers at the defenders' end of a map.
const DEFEND_SPAWN_GROUP := "defend_spawns"

## How much [method text_color_for] lightens a team color so text stays readable on a dark panel.
const TEXT_LIGHTEN := 0.35

## The share of damage a teammate takes when friendly fire is on (CS competitive: a third).
const FRIENDLY_FIRE_DAMAGE := 1.0 / 3.0

## Whether teammates can hurt each other (a match setting, console: mp_friendlyfire).
## Off by default; bullets then pass through teammates (see [Weapon]).
static var friendly_fire: bool = false

## The team of the person at this computer. Their team is drawn blue and the
## other one red. Change it with [method set_viewer_team].
static var viewer_team: int = 0

## The scheme on screen, a [enum ColorScheme] value. Change it with [method set_color_scheme]
## (the shared [Settings] does when the player picks one).
static var color_scheme: int = ColorScheme.STANDARD


## The name of the group holding the spawn markers of [param side] (a [enum Side] value).
## The parameter is an int because GDScript can mistake [code]Teams.Side[/code]
## from another script for a different type while Teams and Character load each other.
static func spawn_group(side: int) -> String:
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


## Switches the colour scheme and recolours every character already in the world.
## [method UiTheme.set_team_scheme] does the same for the UI's theme; the shared [Settings] calls both.
static func set_color_scheme(scheme: int) -> void:
	color_scheme = clampi(scheme, 0, SCHEMES.size() - 1)
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	for node in tree.get_nodes_in_group("characters"):
		(node as Character).update_team_color()


## The colour [param role] ("friendly", "enemy", "friendly_text"...) has in
## [param scheme], or the current scheme when none is given.
static func scheme_color(role: StringName, scheme: int = -1) -> Color:
	return SCHEMES[color_scheme if scheme < 0 else scheme][role]


## The 3D colour of your own team now.
static func friendly_color() -> Color:
	return SCHEMES[color_scheme][&"friendly"]


## The 3D colour of the enemy team now.
static func enemy_color() -> Color:
	return SCHEMES[color_scheme][&"enemy"]


## The UI colour of [param team] now: [param role] is "text" (names, icons, score numbers on a
## dark panel) or "fill" (a bar or pip's body). Friendly for the viewer's team, enemy for the other.
static func ui_color_for(team: int, role: StringName = &"text") -> Color:
	var side := &"friendly_" if team == viewer_team else &"enemy_"
	return SCHEMES[color_scheme][StringName(String(side) + String(role))]


## The opposing team of [param team].
static func other(team: int) -> int:
	return 1 - team


## The clothes color of [param team] as seen by the viewer: blue for the
## viewer's own team, red (orange in the colour-blind scheme) for the other one.
static func color_for(team: int) -> Color:
	return friendly_color() if team == viewer_team else enemy_color()


## [method color_for] lightened by [constant TEXT_LIGHTEN]: the color for names
## and messages (kill feed, round HUD) drawn on a dark background.
static func text_color_for(team: int) -> Color:
	return color_for(team).lightened(TEXT_LIGHTEN)


## How much of an attack's damage reaches [param victim]: 1.0 for enemies, for
## yourself and for damage without an attacker. A teammate takes
## [constant FRIENDLY_FIRE_DAMAGE] if [member friendly_fire] is on, otherwise nothing.
static func damage_factor(victim: Character, attacker: Character) -> float:
	if attacker == null or attacker == victim or attacker.team != victim.team:
		return 1.0
	return FRIENDLY_FIRE_DAMAGE if friendly_fire else 0.0
