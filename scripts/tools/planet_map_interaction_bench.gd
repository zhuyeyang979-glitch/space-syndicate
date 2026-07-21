extends Control
class_name PlanetMapInteractionBench

const OUTPUT_DIR := "user://space_syndicate_design_qa/planet_map_interactions/"
const SCREENSHOT_PATH := "user://space_syndicate_design_qa/planet_map_control_toolbar_sprint_25.png"
const PREVIEW_SCENE := preload("res://scenes/tools/PlanetMapMcpPreview.tscn")
const TOOLBAR_SCENE_PATH := "res://scenes/ui/map/PlanetMapControlToolbar.tscn"
const FULLSCREEN_MAP_SCENE_PATH := "res://scenes/ui/FullscreenMapOverlay.tscn"
const MAIN_SCENE_PATH := "res://scenes/main.tscn"
const MAIN_SCRIPT_PATH := "res://scripts/main.gd"

@export var auto_run := true
@export var auto_quit_after_suite := false

@onready var status_label: Label = %InteractionBenchStatusLabel
@onready var toolbar_preview: Control = %InteractionBenchToolbar
@onready var preview_host: Control = %InteractionBenchPreviewHost

var _suite_running := false
var _last_manifest := {}


func _ready() -> void:
	if toolbar_preview != null and toolbar_preview.has_method("set_controls"):
		toolbar_preview.call("set_controls", _toolbar_fixture())
	if auto_run and not Engine.is_editor_hint():
		call_deferred("run_interaction_suite")


func output_dir() -> String:
	return OUTPUT_DIR


func screenshot_path() -> String:
	return SCREENSHOT_PATH


func interaction_cases() -> Array:
	return [
		{"case_id": "click_selected_district", "fixture_id": "selected_district", "clicked_district": 1, "interaction": "click"},
		{"case_id": "double_click_district", "fixture_id": "selected_district", "clicked_district": 1, "interaction": "double_click"},
		{"case_id": "keyboard_navigation", "fixture_id": "selected_district", "clicked_district": 1, "interaction": "keyboard"},
		{"case_id": "focus_district_programmatic", "fixture_id": "selected_district", "clicked_district": 1, "interaction": "focus"},
		{"case_id": "zoom_projection_sync", "fixture_id": "local_zoom", "clicked_district": 2, "interaction": "projection"},
		{"case_id": "render_cutover_interaction", "fixture_id": "render_cutover", "clicked_district": 3, "interaction": "cutover"},
		{"case_id": "empty_map_safe_interaction", "fixture_id": "empty_map_safe_state", "clicked_district": -1, "interaction": "empty"},
		{"case_id": "toolbar_scene_composition", "fixture_id": "toolbar_default", "clicked_district": -1, "interaction": "toolbar_scene"},
		{"case_id": "layer_focus_action_routes", "fixture_id": "toolbar_default", "clicked_district": -1, "interaction": "toolbar_layer"},
		{"case_id": "trade_product_selection_routes", "fixture_id": "toolbar_default", "clicked_district": -1, "interaction": "toolbar_trade"},
		{"case_id": "real_main_toolbar_route", "fixture_id": "real_main", "clicked_district": -1, "interaction": "toolbar_real_main"},
		{"case_id": "pure_toolbar_snapshot", "fixture_id": "toolbar_default", "clicked_district": -1, "interaction": "toolbar_pure_data"},
		{"case_id": "legacy_toolbar_builders_and_node_arrays_absent", "fixture_id": "main_source", "clicked_district": -1, "interaction": "toolbar_deletion"},
	]


func build_interaction_manifest_preview() -> Dictionary:
	var records: Array = []
	for case_variant in interaction_cases():
		var case: Dictionary = case_variant if case_variant is Dictionary else {}
		records.append({
			"case_id": str(case.get("case_id", "")),
			"fixture_id": str(case.get("fixture_id", "")),
			"clicked_district": int(case.get("clicked_district", -1)),
			"selected_signal_received": false,
			"double_click_signal_received": false,
			"focus_checked": false,
			"projection_sync_checked": false,
			"cutover_enabled": true,
			"legacy_fallback_used": false,
			"toolbar_checked": false,
			"action_id": "",
			"payload_checked": false,
			"disabled_checked": false,
			"main_route_checked": false,
			"deletion_checked": false,
			"pure_data_checked": false,
			"passed": false,
			"notes": "Preview manifest only; run_interaction_suite records live results.",
		})
	return {
		"suite": "planet_map_interactions",
		"output_dir": OUTPUT_DIR,
		"screenshot_path": SCREENSHOT_PATH,
		"records": records,
	}


func run_interaction_suite() -> void:
	if _suite_running:
		return
	_suite_running = true
	_set_status("Running PlanetMap interaction ownership suite...")
	var preview := _ensure_preview()
	var records: Array = []
	var all_passed := preview != null
	if preview == null:
		push_error("PlanetMapInteractionBench could not instantiate PlanetMapMcpPreview.")
	else:
		for case_variant in interaction_cases():
			var case: Dictionary = case_variant if case_variant is Dictionary else {}
			var interaction := str(case.get("interaction", ""))
			var record: Dictionary
			if interaction.begins_with("toolbar_"):
				record = await _run_toolbar_case(case)
			else:
				record = await _run_interaction_case(preview, case)
			records.append(record)
			all_passed = all_passed and bool(record.get("passed", false))
	var manifest := {
		"suite": "planet_map_interactions",
		"output_dir": OUTPUT_DIR,
		"screenshot_path": SCREENSHOT_PATH,
		"record_count": records.size(),
		"passed_count": _passed_count(records),
		"records": records,
	}
	_last_manifest = manifest
	var paths := _write_outputs(manifest)
	var manifest_path := str(paths.get("manifest", "%smanifest.json" % OUTPUT_DIR))
	var report_path := str(paths.get("report", "%sreport.md" % OUTPUT_DIR))
	if preview != null and preview.has_method("apply_fixture"):
		preview.call("apply_fixture", "selected_district")
		await _settle_frames(4)
	print("PlanetMapInteractionBench manifest: %s" % manifest_path)
	print("PlanetMapInteractionBench report: %s" % report_path)
	if all_passed:
		_set_status("Planet interactions passed: %d/%d | %s" % [_passed_count(records), records.size(), manifest_path])
	else:
		_set_status("Planet interactions failed: %d/%d | %s" % [_passed_count(records), records.size(), manifest_path])
		push_error("PlanetMapInteractionBench failed. See %s" % manifest_path)
	_suite_running = false
	if auto_quit_after_suite:
		await get_tree().create_timer(0.25).timeout
		get_tree().quit(0 if all_passed else 1)


func _ensure_preview() -> Control:
	if preview_host == null:
		return null
	var existing := preview_host.find_child("PlanetMapMcpPreview", true, false) as Control
	if existing != null:
		return existing
	var preview := PREVIEW_SCENE.instantiate() as Control
	if preview == null:
		return null
	preview.name = "PlanetMapMcpPreview"
	preview_host.add_child(preview)
	preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return preview


func _run_interaction_case(preview: Control, case: Dictionary) -> Dictionary:
	var case_id := str(case.get("case_id", ""))
	var fixture_id := str(case.get("fixture_id", ""))
	var clicked_district := int(case.get("clicked_district", -1))
	var applied := bool(preview.call("apply_fixture", fixture_id)) if preview.has_method("apply_fixture") else false
	await _settle_frames(3)
	var map_view := _map_view(preview)
	var selected_indices: Array[int] = []
	var double_indices: Array[int] = []
	if map_view != null:
		if map_view.has_signal("district_selected"):
			map_view.connect("district_selected", func(index: int) -> void:
				selected_indices.append(index)
			)
		if map_view.has_signal("district_double_clicked"):
			map_view.connect("district_double_clicked", func(index: int) -> void:
				double_indices.append(index)
			)
	var visible_map := map_view != null and map_view.visible and map_view.size.x > 8.0 and map_view.size.y > 8.0
	var signals_compatible := map_view != null and map_view.has_signal("district_selected") and map_view.has_signal("district_double_clicked")
	var methods_compatible := map_view != null \
		and map_view.has_method("set_map") \
		and map_view.has_method("focus_district") \
		and map_view.has_method("get_district_at_control_position") \
		and map_view.has_method("get_district_control_position")
	var clicked_position := Vector2(-1.0, -1.0)
	var hit_index := -1
	var keyboard_checked := true
	if map_view != null and clicked_district >= 0 and methods_compatible:
		if map_view.has_method("set_programmatic_focus_animation_enabled"):
			map_view.call("set_programmatic_focus_animation_enabled", false)
		clicked_position = map_view.call("get_district_control_position", clicked_district)
		hit_index = int(map_view.call("get_district_at_control_position", clicked_position))
		_emit_left_click(map_view, clicked_position, false)
		await _settle_frames(2)
		_emit_left_click(map_view, clicked_position, true)
		await _settle_frames(2)
		if case_id == "keyboard_navigation":
			keyboard_checked = await _run_keyboard_check(map_view, selected_indices)
		elif case_id == "focus_district_programmatic":
			map_view.call("focus_district", clicked_district)
			await _settle_frames(3)
	var empty_safe_checked := true
	var focus_district_for_case := clicked_district
	if clicked_district < 0 and map_view != null:
		_emit_left_click(map_view, map_view.size * 0.5, false)
		await _settle_frames(2)
		empty_safe_checked = selected_indices.is_empty() and double_indices.is_empty()
	elif case_id == "keyboard_navigation" and not selected_indices.is_empty():
		focus_district_for_case = int(selected_indices[selected_indices.size() - 1])
	var snapshot := _map_snapshot(preview, map_view)
	var cutover_enabled := bool(snapshot.get("sceneized_visual_cutover_enabled", false))
	var legacy_used := bool(snapshot.get("legacy_draw_fallback_used", true))
	var focus_checked := _focus_state_ok(map_view, snapshot, focus_district_for_case)
	var projection_sync_checked := await _projection_sync_ok(map_view, clicked_district, case_id)
	var privacy_checked := not _text_contains_private_tokens(preview)
	var selected_signal_received := clicked_district < 0 or selected_indices.has(clicked_district)
	var double_click_signal_received := clicked_district < 0 or double_indices.has(clicked_district)
	var hit_checked := clicked_district < 0 or hit_index == clicked_district
	var passed := applied \
		and visible_map \
		and signals_compatible \
		and methods_compatible \
		and cutover_enabled \
		and not legacy_used \
		and selected_signal_received \
		and double_click_signal_received \
		and focus_checked \
		and projection_sync_checked \
		and hit_checked \
		and keyboard_checked \
		and empty_safe_checked \
		and privacy_checked
	var notes := "interaction ownership ok"
	if not passed:
		notes = "applied=%s visible=%s signals=%s methods=%s cutover=%s legacy=%s selected=%s double=%s focus=%s projection=%s hit=%s keyboard=%s empty=%s privacy=%s selected_indices=%s double_indices=%s pos=%s hit=%d" % [
			str(applied),
			str(visible_map),
			str(signals_compatible),
			str(methods_compatible),
			str(cutover_enabled),
			str(legacy_used),
			str(selected_signal_received),
			str(double_click_signal_received),
			str(focus_checked),
			str(projection_sync_checked),
			str(hit_checked),
			str(keyboard_checked),
			str(empty_safe_checked),
			str(privacy_checked),
			str(selected_indices),
			str(double_indices),
			str(clicked_position),
			hit_index,
		]
	return {
		"case_id": case_id,
		"fixture_id": fixture_id,
		"clicked_district": clicked_district,
		"selected_signal_received": selected_signal_received,
		"double_click_signal_received": double_click_signal_received,
		"focus_checked": focus_checked,
		"projection_sync_checked": projection_sync_checked,
		"cutover_enabled": cutover_enabled,
		"legacy_fallback_used": legacy_used,
		"passed": passed,
		"notes": notes,
		"methods_compatible": methods_compatible,
		"signals_compatible": signals_compatible,
		"hit_test_checked": hit_checked,
		"keyboard_checked": keyboard_checked,
		"empty_safe_checked": empty_safe_checked,
		"privacy_checked": privacy_checked,
		"toolbar_checked": false,
		"action_id": "",
		"payload_checked": false,
		"disabled_checked": false,
		"main_route_checked": false,
		"deletion_checked": false,
		"pure_data_checked": true,
	}


func _run_toolbar_case(case: Dictionary) -> Dictionary:
	var case_id := str(case.get("case_id", ""))
	var packed := load(TOOLBAR_SCENE_PATH) as PackedScene
	var toolbar := packed.instantiate() as Control if packed != null else null
	var layer_focuses: Array[String] = []
	var route_selections: Array[String] = []
	if toolbar != null:
		add_child(toolbar)
		toolbar.visible = false
		toolbar.connect("map_layer_focus_requested", func(layer_id: String) -> void: layer_focuses.append(layer_id))
		toolbar.connect("optional_route_selection_changed", func(product_id: String) -> void: route_selections.append(product_id))
		await _settle_frames(2)
		toolbar.call("set_controls", _toolbar_fixture())
	var toolbar_checked := toolbar != null and toolbar.has_method("set_controls") and toolbar.has_method("debug_snapshot") and toolbar.has_signal("map_layer_focus_requested") and toolbar.has_signal("optional_route_selection_changed") and not toolbar.has_signal("control_action_requested")
	var payload_checked := false
	var disabled_checked := false
	var main_route_checked := false
	var deletion_checked := false
	var pure_data_checked := false
	var passed := false
	var action_id := ""
	match case_id:
		"toolbar_scene_composition":
			var required_nodes := ["MapReadingHintRail", "MapLayerFocusRail", "MapLayerAllButton", "MapLayerProductButton", "MapLayerRouteButton", "MapLayerIntelButton", "MapLayerWeatherButton", "MapLayerMonsterButton", "MapTradeProductSelector", "MapTradeStatusLabel"]
			var retired_nodes := ["MapContractSourceButton", "MapContractTargetButton", "MapContractStatusLabel"]
			var retired_nodes_absent := true
			for node_name_variant: Variant in retired_nodes:
				retired_nodes_absent = retired_nodes_absent and toolbar.find_child(str(node_name_variant), true, false) == null
			passed = toolbar_checked and _has_nodes(toolbar, required_nodes) and retired_nodes_absent and FileAccess.get_file_as_string(FULLSCREEN_MAP_SCENE_PATH).contains(TOOLBAR_SCENE_PATH)
		"layer_focus_action_routes":
			action_id = "map_layer_focus"
			var button := toolbar.find_child("MapLayerIntelButton", true, false) as Button if toolbar != null else null
			if button != null:
				button.emit_signal("pressed")
			payload_checked = layer_focuses == ["intel"]
			passed = toolbar_checked and payload_checked
		"trade_product_selection_routes":
			action_id = "map_trade_product_select"
			var selector := toolbar.find_child("MapTradeProductSelector", true, false) as OptionButton if toolbar != null else null
			if selector != null and selector.item_count > 1:
				selector.emit_signal("item_selected", 1)
			payload_checked = route_selections == ["食品"]
			passed = toolbar_checked and payload_checked
		"real_main_toolbar_route":
			action_id = "map_layer_focus"
			main_route_checked = await _real_main_toolbar_route_ok()
			passed = toolbar_checked and main_route_checked
		"pure_toolbar_snapshot":
			var snapshot: Variant = toolbar.call("debug_snapshot") if toolbar != null else {}
			pure_data_checked = snapshot is Dictionary and _is_pure_data(snapshot) and _is_pure_data(_toolbar_fixture())
			passed = toolbar_checked and pure_data_checked
		"legacy_toolbar_builders_and_node_arrays_absent":
			var main_source := FileAccess.get_file_as_string(MAIN_SCRIPT_PATH)
			var retired_tokens := ["func _add_map_control_chip", "func _add_map_layer_focus_rail", "func _add_map_action_controls", "func _on_trade_product_selected", "map_build_buttons", "map_guess_options", "map_guess_buttons", "map_role_intel_buttons", "map_city_info_labels", "map_trade_options", "map_trade_buttons", "map_trade_info_labels", "map_layer_buttons", "map_layer_info_labels", "map_contract_source_buttons", "map_contract_target_buttons", "map_contract_info_labels"]
			deletion_checked = main_source.contains("func _map_control_toolbar_snapshot") and not main_source.contains("func _on_map_control_toolbar_action_requested")
			for token_variant: Variant in retired_tokens:
				deletion_checked = deletion_checked and not main_source.contains(str(token_variant))
			passed = toolbar_checked and deletion_checked
	var notes := "toolbar ownership ok" if passed else "toolbar=%s action=%s payload=%s disabled=%s main=%s deletion=%s pure=%s layer_focuses=%s route_selections=%s" % [str(toolbar_checked), action_id, str(payload_checked), str(disabled_checked), str(main_route_checked), str(deletion_checked), str(pure_data_checked), str(layer_focuses), str(route_selections)]
	if toolbar != null:
		remove_child(toolbar)
		toolbar.queue_free()
		await _settle_frames(1)
	return {
		"case_id": case_id,
		"fixture_id": str(case.get("fixture_id", "")),
		"clicked_district": -1,
		"selected_signal_received": true,
		"double_click_signal_received": true,
		"focus_checked": true,
		"projection_sync_checked": true,
		"cutover_enabled": true,
		"legacy_fallback_used": false,
		"toolbar_checked": toolbar_checked,
		"action_id": action_id,
		"payload_checked": payload_checked,
		"disabled_checked": disabled_checked,
		"main_route_checked": main_route_checked,
		"deletion_checked": deletion_checked,
		"pure_data_checked": pure_data_checked,
		"privacy_checked": true,
		"passed": passed,
		"notes": notes,
	}


func _toolbar_fixture() -> Dictionary:
	return {
		"reading_hints": [{"text": "◎ 赌桌中央"}, {"text": "滚轮缩放"}, {"text": "拖拽地图"}, {"text": "双击看牌"}],
		"district_status": {"text": "⌖ 北环区", "tooltip": "公开区域状态"},
		"layers": [
			{"id": "all", "label": "全", "text": "全图", "accent": "#fef3c7", "tip": "全部公开信息"},
			{"id": "product", "label": "◇", "text": "商品", "accent": "#4ade80", "tip": "商品信息"},
			{"id": "route", "label": "⇄", "text": "商路", "accent": "#f59e0b", "tip": "商路信息"},
			{"id": "intel", "label": "?", "text": "情报", "accent": "#60a5fa", "tip": "公开线索"},
			{"id": "weather", "label": "☄", "text": "天气", "accent": "#38bdf8", "tip": "天气信息"},
			{"id": "monster", "label": "◆", "text": "怪兽", "accent": "#fb7185", "tip": "怪兽信息"},
			{"id": "city", "label": "▣", "text": "城市", "accent": "#c084fc", "tip": "城市信息"},
		],
		"selected_layer_id": "all",
		"layer_status": {"text": "图层:全图", "tooltip": "当前图层"},
		"trade": {"options": [{"id": "", "label": "商路关闭"}, {"id": "食品", "label": "食品"}, {"id": "能源", "label": "能源"}], "selected_product_id": "", "status": {"text": "⇄ 商路关"}},
	}


func _real_main_toolbar_route_ok() -> bool:
	var packed := load(MAIN_SCENE_PATH) as PackedScene
	var main := packed.instantiate() as Control if packed != null else null
	if main == null:
		return false
	main.visible = false
	add_child(main)
	await _settle_frames(4)
	if main.has_method("_open_fullscreen_map"):
		main.call("_open_fullscreen_map")
	await _settle_frames(2)
	var toolbar := main.find_child("PlanetMapControlToolbar", true, false) as Control
	var intel_button := toolbar.find_child("MapLayerIntelButton", true, false) as Button if toolbar != null else null
	var typed_layer_events: Array[String] = []
	var production_connection_count := toolbar.get_signal_connection_list("map_layer_focus_requested").size() if toolbar != null else 0
	if toolbar != null:
		toolbar.connect("map_layer_focus_requested", func(layer_id: String) -> void: typed_layer_events.append(layer_id))
	if intel_button != null:
		intel_button.emit_signal("pressed")
	await _settle_frames(2)
	var selection_state := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/TableSelectionState")
	var route_ok := toolbar != null and selection_state != null and production_connection_count > 0 and typed_layer_events == ["intel"] and not toolbar.has_signal("control_action_requested")
	for player_variant: Variant in main.find_children("*", "AudioStreamPlayer", true, false):
		var player := player_variant as AudioStreamPlayer
		if player != null:
			player.stop()
			player.stream = null
	remove_child(main)
	main.queue_free()
	await _settle_frames(4)
	return route_ok


func _selected_layer_id(snapshot: Dictionary) -> String:
	for entry_variant: Variant in snapshot.get("rendered_layers", []):
		if entry_variant is Dictionary and bool((entry_variant as Dictionary).get("selected", false)):
			return str((entry_variant as Dictionary).get("id", ""))
	return ""


func _has_nodes(root_node: Node, node_names: Array) -> bool:
	if root_node == null:
		return false
	for node_name_variant: Variant in node_names:
		if root_node.find_child(str(node_name_variant), true, false) == null:
			return false
	return true


func _is_pure_data(value: Variant) -> bool:
	if value is Callable or typeof(value) == TYPE_OBJECT:
		return false
	if value is Dictionary:
		for key_variant: Variant in value:
			if not _is_pure_data(key_variant) or not _is_pure_data(value[key_variant]):
				return false
	elif value is Array:
		for item_variant: Variant in value:
			if not _is_pure_data(item_variant):
				return false
	return true


func _map_view(preview: Control) -> Control:
	if preview == null:
		return null
	return preview.find_child("PlanetMapView", true, false) as Control


func _map_snapshot(preview: Control, map_view: Control) -> Dictionary:
	if preview != null and preview.has_method("current_map_debug_snapshot"):
		var preview_snapshot_variant: Variant = preview.call("current_map_debug_snapshot")
		if preview_snapshot_variant is Dictionary:
			return preview_snapshot_variant as Dictionary
	if map_view != null and map_view.has_method("get_sceneization_debug_snapshot"):
		var snapshot_variant: Variant = map_view.call("get_sceneization_debug_snapshot")
		if snapshot_variant is Dictionary:
			return snapshot_variant as Dictionary
	return {}


func _emit_left_click(map_view: Control, click_position: Vector2, double_click: bool) -> void:
	if map_view == null or click_position.x < 0.0 or click_position.y < 0.0:
		return
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.position = click_position
	press.pressed = true
	press.double_click = double_click
	map_view.call("_gui_input", press)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.position = click_position
	release.pressed = false
	map_view.call("_gui_input", release)


func _run_keyboard_check(map_view: Control, selected_indices: Array[int]) -> bool:
	if map_view == null:
		return false
	var before_count := selected_indices.size()
	var event := InputEventAction.new()
	event.action = "ui_right"
	event.pressed = true
	map_view.call("_gui_input", event)
	await _settle_frames(5)
	return selected_indices.size() > before_count


func _focus_state_ok(map_view: Control, snapshot: Dictionary, district_index: int) -> bool:
	if map_view == null:
		return false
	if district_index < 0:
		return int(snapshot.get("district_count", 0)) == 0 and int(snapshot.get("selection_marker_count", 0)) == 0
	var selected_matches := int(snapshot.get("selected_district", -1)) == district_index
	var selection_visible := int(snapshot.get("selection_marker_count", 0)) > 0 and bool(snapshot.get("selected_marker_visible", false))
	var focus_overlay := bool(snapshot.get("focus_range_overlay_sceneized", false))
	var district_node := map_view.find_child("PlanetDistrictNode_%02d" % district_index, true, false) as Control
	var selection_node := map_view.find_child("PlanetSelectionRing_%02d" % district_index, true, false) as Control
	return selected_matches and selection_visible and focus_overlay and district_node != null and selection_node != null


func _projection_sync_ok(map_view: Control, district_index: int, case_id: String) -> bool:
	if map_view == null:
		return false
	if district_index < 0:
		return true
	var before_position: Vector2 = _as_vector2(map_view.call("get_district_control_position", district_index)) if map_view.has_method("get_district_control_position") else Vector2(-1.0, -1.0)
	var before_node_position: Vector2 = _district_node_position(map_view, district_index)
	if case_id == "zoom_projection_sync" or case_id == "render_cutover_interaction":
		if map_view.has_method("reset_to_planet_overview"):
			map_view.call("reset_to_planet_overview")
		await _settle_frames(3)
		before_position = _as_vector2(map_view.call("get_district_control_position", district_index))
		before_node_position = _district_node_position(map_view, district_index)
		if map_view.has_method("zoom_to_local_projection"):
			map_view.call("zoom_to_local_projection")
		await _settle_frames(5)
	var after_position: Vector2 = _as_vector2(map_view.call("get_district_control_position", district_index)) if map_view.has_method("get_district_control_position") else Vector2(-1.0, -1.0)
	var after_node_position: Vector2 = _district_node_position(map_view, district_index)
	var hit_index := int(map_view.call("get_district_at_control_position", after_position)) if map_view.has_method("get_district_at_control_position") else -1
	var node_tracks_projection: bool = _valid_control_position(after_node_position) and after_node_position.distance_to(after_position) < 96.0
	if case_id == "zoom_projection_sync" or case_id == "render_cutover_interaction":
		var moved: bool = before_position.distance_to(after_position) > 0.5 or before_node_position.distance_to(after_node_position) > 0.5
		return moved and node_tracks_projection and hit_index == district_index
	return node_tracks_projection and hit_index == district_index


func _as_vector2(value: Variant) -> Vector2:
	if value is Vector2:
		return value as Vector2
	if value is Vector2i:
		return Vector2(value)
	if value is Array and (value as Array).size() >= 2:
		return Vector2(float((value as Array)[0]), float((value as Array)[1]))
	if value is Dictionary:
		var dict := value as Dictionary
		return Vector2(float(dict.get("x", 0.0)), float(dict.get("y", 0.0)))
	return Vector2(-1.0, -1.0)


func _district_node_position(map_view: Control, district_index: int) -> Vector2:
	var node := map_view.find_child("PlanetDistrictNode_%02d" % district_index, true, false) as Control
	if node == null:
		return Vector2.INF
	return node.position + node.size * 0.5


func _valid_control_position(value: Vector2) -> bool:
	return is_finite(value.x) and is_finite(value.y) and value.x > -99999.0 and value.y > -99999.0


func _text_contains_private_tokens(node: Node) -> bool:
	var text := _node_text(node).to_lower()
	for token in ["hidden_owner", "private_target", "private_discard", "owner_secret", "secret_owner"]:
		if text.contains(token):
			return true
	return false


func _node_text(node: Node) -> String:
	if node == null:
		return ""
	var parts := PackedStringArray()
	if node is Label:
		parts.append((node as Label).text)
	elif node is Button:
		parts.append((node as Button).text)
	for child in node.get_children():
		parts.append(_node_text(child))
	return " ".join(parts)


func _write_outputs(manifest: Dictionary) -> Dictionary:
	var absolute_dir := ProjectSettings.globalize_path(OUTPUT_DIR)
	DirAccess.make_dir_recursive_absolute(absolute_dir)
	var manifest_path := "%smanifest.json" % OUTPUT_DIR
	var report_path := "%sreport.md" % OUTPUT_DIR
	var manifest_file := FileAccess.open(manifest_path, FileAccess.WRITE)
	if manifest_file != null:
		manifest_file.store_string(JSON.stringify(manifest, "\t"))
	var report_file := FileAccess.open(report_path, FileAccess.WRITE)
	if report_file != null:
		report_file.store_string(_build_report(manifest))
	return {"manifest": manifest_path, "report": report_path}


func _build_report(manifest: Dictionary) -> String:
	var lines := [
		"# Planet Map Interaction Ownership QA",
		"",
		"Output: `%s`" % OUTPUT_DIR,
		"Screenshot target: `%s`" % SCREENSHOT_PATH,
		"",
		"| Case | Fixture | District | Selected Signal | Double Signal | Focus | Projection | Cutover | Legacy Fallback | Passed | Notes |",
		"| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |",
	]
	var records: Array = manifest.get("records", []) if manifest.get("records", []) is Array else []
	for record_variant in records:
		var record: Dictionary = record_variant if record_variant is Dictionary else {}
		lines.append("| %s | %s | %d | %s | %s | %s | %s | %s | %s | %s | %s |" % [
			str(record.get("case_id", "")),
			str(record.get("fixture_id", "")),
			int(record.get("clicked_district", -1)),
			str(record.get("selected_signal_received", false)),
			str(record.get("double_click_signal_received", false)),
			str(record.get("focus_checked", false)),
			str(record.get("projection_sync_checked", false)),
			str(record.get("cutover_enabled", false)),
			str(record.get("legacy_fallback_used", false)),
			str(record.get("passed", false)),
			str(record.get("notes", "")),
		])
	return "\n".join(lines)


func _passed_count(records: Array) -> int:
	var count := 0
	for record_variant in records:
		var record: Dictionary = record_variant if record_variant is Dictionary else {}
		if bool(record.get("passed", false)):
			count += 1
	return count


func _settle_frames(frame_count: int) -> void:
	for _frame in range(frame_count):
		await get_tree().process_frame


func _set_status(text: String) -> void:
	if status_label != null:
		status_label.text = text
