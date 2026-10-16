class_name BotBuyer
extends RefCounted
## How bots spend their money at the start of a round (M7 task 14, D-099), like a CS team: the
## team decides together whether this is a pistol round, a full buy, a force buy or a save (eco),
## then each bot buys by its class's taste. Every purchase goes through
## [method RoundManager.request_buy], the same rule as yours. A static class (no node).
##
## The team's call, in this order:
## - [b]pistol round[/b] (the first round of each half, everyone has $1,000): each class has its
##   own small buy (the Scout a Hornet, the others a vest and a grenade or the Verdict);
## - [b]full buy[/b] when the team averages at least [constant FULL_BUY] (a rifle, vest and helmet,
##   a grenade);
## - [b]force buy[/b] when the round must be won (either team on match point, the last round of a
##   half) or the team averages [constant FORCE_BUY]: the cheap guns and a vest;
## - otherwise [b]save[/b]: nothing, so next round is a full buy.

enum Plan { PISTOL, FULL, FORCE, ECO }

## Average team money for a full buy (a rifle + vest and helmet + a grenade is $3,600).
const FULL_BUY := 3300
## Average team money for a force buy without a reason to force.
const FORCE_BUY := 2400
## Defenders that buy a defuse kit, at most, per team.
const KITS_PER_TEAM := 2
## Each class's guns, best first, by plan: what it buys when it can afford it. Ids from [Shop].
const FULL_GUNS := {
	&"rifleman": [&"rifle", &"carbine"],
	&"bulwark": [&"rifle", &"shotgun"],
	&"marksman": [&"sniper", &"carbine", &"rifle"],
	&"scout": [&"carbine", &"rifle", &"smg"],
}
const FORCE_GUNS := {
	&"rifleman": [&"smg", &"hand_cannon"],
	&"bulwark": [&"shotgun", &"hand_cannon"],
	&"marksman": [&"hand_cannon", &"smg"],
	&"scout": [&"smg", &"shotgun"],
}
## The grenades each class likes, in order (bots throw frags and flashbangs; smoke they leave).
const GRENADES := {
	&"rifleman": [&"frag", &"flashbang"],
	&"bulwark": [&"flashbang", &"frag"],
	&"marksman": [&"frag", &"flashbang"],
	&"scout": [&"flashbang", &"flashbang", &"frag"],
}
## The Heron is only bought with this much money (it and a vest and helmet).
const SNIPER_MONEY := 4800


## The team's call for this round (see the class description).
static func plan_for(rules: RoundManager, team: int) -> Plan:
	var settings := rules.settings
	var round_number := rules.round_number
	if round_number == 1 or round_number == settings.rounds_to_win:
		return Plan.PISTOL
	var members := rules.get_members(team)
	var total := 0
	for member in members:
		total += rules.get_money(member)
	var average := total / maxi(members.size(), 1)
	if average >= FULL_BUY:
		return Plan.FULL
	var match_point := rules.score.any(func(won: int) -> bool: return won == settings.rounds_to_win - 1)
	var last_of_half := round_number == settings.rounds_to_win - 1
	if match_point or last_of_half or average >= FORCE_BUY:
		return Plan.FORCE
	return Plan.ECO


## Every bot of [param team] shops for this round by the team's plan. [param rng] picks between
## equal choices (seeded, so tests repeat).
static func buy_for_team(rules: RoundManager, team: int, rng: RandomNumberGenerator) -> void:
	if not rules.has_economy():
		return
	var plan := plan_for(rules, team)
	var kits := 0
	var defending := rules.get_side(team) == Teams.Side.DEFENDING
	for bot in rules.get_members(team):
		if bot.is_local_player() or not bot.is_alive():
			continue
		buy_for(rules, bot, plan, rng)
		if defending and plan != Plan.ECO and kits < KITS_PER_TEAM and rules.request_buy(bot, Shop.KIT) == "":
			kits += 1
		_buy_grenades(rules, bot, plan)


## [param bot]'s own shopping by [param plan]: a gun, then armor.
static func buy_for(rules: RoundManager, bot: Character, plan: Plan, rng: RandomNumberGenerator) -> void:
	var class_id: StringName = bot.class_data.id if bot.class_data != null else &"rifleman"
	match plan:
		Plan.PISTOL:
			match class_id:
				&"scout":
					rules.request_buy(bot, &"smg")
				&"marksman":
					rules.request_buy(bot, &"hand_cannon")
					rules.request_buy(bot, Shop.VEST)
				_:
					rules.request_buy(bot, Shop.VEST)
		Plan.FULL:
			var guns: Array = FULL_GUNS.get(class_id, FULL_GUNS[&"rifleman"]).duplicate()
			if class_id == &"bulwark" and rng.randf() < 0.5:
				guns.reverse()  # Half the time the Bulwark takes its Breaker into the fight.
			for gun: StringName in guns:
				if gun == &"sniper" and rules.get_money(bot) < SNIPER_MONEY:
					continue
				if rules.request_buy(bot, gun) == "":
					break
			_buy_armor(rules, bot)
		Plan.FORCE:
			for gun: StringName in FORCE_GUNS.get(class_id, FORCE_GUNS[&"rifleman"]):
				# Keep enough for a vest when the gun is the cheap one.
				if rules.get_money(bot) - rules.get_price(bot, gun) >= Shop.VEST_PRICE or gun == &"hand_cannon":
					if rules.request_buy(bot, gun) == "":
						break
			_buy_armor(rules, bot)
		Plan.ECO:
			pass


static func _buy_armor(rules: RoundManager, bot: Character) -> void:
	if rules.request_buy(bot, Shop.VEST_HELMET) != "":
		rules.request_buy(bot, Shop.VEST)


## Grenades with what's left (not on a save), by the class's taste.
static func _buy_grenades(rules: RoundManager, bot: Character, plan: Plan) -> void:
	if plan == Plan.ECO:
		return
	var class_id: StringName = bot.class_data.id if bot.class_data != null else &"rifleman"
	var wanted: Array = GRENADES.get(class_id, GRENADES[&"rifleman"])
	if plan == Plan.PISTOL or plan == Plan.FORCE:
		wanted = wanted.slice(0, 1)
	for grenade: StringName in wanted:
		rules.request_buy(bot, grenade)
