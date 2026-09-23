class_name DrumSampleBank
extends RefCounted
## Samples per articulation, organised as velocity layers (soft -> loud), each
## holding round-robin variations so repeated hits don't sound identical.

## True for recorded kits: the layers were recorded at their own loudness, so
## playback gain only shapes dynamics within a layer. False for normalised
## (synthesised) samples, where gain carries all of the dynamics.
var natural_dynamics := false

## articulation -> Array of layers; each layer is an Array of AudioStream.
var _layers := {}
## articulation -> round-robin counter.
var _rr := {}
## articulation -> loudness trim in dB.
var _trim := {}


## Appends [param variations] as the next (louder) velocity layer.
func add_layer(articulation: StringName, variations: Array) -> void:
	assert(not variations.is_empty())
	if not _layers.has(articulation):
		_layers[articulation] = []
	_layers[articulation].append(variations)


func set_trim(articulation: StringName, db: float) -> void:
	_trim[articulation] = db


func has(articulation: StringName) -> bool:
	return _layers.has(articulation)


func articulations() -> Array:
	return _layers.keys()


func layer_count(articulation: StringName) -> int:
	return _layers.get(articulation, []).size()


func layer_for(articulation: StringName, intensity: float) -> int:
	var count := layer_count(articulation)
	return clampi(int(intensity * count), 0, count - 1)


## Returns the next round-robin sample for this articulation and intensity,
## or null if the articulation has no samples.
func pick(articulation: StringName, intensity: float) -> AudioStream:
	if not has(articulation):
		return null
	var variations: Array = _layers[articulation][layer_for(articulation, intensity)]
	var n: int = _rr.get(articulation, 0)
	_rr[articulation] = n + 1
	return variations[n % variations.size()]


## Playback volume for a hit at [param intensity] (0..1), including the
## articulation's trim.
func gain_db_for(articulation: StringName, intensity: float, min_db: float = -30.0) -> float:
	var trim: float = _trim.get(articulation, 0.0)
	if not natural_dynamics:
		return gain_db(intensity, min_db) + trim
	# Within a recorded layer, fade from a bit quieter up to full level as the
	# intensity approaches the next layer. The softest layer can go quieter.
	var count := layer_count(articulation)
	if count == 0:
		return trim
	var position := clampf(intensity, 0.0, 1.0) * count
	var layer := layer_for(articulation, intensity)
	var within := clampf(position - layer, 0.0, 1.0)
	var floor_amp := 0.2 if layer == 0 else 0.55
	return linear_to_db(lerpf(floor_amp, 1.0, within)) + trim


## Playback volume for normalised samples. Linear amplitude interpolates from
## [param min_db] at intensity 0 up to 0 dB at intensity 1.
static func gain_db(intensity: float, min_db: float = -30.0) -> float:
	var amp := lerpf(db_to_linear(min_db), 1.0, clampf(intensity, 0.0, 1.0))
	return linear_to_db(amp)
