class_name DrumPiece
extends Node3D
## A hittable surface (drum head, cymbal, pad).
##
## The playing surface is the plane through this node's origin with its local
## +Y axis as the normal. Concentric zones (e.g. head/rim, bell/bow/edge) are
## defined by ascending outer radii. [DrumStick]s call [method find_crossing]
## every frame and [method register_hit] on the earliest crossing.

signal hit(hit: DrumHit)

const GROUP := &"drum_pieces"

@export var piece_id: StringName = &"snare"
## Zone names, innermost first. Must match [member zone_outer_radii] in length.
@export var zone_names: PackedStringArray = PackedStringArray(["head", "rim"])
## Outer radius of each zone in metres, ascending.
@export var zone_outer_radii: PackedFloat32Array = PackedFloat32Array([0.16, 0.19])
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


func surface_normal() -> Vector3:
	return global_basis.y.normalized()


## Returns the fraction along [param p0] -> [param p1] where this stick's tip
## crosses into a zone of this piece, or -1.0. Also updates re-arm state, so it
## must be called every frame for every stick, even when another piece wins.
func find_crossing(stick_id: int, p0: Vector3, p1: Vector3) -> float:
	var center := global_position
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
	return HitMath.zone_index(HitMath.radial_distance(point, global_position, surface_normal()), zone_outer_radii)


## Records a strike at [param point]. Returns the emitted [DrumHit], or null if
## the strike was too slow to sound.
func register_hit(stick_id: int, point: Vector3, tip_velocity: Vector3) -> DrumHit:
	_armed[stick_id] = false
	var speed := -tip_velocity.dot(surface_normal())
	var zone := zone_at(point)
	if speed < min_hit_speed or zone < 0:
		return null
	var h := DrumHit.new()
	h.piece_id = piece_id
	h.zone = StringName(zone_names[zone])
	h.speed = speed
	h.intensity = HitMath.intensity_from_speed(speed, min_hit_speed, max_hit_speed, velocity_exponent)
	h.position = point
	h.stick_id = stick_id
	h.time_usec = Time.get_ticks_usec()
	hit.emit(h)
	return h


func is_armed(stick_id: int) -> bool:
	return _armed.get(stick_id, true)
