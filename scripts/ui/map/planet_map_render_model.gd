extends RefCounted
class_name SpaceSyndicatePlanetMapRenderModel


func build_from_map_view(map_view: Control) -> Dictionary:
	if map_view == null:
		return _empty_payload()
	var snapshot := _projection_snapshot(map_view)
	var viewport_size: Vector2 = map_view.size
	var center := _call_vector2(map_view, "_globe_center", viewport_size * 0.5)
	var radius := _call_float(map_view, "_globe_radius", maxf(24.0, minf(viewport_size.x, viewport_size.y) * 0.34))
	var globe_blend := float(snapshot.get("globe_blend", 1.0))
	var mode := str(snapshot.get("mode", "globe"))
	var map_size := _as_vector2(snapshot.get("map_size_m", Vector2(1400.0, 950.0)))
	var view_center := _as_vector2(snapshot.get("view_center_m", map_size * 0.5))
	var selected_index := int(map_view.get("selected_district"))
	var districts: Array = map_view.get("districts")
	var selected_position := _selected_position(map_view, selected_index)
	var cutover_enabled := bool(map_view.get("sceneized_visual_cutover_enabled"))
	var legacy_fallback_used := bool(map_view.get("legacy_draw_fallback_used"))
	return {
		"component": "PlanetMapRenderModel",
		"viewport_size": viewport_size,
		"map_size_m": map_size,
		"view_center_m": view_center,
		"view_zoom": float(snapshot.get("view_zoom", 0.0)),
		"target_view_zoom": float(snapshot.get("target_view_zoom", 0.0)),
		"mode": mode,
		"globe_blend": globe_blend,
		"globe_mode": bool(snapshot.get("globe_mode", true)),
		"globe_center": center,
		"globe_radius": radius,
		"district_count": districts.size(),
		"selected_district": selected_index,
		"selected_position": selected_position,
		"selected_visible": selected_position.x >= 0.0 and selected_position.y >= 0.0,
		"focus_target_district": int(snapshot.get("focus_target_district", -1)),
		"focus_beacon_active": bool(snapshot.get("focus_beacon_active", false)),
		"focus_beacon_alpha": float(snapshot.get("focus_beacon_alpha", 0.0)),
		"local_grid_lines": _local_grid_lines(viewport_size, globe_blend),
		"orbit_rings": _orbit_rings(center, radius),
		"scale_hint_text": _scale_hint_text(mode, globe_blend),
		"scale_hint_detail": _scale_hint_detail(cutover_enabled, legacy_fallback_used),
		"sceneized_visual_cutover_enabled": cutover_enabled,
		"legacy_draw_fallback_used": legacy_fallback_used,
		"notes": "Pure UI render payload. Projection values are read from PlanetMapView compatibility methods.",
	}


func remaining_draw_backed_surfaces() -> Array[String]:
	return [
		"legacy_region_fill_fallback",
		"legacy_region_label_fallback",
	]


func _empty_payload() -> Dictionary:
	return {
		"component": "PlanetMapRenderModel",
		"viewport_size": Vector2.ZERO,
		"map_size_m": Vector2.ZERO,
		"view_center_m": Vector2.ZERO,
		"mode": "empty",
		"globe_blend": 1.0,
		"globe_mode": true,
		"globe_center": Vector2.ZERO,
		"globe_radius": 0.0,
		"district_count": 0,
		"selected_district": -1,
		"selected_position": Vector2(-1.0, -1.0),
		"selected_visible": false,
		"focus_target_district": -1,
		"focus_beacon_active": false,
		"focus_beacon_alpha": 0.0,
		"local_grid_lines": [],
		"orbit_rings": [],
		"scale_hint_text": "星球全景 | 滚轮贴近",
		"scale_hint_detail": "sceneized render",
		"sceneized_visual_cutover_enabled": true,
		"legacy_draw_fallback_used": false,
		"notes": "Empty render payload.",
	}


func _scale_hint_text(mode: String, globe_blend: float) -> String:
	if mode == "local" or globe_blend <= 0.001:
		return "局部地表 | 双击看牌架"
	if mode == "transition" or globe_blend < 0.985:
		return "过渡中 | 地表卷成星球"
	return "星球全景 | 滚轮贴近"


func _scale_hint_detail(cutover_enabled: bool, legacy_fallback_used: bool) -> String:
	if legacy_fallback_used:
		return "legacy fallback active"
	if cutover_enabled:
		return "场景化星球渲染已启用"
	return "legacy fallback available"


func _projection_snapshot(map_view: Control) -> Dictionary:
	if map_view != null and map_view.has_method("get_projection_debug_snapshot"):
		var snapshot_variant: Variant = map_view.call("get_projection_debug_snapshot")
		if snapshot_variant is Dictionary:
			return snapshot_variant
	return {}


func _selected_position(map_view: Control, selected_index: int) -> Vector2:
	if selected_index < 0 or map_view == null or not map_view.has_method("get_district_control_position"):
		return Vector2(-1.0, -1.0)
	var value: Variant = map_view.call("get_district_control_position", selected_index)
	return _as_vector2(value)


func _local_grid_lines(viewport_size: Vector2, globe_blend: float) -> Array:
	var result: Array = []
	if viewport_size.x <= 1.0 or viewport_size.y <= 1.0:
		return result
	var alpha := maxf(0.0, 1.0 - globe_blend)
	if alpha <= 0.02:
		return result
	var step := maxf(48.0, minf(viewport_size.x, viewport_size.y) / 7.0)
	var x := step
	while x < viewport_size.x:
		result.append({"from": Vector2(x, 0.0), "to": Vector2(x, viewport_size.y), "alpha": alpha})
		x += step
	var y := step
	while y < viewport_size.y:
		result.append({"from": Vector2(0.0, y), "to": Vector2(viewport_size.x, y), "alpha": alpha})
		y += step
	return result


func _orbit_rings(center: Vector2, radius: float) -> Array:
	if radius <= 1.0:
		return []
	return [
		{"center": center, "radius": radius * 0.38, "alpha": 0.16},
		{"center": center, "radius": radius * 0.64, "alpha": 0.13},
		{"center": center, "radius": radius, "alpha": 0.20},
		{"center": center, "radius": radius * 1.12, "alpha": 0.10},
	]


func _call_vector2(target: Object, method_name: String, fallback: Vector2) -> Vector2:
	if target != null and target.has_method(method_name):
		return _as_vector2(target.call(method_name))
	return fallback


func _call_float(target: Object, method_name: String, fallback: float) -> float:
	if target != null and target.has_method(method_name):
		return float(target.call(method_name))
	return fallback


func _as_vector2(value: Variant) -> Vector2:
	if value is Vector2:
		return value
	if value is Vector2i:
		return Vector2(value)
	if value is Array and value.size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	if value is Dictionary:
		return Vector2(float(value.get("x", 0.0)), float(value.get("y", 0.0)))
	return Vector2.ZERO
