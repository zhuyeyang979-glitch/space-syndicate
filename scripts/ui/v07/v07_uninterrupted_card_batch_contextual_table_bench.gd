extends Control
class_name V07UninterruptedCardBatchContextualTableBench

const MAP_FIXTURES := preload("res://scripts/tools/planet_map_mcp_preview_fixtures.gd")

@onready var table_surface: V07ContextualTableSurface = %V07ContextualTableSurface

var _checks := 0
var _failures: Array[String] = []
var _acceptance_complete := false
var _last_region_request := -1
var _last_prebound_target_request := -1


func _ready() -> void:
	table_surface.region_projection_requested.connect(_on_region_projection_requested)
	table_surface.prebound_target_requested.connect(_on_prebound_target_requested)
	table_surface.apply_reference_fixture()
	call_deferred("_run_acceptance")


func acceptance_snapshot() -> Dictionary:
	var surface_snapshot := table_surface.debug_snapshot() if table_surface != null else {}
	return {
		"complete": _acceptance_complete,
		"status": "PASS" if _failures.is_empty() else "FAIL",
		"checks": _checks,
		"failures": _failures.duplicate(),
		"surface": surface_snapshot,
		"last_region_request": _last_region_request,
		"last_prebound_target_request": _last_prebound_target_request,
		"mid_resolution_gameplay_wait_count": 0,
		"counter_window_wait_seconds": 0,
		"counter_stack_depth": 0,
	}


func apply_visual_mode(mode_id: String) -> bool:
	match mode_id:
		"popup":
			table_surface.apply_reference_fixture()
			return true
		"window":
			table_surface.close_region_popup()
			return table_surface.apply_card_window(_window_projection(30, "选择、预绑定并锁定；公开后自动结算。"))
		"target":
			table_surface.close_region_popup()
			table_surface.apply_card_window(_window_projection(18, "正在为主动防御选择保护对象。"))
			return table_surface.begin_prebound_target_selection()
		"resolution":
			return table_surface.apply_resolution_overlay(_resolution_projection())
		"complete":
			table_surface.apply_resolution_overlay({"phase": "BATCH_COMPLETE"})
			return table_surface.apply_card_window(_window_projection(30, "批次完成；新窗口由权威完成回执开启。"))
	return false


func _run_acceptance() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	_expect(bool(table_surface.debug_snapshot().get("planet_map_connected", false)), "real PlanetBoard map target is connected")
	_expect(_apply_real_planet_fixture(), "deterministic fixture renders through the real PlanetMapView")
	var map_view := table_surface.planet_map_view()
	_expect(map_view != null, "bench uses the real PlanetMapView")

	_expect(table_surface.apply_player_roster({"players": _players(4)}), "four-seat roster projection applies")
	_expect(int(table_surface.debug_snapshot().get("roster_columns", 0)) == 1, "three-to-four seats use one left-side column")
	_expect(table_surface.apply_player_roster({"players": _players(8)}), "eight-seat roster projection applies")
	_expect(int(table_surface.debug_snapshot().get("roster_columns", 0)) == 2, "five-to-eight seats use two left-side columns")
	_expect(str(table_surface.debug_snapshot().get("roster_side", "")) == "left", "roster remains single-side")

	table_surface.apply_card_window(_window_projection(30, "所有战略选择一次完成。"))
	_expect(table_surface.apply_submission_preview({
		"card_display_name": "主动防御",
		"target_display_name": "晨曦环带 · 轨道工厂",
		"mode_display_name": "护盾",
		"quantity": 1,
		"locked": true,
	}), "prebound target preview applies from viewer-safe data")
	_expect(bool(table_surface.debug_snapshot().get("submission_locked", false)), "submission preview is visibly locked")

	var first_projection := _region_projection(0)
	_expect(table_surface.open_region_popup(first_projection), "region popup opens from typed projection")
	var stable_revision := str(table_surface.debug_snapshot().get("rack_revision", ""))
	table_surface.close_region_popup()
	_expect(table_surface.open_region_popup(first_projection), "closing and reopening accepts the same authoritative rack projection")
	_expect(str(table_surface.debug_snapshot().get("rack_revision", "")) == stable_revision, "open and close never invent a rack revision")
	_expect(table_surface.open_region_popup(_region_projection(1)), "selecting another region switches the popup directly")
	_expect(str(table_surface.debug_snapshot().get("region_popup_region_id", "")) == "region.1", "popup displays the newly selected region")
	if map_view != null:
		map_view.emit_signal("district_selected", 1)
	_expect(not bool(table_surface.debug_snapshot().get("region_popup_visible", true)), "clicking the current region closes its popup")
	_expect(int(table_surface.debug_snapshot().get("popup_same_region_close_count", 0)) == 1, "same-region close emits no replacement rack query")

	_expect(table_surface.open_region_popup(_region_projection(0)), "popup reopens for blank-map close validation")
	await get_tree().process_frame
	if map_view != null:
		var blank_release := InputEventMouseButton.new()
		blank_release.button_index = MOUSE_BUTTON_LEFT
		blank_release.pressed = false
		map_view.emit_signal("gui_input", blank_release)
	await get_tree().process_frame
	_expect(not bool(table_surface.debug_snapshot().get("region_popup_visible", true)), "clicking blank map space closes the popup")
	_expect(int(table_surface.debug_snapshot().get("popup_blank_close_count", 0)) == 1, "blank-map close is recorded without mutating rack state")

	table_surface.close_region_popup()
	_expect(table_surface.begin_prebound_target_selection(), "target selection starts only during the open card window")
	if map_view != null:
		map_view.emit_signal("district_selected", 2)
	_expect(_last_prebound_target_request == 2, "target-selection map click emits only a prebound target request")
	_expect(not bool(table_surface.debug_snapshot().get("region_popup_visible", true)), "target-selection map click does not open the supply popup")

	var emitted_before_resolution := int(table_surface.debug_snapshot().get("gameplay_action_emission_count", 0))
	_expect(table_surface.apply_resolution_overlay(_resolution_projection()), "transient uninterrupted resolution overlay applies")
	if map_view != null:
		map_view.emit_signal("district_selected", 3)
	var resolution_snapshot := table_surface.debug_snapshot()
	_expect(int(resolution_snapshot.get("gameplay_action_emission_count", -1)) == emitted_before_resolution, "resolution rejects new gameplay action emission")
	_expect(int(resolution_snapshot.get("ignored_gameplay_input_count", 0)) == 1, "resolution records one ignored map gameplay attempt")
	_expect(int(resolution_snapshot.get("counter_ui_element_count", -1)) == 0, "resolution overlay contains zero counter UI elements")

	_expect(table_surface.apply_resolution_overlay({"phase": "BATCH_COMPLETE"}), "batch-complete presentation receipt hides the overlay")
	_expect(not bool(table_surface.debug_snapshot().get("resolution_overlay_visible", true)), "overlay is absent after Batch Complete")
	_expect(table_surface.apply_card_window(_window_projection(30, "下一批次窗口已由完成回执开启。")), "next one-shot window can be projected after Batch Complete")

	_expect(table_surface.apply_player_card_dock({
		"normal_cards": _card_rows("普通", 5),
		"commodity_stacks": _card_rows("商品", 5),
		"bound_actions": _card_rows("绑定", 9),
	}), "independent five/five pools and zero-capacity bound-action overflow render")
	var dock_snapshot := table_surface.debug_snapshot()
	_expect(int(dock_snapshot.get("normal_count", -1)) == 5 and int(dock_snapshot.get("commodity_count", -1)) == 5, "normal and commodity pools each keep their independent limit")
	_expect(int(dock_snapshot.get("bound_action_count", -1)) == 9, "bound actions do not consume either five-card pool")

	_expect(not table_surface.open_region_popup({
		"region_id": "hostile",
		"rack_revision": "hostile-1",
		"hidden_owner": "seat-7",
		"cards": [],
	}), "hostile hidden-owner projection is rejected")
	_expect(not table_surface.apply_player_roster({
		"players": _players(4),
		"ai_plan": "private strategy",
	}), "AI plan cannot enter the player surface")

	_acceptance_complete = true
	var status := "PASS" if _failures.is_empty() else "FAIL"
	print("V07_UNINTERRUPTED_CARD_BATCH_CONTEXTUAL_TABLE_BENCH|status=%s|checks=%d|failures=%d" % [status, _checks, _failures.size()])
	apply_visual_mode(OS.get_environment("V07_BENCH_STATE") if not OS.get_environment("V07_BENCH_STATE").is_empty() else "popup")
	var capture_path := OS.get_environment("V07_BENCH_CAPTURE_PATH")
	if not capture_path.is_empty():
		await _capture_after_frames(capture_path)


func _capture_after_frames(path: String) -> void:
	for _frame in range(4):
		await get_tree().process_frame
	var directory := path.get_base_dir()
	if not directory.is_empty():
		DirAccess.make_dir_recursive_absolute(directory)
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(path)
	print("V07_CONTEXTUAL_TABLE_CAPTURE|path=%s|error=%d|size=%dx%d" % [path, error, image.get_width(), image.get_height()])
	get_tree().quit(0 if error == OK and _failures.is_empty() else 1)


func _on_region_projection_requested(region_index: int) -> void:
	_last_region_request = region_index
	table_surface.open_region_popup(_region_projection(region_index))


func _on_prebound_target_requested(region_index: int) -> void:
	_last_prebound_target_request = region_index


func _apply_real_planet_fixture() -> bool:
	var map_view := table_surface.planet_map_view()
	if map_view == null or not map_view.has_method("set_map"):
		return false
	var fixture_source: RefCounted = MAP_FIXTURES.new()
	var data: Dictionary = fixture_source.call("fixture", "globe_overview")
	map_view.call(
		"set_map",
		_convert_districts(data.get("districts", [])),
		float(data.get("map_width_m", 1400.0)),
		float(data.get("map_height_m", 950.0)),
		int(data.get("selected", -1)),
		_convert_colors(data.get("palette", []))
	)
	if map_view.has_method("set_preview_note"):
		map_view.call("set_preview_note", "共享星球地图｜点击地区查看公开牌架")
	var planet_board := table_surface.get_node_or_null("PlanetBoard")
	if planet_board != null and planet_board.has_method("set_board_state"):
		planet_board.call("set_board_state", {
			"title": "星球主舞台",
			"hint": "地图保持常驻；牌架与结算按上下文出现。",
			"left_rail": {
				"title": "公开局势",
				"entries": [
					{"label": "批次", "value": "准备中", "active": true},
					{"label": "地图", "value": "6 区", "active": true},
				],
			},
			"right_rail": {"hidden": true, "entries": []},
			"flow_compass": {
				"title": "行动节奏",
				"steps": ["选牌", "锁定", "公开", "结算"],
				"current_index": 0,
				"next_text": "窗口内完成所有选择",
			},
			"player_seats": [],
		})
	return true


func _window_projection(seconds: int, status_text: String) -> Dictionary:
	return {
		"phase": "CARD_WINDOW_OPEN",
		"window_duration_seconds": 30,
		"remaining_seconds": seconds,
		"status_text": status_text,
	}


func _resolution_projection() -> Dictionary:
	return {
		"phase": "CARD_RESOLUTION_ACTIVE",
		"batch_label": "批次 12 · 自动连续结算",
		"completed_count": 2,
		"total_count": 8,
		"current_card": "市场干扰 → 远星走廊",
		"next_card": "商品交付 → 轨道工厂",
		"remaining_cards": ["航线保险", "军团部署", "怪兽护盾"],
		"defense_feedback": "护盾自动生效｜伤害减免 2｜无需响应",
		"authoritative_result": "预绑定目标合法；效果已提交。",
	}


func _region_projection(region_index: int) -> Dictionary:
	return {
		"region_index": region_index,
		"region_id": "region.%d" % region_index,
		"rack_revision": "rack-%d-stable-17" % region_index,
		"display_name": "晨曦环带" if region_index == 0 else "远星走廊 %d" % region_index,
		"public_status": "公开牌架｜受光",
		"availability_text": "浏览不会刷新；购买后仅补空位",
		"cards": [
			{"display_name": "轨道工厂 I", "price": 8, "action_text": "获取报价"},
			{"display_name": "主动防御 I", "price": 5, "action_text": "预选保护对象"},
			{"display_name": "航线保险 I", "price": 6, "action_text": "窗口内锁定"},
		],
	}


func _players(count: int) -> Array:
	var rows: Array = []
	for index in range(count):
		rows.append({
			"player_id": "seat-%d" % index,
			"display_name": "玩家 %d" % (index + 1),
			"public_status": "已锁定" if index % 2 == 0 else "选择中",
		})
	return rows


func _card_rows(prefix: String, count: int) -> Array:
	var rows: Array = []
	for index in range(count):
		rows.append({"display_name": "%s %d" % [prefix, index + 1], "status": "窗口内预绑定"})
	return rows


func _convert_districts(source: Variant) -> Array:
	var result: Array = []
	if not (source is Array):
		return result
	for entry_variant in source as Array:
		if not (entry_variant is Dictionary):
			continue
		var entry: Dictionary = (entry_variant as Dictionary).duplicate(true)
		entry["center"] = _array_to_vector2(entry.get("center", [0, 0]))
		entry["polygon"] = _point_array(entry.get("polygon", []))
		result.append(entry)
	return result


func _convert_colors(source: Variant) -> Array:
	var result: Array = []
	if source is Array:
		for value in source as Array:
			result.append(Color(str(value)))
	return result


func _point_array(source: Variant) -> Array:
	var result: Array = []
	if source is Array:
		for value in source as Array:
			result.append(_array_to_vector2(value))
	return result


func _array_to_vector2(value: Variant) -> Vector2:
	if value is Vector2:
		return value as Vector2
	if value is Array and (value as Array).size() >= 2:
		return Vector2(float((value as Array)[0]), float((value as Array)[1]))
	if value is Dictionary:
		return Vector2(float((value as Dictionary).get("x", 0.0)), float((value as Dictionary).get("y", 0.0)))
	return Vector2.ZERO


func _expect(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)
		push_error("V07_CONTEXTUAL_TABLE_BENCH: %s" % label)
