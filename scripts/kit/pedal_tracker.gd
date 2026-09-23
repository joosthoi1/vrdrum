class_name PedalTracker
extends RefCounted
## Turns an analog (or digital) pedal value into discrete presses with a
## loudness taken from how fast it was pushed. Hysteresis stops a trigger
## resting near the threshold from machine-gunning.

## Value the pedal must reach to count as pressed.
var press_threshold := 0.55
## Value it must drop below before it can press again.
var release_threshold := 0.35
## Push speed (full travel per second) for the softest press...
var min_speed := 2.0
## ...and for the loudest.
var max_speed := 25.0
## Presses never go quieter than this, so a slow squeeze still sounds.
var min_intensity := 0.1

var value := 0.0
var speed := 0.0

var _down := false


## Feeds the latest pedal value (0..1). Returns the press intensity (0..1)
## when this update pressed the pedal, otherwise -1.
func update(new_value: float, delta: float) -> float:
	new_value = clampf(new_value, 0.0, 1.0)
	speed = (new_value - value) / delta if delta > 0.0 else 0.0
	value = new_value
	if _down:
		if value < release_threshold:
			_down = false
		return -1.0
	if value < press_threshold:
		return -1.0
	_down = true
	return maxf(min_intensity, HitMath.intensity_from_speed(speed, min_speed, max_speed))


func is_down() -> bool:
	return _down
