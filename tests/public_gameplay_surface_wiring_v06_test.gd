extends SceneTree

const TABLE_SERVICE_SCENE := preload("res://scenes/runtime/GameTableViewModelRuntimeService.tscn")
const CARD_PRESENTATION_SCENE := preload("res://scenes/runtime/CardPresentationRuntimeService.tscn")
const SCHEDULER_SCENE := preload("res://scenes/runtime/ForcedDecisionRuntimeScheduler.tscn")
const GAME_SCREEN_SCENE := preload("res://scenes/ui/GameScreen.tscn")

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var card_presentation := CARD_PRESENTATION_SCENE.instantiate()
	var table_service := TABLE_SERVICE_SCENE.instantiate()
	var scheduler := SCHEDULER_SCENE.instantiate()
	var screen := GAME_SCREEN_SCENE.instantiate() as Control
	root.add_child(card_presentation)
	root.add_child(table_service)
	root.add_child(scheduler)
	root.add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	table_service.call("configure", card_presentation)
	scheduler.call("configure", ["monster_wager", "counter_response", "other_choice"])
	await process_frame

	var bid_state := _bid_state("public_bid")
	scheduler.call("sync_candidates", [], bid_state)
	var active_public_bid := scheduler.call("active_decision", 0) as Dictionary
	_expect(str(active_public_bid.get("priority_group", "")) == "public_bid", "authoritative phase derives the public_bid scheduler candidate")
	var table := _compose_table(table_service, active_public_bid, bid_state)
	_expect(str((table.get("active_forced_decision", {}) as Dictionary).get("kind", "")) == "public_bid", "GameTable ViewModel forwards the viewer-filtered active decision")
	_expect(str(((table.get("player_board", {}) as Dictionary).get("bid_board", {}) as Dictionary).get("phase_id", "")) == "public_bid", "public bid state reaches the normalized TableSnapshot only with matching scheduler authority")
	var route_surface: Dictionary = table.get("optional_route_presentation", {}) as Dictionary
	_expect(bool(route_surface.get("source_bound", false)) and bool(route_surface.get("available", false)), "actual-flow public source is bound into TableSnapshot")
	var geometry: Dictionary = route_surface.get("route_geometry_by_route_id", {}) as Dictionary
	_expect(geometry.keys() == ["route:actual"], "route geometry is filtered to route IDs referenced by committed public flow")
	_expect(not _contains_forbidden_key(table), "table surface projection contains no owner, candidate, cash, hand, or AI-plan fields")

	screen.call("apply_state", table)
	await process_frame
	var overlay: Node = screen.call("get_overlay_host") as Node
	_expect(bool(overlay.call("public_bid_visible")), "transient BidBoard appears for the selected public_bid decision")
	_expect(_visible_forced_panel_count(overlay) == 1, "1280 table shows only one actionable forced surface")
	var bid_panel := screen.find_child("PublicBidDecisionPanel", true, false) as Control
	var action_dock := screen.find_child("PlayerMainActionDock", true, false) as Control
	var viewport_rect := root.get_visible_rect()
	var bid_rect := bid_panel.get_global_rect() if bid_panel != null else Rect2()
	var bid_inside_viewport := bid_rect.position.x >= -0.5 \
		and bid_rect.position.y >= -0.5 \
		and bid_rect.end.x <= viewport_rect.end.x + 0.5 \
		and bid_rect.end.y <= viewport_rect.end.y + 0.5
	_expect(root.size == Vector2i(1280, 720) and bid_panel != null and bid_panel.visible and bid_inside_viewport, "public bid fits inside 1280×720")
	_expect(action_dock != null and bid_rect.intersection(action_dock.get_global_rect()).get_area() <= 0.01, "public bid does not cover the primary action dock")

	var map_view := screen.call("get_embedded_map_view") as Control
	map_view.call("set_map", _districts(), 1400.0, 950.0, -1, [Color("#38bdf8"), Color("#22c55e"), Color("#f59e0b")])
	await process_frame
	_expect(int((map_view.call("optional_route_presentation_snapshot") as Dictionary).get("visible_route_count", -1)) == 0, "actual routes remain hidden by default after production TableSnapshot wiring")
	map_view.call("set_optional_route_selection", "晶雾")
	await process_frame
	var route_debug := map_view.call("optional_route_presentation_snapshot") as Dictionary
	_expect(int(route_debug.get("visible_route_count", -1)) == 1, "local opt-in reveals the committed commodity route")
	var markers: Array = map_view.get("trade_route_markers")
	var points: Array = (markers[0] as Dictionary).get("points", []) if not markers.is_empty() else []
	_expect(points == [Vector2(120, 200), Vector2(310, 320), Vector2(500, 220)], "ordered public region IDs materialize against the live map instead of candidate screen geometry")

	scheduler.call("sync_candidates", [], _bid_state("planning"))
	var planning_active := scheduler.call("active_decision", 0) as Dictionary
	var planning_table := _compose_table(table_service, planning_active, _bid_state("planning"))
	screen.call("apply_state", planning_table)
	await process_frame
	_expect(planning_active.is_empty() and not bool(overlay.call("public_bid_visible")), "leaving public_bid removes the candidate and closes the full bid surface")

	var private_choice := {
		"id": "private_target_1",
		"kind": "player_target_choice",
		"priority_group": "other_choice",
		"owner_player_index": 1,
		"visibility_scope": "private",
		"presentation_surface": "overlay",
		"opened_sequence": 8.0,
		"blocks_global_time": false,
		"blocks_player_actions": true,
		"blocks_card_resolution": false,
		"source_ref": "private_target",
	}
	scheduler.call("sync_candidates", [private_choice], bid_state)
	var hidden_active := scheduler.call("active_decision", 0) as Dictionary
	var hidden_table := _compose_table(table_service, hidden_active, bid_state)
	screen.call("apply_state", hidden_table)
	await process_frame
	_expect(str((hidden_table.get("active_forced_decision", {}) as Dictionary).get("kind", "")) == "private_forced_decision", "non-owner receives only the viewer-filtered waiting hint")
	_expect(_visible_forced_panel_count(overlay) == 0 and not bool(overlay.call("public_bid_visible")), "a higher private decision suppresses public bid without exposing another player's choice")
	_expect(not _contains_forbidden_key(hidden_table), "private waiting projection exposes no owner index or source reference")

	var visible_active := scheduler.call("active_decision", 1) as Dictionary
	var owner_table := _compose_table(table_service, visible_active, bid_state, {
		"id": "private_target_1",
		"kind": "player_target_choice",
		"title": "选择目标玩家",
		"body": "仅当前玩家可见。",
		"actions": [{"id": "target_player_2", "label": "选择"}],
	})
	screen.call("apply_state", owner_table)
	await process_frame
	_expect(_visible_forced_panel_count(overlay) == 1 and not bool(overlay.call("public_bid_visible")), "decision owner sees exactly one matching private target overlay")
	screen.call("apply_state", planning_table)
	await process_frame
	_expect(_visible_forced_panel_count(overlay) == 0, "resolved decision releases the overlay and its layout footprint")

	screen.queue_free()
	scheduler.queue_free()
	table_service.queue_free()
	card_presentation.queue_free()
	await process_frame
	_finish()


func _compose_table(table_service: Node, active: Dictionary, bid: Dictionary, temporary_decision: Dictionary = {}) -> Dictionary:
	return table_service.call("compose_table", {
		"table_source": {
			"player_board": {"hand_cards": [], "actions": [], "quick_actions": []},
			"temporary_decision": temporary_decision,
		},
		"card_surfaces": {},
		"viewer_surfaces": {
			"active_forced_decision": active,
			"public_bid": bid,
			"optional_route_presentation": _route_payload(),
		},
	}) as Dictionary


func _route_payload() -> Dictionary:
	return {
		"source_bound": true,
		"world_effective_seconds": 120.0,
		"public_flow_snapshot": {
			"available": true,
			"public_revision": 8,
			"selected_commodity_id": "",
			"rows": [
				_flow_row("flow-actual", "route:actual"),
			],
		},
		"route_geometry_by_route_id": {
			"route:actual": {
				"ordered_region_ids": ["region.a", "region.b", "region.c"],
				"transport_modes": ["land"],
			},
			"route:future": {
				"ordered_region_ids": ["region.a", "region.c"],
				"transport_modes": ["air"],
				"candidate_id": "private-future",
			},
		},
	}


func _flow_row(event_id: String, route_id: String) -> Dictionary:
	return {
		"flow_event_id": event_id,
		"public_revision": 8,
		"commodity_id": "晶雾",
		"from_region_id": "region.a",
		"to_region_id": "region.c",
		"flow_kind": "market_sale",
		"display_label": "A → C",
		"route_id": route_id,
		"transport_modes": ["land"],
		"delivered_units_band": "medium",
		"capacity_limited": false,
		"congested": false,
		"last_active_world_effective": 119.0,
		"activity_state": "current_tick",
		"ambient_one_hop": false,
		"low_emphasis": false,
	}


func _bid_state(phase_id: String) -> Dictionary:
	return {
		"title": "牌序竞价",
		"phase_id": phase_id,
		"phase": "公开竞价" if phase_id == "public_bid" else "规划",
		"status": "只使用公开牌轨和当前玩家自己的行动。",
		"active": phase_id == "public_bid",
		"visible": true,
		"window_sequence": 4,
		"chips": [{"label": "本阶段", "state": "待确认"}],
		"track_links": [{"id": "track_select_1", "label": "领跑"}],
		"actions": [{"id": "card_group_ready", "label": "完成展示"}],
	}


func _districts() -> Array:
	return [
		{"region_id": "region.a", "name": "A", "center": Vector2(120, 200)},
		{"region_id": "region.b", "name": "B", "center": Vector2(310, 320)},
		{"region_id": "region.c", "name": "C", "center": Vector2(500, 220)},
	]


func _visible_forced_panel_count(overlay: Node) -> int:
	var count := 0
	for name in ["MonsterWagerDecisionPanel", "TemporaryChoiceDecisionPanel", "TemporaryDecisionModal", "PublicBidDecisionPanel"]:
		var control := overlay.find_child(name, true, false) as Control
		if control != null and control.visible:
			count += 1
	return count


func _contains_forbidden_key(value: Variant) -> bool:
	var forbidden := [
		"owner_player_index",
		"source_ref",
		"candidate_id",
		"route_candidates",
		"supplier_player_index",
		"true_owner",
		"hidden_owner",
		"owner_truth",
		"opponent_cash",
		"opponent_hand",
		"ai_plan",
		"ai_score",
	]
	if value is Dictionary:
		for key_variant in (value as Dictionary).keys():
			if forbidden.has(str(key_variant)) or _contains_forbidden_key((value as Dictionary).get(key_variant)):
				return true
	elif value is Array:
		for item_variant in value:
			if _contains_forbidden_key(item_variant):
				return true
	return false


func _expect(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)


func _finish() -> void:
	var status := "PASS" if _failures.is_empty() else "FAIL"
	print("PUBLIC_GAMEPLAY_SURFACE_WIRING_V06_TEST|status=%s|checks=%d|failures=%d" % [status, _checks, _failures.size()])
	for failure in _failures:
		push_error("PUBLIC_GAMEPLAY_SURFACE_WIRING_V06_TEST: %s" % failure)
	quit(0 if _failures.is_empty() else 1)
