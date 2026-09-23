extends TestCase

const STICK := preload("res://scenes/sticks/drum_stick.tscn")


func test_length_and_angle_follow_settings() -> void:
	var stick: DrumStick = STICK.instantiate()
	add_node(stick)
	var settings := tree.root.get_node(^"Settings")
	settings.set_value(&"stick_length", 0.4)
	check_near(stick.global_position.distance_to(stick.tip_position()), 0.4, 1e-4, "tip moved out")
	settings.set_value(&"stick_angle", 10.0)
	check_near(stick.rotation_degrees.x, 10.0, 1e-4, "angle applied")


func test_desktop_sticks_keep_their_angle() -> void:
	var stick: DrumStick = STICK.instantiate()
	stick.follow_angle_setting = false
	stick.grip_pitch_degrees = -40.0
	add_node(stick)
	tree.root.get_node(^"Settings").set_value(&"stick_angle", 20.0)
	check_near(stick.rotation_degrees.x, -40.0, 1e-4)
