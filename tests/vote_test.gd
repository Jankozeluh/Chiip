extends Node
## Automated checks for the map vote online (M17, D-244). Run without a window:
##
##     Godot --headless --path . --fixed-fps 128 --quit-after 60000 res://tests/vote_test.tscn
##
## A host and two clients in this process ([NetHarness]), each with a [MapVote] on its session: the host's
## choices reach everyone; every pick is counted once per player and may change; the counts reach everyone and
## decide the winner (the earlier choice on a tie, the first without votes); a pick out of range and choices
## that aren't rotation maps are ignored; a player who leaves takes their vote along. The end screen and
## "Next map" offline are checked by the rotation suite. Quits with the number of failed checks.

const DEPOT := "res://maps/depot.tscn"
const SQUARE := "res://maps/square.tscn"
const SPILLWAY := "res://maps/spillway.tscn"

var _harness: NetHarness
var _failures: int = 0


func _ready() -> void:
	_harness = NetHarness.new()
	add_child(_harness)
	await _test_vote()
	remove_child(_harness)
	_harness.queue_free()
	for i in 5:
		await get_tree().physics_frame
	if _failures == 0:
		print("\nAll checks passed.")
	else:
		print("\n%d check(s) FAILED." % _failures)
	get_tree().quit(_failures)


func _test_vote() -> void:
	var host := _harness.start_host("Host", "Host")
	var jan := _harness.start_client("Jan", "Jan")
	var eva := _harness.start_client("Eva", "Eva")
	await _harness.wait_until(func() -> bool: return jan.is_active() and eva.is_active() and host.get_players().size() == 3)
	var votes: Array[MapVote] = []
	for session in [host, jan, eva]:
		var vote := MapVote.new()
		vote.session = session
		session.add_child(vote)
		votes.append(vote)
	var host_vote := votes[0]
	var jan_vote := votes[1]
	var eva_vote := votes[2]
	_check("The choices are the rotation's next maps, the one just played last", MapVote.pick_choices([DEPOT, SQUARE, SPILLWAY, "res://maps/x.tscn"], 3) == [DEPOT, SQUARE, SPILLWAY]
			and MapVote.pick_choices([DEPOT, SQUARE], 0) == [SQUARE, DEPOT], "")

	host_vote.start([SQUARE, SPILLWAY, DEPOT])
	var offered := await _harness.wait_until(func() -> bool: return jan_vote.choices == [SQUARE, SPILLWAY, DEPOT] and eva_vote.choices == [SQUARE, SPILLWAY, DEPOT], 256)
	_check("The host's choices reach everyone; without votes the rotation's next wins", offered and host_vote.get_winner() == SQUARE and jan_vote.get_winner() == SQUARE,
			"jan %s, eva %s" % [jan_vote.choices, eva_vote.choices])

	jan_vote.vote(1)
	eva_vote.vote(2)
	var counted := await _harness.wait_until(func() -> bool: return eva_vote.get_counts() == [0, 1, 1] and jan_vote.get_counts() == [0, 1, 1], 256)
	_check("Picks are counted on the host and the counts reach everyone; a tie goes to the earlier choice",
			counted and host_vote.get_counts() == [0, 1, 1] and host_vote.get_winner() == SPILLWAY and jan_vote.get_my_vote() == 1,
			"host %s, jan %s, eva %s" % [host_vote.get_counts(), jan_vote.get_counts(), eva_vote.get_counts()])

	eva_vote.vote(1)
	host_vote.vote(2)
	jan.send_to_host({"vote": 7})
	var changed := await _harness.wait_until(func() -> bool: return jan_vote.get_counts() == [0, 2, 1], 256)
	await _harness.wait_ticks(20)
	_check("A changed pick moves its one vote; the host votes too; a pick out of range is ignored",
			changed and host_vote.get_counts() == [0, 2, 1] and host_vote.get_winner() == SPILLWAY, "host %s" % [host_vote.get_counts()])

	jan.match_message_sender = 1
	jan_vote._on_match_message({"vote_map_0": "res://somewhere/else.tscn", "vote_map_1": SQUARE})
	_check("A client takes only rotation maps as choices", jan_vote.choices == [SQUARE], "%s" % [jan_vote.choices])

	eva.close()
	var gone := await _harness.wait_until(func() -> bool: return host_vote.get_counts() == [0, 1, 1], 512)
	_check("A player who leaves takes their vote along", gone, "host %s" % [host_vote.get_counts()])
	jan.close()
	host.close()
	await _harness.wait_ticks(40)


func _check(description: String, passed: bool, detail: String) -> void:
	if passed:
		print("PASS  ", description, "  (", detail, ")")
	else:
		_failures += 1
		print("FAIL  ", description, "  (", detail, ")")
