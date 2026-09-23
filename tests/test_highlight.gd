extends TestCase

const KIT := preload("res://scenes/kit/drum_kit.tscn")


class Stub:
	func play_hit(_h: DrumHit) -> void:
		pass

	func choke(_group: StringName) -> void:
		pass


func make_kit() -> DrumKit:
	var kit: DrumKit = KIT.instantiate()
	kit.audio = Stub.new()
	add_node(kit)
	return kit


func strike_at(piece: DrumPiece, offset: float) -> void:
	var point := piece.surface_center() + piece.global_basis.x.normalized() * offset
	piece.register_hit(0, point, -piece.surface_normal() * 4.0)


func test_ride_lights_only_the_zone_hit() -> void:
	var kit := make_kit()
	var ride := kit.piece(&"ride")
	var body := ride.get_node("Body")
	var radii := ride.zone_outer_radii
	for zone in radii.size():
		var inner: float = radii[zone - 1] if zone > 0 else 0.0
		var fresh := make_kit()
		var r := fresh.piece(&"ride")
		var b := r.get_node("Body")
		strike_at(r, (inner + radii[zone]) / 2.0)
		for other in radii.size():
			if other == zone:
				check(b.zone_flash(other) > 0.0, "zone %d lights when hit" % zone)
			else:
				check_eq(b.zone_flash(other), 0.0, "zone %d dark when %d is hit" % [other, zone])
	check_eq(body.zone_flash(0), 0.0, "untouched ride stays dark")


func test_hihat_top_lights_when_hit() -> void:
	var kit := make_kit()
	var hihat := kit.piece(&"hihat")
	strike_at(hihat, 0.1)
	check(hihat.get_node("Top").zone_flash(0) > 0.0, "top cymbal lights up")
	check_eq(hihat.get_node("Bottom").zone_flash(0), 0.0, "bottom cymbal has no highlight")


func test_snare_rim_lights_the_hoop() -> void:
	var kit := make_kit()
	var snare := kit.piece(&"snare")
	var body := snare.get_node("Body")
	strike_at(snare, 0.18)
	check(body.rim_flash() > 0.0 and body.head_flash() == 0.0, "rim hit lights the hoop only")
	var other := make_kit().piece(&"snare")
	strike_at(other, 0.05)
	check(other.get_node("Body").head_flash() > 0.0 and other.get_node("Body").rim_flash() == 0.0, "head hit lights the head only")


func test_highlight_can_be_turned_off() -> void:
	HitHighlight.enabled = false
	var kit := make_kit()
	var snare := kit.piece(&"snare")
	strike_at(snare, 0.05)
	HitHighlight.enabled = true
	check_eq(snare.get_node("Body").head_flash(), 0.0, "no flash when disabled")
