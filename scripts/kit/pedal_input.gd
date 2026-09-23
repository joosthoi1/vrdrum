extends Node
## Reads the kick and hi-hat pedals from every supported source and drives
## the kit's Kick and HiHat pieces.
##
## Sources, combined by taking the strongest:
## - VR: right trigger = kick, left trigger = hi-hat pedal (analog). The hands
##   hold the sticks with the grip, so the triggers are free.
## - Keyboard: Space = kick, V = hi-hat pedal. Cheap USB foot switches that
##   send key presses work with no extra setup.
## - Gamepad: right trigger / A = kick, left trigger = hi-hat pedal.

@export var kick_path: NodePath
@export var hihat_path: NodePath

var left_controller: XRController3D
var right_controller: XRController3D

var kick: DrumPiece
var hihat: HiHat

var _kick_pedal := PedalTracker.new()


func _ready() -> void:
	ensure_default_actions()
	kick = get_node_or_null(kick_path) as DrumPiece
	hihat = get_node_or_null(hihat_path) as HiHat


func _process(delta: float) -> void:
	step(delta)


## Reads all inputs once. Public so tests can drive it.
func step(delta: float) -> void:
	var kick_value := Input.get_action_strength(&"kick")
	var hihat_value := Input.get_action_strength(&"hihat_pedal")
	if right_controller:
		kick_value = maxf(kick_value, right_controller.get_float(&"trigger"))
	if left_controller:
		hihat_value = maxf(hihat_value, left_controller.get_float(&"trigger"))
	var intensity := _kick_pedal.update(kick_value, delta)
	if kick and intensity >= 0.0:
		kick.trigger(&"head", intensity)
	if hihat:
		hihat.set_pedal(hihat_value, delta)


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
