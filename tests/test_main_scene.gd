extends TestCase

const MAIN := preload("res://scenes/main.tscn")
const DT := 1.0 / 60.0


func test_desktop_fallback_plays_a_stroke() -> void:
	var main: Node3D = MAIN.instantiate()
	add_node(main)
	check(not main.is_xr(), "headless run uses the desktop rig")
	var rig: Node3D = main.rig
	check(rig != null and rig.has_method("strike"), "desktop rig present")
	if rig == null:
		return
	rig.follow_mouse = false
	var kit: DrumKit = main.kit
	var hits: Array[DrumHit] = []
	kit.hit.connect(func(h: DrumHit) -> void: hits.append(h))
	var sticks: Array[DrumStick] = rig.sticks()
	check_eq(sticks.size(), 2, "two sticks")
	rig.strike(1)
	for frame in 20:
		rig._process(DT)
		for stick in sticks:
			stick.step(DT)
	check_eq(hits.size(), 1, "one hit from one stroke")
	if hits.size() == 1:
		check_eq(hits[0].stick_id, 1, "right stick")
		check_eq(hits[0].zone, &"head", "lands on the head")
