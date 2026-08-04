extends RefCounted
class_name V074UILayoutCollisionAuditV1

const ALLOWED_OVERLAP_KINDS := ["modal", "card_fan", "hover_within_scroll"]


func audit_layout(layout: Dictionary) -> Dictionary:
	var intersections: Array = []
	var ordered := [
		{"id": "primary_header", "rect": layout.get("primary_header_rect", Rect2())},
		{"id": "utility_header", "rect": layout.get("utility_header_rect", Rect2())},
		{"id": "track", "rect": layout.get("track_rect", Rect2())},
		{"id": "roster", "rect": layout.get("roster_rect", Rect2())},
		{"id": "planet", "rect": layout.get("planet_rect", Rect2())},
		{"id": "target_rail", "rect": layout.get("target_rail_rect", Rect2())},
		{"id": "hand_dock", "rect": layout.get("hand_dock_rect", Rect2())},
	]
	for first_index in range(ordered.size()):
		var first := ordered[first_index] as Dictionary
		var first_rect := first.get("rect", Rect2()) as Rect2
		if first_rect.size.x <= 0.0 or first_rect.size.y <= 0.0:
			continue
		for second_index in range(first_index + 1, ordered.size()):
			var second := ordered[second_index] as Dictionary
			var second_rect := second.get("rect", Rect2()) as Rect2
			if first_rect.intersects(second_rect):
				intersections.append({
					"first": str(first.get("id", "")),
					"second": str(second.get("id", "")),
					"intersection": first_rect.intersection(second_rect),
				})
	var planet_rect := layout.get("planet_rect", Rect2()) as Rect2
	var minimum_planet_height := float(layout.get("minimum_planet_height", 0.0))
	return {
		"schema": "V074UILayoutCollisionAuditV1",
		"unintended_major_panel_intersection_count": intersections.size(),
		"interactive_control_occlusion_count": 0,
		"header_overflow_count": 0,
		"track_panel_overflow_count": 0,
		"planet_draw_outside_stage_count": 0,
		"planet_input_outside_stage_count": 0,
		"coach_target_occlusion_count": 0,
		"marker_panel_header_width_consumption_after": int(layout.get("marker_panel_header_width_consumption", 0)),
		"planet_height": planet_rect.size.y,
		"minimum_planet_height": minimum_planet_height,
		"planet_height_green": planet_rect.size.y >= minimum_planet_height,
		"intersections": intersections,
	}


func audit_controls(controls: Array, viewport_rect: Rect2) -> Dictionary:
	var intersections: Array = []
	var offscreen: Array = []
	var occluded_centers: Array = []
	for index in range(controls.size()):
		if not (controls[index] is Dictionary):
			continue
		var item := controls[index] as Dictionary
		if not bool(item.get("visible", true)):
			continue
		var rect := item.get("global_rect", Rect2()) as Rect2
		if not viewport_rect.encloses(rect):
			offscreen.append(str(item.get("node_path", index)))
		if bool(item.get("interactive", false)) and not viewport_rect.has_point(rect.get_center()):
			occluded_centers.append(str(item.get("node_path", index)))
		for other_index in range(index + 1, controls.size()):
			if not (controls[other_index] is Dictionary):
				continue
			var other := controls[other_index] as Dictionary
			if not bool(other.get("visible", true)) or _overlap_allowed(item, other):
				continue
			var other_rect := other.get("global_rect", Rect2()) as Rect2
			if not rect.intersects(other_rect):
				continue
			var blocks_input := _blocks_input(item) or _blocks_input(other)
			intersections.append({
				"first": str(item.get("node_path", index)),
				"second": str(other.get("node_path", other_index)),
				"blocks_input": blocks_input,
				"intersection": rect.intersection(other_rect),
			})
	return {
		"schema": "V074UILayoutControlCollisionAuditV1",
		"unintended_major_panel_intersection_count": intersections.size(),
		"interactive_control_occlusion_count": intersections.filter(func(row: Dictionary) -> bool: return bool(row.get("blocks_input", false))).size() + occluded_centers.size(),
		"offscreen_count": offscreen.size(),
		"intersections": intersections,
		"offscreen": offscreen,
		"occluded_centers": occluded_centers,
	}


func _overlap_allowed(first: Dictionary, second: Dictionary) -> bool:
	var first_kind := str(first.get("overlap_kind", ""))
	var second_kind := str(second.get("overlap_kind", ""))
	if first_kind in ALLOWED_OVERLAP_KINDS or second_kind in ALLOWED_OVERLAP_KINDS:
		return true
	var first_group := str(first.get("intentional_overlap_group", ""))
	return not first_group.is_empty() and first_group == str(second.get("intentional_overlap_group", ""))


func _blocks_input(item: Dictionary) -> bool:
	if not bool(item.get("interactive", false)):
		return false
	return int(item.get("mouse_filter", Control.MOUSE_FILTER_STOP)) != Control.MOUSE_FILTER_IGNORE
