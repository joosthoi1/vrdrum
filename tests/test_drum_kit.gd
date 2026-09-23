extends TestCase

const KIT := preload("res://scenes/kit/drum_kit.tscn")


class AudioStub:
	var played: Array[DrumHit] = []

	func play_hit(h: DrumHit) -> void:
		played.append(h)


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
