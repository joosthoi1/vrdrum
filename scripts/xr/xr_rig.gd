extends XROrigin3D
## VR player rig: headset camera plus a drumstick in each tracked controller.
##
## B/Y recalibrates kit height to where the sticks are held; thumbstick click
## toggles the debug overlay.

signal calibrate_requested(tip_height: float)
signal debug_toggle_requested

@onready var left_hand: XRController3D = $LeftHand
@onready var right_hand: XRController3D = $RightHand


func _ready() -> void:
	left_hand.button_pressed.connect(_on_button_pressed)
	right_hand.button_pressed.connect(_on_button_pressed)


func sticks() -> Array[DrumStick]:
	return [$LeftHand/LeftStick, $RightHand/RightStick]


func _on_button_pressed(action: String) -> void:
	match action:
		"by_button":
			var sum := 0.0
			for stick in sticks():
				sum += stick.tip_position().y
			calibrate_requested.emit(sum / 2.0)
		"primary_click":
			debug_toggle_requested.emit()
