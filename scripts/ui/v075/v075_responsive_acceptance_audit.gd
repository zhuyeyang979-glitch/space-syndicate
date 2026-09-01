extends RefCounted
class_name V075ResponsiveAcceptanceAudit

const INTERSECTION_EPSILON := 0.5


static func audit_control_tree(root: Control) -> Dictionary:
	if not is_instance_valid(root):
		return {
			"schema": "V075ControlTreeGeometryAuditV1",
			"visible_control_count": 0,
			"unintended_overlap_count": 0,
			"outside_surface_count": 1,
			"unreachable_clipped_control_count": 1,
			"rects": {},
		}
	var controls: Array[Control] = []
	_collect_visible_controls(root, root, controls)
	var root_rect := root.get_global_rect()
	var rects := {}
	var outside_count := 0
	var unreachable_count := 0
	for control in controls:
		var rect := control.get_global_rect()
		rects[str(root.get_path_to(control))] = rect
		if root_rect.encloses(rect):
			continue
		outside_count += 1
		if not _has_enabled_scroll_ancestor(control):
			unreachable_count += 1
	var overlap_count := _direct_sibling_overlap_count(root)
	return {
		"schema": "V075ControlTreeGeometryAuditV1",
		"visible_control_count": controls.size(),
		"unintended_overlap_count": overlap_count,
		"outside_surface_count": outside_count,
		"unreachable_clipped_control_count": unreachable_count,
		"surface_rect": root_rect,
		"rects": rects,
	}


static func audit_resource_binding(
	resource_path: String,
	bound_resource: Resource,
	expected_class: String = "Texture2D"
) -> Dictionary:
	var file_exists := FileAccess.file_exists(resource_path)
	var loader_exists := ResourceLoader.exists(resource_path)
	var loaded: Resource = null
	if loader_exists:
		loaded = ResourceLoader.load(resource_path)
	var type_green := (
		loaded != null
		and (expected_class.is_empty() or loaded.is_class(expected_class))
	)
	var binding_green := (
		type_green
		and bound_resource != null
		and bound_resource == loaded
	)
	return {
		"schema": "V075ResourceBindingAuditV1",
		"resource_path": resource_path,
		"file_exists": file_exists,
		"resource_loader_exists": loader_exists,
		"resource_loaded": loaded != null,
		"expected_class": expected_class,
		"resource_type_green": type_green,
		"instance_binding_green": binding_green,
		"failure_count": int(
			not file_exists
			or not loader_exists
			or not type_green
			or not binding_green
		),
	}


static func audit_viewport_dimensions(
	requested_size: Vector2i,
	runtime_size: Vector2i,
	captured_size: Vector2i
) -> Dictionary:
	var runtime_match := runtime_size == requested_size
	var capture_match := captured_size == requested_size
	return {
		"schema": "V075ViewportDimensionAuditV1",
		"requested_size": requested_size,
		"runtime_size": runtime_size,
		"captured_size": captured_size,
		"runtime_match": runtime_match,
		"capture_match": capture_match,
		"mismatch_count": int(not runtime_match) + int(not capture_match),
	}


static func rect_overlap_count(left: Rect2, right: Rect2) -> int:
	var intersection := left.intersection(right)
	return int(
		intersection.size.x > INTERSECTION_EPSILON
		and intersection.size.y > INTERSECTION_EPSILON
	)


static func _collect_visible_controls(
	node: Node,
	root: Control,
	output: Array[Control]
) -> void:
	for child in node.get_children():
		if not (child is Control):
			continue
		var control := child as Control
		if not control.is_visible_in_tree():
			continue
		output.append(control)
		_collect_visible_controls(control, root, output)


static func _direct_sibling_overlap_count(node: Node) -> int:
	var count := 0
	var controls: Array[Control] = []
	for child in node.get_children():
		if child is Control and (child as Control).is_visible_in_tree():
			controls.append(child as Control)
	for left_index in range(controls.size()):
		for right_index in range(left_index + 1, controls.size()):
			count += rect_overlap_count(
				controls[left_index].get_global_rect(),
				controls[right_index].get_global_rect()
			)
	for control in controls:
		count += _direct_sibling_overlap_count(control)
	return count


static func _has_enabled_scroll_ancestor(control: Control) -> bool:
	var cursor := control.get_parent()
	while cursor != null:
		if cursor is ScrollContainer:
			var scroll := cursor as ScrollContainer
			if (
				scroll.horizontal_scroll_mode
					!= ScrollContainer.SCROLL_MODE_DISABLED
				or scroll.vertical_scroll_mode
					!= ScrollContainer.SCROLL_MODE_DISABLED
			):
				return true
		cursor = cursor.get_parent()
	return false
