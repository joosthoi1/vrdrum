extends Node
## Autoload "Settings": player preferences, saved to user://settings.cfg.
##
## Values live in one dictionary keyed by name; [constant SPECS] gives each
## one's default and range, which the settings menu also uses to build its
## controls. Anything that depends on a setting reads it through [method get_value]
## and listens to [signal changed].

signal changed(key: StringName, value: Variant)

const PATH := "user://settings.cfg"

## key -> [default, min, max, step, label, tab]. Booleans have no range.
const SPECS := {
	# Play
	&"sensitivity": [1.0, 0.5, 2.0, 0.05, "Hit sensitivity", "Play"],
	&"dynamics": [1.0, 0.5, 1.8, 0.05, "Dynamics (soft ↔ hard)", "Play"],
	&"highlight_hits": [true, null, null, null, "Highlight hits", "Play"],
	&"left_handed": [false, null, null, null, "Left-handed kit", "Play"],
	&"hihat_invert": [false, null, null, null, "Hi-hat pedal: press to open", "Play"],
	# Sticks
	&"stick_length": [0.32, 0.22, 0.42, 0.01, "Stick length (m)", "Sticks"],
	&"stick_angle": [-15.0, -50.0, 30.0, 1.0, "Stick angle (°)", "Sticks"],
	# Sound
	&"volume_master": [1.0, 0.0, 1.5, 0.05, "Master", "Sound"],
	&"volume_kick": [1.0, 0.0, 1.5, 0.05, "Kick", "Sound"],
	&"volume_snare": [1.0, 0.0, 1.5, 0.05, "Snare", "Sound"],
	&"volume_toms": [1.0, 0.0, 1.5, 0.05, "Toms", "Sound"],
	&"volume_hihat": [1.0, 0.0, 1.5, 0.05, "Hi-hat", "Sound"],
	&"volume_cymbals": [1.0, 0.0, 1.5, 0.05, "Cymbals", "Sound"],
	&"spatial_audio": [0.5, 0.0, 1.0, 0.05, "Spatial audio", "Sound"],
}

## Mixer bus for each volume setting.
const VOLUME_BUSES := {
	&"volume_master": &"Master", &"volume_kick": &"Kick", &"volume_snare": &"Snare",
	&"volume_toms": &"Toms", &"volume_hihat": &"HiHat", &"volume_cymbals": &"Cymbals",
}

## Where settings are saved. Tests point this elsewhere.
var path := PATH
## Save automatically on every change.
var autosave := true

var _values := {}


func _ready() -> void:
	load_settings()
	apply_all()


func get_value(key: StringName) -> Variant:
	return _values.get(key, SPECS[key][0])


func set_value(key: StringName, value: Variant) -> void:
	assert(SPECS.has(key), "Unknown setting %s" % key)
	var spec: Array = SPECS[key]
	if spec[1] != null:
		value = clampf(float(value), spec[1], spec[2])
	if _values.get(key) == value:
		return
	_values[key] = value
	_apply(key, value)
	changed.emit(key, value)
	if autosave:
		save_settings()


func reset_to_defaults() -> void:
	for key in SPECS:
		set_value(key, SPECS[key][0])


func load_settings() -> void:
	_values.clear()
	for key in SPECS:
		_values[key] = SPECS[key][0]
	var file := ConfigFile.new()
	if file.load(path) != OK:
		return
	for key in SPECS:
		var spec: Array = SPECS[key]
		var value = file.get_value("settings", String(key), spec[0])
		if spec[0] is bool:
			if value is bool:
				_values[key] = value
		elif value is float or value is int:
			_values[key] = clampf(float(value), spec[1], spec[2])


func save_settings() -> void:
	var file := ConfigFile.new()
	for key in _values:
		file.set_value("settings", String(key), _values[key])
	file.save(path)


## Pushes every value to the systems that use it (audio buses, hit feel,
## highlights). Scene objects such as sticks apply their own on [signal changed].
func apply_all() -> void:
	for key in _values:
		_apply(key, _values[key])


func _apply(key: StringName, value: Variant) -> void:
	match key:
		&"sensitivity":
			DrumPiece.sensitivity = value
		&"dynamics":
			DrumPiece.dynamics = value
		&"highlight_hits":
			HitHighlight.enabled = value
		&"spatial_audio":
			var audio := get_node_or_null(^"/root/DrumAudio")
			if audio:
				audio.spatial_strength = value
		_:
			if VOLUME_BUSES.has(key):
				var index := AudioServer.get_bus_index(VOLUME_BUSES[key])
				if index != -1:
					AudioServer.set_bus_volume_db(index, linear_to_db(maxf(float(value), 0.0001)))
