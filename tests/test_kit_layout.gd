extends TestCase

const KIT := preload("res://scenes/kit/drum_kit.tscn")


class Stub:
	func play_hit(_h: DrumHit) -> void:
		pass

	func choke(_group: StringName) -> void:
		pass


func make_kit(persist: bool = false) -> DrumKit:
	var kit: DrumKit = KIT.instantiate()
	kit.audio = Stub.new()
	kit.persist = persist
	add_node(kit)
	return kit


func same(a: Transform3D, b: Transform3D) -> bool:
	return a.is_equal_approx(b)


func test_transform_roundtrip() -> void:
	var t := Transform3D(Basis(Vector3(0.3, 1, 0.2).normalized(), 0.7), Vector3(1, 2, 3))
	check(same(KitLayout.from_array(KitLayout.to_array(t)), t))


func test_mirror_twice_is_identity_and_keeps_handedness() -> void:
	var t := Transform3D(Basis.from_euler(Vector3(0.2, 0.4, 0.1)), Vector3(0.5, 1, -0.3))
	var m := KitLayout.mirror_transform(t)
	check_near(m.origin.x, -0.5, 1e-6, "x flipped")
	check_near(m.basis.determinant(), 1.0, 1e-5, "still a rotation")
	check(same(KitLayout.mirror_transform(m), t), "mirroring twice restores")


func test_left_handed_moves_hihat_to_the_right() -> void:
	var kit := make_kit()
	var hihat := kit.piece(&"hihat")
	var right_x := hihat.position.x
	check(right_x < 0.0, "right-handed hi-hat on the left")
	kit.set_left_handed(true)
	check_near(hihat.position.x, -right_x, 1e-5, "mirrored to the right")
	check_near(kit.layout().pieces.hihat[9], right_x, 1e-5, "layout() stays right-handed")
	kit.set_left_handed(false)
	check_near(hihat.position.x, right_x, 1e-5, "back again")


func test_edits_survive_switching_hands() -> void:
	var kit := make_kit()
	var tom := kit.piece(&"tom1")
	kit.set_left_handed(true)
	tom.position.y += 0.1
	var edited_y := tom.position.y
	kit.set_left_handed(false)
	check_near(tom.position.y, edited_y, 1e-5, "height edit kept")


func test_presets_and_slots() -> void:
	var kit := make_kit()
	var ride := kit.piece(&"ride")
	var default_pos := ride.position
	kit.load_preset("compact")
	check(ride.position.distance_to(kit.piece(&"snare").position) < default_pos.distance_to(kit.piece(&"snare").position), "compact is tighter")
	kit.save_slot(1)
	kit.load_preset("default")
	check(ride.position.is_equal_approx(default_pos), "default restored")
	check(kit.load_slot(1), "slot 1 loads")
	check(not ride.position.is_equal_approx(default_pos), "slot 1 has the compact layout")
	check(not kit.load_slot(3), "empty slot")


func test_layout_persists_between_sessions() -> void:
	var kit := make_kit(true)
	kit.piece(&"crash").position += Vector3(0.1, 0.05, 0)
	kit.calibrate_height(1.0)
	var crash_pos := kit.piece(&"crash").global_position
	var again := make_kit(true)
	check(again.piece(&"crash").global_position.is_equal_approx(crash_pos), "restored at startup")


func test_recenter_puts_the_drummer_at_the_head() -> void:
	var kit := make_kit()
	var head := Transform3D(Basis(Vector3.UP, PI / 2), Vector3(1, 1.6, 2))
	kit.recenter(head)
	check(kit.global_position.is_equal_approx(Vector3(1, kit.global_position.y, 2)), "origin under the head")
	var snare_dir := (kit.piece(&"snare").global_position - kit.global_position)
	snare_dir.y = 0
	check(snare_dir.normalized().dot(-head.basis.z) > 0.9, "kit in front of where the head faces")
