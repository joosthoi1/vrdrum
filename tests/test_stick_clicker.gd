extends TestCase

const STICK := preload("res://scenes/sticks/drum_stick.tscn")
const MAIN := preload("res://scenes/main.tscn")
const DT := 1.0 / 90.0


class KitStub:
	var hits: Array[DrumHit] = []

	func play_external_hit(h: DrumHit) -> void:
		hits.append(h)


## Two sticks crossing in an X: stick A lies along x, stick B along z, and B
## sits [param gap] above A where they cross.
func setup() -> Array:
	var a: DrumStick = STICK.instantiate()
	var b: DrumStick = STICK.instantiate()
	add_node(a)
	add_node(b)
	a.grip_pitch_degrees = 0.0
	b.grip_pitch_degrees = 0.0
	a.rotation = Vector3(0, PI / 2, 0)  # points along -x
	b.rotation = Vector3.ZERO           # points along -z
	var clicker := StickClicker.new()
	clicker.sticks = [a, b] as Array[DrumStick]
	var kit := KitStub.new()
	clicker.kit = kit
	add_node(clicker)
	return [a, b, clicker, kit]


## Places the sticks so their middles cross, B [param gap] metres above A.
func place(a: DrumStick, b: DrumStick, gap: float) -> void:
	var mid_a := (a.butt_position() + a.tip_position()) / 2.0
	a.global_position += Vector3(0, 1.0, -0.5) - mid_a
	var mid_b := (b.butt_position() + b.tip_position()) / 2.0
	b.global_position += Vector3(0, 1.0 + gap, -0.5) - mid_b


func test_tap_clicks_once() -> void:
	var parts := setup()
	var a: DrumStick = parts[0]
	var b: DrumStick = parts[1]
	var clicker: StickClicker = parts[2]
	var kit: KitStub = parts[3]
	for gap in [0.1, 0.06, 0.03, 0.01, 0.012, 0.03, 0.08]:
		place(a, b, gap)
		clicker.step(DT)
	check_eq(kit.hits.size(), 1, "one click per tap")
	if kit.hits.size() == 1:
		check_eq(kit.hits[0].articulation(), &"sticks/click")
		check(kit.hits[0].intensity > 0.0, "has a loudness")
		check(kit.hits[0].position.distance_to(Vector3(0, 1.005, -0.5)) < 0.02, "at the crossing")


func test_fast_tap_passing_through_still_clicks() -> void:
	var parts := setup()
	var a: DrumStick = parts[0]
	var b: DrumStick = parts[1]
	var clicker: StickClicker = parts[2]
	var kit: KitStub = parts[3]
	place(a, b, 0.05)
	clicker.step(DT)
	place(a, b, -0.05)  # 10 cm in one frame: straight through
	clicker.step(DT)
	check_eq(kit.hits.size(), 1, "swept check catches it")
	if kit.hits.size() == 1:
		check(kit.hits[0].intensity > 0.9, "a fast tap is loud")


func test_harder_taps_are_louder() -> void:
	var soft: float = _tap_intensity(0.004)
	var hard: float = _tap_intensity(0.02)
	check(hard > soft, "hard %.2f > soft %.2f" % [hard, soft])


func _tap_intensity(step_size: float) -> float:
	var parts := setup()
	var clicker: StickClicker = parts[2]
	var gap := 0.08
	while gap > 0.005:
		place(parts[0], parts[1], gap)
		clicker.step(DT)
		gap -= step_size
	place(parts[0], parts[1], 0.005)
	clicker.step(DT)
	var kit: KitStub = parts[3]
	return kit.hits[0].intensity if kit.hits.size() == 1 else -1.0


func test_resting_together_is_silent() -> void:
	var parts := setup()
	var clicker: StickClicker = parts[2]
	var kit: KitStub = parts[3]
	for gap in [0.012, 0.0121, 0.012, 0.0119]:
		place(parts[0], parts[1], gap)
		clicker.step(DT)
	check_eq(kit.hits.size(), 0, "no click without movement")


func test_sticks_missing_each_other_are_silent() -> void:
	var parts := setup()
	var a: DrumStick = parts[0]
	var b: DrumStick = parts[1]
	var clicker: StickClicker = parts[2]
	var kit: KitStub = parts[3]
	place(a, b, 0.05)
	clicker.step(DT)
	# Move B down past A, but well to the side of A's tip: no crossing.
	b.global_position += Vector3(1.0, -0.1, 0)
	clicker.step(DT)
	check_eq(kit.hits.size(), 0)


func test_setting_and_edit_mode_disable_clicks() -> void:
	var parts := setup()
	var clicker: StickClicker = parts[2]
	var kit: KitStub = parts[3]
	tree.root.get_node(^"Settings").set_value(&"stick_clicks", false)
	for gap in [0.05, 0.01]:
		place(parts[0], parts[1], gap)
		clicker.step(DT)
	check_eq(kit.hits.size(), 0, "off in settings")
	tree.root.get_node(^"Settings").set_value(&"stick_clicks", true)
	parts[0].detecting = false
	for gap in [0.05, 0.01]:
		place(parts[0], parts[1], gap)
		clicker.step(DT)
	check_eq(kit.hits.size(), 0, "silent while editing the kit")


func test_desktop_tap_plays_the_click_sample() -> void:
	var main: Node3D = MAIN.instantiate()
	main.get_node("DrumKit").persist = false
	add_node(main)
	main.rig.follow_mouse = false
	var audio := tree.root.get_node(^"DrumAudio")
	audio.wait_until_ready()
	var hits: Array[DrumHit] = []
	main.kit.hit.connect(func(h: DrumHit) -> void: hits.append(h))
	main.rig.tap_sticks()
	for frame in 20:
		main.rig._process(1.0 / 60.0)
		for stick in main.rig.sticks():
			stick.step(1.0 / 60.0)
		main.stick_clicker.step(1.0 / 60.0)
	check_eq(hits.size(), 1, "one click")
	if hits.size() == 1:
		check_eq(hits[0].articulation(), &"sticks/click")
		check(audio.bank.has(&"sticks/click"), "recorded kit has the click")
