class_name HitCheck
extends Node
## A self-check of shooting that runs in the real game, also in an exported release build (v0.1.1
## hotfix, D-159): [code]Chiip --headless -- --check-hits[/code] starts practice on the Shooting
## Range, puts an enemy bot 5 m in front of the player, and fires one shot each way. It prints
## [code]Chiip hit check: PASS[/code] or [code]FAIL[/code] with the hits and quits with exit code 0
## or 1. Exported builds don't run [code]--script[/code], so this is how a build is checked
## (tools/check_export.sh). [code]main.gd[/code] adds it for the flag.

## Emitted with the result, before quitting (if [member quit_when_done]).
signal finished(passed: bool, detail: String)

## The flag that asks for it.
const FLAG := "--check-hits"
## Physics ticks to wait before each step (the map, the bot's spawn, the bodies' poses).
const SETTLE_TICKS := 20
## Both shoot the Ram: a known gun, accurate standing still (a bot may hold the Heron unscoped).
const GUN := preload("res://weapons/rifle.tres")

## Quit the game with the result as the exit code (off in tests/release_test.gd, which runs it too).
var quit_when_done: bool = true


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	Weapon.silent = true
	await _ticks(SETTLE_TICKS)
	var main := get_parent() as Main
	var map := main.get_map() as Node3D
	var player := map.get_node_or_null("Player") as Character if map != null else null
	if player == null:
		_finish(false, "no player")
		return
	(main.get_node("DevConsole") as DevConsole).run("bot_add normal enemy")
	await _ticks(5)
	var bot: Character = null
	for other in Character.all_in_world(player):
		if not Teams.are_allies(other, player):
			bot = other
	if bot == null:
		_finish(false, "no enemy bot")
		return
	# Nobody moves or shoots on their own meanwhile (as in freeze time), so only the two test shots count.
	player.frozen = true
	bot.frozen = true
	bot.respawn(player.global_position - player.global_basis.z * 5.0, player.rotation.y + PI)
	for shooter: Character in [player, bot]:
		shooter.inventory.set_loadout([GUN] as Array[WeaponData])
	await _ticks(SETTLE_TICKS)
	for i in 300:
		if not player.weapon.is_drawing() and not bot.weapon.is_drawing():
			break
		await get_tree().physics_frame
	var to_bot := _shoot(player, bot)
	var to_player := _shoot(bot, player)
	player.frozen = false
	bot.frozen = false
	_finish(to_bot.damage > 0.0 and to_player.damage > 0.0,
			"player → bot %s, bot → player %s" % [to_bot, to_player])


## One shot from [param shooter] at [param target]'s chest: what it hit and the health it took.
func _shoot(shooter: Character, target: Character) -> Dictionary:
	shooter.aim_at(target.get_chest_position())
	var before := target.health
	var weapon := shooter.weapon
	weapon.last_hit = {}
	weapon.rng.seed = 1
	# Straight through the weapon's own firing (cooldown, ammo, the ray), as a held trigger would.
	weapon._cooldown = 0.0
	weapon._try_fire()
	return {"zone": weapon.last_hit.get("zone", "nothing"), "damage": before - target.health}


func _finish(passed: bool, detail: String) -> void:
	print("Chiip hit check: %s (%s)" % ["PASS" if passed else "FAIL", detail])
	finished.emit(passed, detail)
	if quit_when_done:
		get_tree().quit(0 if passed else 1)


func _ticks(count: int) -> void:
	for i in count:
		await get_tree().physics_frame
