extends Node3D
## Non-VR fallback for development and testing without a headset.
##
## Point at any drum or cymbal with the mouse. Left click (or J) strikes it
## with the right stick, right click (or F) with the left stick. Hold Shift for
## a soft stroke. Strokes are animated through the same tip-sweep detection the
## VR rig uses. Pedals come from pedal_input.gd (Space = kick, V = hi-hat).

@export var hover_height := 0.12
@export var stroke_depth := 0.02
@export var stroke_down_time := 0.03
@export var soft_stroke_down_time := 0.09
@export var stroke_up_time := 0.12
## Sideways offset of an idle stick from the aim point.
@export var stick_spacing := 0.07
## Aim at the piece under the mouse. Off in tests, where there is no mouse.
@export var follow_mouse := true
## Off while the menu or the kit editor is using the mouse.
var input_enabled := true

## Point strokes land on, and the surface normal there.
var aim := Vector3(0.0, 0.75, -0.35)
var aim_normal := Vector3.UP

## Per stick: time into the current stroke (INF = idle) and its down time.
var _stroke_t: Array[float] = [INF, INF]
var _stroke_down: Array[float] = [0.03, 0.03]
## Per stick: aim point and normal locked in when its stroke started.
var _stroke_aim: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var _stroke_normal: Array[Vector3] = [Vector3.UP, Vector3.UP]

@onready var camera: Camera3D = $Camera3D
@onready var _sticks: Array[DrumStick] = [$LeftStick, $RightStick]


func _ready() -> void:
	var snare := _find_piece(&"snare")
	if snare:
		aim_at(snare)
	for i in _sticks.size():
		_place_tip(i, _tip_target(i, hover_height))
		_sticks[i].reset_tracking()


func sticks() -> Array[DrumStick]:
	return _sticks


## Aims at the centre of [param piece] (or a point on it).
func aim_at(piece: DrumPiece, offset: float = 0.0) -> void:
	aim_normal = piece.surface_normal()
	var along := piece.global_basis.x.normalized() * offset
	aim = piece.surface_center() + along


## Starts a stroke with stick 0 (left) or 1 (right). The stroke begins with
## one frame hovering over the aim point, so moving there is never swept
## together with the downstroke (at low frame rates that would look like one
## huge tracking glitch and be ignored).
func strike(index: int, soft: bool = false) -> void:
	_stroke_t[index] = -1.0
	_stroke_aim[index] = aim
	_stroke_normal[index] = aim_normal
	_stroke_down[index] = soft_stroke_down_time if soft else stroke_down_time


func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled:
		return
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
		_place_tip(i, _tip_target(i, _advance_stroke(i, delta)))


## Returns the tip height above the surface for this frame.
func _advance_stroke(i: int, delta: float) -> float:
	var down := _stroke_down[i]
	var prev := _stroke_t[i]
	if prev == INF:
		return hover_height
	if prev < 0.0:
		_stroke_t[i] = 0.0
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


## The striking stick comes down on its locked aim point along the surface
## normal; an idle stick hovers beside the current aim.
func _tip_target(i: int, height: float) -> Vector3:
	if _stroke_t[i] != INF:
		return _stroke_aim[i] + _stroke_normal[i] * height
	var target := aim + aim_normal * height
	target.x += (-1.0 if i == 0 else 1.0) * stick_spacing
	return target


## Moves a stick so its tip is at [param tip]. Sideways moves (re-aiming)
## teleport the stick, so gliding over to another drum never sweeps through
## whatever is in between; only strokes along the normal are detected.
func _place_tip(i: int, tip: Vector3) -> void:
	var stick := _sticks[i]
	var move := tip - stick.tip_position()
	var normal := _stroke_normal[i] if _stroke_t[i] != INF else aim_normal
	var sideways := move - normal * move.dot(normal)
	stick.global_position += move
	if sideways.length() > 0.005:
		stick.reset_tracking()
		stick.step(0.0)


func _update_aim() -> void:
	if not follow_mouse or not input_enabled:
		return
	var viewport := get_viewport()
	if viewport == null or viewport.get_visible_rect().size == Vector2.ZERO:
		return
	var mouse := viewport.get_mouse_position()
	var origin := camera.project_ray_origin(mouse)
	var direction := camera.project_ray_normal(mouse)
	var best_distance := INF
	for node in get_tree().get_nodes_in_group(DrumPiece.GROUP):
		var piece := node as DrumPiece
		if piece.zone_outer_radii.is_empty():
			continue
		var hit = Plane(piece.surface_normal(), piece.surface_center()).intersects_ray(origin, direction)
		if hit == null or piece.zone_at(hit) < 0:
			continue
		var distance := origin.distance_to(hit)
		if distance < best_distance:
			best_distance = distance
			aim = hit
			aim_normal = piece.surface_normal()


func _find_piece(id: StringName) -> DrumPiece:
	for node in get_tree().get_nodes_in_group(DrumPiece.GROUP):
		if (node as DrumPiece).piece_id == id:
			return node
	return null
