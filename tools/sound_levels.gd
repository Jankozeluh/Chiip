class_name SoundLevels
extends RefCounted
## Measures Chiip's generated sounds straight from their .wav files (M13, D-194): peak,
## short-term loudness, length and where the energy sits. Used by `tools/sound_report.gd`
## and by `sound_test`'s mix checks. Reads the source files, not the imported ones (those
## are compressed), so it works only in the project, never in an exported game.

## The window of the short-term loudness, in seconds: about one gunshot's body.
const SHORT_TERM_WINDOW := 0.05
## Band edges of [method band_shares], in Hz.
const BAND_EDGES: Array[float] = [250.0, 1000.0, 4000.0]


## The samples of a 16-bit PCM .wav (mono, or the left channel of stereo) as floats from
## -1 to 1, and its mix rate: {"samples": PackedFloat32Array, "rate": int}. Empty on error.
static func read_wav(path: String) -> Dictionary:
	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.size() < 44 or bytes.slice(0, 4).get_string_from_ascii() != "RIFF":
		return {}
	var channels := 1
	var rate := 0
	var bits := 0
	var offset := 12
	while offset + 8 <= bytes.size():
		var chunk := bytes.slice(offset, offset + 4).get_string_from_ascii()
		var size := bytes.decode_u32(offset + 4)
		if chunk == "fmt ":
			channels = bytes.decode_u16(offset + 10)
			rate = bytes.decode_u32(offset + 12)
			bits = bytes.decode_u16(offset + 22)
		elif chunk == "data" and bits == 16:
			var count := mini(size, bytes.size() - offset - 8) / (2 * channels)
			var samples := PackedFloat32Array()
			samples.resize(count)
			for i in count:
				samples[i] = bytes.decode_s16(offset + 8 + i * 2 * channels) / 32768.0
			return {"samples": samples, "rate": rate}
		offset += 8 + size + (size & 1)
	return {}


## The loudest sample, in dB below full scale (0 dB = full scale, -INF for silence).
static func peak_db(samples: PackedFloat32Array) -> float:
	var peak := 0.0
	for sample in samples:
		peak = maxf(peak, absf(sample))
	return linear_to_db(peak)


## The short-term loudness: the RMS of the loudest [constant SHORT_TERM_WINDOW] stretch, in dB
## below full scale (a full-scale sine is -3 dB). Tells how loud a sound *feels*, which a
## peak doesn't: a short click and a long blast can share a peak.
static func short_term_db(samples: PackedFloat32Array, rate: int) -> float:
	var window := maxi(int(SHORT_TERM_WINDOW * rate), 1)
	var sum := 0.0
	var best := 0.0
	for i in samples.size():
		sum += samples[i] * samples[i]
		if i >= window:
			sum -= samples[i - window] * samples[i - window]
		best = maxf(best, sum)
	return linear_to_db(sqrt(maxf(best, 0.0) / window))


## The RMS of the last [param seconds], in dB (a tail that ends near silence doesn't click).
static func end_db(samples: PackedFloat32Array, rate: int, seconds: float = 0.005) -> float:
	var count := mini(maxi(int(seconds * rate), 1), samples.size())
	var sum := 0.0
	for i in range(samples.size() - count, samples.size()):
		sum += samples[i] * samples[i]
	return linear_to_db(sqrt(sum / maxi(count, 1)))


## The mean of the samples (a DC offset makes a click when a sound starts or stops).
static func dc_offset(samples: PackedFloat32Array) -> float:
	var sum := 0.0
	for sample in samples:
		sum += sample
	return sum / maxi(samples.size(), 1)


## How long the sound stays within [param below_db] of its peak's level, in seconds: from the
## first to the last sample louder than that (its audible length, without a silent end).
static func audible_seconds(samples: PackedFloat32Array, rate: int, below_db: float = 40.0) -> float:
	var threshold := db_to_linear(peak_db(samples) - below_db)
	var first := -1
	var last := -1
	for i in samples.size():
		if absf(samples[i]) >= threshold:
			if first < 0:
				first = i
			last = i
	return 0.0 if first < 0 else float(last - first) / rate


## The share of the energy in each band (below 250 Hz, 250 Hz to 1 kHz, 1 to 4 kHz, above
## 4 kHz), adding up to 1. One-pole filters: a rough picture, enough to tell a boom from a crack.
static func band_shares(samples: PackedFloat32Array, rate: int) -> PackedFloat32Array:
	var alphas := PackedFloat32Array()
	for edge in BAND_EDGES:
		alphas.append(1.0 - exp(-TAU * edge / rate))
	var lows := PackedFloat32Array([0.0, 0.0, 0.0])
	var energy := PackedFloat32Array([0.0, 0.0, 0.0, 0.0])
	for sample in samples:
		for k in 3:
			lows[k] += (sample - lows[k]) * alphas[k]
		energy[0] += lows[0] * lows[0]
		energy[1] += (lows[1] - lows[0]) * (lows[1] - lows[0])
		energy[2] += (lows[2] - lows[1]) * (lows[2] - lows[1])
		energy[3] += (sample - lows[2]) * (sample - lows[2])
	var total := energy[0] + energy[1] + energy[2] + energy[3]
	for k in 4:
		energy[k] = energy[k] / total if total > 0.0 else 0.0
	return energy


## All of the above for the file at [param path]: {"peak_db", "short_term_db", "seconds",
## "audible_seconds", "end_db", "dc", "bands"}. Empty if the file can't be read.
static func measure(path: String) -> Dictionary:
	var wav := read_wav(path)
	if wav.is_empty():
		return {}
	var samples: PackedFloat32Array = wav.samples
	var rate: int = wav.rate
	return {
		"peak_db": peak_db(samples),
		"short_term_db": short_term_db(samples, rate),
		"seconds": float(samples.size()) / rate,
		"audible_seconds": audible_seconds(samples, rate),
		"end_db": end_db(samples, rate),
		"dc": dc_offset(samples),
		"bands": band_shares(samples, rate),
	}
