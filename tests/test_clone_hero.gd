extends TestCase

const KIT := preload("res://scenes/kit/drum_kit.tscn")


class FakePort:
	var sent: Array = []

	func send(status: int, data1: int, data2: int) -> bool:
		sent.append([status, data1, data2])
		return true


class AudioStub:
	var played := 0

	func play_hit(_h: DrumHit) -> void:
		played += 1

	func choke(_group: StringName) -> void:
		pass


class FakeCapture:
	var frames: Array = []
	var size := Vector2i.ZERO
	var started := 0

	func start(_title: String, _max_width: int) -> bool:
		started += 1
		return true

	func stop() -> void:
		pass

	func fetch_frame() -> PackedByteArray:
		return frames.pop_front() if not frames.is_empty() else PackedByteArray()

	func get_frame_size() -> Vector2i:
		return size

	var status := "Capturing (fake)"

	func get_status() -> String:
		return status

	func push(w: int, h: int) -> void:
		size = Vector2i(w, h)
		var data := PackedByteArray()
		data.resize(w * h * 4)
		frames.append(data)


func make_kit(audio: Object = null) -> DrumKit:
	var kit: DrumKit = KIT.instantiate()
	kit.audio = audio if audio else AudioStub.new()
	kit.persist = false
	add_node(kit)
	return kit


func make_bridge(kit: DrumKit) -> Array:
	var bridge := MidiBridge.new()
	bridge.kit = kit
	add_node(bridge)
	var port := FakePort.new()
	bridge.port = port
	bridge.enabled = true
	return [bridge, port]


func strike(kit: DrumKit, id: StringName, offset: float = 0.05) -> void:
	var piece := kit.piece(id)
	var point := piece.surface_center() + piece.global_basis.x.normalized() * offset
	piece.register_hit(0, point, -piece.surface_normal() * 4.0)


# --- Note map ---

func test_every_articulation_maps_in_both_presets() -> void:
	for spec in DrumSynth.articulations():
		var articulation: StringName = spec[0]
		for preset in [DrumMidiMap.Preset.CLONE_HERO, DrumMidiMap.Preset.GENERAL_MIDI]:
			var note := DrumMidiMap.note_for(articulation, preset)
			if articulation == &"sticks/click":
				check_eq(note, -1, "stick clicks are never sent")
			else:
				check(note >= 35 and note <= 81, "%s has a GM drum note (preset %d)" % [articulation, preset])


func test_clone_hero_preset_covers_every_lane() -> void:
	var sent := {}
	for articulation in DrumMidiMap.CLONE_HERO_NOTES:
		sent[DrumMidiMap.note_for(articulation)] = true
	for lane in DrumMidiMap.LANES:
		check(sent.has(lane[1]), "%s lane is played by some pad" % lane[0])
	check_eq(DrumMidiMap.note_for(&"snare/rim"), DrumMidiMap.note_for(&"snare/head"), "one note per pad")
	check(DrumMidiMap.note_for(&"snare/rim", DrumMidiMap.Preset.GENERAL_MIDI) != 38, "GM rimshot has its own note")


func test_velocity_range() -> void:
	check_eq(DrumMidiMap.velocity_for(0.0), 1)
	check_eq(DrumMidiMap.velocity_for(1.0), 127)
	check_eq(DrumMidiMap.velocity_for(5.0), 127, "clamped")
	check(DrumMidiMap.velocity_for(0.5) > 50 and DrumMidiMap.velocity_for(0.5) < 80)


# --- Bridge ---

func test_hits_send_note_on_then_off() -> void:
	var kit := make_kit()
	var parts := make_bridge(kit)
	var bridge: MidiBridge = parts[0]
	var port: FakePort = parts[1]
	strike(kit, &"snare")
	check_eq(port.sent.size(), 1, "note-on straight away")
	if port.sent.size() == 1:
		check_eq(port.sent[0][0], 0x99, "note-on, channel 10")
		check_eq(port.sent[0][1], 38, "snare note")
		check(port.sent[0][2] >= 1 and port.sent[0][2] <= 127, "velocity")
	bridge.send_due_note_offs(Time.get_ticks_msec())
	check_eq(port.sent.size(), 1, "note-off waits")
	bridge.send_due_note_offs(Time.get_ticks_msec() + 1000)
	check_eq(port.sent.size(), 2, "then the note-off")
	if port.sent.size() == 2:
		check_eq(port.sent[1], [0x89, 38, 0])


func test_pedals_send_and_stick_clicks_dont() -> void:
	var kit := make_kit()
	var parts := make_bridge(kit)
	var port: FakePort = parts[1]
	kit.piece(&"kick").trigger(&"head", 0.8)
	check(port.sent.size() == 1 and port.sent[0][1] == 36, "kick pedal sends 36")
	var click := DrumHit.new()
	click.piece_id = &"sticks"
	click.zone = &"click"
	kit.play_external_hit(click)
	check_eq(port.sent.size(), 1, "stick click not sent")


func test_disabled_bridge_sends_nothing() -> void:
	var kit := make_kit()
	var parts := make_bridge(kit)
	parts[0].enabled = false
	strike(kit, &"tom1")
	check_eq(parts[1].sent.size(), 0)


func test_general_midi_preset() -> void:
	var kit := make_kit()
	var parts := make_bridge(kit)
	parts[0].preset = DrumMidiMap.Preset.GENERAL_MIDI
	strike(kit, &"snare", 0.18)  # rim zone
	check(parts[1].sent.size() == 1 and parts[1].sent[0][1] == 40, "GM rimshot")


func test_kit_sounds_off_still_sends_midi() -> void:
	var audio := AudioStub.new()
	var kit := make_kit(audio)
	var parts := make_bridge(kit)
	tree.root.get_node(^"Settings").set_value(&"kit_sounds", false)
	strike(kit, &"crash", 0.2)
	check_eq(audio.played, 0, "no kit sound")
	check_eq(parts[1].sent.size(), 1, "MIDI still sent")
	tree.root.get_node(^"Settings").set_value(&"kit_sounds", true)
	strike(kit, &"crash", 0.2)
	check_eq(audio.played, 1, "sounds back on")


func test_lane_colours_follow_midi_setting() -> void:
	var kit := make_kit()
	var settings := tree.root.get_node(^"Settings")
	var hoop_material = func() -> Material: return kit.piece(&"snare").get_node("Body")._hoop.material_override
	var chrome: Material = hoop_material.call()
	settings.set_value(&"midi_enabled", true)
	var tinted: Material = hoop_material.call()
	check(tinted != chrome and (tinted as StandardMaterial3D).albedo_color.is_equal_approx(DrumMidiMap.RED), "snare hoop turns red")
	settings.set_value(&"lane_colors", false)
	check((hoop_material.call() as StandardMaterial3D).metallic == 1.0, "back to chrome")
	settings.set_value(&"midi_enabled", false)


func test_settings_keep_strings() -> void:
	var settings := tree.root.get_node(^"Settings")
	settings.set_value(&"midi_port", "loopMIDI Port 1")
	settings.save_settings()
	settings.set_value(&"midi_port", "")
	settings.load_settings()
	check_eq(settings.get_value(&"midi_port"), "loopMIDI Port 1")


func test_without_a_port_status_explains() -> void:
	var bridge := MidiBridge.new()
	add_node(bridge)
	bridge.set_enabled(true)
	check(bridge.port == null, "nothing opened")
	check(bridge.status != "", "status explains why: %s" % bridge.status)
	bridge.set_enabled(false)


# --- Native extension (Linux build in tests) ---

func test_native_extension_loads_and_is_safe() -> void:
	if not ClassDB.class_exists(&"MidiOut"):
		return  # extension not built for this platform
	var names = ClassDB.class_call_static(&"MidiOut", &"get_port_names")
	check(names is PackedStringArray, "port list")
	var midi: Object = ClassDB.instantiate(&"MidiOut")
	check(not midi.send(0x90, 38, 100), "send without an open port fails quietly")
	check(not midi.open_port(9999), "bad port index fails quietly")
	check(midi.get_last_error() != "", "with a reason")
	var capture: Object = ClassDB.instantiate(&"WindowCapture")
	if OS.get_name() != "Windows":
		check(not capture.is_supported(), "capture is Windows only")
		check(not capture.start("Clone Hero", 1280), "start refuses")
		check(capture.fetch_frame().is_empty(), "no frames")


# --- Screen ---

func test_screen_shows_frames_at_their_aspect() -> void:
	var kit := make_kit()
	var screen: GameScreen = kit.get_node("GameScreen")
	var fake := FakeCapture.new()
	screen.source = fake
	screen.set_active(true)
	check_eq(fake.started, 1, "capture started")
	fake.push(200, 100)
	screen._process(0.016)
	check_eq(screen.frame_size, Vector2i(200, 100))
	var quad: MeshInstance3D = screen._quad
	check((quad.mesh as QuadMesh).size.is_equal_approx(Vector2(screen.width, screen.width / 2.0)), "2:1 frame, 2:1 screen")
	check(quad.visible, "picture shown")
	fake.push(160, 90)
	screen._process(0.016)
	check((quad.mesh as QuadMesh).size.is_equal_approx(Vector2(screen.width, screen.width * 90.0 / 160.0)), "resized to 16:9")
	for i in 100:
		screen._process(0.016)
	check(quad.visible, "a still picture stays up while no new frames arrive")
	fake.status = "The window is minimized"
	screen._process(1.0)
	check(not quad.visible and screen._label.visible, "problems replace the picture with the reason")
	screen.set_active(false)
	check(not screen.visible, "hidden when off")


func test_screen_without_capture_explains() -> void:
	if GameScreen.is_available():
		return
	var kit := make_kit()
	var screen: GameScreen = kit.get_node("GameScreen")
	screen.set_active(true)
	check(screen.status() != "" and screen._label.visible, "status shown: %s" % screen.status())
	screen.set_active(false)


func test_screen_is_part_of_the_layout_and_not_mirrored() -> void:
	var kit := make_kit()
	var screen: Node3D = kit.get_node("GameScreen")
	screen.position = Vector3(0.3, 1.7, -1.2)
	var data := kit.layout()
	check(data.extras.has("screen"), "saved with the layout")
	kit.set_left_handed(true)
	check_near(screen.position.x, 0.3, 1e-5, "left-handed play doesn't mirror the screen")
	kit.set_left_handed(false)
	var other := make_kit()
	other.apply_layout(data, false, false)
	check(other.get_node("GameScreen").position.is_equal_approx(Vector3(0.3, 1.7, -1.2)), "restored")


func test_kit_editor_can_grab_the_screen() -> void:
	var kit := make_kit()
	var screen: GameScreen = kit.get_node("GameScreen")
	screen.source = FakeCapture.new()
	screen.set_active(true)
	var editor := KitEditor.new()
	editor.kit = kit
	add_node(editor)
	check(editor.piece_near(screen.grab_center() + screen.grab_normal() * 0.03) == screen, "screen within reach")
	screen.set_active(false)
	check(editor.piece_near(screen.grab_center() + screen.grab_normal() * 0.03) != screen, "hidden screen can't be grabbed")
