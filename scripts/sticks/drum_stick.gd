class_name DrumStick
extends Node3D
## A drumstick whose tip is swept against every [DrumPiece] each frame.
##
## The stick is purely kinematic: something else moves it (an [XRController3D]
## parent in VR, the desktop rig otherwise). Detection runs in [method _process]
## so it uses the pose for the frame being rendered, not a physics tick.

signal struck(hit: DrumHit)

@export var stick_id := 0
## Pitch of the stick relative to the controller grip pose, in degrees.
## Negative tilts the tip down.
@export var grip_pitch_degrees := -15.0:
	set(value):
		grip_pitch_degrees = value
		rotation_degrees.x = value
## Distance from the grip to the tip, in metres.
@export var length := 0.32:
	set(value):
		length = value
		_apply_length()
## Take length (and angle, if [member follow_angle_setting]) from the
## Settings autoload.
@export var follow_settings := true
@export var follow_angle_setting := true
## Tip travel above this in one frame is treated as a tracking glitch.
@export var max_frame_travel := 0.5
@export var haptics_enabled := true
@export var haptic_duration := 0.03

## Off while editing the kit layout: the stick then never hits anything.
var detecting := true
## Tip velocity over the last frame, in m/s (world space).
var tip_velocity := Vector3.ZERO

var _prev_tip := Vector3.ZERO
var _has_prev := false

@onready var _tip: Node3D = $Tip


func _ready() -> void:
	rotation_degrees.x = grip_pitch_degrees
	# Run after whatever drives the stick (desktop rig, XR controller updates).
	process_priority = 100
	var settings := get_node_or_null(^"/root/Settings")
	if follow_settings and settings:
		length = settings.get_value(&"stick_length")
		if follow_angle_setting:
			grip_pitch_degrees = settings.get_value(&"stick_angle")
		settings.changed.connect(_on_setting_changed)
	_apply_length()


func _process(delta: float) -> void:
	step(delta)


func tip_position() -> Vector3:
	return _tip.global_position


## Advances tip tracking by one frame and detects strikes. Public so tests can
## drive it deterministically.
func step(delta: float) -> DrumHit:
	var tip := tip_position()
	if not _has_prev or delta <= 0.0:
		_prev_tip = tip
		_has_prev = true
		return null
	var travel := tip - _prev_tip
	var p0 := _prev_tip
	_prev_tip = tip
	if travel.length() > max_frame_travel:
		tip_velocity = Vector3.ZERO
		return null
	tip_velocity = travel / delta
	return _detect(p0, tip)


## Moves the tip marker and resizes the stick model: the butt stays 8 cm
## behind the grip, the tip is [member length] in front of it.
func _apply_length() -> void:
	if not is_inside_tree():
		return
	var tip := get_node_or_null(^"Tip") as Node3D
	var mesh := get_node_or_null(^"Mesh") as MeshInstance3D
	if tip:
		tip.position = Vector3(0, 0, -length)
	if mesh and mesh.mesh is CylinderMesh:
		var cylinder := (mesh.mesh as CylinderMesh).duplicate() as CylinderMesh
		cylinder.height = length + 0.08
		mesh.mesh = cylinder
		mesh.position = Vector3(0, 0, (0.08 - length) / 2.0)
	reset_tracking()


func _on_setting_changed(key: StringName, value: Variant) -> void:
	if key == &"stick_length":
		length = value
	elif key == &"stick_angle" and follow_angle_setting:
		grip_pitch_degrees = value
		reset_tracking()


## Forget the previous tip position, e.g. after teleporting the stick.
func reset_tracking() -> void:
	_has_prev = false
	tip_velocity = Vector3.ZERO


func _detect(p0: Vector3, p1: Vector3) -> DrumHit:
	if not detecting:
		return null
	var best: DrumPiece = null
	var best_t := INF
	# Every piece must see every frame so it can re-arm; only the earliest
	# crossing along the swept segment gets the hit.
	for piece in DrumPiece.all:
		var t := piece.find_crossing(stick_id, p0, p1)
		if t >= 0.0 and t < best_t:
			best_t = t
			best = piece
	if best == null:
		return null
	var h := best.register_hit(stick_id, p0.lerp(p1, best_t), tip_velocity)
	if h:
		_pulse(h.intensity)
		struck.emit(h)
	return h


func _pulse(intensity: float) -> void:
	var controller := get_parent() as XRNode3D
	if haptics_enabled and controller:
		controller.trigger_haptic_pulse(&"haptic", 0.0, lerpf(0.2, 1.0, intensity), haptic_duration, 0.0)
