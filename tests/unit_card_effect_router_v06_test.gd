extends SceneTree

const SCHEMA := preload("res://scripts/cards/v06/units/unit_card_runtime_schema_v06.gd")
const OWNER_SCRIPT := preload("res://scripts/cards/v06/units/unit_card_reference_owner_v06.gd")
const MONSTER_ADAPTER_SCRIPT := preload("res://scripts/cards/v06/units/monster_card_effect_adapter_v06.gd")
const MILITARY_ADAPTER_SCRIPT := preload("res://scripts/cards/v06/units/military_card_effect_adapter_v06.gd")
const ROUTER_SCRIPT := preload("res://scripts/cards/v06/units/unit_card_effect_router_v06.gd")
const CHECKPOINT_GATE_SCRIPT := preload("res://scripts/cards/v06/units/unit_card_checkpoint_gate_v06.gd")

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_field_driven_routing_and_exact_once()
	_verify_frozen_card_flow_intent_normalization()
	_verify_receipt_cannot_self_report_another_effect_kind()
	_verify_commit_failure_remains_retryable()
	_verify_rollback_failure_does_not_close_association()
	_verify_finalize_failure_does_not_close_association()
	_verify_checkpoint_gate_tracks_router_and_owners()
	_finish()


func _verify_frozen_card_flow_intent_normalization() -> void:
	var fixture := _fixture()
	var router: Object = fixture.router
	var target := {"valid": true, "region_id": "region-alpha", "expected_owner_revision": 0}
	var effect_payload := {
		"monster_family_id": "monster.test",
		"card_rank": 1,
		"same_name_upgrade_extend_seconds": 60,
		"public_rule_inputs": {"unit_control_limit": 1},
	}
	var raw_effect_intent := {
		"transaction_id": "router-frozen-card-flow",
		"actor_id": "syndicate-a",
		"card_id": "card.router-frozen-card-flow",
		"card_instance_id": "instance.router-frozen-card-flow",
		"effect_kind": "deploy_or_upgrade_monster",
		"target_context": target,
		"effect_payload": effect_payload,
		"target_hash": SCHEMA.fingerprint(target),
		"payload_hash": SCHEMA.fingerprint(effect_payload),
		"intent_hash": "frozen-card-flow-intent-hash",
	}
	_expect(not raw_effect_intent.has("contract_version") and not raw_effect_intent.has("action_kind") and not raw_effect_intent.has("effect_fields"), "fixture matches the frozen CardFlow raw effect-intent shape")
	var prepared: Dictionary = router.call("prepare_effect", raw_effect_intent)
	_expect(bool(prepared.get("prepared", false)) and str(prepared.get("action_kind", "")) == "deploy_or_upgrade_monster", "router normalizes frozen CardFlow intent into the v0.6 unit contract")
	_expect(not str(prepared.get("unit_intent_fingerprint", "")).is_empty(), "normalized CardFlow intent receives a unit binding fingerprint")
	var rolled_back: Dictionary = router.call("rollback_effect", prepared)
	_expect(bool(rolled_back.get("rolled_back", false)) and bool((router.call("checkpoint_status") as Dictionary).get("can_checkpoint", false)), "normalized prepared intent can roll back cleanly before commit")


func _verify_field_driven_routing_and_exact_once() -> void:
	var fixture := _fixture()
	var router: Object = fixture.router
	var monster_owner: Object = fixture.monster_owner
	var intent := _monster_deploy_intent("router-monster-success", monster_owner.call("revision"), "region-alpha")
	var prepared: Dictionary = router.call("prepare_effect", intent)
	var committed: Dictionary = router.call("commit_effect", prepared)
	var finalized: Dictionary = router.call("finalize_effect", committed)
	var replay: Dictionary = router.call("prepare_effect", intent)
	_expect(bool(prepared.get("prepared", false)) and bool(committed.get("committed", false)) and bool(finalized.get("finalized", false)), "router drives the configured monster handler through all stages")
	_expect(bool(replay.get("idempotent_replay", false)) and bool(replay.get("finalized", false)), "router replays the authoritative terminal receipt")
	_expect(((monster_owner.call("private_debug_snapshot") as Dictionary).get("units", {}) as Dictionary).size() == 1, "router transaction replay does not mutate owner twice")
	var collision := _monster_deploy_intent("router-monster-success", monster_owner.call("revision"), "region-beta")
	var collision_receipt: Dictionary = router.call("prepare_effect", collision)
	_expect(not bool(collision_receipt.get("prepared", true)) and str(collision_receipt.get("reason_code", "")) == "unit_transaction_binding_conflict", "same transaction id cannot bind to a new intent")


func _verify_receipt_cannot_self_report_another_effect_kind() -> void:
	var fixture := _fixture()
	var router: Object = fixture.router
	var monster_owner: Object = fixture.monster_owner
	var military_owner: Object = fixture.military_owner
	var intent := _monster_deploy_intent("router-binding", monster_owner.call("revision"), "region-alpha")
	var prepared: Dictionary = router.call("prepare_effect", intent)
	var forged := prepared.duplicate(true)
	forged["effect_kind"] = "deploy_or_upgrade_military"
	forged["action_kind"] = "deploy_or_upgrade_military"
	var rejected: Dictionary = router.call("commit_effect", forged)
	_expect(not bool(rejected.get("committed", true)) and str(rejected.get("reason_code", "")) == "unit_commit_binding_mismatch", "caller receipt cannot redirect a monster transaction to the military handler")
	_expect(((monster_owner.call("private_debug_snapshot") as Dictionary).get("units", {}) as Dictionary).is_empty(), "forged receipt produces no monster mutation")
	_expect(((military_owner.call("private_debug_snapshot") as Dictionary).get("units", {}) as Dictionary).is_empty(), "forged receipt produces no military mutation")
	var committed: Dictionary = router.call("commit_effect", prepared)
	_expect(bool(committed.get("committed", false)), "authoritative stored binding remains usable after forged caller receipt")
	var forged_terminal := committed.duplicate(true)
	forged_terminal["effect_kind"] = "deploy_or_upgrade_military"
	var forged_rollback: Dictionary = router.call("rollback_effect", forged_terminal)
	_expect(not bool(forged_rollback.get("rolled_back", true)) and str(forged_rollback.get("reason_code", "")) == "unit_rollback_binding_mismatch", "rollback also ignores a receipt's self-reported effect family")
	var rolled_back: Dictionary = router.call("rollback_effect", committed)
	_expect(bool(rolled_back.get("rolled_back", false)), "authoritative association routes rollback to the original owner")
	_expect(((monster_owner.call("private_debug_snapshot") as Dictionary).get("units", {}) as Dictionary).is_empty(), "authoritative rollback restores the monster owner")


func _verify_commit_failure_remains_retryable() -> void:
	var fixture := _fixture()
	var router: Object = fixture.router
	var owner: Object = fixture.military_owner
	var intent := _military_deploy_intent("router-commit-retry", owner.call("revision"), "region-alpha")
	var prepared: Dictionary = router.call("prepare_effect", intent)
	owner.call("set_failure_mode", "commit", true)
	var failed: Dictionary = router.call("commit_effect", prepared)
	_expect(not bool(failed.get("committed", true)), "router preserves explicit owner commit failure")
	_expect(int(((router.call("debug_snapshot") as Dictionary).get("stage_counts", {}) as Dictionary).get("commit_failed", 0)) == 1, "router records commit_failed without claiming success")
	owner.call("set_failure_mode", "commit", false)
	var retried: Dictionary = router.call("commit_effect", prepared)
	_expect(bool(retried.get("committed", false)), "commit failure association remains retryable")
	var rolled_back: Dictionary = router.call("rollback_effect", retried)
	_expect(bool(rolled_back.get("rolled_back", false)), "retried commit remains compensatable")


func _verify_rollback_failure_does_not_close_association() -> void:
	var fixture := _fixture()
	var router: Object = fixture.router
	var owner: Object = fixture.monster_owner
	var intent := _monster_deploy_intent("router-rollback-retry", owner.call("revision"), "region-alpha")
	var prepared: Dictionary = router.call("prepare_effect", intent)
	var committed: Dictionary = router.call("commit_effect", prepared)
	owner.call("set_failure_mode", "rollback", true)
	var failed: Dictionary = router.call("rollback_effect", committed)
	var checkpoint_after_failure: Dictionary = router.call("checkpoint_status")
	_expect(not bool(failed.get("rolled_back", true)) and bool(failed.get("compensation_failed", false)), "router never closes rollback on owner failure")
	_expect(not bool(checkpoint_after_failure.get("can_checkpoint", true)), "failed rollback remains an inflight checkpoint blocker")
	_expect(int(((router.call("debug_snapshot") as Dictionary).get("stage_counts", {}) as Dictionary).get("rollback_failed", 0)) == 1, "router records rollback_failed rather than rolled_back")
	owner.call("set_failure_mode", "rollback", false)
	var retried: Dictionary = router.call("rollback_effect", committed)
	var replay: Dictionary = router.call("rollback_effect", committed)
	_expect(bool(retried.get("rolled_back", false)), "rollback failure remains retryable against the same association")
	_expect(bool(replay.get("idempotent_replay", false)), "successful rollback is exact-once")
	_expect(bool((router.call("checkpoint_status") as Dictionary).get("can_checkpoint", false)), "successful rollback closes router inflight state")


func _verify_finalize_failure_does_not_close_association() -> void:
	var fixture := _fixture()
	var router: Object = fixture.router
	var owner: Object = fixture.military_owner
	var intent := _military_deploy_intent("router-finalize-retry", owner.call("revision"), "region-alpha")
	var prepared: Dictionary = router.call("prepare_effect", intent)
	var committed: Dictionary = router.call("commit_effect", prepared)
	owner.call("set_failure_mode", "finalize", true)
	var failed: Dictionary = router.call("finalize_effect", committed)
	_expect(not bool(failed.get("finalized", true)), "router never closes finalize on owner failure")
	_expect(not bool((router.call("checkpoint_status") as Dictionary).get("can_checkpoint", true)), "failed finalize remains a checkpoint blocker")
	_expect(int(((router.call("debug_snapshot") as Dictionary).get("stage_counts", {}) as Dictionary).get("finalize_failed", 0)) == 1, "router records finalize_failed explicitly")
	owner.call("set_failure_mode", "finalize", false)
	var retried: Dictionary = router.call("finalize_effect", committed)
	var replay: Dictionary = router.call("finalize_effect", committed)
	_expect(bool(retried.get("finalized", false)), "finalize failure remains retryable against the committed owner receipt")
	_expect(bool(replay.get("idempotent_replay", false)), "successful finalize is exact-once")
	_expect(bool((router.call("checkpoint_status") as Dictionary).get("can_checkpoint", false)), "successful finalize closes router inflight state")


func _verify_checkpoint_gate_tracks_router_and_owners() -> void:
	var fixture := _fixture()
	var router: Object = fixture.router
	var gate = CHECKPOINT_GATE_SCRIPT.new()
	var configured: Dictionary = gate.configure(router, [fixture.monster_adapter, fixture.military_adapter])
	_expect(bool(configured.get("configured", false)) and bool((configured.get("status", {}) as Dictionary).get("can_checkpoint", false)), "checkpoint gate starts ready when router and owners are idle")
	var intent := _monster_deploy_intent("router-checkpoint", fixture.monster_owner.call("revision"), "region-alpha")
	var prepared: Dictionary = router.call("prepare_effect", intent)
	var blocked: Dictionary = gate.require_checkpoint_ready()
	_expect(not bool(blocked.get("allowed", true)) and str(blocked.get("reason_code", "")) == "unit_checkpoint_inflight_or_owner_unsafe", "prepared reservation blocks save/checkpoint")
	var rolled_back: Dictionary = router.call("rollback_effect", prepared)
	_expect(bool(rolled_back.get("rolled_back", false)) and bool((gate.require_checkpoint_ready() as Dictionary).get("allowed", false)), "rolling back a prepared reservation reopens checkpoint")


func _fixture() -> Dictionary:
	var monster_owner = OWNER_SCRIPT.new()
	monster_owner.configure("monster")
	var military_owner = OWNER_SCRIPT.new()
	military_owner.configure("military")
	var monster_adapter = MONSTER_ADAPTER_SCRIPT.new()
	var military_adapter = MILITARY_ADAPTER_SCRIPT.new()
	monster_adapter.configure(monster_owner)
	military_adapter.configure(military_owner)
	var router = ROUTER_SCRIPT.new()
	var configured: Dictionary = router.configure({
		"deploy_or_upgrade_monster": monster_adapter,
		"monster_lure_once": monster_adapter,
		"monster_bound_action": monster_adapter,
		"deploy_or_upgrade_military": military_adapter,
		"military_reusable_command": military_adapter,
	})
	_expect(bool(configured.get("configured", false)) and (configured.get("effect_kinds", []) as Array).size() == 5, "router configures all five field-driven unit effect families")
	return {
		"monster_owner": monster_owner,
		"military_owner": military_owner,
		"monster_adapter": monster_adapter,
		"military_adapter": military_adapter,
		"router": router,
	}


func _monster_deploy_intent(transaction_id: String, revision: int, region_id: String) -> Dictionary:
	return SCHEMA.make_intent(
		transaction_id,
		"syndicate-a",
		"card.%s" % transaction_id,
		"instance.%s" % transaction_id,
		"deploy_or_upgrade_monster",
		"deploy_or_upgrade_monster",
		revision,
		{"valid": true, "region_id": region_id},
		{"monster_family_id": "monster.test", "card_rank": 1, "same_name_upgrade_extend_seconds": 60, "public_rule_inputs": {"unit_control_limit": 1}},
		{"anonymous_play": true, "hidden_owner": true}
	)


func _military_deploy_intent(transaction_id: String, revision: int, region_id: String) -> Dictionary:
	return SCHEMA.make_intent(
		transaction_id,
		"syndicate-a",
		"card.%s" % transaction_id,
		"instance.%s" % transaction_id,
		"deploy_or_upgrade_military",
		"deploy_or_upgrade_military",
		revision,
		{"valid": true, "region_id": region_id},
		{"military_family_id": "military.test", "card_rank": 1, "public_rule_inputs": {"unit_control_limit": 1}},
		{"anonymous_play": true, "hidden_owner": true}
	)


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		return
	_failures.append(message)
	print("FAIL: %s" % message)


func _finish() -> void:
	if _failures.is_empty():
		print("UNIT_CARD_EFFECT_ROUTER_V06_TEST|status=PASS|checks=%d|failures=0" % _checks)
		quit(0)
		return
	print("UNIT_CARD_EFFECT_ROUTER_V06_TEST|status=FAIL|checks=%d|failures=%d|details=%s" % [_checks, _failures.size(), JSON.stringify(_failures)])
	quit(1)
