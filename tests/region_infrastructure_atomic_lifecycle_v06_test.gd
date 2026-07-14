extends SceneTree

const CONTROLLER_SCRIPT := preload("res://scripts/runtime/region_infrastructure_runtime_controller.gd")
const PROFILE := preload("res://resources/rules/space_syndicate_ruleset_v06.tres")

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_capability_and_request_failures()
	_verify_build_rollback_exact_once()
	_verify_pending_save_finalize_and_closed_rollback()
	_verify_upgrade_repair_and_terminal_save_load()
	_verify_corrupt_save_is_zero_effect()
	_verify_third_party_progression_fails_closed()
	_finish()


func _verify_capability_and_request_failures() -> void:
	var controller := _controller()
	var capabilities := controller.facility_action_capabilities()
	_expect(bool(capabilities.get("production_ready", false)), "configured controller advertises measured atomic facility capability")
	_expect(int(capabilities.get("facility_action_lifecycle_version", 0)) == 2, "facility lifecycle capability is versioned")
	_expect(bool(capabilities.get("apply", false)) and bool(capabilities.get("rollback", false)) and bool(capabilities.get("finalize", false)) and bool(capabilities.get("save_load", false)), "readiness requires apply rollback finalize and save-load")
	var before := _state_fingerprint(controller)
	var missing_region := controller.apply_facility_action(_request("invalid-region", "missing", "factory", "life", 1))
	_expect(not bool(missing_region.get("committed", true)) and str(missing_region.get("reason_code", "")) == "region_not_found", "unknown region is rejected before mutation")
	var bad_owner := _request("invalid-owner", "region.alpha", "factory", "life", 1)
	bad_owner["owner_player_index"] = -1
	_expect(str(controller.apply_facility_action(bad_owner).get("reason_code", "")) == "owner_invalid", "invalid player owner is rejected")
	var bad_rank := _request("invalid-rank", "region.alpha", "factory", "life", 5)
	_expect(str(controller.apply_facility_action(bad_rank).get("reason_code", "")) == "rank_invalid", "rank above IV is rejected")
	_expect(before == _state_fingerprint(controller), "all request preflight failures leave world revision and journal unchanged")
	controller.free()


func _verify_build_rollback_exact_once() -> void:
	var controller := _controller()
	var request := _request("build-rollback", "region.alpha", "factory", "life", 1)
	var before := _state_fingerprint(controller)
	var applied := controller.apply_facility_action(request)
	_expect(bool(applied.get("committed", false)) and str(applied.get("action_kind", "")) == "build", "build applies once on copied owner state")
	_expect(controller.facilities_snapshot(false).size() == 1 and bool(applied.get("rollback_open", false)), "build publishes one facility and an open rollback window")
	var after_apply := _state_fingerprint(controller)
	var replay := controller.apply_facility_action(request)
	_expect(bool(replay.get("duplicate", false)) and after_apply == _state_fingerprint(controller), "build replay is exact-once")
	var collision_request := request.duplicate(true)
	collision_request["rank"] = 2
	var collision := controller.apply_facility_action(collision_request)
	_expect(str(collision.get("reason_code", "")) == "facility_action_transaction_binding_mismatch" and after_apply == _state_fingerprint(controller), "same transaction with another intent fails closed")
	var tampered := applied.duplicate(true)
	var tampered_binding: Dictionary = (tampered.get("owner_binding", {}) as Dictionary).duplicate(true)
	tampered_binding["slot_id"] = "region.alpha::factory.energy"
	tampered["owner_binding"] = tampered_binding
	var tampered_rollback := controller.rollback_facility_action(tampered)
	_expect(not bool(tampered_rollback.get("rolled_back", true)) and str(tampered_rollback.get("reason_code", "")) == "facility_action_receipt_binding_mismatch", "tampered rollback receipt is rejected")
	_expect(after_apply == _state_fingerprint(controller), "tampered rollback cannot erase a facility or advance a journal")
	var rolled_back := controller.rollback_facility_action(applied)
	_expect(bool(rolled_back.get("rolled_back", false)) and controller.facilities_snapshot(false).is_empty(), "valid rollback restores the full build preimage")
	_expect(_region(controller, "region.alpha").get("lifecycle_state", "") == "undeveloped", "build rollback restores regional lifecycle")
	var rollback_state := _state_fingerprint(controller)
	var rollback_replay := controller.rollback_facility_action(applied)
	_expect(bool(rollback_replay.get("rolled_back", false)) and bool(rollback_replay.get("duplicate", false)) and rollback_state == _state_fingerprint(controller), "rollback replay returns the same terminal result without mutation")
	var finalize_after_rollback := controller.finalize_facility_action(applied)
	_expect(not bool(finalize_after_rollback.get("finalized", true)) and str(finalize_after_rollback.get("reason_code", "")) == "facility_action_finalize_after_rollback", "rolled-back action cannot later finalize")
	_expect(before != rollback_state, "rollback records a monotonic terminal receipt even though world content is restored")
	controller.free()


func _verify_pending_save_finalize_and_closed_rollback() -> void:
	var source := _controller()
	var applied := source.apply_facility_action(_request("pending-finalize", "region.alpha", "market", "energy", 1))
	var committed_state := _state_fingerprint(source)
	var tampered := applied.duplicate(true)
	tampered["owner_binding_fingerprint"] = "tampered"
	var failed_finalize := source.finalize_facility_action(tampered)
	_expect(bool(failed_finalize.get("committed", false)) and not bool(failed_finalize.get("finalized", true)), "failed finalize preserves the authoritative committed fact")
	_expect(bool(failed_finalize.get("rollback_open", false)) and committed_state == _state_fingerprint(source), "failed finalize keeps rollback open and changes no owner state")
	var pending_record := source.facility_action_lifecycle_snapshot("pending-finalize")
	_expect(str(pending_record.get("state", "")) == "applied" and bool(pending_record.get("rollback_open", false)), "failed finalize remains retryable")
	var pending_save := source.to_save_data()
	var restored := _controller()
	var restore_result := restored.apply_save_data(pending_save)
	_expect(bool(restore_result.get("applied", false)) and not bool(restored.facility_action_checkpoint_status().get("can_checkpoint", true)), "pending rollback window round-trips while checkpoint remains blocked")
	var restored_pending := restored.facility_action_lifecycle_snapshot("pending-finalize")
	_expect(str(restored_pending.get("state", "")) == "applied" and bool(restored_pending.get("rollback_open", false)), "restored association retains preimage and owner binding")
	var finalized := restored.finalize_facility_action(applied)
	_expect(bool(finalized.get("finalized", false)) and not bool(finalized.get("rollback_open", true)), "retry after restore explicitly finalizes the owner")
	_expect(restored.facilities_snapshot(false).size() == 1, "finalize keeps the committed facility in place")
	var terminal_state := _state_fingerprint(restored)
	var finalize_replay := restored.finalize_facility_action(applied)
	_expect(bool(finalize_replay.get("finalized", false)) and bool(finalize_replay.get("duplicate", false)) and terminal_state == _state_fingerprint(restored), "finalize replay is exact-once")
	var closed_rollback := restored.rollback_facility_action(applied)
	_expect(not bool(closed_rollback.get("rolled_back", true)) and bool(closed_rollback.get("finalized", false)) and str(closed_rollback.get("reason_code", "")) == "facility_action_rollback_closed", "finalized facility cannot be rolled back")
	_expect(terminal_state == _state_fingerprint(restored), "closed rollback leaves facility and journal untouched")
	source.free()
	restored.free()


func _verify_upgrade_repair_and_terminal_save_load() -> void:
	var controller := _controller()
	var build := controller.apply_facility_action(_request("build-base", "region.alpha", "factory", "industry", 1))
	controller.finalize_facility_action(build)
	var rank_one := _facility(controller, str(build.get("facility_id", "")))
	var upgrade := controller.apply_facility_action(_request("upgrade-rollback", "region.alpha", "factory", "industry", 2))
	_expect(str(upgrade.get("action_kind", "")) == "upgrade" and int(_facility(controller, str(build.get("facility_id", ""))).get("rank", 0)) == 2, "upgrade applies on authoritative slot")
	var upgrade_rollback := controller.rollback_facility_action(upgrade)
	_expect(bool(upgrade_rollback.get("rolled_back", false)) and int(_facility(controller, str(build.get("facility_id", ""))).get("rank", 0)) == int(rank_one.get("rank", 0)), "upgrade rollback restores prior facility rank")
	var committed_upgrade := controller.apply_facility_action(_request("upgrade-final", "region.alpha", "factory", "industry", 2))
	controller.finalize_facility_action(committed_upgrade)
	_expect(int(_facility(controller, str(build.get("facility_id", ""))).get("rank", 0)) == 2, "upgrade finalize preserves rank II")
	var damage := controller.apply_unit_damage({
		"transaction_id": "repair-damage",
		"source_kind": "monster",
		"source_entity_id": "monster.fixture",
		"region_id": "region.alpha",
		"amount": 40,
		"occurred_at": 8.0,
	})
	_expect(bool(damage.get("committed", false)) and int(_region(controller, "region.alpha").get("damage_taken", 0)) == 40, "fixture damage reaches the real regional HP owner")
	var repair := controller.apply_facility_action(_request("repair-rollback", "region.alpha", "factory", "industry", 2))
	_expect(str(repair.get("action_kind", "")) == "repair" and int(repair.get("repaired_amount", 0)) == 40, "same-rank facility action performs the observed repair")
	controller.rollback_facility_action(repair)
	_expect(int(_region(controller, "region.alpha").get("damage_taken", 0)) == 40, "repair rollback restores exact prior damage")
	var repair_final := controller.apply_facility_action(_request("repair-final", "region.alpha", "factory", "industry", 2))
	controller.finalize_facility_action(repair_final)
	_expect(int(_region(controller, "region.alpha").get("damage_taken", -1)) == 0, "repair finalize keeps restored HP")
	var terminal_save := controller.to_save_data()
	var restored := _controller()
	_expect(bool(restored.apply_save_data(terminal_save).get("applied", false)), "finalized and rolled-back journal records survive save-load")
	_expect(_state_fingerprint(controller) == _state_fingerprint(restored), "terminal save-load preserves roster revisions bindings and receipts")
	var legacy := terminal_save.duplicate(true)
	legacy.erase("facility_action_lifecycle_version")
	legacy.erase("facility_action_lifecycles")
	legacy.erase("transaction_receipts")
	var legacy_restored := _controller()
	_expect(bool(legacy_restored.apply_save_data(legacy).get("applied", false)), "legacy v0.6 state-version-one envelope remains loadable as closed exact-once guards")
	controller.free()
	restored.free()
	legacy_restored.free()


func _verify_corrupt_save_is_zero_effect() -> void:
	var source := _controller()
	source.apply_facility_action(_request("corrupt-pending", "region.alpha", "warehouse", "commerce", 1))
	var valid_save := source.to_save_data()
	var target := _controller()
	var target_build := target.apply_facility_action(_request("target-stable", "region.beta", "road", "", 1))
	target.finalize_facility_action(target_build)
	var stable_target := _state_fingerprint(target)

	var missing_preimage := valid_save.duplicate(true)
	var lifecycle_a: Dictionary = (missing_preimage.get("facility_action_lifecycles", {}) as Dictionary).duplicate(true)
	var record_a: Dictionary = (lifecycle_a.get("corrupt-pending", {}) as Dictionary).duplicate(true)
	record_a["preimage"] = {}
	lifecycle_a["corrupt-pending"] = record_a
	missing_preimage["facility_action_lifecycles"] = lifecycle_a
	_expect(not bool(target.apply_save_data(missing_preimage).get("applied", true)) and stable_target == _state_fingerprint(target), "missing preimage load fails before replacing target state")

	var tampered_receipt := valid_save.duplicate(true)
	var receipts_b: Dictionary = (tampered_receipt.get("transaction_receipts", {}) as Dictionary).duplicate(true)
	var receipt_b: Dictionary = (receipts_b.get("corrupt-pending", {}) as Dictionary).duplicate(true)
	receipt_b["owner_binding_fingerprint"] = "tampered"
	receipts_b["corrupt-pending"] = receipt_b
	tampered_receipt["transaction_receipts"] = receipts_b
	_expect(not bool(target.apply_save_data(tampered_receipt).get("applied", true)) and stable_target == _state_fingerprint(target), "receipt-journal binding corruption has zero load side effects")

	var missing_facility := valid_save.duplicate(true)
	missing_facility["facilities"] = []
	_expect(not bool(target.apply_save_data(missing_facility).get("applied", true)) and stable_target == _state_fingerprint(target), "postimage roster corruption has zero load side effects")

	var bad_index := valid_save.duplicate(true)
	var ids: Array = (bad_index.get("processed_transaction_ids", []) as Array).duplicate()
	ids.append("ghost")
	bad_index["processed_transaction_ids"] = ids
	_expect(not bool(target.apply_save_data(bad_index).get("applied", true)) and stable_target == _state_fingerprint(target), "processed transaction index mismatch has zero load side effects")
	source.free()
	target.free()


func _verify_third_party_progression_fails_closed() -> void:
	var controller := _controller()
	var base := controller.apply_facility_action(_request("progress-base", "region.alpha", "factory", "life", 1))
	controller.finalize_facility_action(base)
	var pending := controller.apply_facility_action(_request("progress-pending", "region.alpha", "market", "life", 1))
	var advanced := controller.apply_unit_damage({
		"transaction_id": "progress-damage",
		"source_kind": "military",
		"source_entity_id": "unit.fixture",
		"region_id": "region.alpha",
		"amount": 1,
		"occurred_at": 9.0,
	})
	_expect(bool(advanced.get("committed", false)), "third-party owner progression fixture advances authoritative revision")
	var before_rollback := _state_fingerprint(controller)
	var rejected := controller.rollback_facility_action(pending)
	_expect(not bool(rejected.get("rolled_back", true)) and str(rejected.get("reason_code", "")) == "facility_action_controller_revision_changed", "rollback refuses a world state advanced by another legitimate transaction")
	_expect(before_rollback == _state_fingerprint(controller), "failed progression rollback leaves region facility generation revision and journal untouched")
	var failed_finalize := controller.finalize_facility_action(pending)
	_expect(not bool(failed_finalize.get("finalized", true)) and bool(failed_finalize.get("committed", false)), "failed finalize remains an authoritative committed open association")
	_expect(not bool(controller.facility_rollback_atomic_ready()), "invalidated open association fails readiness instead of pretending atomic safety")
	var target := _controller()
	var target_before := _state_fingerprint(target)
	var restore := target.apply_save_data(controller.to_save_data())
	_expect(not bool(restore.get("applied", true)) and target_before == _state_fingerprint(target), "unrecoverable open association blocks checkpoint restore fail-closed")
	controller.free()
	target.free()


func _controller() -> RegionInfrastructureRuntimeController:
	var controller := CONTROLLER_SCRIPT.new() as RegionInfrastructureRuntimeController
	root.add_child(controller)
	var configured := controller.configure(PROFILE.debug_snapshot())
	_expect(bool(configured.get("configured", false)), "region infrastructure controller configures from real v0.6 profile")
	var initialized := controller.initialize_regions([
		{"region_id": "region.alpha", "terrain_id": "land", "neighbor_region_ids": ["region.beta"], "legacy_index": 0},
		{"region_id": "region.beta", "terrain_id": "land", "neighbor_region_ids": ["region.alpha"], "legacy_index": 1},
	])
	_expect(bool(initialized.get("initialized", false)), "two-region atomic fixture initializes")
	return controller


func _request(transaction_id: String, region_id: String, facility_type: String, industry_id: String, rank: int) -> Dictionary:
	return {
		"transaction_id": transaction_id,
		"region_id": region_id,
		"owner_kind": "player",
		"owner_player_index": 0,
		"facility_type": facility_type,
		"industry_id": industry_id,
		"rank": rank,
		"occurred_at": 1.0,
	}


func _region(controller: RegionInfrastructureRuntimeController, region_id: String) -> Dictionary:
	return controller.region_state_snapshot(region_id)


func _facility(controller: RegionInfrastructureRuntimeController, facility_id: String) -> Dictionary:
	for facility_variant in controller.facilities_snapshot(false):
		if facility_variant is Dictionary and str((facility_variant as Dictionary).get("facility_id", "")) == facility_id:
			return (facility_variant as Dictionary).duplicate(true)
	return {}


func _state_fingerprint(controller: RegionInfrastructureRuntimeController) -> String:
	return JSON.stringify(controller.to_save_data())


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("REGION_INFRASTRUCTURE_ATOMIC_LIFECYCLE_V06_TEST|status=PASS|checks=%d|failures=0" % _checks)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	print("REGION_INFRASTRUCTURE_ATOMIC_LIFECYCLE_V06_TEST|status=FAIL|checks=%d|failures=%d" % [_checks, _failures.size()])
	quit(1)
