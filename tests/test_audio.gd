extends TestCase


func audio() -> Node:
	var node := tree.root.get_node_or_null(^"DrumAudio")
	check(node != null, "DrumAudio autoload present")
	if node:
		node.wait_until_ready()
	return node


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
	var params := DrumSynth.params_for(&"snare/head", 1.0, 0)
	var wav := DrumSynth.render(params, 7)
	var expected_len := int(params.duration * DrumSynth.MIX_RATE) * 2
	check_eq(wav.data.size(), expected_len, "16-bit mono length")
	var peak := 0
	for i in range(0, wav.data.size(), 2):
		peak = maxi(peak, absi(wav.data.decode_s16(i)))
	check(peak > 28000 and peak <= 32767, "normalised peak %d" % peak)
	check_eq(DrumSynth.render(params, 7).data, wav.data, "deterministic for a seed")


func test_every_articulation_has_params() -> void:
	for spec in DrumSynth.articulations():
		var params := DrumSynth.params_for(spec[0], 1.0, 0)
		check(params.get("duration", 0.0) >= 0.1, "%s has a real sound" % spec[0])


func test_recorded_kit_covers_every_articulation() -> void:
	var bank := SampleKit.load_bank()
	check(bank != null, "recorded kit loads")
	if bank == null:
		return
	check(bank.natural_dynamics, "recorded layers carry dynamics")
	for spec in DrumSynth.articulations():
		check(bank.layer_count(spec[0]) >= 3, "%s has velocity layers" % spec[0])


func test_autoload_uses_recorded_kit() -> void:
	var node := audio()
	if node:
		check(node.bank.natural_dynamics, "DrumAudio prefers the recorded kit")


func test_synth_fallback_covers_every_articulation() -> void:
	var bank := DrumSynth.build_default_bank()
	for spec in DrumSynth.articulations():
		check_eq(bank.layer_count(spec[0]), spec[1], "%s layers" % spec[0])


func test_recorded_gain_rises_with_intensity() -> void:
	var bank := SampleKit.load_bank()
	if bank == null:
		return
	for articulation in bank.articulations():
		var last := -INF
		var last_layer := -1
		for i in 21:
			var intensity := i / 20.0
			var layer := bank.layer_for(articulation, intensity)
			var db := bank.gain_db_for(articulation, intensity)
			check(db <= 0.01, "%s never boosts" % articulation)
			if layer == last_layer:
				check(db >= last, "%s gain rises within a layer" % articulation)
			last = db
			last_layer = layer


func test_bus_routing() -> void:
	check_eq(load("res://scripts/audio/drum_audio.gd").bus_for(&"tom2/head"), &"Toms")
	check_eq(load("res://scripts/audio/drum_audio.gd").bus_for(&"ride/bell"), &"Cymbals")
	check_eq(load("res://scripts/audio/drum_audio.gd").bus_for(&"hihat/pedal"), &"HiHat")
	for bus in [&"Drums", &"Kick", &"Snare", &"Toms", &"HiHat", &"Cymbals"]:
		check(AudioServer.get_bus_index(bus) != -1, "bus %s exists" % bus)


func test_voice_pool_never_runs_out() -> void:
	var node := audio()
	if node == null:
		return
	for i in 100:
		check(node.play(&"snare/head", 0.5) != null, "voice %d" % i)


func test_choke_only_hits_its_group() -> void:
	var node := audio()
	if node == null:
		return
	node.choke(&"crash")
	node.choke(&"ride")
	node.play(&"crash/bow", 1.0, &"crash")
	node.play(&"crash/edge", 1.0, &"crash")
	node.play(&"ride/bow", 1.0, &"ride")
	check_eq(node.choke(&"crash"), 2, "both crash voices choked")
	check_eq(node.choke(&"crash"), 0, "already choked")
	check_eq(node.choke(&"ride"), 1, "ride untouched by crash choke")


func test_hit_that_chokes_cuts_the_group_first() -> void:
	var node := audio()
	if node == null:
		return
	node.choke(&"hihat")
	node.play(&"hihat/open", 1.0, &"hihat")
	var chick := DrumHit.new()
	chick.piece_id = &"hihat"
	chick.zone = &"pedal"
	chick.intensity = 0.7
	chick.choke_group = &"hihat"
	chick.chokes = &"hihat"
	check(node.play_hit(chick) != null, "chick plays")
	check_eq(node.choke(&"hihat"), 1, "only the chick is left ringing")


func test_hits_pan_towards_the_drum() -> void:
	var node := audio()
	if node == null:
		return
	var camera := Camera3D.new()
	add_node(camera)
	camera.current = true
	var center: int = node.PAN_STEPS.size() / 2
	check_eq(node.pan_step_for(Vector3(0, 0, -1)), center, "straight ahead is centred")
	check(node.pan_step_for(Vector3(-1, 0, -0.5)) < center, "left of the head pans left")
	check(node.pan_step_for(Vector3(1, 0, -0.5)) > center, "right of the head pans right")
	check_eq(node.pan_step_for(null), center, "no position is centred")
	var voice: AudioStreamPlayer = node.play(&"hihat/closed", 0.5, &"hihat", Vector3(-1, 0, -0.5))
	check(String(voice.bus).begins_with("HiHat_p"), "routed through a hi-hat pan bus, got %s" % voice.bus)
	camera.rotation.y = PI / 2  # turn the head left: the same spot is now ahead
	check_eq(node.pan_step_for(Vector3(-1, 0, 0)), center, "panning follows the head")


func test_pan_buses_follow_spatial_strength() -> void:
	var node := audio()
	if node == null:
		return
	tree.root.get_node(^"Settings").set_value(&"spatial_audio", 0.8)
	var left := AudioServer.get_bus_index(&"Toms_p0")
	check(left != -1, "pan bus exists")
	check_near((AudioServer.get_bus_effect(left, 0) as AudioEffectPanner).pan, -0.8, 1e-4, "hard left scaled by strength")
	check_eq(AudioServer.get_bus_send(left), &"Toms", "pan bus feeds its group")
