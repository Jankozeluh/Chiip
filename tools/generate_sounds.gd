extends SceneTree
## Tool: generates Chiip's placeholder sounds (weapon, footsteps) as .wav files (D-020).
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


## A footstep on grit: a short low thud plus a crunchy burst of filtered noise.
func _footstep(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var samples := _silence(0.14)
	var low_pass := 0.0
	var thud_pitch := rng.randf_range(70.0, 95.0)
	for i in samples.size():
		var t := float(i) / MIX_RATE
		var noise := rng.randf_range(-1.0, 1.0)
		low_pass += (noise - low_pass) * 0.35
		var crunch := low_pass * exp(-t * 45.0) * (0.6 + 0.4 * rng.randf())
		var thud := sin(TAU * thud_pitch * t) * exp(-t * 35.0)
		samples[i] = crunch * 0.7 + thud * 0.9
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
