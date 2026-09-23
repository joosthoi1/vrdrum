extends TestCase

const MAIN := preload("res://scenes/main.tscn")
const DT := 1.0 / 60.0


func make_main() -> Node3D:
	var main: Node3D = MAIN.instantiate()
	add_node(main)
	main.rig.follow_mouse = false
	return main


func play_stroke(rig: Node3D, stick: int) -> void:
	rig.strike(stick)
	for frame in 20:
		rig._process(DT)
		for s in rig.sticks():
			s.step(DT)


func test_desktop_fallback_plays_a_stroke() -> void:
	var main := make_main()
	check(not main.is_xr(), "headless run uses the desktop rig")
	var rig: Node3D = main.rig
	check(rig.has_method("strike"), "desktop rig present")
	var hits: Array[DrumHit] = []
	main.kit.hit.connect(func(h: DrumHit) -> void: hits.append(h))
	check_eq(rig.sticks().size(), 2, "two sticks")
	play_stroke(rig, 1)
	check_eq(hits.size(), 1, "one hit from one stroke")
	if hits.size() == 1:
		check_eq(hits[0].stick_id, 1, "right stick")
		check_eq(hits[0].articulation(), &"snare/head", "lands on the snare head")


func test_every_zone_is_playable_and_has_a_sound() -> void:
	var main := make_main()
	var audio := tree.root.get_node(^"DrumAudio")
	audio.wait_until_ready()
	var rig: Node3D = main.rig
	var hits: Array[DrumHit] = []
	main.kit.hit.connect(func(h: DrumHit) -> void: hits.append(h))
	for piece in main.kit.pieces():
		var radii: PackedFloat32Array = piece.zone_outer_radii
		for zone in radii.size():
			var inner: float = radii[zone - 1] if zone > 0 else 0.0
			rig.aim_at(piece, (inner + radii[zone]) / 2.0)
			hits.clear()
			play_stroke(rig, 1)
			var label := "%s zone %d" % [piece.piece_id, zone]
			check_eq(hits.size(), 1, label + " hit count")
			if hits.size() == 1:
				check_eq(hits[0].piece_id, piece.piece_id, label + " piece")
				check(audio.bank.has(hits[0].articulation()), label + " has samples for " + hits[0].articulation())
