class_name HitMath
extends RefCounted
## Pure geometry for detecting stick strikes.
##
## A stick tip can travel ~10 cm per frame, so strikes are detected by sweeping
## the segment between last frame's and this frame's tip position against each
## drum surface instead of relying on physics colliders. Nothing here touches
## the scene tree, which keeps it unit-testable headless.


## Returns where along [param p0] -> [param p1] the segment crosses the plane
## while moving against [param normal] (from above to on/below the surface),
## as a fraction in (0, 1]. Returns -1.0 when there is no downward crossing.
static func downward_crossing(p0: Vector3, p1: Vector3, plane_point: Vector3, normal: Vector3) -> float:
	var d0 := (p0 - plane_point).dot(normal)
	var d1 := (p1 - plane_point).dot(normal)
	if d0 <= 0.0 or d1 > 0.0:
		return -1.0
	return d0 / (d0 - d1)


## Distance from [param point] to the axis through [param center] along [param normal].
static func radial_distance(point: Vector3, center: Vector3, normal: Vector3) -> float:
	var offset := point - center
	return (offset - normal * offset.dot(normal)).length()


## Index of the first zone whose outer radius contains [param radius], or -1 if
## it lies outside every zone. [param outer_radii] must be ascending.
static func zone_index(radius: float, outer_radii: PackedFloat32Array) -> int:
	for i in outer_radii.size():
		if radius <= outer_radii[i]:
			return i
	return -1


## Maps a strike speed (m/s along the surface normal) to an intensity in [0, 1].
## [param exponent] shapes the response: below 1 favours soft playing, above 1
## makes loud hits harder to reach.
static func intensity_from_speed(speed: float, min_speed: float, max_speed: float, exponent: float = 1.0) -> float:
	if speed <= min_speed or max_speed <= min_speed:
		return 0.0 if speed <= min_speed else 1.0
	var x := clampf((speed - min_speed) / (max_speed - min_speed), 0.0, 1.0)
	return pow(x, exponent)


## Closest points between segments [param p1]->[param q1] and
## [param p2]->[param q2], as Vector2(s, t): the fractions along each segment
## (both clamped to 0..1). Handles parallel and degenerate segments.
## (Ericson, Real-Time Collision Detection, 5.1.9.)
static func closest_segment_params(p1: Vector3, q1: Vector3, p2: Vector3, q2: Vector3) -> Vector2:
	var d1 := q1 - p1
	var d2 := q2 - p2
	var r := p1 - p2
	var a := d1.dot(d1)
	var e := d2.dot(d2)
	var f := d2.dot(r)
	const EPSILON := 1e-9
	if a <= EPSILON and e <= EPSILON:
		return Vector2.ZERO
	if a <= EPSILON:
		return Vector2(0.0, clampf(f / e, 0.0, 1.0))
	var c := d1.dot(r)
	if e <= EPSILON:
		return Vector2(clampf(-c / a, 0.0, 1.0), 0.0)
	var b := d1.dot(d2)
	var denom := a * e - b * b
	var s := clampf((b * f - c * e) / denom, 0.0, 1.0) if denom > EPSILON else 0.0
	var t := (b * s + f) / e
	if t < 0.0:
		t = 0.0
		s = clampf(-c / a, 0.0, 1.0)
	elif t > 1.0:
		t = 1.0
		s = clampf((b - c) / a, 0.0, 1.0)
	return Vector2(s, t)
