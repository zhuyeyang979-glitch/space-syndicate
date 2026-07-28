extends SceneTree

const PURE = preload("res://scripts/semantic/card_batch_pure_data.gd")
const TARGET = preload("res://scripts/semantic/card_batch_prebound_target_spec_v1.gd")
const SUBMISSION = preload("res://scripts/semantic/card_batch_submission_v1.gd")
const INVENTORY = preload("res://scripts/semantic/card_batch_inventory_state_v1.gd")
const STATE = preload("res://scripts/semantic/card_batch_state_v1.gd")
const RUNTIME = preload("res://scripts/runtime/card_batch_reference_runtime.gd")
const VIEWER_AUTHORIZATION = preload("res://scripts/semantic/card_batch_viewer_authorization_v1.gd")
const AUTHORED_RULE = preload("res://scripts/semantic/card_batch_authored_rule_v1.gd")

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_pure_contracts()
	_test_three_independent_pools()
	_test_bound_action_availability_lifecycle()
	_test_supported_roster_sizes()
	_test_one_shot_window_and_deterministic_order()
	_test_target_invalidation_policies()
	_test_automatic_defense_and_time_pause()
	_test_empty_batch_completion_gate()
	_finish()


func _test_pure_contracts() -> void:
	var binding := TARGET.build("factory", ["factory.alpha"], 3, "slot.2", "install", 2, {"effect_amount": 4})
	_expect(bool(TARGET.validate(binding).get("valid", false)), "prebound target stores target, revision, slot, mode, quantity, and authored parameters as pure data")
	_expect(TARGET.fingerprint(binding).length() == 64, "prebound target has a stable SHA-256 fingerprint")
	var reordered := {
		"quantity": 2,
		"mode_id": "install",
		"placement_slot_id": "slot.2",
		"target_revision": 3,
		"target_ids": ["factory.alpha"],
		"target_kind": "factory",
		"schema_version": 1,
		"authored_parameters": {"effect_amount": 4},
		"target_invalidation_policy": "FIZZLE_NO_EFFECT",
	}
	_expect(PURE.stable_fingerprint(binding) == PURE.stable_fingerprint(reordered), "dictionary insertion order does not alter deterministic identity")
	var invalid_binding := binding.duplicate(true)
	invalid_binding["target_ids"] = ["factory.alpha", "factory.alpha"]
	_expect(not bool(TARGET.validate(invalid_binding).get("valid", true)), "duplicate target ids fail closed")
	var retired := _submission("submission.retired", "player.0", 0, "card.retired", "v07.retired", "normal_card", "normal_hand", 1, 0, TARGET.build("none", [], 0, "", "default", 1, {"timing_class": "counter"}))
	_expect(not bool(SUBMISSION.validate(retired).get("valid", true)), "retired counter timing cannot enter the V0.7 submission contract")
	var passive := _submission("submission.passive", "player.0", 0, "bound.passive", "v07.passive", "passive_source_ability", "bound_action_inventory", 1, 0, TARGET.build("none", [], 0))
	_expect(not bool(SUBMISSION.validate(passive).get("valid", true)), "passive source abilities are state, not submitted gameplay cards")
	var wrong_pool := SUBMISSION.build("submission.wrong-pool", "player.0", "commodity.0", "v07.commodity", "commodity_card", "normal_hand", 1, 0, 0, 0, TARGET.build("factory", ["factory.alpha"], 1))
	_expect(not bool(SUBMISSION.validate(wrong_pool).get("valid", true)), "commodity, ordinary, and bound action classes cannot cross their authoritative pools")


func _test_three_independent_pools() -> void:
	var inventory := INVENTORY.empty("player.0")
	for index in range(5):
		var add_normal := INVENTORY.add_normal_card(inventory, _normal("normal.%d" % index, "v07.normal.%d" % index, 1))
		_expect(bool(add_normal.get("committed", false)), "normal hand accepts card %d/5" % (index + 1))
		inventory = add_normal.get("state", {})
	var normal_overflow := INVENTORY.add_normal_card(inventory, _normal("normal.5", "v07.normal.5", 1))
	_expect(not bool(normal_overflow.get("committed", true)) and str(normal_overflow.get("reason_code", "")) == "normal_hand_full", "sixth normal card overflows only the normal hand")
	for index in range(5):
		var add_commodity := INVENTORY.add_commodity_card(inventory, _commodity("commodity.%d" % index, "v07.commodity.%d" % index, 1))
		_expect(bool(add_commodity.get("committed", false)), "full normal hand still accepts commodity card %d/5" % (index + 1))
		inventory = add_commodity.get("state", {})
	var commodity_overflow := INVENTORY.add_commodity_card(inventory, _commodity("commodity.5", "v07.commodity.5", 1))
	_expect(not bool(commodity_overflow.get("committed", true)) and str(commodity_overflow.get("reason_code", "")) == "commodity_inventory_full", "sixth commodity overflows only commodity inventory")
	for index in range(12):
		var source_kind := "monster" if index % 2 == 0 else "military"
		var bound := _bound("bound.%02d" % index, "v07.bound.%02d" % index, source_kind, "%s.%02d" % [source_kind, index], 1, "batch_action" if index % 3 else "passive_source_ability")
		var grant := INVENTORY.grant_bound_action(inventory, bound)
		_expect(bool(grant.get("committed", false)), "bound action %d has zero capacity cost" % (index + 1))
		inventory = grant.get("state", {})
	var capacity := INVENTORY.capacity_snapshot(inventory)
	_expect(int(capacity.get("normal_card_count", -1)) == 5 and int(capacity.get("commodity_card_count", -1)) == 5 and int(capacity.get("bound_action_count", -1)) == 12, "5 normal + 5 commodity + many bound actions is legal")
	_expect(int(capacity.get("bound_action_capacity_cost", -1)) == 0 and bool(INVENTORY.validate(inventory).get("valid", false)), "bound inventory never contributes to either five-card cap")
	var revoke := INVENTORY.revoke_source(inventory, "monster", "monster.00")
	_expect(bool(revoke.get("committed", false)) and int(INVENTORY.capacity_snapshot(revoke.get("state", {})).get("bound_action_count", -1)) == 11, "source departure revokes its bound action without touching either hand")


func _test_supported_roster_sizes() -> void:
	for actor_count in [3, 4, 6, 8]:
		var actors: Array[String] = []
		var inventories := {}
		for index in range(actor_count):
			var actor_id := "player.%d" % index
			actors.append(actor_id)
			inventories[actor_id] = INVENTORY.empty(actor_id)
		var runtime := _new_runtime()
		var begin := runtime.begin_initial_window(actors, inventories)
		runtime.lock_window()
		var run := runtime.run_uninterrupted({})
		var receipt: Dictionary = run.get("batch_complete_receipt", {})
		var next := runtime.consume_batch_complete_receipt(receipt)
		_expect(bool(begin.get("accepted", false)) and bool(run.get("accepted", false)) and bool(next.get("accepted", false)), "%d-player roster completes an empty deterministic batch and opens the next window" % actor_count)
		_free_runtime(runtime)


func _test_bound_action_availability_lifecycle() -> void:
	var bound := _bound("bound.cooldown", "v07.bound.cooldown", "monster", "monster.alpha", 4, "batch_action")
	bound["charges"] = 1
	bound["cooldown_remaining_phase_time_usec"] = 5_000_000
	var inventory := _inventory("player.0", [], [], [bound])
	var runtime := _new_runtime()
	runtime.begin_initial_window(["player.0"], {"player.0": inventory})
	var target := TARGET.build("region", ["region.alpha"], 2, "", "pressure", 1, {
		"effect_kind": "pressure",
		"effect_amount": 2,
		"cooldown_phase_time_usec": 7_000_000,
	})
	var submission := _submission("submission.bound", "player.0", 0, "bound.cooldown", "v07.bound.cooldown", "batch_action", "bound_action_inventory", 4, 0, target)
	_expect(bool(runtime.configure_authoritative_card_rules(_rules_for_submissions([submission])).get("accepted", false)), "trusted composition registers the bound action's authored rule")
	_expect(not bool(runtime.submit_or_replace_draft(submission).get("accepted", true)), "bound action on cooldown is unavailable to Core")
	runtime.advance_window_phase_time_usec(5_000_000)
	_expect(bool(runtime.submit_or_replace_draft(submission).get("accepted", false)), "window phase time deterministically clears bound-action cooldown")
	runtime.lock_window()
	var run := runtime.run_uninterrupted({"submission.bound": {"target_revisions": {"region.alpha": 2}, "inactive_target_ids": []}})
	var completion: Dictionary = run.get("batch_complete_receipt", {})
	_expect(bool(runtime.consume_batch_complete_receipt(completion).get("accepted", false)), "bound-action batch completes and opens the next window")
	_expect(not bool(runtime.submit_or_replace_draft(submission).get("accepted", true)), "zero-charge bound action remains unavailable after the next window opens")
	_free_runtime(runtime)


func _test_one_shot_window_and_deterministic_order() -> void:
	var actors: Array[String] = []
	var inventories := {}
	var submissions: Array = []
	var projections := {}
	for index in range(8):
		var actor := "player.%d" % index
		actors.append(actor)
		var card_id := "card.%d" % index
		inventories[actor] = _inventory(actor, [_normal(card_id, "v07.card.%d" % index, 1)], [], [])
		var submission := _submission(
			"submission.%d" % index, actor, index, card_id, "v07.card.%d" % index,
			"normal_card", "normal_hand", 1, (7 - index) % 3,
			TARGET.build("region", ["region.%d" % index], 1, "", "default", 1, {"effect_kind": "pressure", "effect_amount": index + 1, "run_seed_reference": 7_007_001}),
			index
		)
		submissions.append(submission)
		projections[str(submission.get("submission_id", ""))] = {"target_revisions": {"region.%d" % index: 1}, "inactive_target_ids": []}
	var runtime_a := _new_runtime()
	var runtime_b := _new_runtime()
	_expect(bool(runtime_a.begin_initial_window(actors, inventories, 10_000_000).get("accepted", false)), "eight-seat initial one-shot window opens")
	_expect(bool(runtime_b.begin_initial_window(actors, inventories, 10_000_000).get("accepted", false)), "determinism twin opens from the same initial state")
	_expect(bool(runtime_a.configure_authoritative_card_rules(_rules_for_submissions(submissions)).get("accepted", false)), "trusted authored catalog binds effect and order semantics")
	_expect(bool(runtime_b.configure_authoritative_card_rules(_rules_for_submissions(submissions)).get("accepted", false)), "determinism twin binds the same authored catalog")
	var forged_priority := (submissions[0] as Dictionary).duplicate(true)
	forged_priority["order_priority"] = -999
	_expect(not bool(runtime_a.submit_or_replace_draft(forged_priority).get("accepted", true)), "actor cannot choose a priority that differs from the authored card rule")
	var forged_effect := (submissions[0] as Dictionary).duplicate(true)
	((forged_effect.get("target_binding", {}) as Dictionary).get("authored_parameters", {}) as Dictionary)["effect_amount"] = 999_999
	_expect(not bool(runtime_a.submit_or_replace_draft(forged_effect).get("accepted", true)), "actor cannot increase effect strength beyond the authored card rule")
	_expect(int(runtime_a.state_snapshot().get("window_remaining_phase_time_usec", -1)) == 30_000_000, "card submission window is exactly 30 seconds")
	var time_before := int(runtime_a.state_snapshot().get("world_effective_time_usec", -1))
	var advance := runtime_a.advance_window_phase_time_usec(4_000_000)
	var time_after := int(runtime_a.state_snapshot().get("world_effective_time_usec", -1))
	_expect(bool(advance.get("accepted", false)) and time_after - time_before == 4_000_000, "world-effective time runs during the open card window")
	runtime_b.advance_window_phase_time_usec(4_000_000)
	for submission in submissions:
		_expect(bool(runtime_a.submit_or_replace_draft(submission).get("accepted", false)), "submission enters the open window")
		_expect(bool(runtime_b.submit_or_replace_draft(submission).get("accepted", false)), "same command stream enters the determinism twin")
	var replacement := submissions[0].duplicate(true) as Dictionary
	(replacement.get("target_binding", {}) as Dictionary)["mode_id"] = "alternate"
	_expect(bool(runtime_a.submit_or_replace_draft(replacement).get("accepted", false)), "draft target mode may be revised before one-shot lock")
	_expect(bool(runtime_b.submit_or_replace_draft(replacement).get("accepted", false)), "the same pre-lock revision remains deterministic")
	var lock_a := runtime_a.lock_window()
	var lock_b := runtime_b.lock_window()
	var order_a: Array = lock_a.get("resolution_order", [])
	var order_b: Array = lock_b.get("resolution_order", [])
	_expect(bool(lock_a.get("accepted", false)) and order_a.size() == 8 and order_a == order_b, "window lock builds one deterministic eight-card order")
	_expect(_unique_count(order_a) == 8, "resolution order contains every submission exactly once")
	var locked_state := runtime_a.state_snapshot()
	var locked_submission: Dictionary = (locked_state.get("locked_submissions_by_id", {}) as Dictionary).get("submission.0", {})
	_expect(str((locked_submission.get("target_binding", {}) as Dictionary).get("mode_id", "")) == "alternate", "the last legal pre-lock target mode is frozen")
	var illegal_mid_resolution := runtime_a.submit_or_replace_draft(submissions[0])
	_expect(not bool(illegal_mid_resolution.get("accepted", true)) and str(illegal_mid_resolution.get("reason_code", "")) == "resolution_accepts_no_gameplay_input", "resolution rejects new gameplay submissions")
	var world_at_lock := int(runtime_a.state_snapshot().get("world_effective_time_usec", -1))
	var run_a := runtime_a.run_uninterrupted(projections)
	var run_b := runtime_b.run_uninterrupted(projections)
	_expect(bool(run_a.get("accepted", false)) and (run_a.get("new_card_receipts", []) as Array).size() == 8, "eight locked cards resolve strictly and continuously")
	_expect(int(run_a.get("mid_resolution_gameplay_wait_count", -1)) == 0 and int(run_a.get("counter_window_wait_seconds", -1)) == 0 and int(run_a.get("counter_stack_depth", -1)) == 0, "uninterrupted batch has no gameplay wait, counter window, or counter stack")
	_expect(int(runtime_a.state_snapshot().get("world_effective_time_usec", -1)) == world_at_lock, "world-effective time does not tick between resolving cards")
	_expect(PURE.stable_fingerprint(run_a.get("new_card_receipts", [])) == PURE.stable_fingerprint(run_b.get("new_card_receipts", [])), "same fixed-seed reference and command stream produce the same per-card receipt trace")
	_expect(PURE.stable_fingerprint(runtime_a.state_snapshot().get("mutation_trace", [])) == PURE.stable_fingerprint(runtime_b.state_snapshot().get("mutation_trace", [])), "same state and command stream produce the same mutation trace")
	_expect(runtime_a.state_fingerprint() == runtime_b.state_fingerprint() and runtime_a.state_fingerprint().length() == 64, "same state and command stream produce the same final state fingerprint")
	var complete_receipt: Dictionary = run_a.get("batch_complete_receipt", {})
	_expect(str(complete_receipt.get("receipt_kind", "")) == "CARD_BATCH_COMPLETE_RECEIPT", "authoritative batch completion emits the only next-window receipt")
	var next_window := runtime_a.consume_batch_complete_receipt(complete_receipt)
	_expect(bool(next_window.get("accepted", false)) and str(runtime_a.state_snapshot().get("phase", "")) == STATE.PHASE_CARD_WINDOW_OPEN, "consuming the batch-complete receipt opens the next 30-second window")
	_expect(bool(runtime_a.time_policy().get("world_effective_time_running", false)), "world-effective time resumes only in the next open window")
	_expect(not bool(runtime_a.consume_batch_complete_receipt(complete_receipt).get("accepted", true)), "a batch-complete receipt cannot open a second window twice")
	_free_runtime(runtime_a)
	_free_runtime(runtime_b)


func _test_target_invalidation_policies() -> void:
	var fizzle := _single_card_run("FIZZLE_NO_EFFECT", ["city.original"], {"target_revisions": {"city.original": 4}, "inactive_target_ids": ["city.original"]}, {})
	_expect(str(fizzle.get("outcome", "")) == "FIZZLE_NO_EFFECT" and (fizzle.get("resolved_target_ids", []) as Array).is_empty(), "invalid target defaults to FIZZLE_NO_EFFECT without target reselection")
	var remainder := _single_card_run("COMMIT_LEGAL_REMAINDER", ["city.valid", "city.invalid"], {"target_revisions": {"city.valid": 4, "city.invalid": 4}, "inactive_target_ids": ["city.invalid"]}, {})
	_expect(str(remainder.get("outcome", "")) == "COMMIT_LEGAL_REMAINDER" and remainder.get("resolved_target_ids", []) == ["city.valid"], "authored legal-remainder policy removes only invalid targets deterministically")
	var fallback := _single_card_run("DETERMINISTIC_FALLBACK", ["city.original"], {"target_revisions": {"city.a": 4, "city.z": 4}, "inactive_target_ids": ["city.original"]}, {"deterministic_fallback_target_ids": ["city.z", "city.a"]})
	_expect(str(fallback.get("outcome", "")) == "COMMITTED" and fallback.get("resolved_target_ids", []) == ["city.a"], "authored deterministic fallback uses stable id order and no input")
	var refund_result := _single_card_run_with_runtime("REFUND_BY_AUTHORED_RULE", ["city.original"], {"target_revisions": {}, "inactive_target_ids": ["city.original"]}, {})
	var refund_receipt: Dictionary = refund_result.get("receipt", {})
	var refund_runtime: CardBatchReferenceRuntime = refund_result.get("runtime")
	var refund_inventory: Dictionary = (refund_runtime.state_snapshot().get("inventories_by_actor", {}) as Dictionary).get("player.0", {})
	_expect(str(refund_receipt.get("outcome", "")) == "REFUND_BY_AUTHORED_RULE" and (refund_inventory.get("normal_cards", []) as Array).size() == 1, "authored refund preserves the source card without target reselection")
	_free_runtime(refund_runtime)


func _test_automatic_defense_and_time_pause() -> void:
	var actors := ["player.0", "player.1", "player.2"]
	var inventories := {
		"player.0": _inventory("player.0", [_normal("defense.a", "v07.defense.a", 1)], [], []),
		"player.1": _inventory("player.1", [_normal("defense.b", "v07.defense.b", 1)], [], []),
		"player.2": _inventory("player.2", [_normal("attack", "v07.attack", 1)], [], []),
	}
	var runtime := _new_runtime()
	runtime.begin_initial_window(actors, inventories, 2_000_000)
	var submissions := [
		_submission("submission.defense.a", "player.0", 0, "defense.a", "v07.defense.a", "proactive_defense", "normal_hand", 1, 0, TARGET.build("city", ["city.alpha"], 9, "", "protect", 1, {"defense_kind": "shield", "effect_filter": "damage", "reduction_amount": 2, "prevention_count": 0, "remaining_uses": 1, "visibility_policy": "public", "trigger_refund_amount": 40, "private_trace_count": 1})),
		_submission("submission.defense.b", "player.1", 1, "defense.b", "v07.defense.b", "proactive_defense", "normal_hand", 1, 1, TARGET.build("city", ["city.alpha"], 9, "", "protect", 1, {"defense_kind": "insurance", "effect_filter": "damage", "reduction_amount": 3, "prevention_count": 0, "remaining_uses": 1, "visibility_policy": "public"})),
		_submission("submission.attack", "player.2", 2, "attack", "v07.attack", "batch_interference", "normal_hand", 1, 2, TARGET.build("city", ["city.alpha"], 9, "", "damage", 1, {"effect_kind": "damage", "effect_amount": 10})),
	]
	_expect(bool(runtime.configure_authoritative_card_rules(_rules_for_submissions(submissions)).get("accepted", false)), "defense and attack semantics come from the trusted authored catalog")
	for submission in submissions:
		runtime.submit_or_replace_draft(submission)
	var lock := runtime.lock_window()
	var order_before: Array = lock.get("resolution_order", []).duplicate()
	var world_before := int(runtime.state_snapshot().get("world_effective_time_usec", -1))
	var projections := {
		"submission.defense.a": {"target_revisions": {"city.alpha": 9}, "inactive_target_ids": []},
		"submission.defense.b": {"target_revisions": {"city.alpha": 9}, "inactive_target_ids": []},
		"submission.attack": {"target_revisions": {"city.alpha": 9}, "inactive_target_ids": []},
	}
	var run := runtime.run_uninterrupted(projections)
	var receipts: Array = run.get("new_card_receipts", [])
	var attack_receipt: Dictionary = receipts[2] if receipts.size() == 3 else {}
	var applications: Array = attack_receipt.get("defense_applications", [])
	_expect(receipts.size() == 3 and str((receipts[0] as Dictionary).get("outcome", "")) == "COMMITTED" and str((receipts[1] as Dictionary).get("outcome", "")) == "COMMITTED", "proactive defense cards resolve as ordinary earlier cards")
	_expect(applications.size() == 2 and int(attack_receipt.get("effect_amount", -1)) == 5, "existing defenses automatically reduce the later attack in stable order")
	_expect(str((applications[0] as Dictionary).get("defense_status_id", "")) == "defense:card-batch:000001:submission.defense.a" and str((applications[1] as Dictionary).get("defense_status_id", "")) == "defense:card-batch:000001:submission.defense.b", "multiple defenses apply in deterministic authority order")
	_expect(runtime.state_snapshot().get("resolution_order", []) == order_before and order_before.size() == 3, "defense application inserts no queue entry and never changes resolution order")
	_expect(int(runtime.state_snapshot().get("world_effective_time_usec", -1)) == world_before, "defense application and card commits consume no world-effective time")
	var public_authorization := VIEWER_AUTHORIZATION.new(3) as CardBatchViewerAuthorizationV1
	_expect(runtime.bind_viewer_authorization("player.2", public_authorization), "viewer authorization binds to one exact roster actor")
	var public_projection := runtime.viewer_projection(public_authorization)
	var visible_statuses: Array = public_projection.get("visible_defense_statuses", [])
	var public_projection_text := JSON.stringify(public_projection)
	_expect(visible_statuses.size() == 2 and not public_projection_text.contains("owner_player_id") and not public_projection_text.contains("source_card_instance_id") and not public_projection_text.contains("defense_status_id"), "public DefenseStatus projection redacts owner, source instance, and stable internal status IDs")
	_expect(not public_projection_text.contains("receipt_id") and not public_projection_text.contains("submission_id"), "public resolution projection exposes no correlatable internal receipt or submission IDs")
	var defender_authorization := VIEWER_AUTHORIZATION.new(5) as CardBatchViewerAuthorizationV1
	_expect(runtime.bind_viewer_authorization("player.0", defender_authorization), "defender receives a separate owner-bound authorization")
	var defender_projection := runtime.viewer_projection(defender_authorization)
	var trigger_receipts: Array = defender_projection.get("own_defense_trigger_receipts", [])
	_expect(trigger_receipts.size() == 1 and int((trigger_receipts[0] as Dictionary).get("refund_amount", -1)) == 40 and int((trigger_receipts[0] as Dictionary).get("private_trace_count", -1)) == 1, "triggered proactive defense emits its authored refund and trace only to the defender")
	var phase_trace_text := JSON.stringify(runtime.state_snapshot().get("phase_trace", [])).to_lower()
	_expect(not phase_trace_text.contains("counter") and not phase_trace_text.contains("forced_card_response"), "phase trace contains no counter window, stack, or forced response")
	_free_runtime(runtime)


func _test_empty_batch_completion_gate() -> void:
	var runtime := _new_runtime()
	runtime.begin_initial_window(["player.0"], {"player.0": INVENTORY.empty("player.0")})
	var lock := runtime.advance_window_phase_time_usec(30_000_000)
	_expect(bool(lock.get("accepted", false)) and str(runtime.state_snapshot().get("phase", "")) == STATE.PHASE_BATCH_AFTERMATH, "an empty one-shot window becomes an empty batch instead of waiting")
	var run := runtime.run_uninterrupted({})
	var receipt: Dictionary = run.get("batch_complete_receipt", {})
	_expect(bool(run.get("accepted", false)) and bool(receipt.get("empty_batch", false)), "empty batch emits a batch-complete receipt")
	_expect(str(runtime.state_snapshot().get("phase", "")) == STATE.PHASE_BATCH_COMPLETE and not bool(runtime.time_policy().get("world_effective_time_running", true)), "world remains paused until authoritative completion receipt consumption")
	_expect(bool(runtime.consume_batch_complete_receipt(receipt).get("accepted", false)), "only the empty batch completion receipt opens its next window")
	_free_runtime(runtime)


func _single_card_run(policy: String, targets: Array, projection: Dictionary, extra_parameters: Dictionary) -> Dictionary:
	var result := _single_card_run_with_runtime(policy, targets, projection, extra_parameters)
	var runtime: CardBatchReferenceRuntime = result.get("runtime")
	var receipt: Dictionary = result.get("receipt", {})
	_free_runtime(runtime)
	return receipt


func _single_card_run_with_runtime(policy: String, targets: Array, projection: Dictionary, extra_parameters: Dictionary) -> Dictionary:
	var runtime := _new_runtime()
	var inventory := _inventory("player.0", [_normal("card.single", "v07.single", 1)], [], [])
	runtime.begin_initial_window(["player.0"], {"player.0": inventory})
	var authored := {"effect_kind": "damage", "effect_amount": 4}
	for key in extra_parameters.keys():
		authored[key] = extra_parameters.get(key)
	var submission := _submission("submission.single", "player.0", 0, "card.single", "v07.single", "normal_card", "normal_hand", 1, 0, TARGET.build("city", targets, 4, "", "default", 1, authored), 0, policy)
	runtime.configure_authoritative_card_rules(_rules_for_submissions([submission]))
	runtime.submit_or_replace_draft(submission)
	runtime.lock_window()
	var run := runtime.run_uninterrupted({"submission.single": projection})
	var receipts: Array = run.get("new_card_receipts", [])
	return {"runtime": runtime, "receipt": (receipts[0] as Dictionary).duplicate(true) if not receipts.is_empty() else {}}


func _new_runtime() -> CardBatchReferenceRuntime:
	var runtime := RUNTIME.new() as CardBatchReferenceRuntime
	root.add_child(runtime)
	return runtime


func _free_runtime(runtime: CardBatchReferenceRuntime) -> void:
	if runtime == null:
		return
	root.remove_child(runtime)
	runtime.free()


func _inventory(actor_id: String, normals: Array, commodities: Array, bounds: Array) -> Dictionary:
	var result := INVENTORY.empty(actor_id)
	for card in normals:
		result = INVENTORY.add_normal_card(result, card).get("state", {})
	for card in commodities:
		result = INVENTORY.add_commodity_card(result, card).get("state", {})
	for action in bounds:
		result = INVENTORY.grant_bound_action(result, action).get("state", {})
	return result


func _normal(instance_id: String, semantic_id: String, revision: int) -> Dictionary:
	return {"card_instance_id": instance_id, "card_semantic_id": semantic_id, "source_revision": revision}


func _commodity(instance_id: String, semantic_id: String, revision: int) -> Dictionary:
	return {"card_instance_id": instance_id, "card_semantic_id": semantic_id, "source_revision": revision, "commodity_id": "energy", "commodity_level": 1}


func _bound(instance_id: String, semantic_id: String, source_kind: String, source_id: String, revision: int, action_kind: String) -> Dictionary:
	return {
		"bound_action_id": instance_id, "card_semantic_id": semantic_id, "action_kind": action_kind,
		"source_kind": source_kind, "source_id": source_id, "source_revision": revision,
		"cooldown_remaining_phase_time_usec": 0, "charges": 3,
	}


func _submission(id: String, actor: String, seat: int, card: String, semantic: String, action_class: String, pool: String, revision: int, priority: int, target: Dictionary, sequence: int = 0, policy: String = "FIZZLE_NO_EFFECT") -> Dictionary:
	var target_with_policy := target.duplicate(true)
	target_with_policy["target_invalidation_policy"] = policy
	return SUBMISSION.build(id, actor, card, semantic, action_class, pool, revision, seat, priority, sequence, target_with_policy)


func _rules_for_submissions(submissions: Array) -> Dictionary:
	var rules: Dictionary = {}
	for submission_variant in submissions:
		if not (submission_variant is Dictionary):
			continue
		var submission := submission_variant as Dictionary
		var semantic_id := str(submission.get("card_semantic_id", ""))
		rules[semantic_id] = AUTHORED_RULE.from_submission(submission)
	return rules


func _unique_count(values: Array) -> int:
	var unique: Array = []
	for value in values:
		if value not in unique:
			unique.append(value)
	return unique.size()


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		print("PASS: %s" % message)
		return
	_failures.append(message)
	push_error("FAIL: %s" % message)


func _finish() -> void:
	if _failures.is_empty():
		print("CARD_BATCH_CORE_SEMANTICS_TEST|status=PASS|checks=%d|failures=0" % _checks)
		quit(0)
		return
	push_error("CARD_BATCH_CORE_SEMANTICS_TEST|status=FAIL|checks=%d|failures=%d\n- %s" % [_checks, _failures.size(), "\n- ".join(_failures)])
	quit(1)
