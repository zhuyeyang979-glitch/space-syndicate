extends SceneTree

const PORT := preload("res://scripts/cards/v06/interaction/anonymous_interaction_owner_forwarding_port_v06.gd")
const SCHEMA := preload("res://scripts/cards/v06/interaction/anonymous_interaction_runtime_schema_v06.gd")

var _checks := 0
var _failures: Array[String] = []


class IncompleteOwner:
	extends RefCounted
	var calls := 0
	func anonymous_interaction_runtime_capabilities_v06(_domain: String) -> Dictionary:
		return {"prepare": true, "commit": true, "supported_effect_kinds": ["player_hand_steal"]}
	func prepare_anonymous_interaction_v06(intent: Dictionary) -> Dictionary:
		calls += 1
		return SCHEMA.stage_receipt(intent, "prepared", true, "prepared")


class ReferenceOwner:
	extends RefCounted
	var calls := {"prepare": 0, "commit": 0, "rollback": 0, "finalize": 0}
	func anonymous_interaction_runtime_capabilities_v06(_domain: String) -> Dictionary:
		return {"snapshot": true, "prepare": true, "commit": true, "rollback": true, "finalize": true, "checkpoint": true, "revision": true, "exact_once": true, "save_load": true, "privacy_safe_snapshot": true, "atomic_mutation_ready": true, "supported_effect_kinds": ["player_hand_steal"]}
	func anonymous_interaction_snapshot_v06(domain: String) -> Dictionary:
		return {"available": true, "domain": domain, "revision": 4}
	func prepare_anonymous_interaction_v06(intent: Dictionary) -> Dictionary:
		calls["prepare"] += 1
		return SCHEMA.stage_receipt(intent, "prepared", true, "prepared")
	func commit_anonymous_interaction_v06(prepared: Dictionary) -> Dictionary:
		calls["commit"] += 1
		return SCHEMA.stage_receipt(prepared, "committed", true, "committed")
	func rollback_anonymous_interaction_v06(receipt: Dictionary) -> Dictionary:
		calls["rollback"] += 1
		return SCHEMA.stage_receipt(receipt, "rolled_back", true, "rolled_back")
	func finalize_anonymous_interaction_v06(receipt: Dictionary) -> Dictionary:
		calls["finalize"] += 1
		return SCHEMA.stage_receipt(receipt, "finalized", true, "finalized")
	func anonymous_interaction_checkpoint_status_v06(domain: String) -> Dictionary:
		return {"can_checkpoint": true, "domain": domain}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var incomplete := IncompleteOwner.new()
	var port = PORT.new()
	port.configure(incomplete, "direct_player")
	var matrix: Dictionary = port.capability_matrix()
	var rejected: Dictionary = port.prepare_intent(_intent())
	_expect(not bool(matrix.get("production_ready", true)) and str(rejected.get("reason_code", "")) == "interaction_owner_atomic_contract_missing", "missing atomic capabilities fail closed before prepare")
	_expect(incomplete.calls == 0, "fail-closed owner receives no mutation call")

	var reference := ReferenceOwner.new()
	port = PORT.new()
	port.configure(reference, "direct_player")
	matrix = port.capability_matrix()
	_expect(bool(matrix.get("production_ready", false)) and bool(matrix.get("exact_once", false)) and bool(matrix.get("save_load", false)), "reference owner exposes full capability matrix")
	var prepared: Dictionary = port.prepare_intent(_intent())
	var committed: Dictionary = port.commit_intent(prepared)
	var rolled: Dictionary = port.rollback_intent(committed)
	_expect(bool(prepared.get("prepared", false)) and bool(committed.get("committed", false)) and bool(rolled.get("rolled_back", false)), "full owner forwards prepare commit rollback")
	prepared = port.prepare_intent(_intent("tx-finalize"))
	committed = port.commit_intent(prepared)
	var finalized: Dictionary = port.finalize_intent(committed)
	_expect(bool(finalized.get("finalized", false)), "full owner forwards finalize")
	_expect(bool(port.checkpoint_status().get("can_checkpoint", false)) and bool(port.safe_snapshot().get("available", false)), "checkpoint and privacy snapshot forward")
	_finish()


func _intent(transaction_id: String = "tx-owner") -> Dictionary:
	return {"schema_version": "0.6", "transaction_id": transaction_id, "actor_id": "A", "card_id": "fixture.card", "card_instance_id": "instance", "effect_kind": "player_hand_steal", "target_kind": "opponent_discardable_hand", "target_player_ids": ["B"], "target_revision": 1, "effect_payload": {"direct_player_interaction": true}, "target_hash": "target", "payload_hash": "payload", "intent_hash": "intent-%s" % transaction_id}


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
		print("FAIL: %s" % message)


func _finish() -> void:
	print("ANONYMOUS_INTERACTION_OWNER_CAPABILITY_V06_TEST|status=%s|checks=%d|failures=%d" % ["PASS" if _failures.is_empty() else "FAIL", _checks, _failures.size()])
	quit(0 if _failures.is_empty() else 1)
