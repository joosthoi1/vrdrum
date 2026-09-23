class_name DrumPiece
extends Node3D
## A hittable surface (drum head, cymbal, pad).
##
## The playing surface is the plane through [method surface_center] with this
## node's local +Y axis as the normal. Concentric zones (e.g. head/rim,
## bell/bow/edge) are defined by ascending outer radii. [DrumStick]s call
## [method find_crossing] every frame and [method register_hit] on the
## earliest crossing. Pedal-driven pieces fire hits through [method trigger].

signal hit(hit: DrumHit)
## Emitted when something silences this piece without playing it (a hand
## grabbing a cymbal, the hi-hat closing slowly).
signal choked(group: StringName)

const GROUP := &"drum_pieces"

## Every piece currently in the scene tree. Sticks scan this every frame, so
## it is kept up to date here rather than queried from the group each time.
static var all: Array[DrumPiece] = []

## Global hit sensitivity from the settings: above 1, less force is needed
## for a loud hit.
static var sensitivity := 1.0
## Global scale on [member velocity_exponent] from the settings: above 1
## makes loud hits harder to reach, below 1 easier.
static var dynamics := 1.0

@export var piece_id: StringName = &"snare"
## Zone names, innermost first. Must match [member zone_outer_radii] in length.
## Leave empty for pieces sticks can't hit (the kick).
@export var zone_names: PackedStringArray = PackedStringArray(["head", "rim"])
## Outer radius of each zone in metres, ascending.
@export var zone_outer_radii: PackedFloat32Array = PackedFloat32Array([0.16, 0.19])
## Sounds from this piece belong to this choke group (e.g. a cymbal), so they
## can be cut off. Empty for drums.
@export var choke_group: StringName = &""
## After a hit, the tip must rise this far above the surface before the same
## stick can trigger this piece again. Stops jitter from double-triggering.
@export var rearm_height := 0.012
## Strikes slower than this (m/s along the normal) are treated as resting the
## stick on the surface: silent, but they still disarm.
@export var min_hit_speed := 0.25
## Strike speed that maps to full intensity.
@export var max_hit_speed := 7.0
## Velocity curve shape, see [method HitMath.intensity_from_speed].
@export var velocity_exponent := 0.8

## stick_id -> false while waiting for that stick to lift off after a hit.
var _armed := {}


func _enter_tree() -> void:
	add_to_group(GROUP)
	all.append(self)


func _exit_tree() -> void:
	all.erase(self)


func surface_normal() -> Vector3:
	return global_basis.y.normalized()


## World-space point the playing surface passes through. Overridden by pieces
## whose surface moves (the hi-hat's top cymbal).
func surface_center() -> Vector3:
	return global_position


## Returns the fraction along [param p0] -> [param p1] where this stick's tip
## crosses into a zone of this piece, or -1.0. Also updates re-arm state, so it
## must be called every frame for every stick, even when another piece wins.
func find_crossing(stick_id: int, p0: Vector3, p1: Vector3) -> float:
	var center := surface_center()
	var normal := surface_normal()
	if not _armed.get(stick_id, true):
		if (p1 - center).dot(normal) > rearm_height:
			_armed[stick_id] = true
		return -1.0
	var t := HitMath.downward_crossing(p0, p1, center, normal)
	if t < 0.0:
		return -1.0
	if zone_at(p0.lerp(p1, t)) < 0:
		return -1.0
	return t


## Index into [member zone_names] for a point on the surface, or -1 if outside.
func zone_at(point: Vector3) -> int:
	return HitMath.zone_index(HitMath.radial_distance(point, surface_center(), surface_normal()), zone_outer_radii)


## Records a stick strike at [param point]. Returns the emitted [DrumHit], or
## null if the strike was too slow to sound.
func register_hit(stick_id: int, point: Vector3, tip_velocity: Vector3) -> DrumHit:
	_armed[stick_id] = false
	var speed := -tip_velocity.dot(surface_normal())
	var zone := zone_at(point)
	if speed < min_hit_speed or zone < 0:
		return null
	var loud_speed := maxf(max_hit_speed / sensitivity, min_hit_speed + 0.1)
	var intensity := HitMath.intensity_from_speed(speed, min_hit_speed, loud_speed, velocity_exponent * dynamics)
	return emit_hit(_zone_name(zone), intensity, speed, point, stick_id)


## Fires a hit that doesn't come from a stick (pedals). Returns the hit.
func trigger(zone: StringName, intensity: float, chokes: StringName = &"") -> DrumHit:
	return emit_hit(zone, intensity, 0.0, surface_center(), -1, chokes)


func emit_hit(zone: StringName, intensity: float, speed: float, point: Vector3, stick_id: int, chokes: StringName = &"") -> DrumHit:
	var h := DrumHit.new()
	h.piece_id = piece_id
	h.zone = zone
	h.speed = speed
	h.intensity = clampf(intensity, 0.0, 1.0)
	h.position = point
	h.stick_id = stick_id
	h.choke_group = choke_group
	h.chokes = chokes
	h.time_usec = Time.get_ticks_usec()
	hit.emit(h)
	return h


## Silences this piece's ringing sounds.
func choke() -> void:
	if choke_group:
		choked.emit(choke_group)


func is_armed(stick_id: int) -> bool:
	return _armed.get(stick_id, true)


## Kit editor support: where to grab the piece and how far out it reaches
## (the outermost zone, or a default for pieces sticks can't hit).
func grab_center() -> Vector3:
	return surface_center()


func grab_normal() -> Vector3:
	return surface_normal()


func grab_radius() -> float:
	return zone_outer_radii[zone_outer_radii.size() - 1] if not zone_outer_radii.is_empty() else 0.28


## Re-arms every stick, e.g. after the piece was moved.
func reset_arming() -> void:
	_armed.clear()


## Zone name reported for a strike. Overridden where the sound depends on more
## than where the stick landed (hi-hat openness).
func _zone_name(zone_index: int) -> StringName:
	return StringName(zone_names[zone_index])
