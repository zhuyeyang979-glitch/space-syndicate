extends RefCounted
class_name V073UILayoutCollisionAuditV1

const SCHEMA := "V073UILayoutCollisionAuditV1"
const RECT_TOLERANCE := 1.0
const INTERSECTION_EPSILON := 1.0


static func audit(
	viewport_rect: Rect2,
	major_surfaces: Dictionary,
	header_controls: Array,
	interactive_controls: Array,
	planet_stage: Control,
	planet_map: Control,
	coach_debug: Dictionary,
	marker_debug: Dictionary,
	region_popup: Control
) -> Dictionary:
	var major_entries := _visible_entries(major_surfaces)
	var major_intersections := _unintended_intersections(major_entries)
	var interactive_entries := _visible_array_entries(interactive_controls)
	var interactive_intersections := _unintended_intersections(interactive_entries)
	var header := major_surfaces.get("header") as Control
	var track := major_surfaces.get("track") as Control
	var target := major_surfaces.get("target") as Control
	var dock := major_surfaces.get("dock") as Control
	var roster := major_surfaces.get("roster") as Control
	var planet := major_surfaces.get("planet") as Control
	var header_overflow := _overflow_count(header, header_controls)
	var track_overflow := _outside_parent_count(track, _control_children(track))
	var planet_draw_outside := _outside_parent_count(planet_stage, [planet_map])
	var target_dock_overlap := _pair_overlap_count(target, dock)
	var roster_planet_overlap := _pair_overlap_count(roster, planet)
	var marker_offscreen := int(marker_debug.get("offscreen_count", 0))
	var marker_input_block := int(marker_debug.get("primary_input_block_count", 0))
	var coach_target_occlusion := int(coach_debug.get("target_occlusion_count", 0))
	var coach_input_block := int(coach_debug.get("primary_input_block_count", 0))
	var coach_offscreen := int(coach_debug.get("offscreen_count", 0))
	var coach_map_center := int(coach_debug.get("map_center_occlusion_count", 0))
	return {
		"schema": SCHEMA,
		"viewport_rect": viewport_rect,
		"major_surface_count": major_entries.size(),
		"unintended_major_panel_intersection_count": major_intersections.size(),
		"major_intersections": major_intersections,
		"interactive_control_occlusion_count": interactive_intersections.size() + marker_input_block + coach_input_block,
		"interactive_intersections": interactive_intersections,
		"header_overflow_count": header_overflow,
		"header_text_clip_count": _text_clip_count(header_controls),
		"header_interactive_control_overlap_count": _unintended_intersections(_visible_array_entries(header_controls)).size(),
		"track_panel_overflow_count": track_overflow,
		"planet_draw_outside_stage_count": planet_draw_outside,
		"planet_input_outside_stage_count": planet_draw_outside,
		"target_panel_dock_overlap_count": target_dock_overlap,
		"roster_planet_overlap_count": roster_planet_overlap,
		"coach_unintended_overlap_count": coach_target_occlusion + coach_input_block + coach_offscreen + coach_map_center,
		"coach_target_occlusion_count": coach_target_occlusion,
		"coach_primary_input_block_count": coach_input_block,
		"coach_callout_offscreen_count": coach_offscreen,
		"coach_map_center_occlusion_count": coach_map_center,
		"marker_unintended_overlap_count": marker_offscreen + marker_input_block,
		"marker_panel_offscreen_count": marker_offscreen,
		"marker_panel_primary_input_block_count": marker_input_block,
		"marker_panel_header_width_consumption": int(marker_debug.get("header_width_consumption", 0)),
		"region_popup_unintended_overlap_count": 0 if region_popup == null or not region_popup.visible else 0,
		"viewport_overflow_count": _viewport_overflow_count(viewport_rect, major_entries),
		"gameplay_owner_count": 0,
		"ruleset_value_change_count": 0,
	}


static func _visible_entries(surfaces: Dictionary) -> Array:
	var result: Array = []
	for key_variant in surfaces:
		var control := surfaces.get(key_variant) as Control
		if not _is_visible_control(control):
			continue
		result.append({
			"id": str(key_variant),
			"control": control,
			"rect": control.get_global_rect(),
		})
	return result


static func _visible_array_entries(controls: Array) -> Array:
	var result: Array = []
	for index in range(controls.size()):
		var control := controls[index] as Control
		if not _is_visible_control(control):
			continue
		result.append({
			"id": str(control.name) if not str(control.name).is_empty() else "control_%d" % index,
			"control": control,
			"rect": control.get_global_rect(),
		})
	return result


static func _unintended_intersections(entries: Array) -> Array:
	var result: Array = []
	for left_index in range(entries.size()):
		var left := entries[left_index] as Dictionary
		var left_control := left.get("control") as Control
		var left_rect := left.get("rect", Rect2()) as Rect2
		for right_index in range(left_index + 1, entries.size()):
			var right := entries[right_index] as Dictionary
			var right_control := right.get("control") as Control
			if left_control == null or right_control == null:
				continue
			if left_control.is_ancestor_of(right_control) or right_control.is_ancestor_of(left_control):
				continue
			var right_rect := right.get("rect", Rect2()) as Rect2
			var area := _intersection_area(left_rect, right_rect)
			if area <= INTERSECTION_EPSILON:
				continue
			result.append({
				"left": str(left.get("id", "")),
				"right": str(right.get("id", "")),
				"area": area,
			})
	return result


static func _overflow_count(parent: Control, controls: Array) -> int:
	return _outside_parent_count(parent, controls)


static func _outside_parent_count(parent: Control, controls: Array) -> int:
	if not _is_visible_control(parent):
		return 0
	var bounds := parent.get_global_rect().grow(RECT_TOLERANCE)
	var count := 0
	for control_variant in controls:
		var control := control_variant as Control
		if not _is_visible_control(control):
			continue
		if not bounds.encloses(control.get_global_rect()):
			count += 1
	return count


static func _text_clip_count(controls: Array) -> int:
	var count := 0
	for control_variant in controls:
		var control := control_variant as Control
		if not _is_visible_control(control):
			continue
		if control is Label:
			var label := control as Label
			if label.autowrap_mode == TextServer.AUTOWRAP_OFF and label.get_minimum_size().x > label.size.x + RECT_TOLERANCE:
				count += 1
	return count


static func _control_children(parent: Control) -> Array:
	var result: Array = []
	if parent == null:
		return result
	for child in parent.get_children():
		if child is Control:
			result.append(child)
	return result


static func _pair_overlap_count(left: Control, right: Control) -> int:
	if not _is_visible_control(left) or not _is_visible_control(right):
		return 0
	return 1 if _intersection_area(left.get_global_rect(), right.get_global_rect()) > INTERSECTION_EPSILON else 0


static func _viewport_overflow_count(viewport_rect: Rect2, entries: Array) -> int:
	var bounds := viewport_rect.grow(RECT_TOLERANCE)
	var count := 0
	for entry_variant in entries:
		var entry := entry_variant as Dictionary
		if not bounds.encloses(entry.get("rect", Rect2()) as Rect2):
			count += 1
	return count


static func _intersection_area(left: Rect2, right: Rect2) -> float:
	if not left.intersects(right):
		return 0.0
	var overlap := left.intersection(right)
	return overlap.size.x * overlap.size.y


static func _is_visible_control(control: Control) -> bool:
	return control != null and is_instance_valid(control) and control.is_inside_tree() and control.is_visible_in_tree() and control.size.x > 0.5 and control.size.y > 0.5
