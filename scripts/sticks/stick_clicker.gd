class_name StickClicker
extends Node
## Plays a click when the two drumsticks are tapped together, like a
## drummer counting in.
##
## Each stick is a segment from butt to tip. The sticks click when they come
## within [constant CONTACT] of each other, or when they passed right through
## each other between two frames (a fast tap can cover several centimetres
## per frame). How hard is taken from the relative speed of the two contact
## points. After a click the sticks must separate by [constant RELEASE]
## before they can click again.

signal clicked(hit: DrumHit)

## Stick shafts are ~1.4 cm thick together; a few mm of slack for tracking.
const CONTACT := 0.018
## Separation needed before the next click.
const RELEASE := 0.035
## Only look for pass-throughs when the sticks were at least this close.
const NEAR := 0.15
## Relative speed (m/s) for the softest and the loudest click.
const MIN_SPEED := 0.3
const MAX_SPEED := 4.0

var sticks: Array[DrumStick] = []
## Receives the clicks: anything with [code]play_external_hit(hit)[/code]
## (the [DrumKit]).
var kit: Object
var enabled := true

## Previous frame's segments: [butt_a, tip_a, butt_b, tip_b].
var _prev: Array[Vector3] = []
var _armed := true


func _ready() -> void:
	# After the sticks have moved and done their own hit detection.
	process_priority = 110
	var settings := get_node_or_null(^"/root/Settings")
	if settings:
		enabled = settings.get_value(&"stick_clicks")
		settings.changed.connect(func(key: StringName, value: Variant) -> void:
			if key == &"stick_clicks":
				enabled = value)


func _process(delta: float) -> void:
	step(delta)


## Checks the sticks once. Public so tests can drive it. Returns the click,
## if there was one.
func step(delta: float) -> DrumHit:
	if sticks.size() != 2:
		return null
	var now: Array[Vector3] = [sticks[0].butt_position(), sticks[0].tip_position(),
		sticks[1].butt_position(), sticks[1].tip_position()]
	var prev := _prev
	_prev = now
	if prev.is_empty() or delta <= 0.0 or not enabled:
		return null
	if not (sticks[0].detecting and sticks[1].detecting):
		_armed = true
		return null
	for i in 4:
		if now[i].distance_to(prev[i]) > sticks[0].max_frame_travel:
			return null  # tracking glitch

	var st := HitMath.closest_segment_params(now[0], now[1], now[2], now[3])
	var a := now[0].lerp(now[1], st.x)
	var b := now[2].lerp(now[3], st.y)
	var distance := a.distance_to(b)

	var touching := distance < CONTACT
	if not touching and _armed:
		touching = _passed_through(prev, now, st)
	if not _armed:
		if distance > RELEASE:
			_armed = true
		return null
	if not touching:
		return null

	_armed = false
	# Velocity of the contact point on each stick, from where that same point
	# along the stick was last frame.
	var va := (a - prev[0].lerp(prev[1], st.x)) / delta
	var vb := (b - prev[2].lerp(prev[3], st.y)) / delta
	var speed := (va - vb).length()
	if speed < MIN_SPEED:
		return null  # sticks resting against each other
	return _click(a.lerp(b, 0.5), speed)


## True if the sticks were close last frame and have crossed to the other
## side of each other since.
func _passed_through(prev: Array[Vector3], now: Array[Vector3], st: Vector2) -> bool:
	var prev_st := HitMath.closest_segment_params(prev[0], prev[1], prev[2], prev[3])
	var pa := prev[0].lerp(prev[1], prev_st.x)
	var pb := prev[2].lerp(prev[3], prev_st.y)
	if pa.distance_to(pb) > NEAR or pa.distance_to(pb) < 1e-6:
		return false
	# Crossing only counts along the shafts, not past an end.
	for param in [prev_st.x, prev_st.y, st.x, st.y]:
		if param <= 0.0 or param >= 1.0:
			return false
	var before := pb - pa
	var after := now[2].lerp(now[3], st.y) - now[0].lerp(now[1], st.x)
	return before.dot(after) < 0.0


func _click(position: Vector3, speed: float) -> DrumHit:
	var h := DrumHit.new()
	h.piece_id = &"sticks"
	h.zone = &"click"
	h.speed = speed
	h.intensity = HitMath.intensity_from_speed(speed, MIN_SPEED, MAX_SPEED, 0.8)
	h.position = position
	h.stick_id = -1
	h.time_usec = Time.get_ticks_usec()
	for stick in sticks:
		stick.pulse(h.intensity)
		stick.flash(h.intensity)
	if kit:
		kit.play_external_hit(h)
	clicked.emit(h)
	return h
