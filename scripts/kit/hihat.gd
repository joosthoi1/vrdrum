class_name HiHat
extends DrumPiece
## Hi-hat: stick hits sound closed, half-open or open depending on the pedal,
## and closing the pedal plays the foot "chick" and cuts the ringing open hat.

## Emitted when the pedal position changes, for visuals.
signal openness_changed(openness: float)

## Openness at or below this counts as closed.
@export var closed_below := 0.15
## Openness at or above this counts as fully open; between is half-open.
@export var open_above := 0.6
## How far the top cymbal lifts when fully open, in metres.
@export var open_lift := 0.025
## Pedal closing speed (openness units per second) for the softest chick.
## Slower closes still choke, but silently.
@export var pedal_min_speed := 1.5
@export var pedal_max_speed := 20.0

## 0 = clamped shut, 1 = fully open.
var openness := 1.0


func _init() -> void:
	piece_id = &"hihat"
	zone_names = PackedStringArray(["bow"])
	zone_outer_radii = PackedFloat32Array([0.19])
	choke_group = &"hihat"


## The playing surface follows the top cymbal as it lifts.
func surface_center() -> Vector3:
	return global_position + surface_normal() * openness * open_lift


## Feeds the pedal position: 0 = foot up (open), 1 = pressed down (closed).
## Returns the pedal "chick" hit when this update closed the hat, else null.
func set_pedal(amount: float, delta: float) -> DrumHit:
	var new_openness := 1.0 - clampf(amount, 0.0, 1.0)
	var was_closed := is_closed()
	var closing_speed := (openness - new_openness) / delta if delta > 0.0 else 0.0
	if not is_equal_approx(new_openness, openness):
		openness = new_openness
		openness_changed.emit(openness)
	if was_closed or not is_closed():
		return null
	if closing_speed < pedal_min_speed:
		choke()
		return null
	var intensity := HitMath.intensity_from_speed(closing_speed, pedal_min_speed, pedal_max_speed)
	return trigger(&"pedal", maxf(intensity, 0.1), choke_group)


## &"closed", &"half" or &"open".
func state_name() -> StringName:
	return _zone_name(0)


func is_closed() -> bool:
	return openness <= closed_below


func _zone_name(_zone_index: int) -> StringName:
	if is_closed():
		return &"closed"
	if openness < open_above:
		return &"half"
	return &"open"
