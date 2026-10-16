class_name Shop
extends RefCounted
## What can be bought, and how a purchase is handed over (M7 task 11, D-098). The buy menu shows
## [method items]; the rules decide (when, and whether the money is there:
## [method RoundManager.request_buy], [method ArenaRules.request_buy]) and call [method give].
## A static class, like [Teams]: no node, no autoload.
##
## Items are the arsenal's weapons by their ids (rifle, carbine, pistol, frag...) plus the gear:
## [constant VEST], [constant VEST_HELMET] and [constant KIT].

## The buy menu's categories, in order (keys 1 to 5).
enum Category { PISTOLS, MID_TIER, RIFLES, GEAR, GRENADES }

const VEST := &"vest"
const VEST_HELMET := &"vest_helmet"
const KIT := &"kit"
## Gear prices (D-090): a vest $500, a vest and a helmet $800 (just the helmet when you have a
## vest: the difference), a defuse kit $300 (defenders only).
const VEST_PRICE := 500
const VEST_HELMET_PRICE := 800
const KIT_PRICE := 300
const CATEGORY_NAMES: Array[String] = ["Pistols", "Mid-tier", "Rifles", "Gear", "Grenades"]


## Every item for sale, in menu order: [code]{id, name, price, category, icon, data}[/code]
## ([code]data[/code] is the [WeaponData], null for gear).
static func items() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for data in WeaponData.all():
		if data.price <= 0:
			continue
		out.append({"id": data.id, "name": data.display_name, "price": data.price, "category": category_of(data),
				"icon": data.icon, "data": data})
	out.append({"id": VEST, "name": "Vest", "price": VEST_PRICE, "category": Category.GEAR,
			"icon": load("res://assets/ui/weapons/armor.png"), "data": null})
	out.append({"id": VEST_HELMET, "name": "Vest + helmet", "price": VEST_HELMET_PRICE, "category": Category.GEAR,
			"icon": load("res://assets/ui/weapons/armor_helmet.png"), "data": null})
	out.append({"id": KIT, "name": "Defuse kit", "price": KIT_PRICE, "category": Category.GEAR,
			"icon": load("res://assets/ui/weapons/defuse_kit.png"), "data": null})
	return out


## The item with [param id], or an empty dictionary.
static func find(id: StringName) -> Dictionary:
	for item in items():
		if item.id == id:
			return item
	return {}


## The buy-menu category of a weapon.
static func category_of(data: WeaponData) -> Category:
	match data.category:
		WeaponData.Category.PISTOL:
			return Category.PISTOLS
		WeaponData.Category.SMG, WeaponData.Category.SHOTGUN:
			return Category.MID_TIER
		WeaponData.Category.GRENADE:
			return Category.GRENADES
	return Category.RIFLES


## What [param item_id] costs [param character] now: the helmet alone when it wears a vest.
static func price_for(character: Character, item_id: StringName) -> int:
	var item := find(item_id)
	if item.is_empty():
		return 0
	if item_id == VEST_HELMET and character.armor > 0.0 and not character.has_helmet:
		return VEST_HELMET_PRICE - VEST_PRICE
	return item.price


## Why [param character] can't have [param item_id], or "" if it can (money and time aside):
## it already has it, there's no room for another grenade of that kind, a kit on the attacking
## side ([param defending] false) or without a bomb.
static func refusal(character: Character, item_id: StringName, defending: bool = true, has_bomb: bool = true) -> String:
	var item := find(item_id)
	if item.is_empty():
		return "There's no such thing"
	if not character.is_alive():
		return "You're dead"
	match item_id:
		VEST:
			if character.armor >= Armor.MAX_ARMOR:
				return "You have a vest"
			return ""
		VEST_HELMET:
			if character.armor >= Armor.MAX_ARMOR and character.has_helmet:
				return "You have a vest and a helmet"
			return ""
		KIT:
			if not has_bomb:
				return "No bomb on this map"
			if not defending:
				return "Only defenders need a kit"
			if character.has_defuse_kit:
				return "You have a kit"
			return ""
	var data: WeaponData = item.data
	var carried := character.inventory.find(data)
	if data.is_grenade():
		return "" if character.inventory.can_take(data) else "You can't carry more"
	if carried != null:
		return "You have it"
	return ""


## Hands [param item_id] to [param character] (no money involved): a weapon goes into its slot
## and comes out (the one it replaces drops to the floor, as in CS), gear goes on.
static func give(character: Character, item_id: StringName) -> void:
	var item := find(item_id)
	match item_id:
		VEST:
			character.set_armor(Armor.MAX_ARMOR, character.has_helmet)
			return
		VEST_HELMET:
			character.set_armor(Armor.MAX_ARMOR, true)
			return
		KIT:
			character.set_defuse_kit(true)
			return
	var data: WeaponData = item.data
	var inventory := character.inventory
	if not data.is_grenade():
		var old := inventory.get_in_slot(data.slot)
		if old != null:
			inventory.drop(old)
	var weapon := inventory.give(data)
	if weapon != null and not data.is_grenade():
		inventory.hold(weapon)
