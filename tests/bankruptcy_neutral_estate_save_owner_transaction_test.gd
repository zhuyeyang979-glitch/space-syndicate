extends SceneTree

const ESTATE_SCENE := preload("res://scenes/runtime/BankruptcyNeutralEstateRuntimeController.tscn")
const COORDINATOR_SCENE := preload("res://scenes/runtime/GameRuntimeCoordinator.tscn")

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var estate := ESTATE_SCENE.instantiate() as BankruptcyNeutralEstateRuntimeController
	root.add_child(estate)
	var checkpoint := _checkpoint()
	var applied: Dictionary = estate.apply_save_data(checkpoint)
	_expect(bool(applied.get("applied", false)), "bankruptcy estate accepts a strict authoritative checkpoint")
	var normalized := estate.to_save_data()
	_expect(_pure_data(normalized) and int(normalized.get("state_version", 0)) == 1, "bankruptcy estate checkpoint is pure versioned data")
	_expect((normalized.get("journal", {}) as Dictionary).size() == 2 and (normalized.get("neutral_rent_journal", {}) as Dictionary).size() == 2, "bankruptcy estate preserves lifecycle and neutral-rent exact-once journals")
	_expect(str(normalized.get("last_survivor_transaction_id", "")) == "estate-finalized", "bankruptcy estate preserves the last-survivor exact-once marker")

	var detached_probe := estate.duplicate() as BankruptcyNeutralEstateRuntimeController
	var probe_receipt: Dictionary = detached_probe.apply_save_data(normalized) if detached_probe != null else {}
	_expect(bool(probe_receipt.get("applied", false)) and _same_data(normalized, detached_probe.to_save_data()), "detached registry preflight normalizes bankruptcy state exactly")
	detached_probe.free()

	var cleared := _checkpoint()
	cleared["journal"] = {}
	cleared["neutral_rent_journal"] = {}
	cleared["last_public_receipt"] = {}
	cleared["last_survivor_transaction_id"] = ""
	_expect(bool(estate.apply_save_data(cleared).get("applied", false)) and not _same_data(normalized, estate.to_save_data()), "bankruptcy owner can be mutated before rollback")
	_expect(bool(estate.apply_save_data(normalized).get("applied", false)) and _same_data(normalized, estate.to_save_data()), "bankruptcy rollback restores the exact owner checkpoint")

	var before_invalid := estate.to_save_data()
	var private_injection := before_invalid.duplicate(true)
	(private_injection.get("journal", {}) as Dictionary)["estate-finalized"]["private_cash_cents"] = 987654321
	var rejected_private: Dictionary = estate.apply_save_data(private_injection)
	_expect(not bool(rejected_private.get("applied", true)) and str(rejected_private.get("reason", "")) == "bankruptcy_journal_record_not_allowlisted", "bankruptcy save rejects private participant fields")
	_expect(_same_data(before_invalid, estate.to_save_data()), "private-field rejection mutates no live bankruptcy state")
	var bad_reference := before_invalid.duplicate(true)
	bad_reference["last_survivor_transaction_id"] = "missing-transaction"
	_expect(not bool(estate.apply_save_data(bad_reference).get("applied", true)) and _same_data(before_invalid, estate.to_save_data()), "invalid last-survivor reference fails closed without mutation")
	var debug := estate.debug_snapshot()
	_expect(not debug.has("journal") and not debug.has("neutral_rent_journal") and not JSON.stringify(debug).contains("987654321"), "bankruptcy debug snapshot exposes no private save journal")
	estate.queue_free()

	var coordinator := COORDINATOR_SCENE.instantiate()
	root.add_child(coordinator)
	await process_frame
	var registry := coordinator.get_node_or_null("GameSessionRuntimeController/V06SaveOwnerRegistry")
	var registry_snapshot: Dictionary = registry.registry_snapshot() if registry != null else {}
	_expect(registry != null and bool(registry_snapshot.get("valid", false)), "production registry remains structurally valid")
	_expect(int(registry_snapshot.get("transactional_section_count", 0)) >= 7 and int(registry_snapshot.get("unsupported_section_count", 0)) <= 11, "bankruptcy estate remains one of the registered transactional owners")
	var binding: Resource
	if registry != null:
		for candidate in registry.bindings:
			if candidate != null and str(candidate.section_id) == "bankruptcy_neutral_estate":
				binding = candidate
				break
	_expect(binding != null and binding.is_transactional() and str(binding.owner_path) == "../../BankruptcyNeutralEstateRuntimeController", "registry binds bankruptcy state to the unique production owner")
	_expect(not bool(registry_snapshot.get("resume_ready", true)), "full resume remains fail-closed while eleven sections are unsupported")
	coordinator.queue_free()
	await process_frame
	_finish()


func _checkpoint() -> Dictionary:
	var counts := {
		"hand_cards_removed": 2,
		"goods_removed": 3,
		"military_units_removed": 1,
		"monsters_orphaned": 1,
		"facilities_neutralized": 2,
	}
	var public_receipt := {"player_indices": [1], "estate_counts": counts.duplicate(true), "reason": "negative_cash_checkpoint"}
	return {
		"state_version": 1,
		"ruleset_id": "v0.6",
		"journal": {
			"estate-finalized": {
				"state": "finalized",
				"reason_code": "negative_cash_checkpoint",
				"player_indices": [1],
				"estate_counts": counts.duplicate(true),
				"lifecycle_token": "estate-finalized-token",
				"occurred_at": 42.0,
				"public_receipt": public_receipt.duplicate(true),
			},
			"estate-rolled-back": {
				"state": "rolled_back",
				"reason_code": "participant_commit_failed",
				"player_indices": [2],
				"estate_counts": counts.duplicate(true),
				"lifecycle_token": "estate-rolled-back-token",
				"occurred_at": 43.0,
			},
		},
		"neutral_rent_journal": {"rent-receipt-a": "rent-batch-1", "rent-receipt-b": "rent-batch-1"},
		"last_public_receipt": public_receipt,
		"last_survivor_transaction_id": "estate-finalized",
	}


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
	print("BANKRUPTCY_NEUTRAL_ESTATE_SAVE_OWNER_TRANSACTION_TEST|status=%s|checks=%d|failures=%d" % ["PASS" if _failures.is_empty() else "FAIL", _checks, _failures.size()])
	quit(0 if _failures.is_empty() else 1)
