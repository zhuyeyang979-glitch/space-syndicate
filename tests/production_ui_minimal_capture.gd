extends SceneTree

const MAIN_SCENE_PATH := "res://scenes/main.tscn"
const OUTPUT_DIR := "res://reports/ui/production_acceptance"
const DEFAULT_CAPTURE_SIZE := Vector2i(1280, 720)
const QA_SAVE_PATH := "user://test_runs/e_production_ui_minimal_capture.save"
const PLAYER_DEFAULT_SAVE_PATH := "user://space_syndicate_current_run.save"
const SAVE_COORDINATOR_NODE_PATH := "RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/GameSessionRuntimeController/GameSaveRuntimeCoordinator"

var _failures: Array[String] = []
var _saved_paths: Array[String] = []
var _capture_size := DEFAULT_CAPTURE_SIZE


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_read_capture_size_argument()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	_cleanup_qa_save_artifacts()
	var player_default_before := _save_file_snapshot(PLAYER_DEFAULT_SAVE_PATH)
	_place_capture_window()
	DisplayServer.window_set_size(_capture_size)
	root.size = _capture_size
	var packed := load(MAIN_SCENE_PATH) as PackedScene
	if packed == null:
		_fail("production main scene did not load")
		_finish()
		return
	var main := packed.instantiate()
	var save_coordinator := main.get_node_or_null(SAVE_COORDINATOR_NODE_PATH)
	var save_override_ready := save_coordinator != null \
		and save_coordinator.has_method("set_qa_default_save_path_override") \
		and bool(save_coordinator.call("set_qa_default_save_path_override", QA_SAVE_PATH))
	if not save_override_ready:
		_fail("production main did not install the isolated QA save path before entering the tree")
		main.free()
		_cleanup_qa_save_artifacts()
		_finish()
		return
	var save_operation: Dictionary = save_coordinator.call("operation_snapshot")
	if str(save_operation.get("default_save_path", "")) != QA_SAVE_PATH or not bool(save_operation.get("qa_save_path_override_active", false)):
		_fail("production main save coordinator did not report the isolated QA override")
	root.add_child(main)
	await _pump_frames(12)
	main.set("configured_player_count", 4)
	main.set("configured_ai_player_count", 3)
	main.set("configured_role_indices", [0, 1, 2, 3, 4])
	main.set("configured_starter_monster_indices", [0, 1, 2, 3])
	var coordinator := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator")
	if coordinator != null and coordinator.has_method("clear_runtime_scenario"):
		coordinator.call("clear_runtime_scenario")
	main.call("_new_game")
	main.call("_close_menu")
	await _pump_frames(24)
	_select_first_live_district(main)
	if main.has_method("_sync_runtime_game_screen"):
		main.call("_sync_runtime_game_screen", true)
	await _pump_frames(16)
	var map_view := _runtime_map_view(main)
	if map_view == null:
		_fail("production PlanetMapView was not found")
	elif map_view.has_method("reset_to_planet_overview"):
		map_view.call("reset_to_planet_overview")
	await _pump_frames(10)
	await _save_viewport("e_minimal_clear_globe_%s.png" % _resolution_suffix())
	var baseline_report := _build_report(main, "clear_globe")
	var visible_machine_ids: Array = baseline_report.get("visible_machine_id_candidates", [])
	if not visible_machine_ids.is_empty():
		_fail("visible machine ids remain in the production table: %s" % visible_machine_ids)
	if map_view != null and map_view.has_method("zoom_to_local_projection"):
		map_view.call("zoom_to_local_projection")
		await _pump_frames(10)
		await _save_viewport("e_minimal_clear_local_%s.png" % _resolution_suffix())
	else:
		_fail("production PlanetMapView local projection was unavailable")
	if main.has_method("_open_economy_overview_menu"):
		main.call("_open_economy_overview_menu")
		await _pump_frames(12)
		await _save_viewport("e_minimal_economy_overview_%s.png" % _resolution_suffix())
	else:
		_fail("production economy overview entry was unavailable")
	baseline_report["economy_overview"] = _control_snapshot(main.find_child("EconomyDashboardPanel", true, false))
	baseline_report["economy_back_button"] = _control_snapshot(main.find_child("MenuBackButton", true, false))
	var economy_back_button := main.find_child("MenuBackButton", true, false) as Button
	if economy_back_button != null and economy_back_button.is_visible_in_tree() and economy_back_button.text == "Back":
		_fail("economy overview still exposes the English Back fallback")
	baseline_report["saved_paths"] = _saved_paths.duplicate()
	root.remove_child(main)
	main.queue_free()
	await _pump_frames(4)
	_cleanup_qa_save_artifacts()
	var player_default_after := _save_file_snapshot(PLAYER_DEFAULT_SAVE_PATH)
	var player_default_unchanged := player_default_before == player_default_after
	if not player_default_unchanged:
		_fail("player default save metadata or hash changed during production capture")
	var remaining_qa_artifacts := _qa_save_artifacts()
	if not remaining_qa_artifacts.is_empty():
		_fail("isolated QA save artifacts remain after cleanup: %s" % remaining_qa_artifacts)
	baseline_report["save_isolation"] = {
		"qa_save_path": QA_SAVE_PATH,
		"qa_override_active_before_tree": true,
		"qa_artifacts_after_cleanup": remaining_qa_artifacts,
		"player_default_save_path": PLAYER_DEFAULT_SAVE_PATH,
		"player_default_before": player_default_before,
		"player_default_after": player_default_after,
		"player_default_unchanged": player_default_unchanged,
	}
	baseline_report["failures"] = _failures.duplicate()
	_save_report(baseline_report)
	_finish()


func _select_first_live_district(main: Node) -> void:
	var districts_variant: Variant = main.get("districts")
	if not (districts_variant is Array):
		_fail("production district list was unavailable")
		return
	var districts := districts_variant as Array
	for index in range(districts.size()):
		if districts[index] is Dictionary and not bool((districts[index] as Dictionary).get("destroyed", false)):
			main.call("_select_district", index)
			return
	_fail("production run had no live district to select")


func _runtime_map_view(main: Node) -> Node:
	var runtime_screen := main.find_child("RuntimeGameScreen", true, false)
	var search_root: Node = runtime_screen if runtime_screen != null else main
	return _find_node_with_method(search_root, "get_projection_debug_snapshot")


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


func _build_report(main: Node, state_name: String) -> Dictionary:
	var map_view := _runtime_map_view(main)
	var projection: Dictionary = {}
	if map_view != null and map_view.has_method("get_projection_debug_snapshot"):
		var projection_variant: Variant = map_view.call("get_projection_debug_snapshot")
		projection = projection_variant if projection_variant is Dictionary else {}
	var nodes := {}
	for node_name in [
		"RuntimeGameScreen",
		"PlanetBoard",
		"PlanetMapView",
		"WeatherForecastStrip",
		"RightInspector",
		"DistrictInfoPanel",
		"HandRack",
		"MenuModalOverlay",
	]:
		nodes[node_name] = _control_snapshot(main.find_child(node_name, true, false))
	nodes["WeatherMapOverlay"] = _control_snapshot(main.find_child("WeatherLayer", true, false))
	return {
		"scene": MAIN_SCENE_PATH,
		"state": state_name,
		"resolution": {"x": _capture_size.x, "y": _capture_size.y},
		"renderer": DisplayServer.get_name(),
		"projection": projection,
		"nodes": nodes,
		"visible_machine_id_candidates": _visible_machine_id_candidates(main),
	}


func _control_snapshot(node: Node) -> Dictionary:
	if node == null:
		return {"found": false}
	var snapshot := {
		"found": true,
		"name": str(node.name),
		"path": str(node.get_path()),
		"type": node.get_class(),
	}
	if node is Control:
		var control := node as Control
		var rect := control.get_global_rect()
		snapshot.merge({
			"visible": control.visible,
			"visible_in_tree": control.is_visible_in_tree(),
			"clip_contents": control.clip_contents,
			"rect": {
				"x": snappedf(rect.position.x, 0.01),
				"y": snappedf(rect.position.y, 0.01),
				"width": snappedf(rect.size.x, 0.01),
				"height": snappedf(rect.size.y, 0.01),
			},
		})
	return snapshot


func _visible_machine_id_candidates(root_node: Node) -> Array[String]:
	var candidates: Array[String] = []
	_collect_visible_machine_id_candidates(root_node, candidates)
	return candidates


func _collect_visible_machine_id_candidates(node: Node, candidates: Array[String]) -> void:
	if node == null:
		return
	if node is Control and not (node as Control).is_visible_in_tree():
		return
	var visible_texts: Array[String] = []
	if node is Label:
		visible_texts.append((node as Label).text)
	elif node is Button:
		visible_texts.append((node as Button).text)
	if node is Control:
		visible_texts.append((node as Control).tooltip_text)
	for visible_text in visible_texts:
		var normalized := visible_text.strip_edges()
		var machine_text := normalized.to_lower()
		if normalized != "" and (machine_text.contains("region.") or machine_text.contains("district_") or machine_text.contains("weather_") or machine_text.contains("event_id") or machine_text.contains("card_id") or machine_text.contains("unit.") or machine_text.contains("prism_armor") or machine_text.contains("meteor_sentinel") or machine_text.contains("oasis_support") or machine_text.contains("ember_ring") or machine_text.contains("blue_lancer") or machine_text.contains("mirror_hunter") or machine_text.contains("ocean") or machine_text.contains("land") or machine_text.contains("shipping") or machine_text.contains("technology") or machine_text.contains("energy") or machine_text.contains(" factory") or machine_text.contains(" market") or machine_text.contains(" warehouse") or machine_text.contains("active 公共设施")):
			if not candidates.has(normalized):
				candidates.append(normalized)
	for child in node.get_children():
		_collect_visible_machine_id_candidates(child, candidates)


func _save_viewport(file_name: String) -> void:
	await process_frame
	var image := root.get_texture().get_image()
	if image == null or image.is_empty():
		_fail("viewport image was empty for %s" % file_name)
		return
	if image.get_size() != _capture_size:
		_fail("viewport size mismatch for %s: %s" % [file_name, image.get_size()])
		return
	var resource_path := "%s/%s" % [OUTPUT_DIR, file_name]
	var error := image.save_png(resource_path)
	if error != OK:
		_fail("failed to save %s: %s" % [resource_path, error_string(error)])
		return
	var absolute_path := ProjectSettings.globalize_path(resource_path)
	_saved_paths.append(absolute_path)
	print("CAPTURE: %s" % absolute_path)


func _save_report(report: Dictionary) -> void:
	var path := "%s/e_minimal_clear_%s_scene_tree.json" % [OUTPUT_DIR, _resolution_suffix()]
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_fail("failed to open scene-tree report for writing")
		return
	file.store_string(JSON.stringify(report, "  "))
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
	var directory_path := QA_SAVE_PATH.get_base_dir()
	var file_prefix := QA_SAVE_PATH.get_file()
	var directory := DirAccess.open(directory_path)
	if directory == null:
		return artifacts
	for file_name in directory.get_files():
		if file_name.begins_with(file_prefix):
			artifacts.append("%s/%s" % [directory_path, file_name])
	return artifacts


func _cleanup_qa_save_artifacts() -> void:
	for path in _qa_save_artifacts():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _place_capture_window() -> void:
	var screen_index := 1 if DisplayServer.get_screen_count() > 1 else 0
	DisplayServer.window_set_current_screen(screen_index)
	DisplayServer.window_set_position(DisplayServer.screen_get_position(screen_index) + Vector2i(20, 20))


func _read_capture_size_argument() -> void:
	for argument in OS.get_cmdline_user_args():
		if not argument.begins_with("--capture-size="):
			continue
		var dimensions := argument.trim_prefix("--capture-size=").split("x", false)
		if dimensions.size() != 2 or not dimensions[0].is_valid_int() or not dimensions[1].is_valid_int():
			_fail("invalid --capture-size argument: %s" % argument)
			return
		_capture_size = Vector2i(maxi(640, int(dimensions[0])), maxi(360, int(dimensions[1])))
		return


func _resolution_suffix() -> String:
	return "%dx%d" % [_capture_size.x, _capture_size.y]


func _pump_frames(count: int) -> void:
	for _index in range(maxi(1, count)):
		await process_frame


func _fail(message: String) -> void:
	_failures.append(message)
	push_error("Production UI minimal capture: %s" % message)


func _finish() -> void:
	_cleanup_qa_save_artifacts()
	if _failures.is_empty():
		print("Production UI minimal capture passed: %s" % ", ".join(_saved_paths))
		quit(0)
	else:
		printerr("Production UI minimal capture failed:\n- %s" % "\n- ".join(_failures))
		quit(1)
