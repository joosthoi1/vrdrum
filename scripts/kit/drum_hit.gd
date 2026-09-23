class_name DrumHit
extends RefCounted
## A single detected strike. Carries everything audio, haptics, visuals and
## (later) rhythm-mode scoring need.

var piece_id: StringName
var zone: StringName
## 0..1 loudness derived from [member speed].
var intensity: float
## Tip speed along the surface normal, in m/s.
var speed: float
var position: Vector3
var stick_id: int
var time_usec: int


## Key used to look up samples, e.g. [code]&"snare/head"[/code].
func articulation() -> StringName:
	return StringName("%s/%s" % [piece_id, zone])
