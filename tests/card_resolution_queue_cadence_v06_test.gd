extends SceneTree

const QUEUE_SCRIPT := preload("res://scripts/runtime/card_resolution_queue_runtime_service.gd")
const PROFILE := preload("res://resources/rules/space_syndicate_ruleset_v06.tres")
const VALIDATOR := preload("res://scripts/rules/ruleset_v06_validator.gd")

var _failures: Array[String] = []
var _checks := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var validation: Dictionary = VALIDATOR.validate(PROFILE)
	_expect(bool(validation.get("valid", false)), "v0.6 profile validates the 30/20/5/5 cadence")
	var queue := QUEUE_SCRIPT.new()
	root.add_child(queue)
	queue.configure({"ruleset_id": "v0.6", "card_group": PROFILE.card_group_rules()})
	_expect(bool((queue.debug_snapshot() as Dictionary).get("service_ready", false)), "queue accepts only the authored v0.6 cadence")

	var first := _submit(queue, 0, 0, _facts(0, 45.0), {})
	_expect(bool((first.get("commit", {}) as Dictionary).get("committed", false)), "first ordinary card commits")
	_expect(int(((first.get("commit", {}) as Dictionary).get("entry", {}) as Dictionary).get("window_sequence", -1)) == 0, "new game first batch starts at sequence zero")
	var forged_second := _submit(queue, 0, 1, _facts(0, 44.0), {"actor_id": "player.0", "group_card_limit": 3, "max_cards": 3, "extra_submission_capability": "forged.request"})
	_expect(not bool((forged_second.get("plan", {}) as Dictionary).get("accepted", true)) and str((forged_second.get("plan", {}) as Dictionary).get("reason", "")) == "group_full", "ordinary player cannot raise the one-card limit")
	var stale_facts := _facts_with_capability(0, 44.0, 0, "player.0", 1, 0, 0, 5, 4)
	var stale := _submit(queue, 0, 1, stale_facts, {"actor_id": "player.0", "max_cards": 2})
	_expect(str((stale.get("plan", {}) as Dictionary).get("capability_reason", "")) == "capability_revision_stale", "stale owner revision cannot authorize an extra card")
	var early_facts := _facts_with_capability(0, 44.0, 0, "player.0", 1, 1, 2, 5, 5)
	var early := _submit(queue, 0, 1, early_facts, {"actor_id": "player.0", "max_cards": 2})
	_expect(str((early.get("plan", {}) as Dictionary).get("capability_reason", "")) == "capability_not_active", "capability cannot activate before its window")
	var wrong_actor_facts := _facts_with_capability(0, 44.0, 1, "player.1", 1, 0, 0, 5, 5)
	var wrong_actor := _submit(queue, 0, 1, wrong_actor_facts, {"actor_id": "player.0", "max_cards": 2})
	_expect(str((wrong_actor.get("plan", {}) as Dictionary).get("capability_reason", "")) == "capability_actor_mismatch", "wrong actor capability cannot authorize a card")
	var wrong_window_facts := _facts_with_capability(0, 44.0, 0, "player.0", 1, 0, 1, 5, 5)
	(wrong_window_facts.get("extra_submission_capability", {}) as Dictionary)["window_sequence"] = 1
	var wrong_window := _submit(queue, 0, 1, wrong_window_facts, {"actor_id": "player.0", "max_cards": 2})
	_expect(str((wrong_window.get("plan", {}) as Dictionary).get("capability_reason", "")) == "capability_window_mismatch", "wrong window capability cannot authorize a card")

	var plus_one_facts := _facts_with_capability(0, 44.0, 0, "player.0", 1, 0, 0, 5, 5)
	var second := _submit(queue, 0, 1, plus_one_facts, {"actor_id": "player.0", "max_cards": 3})
	_expect(bool((second.get("commit", {}) as Dictionary).get("committed", false)), "authoritative plus-one capability permits a second card")
	var plus_one_third := _submit(queue, 0, 2, plus_one_facts, {"actor_id": "player.0", "max_cards": 3})
	_expect(not bool((plus_one_third.get("plan", {}) as Dictionary).get("accepted", true)) and int((plus_one_third.get("plan", {}) as Dictionary).get("card_limit", 0)) == 2, "plus-one capability stops at an effective limit of two")
	var hard_cap_facts := _facts_with_capability(0, 43.0, 0, "player.0", 2, 0, 0, 6, 6)
	var third := _submit(queue, 0, 2, hard_cap_facts, {"actor_id": "player.0", "max_cards": 3})
	_expect(bool((third.get("commit", {}) as Dictionary).get("committed", false)), "authoritative general capability permits a third card")
	var current: Array = queue.current_queue()
	_expect(current.size() == 3 and current.all(func(entry: Dictionary) -> bool: return int(entry.get("window_sequence", -1)) == 0), "same batch preserves sequence zero")
	var fourth := _submit(queue, 0, 3, hard_cap_facts, {"actor_id": "player.0", "max_cards": 3})
	_expect(str((fourth.get("plan", {}) as Dictionary).get("reason", "")) == "group_full", "explicit capability hard-stops at three")
	var bid_phase := _submit(queue, 1, 0, _facts(0, 10.0), {})
	_expect(str((bid_phase.get("plan", {}) as Dictionary).get("reason", "")) == "public_bid_phase", "queue rejects submissions in public bid")

	var locked: Dictionary = queue.lock_batch({"reference_player": 0, "player_count": 3})
	_expect(bool(locked.get("locked", false)), "current batch locks without acquiring bid or cash ownership")
	var started: Dictionary = queue.start_next()
	_expect(bool(started.get("started", false)), "one active entry starts")
	var counter := _submit(queue, 1, 0, {
		"player_count": 3,
		"batch_locked": true,
		"counter_window_active": true,
		"simultaneous_timer": 0.0,
		"window_sequence": 0,
	}, {"reactive_counter": true})
	_expect(str((counter.get("commit", {}) as Dictionary).get("route", "")) == "next", "counter waits in next queue")
	queue.complete_active(-1)
	queue.replace_current_queue([])
	var promoted: Dictionary = queue.promote_next_batch({"window_sequence": 0, "game_time": 2.0, "previous_player": 0, "player_count": 3})
	_expect(bool(promoted.get("promoted", false)) and int(promoted.get("window_sequence", -1)) == 1, "next queue promotion advances sequence to one")
	queue.replace_current_queue([])
	var later := _submit(queue, 2, 0, _facts(0, 45.0), {})
	_expect(int(((later.get("plan", {}) as Dictionary).get("entry", {}) as Dictionary).get("window_sequence", -1)) == 2, "later idle batch cannot reuse sequence zero")
	if bool((later.get("plan", {}) as Dictionary).get("accepted", false)):
		queue.commit_submission(later.get("plan", {}) as Dictionary, _commit_receipt())
	queue.replace_current_queue([])
	var saved: Dictionary = queue.to_legacy_save_snapshot()
	_expect(int(saved.get("card_group_last_window_sequence", -1)) == 2, "save data preserves last allocated sequence")

	var restored := QUEUE_SCRIPT.new()
	root.add_child(restored)
	restored.configure({"ruleset_id": "v0.6", "card_group": PROFILE.card_group_rules()})
	restored.apply_legacy_save_snapshot(saved)
	var restored_plan: Dictionary = restored.plan_submission(_request(0, 0, {}), _facts(0, 45.0))
	_expect(int((restored_plan.get("entry", {}) as Dictionary).get("window_sequence", -1)) == 3, "save/load preserves deterministic next sequence")
	var debug: Dictionary = queue.debug_snapshot()
	_expect(not bool(debug.get("priority_bid_authority", true)) and not bool(debug.get("cash_authority", true)) and not bool(debug.get("inventory_authority", true)), "queue retains its narrow ownership boundary")

	queue.queue_free()
	restored.queue_free()
	_finish()


func _submit(queue: Node, player_index: int, slot_index: int, facts: Dictionary, overrides: Dictionary) -> Dictionary:
	var request := _request(player_index, slot_index, overrides)
	var plan: Dictionary = queue.plan_submission(request, facts)
	var commit: Dictionary = {}
	if bool(plan.get("accepted", false)):
		commit = queue.commit_submission(plan, _commit_receipt())
	return {"plan": plan, "commit": commit}


func _request(player_index: int, slot_index: int, overrides: Dictionary) -> Dictionary:
	var request := {
		"player_index": player_index,
		"slot_index": slot_index,
		"already_queued": false,
		"play_cash_cost_cents": 0,
		"financial_margin_cents": 0,
		"available_cash_cents": 100000,
		"skill": {"name": "qa.card.%d.%d" % [player_index, slot_index], "kind": "qa", "persistent": true},
	}
	request.merge(overrides, true)
	return request


func _facts(window_sequence: int, remaining: float) -> Dictionary:
	return {
		"player_count": 3,
		"batch_locked": false,
		"counter_window_active": false,
		"simultaneous_timer": remaining,
		"lock_duration": 5.0,
		"public_bid_duration": 5.0,
		"window_sequence": window_sequence,
		"reference_player": 0,
	}


func _facts_with_capability(window_sequence: int, remaining: float, player_index: int, actor_id: String, bonus_limit: int, activation_sequence: int, expiry_sequence: int, owner_revision: int, current_owner_revision: int) -> Dictionary:
	var facts := _facts(window_sequence, remaining)
	facts["extra_submission_capability_authoritative"] = true
	facts["extra_submission_capability_owner_revision"] = current_owner_revision
	facts["extra_submission_capability"] = {
		"actor_id": actor_id,
		"player_index": player_index,
		"window_sequence": window_sequence,
		"owner_revision": owner_revision,
		"capability_id": "qa.extra_submission.%s" % actor_id,
		"base_limit": 1,
		"bonus_limit": bonus_limit,
		"effective_limit": clampi(1 + bonus_limit, 1, 3),
		"activation_window_sequence": activation_sequence,
		"expiry_window_sequence": expiry_sequence,
		"hard_cap": 3,
	}
	return facts


func _commit_receipt() -> Dictionary:
	return {
		"authorized": true,
		"inventory_committed": true,
		"play_cost_authorized": true,
		"financial_margin_authorized": true,
		"asset_authorized": true,
	}


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		print("PASS: %s" % message)
		return
	_failures.append(message)
	push_error("CARD QUEUE CADENCE: %s" % message)


func _finish() -> void:
	if _failures.is_empty():
		print("Card resolution queue cadence v0.6 test passed. checks=%d" % _checks)
		quit(0)
		return
	push_error("Card resolution queue cadence v0.6 test failed:\n- %s" % "\n- ".join(_failures))
	quit(1)
