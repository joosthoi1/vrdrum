extends XROrigin3D
## VR player rig: headset camera plus a drumstick in each tracked controller.
##
## A/X or the menu button opens the menu; B/Y recalibrates kit height to where
## the sticks are held; thumbstick click toggles the debug overlay. Triggers
## are the pedals (see pedal_input.gd) and click in the menu. The controllers
## are in the "hands" group so they can choke cymbals.

signal calibrate_requested(tip_height: float)
signal debug_toggle_requested
signal menu_toggle_requested

@onready var camera: XRCamera3D = $XRCamera3D
@onready var left_hand: XRController3D = $LeftHand
@onready var right_hand: XRController3D = $RightHand


func _ready() -> void:
	for hand in [left_hand, right_hand]:
		hand.button_pressed.connect(_on_button_pressed)
		hand.add_to_group(&"hands")


func sticks() -> Array[DrumStick]:
	return [$LeftHand/LeftStick, $RightHand/RightStick]


func controllers() -> Array[XRController3D]:
	return [left_hand, right_hand]


func _on_button_pressed(action: String) -> void:
	match action:
		"by_button":
			var sum := 0.0
			for stick in sticks():
				sum += stick.tip_position().y
			calibrate_requested.emit(sum / 2.0)
		"ax_button", "menu_button":
			menu_toggle_requested.emit()
		"primary_click":
			debug_toggle_requested.emit()
