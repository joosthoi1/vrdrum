@tool
extends Node3D
## Procedural drum visuals: shell, head, hoop and an optional stand pole.
## Place under a [DrumPiece]; the head (or the hoop, for rim hits) flashes
## when the piece is hit.
## Geometry is regenerated from the exported values (also in the editor) and
## never saved into the scene.

@export var radius := 0.178:
	set(value):
		radius = value
		_rebuild()
@export var depth := 0.14:
	set(value):
		depth = value
		_rebuild()
@export var shell_color := Color(0.55, 0.08, 0.1):
	set(value):
		shell_color = value
		_rebuild()
## Draw a pole from under the drum down through the floor.
@export var stand := true:
	set(value):
		stand = value
		_rebuild()

var _head_highlight: HitHighlight
var _rim_highlight: HitHighlight
var _hoop: MeshInstance3D
## Clone Hero lane colour for the hoop, or null for chrome.
var _lane_color: Variant = null


func _ready() -> void:
	_rebuild()
	if Engine.is_editor_hint():
		return
	var piece := get_parent() as DrumPiece
	if piece:
		piece.hit.connect(_on_hit)


func _rebuild() -> void:
	if not is_inside_tree():
		return
	for child in get_children():
		if child.has_meta(&"generated"):
			child.free()

	var shell := CylinderMesh.new()
	shell.top_radius = radius
	shell.bottom_radius = radius
	shell.height = depth
	shell.radial_segments = 48
	shell.rings = 1
	_add_mesh(shell, _material(shell_color, 0.3, 0.35), Vector3(0, -depth / 2.0 - 0.004, 0))

	var head := CylinderMesh.new()
	head.top_radius = radius * 0.96
	head.bottom_radius = radius * 0.96
	head.height = 0.004
	head.radial_segments = 48
	head.rings = 1
	var head_instance := _add_mesh(head, _material(Color(0.93, 0.92, 0.88), 0.0, 0.8), Vector3(0, -0.002, 0))
	_head_highlight = HitHighlight.new(head_instance)

	var hoop := TorusMesh.new()
	hoop.inner_radius = radius * 0.955
	hoop.outer_radius = radius * 1.035
	hoop.rings = 48
	hoop.ring_segments = 8
	_hoop = _add_mesh(hoop, _chrome(), Vector3(0, 0.002, 0))
	_rim_highlight = HitHighlight.new(_hoop)
	_apply_lane_color()

	if stand:
		var pole := CylinderMesh.new()
		pole.top_radius = 0.012
		pole.bottom_radius = 0.012
		pole.height = 2.0
		_add_mesh(pole, _chrome(), Vector3(0, -depth - 1.0, 0))


func _add_mesh(mesh: Mesh, material: Material, pos: Vector3) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = pos
	instance.set_meta(&"generated", true)
	add_child(instance)
	return instance


static func _material(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metallic
	m.roughness = roughness
	return m


static func _chrome() -> StandardMaterial3D:
	return _material(Color(0.8, 0.8, 0.82), 1.0, 0.2)


## Colours the hoop in a Clone Hero lane colour; null restores chrome.
func set_lane_color(color: Variant) -> void:
	_lane_color = color
	_apply_lane_color()


func _apply_lane_color() -> void:
	if _hoop == null:
		return
	if _lane_color is Color:
		var tint := _material(_lane_color, 0.4, 0.3)
		tint.emission_enabled = true
		tint.emission = _lane_color
		tint.emission_energy_multiplier = 0.35
		_hoop.material_override = tint
	else:
		_hoop.material_override = _chrome()


func _on_hit(h: DrumHit) -> void:
	var part := _rim_highlight if h.zone == &"rim" else _head_highlight
	if part:
		part.flash(self, h.intensity)


## Highlight strength of the head and hoop right now (for tests).
func head_flash() -> float:
	return _head_highlight.alpha() if _head_highlight else 0.0


func rim_flash() -> float:
	return _rim_highlight.alpha() if _rim_highlight else 0.0
