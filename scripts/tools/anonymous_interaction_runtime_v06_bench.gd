extends Node

const SCHEMA := preload("res://scripts/cards/v06/interaction/anonymous_interaction_runtime_schema_v06.gd")
const ROUTER := preload("res://scripts/cards/v06/interaction/interaction_effect_router_v06.gd")
const PORT := preload("res://scripts/cards/v06/interaction/anonymous_interaction_owner_forwarding_port_v06.gd")
const WINDOW := preload("res://scripts/cards/v06/interaction/counter_response_window_v06.gd")
const FILTER := preload("res://scripts/cards/v06/interaction/anonymous_interaction_receipt_sanitizer_v06.gd")

var _checks := 0
var _failures: Array[String] = []


class ReferenceOwner:
	extends RefCounted
	var commits := 0
	var rollbacks := 0
	var finalizes := 0
	func prepare_intent(intent: Dictionary) -> Dictionary:
		return SCHEMA.stage_receipt(intent, "prepared", true, "reference_prepared")
	func commit_intent(prepared: Dictionary) -> Dictionary:
		commits += 1
		return SCHEMA.stage_receipt(prepared, "committed", true, "reference_committed", {"true_owner": "hidden-A", "opponent_hand": ["secret"]})
	func rollback_intent(receipt: Dictionary) -> Dictionary:
		rollbacks += 1
		return SCHEMA.stage_receipt(receipt, "rolled_back", true, "reference_rolled_back")
	func finalize_intent(receipt: Dictionary) -> Dictionary:
		finalizes += 1
		return SCHEMA.stage_receipt(receipt, "finalized", true, "reference_finalized")


class IncompleteProductionOwner:
	extends RefCounted
	var prepare_calls := 0
	func anonymous_interaction_runtime_capabilities_v06(_domain: String) -> Dictionary:
		return {"prepare": true, "commit": true, "revision": true, "supported_effect_kinds": ["player_hand_steal"]}
	func prepare_anonymous_interaction_v06(intent: Dictionary) -> Dictionary:
		prepare_calls += 1
		return SCHEMA.stage_receipt(intent, "prepared", true, "unsafe_prepare")


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var reference_owner := ReferenceOwner.new()
	var router = ROUTER.new()
	router.configure({"direct_player": reference_owner})
	var intent := _direct_intent()
	var prepared: Dictionary = router.prepare_effect(intent)
	var committed: Dictionary = router.commit_effect(prepared)
	var commit_replay: Dictionary = router.commit_effect(prepared)
	_check("field_router_exact_once", bool(committed.get("committed", false)) and bool(commit_replay.get("idempotent_replay", false)) and reference_owner.commits == 1, {"commit_calls": reference_owner.commits})
	var public := FILTER.sanitize_public(committed)
	var leaks := FILTER.scan_public_leaks(public)
	_check("public_privacy_zero_leaks", leaks.is_empty(), {"leak_count": leaks.size()})
	var finalized: Dictionary = router.finalize_effect(committed)
	var finalize_replay: Dictionary = router.finalize_effect(committed)
	_check("finalize_exact_once", bool(finalized.get("finalized", false)) and bool(finalize_replay.get("idempotent_replay", false)) and reference_owner.finalizes == 1, {"finalize_calls": reference_owner.finalizes})

	var rollback_owner := ReferenceOwner.new()
	router = ROUTER.new()
	router.configure({"direct_player": rollback_owner})
	prepared = router.prepare_effect(_direct_intent("bench-rollback"))
	committed = router.commit_effect(prepared)
	var rolled: Dictionary = router.rollback_effect(committed)
	var rollback_replay: Dictionary = router.rollback_effect(committed)
	_check("rollback_exact_once", bool(rolled.get("rolled_back", false)) and bool(rollback_replay.get("idempotent_replay", false)) and rollback_owner.rollbacks == 1, {"rollback_calls": rollback_owner.rollbacks})

	var unsafe_owner := IncompleteProductionOwner.new()
	var port = PORT.new()
	port.configure(unsafe_owner, "direct_player")
	var rejected: Dictionary = port.prepare_intent(_direct_intent("bench-fail-closed"))
	_check("production_owner_fail_closed", str(rejected.get("reason_code", "")) == "interaction_owner_atomic_contract_missing" and unsafe_owner.prepare_calls == 0, {"reason": rejected.get("reason_code", ""), "owner_calls": unsafe_owner.prepare_calls})

	var windows = WINDOW.new()
	var invalid: Dictionary = windows.open_window({"window_id": "economic", "transaction_id": "tx-economic", "incoming_effect_kind": "economic_price_shift", "incoming_route_domain": "economic", "incoming_direct_player_interaction": false, "legal_responder_ids": ["B"], "opened_at": 10.0, "deadline_seconds": 5.0})
	_check("counter_scope_gate", str(invalid.get("reason_code", "")) == "counter_window_incoming_scope_invalid" and int(windows.debug_snapshot().get("window_count", -1)) == 0, {"reason": invalid.get("reason_code", "")})
	var opened: Dictionary = windows.open_window({"window_id": "direct", "transaction_id": "tx-direct", "incoming_effect_kind": "player_hand_steal", "incoming_route_domain": "direct_player", "incoming_direct_player_interaction": true, "legal_responder_ids": ["B"], "opened_at": 10.0, "deadline_seconds": 5.0})
	var saved := windows.to_save_data()
	var restored = WINDOW.new()
	var loaded: Dictionary = restored.apply_save_data(saved)
	_check("inflight_window_save_load", str(opened.get("state", "")) == "open" and bool(loaded.get("loaded", false)) and str(restored.window_snapshot("direct").get("state", "")) == "open", {"checkpoint": restored.checkpoint_status()})
	var no_holder: Dictionary = windows.open_window({"window_id": "no-holder", "transaction_id": "tx-no-holder", "incoming_effect_kind": "player_hand_disrupt", "incoming_route_domain": "direct_player", "incoming_direct_player_interaction": true, "legal_responder_ids": [], "opened_at": 10.0, "deadline_seconds": 5.0})
	_check("no_holder_explained", str(no_holder.get("outcome", "")) == "no_eligible_responder", {"outcome": no_holder.get("outcome", "")})
	_finish()


func _direct_intent(transaction_id: String = "bench-direct") -> Dictionary:
	return {"schema_version": "0.6", "transaction_id": transaction_id, "actor_id": "A", "card_id": "fixture.interaction", "card_instance_id": "instance-%s" % transaction_id, "effect_kind": "player_hand_steal", "target_kind": "opponent_discardable_hand", "target_player_ids": ["B"], "target_revision": 7, "effect_payload": {"direct_player_interaction": true, "counterable": true}, "target_hash": "target", "payload_hash": "payload", "intent_hash": "intent-%s" % transaction_id}


func _check(event_name: String, valid: bool, fields: Dictionary) -> void:
	_checks += 1
	if not valid:
		_failures.append(event_name)
	_log(event_name, "PASS" if valid else "FAIL", fields)


func _finish() -> void:
	var passed := _failures.is_empty()
	set_meta("bench_exit_code", 0 if passed else 1)
	set_meta("bench_status", "PASS" if passed else "FAIL")
	_log("suite_complete", "PASS" if passed else "FAIL", {"checks": _checks, "failures": _failures.size(), "public_leaks": 0 if passed else -1})


func _log(event_name: String, status: String, fields: Dictionary) -> void:
	var parts: Array[String] = ["ANONYMOUS_INTERACTION_RUNTIME_V06_BENCH", "event=%s" % event_name, "status=%s" % status]
	var keys := fields.keys()
	keys.sort()
	for key_variant in keys:
		parts.append("%s=%s" % [str(key_variant), str(fields.get(key_variant)).replace("|", "/").replace("\n", " ")])
	print("|".join(parts))
