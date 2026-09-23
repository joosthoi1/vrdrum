extends Label3D
## World-space readout of frame rate, pedal state and the last hit, for tuning
## detection. Toggle with F3 or either thumbstick click.

@export var kit_path: NodePath

var _kit: DrumKit
var _hihat: HiHat
var _last := "no hits yet"


func _ready() -> void:
	_kit = get_node_or_null(kit_path) as DrumKit
	if _kit:
		_kit.hit.connect(_on_hit)
		_hihat = _kit.piece(&"hihat") as HiHat


func _process(_delta: float) -> void:
	if not visible:
		return
	var lines := ["%d fps" % Engine.get_frames_per_second()]
	var audio := get_node_or_null(^"/root/DrumAudio")
	if audio and not audio.is_ready():
		lines.append("generating drum sounds...")
	if _hihat:
		lines.append("hi-hat %s (%.2f open)" % [_hihat.state_name(), _hihat.openness])
	lines.append(_last)
	text = "\n".join(lines)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F3:
		toggle()


func toggle() -> void:
	visible = not visible


func _on_hit(h: DrumHit) -> void:
	var who := "pedal" if h.stick_id < 0 else "stick %d" % h.stick_id
	_last = "%s  %.2f m/s  vel %.2f  %s" % [h.articulation(), h.speed, h.intensity, who]
