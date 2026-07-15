extends SceneTree

const MAIN_SCENE_PATH := "res://scenes/main.tscn"
const OUTPUT_DIR := "res://reports/ui/production_acceptance/e_1280_table_readability_v2"
const DEFAULT_CAPTURE_SIZE := Vector2i(1280, 720)
const QA_GAMEPLAY_SEED := 1280720
const QA_SAVE_PATH := "user://test_runs/e_1280_table_readability_v2.save"
const PLAYER_DEFAULT_SAVE_PATH := "user://space_syndicate_current_run.save"
const SAVE_COORDINATOR_NODE_PATH := "RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/GameSessionRuntimeController/GameSaveRuntimeCoordinator"
const RUNTIME_COORDINATOR_NODE_PATH := "RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator"

const MACHINE_MARKERS := [
	"region.", "district_", "weather_", "event_id", "card_id", "unit.",
	"prism_armor", "meteor_sentinel", "oasis_support", "ember_ring", "blue_lancer",
	"mirror_hunter", "private_sentinel", "secret_sentinel", "do_not_expose",
]
const MAP_COMPONENTS := ["PlanetDistrictNode", "PlanetRouteMarker", "PlanetMonsterToken"]

var _infrastructure_failures: Array[String] = []
var _player_default_before: Dictionary = {}
var _capture_resource_path := ""
var _capture_size := DEFAULT_CAPTURE_SIZE
var _evidence_phase := "before"
var _state_id := "clear"
var _check_economy_scroll := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	print("E_1280_CAPTURE_STAGE|start")
	_read_arguments()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	_cleanup_output_artifacts()
	_cleanup_qa_save_artifacts()
	_player_default_before = _save_file_snapshot(PLAYER_DEFAULT_SAVE_PATH)
	_place_capture_window()
	DisplayServer.window_set_size(_capture_size)
	root.size = _capture_size
	print("E_1280_CAPTURE_STAGE|window_ready")

	var packed := load(MAIN_SCENE_PATH) as PackedScene
	if packed == null:
		_fail("production main scene did not load")
		await _finish(null, {})
		return
	print("E_1280_CAPTURE_STAGE|main_loaded")
	var main := packed.instantiate()
	print("E_1280_CAPTURE_STAGE|main_instantiated")
	var save_coordinator := main.get_node_or_null(SAVE_COORDINATOR_NODE_PATH)
	var override_ready := save_coordinator != null \
		and save_coordinator.has_method("set_qa_default_save_path_override") \
		and bool(save_coordinator.call("set_qa_default_save_path_override", QA_SAVE_PATH))
	if not override_ready:
		_fail("isolated QA save override was not installed before Main entered the tree")
		main.free()
		await _finish(null, {})
		return
	var save_operation: Dictionary = save_coordinator.call("operation_snapshot")
	if str(save_operation.get("default_save_path", "")) != QA_SAVE_PATH \
		or not bool(save_operation.get("qa_save_path_override_active", false)):
		_fail("save coordinator did not report the isolated QA path")
	print("E_1280_CAPTURE_STAGE|save_override_ready")

	root.add_child(main)
	print("E_1280_CAPTURE_STAGE|main_in_tree")
	await _pump_frames(12)
	print("E_1280_CAPTURE_STAGE|initial_frames_ready")
	main.set("configured_player_count", 4)
	main.set("configured_ai_player_count", 3)
	main.set("configured_role_indices", [0, 1, 2, 3, 4])
	main.set("configured_starter_monster_indices", [0, 1, 2, 3])
	var coordinator := main.get_node_or_null(RUNTIME_COORDINATOR_NODE_PATH)
	if coordinator != null and coordinator.has_method("clear_runtime_scenario"):
		coordinator.call("clear_runtime_scenario")
	var qa_rng_variant: Variant = main.get("rng")
	if qa_rng_variant is RandomNumberGenerator:
		(qa_rng_variant as RandomNumberGenerator).seed = QA_GAMEPLAY_SEED
	else:
		_fail("production Main RNG was unavailable for deterministic visual evidence")
	print("E_1280_CAPTURE_STAGE|new_game_begin")
	main.call("_new_game")
	print("E_1280_CAPTURE_STAGE|new_game_returned")
	main.call("_close_menu")
	await _pump_frames(24)
	print("E_1280_CAPTURE_STAGE|new_game_frames_ready")
	var target_regions := _first_live_districts(main, 2)
	if target_regions.is_empty():
		_fail("production run had no live district to select")
	else:
		main.call("_select_district", int(target_regions[0]))
	_prepare_weather_state(main, coordinator, target_regions)
	main.call("_sync_runtime_game_screen", true)
	await _pump_frames(12)
	var map_view := _runtime_map_view(main)
	if map_view == null:
		_fail("production PlanetMapView was not found")
	else:
		if map_view.has_method("reset_to_planet_overview"):
			map_view.call("reset_to_planet_overview")
	main.set_process(false)

	print("E_1280_CAPTURE_STAGE|stable_frame_begin")
	var stable_frame := await _wait_for_stable_frame(main)
	print("E_1280_CAPTURE_STAGE|stable_frame_ready|%s" % JSON.stringify(stable_frame))
	var scene_gate := _build_scene_gate(main, map_view)
	var capture := await _save_viewport(
		_capture_file_name(),
		scene_gate.get("required_node_rects", {}) as Dictionary
	)
	var pixel_gate := _pixel_integrity_gate(capture.get("pixel_metrics", {}) as Dictionary)
	var machine_ids := _visible_marker_candidates(main, MACHINE_MARKERS)
	var economy_scroll_gate := await _economy_scroll_reproduction_gate(main) if _check_economy_scroll else {}
	var layout_passed := bool(scene_gate.get("core_table_passed", false)) \
		and bool(scene_gate.get("map_readability_passed", false))
	var report := {
		"evidence_phase": _evidence_phase,
		"state": _state_id,
		"stable_frame": stable_frame,
		"scene_gate": scene_gate,
		"pixel_gate": pixel_gate,
		"machine_id_candidates": machine_ids,
		"machine_id_gate_passed": machine_ids.is_empty(),
		"layout_passed": layout_passed,
		"capture": capture,
		"save_operation_before_tree": save_operation,
		"weather_gate": _weather_state_snapshot(coordinator, main, target_regions),
		"economy_scroll_reproduction_gate": economy_scroll_gate,
	}
	await _finish(main, report)


func _first_live_districts(main: Node, count: int) -> Array[int]:
	var result: Array[int] = []
	var districts_variant: Variant = main.get("districts")
	if not (districts_variant is Array):
		_fail("production district list was unavailable")
		return result
	for index in range((districts_variant as Array).size()):
		var district: Dictionary = (districts_variant as Array)[index] if (districts_variant as Array)[index] is Dictionary else {}
		if not bool(district.get("destroyed", false)):
			result.append(index)
			if result.size() >= count:
				break
	return result


func _prepare_weather_state(main: Node, coordinator: Node, target_regions: Array[int]) -> void:
	if coordinator == null or not coordinator.has_method("weather_runtime_call"):
		_fail("production Weather owner call surface was unavailable")
		return
	coordinator.call("weather_runtime_call", "reset_state")
	if coordinator.has_method("restore_world_effective_seconds"):
		coordinator.call("restore_world_effective_seconds", 0.0)
	if _state_id == "clear":
		return
	if target_regions.is_empty():
		_fail("weather state requires a live region")
		return
	var scheduled := bool(coordinator.call("weather_runtime_call", "schedule_forecast", [
		"ion_storm", int(target_regions[0]), 1, 30.0, 45.0, "visual_acceptance", false,
	]))
	if not scheduled:
		_fail("%s primary weather event did not schedule" % _state_id)
	if _state_id == "dual_active":
		if target_regions.size() < 2:
			_fail("dual_active requires two live regions")
			return
		var second_scheduled := bool(coordinator.call("weather_runtime_call", "schedule_forecast", [
			"gravity_tide", int(target_regions[1]), 1, 30.0, 45.0, "visual_acceptance", false,
		]))
		if not second_scheduled:
			_fail("dual_active secondary weather event did not schedule")
	if _state_id in ["active", "dual_active"]:
		var activation_count := 2 if _state_id == "dual_active" else 1
		for activation_index in range(activation_count):
			if not bool(coordinator.call("weather_runtime_call", "activate_forecast")):
				_fail("%s weather event %d did not activate" % [_state_id, activation_index + 1])
	main.call("_close_menu")


func _weather_state_snapshot(coordinator: Node, main: Node, target_regions: Array[int]) -> Dictionary:
	var forecast: Dictionary = coordinator.call("weather_forecast_view_model") if coordinator != null and coordinator.has_method("weather_forecast_view_model") else {}
	var overlay: Dictionary = coordinator.call("weather_map_overlay_view_model") if coordinator != null and coordinator.has_method("weather_map_overlay_view_model") else {}
	var detail: Dictionary = {}
	if coordinator != null and coordinator.has_method("weather_region_detail_snapshot") and not target_regions.is_empty():
		detail = coordinator.call("weather_region_detail_snapshot", int(target_regions[0]))
	var strip := main.find_child("WeatherForecastStrip", true, false)
	var strip_debug: Dictionary = strip.call("debug_snapshot") if strip != null and strip.has_method("debug_snapshot") else {}
	var expected_count := 0 if _state_id == "clear" else (2 if _state_id == "dual_active" else 1)
	var expected_phase := "" if _state_id == "clear" else ("forecast" if _state_id == "forecast" else "active")
	var forecast_count := (forecast.get("events", []) as Array).size()
	var overlay_count := (overlay.get("regions", []) as Array).size()
	var phase_matches := expected_phase == "" or str(detail.get("phase", "")) == expected_phase
	var strip_count := int(strip_debug.get("event_count", 0))
	return {
		"passed": forecast_count == expected_count and overlay_count == expected_count and strip_count == expected_count and phase_matches,
		"expected_event_count": expected_count,
		"expected_primary_phase": expected_phase,
		"forecast_event_count": forecast_count,
		"overlay_region_count": overlay_count,
		"primary_detail": detail,
		"forecast_strip": strip_debug,
	}


func _runtime_map_view(main: Node) -> Node:
	var runtime_screen := main.find_child("RuntimeGameScreen", true, false)
	return _find_node_with_method(runtime_screen if runtime_screen != null else main, "get_projection_debug_snapshot")


func _economy_scroll_reproduction_gate(main: Node) -> Dictionary:
	main.call("_open_economy_overview_menu")
	await _pump_frames(14)
	var menu_overlay := main.find_child("MenuModalOverlay", true, false)
	var scroll := main.find_child("MenuContentScroll", true, false) as ScrollContainer
	var dashboard := main.find_child("EconomyDashboardPanel", true, false) as Control
	if menu_overlay == null or scroll == null or dashboard == null or not dashboard.is_visible_in_tree():
		return {
			"passed": false,
			"finding_reproduced": false,
			"failure": "economy menu scroll surface was unavailable",
			"no_fix_claimed": true,
		}
	var initial_scroll := scroll.scroll_vertical
	var scroll_bar := scroll.get_v_scroll_bar()
	var maximum_scroll := maxi(0, int(round(scroll_bar.max_value - scroll_bar.page))) if scroll_bar != null else 0
	if menu_overlay.has_method("set_content_scroll_value"):
		menu_overlay.call("set_content_scroll_value", maximum_scroll)
	else:
		scroll.scroll_vertical = maximum_scroll
	await _pump_frames(5)
	var forced_scroll := scroll.scroll_vertical
	main.call("_close_menu")
	await _pump_frames(6)
	main.call("_open_economy_overview_menu")
	await _pump_frames(14)
	var reopened_scroll := scroll.scroll_vertical
	var finding_reproduced := initial_scroll > 1 or reopened_scroll > 1
	var passed := initial_scroll <= 1 and maximum_scroll > 0 and forced_scroll > 1 and reopened_scroll <= 1
	main.call("_close_menu")
	await _pump_frames(6)
	return {
		"passed": passed,
		"finding_reproduced": finding_reproduced,
		"initial_scroll": initial_scroll,
		"maximum_scroll": maximum_scroll,
		"forced_scroll": forced_scroll,
		"reopened_scroll": reopened_scroll,
		"no_fix_claimed": true,
		"sequence": "open_top -> force_bottom -> close -> reopen_top",
	}


func _find_node_with_method(node: Node, method_name: String) -> Node:
	if node == null:
		return null
	if node.has_method(method_name):
		return node
	for child in node.get_children():
		var found := _find_node_with_method(child, method_name)
		if found != null:
			return found
	return null


func _wait_for_stable_frame(main: Node) -> Dictionary:
	var stable_frames := 0
	var last_signature := ""
	var latest := {}
	for _frame_index in range(120):
		await process_frame
		RenderingServer.force_draw(false)
		latest = _core_table_snapshot(main)
		var signature := var_to_str(latest)
		if signature == last_signature:
			stable_frames += 1
		else:
			stable_frames = 1
		last_signature = signature
		if stable_frames >= 8:
			for _settle_index in range(3):
				await process_frame
				RenderingServer.force_draw(false)
			return {"passed": true, "stable_frame_count": stable_frames + 3, "snapshot": latest}
	return {"passed": false, "stable_frame_count": stable_frames, "snapshot": latest}


func _core_table_snapshot(main: Node) -> Dictionary:
	var result := {}
	for node_name in ["TopBar", "PlayerBoard", "HandRack", "PlayerMainActionDock", "RightInspector"]:
		result[node_name] = _control_snapshot(main.find_child(node_name, true, false))
	return result


func _build_scene_gate(main: Node, map_view: Node) -> Dictionary:
	var required_specs := [
		{"key": "TopBar", "node_name": "TopBar", "min_size": Vector2(1180.0, 40.0)},
		{"key": "PlayerBoard", "node_name": "PlayerBoard", "min_size": Vector2(1180.0, 168.0)},
		{"key": "HandRack", "node_name": "HandRack", "min_size": Vector2(300.0, 100.0)},
		{"key": "MainActionDock", "node_name": "PlayerMainActionDock", "min_size": Vector2(240.0, 72.0)},
	]
	var required_nodes := {}
	var required_node_rects := {}
	var core_failures: Array[String] = []
	for spec_variant in required_specs:
		var spec := spec_variant as Dictionary
		var key := str(spec.get("key", "required"))
		var node := main.find_child(str(spec.get("node_name", "")), true, false)
		var snapshot := _control_snapshot(node)
		required_nodes[key] = snapshot
		if node == null or not (node is Control):
			core_failures.append("%s missing" % key)
			continue
		var control := node as Control
		var rect := control.get_global_rect()
		required_node_rects[key] = _rect_data(rect)
		var min_size := spec.get("min_size", Vector2.ZERO) as Vector2
		if not control.is_visible_in_tree():
			core_failures.append("%s not visible in tree" % key)
		if rect.size.x < min_size.x or rect.size.y < min_size.y:
			core_failures.append("%s incomplete rect %s" % [key, rect])
		if not _rect_inside_canvas(rect):
			core_failures.append("%s leaves the stretched logical canvas: %s" % [key, rect])

	var component_nodes := _map_component_snapshots(map_view)
	var overlaps := _map_component_overlaps(component_nodes)
	var hard_overlap_count := 0
	var district_overlap_count := 0
	for overlap_variant in overlaps:
		var overlap := overlap_variant as Dictionary
		if float(overlap.get("smaller_rect_coverage", 0.0)) >= 0.18:
			hard_overlap_count += 1
		if float(overlap.get("smaller_rect_coverage", 0.0)) >= 0.18 \
			and str(overlap.get("first_component", "")) == "PlanetDistrictNode" \
			and str(overlap.get("second_component", "")) == "PlanetDistrictNode":
			district_overlap_count += 1
	var map_failures: Array[String] = []
	if component_nodes.is_empty():
		map_failures.append("no visible sceneized map labels were available")
	if hard_overlap_count > 2:
		map_failures.append("%d label/token pairs cover at least 18%% of the smaller card" % hard_overlap_count)
	if district_overlap_count > 0:
		map_failures.append("%d district-name cards overlap each other" % district_overlap_count)

	var projection: Dictionary = {}
	var sceneization: Dictionary = {}
	if map_view != null:
		if map_view.has_method("get_projection_debug_snapshot"):
			var projection_variant: Variant = map_view.call("get_projection_debug_snapshot")
			projection = projection_variant if projection_variant is Dictionary else {}
		if map_view.has_method("get_sceneization_debug_snapshot"):
			var sceneization_variant: Variant = map_view.call("get_sceneization_debug_snapshot")
			sceneization = sceneization_variant if sceneization_variant is Dictionary else {}
	return {
		"core_table_passed": core_failures.is_empty(),
		"core_table_failures": core_failures,
		"required_nodes": required_nodes,
		"required_node_rects": required_node_rects,
		"map_readability_passed": map_failures.is_empty(),
		"map_readability_failures": map_failures,
		"hard_overlap_pair_count": hard_overlap_count,
		"district_overlap_pair_count": district_overlap_count,
		"all_overlap_pair_count": overlaps.size(),
		"overlap_pairs": overlaps,
		"map_components": component_nodes,
		"projection": projection,
		"sceneization": sceneization,
		"logical_canvas_rect": _rect_data(root.get_visible_rect()),
	}


func _map_component_snapshots(map_view: Node) -> Array[Dictionary]:
	var snapshots: Array[Dictionary] = []
	if map_view == null:
		return snapshots
	_collect_map_component_snapshots(map_view, snapshots)
	return snapshots


func _collect_map_component_snapshots(node: Node, snapshots: Array[Dictionary]) -> void:
	if node is Control:
		var control := node as Control
		var component := str(control.get_meta("mcp_sceneized_component", ""))
		if MAP_COMPONENTS.has(component) and control.is_visible_in_tree():
			var rect := control.get_global_rect()
			snapshots.append({
				"name": str(control.name),
				"path": str(control.get_path()),
				"component": component,
				"rect": _rect_data(rect),
				"inside_logical_canvas": _rect_inside_canvas(rect),
				"debug": control.call("debug_snapshot") if control.has_method("debug_snapshot") else {},
			})
	for child in node.get_children():
		_collect_map_component_snapshots(child, snapshots)


func _map_component_overlaps(snapshots: Array[Dictionary]) -> Array[Dictionary]:
	var overlaps: Array[Dictionary] = []
	for first_index in range(snapshots.size()):
		var first := snapshots[first_index]
		var first_rect := _rect_from_data(first.get("rect", {}) as Dictionary)
		for second_index in range(first_index + 1, snapshots.size()):
			var second := snapshots[second_index]
			var second_rect := _rect_from_data(second.get("rect", {}) as Dictionary)
			var intersection := first_rect.intersection(second_rect)
			var intersection_area := intersection.size.x * intersection.size.y
			if intersection_area <= 1.0:
				continue
			var smaller_area := minf(first_rect.size.x * first_rect.size.y, second_rect.size.x * second_rect.size.y)
			overlaps.append({
				"first": str(first.get("name", "")),
				"first_component": str(first.get("component", "")),
				"second": str(second.get("name", "")),
				"second_component": str(second.get("component", "")),
				"intersection": _rect_data(intersection),
				"intersection_area": snappedf(intersection_area, 0.01),
				"smaller_rect_coverage": snappedf(intersection_area / smaller_area if smaller_area > 0.0 else 0.0, 0.0001),
			})
	return overlaps


func _control_snapshot(node: Node) -> Dictionary:
	if node == null:
		return {"found": false}
	var snapshot := {"found": true, "name": str(node.name), "path": str(node.get_path()), "type": node.get_class()}
	if node is Control:
		var control := node as Control
		snapshot.merge({
			"visible": control.visible,
			"visible_in_tree": control.is_visible_in_tree(),
			"clip_contents": control.clip_contents,
			"rect": _rect_data(control.get_global_rect()),
		})
	return snapshot


func _rect_data(rect: Rect2) -> Dictionary:
	return {
		"x": snappedf(rect.position.x, 0.01),
		"y": snappedf(rect.position.y, 0.01),
		"width": snappedf(rect.size.x, 0.01),
		"height": snappedf(rect.size.y, 0.01),
	}


func _rect_from_data(data: Dictionary) -> Rect2:
	return Rect2(
		float(data.get("x", 0.0)), float(data.get("y", 0.0)),
		float(data.get("width", 0.0)), float(data.get("height", 0.0))
	)


func _rect_inside_canvas(rect: Rect2) -> bool:
	var canvas_rect := root.get_visible_rect()
	return rect.position.x >= canvas_rect.position.x - 1.0 \
		and rect.position.y >= canvas_rect.position.y - 1.0 \
		and rect.end.x <= canvas_rect.end.x + 1.0 \
		and rect.end.y <= canvas_rect.end.y + 1.0


func _visible_marker_candidates(node: Node, markers: Array) -> Array[String]:
	var candidates: Array[String] = []
	_collect_visible_marker_candidates(node, markers, candidates)
	return candidates


func _collect_visible_marker_candidates(node: Node, markers: Array, candidates: Array[String]) -> void:
	if node == null:
		return
	if node is Control and not (node as Control).is_visible_in_tree():
		return
	var texts: Array[String] = []
	if node is Label:
		texts.append((node as Label).text)
	elif node is Button:
		texts.append((node as Button).text)
	if node is Control:
		texts.append((node as Control).tooltip_text)
	for text_variant in texts:
		var normalized := str(text_variant).strip_edges()
		var lower := normalized.to_lower()
		for marker_variant in markers:
			if normalized != "" and lower.contains(str(marker_variant).to_lower()):
				if not candidates.has(normalized):
					candidates.append(normalized)
				break
	for child in node.get_children():
		_collect_visible_marker_candidates(child, markers, candidates)


func _save_viewport(file_name: String, node_rects: Dictionary) -> Dictionary:
	await process_frame
	RenderingServer.force_draw(false)
	var image := root.get_texture().get_image()
	if image == null or image.is_empty():
		_fail("viewport image was empty for %s" % file_name)
		return {"saved": false, "pixel_metrics": {}}
	if image.get_size() != _capture_size:
		_fail("viewport size mismatch for %s: %s" % [file_name, image.get_size()])
		return {"saved": false, "pixel_metrics": {}}
	var pixel_metrics := _image_content_metrics(image, node_rects)
	_capture_resource_path = "%s/%s" % [OUTPUT_DIR, file_name]
	var error := image.save_png(_capture_resource_path)
	if error != OK:
		_fail("failed to save %s: %s" % [_capture_resource_path, error_string(error)])
		return {"saved": false, "pixel_metrics": pixel_metrics}
	print("CAPTURE: %s" % ProjectSettings.globalize_path(_capture_resource_path))
	return {
		"saved": true,
		"resource_path": _capture_resource_path,
		"sha256": FileAccess.get_sha256(_capture_resource_path),
		"pixel_metrics": pixel_metrics,
	}


func _image_content_metrics(image: Image, node_rects: Dictionary) -> Dictionary:
	var node_metrics := {}
	var canvas_size := root.get_visible_rect().size
	var canvas_to_pixel := Vector2(
		float(image.get_width()) / canvas_size.x if canvas_size.x > 0.0 else 1.0,
		float(image.get_height()) / canvas_size.y if canvas_size.y > 0.0 else 1.0
	)
	for node_key in node_rects:
		var canvas_rect := _rect_from_data(node_rects[node_key] as Dictionary)
		var pixel_rect := Rect2(canvas_rect.position * canvas_to_pixel, canvas_rect.size * canvas_to_pixel)
		node_metrics[node_key] = _sample_image_region(image, pixel_rect)
	return {
		"sample_stride_pixels": 4,
		"logical_canvas_size": {"x": canvas_size.x, "y": canvas_size.y},
		"canvas_to_pixel_scale": {"x": canvas_to_pixel.x, "y": canvas_to_pixel.y},
		"whole": _sample_image_region(image, Rect2(Vector2.ZERO, Vector2(image.get_size()))),
		"top": _sample_image_region(image, Rect2(0.0, 0.0, float(image.get_width()), float(image.get_height()) * 0.16)),
		"bottom": _sample_image_region(image, Rect2(0.0, float(image.get_height()) * 0.73, float(image.get_width()), float(image.get_height()) * 0.27)),
		"node_regions": node_metrics,
	}


func _sample_image_region(image: Image, requested_rect: Rect2) -> Dictionary:
	var start_x := clampi(int(floor(requested_rect.position.x)), 0, maxi(0, image.get_width() - 1))
	var start_y := clampi(int(floor(requested_rect.position.y)), 0, maxi(0, image.get_height() - 1))
	var end_x := clampi(int(ceil(requested_rect.end.x)), start_x + 1, image.get_width())
	var end_y := clampi(int(ceil(requested_rect.end.y)), start_y + 1, image.get_height())
	var sample_count := 0
	var non_black_count := 0
	var bright_count := 0
	var effective_count := 0
	var luminance_sum := 0.0
	for y in range(start_y, end_y, 4):
		for x in range(start_x, end_x, 4):
			var color := image.get_pixel(x, y)
			var peak := maxf(color.r, maxf(color.g, color.b))
			var valley := minf(color.r, minf(color.g, color.b))
			var luminance := color.r * 0.2126 + color.g * 0.7152 + color.b * 0.0722
			sample_count += 1
			luminance_sum += luminance
			if peak > 0.035:
				non_black_count += 1
			if peak > 0.19:
				bright_count += 1
			if peak - valley > 0.098 or peak > 0.314:
				effective_count += 1
	return {
		"sample_count": sample_count,
		"non_black_coverage": float(non_black_count) / float(sample_count) if sample_count > 0 else 0.0,
		"bright_coverage": float(bright_count) / float(sample_count) if sample_count > 0 else 0.0,
		"effective_coverage": float(effective_count) / float(sample_count) if sample_count > 0 else 0.0,
		"mean_luminance": luminance_sum / float(sample_count) if sample_count > 0 else 0.0,
		"sampled_rect": {"x": start_x, "y": start_y, "width": end_x - start_x, "height": end_y - start_y},
	}


func _pixel_integrity_gate(metrics: Dictionary) -> Dictionary:
	var failures: Array[String] = []
	var whole := metrics.get("whole", {}) as Dictionary
	if float(whole.get("non_black_coverage", 0.0)) < 0.80:
		failures.append("whole-frame non-black coverage below 80%")
	if float(whole.get("effective_coverage", 0.0)) < 0.18:
		failures.append("whole-frame effective content below 18%")
	for node_key in ["TopBar", "PlayerBoard", "HandRack", "MainActionDock"]:
		var node_metrics := ((metrics.get("node_regions", {}) as Dictionary).get(node_key, {}) as Dictionary)
		if int(node_metrics.get("sample_count", 0)) <= 0:
			failures.append("%s has no sampled screenshot pixels" % node_key)
		elif float(node_metrics.get("non_black_coverage", 0.0)) < 0.65 \
			or float(node_metrics.get("effective_coverage", 0.0)) < 0.02:
			failures.append("%s screenshot pixels are blank or incomplete" % node_key)
	return {"passed": failures.is_empty(), "failure_reasons": failures}


func _finish(main: Node, report: Dictionary) -> void:
	if main != null and is_instance_valid(main):
		root.remove_child(main)
		main.queue_free()
		await _pump_frames(5)
	_cleanup_qa_save_artifacts()
	var player_default_after := _save_file_snapshot(PLAYER_DEFAULT_SAVE_PATH)
	var player_default_unchanged := _player_default_before == player_default_after
	if not player_default_unchanged:
		_fail("player default save metadata or SHA-256 changed")
	var remaining_qa_artifacts := _qa_save_artifacts()
	if not remaining_qa_artifacts.is_empty():
		_fail("isolated QA save artifacts remain after cleanup: %s" % remaining_qa_artifacts)
	report.merge({
		"scene": MAIN_SCENE_PATH,
		"resolution": {"x": _capture_size.x, "y": _capture_size.y},
		"logical_canvas_size": {"x": root.get_visible_rect().size.x, "y": root.get_visible_rect().size.y},
		"save_isolation": {
			"qa_save_path": QA_SAVE_PATH,
			"qa_artifacts_after_cleanup": remaining_qa_artifacts,
			"player_default_save_path": PLAYER_DEFAULT_SAVE_PATH,
			"player_default_before": _player_default_before,
			"player_default_after": player_default_after,
			"player_default_unchanged": player_default_unchanged,
		},
		"infrastructure_failures": _infrastructure_failures,
	}, true)
	var acceptance_passed := bool(report.get("layout_passed", false)) \
		and bool((report.get("pixel_gate", {}) as Dictionary).get("passed", false)) \
		and bool(report.get("machine_id_gate_passed", false)) \
		and bool((report.get("weather_gate", {}) as Dictionary).get("passed", false)) \
		and bool((report.get("stable_frame", {}) as Dictionary).get("passed", false)) \
		and (not _check_economy_scroll or bool((report.get("economy_scroll_reproduction_gate", {}) as Dictionary).get("passed", false))) \
		and player_default_unchanged \
		and remaining_qa_artifacts.is_empty()
	var expected_green := _evidence_phase == "after"
	var expectation_met := acceptance_passed if expected_green else not acceptance_passed
	report["acceptance_passed"] = acceptance_passed
	report["expected_status"] = "GREEN" if expected_green else "RED"
	report["expectation_met"] = expectation_met
	_save_json(_scene_tree_file_name(), report)
	if _infrastructure_failures.is_empty() and expectation_met:
		print("E_1280_TABLE_READABILITY_CAPTURE|status=PASS|phase=%s|state=%s|resolution=%s|layout=%s|expectation_met=true" % [
			_evidence_phase,
			_state_id,
			_resolution_suffix(),
			"GREEN" if acceptance_passed else "RED",
		])
		quit(0)
	else:
		printerr("E_1280_TABLE_READABILITY_CAPTURE|status=FAIL|phase=%s|state=%s|resolution=%s|expectation_met=%s|failures=%d\n- %s" % [
			_evidence_phase,
			_state_id,
			_resolution_suffix(),
			str(expectation_met),
			_infrastructure_failures.size(),
			"\n- ".join(_infrastructure_failures),
		])
		quit(1)


func _save_json(file_name: String, value: Dictionary) -> void:
	var path := "%s/%s" % [OUTPUT_DIR, file_name]
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_fail("failed to open %s" % path)
		return
	file.store_string(JSON.stringify(value, "  "))
	file.close()
	print("SCENE_TREE: %s" % ProjectSettings.globalize_path(path))


func _save_file_snapshot(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"exists": false, "size_bytes": 0, "modified_unix": 0, "sha256": ""}
	var file := FileAccess.open(path, FileAccess.READ)
	var size_bytes := file.get_length() if file != null else -1
	if file != null:
		file.close()
	return {
		"exists": true,
		"size_bytes": size_bytes,
		"modified_unix": FileAccess.get_modified_time(path),
		"sha256": FileAccess.get_sha256(path),
	}


func _qa_save_artifacts() -> Array[String]:
	var artifacts: Array[String] = []
	var directory := DirAccess.open(QA_SAVE_PATH.get_base_dir())
	if directory == null:
		return artifacts
	var prefix := QA_SAVE_PATH.get_file()
	for file_name in directory.get_files():
		if file_name.begins_with(prefix):
			artifacts.append("%s/%s" % [QA_SAVE_PATH.get_base_dir(), file_name])
	return artifacts


func _cleanup_qa_save_artifacts() -> void:
	for path in _qa_save_artifacts():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _cleanup_output_artifacts() -> void:
	var absolute_dir := ProjectSettings.globalize_path(OUTPUT_DIR)
	for file_name in [_capture_file_name(), _scene_tree_file_name()]:
		var path := absolute_dir.path_join(file_name)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


func _read_arguments() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-size="):
			var dimensions := argument.trim_prefix("--capture-size=").split("x", false)
			if dimensions.size() != 2 or not dimensions[0].is_valid_int() or not dimensions[1].is_valid_int():
				_fail("invalid capture size: %s" % argument)
				continue
			_capture_size = Vector2i(maxi(640, int(dimensions[0])), maxi(360, int(dimensions[1])))
		elif argument.begins_with("--evidence-phase="):
			var phase := argument.trim_prefix("--evidence-phase=")
			if phase not in ["before", "after"]:
				_fail("invalid evidence phase: %s" % phase)
			else:
				_evidence_phase = phase
		elif argument.begins_with("--state="):
			var state := argument.trim_prefix("--state=")
			if state not in ["clear", "forecast", "active", "dual_active"]:
				_fail("invalid capture state: %s" % state)
			else:
				_state_id = state
		elif argument == "--check-economy-scroll":
			_check_economy_scroll = true


func _capture_file_name() -> String:
	return "%s_%s_table_%s.png" % [_evidence_phase, _state_id, _resolution_suffix()]


func _scene_tree_file_name() -> String:
	return "%s_%s_%s_scene_tree.json" % [_evidence_phase, _state_id, _resolution_suffix()]


func _resolution_suffix() -> String:
	return "%dx%d" % [_capture_size.x, _capture_size.y]


func _place_capture_window() -> void:
	var screen_index := 1 if DisplayServer.get_screen_count() > 1 else 0
	DisplayServer.window_set_current_screen(screen_index)
	DisplayServer.window_set_position(DisplayServer.screen_get_position(screen_index) + Vector2i(20, 20))


func _pump_frames(count: int) -> void:
	for _index in range(maxi(1, count)):
		await process_frame


func _fail(message: String) -> void:
	_infrastructure_failures.append(message)
	push_error("E 1280 table readability capture: %s" % message)
