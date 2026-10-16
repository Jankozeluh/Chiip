class_name TrainingHub
extends RefCounted
## Where the Shooting Range's training props meet the HUD (v0.2, D-236): a plain class with static members, like
## [Noises], so a prop in the map and the 2D screens in the game scene can find each other without a path.
## The aim trainer ([RangeTrainer]) and the spray wall ([RangeSprayWall]) put themselves here while they have
## something to show; [TrainingHud] reads it every frame and [TrainingMenu] answers a shot at the trainer's pad.
##
## The members are typed [Node3D] and [Object] on purpose: the props and the screens refer to this class, and a
## class that names them back would make the scripts wait for each other.

## The aim trainer whose countdown, run or result is on, or null.
static var trainer: Node3D
## The spray wall that was shot at last, or null.
static var wall: Node3D
## True while a [TrainingHud] is in the tree: the props then keep their in-world readouts quiet.
static var hud_active: bool = false
## The [TrainingMenu] that opens the aim trainer's start panel, or null (then a shot at the pad starts a run at once).
static var menu: Object


## Asks the start panel to open for [param shooter] at [param pad_trainer]. Returns false when there is none.
static func request_start(pad_trainer: Node3D, shooter: Node) -> bool:
	if menu == null or not is_instance_valid(menu):
		return false
	menu.call(&"open_for", pad_trainer, shooter)
	return true


## True while the aim trainer counts down or runs (what Esc stops).
static func is_running() -> bool:
	return trainer != null and is_instance_valid(trainer) and bool(trainer.call(&"is_active"))


## Stops the run that is on (the pause key's job while a run is on).
static func stop_run() -> void:
	if is_running():
		trainer.call(&"stop")


## Forgets everything (a new game, a test starting over).
static func reset() -> void:
	trainer = null
	wall = null
	hud_active = false
	menu = null
