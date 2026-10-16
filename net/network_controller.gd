class_name NetworkController
extends CharacterController
## On the host: drives a friend's character with the commands their computer sends (M9, D-103).
##
## The character is a [member Character.manual] one: [NetHost] steps it once for every command
## that arrives, in order, with [method Character.step], so the host simulates exactly what the
## friend's computer predicted. This controller only keeps the commands until their turn and
## remembers which one ran last (the *ack* that goes back in every snapshot).
##
## The budget stops a friend from running faster than real time (a speed hack): it grows by one
## command per host tick, up to [constant MAX_BUDGET], and each command run spends one. Late
## packets can catch up a few ticks at once; a flood can't. With no commands arriving the
## character stands still.

## Commands that can be saved up (16 ms at 128 Hz) to catch up after a late packet.
const MAX_BUDGET := 8
## Commands kept waiting at most; older ones beyond that are dropped (a client far ahead).
const MAX_QUEUE := 64

## The friend's peer id.
var peer_id: int = 0
## The number of the last command run (0: none yet).
var last_run: int = 0
## Commands run so far.
var commands_run: int = 0

## Received commands not run yet, in order.
var _queue: Array[CharacterInput] = []
## The newest command number received.
var _newest: int = 0
## Commands this controller may run before the next host tick.
var _budget: float = 0.0


func get_input(_delta: float) -> CharacterInput:
	# Not used: the character is stepped by NetHost, one command at a time.
	var input := CharacterInput.new()
	input.yaw = character.get_aim_angles().x
	input.pitch = character.get_aim_angles().y
	return input


func set_look_angles(_yaw: float, _pitch: float) -> void:
	# The friend's own computer decides where they look; its next command says so.
	pass


## Takes the commands of one packet (oldest first): only those newer than any seen before
## are kept, so the repeats in every packet (D-103) are dropped here.
func receive(commands: Array[CharacterInput]) -> void:
	for command in commands:
		if command.tick <= _newest:
			continue
		_newest = command.tick
		_queue.append(command)
	while _queue.size() > MAX_QUEUE:
		_queue.pop_front()


## Gives the budget one more host tick of commands.
func add_tick() -> void:
	_budget = minf(_budget + 1.0, float(MAX_BUDGET))


## The next command to run, if there is one and the budget allows it; null otherwise.
func next_command() -> CharacterInput:
	if _queue.is_empty() or _budget < 1.0:
		return null
	_budget -= 1.0
	var command: CharacterInput = _queue.pop_front()
	last_run = command.tick
	commands_run += 1
	return command


## Commands waiting to run.
func pending() -> int:
	return _queue.size()
