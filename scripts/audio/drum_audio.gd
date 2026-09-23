extends Node
## Autoload "DrumAudio": plays drum hits through a fixed pool of voices.
##
## Samples are uncompressed and preloaded, and voices are allocated up front,
## so triggering a hit never loads or allocates anything. The synthesised kit
## is built on a worker thread at startup (instant once cached).

signal bank_ready

const VOICE_COUNT := 64
const BUS_NAME := &"Drums"

## Playback gain for the softest possible hit.
@export var min_gain_db := -30.0
## Random playback pitch variation (fraction), so repeats never sound
## machine-identical even with few recorded variations.
@export var pitch_jitter := 0.012
## Fade time when a sound is choked.
@export var choke_fade := 0.07

var bank: DrumSampleBank

var _voices: Array[AudioStreamPlayer] = []
var _voice_groups: Array[StringName] = []
var _voice_fades: Array[Tween] = []
var _next_voice := 0
var _build_task := -1
var _built_bank: DrumSampleBank


func _ready() -> void:
	_ensure_bus()
	for i in VOICE_COUNT:
		var voice := AudioStreamPlayer.new()
		voice.bus = BUS_NAME
		add_child(voice)
		_voices.append(voice)
		_voice_groups.append(&"")
		_voice_fades.append(null)
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


func play_hit(hit: DrumHit) -> AudioStreamPlayer:
	if hit.chokes:
		choke(hit.chokes)
	return play(hit.articulation(), hit.intensity, hit.choke_group)


## Plays [param articulation] (e.g. &"snare/head") at [param intensity] 0..1.
## Returns the voice used, or null if there is no sample for it (yet).
func play(articulation: StringName, intensity: float, choke_group: StringName = &"") -> AudioStreamPlayer:
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
	voice.volume_db = DrumSampleBank.gain_db(intensity, min_gain_db)
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


func _ensure_bus() -> void:
	if AudioServer.get_bus_index(BUS_NAME) != -1:
		return
	AudioServer.add_bus()
	var idx := AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, BUS_NAME)
	AudioServer.set_bus_send(idx, &"Master")
	var comp := AudioEffectCompressor.new()
	comp.threshold = -12.0
	comp.ratio = 3.0
	comp.attack_us = 2000.0
	AudioServer.add_bus_effect(idx, comp)
	var room := AudioEffectReverb.new()
	room.room_size = 0.35
	room.damping = 0.6
	room.wet = 0.12
	room.dry = 1.0
	AudioServer.add_bus_effect(idx, room)
