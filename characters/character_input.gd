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
## Use is held: plants the bomb in a bomb site, or defuses a planted bomb (D-080). A fresh press
## while looking at a gun on the floor swaps it for the one in that slot (D-094).
var use: bool = false
## Aim (the right mouse button) is held: the sniper rifle's scope, the knife's stab, a grenade's lob.
var aim: bool = false
## A weapon slot was picked this tick ([enum WeaponData.Slot]: keys 1 to 4), or -1.
var weapon_slot: int = -1
## Switch back to the weapon held before (Q) was pressed this tick.
var last_weapon: bool = false
## Drop the gun in hand (G) was pressed this tick.
var drop: bool = false
