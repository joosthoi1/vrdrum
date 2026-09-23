class_name KitEditor
extends Node
## Layout edit mode: move kit pieces around.
##
## VR: touch a piece with a stick tip and hold that hand's trigger to grab
## it; it follows the stick (position and angle) until released.
## Desktop: drag a piece with the left mouse button; scroll to raise or lower
## it, Shift+scroll to tilt it towards or away from you.
## Sticks don't play while editing, and each change is saved on release.

signal active_changed(active: bool)
signal piece_moved(piece: DrumPiece)

## How close (metres) a stick tip must be to a piece's surface to grab it.
const GRAB_MARGIN := 0.08
const GRAB_HEIGHT := 0.15

var kit: DrumKit
## [stick, controller] pairs used for grabbing in VR.
var hands: Array = []
## Desktop camera for mouse editing (null in VR).
var camera: Camera3D

var active := false:
	set(value):
		if value == active:
			return
		active = value
		for pair in hands:
			pair[0].detecting = not value
		_release_all()
		active_changed.emit(value)

## stick -> {"piece": DrumPiece, "offset": Transform3D}
var _held := {}
var _drag: DrumPiece
var _drag_offset := Vector3.ZERO
var _drag_height := 0.0


## Wires up VR grabbing with each stick and the controller holding it.
func add_hand(stick: DrumStick, controller: XRController3D) -> void:
	hands.append([stick, controller])
	stick.detecting = not active
	if controller:
		controller.button_pressed.connect(func(action: String) -> void:
			if action == "trigger_click":
				grab(stick))
		controller.button_released.connect(func(action: String) -> void:
			if action == "trigger_click":
				release(stick))


## The piece a stick tip is touching, or null.
func piece_near(point: Vector3) -> DrumPiece:
	if kit == null:
		return null
	var best: DrumPiece = null
	var best_distance := INF
	for piece in kit.pieces():
		var center := piece.surface_center()
		var normal := piece.surface_normal()
		var height := absf((point - center).dot(normal))
		var reach := _piece_radius(piece) + GRAB_MARGIN
		var radial := HitMath.radial_distance(point, center, normal)
		if height > GRAB_HEIGHT or radial > reach:
			continue
		var distance := point.distance_to(center)
		if distance < best_distance:
			best_distance = distance
			best = piece
	return best


## Starts holding whatever piece [param stick]'s tip touches.
func grab(stick: DrumStick) -> DrumPiece:
	if not active:
		return null
	var piece := piece_near(stick.tip_position())
	if piece == null:
		return null
	_held[stick] = {"piece": piece, "offset": stick.global_transform.affine_inverse() * piece.global_transform}
	var controller := _controller_for(stick)
	if controller:
		controller.trigger_haptic_pulse(&"haptic", 0.0, 0.5, 0.05, 0.0)
	return piece


func release(stick: DrumStick) -> void:
	if _held.erase(stick) and kit:
		kit.save_current()


func _process(_delta: float) -> void:
	for stick in _held:
		var held: Dictionary = _held[stick]
		var piece: DrumPiece = held.piece
		piece.global_transform = stick.global_transform * held.offset
		piece.reset_arming()
		piece_moved.emit(piece)


func _unhandled_input(event: InputEvent) -> void:
	if not active or camera == null:
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_start_drag(event.position)
			elif _drag:
				_drag = null
				kit.save_current()
			get_viewport().set_input_as_handled()
		elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			var piece := _drag if _drag else pick(event.position)
			if piece:
				var amount := 1.0 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -1.0
				if event.shift_pressed:
					tilt(piece, deg_to_rad(2.0) * amount)
				else:
					raise(piece, 0.01 * amount)
				kit.save_current()
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _drag:
		var point = Plane(Vector3.UP, _drag_height).intersects_ray(
			camera.project_ray_origin(event.position), camera.project_ray_normal(event.position))
		if point != null:
			var target: Vector3 = point + _drag_offset
			_drag.global_position = Vector3(target.x, _drag.global_position.y, target.z)
			_drag.reset_arming()
			piece_moved.emit(_drag)


## The piece under a screen position, or null.
func pick(screen: Vector2) -> DrumPiece:
	var origin := camera.project_ray_origin(screen)
	var direction := camera.project_ray_normal(screen)
	var best: DrumPiece = null
	var best_distance := INF
	for piece in kit.pieces():
		var hit = Plane(piece.surface_normal(), piece.surface_center()).intersects_ray(origin, direction)
		if hit == null or HitMath.radial_distance(hit, piece.surface_center(), piece.surface_normal()) > _piece_radius(piece) + 0.03:
			continue
		var distance := origin.distance_to(hit)
		if distance < best_distance:
			best_distance = distance
			best = piece
	return best


func raise(piece: DrumPiece, amount: float) -> void:
	piece.global_position.y += amount
	piece.reset_arming()
	piece_moved.emit(piece)


## Tilts a piece towards (+) or away from (-) the drummer.
func tilt(piece: DrumPiece, angle: float) -> void:
	var axis := kit.global_basis.x.normalized() if kit else Vector3.RIGHT
	piece.global_basis = Basis(axis, angle) * piece.global_basis
	piece.reset_arming()
	piece_moved.emit(piece)


func _start_drag(screen: Vector2) -> void:
	_drag = pick(screen)
	if _drag == null:
		return
	_drag_height = _drag.global_position.y
	var point = Plane(Vector3.UP, _drag_height).intersects_ray(
		camera.project_ray_origin(screen), camera.project_ray_normal(screen))
	_drag_offset = _drag.global_position - point if point != null else Vector3.ZERO


func _release_all() -> void:
	var had_changes := not _held.is_empty() or _drag != null
	_held.clear()
	_drag = null
	if had_changes and kit:
		kit.save_current()


func _controller_for(stick: DrumStick) -> XRController3D:
	for pair in hands:
		if pair[0] == stick:
			return pair[1]
	return null


## Grab reach: the outermost zone, or a default for pieces sticks can't hit.
static func _piece_radius(piece: DrumPiece) -> float:
	return piece.zone_outer_radii[piece.zone_outer_radii.size() - 1] if not piece.zone_outer_radii.is_empty() else 0.28
