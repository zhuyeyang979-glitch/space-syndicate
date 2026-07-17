extends RefCounted
class_name WorldMapGeometryProjection

var revision := 0
var width_m := 1.0
var height_m := 1.0
var world_rect := Rect2(Vector2.ZERO, Vector2.ONE)


func is_valid() -> bool:
	return revision >= 0 and width_m > 0.0 and height_m > 0.0 and world_rect.size.x > 0.0 and world_rect.size.y > 0.0


func to_dictionary() -> Dictionary:
	if not is_valid():
		return {}
	return {
		"schema_version": 1,
		"revision": revision,
		"width_m": width_m,
		"height_m": height_m,
		"world_rect": world_rect,
		"visibility_scope": "public",
	}
