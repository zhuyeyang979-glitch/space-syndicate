extends SceneTree

const OVERLAY_SCENE := preload("res://scenes/ui/OverlayLayer.tscn")
const GAME_SCREEN_SCENE := preload("res://scenes/ui/GameScreen.tscn")
const DRAWER_SCENE := preload("res://scenes/ui/DistrictSupplyDrawer.tscn")
const DISTRICT_NODE_SCENE := preload("res://scenes/ui/map/PlanetDistrictNode.tscn")
const MAP_SCENE := preload("res://scenes/ui/PlanetMapView.tscn")
const SCHEDULER_SCENE := preload("res://scenes/runtime/ForcedDecisionRuntimeScheduler.tscn")
const SUPPLY_SNAPSHOT_SCENE := preload("res://scenes/runtime/DistrictSupplySnapshotService.tscn")
const TABLE_SNAPSHOT_SCRIPT := preload("res://scripts/viewmodels/table_snapshot.gd")

var _checks := 0
var _failures: Array[String] = []


class RouteViewFake:
	extends Node
	var hidden := false

	func hide_optional_route_presentation() -> void:
		hidden = true


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	await _test_region_rack_intent()
	await _test_public_bid_and_forced_back()
	_test_scheduler_public_bid_priority()
	await _test_game_screen_layout_and_zero_placeholder()
	_finish()


func _test_region_rack_intent() -> void:
	var drawer := DRAWER_SCENE.instantiate() as Control
	root.add_child(drawer)
	await process_frame
	_expect(not drawer.visible, "region rack is closed by default")
	drawer.visible = true
	drawer.call("set_supply", _drawer_snapshot())
	await process_frame
	var action_counts := {"purchase": 0, "preview": 0}
	var quote_state := {"quote": {}}
	drawer.connect("supply_action_requested", func(action_id: String, _payload: Dictionary) -> void:
		if action_id == "district_supply_preview_card":
			action_counts["preview"] = int(action_counts.get("preview", 0)) + 1
		elif action_id == "district_supply_purchase_card":
			action_counts["purchase"] = int(action_counts.get("purchase", 0)) + 1
			quote_state["quote"] = {"quote_id": "quote-1", "remaining_world_us": 5_000_000, "quote_active": true}
	)
	var market_card := drawer.find_child("DistrictSupplyMarketCard_0", true, false) as Control
	_expect(market_card != null, "region rack renders a market card")
	if market_card != null:
		var single := InputEventMouseButton.new()
		single.button_index = MOUSE_BUTTON_LEFT
		single.pressed = true
		single.double_click = false
		market_card.call("_gui_input", single)
		await process_frame
		_expect(int(action_counts.get("preview", 0)) == 0 and int(action_counts.get("purchase", 0)) == 0 and (quote_state.get("quote", {}) as Dictionary).is_empty(), "hover/single-click preview creates no quote and emits no owner action")
		var drawer_debug := drawer.call("debug_snapshot") as Dictionary
		_expect(str(drawer_debug.get("local_preview_card_name", "")) == "测试牌" and bool(drawer_debug.get("passive_preview_only", false)), "single-click updates only the drawer-local preview")
		var double_click := InputEventMouseButton.new()
		double_click.button_index = MOUSE_BUTTON_LEFT
		double_click.pressed = true
		double_click.double_click = true
		market_card.call("_gui_input", double_click)
		await process_frame
		var locked_quote: Dictionary = quote_state.get("quote", {}) as Dictionary
		_expect(int(action_counts.get("purchase", 0)) == 1 and int(locked_quote.get("remaining_world_us", 0)) == 5_000_000, "explicit double-click purchase intent reaches the existing five-second quote route")

	var district_node := DISTRICT_NODE_SCENE.instantiate() as Control
	root.add_child(district_node)
	await process_frame
	district_node.call("configure", {"index": 3, "name": "测试区", "center": Vector2(100, 100)})
	var district_counts := {"single": 0, "double": 0}
	district_node.connect("district_pressed", func(_index: int) -> void: district_counts["single"] = int(district_counts.get("single", 0)) + 1)
	district_node.connect("district_double_pressed", func(_index: int) -> void: district_counts["double"] = int(district_counts.get("double", 0)) + 1)
	var district_single := InputEventMouseButton.new()
	district_single.button_index = MOUSE_BUTTON_LEFT
	district_single.pressed = true
	district_node.call("_on_gui_input", district_single)
	var district_double := InputEventMouseButton.new()
	district_double.button_index = MOUSE_BUTTON_LEFT
	district_double.pressed = true
	district_double.double_click = true
	district_node.call("_on_gui_input", district_double)
	_expect(int(district_counts.get("single", 0)) == 1 and int(district_counts.get("double", 0)) == 1, "single-click only selects a region; double-click uses the explicit rack-open signal")

	var map_view := MAP_SCENE.instantiate() as Control
	root.add_child(map_view)
	await process_frame
	map_view.call("set_map", [{"region_id": "region.0", "center": Vector2(100, 100)}], 500.0, 500.0, 0, [Color("#38bdf8")])
	var shared_open := {"count": 0}
	map_view.connect("district_double_clicked", func(_index: int) -> void: shared_open["count"] = int(shared_open.get("count", 0)) + 1)
	var accept_action := InputEventAction.new()
	accept_action.action = "ui_accept"
	accept_action.pressed = true
	map_view.call("_handle_keyboard_region_navigation", accept_action)
	_expect(int(shared_open.get("count", 0)) == 1, "keyboard/controller ui_accept uses the same explicit rack-open signal")

	var supply_snapshot_service := SUPPLY_SNAPSHOT_SCENE.instantiate()
	root.add_child(supply_snapshot_service)
	var quote_preview: Dictionary = supply_snapshot_service.call("_preview_snapshot", {
		"card_name": "测试牌",
		"display_name": "测试牌",
		"price": 100,
		"purchase_state": {"label": "选择以报价", "detail": "显式获取五秒报价。", "actionable": false, "requires_discard": false},
	}, {"visibility_scope": "viewer_private", "availability_kind": "sunlit"}) as Dictionary
	var dark_preview: Dictionary = supply_snapshot_service.call("_preview_snapshot", {
		"card_name": "测试牌",
		"display_name": "测试牌",
		"price": 100,
		"purchase_state": {"label": "选择以报价", "detail": "暗面不可报价。", "actionable": false, "requires_discard": false},
	}, {"visibility_scope": "viewer_private", "availability_kind": "dark"}) as Dictionary
	_expect(bool(quote_preview.get("buy_enabled", false)) and str(quote_preview.get("buy_text", "")).contains("获取报价"), "explicit Buy remains enabled to create the first quote for a valid sunlit listing")
	_expect(not bool(dark_preview.get("buy_enabled", true)), "invalid or dark listings remain fail-closed before quote creation")

	drawer.queue_free()
	district_node.queue_free()
	map_view.queue_free()
	supply_snapshot_service.queue_free()
	await process_frame


func _test_public_bid_and_forced_back() -> void:
	var fallback := Button.new()
	fallback.text = "安全焦点"
	fallback.focus_mode = Control.FOCUS_ALL
	root.add_child(fallback)
	var opener := Button.new()
	opener.text = "打开竞价"
	opener.focus_mode = Control.FOCUS_ALL
	root.add_child(opener)
	var overlay := OVERLAY_SCENE.instantiate()
	root.add_child(overlay)
	await process_frame
	opener.grab_focus()
	var planning := _bid_state("planning")
	_expect(not bool(overlay.call("show_public_bid", planning)) and not bool(overlay.call("public_bid_visible")), "full BidBoard is absent outside public_bid")
	var public_bid := _bid_state("public_bid")
	_expect(bool(overlay.call("show_public_bid", public_bid)) and bool(overlay.call("public_bid_visible")), "full BidBoard appears only in public_bid")
	await process_frame
	var bid_panel := overlay.find_child("PublicBidDecisionPanel", true, false) as Control
	var focus_owner := root.gui_get_focus_owner()
	_expect(focus_owner != null and bid_panel != null and (focus_owner == bid_panel or bid_panel.is_ancestor_of(focus_owner)), "public bid captures focus inside the shared modal area")
	var bid_action := bid_panel.find_child("BidBoardActionButton", true, false) as Button if bid_panel != null else null
	if bid_action != null:
		bid_action.grab_focus()
		overlay.call("show_public_bid", public_bid)
		await process_frame
		_expect(root.gui_get_focus_owner() == bid_action, "live public_bid snapshot refresh preserves the player's current control focus")
	_expect(bool(overlay.call("handle_back_request")) and bool(overlay.call("public_bid_visible")), "Back is consumed and cannot bypass a forced public bid")

	overlay.call("show_temporary_decision", {
		"id": "monster_wager_9",
		"kind": "monster_wager",
		"title": "怪兽战斗下注",
		"body": "真实下注窗口",
		"actions": [{"id": "monster_wager:9:a:5", "label": "押A 5%"}],
		"wager": {"matchup": "A vs B", "pool": 50},
	})
	await process_frame
	_expect(not bool(overlay.call("public_bid_visible")) and _visible_forced_panel_count(overlay) == 1, "higher forced decision preempts public_bid and only one actionable modal remains")
	_expect(bool(overlay.call("handle_back_request")) and _visible_forced_panel_count(overlay) == 1, "forced wager also consumes Back without closing")
	overlay.call("hide_confirm")
	await process_frame
	_expect(_visible_forced_panel_count(overlay) == 0, "resolved forced decision releases every modal visual")
	_expect(root.gui_get_focus_owner() == opener, "forced-to-forced preemption preserves the original opener focus for final restoration")

	overlay.call("show_temporary_decision", {
		"id": "contract_2",
		"kind": "contract_response",
		"title": "合同回应",
		"body": "真实合约决定",
		"actions": [{"id": "contract_accept_2", "label": "签约"}],
		"contract": {"route": "A → B", "products": "晶雾"},
	})
	_expect(_visible_forced_panel_count(overlay) == 1, "contract overlay exists only when a real decision snapshot is supplied")
	overlay.call("show_temporary_decision", {})
	await process_frame
	_expect(_visible_forced_panel_count(overlay) == 0, "empty decision snapshot leaves wager/contract/target surfaces absent")
	overlay.call("show_temporary_decision", {
		"id": "fixture_only",
		"kind": "fixture_only",
		"title": "不应出现",
		"actions": [{"id": "fixture_action", "label": "伪动作"}],
	})
	_expect(_visible_forced_panel_count(overlay) == 0, "unknown fixture decision kinds fail closed without creating a generic forced modal")
	var rejected_snapshot: RefCounted = TABLE_SNAPSHOT_SCRIPT.new()
	rejected_snapshot.call("apply_dictionary", {
		"temporary_decision": {"id": "stale", "kind": "stale_fixture", "actions": [{"id": "stale_action"}]},
	})
	var rejected_table: Dictionary = rejected_snapshot.call("to_ui_dictionary") as Dictionary
	_expect((rejected_table.get("temporary_decision", {}) as Dictionary).is_empty(), "TableSnapshot allowlists only real wager, counter, contract, discard, and target decision kinds")
	rejected_snapshot.call("apply_dictionary", {
		"active_forced_decision": {
			"id": "fixture-active",
			"kind": "fixture_only",
			"priority_group": "monster_wager",
			"visible_to_viewer": true,
			"presentation_surface": "overlay",
			"blocks_player_actions": true,
		},
	})
	rejected_table = rejected_snapshot.call("to_ui_dictionary") as Dictionary
	_expect((rejected_table.get("active_forced_decision", {}) as Dictionary).is_empty(), "TableSnapshot rejects unknown active-forced kinds even when they claim a real priority group")

	var route_view := RouteViewFake.new()
	route_view.add_to_group("optional_route_presentation_views")
	root.add_child(route_view)
	overlay.call("activate_optional_route_view", opener)
	_expect(bool(overlay.call("handle_back_request")) and route_view.hidden, "Back closes the active optional route view before pause")
	var stack := overlay.call("transient_surface_stack_snapshot") as Dictionary
	_expect(int(stack.get("stack_depth", -1)) == 0, "dismissed route view releases focus-stack metadata and layout footprint")

	overlay.call("show_public_bid", public_bid)
	await process_frame
	overlay.call("hide_public_bid")
	await process_frame
	focus_owner = root.gui_get_focus_owner()
	_expect(not bool(overlay.call("public_bid_visible")) and (focus_owner == opener or focus_owner == null), "public bid resolution hides layout and restores or safely releases opener focus")
	opener.grab_focus()
	overlay.call("show_public_bid", public_bid)
	await process_frame
	opener.queue_free()
	await process_frame
	overlay.call("hide_public_bid")
	await process_frame
	_expect(root.gui_get_focus_owner() == fallback, "focus restoration falls back to the first enabled control when the opener disappeared")

	route_view.queue_free()
	overlay.queue_free()
	fallback.queue_free()
	await process_frame


func _test_scheduler_public_bid_priority() -> void:
	var scheduler := SCHEDULER_SCENE.instantiate()
	root.add_child(scheduler)
	scheduler.call("configure", [])
	scheduler.call("sync_candidates", [_candidate("bid-unconfigured", "public_bid", "public_bid", 1.0)])
	var unconfigured_debug := scheduler.call("debug_snapshot") as Dictionary
	_expect(not bool(unconfigured_debug.get("scheduler_ready", true)) and int(unconfigured_debug.get("candidate_count", -1)) == 0 and str(scheduler.call("active_priority_group")).is_empty(), "empty scheduler configuration stays fail-closed instead of retaining or enabling public_bid alone")
	scheduler.call("configure", ["public_bid", "monster_wager", "counter_response", "contract_response", "other_choice"])
	var configured_debug := scheduler.call("debug_snapshot") as Dictionary
	_expect((configured_debug.get("priority_order", []) as Array) == ["monster_wager", "counter_response", "contract_response", "other_choice", "public_bid"], "prelisted public_bid is normalized to the final lowest-priority slot")
	scheduler.call("sync_candidates", [_candidate("forged-bid", "public_bid", "monster_wager", 1.0)])
	_expect(str(scheduler.call("active_priority_group")).is_empty(), "public_bid cannot forge a higher scheduler priority group")
	scheduler.call("sync_candidates", [_candidate("fixture-only", "fixture_only", "monster_wager", 1.0)])
	_expect(str(scheduler.call("active_priority_group")).is_empty(), "unknown decision kinds cannot enter a configured scheduler priority group")
	scheduler.call("configure", ["monster_wager", "counter_response", "contract_response", "other_choice"])
	scheduler.call("sync_candidates", [
		_candidate("bid", "public_bid", "public_bid", 50.0),
		_candidate("choice", "monster_target_choice", "other_choice", 40.0),
	])
	_expect(str(scheduler.call("active_priority_group")) == "other_choice", "public_bid is lower priority than other real choices")
	scheduler.call("sync_candidates", [_candidate("bid", "public_bid", "public_bid", 50.0)])
	_expect(str(scheduler.call("active_priority_group")) == "public_bid", "public_bid becomes active when no higher decision exists")
	var debug := scheduler.call("debug_snapshot") as Dictionary
	_expect((debug.get("priority_order", []) as Array) == ["monster_wager", "counter_response", "contract_response", "other_choice", "public_bid"], "scheduler appends public_bid as the lowest stable priority")
	scheduler.queue_free()


func _test_game_screen_layout_and_zero_placeholder() -> void:
	var screen := GAME_SCREEN_SCENE.instantiate() as Control
	root.add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await process_frame
	var ordinary_actions: Array[String] = []
	screen.connect("action_requested", func(action_id: String) -> void:
		ordinary_actions.append(action_id)
	)
	screen.call("apply_state", {
		"active_forced_decision": _active_public_bid(),
		"player_board": {
			"title": "玩家板",
			"identity": "本席",
			"cash_text": "¥1000",
			"gdp_text": "10/min",
			"goal_text": "目标",
			"bid_board": _bid_state("public_bid"),
			"actions": [{"id": "inspect", "label": "查看详情"}],
			"quick_actions": [],
			"hand_cards": [],
		},
		"temporary_decision": {},
	})
	await process_frame
	var player_board := screen.find_child("PlayerBoard", true, false)
	var bid_panel := screen.find_child("PublicBidDecisionPanel", true, false) as Control
	var action_dock := screen.find_child("PlayerMainActionDock", true, false) as Control
	var planet_board := screen.find_child("PlanetBoard", true, false) as Control
	_expect(player_board != null and player_board.find_child("PlayerBidBoard", true, false) == null, "PlayerBoard permanently reserves zero BidBoard layout")
	var viewport_rect := root.get_visible_rect()
	var bid_rect := bid_panel.get_global_rect() if bid_panel != null else Rect2()
	var primary_overlap := bid_rect.intersection(action_dock.get_global_rect()).get_area() if bid_panel != null and action_dock != null else -1.0
	var planet_visible_area := planet_board.get_global_rect().get_area() - bid_rect.intersection(planet_board.get_global_rect()).get_area() if bid_panel != null and planet_board != null else 0.0
	var bid_inside_viewport := bid_rect.position.x >= -0.5 and bid_rect.position.y >= -0.5 and bid_rect.end.x <= viewport_rect.end.x + 0.5 and bid_rect.end.y <= viewport_rect.end.y + 0.5
	_expect(root.size == Vector2i(1280, 720) and bid_panel != null and bid_panel.visible and bid_inside_viewport, "public bid primary action fits inside the 1280×720 scaled viewport")
	_expect(primary_overlap <= 0.01 and planet_visible_area > 10_000.0, "public bid does not obscure PlayerBoard primary action and leaves the central planet recognizable")
	screen.call("_on_action_requested", "detail_region")
	var overlay := screen.find_child("OverlayLayer", true, false) as Node
	var forced_side_drawer_result := true
	var forced_stack: Dictionary = {}
	if overlay != null:
		forced_side_drawer_result = bool(overlay.call("show_side_drawer", {"title": "伪侧栏"}))
		forced_stack = overlay.call("transient_surface_stack_snapshot") as Dictionary
	_expect(ordinary_actions.is_empty() and forced_side_drawer_result == false and not bool(forced_stack.get("side_drawer_visible", true)), "forced public_bid blocks ordinary pointer actions and dismissible side drawers")
	screen.call("apply_state", {
		"active_forced_decision": _active_public_bid(),
		"player_board": {"bid_board": _bid_state("public_bid"), "actions": [], "quick_actions": [], "hand_cards": []},
		"temporary_decision": {
			"id": "stale_contract",
			"kind": "contract_response",
			"title": "陈旧合约",
			"actions": [{"id": "contract_accept_stale", "label": "签约"}],
		},
	})
	await process_frame
	var stale_contract_panel := screen.find_child("ContractResponseDecisionPanel", true, false) as Control
	_expect(bid_panel != null and bid_panel.visible and (stale_contract_panel == null or not stale_contract_panel.visible), "scheduler-mismatched temporary data cannot suppress the selected public_bid surface")
	screen.call("apply_state", {
		"active_forced_decision": _active_public_bid(),
		"player_board": {"bid_board": _bid_state("planning"), "actions": [], "quick_actions": [], "hand_cards": []},
		"temporary_decision": {},
	})
	await process_frame
	_expect(bid_panel != null and not bid_panel.visible, "planning/lock/resolve/idle leave full bid surface absent with zero occupancy")
	screen.queue_free()
	await process_frame


func _drawer_snapshot() -> Dictionary:
	var preview := {
		"card_name": "测试牌",
		"title": "测试牌｜设施",
		"body": "被动预览",
		"buy_text": "购买 ¥100",
		"buy_enabled": true,
		"accent": "#38bdf8ff",
		"theme_color": "#38bdf8ff",
	}
	return {
		"title": "区域牌架",
		"rule_strip": "悬停/单击只预览｜双击或购买才报价",
		"privacy_hint": "只显示本地玩家状态。",
		"header_chips": [],
		"market_status": [],
		"cards": [{
			"card_name": "测试牌",
			"title": "测试牌",
			"rank": "I",
			"route": "生产",
			"facts": "公开卡面",
			"state_text": "可购买",
			"accent": "#38bdf8ff",
			"theme_color": "#38bdf8ff",
			"actionable": true,
			"preview": preview,
		}],
		"preview": preview,
		"empty_state": {"market_text": "暂无", "preview_text": "选择"},
	}


func _bid_state(phase_id: String) -> Dictionary:
	return {
		"title": "牌序竞价",
		"phase_id": phase_id,
		"phase": {"public_bid": "公开竞价 5s", "planning": "规划 8s"}.get(phase_id, phase_id),
		"status": "只使用 Card Resolution 的阶段与倒计时。",
		"active": phase_id == "public_bid",
		"visible": true,
		"chips": [{"label": "本阶段", "state": "待确认", "active": true}],
		"track_links": [{"id": "track_select_1", "label": "领跑", "state": "展示组1", "active": true}],
		"actions": [{"id": "card_group_ready", "label": "完成展示", "disabled": false}],
	}


func _candidate(id: String, kind: String, group: String, sequence: float) -> Dictionary:
	return {
		"id": id,
		"kind": kind,
		"priority_group": group,
		"owner_player_index": -1,
		"visibility_scope": "public",
		"presentation_surface": "overlay",
		"opened_sequence": sequence,
		"blocks_global_time": false,
		"blocks_player_actions": true,
		"blocks_card_resolution": false,
		"source_ref": kind,
	}


func _active_public_bid() -> Dictionary:
	return {
		"id": "public_bid",
		"kind": "public_bid",
		"priority_group": "public_bid",
		"visible_to_viewer": true,
		"presentation_surface": "overlay",
		"blocks_global_time": false,
		"blocks_player_actions": true,
		"blocks_card_resolution": false,
	}


func _visible_forced_panel_count(overlay: Node) -> int:
	var count := 0
	for name in ["MonsterWagerDecisionPanel", "ContractResponseDecisionPanel", "TemporaryChoiceDecisionPanel", "TemporaryDecisionModal", "PublicBidDecisionPanel"]:
		var control := overlay.find_child(name, true, false) as Control
		if control != null and control.visible:
			count += 1
	return count


func _expect(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)


func _finish() -> void:
	var status := "PASS" if _failures.is_empty() else "FAIL"
	print("TRANSIENT_GAMEPLAY_WINDOWS_V06_TEST|status=%s|checks=%d|failures=%d" % [status, _checks, _failures.size()])
	for failure in _failures:
		push_error("TRANSIENT_GAMEPLAY_WINDOWS_V06_TEST: %s" % failure)
	quit(0 if _failures.is_empty() else 1)
