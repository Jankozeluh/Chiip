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
