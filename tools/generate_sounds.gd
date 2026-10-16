extends SceneTree
## Tool: generates Chiip's placeholder sounds as .wav files (D-020): the rifle (shot,
## empty click, reload), footsteps on four surfaces, the bomb, bullet impacts, hits on
## characters, interface sounds and, for M7's arsenal, the pistol, hand cannon, SMG,
## carbine, shotgun (shot, pump, shell), sniper rifle (shot, bolt), pistol reload,
## knife, the three grenades (pin, throw, bounce, frag, flash, smoke), buy and pickup.
##
## M13 (D-191, D-194) adds a signature to every gun family: a redesigned SMG shot (light and
## papery, readable in a fight) and hand cannon shot (the boom plus a loud 1-4 kHz crack), a
## far variant of every gun's shot (what it sounds like from 40 m or more: soft attack, almost
## nothing above 1 kHz, a thump at the family's pitch and a long dark echo), three reload
## sounds for each magazine gun (magazine out, magazine in, bolt or slide: every family has
## its own pitch, scrape and timing) and far variants of the frag and bomb explosions. Each of
## them has its own random generator (`_rng_for`, so no sound depends on the order) and is
## brought to a target short-term loudness by `_finish_loudness`; `tools/sound_report.gd`
## prints the result.
##
## Run from the project folder, then let Godot import the new files:
##
##     Godot --headless --path . --script res://tools/generate_sounds.gd
##     Godot --headless --path . --import
##
## Weapons only reference the files in assets/sounds/, so these can be replaced
## with real recordings at any time without code changes.

const MIX_RATE := 22050
const OUTPUT_FOLDER := "res://assets/sounds/"
## Amplitude steps kept after "bit crushing". Fewer steps = crunchier, more retro.
const CRUSH_LEVELS := 48
## The highest peak a finished sound may have (linear, about -1.06 dBFS). Crushing rounds to
## steps of 1/48, so a peak of up to 0.885 still ends on the 42nd step, 0.875 (-1.16 dBFS).
const PEAK_LIMIT := 0.885
## The ceiling of the soft clipper in `_finish_loudness`: its output never reaches this.
const SATURATION_CEILING := 0.87


func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026  # The same sounds every time the tool runs.
	_save("rifle_shot.wav", _gunshot(rng))
	_save("dry_fire.wav", _click(rng))
	_save("rifle_reload.wav", _clack(rng))
	# Added after the weapon sounds so those stay identical when regenerated.
	for i in 3:
		_save("footstep_%d.wav" % (i + 1), _footstep(rng))
	# M8: the bomb (D-080). Added last, so the sounds above stay identical.
	_save("bomb_beep.wav", _bomb_beep())
	_save("bomb_plant.wav", _keypad_press(rng))
	_save("bomb_defuse.wav", _wire_click(rng))
	_save("bomb_explosion.wav", _explosion(rng))
	# M8: footsteps on gravel, metal and wood, bullet impacts, hits on characters
	# and interface sounds. Added last, so everything above stays identical.
	for i in 3:
		_save("footstep_gravel_%d.wav" % (i + 1), _footstep_gravel(rng))
	for i in 3:
		_save("footstep_metal_%d.wav" % (i + 1), _footstep_metal(rng))
	for i in 3:
		_save("footstep_wood_%d.wav" % (i + 1), _footstep_wood(rng))
	_save("impact_hard.wav", _impact_hard(rng))
	_save("impact_gravel.wav", _impact_gravel(rng))
	_save("impact_metal.wav", _impact_metal(rng))
	_save("impact_wood.wav", _impact_wood(rng))
	_save("hit_body.wav", _hit_body(rng))
	_save("hit_head.wav", _hit_head(rng))
	_save("ui_hover.wav", _ui_hover())
	_save("ui_click.wav", _ui_click(rng))
	_save("round_start.wav", _round_start())
	_save("round_won.wav", _round_won())
	_save("round_lost.wav", _round_lost())
	_save("bomb_planted_alert.wav", _bomb_planted_alert())
	# M7: the arsenal. Added last, so everything above stays identical. Guns first
	# (a shot for each weapon plus its handling sounds), then knife, grenades, interface.
	_save("pistol_shot.wav", _pistol_shot(rng))
	_save("hand_cannon_shot.wav", _hand_cannon_shot())
	_save("smg_shot.wav", _smg_shot())
	_save("carbine_shot.wav", _carbine_shot(rng))
	_save("shotgun_shot.wav", _shotgun_shot(rng))
	_save("shotgun_pump.wav", _shotgun_pump(rng))
	_save("shell_insert.wav", _shell_insert(rng))
	_save("sniper_shot.wav", _sniper_shot(rng))
	_save("sniper_bolt.wav", _sniper_bolt(rng))
	_save("pistol_reload.wav", _pistol_reload(rng))
	_save("knife_swing.wav", _knife_swing(rng))
	_save("knife_hit.wav", _knife_hit(rng))
	_save("grenade_pin.wav", _grenade_pin(rng))
	_save("grenade_throw.wav", _grenade_throw(rng))
	_save("grenade_bounce.wav", _grenade_bounce(rng))
	_save("frag_explosion.wav", _frag_explosion(rng))
	_save("flash_pop.wav", _flash_pop(rng))
	_save("flash_ring.wav", _flash_ring())
	_save("smoke_hiss.wav", _smoke_hiss(rng))
	_save("buy.wav", _buy())
	_save("buy_denied.wav", _buy_denied())
	_save("pickup.wav", _pickup(rng))
	# M13: far shots, magazine-gun reloads and far explosions. Each has its own generator.
	_save("pistol_shot_far.wav", _pistol_shot_far())
	_save("smg_shot_far.wav", _smg_shot_far())
	_save("carbine_shot_far.wav", _carbine_shot_far())
	_save("rifle_shot_far.wav", _rifle_shot_far())
	_save("hand_cannon_shot_far.wav", _hand_cannon_shot_far())
	_save("shotgun_shot_far.wav", _shotgun_shot_far())
	_save("sniper_shot_far.wav", _sniper_shot_far())
	_save("frag_explosion_far.wav", _frag_explosion_far())
	_save("bomb_explosion_far.wav", _bomb_explosion_far())
	_save("pistol_mag_out.wav", _pistol_mag_out())
	_save("pistol_mag_in.wav", _pistol_mag_in())
	_save("pistol_charge.wav", _pistol_charge())
	_save("hand_cannon_mag_out.wav", _hand_cannon_mag_out())
	_save("hand_cannon_mag_in.wav", _hand_cannon_mag_in())
	_save("hand_cannon_charge.wav", _hand_cannon_charge())
	_save("smg_mag_out.wav", _smg_mag_out())
	_save("smg_mag_in.wav", _smg_mag_in())
	_save("smg_charge.wav", _smg_charge())
	_save("carbine_mag_out.wav", _carbine_mag_out())
	_save("carbine_mag_in.wav", _carbine_mag_in())
	_save("carbine_charge.wav", _carbine_charge())
	_save("rifle_mag_out.wav", _rifle_mag_out())
	_save("rifle_mag_in.wav", _rifle_mag_in())
	_save("rifle_charge.wav", _rifle_charge())
	_save("sniper_mag_out.wav", _sniper_mag_out())
	_save("sniper_mag_in.wav", _sniper_mag_in())
	_save("sniper_charge.wav", _sniper_charge())
	quit()


## A gunshot: a sharp noise crack, a noisy body and a low thump that drops in pitch.
func _gunshot(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var samples := _silence(0.35)
	var low_pass := 0.0
	var phase := 0.0
	for i in samples.size():
		var t := float(i) / MIX_RATE
		var noise := rng.randf_range(-1.0, 1.0)
		low_pass += (noise - low_pass) * 0.12
		var crack := noise * exp(-t * 70.0)
		var body := low_pass * exp(-t * 11.0) * 3.0
		phase += TAU * lerpf(110.0, 45.0, minf(t * 6.0, 1.0)) / MIX_RATE
		var thump := sin(phase) * exp(-t * 16.0)
		samples[i] = crack * 0.5 + body * 0.8 + thump * 0.8
	return _finish(samples)


## A footstep on grit: a bright heel scuff, a quieter toe scuff 25 ms later,
## and a short mid-range tap. Mostly mid and high frequencies, so it carries
## on laptop speakers as well as headphones.
func _footstep(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var samples := _silence(0.12)
	var low_pass := 0.0
	var tap_pitch := rng.randf_range(170.0, 240.0)
	var toe_delay := rng.randf_range(0.02, 0.03)
	for i in samples.size():
		var t := float(i) / MIX_RATE
		var noise := rng.randf_range(-1.0, 1.0)
		low_pass += (noise - low_pass) * 0.25
		var bright := noise - low_pass  # high-passed: the gritty part
		var heel := bright * exp(-t * 60.0)
		var toe := bright * exp(-(t - toe_delay) * 70.0) * 0.6 if t >= toe_delay else 0.0
		var tap := sin(TAU * tap_pitch * t) * exp(-t * 45.0)
		samples[i] = heel + toe + tap * 0.5
	return _finish(samples)


## The click of pulling the trigger on an empty gun.
func _click(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var samples := _silence(0.06)
	for i in samples.size():
		var t := float(i) / MIX_RATE
		samples[i] = rng.randf_range(-1.0, 1.0) * exp(-t * 400.0) * 0.6 + sin(TAU * 3200.0 * t) * exp(-t * 250.0) * 0.5
	return _finish(samples)


## A metallic clack for each reload step: two quick hits of bright noise and a ring.
func _clack(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var samples := _silence(0.15)
	var low_pass := 0.0
	for i in samples.size():
		var t := float(i) / MIX_RATE
		var noise := rng.randf_range(-1.0, 1.0)
		low_pass += (noise - low_pass) * 0.3
		var bright := noise - low_pass
		var hits := exp(-t * 90.0) + (exp(-(t - 0.035) * 90.0) * 0.7 if t >= 0.035 else 0.0)
		samples[i] = bright * hits + sin(TAU * 700.0 * t) * exp(-t * 50.0) * 0.4
	return _finish(samples)


## The planted bomb's beep: a short, high square-wave pip, easy to pick out
## over gunfire (most energy around 2 kHz).
func _bomb_beep() -> PackedFloat32Array:
	var samples := _silence(0.09)
	for i in samples.size():
		var t := float(i) / MIX_RATE
		var square := signf(sin(TAU * 1950.0 * t)) * 0.6 + sin(TAU * 1950.0 * t) * 0.4
		var envelope := minf(t / 0.004, 1.0) * exp(-maxf(t - 0.05, 0.0) * 120.0)
		samples[i] = square * envelope
	return _finish(samples)


## One key press while planting: a plastic click and a keypad blip.
func _keypad_press(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var samples := _silence(0.08)
	for i in samples.size():
		var t := float(i) / MIX_RATE
		var click := rng.randf_range(-1.0, 1.0) * exp(-t * 500.0)
		var blip := sin(TAU * 2600.0 * t) * (exp(-maxf(t - 0.01, 0.0) * 60.0) if t >= 0.01 else 0.0)
		samples[i] = click * 0.6 + blip * 0.5
	return _finish(samples)


## One snip while defusing: a dry metal click and a short ring.
func _wire_click(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var samples := _silence(0.07)
	var low_pass := 0.0
	for i in samples.size():
		var t := float(i) / MIX_RATE
		var noise := rng.randf_range(-1.0, 1.0)
		low_pass += (noise - low_pass) * 0.35
		samples[i] = (noise - low_pass) * exp(-t * 300.0) + sin(TAU * 3400.0 * t) * exp(-t * 90.0) * 0.35
	return _finish(samples)


## The bomb going off: a crack, a roar of low noise that rolls off slowly and
## a deep thump that drops in pitch.
func _explosion(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var samples := _silence(1.8)
	var low_pass := 0.0
	var lower_pass := 0.0
	var phase := 0.0
	for i in samples.size():
		var t := float(i) / MIX_RATE
		var noise := rng.randf_range(-1.0, 1.0)
		low_pass += (noise - low_pass) * 0.08
		lower_pass += (low_pass - lower_pass) * 0.05
		var crack := noise * exp(-t * 40.0)
		var roar := low_pass * exp(-t * 3.0) * 4.0 + lower_pass * exp(-t * 1.8) * 12.0
		phase += TAU * lerpf(70.0, 28.0, minf(t * 2.0, 1.0)) / MIX_RATE
		var thump := sin(phase) * exp(-t * 4.0)
		samples[i] = crack * 0.35 + roar * 0.7 + thump * 0.9
	return _finish(samples)


## A footstep on loose gravel: a heel crunch and a toe crunch 25-35 ms later, each
## made of rough high-passed noise and a crackle of many tiny random grains.
## Rougher and more broadband than the hard-floor `_footstep`.
func _footstep_gravel(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var samples := _silence(0.15)
	var low_pass := 0.0
	var grain := 0.0
	var toe_delay := rng.randf_range(0.025, 0.035)
	var grain_density := rng.randf_range(0.10, 0.16)
	for i in samples.size():
		var t := float(i) / MIX_RATE
		var noise := rng.randf_range(-1.0, 1.0)
		low_pass += (noise - low_pass) * 0.18
		var bright := noise - low_pass
		var toe := exp(-(t - toe_delay) * 45.0) * 0.75 if t >= toe_delay else 0.0
		var envelope := exp(-t * 40.0) + toe
		grain *= 0.5  # each grain is a very short click
		if rng.randf() < grain_density * minf(envelope, 1.0):
			grain += rng.randf_range(-1.0, 1.0) * 1.6
		samples[i] = bright * envelope * 0.5 + grain * envelope
	return _finish(samples)


## A boot on a metal plate: a sharp heel tick, a quieter toe tick and a short
## ring of three inharmonic partials (about 420, 1130 and 2350 Hz, a bit different
## in every variant).
func _footstep_metal(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var samples := _silence(0.22)
	var low_pass := 0.0
	var low_ring := 420.0 * rng.randf_range(0.92, 1.08)
	var mid_ring := 1130.0 * rng.randf_range(0.92, 1.08)
	var high_ring := 2350.0 * rng.randf_range(0.92, 1.08)
	var toe_delay := rng.randf_range(0.03, 0.045)
	for i in samples.size():
		var t := float(i) / MIX_RATE
		var noise := rng.randf_range(-1.0, 1.0)
		low_pass += (noise - low_pass) * 0.3
		var bright := noise - low_pass
		var toe := exp(-(t - toe_delay) * 300.0) * 0.4 if t >= toe_delay else 0.0
		var tick := bright * (exp(-t * 250.0) + toe)
		var ring := sin(TAU * low_ring * t) * exp(-t * 26.0) * 0.3
		ring += sin(TAU * mid_ring * t) * exp(-t * 30.0) * 0.6
		ring += sin(TAU * high_ring * t) * exp(-t * 36.0) * 0.5
		samples[i] = tick * 0.9 + ring
	return _finish(samples)


## A boot on wooden planks or a crate: a hollow knock, made of a low-mid thump,
## a boxy resonance and a little high-passed noise for the contact. Duller than
## the metal one.
func _footstep_wood(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var samples := _silence(0.15)
	var fast_pass := 0.0
	var faster_pass := 0.0
	var slow_pass := 0.0
	var thump_pitch := rng.randf_range(150.0, 220.0)
	var box_pitch := rng.randf_range(600.0, 900.0)
	var toe_delay := rng.randf_range(0.03, 0.04)
	for i in samples.size():
		var t := float(i) / MIX_RATE
		var noise := rng.randf_range(-1.0, 1.0)
		fast_pass += (noise - fast_pass) * 0.7
		faster_pass += (fast_pass - faster_pass) * 0.7  # two low-passes in a row roll off the highs faster
		slow_pass += (noise - slow_pass) * 0.3
		var band := (faster_pass - slow_pass) * 3.0  # noise between about 1 and 3 kHz: duller than the metal tick
		var thump := sin(TAU * thump_pitch * t) * exp(-t * 50.0)
		var box := sin(TAU * box_pitch * t) * exp(-t * 65.0)
		var box_overtone := sin(TAU * box_pitch * 2.1 * t) * exp(-t * 80.0)
		var contact := band * exp(-t * 130.0)
		var toe := sin(TAU * box_pitch * 0.8 * t) * exp(-(t - toe_delay) * 90.0) * 0.3 if t >= toe_delay else 0.0
		samples[i] = thump * 0.35 + box * 0.6 + box_overtone * 0.35 + contact + toe
	return _finish(samples)


## A bullet into concrete or stone: a very sharp crack that dies in a few
## milliseconds and a gritty tail of sparse debris clicks.
func _impact_hard(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var samples := _silence(0.12)
	var low_pass := 0.0
	var debris := 0.0
	for i in samples.size():
		var t := float(i) / MIX_RATE
		var noise := rng.randf_range(-1.0, 1.0)
		low_pass += (noise - low_pass) * 0.2
		var crack := (noise - low_pass) * exp(-t * 400.0)
		debris *= 0.55
		if t > 0.004 and rng.randf() < 0.008 * exp(-t * 18.0):
			debris += rng.randf_range(-1.0, 1.0) * 0.8
		samples[i] = crack + debris * 0.7
	return _finish(samples)


## A bullet into dirt or gravel: a dull thud of low-passed noise and a short
## scatter of grains.
func _impact_gravel(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var samples := _silence(0.15)
	var low_pass := 0.0
	var grain := 0.0
	for i in samples.size():
		var t := float(i) / MIX_RATE
		var noise := rng.randf_range(-1.0, 1.0)
		low_pass += (noise - low_pass) * 0.2
		var thud := low_pass * exp(-t * 55.0) * 2.2
		grain *= 0.5
		if t > 0.01 and rng.randf() < 0.03 * exp(-t * 22.0):
			grain += rng.randf_range(-1.0, 1.0)
		samples[i] = thud + grain * 1.2 * exp(-t * 15.0)
	return _finish(samples)


## A bullet into metal: a sharp transient and a bright ricochet "ping" of three
## partials between 2 and 4 kHz that glide down a little as they fade.
func _impact_metal(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var samples := _silence(0.35)
	var low_pass := 0.0
	var phase_a := 0.0
	var phase_b := 0.0
	var phase_c := 0.0
	for i in samples.size():
		var t := float(i) / MIX_RATE
		var noise := rng.randf_range(-1.0, 1.0)
		low_pass += (noise - low_pass) * 0.25
		var glide := lerpf(1.0, 0.94, minf(t * 5.0, 1.0))
		phase_a += TAU * 2100.0 * glide / MIX_RATE
		phase_b += TAU * 2950.0 * glide / MIX_RATE
		phase_c += TAU * 3800.0 * glide / MIX_RATE
		var tick := (noise - low_pass) * exp(-t * 450.0)
		var ping := sin(phase_a) * exp(-t * 12.0) * 0.5
		ping += sin(phase_b) * exp(-t * 15.0) * 0.45
		ping += sin(phase_c) * exp(-t * 20.0) * 0.35
		samples[i] = tick * 0.9 + ping
	return _finish(samples)


## A bullet into wood: a mid "thock" that drops in pitch (300-600 Hz) and a
## splintery burst of high-passed noise with a few crackles.
func _impact_wood(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var samples := _silence(0.15)
	var low_pass := 0.0
	var phase := 0.0
	var splinter := 0.0
	for i in samples.size():
		var t := float(i) / MIX_RATE
		var noise := rng.randf_range(-1.0, 1.0)
		low_pass += (noise - low_pass) * 0.3
		phase += TAU * lerpf(600.0, 320.0, minf(t * 25.0, 1.0)) / MIX_RATE
		var thock := sin(phase) * exp(-t * 45.0)
		var spray := (noise - low_pass) * exp(-t * 90.0)
		splinter *= 0.5
		if t > 0.008 and rng.randf() < 0.012 * exp(-t * 25.0):
			splinter += rng.randf_range(-1.0, 1.0)
		samples[i] = thock * 0.7 + spray * 1.2 + splinter * 0.6
	return _finish(samples)


## A bullet hitting a body: a fleshy thwack, a low-mid thump (about 150 Hz,
## sinking) under a muffled slap of low-passed noise.
func _hit_body(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var samples := _silence(0.12)
	var low_pass := 0.0
	var phase := 0.0
	for i in samples.size():
		var t := float(i) / MIX_RATE
		var noise := rng.randf_range(-1.0, 1.0)
		low_pass += (noise - low_pass) * 0.25
		phase += TAU * lerpf(180.0, 120.0, minf(t * 15.0, 1.0)) / MIX_RATE
		var thump := sin(phase) * exp(-t * 38.0)
		var slap := low_pass * exp(-t * 60.0) * 2.5
		samples[i] = thump * 0.8 + slap * 0.9
	return _finish(samples)


## A headshot: a bright, crunchy "dink". A short metallic tone around 2.8 kHz
## with a quick decay, on top of a burst of crunchy (sample-and-hold) noise.
## Much brighter than `_hit_body`.
func _hit_head(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var samples := _silence(0.25)
	var low_pass := 0.0
	var crunch := 0.0
	for i in samples.size():
		var t := float(i) / MIX_RATE
		var noise := rng.randf_range(-1.0, 1.0)
		low_pass += (noise - low_pass) * 0.2
		if i % 3 == 0:
			crunch = rng.randf_range(-1.0, 1.0)  # held for 3 samples: a gritty, crushed noise
		var burst := (crunch * 0.7 + (noise - low_pass) * 0.5) * exp(-t * 110.0)
		var dink := sin(TAU * 2800.0 * t) * exp(-t * 22.0)
		dink += sin(TAU * 3720.0 * t) * exp(-t * 32.0) * 0.4
		dink += sin(TAU * 5600.0 * t) * exp(-t * 45.0) * 0.2
		samples[i] = burst * 0.9 + dink * 0.8
	return _finish(samples)


## A menu hover: a tiny soft triangle-wave tick around 2 kHz. Like every sound
## it is normalised to the same peak, so play it with a lower volume.
func _ui_hover() -> PackedFloat32Array:
	var samples := _silence(0.03)
	for i in samples.size():
		var t := float(i) / MIX_RATE
		samples[i] = _triangle(2000.0 * t) * minf(t / 0.002, 1.0) * exp(-t * 110.0)
	return _finish(samples)


## A menu button press: a short square blip around 1.2 kHz with a little noise click.
func _ui_click(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var samples := _silence(0.06)
	var low_pass := 0.0
	for i in samples.size():
		var t := float(i) / MIX_RATE
		var noise := rng.randf_range(-1.0, 1.0)
		low_pass += (noise - low_pass) * 0.3
		var blip := _square(1200.0 * t) * minf(t / 0.002, 1.0) * exp(-t * 55.0)
		var click := (noise - low_pass) * exp(-t * 500.0)
		samples[i] = blip * 0.6 + click * 0.5
	return _finish(samples)


## "Go!": two short square beeps, 880 Hz and then 1320 Hz, with a short gap.
func _round_start() -> PackedFloat32Array:
	var samples := _silence(0.45)
	_add_note(samples, 0.0, 0.13, 880.0, false, 8.0)
	_add_note(samples, 0.19, 0.24, 1320.0, false, 8.0)
	return _finish(samples)


## A bright happy stinger for winning a round: three quick rising square notes
## (C5, E5, G5), the last one held a little longer.
func _round_won() -> PackedFloat32Array:
	var samples := _silence(0.6)
	_add_note(samples, 0.0, 0.15, 523.0, false, 10.0)
	_add_note(samples, 0.15, 0.15, 659.0, false, 10.0)
	_add_note(samples, 0.3, 0.3, 784.0, false, 7.0)
	return _finish(samples)


## A darker, slower stinger for losing a round: three falling triangle notes (G4, E4, C4).
func _round_lost() -> PackedFloat32Array:
	var samples := _silence(0.6)
	_add_note(samples, 0.0, 0.18, 392.0, true, 6.0)
	_add_note(samples, 0.18, 0.18, 330.0, true, 6.0)
	_add_note(samples, 0.36, 0.24, 262.0, true, 6.0)
	return _finish(samples)


## "The bomb has been planted": a two-tone alarm, four short square tones
## alternating 740 Hz and 980 Hz.
func _bomb_planted_alert() -> PackedFloat32Array:
	var samples := _silence(0.7)
	for i in 4:
		_add_note(samples, i * 0.16, 0.15, 740.0 if i % 2 == 0 else 980.0, false, 3.0)
	return _finish(samples)


# ---- M7: the arsenal ------------------------------------------------------------
# Every weapon has to be told apart by ear, so each gun sits in its own corner of
# the sound: pitch of the crack, weight of the boom and length of the tail.
#
#   pistol       light and snappy: high crack, almost no bass, short tail
#   SMG          small papery rattle, very short so a fast spray doesn't smear
#   carbine      the rifle's tighter, higher cousin: less bass, shorter
#   rifle        (the old rifle_shot.wav, bassy and mid-length)
#   hand cannon  one deep boom with a metallic ring
#   shotgun      a wide blast: lots of low rumble and a long roll
#   sniper       a very sharp crack with long echoes (the loudest gun)
#
# Like every sound they are normalised to the same peak, so how loud a weapon is
# comes from the playback volume. Only the two sounds that should always stay
# quiet (the pistol reload and the flash's ringing) are made quieter in the file.


## The pistol: a light, snappy, high crack (most energy above 1 kHz), a small "tok"
## of the slide at about 400 Hz and very little bass. Short tail.
func _pistol_shot(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var samples := _silence(0.25)
	_add_noise(samples, rng, 0.0, 1.0, 190.0, 9000.0, 1800.0)
	_add_noise(samples, rng, 0.0, 1.4, 45.0, 3500.0, 500.0)
	_add_tone(samples, 0.0, 0.8, 430.0, 200.0, 0.03, 40.0)
	_add_tone(samples, 0.0, 0.2, 200.0, 100.0, 0.05, 30.0)
	_add_noise(samples, rng, 0.01, 0.45, 14.0, 2500.0, 350.0)
	return _finish_arsenal(samples)


## The hand cannon (M13 redesign): one heavy boom with a hard crack on top. A sharp
## crack (noise from 1.5 kHz up, two metallic rings at 1.2 and 2.6 kHz and a mid snap
## around 1-4 kHz that holds for 40 ms, so about a quarter of the energy sits there), a thick
## low body, a deep sinking sub thump (72 Hz down to 28 Hz), the old 1.1 kHz metallic ring and
## two room slaps. Pushed through a soft clipper, so it hits as hard as it can. About 0.65 s.
func _hand_cannon_shot() -> PackedFloat32Array:
	var rng := _rng_for("hand_cannon_shot.wav")
	var samples := _silence(0.65)
	_add_noise(samples, rng, 0.0, 3.0, 80.0, 12000.0, 1500.0, 0.0003)
	_add_noise(samples, rng, 0.0, 4.6, 22.0, 4200.0, 900.0, 0.0004)
	_add_noise(samples, rng, 0.0, 2.0, 13.0, 800.0)
	_add_noise(samples, rng, 0.0, 1.4, 7.0, 260.0)
	_add_tone(samples, 0.0, 1.4, 72.0, 28.0, 0.25, 7.0, 0.001, 0.6)
	_add_tone(samples, 0.0, 1.8, 1200.0, 1100.0, 0.1, 20.0)
	_add_tone(samples, 0.0, 1.0, 2600.0, 2500.0, 0.1, 26.0)
	_add_echoes(samples, PackedFloat32Array([0.11, 0.26]), PackedFloat32Array([0.3, 0.17]), 900.0, 120.0)
	_saturate(samples, 1.8)
	return _finish_loudness(samples, -9.0)


## The SMG (M13 redesign): a fast, light, papery shot, easy to read in a fight even at
## 13 rounds a second. A very short crack, a thin body of mid-range noise (500 Hz to
## 4 kHz, with next to no bass) that holds for about 0.1 s, a paper rustle of crackle and a
## small "tick" tone at 1.4 kHz. Done in 0.2 s.
func _smg_shot() -> PackedFloat32Array:
	var rng := _rng_for("smg_shot.wav")
	var samples := _silence(0.18)
	_add_noise(samples, rng, 0.0, 1.0, 250.0, 6000.0, 1800.0, 0.0003)
	_add_noise(samples, rng, 0.0, 1.8, 34.0, 3200.0, 500.0, 0.0006)
	_add_noise(samples, rng, 0.012, 0.6, 28.0, 2800.0, 900.0, 0.002)
	_add_tone(samples, 0.0, 0.6, 1400.0, 1000.0, 0.04, 40.0, 0.0005)
	_add_crackle(samples, rng, 0.0, 0.06, 0.25, 0.25, 30.0)
	_low_pass(samples, 4500.0, 2)
	return _finish_loudness(samples, -9.0)


## The carbine: the rifle's recipe made tighter and higher. The same three parts
## (crack, body, thump), but the body sits above 250 Hz, the thump starts at
## 165 Hz instead of 110 and everything is gone sooner, so it has far less bass.
func _carbine_shot(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var samples := _silence(0.3)
	_add_noise(samples, rng, 0.0, 1.0, 95.0, 12000.0, 1200.0)
	_add_noise(samples, rng, 0.0, 1.5, 22.0, 1500.0, 250.0)
	_add_tone(samples, 0.0, 1.1, 165.0, 85.0, 0.05, 28.0, 0.001, 0.2)
	_add_noise(samples, rng, 0.01, 0.35, 11.0, 1800.0, 300.0)
	return _finish_arsenal(samples)


## The shotgun: a big, wide blast. Three crack bursts a few milliseconds apart (the
## spread), a heavy body, a long low rumble that rolls out for most of 0.8 s, a deep
## sub and three dull room echoes. Noisier and longer than the hand cannon's boom.
func _shotgun_shot(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var samples := _silence(0.8)
	_add_noise(samples, rng, 0.0, 1.0, 45.0, 20000.0, 300.0, 0.001)
	_add_noise(samples, rng, 0.004, 0.8, 45.0, 20000.0, 300.0, 0.001)
	_add_noise(samples, rng, 0.011, 0.6, 45.0, 20000.0, 300.0, 0.001)
	_add_noise(samples, rng, 0.0, 2.6, 10.0, 3200.0, 250.0, 0.002)
	_add_noise(samples, rng, 0.0, 1.6, 7.0, 900.0, 0.0, 0.002)
	_add_noise(samples, rng, 0.02, 2.2, 2.8, 420.0, 0.0, 0.004)
	_add_tone(samples, 0.0, 2.0, 80.0, 32.0, 0.3, 5.0, 0.002, 0.3)
	_add_echoes(samples, PackedFloat32Array([0.13, 0.27, 0.45]), PackedFloat32Array([0.4, 0.28, 0.16]), 1200.0, 120.0)
	_saturate(samples, 1.5)
	return _finish_arsenal(samples)


## Pumping the shotgun: two mechanical clacks, the slide back (duller, with a
## scrape) at 0.03 s and forward (sharper) at 0.2 s.
func _shotgun_pump(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var samples := _silence(0.35)
	_add_noise(samples, rng, 0.0, 0.3, 30.0, 3500.0, 900.0, 0.012)
	_add_clack(samples, rng, 0.03, 0.9, 700.0, 150.0)
	_add_noise(samples, rng, 0.14, 0.2, 40.0, 3500.0, 900.0, 0.01)
	_add_clack(samples, rng, 0.2, 1.0, 1100.0, 190.0)
	return _finish_arsenal(samples)


## A shell going into the shotgun: a metallic click, the brass ring of the case
## and a short thunk as it seats.
func _shell_insert(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var samples := _silence(0.15)
	_add_clack(samples, rng, 0.0, 0.8, 2400.0, 140.0)
	_add_tone(samples, 0.03, 0.5, 190.0, 110.0, 0.03, 70.0)
	_add_noise(samples, rng, 0.03, 0.4, 90.0, 800.0)
	return _finish_arsenal(samples)


## The sniper rifle: the sharpest, loudest crack of all. A very short wideband
## snap, a hard crack, a body, a long low roll and a deep thump, then four echoes
## that get darker and quieter for a second. Soft-clipped for extra loudness.
func _sniper_shot(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var samples := _silence(1.2)
	_add_noise(samples, rng, 0.0, 3.5, 110.0, 20000.0, 800.0)
	_add_noise(samples, rng, 0.0, 2.0, 400.0, 20000.0, 4000.0)
	_add_noise(samples, rng, 0.0, 2.0, 12.0, 1800.0, 150.0)
	_add_noise(samples, rng, 0.05, 0.7, 2.6, 450.0)
	_add_tone(samples, 0.0, 0.4, 95.0, 40.0, 0.12, 8.0, 0.001, 0.4)
	_add_echoes(samples, PackedFloat32Array([0.17, 0.34, 0.58, 0.88]), PackedFloat32Array([0.9, 0.7, 0.5, 0.32]), 3000.0, 200.0)
	_saturate(samples, 3.0)
	return _finish_arsenal(samples)


## Cycling the sniper's bolt: four clicks, up (a light tick), back (a scrape and a
## clack), forward (a sharper clack) and down (a heavy thunk).
func _sniper_bolt(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var samples := _silence(0.6)
	_add_clack(samples, rng, 0.0, 0.55, 1900.0, 260.0)
	_add_noise(samples, rng, 0.1, 0.3, 30.0, 3500.0, 900.0, 0.012)
	_add_clack(samples, rng, 0.16, 0.9, 900.0, 150.0)
	_add_clack(samples, rng, 0.33, 1.0, 1000.0, 170.0)
	_add_clack(samples, rng, 0.48, 0.85, 1500.0, 120.0)
	_add_tone(samples, 0.48, 0.5, 150.0, 85.0, 0.04, 50.0)
	return _finish_arsenal(samples)


## Reloading the pistol: the magazine clicks in, then the slide snaps shut (a
## sharper, higher hit). Made 6 dB quieter than the rifle's reload, in the file.
func _pistol_reload(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var samples := _silence(0.4)
	_add_clack(samples, rng, 0.0, 0.8, 1400.0, 220.0)
	_add_clack(samples, rng, 0.24, 1.0, 2200.0, 300.0)
	_add_tone(samples, 0.24, 0.3, 2800.0, 2700.0, 0.1, 45.0)
	return _finish_arsenal(samples, 0.5)


## The knife through the air: a quick, bright whoosh of noise whose cutoff sweeps up
## from 500 Hz to 4.2 kHz and down again.
func _knife_swing(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var samples := _silence(0.2)
	_add_whoosh(samples, rng, 0.0, 0.2, 1.0, 500.0, 4200.0, 1200.0, 0.4)
	return _finish_arsenal(samples)


## The knife going in: a dull stab thud (a low sinking thump and a muffled slap)
## with a short, high slice of noise on top.
func _knife_hit(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var samples := _silence(0.2)
	_add_tone(samples, 0.0, 1.0, 150.0, 70.0, 0.04, 38.0)
	_add_noise(samples, rng, 0.0, 1.3, 55.0, 700.0)
	_add_noise(samples, rng, 0.0, 0.5, 160.0, 9000.0, 3000.0)
	_add_whoosh(samples, rng, 0.0, 0.06, 0.35, 3500.0, 6500.0, 3000.0, 0.3)
	return _finish_arsenal(samples)


## Pulling the grenade's pin: a small metallic ping (3.9 kHz and a partial above it)
## with a tick, then the click of the lever 0.11 s later.
func _grenade_pin(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var samples := _silence(0.25)
	_add_noise(samples, rng, 0.0, 0.6, 500.0, 10000.0, 2500.0)
	_add_tone(samples, 0.0, 0.55, 3900.0, 3800.0, 0.1, 38.0)
	_add_tone(samples, 0.0, 0.3, 5700.0, 5700.0, 1.0, 55.0)
	_add_clack(samples, rng, 0.11, 0.7, 1500.0, 200.0)
	return _finish_arsenal(samples)


## Throwing a grenade: a soft, low whoosh of the arm (the cutoff sweeps between 250
## and 1500 Hz) and a little cloth rustle.
func _grenade_throw(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var samples := _silence(0.25)
	_add_whoosh(samples, rng, 0.0, 0.25, 1.0, 250.0, 1500.0, 400.0, 0.45)
	_add_noise(samples, rng, 0.0, 0.25, 20.0, 1500.0, 400.0, 0.03)
	return _finish_arsenal(samples)


## A grenade bouncing on a hard floor: a hollow metallic clink, three inharmonic
## partials around 1, 1.75 and 2.65 kHz and a small thunk, quite unlike the bright
## ping of a bullet on metal.
func _grenade_bounce(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var samples := _silence(0.15)
	_add_tone(samples, 0.0, 0.9, 960.0, 930.0, 0.1, 34.0)
	_add_tone(samples, 0.0, 0.6, 1750.0, 1720.0, 0.1, 42.0)
	_add_tone(samples, 0.0, 0.45, 2650.0, 2620.0, 0.1, 55.0)
	_add_tone(samples, 0.0, 0.3, 230.0, 160.0, 0.02, 70.0)
	_add_noise(samples, rng, 0.0, 0.6, 600.0, 8000.0, 1500.0)
	return _finish_arsenal(samples)


## The frag grenade: a strong explosion, a bit smaller than the bomb's (1.2 s against
## 1.8 s, the thump starts at 88 Hz instead of 70 and there is less deep roar) with
## a long crackle of debris on top.
func _frag_explosion(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var samples := _silence(1.2)
	_add_noise(samples, rng, 0.0, 1.0, 55.0, 20000.0)
	_add_noise(samples, rng, 0.0, 1.6, 9.0, 1400.0)
	_add_noise(samples, rng, 0.0, 2.4, 4.5, 320.0)
	_add_tone(samples, 0.0, 2.4, 88.0, 36.0, 0.3, 5.0, 0.001, 0.25)
	_add_crackle(samples, rng, 0.05, 1.0, 0.55, 0.09, 3.0)
	return _finish_arsenal(samples)


## The flashbang: a very sharp, bright bang. A hard crack above 3.5 kHz, a mid
## body, two hot rings around 4.5 and 6.7 kHz, a bit of punch and a short fizz.
func _flash_pop(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var samples := _silence(0.4)
	_add_noise(samples, rng, 0.0, 1.5, 150.0, 20000.0, 3500.0)
	_add_noise(samples, rng, 0.0, 0.9, 40.0, 12000.0, 1500.0)
	_add_tone(samples, 0.0, 0.8, 4600.0, 4300.0, 0.1, 30.0)
	_add_tone(samples, 0.0, 0.5, 6800.0, 6300.0, 0.1, 40.0)
	_add_tone(samples, 0.0, 0.7, 320.0, 150.0, 0.04, 40.0)
	_add_noise(samples, rng, 0.01, 0.35, 9.0, 6000.0, 1200.0)
	return _finish_arsenal(samples)


## The ringing in your ears after a flash: a near-pure tone at 3.5 kHz with a slight
## beat (a second, weaker tone 12 Hz higher) that fades away over 3 s. Quiet in the
## file (-14 dB) and not bit-crushed, so it stays a clean tone.
func _flash_ring() -> PackedFloat32Array:
	var samples := _silence(3.2)
	for i in samples.size():
		var t := float(i) / MIX_RATE
		var envelope := minf(t / 0.03, 1.0) * exp(-t * 1.4)
		var tone := sin(TAU * 3500.0 * t) + sin(TAU * 3512.0 * t) * 0.35
		samples[i] = tone * envelope
	return _finish_arsenal(samples, 0.2, false)


## The smoke grenade's hiss: a soft "pop" and a burst of gas (noise between 1.8 and
## 9.5 kHz) that starts loud, settles to about a third and flutters a little before
## it dies away over the last 0.6 s.
func _smoke_hiss(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var samples := _silence(2.0)
	var fast := 0.0
	var slow := 0.0
	var flutter := 0.0
	var a_fast := _alpha(9500.0)
	var a_slow := _alpha(1800.0)
	for i in samples.size():
		var t := float(i) / MIX_RATE
		var noise := rng.randf_range(-1.0, 1.0)
		fast += (noise - fast) * a_fast
		slow += (noise - slow) * a_slow
		flutter += (rng.randf_range(-1.0, 1.0) - flutter) * 0.0006
		var level := 0.32 + 0.68 * exp(-t * 4.5)
		var envelope := minf(t / 0.02, 1.0) * level * (1.0 + flutter * 14.0) * clampf((2.0 - t) / 0.6, 0.0, 1.0)
		samples[i] = (fast - slow) * envelope * 1.6
	_add_tone(samples, 0.0, 0.8, 120.0, 60.0, 0.1, 25.0)
	return _finish_arsenal(samples)


## Buying something: a pleasant two-note blip, C6 then G6 (a fifth up), soft
## triangle waves with a little sparkle on the second note.
func _buy() -> PackedFloat32Array:
	var samples := _silence(0.2)
	_add_note(samples, 0.0, 0.09, 1047.0, true, 14.0)
	_add_note(samples, 0.085, 0.115, 1568.0, true, 12.0)
	_add_tone(samples, 0.085, 0.12, 3136.0, 3136.0, 1.0, 30.0)
	return _finish_arsenal(samples)


## "Can't buy that": a short low buzz, two pulses that fall from 165 Hz to 125 Hz,
## made of a narrow pulse wave and a slightly out-of-tune saw wave under a low-pass.
func _buy_denied() -> PackedFloat32Array:
	var samples := _silence(0.2)
	var low_pass := 0.0
	var alpha := _alpha(2600.0)
	for i in samples.size():
		var t := float(i) / MIX_RATE
		var second := t >= 0.105
		var frequency := 125.0 if second else 165.0
		var local_t := t - 0.105 if second else t
		var length := 0.095 if second else 0.085
		var envelope := minf(local_t / 0.004, 1.0) * clampf((length - local_t) / 0.01, 0.0, 1.0)
		var pulse := (1.0 if fposmod(frequency * t, 1.0) < 0.1 else -1.0) + 0.8
		var wave := pulse * 0.8 + (fposmod(frequency * 1.03 * t, 1.0) * 2.0 - 1.0) * 0.25
		low_pass += (wave - low_pass) * alpha
		samples[i] = low_pass * envelope
	return _finish_arsenal(samples)


## Picking a gun up off the floor: a rustle of cloth (soft band noise) with a small
## metallic clack in the middle and a second rustle after it.
func _pickup(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var samples := _silence(0.2)
	_add_noise(samples, rng, 0.0, 0.8, 16.0, 2200.0, 350.0, 0.025)
	_add_clack(samples, rng, 0.06, 0.6, 1500.0, 240.0)
	_add_noise(samples, rng, 0.1, 0.4, 25.0, 1800.0, 500.0, 0.01)
	return _finish_arsenal(samples)


# ---- M13: far shots, reloads and far explosions ------------------------------------
# What a shot sounds like from 40 m or more: no crack (the highs don't carry), a soft
# attack, a thump at the family's pitch and a long, dark echo tail. Each is normalised to
# -12 dB short-term loudness, quieter than the close shot, and the longer the gun's
# close shot, the longer its tail:
#
#   pistol       a thin pop, thump 180 Hz, 0.6 s
#   SMG          a small soft pop, 220 Hz, 0.45 s (short: it fires 13 times a second)
#   carbine      a tight thump, 140 Hz, 0.9 s
#   rifle        a deep thump, 100 Hz, with a rolling tail, 1.1 s
#   hand cannon  a heavy boom, 80 Hz, a long echo, 1.4 s
#   shotgun      a wide dull boom, 70 Hz, 1.4 s
#   sniper       a big deep thump, 60 Hz, a small whip of crack and the longest echo, 2.2 s


## The pistol from far away: a thin pop (soft noise around 300-900 Hz), a small thump at
## about 180 Hz and two dark echoes. 0.6 s.
func _pistol_shot_far() -> PackedFloat32Array:
	var rng := _rng_for("pistol_shot_far.wav")
	var samples := _silence(0.6)
	_add_noise(samples, rng, 0.0, 0.7, 24.0, 900.0, 250.0, 0.004)
	_add_noise(samples, rng, 0.004, 0.5, 9.0, 450.0, 0.0, 0.006)
	_add_tone(samples, 0.0, 3.2, 190.0, 165.0, 0.05, 14.0, 0.004, 0.15, PI / 2.0)
	_add_echoes(samples, PackedFloat32Array([0.12, 0.26, 0.42]), PackedFloat32Array([0.45, 0.3, 0.18]), 700.0, 100.0)
	_low_pass(samples, 1100.0, 2)
	return _finish_loudness(samples, -12.0)


## The SMG from far away: a small soft pop (noise below 800 Hz, a short 220 Hz thump) with
## a short, dull echo. 0.45 s, short because the gun fires so fast.
func _smg_shot_far() -> PackedFloat32Array:
	var rng := _rng_for("smg_shot_far.wav")
	var samples := _silence(0.45)
	_add_noise(samples, rng, 0.0, 0.6, 26.0, 800.0, 200.0, 0.004)
	_add_noise(samples, rng, 0.004, 0.4, 11.0, 400.0, 0.0, 0.006)
	_add_tone(samples, 0.0, 2.6, 230.0, 170.0, 0.05, 20.0, 0.004, 0.1, PI / 2.0)
	_add_echoes(samples, PackedFloat32Array([0.09, 0.2, 0.32]), PackedFloat32Array([0.45, 0.28, 0.16]), 650.0, 100.0)
	_low_pass(samples, 1000.0, 2)
	return _finish_loudness(samples, -12.0)


## The carbine from far away: a tight thump at 140 Hz, a soft body of low noise and a
## dark echo that rolls out for most of a second. 0.9 s.
func _carbine_shot_far() -> PackedFloat32Array:
	var rng := _rng_for("carbine_shot_far.wav")
	var samples := _silence(0.9)
	_add_noise(samples, rng, 0.0, 0.7, 16.0, 800.0, 150.0, 0.004)
	_add_noise(samples, rng, 0.005, 0.7, 6.0, 380.0, 0.0, 0.007)
	_add_tone(samples, 0.0, 3.2, 150.0, 128.0, 0.06, 10.0, 0.004, 0.15, PI / 2.0)
	_add_echoes(samples, PackedFloat32Array([0.15, 0.32, 0.52, 0.75]), PackedFloat32Array([0.5, 0.35, 0.22, 0.12]), 650.0, 90.0)
	_low_pass(samples, 950.0, 2)
	return _finish_loudness(samples, -12.0)


## The rifle from far away: a deep thump at 108 Hz sinking to 82 Hz, a soft low body and
## a long rolling tail (three echoes, darker each time). 1.1 s.
func _rifle_shot_far() -> PackedFloat32Array:
	var rng := _rng_for("rifle_shot_far.wav")
	var samples := _silence(1.1)
	_add_noise(samples, rng, 0.0, 0.8, 12.0, 700.0, 100.0, 0.005)
	_add_noise(samples, rng, 0.005, 0.8, 4.5, 320.0, 0.0, 0.007)
	_add_tone(samples, 0.0, 3.4, 108.0, 82.0, 0.1, 8.0, 0.005, 0.2, PI / 2.0)
	_add_echoes(samples, PackedFloat32Array([0.18, 0.38, 0.62, 0.9]), PackedFloat32Array([0.55, 0.4, 0.28, 0.16]), 550.0, 70.0)
	_low_pass(samples, 800.0, 2)
	return _finish_loudness(samples, -12.0)


## The hand cannon from far away: a heavy boom, a thump from 90 Hz down to 66 Hz, a thick
## low roll and a long echo that keeps coming back. 1.4 s.
func _hand_cannon_shot_far() -> PackedFloat32Array:
	var rng := _rng_for("hand_cannon_shot_far.wav")
	var samples := _silence(1.4)
	_add_noise(samples, rng, 0.0, 0.8, 9.0, 600.0, 80.0, 0.005)
	_add_noise(samples, rng, 0.005, 1.1, 3.6, 260.0, 0.0, 0.01)
	_add_tone(samples, 0.0, 3.6, 90.0, 66.0, 0.12, 6.0, 0.005, 0.25, PI / 2.0)
	_add_echoes(samples, PackedFloat32Array([0.2, 0.43, 0.7, 1.0]), PackedFloat32Array([0.6, 0.45, 0.32, 0.2]), 500.0, 60.0)
	_low_pass(samples, 700.0, 2)
	return _finish_loudness(samples, -12.0)


## The shotgun from far away: a wide, dull boom. A thump from 76 Hz down to 56 Hz, a wide
## low roar with a slow attack and three long echoes. 1.4 s.
func _shotgun_shot_far() -> PackedFloat32Array:
	var rng := _rng_for("shotgun_shot_far.wav")
	var samples := _silence(1.4)
	_add_noise(samples, rng, 0.0, 0.9, 7.0, 500.0, 60.0, 0.006)
	_add_noise(samples, rng, 0.006, 1.2, 3.2, 230.0, 0.0, 0.008)
	_add_tone(samples, 0.0, 3.4, 76.0, 56.0, 0.15, 5.0, 0.006, 0.3, PI / 2.0)
	_add_echoes(samples, PackedFloat32Array([0.22, 0.45, 0.72, 1.0]), PackedFloat32Array([0.6, 0.45, 0.3, 0.18]), 450.0, 50.0)
	_low_pass(samples, 600.0, 2)
	return _finish_loudness(samples, -12.0)


## The sniper rifle from far away: a big, deep thump (66 Hz sinking to 48 Hz), a small
## whip of crack left over at 1-2 kHz, a low roar and the longest rolling echo of all
## (five echoes over two seconds). 2.2 s.
func _sniper_shot_far() -> PackedFloat32Array:
	var rng := _rng_for("sniper_shot_far.wav")
	var samples := _silence(2.2)
	_add_noise(samples, rng, 0.0, 0.7, 6.0, 450.0, 50.0, 0.006)
	_add_noise(samples, rng, 0.006, 0.8, 2.4, 220.0, 0.0, 0.01)
	_add_tone(samples, 0.0, 3.8, 66.0, 48.0, 0.15, 4.0, 0.006, 0.3, PI / 2.0)
	_add_echoes(samples, PackedFloat32Array([0.25, 0.52, 0.85, 1.25, 1.7]), PackedFloat32Array([0.6, 0.5, 0.38, 0.26, 0.16]), 480.0, 40.0)
	_low_pass(samples, 800.0, 2)
	# The whip comes after the low-pass, so it keeps its 1-2 kHz (and no echo of its own).
	_add_noise(samples, rng, 0.004, 2.4, 30.0, 2200.0, 1000.0, 0.004)
	return _finish_loudness(samples, -12.0)


## The frag grenade from far away: a rolling rumble. Low noise (below 300 Hz) that swells
## for 20 ms and rolls out, a thump from 75 Hz down to 30 Hz and two long echoes.
## Nothing above 1 kHz. 1.8 s.
func _frag_explosion_far() -> PackedFloat32Array:
	var rng := _rng_for("frag_explosion_far.wav")
	var samples := _silence(1.8)
	_add_noise(samples, rng, 0.0, 0.8, 5.0, 600.0, 60.0, 0.012)
	_add_noise(samples, rng, 0.004, 1.1, 2.6, 240.0, 0.0, 0.014)
	_add_tone(samples, 0.0, 3.0, 75.0, 30.0, 0.3, 3.6, 0.008, 0.2, PI / 2.0)
	_add_echoes(samples, PackedFloat32Array([0.3, 0.65, 1.05]), PackedFloat32Array([0.5, 0.36, 0.22]), 420.0, 45.0)
	_low_pass(samples, 500.0, 2)
	return _finish_loudness(samples, -11.0)


## The bomb from far away: deeper and longer than the grenade. A very low rumble that
## swells for 30 ms and rolls out for nearly three seconds, a thump from 55 Hz down to
## 24 Hz and three long, dark echoes. 2.8 s.
func _bomb_explosion_far() -> PackedFloat32Array:
	var rng := _rng_for("bomb_explosion_far.wav")
	var samples := _silence(2.8)
	_add_noise(samples, rng, 0.0, 0.8, 3.6, 450.0, 40.0, 0.02)
	_add_noise(samples, rng, 0.006, 1.1, 1.8, 180.0, 0.0, 0.02)
	_add_tone(samples, 0.0, 3.2, 55.0, 24.0, 0.4, 2.6, 0.01, 0.2, PI / 2.0)
	_add_echoes(samples, PackedFloat32Array([0.4, 0.85, 1.4, 2.0]), PackedFloat32Array([0.5, 0.4, 0.28, 0.18]), 380.0, 35.0)
	_low_pass(samples, 400.0, 2)
	return _finish_loudness(samples, -11.0)


# Reloads: three sounds per magazine gun, played at 28%, 66% and 80% of the reload (magazine
# out, magazine in, charging). Each is at most 0.35 s and is -14 dB. The families differ in
# pitch (the pitches of `_add_clack`), in scrape (band noise) and in timing:
#
#   rifle        heavy steel, an AK: scrape and clack, a slam, a bolt pulled and slammed
#   carbine      an M4, lighter and higher: a button click and a slide, a crisp click, a scrape
#   SMG          small and plasticky: soft clicks, a quick light cock
#   sniper       heavy: a thick clunk, a deep click, a four-click bolt
#   pistol       small: a click with a tiny drop, a tight snap, a high slide release
#   hand cannon  a heavy pistol: a heavier click, a chunky snap, a heavy two-clack rack


## The rifle's magazine coming out: a heavy steel scrape (noise from 700 Hz to 3.5 kHz) as
## it slides down, then a heavy clack with a deep thunk at 0.11 s. 0.3 s.
func _rifle_mag_out() -> PackedFloat32Array:
	var rng := _rng_for("rifle_mag_out.wav")
	var samples := _silence(0.3)
	_add_noise(samples, rng, 0.0, 0.7, 18.0, 3500.0, 700.0, 0.012)
	_add_clack(samples, rng, 0.11, 1.0, 520.0, 95.0, 38.0, 55.0, 1000.0, 7000.0)
	_add_noise(samples, rng, 0.16, 0.25, 30.0, 2000.0, 500.0, 0.004)
	return _finish_loudness(samples, -14.0)


## The rifle's magazine going in: a hard metallic slam (a loud clack with a deep thunk at
## 130 Hz) and the click of the latch 50 ms later. 0.25 s.
func _rifle_mag_in() -> PackedFloat32Array:
	var rng := _rng_for("rifle_mag_in.wav")
	var samples := _silence(0.25)
	_add_clack(samples, rng, 0.0, 1.0, 640.0, 120.0, 34.0, 45.0, 1000.0, 7000.0)
	_add_noise(samples, rng, 0.0, 0.5, 40.0, 1800.0, 400.0, 0.001)
	_add_clack(samples, rng, 0.055, 0.55, 1500.0, 220.0)
	return _finish_loudness(samples, -14.0)


## The rifle's bolt: pulled back (a scrape and a clack, quieter) and slammed forward 0.12 s
## later (a bigger clack with a thunk at 150 Hz). 0.3 s.
func _rifle_charge() -> PackedFloat32Array:
	var rng := _rng_for("rifle_charge.wav")
	var samples := _silence(0.3)
	_add_noise(samples, rng, 0.0, 0.35, 28.0, 3500.0, 800.0, 0.008)
	_add_clack(samples, rng, 0.02, 0.6, 520.0, 100.0, 40.0, 60.0, 1000.0, 6000.0)
	_add_clack(samples, rng, 0.14, 1.0, 700.0, 140.0, 34.0, 50.0, 1000.0, 7000.0)
	_add_noise(samples, rng, 0.14, 0.4, 40.0, 1800.0, 400.0, 0.001)
	return _finish_loudness(samples, -14.0)


## The carbine's magazine coming out: the release button's click (high, short) and the
## magazine's light slide (band noise from 2 kHz to 5 kHz) after it. 0.25 s.
func _carbine_mag_out() -> PackedFloat32Array:
	var rng := _rng_for("carbine_mag_out.wav")
	var samples := _silence(0.25)
	_add_clack(samples, rng, 0.0, 0.8, 2400.0, 300.0, 70.0, 140.0, 2500.0, 9000.0)
	_add_noise(samples, rng, 0.04, 0.8, 22.0, 5000.0, 2000.0, 0.008)
	return _finish_loudness(samples, -14.0)


## The carbine's magazine going in: one crisp, high click with a short ring at 2 kHz. 0.15 s.
func _carbine_mag_in() -> PackedFloat32Array:
	var rng := _rng_for("carbine_mag_in.wav")
	var samples := _silence(0.15)
	_add_clack(samples, rng, 0.0, 1.0, 2000.0, 260.0, 60.0, 100.0, 2000.0, 9000.0)
	_add_tone(samples, 0.0, 0.3, 3300.0, 3200.0, 0.1, 80.0)
	return _finish_loudness(samples, -14.0)


## The carbine's charging handle: a scrape (band noise from 1.5 kHz to 4.5 kHz) as it is
## pulled and a sharp bolt release 0.12 s later, high and short. 0.28 s.
func _carbine_charge() -> PackedFloat32Array:
	var rng := _rng_for("carbine_charge.wav")
	var samples := _silence(0.28)
	_add_noise(samples, rng, 0.0, 0.7, 14.0, 4500.0, 1500.0, 0.015)
	_add_clack(samples, rng, 0.13, 1.0, 2600.0, 320.0, 60.0, 100.0, 2500.0, 9000.0)
	return _finish_loudness(samples, -14.0)


## The SMG's magazine coming out: a soft, plasticky click (noise from 1.2 to 4 kHz, a small
## dull ring at 1.3 kHz and a tiny thunk). 0.12 s.
func _smg_mag_out() -> PackedFloat32Array:
	var rng := _rng_for("smg_mag_out.wav")
	var samples := _silence(0.12)
	_add_noise(samples, rng, 0.0, 1.0, 110.0, 4000.0, 1200.0, 0.001)
	_add_tone(samples, 0.0, 0.5, 1300.0, 1000.0, 0.04, 70.0, 0.001)
	_add_tone(samples, 0.0, 0.5, 380.0, 280.0, 0.02, 120.0, 0.001)
	return _finish_loudness(samples, -14.0)


## The SMG's magazine going in: a light snap (a short noise tick and a ring at 1.7 kHz
## that dies quickly). 0.1 s.
func _smg_mag_in() -> PackedFloat32Array:
	var rng := _rng_for("smg_mag_in.wav")
	var samples := _silence(0.1)
	_add_noise(samples, rng, 0.0, 1.0, 220.0, 5000.0, 1600.0, 0.0005)
	_add_tone(samples, 0.0, 0.5, 1700.0, 1500.0, 0.03, 90.0, 0.0005)
	_add_tone(samples, 0.0, 0.4, 450.0, 330.0, 0.02, 140.0, 0.0005)
	return _finish_loudness(samples, -14.0)


## The SMG's cocking handle: a quick light cock, two small clicks 70 ms apart (the
## second a little higher). 0.18 s.
func _smg_charge() -> PackedFloat32Array:
	var rng := _rng_for("smg_charge.wav")
	var samples := _silence(0.18)
	_add_noise(samples, rng, 0.0, 0.8, 160.0, 4500.0, 1200.0, 0.0005)
	_add_tone(samples, 0.0, 0.4, 1200.0, 1000.0, 0.03, 100.0, 0.0005)
	_add_noise(samples, rng, 0.07, 1.0, 190.0, 5000.0, 1600.0, 0.0005)
	_add_tone(samples, 0.07, 0.45, 1600.0, 1400.0, 0.03, 100.0, 0.0005)
	return _finish_loudness(samples, -14.0)


## The sniper rifle's magazine coming out: a thick, heavy clunk (a deep thunk at 75 Hz, a
## ring at 400 Hz and a low noise thud). 0.3 s.
func _sniper_mag_out() -> PackedFloat32Array:
	var rng := _rng_for("sniper_mag_out.wav")
	var samples := _silence(0.3)
	_add_clack(samples, rng, 0.0, 1.0, 400.0, 75.0, 30.0, 40.0, 800.0, 5000.0)
	_add_noise(samples, rng, 0.0, 1.4, 22.0, 600.0, 0.0, 0.002)
	_add_noise(samples, rng, 0.08, 0.3, 25.0, 2500.0, 600.0, 0.01)
	return _finish_loudness(samples, -14.0)


## The sniper rifle's magazine going in: a deep click (ring at 520 Hz, thunk at 85 Hz) and
## a low latch tick after it. 0.25 s.
func _sniper_mag_in() -> PackedFloat32Array:
	var rng := _rng_for("sniper_mag_in.wav")
	var samples := _silence(0.25)
	_add_clack(samples, rng, 0.0, 1.0, 520.0, 85.0, 36.0, 45.0, 900.0, 5000.0)
	_add_noise(samples, rng, 0.0, 1.0, 30.0, 700.0, 0.0, 0.001)
	_add_clack(samples, rng, 0.09, 0.45, 900.0, 140.0, 55.0, 80.0, 1200.0, 6000.0)
	return _finish_loudness(samples, -14.0)


## The sniper rifle's bolt, in a quarter of a second: up (a light tick), back (a scrape and
## a clack), forward (a sharper clack) and down (a heavy thunk), four clicks inside 0.35 s.
func _sniper_charge() -> PackedFloat32Array:
	var rng := _rng_for("sniper_charge.wav")
	var samples := _silence(0.35)
	_add_clack(samples, rng, 0.0, 0.45, 1500.0, 220.0, 70.0, 100.0, 1800.0, 7000.0)
	_add_noise(samples, rng, 0.05, 0.3, 40.0, 3000.0, 800.0, 0.008)
	_add_clack(samples, rng, 0.09, 0.8, 700.0, 110.0, 50.0, 70.0, 1200.0, 6000.0)
	_add_clack(samples, rng, 0.19, 0.9, 950.0, 140.0, 50.0, 70.0, 1200.0, 7000.0)
	_add_clack(samples, rng, 0.255, 1.0, 480.0, 70.0, 36.0, 60.0, 900.0, 5000.0)
	return _finish_loudness(samples, -14.0)


## The pistol's magazine coming out: a small click and a tiny drop (a short falling tone
## 60 ms later, the magazine hitting the hand). 0.2 s.
func _pistol_mag_out() -> PackedFloat32Array:
	var rng := _rng_for("pistol_mag_out.wav")
	var samples := _silence(0.2)
	_add_clack(samples, rng, 0.0, 0.9, 1500.0, 250.0, 60.0, 100.0, 1800.0, 8000.0)
	_add_tone(samples, 0.06, 0.45, 900.0, 450.0, 0.04, 60.0, 0.001)
	_add_noise(samples, rng, 0.06, 0.4, 120.0, 3000.0, 800.0, 0.001)
	return _finish_loudness(samples, -14.0)


## The pistol's magazine going in: a tight, short snap (a clack with a ring at 2 kHz). 0.12 s.
func _pistol_mag_in() -> PackedFloat32Array:
	var rng := _rng_for("pistol_mag_in.wav")
	var samples := _silence(0.12)
	_add_clack(samples, rng, 0.0, 1.0, 2000.0, 320.0, 80.0, 120.0, 2000.0, 9000.0)
	_add_tone(samples, 0.0, 0.3, 3100.0, 3000.0, 0.1, 100.0)
	return _finish_loudness(samples, -14.0)


## The pistol's slide: pulled back (a short scrape) and released, a sharp high clack with a
## ring at 2.8 kHz. 0.2 s.
func _pistol_charge() -> PackedFloat32Array:
	var rng := _rng_for("pistol_charge.wav")
	var samples := _silence(0.2)
	_add_noise(samples, rng, 0.0, 0.5, 30.0, 4500.0, 1500.0, 0.01)
	_add_clack(samples, rng, 0.07, 1.0, 2800.0, 350.0, 50.0, 100.0, 2500.0, 9000.0)
	_add_tone(samples, 0.07, 0.3, 3600.0, 3500.0, 0.1, 45.0)
	return _finish_loudness(samples, -14.0)


## The hand cannon's magazine coming out: a heavier click (ring at 800 Hz, thunk at 140 Hz)
## and a dull drop 60 ms later. 0.22 s.
func _hand_cannon_mag_out() -> PackedFloat32Array:
	var rng := _rng_for("hand_cannon_mag_out.wav")
	var samples := _silence(0.22)
	_add_clack(samples, rng, 0.0, 1.0, 950.0, 150.0, 40.0, 60.0, 1400.0, 8000.0)
	_add_tone(samples, 0.07, 0.5, 400.0, 180.0, 0.05, 50.0, 0.001)
	_add_noise(samples, rng, 0.07, 0.4, 70.0, 1500.0, 300.0, 0.001)
	return _finish_loudness(samples, -14.0)


## The hand cannon's magazine going in: a chunky snap (a clack with a ring at 1 kHz and a
## thick thunk at 170 Hz that holds for 40 ms). 0.18 s.
func _hand_cannon_mag_in() -> PackedFloat32Array:
	var rng := _rng_for("hand_cannon_mag_in.wav")
	var samples := _silence(0.18)
	_add_clack(samples, rng, 0.0, 1.0, 1250.0, 190.0, 38.0, 45.0, 1600.0, 8000.0)
	_add_noise(samples, rng, 0.0, 0.8, 50.0, 1200.0, 200.0, 0.001)
	return _finish_loudness(samples, -14.0)


## The hand cannon's slide: a heavy rack, two clacks 0.11 s apart (the second higher and
## louder). 0.3 s.
func _hand_cannon_charge() -> PackedFloat32Array:
	var rng := _rng_for("hand_cannon_charge.wav")
	var samples := _silence(0.3)
	_add_clack(samples, rng, 0.0, 0.7, 900.0, 140.0, 40.0, 60.0, 1400.0, 8000.0)
	_add_noise(samples, rng, 0.04, 0.3, 30.0, 3000.0, 800.0, 0.01)
	_add_clack(samples, rng, 0.12, 1.0, 1150.0, 180.0, 36.0, 50.0, 1600.0, 8000.0)
	return _finish_loudness(samples, -14.0)


## Adds band-limited noise to `samples`, starting `start` seconds in. The band runs
## from `low_cut` (0 = no high-pass) up to `high_cut` in Hz. `gain` is relative to
## plain white noise of the same strength, whatever the band, so the parts of a
## sound can be balanced by their gains. The envelope rises over `attack` seconds
## and then dies away by `decay` per second (e^-decay*t).
func _add_noise(samples: PackedFloat32Array, rng: RandomNumberGenerator, start: float, gain: float, decay: float, high_cut: float, low_cut: float = 0.0, attack: float = 0.0004) -> void:
	var a_high := _alpha(high_cut)
	var a_low := _alpha(low_cut)
	# Variance of the filtered noise, to give every band the same strength.
	var variance := a_high / (2.0 - a_high)
	if low_cut > 0.0:
		variance += a_low / (2.0 - a_low) - 2.0 * a_high * a_low / (a_high + a_low - a_high * a_low)
	var scale := gain / sqrt(variance)
	var high := 0.0
	var low := 0.0
	var first := int(start * MIX_RATE)
	for i in range(first, samples.size()):
		var local_t := float(i - first) / MIX_RATE
		var envelope := minf(local_t / attack, 1.0) * exp(-local_t * decay)
		if local_t > attack and envelope < 0.002:
			break
		var noise := rng.randf_range(-1.0, 1.0)
		high += (noise - high) * a_high
		if low_cut > 0.0:
			low += (noise - low) * a_low
		samples[i] += (high - low) * envelope * scale


## Adds a sine tone, `start` seconds in, whose pitch glides from `freq_from` to
## `freq_to` Hz over `glide` seconds. `overtone` mixes in the octave above (a bit of
## edge, so a deep thump still carries on small speakers). `start_phase` is where in its
## cycle the tone begins (radians; PI / 2 starts at the top of the wave, so a deep thump
## with a soft attack reaches full strength as soon as the attack is over).
func _add_tone(samples: PackedFloat32Array, start: float, gain: float, freq_from: float, freq_to: float, glide: float, decay: float, attack: float = 0.001, overtone: float = 0.0, start_phase: float = 0.0) -> void:
	var phase := start_phase
	var first := int(start * MIX_RATE)
	for i in range(first, samples.size()):
		var local_t := float(i - first) / MIX_RATE
		var envelope := minf(local_t / attack, 1.0) * exp(-local_t * decay)
		if local_t > attack and envelope < 0.002:
			break
		phase += TAU * lerpf(freq_from, freq_to, minf(local_t / glide, 1.0)) / MIX_RATE
		samples[i] += (sin(phase) + sin(phase * 2.0) * overtone) * envelope * gain


## Adds a mechanical clack, `start` seconds in: a sharp tick of high noise, a short
## ring of two inharmonic metal partials (`ring_pitch` and 2.3 times that) and a low
## thunk of `thunk_pitch` Hz that sinks a little. The optional parameters (M13) shape
## it: `ring_decay` and `thunk_decay` (per second, bigger = shorter) and the band of the
## tick, from `tick_low` to `tick_high` Hz (the defaults are the original clack).
func _add_clack(samples: PackedFloat32Array, rng: RandomNumberGenerator, start: float, gain: float, ring_pitch: float, thunk_pitch: float, ring_decay: float = 55.0, thunk_decay: float = 90.0, tick_low: float = 1500.0, tick_high: float = 9000.0) -> void:
	_add_noise(samples, rng, start, gain * 1.2, 300.0, tick_high, tick_low)
	_add_tone(samples, start, gain * 0.5, ring_pitch, ring_pitch * 0.97, 0.05, ring_decay)
	_add_tone(samples, start, gain * 0.3, ring_pitch * 2.3, ring_pitch * 2.25, 0.05, ring_decay * 1.45)
	_add_tone(samples, start, gain * 0.45, thunk_pitch, thunk_pitch * 0.6, 0.02, thunk_decay)


## Adds a crackle: sparse, very short random clicks (a click is 1-2 samples), most
## often at the start. `density` is the chance of a click per sample at `start`,
## falling by `decay` per second. Lasts `duration` seconds.
func _add_crackle(samples: PackedFloat32Array, rng: RandomNumberGenerator, start: float, duration: float, gain: float, density: float, decay: float) -> void:
	var grain := 0.0
	var first := int(start * MIX_RATE)
	var last := mini(int((start + duration) * MIX_RATE), samples.size())
	for i in range(first, last):
		var local_t := float(i - first) / MIX_RATE
		grain *= 0.5
		if rng.randf() < density * exp(-local_t * decay):
			grain += rng.randf_range(-1.0, 1.0)
		samples[i] += grain * gain


## Adds a whoosh over `duration` seconds: noise through two low-passes whose cutoff
## glides from `cut_from` to `cut_mid` Hz at `peak_at` (0-1, how far into the sound
## the loudest moment is) and on to `cut_to`, under a smooth rise-and-fall window.
func _add_whoosh(samples: PackedFloat32Array, rng: RandomNumberGenerator, start: float, duration: float, gain: float, cut_from: float, cut_mid: float, cut_to: float, peak_at: float) -> void:
	var first := int(start * MIX_RATE)
	var last := mini(int((start + duration) * MIX_RATE), samples.size())
	var stage_one := 0.0
	var stage_two := 0.0
	for i in range(first, last):
		var u := float(i - first) / float(last - first)
		var rising := u < peak_at
		var cutoff := lerpf(cut_from, cut_mid, u / peak_at) if rising else lerpf(cut_mid, cut_to, (u - peak_at) / (1.0 - peak_at))
		var alpha := _alpha(cutoff)
		# Variance of two equal one-pole stages on white noise, to keep the strength.
		var variance := alpha * (1.0 + (1.0 - alpha) * (1.0 - alpha)) / pow(2.0 - alpha, 3.0)
		var warped := 0.5 * u / peak_at if rising else 0.5 + 0.5 * (u - peak_at) / (1.0 - peak_at)
		var window := pow(sin(PI * warped), 2.0)
		var noise := rng.randf_range(-1.0, 1.0)
		stage_one += (noise - stage_one) * alpha
		stage_two += (stage_one - stage_two) * alpha
		samples[i] += stage_two / sqrt(variance) * window * gain


## Adds echoes: copies of what is in `samples` right now, each delayed by `delays`
## seconds and scaled by the matching entry of `gains`. Every copy is low-passed
## (starting at `cutoff` Hz and 30% lower for every following echo), so the echoes get
## darker, and everything below `low_cut` Hz is removed from them (0 = keep it), so
## a deep thump doesn't turn into a rumble that repeats.
func _add_echoes(samples: PackedFloat32Array, delays: PackedFloat32Array, gains: PackedFloat32Array, cutoff: float, low_cut: float = 0.0) -> void:
	var dry := samples.duplicate()
	var a_low := _alpha(low_cut)
	for k in delays.size():
		var shift := int(delays[k] * MIX_RATE)
		var alpha := _alpha(cutoff * pow(0.7, k))
		var low := 0.0
		var rumble := 0.0
		for i in dry.size():
			low += (dry[i] - low) * alpha
			rumble += (dry[i] - rumble) * a_low
			if i + shift < samples.size():
				samples[i + shift] += (low - rumble if low_cut > 0.0 else low) * gains[k]


## A soft clipper: scales the sound to a peak of 1, then bends it with tanh so loud
## parts are squashed against the quieter ones. Makes a sound feel louder once it
## is normalised again. `drive` is how hard (1 = gentle, 2+ = strong).
func _saturate(samples: PackedFloat32Array, drive: float) -> void:
	var peak := 0.0
	for sample in samples:
		peak = maxf(peak, absf(sample))
	for i in samples.size():
		samples[i] = tanh(samples[i] / peak * drive)


## The coefficient for a one-pole low-pass at `cutoff` Hz: `y += (x - y) * alpha`.
func _alpha(cutoff: float) -> float:
	return 1.0 - exp(-TAU * minf(cutoff, 20000.0) / MIX_RATE)


## `_finish` for the arsenal's sounds: fades the last 10 ms (so a tail never ends in a
## click), normalises to the same 90% peak and crushes the levels like every other
## sound (unless `crush` is off), then scales by `gain` (below 1 = quieter on purpose).
func _finish_arsenal(samples: PackedFloat32Array, gain: float = 1.0, crush: bool = true) -> PackedFloat32Array:
	var count := samples.size()
	var fade := mini(int(0.01 * MIX_RATE), count)
	for i in fade:
		samples[count - 1 - i] *= float(i) / fade
	if crush:
		_finish(samples)
	else:
		var peak := 0.0
		for sample in samples:
			peak = maxf(peak, absf(sample))
		for i in count:
			samples[i] = samples[i] / peak * 0.9
	for i in count:
		samples[i] *= gain
	return samples


## A random generator of its own for the sound in `file_name` (M13, D-194), seeded from
## the name: the sound comes out the same whatever order the sounds are made in, and a new
## sound changes none of the others.
func _rng_for(file_name: String) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = file_name.hash()
	return rng


## `_finish` for the M13 sounds (D-194): fades the last 10 ms, takes out the DC offset
## and scales the sound until its short-term loudness (the loudest 50 ms, as
## `SoundLevels.short_term_db` measures it) is `target_db` dBFS. If that would push the
## peak over -1 dBFS, the sound goes through a soft clipper (tanh) instead, whose input
## gain is searched until the loudness fits (a loud, short sound becomes a squarer one, as
## the old normalise-and-saturate sounds already were). Then it is crushed to
## `CRUSH_LEVELS` like every sound, unless `crush` is off (the peak is still kept under
## -1 dBFS). The crushing changes the loudness a little, so the aim is corrected twice.
## `push_warning` if the result is still more than 1 dB off the target.
func _finish_loudness(samples: PackedFloat32Array, target_db: float, crush: bool = true) -> PackedFloat32Array:
	var count := samples.size()
	var mean := 0.0
	for sample in samples:
		mean += sample
	mean /= maxi(count, 1)
	for i in count:
		samples[i] -= mean
	var fade := mini(int(0.01 * MIX_RATE), count)
	for i in fade:
		samples[count - 1 - i] *= float(i) / fade
	var aim := target_db
	var result := _fit_loudness(samples, aim)
	if crush:
		for attempt in 3:
			var crushed := result.duplicate()
			for i in count:
				crushed[i] = roundf(crushed[i] * CRUSH_LEVELS) / CRUSH_LEVELS
			var error := target_db - SoundLevels.short_term_db(crushed, MIX_RATE)
			result = crushed
			if absf(error) <= 0.25 or attempt == 2:
				break
			aim += error
			result = _fit_loudness(samples, aim)
	var loudness := SoundLevels.short_term_db(result, MIX_RATE)
	if absf(loudness - target_db) > 1.0:
		push_warning("generate_sounds: a sound ended at %.1f dB, not the %.1f dB asked for" % [loudness, target_db])
	return result


## The float part of `_finish_loudness`: a copy of `samples` at `target_db` short-term
## loudness, scaled if that keeps the peak under `PEAK_LIMIT`, otherwise soft-clipped.
func _fit_loudness(samples: PackedFloat32Array, target_db: float) -> PackedFloat32Array:
	var gain := db_to_linear(target_db - SoundLevels.short_term_db(samples, MIX_RATE))
	var result := samples.duplicate()
	var peak := 0.0
	for sample in samples:
		peak = maxf(peak, absf(sample))
	if peak * gain <= PEAK_LIMIT:
		for i in result.size():
			result[i] = samples[i] * gain
		return result
	# Loud enough to clip: look for the input gain whose clipped sound has the target loudness.
	var low := gain
	var high := gain * 64.0
	for iteration in 18:
		var middle := sqrt(low * high)
		_clip_into(result, samples, middle)
		if SoundLevels.short_term_db(result, MIX_RATE) < target_db:
			low = middle
		else:
			high = middle
	_clip_into(result, samples, high)
	return result


## Fills `result` with `samples` times `gain`, bent by the soft clipper (tanh, like
## `_saturate`) so that nothing reaches `SATURATION_CEILING`.
func _clip_into(result: PackedFloat32Array, samples: PackedFloat32Array, gain: float) -> void:
	for i in samples.size():
		result[i] = SATURATION_CEILING * tanh(samples[i] * gain / SATURATION_CEILING)


## Low-passes the whole sound at `cutoff` Hz, `passes` times (each pass is one more pole,
## 6 dB per octave steeper): what distance does to a sound (M13's far shots and explosions).
func _low_pass(samples: PackedFloat32Array, cutoff: float, passes: int = 2) -> void:
	var alpha := _alpha(cutoff)
	for pass_index in passes:
		var state := 0.0
		for i in samples.size():
			state += (samples[i] - state) * alpha
			samples[i] = state


## Adds one note to `samples`, starting `start` seconds in: a square or triangle
## wave with a 4 ms attack, an exponential decay and a short release at the end
## so that it doesn't click.
func _add_note(samples: PackedFloat32Array, start: float, duration: float, frequency: float, triangle: bool, decay: float) -> void:
	var first := int(start * MIX_RATE)
	var last := mini(int((start + duration) * MIX_RATE), samples.size())
	for i in range(first, last):
		var local_t := float(i - first) / MIX_RATE
		var envelope := minf(local_t / 0.004, 1.0) * exp(-local_t * decay) * minf((duration - local_t) / 0.008, 1.0)
		var wave := _triangle(frequency * local_t) if triangle else _square(frequency * local_t)
		samples[i] += wave * envelope * 0.6


## A square wave. `cycles` is the position in whole cycles (frequency * time).
func _square(cycles: float) -> float:
	return 1.0 if fposmod(cycles, 1.0) < 0.5 else -1.0


## A triangle wave. `cycles` is the position in whole cycles (frequency * time).
func _triangle(cycles: float) -> float:
	return 4.0 * absf(fposmod(cycles, 1.0) - 0.5) - 1.0


func _silence(seconds: float) -> PackedFloat32Array:
	var samples := PackedFloat32Array()
	samples.resize(int(MIX_RATE * seconds))
	return samples


## Scales the loudest sample to 90% and crushes the amplitude to a few levels.
func _finish(samples: PackedFloat32Array) -> PackedFloat32Array:
	var peak := 0.0
	for sample in samples:
		peak = maxf(peak, absf(sample))
	for i in samples.size():
		samples[i] = roundf(samples[i] / peak * 0.9 * CRUSH_LEVELS) / CRUSH_LEVELS
	return samples


func _save(file_name: String, samples: PackedFloat32Array) -> void:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.data = bytes
	var path := OUTPUT_FOLDER + file_name
	print("%s: %s (%.2f s)" % [path, error_string(stream.save_to_wav(path)), samples.size() / float(MIX_RATE)])
