extends SceneTree

const SCHEMA := preload("res://scripts/cards/v06/units/unit_card_runtime_schema_v06.gd")
const OWNER_SCRIPT := preload("res://scripts/cards/v06/units/unit_card_reference_owner_v06.gd")
const ADAPTER_SCRIPT := preload("res://scripts/cards/v06/units/military_card_effect_adapter_v06.gd")

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_deploy_upgrade_and_finalize()
	_verify_all_reusable_commands_and_exact_once()
	_verify_invalid_target_and_stale_revision()
	_verify_commit_failure_and_rollback_paths()
	_verify_finalize_failure_can_retry()
	_finish()


func _verify_deploy_upgrade_and_finalize() -> void:
	var fixture := _fixture()
	var owner: Object = fixture.owner
	var adapter: Object = fixture.adapter
	var deploy := _intent(
		"military-deploy",
		owner.call("revision"),
		"deploy_or_upgrade_military",
		"deploy_or_upgrade_military",
		{"valid": true, "region_id": "region-alpha"},
		_military_fields(1)
	)
	var prepared: Dictionary = adapter.call("prepare_effect", deploy)
	var committed: Dictionary = adapter.call("commit_effect", prepared)
	var finalized: Dictionary = adapter.call("finalize_effect", committed)
	_expect(bool(prepared.get("prepared", false)), "legal military deploy prepares")
	_expect(bool(committed.get("committed", false)) and str(committed.get("outcome", "")) == "unit_deployed", "legal military deploy commits")
	_expect(bool(finalized.get("finalized", false)), "military deploy finalizes explicitly")
	var units: Dictionary = (owner.call("private_debug_snapshot") as Dictionary).get("units", {}) as Dictionary
	_expect(units.size() == 1, "military deploy creates exactly one reference unit")
	var uid := int(units.keys()[0])

	var upgrade := _intent(
		"military-upgrade",
		owner.call("revision"),
		"deploy_or_upgrade_military",
		"deploy_or_upgrade_military",
		{"valid": true, "unit_uid": uid},
		_military_fields(4)
	)
	var upgrade_prepared: Dictionary = adapter.call("prepare_effect", upgrade)
	var upgrade_committed: Dictionary = adapter.call("commit_effect", upgrade_prepared)
	var upgrade_finalized: Dictionary = adapter.call("finalize_effect", upgrade_committed)
	var upgraded_units: Dictionary = (owner.call("private_debug_snapshot") as Dictionary).get("units", {}) as Dictionary
	var upgraded: Dictionary = upgraded_units.get(uid, {}) as Dictionary
	_expect(bool(upgrade_committed.get("committed", false)) and str(upgrade_committed.get("outcome", "")) == "unit_upgraded", "owned same-family military upgrades")
	_expect(int(upgraded.get("rank", 0)) == 4 and bool(upgraded.get("healed_to_full", false)), "military upgrade forwards rank and repair semantics to owner")
	_expect(bool(upgrade_finalized.get("finalized", false)), "military upgrade finalizes")
	var replay: Dictionary = adapter.call("prepare_effect", upgrade)
	_expect(bool(replay.get("idempotent_replay", false)) and bool(replay.get("finalized", false)), "military deployment transaction replay is exact-once")
	_expect(((owner.call("private_debug_snapshot") as Dictionary).get("units", {}) as Dictionary).size() == 1, "military transaction replay cannot deploy a second unit")


func _verify_all_reusable_commands_and_exact_once() -> void:
	var fixture := _fixture()
	var owner: Object = fixture.owner
	var adapter: Object = fixture.adapter
	var uid: int = owner.call("seed_unit", "syndicate-a", "military.test", "region-alpha", 2)
	var action_targets := {
		"military_move": {"valid": true, "unit_uid": uid, "target_region_id": "region-beta"},
		"military_guard": {"valid": true, "unit_uid": uid, "target_region_id": "region-alpha"},
		"military_attack_monster": {"valid": true, "unit_uid": uid, "target_monster_uid": 777},
		"military_suppress_region": {"valid": true, "unit_uid": uid, "target_region_id": "region-gamma"},
	}
	for action_variant in action_targets.keys():
		var action := str(action_variant)
		var intent := _intent(
			"military-command-%s" % action,
			owner.call("revision"),
			"military_reusable_command",
			action,
			(action_targets[action] as Dictionary).duplicate(true),
			{"command_profile_id": "command.profile.%s" % action, "command_instance_id": "command.%s" % action, "persistent": true}
		)
		var prepared: Dictionary = adapter.call("prepare_effect", intent)
		var committed: Dictionary = adapter.call("commit_effect", prepared)
		var replay_commit: Dictionary = adapter.call("commit_effect", prepared)
		var finalized: Dictionary = adapter.call("finalize_effect", committed)
		_expect(bool(committed.get("committed", false)) and bool(finalized.get("finalized", false)), "%s is forwarded as a reusable command intent" % action)
		_expect(bool(replay_commit.get("idempotent_replay", false)), "%s transaction cannot issue the command twice" % action)
	var command_log: Array = (owner.call("private_debug_snapshot") as Dictionary).get("command_log", []) as Array
	_expect(command_log.size() == action_targets.size(), "move, guard, attack-monster and suppress each issue exactly one owner command")
	_expect(command_log.all(func(entry: Variant) -> bool: return entry is Dictionary and str((entry as Dictionary).get("action_kind", "")).begins_with("military_")), "adapter does not simulate military movement or combat outside the owner")


func _verify_invalid_target_and_stale_revision() -> void:
	var fixture := _fixture()
	var owner: Object = fixture.owner
	var adapter: Object = fixture.adapter
	var invalid := _intent(
		"military-invalid-region",
		owner.call("revision"),
		"deploy_or_upgrade_military",
		"deploy_or_upgrade_military",
		{"valid": true, "region_id": "invalid-sector"},
		_military_fields(1)
	)
	var invalid_receipt: Dictionary = adapter.call("prepare_effect", invalid)
	_expect(not bool(invalid_receipt.get("prepared", true)) and str(invalid_receipt.get("reason_code", "")) == "unit_region_not_authoritative", "authoritative military owner rejects an invalid region")
	_expect(((owner.call("private_debug_snapshot") as Dictionary).get("units", {}) as Dictionary).is_empty(), "invalid military target produces no owner mutation")

	owner.call("seed_unit", "syndicate-a", "military.test", "region-alpha", 1)
	var stale := _intent(
		"military-stale",
		0,
		"deploy_or_upgrade_military",
		"deploy_or_upgrade_military",
		{"valid": true, "region_id": "region-beta"},
		_military_fields(1, 2)
	)
	var stale_receipt: Dictionary = adapter.call("prepare_effect", stale)
	_expect(not bool(stale_receipt.get("prepared", true)) and str(stale_receipt.get("reason_code", "")) == "unit_owner_revision_stale", "stale military owner revision fails closed")


func _verify_commit_failure_and_rollback_paths() -> void:
	var commit_fixture := _fixture()
	var commit_owner: Object = commit_fixture.owner
	var commit_adapter: Object = commit_fixture.adapter
	var commit_intent := _intent("military-commit-fail", 0, "deploy_or_upgrade_military", "deploy_or_upgrade_military", {"valid": true, "region_id": "region-alpha"}, _military_fields(1))
	var commit_prepared: Dictionary = commit_adapter.call("prepare_effect", commit_intent)
	commit_owner.call("set_failure_mode", "commit", true)
	var commit_failed: Dictionary = commit_adapter.call("commit_effect", commit_prepared)
	_expect(not bool(commit_failed.get("committed", true)) and str(commit_failed.get("reason_code", "")) == "reference_commit_injected_failure", "injected military commit failure is explicit")
	_expect(((commit_owner.call("private_debug_snapshot") as Dictionary).get("units", {}) as Dictionary).is_empty(), "failed military commit has no side effect")
	commit_owner.call("set_failure_mode", "commit", false)
	var aborted: Dictionary = commit_adapter.call("rollback_effect", commit_prepared)
	_expect(bool(aborted.get("rolled_back", false)), "prepared military reservation rolls back after commit failure")

	var rollback_fixture := _fixture()
	var rollback_owner: Object = rollback_fixture.owner
	var rollback_adapter: Object = rollback_fixture.adapter
	var rollback_intent := _intent("military-rollback", 0, "deploy_or_upgrade_military", "deploy_or_upgrade_military", {"valid": true, "region_id": "region-alpha"}, _military_fields(1))
	var rollback_prepared: Dictionary = rollback_adapter.call("prepare_effect", rollback_intent)
	var rollback_committed: Dictionary = rollback_adapter.call("commit_effect", rollback_prepared)
	var rollback_ok: Dictionary = rollback_adapter.call("rollback_effect", rollback_committed)
	_expect(bool(rollback_ok.get("rolled_back", false)), "committed military effect rolls back")
	_expect(((rollback_owner.call("private_debug_snapshot") as Dictionary).get("units", {}) as Dictionary).is_empty() and int(rollback_owner.call("revision")) == 0, "successful military rollback restores owner preimage")

	var failed_fixture := _fixture()
	var failed_owner: Object = failed_fixture.owner
	var failed_adapter: Object = failed_fixture.adapter
	var failed_intent := _intent("military-rollback-fail", 0, "deploy_or_upgrade_military", "deploy_or_upgrade_military", {"valid": true, "region_id": "region-alpha"}, _military_fields(1))
	var failed_prepared: Dictionary = failed_adapter.call("prepare_effect", failed_intent)
	var failed_committed: Dictionary = failed_adapter.call("commit_effect", failed_prepared)
	failed_owner.call("set_failure_mode", "rollback", true)
	var failed_rollback: Dictionary = failed_adapter.call("rollback_effect", failed_committed)
	_expect(not bool(failed_rollback.get("rolled_back", true)) and bool(failed_rollback.get("compensation_failed", false)), "military rollback failure is never forged as compensated")
	_expect(((failed_owner.call("private_debug_snapshot") as Dictionary).get("units", {}) as Dictionary).size() == 1, "failed military rollback leaves diagnostic state intact")
	failed_owner.call("set_failure_mode", "rollback", false)
	var retried: Dictionary = failed_adapter.call("rollback_effect", failed_committed)
	_expect(bool(retried.get("rolled_back", false)), "military rollback can retry after explicit owner failure")


func _verify_finalize_failure_can_retry() -> void:
	var fixture := _fixture()
	var owner: Object = fixture.owner
	var adapter: Object = fixture.adapter
	var intent := _intent("military-finalize-fail", 0, "deploy_or_upgrade_military", "deploy_or_upgrade_military", {"valid": true, "region_id": "region-alpha"}, _military_fields(1))
	var prepared: Dictionary = adapter.call("prepare_effect", intent)
	var committed: Dictionary = adapter.call("commit_effect", prepared)
	owner.call("set_failure_mode", "finalize", true)
	var failed: Dictionary = adapter.call("finalize_effect", committed)
	_expect(not bool(failed.get("finalized", true)), "military finalize failure stays explicit")
	_expect(not bool((adapter.call("checkpoint_status") as Dictionary).get("can_checkpoint", true)), "failed military finalize blocks checkpoint")
	owner.call("set_failure_mode", "finalize", false)
	var retried: Dictionary = adapter.call("finalize_effect", committed)
	var replay: Dictionary = adapter.call("finalize_effect", retried)
	_expect(bool(retried.get("finalized", false)), "military finalize remains retryable")
	_expect(bool(replay.get("idempotent_replay", false)), "military finalize replay is exact-once")
	_expect(bool((adapter.call("checkpoint_status") as Dictionary).get("can_checkpoint", false)), "finalized military command releases checkpoint gate")


func _fixture() -> Dictionary:
	var owner = OWNER_SCRIPT.new()
	owner.configure("military")
	var adapter = ADAPTER_SCRIPT.new()
	var configured: Dictionary = adapter.configure(owner)
	_expect(bool(configured.get("configured", false)), "military reference owner adapter configures")
	_expect(bool((configured.get("capability_matrix", {}) as Dictionary).get("atomic_mutation_ready", false)), "military reference owner advertises complete atomic capabilities")
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


func _military_fields(rank: int, control_limit: int = 1) -> Dictionary:
	return {
		"military_family_id": "military.test",
		"card_rank": rank,
		"heal_to_full_on_upgrade": true,
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
		print("MILITARY_CARD_RUNTIME_V06_TEST|status=PASS|checks=%d|failures=0" % _checks)
		quit(0)
		return
	print("MILITARY_CARD_RUNTIME_V06_TEST|status=FAIL|checks=%d|failures=%d|details=%s" % [_checks, _failures.size(), JSON.stringify(_failures)])
	quit(1)
