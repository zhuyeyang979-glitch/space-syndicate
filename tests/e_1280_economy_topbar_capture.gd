extends SceneTree

const MAIN_SCENE_PATH := "res://scenes/main.tscn"
const OUTPUT_DIR := "res://reports/ui/production_acceptance/e_1280_economy_topbar"
const CAPTURE_SIZE := Vector2i(1280, 720)
const QA_GAMEPLAY_SEED := 1280721
const QA_SAVE_PATH := "user://test_runs/e_1280_economy_topbar.save"
const PLAYER_DEFAULT_SAVE_PATH := "user://space_syndicate_current_run.save"
const SAVE_COORDINATOR_NODE_PATH := "RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/GameSessionRuntimeController/GameSaveRuntimeCoordinator"
const RUNTIME_COORDINATOR_NODE_PATH := "RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator"
const CASE_IDS := ["table_idle", "economy_first", "economy_reopened", "economy_active", "economy_dual"]
const MACHINE_MARKERS := [
	"region.", "district_", "weather_", "event_id", "card_id", "unit.",
	"prism_armor", "meteor_sentinel", "oasis_support", "ember_ring", "blue_lancer",
	"mirror_hunter", "private_sentinel", "secret_sentinel", "do_not_expose",
]

var _failures: Array[String] = []
var _case_reports: Dictionary = {}
var _capture_paths: Array[String] = []
var _evidence_phase := "before"
var _player_default_before: Dictionary = {}
var _save_operation_before_tree: Dictionary = {}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_read_arguments()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	_cleanup_output_artifacts()
	_cleanup_qa_save_artifacts()
	_player_default_before = _save_file_snapshot(PLAYER_DEFAULT_SAVE_PATH)
	await _configure_capture_window()

	var packed := load(MAIN_SCENE_PATH) as PackedScene
	if packed == null:
		_fail("production main scene did not load")
		await _finish(null)
		return
	var main := packed.instantiate()
	var save_coordinator := main.get_node_or_null(SAVE_COORDINATOR_NODE_PATH)
	var override_ready := save_coordinator != null \
		and save_coordinator.has_method("set_qa_default_save_path_override") \
		and bool(save_coordinator.call("set_qa_default_save_path_override", QA_SAVE_PATH))
	if not override_ready:
		_fail("isolated QA save override was not installed before Main entered the tree")
		main.free()
		await _finish(null)
		return
	_save_operation_before_tree = save_coordinator.call("operation_snapshot")
	if str(_save_operation_before_tree.get("default_save_path", "")) != QA_SAVE_PATH \
		or not bool(_save_operation_before_tree.get("qa_save_path_override_active", false)):
		_fail("save coordinator did not report the isolated QA path")

	root.add_child(main)
	await _pump_frames(12)
	main.set("configured_player_count", 4)
	main.set("configured_ai_player_count", 3)
	main.set("configured_role_indices", [0, 1, 2, 3, 4])
	main.set("configured_starter_monster_indices", [0, 1, 2, 3])
	var coordinator := main.get_node_or_null(RUNTIME_COORDINATOR_NODE_PATH)
	if coordinator != null and coordinator.has_method("clear_runtime_scenario"):
		coordinator.call("clear_runtime_scenario")
	var runtime_rng := (coordinator as GameRuntimeCoordinator).run_rng_service() if coordinator is GameRuntimeCoordinator else null
	if runtime_rng != null:
		runtime_rng.seed = QA_GAMEPLAY_SEED
	else:
		_fail("production RunRngService was unavailable for deterministic visual evidence")
	main.call("_new_game")
	main.call("_close_menu")
	await _pump_frames(24)
	var target_regions := _first_live_districts(main, 2)
	if target_regions.is_empty():
		_fail("production run had no live district")
	else:
		main.call("_select_district", int(target_regions[0]))
	main.call("_sync_runtime_game_screen", true)
	await _pump_frames(12)
	var map_view := _runtime_map_view(main)
	if map_view != null and map_view.has_method("reset_to_planet_overview"):
		map_view.call("reset_to_planet_overview")
	main.set_process(false)

	await _wait_for_stable_frame(main)
	await _capture_case(main, "table_idle", {"scroll_stage": "closed"})
	if _evidence_phase == "after":
		var wide_probe := await _wide_topbar_probe(main)
		(_case_reports.get("table_idle", {}) as Dictionary)["wide_topbar_probe"] = wide_probe
		if not bool(wide_probe.get("passed", false)):
			_fail("wide TopBar did not restore full public chips: %s" % wide_probe.get("failures", []))
		await _configure_capture_window()
		main.call("_sync_runtime_game_screen", true)
		await _pump_frames(10)

	main.call("_open_economy_overview_menu")
	await _pump_frames(16)
	var first_scroll := _menu_scroll_value(main)
	await _capture_case(main, "economy_first", {
		"scroll_stage": "first_open",
		"scroll_value": first_scroll,
	})

	var detail_expanded_before_deep_scroll := false
	if _evidence_phase == "after":
		var disclosure := main.find_child("MenuBodyDisclosureButton", true, false) as Button
		if disclosure != null and disclosure.is_visible_in_tree():
			disclosure.pressed.emit()
			await _pump_frames(8)
			var body := main.find_child("MenuBodyLabel", true, false) as Label
			detail_expanded_before_deep_scroll = body != null and body.is_visible_in_tree()
		if not detail_expanded_before_deep_scroll:
			_fail("economy detail disclosure did not reveal the retained public summary")
	var maximum_scroll := _menu_scroll_maximum(main)
	var menu_overlay := main.find_child("MenuModalOverlay", true, false)
	if menu_overlay != null and menu_overlay.has_method("set_content_scroll_value"):
		menu_overlay.call("set_content_scroll_value", maximum_scroll)
	else:
		var scroll := main.find_child("MenuContentScroll", true, false) as ScrollContainer
		if scroll != null:
			scroll.scroll_vertical = maximum_scroll
	await _pump_frames(8)
	var forced_scroll := _menu_scroll_value(main)
	main.call("_close_menu")
	await _pump_frames(8)
	main.call("_open_economy_overview_menu")
	await _pump_frames(16)
	var reopened_scroll := _menu_scroll_value(main)
	await _capture_case(main, "economy_reopened", {
		"scroll_stage": "reopened_after_deep_scroll",
		"initial_scroll": first_scroll,
		"maximum_scroll": maximum_scroll,
		"forced_scroll": forced_scroll,
		"scroll_value": reopened_scroll,
		"detail_expanded_before_deep_scroll": detail_expanded_before_deep_scroll,
		"reset_passed": first_scroll <= 1 and maximum_scroll > 0 and forced_scroll > 1 and reopened_scroll <= 1,
	})
	if not (first_scroll <= 1 and maximum_scroll > 0 and forced_scroll > 1 and reopened_scroll <= 1):
		_fail("economy reopen scroll reset failed: %d -> %d/%d -> %d" % [first_scroll, forced_scroll, maximum_scroll, reopened_scroll])

	main.call("_close_menu")
	await _pump_frames(8)
	_prepare_weather_state(main, coordinator, target_regions, false)
	main.call("_sync_runtime_game_screen", true)
	main.call("_open_economy_overview_menu")
	await _pump_frames(16)
	var active_scroll := _menu_scroll_value(main)
	await _capture_case(main, "economy_active", {
		"scroll_stage": "active_weather_open",
		"scroll_value": active_scroll,
		"weather": _weather_snapshot(coordinator),
	})
	if active_scroll > 1:
		_fail("active-weather economy open did not start at the top: %d" % active_scroll)

	main.call("_close_menu")
	await _pump_frames(8)
	_prepare_weather_state(main, coordinator, target_regions, true)
	main.call("_sync_runtime_game_screen", true)
	main.call("_open_economy_overview_menu")
	await _pump_frames(16)
	var dual_scroll := _menu_scroll_value(main)
	await _capture_case(main, "economy_dual", {
		"scroll_stage": "dual_weather_open",
		"scroll_value": dual_scroll,
		"weather": _weather_snapshot(coordinator),
	})
	if dual_scroll > 1:
		_fail("dual-weather economy open did not start at the top: %d" % dual_scroll)

	await _finish(main)


func _capture_case(main: Node, case_id: String, state: Dictionary) -> void:
	await _wait_for_stable_frame(main)
	var scene_snapshot := _scene_snapshot(main, case_id)
	var screenshot := await _save_viewport(_png_name(case_id), scene_snapshot.get("pixel_rects", {}) as Dictionary)
	var pixel_gate := _pixel_integrity_gate(screenshot.get("pixel_metrics", {}) as Dictionary)
	if not bool(pixel_gate.get("passed", false)):
		_fail("%s screenshot pixel integrity failed: %s" % [case_id, pixel_gate.get("failures", [])])
	var machine_ids := _visible_marker_candidates(main, MACHINE_MARKERS)
	if not machine_ids.is_empty():
		_fail("%s exposed machine identifiers: %s" % [case_id, machine_ids])
	var layout_gate := _layout_gate(case_id, scene_snapshot)
	if _evidence_phase == "after" and not bool(layout_gate.get("passed", false)):
		_fail("%s final layout gate failed: %s" % [case_id, layout_gate.get("failures", [])])
	var report := {
		"evidence_phase": _evidence_phase,
		"case": case_id,
		"physical_window_size": _vector2i_data(DisplayServer.window_get_size()),
		"logical_canvas_size": _vector2_data(root.get_visible_rect().size),
		"state": state.duplicate(true),
		"scene_tree": scene_snapshot.get("nodes", {}),
		"layout_gate": layout_gate,
		"capture": screenshot,
		"pixel_integrity_gate": pixel_gate,
		"machine_id_candidates": machine_ids,
		"machine_id_gate_passed": machine_ids.is_empty(),
		"save_operation_before_tree": _save_operation_before_tree.duplicate(true),
	}
	if case_id in ["economy_active", "economy_dual"]:
		var expected_weather_count := 2 if case_id == "economy_dual" else 1
		var weather: Dictionary = state.get("weather", {}) if state.get("weather", {}) is Dictionary else {}
		var weather_passed := int(weather.get("forecast_event_count", 0)) == expected_weather_count \
			and int(weather.get("overlay_region_count", 0)) == expected_weather_count
		report["weather_gate"] = {
			"passed": weather_passed,
			"expected_event_count": expected_weather_count,
			"snapshot": weather,
		}
		if not weather_passed:
			_fail("%s did not expose %d active public weather events" % [case_id, expected_weather_count])
	_case_reports[case_id] = report


func _scene_snapshot(main: Node, case_id: String) -> Dictionary:
	var names := [
		"TopBar", "PhaseLabel", "TurnLabel", "CashChip", "GdpChip", "GoalChip",
		"SelectedDistrictChip", "PrimaryActionChip", "WeatherChip", "MoreChip", "MenuButton",
	]
	if case_id != "table_idle":
		names.append_array([
			"MenuModalOverlay", "MenuSurfacePanel", "MenuContentScroll", "MenuBodyDisclosureButton",
			"MenuBodyLabel", "EconomyDashboardPanel", "EconomyDashboardTitle",
			"EconomyDashboardKpiGrid", "EconomyDashboardOverviewGrid", "EconomyDashboardDecisionRail",
			"EconomyDashboardLaneGrid",
		])
	var nodes := {}
	var pixel_rects := {}
	for node_name in names:
		var control := main.find_child(node_name, true, false) as Control
		nodes[node_name] = _control_snapshot(control)
		if control != null and control.is_visible_in_tree():
			var visible_rect := control.get_global_rect().intersection(root.get_visible_rect())
			if visible_rect.size.x > 1.0 and visible_rect.size.y > 1.0:
				pixel_rects[node_name] = _rect_data(visible_rect)
	return {"nodes": nodes, "pixel_rects": pixel_rects}


func _layout_gate(case_id: String, scene_snapshot: Dictionary) -> Dictionary:
	var nodes: Dictionary = scene_snapshot.get("nodes", {})
	var failures: Array[String] = []
	if DisplayServer.window_get_size() != CAPTURE_SIZE:
		failures.append("physical window is not 1280x720")
	if case_id == "table_idle":
		for node_name in ["TopBar", "PhaseLabel", "TurnLabel", "CashChip", "GdpChip", "GoalChip", "MenuButton"]:
			_require_visible_inside(nodes, node_name, failures)
		if _evidence_phase == "after":
			_require_visible_inside(nodes, "MoreChip", failures)
			var goal_rect := _rect_from_data((nodes.get("GoalChip", {}) as Dictionary).get("rect", {}) as Dictionary)
			if goal_rect.size.x < 140.0:
				failures.append("GoalChip is too narrow to retain the victory target")
			for hidden_name in ["SelectedDistrictChip", "PrimaryActionChip", "WeatherChip"]:
				if bool((nodes.get(hidden_name, {}) as Dictionary).get("visible_in_tree", false)):
					failures.append("%s should move into MoreChip at 1280" % hidden_name)
			var more_tooltip := str((nodes.get("MoreChip", {}) as Dictionary).get("tooltip", ""))
			for marker in ["选区", "下一步", "天气"]:
				if not more_tooltip.contains(marker):
					failures.append("MoreChip tooltip omitted %s" % marker)
	else:
		for node_name in ["MenuModalOverlay", "MenuSurfacePanel", "MenuContentScroll"]:
			_require_visible_inside(nodes, node_name, failures)
		_require_visible_intersection(nodes, "EconomyDashboardPanel", "MenuContentScroll", failures)
		if _evidence_phase == "after":
			for node_name in ["MenuBodyDisclosureButton", "EconomyDashboardKpiGrid", "EconomyDashboardOverviewGrid", "EconomyDashboardDecisionRail"]:
				_require_visible_inside_control(nodes, node_name, "MenuContentScroll", failures)
			_require_visible_inside_control(nodes, "EconomyDashboardTitle", "MenuContentScroll", failures)
			if bool((nodes.get("MenuBodyLabel", {}) as Dictionary).get("visible_in_tree", false)):
				failures.append("full economy summary should default to collapsed")
			var retained_body := str((nodes.get("MenuBodyLabel", {}) as Dictionary).get("text", ""))
			if retained_body.strip_edges() == "":
				failures.append("collapsed economy summary did not retain public detail text")
	return {"passed": failures.is_empty(), "failures": failures}


func _pixel_integrity_gate(metrics: Dictionary) -> Dictionary:
	var failures: Array[String] = []
	var whole: Dictionary = metrics.get("whole", {}) if metrics.get("whole", {}) is Dictionary else {}
	if int(whole.get("sample_count", 0)) <= 0:
		failures.append("whole screenshot had no sampled pixels")
	if float(whole.get("opaque_coverage", 0.0)) < 0.999:
		failures.append("whole screenshot was not opaque")
	if float(whole.get("non_black_coverage", 0.0)) < 0.95:
		failures.append("whole screenshot contained a black/incomplete frame")
	if float(whole.get("mean_luminance", 0.0)) < 0.03:
		failures.append("whole screenshot luminance was implausibly low")
	var node_regions: Dictionary = metrics.get("node_regions", {}) if metrics.get("node_regions", {}) is Dictionary else {}
	for node_name in node_regions:
		var region: Dictionary = node_regions[node_name] if node_regions[node_name] is Dictionary else {}
		if int(region.get("sample_count", 0)) <= 0 or float(region.get("non_black_coverage", 0.0)) < 0.75:
			failures.append("%s pixel region was empty or incomplete" % node_name)
	return {"passed": failures.is_empty(), "failures": failures}


func _require_visible_inside(nodes: Dictionary, node_name: String, failures: Array[String]) -> void:
	var snapshot: Dictionary = nodes.get(node_name, {}) if nodes.get(node_name, {}) is Dictionary else {}
	if not bool(snapshot.get("found", false)):
		failures.append("%s missing" % node_name)
		return
	if not bool(snapshot.get("visible_in_tree", false)):
		failures.append("%s not visible" % node_name)
		return
	var rect := _rect_from_data(snapshot.get("rect", {}) as Dictionary)
	if not _rect_inside_canvas(rect):
		failures.append("%s outside logical canvas: %s" % [node_name, rect])


func _require_visible_inside_control(nodes: Dictionary, node_name: String, parent_name: String, failures: Array[String]) -> void:
	_require_visible_inside(nodes, node_name, failures)
	var snapshot: Dictionary = nodes.get(node_name, {}) if nodes.get(node_name, {}) is Dictionary else {}
	var parent_snapshot: Dictionary = nodes.get(parent_name, {}) if nodes.get(parent_name, {}) is Dictionary else {}
	if not bool(snapshot.get("visible_in_tree", false)) or not bool(parent_snapshot.get("visible_in_tree", false)):
		return
	var rect := _rect_from_data(snapshot.get("rect", {}) as Dictionary)
	var parent_rect := _rect_from_data(parent_snapshot.get("rect", {}) as Dictionary)
	if rect.position.x < parent_rect.position.x - 1.0 or rect.position.y < parent_rect.position.y - 1.0 \
		or rect.end.x > parent_rect.end.x + 1.0 or rect.end.y > parent_rect.end.y + 1.0:
		failures.append("%s is outside first-glance %s clip" % [node_name, parent_name])


func _require_visible_intersection(nodes: Dictionary, node_name: String, parent_name: String, failures: Array[String]) -> void:
	var snapshot: Dictionary = nodes.get(node_name, {}) if nodes.get(node_name, {}) is Dictionary else {}
	var parent_snapshot: Dictionary = nodes.get(parent_name, {}) if nodes.get(parent_name, {}) is Dictionary else {}
	if not bool(snapshot.get("found", false)) or not bool(snapshot.get("visible_in_tree", false)):
		failures.append("%s missing or not visible" % node_name)
		return
	if not bool(parent_snapshot.get("found", false)) or not bool(parent_snapshot.get("visible_in_tree", false)):
		failures.append("%s missing or not visible" % parent_name)
		return
	var rect := _rect_from_data(snapshot.get("rect", {}) as Dictionary)
	var parent_rect := _rect_from_data(parent_snapshot.get("rect", {}) as Dictionary)
	var intersection := rect.intersection(parent_rect)
	if intersection.size.x < minf(120.0, rect.size.x) or intersection.size.y < 80.0:
		failures.append("%s has no meaningful first-glance intersection with %s" % [node_name, parent_name])


func _control_snapshot(control: Control) -> Dictionary:
	if control == null:
		return {"found": false}
	var result := {
		"found": true,
		"name": control.name,
		"path": str(control.get_path()),
		"type": control.get_class(),
		"visible": control.visible,
		"visible_in_tree": control.is_visible_in_tree(),
		"rect": _rect_data(control.get_global_rect()),
		"tooltip": control.tooltip_text,
	}
	if control is Label:
		result["text"] = (control as Label).text
	elif control is Button:
		result["text"] = (control as Button).text
	return result


func _prepare_weather_state(main: Node, coordinator: Node, target_regions: Array[int], dual: bool) -> void:
	if coordinator == null or not coordinator.has_method("weather_runtime_call"):
		_fail("production Weather owner call surface was unavailable")
		return
	coordinator.call("weather_runtime_call", "reset_state")
	if coordinator.has_method("restore_world_effective_seconds"):
		coordinator.call("restore_world_effective_seconds", 0.0)
	if target_regions.is_empty():
		_fail("weather state requires a live region")
		return
	var scheduled := bool(coordinator.call("weather_runtime_call", "schedule_forecast", [
		"ion_storm", int(target_regions[0]), 1, 30.0, 45.0, "economy_visual_acceptance", false,
	]))
	if not scheduled:
		_fail("primary active weather did not schedule")
	if dual:
		if target_regions.size() < 2:
			_fail("dual weather requires two live regions")
			return
		var second_scheduled := bool(coordinator.call("weather_runtime_call", "schedule_forecast", [
			"gravity_tide", int(target_regions[1]), 1, 30.0, 45.0, "economy_visual_acceptance", false,
		]))
		if not second_scheduled:
			_fail("secondary active weather did not schedule")
	var activation_count := 2 if dual else 1
	for activation_index in range(activation_count):
		if not bool(coordinator.call("weather_runtime_call", "activate_forecast")):
			_fail("weather event %d did not activate" % (activation_index + 1))
	main.call("_close_menu")


func _weather_snapshot(coordinator: Node) -> Dictionary:
	var forecast: Dictionary = coordinator.call("weather_forecast_view_model") if coordinator != null and coordinator.has_method("weather_forecast_view_model") else {}
	var overlay: Dictionary = coordinator.call("weather_map_overlay_view_model") if coordinator != null and coordinator.has_method("weather_map_overlay_view_model") else {}
	return {
		"forecast_event_count": (forecast.get("events", []) as Array).size(),
		"overlay_region_count": (overlay.get("regions", []) as Array).size(),
	}


func _wide_topbar_probe(main: Node) -> Dictionary:
	var wide_size := Vector2i(1600, 960)
	root.mode = Window.MODE_WINDOWED
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(wide_size)
	root.size = wide_size
	await _pump_frames(10)
	var failures: Array[String] = []
	if DisplayServer.window_get_size() != wide_size:
		failures.append("physical probe window is not 1600x960")
	var nodes := {}
	for node_name in ["SelectedDistrictChip", "PrimaryActionChip", "WeatherChip", "MoreChip"]:
		var control := main.find_child(node_name, true, false) as Control
		nodes[node_name] = _control_snapshot(control)
	for node_name in ["SelectedDistrictChip", "PrimaryActionChip", "WeatherChip"]:
		if not bool((nodes.get(node_name, {}) as Dictionary).get("visible_in_tree", false)):
			failures.append("%s did not return at 1600" % node_name)
	if bool((nodes.get("MoreChip", {}) as Dictionary).get("visible_in_tree", false)):
		failures.append("MoreChip remained visible at 1600")
	return {
		"passed": failures.is_empty(),
		"physical_window_size": _vector2i_data(DisplayServer.window_get_size()),
		"nodes": nodes,
		"failures": failures,
	}


func _first_live_districts(main: Node, count: int) -> Array[int]:
	var result: Array[int] = []
	var districts_variant: Variant = ((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts
	if not (districts_variant is Array):
		return result
	for index in range((districts_variant as Array).size()):
		var district: Dictionary = (districts_variant as Array)[index] if (districts_variant as Array)[index] is Dictionary else {}
		if not bool(district.get("destroyed", false)):
			result.append(index)
			if result.size() >= count:
				break
	return result


func _runtime_map_view(main: Node) -> Node:
	var runtime_screen := main.find_child("RuntimeGameScreen", true, false)
	return _find_node_with_method(runtime_screen if runtime_screen != null else main, "get_projection_debug_snapshot")


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


func _menu_scroll_value(main: Node) -> int:
	var scroll := main.find_child("MenuContentScroll", true, false) as ScrollContainer
	return scroll.scroll_vertical if scroll != null else -1


func _menu_scroll_maximum(main: Node) -> int:
	var scroll := main.find_child("MenuContentScroll", true, false) as ScrollContainer
	if scroll == null:
		return 0
	var bar := scroll.get_v_scroll_bar()
	return maxi(0, int(round(bar.max_value - bar.page))) if bar != null else 0


func _wait_for_stable_frame(main: Node) -> Dictionary:
	var stable_frames := 0
	var last_signature := ""
	var latest := {}
	for _frame_index in range(120):
		await process_frame
		RenderingServer.force_draw(false)
		latest = _stable_snapshot(main)
		var signature := var_to_str(latest)
		if signature == last_signature:
			stable_frames += 1
		else:
			stable_frames = 1
		last_signature = signature
		if stable_frames >= 8:
			await _pump_frames(3)
			return {"passed": true, "stable_frame_count": stable_frames + 3, "snapshot": latest}
	_fail("production frame did not stabilize")
	return {"passed": false, "stable_frame_count": stable_frames, "snapshot": latest}


func _stable_snapshot(main: Node) -> Dictionary:
	var result := {}
	for node_name in ["TopBar", "MenuModalOverlay", "MenuContentScroll", "EconomyDashboardPanel"]:
		result[node_name] = _control_snapshot(main.find_child(node_name, true, false) as Control)
	return result


func _save_viewport(file_name: String, node_rects: Dictionary) -> Dictionary:
	await process_frame
	RenderingServer.force_draw(false)
	var image := root.get_texture().get_image()
	if image == null or image.is_empty():
		_fail("viewport image was empty for %s" % file_name)
		return {"saved": false}
	if image.get_size() != CAPTURE_SIZE:
		_fail("viewport image size mismatch for %s: %s" % [file_name, image.get_size()])
		return {"saved": false, "pixel_metrics": {}}
	var resource_path := "%s/%s" % [OUTPUT_DIR, file_name]
	var error := image.save_png(resource_path)
	if error != OK:
		_fail("failed to save %s: %s" % [resource_path, error_string(error)])
		return {"saved": false}
	_capture_paths.append(ProjectSettings.globalize_path(resource_path))
	return {
		"saved": true,
		"resource_path": resource_path,
		"sha256": FileAccess.get_sha256(resource_path),
		"pixel_metrics": _image_content_metrics(image, node_rects),
	}


func _image_content_metrics(image: Image, node_rects: Dictionary) -> Dictionary:
	var logical_size := root.get_visible_rect().size
	var scale := Vector2(float(image.get_width()) / logical_size.x, float(image.get_height()) / logical_size.y)
	var node_metrics := {}
	for node_key in node_rects:
		var rect := _rect_from_data(node_rects[node_key] as Dictionary)
		node_metrics[node_key] = _sample_image_region(image, Rect2(rect.position * scale, rect.size * scale))
	return {
		"sample_stride_pixels": 4,
		"canvas_to_pixel_scale": _vector2_data(scale),
		"whole": _sample_image_region(image, Rect2(Vector2.ZERO, Vector2(image.get_size()))),
		"node_regions": node_metrics,
	}


func _sample_image_region(image: Image, requested_rect: Rect2) -> Dictionary:
	var start_x := clampi(int(floor(requested_rect.position.x)), 0, maxi(0, image.get_width() - 1))
	var start_y := clampi(int(floor(requested_rect.position.y)), 0, maxi(0, image.get_height() - 1))
	var end_x := clampi(int(ceil(requested_rect.end.x)), start_x + 1, image.get_width())
	var end_y := clampi(int(ceil(requested_rect.end.y)), start_y + 1, image.get_height())
	var sample_count := 0
	var non_black_count := 0
	var effective_count := 0
	var alpha_count := 0
	var luminance_sum := 0.0
	for y in range(start_y, end_y, 4):
		for x in range(start_x, end_x, 4):
			var color := image.get_pixel(x, y)
			var peak := maxf(color.r, maxf(color.g, color.b))
			var valley := minf(color.r, minf(color.g, color.b))
			var luminance := color.r * 0.2126 + color.g * 0.7152 + color.b * 0.0722
			sample_count += 1
			luminance_sum += luminance
			if color.a > 0.99:
				alpha_count += 1
			if peak > 0.035:
				non_black_count += 1
			if peak - valley > 0.098 or peak > 0.314:
				effective_count += 1
	return {
		"sample_count": sample_count,
		"opaque_coverage": float(alpha_count) / float(sample_count) if sample_count > 0 else 0.0,
		"non_black_coverage": float(non_black_count) / float(sample_count) if sample_count > 0 else 0.0,
		"effective_coverage": float(effective_count) / float(sample_count) if sample_count > 0 else 0.0,
		"mean_luminance": luminance_sum / float(sample_count) if sample_count > 0 else 0.0,
	}


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


func _finish(main: Node) -> void:
	if main != null and is_instance_valid(main):
		main.queue_free()
		await _pump_frames(4)
	_cleanup_qa_save_artifacts()
	var player_default_after := _save_file_snapshot(PLAYER_DEFAULT_SAVE_PATH)
	var save_unchanged := _player_default_before == player_default_after
	if not save_unchanged:
		_fail("player default save metadata or SHA-256 changed")
	var qa_artifacts := _qa_save_artifacts()
	if not qa_artifacts.is_empty():
		_fail("QA save artifacts remain after cleanup: %s" % qa_artifacts)
	for case_id in _case_reports:
		var report: Dictionary = _case_reports[case_id]
		report["save_isolation"] = {
			"qa_save_path": QA_SAVE_PATH,
			"qa_override_active_before_tree": true,
			"qa_artifacts_after_cleanup": qa_artifacts,
			"player_default_save_path": PLAYER_DEFAULT_SAVE_PATH,
			"player_default_before": _player_default_before,
			"player_default_after": player_default_after,
			"player_default_unchanged": save_unchanged,
		}
		report["failures"] = _failures.duplicate()
		_save_json(_json_name(str(case_id)), report)
	var status := "PASS" if _failures.is_empty() else "FAIL"
	print("E_1280_ECONOMY_TOPBAR_CAPTURE|status=%s|phase=%s|cases=%d|failures=%d" % [status, _evidence_phase, _case_reports.size(), _failures.size()])
	if not _failures.is_empty():
		printerr("- %s" % "\n- ".join(_failures))
	quit(0 if _failures.is_empty() else 1)


func _save_json(file_name: String, value: Dictionary) -> void:
	var path := "%s/%s" % [OUTPUT_DIR, file_name]
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_fail("failed to open report path %s" % path)
		return
	file.store_string(JSON.stringify(value, "\t") + "\n")


func _save_file_snapshot(path: String) -> Dictionary:
	var absolute := ProjectSettings.globalize_path(path)
	if not FileAccess.file_exists(absolute):
		return {"exists": false, "size": 0, "modified_time": 0, "sha256": ""}
	return {
		"exists": true,
		"size": FileAccess.get_size(absolute),
		"modified_time": FileAccess.get_modified_time(absolute),
		"sha256": FileAccess.get_sha256(absolute),
	}


func _qa_save_artifacts() -> Array[String]:
	var result: Array[String] = []
	var absolute := ProjectSettings.globalize_path(QA_SAVE_PATH)
	var directory := absolute.get_base_dir()
	var prefix := absolute.get_file().get_basename()
	if not DirAccess.dir_exists_absolute(directory):
		return result
	for file_name in DirAccess.get_files_at(directory):
		if file_name.begins_with(prefix):
			result.append(directory.path_join(file_name))
	return result


func _cleanup_qa_save_artifacts() -> void:
	for path in _qa_save_artifacts():
		DirAccess.remove_absolute(path)


func _cleanup_output_artifacts() -> void:
	var directory := ProjectSettings.globalize_path(OUTPUT_DIR)
	for case_id in CASE_IDS:
		for file_name in [_png_name(case_id), _json_name(case_id)]:
			var path := directory.path_join(file_name)
			if FileAccess.file_exists(path):
				DirAccess.remove_absolute(path)


func _read_arguments() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--evidence-phase="):
			var phase := argument.trim_prefix("--evidence-phase=")
			if phase in ["before", "after"]:
				_evidence_phase = phase
			else:
				_fail("invalid evidence phase: %s" % phase)


func _png_name(case_id: String) -> String:
	return "%s_%s_1280x720.png" % [_evidence_phase, case_id]


func _json_name(case_id: String) -> String:
	return "%s_%s_1280x720_scene_tree.json" % [_evidence_phase, case_id]


func _configure_capture_window() -> void:
	root.mode = Window.MODE_WINDOWED
	root.borderless = false
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
	var screen_index := 1 if DisplayServer.get_screen_count() > 1 else 0
	DisplayServer.window_set_current_screen(screen_index)
	DisplayServer.window_set_position(DisplayServer.screen_get_position(screen_index) + Vector2i(20, 20))
	DisplayServer.window_set_size(CAPTURE_SIZE)
	root.size = CAPTURE_SIZE
	await _pump_frames(6)
	if DisplayServer.window_get_size() != CAPTURE_SIZE or Vector2i(root.get_texture().get_size()) != CAPTURE_SIZE:
		root.mode = Window.MODE_WINDOWED
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(CAPTURE_SIZE)
		root.size = CAPTURE_SIZE
		await _pump_frames(8)


func _pump_frames(count: int) -> void:
	for _index in range(maxi(1, count)):
		await process_frame


func _rect_data(rect: Rect2) -> Dictionary:
	return {"x": snappedf(rect.position.x, 0.01), "y": snappedf(rect.position.y, 0.01), "width": snappedf(rect.size.x, 0.01), "height": snappedf(rect.size.y, 0.01)}


func _rect_from_data(data: Dictionary) -> Rect2:
	return Rect2(float(data.get("x", 0.0)), float(data.get("y", 0.0)), float(data.get("width", 0.0)), float(data.get("height", 0.0)))


func _rect_inside_canvas(rect: Rect2) -> bool:
	var canvas := root.get_visible_rect()
	return rect.position.x >= canvas.position.x - 1.0 and rect.position.y >= canvas.position.y - 1.0 \
		and rect.end.x <= canvas.end.x + 1.0 and rect.end.y <= canvas.end.y + 1.0


func _vector2_data(value: Vector2) -> Dictionary:
	return {"x": snappedf(value.x, 0.01), "y": snappedf(value.y, 0.01)}


func _vector2i_data(value: Vector2i) -> Dictionary:
	return {"x": value.x, "y": value.y}


func _fail(message: String) -> void:
	if not _failures.has(message):
		_failures.append(message)
	push_error("E 1280 economy/topbar capture: %s" % message)
