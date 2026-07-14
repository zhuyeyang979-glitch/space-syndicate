extends SceneTree

const RULESET_BRIDGE_SCENE := preload("res://scenes/runtime/RulesetRuntimeBridge.tscn")
const COORDINATOR_SCENE := preload("res://scenes/runtime/GameRuntimeCoordinator.tscn")
const WINDOW_SCENE := preload("res://scenes/runtime/CardResolutionRuntimeController.tscn")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var host := Node.new()
	root.add_child(host)
	var ruleset_bridge := RULESET_BRIDGE_SCENE.instantiate()
	var coordinator := COORDINATOR_SCENE.instantiate()
	host.add_child(ruleset_bridge)
	host.add_child(coordinator)
	coordinator.call("configure", ruleset_bridge.call("active_profile"))
	_expect(coordinator.get_node_or_null("CardResolutionQueueRuntimeService") != null and coordinator.get_node_or_null("IndustryCapacityRuntimeService") != null, "real GameRuntimeCoordinator statically owns Queue and Industry Capacity services")
	_expect(str((ruleset_bridge.call("active_profile") as Dictionary).get("ruleset_id", "")) == "v0.4", "global production Ruleset bridge remains v0.4")

	var queue := coordinator.get_node_or_null("CardResolutionQueueRuntimeService")
	_expect(queue != null and bool((queue.call("debug_snapshot") as Dictionary).get("service_ready", false)), "scene-owned Queue service runs the v0.5 card-group domain")
	if queue == null:
		host.free()
		_finish()
		return
	queue.call("reset_state")
	var first := _submit(queue, 0, 0, 10000, 2)
	var second := _submit(queue, 0, 1, 10000, 2)
	var third := _submit(queue, 0, 2, 10000, 2)
	_expect(bool((first.get("commit", {}) as Dictionary).get("committed", false)) and bool((second.get("commit", {}) as Dictionary).get("committed", false)), "standard runtime accepts two cards in one player group")
	_expect(not bool((third.get("plan", {}) as Dictionary).get("accepted", true)) and str((third.get("plan", {}) as Dictionary).get("reason", "")) == "group_full", "standard runtime rejects the third card atomically")
	var grouped: Array = queue.call("current_queue")
	_expect(grouped.size() == 2 and str((grouped[0] as Dictionary).get("group_id", "")) == str((grouped[1] as Dictionary).get("group_id", "")), "two cards share one stable group id")
	_expect(int((grouped[0] as Dictionary).get("group_order", 0)) == 1 and int((grouped[1] as Dictionary).get("group_order", 0)) == 2, "group order is stable at one and two")

	var same_bid_other_player := _submit(queue, 1, 0, 10000, 2)
	_expect(bool((same_bid_other_player.get("commit", {}) as Dictionary).get("committed", false)), "equal fixed bids from different groups are legal")
	var invalid_bid := _submit(queue, 2, 0, 7500, 2)
	_expect(str((invalid_bid.get("plan", {}) as Dictionary).get("reason", "")) == "invalid_priority_bid", "arbitrary bid values are rejected")
	var locked: Dictionary = queue.call("lock_batch", {"reference_player": 3, "player_count": 4})
	var receipt: Dictionary = locked.get("public_wager_pool_receipt", {}) if locked.get("public_wager_pool_receipt", {}) is Dictionary else {}
	_expect(bool(locked.get("locked", false)) and int(receipt.get("total_cents", 0)) == 20000, "all fixed bids enter the public monster wager pool")
	_expect(str(receipt.get("recipient_kind", "")) == "public_monster_wager_pool" and not JSON.stringify(receipt).contains("previous_group"), "old previous-group bid chain is absent")
	var duplicate_lock: Dictionary = queue.call("lock_batch", {"reference_player": 3, "player_count": 4})
	_expect(not bool(duplicate_lock.get("locked", true)) and str(duplicate_lock.get("reason", "")) == "wager_pool_receipt_duplicate", "wager pool receipt is exact once")
	var public_snapshot: Dictionary = queue.call("public_snapshot")
	_expect(not JSON.stringify(public_snapshot).contains("player_index") and not JSON.stringify(public_snapshot).contains("payer_player_index"), "public queue snapshot hides group owners and wager payers")
	var save_data: Dictionary = queue.call("to_legacy_save_snapshot")
	_expect(save_data.has("card_wager_receipt_ids") and save_data.has("card_last_wager_receipt"), "save adapter preserves v0.5 queue receipt identity without changing the outer save version")

	var window := WINDOW_SCENE.instantiate()
	host.add_child(window)
	window.call("configure", {"total_window_seconds": 8.0, "lock_seconds": 2.0})
	window.call("begin_group_window", -1.0, 3, 9)
	_expect(is_equal_approx(float(window.get("simultaneous_timer")), 8.0), "runtime controller starts an eight-second window")
	window.call("set_player_ready", 0, true, [0, 1])
	window.call("set_player_ready", 1, true, [0, 1])
	var commands: Array = window.call("tick", 0.0, {"queue_empty": false, "active_present": false, "active_player_indices": [0, 1], "lock_duration": 2.0})
	_expect(_has_transition(commands, "all_ready_lock") and _has_transition(commands, "lock_batch"), "all active players ready locks the batch early")
	host.free()
	_finish()


func _submit(queue: Node, player_index: int, slot_index: int, bid_cents: int, group_limit: int) -> Dictionary:
	var current: Array = queue.call("current_queue")
	var window_sequence := int((current[0] as Dictionary).get("window_sequence", 0)) if not current.is_empty() else 0
	var plan: Dictionary = queue.call("plan_submission", {
		"player_index": player_index,
		"slot_index": slot_index,
		"already_queued": false,
		"group_card_limit": group_limit,
		"priority_bid_cents": bid_cents,
		"play_cash_cost_cents": 0,
		"financial_margin_cents": 0,
		"available_cash_cents": 100000,
		"capacity_reservation": {"capacity_revision": "", "industries": {}, "requirement_choices": []},
		"skill": {"name": "qa.card.%d.%d" % [player_index, slot_index], "kind": "qa", "persistent": true},
	}, {
		"player_count": 4,
		"batch_locked": false,
		"counter_window_active": false,
		"simultaneous_timer": 8.0,
		"lock_duration": 2.0,
		"window_sequence": window_sequence,
		"reference_player": 3,
		"industry_capacity": {},
	})
	var commit := {}
	if bool(plan.get("accepted", false)):
		commit = queue.call("commit_submission", plan, {
			"authorized": true,
			"inventory_committed": true,
			"play_cost_authorized": true,
			"financial_margin_authorized": true,
			"priority_bid_escrow_authorized": true,
			"capacity_authorized": true,
		})
	return {"plan": plan, "commit": commit}


func _has_transition(commands: Array, transition: String) -> bool:
	for command_variant in commands:
		if command_variant is Dictionary and str((command_variant as Dictionary).get("transition", "")) == transition:
			return true
	return false


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append(message)
		push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("Shared card group runtime test passed.")
	else:
		push_error("Shared card group runtime test failed:\n- " + "\n- ".join(_failures))
	quit(_failures.size())
