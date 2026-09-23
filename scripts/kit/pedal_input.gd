extends Node
## Reads the kick and hi-hat pedals from every supported source and drives
## the kit's Kick and HiHat pieces.
##
## Sources, combined by taking the strongest:
## - VR: right trigger = kick, left trigger = hi-hat pedal (analog), swapped
##   in left-handed mode. The hands hold the sticks with the grip, so the
##   triggers are free.
## - Keyboard: Space = kick, V = hi-hat pedal. Cheap USB foot switches that
##   send key presses work with no extra setup.
## - Gamepad: right trigger / A = kick, left trigger = hi-hat pedal.

@export var kick_path: NodePath
@export var hihat_path: NodePath

var left_controller: XRController3D
var right_controller: XRController3D
## Off while the menu uses the triggers for clicking.
var enabled := true
## Swap which trigger is the kick (from the left-handed setting).
var left_handed := false
## Pressing the hi-hat pedal opens the hat instead of closing it.
var hihat_invert := false

var kick: DrumPiece
var hihat: HiHat

var _kick_pedal := PedalTracker.new()


func _ready() -> void:
	ensure_default_actions()
	kick = get_node_or_null(kick_path) as DrumPiece
	hihat = get_node_or_null(hihat_path) as HiHat
	var settings := get_node_or_null(^"/root/Settings")
	if settings:
		left_handed = settings.get_value(&"left_handed")
		hihat_invert = settings.get_value(&"hihat_invert")
		settings.changed.connect(_on_setting_changed)


func _process(delta: float) -> void:
	step(delta)


## Reads all inputs once. Public so tests can drive it.
func step(delta: float) -> void:
	var kick_value := 0.0
	var hihat_value := 0.0
	if enabled:
		kick_value = Input.get_action_strength(&"kick")
		hihat_value = Input.get_action_strength(&"hihat_pedal")
		var kick_hand := left_controller if left_handed else right_controller
		var hihat_hand := right_controller if left_handed else left_controller
		if kick_hand:
			kick_value = maxf(kick_value, kick_hand.get_float(&"trigger"))
		if hihat_hand:
			hihat_value = maxf(hihat_value, hihat_hand.get_float(&"trigger"))
	var intensity := _kick_pedal.update(kick_value, delta)
	if kick and intensity >= 0.0:
		kick.trigger(&"head", intensity)
	if hihat:
		hihat.set_pedal(1.0 - hihat_value if hihat_invert else hihat_value, delta)


func _on_setting_changed(key: StringName, value: Variant) -> void:
	if key == &"left_handed":
		left_handed = value
	elif key == &"hihat_invert":
		hihat_invert = value


## Registers the default bindings unless the project (or the player) already
## defined these actions.
static func ensure_default_actions() -> void:
	if not InputMap.has_action(&"kick"):
		InputMap.add_action(&"kick", 0.1)
		InputMap.action_add_event(&"kick", _key(KEY_SPACE))
		InputMap.action_add_event(&"kick", _joy_button(JOY_BUTTON_A))
		InputMap.action_add_event(&"kick", _joy_axis(JOY_AXIS_TRIGGER_RIGHT))
	if not InputMap.has_action(&"hihat_pedal"):
		InputMap.add_action(&"hihat_pedal", 0.1)
		InputMap.action_add_event(&"hihat_pedal", _key(KEY_V))
		InputMap.action_add_event(&"hihat_pedal", _joy_axis(JOY_AXIS_TRIGGER_LEFT))


static func _key(keycode: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	return event


static func _joy_button(button: JoyButton) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	return event


static func _joy_axis(axis: JoyAxis) -> InputEventJoypadMotion:
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = 1.0
	return event
