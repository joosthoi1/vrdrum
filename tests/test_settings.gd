extends TestCase


func settings() -> Node:
	return tree.root.get_node(^"Settings")


func test_values_are_clamped_and_signalled() -> void:
	var s := settings()
	var seen := []
	s.changed.connect(func(key: StringName, value: Variant) -> void: seen.append([key, value]))
	s.set_value(&"sensitivity", 10.0)
	check_eq(s.get_value(&"sensitivity"), 2.0, "clamped to max")
	s.set_value(&"sensitivity", 2.0)
	check_eq(seen.size(), 1, "no signal when unchanged")


func test_save_and_load_roundtrip() -> void:
	var s := settings()
	s.set_value(&"stick_length", 0.3)
	s.set_value(&"left_handed", true)
	s.save_settings()
	s.set_value(&"stick_length", 0.4)
	s.set_value(&"left_handed", false)
	s.load_settings()
	check_near(s.get_value(&"stick_length"), 0.3, 1e-5, "length restored")
	check_eq(s.get_value(&"left_handed"), true, "flag restored")


func test_reset_restores_defaults() -> void:
	var s := settings()
	s.set_value(&"dynamics", 1.5)
	s.reset_to_defaults()
	check_eq(s.get_value(&"dynamics"), s.SPECS[&"dynamics"][0])


func test_sensitivity_makes_hits_louder() -> void:
	var piece := DrumPiece.new()
	add_node(piece)
	var velocity := Vector3(0, -3.0, 0)
	var before := piece.register_hit(0, Vector3.ZERO, velocity).intensity
	settings().set_value(&"sensitivity", 1.5)
	piece.reset_arming()
	var after := piece.register_hit(0, Vector3.ZERO, velocity).intensity
	check(after > before, "more sensitive: %.2f > %.2f" % [after, before])


func test_volume_sets_the_bus() -> void:
	settings().set_value(&"volume_toms", 0.5)
	check_near(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(&"Toms")), linear_to_db(0.5), 1e-3)


func test_highlight_setting() -> void:
	settings().set_value(&"highlight_hits", false)
	check(not HitHighlight.enabled, "highlights off")
	settings().set_value(&"highlight_hits", true)
	check(HitHighlight.enabled, "highlights on")


func test_graphics_settings_apply() -> void:
	var s := settings()
	s.set_value(&"msaa", 0)
	check_eq(tree.root.msaa_3d, Viewport.MSAA_DISABLED, "MSAA off")
	s.set_value(&"msaa", 9)
	check_eq(s.get_value(&"msaa"), 3, "choice clamped")
	check_eq(tree.root.msaa_3d, Viewport.MSAA_8X, "MSAA 8x")
	s.set_value(&"render_scale", 0.8)
	check_near(tree.root.scaling_3d_scale, 0.8, 1e-5, "desktop render scale")
	var light := OmniLight3D.new()
	light.shadow_enabled = true
	light.add_to_group(&"shadow_lights")
	add_node(light)
	s.set_value(&"shadows", false)
	check(not light.shadow_enabled, "shadows off")
	s.reset_to_defaults()
