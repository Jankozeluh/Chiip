class_name CharacterInput
extends RefCounted
## One physics tick of commands for a [Character]: which way to move, where to
## look, and which buttons are down. The same idea as the "usercmd" a CS client
## sends every tick.
##
## Whatever drives a character (the player's keyboard and mouse, a bot's brain,
## later a network connection) produces one of these per tick, and the
## character simulates it the same way.

## Movement keys as a direction relative to where the character faces:
## x is right (+) or left (−), y is back (+) or forward (−). Length up to 1.
var move: Vector2 = Vector2.ZERO
## Where to look horizontally, in radians (0 = facing −Z, positive turns left).
var yaw: float = 0.0
## Where to look vertically, in radians (positive is up).
var pitch: float = 0.0
## Jump was pressed this tick. Holding it doesn't jump again, as in CS.
var jump: bool = false
## Crouch is held.
var crouch: bool = false
## Walk (slower and silent) is held.
var walk: bool = false
## Fire is held.
var shoot: bool = false
## Reload was pressed this tick.
var reload: bool = false
## Use is held: plants the bomb in a bomb site, or defuses a planted bomb (D-080).
var use: bool = false
## Online (M9, D-103): the command's number, counted up by the player's computer from 1. The
## host runs each number once and in order, tells the client the last one it ran, and seeds
## the shot spread from it. 0 for commands that never travel (bots, single-player).
var tick: int = 0
## Online (M9, D-107): the host tick the player's screen showed the other characters at when
## this command was made (between two snapshots, so it has a fraction). The host checks the
## command's shots against the hit zones as they were then.
var view_tick: float = 0.0


## A copy of this command.
func copy() -> CharacterInput:
	var other := CharacterInput.new()
	other.move = move
	other.yaw = yaw
	other.pitch = pitch
	other.jump = jump
	other.crouch = crouch
	other.walk = walk
	other.shoot = shoot
	other.reload = reload
	other.use = use
	other.tick = tick
	other.view_tick = view_tick
	return other
