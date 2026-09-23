extends Node3D
## Entry point. Starts OpenXR when a runtime is available (SteamVR for PSVR2,
## Index, Vive, Link, ...) and falls back to the desktop rig otherwise, or when
## launched with [code]-- --desktop[/code].

const XR_RIG := preload("res://scenes/xr_rig.tscn")
const DESKTOP_RIG := preload("res://scenes/desktop_rig.tscn")

var xr_interface: OpenXRInterface
var rig: Node3D

@onready var kit: DrumKit = $DrumKit
@onready var debug_overlay: Label3D = $DebugOverlay
@onready var pedals: Node = $Pedals


func _ready() -> void:
	if not OS.get_cmdline_user_args().has("--desktop") and _start_xr():
		rig = XR_RIG.instantiate()
		rig.calibrate_requested.connect(kit.calibrate_height)
		rig.debug_toggle_requested.connect(debug_overlay.toggle)
		pedals.left_controller = rig.get_node(^"LeftHand")
		pedals.right_controller = rig.get_node(^"RightHand")
	else:
		rig = DESKTOP_RIG.instantiate()
	add_child(rig)


func is_xr() -> bool:
	return xr_interface != null and get_viewport().use_xr


func _start_xr() -> bool:
	xr_interface = XRServer.find_interface("OpenXR")
	if xr_interface == null or not xr_interface.is_initialized():
		xr_interface = null
		return false
	# The XR runtime paces frames; vsync on the mirror window would only add latency.
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	get_viewport().use_xr = true
	xr_interface.session_begun.connect(_on_session_begun)
	return true


func _on_session_begun() -> void:
	# Run at the highest refresh rate the headset offers (PSVR2: 120 Hz):
	# more frames means finer stick tracking and lower hit latency.
	var best := 0.0
	for rate in xr_interface.get_available_display_refresh_rates():
		best = maxf(best, rate)
	if best > 0.0:
		xr_interface.display_refresh_rate = best
	var current := xr_interface.display_refresh_rate
	if current > 0.0:
		Engine.physics_ticks_per_second = roundi(current)
	print("OpenXR session started at %.0f Hz" % current)
