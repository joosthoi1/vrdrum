extends Node
## Autoload "DrumAudio": plays drum hits through a fixed pool of voices.
##
## Samples are uncompressed and preloaded, and voices are allocated up front,
## so triggering a hit never loads or allocates anything.

const VOICE_COUNT := 32
const BUS_NAME := &"Drums"

## Playback gain for the softest possible hit.
@export var min_gain_db := -30.0

var bank: DrumSampleBank

var _voices: Array[AudioStreamPlayer] = []
var _next_voice := 0


func _ready() -> void:
	_ensure_bus()
	for i in VOICE_COUNT:
		var voice := AudioStreamPlayer.new()
		voice.bus = BUS_NAME
		add_child(voice)
		_voices.append(voice)
	if bank == null:
		bank = DrumSynth.build_default_bank()


func play_hit(hit: DrumHit) -> AudioStreamPlayer:
	return play(hit.articulation(), hit.intensity)


## Plays [param articulation] (e.g. &"snare/head") at [param intensity] 0..1.
## Returns the voice used, or null if there is no sample for it.
func play(articulation: StringName, intensity: float) -> AudioStreamPlayer:
	var stream := bank.pick(articulation, intensity) if bank else null
	if stream == null:
		push_warning("No sample for articulation '%s'" % articulation)
		return null
	var voice := _take_voice()
	voice.stream = stream
	voice.volume_db = DrumSampleBank.gain_db(intensity, min_gain_db)
	voice.play()
	return voice


## Prefers an idle voice; when all are busy, steals the oldest one.
func _take_voice() -> AudioStreamPlayer:
	for i in VOICE_COUNT:
		var voice := _voices[(_next_voice + i) % VOICE_COUNT]
		if not voice.playing:
			_next_voice = (_next_voice + i + 1) % VOICE_COUNT
			return voice
	var oldest := _voices[_next_voice]
	_next_voice = (_next_voice + 1) % VOICE_COUNT
	return oldest


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
