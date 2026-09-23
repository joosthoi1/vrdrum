class_name UiPanel3D
extends Node3D
## Shows a 2D [Control] on a quad in the world and lets drumsticks point at
## it: each stick casts a laser along its length, and the matching
## controller's trigger clicks. Pointer input is forwarded to the panel's
## SubViewport as mouse events, so ordinary Godot UI works unchanged.

## Physical size of the panel in metres.
@export var panel_size := Vector2(1.0, 0.76)

## Laser length when not pointing at the panel.
const LASER_IDLE := 0.25

var viewport: SubViewport
var quad: MeshInstance3D

## Each pointer: {"origin": Node3D (ray from its origin along -Z),
## "controller": XRController3D or null, "laser": MeshInstance3D,
## "pressed": bool}
var _pointers: Array[Dictionary] = []
var _dot: MeshInstance3D


func _init() -> void:
	viewport = SubViewport.new()
	viewport.disable_3d = true
	viewport.transparent_bg = true
	viewport.gui_embed_subwindows = true
	viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	add_child(viewport)
	quad = MeshInstance3D.new()
	var mesh := QuadMesh.new()
	mesh.size = panel_size
	quad.mesh = mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_texture = viewport.get_texture()
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	quad.material_override = material
	add_child(quad)
	_dot = _make_mesh(SphereMesh.new(), Color(0.45, 0.88, 1.0))
	(_dot.mesh as SphereMesh).radius = 0.006
	(_dot.mesh as SphereMesh).height = 0.012
	_dot.visible = false
	add_child(_dot)


## Puts [param content] on the panel, sized to fill it.
func set_content(content: Control) -> void:
	for child in viewport.get_children():
		viewport.remove_child(child)
	viewport.size = Vector2i(content.custom_minimum_size if content.custom_minimum_size != Vector2.ZERO else Vector2(1000, 760))
	viewport.add_child(content)
	(quad.mesh as QuadMesh).size = Vector2(panel_size.x, panel_size.x * viewport.size.y / viewport.size.x)


## Adds a pointer casting from [param origin] along its -Z axis, clicking
## with [param controller]'s trigger.
func add_pointer(origin: Node3D, controller: XRController3D) -> void:
	var laser := _make_mesh(CylinderMesh.new(), Color(0.45, 0.88, 1.0, 0.6))
	var cylinder := laser.mesh as CylinderMesh
	cylinder.top_radius = 0.002
	cylinder.bottom_radius = 0.002
	cylinder.height = 1.0
	laser.top_level = true
	add_child(laser)
	var pointer := {"origin": origin, "controller": controller, "laser": laser, "pressed": false}
	_pointers.append(pointer)
	if controller:
		controller.button_pressed.connect(func(action: String) -> void: _on_button(pointer, action, true))
		controller.button_released.connect(func(action: String) -> void: _on_button(pointer, action, false))


## Places the panel [param distance] in front of [param head], facing it.
func face(head: Transform3D, distance: float = 0.7, drop: float = 0.15) -> void:
	var forward := -head.basis.z
	forward.y = 0.0
	forward = forward.normalized() if forward.length() > 0.01 else Vector3.FORWARD
	var spot := head.origin + forward * distance + Vector3.DOWN * drop
	# The quad faces +Z, so point -Z away from the player.
	global_transform = Transform3D(Basis.looking_at(forward, Vector3.UP), spot)


## Panel pixel hit by a ray, or null if the ray misses the panel.
func ray_to_pixel(origin: Vector3, direction: Vector3) -> Variant:
	var local_origin := to_local(origin)
	var local_dir := global_basis.inverse() * direction
	if absf(local_dir.z) < 1e-5:
		return null
	var t := -local_origin.z / local_dir.z
	if t <= 0.0:
		return null
	var hit := local_origin + local_dir * t
	var size := (quad.mesh as QuadMesh).size
	var uv := Vector2(hit.x / size.x + 0.5, 0.5 - hit.y / size.y)
	if uv.x < 0.0 or uv.x > 1.0 or uv.y < 0.0 or uv.y > 1.0:
		return null
	return uv * Vector2(viewport.size)


func _process(_delta: float) -> void:
	if not visible:
		return
	_dot.visible = false
	for pointer in _pointers:
		var origin: Node3D = pointer.origin
		if not is_instance_valid(origin):
			continue
		var from := origin.global_position
		var direction := -origin.global_basis.z.normalized()
		var pixel = ray_to_pixel(from, direction)
		var length := LASER_IDLE
		if pixel != null:
			length = from.distance_to(to_global(_panel_point(pixel)))
			_dot.visible = true
			_dot.global_position = from + direction * length
			var motion := InputEventMouseMotion.new()
			motion.position = pixel
			motion.global_position = pixel
			motion.button_mask = MOUSE_BUTTON_MASK_LEFT if pointer.pressed else 0
			viewport.push_input(motion)
			pointer.pixel = pixel
		else:
			pointer.erase("pixel")
		_place_laser(pointer.laser, from, direction, length)


func _panel_point(pixel: Vector2) -> Vector3:
	var size := (quad.mesh as QuadMesh).size
	var uv := pixel / Vector2(viewport.size)
	return Vector3((uv.x - 0.5) * size.x, (0.5 - uv.y) * size.y, 0.0)


func _on_button(pointer: Dictionary, action: String, pressed: bool) -> void:
	if not visible or action != "trigger_click":
		return
	if pressed and not pointer.has("pixel"):
		return
	pointer.pressed = pressed
	click(pointer.get("pixel", Vector2.ZERO), pressed)


## Sends a left-button press or release at [param pixel].
func click(pixel: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = pixel
	event.global_position = pixel
	viewport.push_input(event)


func _place_laser(laser: MeshInstance3D, from: Vector3, direction: Vector3, length: float) -> void:
	laser.visible = visible
	var up := direction
	var side := up.cross(Vector3.UP if absf(up.y) < 0.99 else Vector3.RIGHT).normalized()
	var b := Basis(side, up, side.cross(up)) * Basis.from_scale(Vector3(1, length, 1))
	laser.global_transform = Transform3D(b, from + direction * length / 2.0)


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED:
		for pointer in _pointers:
			pointer.laser.visible = is_visible_in_tree()
			pointer.pressed = false


static func _make_mesh(mesh: PrimitiveMesh, color: Color) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	if color.a < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	instance.material_override = material
	return instance
