extends TestCase

const DT := 1.0 / 90.0


func test_press_needs_release_before_next() -> void:
	var pedal := PedalTracker.new()
	check_eq(pedal.update(0.3, DT), -1.0, "below threshold")
	check(pedal.update(0.9, DT) >= 0.0, "press")
	check_eq(pedal.update(1.0, DT), -1.0, "held")
	check_eq(pedal.update(0.45, DT), -1.0, "hysteresis: not released yet")
	check_eq(pedal.update(0.8, DT), -1.0, "no retrigger without release")
	check_eq(pedal.update(0.1, DT), -1.0, "released")
	check(pedal.update(0.9, DT) >= 0.0, "second press")


func test_press_intensity_follows_speed() -> void:
	var fast := PedalTracker.new()
	var slow := PedalTracker.new()
	var fast_intensity := fast.update(1.0, DT)
	var slow_intensity := -1.0
	for i in 60:
		var v := slow.update(i / 59.0, DT)
		if v >= 0.0:
			slow_intensity = v
	check(fast_intensity > slow_intensity, "fast %.2f > slow %.2f" % [fast_intensity, slow_intensity])
	check(slow_intensity >= slow.min_intensity, "slow press still sounds")


func test_pedal_input_drives_kick_and_hihat() -> void:
	var kick := DrumPiece.new()
	kick.piece_id = &"kick"
	kick.zone_names = PackedStringArray()
	kick.zone_outer_radii = PackedFloat32Array()
	var hihat := HiHat.new()
	add_node(kick)
	add_node(hihat)
	var pedals: Node = load("res://scripts/kit/pedal_input.gd").new()
	pedals.kick_path = kick.get_path()
	pedals.hihat_path = hihat.get_path()
	add_node(pedals)
	var kicks: Array[DrumHit] = []
	kick.hit.connect(func(h: DrumHit) -> void: kicks.append(h))

	pedals.step(DT)
	check_near(hihat.openness, 1.0, 1e-5, "hat open with no input")
	Input.action_press(&"kick")
	Input.action_press(&"hihat_pedal")
	pedals.step(DT)
	pedals.step(DT)
	Input.action_release(&"kick")
	Input.action_release(&"hihat_pedal")
	check_eq(kicks.size(), 1, "one kick per press")
	if kicks.size() == 1:
		check_eq(kicks[0].articulation(), &"kick/head")
	check(hihat.is_closed(), "hat closed while pedal held")
	pedals.step(DT)
	check_near(hihat.openness, 1.0, 1e-5, "hat reopens on release")
