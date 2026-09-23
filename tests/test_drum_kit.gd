extends TestCase

const KIT := preload("res://scenes/kit/drum_kit.tscn")


class AudioStub:
	var played: Array[DrumHit] = []

	func play_hit(h: DrumHit) -> void:
		played.append(h)

	func choke(_group: StringName) -> void:
		pass


func test_hits_reach_audio_and_kit_signal() -> void:
	var kit: DrumKit = KIT.instantiate()
	var stub := AudioStub.new()
	kit.audio = stub
	add_node(kit)
	var forwarded: Array[DrumHit] = []
	kit.hit.connect(func(h: DrumHit) -> void: forwarded.append(h))
	var snare := kit.get_node("Snare") as DrumPiece
	snare.register_hit(0, snare.global_position, -snare.surface_normal() * 3.0)
	check_eq(stub.played.size(), 1, "audio got the hit")
	check_eq(forwarded.size(), 1, "kit re-emitted the hit")


func test_calibrate_height_moves_snare_under_tips() -> void:
	var kit: DrumKit = KIT.instantiate()
	kit.audio = AudioStub.new()
	add_node(kit)
	kit.calibrate_height(1.1, 0.06)
	check_near((kit.get_node("Snare") as Node3D).global_position.y, 1.04, 1e-4)


func test_kit_has_full_layout() -> void:
	var kit: DrumKit = KIT.instantiate()
	kit.audio = AudioStub.new()
	add_node(kit)
	var ids: Array[StringName] = []
	for p in kit.pieces():
		ids.append(p.piece_id)
	for id in [&"kick", &"snare", &"hihat", &"tom1", &"tom2", &"tom3", &"crash", &"ride"]:
		check(id in ids, "kit has %s" % id)
	check(kit.piece(&"hihat") is HiHat, "hi-hat piece")
	check(kit.piece(&"crash") is Cymbal and kit.piece(&"ride") is Cymbal, "cymbals choke")


func test_pieces_do_not_overlap_from_above() -> void:
	# A vertical stroke on the centre of one piece must not cross another
	# piece first, or that drum would be unplayable.
	var kit: DrumKit = KIT.instantiate()
	kit.audio = AudioStub.new()
	add_node(kit)
	for target in kit.pieces():
		if target.zone_outer_radii.is_empty():
			continue
		var center := target.surface_center()
		var from := center + Vector3.UP * 0.12
		var to := center - Vector3.UP * 0.02
		for other in kit.pieces():
			if other == target:
				continue
			var t := other.find_crossing(99, from, to)
			check(t < 0.0, "%s blocks %s" % [other.piece_id, target.piece_id])
