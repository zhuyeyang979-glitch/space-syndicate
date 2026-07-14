extends SceneTree

const CONTROLLER_SCRIPT := preload("res://scripts/runtime/player_organization_runtime_controller.gd")
const ADAPTER_SCRIPT := preload("res://scripts/cards/v06/organization/organization_card_effect_adapter_v06.gd")
const CATALOG_PATH := "res://resources/cards/runtime/card_runtime_catalog_v06.tres"
const ACTOR := "human.alpha"
const FAMILIES := [
	"organization.starport_clearinghouse",
	"organization.quantum_agenda_network",
	"organization.deep_space_archive",
	"organization.monster_liaison_charter",
	"organization.stellar_command_directorate",
]

var _checks := 0
var _failures: Array[String] = []
var _sequence := 0
var _catalog: CardRuntimeCatalogV06Resource
var _created_owners: Array[Node] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_catalog = load(CATALOG_PATH) as CardRuntimeCatalogV06Resource
	_expect(_catalog != null and bool(_catalog.reload().get("valid", false)), "organization runtime uses the authoritative catalog")
	_test_all_catalog_payloads()
	_test_adapter_lifecycle_and_abort()
	_test_fail_closed_contracts()
	_finish()


func _test_all_catalog_payloads() -> void:
	for family_id in FAMILIES:
		for rank in range(1, 5):
			var owner := CONTROLLER_SCRIPT.new() as PlayerOrganizationRuntimeController
			_created_owners.append(owner)
			owner.configure([ACTOR])
			var adapter := ADAPTER_SCRIPT.new() as OrganizationCardEffectAdapterV06
			_expect(bool(adapter.configure(owner).get("atomic_mutation_ready", false)), "%s rank %d adapter binds one atomic owner" % [family_id, rank])
			var intent := _intent("%s.rank_%d" % [family_id, rank], 0)
			var prepared: Dictionary = adapter.prepare_effect(intent)
			_expect(bool(prepared.get("prepared", false)), "%s rank %d prepares from catalog fields" % [family_id, rank])
			var committed: Dictionary = adapter.commit_effect(prepared)
			_expect(bool(committed.get("committed", false)), "%s rank %d commits once" % [family_id, rank])
			var finalized: Dictionary = adapter.finalize_effect(committed)
			_expect(bool(finalized.get("finalized", false)) and bool(adapter.checkpoint_status().get("can_checkpoint", false)), "%s rank %d finalizes checkpoint-safe" % [family_id, rank])


func _test_adapter_lifecycle_and_abort() -> void:
	var owner := CONTROLLER_SCRIPT.new() as PlayerOrganizationRuntimeController
	_created_owners.append(owner)
	owner.configure([ACTOR])
	var adapter := ADAPTER_SCRIPT.new() as OrganizationCardEffectAdapterV06
	adapter.configure(owner)
	var intent := _intent("organization.deep_space_archive.rank_1", 2)
	var prepared: Dictionary = adapter.prepare_effect(intent)
	var aborted: Dictionary = adapter.abort_prepared_effect(prepared)
	_expect(bool(aborted.get("rolled_back", false)) and int(owner.hand_limit_terms(ACTOR, 3).get("ordinary_hand_limit", -1)) == 5, "CardFlow-compatible abort leaves no installed modifier")
	_expect(adapter.abort_prepared_effect(prepared) == aborted, "prepared abort replay is exact once")

	var second_intent := _intent("organization.deep_space_archive.rank_1", 3)
	var second_prepared: Dictionary = adapter.prepare_effect(second_intent)
	var committed: Dictionary = adapter.commit_effect(second_prepared)
	var rollback: Dictionary = adapter.rollback_effect(committed)
	_expect(bool(rollback.get("rolled_back", false)) and int(owner.hand_limit_terms(ACTOR, 4).get("ordinary_hand_limit", -1)) == 5, "adapter rollback compensates the owner before CardFlow state rejection")
	_expect(bool(adapter.capability_matrix().get("rollback_ready", false)), "adapter advertises rollback/finalize/checkpoint capability")


func _test_fail_closed_contracts() -> void:
	var owner := CONTROLLER_SCRIPT.new() as PlayerOrganizationRuntimeController
	_created_owners.append(owner)
	owner.configure([ACTOR])
	var adapter := ADAPTER_SCRIPT.new() as OrganizationCardEffectAdapterV06
	adapter.configure(owner)
	var wrong_effect := _intent("organization.starport_clearinghouse.rank_1", 0)
	wrong_effect["effect_kind"] = "interaction"
	_expect(str(adapter.prepare_effect(wrong_effect).get("reason_code", "")) == "organization_effect_kind_invalid", "non-organization effect fails before consumption")
	var rival_target := _intent("organization.starport_clearinghouse.rank_1", 0)
	(rival_target["target_context"] as Dictionary)["target_actor_id"] = "ai.rival"
	_expect(str(adapter.prepare_effect(rival_target).get("reason_code", "")) == "organization_target_must_be_self", "organization card cannot target another player")
	var forged_payload := _intent("organization.quantum_agenda_network.rank_1", 0)
	(forged_payload["effect_payload"] as Dictionary)["ordinary_submission_bonus"] = 2
	_expect(str(adapter.prepare_effect(forged_payload).get("reason_code", "")) == "organization_action_bandwidth_terms_invalid", "payload cannot forge a submission bonus above the authored ladder")
	var no_window := _intent("organization.deep_space_archive.rank_1", 0)
	(no_window["target_context"] as Dictionary).erase("window_sequence")
	_expect(str(adapter.prepare_effect(no_window).get("reason_code", "")) == "organization_window_sequence_required", "next-window activation requires an authoritative window sequence")


func _intent(card_id: String, window_sequence: int) -> Dictionary:
	_sequence += 1
	var card := _catalog.card_snapshot(card_id)
	var machine: Dictionary = card.get("machine", {}) if card.get("machine", {}) is Dictionary else {}
	var transaction_id := "organization-adapter-%d" % _sequence
	return {
		"transaction_id": transaction_id,
		"actor_id": ACTOR,
		"card_id": card_id,
		"card_instance_id": "%s-instance" % transaction_id,
		"effect_kind": str(machine.get("effect_kind", "")),
		"target_hash": "target-%d" % _sequence,
		"payload_hash": "payload-%d" % _sequence,
		"intent_hash": "intent-%d" % _sequence,
		"target_context": {"target_kind": "self_organization_slot", "target_actor_id": ACTOR, "window_sequence": window_sequence},
		"effect_payload": (machine.get("effect_payload", {}) as Dictionary).duplicate(true),
	}


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
		print("FAIL: %s" % message)


func _finish() -> void:
	for owner in _created_owners:
		if is_instance_valid(owner):
			owner.free()
	_created_owners.clear()
	_catalog = null
	if _failures.is_empty():
		print("ORGANIZATION_CARD_RUNTIME_V06_TEST|status=PASS|checks=%d|failures=0" % _checks)
		quit(0)
		return
	print("ORGANIZATION_CARD_RUNTIME_V06_TEST|status=FAIL|checks=%d|failures=%d|details=%s" % [_checks, _failures.size(), JSON.stringify(_failures)])
	quit(1)
