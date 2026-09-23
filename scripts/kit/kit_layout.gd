class_name KitLayout
extends RefCounted
## Kit layouts: where each piece sits, and where the whole kit is placed in
## the room. Stored as JSON under [member dir] and always in right-handed
## form; left-handed play mirrors a layout when it is applied.
##
## Format: {"version": 1, "placement": [12 floats],
##          "pieces": {"snare": [12 floats], ...},
##          "extras": {"screen": [12 floats]}}
## where 12 floats are a Transform3D: basis x, y, z columns, then origin.
## Extras (the Clone Hero screen) are placed like pieces but never mirrored.

const VERSION := 1
const SLOTS := 3

## Folder layouts are saved in. Tests point this elsewhere.
static var dir := "user://layouts"

## Mirror across the kit's YZ plane (x -> -x).
const MIRROR := Basis(Vector3(-1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1))


## Snapshot of [param kit]: every piece's local transform plus the kit's own.
static func capture(kit: Node3D, pieces: Array, extras: Dictionary = {}) -> Dictionary:
	var out := {"version": VERSION, "placement": to_array(kit.transform), "pieces": {}, "extras": {}}
	for piece in pieces:
		out.pieces[String(piece.piece_id)] = to_array(piece.transform)
	for key in extras:
		out.extras[key] = to_array(extras[key].transform)
	return out


## Moves pieces (and, with [param with_placement], the kit) to [param layout].
## Pieces missing from the layout stay where they are.
static func apply(kit: Node3D, pieces: Array, layout: Dictionary, with_placement: bool = true, extras: Dictionary = {}) -> void:
	if with_placement and layout.has("placement"):
		kit.transform = from_array(layout.placement)
	var saved: Dictionary = layout.get("pieces", {})
	for piece in pieces:
		var key := String(piece.piece_id)
		if saved.has(key):
			piece.transform = from_array(saved[key])
	var saved_extras: Dictionary = layout.get("extras", {})
	for key in extras:
		if saved_extras.has(key):
			extras[key].transform = from_array(saved_extras[key])


## The same layout for the other hand: every piece reflected left <-> right.
## Mirroring twice gives the original back.
static func mirrored(layout: Dictionary) -> Dictionary:
	var out := layout.duplicate(true)
	for key in out.get("pieces", {}):
		out.pieces[key] = to_array(mirror_transform(from_array(out.pieces[key])))
	return out


static func mirror_transform(t: Transform3D) -> Transform3D:
	# S * B * S keeps a proper rotation (no flipped handedness).
	return Transform3D(MIRROR * t.basis * MIRROR, MIRROR * t.origin)


## A tighter variant of [param layout]: every piece pulled towards the snare
## and the cymbals lowered, for shorter reach or smaller play spaces.
static func compact(layout: Dictionary) -> Dictionary:
	var out := layout.duplicate(true)
	var pieces: Dictionary = out.get("pieces", {})
	if not pieces.has("snare"):
		return out
	var center := from_array(pieces.snare).origin
	for key in pieces:
		if key == "snare":
			continue
		var t := from_array(pieces[key])
		var offset := t.origin - center
		t.origin = center + Vector3(offset.x * 0.85, offset.y, offset.z * 0.85)
		if key in ["crash", "ride"]:
			t.origin.y -= 0.06
		pieces[key] = to_array(t)
	return out


static func save(layout: Dictionary, name: String) -> Error:
	DirAccess.make_dir_recursive_absolute(dir)
	var file := FileAccess.open(dir.path_join(name + ".json"), FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(layout, " "))
	return OK


## The saved layout called [param name], or an empty dictionary.
static func load_layout(name: String) -> Dictionary:
	var path := dir.path_join(name + ".json")
	if not FileAccess.file_exists(path):
		return {}
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(data) != TYPE_DICTIONARY or int(data.get("version", 0)) != VERSION:
		return {}
	return data


static func exists(name: String) -> bool:
	return FileAccess.file_exists(dir.path_join(name + ".json"))


static func to_array(t: Transform3D) -> Array:
	var b := t.basis
	return [b.x.x, b.x.y, b.x.z, b.y.x, b.y.y, b.y.z, b.z.x, b.z.y, b.z.z, t.origin.x, t.origin.y, t.origin.z]


static func from_array(a: Array) -> Transform3D:
	if a.size() != 12:
		return Transform3D.IDENTITY
	return Transform3D(Vector3(a[0], a[1], a[2]), Vector3(a[3], a[4], a[5]), Vector3(a[6], a[7], a[8]), Vector3(a[9], a[10], a[11]))
