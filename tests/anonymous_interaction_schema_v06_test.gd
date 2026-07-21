extends SceneTree

const SCHEMA := preload("res://scripts/cards/v06/interaction/anonymous_interaction_runtime_schema_v06.gd")

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var direct := _intent("tx-direct", "player_hand_steal", "opponent_discardable_hand", {"direct_player_interaction": true, "counterable": true}, ["B"])
	var validation := SCHEMA.validate_intent(direct)
	_expect(bool(validation.get("valid", false)) and str(validation.get("route_domain", "")) == "direct_player", "direct-player fields route without card-name matching")
	var self_target := direct.duplicate(true)
	self_target["target_player_ids"] = ["A"]
	_expect(str(SCHEMA.validate_intent(self_target).get("reason_code", "")) == "interaction_self_target_forbidden", "self target is rejected")
	var stale := direct.duplicate(true)
	stale["target_revision"] = -1
	_expect(str(SCHEMA.validate_intent(stale).get("reason_code", "")) == "interaction_target_revision_invalid", "negative or missing revision is rejected")
	var counter := _intent("tx-counter", "card_counter", "incoming_direct_player_interaction", {"target_scope": "direct_player_interaction", "response_depth": 1}, ["A"])
	_expect(str(SCHEMA.validate_intent(counter).get("route_domain", "")) == "counter_response", "counter response fields route")
	var economic_counter := counter.duplicate(true)
	economic_counter["target_kind"] = "incoming_economic_effect"
	_expect(not bool(SCHEMA.validate_intent(economic_counter).get("valid", true)), "counter rejects economic effects")
	var deep_counter := counter.duplicate(true)
	(deep_counter["effect_payload"] as Dictionary)["response_depth"] = 2
	_expect(str(SCHEMA.validate_intent(deep_counter).get("reason_code", "")) == "counter_scope_invalid", "counter depth is exactly one")
	var retired_contract := _intent("tx-contract", "contract_offer_v06", "target_player", {"interaction_domain": "contract"}, ["B"])
	_expect(str(SCHEMA.validate_intent(retired_contract).get("reason_code", "")) == "interaction_effect_fields_unsupported", "retired contract offer has no anonymous interaction route")
	_expect(SCHEMA.route_domain(retired_contract).is_empty(), "generic contract interaction domain is physically unsupported")
	var intel := _intent("tx-intel", "intel_card_trace", "private_evidence", {"interaction_domain": "intel"}, [])
	_expect(str(SCHEMA.validate_intent(intel).get("route_domain", "")) == "intel", "intel routes from effect fields")
	var prepared := SCHEMA.stage_receipt(direct, "prepared", true, "prepared")
	_expect(bool(SCHEMA.validate_prepared_receipt(prepared).get("valid", false)), "prepared receipt schema validates")
	var commit := SCHEMA.stage_receipt(direct, "committed", true, "committed")
	_expect(bool(SCHEMA.validate_commit_receipt(commit).get("valid", false)), "commit receipt schema validates")
	var rollback := SCHEMA.stage_receipt(direct, "rolled_back", true, "rolled_back")
	_expect(bool(SCHEMA.validate_rollback_receipt(rollback).get("valid", false)), "rollback receipt schema validates")
	var finalize := SCHEMA.stage_receipt(direct, "finalized", true, "finalized")
	_expect(bool(SCHEMA.validate_finalize_receipt(finalize).get("valid", false)), "finalize receipt schema validates")
	var wrong := commit.duplicate(true)
	wrong["effect_kind"] = "player_hand_disrupt"
	_expect(not SCHEMA.binding_matches(direct, wrong), "receipt cannot self-report another effect kind")
	_finish()


func _intent(transaction_id: String, effect_kind: String, target_kind: String, payload: Dictionary, targets: Array) -> Dictionary:
	return {
		"schema_version": "0.6", "transaction_id": transaction_id, "actor_id": "A",
		"card_id": "fixture.card", "card_instance_id": "instance-%s" % transaction_id,
		"effect_kind": effect_kind, "target_kind": target_kind, "target_player_ids": targets,
		"target_revision": 3, "effect_payload": payload, "target_hash": "target-hash",
		"payload_hash": "payload-hash", "intent_hash": "intent-%s" % transaction_id,
	}


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
		print("FAIL: %s" % message)


func _finish() -> void:
	print("ANONYMOUS_INTERACTION_SCHEMA_V06_TEST|status=%s|checks=%d|failures=%d" % ["PASS" if _failures.is_empty() else "FAIL", _checks, _failures.size()])
	quit(0 if _failures.is_empty() else 1)
