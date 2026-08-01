extends SceneTree

const MAIN_SCENE := preload("res://scenes/main.tscn")
const INSPECTOR := preload("res://scripts/tools/card_inventory_checkpoint_purity_inspector_v1.gd")

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var main := MAIN_SCENE.instantiate()
	var lifecycle := main.get_node_or_null("RuntimeServices/MenuLifecycleApplicationFlowController")
	if lifecycle != null:
		lifecycle.set("open_root_on_ready", false)
	root.add_child(main)
	await process_frame
	await process_frame
	var services := main.get_node_or_null("RuntimeServices")
	var coordinator := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator
	var session := coordinator.get_node_or_null("GameSessionRuntimeController") if coordinator != null else null
	var draft := services.get_node_or_null("NewGameSetupDraftService") as NewGameSetupDraftService if services != null else null
	var transaction := services.get_node_or_null("SessionStartTransactionCoordinator") as SessionStartTransactionCoordinator if services != null else null
	var started := false
	if draft != null and transaction != null and session != null:
		draft.reset_to_defaults()
		var request := SessionStartRequest.create(
			"alpha04c-card-inventory-full-characterization",
			draft.draft_snapshot(),
			session.session_start_revision(),
			"focused_test"
		)
		var receipt := transaction.start_session(request)
		started = receipt != null and receipt.applied
	_expect(started, "real production V0.6 session starts")
	if not started or coordinator == null:
		await _finish(main)
		return
	main.process_mode = Node.PROCESS_MODE_DISABLED
	var owner := coordinator.get_node_or_null("CardInventorySaveOwner") as CardInventorySaveOwner
	var commodity := coordinator.commodity_card_inventory_runtime_controller()
	var product_market := coordinator.product_market_runtime_controller()
	var district := coordinator.get_node_or_null("DistrictPurchaseRuntimeController") as DistrictPurchaseRuntimeController
	_expect(owner != null and commodity != null and product_market != null and district != null, "all real Card Inventory owners are composed")
	if owner == null or commodity == null or product_market == null or district == null:
		await _finish(main)
		return
	var supply_revision := "alpha04c-characterization-v7"
	var card_id := "alpha04c.characterization.pending"
	var opened := district.open_window(0, 0, {"supply_revision": supply_revision})
	_expect(not opened.is_empty(), "real District Purchase window creates the V7 integer-key state")
	var quote := coordinator.card_market_quote({
		"player_index": 0,
		"district_index": 0,
		"card_id": card_id,
		"supply_revision": supply_revision,
		"base_price": 101,
	})
	var pending := district.reserve_pending_discard({
		"player_index": 0,
		"district_index": 0,
		"card_id": card_id,
		"quote_id": str(quote.get("quote_id", "")),
		"price": int(quote.get("final_price", -1)),
		"opened_at": 12.125,
	})
	_expect(not str(quote.get("quote_id", "")).is_empty() and not pending.is_empty(), "real pending-discard state exposes the production opened_at float path")

	var save_payload := owner.to_save_data()
	var runtime_checkpoint := owner.capture_runtime_checkpoint()
	var captures := {
		"persistent_save": save_payload,
		"runtime_checkpoint": runtime_checkpoint,
		"commodity_save": commodity.to_save_data(),
		"commodity_checkpoint": commodity.capture_runtime_checkpoint(),
		"product_market_save": product_market.to_save_data(),
		"product_market_checkpoint": product_market.capture_runtime_checkpoint(),
		"district_purchase_save": district.to_save_data(),
		"district_purchase_checkpoint": district.capture_runtime_checkpoint(),
	}
	var capture_contexts := {
		"persistent_save": {"child_id": "card_inventory", "method": "to_save_data"},
		"runtime_checkpoint": {"child_id": "card_inventory", "method": "capture_runtime_checkpoint"},
		"commodity_save": {"child_id": "commodity_card_inventory", "method": "to_save_data"},
		"commodity_checkpoint": {"child_id": "commodity_card_inventory", "method": "capture_runtime_checkpoint"},
		"product_market_save": {"child_id": "product_market", "method": "to_save_data"},
		"product_market_checkpoint": {"child_id": "product_market", "method": "capture_runtime_checkpoint"},
		"district_purchase_save": {"child_id": "district_purchase", "method": "to_save_data"},
		"district_purchase_checkpoint": {"child_id": "district_purchase", "method": "capture_runtime_checkpoint"},
	}
	var path_policy := {
		"default": {
			"authoritative_state": true,
			"presentation_only": false,
			"rebindable_dependency": false,
		},
		"suffixes": {
			".pending_payload.opened_at": {
				"authoritative_state": false,
				"presentation_only": true,
				"rebindable_dependency": false,
			},
		},
	}
	var reports: Dictionary = {}
	for capture_id_variant in captures.keys():
		var capture_id := str(capture_id_variant)
		var context := capture_contexts.get(capture_id, {}) as Dictionary
		var root_child_id := str(context.get("child_id", "card_inventory"))
		var method_name := str(context.get("method", "capture_runtime_checkpoint"))
		var source_methods := {
			"commodity_card_inventory": method_name,
			"product_market": method_name,
			"district_purchase": method_name,
		}
		source_methods[root_child_id] = method_name
		reports[capture_id] = INSPECTOR.inspect(
			captures.get(capture_id),
			source_methods,
			root_child_id,
			path_policy
		)
	var save_report := reports.get("persistent_save", {}) as Dictionary
	var checkpoint_report := reports.get("runtime_checkpoint", {}) as Dictionary
	_expect(int(save_payload.get("schema_version", 0)) == 3, "pre-edit production Save remains schema v3")
	_expect(int(runtime_checkpoint.get("schema_version", 0)) == 1, "pre-edit composite checkpoint remains schema v1")
	_expect(int(save_report.get("strict_non_closed_leaf_count", 0)) > 0, "full production Save exposes strict non-closed leaves")
	_expect(int(checkpoint_report.get("strict_non_closed_leaf_count", 0)) > 0, "full production checkpoint exposes strict non-closed leaves")
	var checkpoint_paths := checkpoint_report.get("all_strict_non_closed_paths", []) as Array
	var save_paths := save_report.get("all_strict_non_closed_paths", []) as Array
	_expect(_contains_suffix(checkpoint_paths, "windows_by_player.<non_string_key:int>"), "District integer-key defect is present")
	_expect(_contains_suffix(checkpoint_paths, ".pending_payload.opened_at"), "District pending metadata float is present in the runtime checkpoint")
	_expect(_contains_suffix(save_paths, ".growth_multiplier"), "Product growth float defect is present")
	_expect(_contains_suffix(save_paths, ".market_timer"), "market timer float defect is present")
	_expect(_contains_suffix(save_paths, ".pending_payload.opened_at"), "District pending metadata float is present in persistent Save")
	var forbidden := _forbidden_dependency_records(reports)
	_expect(forbidden.is_empty(), "no Object, Node, Resource, Callable, or RID enters any inspected wire payload")
	_expect(not save_payload.is_empty() and bool(runtime_checkpoint.get("captured", false)), "both real composite captures succeed")

	print("CARD_INVENTORY_FULL_CLOSED_WIRE_CHARACTERIZATION|%s" % JSON.stringify({
		"persistent_save": _report_summary(save_report),
		"runtime_checkpoint": _report_summary(checkpoint_report),
		"children": {
			"commodity_save": _report_summary(reports.get("commodity_save", {}) as Dictionary),
			"commodity_checkpoint": _report_summary(reports.get("commodity_checkpoint", {}) as Dictionary),
			"product_market_save": _report_summary(reports.get("product_market_save", {}) as Dictionary),
			"product_market_checkpoint": _report_summary(reports.get("product_market_checkpoint", {}) as Dictionary),
			"district_purchase_save": _report_summary(reports.get("district_purchase_save", {}) as Dictionary),
			"district_purchase_checkpoint": _report_summary(reports.get("district_purchase_checkpoint", {}) as Dictionary),
		},
		"district_int_key_defect_present": _contains_suffix(checkpoint_paths, "windows_by_player.<non_string_key:int>"),
		"district_pending_opened_at_float_present": _contains_suffix(checkpoint_paths, ".pending_payload.opened_at") and _contains_suffix(save_paths, ".pending_payload.opened_at"),
		"product_growth_float_defect_present": _contains_suffix(save_paths, ".growth_multiplier"),
		"market_timer_float_defect_present": _contains_suffix(save_paths, ".market_timer"),
		"forbidden_dependency_records": forbidden,
	}))
	await _finish(main)


func _report_summary(report: Dictionary) -> Dictionary:
	return {
		"leaf_count": int(report.get("checkpoint_leaf_count", 0)),
		"non_closed_leaf_count": int(report.get("strict_non_closed_leaf_count", 0)),
		"non_closed_type_counts": (report.get("strict_non_closed_type_counts", {}) as Dictionary).duplicate(true),
		"all_non_closed_paths": (report.get("all_strict_non_closed_paths", []) as Array).duplicate(),
	}


func _contains_suffix(paths: Array, suffix: String) -> bool:
	for path_variant in paths:
		if str(path_variant).ends_with(suffix):
			return true
	return false


func _forbidden_dependency_records(reports: Dictionary) -> Array:
	var result: Array = []
	for report_id_variant in reports.keys():
		var report_id := str(report_id_variant)
		var report := reports.get(report_id, {}) as Dictionary
		for record_variant in report.get("strict_non_closed_leaves", []) as Array:
			var record := record_variant as Dictionary
			if str(record.get("variant_type", "")) in ["Object", "Callable", "RID"]:
				result.append({
					"report_id": report_id,
					"json_path": str(record.get("json_path", "")),
					"variant_type": str(record.get("variant_type", "")),
					"reason_code": str(record.get("strict_reason_code", "")),
				})
	return result


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _finish(main: Node) -> void:
	if main != null:
		main.queue_free()
	await process_frame
	print("ALPHA04C_CARD_INVENTORY_FULL_CLOSED_WIRE_CHARACTERIZATION_TEST|status=%s|checks=%d|failures=%d" % [
		"PASS" if _failures.is_empty() else "FAIL",
		_checks,
		_failures.size(),
	])
	if not _failures.is_empty():
		push_error("Full Card Inventory characterization failed:\n- " + "\n- ".join(_failures))
	quit(0 if _failures.is_empty() else 1)
