class_name Cymbal
extends DrumPiece
## A cymbal that can be choked by grabbing its edge: bring a hand (controller)
## to the rim and the ringing stops, as on a real kit.

## A hand this close to the edge (in the plane, metres) chokes the cymbal...
@export var choke_edge_width := 0.07
## ...if it is also within this distance above or below the surface.
@export var choke_height := 0.06

var _held := false


func _process(_delta: float) -> void:
	var holding := false
	for hand in get_tree().get_nodes_in_group(&"hands"):
		if is_hand_at_edge((hand as Node3D).global_position):
			holding = true
			break
	if holding and not _held:
		choke()
	_held = holding


func is_hand_at_edge(point: Vector3) -> bool:
	var normal := surface_normal()
	if absf((point - surface_center()).dot(normal)) > choke_height:
		return false
	var radius := zone_outer_radii[zone_outer_radii.size() - 1] if not zone_outer_radii.is_empty() else 0.0
	var r := HitMath.radial_distance(point, surface_center(), normal)
	return r >= radius - choke_edge_width and r <= radius + choke_edge_width * 0.5
