extends TestCase

const DT := 1.0 / 90.0


func make_hihat() -> HiHat:
	var hihat := HiHat.new()
	add_node(hihat)
	return hihat


func test_stick_articulation_follows_pedal() -> void:
	var hihat := make_hihat()
	var from := Vector3(0.05, 0.05, 0)
	var to := Vector3(0.05, -0.05, 0)
	hihat.set_pedal(0.0, DT)
	var open := hihat.register_hit(0, from.lerp(to, hihat.find_crossing(0, from, to)), (to - from) / DT)
	check(open != null and open.articulation() == &"hihat/open", "foot up = open")
	hihat.set_pedal(0.6, DT)
	check_eq(hihat.state_name(), &"half")
	hihat.set_pedal(1.0, DT)
	check_eq(hihat.state_name(), &"closed")
	var closed := hihat.emit_hit(hihat._zone_name(0), 0.5, 1.0, Vector3.ZERO, 0)
	check_eq(closed.articulation(), &"hihat/closed")
	check_eq(closed.choke_group, &"hihat")


func test_surface_rises_when_open() -> void:
	var hihat := make_hihat()
	hihat.set_pedal(1.0, DT)
	check_near(hihat.surface_center().y, 0.0, 1e-5, "closed")
	hihat.set_pedal(0.0, DT)
	check_near(hihat.surface_center().y, hihat.open_lift, 1e-5, "open")


func test_fast_close_plays_chick_and_chokes() -> void:
	var hihat := make_hihat()
	var hits: Array[DrumHit] = []
	hihat.hit.connect(func(h: DrumHit) -> void: hits.append(h))
	hihat.set_pedal(0.0, DT)
	var chick := hihat.set_pedal(1.0, DT)
	check(chick != null, "chick")
	if chick:
		check_eq(chick.articulation(), &"hihat/pedal")
		check_eq(chick.chokes, &"hihat", "cuts the open hat")
		check_eq(chick.stick_id, -1, "pedal hit")
	check(hihat.set_pedal(1.0, DT) == null, "holding closed does not repeat")
	check_eq(hits.size(), 1)


func test_slow_close_chokes_silently() -> void:
	var hihat := make_hihat()
	var chokes: Array[StringName] = []
	hihat.choked.connect(func(g: StringName) -> void: chokes.append(g))
	hihat.set_pedal(0.0, DT)
	var chick: DrumHit = null
	for i in 90:
		var hit := hihat.set_pedal(i / 89.0, 1.0)
		if hit:
			chick = hit
	check(chick == null, "no chick from a slow close")
	check_eq(chokes, [&"hihat"] as Array[StringName], "still chokes")
