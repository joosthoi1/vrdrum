extends TestCase


func test_layer_selection_and_round_robin() -> void:
	var bank := DrumSampleBank.new()
	var soft := [AudioStreamWAV.new(), AudioStreamWAV.new()]
	var mid := [AudioStreamWAV.new()]
	var loud := [AudioStreamWAV.new()]
	bank.add_layer(&"snare/head", soft)
	bank.add_layer(&"snare/head", mid)
	bank.add_layer(&"snare/head", loud)
	check_eq(bank.layer_for(&"snare/head", 0.0), 0)
	check_eq(bank.layer_for(&"snare/head", 0.5), 1)
	check_eq(bank.layer_for(&"snare/head", 1.0), 2)
	var first := bank.pick(&"snare/head", 0.1)
	var second := bank.pick(&"snare/head", 0.1)
	check(first != second, "round robin alternates")
	check(first in soft and second in soft, "stays in the soft layer")
	check(bank.pick(&"missing", 0.5) == null, "unknown articulation")


func test_gain_curve() -> void:
	check_near(DrumSampleBank.gain_db(1.0, -30.0), 0.0, 1e-3, "full")
	check_near(DrumSampleBank.gain_db(0.0, -30.0), -30.0, 1e-3, "softest")
	check(DrumSampleBank.gain_db(0.5, -30.0) > DrumSampleBank.gain_db(0.25, -30.0), "monotonic")


func test_synth_render() -> void:
	var params := DrumSynth.snare_params(1.0, 0)
	var wav := DrumSynth.render(params, 7)
	var expected_len := int(params.duration * DrumSynth.MIX_RATE) * 2
	check_eq(wav.data.size(), expected_len, "16-bit mono length")
	var peak := 0
	for i in range(0, wav.data.size(), 2):
		peak = maxi(peak, absi(wav.data.decode_s16(i)))
	check(peak > 28000 and peak <= 32767, "normalised peak %d" % peak)
	check_eq(DrumSynth.render(params, 7).data, wav.data, "deterministic for a seed")


func test_default_bank_covers_snare() -> void:
	var bank := DrumSynth.build_default_bank()
	check_eq(bank.layer_count(&"snare/head"), 3)
	check_eq(bank.layer_count(&"snare/rim"), 3)


func test_voice_pool_never_runs_out() -> void:
	var audio := tree.root.get_node_or_null(^"DrumAudio")
	check(audio != null, "DrumAudio autoload present")
	if audio == null:
		return
	for i in 50:
		check(audio.play(&"snare/head", 0.5) != null, "voice %d" % i)
