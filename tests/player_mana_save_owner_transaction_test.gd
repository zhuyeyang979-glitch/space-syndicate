extends SceneTree

const RULESET_PROFILE := preload("res://resources/rules/space_syndicate_ruleset_v06.tres")
const MANA_SCENE := preload("res://scenes/runtime/PlayerManaRuntimeController.tscn")
const COORDINATOR_SCENE := preload("res://scenes/runtime/GameRuntimeCoordinator.tscn")

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var mana := MANA_SCENE.instantiate() as PlayerManaRuntimeController
	root.add_child(mana)
	var configured: Dictionary = mana.configure(RULESET_PROFILE.debug_snapshot())
	_expect(bool(configured.get("configured", false)), "player mana owner configures from the active v0.6 profile")
	mana.reset_state(2)
	var seeded := mana.to_save_data()
	seeded["pools_by_player"] = {
		"0": _asset_row({"energy": 9000, "technology": 5000}),
		"1": _asset_row({"commerce": 7000}),
	}
	seeded["recovery_remainders_by_player"] = {
		"0": _asset_row({"energy": 17}),
		"1": _asset_row({"commerce": 23}),
	}
	seeded["revision"] = 41
	var seeded_receipt: Dictionary = mana.apply_save_data(seeded)
	_expect(bool(seeded_receipt.get("applied", false)), "player mana accepts a valid authoritative seed")
	var plan: Dictionary = mana.plan_reservation({
		"transaction_id": "save-owner-active-reservation",
		"player_index": 0,
		"asset_cost": {"energy": 2, "technology": 1},
	})
	var committed: Dictionary = mana.commit_reservation(plan)
	_expect(bool(plan.get("accepted", false)) and bool(committed.get("authorized", false)), "player mana fixture contains an active authoritative reservation")
	var terminal_plan: Dictionary = mana.plan_reservation({
		"transaction_id": "save-owner-terminal-receipt",
		"player_index": 1,
		"asset_cost": {"commerce": 2},
	})
	mana.commit_reservation(terminal_plan)
	var terminal: Dictionary = mana.consume_reservation("save-owner-terminal-receipt", {"resolved": true})
	_expect(str(terminal.get("outcome", "")) == "consumed", "player mana fixture contains an exact-once terminal receipt")

	var checkpoint := mana.to_save_data()
	var checkpoint_revision := int(checkpoint.get("revision", -1))
	_expect(checkpoint_revision >= 0 and _pure_data(checkpoint), "player mana checkpoint is pure data with a valid revision")
	mana.advance(2000, 99.0, {"0": _flow_row({"life": 200, "shipping": 100})})
	mana.release_reservation("save-owner-active-reservation", "test_mutation")
	_expect(not _same_data(checkpoint, mana.to_save_data()), "player mana mutation changes the authoritative checkpoint")
	var restored: Dictionary = mana.apply_save_data(checkpoint)
	_expect(bool(restored.get("applied", false)) and _same_data(checkpoint, mana.to_save_data()), "player mana restore is byte-equivalent including revision reservations and receipts")
	_expect(int(mana.to_save_data().get("revision", -1)) == checkpoint_revision, "player mana restore does not synthesize a new revision")
	var detached_probe := mana.duplicate() as PlayerManaRuntimeController
	var detached_receipt: Dictionary = detached_probe.apply_save_data(checkpoint) if detached_probe != null else {}
	_expect(bool(detached_receipt.get("applied", false)) and _same_data(checkpoint, detached_probe.to_save_data()), "detached registry preflight probe normalizes player mana without mutating the live owner")
	detached_probe.free()

	var before_invalid := mana.to_save_data()
	var invalid := before_invalid.duplicate(true)
	invalid["revision"] = -1
	var invalid_receipt: Dictionary = mana.apply_save_data(invalid)
	_expect(not bool(invalid_receipt.get("applied", true)) and str(invalid_receipt.get("reason", "")) == "asset_save_revision_invalid", "invalid revision fails closed")
	_expect(_same_data(before_invalid, mana.to_save_data()), "failed player mana restore mutates no authoritative state")
	mana.advance(1000, 100.0, {"0": _flow_row({"industry": 100})})
	var rollback_receipt: Dictionary = mana.apply_save_data(checkpoint)
	_expect(bool(rollback_receipt.get("applied", false)) and _same_data(checkpoint, mana.to_save_data()), "player mana rollback can restore the same checkpoint repeatedly")

	var public_snapshot := mana.public_snapshot()
	_expect(not public_snapshot.has("pools_by_player") and not public_snapshot.has("reservations") and not public_snapshot.has("terminal_receipts"), "player mana public snapshot exposes no private save state")
	mana.queue_free()

	var coordinator := COORDINATOR_SCENE.instantiate()
	root.add_child(coordinator)
	await process_frame
	var registry := coordinator.get_node_or_null("GameSessionRuntimeController/V06SaveOwnerRegistry")
	var registry_snapshot: Dictionary = registry.registry_snapshot() if registry != null else {}
	_expect(registry != null and bool(registry_snapshot.get("valid", false)), "production save registry remains structurally valid")
	_expect(int(registry_snapshot.get("transactional_section_count", 0)) == 6 and int(registry_snapshot.get("unsupported_section_count", 0)) == 12, "player mana advances the honest production boundary to 6 transactional and 12 unsupported sections")
	var mana_binding: Resource
	if registry != null:
		for binding in registry.bindings:
			if binding != null and str(binding.section_id) == "player_mana":
				mana_binding = binding
				break
	_expect(mana_binding != null and mana_binding.is_transactional() and str(mana_binding.owner_path) == "../../PlayerManaRuntimeController", "registry binds player mana to the unique production owner")
	_expect(not bool(registry_snapshot.get("resume_ready", true)), "full resume remains fail-closed while twelve sections are unsupported")
	coordinator.queue_free()
	await process_frame
	_finish()


func _asset_row(overrides: Dictionary) -> Dictionary:
	var row := {}
	for asset_id_variant in PlayerManaRuntimeController.ASSET_IDS:
		var asset_id := str(asset_id_variant)
		row[asset_id] = maxi(0, int(overrides.get(asset_id, 0)))
	return row


func _flow_row(overrides: Dictionary) -> Dictionary:
	var colors := {}
	for asset_id_variant in PlayerManaRuntimeController.ASSET_IDS:
		var asset_id := str(asset_id_variant)
		colors[asset_id] = {"gdp_per_minute": maxi(0, int(overrides.get(asset_id, 0)))}
	return {"colors": colors}


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
	print("PLAYER_MANA_SAVE_OWNER_TRANSACTION_TEST|status=%s|checks=%d|failures=%d" % ["PASS" if _failures.is_empty() else "FAIL", _checks, _failures.size()])
	quit(0 if _failures.is_empty() else 1)
