extends TestCase

const DT := 1.0 / 90.0


func make_piece() -> DrumPiece:
	var piece := DrumPiece.new()
	piece.zone_names = PackedStringArray(["head", "rim"])
	piece.zone_outer_radii = PackedFloat32Array([0.16, 0.19])
	add_node(piece)
	return piece


func strike(piece: DrumPiece, stick: int, from: Vector3, to: Vector3) -> DrumHit:
	var t := piece.find_crossing(stick, from, to)
	if t < 0.0:
		return null
	return piece.register_hit(stick, from.lerp(to, t), (to - from) / DT)


func test_center_hit_is_head() -> void:
	var piece := make_piece()
	var emitted: Array[DrumHit] = []
	piece.hit.connect(func(h: DrumHit) -> void: emitted.append(h))
	var h := strike(piece, 0, Vector3(0, 0.02, 0), Vector3(0, -0.02, 0))
	check(h != null, "expected a hit")
	if h:
		check_eq(h.zone, &"head")
		check_eq(h.articulation(), &"snare/head")
		check_near(h.speed, 0.04 / DT, 1e-3)
		check(h.intensity > 0.0 and h.intensity <= 1.0, "intensity in range")
		check_near(h.position.y, 0.0, 1e-5, "hit point on surface")
	check_eq(emitted.size(), 1, "signal emitted once")


func test_rim_zone_and_outside() -> void:
	var piece := make_piece()
	var rim := strike(piece, 0, Vector3(0.18, 0.02, 0), Vector3(0.18, -0.02, 0))
	check(rim != null and rim.zone == &"rim", "rim hit")
	var miss := strike(piece, 1, Vector3(0.3, 0.02, 0), Vector3(0.3, -0.02, 0))
	check(miss == null, "outside radius misses")


func test_no_retrigger_until_lifted() -> void:
	var piece := make_piece()
	check(strike(piece, 0, Vector3(0, 0.02, 0), Vector3(0, -0.01, 0)) != null, "first hit")
	check(not piece.is_armed(0), "disarmed after hit")
	# Jitter: bounces a few mm, below the re-arm height, then back down.
	check_eq(piece.find_crossing(0, Vector3(0, -0.01, 0), Vector3(0, 0.005, 0)), -1.0)
	check(strike(piece, 0, Vector3(0, 0.005, 0), Vector3(0, -0.01, 0)) == null, "jitter does not retrigger")
	# Lift clearly above the surface, then strike again.
	check_eq(piece.find_crossing(0, Vector3(0, -0.01, 0), Vector3(0, 0.05, 0)), -1.0)
	check(piece.is_armed(0), "re-armed after lifting")
	check(strike(piece, 0, Vector3(0, 0.05, 0), Vector3(0, -0.01, 0)) != null, "second hit after lift")


func test_sticks_arm_independently() -> void:
	var piece := make_piece()
	check(strike(piece, 0, Vector3(0, 0.02, 0), Vector3(0, -0.02, 0)) != null, "left")
	check(strike(piece, 1, Vector3(0.05, 0.02, 0), Vector3(0.05, -0.02, 0)) != null, "right unaffected")


func test_slow_contact_is_silent_but_disarms() -> void:
	var piece := make_piece()
	var from := Vector3(0, 0.001, 0)
	var to := Vector3(0, -0.001, 0)
	var t := piece.find_crossing(0, from, to)
	check(t >= 0.0, "crosses")
	check(piece.register_hit(0, from.lerp(to, t), Vector3(0, -0.1, 0)) == null, "too slow to sound")
	check(not piece.is_armed(0), "resting stick disarms")


func test_tilted_piece_uses_its_own_normal() -> void:
	var piece := make_piece()
	piece.rotation = Vector3(PI / 2.0, 0, 0)  # surface normal now +Z
	check(strike(piece, 0, Vector3(0, 0, 0.03), Vector3(0, 0, -0.03)) != null, "strike along -Z")
	check(strike(piece, 1, Vector3(0, 0.03, 0), Vector3(0, -0.03, 0)) == null, "sweeping along the surface is not a hit")
