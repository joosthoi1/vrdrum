@tool
extends Node3D
## Procedural cymbal visuals with a spring wobble when hit.
## Place under a [DrumPiece] ([Cymbal] or [HiHat]). Geometry is regenerated
## from the exported values (also in the editor) and never saved.

@export var radius := 0.23:
	set(value):
		radius = value
		_rebuild()
@export var bell_radius := 0.06:
	set(value):
		bell_radius = value
		_rebuild()
## Upside down, for the hi-hat's bottom cymbal.
@export var flipped := false:
	set(value):
		flipped = value
		_rebuild()
@export var stand := true:
	set(value):
		stand = value
		_rebuild()
## Lift with the parent [HiHat]'s openness (top hi-hat cymbal).
@export var follow_hihat := false
## Wobble spring stiffness and damping.
@export var stiffness := 90.0
@export var damping := 3.5
## Wobble kick per unit hit intensity, in rad/s.
@export var hit_impulse := 1.6
@export var max_tilt := 0.35

var _pivot: Node3D
## Small-angle tilt (axis * angle) and its angular velocity, in local space.
var _tilt := Vector3.ZERO
var _spin := Vector3.ZERO


func _ready() -> void:
	_rebuild()
	if Engine.is_editor_hint():
		return
	var piece := get_parent() as DrumPiece
	if piece:
		piece.hit.connect(_on_hit)
		piece.choked.connect(_on_choked)


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or _pivot == null:
		return
	if follow_hihat:
		var hihat := get_parent() as HiHat
		if hihat:
			_pivot.position.y = hihat.openness * hihat.open_lift
	if _tilt == Vector3.ZERO and _spin == Vector3.ZERO:
		return
	_spin += (-stiffness * _tilt - damping * _spin) * delta
	_tilt += _spin * delta
	if _tilt.length() > max_tilt:
		_tilt = _tilt.normalized() * max_tilt
	if _tilt.length() < 0.0005 and _spin.length() < 0.005:
		_tilt = Vector3.ZERO
		_spin = Vector3.ZERO
	_pivot.basis = Basis(_tilt.normalized(), _tilt.length()) if _tilt != Vector3.ZERO else Basis.IDENTITY


## Current wobble angle in radians.
func tilt_angle() -> float:
	return _tilt.length()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	for child in get_children():
		if child.has_meta(&"generated"):
			child.free()
	_pivot = Node3D.new()
	_pivot.set_meta(&"generated", true)
	add_child(_pivot)

	var bronze := StandardMaterial3D.new()
	bronze.albedo_color = Color(0.83, 0.66, 0.3)
	bronze.metallic = 0.85
	bronze.roughness = 0.3
	bronze.cull_mode = BaseMaterial3D.CULL_DISABLED
	var direction := -1.0 if flipped else 1.0

	var plate := CylinderMesh.new()
	plate.top_radius = bell_radius
	plate.bottom_radius = radius
	plate.height = 0.012
	plate.radial_segments = 48
	plate.rings = 1
	plate.cap_top = false
	plate.cap_bottom = false
	# Centred on the playing surface so edge hits line up with the visual.
	var plate_instance := _add(plate, bronze, Vector3.ZERO)
	if flipped:
		plate_instance.rotation.x = PI

	var bell := SphereMesh.new()
	bell.radius = bell_radius
	bell.height = bell_radius * 0.5
	bell.radial_segments = 24
	bell.rings = 8
	_add(bell, bronze, Vector3(0, 0.004 * direction, 0))

	if stand:
		var pole := CylinderMesh.new()
		pole.top_radius = 0.01
		pole.bottom_radius = 0.01
		pole.height = 2.0
		var chrome := StandardMaterial3D.new()
		chrome.albedo_color = Color(0.8, 0.8, 0.82)
		chrome.metallic = 1.0
		chrome.roughness = 0.2
		var instance := MeshInstance3D.new()
		instance.mesh = pole
		instance.material_override = chrome
		instance.position = Vector3(0, -1.02, 0)
		instance.set_meta(&"generated", true)
		add_child(instance)


func _add(mesh: Mesh, material: Material, pos: Vector3) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = pos
	_pivot.add_child(instance)
	return instance


func _on_hit(h: DrumHit) -> void:
	if h.stick_id < 0:
		return
	# Push the struck side down: rotate about the in-plane axis perpendicular
	# to the direction of the hit.
	var local := to_local(h.position)
	var out := Vector3(local.x, 0.0, local.z)
	if out.length() < 0.01:
		return
	var axis := out.normalized().cross(Vector3.UP)
	_spin -= axis * hit_impulse * lerpf(0.3, 1.0, h.intensity)


func _on_choked(_group: StringName) -> void:
	_spin *= 0.2
	_tilt *= 0.5
