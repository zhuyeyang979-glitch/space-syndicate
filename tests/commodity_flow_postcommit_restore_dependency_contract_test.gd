extends SceneTree

const RestoreContract := preload("res://scripts/runtime/commodity_flow_postcommit_restore_dependency_contract.gd")

var _checks := 0
var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var fixture := _fixture()
	var valid := _validate(fixture)
	_expect(bool(valid.get("accepted", false)) and bool(valid.get("applicable", false)), "matching finalized owner sections pass the pure-data restore dependency contract")
	var empty_finalized := fixture.duplicate(true)
	var empty_flow: Dictionary = (empty_finalized.get("flow", {}) as Dictionary).duplicate(true)
	var empty_consumer: Dictionary = (empty_flow.get("postcommit_consumer", {}) as Dictionary).duplicate(true)
	var empty_journal: Dictionary = (empty_consumer.get("journal", {}) as Dictionary).duplicate(true)
	var empty_record: Dictionary = (empty_journal.get(_batch_id(1), {}) as Dictionary).duplicate(true)
	empty_record["city_target_completed_by_district"] = {}
	empty_record["cash_target_completed_by_player"] = {}
	empty_journal[_batch_id(1)] = empty_record
	empty_consumer["journal"] = empty_journal
	empty_flow["postcommit_consumer"] = empty_consumer
	empty_finalized["flow"] = empty_flow
	var empty_world := _session_world(empty_finalized)
	empty_world["commodity_postcommit_city_lineage_by_district"] = {}
	empty_world["commodity_postcommit_cash_lineage_by_player"] = {}
	_set_session_world(empty_finalized, empty_world)
	_expect(bool(_validate(empty_finalized).get("accepted", false)), "empty finalized batch accepts no city/cash lineage while retaining matching downstream exact-once bindings")

	var city_behind := fixture.duplicate(true)
	var city_session := _session_world(city_behind)
	city_session["commodity_postcommit_city_lineage_by_district"] = {}
	_set_session_world(city_behind, city_session)
	_expect(not bool(_validate(city_behind).get("accepted", true)), "finalized consumer ahead of WorldSession GDP lineage fails closed")

	var cash_behind := fixture.duplicate(true)
	var cash_session := _session_world(cash_behind)
	cash_session["commodity_postcommit_cash_lineage_by_player"] = {}
	_set_session_world(cash_behind, cash_session)
	_expect(not bool(_validate(cash_behind).get("accepted", true)), "finalized consumer ahead of WorldSession cash observation fails closed")

	var world_ahead := fixture.duplicate(true)
	var ahead_world := _session_world(world_ahead)
	var ahead_city: Dictionary = (ahead_world.get("commodity_postcommit_city_lineage_by_district", {}) as Dictionary).duplicate(true)
	ahead_city["1"] = _city_binding(2)
	ahead_world["commodity_postcommit_city_lineage_by_district"] = ahead_city
	_set_session_world(world_ahead, ahead_world)
	_expect(not bool(_validate(world_ahead).get("accepted", true)), "WorldSession target lineage ahead of CommodityFlow fails closed")

	var bankruptcy_behind := fixture.duplicate(true)
	(bankruptcy_behind.get("bankruptcy") as Dictionary)["journal"] = {}
	_expect(not bool(_validate(bankruptcy_behind).get("accepted", true)), "finalized consumer ahead of bankruptcy checkpoint fails closed")

	var bankruptcy_collision := fixture.duplicate(true)
	var collision_bankruptcy: Dictionary = bankruptcy_collision.get("bankruptcy") as Dictionary
	var collision_bankruptcy_journal: Dictionary = (collision_bankruptcy.get("journal", {}) as Dictionary).duplicate(true)
	var bankruptcy_id := "bankruptcy:%s" % _batch_id(1)
	var collision_bankruptcy_record: Dictionary = (collision_bankruptcy_journal.get(bankruptcy_id, {}) as Dictionary).duplicate(true)
	collision_bankruptcy_record["request_fingerprint"] = "bankruptcy-collision".sha256_text()
	collision_bankruptcy_journal[bankruptcy_id] = collision_bankruptcy_record
	collision_bankruptcy["journal"] = collision_bankruptcy_journal
	bankruptcy_collision["bankruptcy"] = collision_bankruptcy
	_expect(not bool(_validate(bankruptcy_collision).get("accepted", true)), "bankruptcy request fingerprint collision fails closed")

	var mana_behind := fixture.duplicate(true)
	(mana_behind.get("mana") as Dictionary)["advance_once_journal"] = {}
	_expect(not bool(_validate(mana_behind).get("accepted", true)), "finalized consumer ahead of PlayerMana advance-once lineage fails closed")

	var mana_ahead := fixture.duplicate(true)
	var ahead_mana: Dictionary = mana_ahead.get("mana") as Dictionary
	var ahead_mana_journal: Dictionary = (ahead_mana.get("advance_once_journal", {}) as Dictionary).duplicate(true)
	var ahead_asset_id := "asset-recovery:%s" % _batch_id(2)
	ahead_mana_journal[ahead_asset_id] = {
		"transaction_id": ahead_asset_id,
		"fingerprint": "ahead-asset".sha256_text(),
		"receipt": {"advanced": true},
	}
	ahead_mana["advance_once_journal"] = ahead_mana_journal
	mana_ahead["mana"] = ahead_mana
	_expect(not bool(_validate(mana_ahead).get("accepted", true)), "PlayerMana lineage ahead of CommodityFlow fails closed")

	var pending := _fixture()
	var pending_flow: Dictionary = pending.get("flow") as Dictionary
	var pending_consumer: Dictionary = (pending_flow.get("postcommit_consumer", {}) as Dictionary).duplicate(true)
	pending_consumer["completed_through_batch_sequence"] = 0
	pending_consumer["pending_batch_id"] = _batch_id(1)
	var pending_journal: Dictionary = (pending_consumer.get("journal", {}) as Dictionary).duplicate(true)
	var pending_record: Dictionary = (pending_journal.get(_batch_id(1), {}) as Dictionary).duplicate(true)
	pending_record["state"] = "pending"
	pending_record["cash_target_completed_by_player"] = {}
	pending_record["bankruptcy_target_completed"] = false
	pending_record["asset_recovery_target_completed"] = false
	pending_journal[_batch_id(1)] = pending_record
	pending_consumer["journal"] = pending_journal
	pending_flow["postcommit_consumer"] = pending_consumer
	pending["flow"] = pending_flow
	var pending_world := _session_world(pending)
	pending_world["commodity_postcommit_cash_lineage_by_player"] = {}
	_set_session_world(pending, pending_world)
	(pending.get("mana") as Dictionary)["advance_once_journal"] = {}
	_expect(bool(_validate(pending).get("accepted", false)), "pending target-success/caller-ack window remains recoverable when existing target bindings match")

	var legacy := _fixture()
	var legacy_flow: Dictionary = legacy.get("flow") as Dictionary
	legacy_flow["batch_sequence"] = 5
	var legacy_consumer: Dictionary = legacy_flow.get("postcommit_consumer") as Dictionary
	legacy_consumer["completed_through_batch_sequence"] = 5
	legacy_consumer["pending_batch_id"] = ""
	legacy_consumer["journal"] = {}
	legacy_consumer["legacy_bootstrap_reason"] = CommodityFlowPostCommitReceiptConsumer.LEGACY_BOOTSTRAP_REASON
	legacy_flow["postcommit_consumer"] = legacy_consumer
	legacy["flow"] = legacy_flow
	var legacy_world := _session_world(legacy)
	legacy_world["commodity_postcommit_city_lineage_by_district"] = {}
	legacy_world["commodity_postcommit_cash_lineage_by_player"] = {}
	_set_session_world(legacy, legacy_world)
	(legacy.get("bankruptcy") as Dictionary)["journal"] = {}
	(legacy.get("mana") as Dictionary)["advance_once_journal"] = {}
	_expect(bool(_validate(legacy).get("accepted", false)), "explicit pre-cutover synchronous-completion bootstrap accepts empty target cursors")
	var forged_legacy := legacy.duplicate(true)
	var forged_flow: Dictionary = (forged_legacy.get("flow", {}) as Dictionary).duplicate(true)
	var forged_consumer: Dictionary = (forged_flow.get("postcommit_consumer", {}) as Dictionary).duplicate(true)
	forged_consumer["legacy_bootstrap_reason"] = "forged_nonempty_legacy_reason"
	forged_flow["postcommit_consumer"] = forged_consumer
	forged_legacy["flow"] = forged_flow
	var forged_before := forged_legacy.duplicate(true)
	var forged_result := _validate(forged_legacy)
	_expect(
		not bool(forged_result.get("accepted", true))
		and str(forged_result.get("reason_code", "")) == "commodity_postcommit_legacy_bootstrap_reason_invalid"
		and forged_legacy == forged_before,
		"unknown non-empty legacy marker cannot forge a no-journal bootstrap and validation is pure"
	)

	var not_applicable := RestoreContract.validate_dependencies({}, {}, {}, {})
	_expect(bool(not_applicable.get("accepted", false)) and not bool(not_applicable.get("applicable", true)), "unrelated registry fixtures remain outside the CommodityFlow dependency contract")

	var registry_source := FileAccess.get_file_as_string("res://scripts/runtime/v06_save_owner_registry.gd")
	var contract_source := FileAccess.get_file_as_string("res://scripts/runtime/commodity_flow_postcommit_restore_dependency_contract.gd")
	_expect(registry_source.contains("CommodityFlowPostCommitRestoreDependencyContractScript") and registry_source.contains("validate_dependencies"), "formal save registry invokes the CommodityFlow dependency contract before apply")
	_expect(not contract_source.contains("get_node") and not contract_source.contains("get_tree") and not contract_source.contains("current_scene"), "restore dependency contract reads only detached candidate data")

	if _failures == 0:
		print("COMMODITY POSTCOMMIT RESTORE DEPENDENCY PASS: %d/%d" % [_checks, _checks])
		quit(0)
		return
	push_error("COMMODITY POSTCOMMIT RESTORE DEPENDENCY FAIL: %d/%d" % [_failures, _checks])
	quit(1)


func _validate(fixture: Dictionary) -> Dictionary:
	return RestoreContract.validate_dependencies(
		(fixture.get("flow", {}) as Dictionary).duplicate(true),
		(fixture.get("session", {}) as Dictionary).duplicate(true),
		(fixture.get("bankruptcy", {}) as Dictionary).duplicate(true),
		(fixture.get("mana", {}) as Dictionary).duplicate(true)
	)


func _fixture() -> Dictionary:
	var sequence := 1
	var batch_id := _batch_id(sequence)
	var batch_fingerprint := "restore-contract-batch-1".sha256_text()
	var city_fingerprint := "restore-contract-city-1".sha256_text()
	var bankruptcy_fingerprint := "restore-contract-bankruptcy-1".sha256_text()
	var asset_fingerprint := "restore-contract-asset-1".sha256_text()
	var bankruptcy_id := "bankruptcy:%s" % batch_id
	var asset_id := "asset-recovery:%s" % batch_id
	var record := {
		"state": "finalized",
		"batch_id": batch_id,
		"batch_sequence": sequence,
		"batch_fingerprint": batch_fingerprint,
		"city_breakdown_fingerprint": city_fingerprint,
		"city_target_completed_by_district": {"0": true},
		"cash_target_completed_by_player": {"0": true},
		"downstream_snapshot": {
			"bankruptcy_transaction_id": bankruptcy_id,
			"bankruptcy_request_fingerprint": bankruptcy_fingerprint,
			"asset_recovery_transaction_id": asset_id,
			"asset_recovery_request_fingerprint": asset_fingerprint,
		},
		"bankruptcy_target_completed": true,
		"asset_recovery_target_completed": true,
	}
	return {
		"flow": {
			"batch_sequence": sequence,
			"postcommit_consumer": {
				"completed_through_batch_sequence": sequence,
				"pending_batch_id": "",
				"legacy_bootstrap_reason": "",
				"journal": {batch_id: record},
			},
		},
		"session": {
			"world_session_state": {
				"commodity_postcommit_city_lineage_by_district": {"0": _city_binding(sequence, batch_fingerprint, city_fingerprint)},
				"commodity_postcommit_cash_lineage_by_player": {"0": _cash_binding(sequence, batch_fingerprint)},
			},
		},
		"bankruptcy": {
			"commodity_flow_retired_sequence": 0,
			"journal": {
				bankruptcy_id: {
					"state": "finalized",
					"request_fingerprint": bankruptcy_fingerprint,
					"source_fingerprint": batch_fingerprint,
				},
			},
		},
		"mana": {
			"advance_once_journal": {
				asset_id: {
					"transaction_id": asset_id,
					"fingerprint": asset_fingerprint,
					"receipt": {"advanced": true},
				},
			},
		},
	}


func _session_world(fixture: Dictionary) -> Dictionary:
	return ((fixture.get("session", {}) as Dictionary).get("world_session_state", {}) as Dictionary).duplicate(true)


func _set_session_world(fixture: Dictionary, world: Dictionary) -> void:
	var session: Dictionary = (fixture.get("session", {}) as Dictionary).duplicate(true)
	session["world_session_state"] = world
	fixture["session"] = session


func _city_binding(sequence: int, fingerprint := "", city_fingerprint := "") -> Dictionary:
	return {
		"batch_sequence": sequence,
		"batch_id": _batch_id(sequence),
		"batch_fingerprint": fingerprint if not fingerprint.is_empty() else ("restore-contract-batch-%d" % sequence).sha256_text(),
		"city_breakdown_fingerprint": city_fingerprint if not city_fingerprint.is_empty() else ("restore-contract-city-%d" % sequence).sha256_text(),
	}


func _cash_binding(sequence: int, fingerprint := "") -> Dictionary:
	return {
		"batch_sequence": sequence,
		"batch_id": _batch_id(sequence),
		"batch_fingerprint": fingerprint if not fingerprint.is_empty() else ("restore-contract-batch-%d" % sequence).sha256_text(),
	}


func _batch_id(sequence: int) -> String:
	return "commodity-flow-batch-%010d" % sequence


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		return
	_failures += 1
	push_error("COMMODITY POSTCOMMIT RESTORE DEPENDENCY: %s" % message)
