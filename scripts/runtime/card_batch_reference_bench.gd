extends Node
class_name CardBatchReferenceBench

const TARGET = preload("res://scripts/semantic/card_batch_prebound_target_spec_v1.gd")
const SUBMISSION = preload("res://scripts/semantic/card_batch_submission_v1.gd")
const INVENTORY = preload("res://scripts/semantic/card_batch_inventory_state_v1.gd")
const AUTHORED_RULE = preload("res://scripts/semantic/card_batch_authored_rule_v1.gd")

@export var run_on_ready := true

@onready var runtime: CardBatchReferenceRuntime = $CardBatchRuntime

var last_result: Dictionary = {}


func _ready() -> void:
	if run_on_ready:
		last_result = run_reference_scenario()
		print("CARD_BATCH_REFERENCE_BENCH|status=%s|cards=%d|waits=%d|next_window=%s" % [
			"PASS" if bool(last_result.get("passed", false)) else "FAIL",
			int(last_result.get("card_receipt_count", 0)),
			int(last_result.get("mid_resolution_gameplay_wait_count", -1)),
			str(last_result.get("next_window_id", "")),
		])


func run_reference_scenario() -> Dictionary:
	var actors := ["player.0", "player.1", "player.2", "player.3"]
	var inventories := {
		"player.0": _inventory("player.0", [_normal("card.shield", "v07.proactive.shield", 1)], [], []),
		"player.1": _inventory("player.1", [_normal("card.attack", "v07.batch.attack", 1)], [], []),
		"player.2": _inventory("player.2", [], [_commodity("commodity.energy", "v07.commodity.energy", 1)], []),
		"player.3": _inventory("player.3", [], [], [_bound("bound.military", "v07.bound.military", 1)]),
	}
	var begin := runtime.begin_initial_window(actors, inventories, 12_000_000)
	if not bool(begin.get("accepted", false)):
		return {"passed": false, "reason_code": str(begin.get("reason_code", "begin_failed"))}
	var submissions := [
		_submission("submission.shield", "player.0", 0, "card.shield", "v07.proactive.shield", "proactive_defense", "normal_hand", 1, 0, _target("city", ["city.alpha"], 7, {
			"defense_kind": "shield", "effect_filter": "damage", "reduction_amount": 4,
			"prevention_count": 0, "remaining_uses": 1, "visibility_policy": "public",
		})),
		_submission("submission.attack", "player.1", 1, "card.attack", "v07.batch.attack", "batch_interference", "normal_hand", 1, 10, _target("city", ["city.alpha"], 7, {"effect_kind": "damage", "effect_amount": 9})),
		_submission("submission.commodity", "player.2", 2, "commodity.energy", "v07.commodity.energy", "commodity_card", "commodity_inventory", 1, 20, _target("factory", ["factory.alpha"], 7, {"effect_kind": "supply", "effect_amount": 3})),
		_submission("submission.bound", "player.3", 3, "bound.military", "v07.bound.military", "batch_action", "bound_action_inventory", 1, 30, _target("region", ["region.alpha"], 7, {"effect_kind": "military", "effect_amount": 2, "cooldown_phase_time_usec": 5_000_000})),
	]
	var rules: Dictionary = {}
	for submission_variant in submissions:
		var authored_submission := submission_variant as Dictionary
		rules[str(authored_submission.get("card_semantic_id", ""))] = AUTHORED_RULE.from_submission(authored_submission)
	var configured := runtime.configure_authoritative_card_rules(rules)
	if not bool(configured.get("accepted", false)):
		return {"passed": false, "reason_code": str(configured.get("reason_code", "authored_rules_failed"))}
	for submission in submissions:
		var submit := runtime.submit_or_replace_draft(submission)
		if not bool(submit.get("accepted", false)):
			return {"passed": false, "reason_code": str(submit.get("reason_code", "submit_failed"))}
	var lock := runtime.lock_window()
	if not bool(lock.get("accepted", false)):
		return {"passed": false, "reason_code": str(lock.get("reason_code", "lock_failed"))}
	var rejected_during_resolution := runtime.submit_or_replace_draft(submissions[1])
	var projection_by_submission := {}
	for submission in submissions:
		projection_by_submission[str(submission.get("submission_id", ""))] = {
			"target_revisions": {
				"city.alpha": 7,
				"factory.alpha": 7,
				"region.alpha": 7,
			},
			"inactive_target_ids": [],
		}
	var run := runtime.run_uninterrupted(projection_by_submission)
	if not bool(run.get("accepted", false)):
		return {"passed": false, "reason_code": str(run.get("reason_code", "run_failed"))}
	var receipt: Dictionary = run.get("batch_complete_receipt", {})
	var open_next := runtime.consume_batch_complete_receipt(receipt)
	var snapshot := runtime.state_snapshot()
	var receipts: Array = run.get("new_card_receipts", [])
	var attack_receipt: Dictionary = receipts[1] if receipts.size() > 1 and receipts[1] is Dictionary else {}
	return {
		"passed": not bool(rejected_during_resolution.get("accepted", true)) \
			and bool(open_next.get("accepted", false)) \
			and receipts.size() == 4 \
			and int(attack_receipt.get("effect_amount", -1)) == 5 \
			and (attack_receipt.get("defense_applications", []) as Array).size() == 1,
		"reason_code": "card_batch_reference_scenario_complete",
		"card_receipt_count": receipts.size(),
		"mid_resolution_gameplay_wait_count": int(run.get("mid_resolution_gameplay_wait_count", -1)),
		"counter_window_wait_seconds": int(run.get("counter_window_wait_seconds", -1)),
		"counter_stack_depth": int(run.get("counter_stack_depth", -1)),
		"next_window_id": str(snapshot.get("window_id", "")),
		"world_effective_time_running": bool(runtime.time_policy().get("world_effective_time_running", false)),
		"state_fingerprint": runtime.state_fingerprint(),
	}


func _inventory(actor_id: String, normals: Array, commodities: Array, bounds: Array) -> Dictionary:
	var result := INVENTORY.empty(actor_id)
	for card in normals:
		result = (INVENTORY.add_normal_card(result, card).get("state", {}) as Dictionary).duplicate(true)
	for card in commodities:
		result = (INVENTORY.add_commodity_card(result, card).get("state", {}) as Dictionary).duplicate(true)
	for action in bounds:
		result = (INVENTORY.grant_bound_action(result, action).get("state", {}) as Dictionary).duplicate(true)
	return result


func _normal(instance_id: String, semantic_id: String, revision: int) -> Dictionary:
	return {"card_instance_id": instance_id, "card_semantic_id": semantic_id, "source_revision": revision}


func _commodity(instance_id: String, semantic_id: String, revision: int) -> Dictionary:
	return {"card_instance_id": instance_id, "card_semantic_id": semantic_id, "source_revision": revision, "commodity_id": "energy", "commodity_level": 1}


func _bound(instance_id: String, semantic_id: String, revision: int) -> Dictionary:
	return {
		"bound_action_id": instance_id, "card_semantic_id": semantic_id, "action_kind": "batch_action",
		"source_kind": "military", "source_id": "military.alpha", "source_revision": revision,
		"cooldown_remaining_phase_time_usec": 0, "charges": 3,
	}


func _target(kind: String, ids: Array, revision: int, parameters: Dictionary) -> Dictionary:
	return TARGET.build(kind, ids, revision, "", "default", 1, parameters)


func _submission(id: String, actor: String, seat: int, card: String, semantic: String, action_class: String, pool: String, revision: int, priority: int, target: Dictionary) -> Dictionary:
	return SUBMISSION.build(id, actor, card, semantic, action_class, pool, revision, seat, priority, 0, target)
