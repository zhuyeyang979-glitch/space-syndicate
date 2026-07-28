@tool
extends Control
class_name V07ReferencePlanetStage

@onready var _map_view: Control = %V07ReferencePlanetMapView


func _ready() -> void:
	# The shared map implementation defaults to a 720 px square for the
	# production board. The contextual reference stage has a shorter responsive
	# band, so it supplies its own non-authoritative presentation minimum.
	if _map_view != null:
		_map_view.custom_minimum_size = Vector2(420.0, 320.0)
	set_meta("v07_reference_planet_stage", true)


func get_embedded_map_view() -> Control:
	return _map_view


func debug_snapshot() -> Dictionary:
	var backdrop := _map_view.get_node_or_null("BackdropLayer/PlanetGlobeBackdrop") \
		if _map_view != null else null
	var guide := _map_view.get_node_or_null("OrbitLayer/PlanetOrbitGuide") \
		if _map_view != null else null
	var backdrop_snapshot := _debug_snapshot(backdrop)
	var guide_snapshot := _debug_snapshot(guide)
	return {
		"reference_stage": true,
		"map_view_connected": _map_view != null,
		"legacy_draw_fallback_enabled": bool(_map_view.get("legacy_draw_fallback_enabled")) \
			if _map_view != null else true,
		"positional_decoration_count": int(backdrop_snapshot.get("positional_decoration_count", -1)),
		"radial_spoke_count": int(guide_snapshot.get("radial_spoke_count", -1)),
		"positional_marker_count": int(guide_snapshot.get("positional_marker_count", -1)),
		"left_right_layer_count": _named_layer_count([
			"RoleSeatLayerHost",
			"BackSeatLayer",
			"FrontSeatLayer",
		]),
	}


func _debug_snapshot(node: Node) -> Dictionary:
	if node == null or not node.has_method("debug_snapshot"):
		return {}
	var value: Variant = node.call("debug_snapshot")
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _named_layer_count(names: Array[String]) -> int:
	var count := 0
	for candidate in find_children("*", "", true, false):
		if candidate != null and candidate.name in names:
			count += 1
	return count
