extends Control
class_name PublicGameplaySurfaceWiringV06Bench

@onready var card_presentation: Node = %CardPresentationRuntimeService
@onready var table_service: Node = %GameTableViewModelRuntimeService
@onready var scheduler: Node = %ForcedDecisionRuntimeScheduler
@onready var game_screen: Control = %GameScreen
@onready var status_label: Label = %StatusLabel

var _checks := 0
var _failures: Array[String] = []
var _finished := false


func _ready() -> void:
	if not Engine.is_editor_hint():
		call_deferred("_run_bench")


func _run_bench() -> void:
	if get_window() != null:
		get_window().size = Vector2i(1280, 720)
	table_service.call("configure", card_presentation)
	scheduler.call("configure", ["monster_wager", "counter_response", "contract_response", "other_choice"])
	var bid := {
		"title": "牌序竞价",
		"phase_id": "public_bid",
		"phase": "公开竞价",
		"status": "当前公开阶段",
		"active": true,
		"visible": true,
		"window_sequence": 7,
		"chips": [{"label": "本阶段", "state": "待确认"}],
		"track_links": [{"id": "track_select_1", "label": "牌轨"}],
		"actions": [{"id": "card_group_ready", "label": "完成展示"}],
	}
	scheduler.call("sync_candidates", [], bid)
	var active := scheduler.call("active_decision", 0) as Dictionary
	var table := table_service.call("compose_table", {
		"table_source": {
			"player_board": {"hand_cards": [], "actions": [], "quick_actions": []},
		},
		"card_surfaces": {},
		"viewer_surfaces": {
			"active_forced_decision": active,
			"public_bid": bid,
			"optional_route_presentation": _route_payload(),
		},
	}) as Dictionary
	game_screen.call("apply_state", table)
	await get_tree().process_frame
	var overlay: Node = game_screen.call("get_overlay_host") as Node
	_check(bool(overlay.call("public_bid_visible")), "public_bid_visible")
	_check(_visible_forced_panel_count(overlay) == 1, "single_forced_surface")
	var bid_panel := game_screen.find_child("PublicBidDecisionPanel", true, false) as Control
	var action_dock := game_screen.find_child("PlayerMainActionDock", true, false) as Control
	var viewport_rect := get_viewport_rect()
	var bid_rect := bid_panel.get_global_rect() if bid_panel != null else Rect2()
	var bid_inside_viewport := bid_rect.position.x >= -0.5 \
		and bid_rect.position.y >= -0.5 \
		and bid_rect.end.x <= viewport_rect.end.x + 0.5 \
		and bid_rect.end.y <= viewport_rect.end.y + 0.5
	_check(bid_panel != null and bid_inside_viewport, "bid_inside_1280x720")
	_check(action_dock != null and bid_rect.intersection(action_dock.get_global_rect()).get_area() <= 0.01, "bid_avoids_primary_action")
	var map_view := game_screen.call("get_embedded_map_view") as Control
	map_view.call("set_map", _districts(), 1400.0, 950.0, -1, [Color("#38bdf8"), Color("#22c55e"), Color("#f59e0b")])
	await get_tree().process_frame
	_check(str((table.get("active_forced_decision", {}) as Dictionary).get("kind", "")) == "public_bid", "viewer_filtered_decision")
	var hidden_snapshot := map_view.call("optional_route_presentation_snapshot") as Dictionary
	_check(int(hidden_snapshot.get("visible_route_count", -1)) == 0, "routes_hidden_by_default")
	map_view.call("set_optional_route_selection", "晶雾")
	await get_tree().process_frame
	var visible_snapshot := map_view.call("optional_route_presentation_snapshot") as Dictionary
	_check(int(visible_snapshot.get("visible_route_count", -1)) == 1, "actual_route_visible_after_opt_in")
	_check(not _contains_forbidden_key(table), "privacy_allowlist")
	_finished = true
	var status := "PASS" if _failures.is_empty() else "FAIL"
	status_label.text = "C2 Public Surface Wiring %s | %d/%d" % [status, _checks - _failures.size(), _checks]
	print("PUBLIC_GAMEPLAY_SURFACE_WIRING_V06_BENCH|status=%s|checks=%d|failures=%d" % [status, _checks, _failures.size()])
	for failure in _failures:
		push_error("PUBLIC_GAMEPLAY_SURFACE_WIRING_V06_BENCH: %s" % failure)
	if DisplayServer.get_name().to_lower() == "headless":
		get_tree().quit(0 if _failures.is_empty() else 1)


func debug_snapshot() -> Dictionary:
	var map_view: Control = game_screen.call("get_embedded_map_view") as Control if game_screen != null else null
	var overlay: Node = game_screen.call("get_overlay_host") as Node if game_screen != null else null
	return {
		"finished": _finished,
		"status": "PASS" if _finished and _failures.is_empty() else ("FAIL" if _finished else "RUNNING"),
		"checks": _checks,
		"failures": _failures.duplicate(),
		"public_bid_visible": bool(overlay.call("public_bid_visible")) if overlay != null else false,
		"visible_forced_surface_count": _visible_forced_panel_count(overlay) if overlay != null else -1,
		"route_presentation": map_view.call("optional_route_presentation_snapshot") if map_view != null else {},
		"viewport_size": get_viewport_rect().size,
	}


func _route_payload() -> Dictionary:
	return {
		"source_bound": true,
		"world_effective_seconds": 90.0,
		"public_flow_snapshot": {
			"available": true,
			"public_revision": 3,
			"selected_commodity_id": "",
			"rows": [{
				"flow_event_id": "bench-flow",
				"public_revision": 3,
				"commodity_id": "晶雾",
				"from_region_id": "region.a",
				"to_region_id": "region.c",
				"flow_kind": "market_sale",
				"display_label": "A → C",
				"route_id": "route:bench",
				"transport_modes": ["land"],
				"delivered_units_band": "medium",
				"capacity_limited": false,
				"congested": false,
				"last_active_world_effective": 89.0,
				"activity_state": "current_tick",
				"ambient_one_hop": false,
				"low_emphasis": false,
			}],
		},
		"route_geometry_by_route_id": {
			"route:bench": {
				"ordered_region_ids": ["region.a", "region.b", "region.c"],
				"transport_modes": ["land"],
			},
		},
	}


func _districts() -> Array:
	return [
		{"region_id": "region.a", "name": "A", "center": Vector2(120, 200)},
		{"region_id": "region.b", "name": "B", "center": Vector2(310, 320)},
		{"region_id": "region.c", "name": "C", "center": Vector2(500, 220)},
	]


func _visible_forced_panel_count(overlay: Node) -> int:
	if overlay == null:
		return 0
	var count := 0
	for name in ["MonsterWagerDecisionPanel", "ContractResponseDecisionPanel", "TemporaryChoiceDecisionPanel", "TemporaryDecisionModal", "PublicBidDecisionPanel"]:
		var control := overlay.find_child(name, true, false) as Control
		if control != null and control.visible:
			count += 1
	return count


func _contains_forbidden_key(value: Variant) -> bool:
	var forbidden := ["owner_player_index", "source_ref", "candidate_id", "supplier_player_index", "true_owner", "hidden_owner", "owner_truth", "opponent_cash", "opponent_hand", "ai_plan", "ai_score"]
	if value is Dictionary:
		for key_variant in (value as Dictionary).keys():
			if forbidden.has(str(key_variant)) or _contains_forbidden_key((value as Dictionary).get(key_variant)):
				return true
	elif value is Array:
		for item_variant in value:
			if _contains_forbidden_key(item_variant):
				return true
	return false


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)
