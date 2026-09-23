extends TestCase

const KIT := preload("res://scenes/kit/drum_kit.tscn")


func test_hand_at_edge_chokes_once() -> void:
	var kit: DrumKit = KIT.instantiate()
	var chokes: Array[StringName] = []
	var stub := Stub.new(chokes)
	kit.audio = stub
	add_node(kit)
	var crash := kit.piece(&"crash") as Cymbal
	var hand := Node3D.new()
	hand.add_to_group(&"hands")
	add_node(hand)
	var radius := crash.zone_outer_radii[crash.zone_outer_radii.size() - 1]
	hand.global_position = crash.global_position + crash.global_basis.x.normalized() * (radius - 0.02)
	check(crash.is_hand_at_edge(hand.global_position), "detects the hand")
	crash._process(0.01)
	crash._process(0.01)
	check_eq(chokes, [&"crash"] as Array[StringName], "one choke while held")
	hand.global_position = crash.global_position + Vector3(0, 0.3, 0)
	check(not crash.is_hand_at_edge(hand.global_position), "hand above is not a grab")
	crash._process(0.01)
	hand.global_position = crash.global_position
	check(not crash.is_hand_at_edge(hand.global_position), "centre is not the edge")


func test_hit_wobbles_the_cymbal() -> void:
	var kit: DrumKit = KIT.instantiate()
	kit.audio = Stub.new([])
	add_node(kit)
	var ride := kit.piece(&"ride")
	var body := ride.get_node("Body")
	var point := ride.surface_center() + ride.global_basis.x.normalized() * 0.15
	ride.register_hit(0, point, -ride.surface_normal() * 4.0)
	body._process(1.0 / 90.0)
	check(body.tilt_angle() > 0.0, "tilts after a hit")
	for i in 900:
		body._process(1.0 / 90.0)
	check_near(body.tilt_angle(), 0.0, 1e-3, "settles")


class Stub:
	var chokes: Array[StringName]

	func _init(list: Array[StringName]) -> void:
		chokes = list

	func play_hit(_h: DrumHit) -> void:
		pass

	func choke(group: StringName) -> void:
		chokes.append(group)
