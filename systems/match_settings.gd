class_name MatchSettings
extends Resource
## The rules of one match: team sizes, bot skill, match length, friendly fire
## and the round timings. Match setup (M5) fills one in; the [RoundManager]
## plays by it. The defaults are D-041's: 3v3, Normal bots, first to 5,
## friendly fire off, 5 s freeze time.

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
## move or shoot. CS: 15 s with buying; 5 s until there's something to buy (M7).
@export var freeze_time: float = 5.0
## Seconds a live round lasts. When it runs out, the defending side wins. CS: 1:55.
@export var round_time: float = 115.0
## Seconds between a round's result and the next round's freeze time.
@export var round_end_time: float = 5.0
