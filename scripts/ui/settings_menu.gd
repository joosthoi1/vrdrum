class_name SettingsMenu
extends PanelContainer
## The in-game menu: settings tabs generated from Settings.SPECS plus kit
## layout tools. Shown on a world-space panel in VR and as an overlay on
## desktop. Sized and styled to be readable on a VR panel.

signal close_requested
signal edit_layout_requested
signal recenter_requested

const SIZE := Vector2(1000, 760)
const FONT_SIZE := 28

## The kit the Kit tab acts on.
var kit: DrumKit
## Show VR-only actions (recenter).
var vr := false
## Size multiplier: 1 on the VR panel, smaller for desktop windows.
var ui_scale := 1.0

var _settings: Node
## setting key -> [control, value label or null]
var _controls := {}
var _status: Label


func _ready() -> void:
	custom_minimum_size = SIZE * ui_scale
	size = custom_minimum_size
	theme = _make_theme(ui_scale)
	_settings = get_node_or_null(^"/root/Settings")
	var root := VBoxContainer.new()
	root.add_theme_constant_override(&"separation", 12)
	add_child(root)

	var title := Label.new()
	title.text = "VR Drums"
	title.add_theme_font_size_override(&"font_size", roundi(40 * ui_scale))
	root.add_child(title)

	var tabs := TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(tabs)
	var pages := {}
	for tab_name in ["Play", "Sticks", "Sound"]:
		pages[tab_name] = _add_page(tabs, tab_name)
	if _settings:
		for key in _settings.SPECS:
			var spec: Array = _settings.SPECS[key]
			_add_setting(pages[spec[5]], key, spec)
		_settings.changed.connect(_on_setting_changed)
	_build_kit_page(_add_page(tabs, "Kit"))

	var bottom := HBoxContainer.new()
	root.add_child(bottom)
	_status = Label.new()
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(_status)
	var close := Button.new()
	close.text = "Close"
	close.pressed.connect(close_requested.emit)
	bottom.add_child(close)


## The control bound to a setting (slider or check button). For tests.
func control_for(key: StringName) -> Control:
	return _controls[key][0] if _controls.has(key) else null


func show_status(text: String) -> void:
	if _status:
		_status.text = text


func _add_page(tabs: TabContainer, tab_name: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = tab_name
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs.add_child(scroll)
	var page := VBoxContainer.new()
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_theme_constant_override(&"separation", 14)
	scroll.add_child(page)
	return page


func _add_setting(page: VBoxContainer, key: StringName, spec: Array) -> void:
	var value = _settings.get_value(key)
	if spec[0] is bool:
		var check := CheckButton.new()
		check.text = spec[4]
		check.button_pressed = value
		check.toggled.connect(func(on: bool) -> void: _settings.set_value(key, on))
		page.add_child(check)
		_controls[key] = [check, null]
		return
	var row := HBoxContainer.new()
	page.add_child(row)
	var label := Label.new()
	label.text = spec[4]
	label.custom_minimum_size.x = 380 * ui_scale
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = spec[1]
	slider.max_value = spec[2]
	slider.step = spec[3]
	slider.value = value
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(slider)
	var readout := Label.new()
	readout.custom_minimum_size.x = 110 * ui_scale
	readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	readout.text = _format(value, spec[3])
	row.add_child(readout)
	slider.value_changed.connect(func(v: float) -> void: _settings.set_value(key, v))
	_controls[key] = [slider, readout]


func _build_kit_page(page: VBoxContainer) -> void:
	var hint := Label.new()
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.text = ("Height: hold both sticks where you want the snare and press B / Y." if vr
		else "Edit layout: drag pieces with the mouse, scroll to raise or lower, Shift+scroll to tilt.")
	page.add_child(hint)
	_add_buttons(page, [
		["Edit layout", func() -> void: edit_layout_requested.emit()],
		["Kit higher", func() -> void: _nudge_height(0.02)],
		["Kit lower", func() -> void: _nudge_height(-0.02)],
	])
	if vr:
		_add_buttons(page, [["Recenter kit on me", func() -> void: recenter_requested.emit()]])
	_add_buttons(page, [
		["Default layout", func() -> void: _preset("default")],
		["Compact layout", func() -> void: _preset("compact")],
	])
	for slot in range(1, KitLayout.SLOTS + 1):
		_add_buttons(page, [
			["Save slot %d" % slot, func() -> void: _save_slot(slot)],
			["Load slot %d" % slot, func() -> void: _load_slot(slot)],
		])
	_add_buttons(page, [["Reset all settings", _reset_settings]])


func _add_buttons(page: VBoxContainer, buttons: Array) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 12)
	page.add_child(row)
	for spec in buttons:
		var button := Button.new()
		button.text = spec[0]
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(spec[1])
		row.add_child(button)


func _nudge_height(amount: float) -> void:
	if kit:
		var snare := kit.piece(&"snare")
		kit.calibrate_height((snare.global_position.y if snare else kit.global_position.y) + amount, 0.0)


func _preset(preset: String) -> void:
	if kit:
		kit.load_preset(preset)
		show_status("Loaded %s layout" % preset)


func _save_slot(slot: int) -> void:
	if kit:
		kit.save_slot(slot)
		show_status("Saved layout to slot %d" % slot)


func _load_slot(slot: int) -> void:
	if kit:
		show_status("Loaded slot %d" % slot if kit.load_slot(slot) else "Slot %d is empty" % slot)


func _reset_settings() -> void:
	if _settings:
		_settings.reset_to_defaults()
		show_status("Settings reset")


func _on_setting_changed(key: StringName, value: Variant) -> void:
	if not _controls.has(key):
		return
	var control: Control = _controls[key][0]
	if control is CheckButton:
		control.set_pressed_no_signal(value)
	elif control is HSlider:
		control.set_value_no_signal(value)
		_controls[key][1].text = _format(value, control.step)


static func _format(value: Variant, step: float) -> String:
	return "%d" % roundi(value) if step >= 1.0 else "%.2f" % value


static func _make_theme(scale: float) -> Theme:
	var t := Theme.new()
	t.default_font_size = roundi(FONT_SIZE * scale)
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.1, 0.11, 0.14, 0.97)
	panel.set_corner_radius_all(18)
	panel.set_content_margin_all(28)
	t.set_stylebox(&"panel", &"PanelContainer", panel)
	var button := StyleBoxFlat.new()
	button.bg_color = Color(0.22, 0.24, 0.3)
	button.set_corner_radius_all(10)
	button.set_content_margin_all(14)
	var hover := button.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.3, 0.45, 0.6)
	var pressed := button.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.25, 0.65, 0.85)
	for type in [&"Button", &"CheckButton"]:
		t.set_stylebox(&"normal", type, button)
		t.set_stylebox(&"hover", type, hover)
		t.set_stylebox(&"pressed", type, pressed)
		t.set_stylebox(&"hover_pressed", type, pressed)
		t.set_stylebox(&"focus", type, StyleBoxEmpty.new())
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.3, 0.32, 0.38)
	track.set_corner_radius_all(6)
	track.content_margin_top = 6
	track.content_margin_bottom = 6
	t.set_stylebox(&"slider", &"HSlider", track)
	var fill := track.duplicate() as StyleBoxFlat
	fill.bg_color = Color(0.25, 0.65, 0.85)
	t.set_stylebox(&"grabber_area", &"HSlider", fill)
	t.set_stylebox(&"grabber_area_highlight", &"HSlider", fill)
	var d := roundi(36 * scale)
	var grabber := Image.create(d, d, false, Image.FORMAT_RGBA8)
	grabber.fill(Color(0, 0, 0, 0))
	for y in d:
		for x in d:
			if Vector2(x - (d - 1) / 2.0, y - (d - 1) / 2.0).length() <= d / 2.0 - 1.0:
				grabber.set_pixel(x, y, Color(0.9, 0.95, 1.0))
	var grabber_texture := ImageTexture.create_from_image(grabber)
	t.set_icon(&"grabber", &"HSlider", grabber_texture)
	t.set_icon(&"grabber_highlight", &"HSlider", grabber_texture)
	return t
