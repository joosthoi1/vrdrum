@tool
class_name HitHighlight
extends RefCounted
## A flash overlay for one mesh: lights up when that part of a drum or cymbal
## is hit, then fades out. Helps judge timing and see where a hit landed.

## Global switch, set from the settings menu.
static var enabled := true

var material := StandardMaterial3D.new()
var color: Color
var fade_time: float

var _tween: Tween


func _init(mesh: MeshInstance3D, flash_color: Color = Color(0.45, 0.88, 1.0), fade: float = 0.15) -> void:
	color = flash_color
	fade_time = fade
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = Color(color, 0.0)
	mesh.material_overlay = material


## Flashes with a strength following [param intensity] (0..1).
func flash(owner: Node, intensity: float) -> void:
	if not enabled or not owner.is_inside_tree():
		return
	if _tween:
		_tween.kill()
	material.albedo_color = Color(color, lerpf(0.25, 0.8, intensity))
	_tween = owner.create_tween()
	_tween.tween_property(material, "albedo_color:a", 0.0, fade_time)


func alpha() -> float:
	return material.albedo_color.a
