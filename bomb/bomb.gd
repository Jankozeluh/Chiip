class_name Bomb
extends Node3D
## The bomb of a bomb round, like CS's C4 (GAME_DESIGN 4.7, D-080).
##
## One attacker carries it on their back. Holding Use inside a bomb site (an
## [Area3D] in group [constant SITE_GROUP]) for [member MatchSettings.plant_time]
## plants it; the fuse then runs [member MatchSettings.bomb_fuse_time] and the
## bomb beeps faster and faster until it explodes, hurting everyone near it. A
## defender holding Use next to it for [member MatchSettings.defuse_time]
## defuses it. Letting go of Use starts the plant or the defuse over. While
## someone plants or defuses, they can look and crouch but not move or shoot
## ([member Character.busy]). If the carrier dies, the bomb drops where they
## fell, and the first attacker to walk over it picks it up. Defenders can't.
##
## Everyone plays by the same rule: a [CharacterInput] with [code]use[/code]
## held, whether it comes from your keyboard or a bot's brain.
##
## This is authority code (docs/ARCHITECTURE.md, "Keeping multiplayer
## possible"): the [RoundManager] creates it on maps with bomb sites, hands it
## to an attacker at every round start, and ends the round on [signal planted],
## [signal defused] and [signal exploded]. The HUD only reads it. The model, the
## blinking light, the marker and the sounds are presentation.

## Where the bomb is in its life. A round starts with [constant CARRIED].
enum State { CARRIED, DROPPED, PLANTED, DEFUSED, EXPLODED }

## Emitted when an attacker takes the bomb: at the round start and when a
## dropped bomb is picked up.
signal picked_up(carrier: Character)
## Emitted when the carrier dies and the bomb falls to the floor at [param at].
signal dropped(at: Vector3)
## Emitted when a plant is finished: the fuse starts.
signal planted(site: Area3D, planter: Character)
## Emitted when a defuse is finished: the bomb won't explode.
signal defused(defuser: Character)
## Emitted when the fuse runs out, before the blast hurts anyone.
signal exploded
## Emitted on every beep of the planted bomb.
signal beeped

## Group of the bomb-site areas on a map.
const SITE_GROUP := "bomb_sites"
## Group the bomb is in, so bots can find it without a round manager.
const GROUP := "bomb"
## How close (metres, along the floor) an attacker must walk to a dropped bomb to pick it up.
const PICKUP_DISTANCE := 1.2
## How far above or below a dropped bomb an attacker can still pick it up (metres).
const PICKUP_HEIGHT := 1.6
## How close (metres, along the floor) a defender must stand to defuse.
const DEFUSE_DISTANCE := 1.5
## How far below a dying carrier the bomb looks for a floor to drop onto (metres).
const DROP_SEARCH := 6.0
## Where the bomb sits on a carrier's back, in the carrier's own space
## (forward is −z, so +z is behind).
const BACK_OFFSET := Vector3(0.0, 1.15, 0.22)
## Seconds between beeps right after the plant and in the last moment.
const BEEP_INTERVAL_START := 1.0
const BEEP_INTERVAL_END := 0.13
## Seconds between the key or wire sounds while someone plants or defuses.
const ACTION_SOUND_INTERVAL := 0.45
## Planting and defusing can be heard by bots this far away (metres): it's how
## defenders hear a plant, as in CS.
const ACTION_NOISE_RANGE := 20.0
## How long the blinking light stays lit after each beep (seconds).
const BLINK_TIME := 0.08

@export_group("Blast")
## Damage right at the bomb. CS: 500.
@export var blast_damage: float = 500.0
## How quickly the damage falls off: the width of its bell curve, in metres.
## 7.5 m is lethal (100) out to about 13.5 m and does 50 at 17.7 m and almost
## nothing beyond 22 m: CS's curve scaled down for maps half the size.
@export var blast_spread: float = 7.5

@export_group("Sounds")
## The planted bomb's beep, faster and faster until it explodes.
@export var beep_sound: AudioStream = preload("res://assets/sounds/bomb_beep.wav")
## A key press, about twice a second while someone plants.
@export var plant_sound: AudioStream = preload("res://assets/sounds/bomb_plant.wav")
## A wire click, about twice a second while someone defuses.
@export var defuse_sound: AudioStream = preload("res://assets/sounds/bomb_defuse.wav")
## The explosion.
@export var explosion_sound: AudioStream = preload("res://assets/sounds/bomb_explosion.wav")

## The rules: plant, defuse and fuse times. Set by the round manager.
var settings: MatchSettings = MatchSettings.new()
## Where the bomb is in its life. Read-only for other scripts.
var state: State = State.DROPPED
## Who carries it while [constant State.CARRIED], otherwise null.
var carrier: Character
## The site it was planted in, once planted.
var site: Area3D
## The team that attacks this round: the only one that can carry and plant it.
var attacking_team: int = 0
## Seconds left on the fuse while planted.
var fuse_left: float = 0.0
## The character planting or defusing right now, or null.
var actor: Character
## How far the current plant or defuse has come, 0 to 1.
var progress: float = 0.0
## Planting, defusing and picking up only work while this is true. The round
## manager turns it on when the round goes live and off when it ends. A
## planted bomb keeps ticking either way.
var active: bool = false
## Answers whether a defender has a defuse kit. Nobody has one until the
## economy (M7) sets this to its own check.
var kit_check: Callable = func(_defuser: Character) -> bool: return false

## Seconds until the next beep, and until the next plant or defuse sound.
var _beep_wait: float = 0.0
var _action_sound_wait: float = 0.0
## Seconds the blinking light has left to stay lit.
var _blink_left: float = 0.0

@onready var _model: Node3D = $Model
@onready var _light_mesh: MeshInstance3D = $Model/Light
@onready var _light: OmniLight3D = $Model/Glow
@onready var _marker: Label3D = $Marker
@onready var _beep_audio: AudioStreamPlayer3D = $BeepAudio
@onready var _action_audio: AudioStreamPlayer3D = $ActionAudio
@onready var _explosion_audio: AudioStreamPlayer3D = $ExplosionAudio
@onready var _explosion: Node3D = $Explosion
@onready var _blast: MeshInstance3D = $Explosion/Blast
@onready var _blast_light: OmniLight3D = $Explosion/BlastLight


func _ready() -> void:
	add_to_group(GROUP)
	# The sites only report who stands in them while monitoring is on.
	for node in get_tree().get_nodes_in_group(SITE_GROUP):
		var area := node as Area3D
		if area != null and get_parent().is_ancestor_of(area):
			area.monitoring = true
	_explosion.visible = false
	_set_lit(false)


## The bomb sites of the map the bomb is in.
func get_sites() -> Array[Area3D]:
	var sites: Array[Area3D] = []
	for node in get_tree().get_nodes_in_group(SITE_GROUP):
		if node is Area3D and get_parent().is_ancestor_of(node):
			sites.append(node)
	return sites


## The site [param character] stands in, or null.
func get_site_of(character: Character) -> Area3D:
	if character == null or not character.is_alive():
		return null
	for area in get_sites():
		if area.overlaps_body(character):
			return area
	return null


## The floor in the middle of [param area]: the bottom of its box (the site
## areas stand on the floor), or its centre for another shape.
static func get_site_floor(area: Area3D) -> Vector3:
	for child in area.get_children():
		var shape := child as CollisionShape3D
		if shape != null and shape.shape is BoxShape3D:
			return shape.global_position + Vector3.DOWN * (shape.shape as BoxShape3D).size.y * 0.5
	return area.global_position


## The letter of [param area] for messages: "A" for a node named BombSiteA.
static func site_letter(area: Area3D) -> String:
	return String(area.name).trim_prefix("BombSite") if area != null else ""


## Seconds [param defuser] needs to defuse: shorter with a kit (see [member kit_check]).
func get_defuse_time(defuser: Character) -> float:
	return settings.kit_defuse_time if kit_check.call(defuser) else settings.defuse_time


## True while the bomb is planted and ticking.
func is_planted() -> bool:
	return state == State.PLANTED


## True while [param character] is planting (not defusing) the bomb.
func is_planting(character: Character) -> bool:
	return actor == character and state == State.CARRIED


## True while [param character] is defusing the bomb.
func is_defusing(character: Character) -> bool:
	return actor == character and state == State.PLANTED


## A fresh round: the bomb is back in one piece and [param new_carrier] (an
## attacker of [param attackers]) has it. Called by the round manager after
## everyone has respawned.
func start_round(new_carrier: Character, attackers: int) -> void:
	_stop_action()
	attacking_team = attackers
	site = null
	fuse_left = settings.bomb_fuse_time
	_explosion.visible = false
	_model.visible = true
	_set_lit(false)
	_give_to(new_carrier)


## Plants the bomb at once in [param in_site], where [param planter] stands (a
## finished plant). Used when a plant completes, by tests, and later by M9
## clients told about a plant.
func plant(in_site: Area3D, planter: Character) -> void:
	_stop_action()
	var at := planter.global_position if planter != null else in_site.global_position
	carrier = null
	site = in_site
	state = State.PLANTED
	fuse_left = settings.bomb_fuse_time
	_beep_wait = 0.0
	_place(_floor_below(at), global_rotation.y)
	_model.visible = true
	planted.emit(in_site, planter)


func _physics_process(delta: float) -> void:
	match state:
		State.CARRIED:
			_update_carried(delta)
		State.DROPPED:
			_update_dropped()
		State.PLANTED:
			_update_planted(delta)


func _process(delta: float) -> void:
	# Presentation only: the blinking light and who sees the marker.
	if _blink_left > 0.0:
		_blink_left -= delta
		if _blink_left <= 0.0:
			_set_lit(false)
	# Attackers see a dropped bomb through walls (CS shows it on their radar);
	# everyone sees a planted one, with its site announced.
	_marker.visible = (state == State.DROPPED and Teams.viewer_team == attacking_team) or state == State.PLANTED


# --- Carried, dropped, planted ---


func _update_carried(delta: float) -> void:
	if not is_instance_valid(carrier) or not carrier.is_alive():
		_drop()
		return
	_follow_carrier()
	var in_site := get_site_of(carrier) if active and not carrier.frozen and carrier.is_on_floor() else null
	if in_site == null or not carrier.is_holding_use():
		_stop_action()
		return
	if actor != carrier:
		_start_action(carrier)
	_continue_action(delta / settings.plant_time)
	if progress >= 1.0:
		plant(in_site, carrier)


func _update_dropped() -> void:
	if not active:
		return
	var nearest: Character = null
	var nearest_distance := PICKUP_DISTANCE
	for node in get_tree().get_nodes_in_group("characters"):
		var character := node as Character
		if character.team != attacking_team or not character.is_alive():
			continue
		var offset := character.global_position - global_position
		var distance := Vector2(offset.x, offset.z).length()
		if distance <= nearest_distance and absf(offset.y) <= PICKUP_HEIGHT:
			nearest = character
			nearest_distance = distance
	if nearest != null:
		_give_to(nearest)


func _update_planted(delta: float) -> void:
	_update_defuse(delta)
	if state != State.PLANTED:
		return
	fuse_left -= delta
	_beep_wait -= delta
	if _beep_wait <= 0.0:
		_beep()
		_beep_wait = lerpf(BEEP_INTERVAL_END, BEEP_INTERVAL_START, clampf(fuse_left / settings.bomb_fuse_time, 0.0, 1.0))
	if fuse_left <= 0.0:
		_explode()


## Keeps the current defuser going, or starts the first defender who holds Use
## within reach. Only one defender defuses at a time.
func _update_defuse(delta: float) -> void:
	if actor != null and not _can_defuse(actor):
		_stop_action()
	if actor == null and active:
		for node in get_tree().get_nodes_in_group("characters"):
			var character := node as Character
			if _can_defuse(character):
				_start_action(character)
				break
	if actor == null:
		return
	_continue_action(delta / get_defuse_time(actor))
	if progress >= 1.0:
		var defuser := actor
		_stop_action()
		state = State.DEFUSED
		_set_lit(false)
		defused.emit(defuser)


func _can_defuse(character: Character) -> bool:
	if not active or not is_instance_valid(character) or character.team == attacking_team:
		return false
	if character.frozen or not character.is_on_floor() or not character.is_holding_use():
		return false
	var offset := character.global_position - global_position
	return Vector2(offset.x, offset.z).length() <= DEFUSE_DISTANCE and absf(offset.y) <= PICKUP_HEIGHT


## The blast: CS's bomb damage, a bell curve around the bomb (500 at the bomb,
## lethal out to about 13 m, almost nothing beyond 20 m). Walls don't shield,
## as in CS. Nobody gets a kill for it.
func _explode() -> void:
	state = State.EXPLODED
	_stop_action()
	_set_lit(false)
	exploded.emit()
	for node in get_tree().get_nodes_in_group("characters"):
		var character := node as Character
		if character.is_alive():
			var damage := get_blast_damage(character.get_visibility_points()[1].distance_to(global_position))
			if damage >= 1.0:
				character.take_damage(damage, Hitbox.Zone.CHEST, null)
	_play_explosion()


## The blast's damage [param distance] metres from the bomb.
func get_blast_damage(distance: float) -> float:
	return blast_damage * exp(-distance * distance / (2.0 * blast_spread * blast_spread))


# --- Helpers ---


func _give_to(new_carrier: Character) -> void:
	_stop_action()
	carrier = new_carrier
	state = State.CARRIED if new_carrier != null else State.DROPPED
	if new_carrier == null:
		return
	_follow_carrier()
	reset_physics_interpolation()
	# Upright against the carrier's back. You don't see the bomb on your own back.
	_model.rotation = Vector3(PI / 2.0, 0.0, 0.0)
	_model.visible = not new_carrier.is_local_player()
	picked_up.emit(new_carrier)


func _drop() -> void:
	var at := global_position
	if is_instance_valid(carrier):
		at = carrier.global_position
	_stop_action()
	carrier = null
	state = State.DROPPED
	_place(_floor_below(at + Vector3.UP * 0.5), global_rotation.y)
	_model.visible = true
	dropped.emit(global_position)


func _follow_carrier() -> void:
	global_transform = carrier.global_transform * Transform3D(Basis(), BACK_OFFSET)


## Puts the bomb on the floor at [param at], facing [param yaw], without
## smoothing it in from where it was.
func _place(at: Vector3, yaw: float) -> void:
	global_transform = Transform3D(Basis(Vector3.UP, yaw), at)
	reset_physics_interpolation()
	_model.rotation = Vector3.ZERO


## The floor right under [param from] (the world only), or [param from] if there is none within [constant DROP_SEARCH].
func _floor_below(from: Vector3) -> Vector3:
	var query := PhysicsRayQueryParameters3D.create(from + Vector3.UP * 0.1, from + Vector3.DOWN * DROP_SEARCH, PhysicsLayers.WORLD)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit["position"] if not hit.is_empty() else from


## [param character] plants or defuses from now on: it can't move or shoot meanwhile.
func _start_action(character: Character) -> void:
	_stop_action()
	actor = character
	actor.busy = true
	progress = 0.0
	_action_sound_wait = 0.0


## Moves the current plant or defuse on by [param amount] (a share of the whole),
## with a key press or wire click about twice a second, which bots hear too.
func _continue_action(amount: float) -> void:
	progress += amount
	_action_sound_wait -= 1.0 / Engine.physics_ticks_per_second
	if _action_sound_wait > 0.0:
		return
	_action_sound_wait = ACTION_SOUND_INTERVAL
	Noises.make_noise(actor.global_position, ACTION_NOISE_RANGE, actor)
	var sound := plant_sound if state == State.CARRIED else defuse_sound
	if sound != null:
		_action_audio.global_position = actor.get_visibility_points()[1]
		_action_audio.stream = sound
		_action_audio.play()


## Ends a plant or defuse, finished or not; an unfinished one starts over next time.
func _stop_action() -> void:
	if is_instance_valid(actor):
		actor.busy = false
	actor = null
	progress = 0.0


func _beep() -> void:
	beeped.emit()
	_set_lit(true)
	_blink_left = BLINK_TIME
	if beep_sound != null:
		_beep_audio.stream = beep_sound
		_beep_audio.play()


func _set_lit(lit: bool) -> void:
	if _light_mesh == null:
		return
	_light_mesh.visible = lit
	_light.visible = lit


## The flash: a ball of light that grows and fades, and the boom. Visual only.
func _play_explosion() -> void:
	_model.visible = false
	_explosion.visible = true
	var material := _blast.get_active_material(0) as StandardMaterial3D
	_blast.scale = Vector3.ONE * 0.5
	material.albedo_color.a = 0.9
	_blast_light.light_energy = 8.0
	var tween := create_tween().set_parallel()
	tween.tween_property(_blast, "scale", Vector3.ONE * blast_spread * 1.3, 0.45).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(material, "albedo_color:a", 0.0, 0.6)
	tween.tween_property(_blast_light, "light_energy", 0.0, 0.8)
	tween.chain().tween_callback(func() -> void: _explosion.visible = false)
	if explosion_sound != null:
		_explosion_audio.stream = explosion_sound
		_explosion_audio.play()
