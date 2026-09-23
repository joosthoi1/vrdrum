extends Label3D
## World-space readout of frame rate and the last hit, for tuning detection.
## Toggle with F3 or either thumbstick click.

@export var kit_path: NodePath

var _last := "no hits yet"


func _ready() -> void:
	var kit := get_node_or_null(kit_path) as DrumKit
	if kit:
		kit.hit.connect(_on_hit)


func _process(_delta: float) -> void:
	if visible:
		text = "%d fps\n%s" % [Engine.get_frames_per_second(), _last]


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F3:
		toggle()


func toggle() -> void:
	visible = not visible


func _on_hit(h: DrumHit) -> void:
	_last = "%s  %.2f m/s  vel %.2f  stick %d" % [h.articulation(), h.speed, h.intensity, h.stick_id]
