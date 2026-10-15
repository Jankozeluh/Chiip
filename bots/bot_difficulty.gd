class_name BotDifficulty
extends Resource
## How well a bot fights: reaction time, aim, recoil control and shooting
## habits. Saved as data files (bots/difficulty_*.tres) so difficulty can be
## tuned in the Inspector without touching code.

## Name shown in the console, e.g. "normal".
@export var display_name: String = "normal"

@export_group("Reaction")
## Seconds between first seeing an enemy and the first shot. Humans: about 0.2–0.4.
@export var reaction_time: float = 0.3

@export_group("Aim")
## How fast the bot can turn its view while fighting, in degrees per second.
@export var aim_turn_speed: float = 300.0
## How far off the aim is when the bot first spots an enemy, in degrees.
@export var initial_aim_error: float = 4.0
## Seconds for that error to shrink to about a third (it keeps shrinking after).
@export var aim_settle_time: float = 0.6
## The smallest error the bot ever reaches, in degrees (shaky hands).
@export var minimum_aim_error: float = 0.6
## Chance of aiming at the head instead of the chest (0–1).
@export_range(0.0, 1.0) var headshot_chance: float = 0.3

@export_group("Shooting")
## How much of the spray pattern the bot pulls against (0 = none, 1 = perfect).
@export_range(0.0, 1.0) var recoil_control: float = 0.55
## Stops by tapping the opposite key (counter-strafing) instead of just letting go.
@export var counter_strafes: bool = true
## Beyond this distance (metres) the bot shoots short bursts instead of spraying.
@export var burst_distance: float = 15.0
## Shots per burst at long range.
@export var burst_length: int = 2
## Shots per spray at close range.
@export var spray_length: int = 10
## Pause between bursts or sprays, in seconds, so recoil can wear off.
@export var burst_pause: float = 0.35
