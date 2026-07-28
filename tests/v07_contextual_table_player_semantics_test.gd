extends SceneTree

const SURFACE_SCENE := preload("res://scenes/ui/v07/V07ContextualTableSurface.tscn")
const BENCH_SCENE := preload("res://scenes/tools/V07UninterruptedCardBatchContextualTableBench.tscn")

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1366, 768)
	var surface := SURFACE_SCENE.instantiate() as V07ContextualTableSurface
	_expect(surface != null, "V0.7 contextual table surface instantiates")
	if surface == null:
		_finish()
		return
	root.add_child(surface)
	await process_frame
	await process_frame
	var initial := surface.debug_snapshot()
	_expect(int(initial.get("roster_count", -1)) == 0, "reusable player surface owns no default gameplay fixture")
	_expect(not bool(initial.get("card_window_visible", true)) and not bool(initial.get("submission_summary_visible", true)) and not bool(initial.get("region_popup_visible", true)), "reusable surface starts without fictional window, target, or rack state")
	_expect(bool(initial.get("planet_map_connected", false)), "surface uses the real map interaction implementation")
	_expect(bool(initial.get("reference_planet_stage", false)), "surface owns a V0.7 reference-only planet stage")
	_expect(int(initial.get("reference_player_roster_source_count", -1)) == 1, "one left-side roster is the only player placement source")
	_expect(int(initial.get("orbit_player_marker_count", -1)) == 0, "reference planet renders zero orbit player markers")
	_expect(int(initial.get("orbit_radial_spoke_count", -1)) == 0, "reference planet renders zero positional radial spokes")
	_expect(int(initial.get("left_right_seat_layer_count", -1)) == 0, "reference planet contains zero left or right seat layers")
	_expect(not bool(initial.get("legacy_draw_fallback_enabled", true)), "reference planet cannot fall back to the old table draw path")

	for count in [3, 4, 5, 8]:
		_expect(surface.apply_player_roster({"players": _players(count)}), "%d-seat public roster applies" % count)
		var expected_columns := 1 if count <= 4 else 2
		_expect(int(surface.debug_snapshot().get("roster_columns", 0)) == expected_columns, "%d-seat roster uses %d left-side column(s)" % [count, expected_columns])
	_expect(str(surface.debug_snapshot().get("roster_side", "")) == "left", "player avatars have one left-side roster only")
	var reversed_players := _players(8)
	reversed_players.reverse()
	_expect(surface.apply_player_roster({"players": reversed_players}), "roster accepts a differently delivered authorized projection")
	_expect(surface.debug_snapshot().get("roster_player_ids", []) == ["seat-0", "seat-1", "seat-2", "seat-3", "seat-4", "seat-5", "seat-6", "seat-7"], "explicit public order remains stable when delivery order changes")
	_expect(bool(surface.debug_snapshot().get("roster_focus_links_valid", false)), "all roster entries expose deterministic keyboard navigation")
	var inspected_players: Array[String] = []
	surface.player_inspection_requested.connect(func(player_id: String) -> void:
		inspected_players.append(player_id)
	)
	_expect(surface.request_player_inspection("seat-4"), "roster entry requests public player inspection")
	_expect(inspected_players == ["seat-4"] and str(surface.debug_snapshot().get("last_inspected_player_id", "")) == "seat-4", "inspection emits only the authorized public player id")

	_expect(not surface.apply_card_window({
		"phase": "CARD_WINDOW_OPEN",
		"window_duration_seconds": 31,
		"remaining_seconds": 30,
	}), "player surface rejects a non-30-second authored window")
	_expect(surface.apply_card_window(_window_projection(30)), "30-second one-shot window projects")
	_expect(surface.apply_submission_preview({
		"card_display_name": "商品交付",
		"target_display_name": "轨道工厂 · 商品槽 2",
		"mode_display_name": "安装",
		"quantity": 2,
		"locked": true,
	}), "commodity target, slot, mode and quantity have one locked viewer projection")
	_expect(bool(surface.debug_snapshot().get("submission_locked", false)), "prebound selection is visibly locked before reveal")

	var region_requests: Array[int] = []
	var target_requests: Array[int] = []
	surface.region_projection_requested.connect(func(index: int) -> void:
		region_requests.append(index)
	)
	surface.prebound_target_requested.connect(func(index: int) -> void:
		target_requests.append(index)
	)
	var map_view := surface.planet_map_view()
	_expect(map_view != null, "map input remains available in the Bench surface")
	if map_view != null:
		map_view.emit_signal("district_selected", 1)
	_expect(region_requests == [1], "ordinary map click requests a presentation projection without gameplay mutation")

	var first_region := _region_projection(1, "stable-rack-11")
	_expect(surface.open_region_popup(first_region), "typed region rack projection opens translucent contextual popup")
	surface.close_region_popup()
	_expect(surface.open_region_popup(first_region), "popup can reopen without requesting a redraw")
	_expect(str(surface.debug_snapshot().get("rack_revision", "")) == "stable-rack-11", "open and close preserve authoritative rack revision")
	_expect(surface.open_region_popup(_region_projection(2, "stable-rack-22")), "another region directly replaces popup content")
	_expect(str(surface.debug_snapshot().get("region_popup_region_id", "")) == "region.2", "direct region switch projects the selected region")
	if map_view != null:
		map_view.emit_signal("district_selected", 2)
	_expect(not bool(surface.debug_snapshot().get("region_popup_visible", true)), "clicking the currently open region closes its popup")
	_expect(region_requests == [1], "same-region close emits no replacement projection request")

	_expect(surface.open_region_popup(first_region), "popup reopens for blank-map close behavior")
	await process_frame
	if map_view != null:
		var blank_release := InputEventMouseButton.new()
		blank_release.button_index = MOUSE_BUTTON_LEFT
		blank_release.pressed = false
		map_view.emit_signal("gui_input", blank_release)
	await process_frame
	_expect(not bool(surface.debug_snapshot().get("region_popup_visible", true)), "blank map click closes the contextual popup")
	_expect(int(surface.debug_snapshot().get("popup_blank_close_count", 0)) == 1, "blank close is typed presentation behavior only")

	surface.close_region_popup()
	_expect(surface.begin_prebound_target_selection(), "window permits prebound target-selection mode")
	if map_view != null:
		map_view.emit_signal("district_selected", 3)
	_expect(target_requests == [3], "target-selection click emits the same precommit path")
	_expect(not bool(surface.debug_snapshot().get("region_popup_visible", true)), "target selection never opens the rack popup")

	var gameplay_before := int(surface.debug_snapshot().get("gameplay_action_emission_count", 0))
	_expect(surface.apply_resolution_overlay(_resolution_projection()), "strict sequential resolution projection applies")
	if map_view != null:
		map_view.emit_signal("district_selected", 4)
	var resolving := surface.debug_snapshot()
	_expect(bool(resolving.get("resolution_overlay_visible", false)), "resolution sequence appears only as a transient overlay")
	_expect(int(resolving.get("gameplay_action_emission_count", -1)) == gameplay_before, "resolution map input emits no gameplay action")
	_expect(int(resolving.get("counter_ui_element_count", -1)) == 0, "player resolution surface has no counter UI")
	_expect(int(resolving.get("ignored_gameplay_input_count", 0)) == 1, "blocked resolution input is observable without affecting authority")
	_expect(surface.apply_resolution_overlay({"phase": "BATCH_COMPLETE"}), "Batch Complete receipt closes the transient overlay")
	var complete_snapshot := surface.debug_snapshot()
	_expect(not bool(complete_snapshot.get("resolution_overlay_visible", true)) and str(complete_snapshot.get("interaction_mode", "")) == V07ContextualTableSurface.MODE_TABLE_MAP, "Batch Complete returns the map to the primary interaction mode")
	if map_view != null:
		map_view.emit_signal("district_selected", 5)
	_expect(region_requests == [1, 5], "map input resumes as a presentation query only after Batch Complete")

	_expect(surface.apply_player_card_dock({
		"normal_cards": _cards("普通", 5),
		"commodity_stacks": _cards("商品", 5),
		"bound_actions": _cards("绑定", 12),
	}), "three independent card pools render with bound-action overflow")
	var dock := surface.debug_snapshot()
	_expect(int(dock.get("normal_count", -1)) == 5, "ordinary hand shows its independent five-card cap")
	_expect(int(dock.get("commodity_count", -1)) == 5, "commodity inventory shows its independent five-slot cap")
	_expect(int(dock.get("bound_action_count", -1)) == 12, "bound actions have zero capacity cost")
	_expect(not surface.apply_player_card_dock({
		"normal_cards": _cards("普通", 6),
		"commodity_stacks": [],
		"bound_actions": [],
	}), "ordinary hand overflow is rejected")
	_expect(not surface.apply_player_card_dock({
		"normal_cards": [],
		"commodity_stacks": _cards("商品", 6),
		"bound_actions": [],
	}), "commodity inventory overflow is rejected")

	_expect(not surface.apply_player_roster({"players": _players(4), "ai_plan": "secret"}), "AI private plan fails closed at player projection boundary")
	_expect(not surface.open_region_popup({
		"region_id": "region.hostile",
		"rack_revision": "hostile",
		"future_rack": ["leak"],
		"cards": [],
	}), "future rack information fails closed")
	_expect(not surface.apply_submission_preview({
		"card_display_name": "攻击",
		"target_display_name": "隐藏目标",
		"hidden_owner_id": "seat-7",
	}), "hidden owner cannot enter the submission projection")
	var hostile_node := Node.new()
	_expect(not surface.apply_player_roster({"players": _players(3), "hostile_object": hostile_node}), "Node and Object references are rejected")
	hostile_node.free()

	surface.queue_free()
	await process_frame

	var bench := BENCH_SCENE.instantiate() as V07UninterruptedCardBatchContextualTableBench
	root.add_child(bench)
	for _frame in range(6):
		await process_frame
	var acceptance := bench.acceptance_snapshot()
	_expect(bool(acceptance.get("complete", false)) and str(acceptance.get("status", "")) == "PASS", "production-wiring Bench completes all contextual table checks")
	_expect(int(acceptance.get("mid_resolution_gameplay_wait_count", -1)) == 0, "Bench records zero mid-resolution gameplay waits")
	_expect(int(acceptance.get("counter_window_wait_seconds", -1)) == 0 and int(acceptance.get("counter_stack_depth", -1)) == 0, "Bench records no counter window or stack")
	bench.queue_free()
	await process_frame
	_finish()


func _window_projection(seconds: int) -> Dictionary:
	return {
		"phase": "CARD_WINDOW_OPEN",
		"window_duration_seconds": 30,
		"remaining_seconds": seconds,
		"status_text": "窗口内一次选择，锁定后不再修改。",
	}


func _resolution_projection() -> Dictionary:
	return {
		"phase": "CARD_RESOLUTION_ACTIVE",
		"batch_label": "批次 7",
		"completed_count": 1,
		"total_count": 4,
		"current_card": "主动防御 → 轨道工厂",
		"next_card": "市场干扰 → 晨曦环带",
		"remaining_cards": ["商品交付", "军团部署"],
		"defense_feedback": "护盾自动生效｜无需响应",
		"authoritative_result": "预绑定目标合法；效果已提交。",
	}


func _region_projection(index: int, revision: String) -> Dictionary:
	return {
		"region_index": index,
		"region_id": "region.%d" % index,
		"rack_revision": revision,
		"display_name": "地区 %d" % index,
		"public_status": "公开牌架",
		"availability_text": "浏览不刷新",
		"cards": [{"display_name": "主动防御 I", "price": 5, "action_text": "预选目标"}],
	}


func _players(count: int) -> Array:
	var rows: Array = []
	for index in range(count):
		rows.append({
			"player_id": "seat-%d" % index,
			"display_name": "玩家 %d" % (index + 1),
			"public_status": "已锁定" if index % 2 == 0 else "选择中",
			"public_order_index": index,
		})
	return rows


func _cards(prefix: String, count: int) -> Array:
	var rows: Array = []
	for index in range(count):
		rows.append({"display_name": "%s %d" % [prefix, index + 1]})
	return rows


func _expect(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)


func _finish() -> void:
	var status := "PASS" if _failures.is_empty() else "FAIL"
	print("V07_CONTEXTUAL_TABLE_PLAYER_SEMANTICS_TEST|status=%s|checks=%d|failures=%d" % [status, _checks, _failures.size()])
	for failure in _failures:
		push_error("V07_CONTEXTUAL_TABLE_PLAYER_SEMANTICS_TEST: %s" % failure)
	quit(0 if _failures.is_empty() else 1)
