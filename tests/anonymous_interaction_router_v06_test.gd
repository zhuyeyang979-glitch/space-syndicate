extends SceneTree

const ROUTER := preload("res://scripts/cards/v06/interaction/interaction_effect_router_v06.gd")
const SCHEMA := preload("res://scripts/cards/v06/interaction/anonymous_interaction_runtime_schema_v06.gd")

var _checks := 0
var _failures: Array[String] = []


class ReferenceOwner:
	extends RefCounted
	var prepare_calls := 0
	var commit_calls := 0
	var rollback_calls := 0
	var finalize_calls := 0
	var commit_succeeds := true
	var rollback_succeeds := true
	var finalize_succeeds := true

	func prepare_intent(intent: Dictionary) -> Dictionary:
		prepare_calls += 1
		return SCHEMA.stage_receipt(intent, "prepared", true, "prepared", {"route_domain": intent.get("route_domain", "")})

	func commit_intent(prepared: Dictionary) -> Dictionary:
		commit_calls += 1
		return SCHEMA.stage_receipt(prepared, "committed", commit_succeeds, "committed" if commit_succeeds else "simulated_commit_failure")

	func rollback_intent(receipt: Dictionary) -> Dictionary:
		rollback_calls += 1
		return SCHEMA.stage_receipt(receipt, "rolled_back", rollback_succeeds, "rolled_back" if rollback_succeeds else "simulated_rollback_failure")

	func finalize_intent(receipt: Dictionary) -> Dictionary:
		finalize_calls += 1
		return SCHEMA.stage_receipt(receipt, "finalized", finalize_succeeds, "finalized" if finalize_succeeds else "simulated_finalize_failure")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_routes_and_exact_once()
	_verify_failure_lifecycle()
	_verify_counter_scope_zero_side_effect()
	_finish()


func _verify_routes_and_exact_once() -> void:
	var router = ROUTER.new()
	var owners := {"contract": ReferenceOwner.new(), "intel": ReferenceOwner.new(), "direct_player": ReferenceOwner.new(), "counter_response": ReferenceOwner.new()}
	_expect(bool(router.configure(owners).get("configured", false)), "router configures all field domains")
	_expect(not router.configured_domains().has("contract"), "retired contract owner is not configurable")
	var fixtures := [
		_intent("tx-intel", "intel_card_trace", "private_evidence", {"interaction_domain": "intel"}, []),
		_intent("tx-direct", "player_hand_disrupt", "opponent_discardable_hand", {"direct_player_interaction": true}, ["B"]),
		_intent("tx-counter", "card_counter", "incoming_direct_player_interaction", {"target_scope": "direct_player_interaction", "response_depth": 1}, ["A"]),
	]
	for fixture_variant in fixtures:
		var fixture: Dictionary = fixture_variant
		var domain := SCHEMA.route_domain(fixture)
		var owner: ReferenceOwner = owners[domain]
		var prepared: Dictionary = router.prepare_effect(fixture)
		var committed: Dictionary = router.commit_effect(prepared)
		var replay: Dictionary = router.commit_effect(prepared)
		_expect(bool(prepared.get("prepared", false)) and bool(committed.get("committed", false)), "%s prepare and commit" % domain)
		_expect(bool(replay.get("idempotent_replay", false)) and owner.commit_calls == 1, "%s commit is exact-once" % domain)
		var finalized: Dictionary = router.finalize_effect(committed)
		var finalize_replay: Dictionary = router.finalize_effect(committed)
		_expect(bool(finalized.get("finalized", false)) and bool(finalize_replay.get("idempotent_replay", false)) and owner.finalize_calls == 1, "%s finalize is exact-once" % domain)
	_expect(bool(router.checkpoint_status().get("can_checkpoint", false)), "finalized router is checkpoint-safe")
	var retired_contract := _intent("tx-contract", "contract_offer_v06", "target_player", {"interaction_domain": "contract"}, ["B"])
	var rejected: Dictionary = router.prepare_effect(retired_contract)
	_expect(not bool(rejected.get("prepared", false)) and str(rejected.get("reason_code", "")) == "interaction_effect_fields_unsupported", "retired contract offer reaches no router owner")


func _verify_failure_lifecycle() -> void:
	var commit_owner := ReferenceOwner.new()
	commit_owner.commit_succeeds = false
	var router = ROUTER.new()
	router.configure({"direct_player": commit_owner})
	var prepared: Dictionary = router.prepare_effect(_intent("tx-commit-fail", "player_hand_steal", "opponent_discardable_hand", {"direct_player_interaction": true}, ["B"]))
	var failed: Dictionary = router.commit_effect(prepared)
	_expect(not bool(failed.get("committed", true)) and commit_owner.commit_calls == 1, "commit failure is explicit and not replayed")
	var rolled: Dictionary = router.rollback_effect(prepared)
	_expect(bool(rolled.get("rolled_back", false)) and commit_owner.rollback_calls == 1, "prepared or failed commit can rollback")

	var rollback_owner := ReferenceOwner.new()
	rollback_owner.rollback_succeeds = false
	router = ROUTER.new()
	router.configure({"direct_player": rollback_owner})
	prepared = router.prepare_effect(_intent("tx-rollback-fail", "player_hand_steal", "opponent_discardable_hand", {"direct_player_interaction": true}, ["B"]))
	var committed: Dictionary = router.commit_effect(prepared)
	rolled = router.rollback_effect(committed)
	_expect(not bool(rolled.get("rolled_back", true)) and not bool(router.checkpoint_status().get("can_checkpoint", true)), "rollback failure remains inflight and honest")

	var finalize_owner := ReferenceOwner.new()
	finalize_owner.finalize_succeeds = false
	router = ROUTER.new()
	router.configure({"direct_player": finalize_owner})
	prepared = router.prepare_effect(_intent("tx-finalize-fail", "player_hand_disrupt", "opponent_discardable_hand", {"direct_player_interaction": true}, ["B"]))
	committed = router.commit_effect(prepared)
	var finalized: Dictionary = router.finalize_effect(committed)
	_expect(not bool(finalized.get("finalized", true)) and finalize_owner.finalize_calls == 1, "finalize failure is explicit")


func _verify_counter_scope_zero_side_effect() -> void:
	var counter_owner := ReferenceOwner.new()
	var router = ROUTER.new()
	router.configure({"counter_response": counter_owner})
	for kind in ["economic_price_shift", "monster_autonomous_action", "weather_control", "map_capacity_effect"]:
		var invalid := _intent("tx-invalid-%s" % kind, "card_counter", "incoming_%s" % kind, {"target_scope": kind, "response_depth": 1}, ["A"])
		var result: Dictionary = router.prepare_effect(invalid)
		_expect(not bool(result.get("prepared", true)), "%s cannot be phase-vetoed" % kind)
	_expect(counter_owner.prepare_calls == 0 and counter_owner.commit_calls == 0, "invalid counter scopes have zero owner side effects")


func _intent(transaction_id: String, effect_kind: String, target_kind: String, payload: Dictionary, targets: Array) -> Dictionary:
	return {"schema_version": "0.6", "transaction_id": transaction_id, "actor_id": "A", "card_id": "fixture.card", "card_instance_id": "instance-%s" % transaction_id, "effect_kind": effect_kind, "target_kind": target_kind, "target_player_ids": targets, "target_revision": 1, "effect_payload": payload, "target_hash": "target", "payload_hash": "payload", "intent_hash": "intent-%s" % transaction_id}


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
		print("FAIL: %s" % message)


func _finish() -> void:
	print("ANONYMOUS_INTERACTION_ROUTER_V06_TEST|status=%s|checks=%d|failures=%d" % ["PASS" if _failures.is_empty() else "FAIL", _checks, _failures.size()])
	quit(0 if _failures.is_empty() else 1)
