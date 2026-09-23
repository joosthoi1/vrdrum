extends Node3D
## Entry point. Starts OpenXR when a runtime is available (SteamVR for PSVR2,
## Index, Vive, Link, ...) and falls back to the desktop rig otherwise, or when
## launched with [code]-- --desktop[/code]. Also owns the menu and the kit
## layout editor.
##
## Menu: A/X or the menu button in VR, Esc on desktop. While the menu is open
## in VR the triggers click instead of working the pedals.

const XR_RIG := preload("res://scenes/xr_rig.tscn")
const DESKTOP_RIG := preload("res://scenes/desktop_rig.tscn")

var xr_interface: OpenXRInterface
var rig: Node3D
var menu: SettingsMenu
## VR only: the world-space panel the menu is shown on.
var menu_panel: UiPanel3D
## Desktop only: the overlay layer the menu is shown on.
var menu_layer: CanvasLayer
var editor: KitEditor
var stick_clicker: StickClicker

@onready var kit: DrumKit = $DrumKit
@onready var debug_overlay: Label3D = $DebugOverlay
@onready var pedals: Node = $Pedals
@onready var edit_hint: Label3D = $EditHint


func _ready() -> void:
	editor = KitEditor.new()
	editor.name = "KitEditor"
	editor.kit = kit
	editor.active_changed.connect(_on_edit_mode_changed)
	add_child(editor)
	menu = SettingsMenu.new()
	menu.kit = kit
	menu.close_requested.connect(close_menu)
	menu.edit_layout_requested.connect(start_editing)
	menu.recenter_requested.connect(_recenter)

	if not OS.get_cmdline_user_args().has("--desktop") and _start_xr():
		rig = XR_RIG.instantiate()
		add_child(rig)
		rig.calibrate_requested.connect(kit.calibrate_height)
		rig.debug_toggle_requested.connect(debug_overlay.toggle)
		rig.menu_toggle_requested.connect(toggle_menu)
		pedals.left_controller = rig.left_hand
		pedals.right_controller = rig.right_hand
		menu.vr = true
		menu_panel = UiPanel3D.new()
		menu_panel.name = "MenuPanel"
		add_child(menu_panel)
		menu_panel.set_content(menu)
		menu_panel.visible = false
		for i in 2:
			menu_panel.add_pointer(rig.sticks()[i], rig.controllers()[i])
			editor.add_hand(rig.sticks()[i], rig.controllers()[i])
	else:
		rig = DESKTOP_RIG.instantiate()
		add_child(rig)
		menu.ui_scale = clampf(get_viewport().get_visible_rect().size.y * 0.9 / SettingsMenu.SIZE.y, 0.5, 1.0)
		menu_layer = CanvasLayer.new()
		menu_layer.layer = 10
		menu_layer.visible = false
		add_child(menu_layer)
		var center := CenterContainer.new()
		center.set_anchors_preset(Control.PRESET_FULL_RECT)
		center.mouse_filter = Control.MOUSE_FILTER_IGNORE
		menu_layer.add_child(center)
		center.add_child(menu)
		editor.camera = rig.camera
		for stick in rig.sticks():
			editor.add_hand(stick, null)
	edit_hint.visible = false
	stick_clicker = StickClicker.new()
	stick_clicker.name = "StickClicker"
	stick_clicker.sticks = rig.sticks()
	stick_clicker.kit = kit
	add_child(stick_clicker)
	# Settings loaded before this scene existed; push them to its lights etc.
	var settings := get_node_or_null(^"/root/Settings")
	if settings:
		settings.apply_all()


func is_xr() -> bool:
	return xr_interface != null and get_viewport().use_xr


func is_menu_open() -> bool:
	return (menu_panel.visible if menu_panel else menu_layer.visible)


func toggle_menu() -> void:
	if editor.active:
		editor.active = false
	elif is_menu_open():
		close_menu()
	else:
		open_menu()


func open_menu() -> void:
	if menu_panel:
		menu_panel.face(rig.camera.global_transform)
		menu_panel.visible = true
		pedals.enabled = false
	else:
		menu_layer.visible = true
	_set_rig_input(false)


func close_menu() -> void:
	if menu_panel:
		menu_panel.visible = false
	else:
		menu_layer.visible = false
	pedals.enabled = not editor.active
	_set_rig_input(not editor.active)


func start_editing() -> void:
	close_menu()
	editor.active = true


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		toggle_menu()
		get_viewport().set_input_as_handled()


func _on_edit_mode_changed(active: bool) -> void:
	pedals.enabled = not active and not is_menu_open()
	_set_rig_input(not active and not is_menu_open())
	edit_hint.visible = active
	if active and rig.has_method("controllers"):
		edit_hint.text = "Editing the kit\nTouch a piece with a stick and hold the trigger to move it\nA / X when done"
	elif active:
		edit_hint.text = "Editing the kit: drag pieces, scroll to raise or lower, Shift+scroll to tilt. Esc when done."


## Desktop rig: stop mouse and key strokes while the menu or editor is using them.
func _set_rig_input(on: bool) -> void:
	if "input_enabled" in rig:
		rig.input_enabled = on


func _recenter() -> void:
	if rig.get(&"camera"):
		kit.recenter(rig.camera.global_transform)
		menu.show_status("Kit recentered")
		menu_panel.face(rig.camera.global_transform)


func _start_xr() -> bool:
	xr_interface = XRServer.find_interface("OpenXR")
	if xr_interface == null or not xr_interface.is_initialized():
		xr_interface = null
		return false
	# The XR runtime paces frames; vsync on the mirror window would only add latency.
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var settings := get_node_or_null(^"/root/Settings")
	if settings:
		xr_interface.render_target_size_multiplier = settings.get_value(&"render_scale")
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
