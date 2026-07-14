extends Node

const SCHEMA := preload("res://scripts/cards/v06/units/unit_card_runtime_schema_v06.gd")
const REFERENCE_OWNER_SCRIPT := preload("res://scripts/cards/v06/units/unit_card_reference_owner_v06.gd")
const MONSTER_ADAPTER_SCRIPT := preload("res://scripts/cards/v06/units/monster_card_effect_adapter_v06.gd")
const MILITARY_ADAPTER_SCRIPT := preload("res://scripts/cards/v06/units/military_card_effect_adapter_v06.gd")
const ROUTER_SCRIPT := preload("res://scripts/cards/v06/units/unit_card_effect_router_v06.gd")
const RECEIPT_FILTER := preload("res://scripts/cards/v06/units/unit_card_receipt_filter_v06.gd")
const CHECKPOINT_GATE_SCRIPT := preload("res://scripts/cards/v06/units/unit_card_checkpoint_gate_v06.gd")
const MONSTER_RUNTIME_SCRIPT := preload("res://scripts/runtime/monster_runtime_controller.gd")
const MILITARY_RUNTIME_SCRIPT := preload("res://scripts/runtime/military_runtime_controller.gd")

const ACTOR_ID := "bench-syndicate"

var _checks := 0
var _failures: Array[String] = []


func _ready() -> void:
	set_meta("bench_exit_code", 1)
	call_deferred("_run")


func _run() -> void:
	var monster_owner = REFERENCE_OWNER_SCRIPT.new()
	var military_owner = REFERENCE_OWNER_SCRIPT.new()
	_check(bool(monster_owner.configure("monster").get("configured", false)), "reference_monster_owner_configured")
	_check(bool(military_owner.configure("military").get("configured", false)), "reference_military_owner_configured")

	var monster_adapter = MONSTER_ADAPTER_SCRIPT.new()
	var military_adapter = MILITARY_ADAPTER_SCRIPT.new()
	_check(bool(monster_adapter.configure(monster_owner).get("configured", false)), "reference_monster_adapter_configured")
	_check(bool(military_adapter.configure(military_owner).get("configured", false)), "reference_military_adapter_configured")

	var router = ROUTER_SCRIPT.new()
	var router_config: Dictionary = router.configure({
		"deploy_or_upgrade_monster": monster_adapter,
		"monster_lure_once": monster_adapter,
		"monster_bound_action": monster_adapter,
		"deploy_or_upgrade_military": military_adapter,
		"military_reusable_command": military_adapter,
	})
	_check(bool(router_config.get("configured", false)), "router_configured")
	_check((router_config.get("effect_kinds", []) as Array).size() == 5, "router_all_effect_families")

	var gate = CHECKPOINT_GATE_SCRIPT.new()
	var gate_config: Dictionary = gate.configure(router, [monster_adapter, military_adapter])
	_check(bool(gate_config.get("configured", false)), "checkpoint_gate_configured")
	_check(bool(gate.checkpoint_status().get("can_checkpoint", false)), "checkpoint_initially_ready")

	var monster_deploy := SCHEMA.make_intent(
		"bench-monster-deploy",
		ACTOR_ID,
		"monster.bench.rank_1",
		"monster-card-instance-1",
		"deploy_or_upgrade_monster",
		"deploy_or_upgrade_monster",
		monster_owner.revision(),
		{"region_id": "region-alpha"},
		{
			"monster_family_id": "monster-family-bench",
			"card_rank": 1,
			"heal_to_full_on_upgrade": true,
			"same_name_upgrade_extend_seconds": 60,
			"public_rule_inputs": {"unit_control_limit": 1},
		}
	)
	var deploy_result := _execute_and_finalize(router, gate, monster_deploy, "monster_deploy")
	var monster_uid := int((deploy_result.get("private_fields", {}) as Dictionary).get("bound_unit_uid", 0))
	_check(monster_uid > 0 and str(deploy_result.get("outcome", "")) == "unit_deployed", "monster_deployed")

	var lure_intent := SCHEMA.make_intent(
		"bench-monster-lure",
		ACTOR_ID,
		"monster.lure.once",
		"monster-lure-instance-1",
		"monster_lure_once",
		"monster_lure",
		monster_owner.revision(),
		{"unit_uid": monster_uid, "target_region_id": "region-beta"},
		{"consumption_policy": "next_autonomous_move_once"}
	)
	var lure_result := _execute_and_finalize(router, gate, lure_intent, "monster_lure")
	_check(bool(lure_result.get("finalized", false)), "monster_lure_finalized")
	var lure_first: Dictionary = monster_owner.consume_reference_lure(monster_uid)
	var lure_second: Dictionary = monster_owner.consume_reference_lure(monster_uid)
	_check(bool(lure_first.get("consumed", false)) and str(lure_first.get("target_region_id", "")) == "region-beta", "monster_lure_consumed_once")
	_check(not bool(lure_second.get("consumed", false)), "monster_lure_second_consume_rejected")
	var lure_replay: Dictionary = router.prepare_effect(lure_intent)
	var lure_third: Dictionary = monster_owner.consume_reference_lure(monster_uid)
	_check(bool(lure_replay.get("idempotent_replay", false)) and bool(lure_replay.get("finalized", false)), "monster_lure_transaction_replay")
	_check(not bool(lure_third.get("consumed", false)), "monster_lure_replay_does_not_restore_override")

	var skill_intent := SCHEMA.make_intent(
		"bench-monster-fixed-skill",
		ACTOR_ID,
		"monster.bound.guard",
		"monster-fixed-skill-instance-1",
		"monster_bound_action",
		"monster_guard",
		monster_owner.revision(),
		{"unit_uid": monster_uid},
		{
			"skill_profile_id": "monster-fixed-guard-profile",
			"bound_action_instance_id": "monster-%d-fixed-guard" % monster_uid,
		}
	)
	var skill_result := _execute_and_finalize(router, gate, skill_intent, "monster_fixed_skill")
	_check(bool(skill_result.get("finalized", false)), "monster_fixed_skill_finalized")
	var monster_debug: Dictionary = monster_owner.private_debug_snapshot()
	_check((monster_debug.get("command_log", []) as Array).size() == 1, "monster_fixed_skill_forwarded_once")

	var military_deploy := SCHEMA.make_intent(
		"bench-military-deploy",
		ACTOR_ID,
		"military.bench.rank_1",
		"military-card-instance-1",
		"deploy_or_upgrade_military",
		"deploy_or_upgrade_military",
		military_owner.revision(),
		{"region_id": "region-alpha"},
		{
			"military_family_id": "military-family-bench",
			"card_rank": 1,
			"public_rule_inputs": {"unit_control_limit": 1},
		}
	)
	var military_deploy_result := _execute_and_finalize(router, gate, military_deploy, "military_deploy")
	var military_uid := int((military_deploy_result.get("private_fields", {}) as Dictionary).get("bound_unit_uid", 0))
	_check(military_uid > 0 and str(military_deploy_result.get("outcome", "")) == "unit_deployed", "military_deployed")

	var command_intent := SCHEMA.make_intent(
		"bench-military-command",
		ACTOR_ID,
		"military.command.move",
		"military-command-card-instance-1",
		"military_reusable_command",
		"military_move",
		military_owner.revision(),
		{"unit_uid": military_uid, "target_region_id": "region-gamma"},
		{
			"command_instance_id": "military-%d-command-move" % military_uid,
			"command_profile_id": "military-move-profile",
			"persistent": true,
		}
	)
	var command_result := _execute_and_finalize(router, gate, command_intent, "military_command")
	_check(bool(command_result.get("finalized", false)), "military_command_finalized")
	var command_replay: Dictionary = router.prepare_effect(command_intent)
	var military_debug: Dictionary = military_owner.private_debug_snapshot()
	_check(bool(command_replay.get("idempotent_replay", false)) and bool(command_replay.get("finalized", false)), "military_command_transaction_replay")
	_check((military_debug.get("command_log", []) as Array).size() == 1, "military_command_forwarded_exactly_once")

	_run_privacy_checks(command_result)
	_run_real_owner_fail_closed_checks()
	_check(bool(gate.checkpoint_status().get("can_checkpoint", false)), "checkpoint_ready_after_terminal_stages")
	_finish()


func _execute_and_finalize(router: Object, gate: Object, intent: Dictionary, label: String) -> Dictionary:
	var prepared: Dictionary = router.call("prepare_effect", intent)
	_check(bool(prepared.get("prepared", false)), "%s_prepared" % label)
	if not bool(prepared.get("prepared", false)):
		return prepared
	_check(not bool(gate.call("checkpoint_status").get("can_checkpoint", true)), "%s_checkpoint_blocked_while_inflight" % label)
	var committed: Dictionary = router.call("commit_effect", prepared)
	_check(bool(committed.get("committed", false)), "%s_committed" % label)
	if not bool(committed.get("committed", false)):
		return committed
	var finalized: Dictionary = router.call("finalize_effect", committed)
	_check(bool(finalized.get("finalized", false)), "%s_finalized" % label)
	_check(bool(gate.call("checkpoint_status").get("can_checkpoint", false)), "%s_checkpoint_reopened" % label)
	return finalized


func _run_privacy_checks(receipt: Dictionary) -> void:
	var adversarial := receipt.duplicate(true)
	var public_fields: Dictionary = adversarial.get("public_fields", {}) if adversarial.get("public_fields", {}) is Dictionary else {}
	public_fields = public_fields.duplicate(true)
	public_fields["public_changes"] = [
		{
			"label": "军令已受理",
			"hidden_owner": "never-public-owner",
			"opponent_cash": 999,
			"ai_private_plan": "never-public-plan",
		},
	]
	adversarial["public_fields"] = public_fields
	adversarial["true_owner"] = "never-public-owner"
	adversarial["opponent_hand"] = ["never-public-card"]
	var public_receipt: Dictionary = RECEIPT_FILTER.public_view(adversarial)
	var scan: Dictionary = RECEIPT_FILTER.public_leak_scan(public_receipt)
	var encoded := JSON.stringify(public_receipt)
	_check(int(scan.get("leak_count", -1)) == 0, "public_receipt_privacy_leak_count_zero")
	_check(not encoded.contains("never-public"), "public_receipt_private_values_removed")
	_check(bool(public_receipt.get("anonymous", false)) and not public_receipt.has("revealed_owner_label"), "public_receipt_anonymous")
	var own_private: Dictionary = RECEIPT_FILTER.private_view(receipt, ACTOR_ID)
	var rival_private: Dictionary = RECEIPT_FILTER.private_view(receipt, "rival-syndicate")
	_check(own_private.has("private") and not rival_private.has("private"), "private_receipt_viewer_scoped")


func _run_real_owner_fail_closed_checks() -> void:
	var real_monster: Node = MONSTER_RUNTIME_SCRIPT.new()
	var real_military: Node = MILITARY_RUNTIME_SCRIPT.new()
	add_child(real_monster)
	add_child(real_military)

	var monster_adapter = MONSTER_ADAPTER_SCRIPT.new()
	var military_adapter = MILITARY_ADAPTER_SCRIPT.new()
	monster_adapter.configure(real_monster)
	military_adapter.configure(real_military)
	var monster_capabilities: Dictionary = monster_adapter.capability_matrix()
	var military_capabilities: Dictionary = military_adapter.capability_matrix()
	_check(not bool(monster_capabilities.get("atomic_mutation_ready", true)), "real_monster_owner_atomic_capability_gap_detected")
	_check(not bool(military_capabilities.get("atomic_mutation_ready", true)), "real_military_owner_atomic_capability_gap_detected")

	var monster_before := _roster_size(real_monster)
	var monster_intent := SCHEMA.make_intent(
		"bench-real-monster-fail-closed",
		ACTOR_ID,
		"monster.bench.rank_1",
		"real-monster-card-instance-1",
		"deploy_or_upgrade_monster",
		"deploy_or_upgrade_monster",
		0,
		{"region_id": "region-alpha"},
		{"monster_family_id": "monster-family-bench", "card_rank": 1}
	)
	var monster_result: Dictionary = monster_adapter.prepare_effect(monster_intent)
	_check(
		not bool(monster_result.get("prepared", false))
		and str(monster_result.get("reason_code", "")) == "monster_owner_atomic_contract_missing"
		and _roster_size(real_monster) == monster_before,
		"real_monster_owner_fails_closed_without_mutation"
	)

	var military_before := _roster_size(real_military)
	var military_intent := SCHEMA.make_intent(
		"bench-real-military-fail-closed",
		ACTOR_ID,
		"military.bench.rank_1",
		"real-military-card-instance-1",
		"deploy_or_upgrade_military",
		"deploy_or_upgrade_military",
		0,
		{"region_id": "region-alpha"},
		{"military_family_id": "military-family-bench", "card_rank": 1}
	)
	var military_result: Dictionary = military_adapter.prepare_effect(military_intent)
	_check(
		not bool(military_result.get("prepared", false))
		and str(military_result.get("reason_code", "")) == "military_owner_atomic_contract_missing"
		and _roster_size(real_military) == military_before,
		"real_military_owner_fails_closed_without_mutation"
	)


func _roster_size(runtime_owner: Object) -> int:
	if runtime_owner == null or not runtime_owner.has_method("roster_snapshot"):
		return -1
	var value_variant: Variant = runtime_owner.call("roster_snapshot", false)
	return (value_variant as Array).size() if value_variant is Array else -1


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)


func _finish() -> void:
	if _failures.is_empty():
		set_meta("bench_exit_code", 0)
		print("MONSTER_MILITARY_CARD_RUNTIME_V06_BENCH|status=PASS|checks=%d|failures=0" % _checks)
		return
	set_meta("bench_exit_code", 1)
	var details := JSON.stringify(_failures).replace("|", "/").replace("\n", " ")
	print("MONSTER_MILITARY_CARD_RUNTIME_V06_BENCH|status=FAIL|checks=%d|failures=%d|details=%s" % [_checks, _failures.size(), details])
	push_error("Monster/Military v0.6 Bench failed: %s" % ", ".join(_failures))
