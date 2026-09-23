class_name DrumSynth
extends RefCounted
## Procedurally synthesised placeholder drum sounds.
##
## Lets the kit make noise with no sample files or licensing to sort out. A
## recorded multi-sampled kit can replace these later by filling a
## [DrumSampleBank] with the same articulation keys.

const MIX_RATE := 48000


## Builds the bank for every articulation the kit currently has pieces for.
static func build_default_bank() -> DrumSampleBank:
	var bank := DrumSampleBank.new()
	var layers := 3
	for layer in layers:
		var brightness := (layer + 1.0) / layers
		var head := []
		var rim := []
		for rr in 3:
			head.append(render(snare_params(brightness, rr), 1000 + layer * 16 + rr))
		for rr in 2:
			rim.append(render(rimshot_params(brightness, rr), 2000 + layer * 16 + rr))
		bank.add_layer(&"snare/head", head)
		bank.add_layer(&"snare/rim", rim)
	return bank


static func snare_params(brightness: float, variation: int) -> Dictionary:
	var detune := 1.0 + 0.015 * (variation - 1)
	return {
		"duration": 0.45,
		"tones": [[180.0 * detune, 0.6, 0.07], [330.0 * detune, 0.35, 0.05]],
		"pitch_drop": 0.15,
		"pitch_decay": 0.01,
		"noise_amp": 0.9,
		"noise_decay": 0.13 + 0.04 * brightness,
		"noise_cutoff": lerpf(3500.0, 9000.0, brightness),
		"noise_highpass": 400.0,
		"click_amp": 0.3 * brightness,
	}


static func rimshot_params(brightness: float, variation: int) -> Dictionary:
	var detune := 1.0 + 0.02 * variation
	return {
		"duration": 0.35,
		"tones": [[400.0 * detune, 0.5, 0.03], [1150.0 * detune, 0.4, 0.02], [2200.0, 0.2, 0.01]],
		"noise_amp": 1.0,
		"noise_decay": 0.09,
		"noise_cutoff": lerpf(6000.0, 12000.0, brightness),
		"noise_highpass": 1000.0,
		"click_amp": 0.6,
	}


## Renders a mono 16-bit sample from decaying sine partials plus filtered
## noise. All renders are peak-normalised; loudness comes from playback gain.
##
## Params: duration (s); tones: [[freq_hz, amp, decay_s], ...]; pitch_drop
## (extra pitch at t=0 as a fraction, decaying over pitch_decay s); noise_amp,
## noise_decay, noise_cutoff (low-pass Hz), noise_highpass (Hz, 0 = off);
## click_amp (1 ms noise burst for stick attack).
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
	var noise_amp: float = p.get("noise_amp", 0.0)
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
	var hp_state := 0.0
	var peak := 0.0
	for i in n:
		var s := 0.0
		var fmul := 1.0 + pitch_drop * pitch_env
		pitch_env *= pitch_k
		for j in freqs.size():
			phases[j] += TAU * freqs[j] * fmul * dt
			s += sin(phases[j]) * amps[j] * envs[j]
			envs[j] *= ks[j]
		if noise_amp > 0.0:
			lp += (rng.randf_range(-1.0, 1.0) - lp) * lp_a
			var x := lp
			if hp_a > 0.0:
				hp_state += (x - hp_state) * hp_a
				x -= hp_state
			s += x * noise_amp * noise_env
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
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.data = data
	return wav
