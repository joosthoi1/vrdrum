class_name MidiBridge
extends Node
## Sends every hit on the kit out as a MIDI note, so Clone Hero (or a DAW)
## can use the VR kit like an electronic drum kit.
##
## On Windows, create a virtual cable with loopMIDI and pick its port; Clone
## Hero then selects the same port as its MIDI input. On Linux the bridge can
## also create its own virtual ALSA port. Needs the vrdrum_native extension.

signal status_changed(status: String)

## GM percussion is MIDI channel 10 (index 9).
const CHANNEL := 9
## How long after the note-on the note-off is sent.
const NOTE_LENGTH_MS := 30
## Port choice that creates a virtual port instead (Linux / macOS only).
const VIRTUAL_PORT := "Create virtual port \"VR Drums\""

var kit: DrumKit
## The output: a MidiOut from the native extension, or any object with
## send(status, data1, data2) (tests use a fake).
var port: Object
var enabled := false
var preset: int = DrumMidiMap.Preset.CLONE_HERO
var status := "MIDI output is off":
	set(value):
		if value != status:
			status = value
			status_changed.emit(value)

var _settings: Node
## [due time in msec, note] pairs waiting for their note-off.
var _pending_offs: Array = []


func _ready() -> void:
	if kit:
		kit.hit.connect(_on_hit)
	_settings = get_node_or_null(^"/root/Settings")
	if _settings:
		preset = _settings.get_value(&"midi_map")
		_settings.changed.connect(_on_setting_changed)
		if _settings.get_value(&"midi_enabled"):
			set_enabled(true)


func _exit_tree() -> void:
	close_port()


## True when the native extension that provides MIDI output is loaded.
static func is_available() -> bool:
	return ClassDB.class_exists(&"MidiOut")


## Output ports to choose from (empty without the native extension).
static func port_names() -> PackedStringArray:
	if not is_available():
		return PackedStringArray()
	var names: PackedStringArray = ClassDB.class_call_static(&"MidiOut", &"get_port_names")
	if OS.get_name() != "Windows":
		names.append(VIRTUAL_PORT)
	return names


func set_enabled(on: bool) -> void:
	enabled = on
	if on:
		open_port()
	else:
		close_port()
		status = "MIDI output is off"


## Opens the port saved in the settings. With none saved, picks a port
## that looks like a loopMIDI / "VR Drums" cable.
func open_port() -> bool:
	close_port()
	if not is_available():
		status = "MIDI output needs the vrdrum_native extension, which isn't loaded on this platform"
		return false
	var names := port_names()
	var wanted: String = _settings.get_value(&"midi_port") if _settings else ""
	if wanted == "":
		for candidate in names:
			var lower := candidate.to_lower()
			if "vr drums" in lower or "loopmidi" in lower:
				wanted = candidate
				break
	if wanted == "":
		status = "Pick a MIDI output port (create one with loopMIDI first)"
		return false
	var index := names.find(wanted)
	if index == -1:
		status = "Port \"%s\" not found. Is loopMIDI running?" % wanted
		return false
	var midi: Object = ClassDB.instantiate(&"MidiOut")
	var ok: bool = midi.open_virtual_port("VR Drums") if wanted == VIRTUAL_PORT else midi.open_port(index)
	if not ok:
		status = "Couldn't open \"%s\": %s" % [wanted, midi.get_last_error()]
		return false
	port = midi
	status = "Sending to \"%s\"" % midi.get_port_name()
	return true


func close_port() -> void:
	_flush_note_offs()
	if port and port.has_method("close"):
		port.close()
	port = null


## Sends one note (note-on now, note-off shortly after).
func send_note(note: int, velocity: int) -> void:
	if port == null:
		return
	port.send(0x90 | CHANNEL, note, velocity)
	_pending_offs.append([Time.get_ticks_msec() + NOTE_LENGTH_MS, note])


## Sends a Clone Hero lane's note, for mapping lanes in Clone Hero.
func test_lane(note: int) -> void:
	if port == null and enabled:
		open_port()
	send_note(note, 100)


func _process(_delta: float) -> void:
	if not _pending_offs.is_empty():
		send_due_note_offs(Time.get_ticks_msec())


## Sends the note-offs due by [param now_msec]. Public so tests can drive it.
func send_due_note_offs(now_msec: int) -> void:
	while not _pending_offs.is_empty() and _pending_offs[0][0] <= now_msec:
		var off: Array = _pending_offs.pop_front()
		if port:
			port.send(0x80 | CHANNEL, off[1], 0)


func _flush_note_offs() -> void:
	for off in _pending_offs:
		if port:
			port.send(0x80 | CHANNEL, off[1], 0)
	_pending_offs.clear()


func _on_hit(h: DrumHit) -> void:
	if not enabled or port == null:
		return
	var note := DrumMidiMap.note_for(h.articulation(), preset)
	if note >= 0:
		send_note(note, DrumMidiMap.velocity_for(h.intensity))


func _on_setting_changed(key: StringName, value: Variant) -> void:
	match key:
		&"midi_enabled":
			set_enabled(value)
		&"midi_port":
			if enabled:
				open_port()
		&"midi_map":
			preset = value
