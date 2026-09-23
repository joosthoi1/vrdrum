class_name DrumSynth
extends RefCounted
## Procedurally synthesised placeholder drum sounds.
##
## Lets the kit make noise with no sample files or licensing to sort out. A
## recorded multi-sampled kit can replace these later by filling a
## [DrumSampleBank] with the same articulation keys.
##
## Rendering the whole kit takes a few seconds in GDScript, so renders are
## cached under [constant CACHE_DIR]; bump [constant VERSION] whenever the
## sound design changes to invalidate old caches.

const MIX_RATE := 48000
const VERSION := 4
const CACHE_DIR := "user://synth_cache"

## Inharmonic square-wave partials (TR-808 style) for metallic sounds.
const METAL_FREQS := [205.3, 304.4, 369.6, 522.7, 540.0, 800.0]


## Every articulation the default kit plays: [articulation, layers, variations].
## Round-robin variety for cymbals comes mostly from playback pitch jitter, so
## they get fewer rendered variations.
static func articulations() -> Array:
	return [
		[&"kick/head", 3, 2],
		[&"snare/head", 3, 3],
		[&"snare/rim", 3, 2],
		[&"tom1/head", 3, 2],
		[&"tom2/head", 3, 2],
		[&"tom3/head", 3, 2],
		[&"hihat/closed", 3, 2],
		[&"hihat/half", 2, 2],
		[&"hihat/open", 2, 1],
		[&"hihat/pedal", 1, 2],
		[&"crash/bow", 2, 1],
		[&"crash/edge", 2, 1],
		[&"ride/bow", 3, 2],
		[&"ride/bell", 2, 1],
		[&"ride/edge", 2, 1],
		[&"sticks/click", 3, 2],
	]


## Renders (or loads from cache) every articulation. Safe to call from a
## worker thread. Pass an empty [param cache_dir] to skip the cache.
static func build_default_bank(cache_dir: String = CACHE_DIR) -> DrumSampleBank:
	var bank := DrumSampleBank.new()
	var dir := "%s/v%d" % [cache_dir, VERSION] if cache_dir else ""
	if dir:
		DirAccess.make_dir_recursive_absolute(dir)
	for spec in articulations():
		var articulation: StringName = spec[0]
		var layers: int = spec[1]
		var variations: int = spec[2]
		for layer in layers:
			var brightness := (layer + 1.0) / layers
			var streams := []
			for variation in variations:
				var seed := hash("%s/%d/%d" % [articulation, layer, variation])
				var path := "%s/%s_%d_%d.pcm" % [dir, String(articulation).replace("/", "_"), layer, variation] if dir else ""
				streams.append(_cached_render(path, params_for(articulation, brightness, variation), seed))
			bank.add_layer(articulation, streams)
	return bank


## Cache files are raw 16-bit mono PCM. (Not Resources: ResourceLoader leaks
## an object per load when called from a worker thread.)
static func _cached_render(path: String, params: Dictionary, seed: int) -> AudioStreamWAV:
	if path and FileAccess.file_exists(path):
		var data := FileAccess.get_file_as_bytes(path)
		if not data.is_empty():
			return _wav(data)
	var wav := render(params, seed)
	if path:
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file:
			file.store_buffer(wav.data)
	return wav


static func _wav(data: PackedByteArray) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.data = data
	return wav


## Synth parameters for one articulation, see [method render].
## [param brightness] is 0..1 from soft to loud layer.
static func params_for(articulation: StringName, brightness: float, variation: int) -> Dictionary:
	var detune := 1.0 + 0.015 * (variation - 0.5)
	match articulation:
		&"kick/head":
			return {
				"duration": 0.6,
				"tones": [[52.0 * detune, 1.0, 0.32], [104.0, 0.15, 0.08]],
				"pitch_drop": 1.8, "pitch_decay": 0.028,
				"noise_amp": 0.15, "noise_decay": 0.012, "noise_cutoff": lerpf(2000.0, 5000.0, brightness),
				"click_amp": 0.35 * brightness,
			}
		&"snare/head":
			return {
				"duration": 0.45,
				"tones": [[180.0 * detune, 0.6, 0.07], [330.0 * detune, 0.35, 0.05]],
				"pitch_drop": 0.15, "pitch_decay": 0.01,
				"noise_amp": 0.9, "noise_decay": 0.13 + 0.04 * brightness,
				"noise_cutoff": lerpf(3500.0, 9000.0, brightness), "noise_highpass": 400.0,
				"click_amp": 0.3 * brightness,
			}
		&"snare/rim":
			return {
				"duration": 0.35,
				"tones": [[400.0 * detune, 0.5, 0.03], [1150.0 * detune, 0.4, 0.02], [2200.0, 0.2, 0.01]],
				"noise_amp": 1.0, "noise_decay": 0.09,
				"noise_cutoff": lerpf(6000.0, 12000.0, brightness), "noise_highpass": 1000.0,
				"click_amp": 0.6,
			}
		&"tom1/head", &"tom2/head", &"tom3/head":
			var pitch: float = {&"tom1/head": 210.0, &"tom2/head": 160.0, &"tom3/head": 105.0}[articulation]
			return {
				"duration": 0.8 if pitch > 150.0 else 1.1,
				"tones": [[pitch * detune, 0.9, 0.28], [pitch * 1.6 * detune, 0.25, 0.1]],
				"pitch_drop": 0.35, "pitch_decay": 0.04,
				"noise_amp": 0.25, "noise_decay": 0.05, "noise_cutoff": lerpf(2500.0, 6000.0, brightness),
				"click_amp": 0.25 * brightness,
			}
		&"hihat/closed", &"hihat/half", &"hihat/open", &"hihat/pedal":
			var decay: float = {&"hihat/closed": 0.045, &"hihat/half": 0.22, &"hihat/open": 0.55, &"hihat/pedal": 0.035}[articulation]
			return {
				"duration": minf(decay * 3.5, 1.6) + 0.05,
				"metal_amp": 0.8, "metal_scale": 1.0 + 0.02 * variation,
				"noise_amp": 0.7, "noise_decay": decay,
				"noise_cutoff": lerpf(11000.0, 16000.0, brightness),
				"noise_highpass": 5500.0 if articulation == &"hihat/pedal" else 7000.0,
				"click_amp": 0.15 * brightness,
			}
		&"crash/bow", &"crash/edge":
			var edge := articulation == &"crash/edge"
			return {
				"duration": 2.6,
				"metal_amp": 0.6, "metal_scale": 1.3,
				"noise_amp": 1.0, "noise_decay": 1.3 if edge else 1.0,
				"noise_cutoff": lerpf(7000.0, 13000.0, brightness) * (1.1 if edge else 1.0),
				"noise_highpass": 2200.0 if edge else 3200.0,
				"click_amp": 0.2,
			}
		&"ride/bow":
			return {
				"duration": 2.0,
				"tones": [[3150.0 * detune, 0.35, 0.12], [4720.0, 0.15, 0.08]],
				"metal_amp": 0.35, "metal_scale": 2.1,
				"noise_amp": 0.45, "noise_decay": 0.9,
				"noise_cutoff": lerpf(8000.0, 12000.0, brightness), "noise_highpass": 4500.0,
				"click_amp": 0.3 * brightness,
			}
		&"ride/bell":
			return {
				"duration": 2.2,
				"tones": [[780.0, 0.6, 0.9], [1190.0, 0.45, 0.7], [1655.0, 0.35, 0.5], [2440.0, 0.25, 0.35]],
				"noise_amp": 0.15, "noise_decay": 0.4,
				"noise_cutoff": 9000.0, "noise_highpass": 3000.0,
				"click_amp": 0.3,
			}
		&"ride/edge":
			return {
				"duration": 2.6,
				"tones": [[3150.0, 0.15, 0.1]],
				"metal_amp": 0.6, "metal_scale": 1.6,
				"noise_amp": 0.9, "noise_decay": 1.4,
				"noise_cutoff": lerpf(6000.0, 10000.0, brightness), "noise_highpass": 2500.0,
				"click_amp": 0.2,
			}
		&"sticks/click":
			return {
				"duration": 0.12,
				"tones": [[2500.0 * detune, 0.5, 0.015], [3900.0 * detune, 0.3, 0.01]],
				"noise_amp": 0.6, "noise_decay": 0.012,
				"noise_cutoff": lerpf(7000.0, 12000.0, brightness), "noise_highpass": 1500.0,
				"click_amp": 0.5,
			}
	push_error("No synth parameters for %s" % articulation)
	return {"duration": 0.1}


## Renders a mono 16-bit sample from decaying sine partials, plus a noise and
## metallic (square-wave) source through shared low-pass and high-pass
## filters. All renders are peak-normalised; loudness comes from playback gain.
##
## Params: duration (s); tones: [[freq_hz, amp, decay_s], ...]; pitch_drop
## (extra pitch at t=0 as a fraction, decaying over pitch_decay s); noise_amp,
## metal_amp, metal_scale (multiplies [constant METAL_FREQS]), noise_decay
## (envelope for noise and metal), noise_cutoff (low-pass Hz), noise_highpass
## (Hz, 0 = off, two cascaded stages); click_amp (1 ms noise burst for the
## stick attack).
static func render(p: Dictionary, seed: int) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var dt := 1.0 / MIX_RATE
	var n := int(float(p.get("duration", 0.4)) * MIX_RATE)
	var tones: Array = p.get("tones", [])
	var freqs := PackedFloat64Array()
	var amps := PackedFloat64Array()
	var envs := PackedFloat64Array()
	var ks := PackedFloat64Array()
	for tone in tones:
		freqs.append(tone[0])
		amps.append(tone[1])
		envs.append(1.0)
		ks.append(exp(-dt / float(tone[2])))
	var phases := PackedFloat64Array()
	phases.resize(tones.size())
	var pitch_drop: float = p.get("pitch_drop", 0.0)
	var pitch_env := 1.0
	var pitch_k := exp(-dt / float(p.get("pitch_decay", 0.02)))

	var metal_amp: float = p.get("metal_amp", 0.0)
	var metal_steps := PackedFloat64Array()
	var metal_phases := PackedFloat64Array()
	if metal_amp > 0.0:
		for f in METAL_FREQS:
			metal_steps.append(f * float(p.get("metal_scale", 1.0)) * dt)
			metal_phases.append(rng.randf())
	var metal_norm := metal_amp / maxf(1.0, metal_steps.size())

	var noise_amp: float = p.get("noise_amp", 0.0)
	var noisy := noise_amp > 0.0 or metal_amp > 0.0
	var noise_env := 1.0
	var noise_k := exp(-dt / float(p.get("noise_decay", 0.1)))
	var lp_a := 1.0 - exp(-TAU * float(p.get("noise_cutoff", 8000.0)) * dt)
	var hp_cutoff: float = p.get("noise_highpass", 0.0)
	var hp_a := 1.0 - exp(-TAU * hp_cutoff * dt) if hp_cutoff > 0.0 else 0.0
	var click_amp: float = p.get("click_amp", 0.0)
	var click_len := int(0.001 * MIX_RATE)
	var fade_len := int(0.005 * MIX_RATE)

	var samples := PackedFloat32Array()
	samples.resize(n)
	var lp := 0.0
	var hp1 := 0.0
	var hp2 := 0.0
	var peak := 0.0
	for i in n:
		var s := 0.0
		var fmul := 1.0 + pitch_drop * pitch_env
		pitch_env *= pitch_k
		for j in freqs.size():
			phases[j] += TAU * freqs[j] * fmul * dt
			s += sin(phases[j]) * amps[j] * envs[j]
			envs[j] *= ks[j]
		if noisy:
			var x := rng.randf_range(-1.0, 1.0) * noise_amp
			for j in metal_steps.size():
				metal_phases[j] = fmod(metal_phases[j] + metal_steps[j], 1.0)
				x += metal_norm if metal_phases[j] < 0.5 else -metal_norm
			lp += (x - lp) * lp_a
			x = lp
			if hp_a > 0.0:
				hp1 += (x - hp1) * hp_a
				x -= hp1
				hp2 += (x - hp2) * hp_a
				x -= hp2
			s += x * noise_env
			noise_env *= noise_k
		if i < click_len:
			s += click_amp * (1.0 - float(i) / click_len) * rng.randf_range(-1.0, 1.0)
		if i >= n - fade_len:
			s *= float(n - i) / fade_len
		samples[i] = s
		peak = maxf(peak, absf(s))

	var scale := 0.9 / peak if peak > 0.0 else 0.0
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		data.encode_s16(i * 2, int(clampf(samples[i] * scale, -1.0, 1.0) * 32767.0))
	return _wav(data)
