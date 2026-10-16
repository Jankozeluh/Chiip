class_name Inventory
extends Node
## The weapons a [Character] carries (M7, D-094): one gun per slot (primary and pistol), the
## knife, and grenades (one node per kind, whose "magazine" is how many you carry). The character
## holds one of them at a time: [member Character.weapon]. A child node of the character, the way
## Godot composes behaviour (Unity would add a component).
##
## Everything here follows the character's per-tick [CharacterInput] ([method handle_input]):
## keys 1 to 4 pick a slot (4 again cycles the grenades), Q the last weapon, G drops the gun in
## hand, and a press of Use (E) while looking at a gun on the floor swaps it for the one in that
## slot. Walking over a gun takes it when its slot is free ([method update_pickups]). So bots and,
## in M9, network players follow the same rules as you. Switching takes the new weapon's draw
## time before it can fire (shorter for the Rifleman: [member ClassData.weapon_switch_time_factor]).
##
## The weapons hang under one node, the holder: the camera for the player (they show as its
## first-person viewmodel) and the head for bots. Weapons you aren't holding are hidden and don't
## process. The game rules hand out loadouts with [method set_loadout] (D-090: a fresh one every
## round). This is authority code: in M9 the host decides what a player carries.

## Emitted when what the character carries changes: a weapon given, taken, dropped or used up,
## or a new loadout. The HUD's slot list listens.
signal changed

## At most this many grenades in all (CS: 4).
const MAX_GRENADES := 4
## How close (metres, along the floor) your feet must come to a gun on the floor to take it, and
## how far above or below them it may be.
const PICKUP_REACH := 0.9
const PICKUP_HEIGHT := 1.3
## How far Use reaches to swap for a gun on the floor (metres from the eyes) and how far off the
## view it may be (degrees).
const SWAP_REACH := 2.4
const SWAP_ANGLE := 20.0
## Where a dropped gun leaves your hands: in front of the eyes and below them (metres).
const DROP_FORWARD := 0.6
const DROP_BELOW := 0.4

var _character: Character
## The node the weapons hang under.
var _holder: Node3D
## Every weapon carried, in the order they came.
var _weapons: Array[Weapon] = []
## The weapon held before the current one (Q switches back to it).
var _last: Weapon
## Whether the held weapon shows its first-person viewmodel (see [method Character.set_first_person]).
var _first_person: bool = false
## Use was held last tick (a swap needs a fresh press).
var _use_was_held: bool = false


## Ties the inventory to [param character]; [param starting] is the weapon its scene already
## holds (or null), and the weapons hang where that one does (or under [param fallback_holder]).
## [Character] calls it once, in its _ready.
func set_up(character: Character, starting: Weapon, fallback_holder: Node3D) -> void:
	_character = character
	_holder = starting.get_parent() as Node3D if starting != null else fallback_holder
	if starting != null:
		_weapons.append(starting)
		starting.equip(character)


## Every weapon carried, in the order they came.
func get_weapons() -> Array[Weapon]:
	return _weapons.duplicate()


## The weapon in [param slot] ([enum WeaponData.Slot]); for grenades the first one. Null if empty.
func get_in_slot(slot: int) -> Weapon:
	for weapon in _weapons:
		if weapon.data.slot == slot:
			return weapon
	return null


## The grenades carried, one weapon per kind (its magazine is how many).
func get_grenades() -> Array[Weapon]:
	return _weapons.filter(func(weapon: Weapon) -> bool: return weapon.data.is_grenade())


## How many grenades are carried in all.
func get_grenade_count() -> int:
	var count := 0
	for weapon in get_grenades():
		count += weapon.magazine
	return count


## The carried weapon made from [param data] (compared by id), or null.
func find(data: WeaponData) -> Weapon:
	for weapon in _weapons:
		if weapon.data.id == data.id:
			return weapon
	return null


## True if [param data] fits: its slot is free, or for a grenade, fewer than its
## [member WeaponData.max_carried] of that kind and fewer than [constant MAX_GRENADES] in all.
func can_take(data: WeaponData) -> bool:
	if data.is_grenade():
		var carried := find(data)
		var count := carried.magazine if carried != null else 0
		return count < data.max_carried and get_grenade_count() < MAX_GRENADES
	return get_in_slot(data.slot) == null


## Adds a weapon made from [param data], with [param mag] rounds in the magazine and [param spare]
## in reserve (-1: full). A grenade of a kind already carried adds one to it. Returns the weapon,
## or null when it doesn't fit ([method can_take]). With nothing in hand, it's taken out at once.
func give(data: WeaponData, mag: int = -1, spare: int = -1) -> Weapon:
	if data == null or not can_take(data):
		return null
	if data.is_grenade():
		var carried := find(data)
		if carried != null:
			carried.magazine += 1
			carried.ammo_changed.emit(carried.magazine, carried.reserve)
			changed.emit()
			return carried
	var weapon := Weapon.create(data)
	weapon.visible = false
	_holder.add_child(weapon)
	if mag >= 0 and not data.is_grenade():
		weapon.magazine = mag
	if spare >= 0:
		weapon.reserve = spare
	weapon.equip(_character)
	weapon.set_viewmodel_visible(false)
	weapon.process_mode = Node.PROCESS_MODE_DISABLED
	_character.set_up_arms_for(weapon)
	weapon.set_arms_team_color(Teams.color_for(_character.team))
	_weapons.append(weapon)
	changed.emit()
	if _character.weapon == null:
		hold(weapon, true)
	return weapon


## Takes [param weapon] out of the inventory and frees it (a grenade kind used up, a gun dropped).
## If it was in hand, the best weapon left is taken out (with its draw time), or with
## [param back_to_last] the one held before it (after throwing the last grenade, as in CS).
func remove(weapon: Weapon, back_to_last: bool = false) -> void:
	if weapon == null or not _weapons.has(weapon):
		return
	var was_held := weapon == _character.weapon
	_weapons.erase(weapon)
	if _last == weapon:
		_last = null
	if was_held:
		weapon.holster()
		_character.weapon = null
	weapon.get_parent().remove_child(weapon)
	weapon.queue_free()
	changed.emit()
	if was_held:
		hold(_last if back_to_last and _last != null and _weapons.has(_last) else get_best())


## Empties the inventory: nothing in hand.
func clear() -> void:
	var held := _character.weapon
	for weapon in _weapons:
		weapon.holster()
		weapon.get_parent().remove_child(weapon)
		weapon.queue_free()
	_weapons.clear()
	_last = null
	_character.weapon = null
	if held != null:
		_character.weapon_changed.emit(null)
	changed.emit()


## Replaces everything with [param loadout] (full ammo) and takes out the best of it at once (a
## round start or a spawn: no draw time). The fresh loadout of every round (D-090) comes this way.
func set_loadout(loadout: Array[WeaponData]) -> void:
	clear()
	for data in loadout:
		give(data)
	if _character.weapon == null or _character.weapon != get_best():
		hold(get_best(), true)


## The weapon to have in hand when nothing else is chosen: the primary, else the pistol, else the
## knife, else a grenade.
func get_best() -> Weapon:
	for slot in [WeaponData.Slot.PRIMARY, WeaponData.Slot.PISTOL, WeaponData.Slot.KNIFE, WeaponData.Slot.GRENADE]:
		var weapon := get_in_slot(slot)
		if weapon != null:
			return weapon
	return null


## Takes [param weapon] out: the one in hand is put away (its reload is lost), and the new one
## can't fire for its draw time, unless [param instant]. Emits [signal Character.weapon_changed].
func hold(weapon: Weapon, instant: bool = false) -> void:
	var old := _character.weapon
	if weapon == old:
		return
	if old != null and is_instance_valid(old):
		old.holster()
		old.visible = false
		old.set_viewmodel_visible(false)
		old.process_mode = Node.PROCESS_MODE_DISABLED
		if _weapons.has(old):
			_last = old
	_character.weapon = weapon
	if weapon != null:
		weapon.process_mode = Node.PROCESS_MODE_INHERIT
		weapon.visible = _character.is_alive()
		weapon.set_viewmodel_visible(_first_person)
		weapon.draw(0.0 if instant else get_draw_time(weapon.data))
	_character.weapon_changed.emit(weapon)
	changed.emit()


## Seconds [param data] takes to draw for this character: its draw time, shorter for the
## Rifleman's Quick Hands.
func get_draw_time(data: WeaponData) -> float:
	var factor := _character.class_data.weapon_switch_time_factor if _character.class_data != null else 1.0
	return data.draw_time * factor


## Takes out the weapon in [param slot] (keys 1 to 4). The grenade slot cycles through the kinds
## carried when a grenade is already in hand.
func select_slot(slot: int) -> void:
	var target: Weapon = null
	if slot == WeaponData.Slot.GRENADE:
		var grenades := get_grenades()
		if grenades.is_empty():
			return
		var at := grenades.find(_character.weapon)
		target = grenades[(at + 1) % grenades.size()]
	else:
		target = get_in_slot(slot)
	if target != null:
		hold(target)


## Takes out the weapon held before this one (Q), if it is still carried.
func select_last() -> void:
	if _last != null and _weapons.has(_last):
		hold(_last)


## Drops [param weapon] (a primary or a pistol: the knife and grenades can't be dropped) in front
## of the character, with its ammo, and takes out the best weapon left. Returns the gun on the
## floor, or null.
func drop(weapon: Weapon) -> WeaponPickup:
	if weapon == null or not _weapons.has(weapon):
		return null
	if weapon.data.slot != WeaponData.Slot.PRIMARY and weapon.data.slot != WeaponData.Slot.PISTOL:
		return null
	var forward := -_character.global_basis.z
	var at := _character.get_eye_position() + forward * DROP_FORWARD + Vector3.DOWN * DROP_BELOW
	var pickup := WeaponPickup.spawn(_character.get_parent(), weapon.data, weapon.magazine, weapon.reserve, at,
			_character.global_rotation.y, _character)
	remove(weapon)
	return pickup


## What a dying character leaves behind (D-090): its best gun, the primary, else the pistol.
## Grenades and the rest are lost with it.
func drop_on_death() -> WeaponPickup:
	if not _character.is_inside_tree():
		return null
	var best := get_in_slot(WeaponData.Slot.PRIMARY)
	if best == null:
		best = get_in_slot(WeaponData.Slot.PISTOL)
	return drop(best)


## Shows or hides the held weapon's first-person viewmodel, now and for every weapon taken out
## later. [method Character.set_first_person] calls it.
func set_first_person(on: bool) -> void:
	_first_person = on
	if _character.weapon != null:
		_character.weapon.set_viewmodel_visible(on)


## Refills every gun (on respawn: full magazine and reserve, as in CS:GO).
func refill() -> void:
	for weapon in _weapons:
		weapon.refill()


## Follows this tick's command: a slot key, Q, G, and a fresh press of Use for a swap.
func handle_input(input: CharacterInput) -> void:
	if input.weapon_slot >= 0:
		select_slot(input.weapon_slot)
	elif input.last_weapon:
		select_last()
	if input.drop:
		drop(_character.weapon)
	var use_pressed := input.use and not _use_was_held
	_use_was_held = input.use
	if use_pressed:
		try_swap()


## Takes every gun on the floor the character's feet touch whose slot is free (walking over a
## gun picks it up, as in CS). It doesn't take it out: that's still your choice.
func update_pickups() -> void:
	for node in get_tree().get_nodes_in_group(WeaponPickup.GROUP):
		var pickup := node as WeaponPickup
		if pickup == null or pickup.is_queued_for_deletion() or not pickup.can_be_taken_by(_character):
			continue
		if not can_take(pickup.data):
			continue
		var offset := pickup.global_position - _character.global_position
		if Vector2(offset.x, offset.z).length() <= PICKUP_REACH and offset.y > -0.5 and offset.y < PICKUP_HEIGHT:
			take(pickup)


## Takes [param pickup] off the floor into its slot (with its ammo) and frees it. Returns the
## weapon, or null when it doesn't fit.
func take(pickup: WeaponPickup) -> Weapon:
	var weapon := give(pickup.data, pickup.magazine, pickup.reserve)
	if weapon == null:
		return null
	pickup.remove_from_group(WeaponPickup.GROUP)
	if pickup.spot != null and pickup.spot.has_method("on_taken"):
		pickup.spot.on_taken(_character)
	pickup.queue_free()
	return weapon


## The gun on the floor the character looks at within reach (see [constant SWAP_REACH] and
## [constant SWAP_ANGLE]), the closest to the line of sight; null if none.
func get_looked_at_pickup() -> WeaponPickup:
	var eye := _character.get_eye_position()
	var aim := _character.get_aim_angles()
	var look := -Basis.from_euler(Vector3(aim.y, aim.x, 0.0)).z
	var best: WeaponPickup = null
	var best_angle := SWAP_ANGLE
	for node in get_tree().get_nodes_in_group(WeaponPickup.GROUP):
		var pickup := node as WeaponPickup
		if pickup == null or pickup.is_queued_for_deletion() or not pickup.can_be_taken_by(_character):
			continue
		var to := pickup.get_center() - eye
		if to.length() > SWAP_REACH:
			continue
		var angle := rad_to_deg(look.angle_to(to))
		if angle <= best_angle:
			best = pickup
			best_angle = angle
	return best


## Use pressed while looking at a gun on the floor: takes it, dropping the gun in that slot if
## there is one (Call of Duty's swap), and takes it out. Returns true if something was taken.
func try_swap() -> bool:
	var pickup := get_looked_at_pickup()
	if pickup == null:
		return false
	if not can_take(pickup.data):
		if pickup.data.is_grenade():
			return false
		drop(get_in_slot(pickup.data.slot))
	var weapon := take(pickup)
	if weapon == null:
		return false
	hold(weapon)
	return true
