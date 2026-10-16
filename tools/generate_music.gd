extends SceneTree
## Tool (M13, D-195): generates Chiip's music as .wav files in `assets/sounds/music/`: the
## main menu's looping track (`menu_theme.wav`, about 35 s) and six stingers in the same key
## (E minor) and the same sound palette (a pulsing filtered saw bass, a pad of detuned saws
## under a low-pass, a square lead with vibrato, a sparse kit of noise and sine): round start,
## round won, round lost, bomb defused, match won and match lost. Everything is synthesized
## here in code, no samples; the music and the stingers are made for Chiip and fall under the
## project's CC BY-NC-SA 4.0 licence for sounds (D-170), like the rest of `assets/sounds/`.
##
## Run from the project folder, then let Godot import the new files:
##
##     Godot --headless --path . --quit-after 100 --script res://tools/generate_music.gd
##     Godot --headless --path . --import
##
## `menu_theme.wav` has to loop: its `.wav.import` file keeps the loop setting (`edit/loop_mode=2`,
## forward, from `edit/loop_begin=0` to `edit/loop_end=-1`, the end of the file). Edit those
## three lines once after the first import (the importer does not overwrite them again); `-- --check`
## after the script path only loads the imported file and prints its loop setting.
##
## How the loop is made seamless: the whole track is rendered as 16 bars plus four seconds of
## "tail" (what rings on past the end: the last notes' releases, the echoes, the reverb, the pad's
## filter), and the tail is then added back onto the start of the loop. The end flows into the
## beginning as if the track had been playing for ever; the pad's filter sweep is periodic, and
## the loop is not faded or crushed. Each stinger is rendered the same way and ends in silence.
##
## `tools/sound_report.gd -- music` prints the levels: the loop is levelled to -18 dB
## short-term loudness (`SoundLevels.short_term_db`, the loudest 50 ms) and each stinger to
## -12 dB, all with a peak under -1 dBFS. Every file has its own random generator (`_rng_for`).

const MIX_RATE := 22050
const OUTPUT_FOLDER := "res://assets/sounds/music/"
## Amplitude steps kept after "bit crushing" a stinger (like every game sound); the loop is not crushed.
const CRUSH_LEVELS := 48
## The highest peak a finished sound may have (linear, about -1.06 dBFS).
const PEAK_LIMIT := 0.885
## The ceiling of the soft clipper in `_fit_loudness`: its output never reaches this.
const SATURATION_CEILING := 0.87
## Short-term loudness (dBFS) of the menu loop and of each stinger.
const MENU_DB := -18.0
const STINGER_DB := -12.0

## Samples in one sixteenth note of the menu loop. 3007 is 109.99 BPM, and a whole number, so
## every step lands on a sample and the loop is exactly 256 steps.
const STEP := 3007
const BARS := 16
const LOOP_SAMPLES := STEP * 16 * BARS
## What is rendered after the loop's end and then folded back onto its start, in seconds.
const TAIL_SECONDS := 4.0
## A filter's cutoff is updated every this many samples (not every sample: `tan` is slow).
const CONTROL_BLOCK := 16
## The stingers' tempo: an eighth note is `EIGHTH` seconds.
const EIGHTH := 60.0 / 110.0 / 2.0

## The menu loop's chords by name: [bass root (MIDI), the pad's notes (MIDI)]. Voiced to move by
## the smallest steps: Em, C, G and D share notes. `B5` is a power chord (no third), so the lead's
## D natural over it doesn't clash with a D sharp.
const CHORDS := {
	"Em": [40, [52, 55, 59, 64]],
	"C": [36, [52, 55, 60, 64]],
	"G": [43, [55, 59, 62, 67]],
	"D": [38, [54, 57, 62, 66]],
	"B5": [35, [47, 54, 59, 66]],
}
## One chord per bar: i, VI, III, VII twice, the second time ending on the dominant.
const PROGRESSION: Array[String] = ["Em", "Em", "C", "C", "G", "G", "D", "D", "Em", "Em", "C", "C", "G", "G", "D", "B5"]
## The bass notes of a bar's eight eighths, in semitones above the chord's root; the last bar of
## every four plays the second pattern, a walk back to the next root.
const BASS_PATTERN_A: Array[int] = [0, 0, 12, 0, 0, 0, 12, 0]
const BASS_PATTERN_B: Array[int] = [0, 0, 12, 0, 0, 12, 7, 5]
## The lead motif, one phrase for each two bars of the second half (over Em, C, G, then D and
## B5): [start step in the phrase (0 to 31), length in steps, MIDI note].
const LEAD_PHRASES: Array = [
	[[0, 6, 76], [6, 2, 74], [8, 4, 71], [12, 4, 67], [16, 6, 69], [22, 2, 71], [24, 8, 74]],
	[[0, 6, 76], [6, 2, 74], [8, 4, 72], [12, 4, 67], [16, 6, 69], [22, 2, 67], [24, 8, 76]],
	[[0, 6, 74], [6, 2, 71], [8, 4, 67], [12, 4, 71], [16, 6, 74], [22, 2, 76], [24, 4, 74], [28, 4, 71]],
	[[0, 6, 69], [6, 2, 71], [8, 4, 74], [12, 4, 69], [16, 6, 71], [22, 2, 69], [24, 8, 66]],
]


## One voice of a track per buffer, so they can be balanced, ducked and sent to the reverb
## separately: the bass, the pad, the lead, the kit (kick, toms, hats), the snare with its
## clap, and the effects (risers, crashes).
class Layers:
	var bass := PackedFloat32Array()
	var pad := PackedFloat32Array()
	var lead := PackedFloat32Array()
	var kit := PackedFloat32Array()
	var snare := PackedFloat32Array()
	var fx := PackedFloat32Array()

	func _init(size: int) -> void:
		for layer: PackedFloat32Array in [bass, pad, lead, kit, snare, fx]:
			layer.resize(size)

	func all() -> Array[PackedFloat32Array]:
		return [bass, pad, lead, kit, snare, fx]


## A state-variable filter in its trapezoidal form (stable at any cutoff, resonance `q`):
## `process()` returns the low-pass of one sample and leaves the band-pass in `band`.
## `set_cutoff()` changes the cutoff without a click.
class Filter:
	var q_inv: float
	var rate: float
	var a1 := 0.0
	var a2 := 0.0
	var a3 := 0.0
	var ic1 := 0.0
	var ic2 := 0.0
	var band := 0.0

	func _init(q: float, mix_rate: float) -> void:
		q_inv = 1.0 / q
		rate = mix_rate

	func set_cutoff(cutoff: float) -> void:
		var g := tan(PI * minf(cutoff, rate * 0.45) / rate)
		a1 = 1.0 / (1.0 + g * (g + q_inv))
		a2 = g * a1
		a3 = g * a2

	func process(x: float) -> float:
		var v3 := x - ic2
		var v1 := a1 * ic1 + a2 * v3
		var v2 := ic2 + a2 * ic1 + a3 * v3
		ic1 = 2.0 * v1 - ic1
		ic2 = 2.0 * v2 - ic2
		band = v1
		return v2


func _init() -> void:
	if OS.get_cmdline_user_args().has("--check"):
		_check_loop()
		quit()
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_FOLDER))
	_save("menu_theme.wav", _menu_theme())
	_save("stinger_round_start.wav", _stinger_round_start())
	_save("stinger_round_won.wav", _stinger_round_won())
	_save("stinger_round_lost.wav", _stinger_round_lost())
	_save("stinger_bomb_defused.wav", _stinger_bomb_defused())
	_save("stinger_match_won.wav", _stinger_match_won())
	_save("stinger_match_lost.wav", _stinger_match_lost())
	quit()


## `-- --check`: loads the imported menu theme and prints whether it loops.
func _check_loop() -> void:
	var stream := load(OUTPUT_FOLDER + "menu_theme.wav") as AudioStreamWAV
	if stream == null:
		print("menu_theme.wav: not imported yet (run the import command first)")
		return
	var modes := {AudioStreamWAV.LOOP_DISABLED: "disabled", AudioStreamWAV.LOOP_FORWARD: "forward",
			AudioStreamWAV.LOOP_PINGPONG: "ping-pong", AudioStreamWAV.LOOP_BACKWARD: "backward"}
	print("menu_theme.wav: loop_mode=%s (%d), loop_begin=%d, loop_end=%d, length %.2f s" % [
			modes.get(stream.loop_mode, "?"), stream.loop_mode, stream.loop_begin, stream.loop_end, stream.get_length()])


# ---- The menu track --------------------------------------------------------------------


## The main menu's loop, 16 bars of about 110 BPM in E minor (34.9 s): a pulsing filtered saw
## bass in eighths over a pad of detuned saws whose low-pass opens and closes once over the loop,
## a sparse kit (kick, snare and clap on two and four, closed hats that get busier) that builds
## from one kick per bar to a full groove, a riser into the second half, where a pulse lead with
## vibrato and a dotted-eighth echo plays a short motif, and a snare fill and riser back into the
## start. The pad and the bass duck a little under every kick. Not faded, not crushed: the end
## flows into the beginning.
func _menu_theme() -> PackedFloat32Array:
	var rng := _rng_for("menu_theme.wav")
	var size := LOOP_SAMPLES + int(TAIL_SECONDS * MIX_RATE)
	var layers := Layers.new(size)
	var kicks := PackedInt32Array()
	# The chords: bass in eighths, the pad once per run of equal chords.
	var run_start := 0
	for bar in BARS:
		var chord: Array = CHORDS[PROGRESSION[bar]]
		var pattern := BASS_PATTERN_B if bar % 4 == 3 else BASS_PATTERN_A
		for eighth in 8:
			var start := (bar * 16 + eighth * 2) * STEP
			var accent := 1.0 if eighth % 4 == 0 else (0.85 if eighth % 2 == 0 else 0.7)
			_bass_note(layers.bass, start, int(STEP * 1.6), float(chord[0] + pattern[eighth]), accent, 1500.0, 240.0, 16.0)
		if bar == BARS - 1 or PROGRESSION[bar + 1] != PROGRESSION[bar]:
			var length := (bar + 1 - run_start) * 16 * STEP
			_pad_chord(layers.pad, rng, run_start * 16 * STEP, length, chord[1], 1.0, 0.45, 0.7)
			run_start = bar + 1
	# The pad's low-pass: closed at the start of the loop, open in the middle of it, and periodic.
	var cutoffs := PackedFloat32Array()
	cutoffs.resize(size / CONTROL_BLOCK + 1)
	for block in cutoffs.size():
		var phase := fposmod(float(block * CONTROL_BLOCK), LOOP_SAMPLES) / LOOP_SAMPLES
		var open := 0.5 - 0.5 * cos(TAU * (phase - 0.05))
		cutoffs[block] = 380.0 * pow(2800.0 / 380.0, open)
	_filter_sweep(layers.pad, cutoffs, 1.4)
	# The kit.
	for bar in BARS:
		var origin := bar * 16
		var kick_steps: Array[int] = [0]
		if bar >= 8:
			kick_steps = [0, 6, 8, 11]
		elif bar >= 2:
			kick_steps = [0, 8, 10]
		for step in kick_steps:
			_kick(layers.kit, rng, (origin + step) * STEP, 1.0 if step % 4 == 0 else 0.75)
			kicks.append((origin + step) * STEP)
		if bar >= 3:
			var snare_steps: Array[int] = [12]
			if bar >= 4:
				snare_steps = [4, 12]
			if bar == BARS - 1:
				snare_steps = [4]
			for step in snare_steps:
				_snare(layers.snare, rng, (origin + step) * STEP, 0.9)
				if bar >= 8:
					_clap(layers.snare, rng, (origin + step) * STEP, 0.55)
		# Fills: a short one before the lead comes in, a longer one into the start of the loop.
		var fill_steps: Array[int] = []
		if bar == 7:
			fill_steps = [12, 14, 15]
		elif bar == BARS - 1:
			fill_steps = [8, 10, 12, 13, 14, 15]
		for k in fill_steps.size():
			_snare(layers.snare, rng, (origin + fill_steps[k]) * STEP, 0.4 + 0.1 * k)
		var hat_velocity: Array[float]
		if bar < 2:
			hat_velocity = [0.0, 0.0, 0.5, 0.0, 0.0, 0.0, 0.5, 0.0, 0.0, 0.0, 0.5, 0.0, 0.0, 0.0, 0.5, 0.0]
		elif bar < 8:
			hat_velocity = [0.45, 0.0, 0.7, 0.0, 0.45, 0.0, 0.7, 0.0, 0.45, 0.0, 0.7, 0.0, 0.45, 0.0, 0.7, 0.0]
		else:
			hat_velocity = [0.45, 0.22, 0.7, 0.3, 0.45, 0.25, 0.7, 0.22, 0.45, 0.3, 0.7, 0.22, 0.45, 0.25, 0.7, 0.35]
		for step in 16:
			if hat_velocity[step] > 0.0:
				_hat(layers.kit, rng, (origin + step) * STEP, hat_velocity[step], false)
		if bar >= 2 and bar % 2 == 1:
			_hat(layers.kit, rng, (origin + 14) * STEP, 0.6, true)
	# Risers: a bar into the lead's entrance, two bars into the start of the loop.
	_add_whoosh(layers.fx, rng, 7 * 16 * STEP, 16 * STEP, 0.5, 500.0, 6500.0, 6500.0, 0.92)
	_add_whoosh(layers.fx, rng, 14 * 16 * STEP, 32 * STEP, 0.7, 400.0, 7500.0, 7500.0, 0.94)
	_crash(layers.fx, rng, 0, 0.55)
	_crash(layers.fx, rng, 8 * 16 * STEP, 0.4)
	# The lead, second half only: one phrase for every two bars.
	for pair in 4:
		for note: Array in LEAD_PHRASES[pair]:
			var start := (8 * 16 + pair * 32 + int(note[0])) * STEP
			_lead_note(layers.lead, start, int(note[1]) * STEP - int(0.02 * MIX_RATE), float(note[2]), 1.0, 4200.0, 0.42, true)
	_echo(layers.lead, 3 * STEP, 0.42, 3500.0)
	# Ducking: the pad (and a little of the bass) lets go of the kick for a moment.
	_duck(layers.pad, kicks, 0.42, 0.14)
	_duck(layers.bass, kicks, 0.18, 0.1)
	var mixed := _bounce(layers, [-10.0, -13.0, -11.0, -9.0, -11.0, -22.0], 1.0, 0.84, [0.3, 0.55, 0.12])
	# Back onto the start: what rings past the loop's end.
	var folded := mixed.slice(0, LOOP_SAMPLES)
	for i in range(LOOP_SAMPLES, mixed.size()):
		folded[(i - LOOP_SAMPLES) % LOOP_SAMPLES] += mixed[i]
	_high_pass(folded, 32.0, 2)
	_compress(folded, 0.4, 3.0, 0.004, 0.12)
	return _finish_loudness(folded, MENU_DB, false, false)


# ---- The stingers -----------------------------------------------------------------------


## Round start, 0.8 s: "go". Two short rising lead notes (E4, B4) and then the hit: kick,
## snare, an E power chord of saws with the bass underneath and a lead E5 on top.
func _stinger_round_start() -> PackedFloat32Array:
	var rng := _rng_for("stinger_round_start.wav")
	var layers := Layers.new(_t(1.8))
	_lead_note(layers.lead, _t(0.0), _t(0.1), 64, 0.9, 5200.0, 0.4, false)
	_lead_note(layers.lead, _t(0.15), _t(0.12), 71, 0.9, 5200.0, 0.4, false)
	var hit := 0.34
	_kick(layers.kit, rng, _t(hit), 1.0)
	_snare(layers.snare, rng, _t(hit), 0.9)
	_hat(layers.kit, rng, _t(hit), 0.8, true)
	_bass_note(layers.bass, _t(hit), _t(0.24), 40, 1.0, 1800.0, 300.0, 9.0)
	_pad_chord(layers.pad, rng, _t(hit), _t(0.2), [52, 59, 64, 71], 1.0, 0.004, 0.16)
	_lead_note(layers.lead, _t(hit), _t(0.18), 76, 0.8, 5200.0, 0.4, false)
	return _stinger_finish(layers, 0.8, [-9.0, -11.0, -11.0, -8.0, -10.0, -30.0], 0.65, 0.7)


## Round won, 1.6 s: a bright rising phrase in E major, the colour the minor key never gets.
## Four quick lead notes climb the chord (E4, G#4, B4, C#5) and resolve up to a held E5 with
## vibrato over an E major pad whose filter opens, a kick, a clap and the bass.
func _stinger_round_won() -> PackedFloat32Array:
	var rng := _rng_for("stinger_round_won.wav")
	var layers := Layers.new(_t(2.6))
	var rise: Array[int] = [64, 68, 71, 73]
	for k in rise.size():
		_lead_note(layers.lead, _t(0.13 * k), _t(0.115), rise[k], 0.8 + 0.05 * k, 6500.0, 0.4, false)
	_lead_note(layers.lead, _t(0.52), _t(0.72), 76, 1.0, 6500.0, 0.4, true)
	_echo(layers.lead, _t(EIGHTH * 0.75), 0.3, 4500.0)
	_kick(layers.kit, rng, _t(0.0), 0.6)
	_hat(layers.kit, rng, _t(0.13), 0.45, false)
	_hat(layers.kit, rng, _t(0.39), 0.45, false)
	_kick(layers.kit, rng, _t(0.52), 1.0)
	_clap(layers.snare, rng, _t(0.52), 1.0)
	_bass_note(layers.bass, _t(0.0), _t(0.3), 40, 0.8, 1500.0, 260.0, 10.0)
	_bass_note(layers.bass, _t(0.52), _t(0.7), 40, 1.0, 1800.0, 280.0, 5.0)
	_pad_chord(layers.pad, rng, _t(0.52), _t(0.7), [52, 56, 59, 64, 68], 1.0, 0.02, 0.4)
	_filter_sweep(layers.pad, _sweep(layers.pad.size(), _t(0.5), _t(1.5), 900.0, 4200.0), 1.0)
	return _stinger_finish(layers, 1.6, [-10.0, -12.0, -9.0, -10.0, -10.0, -30.0], 0.9, 0.76)


## Round lost, 1.6 s: slower and darker. A falling minor phrase on a dull pulse lead (B4, A4,
## G4, E4), a low tom under the first and last notes, an E minor pad whose filter closes, and
## the bass on the last note. No hats, no clap: nothing bright in it.
func _stinger_round_lost() -> PackedFloat32Array:
	var rng := _rng_for("stinger_round_lost.wav")
	var layers := Layers.new(_t(2.6))
	var fall: Array[int] = [71, 69, 67]
	for k in fall.size():
		_lead_note(layers.lead, _t(0.34 * k), _t(0.33), fall[k], 0.9, 2200.0, 0.5, false)
	_lead_note(layers.lead, _t(1.02), _t(0.5), 64, 1.0, 2200.0, 0.5, true)
	_tom(layers.kit, rng, _t(0.0), 0.9, 120.0, 66.0)
	_tom(layers.kit, rng, _t(1.02), 1.0, 100.0, 54.0)
	_bass_note(layers.bass, _t(1.02), _t(0.5), 40, 1.0, 700.0, 200.0, 5.0)
	_pad_chord(layers.pad, rng, _t(0.68), _t(0.85), [52, 55, 59, 64], 1.0, 0.2, 0.4)
	_filter_sweep(layers.pad, _sweep(layers.pad.size(), _t(0.6), _t(1.6), 2400.0, 320.0), 1.2)
	return _stinger_finish(layers, 1.6, [-10.0, -12.0, -10.0, -9.0, -30.0, -30.0], 1.25, 0.82)


## Bomb defused, 1.8 s: relief. A tense figure of ticking pulses that speeds up, the tritone
## F4 and B3 alternating over closed hats, then it resolves: the F falls to a held E4 with
## vibrato over an open chord (E, B, F#, B, F#: fifths and a second, no third) that swells in,
## a soft kick and the bass. Different in shape from round won: no climb, a stutter and then a pool.
func _stinger_bomb_defused() -> PackedFloat32Array:
	var rng := _rng_for("stinger_bomb_defused.wav")
	var layers := Layers.new(_t(2.8))
	var times: Array[float] = [0.0, 0.13, 0.25, 0.36, 0.45, 0.53, 0.6]
	for k in times.size():
		_lead_note(layers.lead, _t(times[k]), _t(0.065), 65 if k % 2 == 0 else 59, 0.55 + 0.07 * k, 6000.0, 0.25, false)
		_hat(layers.kit, rng, _t(times[k]), 0.4 + 0.05 * k, false)
	var resolve := 0.7
	_lead_note(layers.lead, _t(resolve), _t(0.9), 64, 0.9, 4200.0, 0.45, true)
	_echo(layers.lead, _t(EIGHTH), 0.3, 3500.0)
	_kick(layers.kit, rng, _t(resolve), 0.65)
	_bass_note(layers.bass, _t(resolve), _t(0.9), 40, 0.9, 900.0, 220.0, 4.0)
	_pad_chord(layers.pad, rng, _t(resolve), _t(0.85), [47, 54, 59, 64, 66], 1.0, 0.1, 0.5)
	_filter_sweep(layers.pad, _sweep(layers.pad.size(), _t(resolve), _t(1.5), 700.0, 3800.0), 1.0)
	return _stinger_finish(layers, 1.8, [-11.0, -9.0, -11.0, -11.0, -30.0, -30.0], 1.15, 0.8)


## Match won, 3 s: a triumphant cadence, VI to VII to I (C, D, E major), the "rock" way home
## from the minor key. The kit drives it: kicks on the chord changes, hats on the eighths, a
## snare roll into the E and a snare, clap and crash on it. The lead climbs E5, F#5, G#5 and lands
## on a held B5 with vibrato, over saws and a bass that play the chords. The E major chord rings out.
func _stinger_match_won() -> PackedFloat32Array:
	var rng := _rng_for("stinger_match_won.wav")
	var layers := Layers.new(_t(4.4))
	var e := EIGHTH
	_pad_chord(layers.pad, rng, _t(0.0), _t(3.0 * e), [52, 55, 60, 64], 1.0, 0.01, 0.2)
	_pad_chord(layers.pad, rng, _t(3.0 * e), _t(3.0 * e), [54, 57, 62, 66], 1.0, 0.01, 0.2)
	_pad_chord(layers.pad, rng, _t(6.0 * e), _t(5.0 * e), [52, 56, 59, 64, 68], 1.1, 0.01, 0.6)
	for k in 3:
		_bass_note(layers.bass, _t(k * e), _t(e * 0.9), 36, 1.0, 1600.0, 240.0, 12.0)
		_bass_note(layers.bass, _t((3 + k) * e), _t(e * 0.9), 38, 1.0, 1600.0, 240.0, 12.0)
	_bass_note(layers.bass, _t(6.0 * e), _t(e * 4.0), 40, 1.1, 1900.0, 280.0, 4.0)
	_lead_note(layers.lead, _t(0.0), _t(3.0 * e - 0.03), 76, 0.9, 5500.0, 0.42, true)
	_lead_note(layers.lead, _t(3.0 * e), _t(3.0 * e - 0.03), 78, 0.95, 5500.0, 0.42, true)
	_lead_note(layers.lead, _t(6.0 * e), _t(e - 0.02), 80, 1.0, 5500.0, 0.42, false)
	_lead_note(layers.lead, _t(7.0 * e), _t(4.0 * e), 83, 1.0, 5500.0, 0.42, true)
	_echo(layers.lead, _t(e * 1.5), 0.35, 4000.0)
	for step: float in [0.0, 2.0, 3.0, 6.0]:
		_kick(layers.kit, rng, _t(step * e), 1.0)
	for k in 11:
		if k != 6:
			_hat(layers.kit, rng, _t(k * e), 0.42 if k % 2 == 0 else 0.6, false)
	_snare(layers.snare, rng, _t(2.0 * e), 0.9)
	for k in 5:
		_snare(layers.snare, rng, _t(4.0 * e + k * e * 0.4), 0.4 + 0.15 * k)
	_snare(layers.snare, rng, _t(6.0 * e), 1.0)
	_clap(layers.snare, rng, _t(6.0 * e), 0.8)
	_crash(layers.fx, rng, _t(6.0 * e), 1.0)
	return _stinger_finish(layers, 3.0, [-9.0, -11.0, -10.0, -8.0, -10.0, -16.0], 0.85, 0.78)


## Match lost, 3 s: a sombre cadence, VI to V to i (C, B, E minor). Slow toms instead of a kit,
## a dull lead that sinks stepwise (G4, F#4, E4) with a slow vibrato, a low bass on every chord, a
## pad whose filter closes over the whole stinger and a long reverb. The last E minor chord is bare.
func _stinger_match_lost() -> PackedFloat32Array:
	var rng := _rng_for("stinger_match_lost.wav")
	var layers := Layers.new(_t(4.4))
	_pad_chord(layers.pad, rng, _t(0.0), _t(0.95), [48, 55, 60, 64], 1.0, 0.08, 0.3)
	_pad_chord(layers.pad, rng, _t(1.0), _t(0.95), [47, 54, 59, 66], 1.0, 0.08, 0.3)
	_pad_chord(layers.pad, rng, _t(2.0), _t(0.8), [52, 59, 64, 67], 1.0, 0.08, 0.7)
	_filter_sweep(layers.pad, _sweep(layers.pad.size(), _t(0.0), _t(3.0), 2400.0, 260.0), 1.2)
	_lead_note(layers.lead, _t(0.0), _t(0.95), 67, 0.9, 2000.0, 0.5, true)
	_lead_note(layers.lead, _t(1.0), _t(0.95), 66, 0.9, 2000.0, 0.5, true)
	_lead_note(layers.lead, _t(2.0), _t(0.85), 64, 1.0, 2000.0, 0.5, true)
	_echo(layers.lead, _t(EIGHTH * 2.0), 0.3, 2500.0)
	_bass_note(layers.bass, _t(0.0), _t(0.9), 36, 0.9, 600.0, 170.0, 5.0)
	_bass_note(layers.bass, _t(1.0), _t(0.9), 35, 0.9, 600.0, 170.0, 5.0)
	_bass_note(layers.bass, _t(2.0), _t(0.8), 40, 1.0, 650.0, 190.0, 4.0)
	_tom(layers.kit, rng, _t(0.0), 0.9, 125.0, 68.0)
	_tom(layers.kit, rng, _t(1.0), 0.9, 112.0, 60.0)
	_tom(layers.kit, rng, _t(2.0), 1.0, 100.0, 52.0)
	_kick(layers.kit, rng, _t(2.0), 0.7)
	return _stinger_finish(layers, 3.0, [-9.0, -12.0, -11.0, -9.0, -30.0, -30.0], 1.5, 0.86)


# ---- Putting layers together ------------------------------------------------------------


## Mixes `layers` into one buffer. Every layer is first scaled to its own short-term loudness
## from `levels` (dBFS, in the order bass, pad, lead, kit, snare, fx; a silent layer is skipped),
## so the balance comes from this list and not from the synthesis gains. A reverb of `reverb`
## (the gain of the wet sound, about 1; `feedback` is its length) follows, fed by the lead, the snare
## and the pad in the amounts `sends`.
func _bounce(layers: Layers, levels: Array, reverb: float, feedback: float, sends: Array) -> PackedFloat32Array:
	var all := layers.all()
	for k in all.size():
		var level := SoundLevels.short_term_db(all[k], MIX_RATE)
		if is_finite(level):
			var gain := db_to_linear(float(levels[k]) - level)
			for i in all[k].size():
				all[k][i] *= gain
	var mixed := PackedFloat32Array()
	mixed.resize(layers.bass.size())
	var send := PackedFloat32Array()
	send.resize(mixed.size())
	for i in mixed.size():
		mixed[i] = layers.bass[i] + layers.pad[i] + layers.lead[i] + layers.kit[i] + layers.snare[i] + layers.fx[i]
		send[i] = layers.lead[i] * sends[0] + layers.snare[i] * sends[1] + layers.pad[i] * sends[2]
	var wet := _reverb(send, feedback, 5000.0)
	for i in mixed.size():
		mixed[i] += wet[i] * reverb
	return mixed


## Finishes a stinger: the mix of `layers` (see `_bounce`), without what is under 32 Hz, cut at
## `length` seconds with a fade over the last 80 ms, levelled to `STINGER_DB` and crushed.
func _stinger_finish(layers: Layers, length: float, levels: Array, reverb: float, feedback: float) -> PackedFloat32Array:
	var mixed := _bounce(layers, levels, reverb, feedback, [0.3, 0.5, 0.12])
	_high_pass(mixed, 32.0, 2)
	var result := mixed.slice(0, _t(length))
	var fade := _t(0.08)
	for i in fade:
		var gain := 0.5 + 0.5 * cos(PI * float(i) / fade)
		result[result.size() - fade + i] *= gain
	return _finish_loudness(result, STINGER_DB, true, true)


# ---- Voices -----------------------------------------------------------------------------


## A bass note starting at sample `start`, `length` samples held and then released over 30 ms:
## a band-limited saw through a resonant low-pass whose cutoff falls from `open` to `shut` Hz
## (`decay` per second: the pluck of the pulse), a sine at the same pitch under it and a
## soft clip for a little grit.
func _bass_note(buffer: PackedFloat32Array, start: int, length: int, midi: float, gain: float, open: float, shut: float, decay: float) -> void:
	var dt := _hz(midi) / MIX_RATE
	var release := int(0.03 * MIX_RATE)
	var filter := Filter.new(2.4, MIX_RATE)
	var phase := 0.0
	for n in length + release:
		var i := start + n
		if i >= buffer.size():
			break
		if n % CONTROL_BLOCK == 0:
			filter.set_cutoff(shut + (open - shut) * exp(-float(n) / MIX_RATE * decay))
		phase = fposmod(phase + dt, 1.0)
		var tone := filter.process(_saw(phase, dt)) * 1.2 + sin(TAU * phase) * 0.55
		var envelope := minf(float(n) / (0.003 * MIX_RATE), 1.0) * (1.0 if n < length else 1.0 - float(n - length) / release)
		buffer[i] += tanh(tone * 1.5) * 0.7 * envelope * gain


## A pad chord: every note of `midis` as two saws detuned by -7 and +7 cents, starting at
## sample `start`, held `length` samples, with a smooth attack of `attack` seconds and a
## release of `release` seconds. The saws start at random phases so repeats are not identical.
func _pad_chord(buffer: PackedFloat32Array, rng: RandomNumberGenerator, start: int, length: int, midis: Array, gain: float, attack: float, release: float) -> void:
	var dts := PackedFloat64Array()
	var phases := PackedFloat64Array()
	for midi: int in midis:
		for cents: float in [-7.0, 7.0]:
			dts.append(_hz(midi) * pow(2.0, cents / 1200.0) / MIX_RATE)
			phases.append(rng.randf())
	var release_samples := int(release * MIX_RATE)
	var attack_samples := maxf(attack * MIX_RATE, 1.0)
	var scale := gain / sqrt(float(dts.size())) * 0.6
	for n in length + release_samples:
		var i := start + n
		if i >= buffer.size():
			break
		var sum := 0.0
		for v in dts.size():
			phases[v] = fposmod(phases[v] + dts[v], 1.0)
			sum += _saw(phases[v], dts[v])
		var rise := smoothstep(0.0, 1.0, float(n) / attack_samples)
		var fall := 1.0 if n < length else smoothstep(0.0, 1.0, 1.0 - float(n - length) / release_samples)
		buffer[i] += sum * scale * rise * fall


## A lead note: two pulse waves (the second narrower and 9 cents sharp), a low-pass whose
## cutoff starts at `brightness` Hz and settles to about half of it, a 6 ms attack and a 60 ms
## release. With `vibrato` the pitch wobbles by 10 cents at 5.7 Hz, from 120 ms in.
func _lead_note(buffer: PackedFloat32Array, start: int, length: int, midi: float, gain: float, brightness: float, duty: float, vibrato: bool) -> void:
	var freq := _hz(midi)
	var release := int(0.06 * MIX_RATE)
	var filter := Filter.new(0.9, MIX_RATE)
	var phase_a := 0.0
	var phase_b := 0.0
	for n in length + release:
		var i := start + n
		if i >= buffer.size():
			break
		var t := float(n) / MIX_RATE
		if n % CONTROL_BLOCK == 0:
			filter.set_cutoff(brightness * (0.5 + 0.5 * exp(-t * 9.0)))
		var bend := 1.0
		if vibrato:
			bend += 0.0058 * sin(TAU * 5.7 * t) * smoothstep(0.12, 0.4, t)
		var dt_a := freq * bend / MIX_RATE
		var dt_b := dt_a * 1.0052
		phase_a = fposmod(phase_a + dt_a, 1.0)
		phase_b = fposmod(phase_b + dt_b, 1.0)
		var tone := filter.process(_pulse(phase_a, dt_a, duty) + _pulse(phase_b, dt_b, duty * 0.6) * 0.6)
		var envelope := minf(t / 0.006, 1.0) * (1.0 if n < length else 1.0 - float(n - length) / release)
		buffer[i] += tone * 0.5 * envelope * gain


## A kick: a sine that falls from 175 to 50 Hz in 70 ms and dies away in about 0.35 s, with a
## little octave for small speakers and a short click of noise. Nothing below 50 Hz.
func _kick(buffer: PackedFloat32Array, rng: RandomNumberGenerator, start: int, gain: float) -> void:
	_add_tone(buffer, start, gain, 175.0, 50.0, 0.07, 9.0, 0.0015, 0.12)
	_add_noise(buffer, rng, start, gain * 0.22, 380.0, 3200.0, 700.0)


## A tom: a sine that falls from `from_hz` to `to_hz` over 0.15 s and rings for about a
## second, with a soft click.
func _tom(buffer: PackedFloat32Array, rng: RandomNumberGenerator, start: int, gain: float, from_hz: float, to_hz: float) -> void:
	_add_tone(buffer, start, gain, from_hz, to_hz, 0.15, 5.5, 0.002, 0.08)
	_add_noise(buffer, rng, start, gain * 0.12, 260.0, 2400.0, 500.0)


## A snare: a band of noise (1.5 to 8 kHz) that dies in about 0.15 s over a short 190 Hz body.
func _snare(buffer: PackedFloat32Array, rng: RandomNumberGenerator, start: int, gain: float) -> void:
	_add_noise(buffer, rng, start, gain * 0.55, 17.0, 8000.0, 1500.0, 0.0008)
	_add_tone(buffer, start, gain * 0.5, 190.0, 160.0, 0.04, 26.0, 0.001, 0.2)


## A clap: four quick bursts of noise (0.9 to 3.5 kHz) 9 ms apart, the last one ringing longer.
func _clap(buffer: PackedFloat32Array, rng: RandomNumberGenerator, start: int, gain: float) -> void:
	for k in 3:
		_add_noise(buffer, rng, start + k * int(0.009 * MIX_RATE), gain * 0.4, 110.0, 3500.0, 900.0, 0.0006)
	_add_noise(buffer, rng, start + 3 * int(0.009 * MIX_RATE), gain * 0.5, 22.0, 3500.0, 900.0, 0.0006)


## A hat: noise between 6 and 9.5 kHz, a closed one lasting about 40 ms, an open one 0.3 s.
func _hat(buffer: PackedFloat32Array, rng: RandomNumberGenerator, start: int, gain: float, open: bool) -> void:
	_add_noise(buffer, rng, start, gain * 0.22, 14.0 if open else 85.0, 9500.0, 6000.0, 0.0005)


## A crash: a wash of noise (3.5 to 10 kHz) that takes about 1.5 s to die away.
func _crash(buffer: PackedFloat32Array, rng: RandomNumberGenerator, start: int, gain: float) -> void:
	_add_noise(buffer, rng, start, gain * 0.25, 2.6, 10000.0, 3500.0, 0.001)


# ---- Effects and helpers ----------------------------------------------------------------


## The frequency of a MIDI note in Hz (A4 = 69 = 440 Hz).
func _hz(midi: float) -> float:
	return 440.0 * pow(2.0, (midi - 69.0) / 12.0)


## Seconds to samples.
func _t(seconds: float) -> int:
	return int(round(seconds * MIX_RATE))


## PolyBLEP: the correction that rounds off a step at phase 0, `dt` being the phase moved per
## sample (frequency / rate). Removes most of the aliasing of a naive saw or pulse.
func _blep(phase: float, dt: float) -> float:
	if phase < dt:
		var x := phase / dt
		return x + x - x * x - 1.0
	if phase > 1.0 - dt:
		var x := (phase - 1.0) / dt
		return x * x + x + x + 1.0
	return 0.0


## A band-limited saw wave at `phase` (0 to 1, one cycle).
func _saw(phase: float, dt: float) -> float:
	return 2.0 * phase - 1.0 - _blep(phase, dt)


## A band-limited pulse wave at `phase` (0 to 1) with its high part `duty` of the cycle.
func _pulse(phase: float, dt: float, duty: float) -> float:
	return (1.0 if phase < duty else -1.0) + _blep(phase, dt) - _blep(fposmod(phase - duty + 1.0, 1.0), dt)


## The coefficient for a one-pole low-pass at `cutoff` Hz: `y += (x - y) * alpha`.
func _alpha(cutoff: float) -> float:
	return 1.0 - exp(-TAU * minf(cutoff, 20000.0) / MIX_RATE)


## Adds band-limited noise (between `low_cut` and `high_cut` Hz, equal strength whatever the
## band) starting at sample `start`: it rises over `attack` seconds and then dies away by
## `decay` per second (e^-decay*t). The same recipe as `generate_sounds.gd`'s.
func _add_noise(samples: PackedFloat32Array, rng: RandomNumberGenerator, start: int, gain: float, decay: float, high_cut: float, low_cut: float = 0.0, attack: float = 0.0004) -> void:
	var a_high := _alpha(high_cut)
	var a_low := _alpha(low_cut)
	var variance := a_high / (2.0 - a_high)
	if low_cut > 0.0:
		variance += a_low / (2.0 - a_low) - 2.0 * a_high * a_low / (a_high + a_low - a_high * a_low)
	var scale := gain / sqrt(variance)
	var high := 0.0
	var low := 0.0
	for i in range(start, samples.size()):
		var local_t := float(i - start) / MIX_RATE
		var envelope := minf(local_t / attack, 1.0) * exp(-local_t * decay)
		if local_t > attack and envelope < 0.002:
			break
		var noise := rng.randf_range(-1.0, 1.0)
		high += (noise - high) * a_high
		if low_cut > 0.0:
			low += (noise - low) * a_low
		samples[i] += (high - low) * envelope * scale


## Adds a sine tone starting at sample `start` whose pitch glides from `freq_from` to
## `freq_to` Hz over `glide` seconds, with `overtone` of the octave above mixed in. The same
## recipe as `generate_sounds.gd`'s.
func _add_tone(samples: PackedFloat32Array, start: int, gain: float, freq_from: float, freq_to: float, glide: float, decay: float, attack: float = 0.001, overtone: float = 0.0) -> void:
	var phase := 0.0
	for i in range(start, samples.size()):
		var local_t := float(i - start) / MIX_RATE
		var envelope := minf(local_t / attack, 1.0) * exp(-local_t * decay)
		if local_t > attack and envelope < 0.002:
			break
		phase += TAU * lerpf(freq_from, freq_to, minf(local_t / glide, 1.0)) / MIX_RATE
		samples[i] += (sin(phase) + sin(phase * 2.0) * overtone) * envelope * gain


## Adds a whoosh of noise over `duration` samples from `start`: two low-passes whose cutoff
## goes from `cut_from` to `cut_mid` Hz at `peak_at` (0 to 1 of the way) and on to `cut_to`,
## under a smooth rise and fall. The same recipe as `generate_sounds.gd`'s.
func _add_whoosh(samples: PackedFloat32Array, rng: RandomNumberGenerator, start: int, duration: int, gain: float, cut_from: float, cut_mid: float, cut_to: float, peak_at: float) -> void:
	var last := mini(start + duration, samples.size())
	var stage_one := 0.0
	var stage_two := 0.0
	for i in range(start, last):
		var u := float(i - start) / float(last - start)
		var rising := u < peak_at
		var cutoff := lerpf(cut_from, cut_mid, u / peak_at) if rising else lerpf(cut_mid, cut_to, (u - peak_at) / (1.0 - peak_at))
		var alpha := _alpha(cutoff)
		var variance := alpha * (1.0 + (1.0 - alpha) * (1.0 - alpha)) / pow(2.0 - alpha, 3.0)
		var warped := 0.5 * u / peak_at if rising else 0.5 + 0.5 * (u - peak_at) / (1.0 - peak_at)
		var window := pow(sin(PI * warped), 2.0)
		var noise := rng.randf_range(-1.0, 1.0)
		stage_one += (noise - stage_one) * alpha
		stage_two += (stage_one - stage_two) * alpha
		samples[i] += stage_two / sqrt(variance) * window * gain


## Cutoffs for `_filter_sweep` over `size` samples: `from_hz` until sample `start`, then a
## glide that is even in octaves to `to_hz` at sample `end`, and `to_hz` after that.
func _sweep(size: int, start: int, end: int, from_hz: float, to_hz: float) -> PackedFloat32Array:
	var cutoffs := PackedFloat32Array()
	cutoffs.resize(size / CONTROL_BLOCK + 1)
	for block in cutoffs.size():
		var u := clampf(float(block * CONTROL_BLOCK - start) / float(end - start), 0.0, 1.0)
		cutoffs[block] = from_hz * pow(to_hz / from_hz, u)
	return cutoffs


## Runs `samples` through a resonant low-pass (resonance `q`) whose cutoff follows `cutoffs`
## (Hz, one value for every `CONTROL_BLOCK` samples).
func _filter_sweep(samples: PackedFloat32Array, cutoffs: PackedFloat32Array, q: float) -> void:
	var filter := Filter.new(q, MIX_RATE)
	for i in samples.size():
		if i % CONTROL_BLOCK == 0:
			filter.set_cutoff(cutoffs[mini(i / CONTROL_BLOCK, cutoffs.size() - 1)])
		samples[i] = filter.process(samples[i])


## Echoes `samples` onto itself: every `delay` samples a copy of what was there, `feedback`
## as loud and darkened by a low-pass at `cutoff` Hz, again and again.
func _echo(samples: PackedFloat32Array, delay: int, feedback: float, cutoff: float) -> void:
	var alpha := _alpha(cutoff)
	var low := 0.0
	for i in range(delay, samples.size()):
		low += (samples[i - delay] - low) * alpha
		samples[i] += low * feedback


## Ducks `samples` under every kick (a sample number in `kicks`): the gain drops by `depth`
## within 4 ms of it and comes back with a time constant of `recovery` seconds.
func _duck(samples: PackedFloat32Array, kicks: PackedInt32Array, depth: float, recovery: float) -> void:
	var gains := PackedFloat32Array()
	gains.resize(samples.size())
	gains.fill(1.0)
	var span := int(recovery * 5.0 * MIX_RATE)
	for kick in kicks:
		for n in mini(span, samples.size() - kick):
			var t := float(n) / MIX_RATE
			gains[kick + n] *= 1.0 - depth * minf(t / 0.004, 1.0) * exp(-t / recovery)
	for i in samples.size():
		samples[i] *= gains[i]


## A small reverb of `send`: four feedback combs (a different length each, `feedback` is how long
## they ring, their echoes darkened at `damp_cutoff` Hz) into two all-passes. Returns the wet
## sound, which is not mixed with the dry one.
func _reverb(send: PackedFloat32Array, feedback: float, damp_cutoff: float) -> PackedFloat32Array:
	var wet := PackedFloat32Array()
	wet.resize(send.size())
	var damp := _alpha(damp_cutoff)
	for delay: int in [1117, 1237, 1327, 1439]:
		var line := PackedFloat32Array()
		line.resize(delay)
		var position := 0
		var low := 0.0
		for i in send.size():
			var out := line[position]
			low += (out - low) * damp
			line[position] = send[i] + low * feedback
			position += 1
			if position >= delay:
				position = 0
			wet[i] += out * 0.25
	for delay: int in [225, 341]:
		var line := PackedFloat32Array()
		line.resize(delay)
		var position := 0
		for i in send.size():
			var buffered := line[position]
			var value := wet[i] + buffered * 0.5
			line[position] = value
			wet[i] = buffered - value * 0.5
			position += 1
			if position >= delay:
				position = 0
	return wet


## Takes out everything below `cutoff` Hz with `passes` one-pole high-passes (also the DC offset).
func _high_pass(samples: PackedFloat32Array, cutoff: float, passes: int) -> void:
	var a := 1.0 / (1.0 + TAU * cutoff / MIX_RATE)
	for pass_index in passes:
		var previous_in := 0.0
		var previous_out := 0.0
		for i in samples.size():
			var value := samples[i]
			previous_out = a * (previous_out + value - previous_in)
			previous_in = value
			samples[i] = previous_out


## A compressor for a looping buffer: where the level (a fast follower of the absolute value)
## is above `threshold` times the buffer's peak, the gain falls so that the excess is cut to
## 1 / `ratio`; the follower rises over `attack` seconds and falls over `release`. The
## loop is run twice, so the end hands its state over to the start.
func _compress(samples: PackedFloat32Array, threshold: float, ratio: float, attack: float, release: float) -> void:
	var peak := 0.0
	for sample in samples:
		peak = maxf(peak, absf(sample))
	var limit := threshold * peak
	var up := 1.0 - exp(-1.0 / (attack * MIX_RATE))
	var down := 1.0 - exp(-1.0 / (release * MIX_RATE))
	var level := 0.0
	for pass_index in 2:
		for i in samples.size():
			var magnitude := absf(samples[i])
			level += (magnitude - level) * (up if magnitude > level else down)
			var gain := 1.0
			if level > limit:
				gain = pow(level / limit, 1.0 / ratio - 1.0)
			if pass_index == 1:
				samples[i] *= gain


## A copy of the sound's name's own random generator: the sound comes out the same whatever
## order the files are made in (`generate_sounds.gd` does the same).
func _rng_for(file_name: String) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = file_name.hash()
	return rng


# ---- Levelling and saving ---------------------------------------------------------------


## `_finish_loudness` of `generate_sounds.gd` (D-194), with one more option: takes out the DC
## offset, fades the last 10 ms (`fade`: off for the loop, which must not dip at its seam) and
## scales the sound to `target_db` short-term loudness, soft-clipping it if that would put the
## peak over -1 dBFS; then crushes it to `CRUSH_LEVELS` unless `crush` is off. `push_warning` if
## the result is more than 1 dB off the target.
func _finish_loudness(samples: PackedFloat32Array, target_db: float, crush: bool, fade: bool) -> PackedFloat32Array:
	var count := samples.size()
	var mean := 0.0
	for sample in samples:
		mean += sample
	mean /= maxi(count, 1)
	for i in count:
		samples[i] -= mean
	if fade:
		var fade_samples := mini(int(0.01 * MIX_RATE), count)
		for i in fade_samples:
			samples[count - 1 - i] *= float(i) / fade_samples
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
		push_warning("generate_music: a sound ended at %.1f dB, not the %.1f dB asked for" % [loudness, target_db])
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


## Fills `result` with `samples` times `gain`, bent by the soft clipper (tanh) so that nothing
## reaches `SATURATION_CEILING`.
func _clip_into(result: PackedFloat32Array, samples: PackedFloat32Array, gain: float) -> void:
	for i in samples.size():
		result[i] = SATURATION_CEILING * tanh(samples[i] * gain / SATURATION_CEILING)


## Writes `samples` to `OUTPUT_FOLDER` as a 22050 Hz mono 16-bit .wav and prints what it did.
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
