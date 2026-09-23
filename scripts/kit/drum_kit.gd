class_name DrumKit
extends Node3D
## Owns the kit's [DrumPiece]s, routes their hits and chokes to audio and
## re-emits hits as one stream for anything else that listens (debug overlay,
## scoring). Also owns the kit layout: presets, save slots, left-handed
## mirroring, height calibration and recentering. The layout in use is saved
## as "current" and restored at startup.

signal hit(hit: DrumHit)
## Emitted after the layout or placement changes.
signal layout_changed

const CURRENT := "current"

## Where hits are sent for playback. Defaults to the DrumAudio autoload; tests
## can swap in a stub with [code]play_hit(hit)[/code] and [code]choke(group)[/code].
var audio: Object
## Load the saved layout at startup and save every change. Off in tests.
var persist := true
## The layout the scene was authored with (right-handed).
var default_layout: Dictionary
var left_handed := false


func _ready() -> void:
	if audio == null:
		audio = get_node_or_null(^"/root/DrumAudio")
	for piece in pieces():
		piece.hit.connect(_on_piece_hit)
		piece.choked.connect(_on_piece_choked)
	default_layout = KitLayout.capture(self, pieces())
	var settings := get_node_or_null(^"/root/Settings")
	if settings:
		left_handed = settings.get_value(&"left_handed")
		settings.changed.connect(_on_setting_changed)
	var saved := KitLayout.load_layout(CURRENT) if persist else {}
	apply_layout(saved if not saved.is_empty() else default_layout, not saved.is_empty(), false)


## The current layout in right-handed form.
func layout() -> Dictionary:
	var current := KitLayout.capture(self, pieces())
	return KitLayout.mirrored(current) if left_handed else current


## Applies a right-handed [param data] (mirrored when playing left-handed).
func apply_layout(data: Dictionary, with_placement: bool = true, save: bool = true) -> void:
	KitLayout.apply(self, pieces(), KitLayout.mirrored(data) if left_handed else data, with_placement)
	_after_layout_change(save)


func set_left_handed(on: bool) -> void:
	if on == left_handed:
		return
	var current := layout()
	left_handed = on
	apply_layout(current, false)


## Loads a built-in layout: "default" or "compact". Keeps the placement.
func load_preset(preset: String) -> void:
	match preset:
		"compact":
			apply_layout(KitLayout.compact(default_layout), false)
		_:
			apply_layout(default_layout, false)


func save_slot(slot: int) -> void:
	KitLayout.save(layout(), "slot%d" % slot)


## Returns false if the slot is empty.
func load_slot(slot: int) -> bool:
	var data := KitLayout.load_layout("slot%d" % slot)
	if data.is_empty():
		return false
	apply_layout(data, false)
	return true


## Saves the current layout so it is restored next time.
func save_current() -> void:
	if persist:
		KitLayout.save(layout(), CURRENT)


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
	_after_layout_change(true)


## Places the kit around the player: the kit's origin (where the drummer
## sits) goes under [param head], turned to face where the head faces. Keeps
## the kit's height.
func recenter(head: Transform3D) -> void:
	var forward := -head.basis.z
	forward.y = 0.0
	if forward.length() < 0.01:
		return
	var yaw := atan2(-forward.x, -forward.z)
	global_transform = Transform3D(Basis(Vector3.UP, yaw), Vector3(head.origin.x, global_position.y, head.origin.z))
	_after_layout_change(true)


func _after_layout_change(save: bool) -> void:
	for p in pieces():
		p.reset_arming()
	if save:
		save_current()
	layout_changed.emit()


func _on_setting_changed(key: StringName, value: Variant) -> void:
	if key == &"left_handed":
		set_left_handed(value)


func _collect_pieces(node: Node, out: Array[DrumPiece]) -> void:
	for child in node.get_children():
		if child is DrumPiece:
			out.append(child)
		_collect_pieces(child, out)


## Plays and announces a hit that doesn't come from a kit piece (the sticks
## clicked together).
func play_external_hit(h: DrumHit) -> void:
	_on_piece_hit(h)


func _on_piece_hit(h: DrumHit) -> void:
	if audio:
		audio.play_hit(h)
	hit.emit(h)


func _on_piece_choked(group: StringName) -> void:
	if audio:
		audio.choke(group)
