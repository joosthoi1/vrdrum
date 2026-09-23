extends Node3D
## Non-VR fallback for development and testing without a headset.
##
## Sticks hover over the point under the mouse. Left click (or J) strikes with
## the right stick, right click (or F) with the left stick. Hold Shift for a
## soft stroke. Strokes are animated through the same tip-sweep detection the
## VR rig uses.

@export var hover_height := 0.12
@export var stroke_depth := 0.02
@export var stroke_down_time := 0.03
@export var soft_stroke_down_time := 0.09
@export var stroke_up_time := 0.12
## Horizontal offset of each stick from the aim point, [left, right].
@export var stick_spacing := 0.07
## Aim at the point under the mouse. Off in tests, where there is no mouse.
@export var follow_mouse := true

var _surface_y := 0.75
var _aim := Vector3(0.0, 0.75, -0.35)
## Per stick: time into the current stroke (INF = idle) and its down time.
var _stroke_t: Array[float] = [INF, INF]
var _stroke_down: Array[float] = [0.03, 0.03]

@onready var camera: Camera3D = $Camera3D
@onready var _sticks: Array[DrumStick] = [$LeftStick, $RightStick]


func _ready() -> void:
	var piece := get_tree().get_first_node_in_group(DrumPiece.GROUP) as DrumPiece
	if piece:
		_surface_y = piece.global_position.y
		_aim = piece.global_position
	for i in _sticks.size():
		_sticks[i].global_position += _target_tip(i, hover_height) - _sticks[i].tip_position()
		_sticks[i].reset_tracking()


func sticks() -> Array[DrumStick]:
	return _sticks


## Starts a stroke with stick 0 (left) or 1 (right).
func strike(index: int, soft: bool = false) -> void:
	_stroke_t[index] = 0.0
	_stroke_down[index] = soft_stroke_down_time if soft else stroke_down_time


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			strike(1, event.shift_pressed)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			strike(0, event.shift_pressed)
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_J:
			strike(1, event.shift_pressed)
		elif event.keycode == KEY_F:
			strike(0, event.shift_pressed)


func _process(delta: float) -> void:
	_update_aim()
	for i in _sticks.size():
		var tip := _target_tip(i, _advance_stroke(i, delta))
		_sticks[i].global_position += tip - _sticks[i].tip_position()


## Returns the tip height above the surface for this frame.
func _advance_stroke(i: int, delta: float) -> float:
	var down := _stroke_down[i]
	var prev := _stroke_t[i]
	if prev == INF:
		return hover_height
	var t := prev + delta
	# Always pass through the bottom, even if a slow frame skips past it.
	if prev < down and t >= down:
		_stroke_t[i] = down
		return -stroke_depth
	_stroke_t[i] = t
	if t < down:
		return lerpf(hover_height, -stroke_depth, t / down)
	if t < down + stroke_up_time:
		return lerpf(-stroke_depth, hover_height, (t - down) / stroke_up_time)
	_stroke_t[i] = INF
	return hover_height


func _target_tip(i: int, height: float) -> Vector3:
	var side := -1.0 if i == 0 else 1.0
	return Vector3(_aim.x + side * stick_spacing, _surface_y + height, _aim.z)


func _update_aim() -> void:
	if not follow_mouse:
		return
	var viewport := get_viewport()
	if viewport == null or viewport.get_visible_rect().size == Vector2.ZERO:
		return
	var mouse := viewport.get_mouse_position()
	var hit = Plane(Vector3.UP, _surface_y).intersects_ray(camera.project_ray_origin(mouse), camera.project_ray_normal(mouse))
	if hit != null:
		_aim = hit
