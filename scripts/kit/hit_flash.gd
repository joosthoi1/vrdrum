extends MeshInstance3D
## Briefly lights up a drum surface when its parent [DrumPiece] is hit.
## Helps judge timing and spot tracking problems.

@export var color := Color(1.0, 0.75, 0.3)
@export var fade_time := 0.15

var _overlay := StandardMaterial3D.new()
var _tween: Tween


func _ready() -> void:
	_overlay.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_overlay.albedo_color = Color(color, 0.0)
	material_overlay = _overlay
	var piece := get_parent() as DrumPiece
	if piece:
		piece.hit.connect(_on_hit)


func _on_hit(h: DrumHit) -> void:
	if _tween:
		_tween.kill()
	_overlay.albedo_color = Color(color, lerpf(0.25, 0.8, h.intensity))
	_tween = create_tween()
	_tween.tween_property(_overlay, "albedo_color:a", 0.0, fade_time)
