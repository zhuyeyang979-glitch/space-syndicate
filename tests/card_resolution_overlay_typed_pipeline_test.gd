extends SceneTree

const PROJECTION := preload("res://scripts/presentation/card_resolution_overlay_projection_v1.gd")
const TARGET_SCENE := preload("res://scenes/ui/CardResolutionBanner.tscn")
const TARGET_SCRIPT := preload("res://scripts/ui/table/card_resolution_overlay.gd")
const OVERLAY_LAYER_SCENE := preload("res://scenes/ui/OverlayLayer.tscn")

var _checks := 0
var _failures: Array[String] = []
var _viewmodel := GameTableViewModelRuntimeService.new()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_v06_projection_contract()
	_test_group_window_parity()
	_test_closed_and_public_only_contract()
	_test_v07_production_gate()
	await _test_typed_target_stale_and_duplicate_behavior()
	await _test_overlay_layer_pipeline_and_zero_mutation()
	_finish()


func _test_v06_projection_contract() -> void:
	var counter := _compose_overlay(PROJECTION.MODE_V06_LEGACY, "counter", true, 10, 41, 4.25)
	_expect(bool(PROJECTION.validation_report(counter).get("valid", false)), "V0.6 counter overlay is a valid typed projection")
	_expect(str(counter.get("resolution_runtime_mode", "")) == PROJECTION.MODE_V06_LEGACY, "production projection declares V06_LEGACY_RESOLUTION")
	_expect(bool(counter.get("visible", false)) and str(counter.get("phase_id", "")) == "counter", "V0.6 counter phase remains visibly represented")
	_expect(bool(counter.get("counter_response_visible", false)) \
		and str(counter.get("gameplay_input_mode", "")) == "V06_COUNTER_RESPONSE", "visible V0.6 counter phase declares its real response-input mode")
	_expect((counter.get("badge_labels", []) as Array).has("响应窗口"), "V0.6 counter projection carries an explicit response-window badge")
	var resolving := _compose_overlay(PROJECTION.MODE_V06_LEGACY, "resolving", true, 11, 41, 1.5)
	_expect(bool(PROJECTION.validation_report(resolving).get("valid", false)) \
		and not bool(resolving.get("counter_response_visible", true)) \
		and str(resolving.get("gameplay_input_mode", "")) == "NONE", "non-counter V0.6 phases expose no gameplay input")
	var forged_input := resolving.duplicate(true)
	forged_input["gameplay_input_mode"] = "V06_COUNTER_RESPONSE"
	_expect(not bool(PROJECTION.validation_report(forged_input).get("valid", true)), "projection contract rejects response input outside the V0.6 counter phase")
	var forged_counter := resolving.duplicate(true)
	forged_counter["counter_response_visible"] = true
	_expect(not bool(PROJECTION.validation_report(forged_counter).get("valid", true)), "projection contract rejects an invented counter surface")


func _test_group_window_parity() -> void:
	for phase in ["planning", "public_bid", "lock"]:
		var surfaces := _viewmodel.compose_card_surfaces({
			"track": {
				"resolution_runtime_mode": PROJECTION.MODE_V06_LEGACY,
				"resolution_overlay_source": {
					"revision": 100 + ["planning", "public_bid", "lock"].find(phase),
					"overlay": {
						"visible": true,
						"phase": phase,
						"resolution_id": -1,
						"remaining_seconds": 6.0,
						"card_name": "",
					},
				},
				"queue": [{
					"entry": {
						"resolution_id": 71,
						"group_position": 2,
						"group_order": 1,
						"group_size": 2,
					},
					"card_label": "生命工厂",
					"requirement_text": "条件：区域GDP份额≥10%",
					"card": {},
				}],
				"next_queue": [{"entry": {"resolution_id": 72}, "card_label": "下批牌", "card": {}}],
				"history": [],
				"events": [],
			},
		})
		var track := surfaces.get("card_resolution_track", {}) as Dictionary
		var overlay := PROJECTION.detached_copy(track.get("overlay", {}))
		_expect(bool(PROJECTION.validation_report(overlay).get("valid", false)), "%s group window produces a valid typed overlay" % phase)
		_expect(str(overlay.get("title", "")).begins_with("共享窗·") \
			and str(overlay.get("body_text", "")).contains("G2·1/2 生命工厂") \
			and str(overlay.get("body_text", "")).contains("GDP份额") \
			and (overlay.get("badge_labels", []) as Array).has("候补1") \
			and (overlay.get("badge_labels", []) as Array).has("下批1"), "%s preserves viewer-safe group order, requirement, and queue counts" % phase)


func _test_closed_and_public_only_contract() -> void:
	var closed := _compose_overlay(PROJECTION.MODE_V06_LEGACY, "resolving", false, 12, 99, 7.0)
	_expect(bool(PROJECTION.validation_report(closed).get("valid", false)), "closed overlay remains a valid typed projection")
	_expect(not bool(closed.get("visible", true)) and str(closed.get("phase_id", "")) == "idle" \
		and int(closed.get("resolution_id", -2)) == -1 \
		and int(closed.get("remaining_milliseconds", -1)) == 0, "closed projection canonicalizes phase, identity, and timer")
	_expect(str(closed.get("visibility_scope", "")) == "public" \
		and TablePresentationPureDataPolicy.is_pure_data(closed) \
		and PlayerVisibleSurfacePolicy.is_safe_closed_data(closed), "closed projection is public-only privacy-safe pure data")
	var counter := _compose_overlay(PROJECTION.MODE_V06_LEGACY, "counter", true, 13, 42, 3.0)
	_expect(str(counter.get("visibility_scope", "")) == "public" \
		and TablePresentationPureDataPolicy.is_pure_data(counter) \
		and PlayerVisibleSurfacePolicy.is_safe_closed_data(counter), "visible projection is public-only privacy-safe pure data")
	var private_scope := _projection_source(PROJECTION.MODE_V06_LEGACY, "counter", true, 14, 43, 2.0)
	private_scope["visibility_scope"] = "viewer_private"
	_expect(PROJECTION.build(private_scope).is_empty(), "viewer-private overlay scope fails closed")
	var hidden_owner := _projection_source(PROJECTION.MODE_V06_LEGACY, "counter", true, 15, 44, 2.0)
	hidden_owner["hidden_owner"] = "player.7"
	_expect(PROJECTION.build(hidden_owner).is_empty(), "closed schema rejects hidden-owner payloads")
	var runtime_object := _projection_source(PROJECTION.MODE_V06_LEGACY, "counter", true, 16, 45, 2.0)
	runtime_object["body_text"] = Node.new()
	_expect(PROJECTION.build(runtime_object).is_empty(), "runtime Objects fail the pure-data boundary")
	(runtime_object.get("body_text") as Node).free()
	var invalid_closed := _projection_source(PROJECTION.MODE_V06_LEGACY, "idle", false, 17, 12, 1.0)
	_expect(PROJECTION.build(invalid_closed).is_empty(), "closed overlay cannot retain a resolution identity or timer")


func _test_v07_production_gate() -> void:
	var query_source := FileAccess.get_file_as_string("res://scripts/presentation/table_presentation_viewmodel_query.gd")
	var program_source := FileAccess.get_file_as_string("res://AGENTS.md")
	_expect(query_source.contains('"resolution_runtime_mode": CARD_RESOLUTION_OVERLAY_PROJECTION_SCRIPT.MODE_V06_LEGACY'), "production query explicitly selects the V0.6 adapter")
	_expect(not query_source.contains("MODE_V07_UNINTERRUPTED"), "production query has no V0.7 runtime-mode selection path")
	_expect(program_source.contains("FULL_V0_7_RUNTIME_CUTOVER=false"), "program constitution still marks the V0.7 runtime cutover disabled")
	var future_reference := _compose_overlay(PROJECTION.MODE_V07_UNINTERRUPTED, "resolving", true, 18, 46, 1.0)
	_expect(bool(PROJECTION.validation_report(future_reference).get("valid", false)) \
		and not bool(future_reference.get("counter_response_visible", true)) \
		and str(future_reference.get("gameplay_input_mode", "")) == "NONE", "V0.7 remains a typed future adapter without counter input")


func _test_typed_target_stale_and_duplicate_behavior() -> void:
	var target := TARGET_SCENE.instantiate() as TARGET_SCRIPT
	root.add_child(target)
	await process_frame
	var counter := _compose_overlay(PROJECTION.MODE_V06_LEGACY, "counter", true, 20, 51, 5.0)
	_expect(target.apply_projection(counter), "typed target applies the current V0.6 counter projection")
	var after_first: Dictionary = target.debug_snapshot()
	_expect(bool(after_first.get("visible", false)) and int(after_first.get("apply_count", 0)) == 1, "first projection renders exactly once")
	_expect(target.apply_projection(counter), "identical projection is handled idempotently")
	var after_duplicate: Dictionary = target.debug_snapshot()
	_expect(int(after_duplicate.get("apply_count", -1)) == 1 \
		and int(after_duplicate.get("duplicate_count", 0)) == 1, "duplicate projection is rejected from a second target apply")
	var conflicting := _compose_overlay(PROJECTION.MODE_V06_LEGACY, "resolving", true, 20, 52, 2.0)
	_expect(not target.apply_projection(conflicting), "same revision with a different fingerprint is rejected")
	_expect(int(target.debug_snapshot().get("conflict_count", 0)) == 1 \
		and int(target.debug_snapshot().get("apply_count", -1)) == 1, "revision conflict preserves the first exact-once apply")
	var stale := _compose_overlay(PROJECTION.MODE_V06_LEGACY, "resolving", true, 19, 52, 2.0)
	_expect(not target.apply_projection(stale), "older projection revision is rejected")
	var after_stale: Dictionary = target.debug_snapshot()
	_expect(int(after_stale.get("apply_count", -1)) == 1 \
		and int(after_stale.get("stale_count", 0)) == 1 \
		and bool(after_stale.get("visible", false)), "stale rejection preserves the current rendered projection")
	var current := _compose_overlay(PROJECTION.MODE_V06_LEGACY, "resolving", true, 21, 53, 1.0)
	_expect(target.apply_projection(current), "newer typed projection advances the target")
	var target_debug: Dictionary = target.debug_snapshot()
	_expect(int(target_debug.get("apply_count", 0)) == 2 \
		and not bool(target_debug.get("mutates_gameplay", true)) \
		and not bool(target_debug.get("accepts_gameplay_input", true)), "target is read-only and owns no gameplay input")
	var target_source := FileAccess.get_file_as_string("res://scripts/ui/table/card_resolution_overlay.gd")
	for forbidden in ["WorldSessionState", "RunRngService", "GameRuntimeCoordinator", "submit_intent", "game_action", "counter_window_active"]:
		_expect(not target_source.contains(forbidden), "target source does not calculate or mutate %s" % forbidden)
	target.queue_free()
	await process_frame


func _test_overlay_layer_pipeline_and_zero_mutation() -> void:
	var layer := OVERLAY_LAYER_SCENE.instantiate()
	root.add_child(layer)
	await process_frame
	var emitted := {"count": 0}
	for signal_name in [
		"side_drawer_action_requested",
		"temporary_decision_action_requested",
		"public_bid_action_requested",
		"map_layer_focus_requested",
	]:
		if layer.has_signal(signal_name):
			layer.connect(signal_name, func(_value: Variant) -> void: emitted["count"] = int(emitted.get("count", 0)) + 1)
	var gameplay_sentinel := {
		"cash": 100,
		"inventory": ["unchanged"],
		"world_revision": 77,
	}
	var before := gameplay_sentinel.duplicate(true)
	var counter := _compose_overlay(PROJECTION.MODE_V06_LEGACY, "counter", true, 30, 61, 4.0)
	_expect(bool(layer.call("apply_card_resolution_presentation", counter)), "OverlayLayer forwards one typed projection to its scene-owned target")
	var target := layer.get_node_or_null("RuntimeSurfaceLayer/CardResolutionTableBannerOverlay") as TARGET_SCRIPT
	var debug: Dictionary = target.debug_snapshot() if target != null else {}
	_expect(target != null and bool(debug.get("visible", false)) \
		and int(debug.get("apply_count", 0)) == 1, "production OverlayLayer contains and updates one resolution target")
	_expect(gameplay_sentinel == before and int(emitted.get("count", 0)) == 0, "presentation apply changes no gameplay state and emits no gameplay action")
	var service_debug: Dictionary = _viewmodel.debug_snapshot()
	_expect(not bool(service_debug.get("calculates_play_legality", true)) \
		and not bool(service_debug.get("mutates_game_state", true)) \
		and not bool(service_debug.get("reads_runtime_nodes", true)), "ViewModel composes presentation only and calculates no gameplay rules")
	layer.call("clear_card_resolution_presentation")
	_expect(not bool(target.debug_snapshot().get("visible", true)), "OverlayLayer clear closes the transient target")
	layer.queue_free()
	await process_frame


func _compose_overlay(
	mode: String,
	phase: String,
	visible: bool,
	revision: int,
	resolution_id: int,
	remaining_seconds: float
) -> Dictionary:
	var surfaces := _viewmodel.compose_card_surfaces({
		"track": {
			"resolution_runtime_mode": mode,
			"resolution_overlay_source": {
				"revision": revision,
				"overlay": {
					"visible": visible,
					"phase": phase,
					"resolution_id": resolution_id,
					"remaining_seconds": remaining_seconds,
					"card_name": "匿名公开牌",
				},
			},
			"history": [],
			"queue": [],
			"next_queue": [],
			"events": [],
		},
	})
	var track: Dictionary = surfaces.get("card_resolution_track", {}) \
		if surfaces.get("card_resolution_track", {}) is Dictionary else {}
	return PROJECTION.detached_copy(track.get("overlay", {}))


func _projection_source(
	mode: String,
	phase: String,
	visible: bool,
	revision: int,
	resolution_id: int,
	remaining_seconds: float
) -> Dictionary:
	return {
		"schema_version": PROJECTION.SCHEMA_VERSION,
		"resolution_runtime_mode": mode,
		"source_revision": revision,
		"visible": visible,
		"phase_id": phase,
		"resolution_id": resolution_id,
		"remaining_milliseconds": maxi(0, int(round(remaining_seconds * 1000.0))),
		"title": "匿名公开牌" if visible else "",
		"status_text": "公开结算" if visible else "",
		"body_text": "公开效果摘要" if visible else "",
		"card_kind": "ordinary" if visible else "",
		"card_tags": "public" if visible else "",
		"accent_hex": "#fb7185",
		"rank": 1 if visible else 0,
		"art_stats": "" if not visible else "公开",
		"illustration_key": "" if not visible else "card.public",
		"badge_labels": ["公开"] if visible else [],
		"counter_response_visible": visible and mode == PROJECTION.MODE_V06_LEGACY and phase == "counter",
		"gameplay_input_mode": "V06_COUNTER_RESPONSE" \
			if visible and mode == PROJECTION.MODE_V06_LEGACY and phase == "counter" else "NONE",
		"visibility_scope": "public",
	}


func _expect(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)


func _finish() -> void:
	var status := "PASS" if _failures.is_empty() else "FAIL"
	print("CARD_RESOLUTION_OVERLAY_TYPED_PIPELINE_TEST|status=%s|checks=%d|failures=%d" % [status, _checks, _failures.size()])
	for failure in _failures:
		push_error("CARD_RESOLUTION_OVERLAY_TYPED_PIPELINE_TEST: %s" % failure)
	_viewmodel.free()
	quit(0 if _failures.is_empty() else 1)
