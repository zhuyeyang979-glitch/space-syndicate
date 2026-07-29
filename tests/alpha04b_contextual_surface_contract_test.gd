extends SceneTree

const REGION_SCENE := preload("res://scenes/ui/table/RegionSupplyPopup.tscn")
const ACTION_SCENE := preload("res://scenes/ui/table/CompactCurrentActionSurface.tscn")
const TOAST_SCENE := preload("res://scenes/ui/table/NonBlockingToastSurface.tscn")
const HISTORY_SCENE := preload("res://scenes/ui/table/ExpandablePublicHistorySurface.tscn")
const DETAIL_SCENE := preload("res://scenes/ui/table/ContextDetailDrawer.tscn")

const REGION := preload("res://scripts/presentation/region_supply_popup_projection_v1.gd")
const ACTION_CONTEXT := preload("res://scripts/presentation/current_action_context_projection_v1.gd")
const FEEDBACK := preload("res://scripts/presentation/public_feedback_projection_v1.gd")
const DETAIL := preload("res://scripts/presentation/context_detail_projection_v1.gd")
const OFFER := preload("res://scripts/semantic/game_action_offer_v1.gd")
const ACTION_INTENT := preload("res://scripts/semantic/game_action_intent_v1.gd")

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	await _test_region_supply_popup()
	await _test_compact_current_action()
	await _test_feedback_surfaces()
	await _test_context_detail_closed_union()
	_finish()


func _test_region_supply_popup() -> void:
	var surface := REGION_SCENE.instantiate() as SpaceSyndicateRegionSupplyPopup
	_expect(surface != null, "RegionSupplyPopup instantiates")
	if surface == null:
		return
	root.add_child(surface)
	surface.bind_viewer(0, 3)
	await process_frame
	var projection := REGION.build(_region_source(7, 5))
	_expect(surface.apply_projection(projection), "RegionSupplyPopup accepts its viewer-authorized typed projection")
	await process_frame
	var debug := surface.debug_snapshot()
	_expect(bool(debug.get("reuses_production_district_supply_drawer", false)) \
		and int(debug.get("production_drawer_instance_count", 0)) == 1, "RegionSupplyPopup owns exactly one reused production DistrictSupplyDrawer")
	_expect(not bool(debug.get("owns_rack", true)) and not bool(debug.get("owns_purchase_window", true)) \
		and not bool(debug.get("owns_rng", true)), "RegionSupplyPopup owns no rack, purchase window, or RNG")
	var drawer := surface.find_child("ProductionDistrictSupplyDrawer", true, false) as Control
	var market_grid := drawer.find_child("DistrictSupplyMarketGrid", true, false) as Container
	var first_card := market_grid.get_child(0) as Control if market_grid != null and market_grid.get_child_count() == 1 else null
	_expect(first_card != null, "typed region projection adapts into the production drawer card")
	var drawer_id := drawer.get_instance_id() if drawer != null else 0
	_expect(surface.apply_projection(projection), "duplicate region projection is idempotent")
	_expect(int(surface.debug_snapshot().get("duplicate_count", 0)) == 1, "duplicate region projection is counted without rebuilding")
	var switched := REGION.build(_region_source(7, 3, "region.1", 1, "南境", "rack.card.1"))
	_expect(surface.apply_projection(switched), "same source revision accepts a lower per-region rack revision when switching regions")
	await process_frame
	var switched_card := market_grid.get_child(0) as Control if market_grid != null and market_grid.get_child_count() == 1 else null
	var switched_card_id := switched_card.get_instance_id() if switched_card != null else 0
	var refreshed := REGION.build(_region_source(8, 6, "region.1", 1, "南境", "rack.card.1"))
	_expect(surface.apply_projection(refreshed), "newer region and rack revisions apply")
	await process_frame
	var refreshed_card := market_grid.get_child(0) as Control if market_grid != null and market_grid.get_child_count() == 1 else null
	_expect(drawer.get_instance_id() == drawer_id and refreshed_card != null \
		and refreshed_card.get_instance_id() == switched_card_id, "region refresh reuses both production drawer and stable rack-card node")
	_expect(not surface.apply_projection(projection) and int(surface.debug_snapshot().get("stale_count", 0)) == 1, "region surface rejects a stale source/rack revision")
	var supply_actions: Array[String] = []
	surface.supply_action_requested.connect(func(action_id: String, _payload: Dictionary) -> void:
		supply_actions.append(action_id)
	)
	drawer.call("_on_close_pressed")
	_expect(supply_actions == ["district_supply_close"] and not surface.visible, "drawer close stays on the production supply action port and closes the surface")
	var close_reasons: Array[String] = []
	surface.close_requested.connect(func(reason_id: String) -> void:
		close_reasons.append(reason_id)
	)
	_expect(surface.show_popup(), "region popup can reopen without rebuilding its drawer")
	surface.call("_on_backdrop_gui_input", _left_click())
	_expect(not surface.visible and close_reasons.back() == "outside_pointer" \
		and supply_actions.back() == "district_supply_close", "region popup owns outside-pointer close and routes close to the production port")
	_expect(surface.show_popup(), "region popup reopens for keyboard-close coverage")
	surface.call("_unhandled_key_input", _cancel_action())
	_expect(not surface.visible and close_reasons.back() == "escape" \
		and supply_actions.back() == "district_supply_close", "region popup owns Esc close and routes close to the production port")
	_expect(float(surface.debug_snapshot().get("render_p95_ms", -1.0)) >= 0.0, "region surface reports bounded render p95")
	surface.queue_free()
	await process_frame


func _test_compact_current_action() -> void:
	var surface := ACTION_SCENE.instantiate() as SpaceSyndicateCompactCurrentActionSurface
	_expect(surface != null, "CompactCurrentActionSurface instantiates")
	if surface == null:
		return
	root.add_child(surface)
	surface.bind_viewer(0, 3)
	await process_frame
	var projection := ACTION_CONTEXT.build(_action_context_source(11))
	_expect(surface.apply_projection(projection), "compact action surface accepts typed current-action context")
	await process_frame
	var debug := surface.debug_snapshot()
	_expect(int(debug.get("offer_count", 0)) == 1 and not bool(debug.get("accepts_card_submission", true)), "compact action exposes the non-card offer and cannot accept card submission")
	root.size = Vector2i(1366, 768)
	surface.size = Vector2(1000, 84)
	await process_frame
	_expect(surface.custom_minimum_size.y <= 88.0 \
		and surface.get_combined_minimum_size().y <= 88.0, "compact action remains an <=88px production strip at 1366 width")
	var dock := surface.find_child("CurrentActionDock", true, false) as Control
	var dock_id := dock.get_instance_id() if dock != null else 0
	_expect(surface.apply_projection(projection) and int(surface.debug_snapshot().get("duplicate_count", 0)) == 1, "duplicate current-action projection reuses the ActionDock")
	_expect(dock != null and dock.get_instance_id() == dock_id, "current-action ActionDock node identity remains stable")
	var emitted_offers: Array[Dictionary] = []
	surface.game_action_offer_requested.connect(func(offer: Dictionary) -> void:
		emitted_offers.append(offer)
	)
	var action_button := dock.find_child("PlayerActionButton", true, false) as Button if dock != null else null
	_expect(action_button != null, "compact action renders one safe quick-action button")
	if action_button != null:
		action_button.pressed.emit()
	_expect(emitted_offers.size() == 1 \
		and str(emitted_offers[0].get("semantic_action_id", "")) == ACTION_INTENT.ACTION_DISTRICT_SUPPLY_OPEN, "compact action emits the typed non-card GameActionOffer directly")
	var card_context := _action_context_source(12)
	card_context["game_action_offers"] = [_offer(ACTION_INTENT.ACTION_CARD_PLAY, 12)]
	_expect(ACTION_CONTEXT.build(card_context).is_empty(), "typed action schema fails closed before a card-play offer can reach the surface")
	_expect(not surface.apply_projection(ACTION_CONTEXT.build(_action_context_source(10))) \
		and int(surface.debug_snapshot().get("stale_count", 0)) == 1, "compact action surface rejects stale context revision")
	_expect(float(surface.debug_snapshot().get("render_p95_ms", -1.0)) >= 0.0, "compact action surface reports bounded render p95")
	surface.queue_free()
	await process_frame


func _test_feedback_surfaces() -> void:
	var toast := TOAST_SCENE.instantiate() as SpaceSyndicateNonBlockingToastSurface
	var history := HISTORY_SCENE.instantiate() as SpaceSyndicateExpandablePublicHistorySurface
	_expect(toast != null and history != null, "toast and public-history surfaces instantiate")
	if toast == null or history == null:
		return
	root.add_child(toast)
	root.add_child(history)
	toast.bind_viewer(0, 3)
	history.bind_viewer(0, 3)
	await process_frame
	var private_feedback := FEEDBACK.build(_feedback_source(1, FEEDBACK.VISIBILITY_VIEWER_PRIVATE, FEEDBACK.SEVERITY_FAILURE))
	_expect(toast.apply_projection(private_feedback), "toast accepts viewer-bound private failure feedback transiently")
	var toast_label := toast.find_child("ToastMessage", true, false) as Label
	var toast_label_id := toast_label.get_instance_id() if toast_label != null else 0
	var toast_debug := toast.debug_snapshot()
	_expect(toast.visible and bool(toast_debug.get("non_blocking", false)) \
		and not bool(toast_debug.get("persists_feedback", true)) \
		and not bool(toast_debug.get("forwards_viewer_private_to_public_history", true)), "private toast is non-blocking, transient, and never copied to public history")
	_expect(not history.apply_projections([private_feedback]) \
		and int(history.debug_snapshot().get("private_reject_count", 0)) == 1, "public history strictly rejects viewer-private feedback")
	var public_one := FEEDBACK.build(_feedback_source(2, FEEDBACK.VISIBILITY_PUBLIC, FEEDBACK.SEVERITY_INFORMATIONAL))
	var public_two := FEEDBACK.build(_feedback_source(3, FEEDBACK.VISIBILITY_PUBLIC, FEEDBACK.SEVERITY_SUCCESS))
	_expect(history.apply_projections([public_one, public_two]), "public history accepts ordered public typed feedback")
	history.set_expanded(true)
	await process_frame
	var history_debug := history.debug_snapshot()
	_expect(int(history_debug.get("entry_count", 0)) == 2 and bool(history_debug.get("expanded", false)) \
		and bool(history_debug.get("accepts_public_only", false)), "public history expands with exactly the public entries")
	var history_label := history.find_child("PublicHistoryEntries", true, false) as RichTextLabel
	var history_label_id := history_label.get_instance_id() if history_label != null else 0
	var public_three := FEEDBACK.build(_feedback_source(4, FEEDBACK.VISIBILITY_PUBLIC, FEEDBACK.SEVERITY_WARNING))
	_expect(history.apply_projections([public_one, public_two, public_three]), "new public receipt revision refreshes history")
	_expect(history_label != null and history_label.get_instance_id() == history_label_id, "history refresh reuses its entry-render node")
	_expect(not history.apply_projections([public_one, public_two]) \
		and int(history.debug_snapshot().get("stale_count", 0)) == 1, "public history rejects a stale receipt sequence")
	var public_toast := FEEDBACK.build(_feedback_source(5, FEEDBACK.VISIBILITY_PUBLIC, FEEDBACK.SEVERITY_SUCCESS))
	_expect(toast.apply_projection(public_toast), "toast also accepts public feedback")
	_expect(toast_label != null and toast_label.get_instance_id() == toast_label_id, "toast refresh reuses its message node")
	_expect(not toast.apply_projection(private_feedback) \
		and int(toast.debug_snapshot().get("stale_count", 0)) == 1, "toast rejects stale feedback revision")
	toast.dismiss("focused_test")
	_expect(not toast.visible, "toast supports surface-owned dismissal")
	history.set_expanded(false)
	_expect(not bool(history.debug_snapshot().get("expanded", true)), "public history supports surface-owned collapse")
	_expect(float(history.debug_snapshot().get("render_p95_ms", -1.0)) >= 0.0 \
		and float(toast.debug_snapshot().get("render_p95_ms", -1.0)) >= 0.0, "feedback surfaces report bounded render p95")
	toast.queue_free()
	history.queue_free()
	await process_frame


func _test_context_detail_closed_union() -> void:
	var surface := DETAIL_SCENE.instantiate() as SpaceSyndicateContextDetailDrawer
	_expect(surface != null, "ContextDetailDrawer instantiates")
	if surface == null:
		return
	root.add_child(surface)
	surface.bind_viewer(0, 3)
	await process_frame
	var body := surface.find_child("ContextDetailBody", true, false) as Label
	var body_id := body.get_instance_id() if body != null else 0
	var revision := 20
	for context_kind in [
		DETAIL.KIND_NORMAL_CARD,
		DETAIL.KIND_COMMODITY_CARD,
		DETAIL.KIND_PUBLIC_TRACK,
		DETAIL.KIND_REGION_FACILITY,
		DETAIL.KIND_COMMODITY_SOURCE,
		DETAIL.KIND_PUBLIC_EVENT,
	]:
		var projection := DETAIL.build(_detail_source(context_kind, revision))
		_expect(surface.apply_projection(projection), "ContextDetailDrawer applies closed kind %s" % context_kind)
		await process_frame
		var debug := surface.debug_snapshot()
		_expect(str(debug.get("context_kind", "")) == context_kind \
			and bool(debug.get("read_only", false)) \
			and not bool(debug.get("accepts_card_submission", true)), "context kind %s stays read-only" % context_kind)
		_expect(body != null and body.get_instance_id() == body_id, "context kind %s reuses the body node" % context_kind)
		revision += 1
	var exact_kinds: Array = surface.debug_snapshot().get("closed_context_kinds", []) as Array
	_expect(exact_kinds == ["normal_card", "commodity_card", "public_track", "region_facility", "commodity_source", "public_event"], "ContextDetailDrawer exposes the exact six closed kinds")
	_expect(not surface.apply_projection(DETAIL.build(_detail_source(DETAIL.KIND_PUBLIC_EVENT, revision - 2))) \
		and int(surface.debug_snapshot().get("stale_count", 0)) == 1, "ContextDetailDrawer rejects stale detail revision")
	var close_reasons: Array[String] = []
	surface.close_requested.connect(func(reason_id: String) -> void:
		close_reasons.append(reason_id)
	)
	surface.close_drawer("close_button")
	_expect(not surface.visible and close_reasons.back() == "close_button", "ContextDetailDrawer supports surface-owned close")
	_expect(surface.show_drawer(), "ContextDetailDrawer reopens without rebuilding its detail nodes")
	surface.call("_on_backdrop_gui_input", _left_click())
	_expect(not surface.visible and close_reasons.back() == "outside_pointer", "ContextDetailDrawer owns outside-pointer close")
	_expect(surface.show_drawer(), "ContextDetailDrawer reopens for keyboard-close coverage")
	surface.call("_unhandled_key_input", _cancel_action())
	_expect(not surface.visible and close_reasons.back() == "escape", "ContextDetailDrawer owns Esc close")
	_expect(float(surface.debug_snapshot().get("render_p95_ms", -1.0)) >= 0.0, "ContextDetailDrawer reports bounded render p95")
	surface.queue_free()
	await process_frame


func _region_source(
	source_revision: int,
	rack_revision: int,
	region_id := "region.0",
	region_index := 0,
	display_name := "北境",
	rack_card_id := "rack.card.0"
) -> Dictionary:
	return {
		"schema_version": REGION.SCHEMA_VERSION,
		"viewer_index": 0,
		"authorization_revision": 3,
		"region_id": region_id,
		"region_index": region_index,
		"display_name": display_name,
		"source_revision": source_revision,
		"rack_revision": rack_revision,
		"public_status": "active",
		"availability": _availability(true),
		"monster_price_pressure": 2,
		"facility_slots": [{
			"slot_id": "facility.slot.0", "display_name": "设施槽位", "public_status": "open",
			"is_occupied": false, "detail_context_id": "detail.facility-slot-0",
		}],
		"rack_cards": [{
			"rack_card_id": rack_card_id, "card_semantic_id": "facility.orbital-factory.rank-1",
			"display_name": "轨道工厂", "illustration_key": "facility.orbital-factory",
			"costs": [_cost()], "availability": _availability(true), "detail_context_id": "detail.rack-card-0",
			"source_revision": source_revision, "rack_revision": rack_revision,
		}],
		"requirements": [_requirement(true)],
		"allowed_actions": [],
		"allowed_navigation_intents": [],
	}


func _action_context_source(revision: int) -> Dictionary:
	return {
		"schema_version": ACTION_CONTEXT.SCHEMA_VERSION,
		"viewer_index": 0,
		"authorization_revision": 3,
		"context_id": "context.region-supply",
		"source_revision": revision,
		"title": "地区行动",
		"summary": "选择打开区域牌架。",
		"reason_id": "none",
		"reason_text": "",
		"costs": [_cost()],
		"requirements": [_requirement(true)],
		"consequences": [{
			"consequence_id": "consequence.open", "message_token": "feedback.supply.open", "arguments": {},
		}],
		"game_action_offers": [_offer(ACTION_INTENT.ACTION_DISTRICT_SUPPLY_OPEN, revision)],
		"navigation_intents": [],
	}


func _feedback_source(revision: int, visibility_scope: String, severity: String) -> Dictionary:
	return {
		"schema_version": FEEDBACK.SCHEMA_VERSION,
		"viewer_index": 0,
		"authorization_revision": 3,
		"receipt_id": "receipt.feedback-%d" % revision,
		"revision": revision,
		"severity": severity,
		"reason_id": "insufficient-funds" if severity == FEEDBACK.SEVERITY_FAILURE else "none",
		"message_token": "feedback.fixture-%d" % revision,
		"arguments": {"count": revision},
		"public_or_viewer_private": visibility_scope,
		"history_link": {},
	}


func _detail_source(context_kind: String, revision: int) -> Dictionary:
	return {
		"schema_version": DETAIL.SCHEMA_VERSION,
		"viewer_index": 0,
		"authorization_revision": 3,
		"source_revision": revision,
		"context_id": "detail.%s" % context_kind.replace("_", "-"),
		"context_kind": context_kind,
		"visibility_scope": "viewer_private" if context_kind in [DETAIL.KIND_NORMAL_CARD, DETAIL.KIND_COMMODITY_CARD] else "public",
		"title": "详情 %s" % context_kind,
		"subtitle": "只读上下文",
		"content": _detail_content(context_kind),
		"navigation_intents": [],
	}


func _detail_content(context_kind: String) -> Dictionary:
	match context_kind:
		DETAIL.KIND_NORMAL_CARD:
			return {
				"card_instance_id": "card.instance.1", "card_semantic_id": "facility.orbital.rank-1",
				"display_name": "轨道设施", "illustration_key": "facility.orbital",
				"timing_text": "行动阶段", "target_text": "一个地区", "effect_text": "获得公开效果",
				"duration_text": "立即", "visibility_text": "仅当前玩家", "keyword_tokens": ["keyword.facility"],
				"disabled_reason_id": "none", "disabled_reason_text": "",
			}
		DETAIL.KIND_COMMODITY_CARD:
			return {
				"commodity_card_instance_id": "commodity.card.1", "card_semantic_id": "commodity.berry.rank-2",
				"commodity_id": "star-dew-berry", "display_name": "星露莓", "illustration_key": "commodity.star-dew-berry",
				"level": 2, "base_units": 2, "target_text": "同产业设施", "effect_text": "结算商品",
				"source_text": "公共商品轨", "disabled_reason_id": "none", "disabled_reason_text": "",
			}
		DETAIL.KIND_PUBLIC_TRACK:
			return {
				"resolution_id": "resolution.1", "card_semantic_id": "track.public-card",
				"display_name": "公共牌轨", "illustration_key": "track.public-card", "public_status": "available",
				"summary": "公开摘要", "detail": "公开详情", "keyword_tokens": ["keyword.public"],
			}
		DETAIL.KIND_REGION_FACILITY:
			return {
				"facility_id": "facility.1", "region_id": "region.0", "display_name": "公开设施",
				"illustration_key": "facility.public", "public_status": "active", "summary": "设施摘要", "detail": "设施详情",
			}
		DETAIL.KIND_COMMODITY_SOURCE:
			return {
				"source_id": "source.market.1", "commodity_id": "star-dew-berry", "display_name": "公开来源",
				"illustration_key": "commodity.source.market", "public_status": "active", "summary": "来源摘要", "detail": "来源详情",
			}
		DETAIL.KIND_PUBLIC_EVENT:
			return {
				"receipt_id": "receipt.event-1", "reason_id": "none", "message_token": "event.public.fixture",
				"arguments": {"count": 1}, "summary": "事件摘要", "detail": "事件详情", "history_link": {},
			}
	return {}


func _availability(available: bool) -> Dictionary:
	return {
		"state_id": "available" if available else "disabled",
		"reason_id": "none" if available else "blocked",
		"reason_text": "" if available else "暂不可用",
	}


func _cost() -> Dictionary:
	return {
		"cost_id": "cost.purchase", "resource_id": "commerce", "amount_units": 3,
		"display_token": "cost.commerce",
	}


func _requirement(satisfied: bool) -> Dictionary:
	return {
		"requirement_id": "requirement.selected-region", "satisfied": satisfied,
		"reason_id": "none" if satisfied else "region-required",
		"message_token": "requirement.region.selected", "arguments": {"count": 1},
	}


func _offer(action_id: String, revision: int) -> Dictionary:
	var contract := ACTION_INTENT.action_contract(action_id)
	var bindings: Array = []
	match action_id:
		ACTION_INTENT.ACTION_CARD_PLAY:
			bindings = [
				{"target_role_id": "card_instance_id", "target_id": "card.instance.1"},
				{"target_role_id": "hand_slot_id", "target_id": "hand.slot.0"},
			]
		ACTION_INTENT.ACTION_DISTRICT_SUPPLY_OPEN:
			bindings = [{"target_role_id": "region_id", "target_id": "region.0"}]
	return OFFER.build({
		"schema_version": OFFER.SCHEMA_VERSION,
		"semantic_action_id": action_id,
		"action_family_id": str(contract.get("action_family_id", "")),
		"source_revision": revision,
		"actor_scope": "authorized_actor",
		"public_or_private_target_spec": {
			"visibility_scope_id": "viewer_private", "target_kind_id": "stable-ids",
			"target_bindings": bindings, "requires_target": not bindings.is_empty(),
		},
		"legality_state": "available",
		"disabled_reason_id": "none",
		"cost_spec": {"cost_kind_id": "domain-owned", "amount_units": 0, "resource_id": "none"},
		"requirement_spec": {"requirement_ids": ["domain-legality"], "source_revision_required": true},
		"consequence_spec": {"committed_effect_refs": [], "refresh_scope": "full"},
		"presentation_token_ids": ["action.fixture"],
	})


func _left_click() -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	return event


func _cancel_action() -> InputEventAction:
	var event := InputEventAction.new()
	event.action = "ui_cancel"
	event.pressed = true
	return event


func _expect(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)


func _finish() -> void:
	var status := "PASS" if _failures.is_empty() else "FAIL"
	print("ALPHA04B_CONTEXTUAL_SURFACE_CONTRACT_TEST|status=%s|checks=%d|failures=%d" % [status, _checks, _failures.size()])
	for failure in _failures:
		push_error("ALPHA04B_CONTEXTUAL_SURFACE_CONTRACT_TEST: %s" % failure)
	quit(0 if _failures.is_empty() else 1)
