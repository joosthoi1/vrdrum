extends TestCase

const KIT := preload("res://scenes/kit/drum_kit.tscn")
const STICK := preload("res://scenes/sticks/drum_stick.tscn")


class Stub:
	func play_hit(_h: DrumHit) -> void:
		pass

	func choke(_group: StringName) -> void:
		pass


func setup() -> Array:
	var kit: DrumKit = KIT.instantiate()
	kit.audio = Stub.new()
	kit.persist = false
	add_node(kit)
	var stick: DrumStick = STICK.instantiate()
	add_node(stick)
	var editor := KitEditor.new()
	editor.kit = kit
	add_node(editor)
	editor.add_hand(stick, null)
	return [kit, stick, editor]


func place_tip(stick: DrumStick, point: Vector3) -> void:
	stick.global_position += point - stick.tip_position()


func test_grab_moves_piece_with_stick() -> void:
	var parts := setup()
	var kit: DrumKit = parts[0]
	var stick: DrumStick = parts[1]
	var editor: KitEditor = parts[2]
	var tom := kit.piece(&"tom1")
	place_tip(stick, tom.surface_center() + tom.surface_normal() * 0.02)
	check(editor.grab(stick) == null, "no grabbing outside edit mode")
	editor.active = true
	check(not stick.detecting, "sticks stop playing while editing")
	check(editor.grab(stick) == tom, "grabs the touched piece")
	var start := tom.global_position
	stick.global_position += Vector3(0.2, 0.1, 0)
	editor._process(0.016)
	check(tom.global_position.is_equal_approx(start + Vector3(0.2, 0.1, 0)), "piece follows the stick")
	editor.release(stick)
	stick.global_position += Vector3(0.2, 0, 0)
	editor._process(0.016)
	check(tom.global_position.is_equal_approx(start + Vector3(0.2, 0.1, 0)), "released piece stays")
	editor.active = false
	check(stick.detecting, "sticks play again")


func test_nothing_to_grab_in_empty_space() -> void:
	var parts := setup()
	var editor: KitEditor = parts[2]
	editor.active = true
	place_tip(parts[1], Vector3(0, 2.5, 1.5))
	check(editor.grab(parts[1]) == null)


func test_raise_and_tilt() -> void:
	var parts := setup()
	var kit: DrumKit = parts[0]
	var editor: KitEditor = parts[2]
	var snare := kit.piece(&"snare")
	var y := snare.global_position.y
	editor.raise(snare, 0.05)
	check_near(snare.global_position.y, y + 0.05, 1e-5)
	var normal := snare.surface_normal()
	editor.tilt(snare, 0.2)
	check_near(snare.surface_normal().angle_to(normal), 0.2, 1e-4)
