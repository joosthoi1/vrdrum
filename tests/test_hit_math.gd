extends TestCase


func test_crossing_downward_through_plane() -> void:
	var t := HitMath.downward_crossing(Vector3(0, 0.1, 0), Vector3(0, -0.1, 0), Vector3.ZERO, Vector3.UP)
	check_near(t, 0.5)


func test_crossing_fraction_is_proportional() -> void:
	var t := HitMath.downward_crossing(Vector3(0, 0.3, 0), Vector3(0, -0.1, 0), Vector3.ZERO, Vector3.UP)
	check_near(t, 0.75)


func test_no_crossing_moving_up() -> void:
	check_eq(HitMath.downward_crossing(Vector3(0, -0.1, 0), Vector3(0, 0.1, 0), Vector3.ZERO, Vector3.UP), -1.0)


func test_no_crossing_staying_above_or_below() -> void:
	check_eq(HitMath.downward_crossing(Vector3(0, 0.2, 0), Vector3(0, 0.1, 0), Vector3.ZERO, Vector3.UP), -1.0, "above")
	check_eq(HitMath.downward_crossing(Vector3(0, -0.1, 0), Vector3(0, -0.2, 0), Vector3.ZERO, Vector3.UP), -1.0, "below")


func test_touching_surface_counts_starting_on_it_does_not() -> void:
	check_near(HitMath.downward_crossing(Vector3(0, 0.1, 0), Vector3(0, 0, 0), Vector3.ZERO, Vector3.UP), 1.0)
	check_eq(HitMath.downward_crossing(Vector3(0, 0, 0), Vector3(0, -0.1, 0), Vector3.ZERO, Vector3.UP), -1.0)


func test_crossing_tilted_plane() -> void:
	var normal := Vector3(0, 1, 1).normalized()
	var t := HitMath.downward_crossing(Vector3(0, 0, 0.2), Vector3(0, 0, -0.2), Vector3.ZERO, normal)
	check_near(t, 0.5)


func test_radial_distance_ignores_height() -> void:
	check_near(HitMath.radial_distance(Vector3(0.3, 0.5, 0.4), Vector3.ZERO, Vector3.UP), 0.5)
	check_near(HitMath.radial_distance(Vector3(1, 2, 3), Vector3(1, 0, 3), Vector3.UP), 0.0)


func test_zone_index() -> void:
	var radii := PackedFloat32Array([0.1, 0.2])
	check_eq(HitMath.zone_index(0.05, radii), 0)
	check_eq(HitMath.zone_index(0.1, radii), 0)
	check_eq(HitMath.zone_index(0.15, radii), 1)
	check_eq(HitMath.zone_index(0.25, radii), -1)


func test_intensity_curve() -> void:
	check_eq(HitMath.intensity_from_speed(0.1, 0.25, 7.0), 0.0, "below min")
	check_eq(HitMath.intensity_from_speed(0.25, 0.25, 7.0), 0.0, "at min")
	check_near(HitMath.intensity_from_speed(3.625, 0.25, 7.0), 0.5, 1e-4, "linear midpoint")
	check_eq(HitMath.intensity_from_speed(7.0, 0.25, 7.0), 1.0, "at max")
	check_eq(HitMath.intensity_from_speed(20.0, 0.25, 7.0), 1.0, "clamped")
	check(HitMath.intensity_from_speed(3.625, 0.25, 7.0, 0.8) > 0.5, "exponent < 1 lifts soft hits")


func test_intensity_is_monotonic() -> void:
	var last := -1.0
	for i in 100:
		var v := HitMath.intensity_from_speed(i * 0.1, 0.25, 7.0, 0.8)
		check(v >= last, "decreased at speed %.1f" % (i * 0.1))
		last = v
