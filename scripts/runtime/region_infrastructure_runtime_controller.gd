@tool
extends Node
class_name RegionInfrastructureRuntimeController

signal infrastructure_receipt_committed(receipt: Dictionary)
signal region_lifecycle_changed(receipt: Dictionary)
signal facility_action_rolled_back(receipt: Dictionary)
signal facility_action_finalized(receipt: Dictionary)

const SAVE_VERSION := 1
const RULESET_ID := "v0.6"
const FACILITY_ACTION_LIFECYCLE_VERSION := 2
const FACILITY_ACTION_STATES := ["applied", "rolled_back", "finalized"]
const OWNER_KINDS := ["player", "neutral"]
const FACILITY_TYPES := ["factory", "market", "road", "port", "spaceport", "warehouse"]
const INDUSTRY_IDS := ["life", "energy", "industry", "technology", "commerce", "shipping"]
const DAMAGE_SOURCE_KINDS := ["monster", "military"]
const REPAIR_SOURCE_KINDS := ["facility_card", "military"]

var _configured := false
var _maximum_rank := 4
var _hp_by_rank := {1: 100, 2: 200, 3: 300, 4: 400}
var _regions: Dictionary = {}
var _facilities: Dictionary = {}
var _facility_by_slot: Dictionary = {}
var _slot_generations: Dictionary = {}
var _facility_tombstones: Array = []
var _transaction_receipts: Dictionary = {}
var _facility_action_lifecycles: Dictionary = {}
var _revision := 0
var _receipt_sequence := 0
var _bankruptcy_estate_journal: Dictionary = {}


func configure(ruleset_snapshot: Dictionary) -> Dictionary:
	var identity: Dictionary = ruleset_snapshot.get("identity", ruleset_snapshot)
	var infrastructure: Dictionary = ruleset_snapshot.get("infrastructure", ruleset_snapshot)
	var ruleset_id := str(identity.get("ruleset_id", ruleset_snapshot.get("ruleset_id", "")))
	if ruleset_id != RULESET_ID:
		_configured = false
		return {"configured": false, "reason": "ruleset_not_v06", "ruleset_id": ruleset_id}
	var rank_table_variant: Variant = infrastructure.get("facility_hp_contribution_by_rank", {})
	if not (rank_table_variant is Dictionary):
		_configured = false
		return {"configured": false, "reason": "facility_hp_table_missing", "ruleset_id": ruleset_id}
	var parsed_table := _parse_rank_table(rank_table_variant as Dictionary)
	if parsed_table.size() != 4:
		_configured = false
		return {"configured": false, "reason": "facility_hp_table_invalid", "ruleset_id": ruleset_id}
	_maximum_rank = clampi(int(infrastructure.get("maximum_facility_rank", 4)), 1, 4)
	_hp_by_rank = parsed_table
	_configured = true
	return {
		"configured": true,
		"ruleset_id": RULESET_ID,
		"maximum_facility_rank": _maximum_rank,
		"facility_hp_contribution_by_rank": _rank_table_snapshot(),
	}


func reset_state() -> void:
	_regions.clear()
	_facilities.clear()
	_facility_by_slot.clear()
	_slot_generations.clear()
	_facility_tombstones.clear()
	_transaction_receipts.clear()
	_facility_action_lifecycles.clear()
	_revision = 0
	_receipt_sequence = 0
	_bankruptcy_estate_journal.clear()


func bankruptcy_estate_stage(stage: String, request: Dictionary) -> Dictionary:
	var transaction_id := str(request.get("transaction_id", "")).strip_edges()
	var player_indices: Array = request.get("player_indices", []) if request.get("player_indices", []) is Array else []
	if transaction_id.is_empty() or player_indices.is_empty() or not (["prepare", "commit", "rollback", "finalize"].has(stage)):
		return _bankruptcy_estate_failure(stage, "region_bankruptcy_request_invalid")
	var record: Dictionary = _bankruptcy_estate_journal.get(transaction_id, {}) if _bankruptcy_estate_journal.get(transaction_id, {}) is Dictionary else {}
	if not record.is_empty() and record.get("player_indices", []) != player_indices:
		return _bankruptcy_estate_failure(stage, "region_bankruptcy_transaction_collision")
	match stage:
		"prepare":
			if not record.is_empty():
				return _bankruptcy_estate_result(stage, record, true)
			var target_indices: Dictionary = {}
			for value in player_indices:
				target_indices[str(int(value))] = true
			var postimage := _facilities.duplicate(true)
			var neutralized := 0
			for facility_id_variant in postimage.keys():
				var facility: Dictionary = postimage[facility_id_variant] if postimage[facility_id_variant] is Dictionary else {}
				if str(facility.get("owner_kind", "")) == "player" and target_indices.has(str(int(facility.get("owner_player_index", -1)))):
					facility["owner_kind"] = "neutral"
					facility["owner_player_index"] = -1
					postimage[facility_id_variant] = facility
					neutralized += 1
			record = {
				"state": "prepared",
				"player_indices": player_indices.duplicate(),
				"expected_revision": _revision,
				"expected_hash": var_to_str(_facilities).sha256_text(),
				"preimage": _facilities.duplicate(true),
				"postimage": postimage,
				"estate_counts": {"facilities_neutralized": neutralized},
			}
			_bankruptcy_estate_journal[transaction_id] = record
			return _bankruptcy_estate_result(stage, record, false)
		"commit":
			if record.is_empty():
				return _bankruptcy_estate_failure(stage, "region_bankruptcy_prepare_missing")
			if str(record.get("state", "")) in ["committed", "finalized"]:
				return _bankruptcy_estate_result(stage, record, true)
			if str(record.get("state", "")) != "prepared" or _revision != int(record.get("expected_revision", -1)) or var_to_str(_facilities).sha256_text() != str(record.get("expected_hash", "")):
				return _bankruptcy_estate_failure(stage, "region_bankruptcy_revision_changed")
			_facilities = (record.get("postimage", {}) as Dictionary).duplicate(true)
			_revision += 1
			record["state"] = "committed"
			_bankruptcy_estate_journal[transaction_id] = record
			return _bankruptcy_estate_result(stage, record, false)
		"rollback":
			if record.is_empty():
				return _bankruptcy_estate_failure(stage, "region_bankruptcy_prepare_missing")
			if str(record.get("state", "")) == "rolled_back":
				return _bankruptcy_estate_result(stage, record, true)
			if str(record.get("state", "")) == "finalized":
				return _bankruptcy_estate_failure(stage, "region_bankruptcy_already_finalized")
			if str(record.get("state", "")) == "committed":
				_facilities = (record.get("preimage", {}) as Dictionary).duplicate(true)
				_revision = int(record.get("expected_revision", _revision))
			record["state"] = "rolled_back"
			_bankruptcy_estate_journal[transaction_id] = record
			return _bankruptcy_estate_result(stage, record, false)
		"finalize":
			if record.is_empty() or not (str(record.get("state", "")) in ["committed", "finalized"]):
				return _bankruptcy_estate_failure(stage, "region_bankruptcy_commit_missing")
			var duplicate := str(record.get("state", "")) == "finalized"
			record["state"] = "finalized"
			record.erase("preimage")
			record.erase("postimage")
			_bankruptcy_estate_journal[transaction_id] = record
			return _bankruptcy_estate_result(stage, record, duplicate)
	return _bankruptcy_estate_failure(stage, "region_bankruptcy_stage_invalid")


func _bankruptcy_estate_result(stage: String, record: Dictionary, duplicate: bool) -> Dictionary:
	return {
		"prepared": stage == "prepare", "committed": stage == "commit",
		"rolled_back": stage == "rollback", "finalized": stage == "finalize",
		"duplicate": duplicate, "reason_code": "region_bankruptcy_%s" % stage,
		"estate_counts": (record.get("estate_counts", {}) as Dictionary).duplicate(true) if record.get("estate_counts", {}) is Dictionary else {},
	}


func _bankruptcy_estate_failure(stage: String, reason_code: String) -> Dictionary:
	return {"prepared": false, "committed": false, "rolled_back": false, "finalized": false, "stage": stage, "reason_code": reason_code, "estate_counts": {}}


func initialize_regions(region_definitions: Array) -> Dictionary:
	if not _configured:
		return {"initialized": false, "reason": "controller_not_configured"}
	var prepared: Dictionary = {}
	var errors: Array[String] = []
	for definition_variant in region_definitions:
		if not (definition_variant is Dictionary):
			errors.append("region_definition_not_dictionary")
			continue
		var definition: Dictionary = definition_variant
		var region_id := str(definition.get("region_id", "")).strip_edges()
		if region_id.is_empty():
			errors.append("region_id_missing")
			continue
		if prepared.has(region_id):
			errors.append("duplicate_region_id:%s" % region_id)
			continue
		var neighbor_ids: Array = _string_array(definition.get("neighbor_region_ids", []))
		prepared[region_id] = {
			"region_id": region_id,
			"terrain_id": str(definition.get("terrain_id", "unknown")),
			"neighbor_region_ids": neighbor_ids,
			"facility_slot_ids": standard_slot_ids(region_id),
			"lifecycle_state": "undeveloped",
			"damage_taken": 0,
			"generation": maxi(1, int(definition.get("generation", 1))),
			"revision": 1,
			"legacy_index": int(definition.get("legacy_index", -1)),
		}
	if not errors.is_empty():
		return {"initialized": false, "reason": "region_definitions_invalid", "errors": errors}
	reset_state()
	_regions = prepared
	_revision = 1 if not _regions.is_empty() else 0
	return {
		"initialized": true,
		"region_count": _regions.size(),
		"facility_count": 0,
		"revision": _revision,
	}


func standard_slot_ids(region_id: String) -> Array:
	var result: Array = []
	for industry_id in INDUSTRY_IDS:
		result.append(slot_id(region_id, "factory", industry_id))
	for industry_id in INDUSTRY_IDS:
		result.append(slot_id(region_id, "market", industry_id))
	for industry_id in INDUSTRY_IDS:
		result.append(slot_id(region_id, "warehouse", industry_id))
	for facility_type in ["road", "port", "spaceport"]:
		result.append(slot_id(region_id, facility_type, ""))
	return result


func slot_id(region_id: String, facility_type: String, industry_id: String = "") -> String:
	var key := facility_type
	if facility_type == "factory" or facility_type == "market" or facility_type == "warehouse":
		key = "%s.%s" % [facility_type, industry_id]
	return "%s::%s" % [region_id, key]


func region_id_for_legacy_index(legacy_index: int) -> String:
	for region_id_variant in _regions:
		var region: Dictionary = _regions[region_id_variant]
		if int(region.get("legacy_index", -1)) == legacy_index:
			return str(region_id_variant)
	return ""


func apply_facility_action(request: Dictionary) -> Dictionary:
	var transaction_id := str(request.get("transaction_id", "")).strip_edges()
	var common_error := _request_error(transaction_id, request)
	if not common_error.is_empty():
		return _failure_receipt("facility_action", transaction_id, common_error)
	var intent_fingerprint := _facility_intent_fingerprint(request)
	if _transaction_receipts.has(transaction_id):
		return _facility_action_replay(transaction_id, intent_fingerprint)
	var region_id := str(request.get("region_id", ""))
	if not _regions.has(region_id):
		return _failure_receipt("facility_action", transaction_id, "region_not_found")
	var owner_kind := str(request.get("owner_kind", "player"))
	var owner_player_index := int(request.get("owner_player_index", -1))
	if not OWNER_KINDS.has(owner_kind) or (owner_kind == "player" and owner_player_index < 0):
		return _failure_receipt("facility_action", transaction_id, "owner_invalid")
	if owner_kind == "neutral":
		owner_player_index = -1
	var facility_type := str(request.get("facility_type", ""))
	var industry_id := str(request.get("industry_id", ""))
	if not _facility_kind_valid(facility_type, industry_id):
		return _failure_receipt("facility_action", transaction_id, "facility_kind_invalid")
	var requested_rank := int(request.get("rank", 0))
	if requested_rank < 1 or requested_rank > _maximum_rank:
		return _failure_receipt("facility_action", transaction_id, "rank_invalid")
	var target_slot_id := slot_id(region_id, facility_type, industry_id)
	var next_regions := _regions.duplicate(true)
	var next_facilities := _facilities.duplicate(true)
	var next_facility_by_slot := _facility_by_slot.duplicate(true)
	var next_slot_generations := _slot_generations.duplicate(true)
	var next_receipts := _transaction_receipts.duplicate(true)
	var next_lifecycles := _facility_action_lifecycles.duplicate(true)
	var region: Dictionary = (next_regions[region_id] as Dictionary).duplicate(true)
	var before := _derived_region_snapshot_from_state(region_id, next_regions, next_facilities, next_facility_by_slot)
	var existing_id := str(next_facility_by_slot.get(target_slot_id, ""))
	var preimage := {
		"region_before": region.duplicate(true),
		"slot_mapping_before_present": next_facility_by_slot.has(target_slot_id),
		"slot_mapping_before": existing_id,
		"facility_before_present": not existing_id.is_empty() and next_facilities.has(existing_id),
		"facility_before": (next_facilities[existing_id] as Dictionary).duplicate(true) if not existing_id.is_empty() and next_facilities.has(existing_id) else {},
		"slot_generation_before_present": next_slot_generations.has(target_slot_id),
		"slot_generation_before": int(next_slot_generations.get(target_slot_id, 0)),
		"controller_revision_before": _revision,
	}
	var action_kind := "build"
	var repaired_amount := 0
	var facility_id := existing_id
	var old_rank := 0
	if existing_id.is_empty():
		var generation := int(next_slot_generations.get(target_slot_id, 0)) + 1
		next_slot_generations[target_slot_id] = generation
		facility_id = "%s::g%d" % [target_slot_id, generation]
		var facility := {
			"facility_id": facility_id,
			"slot_id": target_slot_id,
			"region_id": region_id,
			"facility_type": facility_type,
			"industry_id": industry_id,
			"owner_kind": owner_kind,
			"owner_player_index": owner_player_index,
			"rank": requested_rank,
			"generation": generation,
			"active": true,
			"built_at": float(request.get("occurred_at", 0.0)),
		}
		next_facilities[facility_id] = facility
		next_facility_by_slot[target_slot_id] = facility_id
		if str(region.get("lifecycle_state", "")) == "ruined":
			region["generation"] = int(region.get("generation", 1)) + 1
		region["lifecycle_state"] = "active"
	else:
		var existing: Dictionary = (next_facilities.get(existing_id, {}) as Dictionary).duplicate(true)
		if existing.is_empty() or not bool(existing.get("active", false)):
			return _failure_receipt("facility_action", transaction_id, "slot_state_invalid")
		if str(existing.get("owner_kind", "")) != owner_kind or int(existing.get("owner_player_index", -1)) != owner_player_index:
			return _failure_receipt("facility_action", transaction_id, "facility_owned_by_other")
		old_rank = int(existing.get("rank", 1))
		if requested_rank > old_rank:
			action_kind = "upgrade"
			existing["rank"] = requested_rank
			next_facilities[existing_id] = existing
		else:
			action_kind = "repair"
			repaired_amount = mini(int(region.get("damage_taken", 0)), _hp_for_rank(requested_rank))
			region["damage_taken"] = maxi(0, int(region.get("damage_taken", 0)) - repaired_amount)
	region["revision"] = int(region.get("revision", 0)) + 1
	next_regions[region_id] = region
	var next_revision := _revision + 1
	var next_receipt_sequence := _receipt_sequence + 1
	var after := _derived_region_snapshot_from_state(region_id, next_regions, next_facilities, next_facility_by_slot)
	var lifecycle_changed := str(before.get("lifecycle_state", "")) != str(after.get("lifecycle_state", ""))
	var facility_after: Dictionary = (next_facilities[facility_id] as Dictionary).duplicate(true) if next_facilities.has(facility_id) else {}
	var owner_binding := _facility_owner_binding({
		"transaction_id": transaction_id,
		"intent_fingerprint": intent_fingerprint,
		"action_kind": action_kind,
		"region_id": region_id,
		"slot_id": target_slot_id,
		"facility_id": facility_id,
		"facility_type": facility_type,
		"industry_id": industry_id,
		"owner_kind": owner_kind,
		"owner_player_index": owner_player_index,
		"generation": int(facility_after.get("generation", 0)),
		"controller_revision_before": _revision,
		"controller_revision_after": next_revision,
		"region_revision_before": int((preimage.get("region_before", {}) as Dictionary).get("revision", 0)),
		"region_revision_after": int(region.get("revision", 0)),
		"receipt_sequence": next_receipt_sequence,
	})
	var owner_binding_fingerprint := _stable_fingerprint(owner_binding)
	var receipt := {
		"receipt_kind": "facility_action",
		"facility_action_lifecycle_version": FACILITY_ACTION_LIFECYCLE_VERSION,
		"transaction_id": transaction_id,
		"committed": true,
		"reason": "committed",
		"reason_code": "facility_action_committed",
		"action_kind": action_kind,
		"region_id": region_id,
		"slot_id": target_slot_id,
		"facility_id": facility_id,
		"facility_type": facility_type,
		"industry_id": industry_id,
		"owner_kind": owner_kind,
		"owner_player_index": owner_player_index,
		"old_rank": old_rank,
		"new_rank": requested_rank,
		"repaired_amount": repaired_amount,
		"max_hp_before": int(before.get("derived_max_hp", 0)),
		"max_hp_after": int(after.get("derived_max_hp", 0)),
		"current_hp_before": int(before.get("derived_current_hp", 0)),
		"current_hp_after": int(after.get("derived_current_hp", 0)),
		"lifecycle_changed": lifecycle_changed,
		"lifecycle_state": str(after.get("lifecycle_state", "")),
		"revision": next_revision,
		"receipt_sequence": next_receipt_sequence,
		"intent_fingerprint": intent_fingerprint,
		"owner_binding": owner_binding.duplicate(true),
		"owner_binding_fingerprint": owner_binding_fingerprint,
		"rollback_open": true,
		"rolled_back": false,
		"finalized": false,
		"post_commit_intents": _post_commit_intents(region_id, lifecycle_changed),
	}
	var lifecycle_record := {
		"facility_action_lifecycle_version": FACILITY_ACTION_LIFECYCLE_VERSION,
		"transaction_id": transaction_id,
		"intent_fingerprint": intent_fingerprint,
		"state": "applied",
		"rollback_open": true,
		"owner_binding": owner_binding.duplicate(true),
		"owner_binding_fingerprint": owner_binding_fingerprint,
		"preimage": preimage.duplicate(true),
		"postimage": {
			"region_after": region.duplicate(true),
			"facility_after": facility_after,
			"slot_mapping_after": facility_id,
			"slot_generation_after": int(next_slot_generations.get(target_slot_id, 0)),
			"controller_revision_after": next_revision,
		},
		"original_receipt": receipt.duplicate(true),
		"terminal_receipt": {},
	}
	next_receipts[transaction_id] = receipt.duplicate(true)
	next_lifecycles[transaction_id] = lifecycle_record
	_swap_facility_action_state(next_regions, next_facilities, next_facility_by_slot, next_slot_generations, next_receipts, next_lifecycles, next_revision, next_receipt_sequence)
	_emit_receipt(receipt, lifecycle_changed)
	return receipt.duplicate(true)


func rollback_facility_action(receipt_or_transaction: Variant) -> Dictionary:
	var input := _facility_action_input(receipt_or_transaction)
	var normalized_id := str(input.get("transaction_id", ""))
	var provided_receipt: Dictionary = input.get("receipt", {}) if input.get("receipt", {}) is Dictionary else {}
	if not _configured:
		return _facility_rollback_failure(normalized_id, "controller_not_configured")
	if normalized_id.is_empty():
		return _facility_rollback_failure(normalized_id, "transaction_id_missing")
	if not _facility_action_lifecycles.has(normalized_id):
		return _facility_rollback_failure(normalized_id, "facility_action_transaction_missing")
	var lifecycle_record: Dictionary = (_facility_action_lifecycles[normalized_id] as Dictionary).duplicate(true)
	var lifecycle_error := _facility_lifecycle_record_error(lifecycle_record)
	if not lifecycle_error.is_empty():
		return _facility_rollback_failure(normalized_id, lifecycle_error)
	var lifecycle_state := str(lifecycle_record.get("state", ""))
	if lifecycle_state == "rolled_back":
		return _terminal_facility_replay(lifecycle_record)
	if lifecycle_state == "finalized" or not bool(lifecycle_record.get("rollback_open", false)):
		return _facility_rollback_failure(normalized_id, "facility_action_rollback_closed", true)
	var binding_error := _facility_receipt_binding_error(provided_receipt, lifecycle_record)
	if not binding_error.is_empty():
		return _facility_rollback_failure(normalized_id, binding_error)
	var current_state_error := _facility_current_state_error(lifecycle_record, _regions, _facilities, _facility_by_slot, _slot_generations, _revision)
	if not current_state_error.is_empty():
		return _facility_rollback_failure(normalized_id, current_state_error)
	var preimage_error := _facility_preimage_error(lifecycle_record)
	if not preimage_error.is_empty():
		return _facility_rollback_failure(normalized_id, preimage_error)

	var owner_binding: Dictionary = lifecycle_record.get("owner_binding", {}) as Dictionary
	var preimage: Dictionary = lifecycle_record.get("preimage", {}) as Dictionary
	var postimage: Dictionary = lifecycle_record.get("postimage", {}) as Dictionary
	var original_receipt: Dictionary = lifecycle_record.get("original_receipt", {}) as Dictionary
	var region_id := str(owner_binding.get("region_id", ""))
	var target_slot_id := str(owner_binding.get("slot_id", ""))
	var facility_id_after := str(owner_binding.get("facility_id", ""))
	var next_regions := _regions.duplicate(true)
	var next_facilities := _facilities.duplicate(true)
	var next_facility_by_slot := _facility_by_slot.duplicate(true)
	var next_slot_generations := _slot_generations.duplicate(true)
	var next_receipts := _transaction_receipts.duplicate(true)
	var next_lifecycles := _facility_action_lifecycles.duplicate(true)
	var current_region: Dictionary = (next_regions[region_id] as Dictionary).duplicate(true)
	var before_rollback := _derived_region_snapshot_from_state(region_id, next_regions, next_facilities, next_facility_by_slot)
	next_facilities.erase(facility_id_after)
	next_facility_by_slot.erase(target_slot_id)
	if bool(preimage.get("facility_before_present", false)):
		var facility_before: Dictionary = (preimage.get("facility_before", {}) as Dictionary).duplicate(true)
		next_facilities[str(facility_before.get("facility_id", ""))] = facility_before
	if bool(preimage.get("slot_mapping_before_present", false)):
		next_facility_by_slot[target_slot_id] = str(preimage.get("slot_mapping_before", ""))
	if bool(preimage.get("slot_generation_before_present", false)):
		next_slot_generations[target_slot_id] = int(preimage.get("slot_generation_before", 0))
	else:
		next_slot_generations.erase(target_slot_id)
	var restored_region: Dictionary = (preimage.get("region_before", {}) as Dictionary).duplicate(true)
	restored_region["revision"] = int(current_region.get("revision", 0)) + 1
	next_regions[region_id] = restored_region
	var next_revision := _revision + 1
	var next_receipt_sequence := _receipt_sequence + 1
	var after_rollback := _derived_region_snapshot_from_state(region_id, next_regions, next_facilities, next_facility_by_slot)
	var lifecycle_changed := str(before_rollback.get("lifecycle_state", "")) != str(after_rollback.get("lifecycle_state", ""))
	var receipt := {
		"receipt_kind": "facility_action_rollback",
		"facility_action_lifecycle_version": FACILITY_ACTION_LIFECYCLE_VERSION,
		"transaction_id": normalized_id,
		"committed": false,
		"rolled_back": true,
		"finalized": false,
		"rollback_open": false,
		"duplicate": false,
		"reason": "rolled_back",
		"reason_code": "facility_action_rolled_back",
		"action_kind": str(owner_binding.get("action_kind", "")),
		"region_id": region_id,
		"slot_id": target_slot_id,
		"facility_id": facility_id_after,
		"lifecycle_changed": lifecycle_changed,
		"lifecycle_state": str(after_rollback.get("lifecycle_state", "")),
		"revision": next_revision,
		"receipt_sequence": next_receipt_sequence,
		"original_receipt_sequence": int(original_receipt.get("receipt_sequence", 0)),
		"owner_binding": owner_binding.duplicate(true),
		"owner_binding_fingerprint": str(lifecycle_record.get("owner_binding_fingerprint", "")),
		"post_commit_intents": _post_commit_intents(region_id, lifecycle_changed),
	}
	lifecycle_record["state"] = "rolled_back"
	lifecycle_record["rollback_open"] = false
	lifecycle_record["preimage"] = {}
	lifecycle_record["preimage_cleared"] = true
	lifecycle_record["terminal_receipt"] = receipt.duplicate(true)
	lifecycle_record["terminal_revision"] = next_revision
	lifecycle_record["terminal_receipt_sequence"] = next_receipt_sequence
	next_receipts[normalized_id] = receipt.duplicate(true)
	next_lifecycles[normalized_id] = lifecycle_record
	_swap_facility_action_state(next_regions, next_facilities, next_facility_by_slot, next_slot_generations, next_receipts, next_lifecycles, next_revision, next_receipt_sequence)
	_emit_receipt(receipt, lifecycle_changed)
	facility_action_rolled_back.emit(receipt.duplicate(true))
	return receipt.duplicate(true)


func finalize_facility_action(receipt_or_transaction: Variant) -> Dictionary:
	var input := _facility_action_input(receipt_or_transaction)
	var transaction_id := str(input.get("transaction_id", ""))
	var provided_receipt: Dictionary = input.get("receipt", {}) if input.get("receipt", {}) is Dictionary else {}
	if not _configured:
		return _facility_finalize_failure(transaction_id, "controller_not_configured")
	if transaction_id.is_empty():
		return _facility_finalize_failure(transaction_id, "transaction_id_missing")
	if not _facility_action_lifecycles.has(transaction_id):
		return _facility_finalize_failure(transaction_id, "facility_action_transaction_missing")
	var lifecycle_record: Dictionary = (_facility_action_lifecycles[transaction_id] as Dictionary).duplicate(true)
	var lifecycle_error := _facility_lifecycle_record_error(lifecycle_record)
	if not lifecycle_error.is_empty():
		return _facility_finalize_failure(transaction_id, lifecycle_error)
	var lifecycle_state := str(lifecycle_record.get("state", ""))
	if lifecycle_state == "finalized":
		return _terminal_facility_replay(lifecycle_record)
	if lifecycle_state == "rolled_back":
		return _facility_finalize_failure(transaction_id, "facility_action_finalize_after_rollback", true)
	var binding_error := _facility_receipt_binding_error(provided_receipt, lifecycle_record)
	if not binding_error.is_empty():
		return _facility_finalize_failure(transaction_id, binding_error)
	var current_state_error := _facility_current_state_error(lifecycle_record, _regions, _facilities, _facility_by_slot, _slot_generations, _revision)
	if not current_state_error.is_empty():
		return _facility_finalize_failure(transaction_id, current_state_error)
	var preimage_error := _facility_preimage_error(lifecycle_record)
	if not preimage_error.is_empty():
		return _facility_finalize_failure(transaction_id, preimage_error)
	var owner_binding: Dictionary = lifecycle_record.get("owner_binding", {}) as Dictionary
	var next_receipt_sequence := _receipt_sequence + 1
	var receipt := {
		"receipt_kind": "facility_action_finalize",
		"facility_action_lifecycle_version": FACILITY_ACTION_LIFECYCLE_VERSION,
		"transaction_id": transaction_id,
		"committed": true,
		"rolled_back": false,
		"finalized": true,
		"rollback_open": false,
		"duplicate": false,
		"reason": "finalized",
		"reason_code": "facility_action_finalized",
		"action_kind": str(owner_binding.get("action_kind", "")),
		"region_id": str(owner_binding.get("region_id", "")),
		"slot_id": str(owner_binding.get("slot_id", "")),
		"facility_id": str(owner_binding.get("facility_id", "")),
		"revision": _revision,
		"receipt_sequence": next_receipt_sequence,
		"original_receipt_sequence": int((lifecycle_record.get("original_receipt", {}) as Dictionary).get("receipt_sequence", 0)),
		"owner_binding": owner_binding.duplicate(true),
		"owner_binding_fingerprint": str(lifecycle_record.get("owner_binding_fingerprint", "")),
		"post_commit_intents": [],
	}
	lifecycle_record["state"] = "finalized"
	lifecycle_record["rollback_open"] = false
	lifecycle_record["preimage"] = {}
	lifecycle_record["preimage_cleared"] = true
	lifecycle_record["terminal_receipt"] = receipt.duplicate(true)
	lifecycle_record["terminal_revision"] = _revision
	lifecycle_record["terminal_receipt_sequence"] = next_receipt_sequence
	var next_receipts := _transaction_receipts.duplicate(true)
	var next_lifecycles := _facility_action_lifecycles.duplicate(true)
	next_receipts[transaction_id] = receipt.duplicate(true)
	next_lifecycles[transaction_id] = lifecycle_record
	_swap_facility_action_state(
		_regions.duplicate(true),
		_facilities.duplicate(true),
		_facility_by_slot.duplicate(true),
		_slot_generations.duplicate(true),
		next_receipts,
		next_lifecycles,
		_revision,
		next_receipt_sequence
	)
	_emit_receipt(receipt, false)
	facility_action_finalized.emit(receipt.duplicate(true))
	return receipt.duplicate(true)


func facility_rollback_atomic_ready() -> bool:
	if not _configured or FACILITY_ACTION_LIFECYCLE_VERSION < 2:
		return false
	for method_name in [
		"apply_facility_action",
		"rollback_facility_action",
		"finalize_facility_action",
		"facility_action_checkpoint_status",
		"to_save_data",
		"apply_save_data",
	]:
		if not has_method(method_name):
			return false
	return bool(facility_action_checkpoint_status().get("can_checkpoint", false))


func facility_action_checkpoint_status() -> Dictionary:
	var integrity := _facility_lifecycle_integrity_report()
	var pending_ids: Array = []
	var transaction_ids: Array = _facility_action_lifecycles.keys()
	transaction_ids.sort()
	for transaction_id_variant in transaction_ids:
		var transaction_id := str(transaction_id_variant)
		var record: Dictionary = _facility_action_lifecycles.get(transaction_id, {}) if _facility_action_lifecycles.get(transaction_id, {}) is Dictionary else {}
		if str(record.get("state", "")) == "applied":
			pending_ids.append(transaction_id)
	var can_checkpoint := bool(integrity.get("valid", false)) and pending_ids.is_empty()
	return {
		"can_checkpoint": can_checkpoint,
		"reason_code": "facility_action_checkpoint_ready" if can_checkpoint else "facility_action_lifecycle_pending_or_invalid",
		"pending_count": pending_ids.size(),
		"pending_transaction_ids": pending_ids,
		"journal_valid": bool(integrity.get("valid", false)),
	}


func facility_action_capabilities() -> Dictionary:
	var integrity := _facility_lifecycle_integrity_report()
	return {
		"ruleset_id": RULESET_ID,
		"state_version": SAVE_VERSION,
		"facility_action_lifecycle_version": FACILITY_ACTION_LIFECYCLE_VERSION,
		"apply": has_method("apply_facility_action"),
		"rollback": has_method("rollback_facility_action"),
		"finalize": has_method("finalize_facility_action"),
		"checkpoint": has_method("facility_action_checkpoint_status"),
		"save_load": has_method("to_save_data") and has_method("apply_save_data"),
		"exact_once": true,
		"copy_swap": true,
		"journal_valid": bool(integrity.get("valid", false)),
		"production_ready": facility_rollback_atomic_ready(),
	}


func facility_action_lifecycle_snapshot(transaction_id := "") -> Dictionary:
	var normalized_id := transaction_id.strip_edges()
	if not normalized_id.is_empty():
		return (_facility_action_lifecycles.get(normalized_id, {}) as Dictionary).duplicate(true)
	return _facility_action_lifecycles.duplicate(true)


func apply_unit_damage(request: Dictionary) -> Dictionary:
	var transaction_id := str(request.get("transaction_id", "")).strip_edges()
	var replay := _replay_receipt(transaction_id)
	if not replay.is_empty():
		return replay
	var common_error := _request_error(transaction_id, request)
	if not common_error.is_empty():
		return _remember_receipt(transaction_id, _failure_receipt("unit_damage", transaction_id, common_error))
	var source_kind := str(request.get("source_kind", ""))
	if not DAMAGE_SOURCE_KINDS.has(source_kind):
		return _remember_receipt(transaction_id, _failure_receipt("unit_damage", transaction_id, "damage_source_not_authorized"))
	var source_entity_id := str(request.get("source_entity_id", "")).strip_edges()
	if source_entity_id.is_empty():
		return _remember_receipt(transaction_id, _failure_receipt("unit_damage", transaction_id, "source_entity_id_missing"))
	var region_id := str(request.get("region_id", ""))
	if not _regions.has(region_id):
		return _remember_receipt(transaction_id, _failure_receipt("unit_damage", transaction_id, "region_not_found"))
	var amount := int(request.get("amount", 0))
	if amount <= 0:
		return _remember_receipt(transaction_id, _failure_receipt("unit_damage", transaction_id, "damage_amount_invalid"))
	var before := _derived_region_snapshot(region_id)
	var current_hp := int(before.get("derived_current_hp", 0))
	if current_hp <= 0:
		return _remember_receipt(transaction_id, _failure_receipt("unit_damage", transaction_id, "region_has_no_damageable_infrastructure"))
	var applied := mini(amount, current_hp)
	var region: Dictionary = (_regions[region_id] as Dictionary).duplicate(true)
	region["damage_taken"] = int(region.get("damage_taken", 0)) + applied
	var ruined := int(region.get("damage_taken", 0)) >= int(before.get("derived_max_hp", 0))
	var destroyed_facility_ids: Array = []
	if ruined:
		destroyed_facility_ids = _tombstone_region_facilities(region_id, float(request.get("occurred_at", 0.0)))
		region["damage_taken"] = 0
		region["lifecycle_state"] = "ruined"
		region["generation"] = int(region.get("generation", 1)) + 1
	region["revision"] = int(region.get("revision", 0)) + 1
	_regions[region_id] = region
	_revision += 1
	var after := _derived_region_snapshot(region_id)
	var receipt := {
		"receipt_kind": "unit_damage",
		"transaction_id": transaction_id,
		"committed": true,
		"reason": "committed",
		"source_kind": source_kind,
		"source_entity_id": source_entity_id,
		"region_id": region_id,
		"requested_damage": amount,
		"applied_damage": applied,
		"max_hp_before": int(before.get("derived_max_hp", 0)),
		"current_hp_before": current_hp,
		"current_hp_after": int(after.get("derived_current_hp", 0)),
		"damage_taken_after": int(after.get("damage_taken", 0)),
		"region_ruined": ruined,
		"destroyed_facility_ids": destroyed_facility_ids,
		"lifecycle_changed": ruined,
		"lifecycle_state": str(after.get("lifecycle_state", "")),
		"revision": _revision,
		"post_commit_intents": _post_commit_intents(region_id, ruined),
	}
	return _commit_receipt(transaction_id, receipt, ruined)


func apply_weather_damage(request: Dictionary) -> Dictionary:
	var transaction_id := str(request.get("transaction_id", "")).strip_edges()
	var replay := _replay_receipt(transaction_id)
	if not replay.is_empty():
		return replay
	var common_error := _request_error(transaction_id, request)
	if not common_error.is_empty():
		return _remember_receipt(transaction_id, _failure_receipt("weather_damage", transaction_id, common_error))
	var source_event_id := int(request.get("source_event_id", 0))
	if source_event_id <= 0:
		return _remember_receipt(transaction_id, _failure_receipt("weather_damage", transaction_id, "weather_event_id_missing"))
	var region_id := str(request.get("region_id", ""))
	if not _regions.has(region_id):
		return _remember_receipt(transaction_id, _failure_receipt("weather_damage", transaction_id, "region_not_found"))
	var amount := int(request.get("amount", 0))
	if amount <= 0:
		return _remember_receipt(transaction_id, _failure_receipt("weather_damage", transaction_id, "damage_amount_invalid"))
	var before := _derived_region_snapshot(region_id)
	var current_hp := int(before.get("derived_current_hp", 0))
	if current_hp <= 0:
		return _commit_receipt(transaction_id, {
			"receipt_kind": "weather_damage",
			"transaction_id": transaction_id,
			"committed": true,
			"reason": "no_damageable_infrastructure",
			"reason_code": "weather_damage_no_infrastructure",
			"source_kind": "weather",
			"source_event_id": source_event_id,
			"region_id": region_id,
			"requested_damage": amount,
			"applied_damage": 0,
			"accounted_total": maxi(0, int(request.get("accounted_total", 0))),
			"max_hp_before": int(before.get("derived_max_hp", 0)),
			"current_hp_before": 0,
			"current_hp_after": 0,
			"damage_taken_after": int(before.get("damage_taken", 0)),
			"region_ruined": str(before.get("lifecycle_state", "")) == "ruined",
			"destroyed_facility_ids": [],
			"lifecycle_changed": false,
			"lifecycle_state": str(before.get("lifecycle_state", "")),
			"revision": _revision,
			"post_commit_intents": [],
		}, false)
	var applied := mini(amount, maxi(0, current_hp - 1))
	if applied > 0:
		var region: Dictionary = (_regions[region_id] as Dictionary).duplicate(true)
		region["damage_taken"] = int(region.get("damage_taken", 0)) + applied
		region["revision"] = int(region.get("revision", 0)) + 1
		_regions[region_id] = region
		_revision += 1
	var after := _derived_region_snapshot(region_id)
	var receipt := {
		"receipt_kind": "weather_damage",
		"transaction_id": transaction_id,
		"committed": true,
		"reason": "committed" if applied > 0 else "nonlethal_floor_preserved",
		"reason_code": "weather_damage_committed" if applied > 0 else "weather_damage_nonlethal_floor",
		"source_kind": "weather",
		"source_event_id": source_event_id,
		"region_id": region_id,
		"requested_damage": amount,
		"applied_damage": applied,
		"accounted_total": maxi(0, int(request.get("accounted_total", 0))),
		"max_hp_before": int(before.get("derived_max_hp", 0)),
		"current_hp_before": current_hp,
		"current_hp_after": int(after.get("derived_current_hp", 0)),
		"damage_taken_after": int(after.get("damage_taken", 0)),
		"region_ruined": false,
		"destroyed_facility_ids": [],
		"lifecycle_changed": false,
		"lifecycle_state": str(after.get("lifecycle_state", "")),
		"revision": _revision,
		"post_commit_intents": _post_commit_intents(region_id, false) if applied > 0 else [],
	}
	return _commit_receipt(transaction_id, receipt, false)


func apply_repair(request: Dictionary) -> Dictionary:
	var transaction_id := str(request.get("transaction_id", "")).strip_edges()
	var replay := _replay_receipt(transaction_id)
	if not replay.is_empty():
		return replay
	var common_error := _request_error(transaction_id, request)
	if not common_error.is_empty():
		return _remember_receipt(transaction_id, _failure_receipt("region_repair", transaction_id, common_error))
	var source_kind := str(request.get("source_kind", ""))
	if not REPAIR_SOURCE_KINDS.has(source_kind):
		return _remember_receipt(transaction_id, _failure_receipt("region_repair", transaction_id, "repair_source_not_authorized"))
	var region_id := str(request.get("region_id", ""))
	if not _regions.has(region_id):
		return _remember_receipt(transaction_id, _failure_receipt("region_repair", transaction_id, "region_not_found"))
	var amount := int(request.get("amount", 0))
	if amount <= 0:
		return _remember_receipt(transaction_id, _failure_receipt("region_repair", transaction_id, "repair_amount_invalid"))
	var region: Dictionary = (_regions[region_id] as Dictionary).duplicate(true)
	var before_damage := int(region.get("damage_taken", 0))
	if before_damage <= 0 or str(region.get("lifecycle_state", "")) == "ruined":
		return _remember_receipt(transaction_id, _failure_receipt("region_repair", transaction_id, "region_not_repairable"))
	var applied := mini(amount, before_damage)
	region["damage_taken"] = before_damage - applied
	region["revision"] = int(region.get("revision", 0)) + 1
	_regions[region_id] = region
	_revision += 1
	var after := _derived_region_snapshot(region_id)
	var receipt := {
		"receipt_kind": "region_repair",
		"transaction_id": transaction_id,
		"committed": true,
		"reason": "committed",
		"source_kind": source_kind,
		"source_entity_id": str(request.get("source_entity_id", "")),
		"region_id": region_id,
		"requested_repair": amount,
		"applied_repair": applied,
		"damage_taken_after": int(after.get("damage_taken", 0)),
		"current_hp_after": int(after.get("derived_current_hp", 0)),
		"lifecycle_changed": false,
		"lifecycle_state": str(after.get("lifecycle_state", "")),
		"revision": _revision,
		"post_commit_intents": _post_commit_intents(region_id, false),
	}
	return _commit_receipt(transaction_id, receipt, false)


func region_state_snapshot(region_id: String) -> Dictionary:
	if not _regions.has(region_id):
		return {}
	return (_regions[region_id] as Dictionary).duplicate(true)


func region_snapshot(region_id: String) -> Dictionary:
	return _derived_region_snapshot(region_id)


func regions_snapshot() -> Array:
	var result: Array = []
	var region_ids: Array = _regions.keys()
	region_ids.sort()
	for region_id_variant in region_ids:
		result.append(_derived_region_snapshot(str(region_id_variant)))
	return result


func facilities_snapshot(include_tombstones := false) -> Array:
	var result: Array = []
	var facility_ids: Array = _facilities.keys()
	facility_ids.sort()
	for facility_id_variant in facility_ids:
		result.append((_facilities[facility_id_variant] as Dictionary).duplicate(true))
	if include_tombstones:
		for tombstone_variant in _facility_tombstones:
			result.append((tombstone_variant as Dictionary).duplicate(true))
	return result


func to_save_data() -> Dictionary:
	var region_records: Array = []
	var region_ids: Array = _regions.keys()
	region_ids.sort()
	for region_id_variant in region_ids:
		region_records.append((_regions[region_id_variant] as Dictionary).duplicate(true))
	var transaction_ids: Array = _transaction_receipts.keys()
	transaction_ids.sort()
	var rolled_back_facility_action_transaction_ids: Array = []
	var finalized_facility_action_transaction_ids: Array = []
	for transaction_id_variant in _facility_action_lifecycles.keys():
		var transaction_id := str(transaction_id_variant)
		var lifecycle: Dictionary = _facility_action_lifecycles.get(transaction_id, {}) as Dictionary
		match str(lifecycle.get("state", "")):
			"rolled_back":
				rolled_back_facility_action_transaction_ids.append(transaction_id)
			"finalized":
				finalized_facility_action_transaction_ids.append(transaction_id)
	rolled_back_facility_action_transaction_ids.sort()
	finalized_facility_action_transaction_ids.sort()
	return {
		"state_version": SAVE_VERSION,
		"ruleset_id": RULESET_ID,
		"facility_action_lifecycle_version": FACILITY_ACTION_LIFECYCLE_VERSION,
		"revision": _revision,
		"receipt_sequence": _receipt_sequence,
		"regions": region_records,
		"facilities": facilities_snapshot(false),
		"facility_tombstones": _facility_tombstones.duplicate(true),
		"slot_generations": _slot_generations.duplicate(true),
		"transaction_receipts": _transaction_receipts.duplicate(true),
		"facility_action_lifecycles": _facility_action_lifecycles.duplicate(true),
		"processed_transaction_ids": transaction_ids,
		"rolled_back_facility_action_transaction_ids": rolled_back_facility_action_transaction_ids,
		"finalized_facility_action_transaction_ids": finalized_facility_action_transaction_ids,
	}


func apply_save_data(data: Dictionary) -> Dictionary:
	if not _configured:
		return {"applied": false, "reason": "controller_not_configured"}
	var prepared := _prepare_save_state(data)
	if not bool(prepared.get("valid", false)):
		return {"applied": false, "reason": str(prepared.get("reason", "save_invalid"))}
	_regions = (prepared.get("regions", {}) as Dictionary).duplicate(true)
	_facilities = (prepared.get("facilities", {}) as Dictionary).duplicate(true)
	_facility_by_slot = (prepared.get("facility_by_slot", {}) as Dictionary).duplicate(true)
	_slot_generations = (prepared.get("slot_generations", {}) as Dictionary).duplicate(true)
	_facility_tombstones = (prepared.get("facility_tombstones", []) as Array).duplicate(true)
	_transaction_receipts = (prepared.get("transaction_receipts", {}) as Dictionary).duplicate(true)
	_facility_action_lifecycles = (prepared.get("facility_action_lifecycles", {}) as Dictionary).duplicate(true)
	_revision = int(prepared.get("revision", 0))
	_receipt_sequence = int(prepared.get("receipt_sequence", 0))
	return {
		"applied": true,
		"region_count": _regions.size(),
		"facility_count": _facilities.size(),
		"facility_action_lifecycle_count": _facility_action_lifecycles.size(),
		"revision": _revision,
	}


func debug_snapshot() -> Dictionary:
	var lifecycle_integrity := _facility_lifecycle_integrity_report()
	var checkpoint := facility_action_checkpoint_status()
	return {
		"controller_ready": _configured,
		"ruleset_id": RULESET_ID,
		"state_version": SAVE_VERSION,
		"facility_action_lifecycle_version": FACILITY_ACTION_LIFECYCLE_VERSION,
		"runtime_owner": "RegionInfrastructureRuntimeController",
		"region_count": _regions.size(),
		"facility_count": _facilities.size(),
		"tombstone_count": _facility_tombstones.size(),
		"facility_action_lifecycle_count": _facility_action_lifecycles.size(),
		"facility_action_pending_count": int(lifecycle_integrity.get("pending_count", 0)),
		"facility_action_finalized_count": int(lifecycle_integrity.get("finalized_count", 0)),
		"facility_action_rolled_back_count": int(lifecycle_integrity.get("rolled_back_count", 0)),
		"facility_rollback_atomic_ready": facility_rollback_atomic_ready(),
		"facility_action_checkpoint": checkpoint,
		"facility_lifecycle_integrity": lifecycle_integrity,
		"revision": _revision,
		"facility_hp_contribution_by_rank": _rank_table_snapshot(),
		"regions": regions_snapshot(),
		"has_heat_state": false,
		"has_panic_state": false,
		"unit_only_damage": true,
		"pure_data": _is_pure_data(to_save_data()),
	}


func _derived_region_snapshot(region_id: String) -> Dictionary:
	return _derived_region_snapshot_from_state(region_id, _regions, _facilities, _facility_by_slot)


func _derived_region_snapshot_from_state(
	region_id: String,
	regions: Dictionary,
	facilities_by_id: Dictionary,
	facility_by_slot: Dictionary
) -> Dictionary:
	if not regions.has(region_id):
		return {}
	var result: Dictionary = (regions[region_id] as Dictionary).duplicate(true)
	var facilities: Array = []
	var derived_max_hp := 0
	for slot_id_variant in result.get("facility_slot_ids", []):
		var facility_id := str(facility_by_slot.get(str(slot_id_variant), ""))
		if facility_id.is_empty() or not facilities_by_id.has(facility_id):
			continue
		var facility: Dictionary = facilities_by_id[facility_id]
		if not bool(facility.get("active", false)):
			continue
		facilities.append(facility.duplicate(true))
		derived_max_hp += _hp_for_rank(int(facility.get("rank", 1)))
	var damage_taken := clampi(int(result.get("damage_taken", 0)), 0, derived_max_hp)
	var current_hp := maxi(0, derived_max_hp - damage_taken)
	result["facilities"] = facilities
	result["derived_max_hp"] = derived_max_hp
	result["derived_current_hp"] = current_hp
	result["integrity_basis_points"] = 10000 if derived_max_hp <= 0 else int(round(float(current_hp) * 10000.0 / float(derived_max_hp)))
	result["facility_count"] = facilities.size()
	return result


func _tombstone_region_facilities(region_id: String, destroyed_at: float) -> Array:
	var destroyed_ids: Array = []
	var active_ids: Array = _facilities.keys()
	for facility_id_variant in active_ids:
		var facility_id := str(facility_id_variant)
		var facility: Dictionary = _facilities[facility_id]
		if str(facility.get("region_id", "")) != region_id:
			continue
		destroyed_ids.append(facility_id)
		_facility_tombstones.append({
			"facility_id": facility_id,
			"slot_id": str(facility.get("slot_id", "")),
			"region_id": region_id,
			"generation": int(facility.get("generation", 1)),
			"destroyed_at": destroyed_at,
			"active": false,
		})
		_facility_by_slot.erase(str(facility.get("slot_id", "")))
		_facilities.erase(facility_id)
	return destroyed_ids


func _post_commit_intents(region_id: String, lifecycle_changed: bool) -> Array:
	var intents: Array = [
		{"intent_id": "region_snapshot_refresh", "region_id": region_id},
		{"intent_id": "route_rebuild", "region_id": region_id},
		{"intent_id": "commodity_flow_refresh", "region_id": region_id},
	]
	if lifecycle_changed:
		intents.append({"intent_id": "region_lifecycle_presentation", "region_id": region_id})
	return intents


func _commit_receipt(transaction_id: String, receipt: Dictionary, lifecycle_changed: bool) -> Dictionary:
	_receipt_sequence += 1
	receipt["receipt_sequence"] = _receipt_sequence
	var stored := _remember_receipt(transaction_id, receipt)
	_emit_receipt(stored, lifecycle_changed)
	return stored


func _emit_receipt(receipt: Dictionary, lifecycle_changed: bool) -> void:
	infrastructure_receipt_committed.emit(receipt.duplicate(true))
	if lifecycle_changed:
		region_lifecycle_changed.emit(receipt.duplicate(true))


func _remember_receipt(transaction_id: String, receipt: Dictionary) -> Dictionary:
	var stored := receipt.duplicate(true)
	if not transaction_id.is_empty():
		_transaction_receipts[transaction_id] = stored.duplicate(true)
	return stored


func _replay_receipt(transaction_id: String) -> Dictionary:
	if transaction_id.is_empty() or not _transaction_receipts.has(transaction_id):
		return {}
	var receipt: Dictionary = (_transaction_receipts[transaction_id] as Dictionary).duplicate(true)
	receipt["replayed"] = true
	return receipt


func _request_error(transaction_id: String, request: Dictionary) -> String:
	if not _configured:
		return "controller_not_configured"
	if transaction_id.is_empty():
		return "transaction_id_missing"
	if not _is_pure_data(request):
		return "request_not_pure_data"
	return ""


func _failure_receipt(receipt_kind: String, transaction_id: String, reason: String) -> Dictionary:
	return {
		"receipt_kind": receipt_kind,
		"transaction_id": transaction_id,
		"committed": false,
		"reason": reason,
		"reason_code": reason,
		"revision": _revision,
		"post_commit_intents": [],
	}


func _facility_rollback_failure(transaction_id: String, reason: String, closed := false) -> Dictionary:
	return {
		"receipt_kind": "facility_action_rollback",
		"facility_action_lifecycle_version": FACILITY_ACTION_LIFECYCLE_VERSION,
		"transaction_id": transaction_id,
		"committed": false,
		"rolled_back": false,
		"finalized": closed,
		"rollback_open": not closed,
		"duplicate": false,
		"reason": reason,
		"reason_code": reason,
		"revision": _revision,
		"post_commit_intents": [],
	}


func _facility_finalize_failure(transaction_id: String, reason: String, rolled_back := false) -> Dictionary:
	return {
		"receipt_kind": "facility_action_finalize",
		"facility_action_lifecycle_version": FACILITY_ACTION_LIFECYCLE_VERSION,
		"transaction_id": transaction_id,
		"committed": not rolled_back,
		"rolled_back": rolled_back,
		"finalized": false,
		"rollback_open": false if rolled_back else true,
		"duplicate": false,
		"reason": reason,
		"reason_code": reason,
		"revision": _revision,
		"post_commit_intents": [],
	}


func _facility_action_replay(transaction_id: String, intent_fingerprint: String) -> Dictionary:
	var lifecycle: Dictionary = _facility_action_lifecycles.get(transaction_id, {}) if _facility_action_lifecycles.get(transaction_id, {}) is Dictionary else {}
	if not lifecycle.is_empty() and str(lifecycle.get("intent_fingerprint", "")) != intent_fingerprint:
		return _failure_receipt("facility_action", transaction_id, "facility_action_transaction_binding_mismatch")
	var receipt: Dictionary = _transaction_receipts.get(transaction_id, {}) if _transaction_receipts.get(transaction_id, {}) is Dictionary else {}
	if receipt.is_empty():
		return _failure_receipt("facility_action", transaction_id, "facility_action_transaction_record_invalid")
	if lifecycle.is_empty() and str(receipt.get("intent_fingerprint", intent_fingerprint)) != intent_fingerprint:
		return _failure_receipt("facility_action", transaction_id, "facility_action_transaction_binding_mismatch")
	var replay := receipt.duplicate(true)
	replay["duplicate"] = true
	replay["replayed"] = true
	return replay


func _facility_intent_fingerprint(request: Dictionary) -> String:
	return _stable_fingerprint({
		"transaction_id": str(request.get("transaction_id", "")).strip_edges(),
		"region_id": str(request.get("region_id", "")),
		"owner_kind": str(request.get("owner_kind", "player")),
		"owner_player_index": int(request.get("owner_player_index", -1)),
		"facility_type": str(request.get("facility_type", "")),
		"industry_id": str(request.get("industry_id", "")),
		"rank": int(request.get("rank", 0)),
		"occurred_at": float(request.get("occurred_at", 0.0)),
	})


func _facility_owner_binding(source: Dictionary) -> Dictionary:
	return {
		"receipt_kind": "facility_action",
		"transaction_id": str(source.get("transaction_id", "")),
		"intent_fingerprint": str(source.get("intent_fingerprint", "")),
		"action_kind": str(source.get("action_kind", "")),
		"region_id": str(source.get("region_id", "")),
		"slot_id": str(source.get("slot_id", "")),
		"facility_id": str(source.get("facility_id", "")),
		"facility_type": str(source.get("facility_type", "")),
		"industry_id": str(source.get("industry_id", "")),
		"owner_kind": str(source.get("owner_kind", "")),
		"owner_player_index": int(source.get("owner_player_index", -1)),
		"generation": int(source.get("generation", 0)),
		"controller_revision_before": int(source.get("controller_revision_before", -1)),
		"controller_revision_after": int(source.get("controller_revision_after", -1)),
		"region_revision_before": int(source.get("region_revision_before", -1)),
		"region_revision_after": int(source.get("region_revision_after", -1)),
		"receipt_sequence": int(source.get("receipt_sequence", 0)),
	}


func _facility_action_input(value: Variant) -> Dictionary:
	if value is String or value is StringName:
		return {"transaction_id": str(value).strip_edges(), "receipt": {}}
	if not (value is Dictionary):
		return {"transaction_id": "", "receipt": {}}
	var receipt: Dictionary = (value as Dictionary).duplicate(true)
	if str(receipt.get("receipt_kind", "")) != "facility_action" and receipt.get("owner_receipt", null) is Dictionary:
		var nested: Dictionary = receipt.get("owner_receipt", {}) as Dictionary
		if str(nested.get("receipt_kind", "")) == "facility_action":
			receipt = nested.duplicate(true)
	return {"transaction_id": str(receipt.get("transaction_id", "")).strip_edges(), "receipt": receipt}


func _facility_lifecycle_record_error(record: Dictionary) -> String:
	if not _is_pure_data(record):
		return "facility_action_lifecycle_not_pure_data"
	if int(record.get("facility_action_lifecycle_version", -1)) != FACILITY_ACTION_LIFECYCLE_VERSION:
		return "facility_action_lifecycle_version_invalid"
	var transaction_id := str(record.get("transaction_id", "")).strip_edges()
	var state := str(record.get("state", ""))
	if transaction_id.is_empty() or not FACILITY_ACTION_STATES.has(state):
		return "facility_action_lifecycle_shape_invalid"
	var owner_binding: Dictionary = record.get("owner_binding", {}) if record.get("owner_binding", {}) is Dictionary else {}
	if owner_binding.is_empty() or str(owner_binding.get("receipt_kind", "")) != "facility_action" or str(owner_binding.get("transaction_id", "")) != transaction_id:
		return "facility_action_owner_binding_invalid"
	for key in ["intent_fingerprint", "action_kind", "region_id", "slot_id", "facility_id", "facility_type", "owner_kind"]:
		if str(owner_binding.get(key, "")).is_empty():
			return "facility_action_owner_binding_invalid"
	if str(record.get("owner_binding_fingerprint", "")) != _stable_fingerprint(owner_binding):
		return "facility_action_owner_binding_fingerprint_invalid"
	if str(record.get("intent_fingerprint", "")) != str(owner_binding.get("intent_fingerprint", "")):
		return "facility_action_intent_binding_invalid"
	var original_receipt: Dictionary = record.get("original_receipt", {}) if record.get("original_receipt", {}) is Dictionary else {}
	if original_receipt.is_empty() or str(original_receipt.get("receipt_kind", "")) != "facility_action" or not bool(original_receipt.get("committed", false)):
		return "facility_action_original_receipt_invalid"
	if str(original_receipt.get("transaction_id", "")) != transaction_id or str(original_receipt.get("owner_binding_fingerprint", "")) != str(record.get("owner_binding_fingerprint", "")):
		return "facility_action_original_receipt_binding_invalid"
	var rollback_open := bool(record.get("rollback_open", false))
	var preimage: Dictionary = record.get("preimage", {}) if record.get("preimage", {}) is Dictionary else {}
	var postimage: Dictionary = record.get("postimage", {}) if record.get("postimage", {}) is Dictionary else {}
	var terminal_receipt: Dictionary = record.get("terminal_receipt", {}) if record.get("terminal_receipt", {}) is Dictionary else {}
	if postimage.is_empty():
		return "facility_action_postimage_invalid"
	if state == "applied":
		if not rollback_open or preimage.is_empty() or not terminal_receipt.is_empty():
			return "facility_action_pending_lifecycle_invalid"
	else:
		if rollback_open or not preimage.is_empty() or terminal_receipt.is_empty():
			return "facility_action_terminal_lifecycle_invalid"
		var expected_kind := "facility_action_rollback" if state == "rolled_back" else "facility_action_finalize"
		if str(terminal_receipt.get("receipt_kind", "")) != expected_kind or str(terminal_receipt.get("transaction_id", "")) != transaction_id:
			return "facility_action_terminal_receipt_invalid"
	return ""


func _facility_receipt_binding_error(provided_receipt: Dictionary, lifecycle_record: Dictionary) -> String:
	if provided_receipt.is_empty():
		return ""
	if str(provided_receipt.get("receipt_kind", "")) != "facility_action" or not bool(provided_receipt.get("committed", false)):
		return "facility_action_receipt_kind_invalid"
	if str(provided_receipt.get("transaction_id", "")) != str(lifecycle_record.get("transaction_id", "")):
		return "facility_action_receipt_transaction_mismatch"
	if str(provided_receipt.get("owner_binding_fingerprint", "")) != str(lifecycle_record.get("owner_binding_fingerprint", "")):
		return "facility_action_receipt_binding_mismatch"
	var provided_binding: Dictionary = provided_receipt.get("owner_binding", {}) if provided_receipt.get("owner_binding", {}) is Dictionary else {}
	var expected_binding: Dictionary = lifecycle_record.get("owner_binding", {}) as Dictionary
	if provided_binding.is_empty() or not _values_match(provided_binding, expected_binding):
		return "facility_action_receipt_binding_mismatch"
	return ""


func _facility_current_state_error(
	lifecycle_record: Dictionary,
	regions: Dictionary,
	facilities: Dictionary,
	facility_by_slot: Dictionary,
	slot_generations: Dictionary,
	controller_revision: int
) -> String:
	var owner_binding: Dictionary = lifecycle_record.get("owner_binding", {}) as Dictionary
	var postimage: Dictionary = lifecycle_record.get("postimage", {}) as Dictionary
	var region_id := str(owner_binding.get("region_id", ""))
	var target_slot_id := str(owner_binding.get("slot_id", ""))
	var facility_id := str(owner_binding.get("facility_id", ""))
	if controller_revision != int(postimage.get("controller_revision_after", -1)) or controller_revision != int(owner_binding.get("controller_revision_after", -1)):
		return "facility_action_controller_revision_changed"
	if not regions.has(region_id) or not _values_match(regions.get(region_id, {}), postimage.get("region_after", {})):
		return "facility_action_region_state_changed"
	if str(facility_by_slot.get(target_slot_id, "")) != str(postimage.get("slot_mapping_after", "")) or str(postimage.get("slot_mapping_after", "")) != facility_id:
		return "facility_action_slot_mapping_changed"
	if not facilities.has(facility_id) or not _values_match(facilities.get(facility_id, {}), postimage.get("facility_after", {})):
		return "facility_action_facility_state_changed"
	if int(slot_generations.get(target_slot_id, -1)) != int(postimage.get("slot_generation_after", -2)):
		return "facility_action_slot_generation_changed"
	return ""


func _facility_preimage_error(lifecycle_record: Dictionary) -> String:
	var owner_binding: Dictionary = lifecycle_record.get("owner_binding", {}) as Dictionary
	var preimage: Dictionary = lifecycle_record.get("preimage", {}) if lifecycle_record.get("preimage", {}) is Dictionary else {}
	if preimage.is_empty():
		return "facility_action_preimage_missing"
	var region_before: Dictionary = preimage.get("region_before", {}) if preimage.get("region_before", {}) is Dictionary else {}
	var region_id := str(owner_binding.get("region_id", ""))
	var target_slot_id := str(owner_binding.get("slot_id", ""))
	if region_before.is_empty() or str(region_before.get("region_id", "")) != region_id:
		return "facility_action_region_preimage_invalid"
	if int(preimage.get("controller_revision_before", -1)) != int(owner_binding.get("controller_revision_before", -2)):
		return "facility_action_controller_preimage_invalid"
	var facility_before_present := bool(preimage.get("facility_before_present", false))
	var mapping_before_present := bool(preimage.get("slot_mapping_before_present", false))
	var facility_before: Dictionary = preimage.get("facility_before", {}) if preimage.get("facility_before", {}) is Dictionary else {}
	var mapping_before := str(preimage.get("slot_mapping_before", ""))
	if facility_before_present != mapping_before_present:
		return "facility_action_slot_preimage_invalid"
	if facility_before_present:
		if facility_before.is_empty() or mapping_before.is_empty() or str(facility_before.get("facility_id", "")) != mapping_before:
			return "facility_action_facility_preimage_invalid"
		if str(facility_before.get("slot_id", "")) != target_slot_id or str(facility_before.get("region_id", "")) != region_id:
			return "facility_action_facility_preimage_invalid"
	elif not facility_before.is_empty() or not mapping_before.is_empty():
		return "facility_action_empty_preimage_invalid"
	var generation_before := int(preimage.get("slot_generation_before", 0))
	if bool(preimage.get("slot_generation_before_present", false)) and generation_before < 1:
		return "facility_action_generation_preimage_invalid"
	return ""


func _terminal_facility_replay(lifecycle_record: Dictionary) -> Dictionary:
	var receipt: Dictionary = lifecycle_record.get("terminal_receipt", {}) if lifecycle_record.get("terminal_receipt", {}) is Dictionary else {}
	if receipt.is_empty():
		var transaction_id := str(lifecycle_record.get("transaction_id", ""))
		return _failure_receipt("facility_action", transaction_id, "facility_action_terminal_receipt_missing")
	var replay := receipt.duplicate(true)
	replay["duplicate"] = true
	replay["replayed"] = true
	return replay


func _swap_facility_action_state(
	next_regions: Dictionary,
	next_facilities: Dictionary,
	next_facility_by_slot: Dictionary,
	next_slot_generations: Dictionary,
	next_receipts: Dictionary,
	next_lifecycles: Dictionary,
	next_revision: int,
	next_receipt_sequence: int
) -> void:
	_regions = next_regions
	_facilities = next_facilities
	_facility_by_slot = next_facility_by_slot
	_slot_generations = next_slot_generations
	_transaction_receipts = next_receipts
	_facility_action_lifecycles = next_lifecycles
	_revision = next_revision
	_receipt_sequence = next_receipt_sequence


func _facility_lifecycle_integrity_report() -> Dictionary:
	var errors: Array = []
	var pending_count := 0
	var rolled_back_count := 0
	var finalized_count := 0
	var transaction_ids: Array = _facility_action_lifecycles.keys()
	transaction_ids.sort()
	for transaction_id_variant in transaction_ids:
		var transaction_id := str(transaction_id_variant)
		var record: Dictionary = _facility_action_lifecycles.get(transaction_id, {}) if _facility_action_lifecycles.get(transaction_id, {}) is Dictionary else {}
		var error := _facility_lifecycle_record_error(record)
		if error.is_empty() and str(record.get("transaction_id", "")) != transaction_id:
			error = "facility_action_lifecycle_key_mismatch"
		if error.is_empty():
			var state := str(record.get("state", ""))
			match state:
				"applied":
					pending_count += 1
					error = _facility_current_state_error(record, _regions, _facilities, _facility_by_slot, _slot_generations, _revision)
				"rolled_back":
					rolled_back_count += 1
				"finalized":
					finalized_count += 1
		if error.is_empty():
			var expected_receipt: Dictionary = record.get("original_receipt", {}) if str(record.get("state", "")) == "applied" else record.get("terminal_receipt", {})
			if not _transaction_receipts.has(transaction_id) or not _values_match(_transaction_receipts.get(transaction_id, {}), expected_receipt):
				error = "facility_action_transaction_journal_mismatch"
		if not error.is_empty():
			errors.append({"transaction_id": transaction_id, "reason": error})
	return {
		"valid": errors.is_empty(),
		"record_count": transaction_ids.size(),
		"pending_count": pending_count,
		"rolled_back_count": rolled_back_count,
		"finalized_count": finalized_count,
		"errors": errors,
	}


func _prepare_save_state(data: Dictionary) -> Dictionary:
	if int(data.get("state_version", -1)) != SAVE_VERSION or str(data.get("ruleset_id", "")) != RULESET_ID:
		return {"valid": false, "reason": "save_header_invalid"}
	if not _is_pure_data(data):
		return {"valid": false, "reason": "save_not_pure_data"}
	if not (data.get("regions", null) is Array) or not (data.get("facilities", null) is Array):
		return {"valid": false, "reason": "save_world_shape_invalid"}
	var revision := int(data.get("revision", -1))
	var receipt_sequence := int(data.get("receipt_sequence", -1))
	if revision < 0 or receipt_sequence < 0:
		return {"valid": false, "reason": "save_revision_invalid"}

	var prepared_regions: Dictionary = {}
	var prepared_facilities: Dictionary = {}
	var prepared_by_slot: Dictionary = {}
	var region_records: Array = data.get("regions", []) as Array
	for region_variant in region_records:
		if not (region_variant is Dictionary):
			return {"valid": false, "reason": "region_record_invalid"}
		var region: Dictionary = (region_variant as Dictionary).duplicate(true)
		var region_id := str(region.get("region_id", "")).strip_edges()
		if region_id.is_empty() or prepared_regions.has(region_id) or region.has("max_hp") or region.has("panic") or region.has("heat"):
			return {"valid": false, "reason": "region_record_invalid"}
		if not (region.get("facility_slot_ids", null) is Array) or int(region.get("generation", 0)) < 1 or int(region.get("revision", 0)) < 1 or int(region.get("damage_taken", -1)) < 0:
			return {"valid": false, "reason": "region_record_invalid"}
		var saved_slots := _string_array(region.get("facility_slot_ids", []))
		var expected_slots := standard_slot_ids(region_id)
		if saved_slots.size() != expected_slots.size():
			return {"valid": false, "reason": "region_slot_catalog_invalid"}
		for expected_slot_variant in expected_slots:
			if not saved_slots.has(str(expected_slot_variant)):
				return {"valid": false, "reason": "region_slot_catalog_invalid"}
		prepared_regions[region_id] = region

	var facility_records: Array = data.get("facilities", []) as Array
	for facility_variant in facility_records:
		if not (facility_variant is Dictionary):
			return {"valid": false, "reason": "facility_record_invalid"}
		var facility: Dictionary = (facility_variant as Dictionary).duplicate(true)
		var facility_id := str(facility.get("facility_id", "")).strip_edges()
		var target_slot_id := str(facility.get("slot_id", "")).strip_edges()
		var region_id := str(facility.get("region_id", "")).strip_edges()
		var facility_type := str(facility.get("facility_type", ""))
		var industry_id := str(facility.get("industry_id", ""))
		var owner_kind := str(facility.get("owner_kind", ""))
		var owner_player_index := int(facility.get("owner_player_index", -1))
		var rank := int(facility.get("rank", 0))
		var generation := int(facility.get("generation", 0))
		if facility_id.is_empty() or target_slot_id.is_empty() or prepared_facilities.has(facility_id) or prepared_by_slot.has(target_slot_id):
			return {"valid": false, "reason": "facility_record_invalid"}
		if not prepared_regions.has(region_id) or facility.has("current_hp") or facility.has("damage") or not bool(facility.get("active", false)):
			return {"valid": false, "reason": "facility_record_invalid"}
		if not _facility_kind_valid(facility_type, industry_id) or target_slot_id != slot_id(region_id, facility_type, industry_id):
			return {"valid": false, "reason": "facility_record_invalid"}
		if not OWNER_KINDS.has(owner_kind) or (owner_kind == "player" and owner_player_index < 0) or (owner_kind == "neutral" and owner_player_index != -1):
			return {"valid": false, "reason": "facility_record_invalid"}
		if rank < 1 or rank > _maximum_rank or generation < 1 or facility_id != "%s::g%d" % [target_slot_id, generation]:
			return {"valid": false, "reason": "facility_record_invalid"}
		prepared_facilities[facility_id] = facility
		prepared_by_slot[target_slot_id] = facility_id

	if not (data.get("slot_generations", null) is Dictionary) or not (data.get("facility_tombstones", null) is Array):
		return {"valid": false, "reason": "facility_auxiliary_state_invalid"}
	var prepared_slot_generations := (data.get("slot_generations", {}) as Dictionary).duplicate(true)
	for slot_variant in prepared_slot_generations.keys():
		var slot_key := str(slot_variant)
		var generation := int(prepared_slot_generations[slot_variant])
		if slot_key.is_empty() or generation < 1:
			return {"valid": false, "reason": "slot_generation_record_invalid"}
	for facility_id_variant in prepared_facilities.keys():
		var facility: Dictionary = prepared_facilities[facility_id_variant]
		var target_slot_id := str(facility.get("slot_id", ""))
		if int(prepared_slot_generations.get(target_slot_id, 0)) < int(facility.get("generation", 0)):
			return {"valid": false, "reason": "slot_generation_record_invalid"}
	var prepared_tombstones: Array = (data.get("facility_tombstones", []) as Array).duplicate(true)
	for tombstone_variant in prepared_tombstones:
		if not (tombstone_variant is Dictionary):
			return {"valid": false, "reason": "facility_tombstone_invalid"}
		var tombstone: Dictionary = tombstone_variant
		if str(tombstone.get("facility_id", "")).is_empty() or str(tombstone.get("slot_id", "")).is_empty() or str(tombstone.get("region_id", "")).is_empty() or int(tombstone.get("generation", 0)) < 1:
			return {"valid": false, "reason": "facility_tombstone_invalid"}

	var prepared_receipts: Dictionary = {}
	var prepared_lifecycles: Dictionary = {}
	var has_atomic_lifecycle := data.has("facility_action_lifecycle_version") or data.has("facility_action_lifecycles") or data.has("transaction_receipts")
	if has_atomic_lifecycle:
		if int(data.get("facility_action_lifecycle_version", -1)) != FACILITY_ACTION_LIFECYCLE_VERSION:
			return {"valid": false, "reason": "facility_action_lifecycle_version_invalid"}
		if not (data.get("transaction_receipts", null) is Dictionary) or not (data.get("facility_action_lifecycles", null) is Dictionary):
			return {"valid": false, "reason": "facility_action_journal_shape_invalid"}
		prepared_receipts = (data.get("transaction_receipts", {}) as Dictionary).duplicate(true)
		prepared_lifecycles = (data.get("facility_action_lifecycles", {}) as Dictionary).duplicate(true)
		for transaction_id_variant in prepared_receipts.keys():
			var transaction_id := str(transaction_id_variant).strip_edges()
			var receipt_variant: Variant = prepared_receipts[transaction_id_variant]
			if transaction_id.is_empty() or not (receipt_variant is Dictionary):
				return {"valid": false, "reason": "transaction_receipt_record_invalid"}
			var receipt: Dictionary = receipt_variant
			if str(receipt.get("transaction_id", "")) != transaction_id:
				return {"valid": false, "reason": "transaction_receipt_binding_invalid"}
		for transaction_id_variant in prepared_lifecycles.keys():
			var transaction_id := str(transaction_id_variant).strip_edges()
			var lifecycle_variant: Variant = prepared_lifecycles[transaction_id_variant]
			if transaction_id.is_empty() or not (lifecycle_variant is Dictionary):
				return {"valid": false, "reason": "facility_action_lifecycle_record_invalid"}
			var lifecycle: Dictionary = lifecycle_variant
			var lifecycle_error := _facility_lifecycle_record_error(lifecycle)
			if not lifecycle_error.is_empty() or str(lifecycle.get("transaction_id", "")) != transaction_id:
				return {"valid": false, "reason": lifecycle_error if not lifecycle_error.is_empty() else "facility_action_lifecycle_key_mismatch"}
			var state := str(lifecycle.get("state", ""))
			var expected_receipt: Dictionary = lifecycle.get("original_receipt", {}) if state == "applied" else lifecycle.get("terminal_receipt", {})
			if not prepared_receipts.has(transaction_id) or not _values_match(prepared_receipts.get(transaction_id, {}), expected_receipt):
				return {"valid": false, "reason": "facility_action_transaction_journal_mismatch"}
			if state == "applied":
				var current_error := _facility_current_state_error(lifecycle, prepared_regions, prepared_facilities, prepared_by_slot, prepared_slot_generations, revision)
				if not current_error.is_empty():
					return {"valid": false, "reason": current_error}
				var preimage_error := _facility_preimage_error(lifecycle)
				if not preimage_error.is_empty():
					return {"valid": false, "reason": preimage_error}
		var processed_transaction_ids := _string_array(data.get("processed_transaction_ids", []))
		var receipt_ids: Array = prepared_receipts.keys()
		receipt_ids.sort()
		processed_transaction_ids.sort()
		if processed_transaction_ids != receipt_ids:
			return {"valid": false, "reason": "processed_transaction_index_mismatch"}
	else:
		var processed_transaction_ids := _string_array(data.get("processed_transaction_ids", []))
		var rolled_back_ids := _string_array(data.get("rolled_back_facility_action_transaction_ids", []))
		for transaction_id_variant in rolled_back_ids:
			if not processed_transaction_ids.has(transaction_id_variant):
				return {"valid": false, "reason": "rollback_transaction_record_invalid"}
		for transaction_id_variant in processed_transaction_ids:
			var transaction_id := str(transaction_id_variant)
			if rolled_back_ids.has(transaction_id):
				prepared_receipts[transaction_id] = {
					"receipt_kind": "facility_action_rollback",
					"transaction_id": transaction_id,
					"committed": false,
					"rolled_back": true,
					"finalized": false,
					"rollback_open": false,
					"reason": "restored_rolled_back_exact_once_guard",
					"reason_code": "restored_rolled_back_exact_once_guard",
				}
			else:
				prepared_receipts[transaction_id] = {
					"transaction_id": transaction_id,
					"committed": true,
					"finalized": true,
					"rollback_open": false,
					"reason": "restored_exact_once_guard",
					"reason_code": "restored_exact_once_guard",
				}

	var maximum_receipt_sequence := 0
	for receipt_variant in prepared_receipts.values():
		if receipt_variant is Dictionary:
			maximum_receipt_sequence = maxi(maximum_receipt_sequence, int((receipt_variant as Dictionary).get("receipt_sequence", 0)))
	if receipt_sequence < maximum_receipt_sequence:
		return {"valid": false, "reason": "receipt_sequence_regressed"}
	return {
		"valid": true,
		"regions": prepared_regions,
		"facilities": prepared_facilities,
		"facility_by_slot": prepared_by_slot,
		"slot_generations": prepared_slot_generations,
		"facility_tombstones": prepared_tombstones,
		"transaction_receipts": prepared_receipts,
		"facility_action_lifecycles": prepared_lifecycles,
		"revision": revision,
		"receipt_sequence": receipt_sequence,
	}


func _values_match(first: Variant, second: Variant) -> bool:
	return JSON.stringify(_canonicalize(first)) == JSON.stringify(_canonicalize(second))


func _stable_fingerprint(value: Variant) -> String:
	return str(hash(JSON.stringify(_canonicalize(value))))


func _canonicalize(value: Variant) -> Variant:
	if value is Dictionary:
		var source: Dictionary = value
		var keys: Array = source.keys()
		keys.sort_custom(func(first: Variant, second: Variant) -> bool: return str(first) < str(second))
		var normalized: Dictionary = {}
		for key_variant in keys:
			normalized[str(key_variant)] = _canonicalize(source[key_variant])
		return normalized
	if value is Array:
		var normalized_array: Array = []
		for item_variant in value:
			normalized_array.append(_canonicalize(item_variant))
		return normalized_array
	return value


func _facility_kind_valid(facility_type: String, industry_id: String) -> bool:
	if not FACILITY_TYPES.has(facility_type):
		return false
	if facility_type == "factory" or facility_type == "market" or facility_type == "warehouse":
		return INDUSTRY_IDS.has(industry_id)
	return industry_id.is_empty()


func _hp_for_rank(rank: int) -> int:
	return int(_hp_by_rank.get(clampi(rank, 1, _maximum_rank), 0))


func _parse_rank_table(source: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	var labels := ["I", "II", "III", "IV"]
	for index in range(labels.size()):
		var value := int(source.get(labels[index], 0))
		if value <= 0:
			return {}
		result[index + 1] = value
	return result


func _rank_table_snapshot() -> Dictionary:
	return {
		"I": int(_hp_by_rank.get(1, 0)),
		"II": int(_hp_by_rank.get(2, 0)),
		"III": int(_hp_by_rank.get(3, 0)),
		"IV": int(_hp_by_rank.get(4, 0)),
	}


func _string_array(value: Variant) -> Array:
	var result: Array = []
	if value is Array:
		for item in value:
			var text := str(item)
			if not text.is_empty() and not result.has(text):
				result.append(text)
	return result


func _is_pure_data(value: Variant) -> bool:
	if value == null or value is String or value is StringName or value is bool or value is int or value is float:
		return true
	if value is Array:
		for item in value:
			if not _is_pure_data(item):
				return false
		return true
	if value is Dictionary:
		for key in value:
			if not (key is String or key is StringName or key is int) or not _is_pure_data(value[key]):
				return false
		return true
	return false
