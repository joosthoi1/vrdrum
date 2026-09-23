class_name DrumKit
extends Node3D
## Owns the kit's [DrumPiece]s, routes their hits to audio and re-emits them
## as one stream for anything else that listens (debug overlay, scoring).

signal hit(hit: DrumHit)

## Where hits are sent for playback. Defaults to the DrumAudio autoload; tests
## can swap in a stub with a [code]play_hit(hit)[/code] method.
var audio: Object


func _ready() -> void:
	if audio == null:
		audio = get_node_or_null(^"/root/DrumAudio")
	for piece in find_children("*", "DrumPiece", true, false):
		(piece as DrumPiece).hit.connect(_on_piece_hit)


func pieces() -> Array[DrumPiece]:
	var out: Array[DrumPiece] = []
	for piece in find_children("*", "DrumPiece", true, false):
		out.append(piece)
	return out


## Moves the kit vertically so the snare (or first piece) sits
## [param below_tips] metres under [param tip_height].
func calibrate_height(tip_height: float, below_tips: float = 0.06) -> void:
	var reference := get_node_or_null(^"Snare") as DrumPiece
	if reference == null:
		var all := pieces()
		if all.is_empty():
			return
		reference = all[0]
	global_position.y += (tip_height - below_tips) - reference.global_position.y


func _on_piece_hit(h: DrumHit) -> void:
	if audio:
		audio.play_hit(h)
	hit.emit(h)
