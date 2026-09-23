extends TestCase

const MAIN := preload("res://scenes/main.tscn")


func test_menu_controls_follow_settings() -> void:
	var menu := SettingsMenu.new()
	add_node(menu)
	var settings := tree.root.get_node(^"Settings")
	var slider := menu.control_for(&"stick_length") as HSlider
	check(slider != null, "stick length slider")
	slider.value = 0.3
	check_near(settings.get_value(&"stick_length"), 0.3, 1e-5, "slider sets the setting")
	settings.set_value(&"stick_length", 0.36)
	check_near(slider.value, 0.36, 1e-5, "setting moves the slider")
	var check_button := menu.control_for(&"left_handed") as CheckButton
	check_button.button_pressed = true
	check_eq(settings.get_value(&"left_handed"), true, "toggle sets the flag")


func test_every_setting_has_a_control() -> void:
	var menu := SettingsMenu.new()
	add_node(menu)
	for key in tree.root.get_node(^"Settings").SPECS:
		check(menu.control_for(key) != null, "%s has a control" % key)


func test_panel_ray_maps_to_pixels() -> void:
	var panel := UiPanel3D.new()
	add_node(panel)
	var content := SettingsMenu.new()
	panel.set_content(content)
	panel.global_position = Vector3(0, 1.5, -1)
	var center = panel.ray_to_pixel(Vector3(0, 1.5, 0), Vector3.FORWARD)
	check(center != null and (center as Vector2).is_equal_approx(Vector2(panel.viewport.size) / 2.0), "centre ray hits the centre")
	var corner = panel.ray_to_pixel(Vector3(-0.45, 1.5 + 0.3, 0), Vector3.FORWARD)
	check(corner != null and corner.x < 100 and corner.y < 150, "top-left ray hits the top-left")
	check(panel.ray_to_pixel(Vector3(2, 1.5, 0), Vector3.FORWARD) == null, "miss beside the panel")
	check(panel.ray_to_pixel(Vector3(0, 1.5, 0), Vector3.BACK) == null, "miss pointing away")


func test_panel_faces_the_player() -> void:
	var panel := UiPanel3D.new()
	add_node(panel)
	panel.face(Transform3D(Basis.IDENTITY, Vector3(0, 1.6, 0)))
	check(panel.global_position.z < -0.5, "in front of the player")
	check(panel.global_basis.z.dot(Vector3.BACK) > 0.99, "front side towards the player")


func test_desktop_menu_and_edit_mode() -> void:
	var main: Node3D = MAIN.instantiate()
	main.get_node("DrumKit").persist = false
	add_node(main)
	check(not main.is_menu_open())
	main.toggle_menu()
	check(main.is_menu_open(), "menu opens")
	check(not main.rig.input_enabled, "rig ignores the mouse under the menu")
	main.start_editing()
	check(not main.is_menu_open() and main.editor.active, "editing from the menu")
	for stick in main.rig.sticks():
		check(not stick.detecting, "sticks silent while editing")
	main.toggle_menu()
	check(not main.editor.active and main.rig.input_enabled, "leaving edit mode")
