extends SceneTree

const SCHEMA := preload("res://scripts/cards/v06/units/unit_card_runtime_schema_v06.gd")
const OWNER_SCRIPT := preload("res://scripts/cards/v06/units/unit_card_reference_owner_v06.gd")
const ADAPTER_SCRIPT := preload("res://scripts/cards/v06/units/monster_card_effect_adapter_v06.gd")

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_summon_upgrade_and_finalize()
	_verify_lure_is_one_shot_and_exact_once()
	_verify_all_bound_skill_families()
	_verify_invalid_target_and_stale_revision()
	_verify_commit_failure_and_rollback_paths()
	_verify_finalize_failure_can_retry()
	_finish()


func _verify_summon_upgrade_and_finalize() -> void:
	var fixture := _fixture()
	var owner: Object = fixture.owner
	var adapter: Object = fixture.adapter
	var summon := _intent(
		"monster-summon",
		owner.call("revision"),
		"deploy_or_upgrade_monster",
		"deploy_or_upgrade_monster",
		{"valid": true, "region_id": "region-alpha"},
		_monster_fields(1)
	)
	var prepared: Dictionary = adapter.call("prepare_effect", summon)
	var committed: Dictionary = adapter.call("commit_effect", prepared)
	var finalized: Dictionary = adapter.call("finalize_effect", committed)
	_expect(bool(prepared.get("prepared", false)), "legal monster summon prepares")
	_expect(bool(committed.get("committed", false)) and str(committed.get("outcome", "")) == "unit_deployed", "legal monster summon commits once")
	_expect(bool(finalized.get("finalized", false)), "monster summon finalizes explicitly")
	var snapshot: Dictionary = owner.call("private_debug_snapshot")
	var units: Dictionary = snapshot.get("units", {}) as Dictionary
	_expect(units.size() == 1 and int(snapshot.get("history_count", -1)) == 1, "summon creates one reference unit and one terminal journal entry")
	var uid := int(units.keys()[0])

	var upgrade := _intent(
		"monster-upgrade",
		owner.call("revision"),
		"deploy_or_upgrade_monster",
		"deploy_or_upgrade_monster",
		{"valid": true, "unit_uid": uid},
		_monster_fields(3)
	)
	var upgrade_prepared: Dictionary = adapter.call("prepare_effect", upgrade)
	var upgrade_committed: Dictionary = adapter.call("commit_effect", upgrade_prepared)
	var upgrade_finalized: Dictionary = adapter.call("finalize_effect", upgrade_committed)
	var upgraded: Dictionary = (owner.call("private_debug_snapshot") as Dictionary).get("units", {}).get(uid, {}) as Dictionary
	_expect(bool(upgrade_committed.get("committed", false)) and str(upgrade_committed.get("outcome", "")) == "unit_upgraded", "same-family owned monster upgrades")
	_expect(int(upgraded.get("rank", 0)) == 3 and int(upgraded.get("presence_extension_seconds", 0)) == 60, "upgrade forwards rank and additive presence extension without recomputing combat")
	_expect(bool(upgrade_finalized.get("finalized", false)), "monster upgrade finalizes")
	var replay: Dictionary = adapter.call("prepare_effect", upgrade)
	_expect(bool(replay.get("idempotent_replay", false)) and bool(replay.get("finalized", false)), "finalized monster transaction replays its journal instead of upgrading twice")
	_expect(int(((owner.call("private_debug_snapshot") as Dictionary).get("units", {}) as Dictionary).get(uid, {}).get("rank", 0)) == 3, "monster transaction replay has no second mutation")


func _verify_lure_is_one_shot_and_exact_once() -> void:
	var fixture := _fixture()
	var owner: Object = fixture.owner
	var adapter: Object = fixture.adapter
	var uid: int = owner.call("seed_unit", "syndicate-a", "monster.test", "region-alpha", 1)
	var lure := _intent(
		"monster-lure",
		owner.call("revision"),
		"monster_lure_once",
		"monster_lure",
		{"valid": true, "unit_uid": uid, "target_region_id": "region-delta"},
		{"consumption_policy": "next_autonomous_move_once"}
	)
	var prepared: Dictionary = adapter.call("prepare_effect", lure)
	var committed: Dictionary = adapter.call("commit_effect", prepared)
	var replay_commit: Dictionary = adapter.call("commit_effect", prepared)
	var finalized: Dictionary = adapter.call("finalize_effect", committed)
	_expect(bool(committed.get("committed", false)) and str(committed.get("outcome", "")) == "monster_lure_reserved_once", "lure installs one autonomous-move override")
	_expect(bool(replay_commit.get("idempotent_replay", false)), "lure commit replay does not install a second override")
	_expect(bool(finalized.get("finalized", false)), "lure can finalize before the autonomous owner consumes it")
	var first_consume: Dictionary = owner.call("consume_reference_lure", uid)
	var second_consume: Dictionary = owner.call("consume_reference_lure", uid)
	_expect(bool(first_consume.get("consumed", false)) and str(first_consume.get("target_region_id", "")) == "region-delta", "autonomous owner consumes the lure once")
	_expect(not bool(second_consume.get("consumed", true)), "lure cannot be consumed twice")
	var replay_after_consume: Dictionary = adapter.call("prepare_effect", lure)
	_expect(bool(replay_after_consume.get("idempotent_replay", false)), "lure transaction remains exact-once after consumption")


func _verify_all_bound_skill_families() -> void:
	var fixture := _fixture()
	var owner: Object = fixture.owner
	var adapter: Object = fixture.adapter
	var uid: int = owner.call("seed_unit", "syndicate-a", "monster.test", "region-alpha", 2)
	var action_targets := {
		"monster_move": {"valid": true, "unit_uid": uid, "target_region_id": "region-beta"},
		"monster_attack": {"valid": true, "unit_uid": uid, "target_monster_uid": 901},
		"monster_guard": {"valid": true, "unit_uid": uid},
		"monster_area_suppress": {"valid": true, "unit_uid": uid, "target_region_id": "region-gamma"},
	}
	for action_variant in action_targets.keys():
		var action := str(action_variant)
		var intent := _intent(
			"monster-skill-%s" % action,
			owner.call("revision"),
			"monster_bound_action",
			action,
			(action_targets[action] as Dictionary).duplicate(true),
			{"skill_profile_id": "skill.profile.%s" % action, "bound_action_instance_id": "bound.%s" % action}
		)
		var prepared: Dictionary = adapter.call("prepare_effect", intent)
		var committed: Dictionary = adapter.call("commit_effect", prepared)
		var finalized: Dictionary = adapter.call("finalize_effect", committed)
		_expect(bool(committed.get("committed", false)) and bool(finalized.get("finalized", false)), "%s is accepted as a field-driven fixed monster skill" % action)
	var command_log: Array = (owner.call("private_debug_snapshot") as Dictionary).get("command_log", []) as Array
	_expect(command_log.size() == action_targets.size(), "fixed monster skills are forwarded as intents without adapter-side movement or damage simulation")


func _verify_invalid_target_and_stale_revision() -> void:
	var fixture := _fixture()
	var owner: Object = fixture.owner
	var adapter: Object = fixture.adapter
	var invalid := _intent(
		"monster-invalid-region",
		owner.call("revision"),
		"deploy_or_upgrade_monster",
		"deploy_or_upgrade_monster",
		{"valid": true, "region_id": "invalid-region"},
		_monster_fields(1)
	)
	var invalid_receipt: Dictionary = adapter.call("prepare_effect", invalid)
	_expect(not bool(invalid_receipt.get("prepared", true)) and str(invalid_receipt.get("reason_code", "")) == "unit_region_not_authoritative", "authoritative owner rejects an invalid monster region before mutation")
	_expect(((owner.call("private_debug_snapshot") as Dictionary).get("units", {}) as Dictionary).is_empty(), "invalid monster target leaves owner state unchanged")

	owner.call("seed_unit", "syndicate-a", "monster.test", "region-alpha", 1)
	var stale := _intent(
		"monster-stale",
		0,
		"deploy_or_upgrade_monster",
		"deploy_or_upgrade_monster",
		{"valid": true, "region_id": "region-beta"},
		_monster_fields(1, 2)
	)
	var stale_receipt: Dictionary = adapter.call("prepare_effect", stale)
	_expect(not bool(stale_receipt.get("prepared", true)) and str(stale_receipt.get("reason_code", "")) == "unit_owner_revision_stale", "stale monster owner revision fails closed")


func _verify_commit_failure_and_rollback_paths() -> void:
	var commit_fixture := _fixture()
	var commit_owner: Object = commit_fixture.owner
	var commit_adapter: Object = commit_fixture.adapter
	var commit_intent := _intent("monster-commit-fail", 0, "deploy_or_upgrade_monster", "deploy_or_upgrade_monster", {"valid": true, "region_id": "region-alpha"}, _monster_fields(1))
	var commit_prepared: Dictionary = commit_adapter.call("prepare_effect", commit_intent)
	commit_owner.call("set_failure_mode", "commit", true)
	var commit_failed: Dictionary = commit_adapter.call("commit_effect", commit_prepared)
	_expect(not bool(commit_failed.get("committed", true)) and str(commit_failed.get("reason_code", "")) == "reference_commit_injected_failure", "injected monster commit failure is explicit")
	_expect(((commit_owner.call("private_debug_snapshot") as Dictionary).get("units", {}) as Dictionary).is_empty(), "failed monster commit has no side effect")
	commit_owner.call("set_failure_mode", "commit", false)
	var abort_result: Dictionary = commit_adapter.call("rollback_effect", commit_prepared)
	_expect(bool(abort_result.get("rolled_back", false)), "prepared monster reservation can roll back after commit failure")

	var rollback_fixture := _fixture()
	var rollback_owner: Object = rollback_fixture.owner
	var rollback_adapter: Object = rollback_fixture.adapter
	var rollback_intent := _intent("monster-rollback", 0, "deploy_or_upgrade_monster", "deploy_or_upgrade_monster", {"valid": true, "region_id": "region-alpha"}, _monster_fields(1))
	var rollback_prepared: Dictionary = rollback_adapter.call("prepare_effect", rollback_intent)
	var rollback_committed: Dictionary = rollback_adapter.call("commit_effect", rollback_prepared)
	var rollback_ok: Dictionary = rollback_adapter.call("rollback_effect", rollback_committed)
	_expect(bool(rollback_ok.get("rolled_back", false)), "committed monster effect restores its preimage on rollback")
	_expect(((rollback_owner.call("private_debug_snapshot") as Dictionary).get("units", {}) as Dictionary).is_empty() and int(rollback_owner.call("revision")) == 0, "successful monster rollback restores roster and revision")

	var failed_fixture := _fixture()
	var failed_owner: Object = failed_fixture.owner
	var failed_adapter: Object = failed_fixture.adapter
	var failed_intent := _intent("monster-rollback-fail", 0, "deploy_or_upgrade_monster", "deploy_or_upgrade_monster", {"valid": true, "region_id": "region-alpha"}, _monster_fields(1))
	var failed_prepared: Dictionary = failed_adapter.call("prepare_effect", failed_intent)
	var failed_committed: Dictionary = failed_adapter.call("commit_effect", failed_prepared)
	failed_owner.call("set_failure_mode", "rollback", true)
	var failed_rollback: Dictionary = failed_adapter.call("rollback_effect", failed_committed)
	_expect(not bool(failed_rollback.get("rolled_back", true)) and bool(failed_rollback.get("compensation_failed", false)), "monster rollback failure is never reported as compensated")
	_expect(((failed_owner.call("private_debug_snapshot") as Dictionary).get("units", {}) as Dictionary).size() == 1, "failed rollback preserves diagnostic owner state")
	failed_owner.call("set_failure_mode", "rollback", false)
	var retry_rollback: Dictionary = failed_adapter.call("rollback_effect", failed_committed)
	_expect(bool(retry_rollback.get("rolled_back", false)), "monster rollback remains retryable after explicit failure")


func _verify_finalize_failure_can_retry() -> void:
	var fixture := _fixture()
	var owner: Object = fixture.owner
	var adapter: Object = fixture.adapter
	var intent := _intent("monster-finalize-fail", 0, "deploy_or_upgrade_monster", "deploy_or_upgrade_monster", {"valid": true, "region_id": "region-alpha"}, _monster_fields(1))
	var prepared: Dictionary = adapter.call("prepare_effect", intent)
	var committed: Dictionary = adapter.call("commit_effect", prepared)
	owner.call("set_failure_mode", "finalize", true)
	var failed: Dictionary = adapter.call("finalize_effect", committed)
	_expect(not bool(failed.get("finalized", true)), "monster finalize failure does not close the reservation")
	_expect(not bool((adapter.call("checkpoint_status") as Dictionary).get("can_checkpoint", true)), "failed monster finalize blocks checkpoint")
	owner.call("set_failure_mode", "finalize", false)
	var retried: Dictionary = adapter.call("finalize_effect", committed)
	var replay: Dictionary = adapter.call("finalize_effect", retried)
	_expect(bool(retried.get("finalized", false)), "monster finalize succeeds when retried")
	_expect(bool(replay.get("idempotent_replay", false)), "monster finalize replay is exact-once")
	_expect(bool((adapter.call("checkpoint_status") as Dictionary).get("can_checkpoint", false)), "finalized monster action releases checkpoint gate")


func _fixture() -> Dictionary:
	var owner = OWNER_SCRIPT.new()
	owner.configure("monster")
	var adapter = ADAPTER_SCRIPT.new()
	var configured: Dictionary = adapter.configure(owner)
	_expect(bool(configured.get("configured", false)), "monster reference owner adapter configures")
	_expect(bool((configured.get("capability_matrix", {}) as Dictionary).get("atomic_mutation_ready", false)), "monster reference owner advertises the complete atomic contract")
	return {"owner": owner, "adapter": adapter}


func _intent(transaction_id: String, revision: int, effect_kind: String, action_kind: String, target: Dictionary, fields: Dictionary) -> Dictionary:
	return SCHEMA.make_intent(
		transaction_id,
		"syndicate-a",
		"card.%s" % transaction_id,
		"instance.%s" % transaction_id,
		effect_kind,
		action_kind,
		revision,
		target,
		fields,
		{"anonymous_play": true, "hidden_owner": true}
	)


func _monster_fields(rank: int, control_limit: int = 1) -> Dictionary:
	return {
		"monster_family_id": "monster.test",
		"card_rank": rank,
		"heal_to_full_on_upgrade": true,
		"presence_time_policy": "add_to_remaining_time",
		"same_name_upgrade_extend_seconds": 60,
		"public_rule_inputs": {"unit_control_limit": control_limit},
	}


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		return
	_failures.append(message)
	print("FAIL: %s" % message)


func _finish() -> void:
	if _failures.is_empty():
		print("MONSTER_CARD_RUNTIME_V06_TEST|status=PASS|checks=%d|failures=0" % _checks)
		quit(0)
		return
	print("MONSTER_CARD_RUNTIME_V06_TEST|status=FAIL|checks=%d|failures=%d|details=%s" % [_checks, _failures.size(), JSON.stringify(_failures)])
	quit(1)
