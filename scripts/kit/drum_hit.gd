class_name DrumHit
extends RefCounted
## A single detected strike. Carries everything audio, haptics, visuals and
## (later) rhythm-mode scoring need.

var piece_id: StringName
var zone: StringName
## 0..1 loudness derived from [member speed] (or pedal speed).
var intensity: float
## Tip speed along the surface normal, in m/s. 0 for pedal hits.
var speed: float
var position: Vector3
## Which stick made the hit, or -1 for pedals.
var stick_id: int
var time_usec: int
## Choke group this sound belongs to, so it can be cut off later.
var choke_group: StringName
## Choke group to silence before this sound plays (the hi-hat pedal closing
## cuts the open hi-hat).
var chokes: StringName


## Key used to look up samples, e.g. [code]&"snare/head"[/code].
func articulation() -> StringName:
	return StringName("%s/%s" % [piece_id, zone])
