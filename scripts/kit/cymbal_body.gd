@tool
extends Node3D
## Procedural cymbal visuals with a spring wobble and a per-zone hit flash.
## Place under a [DrumPiece] ([Cymbal] or [HiHat]). The plate is built as one
## ring per playing zone of the parent (e.g. bell / bow / edge), so the ring
## that was hit lights up. Geometry is regenerated from the exported values
## (also in the editor) and never saved.

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
## Light up the hit zone. Off for the hi-hat's bottom cymbal.
@export var highlight := true
## Wobble spring stiffness and damping.
@export var stiffness := 90.0
@export var damping := 3.5
## Wobble kick per unit hit intensity, in rad/s.
@export var hit_impulse := 1.6
@export var max_tilt := 0.35

const PLATE_HEIGHT := 0.012

var _pivot: Node3D
var _bronze: StandardMaterial3D
## Outermost ring of the plate, tinted with the lane colour.
var _edge_ring: MeshInstance3D
## Clone Hero lane colour for the edge ring, or null for plain bronze.
var _lane_color: Variant = null
## One highlight per zone of the parent piece.
var _zone_highlights: Array[HitHighlight] = []
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


## Highlight strength of each zone's ring right now (for tests).
func zone_flash(zone: int) -> float:
	if zone < 0 or zone >= _zone_highlights.size() or _zone_highlights[zone] == null:
		return 0.0
	return _zone_highlights[zone].alpha()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	for child in get_children():
		if child.has_meta(&"generated"):
			child.free()
	_zone_highlights.clear()
	_pivot = Node3D.new()
	_pivot.set_meta(&"generated", true)
	add_child(_pivot)

	var bronze := StandardMaterial3D.new()
	bronze.albedo_color = Color(0.83, 0.66, 0.3)
	bronze.metallic = 0.85
	bronze.roughness = 0.3
	bronze.cull_mode = BaseMaterial3D.CULL_DISABLED
	_bronze = bronze
	_edge_ring = null

	# Zone radii from the parent piece; a plain cymbal is one zone. Read the
	# property generically: in the editor the (non-tool) parent script is only
	# a placeholder, and casting it would fail.
	var zone_radii := PackedFloat32Array([radius])
	var parent_radii = get_parent().get(&"zone_outer_radii") if get_parent() else null
	if parent_radii is PackedFloat32Array and not parent_radii.is_empty():
		zone_radii = parent_radii.duplicate()
		zone_radii[zone_radii.size() - 1] = maxf(zone_radii[zone_radii.size() - 1], radius)

	var bell := SphereMesh.new()
	bell.radius = bell_radius
	bell.height = bell_radius * 0.5
	bell.radial_segments = 24
	bell.rings = 8
	var bell_instance := _add(bell, bronze, Vector3(0, 0.004 * (-1.0 if flipped else 1.0), 0))

	# The plate is a shallow cone from the bell out to the edge, split into
	# one frustum per zone.
	var inner := bell_radius
	for zone in zone_radii.size():
		var outer := minf(zone_radii[zone], radius)
		var ring: MeshInstance3D = bell_instance
		if outer > inner + 0.001:
			ring = _add_ring(inner, outer, bronze)
			inner = outer
			_edge_ring = ring
		_zone_highlights.append(HitHighlight.new(ring) if highlight else null)
	_apply_lane_color()

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


## A frustum of the plate's cone between two radii. The whole plate is
## centred on the playing surface so hits line up with the visual.
func _add_ring(inner: float, outer: float, material: Material) -> MeshInstance3D:
	var span := maxf(radius - bell_radius, 0.001)
	var height_at := func(r: float) -> float: return PLATE_HEIGHT * (0.5 - (r - bell_radius) / span)
	var ring := CylinderMesh.new()
	ring.top_radius = inner
	ring.bottom_radius = outer
	ring.height = maxf(height_at.call(inner) - height_at.call(outer), 0.0005)
	ring.radial_segments = 48
	ring.rings = 1
	ring.cap_top = false
	ring.cap_bottom = false
	var y: float = (height_at.call(inner) + height_at.call(outer)) / 2.0
	var instance := _add(ring, material, Vector3(0, -y if flipped else y, 0))
	if flipped:
		instance.rotation.x = PI
	return instance


func _add(mesh: Mesh, material: Material, pos: Vector3) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = pos
	_pivot.add_child(instance)
	return instance


## Colours the edge ring in a Clone Hero lane colour; null restores bronze.
func set_lane_color(color: Variant) -> void:
	_lane_color = color
	_apply_lane_color()


func _apply_lane_color() -> void:
	if _edge_ring == null:
		return
	if _lane_color is Color:
		var tint := _bronze.duplicate() as StandardMaterial3D
		tint.albedo_color = _bronze.albedo_color.lerp(_lane_color, 0.75)
		tint.emission_enabled = true
		tint.emission = _lane_color
		tint.emission_energy_multiplier = 0.3
		_edge_ring.material_override = tint
	else:
		_edge_ring.material_override = _bronze


func _on_hit(h: DrumHit) -> void:
	var piece := get_parent() as DrumPiece
	var zone := 0
	if piece and h.stick_id >= 0:
		zone = maxi(piece.zone_at(h.position), 0)
	if zone < _zone_highlights.size() and _zone_highlights[zone]:
		_zone_highlights[zone].flash(self, h.intensity if h.stick_id >= 0 else h.intensity * 0.5)
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
