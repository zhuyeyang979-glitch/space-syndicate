extends SceneTree

const CONTROLLER_SCRIPT := preload("res://scripts/runtime/player_organization_runtime_controller.gd")
const CATALOG_PATH := "res://resources/cards/runtime/card_runtime_catalog_v06.tres"
const ACTOR := "human.alpha"
const RIVAL := "ai.beta"

var _checks := 0
var _failures: Array[String] = []
var _transaction_sequence := 0
var _catalog: CardRuntimeCatalogV06Resource
var _created_owners: Array[Node] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_catalog = load(CATALOG_PATH) as CardRuntimeCatalogV06Resource
	_expect(_catalog != null and bool(_catalog.reload().get("valid", false)), "authoritative v0.6 catalog loads")
	if _catalog == null:
		_finish()
		return
	_test_atomic_lifecycle_and_activation()
	_test_upgrade_slot_limit_and_replay()
	_test_private_capabilities_and_forgery_resistance()
	_test_save_load_with_inflight_transaction()
	_finish()


func _test_atomic_lifecycle_and_activation() -> void:
	var owner := _new_owner()
	var intent := _intent("organization.starport_clearinghouse.rank_1", 4)
	var prepared: Dictionary = owner.prepare_organization_upgrade(intent)
	_expect(bool(prepared.get("prepared", false)) and not bool(prepared.get("committed", true)), "prepare is accepted without installing the organization")
	_expect(not bool(owner.checkpoint_status().get("can_checkpoint", true)), "prepared lifecycle blocks checkpoints")
	_expect(int(owner.asset_recovery_terms(ACTOR, 5).get("asset_conversion_bonus_bp", -1)) == 0, "prepared organization has no gameplay effect")
	var committed: Dictionary = owner.commit_organization_upgrade(prepared)
	_expect(bool(committed.get("committed", false)) and bool(committed.get("rollback_open", false)), "commit installs one rollback-open organization upgrade")
	_expect(int(owner.asset_recovery_terms(ACTOR, 4).get("asset_conversion_bonus_bp", -1)) == 0, "organization does not activate in the submitting window")
	var active_terms: Dictionary = owner.asset_recovery_terms(ACTOR, 5)
	_expect(int(active_terms.get("asset_conversion_bonus_bp", -1)) == 500 and int(active_terms.get("asset_conversion_bonus_cap_milli_per_second", -1)) == 50, "asset conversion activates at the next window with the authored cap")
	var rolled_back: Dictionary = owner.rollback_organization_upgrade(committed)
	_expect(bool(rolled_back.get("rolled_back", false)) and int(owner.asset_recovery_terms(ACTOR, 5).get("asset_conversion_bonus_bp", -1)) == 0, "rollback restores the exact modifier content preimage")
	_expect(owner.rollback_organization_upgrade(committed) == rolled_back, "rollback replay is exact once")

	var committed_again := _install(owner, "organization.starport_clearinghouse.rank_1", 7, false)
	var finalized: Dictionary = owner.finalize_organization_upgrade(committed_again)
	_expect(bool(finalized.get("finalized", false)) and not bool(finalized.get("rollback_open", true)), "finalize closes the rollback window")
	_expect(owner.finalize_organization_upgrade(committed_again) == finalized, "finalize replay returns the same terminal receipt")
	_expect(not bool(owner.rollback_organization_upgrade(committed_again).get("rolled_back", true)), "finalized organization cannot be rolled back")


func _test_upgrade_slot_limit_and_replay() -> void:
	var owner := _new_owner()
	var first := _install(owner, "organization.starport_clearinghouse.rank_1", 0)
	var duplicate_prepare: Dictionary = owner.prepare_organization_upgrade(_intent("organization.starport_clearinghouse.rank_1", 1))
	_expect(not bool(duplicate_prepare.get("prepared", true)) and str(duplicate_prepare.get("reason_code", "")) == "organization_upgrade_must_be_higher_rank", "same-rank install fails before card consumption")
	var rank_two_intent := _intent("organization.starport_clearinghouse.rank_2", 1)
	var rank_two_prepared: Dictionary = owner.prepare_organization_upgrade(rank_two_intent)
	var rank_two_committed: Dictionary = owner.commit_organization_upgrade(rank_two_prepared)
	_expect(int(owner.asset_recovery_terms(ACTOR, 2).get("asset_conversion_bonus_bp", -1)) == 1000, "higher rank replaces the family in its existing slot")
	owner.rollback_organization_upgrade(rank_two_committed)
	_expect(int(owner.asset_recovery_terms(ACTOR, 2).get("asset_conversion_bonus_bp", -1)) == 500, "upgrade rollback restores the previous lower-rank organization")

	_install(owner, "organization.quantum_agenda_network.rank_1", 2)
	_install(owner, "organization.deep_space_archive.rank_1", 2)
	var full: Dictionary = owner.prepare_organization_upgrade(_intent("organization.monster_liaison_charter.rank_1", 3))
	_expect(not bool(full.get("prepared", true)) and str(full.get("reason_code", "")) == "organization_slots_full", "a fourth family fails closed when all three organization slots are occupied")
	var private: Dictionary = owner.private_snapshot(ACTOR, 4)
	var installed := 0
	for slot_variant in private.get("slots", []) as Array:
		if slot_variant is Dictionary and not (slot_variant as Dictionary).is_empty():
			installed += 1
	_expect(installed == 3, "exactly three organization families occupy the three slots")

	var replay_intent := _intent("organization.starport_clearinghouse.rank_3", 4)
	var prepared: Dictionary = owner.prepare_organization_upgrade(replay_intent)
	# Existing family can still upgrade while all slots are occupied.
	_expect(bool(prepared.get("prepared", false)), "a higher-rank replacement remains legal with three occupied slots")
	var committed: Dictionary = owner.commit_organization_upgrade(prepared)
	var finalized: Dictionary = owner.finalize_organization_upgrade(committed)
	_expect(owner.prepare_organization_upgrade(replay_intent) == finalized, "same transaction replays its finalized receipt without a second install")
	_expect(bool(first.get("finalized", false)), "initial helper install was finalized")


func _test_private_capabilities_and_forgery_resistance() -> void:
	var action_owner := _new_owner()
	_install(action_owner, "organization.quantum_agenda_network.rank_4", 0)
	var first_active: Dictionary = action_owner.card_window_submission_capability(ACTOR, 1)
	_expect(int(first_active.get("effective_submission_limit", -1)) == 2 and int(first_active.get("extra_submission_asset_surcharge", -1)) == 1, "rank IV bandwidth grants one extra ordinary submission at surcharge one")
	var third_active: Dictionary = action_owner.card_window_submission_capability(ACTOR, 3)
	_expect(int(third_active.get("effective_submission_limit", -1)) == 3 and bool(third_active.get("burst_eligible", false)) and int(third_active.get("burst_submission_surcharge", -1)) == 4, "rank IV every-third-window burst grants the capped third submission")
	_expect(bool(action_owner.validate_card_window_submission_capability(third_active).get("valid", false)), "owner validates its exact private window capability")
	var forged := third_active.duplicate(true)
	forged["effective_submission_limit"] = 2
	_expect(not bool(action_owner.validate_card_window_submission_capability(forged).get("valid", true)), "changing an effective limit invalidates the signed capability")
	var cross_actor := third_active.duplicate(true)
	cross_actor["actor_id"] = RIVAL
	_expect(not bool(action_owner.validate_card_window_submission_capability(cross_actor).get("valid", true)), "a private capability is bound to one actor")
	var cross_window := third_active.duplicate(true)
	cross_window["window_sequence"] = 4
	_expect(not bool(action_owner.validate_card_window_submission_capability(cross_window).get("valid", true)), "a private capability is bound to one window snapshot")

	var hand_owner := _new_owner()
	_install(hand_owner, "organization.deep_space_archive.rank_4", 0)
	_expect(int(hand_owner.hand_limit_terms(ACTOR, 0).get("ordinary_hand_limit", -1)) == 5 and int(hand_owner.hand_limit_terms(ACTOR, 1).get("ordinary_hand_limit", -1)) == 9, "rank IV hand capacity changes only the next-window ordinary limit from five to nine")

	var monster_owner := _new_owner()
	_install(monster_owner, "organization.monster_liaison_charter.rank_4", 0)
	var monster_caps: Dictionary = monster_owner.monster_binding_caps(ACTOR, 1)
	_expect(int(monster_caps.get("controlled_monster_count_limit", -1)) == 2 and int(monster_caps.get("primary_monster_rank_limit", -1)) == 4 and int(monster_caps.get("secondary_monster_rank_limit", -1)) == 4, "rank IV monster liaison exposes two rank-IV binding caps without controlling movement")
	_expect(bool(monster_owner.monster_binding_caps_for_target_owner(ACTOR, 1).get("foreign_upgrade_does_not_transfer_control", false)), "foreign monster upgrades query target-owner caps without transferring control")

	var military_owner := _new_owner()
	_install(military_owner, "organization.stellar_command_directorate.rank_3", 0)
	var military_caps: Dictionary = military_owner.military_command_caps(ACTOR, 1)
	_expect(int(military_caps.get("controlled_military_count_limit", -1)) == 2 and int(military_caps.get("primary_military_rank_limit", -1)) == 4 and int(military_caps.get("secondary_military_rank_limit", -1)) == 2, "rank III command directorate exposes the authored primary and secondary military caps")


func _test_save_load_with_inflight_transaction() -> void:
	var owner := _new_owner()
	var prepared: Dictionary = owner.prepare_organization_upgrade(_intent("organization.deep_space_archive.rank_2", 9))
	var committed: Dictionary = owner.commit_organization_upgrade(prepared)
	_expect(not bool(owner.checkpoint_status().get("can_checkpoint", true)), "committed rollback-open lifecycle blocks normal checkpoints")
	var save: Dictionary = owner.to_save_data()
	var restored = CONTROLLER_SCRIPT.new()
	_created_owners.append(restored)
	var applied: Dictionary = restored.apply_save_data(save)
	_expect(bool(applied.get("applied", false)) and not bool(restored.checkpoint_status().get("can_checkpoint", true)), "save/load preserves an inflight committed lifecycle")
	var restored_terms: Dictionary = restored.hand_limit_terms(ACTOR, 10)
	_expect(int(restored_terms.get("ordinary_hand_limit", -1)) == 7, "save/load preserves the pending organization's next-window capability")
	var restored_rollback: Dictionary = restored.rollback_organization_upgrade(committed)
	_expect(bool(restored_rollback.get("rolled_back", false)) and int(restored.hand_limit_terms(ACTOR, 10).get("ordinary_hand_limit", -1)) == 5, "loaded inflight lifecycle remains exactly rollbackable")
	_expect(bool(restored.checkpoint_status().get("can_checkpoint", false)), "rolled-back loaded lifecycle becomes checkpoint safe")
	var roundtrip := restored.to_save_data()
	var second = CONTROLLER_SCRIPT.new()
	_created_owners.append(second)
	_expect(bool(second.apply_save_data(roundtrip).get("applied", false)), "terminal organization journal round-trips through save data")


func _new_owner() -> PlayerOrganizationRuntimeController:
	var owner := CONTROLLER_SCRIPT.new() as PlayerOrganizationRuntimeController
	_created_owners.append(owner)
	var configured: Dictionary = owner.configure([ACTOR, RIVAL])
	_expect(bool(configured.get("configured", false)), "organization owner configures two unique actors")
	return owner


func _install(owner: PlayerOrganizationRuntimeController, card_id: String, window_sequence: int, finalize := true) -> Dictionary:
	var prepared: Dictionary = owner.prepare_organization_upgrade(_intent(card_id, window_sequence))
	if not bool(prepared.get("prepared", false)):
		return prepared
	var committed: Dictionary = owner.commit_organization_upgrade(prepared)
	return owner.finalize_organization_upgrade(committed) if finalize and bool(committed.get("committed", false)) else committed


func _intent(card_id: String, window_sequence: int, actor_id := ACTOR) -> Dictionary:
	_transaction_sequence += 1
	var card := _catalog.card_snapshot(card_id)
	var machine: Dictionary = card.get("machine", {}) if card.get("machine", {}) is Dictionary else {}
	var payload: Dictionary = machine.get("effect_payload", {}) if machine.get("effect_payload", {}) is Dictionary else {}
	var transaction_id := "organization-test-%d" % _transaction_sequence
	return {
		"transaction_id": transaction_id,
		"actor_id": actor_id,
		"card_id": card_id,
		"card_instance_id": "%s-instance" % transaction_id,
		"effect_kind": str(machine.get("effect_kind", "")),
		"target_hash": "target-%d" % _transaction_sequence,
		"payload_hash": "payload-%d" % _transaction_sequence,
		"intent_hash": "intent-%d" % _transaction_sequence,
		"target_context": {"target_kind": "self_organization_slot", "target_actor_id": actor_id, "window_sequence": window_sequence},
		"effect_payload": payload.duplicate(true),
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
		print("PLAYER_ORGANIZATION_RUNTIME_CONTROLLER_V06_TEST|status=PASS|checks=%d|failures=0" % _checks)
		quit(0)
		return
	print("PLAYER_ORGANIZATION_RUNTIME_CONTROLLER_V06_TEST|status=FAIL|checks=%d|failures=%d|details=%s" % [_checks, _failures.size(), JSON.stringify(_failures)])
	quit(1)
