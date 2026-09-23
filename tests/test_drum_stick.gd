extends TestCase

const DT := 1.0 / 90.0
const STICK := preload("res://scenes/sticks/drum_stick.tscn")
const SNARE := preload("res://scenes/kit/pieces/snare.tscn")


func make_stick() -> DrumStick:
	var stick: DrumStick = STICK.instantiate()
	add_node(stick)
	return stick


func make_snare(y: float) -> DrumPiece:
	var snare: DrumPiece = SNARE.instantiate()
	snare.position = Vector3(0, y, 0)
	add_node(snare)
	return snare


## Moves the stick so its tip sits at [param tip], then runs one frame.
func move_tip(stick: DrumStick, tip: Vector3) -> DrumHit:
	stick.global_position += tip - stick.tip_position()
	return stick.step(DT)


func test_stroke_produces_one_hit() -> void:
	var snare := make_snare(0.75)
	var stick := make_stick()
	var hits: Array[DrumHit] = []
	stick.struck.connect(func(h: DrumHit) -> void: hits.append(h))
	for y in [0.9, 0.85, 0.8, 0.76, 0.73, 0.74, 0.78, 0.85]:
		move_tip(stick, Vector3(0, y, 0))
	check_eq(hits.size(), 1, "hit count")
	if hits.size() == 1:
		check_eq(hits[0].piece_id, snare.piece_id)
		check_near(hits[0].speed, 0.03 / DT, 1e-3, "speed of the crossing frame")


func test_fast_stroke_is_not_missed() -> void:
	make_snare(0.75)
	var stick := make_stick()
	move_tip(stick, Vector3(0, 0.85, 0))
	# 12 cm in one 90 Hz frame (~11 m/s): a collider would tunnel through.
	var h := move_tip(stick, Vector3(0, 0.73, 0))
	check(h != null, "swept test catches it")
	if h:
		check_eq(h.intensity, 1.0, "full intensity")


func test_tracking_glitch_is_ignored() -> void:
	make_snare(0.75)
	var stick := make_stick()
	move_tip(stick, Vector3(0, 1.5, 0))
	check(move_tip(stick, Vector3(0, 0.7, 0)) == null, "teleport through the drum is not a hit")


func test_earliest_crossing_wins() -> void:
	var upper := make_snare(0.75)
	upper.piece_id = &"upper"
	var lower := make_snare(0.70)
	lower.piece_id = &"lower"
	var stick := make_stick()
	move_tip(stick, Vector3(0, 0.8, 0))
	var h := move_tip(stick, Vector3(0, 0.65, 0))
	check(h != null and h.piece_id == &"upper", "top surface is hit first")


func test_first_frame_never_hits() -> void:
	make_snare(0.75)
	var stick := make_stick()
	stick.global_position += Vector3(0, 0.7, 0) - stick.tip_position()
	check(stick.step(DT) == null, "no previous position yet")
