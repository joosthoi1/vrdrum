class_name SampleKit
extends RefCounted
## Loads a recorded kit (a folder with kit.json and WAV files, built by
## tools/build_sample_kit.py) into a [DrumSampleBank].
##
## kit.json: {"articulations": {"snare/head": {"gain_db": -1.5,
##   "layers": [["soft_rr1.wav", "soft_rr2.wav"], ..., ["loud_rr1.wav"]]}}}
## Layers go soft to loud; paths are relative to the folder.

const DEFAULT_DIR := "res://assets/kits/rusty"


## Returns the bank, or null if the folder has no usable kit.json.
static func load_bank(dir: String = DEFAULT_DIR) -> DrumSampleBank:
	var manifest_path := dir.path_join("kit.json")
	if not FileAccess.file_exists(manifest_path):
		return null
	var manifest = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	if typeof(manifest) != TYPE_DICTIONARY or not manifest.has("articulations"):
		push_error("Invalid kit manifest: %s" % manifest_path)
		return null
	var bank := DrumSampleBank.new()
	bank.natural_dynamics = true
	for key in manifest.articulations:
		var articulation := StringName(key)
		var entry: Dictionary = manifest.articulations[key]
		for layer in entry.get("layers", []):
			var streams := []
			for file in layer:
				var stream := load(dir.path_join(file)) as AudioStream
				if stream:
					streams.append(stream)
				else:
					push_error("Missing sample %s" % dir.path_join(file))
			if not streams.is_empty():
				bank.add_layer(articulation, streams)
		bank.set_trim(articulation, float(entry.get("gain_db", 0.0)))
	return bank
