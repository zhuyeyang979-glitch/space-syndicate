extends SceneTree

const SERVICE_SCENE := "res://scenes/runtime/CardResolutionExecutionRuntimeService.tscn"

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load(SERVICE_SCENE) as PackedScene
	_expect(packed != null, "execution service scene loads")
	if packed == null:
		_finish()
		return
	var service := packed.instantiate() as Node
	_expect(service != null, "execution service scene instantiates")
	if service == null:
		_finish()
		return
	root.add_child(service)
	service.call("configure", {"ruleset_id": "v0.4"})

	var normal := service.call("plan_execution", _request(3701, "cash_gain")) as Dictionary
	_expect(bool(normal.get("ready", false)) and _next_kind(normal) == "counter_check", "normal execution starts with counter check")
	var normal_order: Array[String] = []
	normal = _drive(service, normal, normal_order, {})
	var expected_normal := [
		"counter_check", "release_active", "finish_presentation", "revalidate_requirement",
		"revalidate_target", "dispatch_effect", "finish_card_commitment", "create_aftermath",
		"restore_context", "append_history", "finish_batch",
	]
	_expect(normal_order == expected_normal, "normal execution follows the owned intent order")
	var normal_result := service.call("finalize_execution", normal) as Dictionary
	_expect(bool(normal_result.get("completed", false)) and bool(normal_result.get("effect_dispatched", false)), "normal execution finalizes after one effect dispatch")
	var duplicate := service.call("plan_execution", _request(3701, "cash_gain")) as Dictionary
	_expect(not bool(duplicate.get("ready", true)) and str(duplicate.get("reason", "")) == "already_completed", "completed resolution cannot be planned twice")

	var countered := service.call("plan_execution", _request(3702, "city_development")) as Dictionary
	var counter_order: Array[String] = []
	countered = _drive(service, countered, counter_order, {"countered": true})
	_expect(not counter_order.has("dispatch_effect") and not counter_order.has("revalidate_requirement"), "countered execution skips original validation and effect dispatch")
	var counter_result := service.call("finalize_execution", countered) as Dictionary
	_expect(bool(counter_result.get("completed", false)) and bool(counter_result.get("countered", false)), "countered execution still completes commitment and history")

	var stale := service.call("plan_execution", _request(3703, "product_speculation")) as Dictionary
	var stale_order: Array[String] = []
	stale = _drive(service, stale, stale_order, {"requirement_valid": false})
	_expect(not stale_order.has("dispatch_effect") and stale_order.has("finish_card_commitment") and stale_order.has("append_history"), "stale requirement keeps commitment and history without dispatch")
	_expect(bool((service.call("finalize_execution", stale) as Dictionary).get("completed", false)), "stale requirement transaction finalizes safely")

	var failed_release := service.call("plan_execution", _request(3704, "cash_gain")) as Dictionary
	failed_release = service.call("advance_execution", failed_release, {"intent_type": "counter_check", "countered": false}) as Dictionary
	failed_release = service.call("advance_execution", failed_release, {"intent_type": "release_active", "completed": false, "reason": "active_resolution_mismatch"}) as Dictionary
	_expect(str(failed_release.get("status", "")) == "aborted" and _next_kind(failed_release) == "" and not bool(failed_release.get("effect_dispatched", false)), "failed active release blocks effect dispatch")

	var promoted := service.call("plan_execution", _request(3705, "product_speculation")) as Dictionary
	var promoted_order: Array[String] = []
	promoted = _drive(service, promoted, promoted_order, {"next_queue_count": 1})
	_expect(promoted_order.has("promote_next_batch") and str(promoted.get("continuation_kind", "")) == "normal", "empty current queue promotes the next batch with the normal continuation")
	_expect(bool((service.call("finalize_execution", promoted) as Dictionary).get("completed", false)), "promoted execution finalizes")

	var missing_recovery := service.call("recover_from_active", {}, {}) as Dictionary
	_expect(not bool(missing_recovery.get("replay_allowed", true)) and str(missing_recovery.get("reason", "")) == "active_missing", "missing active state never replays an effect")
	var snapshot := service.call("debug_snapshot") as Dictionary
	_expect(_is_pure_data(snapshot), "execution service debug snapshot contains pure data only")
	_expect(bool(snapshot.get("execution_orchestration_authority", false)) and not bool(snapshot.get("queue_authority", true)) and not bool(snapshot.get("concrete_effect_authority", true)), "execution service advertises a narrow ownership boundary")

	service.queue_free()
	_finish()


func _drive(service: Node, transaction: Dictionary, order: Array[String], options: Dictionary) -> Dictionary:
	var guard := 0
	while _next_kind(transaction) != "" and guard < 20:
		guard += 1
		var intent_kind := _next_kind(transaction)
		order.append(intent_kind)
		var receipt := {"intent_type": intent_kind}
		match intent_kind:
			"counter_check":
				receipt["countered"] = bool(options.get("countered", false))
				receipt["counter_resolution_id"] = 991 if bool(receipt["countered"]) else -1
			"release_active": receipt["completed"] = true
			"finish_presentation": receipt["finished"] = true
			"revalidate_requirement":
				receipt["valid"] = bool(options.get("requirement_valid", true))
				receipt["reason"] = "requirement_invalid" if not bool(receipt["valid"]) else "valid"
			"revalidate_target": receipt["valid"] = true
			"dispatch_effect":
				receipt["dispatched"] = true
				receipt["resolved"] = true
				receipt["continuation_kind"] = str(options.get("continuation_kind", "normal"))
			"finish_card_commitment": receipt["committed"] = true
			"create_aftermath": receipt["entry_patch"] = {"aftermath_clue": "observed"}
			"restore_context": receipt["restored"] = true
			"append_history":
				receipt["appended"] = true
				receipt["current_queue_count"] = 0
			"finish_batch":
				receipt["finished"] = true
				receipt["next_queue_count"] = int(options.get("next_queue_count", 0))
			"promote_next_batch": receipt["promoted"] = true
			"start_next": receipt["started"] = true
		transaction = service.call("advance_execution", transaction, receipt) as Dictionary
	return transaction


func _request(resolution_id: int, kind: String) -> Dictionary:
	var skill := {"name": "QA Card", "kind": kind, "rank": 1}
	return {
		"active_entry": {
			"resolution_id": resolution_id,
			"queued_order": resolution_id,
			"player_index": 0,
			"slot_index": -1,
			"consumed_on_queue": true,
			"play_cost_paid_on_queue": true,
			"skill": skill,
		},
		"skill": skill,
		"target_kind": "none",
		"selection_context": {
			"selected_player": 0,
			"selected_district": 0,
			"selected_trade_product": "QA Product",
			"contract_source_district": -1,
			"contract_target_district": -1,
		},
	}


func _next_kind(transaction: Dictionary) -> String:
	var next: Dictionary = transaction.get("next_intent", {}) if transaction.get("next_intent", {}) is Dictionary else {}
	return str(next.get("intent_type", ""))


func _is_pure_data(value: Variant) -> bool:
	if value is Callable or value is Node or value is Object:
		return false
	if value is Dictionary:
		for key in (value as Dictionary).keys():
			if not _is_pure_data(key) or not _is_pure_data((value as Dictionary)[key]):
				return false
	if value is Array:
		for item in value as Array:
			if not _is_pure_data(item):
				return false
	return true


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
		return
	_failures.append(message)
	push_error("CARD RESOLUTION EXECUTION SERVICE: %s" % message)


func _finish() -> void:
	if _failures.is_empty():
		print("Card resolution execution runtime service test passed.")
		quit(0)
		return
	push_error("Card resolution execution runtime service test failed:\n- %s" % "\n- ".join(_failures))
	quit(1)
