extends SceneTree

const MANA_SCRIPT := preload("res://scripts/runtime/player_mana_runtime_controller.gd")
const PROFILE_SNAPSHOT := {
	"identity": {"ruleset_id": "v0.6", "currency_scale": 100},
	"mana": {"per_color_maximum": 100, "gdp_per_minute_divisor": 100},
	"capabilities": {
		"six_color_mana_enabled": true,
		"industry_capacity_reservations_enabled": false,
	},
}
const SNAPSHOT_KEYS := [
	"schema_version",
	"transaction_id",
	"player_index",
	"asset_cost",
	"asset_debit",
	"debit_milliunits",
	"state",
	"fingerprint",
]
const SETTLEMENT_SNAPSHOT_KEYS := [
	"found",
	"reason_code",
	"state_id",
	"outcome_id",
	"reservation",
	"terminal_receipt",
]
const TERMINAL_RECEIPT_KEYS := [
	"committed",
	"authorized",
	"settled",
	"duplicate",
	"transaction_id",
	"player_index",
	"outcome",
	"asset_debit",
	"debit_milliunits",
	"reservation_binding",
	"reservation_reserved_at",
	"settled_at",
	"reason",
	"revision",
]

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var mana = _owner_with_balances()
	var plan = mana.plan_reservation({
		"transaction_id": "facility-binding-pending",
		"player_index": 0,
		"asset_cost": {"generic": 2},
		"generic_asset_allocation": {"energy": 2},
	})
	_expect(bool(plan.get("accepted", false)), "fixture creates an accepted reservation plan")
	var committed = mana.commit_reservation(plan)
	_expect(bool(committed.get("committed", false)) and not bool(committed.get("duplicate", true)), "first reservation commit succeeds once")

	var snapshot = mana.reservation_snapshot("facility-binding-pending")
	_expect(_same_string_set(snapshot.keys(), SNAPSHOT_KEYS), "pending reservation snapshot has the closed v1 shape")
	_expect(_pure_data(snapshot) and str(snapshot.get("state", "")) == "reserved", "pending reservation snapshot is detached pure data")
	_expect(str(snapshot.get("fingerprint", "")).length() == 64 and str(snapshot.get("fingerprint", "")) == mana.reservation_fingerprint(snapshot), "reservation fingerprint deterministically binds the closed snapshot")
	_expect(str(snapshot.get("transaction_id", "")) == "facility-binding-pending" and int(snapshot.get("player_index", -1)) == 0, "reservation snapshot binds transaction and actor")
	_expect((snapshot.get("asset_cost") as Dictionary) == plan.get("asset_cost") and (snapshot.get("asset_debit") as Dictionary) == plan.get("asset_debit") and (snapshot.get("debit_milliunits") as Dictionary) == plan.get("debit_milliunits"), "reservation snapshot binds cost debit and milliunits")
	var pending_settlement: Dictionary = mana.reservation_settlement_snapshot("facility-binding-pending")
	var pending_binding := (pending_settlement.get("reservation") as Dictionary).duplicate(true)
	_assert_settlement_snapshot(mana, pending_settlement, "reserved", "pending", pending_binding, false, "pending")
	var caller_mutated_pending: Dictionary = pending_settlement.duplicate(true)
	(caller_mutated_pending.get("reservation") as Dictionary)["transaction_id"] = "same-id-caller-mutation"
	_expect(mana.reservation_settlement_snapshot("facility-binding-pending") == pending_settlement, "caller mutation cannot alter the authoritative pending settlement snapshot")
	(snapshot.get("asset_cost") as Dictionary)["generic"] = 99
	_expect(int((mana.reservation_snapshot("facility-binding-pending").get("asset_cost") as Dictionary).get("generic", -1)) == 2, "caller mutation cannot alter the authoritative reservation")
	_expect(mana.reservation_snapshot("missing-reservation").is_empty() and mana.reservation_snapshot(" facility-binding-pending").is_empty(), "unknown or noncanonical transaction IDs do not expose reservations")

	var before_duplicate = mana.to_save_data()
	var duplicate = mana.commit_reservation(plan.duplicate(true))
	_expect(bool(duplicate.get("committed", false)) and bool(duplicate.get("duplicate", false)), "an identical pending plan replays idempotently")
	_expect(_same_data(before_duplicate, mana.to_save_data()), "identical pending replay mutates no save-owned state")
	_expect_collision_without_mutation(mana, _with(plan, "player_index", 1), "same ID with a different actor collides")
	var different_cost = plan.duplicate(true)
	(different_cost.get("asset_cost") as Dictionary)["generic"] = 0
	(different_cost.get("asset_cost") as Dictionary)["energy"] = 2
	_expect_collision_without_mutation(mana, different_cost, "same ID with a different cost collides")
	var different_debit = plan.duplicate(true)
	(different_debit.get("asset_debit") as Dictionary)["energy"] = 0
	(different_debit.get("asset_debit") as Dictionary)["technology"] = 2
	(different_debit.get("debit_milliunits") as Dictionary)["energy"] = 0
	(different_debit.get("debit_milliunits") as Dictionary)["technology"] = 2000
	_expect_collision_without_mutation(mana, different_debit, "same ID with a different debit collides")
	_expect(mana.reservation_settlement_snapshot("facility-binding-pending") == pending_settlement, "same-ID pending mutations fail closed without changing the settlement snapshot")

	var checkpoint = mana.to_save_data()
	var fingerprint_before_restore := str(mana.reservation_snapshot("facility-binding-pending").get("fingerprint", ""))
	var restored = _new_owner()
	var restore_receipt = restored.apply_save_data(checkpoint)
	_expect(bool(restore_receipt.get("applied", false)), "reservation checkpoint restores through the existing save owner")
	var restored_snapshot = restored.reservation_snapshot("facility-binding-pending")
	_expect(str(restored_snapshot.get("fingerprint", "")) == fingerprint_before_restore and restored.reservation_fingerprint(restored_snapshot) == fingerprint_before_restore, "reservation fingerprint is stable across save and cold restore")
	var restored_pending_settlement: Dictionary = restored.reservation_settlement_snapshot("facility-binding-pending")
	_expect(restored_pending_settlement == pending_settlement, "pending settlement snapshot has exact cold-restore parity")
	_assert_settlement_snapshot(restored, restored_pending_settlement, "reserved", "pending", pending_binding, false, "restored pending")
	_expect(bool(restored.commit_reservation(plan.duplicate(true)).get("duplicate", false)), "restored pending reservation preserves idempotent replay")

	var consumed = restored.consume_reservation("facility-binding-pending", {"resolved": true})
	_expect(str(consumed.get("outcome", "")) == "consumed" and restored.reservation_snapshot("facility-binding-pending").is_empty(), "consumed reservations leave no pending snapshot")
	var consumed_settlement: Dictionary = restored.reservation_settlement_snapshot("facility-binding-pending")
	_assert_settlement_snapshot(restored, consumed_settlement, "terminal", "consumed", pending_binding, true, "consumed")
	var caller_mutated_consumed: Dictionary = consumed_settlement.duplicate(true)
	(caller_mutated_consumed.get("terminal_receipt") as Dictionary)["outcome"] = "released"
	_expect(restored.reservation_settlement_snapshot("facility-binding-pending") == consumed_settlement, "caller mutation cannot alter the authoritative consumed settlement snapshot")
	var consumed_checkpoint = restored.to_save_data()
	var consumed_restored = _new_owner()
	_expect(bool(consumed_restored.apply_save_data(consumed_checkpoint).get("applied", false)), "consumed settlement checkpoint restores")
	_expect(consumed_restored.reservation_settlement_snapshot("facility-binding-pending") == consumed_settlement, "consumed settlement snapshot has exact cold-restore parity")
	var consumed_replay = restored.commit_reservation(plan.duplicate(true))
	_expect(bool(consumed_replay.get("duplicate", false)) and str(consumed_replay.get("outcome", "")) == "consumed", "matching plan replays a consumed terminal receipt")
	_expect(_same_data(consumed_checkpoint, restored.to_save_data()), "matching consumed replay mutates no save-owned state")
	_expect_collision_without_mutation(restored, different_cost, "different plan cannot impersonate a consumed terminal receipt")

	var release_plan = restored.plan_reservation({
		"transaction_id": "facility-binding-released",
		"player_index": 1,
		"asset_cost": {"shipping": 1},
	})
	_expect(bool(release_plan.get("accepted", false)) and bool(restored.commit_reservation(release_plan).get("committed", false)), "release fixture commits")
	var release_binding: Dictionary = restored.reservation_snapshot("facility-binding-released")
	var released = restored.release_reservation("facility-binding-released", "facility_resolution_failed")
	_expect(str(released.get("outcome", "")) == "released", "release creates a terminal receipt")
	var released_settlement: Dictionary = restored.reservation_settlement_snapshot("facility-binding-released")
	_assert_settlement_snapshot(restored, released_settlement, "terminal", "released", release_binding, true, "released")
	var released_checkpoint = restored.to_save_data()
	var released_replay = restored.commit_reservation(release_plan.duplicate(true))
	_expect(bool(released_replay.get("duplicate", false)) and str(released_replay.get("outcome", "")) == "released", "matching plan replays a released terminal receipt")
	var wrong_release_actor := _with(release_plan, "player_index", 0)
	_expect_collision_without_mutation(restored, wrong_release_actor, "different plan cannot impersonate a released terminal receipt")
	_expect(_same_data(released_checkpoint, restored.to_save_data()), "released replay and collision preserve save-owned state")
	var released_fingerprint := str((released.get("reservation_binding") as Dictionary).get("fingerprint", ""))
	_expect_rollback_rejected_without_mutation(restored, "facility-binding-released", released_fingerprint, "facility_resolution_failed", "asset_reservation_not_consumed", "released terminal receipt cannot be rolled back as consumed")

	var rollback_plan = restored.plan_reservation({
		"transaction_id": "facility-binding-consumed-rollback",
		"player_index": 0,
		"asset_cost": {"industry": 3},
	})
	_expect(bool(rollback_plan.get("accepted", false)) and bool(restored.commit_reservation(rollback_plan).get("committed", false)), "rollback fixture commits")
	var rollback_binding = restored.reservation_snapshot("facility-binding-consumed-rollback")
	var rollback_fingerprint := str(rollback_binding.get("fingerprint", ""))
	var pool_before_consume := int((((restored.to_save_data().get("pools_by_player") as Dictionary).get("0") as Dictionary).get("industry", -1)))
	var rollback_consumed = restored.consume_reservation("facility-binding-consumed-rollback", {"resolved": true})
	var pool_after_consume := int((((restored.to_save_data().get("pools_by_player") as Dictionary).get("0") as Dictionary).get("industry", -1)))
	_expect(str(rollback_consumed.get("outcome", "")) == "consumed" and pool_after_consume == pool_before_consume - 3000, "consume debits the rollback fixture exactly once")
	_expect_rollback_rejected_without_mutation(restored, "facility-binding-consumed-rollback", "0".repeat(64), "facility_effect_compensation", "asset_reservation_binding_collision", "rollback rejects the wrong reservation fingerprint")
	var rollback_result = restored.rollback_consumed_reservation(
		"facility-binding-consumed-rollback",
		rollback_fingerprint,
		"facility_effect_compensation"
	)
	var after_rollback_save = restored.to_save_data()
	var pool_after_rollback := int((((after_rollback_save.get("pools_by_player") as Dictionary).get("0") as Dictionary).get("industry", -1)))
	_expect(bool(rollback_result.get("rolled_back", false)) and not bool(rollback_result.get("duplicate", true)), "matching consumed binding rolls back once")
	_expect(pool_after_rollback == pool_before_consume, "consumed rollback restores the exact debit to the original player pool")
	_expect(not (after_rollback_save.get("terminal_receipts") as Dictionary).has("facility-binding-consumed-rollback") and (after_rollback_save.get("reservations") as Dictionary).has("facility-binding-consumed-rollback"), "rollback removes the consumed terminal and restores the same pending reservation")
	_expect(str(restored.reservation_snapshot("facility-binding-consumed-rollback").get("fingerprint", "")) == rollback_fingerprint, "restored pending reservation preserves its original binding fingerprint")
	var rollback_replay = restored.rollback_consumed_reservation("facility-binding-consumed-rollback", rollback_fingerprint, "facility_effect_compensation")
	_expect(bool(rollback_replay.get("rolled_back", false)) and bool(rollback_replay.get("duplicate", false)), "same rollback content is idempotent")
	_expect(_same_data(after_rollback_save, restored.to_save_data()), "idempotent rollback does not credit assets twice")
	_expect_rollback_rejected_without_mutation(restored, "facility-binding-consumed-rollback", rollback_fingerprint, "different_compensation_reason", "asset_reservation_rollback_collision", "same rollback binding with different content collides")
	var ordinary_pending_plan = restored.plan_reservation({
		"transaction_id": "facility-binding-never-consumed",
		"player_index": 1,
		"asset_cost": {"commerce": 1},
	})
	_expect(bool(ordinary_pending_plan.get("accepted", false)) and bool(restored.commit_reservation(ordinary_pending_plan).get("committed", false)), "ordinary pending fixture commits")
	var ordinary_pending_fingerprint := str(restored.reservation_snapshot("facility-binding-never-consumed").get("fingerprint", ""))
	_expect_rollback_rejected_without_mutation(restored, "facility-binding-never-consumed", ordinary_pending_fingerprint, "facility_effect_compensation", "asset_reservation_not_consumed", "ordinary pending reservation cannot impersonate rollback replay")
	var rollback_checkpoint = restored.to_save_data()
	var rollback_restored = _new_owner()
	_expect(bool(rollback_restored.apply_save_data(rollback_checkpoint).get("applied", false)), "rolled-back pending reservation survives cold restore")
	var restored_rollback_replay = rollback_restored.rollback_consumed_reservation("facility-binding-consumed-rollback", rollback_fingerprint, "facility_effect_compensation")
	_expect(bool(restored_rollback_replay.get("rolled_back", false)) and bool(restored_rollback_replay.get("duplicate", false)), "rollback exact-once marker survives cold restore")
	_expect(_same_data(rollback_checkpoint, rollback_restored.to_save_data()), "cold-restored rollback replay remains mutation-free")

	var terminal_restored = _new_owner()
	_expect(bool(terminal_restored.apply_save_data(released_checkpoint).get("applied", false)), "terminal bindings survive cold restore")
	_expect(terminal_restored.reservation_settlement_snapshot("facility-binding-pending") == consumed_settlement, "consumed settlement remains identical after a later terminal checkpoint restore")
	_expect(terminal_restored.reservation_settlement_snapshot("facility-binding-released") == released_settlement, "released settlement snapshot has exact cold-restore parity")
	_expect(bool(terminal_restored.commit_reservation(plan.duplicate(true)).get("duplicate", false)), "restored consumed terminal binding accepts only its original plan")
	_expect_collision_without_mutation(terminal_restored, different_debit, "restored consumed terminal binding rejects changed debit")
	_expect(bool(terminal_restored.commit_reservation(release_plan.duplicate(true)).get("duplicate", false)), "restored released terminal binding accepts only its original plan")

	var legacy_save = released_checkpoint.duplicate(true)
	for receipt_variant in (legacy_save.get("terminal_receipts") as Dictionary).values():
		if receipt_variant is Dictionary:
			(receipt_variant as Dictionary).erase("reservation_binding")
	_expect(bool(restored.preflight_save_data(legacy_save).get("accepted", false)), "legacy terminal receipts without a binding remain save-preflight compatible")
	var legacy_owner = _new_owner()
	_expect(bool(legacy_owner.apply_save_data(legacy_save).get("applied", false)), "legacy terminal receipts remain restorable")
	_expect_collision_without_mutation(legacy_owner, plan.duplicate(true), "legacy terminal replay fails closed when no full binding can be proven")

	var tampered_terminal = released_checkpoint.duplicate(true)
	var terminal_receipts := tampered_terminal.get("terminal_receipts") as Dictionary
	var tampered_receipt := terminal_receipts.get("facility-binding-pending") as Dictionary
	var tampered_binding := tampered_receipt.get("reservation_binding") as Dictionary
	(tampered_binding.get("asset_cost") as Dictionary)["generic"] = 3
	_expect(not bool(restored.preflight_save_data(tampered_terminal).get("accepted", true)), "save preflight rejects a terminal binding with a stale fingerprint")
	var hostile_restore = _new_owner()
	var hostile_before = hostile_restore.to_save_data()
	var hostile_receipt = hostile_restore.apply_save_data(tampered_terminal)
	var hostile_settlement: Dictionary = hostile_restore.reservation_settlement_snapshot("facility-binding-pending")
	_expect(not bool(hostile_receipt.get("applied", true)) and _same_data(hostile_before, hostile_restore.to_save_data()), "same-ID terminal mutation fails closed with zero save-owner mutation")
	_expect(_same_string_set(hostile_settlement.keys(), SETTLEMENT_SNAPSHOT_KEYS) and _pure_data(hostile_settlement) and not bool(hostile_settlement.get("found", true)) and str(hostile_settlement.get("state_id", "")) == "missing", "same-ID terminal mutation exposes only a closed missing settlement snapshot")

	_expect(not restored.has_method("reservation_snapshots") and not restored.has_method("list_reservations") and not restored.has_method("all_reservation_snapshots"), "PlayerMana exposes no reservation enumeration API")
	var public_snapshot = restored.public_snapshot()
	_expect(not public_snapshot.has("reservation") and not public_snapshot.has("reservations") and not public_snapshot.has("terminal_receipts"), "public PlayerMana projection exposes no reservation body")

	mana.queue_free()
	restored.queue_free()
	terminal_restored.queue_free()
	legacy_owner.queue_free()
	rollback_restored.queue_free()
	consumed_restored.queue_free()
	hostile_restore.queue_free()
	await process_frame
	_finish()


func _owner_with_balances():
	var owner = _new_owner()
	owner.reset_state(2)
	var saved = owner.to_save_data()
	saved["pools_by_player"] = {
		"0": _asset_row(20),
		"1": _asset_row(20),
	}
	saved["recovery_remainders_by_player"] = {
		"0": _asset_row(0),
		"1": _asset_row(0),
	}
	_expect(bool(owner.apply_save_data(saved).get("applied", false)), "fixture seeds two authoritative asset owners")
	return owner


func _new_owner():
	var owner = MANA_SCRIPT.new()
	root.add_child(owner)
	_expect(bool(owner.configure(PROFILE_SNAPSHOT).get("configured", false)), "PlayerMana configures from v0.6")
	return owner


func _asset_row(asset_count: int) -> Dictionary:
	var row := {}
	for asset_id_variant in MANA_SCRIPT.ASSET_IDS:
		row[str(asset_id_variant)] = asset_count * MANA_SCRIPT.MILLIASSET_SCALE
	return row


func _with(source: Dictionary, key: String, value: Variant) -> Dictionary:
	var result := source.duplicate(true)
	result[key] = value
	return result


func _expect_collision_without_mutation(mana: Variant, plan: Dictionary, message: String) -> void:
	var before = mana.to_save_data()
	var result = mana.commit_reservation(plan)
	_expect(not bool(result.get("committed", true)) and not bool(result.get("authorized", true)) and str(result.get("reason", "")) == "asset_reservation_binding_collision", message)
	_expect(_same_data(before, mana.to_save_data()), "%s with zero save-owned mutation" % message)


func _expect_rollback_rejected_without_mutation(
	mana: Variant,
	transaction_id: String,
	expected_fingerprint: String,
	reason: String,
	expected_reason: String,
	message: String
) -> void:
	var before = mana.to_save_data()
	var result = mana.rollback_consumed_reservation(transaction_id, expected_fingerprint, reason)
	_expect(not bool(result.get("rolled_back", true)) and str(result.get("reason", "")) == expected_reason, message)
	_expect(_same_data(before, mana.to_save_data()), "%s with zero save-owned mutation" % message)


func _assert_settlement_snapshot(
	mana: Variant,
	snapshot: Dictionary,
	expected_state_id: String,
	expected_outcome_id: String,
	expected_binding: Dictionary,
	expect_terminal: bool,
	label: String
) -> void:
	_expect(_same_string_set(snapshot.keys(), SETTLEMENT_SNAPSHOT_KEYS), "%s settlement snapshot has the closed exact-key shape" % label)
	_expect(_pure_data(snapshot), "%s settlement snapshot is detached pure data" % label)
	_expect(bool(snapshot.get("found", false)) and str(snapshot.get("state_id", "")) == expected_state_id and str(snapshot.get("outcome_id", "")) == expected_outcome_id, "%s settlement snapshot exposes the expected state and outcome" % label)
	var binding := snapshot.get("reservation", {}) as Dictionary
	var binding_fingerprint := str(binding.get("fingerprint", ""))
	_expect(_same_string_set(binding.keys(), SNAPSHOT_KEYS) and binding == expected_binding, "%s settlement snapshot carries the exact reservation binding" % label)
	_expect(binding_fingerprint.length() == 64 and mana.reservation_fingerprint(binding) == binding_fingerprint, "%s settlement snapshot validates its reservation fingerprint" % label)
	var terminal := snapshot.get("terminal_receipt", {}) as Dictionary
	if not expect_terminal:
		_expect(terminal.is_empty(), "%s settlement snapshot has no premature terminal receipt" % label)
		return
	_expect(_same_string_set(terminal.keys(), TERMINAL_RECEIPT_KEYS) and _pure_data(terminal), "%s settlement terminal receipt has the closed pure-data shape" % label)
	_expect(str(terminal.get("transaction_id", "")) == str(binding.get("transaction_id", "")) and int(terminal.get("player_index", -1)) == int(binding.get("player_index", -2)) and str(terminal.get("outcome", "")) == expected_outcome_id, "%s terminal receipt is bound to the same transaction, player, and outcome" % label)
	_expect((terminal.get("reservation_binding", {}) as Dictionary) == binding, "%s terminal receipt embeds the identical fingerprint-bound reservation" % label)


func _same_string_set(left: Array, right: Array) -> bool:
	var normalized_left: Array[String] = []
	var normalized_right: Array[String] = []
	for value in left:
		normalized_left.append(str(value))
	for value in right:
		normalized_right.append(str(value))
	normalized_left.sort()
	normalized_right.sort()
	return normalized_left == normalized_right


func _same_data(left: Variant, right: Variant) -> bool:
	return JSON.stringify(left) == JSON.stringify(right)


func _pure_data(value: Variant) -> bool:
	if value is Callable or typeof(value) == TYPE_OBJECT:
		return false
	if value is Dictionary:
		for key_variant in value.keys():
			if not _pure_data(key_variant) or not _pure_data(value[key_variant]):
				return false
	elif value is Array:
		for item_variant in value:
			if not _pure_data(item_variant):
				return false
	return true


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
		push_error(message)


func _finish() -> void:
	print("PLAYER_MANA_RESERVATION_BINDING_V06_TEST|status=%s|checks=%d|failures=%d" % ["PASS" if _failures.is_empty() else "FAIL", _checks, _failures.size()])
	quit(0 if _failures.is_empty() else 1)
