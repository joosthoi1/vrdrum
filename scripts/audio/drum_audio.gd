extends Node
## Autoload "DrumAudio": plays drum hits through a fixed pool of voices.
##
## Uses the recorded kit (res://assets/kits/rusty) when present and falls back
## to the synthesised kit, built on a worker thread (instant once cached).
## Voices are positional, so in VR each drum is heard from where it stands.
## Everything is preloaded and allocated up front: triggering a hit never
## loads or allocates anything.
##
## Bus layout: Kick / Snare / Toms / HiHat / Cymbals -> Drums (glue
## compressor, light room) -> Master.

signal bank_ready

const VOICE_COUNT := 64
const BUS_NAME := &"Drums"
const GROUP_BUSES: Array[StringName] = [&"Kick", &"Snare", &"Toms", &"HiHat", &"Cymbals"]

## Playback gain for the softest possible hit (synthesised kit only; recorded
## layers carry their own dynamics).
@export var min_gain_db := -30.0
## Random playback pitch variation (fraction), so repeats never sound
## machine-identical even with few recorded variations.
@export var pitch_jitter := 0.006
## Fade time when a sound is choked.
@export var choke_fade := 0.07
## How strongly sounds pan towards where each drum is (0 = centred, 1 = full).
@export var spatial_strength := 0.5:
	set(value):
		spatial_strength = value
		for voice in _voices:
			voice.panning_strength = value
## Load the recorded kit. Off falls back to the synthesised kit.
@export var use_recorded_kit := true

var bank: DrumSampleBank

var _voices: Array[AudioStreamPlayer3D] = []
var _voice_groups: Array[StringName] = []
var _voice_fades: Array[Tween] = []
var _next_voice := 0
var _build_task := -1
var _built_bank: DrumSampleBank


func _ready() -> void:
	_ensure_buses()
	for i in VOICE_COUNT:
		var voice := AudioStreamPlayer3D.new()
		voice.bus = BUS_NAME
		voice.attenuation_model = AudioStreamPlayer3D.ATTENUATION_DISABLED
		voice.panning_strength = spatial_strength
		voice.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED
		add_child(voice)
		_voices.append(voice)
		_voice_groups.append(&"")
		_voice_fades.append(null)
	if bank == null and use_recorded_kit:
		bank = SampleKit.load_bank()
	if bank == null:
		_build_task = WorkerThreadPool.add_task(_build_bank, false, "Build drum sounds")


func _process(_delta: float) -> void:
	if _build_task != -1 and WorkerThreadPool.is_task_completed(_build_task):
		_finish_build()


func _exit_tree() -> void:
	# Never quit with the build still running on a worker thread.
	if _build_task != -1:
		_finish_build()


func is_ready() -> bool:
	return bank != null


## Blocks until the sample bank is available. For tests and tools.
func wait_until_ready() -> void:
	if _build_task != -1:
		_finish_build()


func play_hit(hit: DrumHit) -> AudioStreamPlayer3D:
	if hit.chokes:
		choke(hit.chokes)
	return play(hit.articulation(), hit.intensity, hit.choke_group, hit.position)


## Plays [param articulation] (e.g. &"snare/head") at [param intensity] 0..1
## from [param position]. Returns the voice used, or null if there is no
## sample for it (yet).
func play(articulation: StringName, intensity: float, choke_group: StringName = &"", position: Vector3 = Vector3.ZERO) -> AudioStreamPlayer3D:
	if bank == null:
		return null
	var stream := bank.pick(articulation, intensity)
	if stream == null:
		push_warning("No sample for articulation '%s'" % articulation)
		return null
	var index := _take_voice()
	var voice := _voices[index]
	_voice_groups[index] = choke_group
	voice.stream = stream
	voice.bus = bus_for(articulation)
	voice.global_position = position
	voice.volume_db = bank.gain_db_for(articulation, intensity, min_gain_db)
	voice.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	voice.play()
	return voice


## Quickly fades out every playing sound in [param group]. Returns how many
## voices were choked.
func choke(group: StringName) -> int:
	var count := 0
	for i in VOICE_COUNT:
		if _voice_groups[i] != group or not _voices[i].playing:
			continue
		_voice_groups[i] = &""
		_stop_fade(i)
		var voice := _voices[i]
		var fade := voice.create_tween()
		fade.tween_property(voice, "volume_db", -60.0, choke_fade)
		fade.tween_callback(voice.stop)
		_voice_fades[i] = fade
		count += 1
	return count


## Mixer bus for an articulation, e.g. &"tom2/head" -> &"Toms".
static func bus_for(articulation: StringName) -> StringName:
	var piece := String(articulation).get_slice("/", 0)
	match piece:
		"kick":
			return &"Kick"
		"snare":
			return &"Snare"
		"hihat":
			return &"HiHat"
		"crash", "ride":
			return &"Cymbals"
	if piece.begins_with("tom"):
		return &"Toms"
	return BUS_NAME


## Sets a mixer bus volume (linear 0..1.5). Used by the settings menu.
static func set_bus_volume(bus: StringName, linear: float) -> void:
	var index := AudioServer.get_bus_index(bus)
	if index != -1:
		AudioServer.set_bus_volume_db(index, linear_to_db(maxf(linear, 0.0001)))


## Prefers an idle voice; when all are busy, steals the oldest one.
func _take_voice() -> int:
	var index := _next_voice
	for i in VOICE_COUNT:
		var candidate := (_next_voice + i) % VOICE_COUNT
		if not _voices[candidate].playing:
			index = candidate
			break
	_next_voice = (index + 1) % VOICE_COUNT
	_stop_fade(index)
	return index


func _stop_fade(index: int) -> void:
	if _voice_fades[index]:
		_voice_fades[index].kill()
		_voice_fades[index] = null


func _build_bank() -> void:
	_built_bank = DrumSynth.build_default_bank()


func _finish_build() -> void:
	WorkerThreadPool.wait_for_task_completion(_build_task)
	_build_task = -1
	bank = _built_bank
	_built_bank = null
	bank_ready.emit()


func _ensure_buses() -> void:
	if AudioServer.get_bus_index(BUS_NAME) != -1:
		return
	var drums := _add_bus(BUS_NAME, &"Master")
	var comp := AudioEffectCompressor.new()
	comp.threshold = -10.0
	comp.ratio = 2.5
	comp.attack_us = 5000.0
	AudioServer.add_bus_effect(drums, comp)
	var room := AudioEffectReverb.new()
	room.room_size = 0.3
	room.damping = 0.6
	room.wet = 0.06
	room.dry = 1.0
	AudioServer.add_bus_effect(drums, room)
	for bus in GROUP_BUSES:
		_add_bus(bus, BUS_NAME)


static func _add_bus(bus_name: StringName, send: StringName) -> int:
	AudioServer.add_bus()
	var index := AudioServer.bus_count - 1
	AudioServer.set_bus_name(index, bus_name)
	AudioServer.set_bus_send(index, send)
	return index
