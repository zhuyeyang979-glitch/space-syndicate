extends SceneTree

const SCHEMA := preload("res://scripts/cards/v06/units/unit_card_runtime_schema_v06.gd")
const MONSTER_ADAPTER_SCRIPT := preload("res://scripts/cards/v06/units/monster_card_effect_adapter_v06.gd")
const MILITARY_ADAPTER_SCRIPT := preload("res://scripts/cards/v06/units/military_card_effect_adapter_v06.gd")
const REFERENCE_OWNER_SCRIPT := preload("res://scripts/cards/v06/units/unit_card_reference_owner_v06.gd")
const MONSTER_OWNER_SCRIPT := preload("res://scripts/runtime/monster_runtime_controller.gd")
const MILITARY_OWNER_SCRIPT := preload("res://scripts/runtime/military_runtime_controller.gd")
const ROUTER_SCRIPT := preload("res://scripts/cards/v06/units/unit_card_effect_router_v06.gd")
const CHECKPOINT_GATE_SCRIPT := preload("res://scripts/cards/v06/units/unit_card_checkpoint_gate_v06.gd")
const CARD_CATALOG_JSON := "res://data/cards/card_runtime_catalog_v06.json"

var _checks := 0
var _failures: Array[String] = []


class DeclaresCapabilitiesWithoutMethods:
	extends RefCounted

	func unit_card_runtime_capabilities_v06(domain: String) -> Dictionary:
		return {
			"contract_version": "v0.6",
			"revision": true,
			"prepare": true,
			"commit": true,
			"rollback": true,
			"finalize": true,
			"exact_once": true,
			"checkpoint_gate": true,
			"privacy_safe_snapshot": true,
			"supported_effect_kinds": ["deploy_or_upgrade_%s" % domain],
			"supported_action_kinds": ["deploy_or_upgrade_%s" % domain],
		}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_shipped_catalog_effect_family_counts()
	_verify_real_monster_owner_fails_closed()
	_verify_real_military_owner_fails_closed()
	_verify_declarations_cannot_fake_owner_methods()
	_verify_reference_owner_is_the_explicit_positive_control()
	_verify_checkpoint_gate_rejects_legacy_owners()
	_finish()


func _verify_shipped_catalog_effect_family_counts() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CARD_CATALOG_JSON))
	_expect(parsed is Dictionary, "shipped v0.6 card runtime catalog parses for capability audit")
	if not (parsed is Dictionary):
		return
	var counts: Dictionary = {}
	var cards: Array = (parsed as Dictionary).get("cards", []) as Array
	for card_variant in cards:
		if not (card_variant is Dictionary):
			continue
		var card: Dictionary = card_variant as Dictionary
		var effect_kind := str(card.get("effect_kind", ""))
		if card.get("machine", {}) is Dictionary:
			effect_kind = str((card.get("machine", {}) as Dictionary).get("effect_kind", effect_kind))
		counts[effect_kind] = int(counts.get(effect_kind, 0)) + 1
	_expect(int(counts.get("deploy_or_upgrade_monster", 0)) == 32, "shipped catalog contains 32 deploy-or-upgrade monster cards")
	_expect(int(counts.get("deploy_or_upgrade_military", 0)) == 28, "shipped catalog contains 28 deploy-or-upgrade military cards")
	_expect(int(counts.get("monster_lure_once", 0)) == 0 and int(counts.get("monster_bound_action", 0)) == 0 and int(counts.get("military_reusable_command", 0)) == 0, "shipped catalog currently contains no lure, bound-action, or reusable-command card entries")


func _verify_real_monster_owner_fails_closed() -> void:
	var owner = MONSTER_OWNER_SCRIPT.new()
	var adapter = MONSTER_ADAPTER_SCRIPT.new()
	var configured: Dictionary = adapter.configure(owner)
	var matrix: Dictionary = configured.get("capability_matrix", {}) as Dictionary
	var before := JSON.stringify(owner.roster_snapshot(true))
	var result: Dictionary = adapter.prepare_effect(_monster_intent("real-monster-owner"))
	var after := JSON.stringify(owner.roster_snapshot(true))
	_expect(bool(configured.get("configured", false)), "legacy monster owner can be inspected through the forwarding port")
	_expect(not bool(matrix.get("atomic_mutation_ready", true)) and str(matrix.get("capability_reason", "")) == "monster_owner_atomic_contract_missing", "real monster owner advertises no unsupported atomic readiness")
	_expect(_contains_required_gaps(matrix), "real monster owner matrix names every mandatory transaction gap")
	_expect(bool(matrix.get("snapshot", false)) and bool(matrix.get("save_load", false)), "capability audit still records real monster snapshot and save-load support")
	_expect(not bool(result.get("prepared", true)) and str(result.get("reason_code", "")) == "monster_owner_atomic_contract_missing", "real monster mutation fails closed at adapter entry")
	_expect(before == after, "fail-closed monster adapter never invokes legacy summon or mutation APIs")
	var feedback: Dictionary = result.get("player_feedback", {}) as Dictionary
	_expect(str(feedback.get("reason", "")).contains("资产") and not JSON.stringify(feedback).to_lower().contains("mana") and not JSON.stringify(feedback).contains("法力"), "capability failure uses player-facing asset terminology")
	_expect(not bool((adapter.checkpoint_status() as Dictionary).get("can_checkpoint", true)), "legacy monster owner cannot pass the inflight checkpoint gate")
	owner.free()


func _verify_real_military_owner_fails_closed() -> void:
	var owner = MILITARY_OWNER_SCRIPT.new()
	var adapter = MILITARY_ADAPTER_SCRIPT.new()
	var configured: Dictionary = adapter.configure(owner)
	var matrix: Dictionary = configured.get("capability_matrix", {}) as Dictionary
	var before := JSON.stringify(owner.roster_snapshot(true))
	var result: Dictionary = adapter.prepare_effect(_military_intent("real-military-owner"))
	var after := JSON.stringify(owner.roster_snapshot(true))
	_expect(bool(configured.get("configured", false)), "legacy military owner can be inspected through the forwarding port")
	_expect(not bool(matrix.get("atomic_mutation_ready", true)) and str(matrix.get("capability_reason", "")) == "military_owner_atomic_contract_missing", "real military owner advertises no unsupported atomic readiness")
	_expect(_contains_required_gaps(matrix), "real military owner matrix names every mandatory transaction gap")
	_expect(bool(matrix.get("snapshot", false)) and bool(matrix.get("save_load", false)), "capability audit records real military snapshot and save-load support")
	_expect(not bool(result.get("prepared", true)) and str(result.get("reason_code", "")) == "military_owner_atomic_contract_missing", "real military mutation fails closed at adapter entry")
	_expect(before == after, "fail-closed military adapter never invokes legacy summon or command APIs")
	_expect(not bool((adapter.checkpoint_status() as Dictionary).get("can_checkpoint", true)), "legacy military owner cannot pass checkpoint gate")
	owner.free()


func _verify_declarations_cannot_fake_owner_methods() -> void:
	var liar = DeclaresCapabilitiesWithoutMethods.new()
	var monster_adapter = MONSTER_ADAPTER_SCRIPT.new()
	var configured: Dictionary = monster_adapter.configure(liar)
	var matrix: Dictionary = configured.get("capability_matrix", {}) as Dictionary
	_expect(not bool(matrix.get("prepare", true)) and not bool(matrix.get("commit", true)) and not bool(matrix.get("rollback", true)) and not bool(matrix.get("finalize", true)), "capability declarations require corresponding owner methods")
	_expect(not bool(matrix.get("checkpoint_gate", true)) and not bool(matrix.get("atomic_mutation_ready", true)), "declared checkpoint support also requires a callable gate")
	var result: Dictionary = monster_adapter.prepare_effect(_monster_intent("lying-owner"))
	_expect(not bool(result.get("prepared", true)) and str(result.get("reason_code", "")) == "monster_owner_atomic_contract_missing", "false capability declaration cannot produce a success receipt")


func _verify_reference_owner_is_the_explicit_positive_control() -> void:
	var owner = REFERENCE_OWNER_SCRIPT.new()
	owner.configure("monster")
	var adapter = MONSTER_ADAPTER_SCRIPT.new()
	var configured: Dictionary = adapter.configure(owner)
	var matrix: Dictionary = configured.get("capability_matrix", {}) as Dictionary
	_expect(bool(matrix.get("atomic_mutation_ready", false)) and bool(matrix.get("privacy_safe_snapshot", false)), "reference-only owner explicitly implements the complete contract")
	_expect((matrix.get("missing_mutation_capabilities", []) as Array).is_empty(), "positive-control owner has no mutation capability gaps")
	var prepared: Dictionary = adapter.prepare_effect(_monster_intent("reference-positive"))
	var committed: Dictionary = adapter.commit_effect(prepared)
	var finalized: Dictionary = adapter.finalize_effect(committed)
	_expect(bool(prepared.get("prepared", false)) and bool(committed.get("committed", false)) and bool(finalized.get("finalized", false)), "reference owner proves the adapter contract without claiming production ownership")
	var safe_snapshot: Dictionary = (adapter.get("_port") as Object).call("safe_snapshot")
	_expect(bool(safe_snapshot.get("available", false)) and not JSON.stringify(safe_snapshot).contains("actor_id"), "reference owner's declared safe snapshot omits private actor identity")


func _verify_checkpoint_gate_rejects_legacy_owners() -> void:
	var monster_owner = MONSTER_OWNER_SCRIPT.new()
	var military_owner = MILITARY_OWNER_SCRIPT.new()
	var monster_adapter = MONSTER_ADAPTER_SCRIPT.new()
	var military_adapter = MILITARY_ADAPTER_SCRIPT.new()
	monster_adapter.configure(monster_owner)
	military_adapter.configure(military_owner)
	var router = ROUTER_SCRIPT.new()
	router.configure({
		"deploy_or_upgrade_monster": monster_adapter,
		"deploy_or_upgrade_military": military_adapter,
	})
	var gate = CHECKPOINT_GATE_SCRIPT.new()
	gate.configure(router, [monster_adapter, military_adapter])
	var status: Dictionary = gate.require_checkpoint_ready()
	_expect(not bool(status.get("allowed", true)) and str(status.get("reason_code", "")) == "unit_checkpoint_inflight_or_owner_unsafe", "checkpoint gate refuses save when either authoritative owner lacks reservation checkpoint semantics")
	var feedback: Dictionary = status.get("player_feedback", {}) as Dictionary
	_expect(not str(feedback.get("reason", "")).is_empty() and not str(feedback.get("next_step", "")).is_empty(), "blocked checkpoint tells the player why and what to do next")
	monster_owner.free()
	military_owner.free()


func _contains_required_gaps(matrix: Dictionary) -> bool:
	var missing: Array = matrix.get("missing_mutation_capabilities", []) as Array
	for required in ["revision", "prepare", "commit", "rollback", "finalize", "exact_once", "checkpoint_gate"]:
		if not missing.has(required):
			return false
	return true


func _monster_intent(transaction_id: String) -> Dictionary:
	return SCHEMA.make_intent(
		transaction_id,
		"syndicate-a",
		"card.%s" % transaction_id,
		"instance.%s" % transaction_id,
		"deploy_or_upgrade_monster",
		"deploy_or_upgrade_monster",
		0,
		{"valid": true, "region_id": "region-alpha"},
		{"monster_family_id": "monster.test", "card_rank": 1, "same_name_upgrade_extend_seconds": 60, "public_rule_inputs": {"unit_control_limit": 1}}
	)


func _military_intent(transaction_id: String) -> Dictionary:
	return SCHEMA.make_intent(
		transaction_id,
		"syndicate-a",
		"card.%s" % transaction_id,
		"instance.%s" % transaction_id,
		"deploy_or_upgrade_military",
		"deploy_or_upgrade_military",
		0,
		{"valid": true, "region_id": "region-alpha"},
		{"military_family_id": "military.test", "card_rank": 1, "public_rule_inputs": {"unit_control_limit": 1}}
	)


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		return
	_failures.append(message)
	print("FAIL: %s" % message)


func _finish() -> void:
	if _failures.is_empty():
		print("UNIT_CARD_OWNER_CAPABILITY_V06_TEST|status=PASS|checks=%d|failures=0" % _checks)
		quit(0)
		return
	print("UNIT_CARD_OWNER_CAPABILITY_V06_TEST|status=FAIL|checks=%d|failures=%d|details=%s" % [_checks, _failures.size(), JSON.stringify(_failures)])
	quit(1)
