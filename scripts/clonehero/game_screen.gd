class_name GameScreen
extends Node3D
## A screen in the practice room showing another app's window, captured
## live: Clone Hero, while everyone else watches it on the TV or monitor.
##
## Frames come from the native WindowCapture (Windows): BGRA pixels, which
## the shader swizzles so the CPU never converts them. The screen faces +Z,
## is part of the kit layout and can be moved in the kit editor.

const GROUP := &"layout_grabbables"
## WindowCapture statuses start with this while the window is being
## captured. Frames only arrive when the picture changes, so a still
## Clone Hero menu can go seconds without one: that isn't a problem.
const CAPTURING := "Capturing"
const SHADER := """
shader_type spatial;
render_mode unshaded, cull_back;
uniform sampler2D frame : source_color, filter_linear_mipmap;
void fragment() {
	ALBEDO = texture(frame, UV).bgr;
}
"""

## Screen width in metres; the height follows the window's aspect ratio.
@export var width := 1.3:
	set(value):
		width = value
		_resize()

## Where frames come from: a WindowCapture, or any object with start(),
## stop(), fetch_frame(), get_frame_size() and get_status() (tests use a fake).
var source: Object
## Only windows whose title contains this are captured.
var window_title := "Clone Hero"
## Frames wider than this are scaled down (1280 or 1920).
var max_width := 1280

var active := false
var frame_size := Vector2i.ZERO

var _aspect := 16.0 / 9.0
var _quad: MeshInstance3D
var _bezel: MeshInstance3D
var _label: Label3D
var _material := ShaderMaterial.new()
var _texture: ImageTexture
var _status_check := 0.0


func _ready() -> void:
	add_to_group(GROUP)
	_material.shader = Shader.new()
	_material.shader.code = SHADER
	_quad = MeshInstance3D.new()
	_quad.mesh = QuadMesh.new()
	_quad.material_override = _material
	_quad.visible = false
	add_child(_quad)
	_bezel = MeshInstance3D.new()
	_bezel.mesh = BoxMesh.new()
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.05, 0.05, 0.06)
	dark.roughness = 0.5
	_bezel.material_override = dark
	add_child(_bezel)
	_label = Label3D.new()
	_label.pixel_size = 0.0015
	_label.font_size = 36
	_label.position = Vector3(0, 0, 0.012)
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_label)
	_resize()
	var settings := get_node_or_null(^"/root/Settings")
	if settings:
		window_title = settings.get_value(&"ch_window")
		max_width = 1920 if settings.get_value(&"ch_capture_width") == 1 else 1280
		width = settings.get_value(&"ch_screen_size")
		settings.changed.connect(_on_setting_changed)
		set_active(settings.get_value(&"ch_screen"))
	else:
		set_active(false)


func _exit_tree() -> void:
	if source and active:
		source.stop()


## True when the native extension that captures windows is loaded and
## supports this platform.
static func is_available() -> bool:
	return ClassDB.class_exists(&"WindowCapture") and ClassDB.class_call_static(&"WindowCapture", &"is_supported")


## Titles of windows that can be shown (empty where capture is unavailable).
static func window_titles() -> PackedStringArray:
	return ClassDB.class_call_static(&"WindowCapture", &"list_windows") if is_available() else PackedStringArray()


func set_active(on: bool) -> void:
	visible = on
	if on == active and (not on or source):
		return
	active = on
	if on:
		if source == null and is_available():
			source = ClassDB.instantiate(&"WindowCapture")
		if source:
			source.start(window_title, max_width)
		_show_status()
	elif source:
		source.stop()


## Restarts capture, e.g. after the window title or resolution changed.
func restart() -> void:
	if active and source:
		source.stop()
		source.start(window_title, max_width)
		_show_status()


func status() -> String:
	if source:
		return source.get_status()
	if not ClassDB.class_exists(&"WindowCapture"):
		return "Window capture needs the vrdrum_native extension"
	return "Window capture needs Windows. See Desktop+ in docs/CLONE_HERO.md"


func _process(delta: float) -> void:
	if not active or source == null:
		return
	var data: PackedByteArray = source.fetch_frame()
	if data.is_empty():
		# Check now and then whether capture is still fine (window closed,
		# minimized...); if not, show why instead of a frozen picture.
		_status_check -= delta
		if _status_check <= 0.0:
			_status_check = 0.5
			_show_status()
		return
	var size: Vector2i = source.get_frame_size()
	if data.size() != size.x * size.y * 4 or size.x <= 0 or size.y <= 0:
		return
	var image := Image.create_from_data(size.x, size.y, false, Image.FORMAT_RGBA8, data)
	if _texture == null or size != frame_size:
		frame_size = size
		_texture = ImageTexture.create_from_image(image)
		_material.set_shader_parameter(&"frame", _texture)
		_aspect = float(size.x) / size.y
		_resize()
	else:
		_texture.update(image)
	_quad.visible = true
	_label.visible = false


func _show_status() -> void:
	var text := status()
	_quad.visible = _texture != null and text.begins_with(CAPTURING)
	_label.visible = not _quad.visible
	_label.text = text


func _resize() -> void:
	if _quad == null:
		return
	var height := width / _aspect
	(_quad.mesh as QuadMesh).size = Vector2(width, height)
	(_bezel.mesh as BoxMesh).size = Vector3(width + 0.05, height + 0.05, 0.02)
	_bezel.position = Vector3(0, 0, -0.011)
	_label.width = width / _label.pixel_size * 0.9


## Kit editor support: the screen can be grabbed like a kit piece.
func grab_center() -> Vector3:
	return global_position


func grab_normal() -> Vector3:
	return global_basis.z.normalized()


func grab_radius() -> float:
	return width / 2.0


func _on_setting_changed(key: StringName, value: Variant) -> void:
	match key:
		&"ch_screen":
			set_active(value)
		&"ch_window":
			window_title = value
			restart()
		&"ch_capture_width":
			max_width = 1920 if value == 1 else 1280
			restart()
		&"ch_screen_size":
			width = value
