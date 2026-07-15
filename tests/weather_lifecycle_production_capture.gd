extends SceneTree

const MAIN_SCENE_PATH := "res://scenes/main.tscn"
const OUTPUT_DIR := "res://reports/ui/production_acceptance/e_weather_lifecycle"
const CAPTURE_SIZE := Vector2i(1600, 960)
const QA_SAVE_PATH := "user://test_runs/e_weather_lifecycle_production_capture.save"
const PLAYER_DEFAULT_SAVE_PATH := "user://space_syndicate_current_run.save"
const SAVE_COORDINATOR_NODE_PATH := "RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/GameSessionRuntimeController/GameSaveRuntimeCoordinator"
const RUNTIME_COORDINATOR_NODE_PATH := "RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator"
const CITY_FIXTURES := preload("res://tests/helpers/city_world_fixture_factory.gd")

const STATE_CASES := [
	{"id": "forecast", "definition_id": "ion_storm", "phase": "forecast"},
	{"id": "active", "definition_id": "spore_season", "phase": "active"},
	{"id": "fading", "definition_id": "spore_season", "phase": "fading"},
	{"id": "dual_active", "definition_id": "ion_storm", "second_definition_id": "gravity_tide", "phase": "active"},
]

const MACHINE_MARKERS := [
	"region.", "district_", "weather_", "event_id", "card_id", "unit.",
	"prism_armor", "meteor_sentinel", "oasis_support", "ember_ring", "blue_lancer",
	"mirror_hunter", "private_sentinel", "secret_sentinel", "do_not_expose",
]
const QA_MARKERS := ["test_runs", "qa_save", "fixture_source", "e_weather_lifecycle"]

var _failures: Array[String] = []
var _checks := 0
var _capture_paths: Array[String] = []
var _table_pixel_metrics_by_case: Dictionary = {}
var _state_reports: Array[Dictionary] = []
var _player_default_before: Dictionary = {}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	_cleanup_output_artifacts()
	_cleanup_qa_save_artifacts()
	_player_default_before = _save_file_snapshot(PLAYER_DEFAULT_SAVE_PATH)
	_place_capture_window()
	DisplayServer.window_set_size(CAPTURE_SIZE)
	root.size = CAPTURE_SIZE

	var packed := load(MAIN_SCENE_PATH) as PackedScene
	if packed == null:
		_fail("production main scene did not load")
		await _finish(null, {})
		return
	var main := packed.instantiate()
	var save_coordinator := main.get_node_or_null(SAVE_COORDINATOR_NODE_PATH)
	var override_ready := save_coordinator != null \
		and save_coordinator.has_method("set_qa_default_save_path_override") \
		and bool(save_coordinator.call("set_qa_default_save_path_override", QA_SAVE_PATH))
	_expect(override_ready, "isolated QA save override installs before Main enters the tree")
	if not override_ready:
		main.free()
		await _finish(null, {})
		return
	var save_operation: Dictionary = save_coordinator.call("operation_snapshot")
	_expect(str(save_operation.get("default_save_path", "")) == QA_SAVE_PATH, "save coordinator reports the isolated path")
	_expect(bool(save_operation.get("qa_save_path_override_active", false)), "save coordinator reports the QA override active")

	root.add_child(main)
	await _pump_frames(12)
	main.set("configured_player_count", 4)
	main.set("configured_ai_player_count", 3)
	main.set("configured_role_indices", [0, 1, 2, 3, 4])
	main.set("configured_starter_monster_indices", [0, 1, 2, 3])
	var coordinator := main.get_node_or_null(RUNTIME_COORDINATOR_NODE_PATH)
	if coordinator != null and coordinator.has_method("clear_runtime_scenario"):
		coordinator.call("clear_runtime_scenario")
	main.call("_new_game")
	main.call("_close_menu")
	await _pump_frames(24)
	main.set_process(false)

	_expect(coordinator != null, "production GameRuntimeCoordinator is present")
	_expect(coordinator != null and coordinator.has_method("weather_runtime_call"), "Coordinator exposes the Weather owner call surface")
	_expect(coordinator != null and coordinator.has_method("weather_forecast_view_model"), "Coordinator exposes public Weather presentation")
	var map_view := _runtime_map_view(main)
	_expect(map_view != null, "production PlanetMapView is present")
	var target_regions := _prepare_visible_world(main)
	_expect(target_regions.size() == 2, "two live regions are available for deterministic concurrent weather")

	if coordinator != null and map_view != null and target_regions.size() == 2:
		for case_variant in STATE_CASES:
			await _capture_case(main, coordinator, map_view, case_variant as Dictionary, target_regions)

	await _finish(main, {
		"save_operation_before_tree": save_operation,
		"target_regions": target_regions,
		"state_reports": _state_reports,
	})


func _prepare_visible_world(main: Node) -> Array[int]:
	var districts_variant: Variant = main.get("districts")
	if not (districts_variant is Array):
		_fail("production district list is unavailable")
		return []
	var districts := districts_variant as Array
	var city_region := -1
	for index in range(districts.size()):
		var district: Dictionary = districts[index] if districts[index] is Dictionary else {}
		if str(district.get("terrain", "")) == "land" and not bool(district.get("destroyed", false)) and (district.get("city", {}) as Dictionary).is_empty():
			city_region = index
			break
	if city_region < 0:
		_fail("no buildable production land region is available for a real city marker")
		return []
	var city_receipt := CITY_FIXTURES.create_city(main, 0, city_region, "weather visual acceptance", "production")
	_expect(bool(city_receipt.get("created", false)), "Coordinator city-development settlement creates a real city marker for occlusion review")
	if not bool(city_receipt.get("created", false)):
		_fail("city fixture receipt: %s" % JSON.stringify(city_receipt))
	var second_region := -1
	districts = main.get("districts") as Array
	for index in range(districts.size()):
		var district: Dictionary = districts[index] if districts[index] is Dictionary else {}
		if index != city_region and not bool(district.get("destroyed", false)):
			second_region = index
			break
	if second_region < 0:
		_fail("no second live region is available")
		return []
	main.call("_select_district", city_region)
	main.call("_sync_runtime_game_screen", true)
	return [city_region, second_region]


func _capture_case(main: Node, coordinator: Node, map_view: Node, case_data: Dictionary, target_regions: Array[int]) -> void:
	var case_id := str(case_data.get("id", "invalid"))
	var primary_region := target_regions[0]
	var second_region := target_regions[1]
	coordinator.call("weather_runtime_call", "reset_state")
	coordinator.call("restore_world_effective_seconds", 0.0)
	var scheduled := bool(coordinator.call("weather_runtime_call", "schedule_forecast", [
		str(case_data.get("definition_id", "ion_storm")), primary_region, 1, 30.0, 45.0, "visual_acceptance", false,
	]))
	_expect(scheduled, "%s schedules the primary event through Weather owner" % case_id)
	if case_data.has("second_definition_id"):
		var second_scheduled := bool(coordinator.call("weather_runtime_call", "schedule_forecast", [
			str(case_data.get("second_definition_id", "gravity_tide")), second_region, 1, 30.0, 45.0, "visual_acceptance", false,
		]))
		_expect(second_scheduled, "%s schedules the second-region event through Weather owner" % case_id)
	var expected_phase := str(case_data.get("phase", ""))
	if expected_phase in ["active", "fading"]:
		var activation_count := 2 if case_data.has("second_definition_id") else 1
		for activation_index in range(activation_count):
			var activated := bool(coordinator.call("weather_runtime_call", "activate_forecast"))
			_expect(activated, "%s activates event %d through Weather owner" % [case_id, activation_index + 1])
	if expected_phase == "fading":
		var active_projection: Dictionary = coordinator.call("weather_runtime_public_projection")
		var active_events := active_projection.get("events", []) as Array
		var active_boundary_us := int((active_events[0] as Dictionary).get("boundary_world_us", 0)) if not active_events.is_empty() else 0
		_expect(active_boundary_us > 0, "%s public Weather projection exposes the active-to-fading boundary" % case_id)
		coordinator.call("restore_world_effective_seconds", float(active_boundary_us) / 1_000_000.0)
		coordinator.call("weather_runtime_call", "tick", [0.0])

	main.call("_select_district", primary_region)
	main.call("_close_menu")
	main.call("_sync_runtime_game_screen", true)
	if map_view.has_method("reset_to_planet_overview"):
		map_view.call("reset_to_planet_overview")
	var table_scene_gate := await _wait_for_complete_table_frame(main, case_id)
	_expect(bool(table_scene_gate.get("passed", false)), "%s table reaches a stable complete production frame" % case_id)

	var forecast: Dictionary = coordinator.call("weather_forecast_view_model")
	var overlay: Dictionary = coordinator.call("weather_map_overlay_view_model")
	var detail: Dictionary = coordinator.call("weather_region_detail_snapshot", primary_region)
	var expected_count := 2 if case_data.has("second_definition_id") else 1
	_expect(str(detail.get("phase", "")) == expected_phase, "%s region detail reports phase %s" % [case_id, expected_phase])
	_expect(int(detail.get("remaining_us", 0)) > 0, "%s region detail reports remaining time" % case_id)
	_expect((detail.get("effects", []) as Array).size() == 3, "%s region detail exposes exactly the first three public effects" % case_id)
	_expect(not str(detail.get("exploitation_hint", "")).is_empty(), "%s region detail exposes exploitation guidance" % case_id)
	_expect(not str(detail.get("counterplay_hint", "")).is_empty(), "%s region detail exposes counterplay guidance" % case_id)
	_expect((forecast.get("events", []) as Array).size() == expected_count, "%s public forecast contains %d event(s)" % [case_id, expected_count])
	_expect((overlay.get("regions", []) as Array).size() == expected_count, "%s public overlay contains %d affected region(s)" % [case_id, expected_count])

	var district_detail := _district_detail_text(main)
	var phase_label := str({"forecast": "预报中", "active": "生效中", "fading": "正在消退"}.get(expected_phase, expected_phase))
	_expect(district_detail.contains(phase_label) and district_detail.contains("剩余"), "%s visible region detail shows phase and remaining time" % case_id)
	var effect_hits := 0
	for effect_variant in detail.get("effects", []):
		var effect := effect_variant as Dictionary
		if district_detail.contains(str(effect.get("label", ""))) and district_detail.contains(str(effect.get("value_text", ""))):
			effect_hits += 1
	_expect(effect_hits == 3, "%s visible region detail shows all three public effects" % case_id)
	_expect(district_detail.contains("利用：") and district_detail.contains(str(detail.get("exploitation_hint", ""))), "%s visible region detail shows exploitation guidance" % case_id)
	_expect(district_detail.contains("应对：") and district_detail.contains(str(detail.get("counterplay_hint", ""))), "%s visible region detail shows counterplay guidance" % case_id)

	var sceneization: Dictionary = map_view.call("get_sceneization_debug_snapshot") if map_view.has_method("get_sceneization_debug_snapshot") else {}
	var layer_gate := _layer_gate(map_view, sceneization)
	_expect(bool(layer_gate.get("passed", false)), "%s weather overlay stays below boundaries/cities/routes/monsters with real visible objects" % case_id)
	var table_machine_ids := _visible_marker_candidates(main, MACHINE_MARKERS)
	var table_qa_residue := _visible_marker_candidates(main, QA_MARKERS)
	_expect(table_machine_ids.is_empty(), "%s production table exposes no machine identifiers" % case_id)
	_expect(table_qa_residue.is_empty(), "%s production table exposes no QA residue" % case_id)
	var table_file := "e_weather_%s_table_1600x960.png" % case_id
	var table_capture := await _save_viewport(table_file, table_scene_gate.get("node_rects", {}) as Dictionary)
	var table_pixel_metrics := table_capture.get("pixel_metrics", {}) as Dictionary
	_table_pixel_metrics_by_case[case_id] = table_pixel_metrics.duplicate(true)
	var table_pixel_gate := _table_pixel_integrity_gate(case_id, table_pixel_metrics)
	_expect(bool(table_pixel_gate.get("passed", false)), "%s screenshot contains a complete non-black production table frame" % case_id)

	var economy_snapshot: Dictionary = main.call("_economy_dashboard_public_snapshot")
	var economy_summary := str(economy_snapshot.get("summary_text", ""))
	var primary_name := str(detail.get("display_name", ""))
	_expect(economy_summary.contains("经济天气:") and economy_summary.contains(primary_name), "%s economy overview names the public weather reason" % case_id)
	main.call("_open_economy_overview_menu")
	await _pump_frames(14)
	var economy_panel := main.find_child("EconomyDashboardPanel", true, false) as Control
	_expect(economy_panel != null and economy_panel.is_visible_in_tree(), "%s economy dashboard is visible" % case_id)
	var economy_visible_text := _visible_text(economy_panel)
	_expect(economy_visible_text.contains(primary_name), "%s visible economy dashboard carries the weather name" % case_id)
	var economy_machine_ids := _visible_marker_candidates(main, MACHINE_MARKERS)
	var economy_qa_residue := _visible_marker_candidates(main, QA_MARKERS)
	_expect(economy_machine_ids.is_empty(), "%s economy overview exposes no machine identifiers" % case_id)
	_expect(economy_qa_residue.is_empty(), "%s economy overview exposes no QA residue" % case_id)
	var economy_file := "e_weather_%s_economy_1600x960.png" % case_id
	var economy_capture := await _save_viewport(economy_file)

	var strip := main.find_child("WeatherForecastStrip", true, false)
	var state_report := {
		"case_id": case_id,
		"resolution": {"x": CAPTURE_SIZE.x, "y": CAPTURE_SIZE.y},
		"scene": MAIN_SCENE_PATH,
		"renderer": DisplayServer.get_name(),
		"table_screenshot": table_file,
		"economy_screenshot": economy_file,
		"table_scene_integrity_gate": table_scene_gate,
		"table_pixel_integrity_gate": table_pixel_gate,
		"table_pixel_metrics": table_pixel_metrics,
		"economy_pixel_metrics": economy_capture.get("pixel_metrics", {}),
		"forecast": forecast,
		"overlay": overlay,
		"region_detail": detail,
		"district_detail_visible_text": district_detail,
		"forecast_strip_debug": strip.call("debug_snapshot") if strip != null and strip.has_method("debug_snapshot") else {},
		"map_sceneization": sceneization,
		"layer_gate": layer_gate,
		"economy_summary_text": economy_summary,
		"economy_visible_text": economy_visible_text,
		"visible_machine_id_candidates": {"table": table_machine_ids, "economy": economy_machine_ids},
		"visible_qa_residue_candidates": {"table": table_qa_residue, "economy": economy_qa_residue},
		"required_nodes_at_table_capture": table_scene_gate.get("required_nodes", {}),
		"economy_nodes_at_economy_capture": _economy_node_snapshots(main),
	}
	_state_reports.append(state_report)
	_save_json("e_weather_%s_1600x960_scene_tree.json" % case_id, state_report)
	main.call("_close_menu")
	await _pump_frames(6)


func _wait_for_complete_table_frame(main: Node, case_id: String) -> Dictionary:
	var stable_frames := 0
	var last_signature := ""
	var latest_gate: Dictionary = {}
	for _frame_index in range(120):
		await process_frame
		await RenderingServer.frame_post_draw
		latest_gate = _table_scene_integrity(main)
		var signature := var_to_str(latest_gate.get("required_nodes", {}))
		if bool(latest_gate.get("passed", false)) and signature == last_signature:
			stable_frames += 1
		elif bool(latest_gate.get("passed", false)):
			stable_frames = 1
		else:
			stable_frames = 0
		last_signature = signature
		if stable_frames >= 8:
			for _settle_index in range(3):
				await process_frame
				await RenderingServer.frame_post_draw
			latest_gate = _table_scene_integrity(main)
			latest_gate["stable_frame_count"] = stable_frames + 3
			latest_gate["case_id"] = case_id
			return latest_gate
	latest_gate["passed"] = false
	latest_gate["stable_frame_count"] = stable_frames
	latest_gate["case_id"] = case_id
	var reasons := latest_gate.get("failure_reasons", []) as Array
	reasons.append("complete table frame did not remain stable for 8 post-draw frames")
	latest_gate["failure_reasons"] = reasons
	return latest_gate


func _table_scene_integrity(main: Node) -> Dictionary:
	var required_specs := [
		{"key": "TopBar", "node_name": "TopBar", "min_size": Vector2(1500.0, 48.0)},
		{"key": "LeftCardShelf", "node_name": "PlanetLeftSpaceRail", "min_size": Vector2(200.0, 220.0)},
		{"key": "RightInspector", "node_name": "RightInspector", "min_size": Vector2(280.0, 580.0)},
		{"key": "PlayerBoard", "node_name": "PlayerBoard", "min_size": Vector2(1500.0, 185.0)},
		{"key": "HandRack", "node_name": "HandRack", "min_size": Vector2(900.0, 120.0)},
		{"key": "BidBoard", "node_name": "PlayerBidBoard", "min_size": Vector2(250.0, 44.0)},
	]
	var required_nodes := {}
	var node_rects := {}
	var failure_reasons: Array[String] = []
	for spec_variant in required_specs:
		var spec := spec_variant as Dictionary
		var key := str(spec.get("key", "required"))
		var node := main.find_child(str(spec.get("node_name", "")), true, false)
		var snapshot := _control_snapshot(node)
		required_nodes[key] = snapshot
		if node == null or not (node is Control):
			failure_reasons.append("%s missing" % key)
			continue
		var control := node as Control
		var rect := control.get_global_rect()
		var min_size := spec.get("min_size", Vector2.ZERO) as Vector2
		node_rects[key] = {
			"x": rect.position.x,
			"y": rect.position.y,
			"width": rect.size.x,
			"height": rect.size.y,
		}
		if not control.is_visible_in_tree():
			failure_reasons.append("%s not visible in tree" % key)
		if rect.size.x < min_size.x or rect.size.y < min_size.y:
			failure_reasons.append("%s incomplete rect %s" % [key, rect])
		if not _rect_inside_capture(rect):
			failure_reasons.append("%s leaves the 1600x960 viewport: %s" % [key, rect])
	var menu_overlay := main.find_child("MenuModalOverlay", true, false) as Control
	var menu_hidden := menu_overlay == null or not menu_overlay.is_visible_in_tree()
	if not menu_hidden:
		failure_reasons.append("MenuModalOverlay is still covering the production table")
	return {
		"passed": failure_reasons.is_empty(),
		"failure_reasons": failure_reasons,
		"menu_overlay_hidden": menu_hidden,
		"required_nodes": required_nodes,
		"node_rects": node_rects,
	}


func _rect_inside_capture(rect: Rect2) -> bool:
	return rect.position.x >= -1.0 and rect.position.y >= -1.0 \
		and rect.end.x <= float(CAPTURE_SIZE.x) + 1.0 \
		and rect.end.y <= float(CAPTURE_SIZE.y) + 1.0


func _table_pixel_integrity_gate(case_id: String, metrics: Dictionary) -> Dictionary:
	var failure_reasons: Array[String] = []
	var whole := metrics.get("whole", {}) as Dictionary
	if float(whole.get("non_black_coverage", 0.0)) < 0.80:
		failure_reasons.append("whole-frame non-black coverage below 80%")
	if float(whole.get("bright_coverage", 0.0)) < 0.12:
		failure_reasons.append("whole-frame bright coverage below 12%")
	if float(whole.get("effective_coverage", 0.0)) < 0.18:
		failure_reasons.append("whole-frame effective content below 18%")
	var node_regions := metrics.get("node_regions", {}) as Dictionary
	for node_key in ["TopBar", "LeftCardShelf", "RightInspector", "PlayerBoard", "HandRack", "BidBoard"]:
		var node_metrics := node_regions.get(node_key, {}) as Dictionary
		if int(node_metrics.get("sample_count", 0)) <= 0:
			failure_reasons.append("%s has no sampled screenshot pixels" % node_key)
		elif float(node_metrics.get("non_black_coverage", 0.0)) < 0.65 or float(node_metrics.get("effective_coverage", 0.0)) < 0.02:
			failure_reasons.append("%s screenshot pixels are blank or materially incomplete" % node_key)
	var comparisons := {}
	if case_id == "dual_active":
		for reference_case in ["forecast", "active"]:
			if not _table_pixel_metrics_by_case.has(reference_case):
				failure_reasons.append("missing %s pixel baseline" % reference_case)
		var reference_metrics := _stronger_reference_metrics("forecast", "active")
		if not reference_metrics.is_empty():
			comparisons = _compare_pixel_metrics(metrics, reference_metrics, 0.85)
			for comparison_key in comparisons:
				if not bool((comparisons[comparison_key] as Dictionary).get("passed", false)):
					failure_reasons.append("dual_active %s coverage is below 85%% of forecast/active" % comparison_key)
	return {
		"passed": failure_reasons.is_empty(),
		"failure_reasons": failure_reasons,
		"baseline_ratio_floor": 0.85,
		"comparisons_to_stronger_forecast_or_active": comparisons,
	}


func _stronger_reference_metrics(first_case: String, second_case: String) -> Dictionary:
	if not _table_pixel_metrics_by_case.has(first_case) or not _table_pixel_metrics_by_case.has(second_case):
		return {}
	var first := _table_pixel_metrics_by_case[first_case] as Dictionary
	var second := _table_pixel_metrics_by_case[second_case] as Dictionary
	var result := {"whole": {}, "screen_regions": {}}
	for metric_key in ["non_black_coverage", "bright_coverage", "effective_coverage", "mean_luminance"]:
		(result["whole"] as Dictionary)[metric_key] = maxf(
			float((first.get("whole", {}) as Dictionary).get(metric_key, 0.0)),
			float((second.get("whole", {}) as Dictionary).get(metric_key, 0.0))
		)
	for region_key in ["top", "left", "right", "bottom"]:
		var region_reference := {}
		for metric_key in ["non_black_coverage", "bright_coverage", "effective_coverage", "mean_luminance"]:
			region_reference[metric_key] = maxf(
				float((((first.get("screen_regions", {}) as Dictionary).get(region_key, {}) as Dictionary).get(metric_key, 0.0))),
				float((((second.get("screen_regions", {}) as Dictionary).get(region_key, {}) as Dictionary).get(metric_key, 0.0)))
			)
		(result["screen_regions"] as Dictionary)[region_key] = region_reference
	return result


func _compare_pixel_metrics(candidate: Dictionary, reference: Dictionary, ratio_floor: float) -> Dictionary:
	var comparisons := {}
	for metric_key in ["non_black_coverage", "bright_coverage", "effective_coverage", "mean_luminance"]:
		comparisons["whole_%s" % metric_key] = _coverage_comparison(
			float((candidate.get("whole", {}) as Dictionary).get(metric_key, 0.0)),
			float((reference.get("whole", {}) as Dictionary).get(metric_key, 0.0)),
			ratio_floor
		)
	for region_key in ["top", "left", "right", "bottom"]:
		for metric_key in ["bright_coverage", "effective_coverage", "mean_luminance"]:
			comparisons["%s_%s" % [region_key, metric_key]] = _coverage_comparison(
				float((((candidate.get("screen_regions", {}) as Dictionary).get(region_key, {}) as Dictionary).get(metric_key, 0.0))),
				float((((reference.get("screen_regions", {}) as Dictionary).get(region_key, {}) as Dictionary).get(metric_key, 0.0))),
				ratio_floor
			)
	return comparisons


func _coverage_comparison(candidate: float, reference: float, ratio_floor: float) -> Dictionary:
	var ratio := candidate / reference if reference > 0.000001 else 1.0
	return {"candidate": candidate, "reference": reference, "ratio": ratio, "passed": ratio >= ratio_floor}


func _layer_gate(map_view: Node, sceneization: Dictionary) -> Dictionary:
	var weather_layer := map_view.get_node_or_null("WeatherLayer") as Control
	var district_layer := map_view.get_node_or_null("DistrictLayer") as Control
	var route_layer := map_view.get_node_or_null("RouteLayer") as Control
	var monster_layer := map_view.get_node_or_null("MonsterLayer") as Control
	var weather_index := weather_layer.get_index() if weather_layer != null else -1
	var district_index := district_layer.get_index() if district_layer != null else -1
	var route_index := route_layer.get_index() if route_layer != null else -1
	var monster_index := monster_layer.get_index() if monster_layer != null else -1
	var counts := {
		"district_polygon_count": int(sceneization.get("district_polygon_count", 0)),
		"city_marker_count": int(sceneization.get("city_marker_count", 0)),
		"route_segment_count": int(sceneization.get("route_segment_count", 0)),
		"route_marker_count": int(sceneization.get("route_marker_count", 0)),
		"monster_token_count": int(sceneization.get("monster_token_count", 0)),
	}
	var ordering := weather_index >= 0 and weather_index < district_index and district_index < route_index and route_index < monster_index
	var objects_present := int(counts.district_polygon_count) > 0 and int(counts.city_marker_count) > 0 \
		and (int(counts.route_segment_count) > 0 or int(counts.route_marker_count) > 0) and int(counts.monster_token_count) > 0
	return {
		"passed": ordering and objects_present and weather_layer != null and weather_layer.mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"weather_mouse_filter_ignore": weather_layer != null and weather_layer.mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"layer_indices": {"weather": weather_index, "district_and_city": district_index, "route": route_index, "monster": monster_index},
		"objects_present": objects_present,
		"counts": counts,
		"weather_overlay_debug": map_view.call("weather_overlay_debug_snapshot") if map_view.has_method("weather_overlay_debug_snapshot") else {},
	}


func _district_detail_text(main: Node) -> String:
	var panel := main.find_child("DistrictInfoPanel", true, false)
	if panel == null:
		return ""
	var full_label := panel.find_child("DistrictFullDetail", true, false) as Label
	return full_label.text if full_label != null else _visible_text(panel)


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


func _economy_node_snapshots(main: Node) -> Dictionary:
	var result := {}
	for node_name in ["RuntimeGameScreen", "MenuModalOverlay", "EconomyDashboardPanel", "MenuBackButton"]:
		result[node_name] = _control_snapshot(main.find_child(node_name, true, false))
	return result


func _control_snapshot(node: Node) -> Dictionary:
	if node == null:
		return {"found": false}
	var result := {"found": true, "name": str(node.name), "path": str(node.get_path()), "type": node.get_class()}
	if node is Control:
		var control := node as Control
		var rect := control.get_global_rect()
		result.merge({
			"visible": control.visible,
			"visible_in_tree": control.is_visible_in_tree(),
			"rect": {"x": rect.position.x, "y": rect.position.y, "width": rect.size.x, "height": rect.size.y},
		})
	return result


func _visible_text(node: Node) -> String:
	var lines: Array[String] = []
	_collect_visible_text(node, lines)
	return "\n".join(lines)


func _collect_visible_text(node: Node, lines: Array[String]) -> void:
	if node == null:
		return
	if node is Control and not (node as Control).is_visible_in_tree():
		return
	if node is Label and not (node as Label).text.strip_edges().is_empty():
		lines.append((node as Label).text.strip_edges())
	elif node is Button and not (node as Button).text.strip_edges().is_empty():
		lines.append((node as Button).text.strip_edges())
	if node is Control and not (node as Control).tooltip_text.strip_edges().is_empty():
		lines.append((node as Control).tooltip_text.strip_edges())
	for child in node.get_children():
		_collect_visible_text(child, lines)


func _visible_marker_candidates(node: Node, markers: Array) -> Array[String]:
	var candidates: Array[String] = []
	var text := _visible_text(node)
	for line in text.split("\n", false):
		var normalized := str(line).strip_edges()
		var lower := normalized.to_lower()
		for marker_variant in markers:
			if lower.contains(str(marker_variant).to_lower()):
				if not candidates.has(normalized):
					candidates.append(normalized)
				break
	return candidates


func _save_viewport(file_name: String, node_rects: Dictionary = {}) -> Dictionary:
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image == null or image.is_empty():
		_fail("viewport image was empty for %s" % file_name)
		return {"saved": false, "pixel_metrics": {}}
	_expect(image.get_size() == CAPTURE_SIZE, "%s is exactly 1600x960" % file_name)
	var pixel_metrics := _image_content_metrics(image, node_rects)
	var resource_path := "%s/%s" % [OUTPUT_DIR, file_name]
	var error := image.save_png(resource_path)
	if error != OK:
		_fail("failed to save %s: %s" % [resource_path, error_string(error)])
		return {"saved": false, "pixel_metrics": pixel_metrics}
	var absolute_path := ProjectSettings.globalize_path(resource_path)
	_capture_paths.append(absolute_path)
	print("CAPTURE: %s" % absolute_path)
	return {
		"saved": true,
		"resource_path": resource_path,
		"absolute_path": absolute_path,
		"sha256": FileAccess.get_sha256(resource_path),
		"pixel_metrics": pixel_metrics,
	}


func _image_content_metrics(image: Image, node_rects: Dictionary) -> Dictionary:
	var screen_regions := {
		"top": Rect2(0.0, 0.0, 1600.0, 120.0),
		"left": Rect2(0.0, 120.0, 360.0, 612.0),
		"right": Rect2(1280.0, 120.0, 320.0, 612.0),
		"bottom": Rect2(0.0, 736.0, 1600.0, 224.0),
	}
	var screen_metrics := {}
	for region_key in screen_regions:
		screen_metrics[region_key] = _sample_image_region(image, screen_regions[region_key] as Rect2)
	var node_metrics := {}
	for node_key in node_rects:
		var rect_data := node_rects[node_key] as Dictionary
		var rect := Rect2(
			float(rect_data.get("x", 0.0)),
			float(rect_data.get("y", 0.0)),
			float(rect_data.get("width", 0.0)),
			float(rect_data.get("height", 0.0))
		)
		node_metrics[node_key] = _sample_image_region(image, rect)
	return {
		"sample_stride_pixels": 4,
		"non_black_peak_floor": 0.035,
		"bright_peak_floor": 0.19,
		"effective_chroma_floor": 0.098,
		"effective_peak_floor": 0.314,
		"whole": _sample_image_region(image, Rect2(Vector2.ZERO, Vector2(image.get_size()))),
		"screen_regions": screen_metrics,
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


func _save_json(file_name: String, value: Dictionary) -> void:
	var path := "%s/%s" % [OUTPUT_DIR, file_name]
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_fail("failed to open %s" % path)
		return
	file.store_string(JSON.stringify(value, "  "))
	file.close()
	print("SCENE_TREE: %s" % ProjectSettings.globalize_path(path))


func _finish(main: Node, report: Dictionary) -> void:
	if main != null and is_instance_valid(main):
		root.remove_child(main)
		main.queue_free()
		await _pump_frames(5)
	_cleanup_qa_save_artifacts()
	var player_default_after := _save_file_snapshot(PLAYER_DEFAULT_SAVE_PATH)
	var player_default_unchanged := _player_default_before == player_default_after
	_expect(player_default_unchanged, "player default save metadata and SHA-256 are unchanged")
	var remaining_qa_artifacts := _qa_save_artifacts()
	_expect(remaining_qa_artifacts.is_empty(), "isolated QA save artifacts are removed after capture")
	report.merge({
		"scene": MAIN_SCENE_PATH,
		"resolution": {"x": CAPTURE_SIZE.x, "y": CAPTURE_SIZE.y},
		"capture_paths": _capture_paths,
		"save_isolation": {
			"qa_save_path": QA_SAVE_PATH,
			"qa_override_active_before_tree": true,
			"qa_artifacts_after_cleanup": remaining_qa_artifacts,
			"player_default_save_path": PLAYER_DEFAULT_SAVE_PATH,
			"player_default_before": _player_default_before,
			"player_default_after": player_default_after,
			"player_default_unchanged": player_default_unchanged,
		},
		"checks": _checks,
		"failures": _failures,
	}, true)
	_save_json("e_weather_lifecycle_1600x960_gate.json", report)
	if _failures.is_empty():
		print("WEATHER_LIFECYCLE_PRODUCTION_CAPTURE|status=PASS|checks=%d|failures=0" % _checks)
		quit(0)
	else:
		printerr("WEATHER_LIFECYCLE_PRODUCTION_CAPTURE|status=FAIL|checks=%d|failures=%d\n- %s" % [_checks, _failures.size(), "\n- ".join(_failures)])
		quit(1)


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
	var directory := DirAccess.open(absolute_dir)
	if directory == null:
		return
	for file_name in directory.get_files():
		if file_name.begins_with("e_weather_") and (file_name.ends_with(".png") or file_name.ends_with(".json")):
			DirAccess.remove_absolute(absolute_dir.path_join(file_name))


func _place_capture_window() -> void:
	var screen_index := 1 if DisplayServer.get_screen_count() > 1 else 0
	DisplayServer.window_set_current_screen(screen_index)
	DisplayServer.window_set_position(DisplayServer.screen_get_position(screen_index) + Vector2i(20, 20))


func _pump_frames(count: int) -> void:
	for _index in range(maxi(1, count)):
		await process_frame


func _expect(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_fail(label)


func _fail(message: String) -> void:
	if not _failures.has(message):
		_failures.append(message)
	printerr("WEATHER_LIFECYCLE_GATE_FAIL: %s" % message)
