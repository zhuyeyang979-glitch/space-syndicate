extends RefCounted
class_name V075PublicActionBatchCore

const FacilityCore := preload(
	"res://scripts/v074/facility/v074_facility_runtime_core.gd"
)

const SCHEMA_VERSION := 1
const RULESET_ID := "v0.7.5"
const CONTRACT_ID := "v075.public_action_batch.core_authority.v1"
const MAX_ACTIONS_PER_PLAYER := 5
const ACTION_DOMAINS := ["facility", "monster", "military"]


static func lock_batch(
	batch_id: String,
	player_ids: Array,
	hidden_order: Array,
	player_local_queues: Dictionary,
	facility_slots: Array
) -> Dictionary:
	var players := _string_ids(player_ids)
	var order := _string_ids(hidden_order)
	if not _stable_id(batch_id) or players.is_empty():
		return {}
	if not _same_set(players, order) or not _exact_keys(player_local_queues, players):
		return {}

	var queues := {}
	var seen_action_ids := {}
	var facility_target_slots_at_batch_lock := {}
	for player_id in players:
		var queue_variant: Variant = player_local_queues.get(player_id)
		if not (queue_variant is Array):
			return {}
		var source_queue := queue_variant as Array
		if source_queue.size() > MAX_ACTIONS_PER_PLAYER:
			return {}
		var queue: Array = []
		for local_index in range(source_queue.size()):
			var action_variant: Variant = source_queue[local_index]
			if not (action_variant is Dictionary):
				return {}
			var action := (action_variant as Dictionary).duplicate(true)
			var action_id := str(action.get("action_id", ""))
			var domain := _action_domain(action)
			if (
				not _stable_id(action_id)
				or seen_action_ids.has(action_id)
				or str(action.get("actor_id", "")) != player_id
				or int(action.get("local_action_index", -1)) != local_index
				or domain not in ACTION_DOMAINS
				or not _pure_data(action)
			):
				return {}
			action["action_domain"] = domain
			seen_action_ids[action_id] = true
			queue.append(action)
			if domain == "facility":
				var target_slot := _facility_slot_snapshot(
					action,
					facility_slots
				)
				if target_slot.is_empty():
					return {}
				facility_target_slots_at_batch_lock[action_id] = target_slot
		queues[player_id] = queue

	var facility_queues := {}
	for player_id in players:
		facility_queues[player_id] = []

	var facility_state := FacilityCore.lock_batch(
		batch_id,
		players,
		order,
		facility_queues,
		facility_slots,
		true
	)
	if facility_state.is_empty():
		return {}
	var authority_queue := _build_authority_queue(order, queues)
	var public_queue: Array = []
	for queue_index in range(authority_queue.size()):
		var entry := authority_queue[queue_index] as Dictionary
		public_queue.append({
			"queue_index": queue_index,
			"anonymous_action_id": str(entry.get("anonymous_action_id", "")),
			"local_action_index": int(entry.get("local_action_index", -1)),
			"action_domain": str(entry.get("action_domain", "")),
			"resolution_status": "pending",
			"public_reason_code": "pending_anonymous_resolution",
		})
	var state := {
		"schema_version": SCHEMA_VERSION,
		"ruleset_id": RULESET_ID,
		"contract_id": CONTRACT_ID,
		"batch_id": batch_id,
		"revision": 1,
		"status": "resolved" if authority_queue.is_empty() else "resolution_ready",
		"player_ids": players,
		"frozen_hidden_order": order,
		"player_local_queues": queues,
		"authority_queue": authority_queue,
		"anonymous_global_queue": public_queue,
		"resolution_cursor": 0,
		"facility_substate": facility_state,
		"facility_target_slots_at_batch_lock": (
			facility_target_slots_at_batch_lock.duplicate(true)
		),
		"processed_action_ids": {},
		"resolution_receipts": [],
	}
	return _seal(state)


static func resolve_next(state: Dictionary) -> Dictionary:
	if not bool(validation_report(state).get("valid", false)):
		return {"accepted": false, "reason_code": "public_action_state_invalid"}
	return _resolve_next_validated(state, false)


static func resolve_next_authority_owned(state: Dictionary) -> Dictionary:
	# RuntimeOwner has sole custody of this state between strict lock/replace
	# boundaries. The transition and output are identical to resolve_next();
	# only the repeated full-tree input validation and deep copy are skipped.
	if not _authority_owned_state_header_valid(state):
		return {
			"accepted": false,
			"reason_code": "public_action_authority_state_invalid",
		}
	return _resolve_next_validated(state, true)


static func _resolve_next_validated(
	state: Dictionary,
	authority_owned: bool
) -> Dictionary:
	if str(state.get("status", "")) == "resolved":
		return {"accepted": false, "reason_code": "public_action_batch_resolved"}
	var queue := state.get("authority_queue", []) as Array
	var cursor := int(state.get("resolution_cursor", -1))
	if cursor < 0 or cursor >= queue.size():
		return {"accepted": false, "reason_code": "public_action_cursor_invalid"}
	var entry := queue[cursor] as Dictionary
	var action := entry.get("action", {}) as Dictionary
	var action_id := str(entry.get("action_id", ""))
	var processed := state.get("processed_action_ids", {}) as Dictionary
	if processed.has(action_id):
		var prior_index := int(processed.get(action_id, -1))
		var prior := state.get("resolution_receipts", []) as Array
		if prior_index >= 0 and prior_index < prior.size():
			return {
				"accepted": true,
				"reason_code": "public_action_exact_once_replay",
				"state": state.duplicate(not authority_owned),
				"receipt": (prior[prior_index] as Dictionary).duplicate(true),
			}
		return {"accepted": false, "reason_code": "public_action_ledger_invalid"}

	var next := state.duplicate(not authority_owned)
	var domain := str(entry.get("action_domain", ""))
	var receipt: Dictionary
	if domain == "facility":
		var facility_outcome := _resolve_facility_entry(
			next,
			entry,
			authority_owned
		)
		if not bool(facility_outcome.get("accepted", false)):
			return {
				"accepted": false,
				"reason_code": "facility_delegate_resolution_failed",
				"detail": facility_outcome.duplicate(true),
			}
		var facility_receipt := facility_outcome.get("receipt", {}) as Dictionary
		if str(facility_receipt.get("action_id", "")) != action_id:
			return {
				"accepted": false,
				"reason_code": "facility_delegate_order_mismatch",
				"expected_action_id": action_id,
				"actual_action_id": str(facility_receipt.get("action_id", "")),
			}
		next["facility_substate"] = (
			facility_outcome.get("facility_substate", {}) as Dictionary
		).duplicate(not authority_owned)
		receipt = _facility_receipt(
			str(next.get("batch_id", "")),
			entry,
			facility_receipt
		)
	else:
		receipt = {
			"schema_version": SCHEMA_VERSION,
			"contract_id": "v075.public_action_batch.receipt.v1",
			"receipt_id": _receipt_id(
				str(next.get("batch_id", "")),
				entry
			),
			"batch_id": str(next.get("batch_id", "")),
			"state_revision": int(next.get("revision", 0)) + 1,
			"anonymous_action_id": str(entry.get("anonymous_action_id", "")),
			"action_id": action_id,
			"actor_id": str(entry.get("actor_id", "")),
			"action_domain": domain,
			"accepted": true,
			"outcome_id": "combat_action_ready",
			"reason_code": "combat_action_ready_for_authority",
			"asset_reservation_released": false,
			"normal_card_destination": "discard",
			"action_slot_refunded": false,
			"exact_once": true,
			"action_binding": action.duplicate(true),
		}
		receipt["receipt_fingerprint"] = _fingerprint(receipt)
	next["resolution_cursor"] = cursor + 1
	next["revision"] = int(next.get("revision", 0)) + 1
	next["status"] = (
		"resolved"
		if int(next.get("resolution_cursor", 0)) >= queue.size()
		else "resolution_ready"
	)
	var public_queue := (
		next.get("anonymous_global_queue", []) as Array
	).duplicate(true)
	var public_entry := (public_queue[cursor] as Dictionary).duplicate(true)
	public_entry["resolution_status"] = "resolved"
	public_entry["public_reason_code"] = str(receipt.get("reason_code", ""))
	public_queue[cursor] = public_entry
	next["anonymous_global_queue"] = public_queue
	var receipts := (
		next.get("resolution_receipts", []) as Array
	).duplicate(false)
	processed = (next.get("processed_action_ids", {}) as Dictionary).duplicate(true)
	processed[action_id] = receipts.size()
	receipts.append(receipt.duplicate(true))
	next["processed_action_ids"] = processed
	next["resolution_receipts"] = receipts
	next = _seal_authority_owned(next) if authority_owned else _seal(next)
	return {
		"accepted": true,
		"reason_code": "public_action_resolved",
		"state": next,
		"receipt": receipt,
	}


static func replace_facility_substate(
	state: Dictionary,
	facility_substate: Dictionary
) -> Dictionary:
	if not bool(validation_report(state).get("valid", false)):
		return {}
	var facility_report := FacilityCore.validation_report(facility_substate)
	if not bool(facility_report.get("valid", false)):
		return {}
	if str(facility_substate.get("batch_id", "")) != str(state.get("batch_id", "")):
		return {}
	var next := state.duplicate(true)
	next["facility_substate"] = facility_substate.duplicate(true)
	next["revision"] = int(next.get("revision", 0)) + 1
	return _seal(next)


static func replace_facility_slots(
	state: Dictionary,
	facility_slots: Array
) -> Dictionary:
	if not bool(validation_report(state).get("valid", false)):
		return {}
	var current := facility_substate(state)
	if current.is_empty():
		return {}
	var current_slots := current.get("facility_slots", {}) as Dictionary
	var replacement_slots := {}
	for slot_variant in facility_slots:
		if not (slot_variant is Dictionary):
			return {}
		var slot := (slot_variant as Dictionary).duplicate(true)
		if not bool(FacilityCore.slot_validation_report(slot).get(
			"valid",
			false
		)):
			return {}
		var slot_id := str(slot.get("slot_id", ""))
		if slot_id.is_empty() or replacement_slots.has(slot_id):
			return {}
		replacement_slots[slot_id] = slot
	if replacement_slots.size() != current_slots.size():
		return {}
	for slot_id_variant in current_slots.keys():
		if not replacement_slots.has(str(slot_id_variant)):
			return {}
	var next_facility := current.duplicate(true)
	next_facility["facility_slots"] = replacement_slots
	next_facility.erase("state_fingerprint")
	var sealed_facility := FacilityCore._seal(
		next_facility,
		"state_fingerprint"
	)
	if sealed_facility.is_empty() or not bool(
		FacilityCore.validation_report(sealed_facility).get(
			"valid",
			false
		)
	):
		return {}
	return replace_facility_substate(state, sealed_facility)

static func facility_substate(state: Dictionary) -> Dictionary:
	if not bool(validation_report(state).get("valid", false)):
		return {}
	return (state.get("facility_substate", {}) as Dictionary).duplicate(true)


static func player_projection(state: Dictionary, viewer_id: String) -> Dictionary:
	if not bool(validation_report(state).get("valid", false)):
		return {}
	var projection := FacilityCore.player_projection(
		state.get("facility_substate", {}) as Dictionary,
		viewer_id
	)
	if projection.is_empty():
		return {}
	projection["ruleset_id"] = RULESET_ID
	projection["mixed_action_batch_contract_id"] = CONTRACT_ID
	projection["facility_substate_revision"] = projection.get(
		"state_revision",
		0
	)
	projection["state_revision"] = int(state.get("revision", 0))
	projection["anonymous_global_queue"] = (
		state.get("anonymous_global_queue", []) as Array
	).duplicate(true)
	projection["own_mixed_queue"] = (
		(state.get("player_local_queues", {}) as Dictionary).get(viewer_id, []) as Array
	).duplicate(true)
	return projection


static func ai_observation(state: Dictionary, viewer_id: String) -> Dictionary:
	if not bool(validation_report(state).get("valid", false)):
		return {}
	var observation := FacilityCore.ai_observation(
		state.get("facility_substate", {}) as Dictionary,
		viewer_id
	)
	if observation.is_empty():
		return {}
	observation["ruleset_id"] = RULESET_ID
	observation["mixed_action_batch_contract_id"] = CONTRACT_ID
	observation["facility_substate_revision"] = observation.get(
		"state_revision",
		0
	)
	observation["state_revision"] = int(state.get("revision", 0))
	observation["anonymous_global_queue"] = (
		state.get("anonymous_global_queue", []) as Array
	).duplicate(true)
	observation["own_mixed_queue"] = (
		(state.get("player_local_queues", {}) as Dictionary).get(viewer_id, []) as Array
	).duplicate(true)
	return observation


static func public_projection(state: Dictionary) -> Dictionary:
	if not bool(validation_report(state).get("valid", false)):
		return {}
	var projection := FacilityCore.public_projection(
		state.get("facility_substate", {}) as Dictionary
	)
	if projection.is_empty():
		return {}
	projection["ruleset_id"] = RULESET_ID
	projection["facility_substate_revision"] = projection.get(
		"state_revision",
		0
	)
	projection["state_revision"] = int(state.get("revision", 0))
	projection["anonymous_global_queue"] = (
		state.get("anonymous_global_queue", []) as Array
	).duplicate(true)
	return projection


static func validation_report(value: Variant) -> Dictionary:
	var errors: Array[String] = []
	if not (value is Dictionary) or not _pure_data(value):
		return {"valid": false, "error_count": 1, "errors": ["state_not_pure_data"]}
	var state := value as Dictionary
	for key in [
		"schema_version", "ruleset_id", "contract_id", "batch_id", "revision",
		"status", "player_ids", "frozen_hidden_order", "player_local_queues",
		"authority_queue", "anonymous_global_queue", "resolution_cursor",
		"facility_substate", "facility_target_slots_at_batch_lock",
		"processed_action_ids", "resolution_receipts",
		"state_fingerprint",
	]:
		if not state.has(key):
			errors.append("state_missing_%s" % key)
	if errors.is_empty():
		if int(state.get("schema_version", 0)) != SCHEMA_VERSION:
			errors.append("schema_version_invalid")
		if str(state.get("ruleset_id", "")) != RULESET_ID:
			errors.append("ruleset_id_invalid")
		if str(state.get("contract_id", "")) != CONTRACT_ID:
			errors.append("contract_id_invalid")
		if str(state.get("status", "")) not in ["resolution_ready", "resolved"]:
			errors.append("status_invalid")
		var queue := state.get("authority_queue", []) as Array
		var public_queue := state.get("anonymous_global_queue", []) as Array
		var cursor := int(state.get("resolution_cursor", -1))
		if public_queue.size() != queue.size() or cursor < 0 or cursor > queue.size():
			errors.append("queue_cursor_invalid")
		if str(state.get("status", "")) == "resolution_ready" and cursor >= queue.size():
			errors.append("ready_cursor_invalid")
		if str(state.get("status", "")) == "resolved" and cursor != queue.size():
			errors.append("resolved_cursor_invalid")
		var receipts := state.get("resolution_receipts", []) as Array
		var processed := state.get("processed_action_ids", {}) as Dictionary
		if receipts.size() != cursor or processed.size() != cursor:
			errors.append("exact_once_ledger_size_invalid")
		else:
			var seen_receipt_ids: Dictionary = {}
			for index in range(cursor):
				var entry := queue[index] as Dictionary
				var receipt := receipts[index] as Dictionary
				var action_id := str(entry.get("action_id", ""))
				var receipt_id := str(receipt.get("receipt_id", ""))
				if (
					action_id.is_empty()
					or str(receipt.get("action_id", "")) != action_id
					or int(processed.get(action_id, -1)) != index
					or receipt_id.is_empty()
					or seen_receipt_ids.has(receipt_id)
					or not _receipt_binding_valid(
						receipt,
						entry,
						str(state.get("batch_id", ""))
					)
				):
					errors.append("exact_once_ledger_binding_invalid")
					break
				seen_receipt_ids[receipt_id] = true
		var facility_report := FacilityCore.validation_report(
			state.get("facility_substate", {}) as Dictionary
		)
		if not bool(facility_report.get("valid", false)):
			errors.append("facility_substate_invalid")
		var target_slots_variant: Variant = state.get(
			"facility_target_slots_at_batch_lock"
		)
		if not (target_slots_variant is Dictionary):
			errors.append("facility_target_slots_invalid")
		else:
			var target_slots := target_slots_variant as Dictionary
			var current_slots := (
				state.get("facility_substate", {}) as Dictionary
			).get("facility_slots", {}) as Dictionary
			for action_id_variant in target_slots.keys():
				var action_id := str(action_id_variant)
				var slot_variant: Variant = target_slots.get(action_id_variant)
				if (
					not (slot_variant is Dictionary)
					or not bool(FacilityCore.slot_validation_report(slot_variant).get(
						"valid",
						false
					))
					or not current_slots.has(str((slot_variant as Dictionary).get(
						"slot_id",
						""
					)))
				):
					errors.append("facility_target_slot_invalid")
					break
		var unsealed := state.duplicate(true)
		unsealed.erase("state_fingerprint")
		if str(state.get("state_fingerprint", "")) != _fingerprint(unsealed):
			errors.append("state_fingerprint_invalid")
	return {
		"valid": errors.is_empty(),
		"error_count": errors.size(),
		"errors": errors,
		"reason_code": "public_action_state_valid" if errors.is_empty() else errors[0],
	}


static func _build_authority_queue(order: Array[String], queues: Dictionary) -> Array:
	var result: Array = []
	for local_index in range(MAX_ACTIONS_PER_PLAYER):
		for actor_id in order:
			var queue := queues.get(actor_id, []) as Array
			if local_index >= queue.size():
				continue
			var action := queue[local_index] as Dictionary
			result.append({
				"anonymous_action_id": "anonymous.%06d" % result.size(),
				"action_id": str(action.get("action_id", "")),
				"actor_id": actor_id,
				"local_action_index": local_index,
				"action_domain": _action_domain(action),
				"action": action.duplicate(true),
			})
	return result


static func _facility_receipt(
	batch_id: String,
	entry: Dictionary,
	facility_receipt: Dictionary
) -> Dictionary:
	var receipt := facility_receipt.duplicate(true)
	# FacilityCore's legacy receipt id is local to its anonymous queue. The
	# mixed V075 authority spans batches, so bind the public receipt identity to
	# both batch and anonymous action before sealing the V075 wrapper.
	receipt["receipt_id"] = _receipt_id(batch_id, entry)
	receipt["batch_id"] = batch_id
	receipt["action_domain"] = "facility"
	receipt["anonymous_action_id"] = str(entry.get("anonymous_action_id", ""))
	receipt["exact_once"] = true
	receipt["action_binding"] = {}
	receipt.erase("receipt_fingerprint")
	receipt["receipt_fingerprint"] = _fingerprint(receipt)
	return receipt


static func _receipt_id(batch_id: String, entry: Dictionary) -> String:
	var binding := {
		"batch_id": batch_id,
		"anonymous_action_id": str(entry.get("anonymous_action_id", "")),
		"action_id": str(entry.get("action_id", "")),
		"actor_id": str(entry.get("actor_id", "")),
		"action_domain": str(entry.get("action_domain", "")),
		"action": (entry.get("action", {}) as Dictionary).duplicate(true),
	}
	return "receipt.%s.%s.%s" % [
		batch_id,
		str(entry.get("anonymous_action_id", "")),
		_fingerprint(binding).substr(0, 16),
	]


static func _receipt_binding_valid(
	receipt: Dictionary,
	entry: Dictionary,
	batch_id: String
) -> bool:
	if (
		not bool(receipt.get("exact_once", false))
		or str(receipt.get("batch_id", "")) != batch_id
		or str(receipt.get("anonymous_action_id", ""))
			!= str(entry.get("anonymous_action_id", ""))
		or str(receipt.get("action_id", "")) != str(entry.get("action_id", ""))
		or str(receipt.get("actor_id", "")) != str(entry.get("actor_id", ""))
		or str(receipt.get("action_domain", ""))
			!= str(entry.get("action_domain", ""))
		or str(receipt.get("receipt_id", "")) != _receipt_id(batch_id, entry)
	):
		return false
	var fingerprint := str(receipt.get("receipt_fingerprint", ""))
	if fingerprint.length() != 64:
		return false
	var unsealed := receipt.duplicate(true)
	unsealed.erase("receipt_fingerprint")
	return fingerprint == _fingerprint(unsealed)


static func _action_domain(action: Dictionary) -> String:
	var explicit := str(action.get("action_domain", ""))
	if explicit in ACTION_DOMAINS:
		return explicit
	if str(action.get("facility_action_mode", "")) in FacilityCore.FACILITY_ACTION_MODES:
		return "facility"
	return ""


static func _facility_slot_snapshot(
	action: Dictionary,
	facility_slots: Array
) -> Dictionary:
	var target_slot_id := str(action.get("target_slot_id", ""))
	for slot_variant in facility_slots:
		if (
			slot_variant is Dictionary
			and str((slot_variant as Dictionary).get("slot_id", ""))
				== target_slot_id
		):
			return (slot_variant as Dictionary).duplicate(true)
	return {}


static func _resolve_facility_entry(
	state: Dictionary,
	entry: Dictionary,
	authority_owned: bool
) -> Dictionary:
	var action := entry.get("action", {}) as Dictionary
	var facility_action := action.duplicate(true)
	facility_action.erase("action_domain")
	if FacilityCore._action_error(facility_action) != "":
		return {
			"accepted": false,
			"reason_code": "facility_delegate_action_invalid",
		}
	var facility_state := state.get("facility_substate", {}) as Dictionary
	var current_slots := facility_state.get("facility_slots", {}) as Dictionary
	var slot_id := str(facility_action.get("target_slot_id", ""))
	if not current_slots.has(slot_id):
		return {
			"accepted": false,
			"reason_code": "facility_delegate_slot_missing",
		}
	var current_slot := current_slots.get(slot_id, {}) as Dictionary
	var invalid_reason := FacilityCore._revalidation_reason(
		facility_action,
		current_slot
	)
	# The resolved V0.7.4 substate is an immutable slot snapshot here. Copy the
	# dictionary shell and the target slot only; FacilityCore still owns every
	# revalidation, transition, warehouse decoration, and Receipt field.
	var next_facility := facility_state.duplicate(false)
	next_facility["facility_slots"] = current_slots.duplicate(false)
	if invalid_reason.is_empty():
		FacilityCore._apply_successful_action(next_facility, facility_action)
	next_facility.erase("state_fingerprint")
	next_facility["state_fingerprint"] = FacilityCore._fingerprint(
		next_facility
	)
	var target_slot := (
		(next_facility.get("facility_slots", {}) as Dictionary).get(
			slot_id,
			{}
		) as Dictionary
	)
	var facility_commit_valid := (
		not str(next_facility.get("state_fingerprint", "")).is_empty()
		and bool(FacilityCore.slot_validation_report(target_slot).get(
			"valid",
			false
		))
	)
	if not authority_owned:
		facility_commit_valid = facility_commit_valid and bool(
			FacilityCore.validation_report(next_facility).get("valid", false)
		)
	if not facility_commit_valid:
		return {
			"accepted": false,
			"reason_code": "facility_delegate_commit_invalid",
		}
	var facility_receipt := FacilityCore._build_receipt(
		next_facility,
		{
			"anonymous_action_id": str(entry.get(
				"anonymous_action_id",
				""
			)),
		},
		facility_action,
		invalid_reason,
		int(state.get("revision", 0)) + 1
	)
	if FacilityCore._receipt_error(facility_receipt) != "":
		return {
			"accepted": false,
			"reason_code": "facility_delegate_receipt_invalid",
		}
	return {
		"accepted": true,
		"reason_code": str(facility_receipt.get("reason_code", "")),
		"facility_substate": next_facility,
		"receipt": facility_receipt,
	}


static func _seal(value: Dictionary) -> Dictionary:
	var result := value.duplicate(true)
	result.erase("state_fingerprint")
	result["state_fingerprint"] = _fingerprint(result)
	return result


static func _seal_authority_owned(value: Dictionary) -> Dictionary:
	var result := value.duplicate(false)
	result.erase("state_fingerprint")
	result["state_fingerprint"] = _fingerprint(result)
	return result


static func _authority_owned_state_header_valid(state: Dictionary) -> bool:
	if (
		int(state.get("schema_version", 0)) != SCHEMA_VERSION
		or str(state.get("ruleset_id", "")) != RULESET_ID
		or str(state.get("contract_id", "")) != CONTRACT_ID
		or not _stable_id(str(state.get("batch_id", "")))
		or str(state.get("status", "")) not in ["resolution_ready", "resolved"]
		or not (state.get("authority_queue") is Array)
		or not (state.get("anonymous_global_queue") is Array)
		or not (state.get("processed_action_ids") is Dictionary)
		or not (state.get("resolution_receipts") is Array)
		or not (state.get("facility_substate") is Dictionary)
		or str(state.get("state_fingerprint", "")).length() != 64
	):
		return false
	var unsealed := state.duplicate(false)
	unsealed.erase("state_fingerprint")
	if str(state.get("state_fingerprint", "")) != _fingerprint(unsealed):
		return false
	var queue := state.get("authority_queue", []) as Array
	var public_queue := state.get("anonymous_global_queue", []) as Array
	var cursor := int(state.get("resolution_cursor", -1))
	var facility_state := state.get("facility_substate", {}) as Dictionary
	if (
		cursor < 0
		or cursor > queue.size()
		or public_queue.size() != queue.size()
		or str(facility_state.get("status", "")) != "resolved"
		or str(facility_state.get("state_fingerprint", "")).length() != 64
	):
		return false
	var receipts := state.get("resolution_receipts", []) as Array
	var processed := state.get("processed_action_ids", {}) as Dictionary
	if receipts.size() != cursor or processed.size() != cursor:
		return false
	var seen_receipt_ids: Dictionary = {}
	for index in range(cursor):
		var entry := queue[index] as Dictionary
		var receipt := receipts[index] as Dictionary
		var action_id := str(entry.get("action_id", ""))
		if (
			receipt.is_empty()
			or not _receipt_binding_valid(
				receipt,
				entry,
				str(state.get("batch_id", ""))
			)
			or str(receipt.get("action_id", "")) != action_id
			or int(processed.get(action_id, -1)) != index
		):
			return false
		var receipt_id := str(receipt.get("receipt_id", ""))
		if receipt_id.is_empty() or seen_receipt_ids.has(receipt_id):
			return false
		seen_receipt_ids[receipt_id] = true
	return (
		cursor >= 0
		and cursor <= queue.size()
		and public_queue.size() == queue.size()
		and str(facility_state.get("status", "")) == "resolved"
		and str(facility_state.get("state_fingerprint", "")).length() == 64
	)


static func _fingerprint(value: Variant) -> String:
	return JSON.stringify(_canonical(value)).sha256_text().to_lower()


static func _canonical(value: Variant) -> Variant:
	if value is Array:
		var rows: Array = []
		for item in value as Array:
			rows.append(_canonical(item))
		return rows
	if value is Dictionary:
		var keys: Array[String] = []
		for key_variant in (value as Dictionary).keys():
			keys.append(str(key_variant))
		keys.sort()
		var result := {}
		for key in keys:
			result[key] = _canonical((value as Dictionary).get(key))
		return result
	return value


static func _pure_data(value: Variant, depth: int = 0) -> bool:
	if depth > 64:
		return false
	if value == null or value is bool or value is int or value is float or value is String:
		return true
	if value is Vector2 or value is Vector3 or value is Color:
		return true
	if value is Array:
		for item in value as Array:
			if not _pure_data(item, depth + 1):
				return false
		return true
	if value is Dictionary:
		for key_variant in (value as Dictionary).keys():
			if not (key_variant is String) or not _pure_data(
				(value as Dictionary).get(key_variant), depth + 1
			):
				return false
		return true
	return false


static func _string_ids(value: Array) -> Array[String]:
	var result: Array[String] = []
	for item in value:
		var text := str(item)
		if not _stable_id(text) or result.has(text):
			return []
		result.append(text)
	return result


static func _stable_id(value: Variant) -> bool:
	if not (value is String):
		return false
	var text := str(value)
	return not text.is_empty() and text.length() <= 160 and not text.contains(" ")


static func _same_set(left: Array[String], right: Array[String]) -> bool:
	var a := left.duplicate()
	var b := right.duplicate()
	a.sort()
	b.sort()
	return a == b


static func _exact_keys(value: Dictionary, keys: Array[String]) -> bool:
	if value.size() != keys.size():
		return false
	for key in keys:
		if not value.has(key):
			return false
	return true
