extends Node
## Automated checks for M7's arsenal online (M9 phase B, D-113). Run without a window:
##
##     Godot --headless --path . --fixed-fps 128 --quit-after 200000 res://tests/netarsenal_test.tscn
##
## A host and a client play rounds on Depot in this one process ([NetHarness]), at 100 ms of
## round trip, with the bots held still. Checked: the client carries what the host gives it and
## holds the same weapon; switching weapons is predicted; a puppet holds the weapon its player
## holds; dropping is the host's and the gun appears on the client's floor; walking over it takes
## it back; armor reaches the client; map weapons show on the client with their rings; a frag the
## client throws flies on the client and goes off there with the host's blast; a flash blinds
## the client's player; a smoke leaves the same cloud on both sides. The economy (task 13): your
## money and its reward lines follow the host's, a purchase in the freeze time is the host's to make
## and comes back as money, gear and inventory, the class draft offers the same two classes on both
## sides, and the kill feed knows the weapon of a kill. Quits with the number of failed checks as
## the exit code.

const MAP := preload("res://maps/depot.tscn")

var _harness: NetHarness
var _failures: int = 0
var _host_main: Node
var _client_main: Node
var _host_session: NetSession
var _client_session: NetSession
var _host: NetHost
var _client: NetClient
var _friend: Character
var _own: Character
var _host_rules: RoundManager
## What the client's player is told to do this tick (see [method _command]).
var _slot: int = -1
var _shoot: bool = false
var _drop: bool = false


func _ready() -> void:
	_harness = NetHarness.new()
	add_child(_harness)
	if await _start():
		await _test_inventory()
		await _test_drop_and_pickup()
		await _test_armor_and_map_weapons()
		await _test_grenades()
		await _test_economy()
	for main in [_client_main, _host_main]:
		if main != null and is_instance_valid(main):
			main.get_parent().remove_child(main)
			main.queue_free()
	for session in [_client_session, _host_session]:
		if session != null and is_instance_valid(session):
			session.close()
	for i in 40:
		await get_tree().physics_frame
	remove_child(_harness)
	_harness.queue_free()
	for i in 5:
		await get_tree().physics_frame
	if _failures == 0:
		print("\nAll checks passed.")
	else:
		print("\n%d check(s) FAILED." % _failures)
	get_tree().quit(_failures)


func _rules() -> MatchSettings:
	var rules := MatchSettings.new()
	rules.team_size = 2
	rules.enemy_team_size = 2
	rules.rounds_to_win = 5
	rules.freeze_time = 1.0
	rules.round_time = 120.0
	rules.round_end_time = 1.0
	return rules


func _start() -> bool:
	_host_session = _harness.start_host("Host", "Host")
	_client_session = _harness.start_client("Client", "Jan")
	await _harness.wait_until(_client_session.is_active)
	_host_session.set_player_team(_client_session.local_peer_id, 0)
	await _harness.wait_ticks(10)
	_host_main = _harness.start_game(_host_session.get_parent(), _host_session, MAP, _rules())
	_client_main = _harness.start_game(_client_session.get_parent(), _client_session, MAP, _rules())
	_harness.silence(_host_main.get_player())
	_harness.silence(_client_main.get_player())
	_host = _host_main.get_net_game() as NetHost
	_client = _client_main.get_net_game() as NetClient
	var both := func() -> bool: return _host.is_started() and _client.is_welcomed()
	if not await _harness.wait_until(both, 1200):
		_check("The match starts", false, "")
		return false
	_host_rules = _host.rules
	_friend = _host.get_character_of(_client_session.local_peer_id)
	_own = _client.player
	_client.command_source = _command
	await _harness.wait_until(func() -> bool: return _host_rules.phase == RoundManager.Phase.LIVE, 600)
	_hold_bots()
	_host_session.fake_lag_ms = 50.0
	_client_session.fake_lag_ms = 50.0
	await _harness.wait_ticks(60)
	return true


## The client's player stands still and does what the test asks for this tick.
func _command(_delta: float) -> CharacterInput:
	var command := CharacterInput.new()
	command.yaw = _own.get_aim_angles().x
	command.pitch = _own.get_aim_angles().y
	command.weapon_slot = _slot
	command.shoot = _shoot
	command.drop = _drop
	_slot = -1
	_drop = false
	return command


func _hold_bots() -> void:
	for character in _host_rules.get_participants():
		if character.get_node_or_null("BotController") != null:
			character.frozen = true


func _ids(character: Character) -> Array:
	return character.inventory.get_weapons().map(func(weapon: Weapon) -> StringName: return weapon.data.id)


func _held(character: Character) -> StringName:
	return character.weapon.data.id if character.weapon != null else &""


func _test_inventory() -> void:
	_check("The client carries what the host gave its character, and holds the same weapon",
			not _ids(_friend).is_empty() and _ids(_own) == _ids(_friend) and _held(_own) == _held(_friend),
			"host %s holding %s, client %s holding %s" % [_ids(_friend), _held(_friend), _ids(_own), _held(_own)])
	var host_player: Character = _host_main.get_player()
	var puppet := _client.get_character(host_player.net_id)
	_check("A puppet holds the weapon its player holds", puppet != null and _held(puppet) == _held(host_player),
			"host player %s, puppet %s" % [_held(host_player), _held(puppet) if puppet != null else &"-"])
	# Switching is predicted: the knife is out on the client at once, on the host a round trip later.
	var corrections := _client.corrections
	_slot = WeaponData.Slot.KNIFE
	await _harness.wait_ticks(2)
	var here_at_once := _held(_own)
	var there_at_once := _held(_friend)
	await _harness.wait_ticks(40)
	_check("Switching weapons is predicted: your knife is out at once, the host's a round trip later, with no correction",
			here_at_once == &"knife" and there_at_once != &"knife" and _held(_friend) == &"knife" and _client.corrections == corrections,
			"at once %s / %s, then %s, %d corrections" % [here_at_once, there_at_once, _held(_friend), _client.corrections - corrections])
	# The host gives a rifle: it arrives in the client's inventory, and taking it out works too.
	_friend.inventory.give(WeaponData.find(&"rifle"))
	await _harness.wait_until(func() -> bool: return _own.inventory.find(WeaponData.find(&"rifle")) != null, 120)
	_slot = WeaponData.Slot.PRIMARY
	await _harness.wait_ticks(60)
	_check("A gun the host gives arrives in the client's inventory; taking it out works on both sides",
			_ids(_own) == _ids(_friend) and _held(_own) == &"rifle" and _held(_friend) == &"rifle",
			"host %s holding %s, client %s holding %s" % [_ids(_friend), _held(_friend), _ids(_own), _held(_own)])


func _test_drop_and_pickup() -> void:
	_drop = true
	var dropped := func() -> bool: return _held(_friend) != &"rifle" and not WeaponPickup.all_in_world(_host_main.get_map()).filter(
			func(p: WeaponPickup) -> bool: return p.data.id == &"rifle" and p.spot == null).is_empty()
	await _harness.wait_until(dropped, 120)
	var host_pickup: WeaponPickup = null
	for pickup in WeaponPickup.all_in_world(_host_main.get_map()):
		if pickup.data.id == &"rifle" and pickup.spot == null:
			host_pickup = pickup
	await _harness.wait_ticks(60)
	var copies := WeaponPickup.all_in_world(_client_main.get_map()).filter(func(p: WeaponPickup) -> bool: return p.replica and p.data.id == &"rifle" and not p.floating)
	_check("Dropping is the host's: the rifle leaves both inventories and lies on the client's floor where it lies on the host's",
			host_pickup != null and _own.inventory.find(WeaponData.find(&"rifle")) == null and _held(_own) == _held(_friend)
					and copies.size() == 1 and (copies[0] as WeaponPickup).global_position.distance_to(host_pickup.global_position) < 0.05,
			"host pickup %s, client copies %d, client holds %s" % [host_pickup, copies.size(), _held(_own)])
	# Walking over it takes it again (the host moves the character onto it, past the dropper's delay).
	await _harness.wait_ticks(140)
	if host_pickup != null and is_instance_valid(host_pickup):
		_friend.global_position = host_pickup.global_position - Vector3.UP * 0.04
	await _harness.wait_ticks(80)
	var left := WeaponPickup.all_in_world(_client_main.get_map()).filter(func(p: WeaponPickup) -> bool: return p.replica and p.data.id == &"rifle" and not p.floating)
	_check("Walking over it takes it back: gone from the client's floor, back in the client's inventory",
			left.is_empty() and _own.inventory.find(WeaponData.find(&"rifle")) != null and _ids(_own) == _ids(_friend),
			"%d copies left, client carries %s" % [left.size(), _ids(_own)])


func _test_armor_and_map_weapons() -> void:
	_friend.set_armor(100.0, true)
	var host_player: Character = _host_main.get_player()
	host_player.set_armor(60.0, false)
	await _harness.wait_ticks(40)
	var puppet := _client.get_character(host_player.net_id)
	_check("Armor reaches the client: your vest and helmet, and the puppets'",
			ceili(_own.armor) == 100 and _own.has_helmet and puppet != null and ceili(puppet.armor) == 60 and not puppet.has_helmet,
			"yours %d%s, the host's puppet %d" % [ceili(_own.armor), " + helmet" if _own.has_helmet else "", ceili(puppet.armor) if puppet != null else -1])
	var host_spots := get_tree().get_nodes_in_group(WeaponSpot.GROUP).filter(func(n: Node) -> bool: return _host_main.get_map().is_ancestor_of(n))
	var client_spots := get_tree().get_nodes_in_group(WeaponSpot.GROUP).filter(func(n: Node) -> bool: return _client_main.get_map().is_ancestor_of(n))
	var floating := WeaponPickup.all_in_world(_client_main.get_map()).filter(func(p: WeaponPickup) -> bool: return p.floating)
	var same_places := true
	for spot: Node in host_spots:
		var match_found := client_spots.any(func(other: Node) -> bool:
			return (other as WeaponSpot).weapon.id == (spot as WeaponSpot).weapon.id and (other as Node3D).global_position.distance_to((spot as Node3D).global_position) < 0.05)
		same_places = same_places and match_found
	_check("Map weapons show on the client: the same rings at the same places, with their guns floating over them",
			not host_spots.is_empty() and client_spots.size() == host_spots.size() and same_places and floating.size() == host_spots.size(),
			"host %d spots, client %d spots and %d floating guns" % [host_spots.size(), client_spots.size(), floating.size()])


func _test_grenades() -> void:
	# A frag: given by the host, taken out and thrown by the client.
	_friend.inventory.give(WeaponData.find(&"frag"))
	await _harness.wait_until(func() -> bool: return _own.inventory.find(WeaponData.find(&"frag")) != null, 120)
	_slot = WeaponData.Slot.GRENADE
	await _harness.wait_ticks(60)
	_shoot = true
	await _harness.wait_ticks(60)
	_shoot = false
	var flying := func() -> bool: return not _client_main.get_map().find_children("*", "Grenade", true, false).is_empty()
	var seen := await _harness.wait_until(flying, 120)
	var copy: Grenade = _client_main.get_map().find_children("*", "Grenade", true, false)[0] if seen else null
	var host_grenades: Array = _host_main.get_map().find_children("*", "Grenade", true, false)
	var apart := (copy.global_position.distance_to((host_grenades[0] as Node3D).global_position) if copy != null and not host_grenades.is_empty() else -1.0)
	_check("A frag the client throws flies on the client too: one copy, where the host's is (a few ticks behind)",
			seen and copy.replica and host_grenades.size() == 1 and apart < 2.0,
			"seen %s, host has %d, %.2f m apart" % [seen, host_grenades.size(), apart])
	var gone := func() -> bool: return _client_main.get_map().find_children("*", "Grenade", true, false).is_empty() \
			and _host_main.get_map().find_children("*", "Grenade", true, false).is_empty()
	await _harness.wait_until(gone, 600)
	var blasts: Array = _client_main.get_map().find_children("*", "Explosion", true, false)
	_check("When it goes off on the host, the client's copy goes and the blast plays on the client",
			_client_main.get_map().find_children("*", "Grenade", true, false).is_empty() and not blasts.is_empty(), "%d blasts" % blasts.size())
	# A flash blinds the client's player as the host decided.
	_friend.flash(1.0, 2.0)
	await _harness.wait_ticks(20)
	_check("A flashbang the host says blinded you blinds your player here", _own.get_flash_alpha() > 0.5, "alpha %.2f" % _own.get_flash_alpha())
	# A smoke: the same cloud on both sides.
	_friend.inventory.give(WeaponData.find(&"smoke"))
	await _harness.wait_until(func() -> bool: return _own.inventory.find(WeaponData.find(&"smoke")) != null, 120)
	_slot = WeaponData.Slot.GRENADE
	await _harness.wait_ticks(60)
	_shoot = true
	await _harness.wait_ticks(60)
	_shoot = false
	var clouds := func() -> bool: return not _client_main.get_map().find_children("*", "SmokeCloud", true, false).is_empty()
	await _harness.wait_until(clouds, 900)
	var host_clouds: Array = _host_main.get_map().find_children("*", "SmokeCloud", true, false)
	var client_clouds: Array = _client_main.get_map().find_children("*", "SmokeCloud", true, false)
	_check("A smoke leaves the same cloud on the client, at the same place, from the same seed",
			host_clouds.size() == 1 and client_clouds.size() == 1
					and (client_clouds[0] as Node3D).global_position.distance_to((host_clouds[0] as Node3D).global_position) < 0.01
					and (client_clouds[0] as SmokeCloud).rng.seed == (host_clouds[0] as SmokeCloud).rng.seed,
			"host %d, client %d" % [host_clouds.size(), client_clouds.size()])


func _check(description: String, passed: bool, detail: String) -> void:
	if passed:
		print("PASS  ", description)
	else:
		_failures += 1
		print("FAIL  ", description, "  (", detail, ")")


func _test_economy() -> void:
	var client_rules := _client.rules
	_check("The class draft offers you the same two classes on both sides",
			client_rules.get_draft(_own).size() == 2 and client_rules.get_draft(_own) == _host_rules.get_draft(_friend),
			"host %s, client %s" % [_host_rules.get_draft(_friend).map(func(c: ClassData) -> StringName: return c.id),
					client_rules.get_draft(_own).map(func(c: ClassData) -> StringName: return c.id)])
	var lines: Array = []
	client_rules.money_changed.connect(func(character: Character, amount: int, reason: String) -> void:
		if character == _own:
			lines.append([amount, reason]))
	_host_rules.add_money(_friend, 300, "Test reward")
	await _harness.wait_ticks(30)
	_check("Your money follows the host's, with its reward line (\"+$300 · Test reward\")",
			client_rules.get_money(_own) == _host_rules.get_money(_friend) and lines.has([300, "Test reward"]),
			"host $%d, client $%d, lines %s" % [_host_rules.get_money(_friend), client_rules.get_money(_own), lines])
	# The kill feed's weapon: a bot killed by the host's player with a rifle.
	var victim: Character = null
	for character in _host_rules.get_participants():
		if character.get_node_or_null("BotController") != null and character.team != _host_main.get_player().team and character.is_alive():
			victim = character
	var killed: Array = []
	client_rules.character_killed.connect(func(dead: Character, _killer: Character, _headshot: bool) -> void:
		killed.append(dead.last_damage_source.id if dead.last_damage_source != null else &""))
	victim.take_damage(500.0, Hitbox.Zone.CHEST, _host_main.get_player(), 1.0, WeaponData.find(&"rifle"))
	await _harness.wait_ticks(30)
	_check("The kill feed knows the weapon of a kill on the client too", killed == [&"rifle"], "%s" % [killed])
	# A purchase: the next freeze time, the client buys a vest; the host decides and pays.
	_host_rules.time_left = 0.05
	var freezing := func() -> bool: return _host_rules.phase == RoundManager.Phase.FREEZE and client_rules.phase == RoundManager.Phase.FREEZE
	await _harness.wait_until(freezing, 1200)
	await _harness.wait_ticks(4)
	# No vest yet (the dead lose theirs, the living keep it) and money for one.
	_friend.set_armor(0.0, false)
	_host_rules.add_money(_friend, 1000, "Test")
	await _harness.wait_ticks(30)
	var before := _host_rules.get_money(_friend)
	var asked := client_rules.request_buy(_own, Shop.VEST)
	await _harness.wait_ticks(40)
	_check("A purchase is the host's: the client asks, the host pays and hands it over, and money, armor and gear come back",
			asked == "" and _host_rules.get_money(_friend) == before - Shop.VEST_PRICE and client_rules.get_money(_own) == before - Shop.VEST_PRICE
					and ceili(_friend.armor) == 100 and ceili(_own.armor) == 100,
			"asked \"%s\", host $%d -> $%d, client $%d, armor %d / %d" % [asked, before, _host_rules.get_money(_friend),
					client_rules.get_money(_own), ceili(_friend.armor), ceili(_own.armor)])
	var refused := client_rules.request_buy(_own, Shop.VEST)
	_check("The client's buy menu refuses what the host would refuse, from the replicated money and gear",
			refused != "", "\"%s\"" % refused)

