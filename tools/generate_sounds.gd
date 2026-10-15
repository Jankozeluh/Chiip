extends SceneTree
## Tool: generates Chiip's placeholder sounds (weapon, footsteps on four surfaces, bomb,
## impacts, hits and interface) as .wav files (D-020).
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
