class_name DrumKit
extends Node3D
## Owns the kit's [DrumPiece]s, routes their hits and chokes to audio and
## re-emits hits as one stream for anything else that listens (debug overlay,
## scoring).

signal hit(hit: DrumHit)

## Where hits are sent for playback. Defaults to the DrumAudio autoload; tests
## can swap in a stub with [code]play_hit(hit)[/code] and [code]choke(group)[/code].
var audio: Object


func _ready() -> void:
	if audio == null:
		audio = get_node_or_null(^"/root/DrumAudio")
	for piece in pieces():
		piece.hit.connect(_on_piece_hit)
		piece.choked.connect(_on_piece_choked)


func pieces() -> Array[DrumPiece]:
	var out: Array[DrumPiece] = []
	_collect_pieces(self, out)
	return out


func piece(id: StringName) -> DrumPiece:
	for p in pieces():
		if p.piece_id == id:
			return p
	return null


## Moves the kit vertically so the snare (or first piece) sits
## [param below_tips] metres under [param tip_height].
func calibrate_height(tip_height: float, below_tips: float = 0.06) -> void:
	var reference := piece(&"snare")
	if reference == null:
		var all := pieces()
		if all.is_empty():
			return
		reference = all[0]
	global_position.y += (tip_height - below_tips) - reference.global_position.y


func _collect_pieces(node: Node, out: Array[DrumPiece]) -> void:
	for child in node.get_children():
		if child is DrumPiece:
			out.append(child)
		_collect_pieces(child, out)


func _on_piece_hit(h: DrumHit) -> void:
	if audio:
		audio.play_hit(h)
	hit.emit(h)


func _on_piece_choked(group: StringName) -> void:
	if audio:
		audio.choke(group)
