extends SceneTree
## Tool: generates Chiip's placeholder sounds (weapon, footsteps, bomb) as .wav files (D-020).
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
