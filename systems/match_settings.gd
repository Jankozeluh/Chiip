class_name MatchSettings
extends Resource
## The rules of one match: team sizes, bot skill, match length, friendly fire
## and the round timings. Match setup (M5) fills one in; the [RoundManager]
## plays by it. The defaults are D-041's: 3v3, Normal bots, first to 5,
## friendly fire off, 5 s freeze time.

## How the match is played (D-049).
enum GameMode {
	## Rounds with one life each (CS, or CoD's Search & Destroy), bomb rounds on
	## maps with bomb sites. A [RoundManager].
	ROUNDS,
	## Like CoD's Team Deathmatch: respawn after a few seconds, first team to the
	## kill limit wins. A [RespawnMatch].
	TEAM_RESPAWN,
}

## Rounds or team respawn.
@export var game_mode: GameMode = GameMode.ROUNDS

@export_group("Teams")
## Players on your team, you included (1–5).
@export_range(1, 5) var team_size: int = 3
## Bots on the enemy team (1–5).
@export_range(1, 5) var enemy_team_size: int = 3
## How well every bot in the match fights, teammates included.
@export var bot_difficulty: BotDifficulty = preload("res://bots/difficulty_normal.tres")

@export_group("Rules")
## Rounds a team must win to win the match: 5, 10 or 15.
@export var rounds_to_win: int = 5
## When on, teammates take a third of the damage; when off, none, and bullets
## pass through them (D-042).
@export var friendly_fire: bool = false

@export_group("Timing")
## Seconds at the start of each round when everyone can look around but not
## move or shoot, and buy (D-098). CS: 15 s with buying (5 s until M7 brought the buy menu).
## Team respawn keeps 5 s.
@export var freeze_time: float = 15.0
## Seconds a live round lasts. When it runs out, the defending side wins. CS: 1:55.
@export var round_time: float = 115.0
## Seconds between a round's result and the next round's freeze time.
@export var round_end_time: float = 5.0

@export_group("Bomb")
## Play bomb rounds on maps with bomb sites (D-080): one attacker carries the
## bomb, a plant stops the round clock, and the round can also end with the
## bomb exploding or being defused. Off, or on a map without bomb sites,
## rounds are won by elimination and time only.
@export var bomb_rounds: bool = true
## Seconds a planted bomb ticks before it explodes. CS: 40.
@export var bomb_fuse_time: float = 40.0
## Seconds of holding Use inside a bomb site to plant. CS: 3.2.
@export var plant_time: float = 3.2
## Seconds of holding Use next to the planted bomb to defuse it without a kit. CS: 10.
@export var defuse_time: float = 10.0
## Seconds to defuse with a defuse kit (bought from M7 on). CS: 5.
@export var kit_defuse_time: float = 5.0

@export_group("Team respawn")
## Kills a team needs to win a team respawn match (D-082, D-083). CoD: 75 at
## 6v6. 50 takes bots-only 3v3 matches about 4 minutes.
@export var kill_limit: int = 50
## Seconds a team respawn match lasts; then the team with more kills wins (a
## tie goes to overtime: the next kill wins). CoD: 10 minutes.
@export var time_limit: float = 600.0
## Seconds from dying to coming back in a team respawn match.
@export var respawn_delay: float = 3.0

@export_group("Player")
## The class the player starts the match with. Null keeps the class of the map's [code]Player[/code]
## character (the Rifleman); the class menu changes it during freeze time (D-052, D-078).
@export var player_class: ClassData

@export_group("Loadout")
## What everyone has at the start of every round (D-090: a fresh loadout every round, like CoD's
## Search & Destroy): the knife and the Sparrow. Whatever is bought or picked up lasts one round.
## Team respawn uses each class's own loadout instead ([member ClassData.loadout]).
@export var round_loadout: Array[WeaponData] = [preload("res://weapons/knife.tres"), preload("res://weapons/pistol.tres")]

@export_group("Economy")
## Money in rounds (D-090, D-098): earned by winning, losing, killing and the bomb, carried over
## between rounds and spent in the buy menu. Off: no money at all (the team respawn mode has none).
@export var economy: bool = true
## Money at the start of each half, and the most anyone can have.
@export var start_money: int = 1000
@export var max_money: int = 10000
## For winning a round.
@export var win_money: int = 3000
## For losing a round: the first number for a first loss, the next for each loss in a row after
## it; the last one repeats. A win starts the count again.
@export var loss_money: PackedInt32Array = PackedInt32Array([1500, 2000, 2500, 3000])
## Taken away for killing a teammate.
@export var teamkill_penalty: int = 200
## For every attacker when the bomb is planted, and for the defender who defuses it.
@export var plant_money: int = 200
@export var defuse_money: int = 200
## The bots shop at the start of each round by their money (D-099). Tests of the money rules turn
## it off, so only what they do changes the numbers.
@export var bots_buy: bool = true
