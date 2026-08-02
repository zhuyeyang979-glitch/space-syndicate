extends RefCounted
class_name QueuedFacilityCardRestoreDependencyContractV06

const Binding := preload("res://scripts/cards/v06/queued_facility_card_action_v1.gd")
const StableTarget := preload("res://scripts/runtime/card_resolution_stable_target_envelope.gd")
const Wire := preload("res://scripts/semantic/semantic_wire_v1.gd")

const ASSET_IDS := ["life", "energy", "industry", "technology", "commerce", "shipping"]
const ESCROW_FIELDS := [
	"schema_version", "state_id", "request_id", "intent_fingerprint", "actor_id",
	"actor_player_index", "source_slot_index", "hand_slot_id", "card_semantic_id",
	"runtime_instance_id", "source_record_fingerprint", "source_slot_fingerprint",
	"escrow_id", "card_record", "predecessor_escrow_fingerprint", "escrow_fingerprint",
]
const ESCROW_RECEIPT_FIELDS := [
	"schema_version", "state_id", "request_id", "intent_fingerprint", "actor_id",
	"actor_player_index", "source_slot_index", "hand_slot_id", "card_semantic_id",
	"runtime_instance_id", "source_record_fingerprint", "source_slot_fingerprint",
	"escrow_id", "reason_code", "escrow_fingerprint", "receipt_fingerprint",
]
const POST_EFFECT_NEXT_INTENT_IDS := [
	"finish_card_commitment",
	"create_aftermath",
	"restore_context",
	"append_history",
	"start_next",
	"finish_batch",
	"promote_next_batch",
]


static func validate(queue_state: Dictionary, all_states: Dictionary) -> Dictionary:
	var references_result := _facility_references(queue_state, all_states.get("card_resolution_execution", {}))
	if not bool(references_result.get("valid", false)):
		return _reject(str(references_result.get("reason_code", "facility_restore_reference_invalid")))
	var references := references_result.get("references", {}) as Dictionary
	for section_id in ["session", "player_mana"]:
		if not (all_states.get(section_id) is Dictionary):
			return _reject("facility_restore_dependency_section_missing")
	var session_result := _session_context(all_states.get("session") as Dictionary)
	if not bool(session_result.get("valid", false)):
		return _reject(str(session_result.get("reason_code", "facility_restore_session_invalid")))
	var mana_result := _mana_context(all_states.get("player_mana") as Dictionary)
	if not bool(mana_result.get("valid", false)):
		return _reject(str(mana_result.get("reason_code", "facility_restore_mana_invalid")))
	var active_escrows := session_result.get("active_escrows") as Dictionary
	var mana_reservations := mana_result.get("reservations") as Dictionary
	if references.is_empty():
		if not active_escrows.is_empty():
			return _reject("facility_restore_orphan_escrow")
		for reservation_id_variant in mana_reservations.keys():
			if str(reservation_id_variant).begins_with("card-asset."):
				return _reject("facility_restore_orphan_reservation")
		return _accepted(0, 0, 0, 0)
	if not (all_states.get("region_infrastructure") is Dictionary):
		return _reject("facility_restore_dependency_section_missing")
	var region_result := _region_context(all_states.get("region_infrastructure") as Dictionary)
	if not bool(region_result.get("valid", false)):
		return _reject(str(region_result.get("reason_code", "facility_restore_region_invalid")))
	var referenced_escrow_ids: Dictionary = {}
	var referenced_reservation_ids: Dictionary = {}
	for resolution_key_variant in references.keys():
		var row := references.get(resolution_key_variant) as Dictionary
		var validation := _validate_reference(
			row,
			queue_state,
			session_result,
			mana_result,
			region_result
		)
		if not bool(validation.get("valid", false)):
			return _reject(str(validation.get("reason_code", "facility_restore_binding_invalid")))
		var binding := row.get("binding") as Dictionary
		var escrow_ref := binding.get("card_escrow") as Dictionary
		referenced_escrow_ids[str(escrow_ref.get("escrow_id", ""))] = true
		var reservation_ref := binding.get("asset_reservation") as Dictionary
		if bool(reservation_ref.get("required", false)):
			referenced_reservation_ids[str(reservation_ref.get("reservation_id", ""))] = true
	for escrow_id_variant in active_escrows.keys():
		if not referenced_escrow_ids.has(str(escrow_id_variant)):
			return _reject("facility_restore_orphan_escrow")
	for reservation_id_variant in mana_reservations.keys():
		var reservation_id := str(reservation_id_variant)
		if reservation_id.begins_with("card-asset.") \
				and not referenced_reservation_ids.has(reservation_id):
			return _reject("facility_restore_orphan_reservation")
	return _accepted(
		references.size(),
		referenced_escrow_ids.size(),
		referenced_reservation_ids.size(),
		int(region_result.get("target_count", 0))
	)


static func _facility_references(queue_state: Dictionary, execution_variant: Variant) -> Dictionary:
	var references: Dictionary = {}
	for lane_spec in [
		{"lane": "current", "entries": queue_state.get("current_queue", [])},
		{"lane": "active", "entries": [queue_state.get("active_entry", {})]},
		{"lane": "next", "entries": queue_state.get("next_queue", [])},
	]:
		if not (lane_spec.get("entries") is Array):
			return {"valid": false, "reason_code": "facility_restore_queue_shape_invalid"}
		for entry_variant in lane_spec.get("entries") as Array:
			if entry_variant is Dictionary and not (entry_variant as Dictionary).is_empty():
				var recorded := _record_reference(
					references,
					entry_variant as Dictionary,
					"queue.%s" % str(lane_spec.get("lane", ""))
				)
				if not bool(recorded.get("valid", false)):
					return recorded
	if not (execution_variant is Dictionary):
		return {"valid": false, "reason_code": "facility_restore_execution_shape_invalid"}
	var execution := execution_variant as Dictionary
	for transaction_variant in execution.get("inflight_execution_transactions", []):
		if not (transaction_variant is Dictionary):
			return {"valid": false, "reason_code": "facility_restore_execution_shape_invalid"}
		var transaction := transaction_variant as Dictionary
		var entry_variant: Variant = transaction.get("active_entry", {})
		if entry_variant is Dictionary:
			var recorded := _record_reference(
				references,
				entry_variant as Dictionary,
				"execution.inflight",
				transaction
			)
			if not bool(recorded.get("valid", false)):
				return recorded
	for pending_variant in execution.get("pending_settlements", []):
		if not (pending_variant is Dictionary) or not ((pending_variant as Dictionary).get("transaction") is Dictionary):
			return {"valid": false, "reason_code": "facility_restore_execution_shape_invalid"}
		var transaction := (pending_variant as Dictionary).get("transaction") as Dictionary
		var entry_variant: Variant = transaction.get("active_entry", {})
		if entry_variant is Dictionary:
			var recorded := _record_reference(
				references,
				entry_variant as Dictionary,
				"execution.pending_settlement",
				transaction
			)
			if not bool(recorded.get("valid", false)):
				return recorded
	return {"valid": true, "references": references}


static func _record_reference(
	references: Dictionary,
	entry: Dictionary,
	source_id: String,
	execution_transaction: Dictionary = {}
) -> Dictionary:
	if not entry.has("v06_facility_action"):
		return {"valid": true}
	var evidence := {
		"source_id": source_id,
		"stage_id": "pre_effect",
	}
	if source_id.begins_with("execution."):
		var evidence_result := _execution_reference_evidence(execution_transaction, source_id)
		if not bool(evidence_result.get("valid", false)):
			return evidence_result
		evidence = (evidence_result.get("evidence", {}) as Dictionary).duplicate(true)
	var binding_variant: Variant = entry.get("v06_facility_action")
	var report := Binding.validation_report(binding_variant)
	if not bool(report.get("valid", false)):
		return {"valid": false, "reason_code": "facility_restore_binding_schema_invalid"}
	var binding := binding_variant as Dictionary
	var resolution_id := int(binding.get("resolution_id", -1))
	var key := str(resolution_id)
	if references.has(key):
		var existing := references.get(key) as Dictionary
		if existing.get("entry") != entry or existing.get("binding") != binding:
			return {"valid": false, "reason_code": "facility_restore_resolution_collision"}
		var sources := (existing.get("sources", []) as Array).duplicate()
		if not sources.has(source_id):
			sources.append(source_id)
		existing["sources"] = sources
		var source_evidence := (existing.get("source_evidence", []) as Array).duplicate(true)
		if not source_evidence.has(evidence):
			source_evidence.append(evidence.duplicate(true))
		existing["source_evidence"] = source_evidence
		references[key] = existing
		return {"valid": true}
	references[key] = {
		"entry": entry.duplicate(true),
		"binding": binding.duplicate(true),
		"sources": [source_id],
		"source_evidence": [evidence.duplicate(true)],
	}
	return {"valid": true}


static func _execution_reference_evidence(transaction: Dictionary, source_id: String) -> Dictionary:
	if transaction.is_empty() or not (transaction.get("completed_intents", []) is Array):
		return {"valid": false, "reason_code": "facility_restore_execution_stage_invalid"}
	var completed := transaction.get("completed_intents") as Array
	var dispatch_count := 0
	for intent_variant in completed:
		if not (intent_variant is String):
			return {"valid": false, "reason_code": "facility_restore_execution_stage_invalid"}
		if str(intent_variant) == "dispatch_effect":
			dispatch_count += 1
	if dispatch_count > 1:
		return {"valid": false, "reason_code": "facility_restore_execution_stage_invalid"}
	if dispatch_count == 0:
		return {
			"valid": true,
			"evidence": {"source_id": source_id, "stage_id": "pre_effect"},
		}
	if not completed.has("release_active"):
		return {"valid": false, "reason_code": "facility_restore_execution_stage_invalid"}
	var next_intent: Dictionary = transaction.get("next_intent", {}) \
			if transaction.get("next_intent", {}) is Dictionary else {}
	if source_id == "execution.pending_settlement":
		if not next_intent.is_empty() or not completed.has("append_history") \
				or not bool(transaction.get("history_appended", false)):
			return {"valid": false, "reason_code": "facility_restore_execution_stage_invalid"}
	else:
		var next_intent_id := str(next_intent.get("intent_type", ""))
		if next_intent_id not in POST_EFFECT_NEXT_INTENT_IDS \
				or int(next_intent.get("resolution_id", -1)) != int(transaction.get("resolution_id", -2)) \
				or int(next_intent.get("execution_id", -1)) != int(transaction.get("execution_id", -2)):
			return {"valid": false, "reason_code": "facility_restore_execution_stage_invalid"}
	return {
		"valid": true,
		"evidence": {
			"source_id": source_id,
			"stage_id": "post_effect",
			"resolved": bool(transaction.get("resolved", false)),
			"effect_dispatched": bool(transaction.get("effect_dispatched", false)),
		},
	}


static func _session_context(session_state: Dictionary) -> Dictionary:
	if not (session_state.get("game_session_runtime") is Dictionary) \
			or not (session_state.get("world_session_state") is Dictionary):
		return {"valid": false, "reason_code": "facility_restore_session_shape_invalid"}
	var game := session_state.get("game_session_runtime") as Dictionary
	var world := session_state.get("world_session_state") as Dictionary
	if not (world.get("players") is Array):
		return {"valid": false, "reason_code": "facility_restore_player_roster_invalid"}
	var persistent_identity := Wire.fingerprint({
		"ruleset_id": game.get("ruleset_id"),
		"session_id": game.get("session_id"),
		"scenario_id": game.get("scenario_id"),
		"seed": str(game.get("seed")),
		"setup": (game.get("setup") as Dictionary).duplicate(true) if game.get("setup") is Dictionary else {},
	})
	if persistent_identity.is_empty() or not Wire.is_session_id(game.get("session_id")):
		return {"valid": false, "reason_code": "facility_restore_session_identity_invalid"}
	var players := world.get("players") as Array
	var active_escrows: Dictionary = {}
	var terminal_escrows: Dictionary = {}
	var active_runtime_ids: Dictionary = {}
	for player_index in range(players.size()):
		if not (players[player_index] is Dictionary):
			return {"valid": false, "reason_code": "facility_restore_player_roster_invalid"}
		var player := players[player_index] as Dictionary
		if not (player.get("slots") is Array):
			return {"valid": false, "reason_code": "facility_restore_player_roster_invalid"}
		for escrow_id_variant in (player.get("facility_card_escrows", {}) as Dictionary).keys() \
				if player.get("facility_card_escrows", {}) is Dictionary else []:
			var escrow_id := str(escrow_id_variant)
			var record: Variant = (player.get("facility_card_escrows") as Dictionary).get(escrow_id_variant)
			if not (record is Dictionary) or active_escrows.has(escrow_id) or terminal_escrows.has(escrow_id) \
					or not Wire.exact_fields(record as Dictionary, ESCROW_FIELDS):
				return {"valid": false, "reason_code": "facility_restore_escrow_invalid"}
			var escrow := record as Dictionary
			var escrow_state_id := str(escrow.get("state_id", ""))
			if escrow_state_id not in ["committed_resolution_escrow", "consumed_pending_finalization"] \
					or str(escrow.get("escrow_id", "")) != escrow_id \
					or int(escrow.get("actor_player_index", -1)) != player_index \
					or str(escrow.get("actor_id", "")) != "player.%d" % player_index \
					or str(escrow.get("escrow_fingerprint", "")) != _stable_data_fingerprint(escrow, "escrow_fingerprint") \
					or not (escrow.get("card_record") is Dictionary) \
					or str(escrow.get("source_slot_fingerprint", "")) != _stable_data_fingerprint(escrow.get("card_record")):
				return {"valid": false, "reason_code": "facility_restore_escrow_invalid"}
			if escrow_state_id == "committed_resolution_escrow":
				if not str(escrow.get("predecessor_escrow_fingerprint", "")).is_empty():
					return {"valid": false, "reason_code": "facility_restore_escrow_invalid"}
			else:
				var committed_predecessor := escrow.duplicate(true)
				committed_predecessor["state_id"] = "committed_resolution_escrow"
				committed_predecessor["predecessor_escrow_fingerprint"] = ""
				committed_predecessor["escrow_fingerprint"] = _stable_data_fingerprint(
					committed_predecessor,
					"escrow_fingerprint"
				)
				if str(escrow.get("predecessor_escrow_fingerprint", "")) \
						!= str(committed_predecessor.get("escrow_fingerprint", "")):
					return {"valid": false, "reason_code": "facility_restore_escrow_invalid"}
			var slot_index := int(escrow.get("source_slot_index", -1))
			var slots := player.get("slots") as Array
			var runtime_instance_id := str(escrow.get("runtime_instance_id", ""))
			if slot_index < 0 or slot_index >= slots.size() or slots[slot_index] != null \
					or active_runtime_ids.has(runtime_instance_id):
				return {"valid": false, "reason_code": "facility_restore_escrow_slot_invalid"}
			active_runtime_ids[runtime_instance_id] = true
			active_escrows[escrow_id] = {"player_index": player_index, "record": escrow.duplicate(true)}
		for escrow_id_variant in (player.get("facility_card_escrow_receipts", {}) as Dictionary).keys() \
				if player.get("facility_card_escrow_receipts", {}) is Dictionary else []:
			var escrow_id := str(escrow_id_variant)
			var receipt: Variant = (player.get("facility_card_escrow_receipts") as Dictionary).get(escrow_id_variant)
			if not (receipt is Dictionary) or active_escrows.has(escrow_id) or terminal_escrows.has(escrow_id) \
					or not Wire.exact_fields(receipt as Dictionary, ESCROW_RECEIPT_FIELDS):
				return {"valid": false, "reason_code": "facility_restore_escrow_receipt_invalid"}
			var terminal := receipt as Dictionary
			if str(terminal.get("state_id", "")) not in ["consumed_finalized", "released"] \
					or str(terminal.get("escrow_id", "")) != escrow_id \
					or int(terminal.get("actor_player_index", -1)) != player_index \
					or str(terminal.get("receipt_fingerprint", "")) != _stable_data_fingerprint(terminal, "receipt_fingerprint"):
				return {"valid": false, "reason_code": "facility_restore_escrow_receipt_invalid"}
			terminal_escrows[escrow_id] = {"player_index": player_index, "receipt": terminal.duplicate(true)}
	for player_variant in players:
		for slot_variant in (player_variant as Dictionary).get("slots") as Array:
			if slot_variant is Dictionary and active_runtime_ids.has(str((slot_variant as Dictionary).get("runtime_instance_id", ""))):
				return {"valid": false, "reason_code": "facility_restore_runtime_instance_collision"}
	return {
		"valid": true,
		"session_id": str(game.get("session_id", "")),
		"persistent_identity": persistent_identity,
		"players": players,
		"active_escrows": active_escrows,
		"terminal_escrows": terminal_escrows,
	}


static func _mana_context(mana_state: Dictionary) -> Dictionary:
	if not (mana_state.get("reservations") is Dictionary) \
			or not (mana_state.get("terminal_receipts") is Dictionary) \
			or not (mana_state.get("pools_by_player") is Dictionary):
		return {"valid": false, "reason_code": "facility_restore_mana_shape_invalid"}
	var reservations := mana_state.get("reservations") as Dictionary
	var terminals := mana_state.get("terminal_receipts") as Dictionary
	var snapshots: Dictionary = {}
	var reserved_by_player: Dictionary = {}
	for reservation_id_variant in reservations.keys():
		var reservation_id := str(reservation_id_variant)
		if terminals.has(reservation_id_variant) or terminals.has(reservation_id) \
				or not (reservations.get(reservation_id_variant) is Dictionary):
			return {"valid": false, "reason_code": "facility_restore_reservation_collision"}
		var record := reservations.get(reservation_id_variant) as Dictionary
		var snapshot := _reservation_snapshot(record)
		if snapshot.is_empty() or str(snapshot.get("transaction_id", "")) != reservation_id:
			return {"valid": false, "reason_code": "facility_restore_reservation_invalid"}
		snapshots[reservation_id] = snapshot
		var player_key := str(int(snapshot.get("player_index", -1)))
		var total: Dictionary = reserved_by_player.get(player_key, {}) if reserved_by_player.get(player_key, {}) is Dictionary else {}
		for asset_id in ASSET_IDS:
			total[asset_id] = int(total.get(asset_id, 0)) + int((snapshot.get("debit_milliunits") as Dictionary).get(asset_id, 0))
		reserved_by_player[player_key] = total
	var pools := mana_state.get("pools_by_player") as Dictionary
	for player_key_variant in reserved_by_player.keys():
		var player_key := str(player_key_variant)
		if not (pools.get(player_key) is Dictionary):
			return {"valid": false, "reason_code": "facility_restore_reservation_player_missing"}
		for asset_id in ASSET_IDS:
			if int((reserved_by_player.get(player_key) as Dictionary).get(asset_id, 0)) \
					> int((pools.get(player_key) as Dictionary).get(asset_id, -1)):
				return {"valid": false, "reason_code": "facility_restore_reservation_overcommitted"}
	return {"valid": true, "reservations": snapshots, "terminals": terminals.duplicate(true)}


static func _reservation_snapshot(record: Dictionary) -> Dictionary:
	for field_id in ["transaction_id", "player_index", "asset_cost", "asset_debit", "debit_milliunits", "state"]:
		if not record.has(field_id):
			return {}
	var snapshot := {
		"schema_version": 1,
		"transaction_id": record.get("transaction_id"),
		"player_index": record.get("player_index"),
		"asset_cost": (record.get("asset_cost") as Dictionary).duplicate(true) if record.get("asset_cost") is Dictionary else {},
		"asset_debit": (record.get("asset_debit") as Dictionary).duplicate(true) if record.get("asset_debit") is Dictionary else {},
		"debit_milliunits": (record.get("debit_milliunits") as Dictionary).duplicate(true) if record.get("debit_milliunits") is Dictionary else {},
		"state": record.get("state"),
		"fingerprint": "",
	}
	if str(snapshot.get("state", "")) != "reserved" or not Wire.is_session_id(snapshot.get("transaction_id")) \
			or not Wire.is_nonnegative_integer(snapshot.get("player_index")) \
			or not _exact_nonnegative_map(snapshot.get("asset_cost"), ASSET_IDS + ["generic"]) \
			or not _exact_nonnegative_map(snapshot.get("asset_debit"), ASSET_IDS) \
			or not _exact_nonnegative_map(snapshot.get("debit_milliunits"), ASSET_IDS):
		return {}
	for asset_id in ASSET_IDS:
		if int((snapshot.get("debit_milliunits") as Dictionary).get(asset_id, -1)) \
				!= int((snapshot.get("asset_debit") as Dictionary).get(asset_id, -1)) * 1000:
			return {}
	snapshot["fingerprint"] = Wire.fingerprint(snapshot, "fingerprint")
	return snapshot if Wire.is_fingerprint(snapshot.get("fingerprint")) else {}


static func _region_context(region_state: Dictionary) -> Dictionary:
	if not (region_state.get("regions") is Array) or not (region_state.get("slot_generations") is Dictionary) \
			or not (region_state.get("facilities") is Array) \
			or not (region_state.get("facility_action_lifecycles") is Dictionary):
		return {"valid": false, "reason_code": "facility_restore_region_shape_invalid"}
	for lifecycle_variant in (region_state.get("facility_action_lifecycles") as Dictionary).values():
		if lifecycle_variant is Dictionary and str((lifecycle_variant as Dictionary).get("state", "")) == "applied":
			return {"valid": false, "reason_code": "facility_restore_region_half_finalized"}
	var regions: Dictionary = {}
	for region_variant in region_state.get("regions") as Array:
		if not (region_variant is Dictionary):
			return {"valid": false, "reason_code": "facility_restore_region_record_invalid"}
		var region := region_variant as Dictionary
		var region_id := str(region.get("region_id", ""))
		if region_id.is_empty() or regions.has(region_id) or not (region.get("facility_slot_ids") is Array):
			return {"valid": false, "reason_code": "facility_restore_region_record_invalid"}
		regions[region_id] = region.duplicate(true)
	var facilities: Dictionary = {}
	var facilities_by_slot: Dictionary = {}
	for facility_variant in region_state.get("facilities") as Array:
		if not (facility_variant is Dictionary):
			return {"valid": false, "reason_code": "facility_restore_facility_record_invalid"}
		var facility := facility_variant as Dictionary
		var facility_id := str(facility.get("facility_id", ""))
		var slot_id := str(facility.get("slot_id", ""))
		if facility_id.is_empty() or slot_id.is_empty() or facilities.has(facility_id) \
				or facilities_by_slot.has(slot_id):
			return {"valid": false, "reason_code": "facility_restore_facility_record_invalid"}
		facilities[facility_id] = facility.duplicate(true)
		facilities_by_slot[slot_id] = facility_id
	return {
		"valid": true,
		"regions": regions,
		"facilities": facilities,
		"facilities_by_slot": facilities_by_slot,
		"slot_generations": (region_state.get("slot_generations") as Dictionary).duplicate(true),
		"facility_action_lifecycles": (region_state.get("facility_action_lifecycles") as Dictionary).duplicate(true),
		"target_count": (region_state.get("slot_generations") as Dictionary).size(),
	}


static func _validate_reference(
	row: Dictionary,
	queue_state: Dictionary,
	session: Dictionary,
	mana: Dictionary,
	regions: Dictionary
) -> Dictionary:
	var entry := row.get("entry") as Dictionary
	var binding := row.get("binding") as Dictionary
	var sources := row.get("sources") as Array
	var phase := _reference_phase(row)
	if not bool(phase.get("valid", false)):
		return {"valid": false, "reason_code": str(phase.get("reason_code", "facility_restore_reference_phase_invalid"))}
	var post_effect := str(phase.get("stage_id", "")) == "post_effect"
	var resolution_id := int(binding.get("resolution_id", -1))
	if int(entry.get("resolution_id", -2)) != resolution_id \
			or int(entry.get("queued_order", -2)) != resolution_id \
			or int(entry.get("player_index", -1)) != int(binding.get("actor_player_index", -2)) \
			or int(entry.get("slot_index", -1)) != int(binding.get("source_slot_index", -2)) \
			or int(binding.get("queue_revision_at_commit", -1)) <= 0 \
			or int(binding.get("queue_revision_at_commit", -1)) > int(queue_state.get("revision", -2)):
		return {"valid": false, "reason_code": "facility_restore_queue_mirror_mismatch"}
	var skill: Dictionary = entry.get("skill", {}) if entry.get("skill") is Dictionary else {}
	if str(skill.get("kind", "")) != "public_facility" \
			or int(skill.get("rank", -1)) != int(binding.get("rank", -2)):
		return {"valid": false, "reason_code": "facility_restore_skill_mirror_mismatch"}
	if str(binding.get("session_id", "")) != str(session.get("session_id", "")) \
			or str(binding.get("session_identity_fingerprint", "")) != str(session.get("persistent_identity", "")):
		return {"valid": false, "reason_code": "facility_restore_session_binding_mismatch"}
	var player_index := int(binding.get("actor_player_index", -1))
	var players := session.get("players") as Array
	if player_index < 0 or player_index >= players.size() or not (players[player_index] is Dictionary):
		return {"valid": false, "reason_code": "facility_restore_actor_missing"}
	var player := players[player_index] as Dictionary
	var expected_kind := "ai" if bool(player.get("is_ai", false)) else "human"
	if bool(player.get("eliminated", false)) or str(binding.get("actor_id", "")) != "player.%d" % player_index \
			or str(binding.get("actor_kind_id", "")) != expected_kind:
		return {"valid": false, "reason_code": "facility_restore_actor_binding_mismatch"}
	var stable_target := StableTarget.validate_entry_binding(entry)
	var target := binding.get("prebound_target") as Dictionary
	if not bool(stable_target.get("valid", false)) \
			or str((stable_target.get("envelope") as Dictionary).get("session_id", "")) != str(binding.get("session_id", "")) \
			or str((stable_target.get("envelope") as Dictionary).get("region_id", "")) != str(target.get("region_id", "")):
		return {"valid": false, "reason_code": "facility_restore_stable_target_mismatch"}
	var region_map := regions.get("regions") as Dictionary
	var region_id := str(target.get("region_id", ""))
	if not region_map.has(region_id):
		return {"valid": false, "reason_code": "facility_restore_target_region_missing"}
	var region := region_map.get(region_id) as Dictionary
	var expected_slot_id := _facility_slot_id(
		region_id,
		str(binding.get("facility_kind_id", "")),
		str(binding.get("industry_id", ""))
	)
	var slot_generations := regions.get("slot_generations") as Dictionary
	if expected_slot_id.is_empty() or str(target.get("target_slot_id", "")) != expected_slot_id \
			or not (region.get("facility_slot_ids") as Array).has(expected_slot_id) \
			or str(target.get("target_state_fingerprint", "")) != Wire.fingerprint(target, "target_state_fingerprint"):
		return {"valid": false, "reason_code": "facility_restore_target_binding_mismatch"}
	var lifecycle_state := ""
	if post_effect:
		var post_effect_validation := _validate_post_effect_facility_binding(
			binding,
			target,
			region,
			expected_slot_id,
			regions
		)
		if not bool(post_effect_validation.get("valid", false)):
			return post_effect_validation
		lifecycle_state = str(post_effect_validation.get("lifecycle_state", ""))
	elif int(target.get("region_revision", -1)) != int(region.get("revision", -2)) \
			or int(target.get("target_slot_generation", -1)) != int(slot_generations.get(expected_slot_id, 0)):
		return {"valid": false, "reason_code": "facility_restore_target_binding_mismatch"}
	var escrow_ref := binding.get("card_escrow") as Dictionary
	var escrow_id := str(escrow_ref.get("escrow_id", ""))
	var active_escrows := session.get("active_escrows") as Dictionary
	var terminal_escrows := session.get("terminal_escrows") as Dictionary
	var queue_pending := false
	for source_variant in sources:
		queue_pending = queue_pending or str(source_variant).begins_with("queue.")
	if queue_pending and not active_escrows.has(escrow_id):
		return {"valid": false, "reason_code": "facility_restore_queue_escrow_missing"}
	if active_escrows.has(escrow_id):
		var escrow := (active_escrows.get(escrow_id) as Dictionary).get("record") as Dictionary
		var escrow_state_id := str(escrow.get("state_id", ""))
		var escrow_fingerprint_matches := str(escrow.get("escrow_fingerprint", "")) \
				== str(escrow_ref.get("escrow_fingerprint", ""))
		if escrow_state_id == "consumed_pending_finalization":
			escrow_fingerprint_matches = str(escrow.get("predecessor_escrow_fingerprint", "")) \
					== str(escrow_ref.get("escrow_fingerprint", ""))
		if not escrow_fingerprint_matches or not _escrow_matches_binding(escrow, binding):
			return {"valid": false, "reason_code": "facility_restore_escrow_binding_mismatch"}
		if (not post_effect and escrow_state_id != "committed_resolution_escrow") \
				or (post_effect and lifecycle_state == "finalized" \
					and escrow_state_id != "consumed_pending_finalization"):
			return {"valid": false, "reason_code": "facility_restore_escrow_state_mismatch"}
	elif terminal_escrows.has(escrow_id):
		var receipt := (terminal_escrows.get(escrow_id) as Dictionary).get("receipt") as Dictionary
		if not _escrow_matches_binding(receipt, binding):
			return {"valid": false, "reason_code": "facility_restore_escrow_receipt_binding_mismatch"}
		var expected_terminal_state := "consumed_finalized" if lifecycle_state == "finalized" else "released"
		if post_effect and str(receipt.get("state_id", "")) != expected_terminal_state:
			return {"valid": false, "reason_code": "facility_restore_escrow_state_mismatch"}
	else:
		return {"valid": false, "reason_code": "facility_restore_escrow_missing"}
	var reservation_ref := binding.get("asset_reservation") as Dictionary
	if bool(reservation_ref.get("required", false)):
		var reservation_id := str(reservation_ref.get("reservation_id", ""))
		var reservations := mana.get("reservations") as Dictionary
		var terminals := mana.get("terminals") as Dictionary
		if queue_pending and not reservations.has(reservation_id):
			return {"valid": false, "reason_code": "facility_restore_queue_reservation_missing"}
		if reservations.has(reservation_id):
			var reservation := reservations.get(reservation_id) as Dictionary
			if str(reservation.get("fingerprint", "")) != str(reservation_ref.get("reservation_fingerprint", "")) \
					or int(reservation.get("player_index", -1)) != player_index \
					or reservation.get("asset_cost") != entry.get("asset_cost") \
					or reservation.get("asset_debit") != entry.get("asset_debit"):
				return {"valid": false, "reason_code": "facility_restore_reservation_binding_mismatch"}
		elif terminals.has(reservation_id):
			var terminal := terminals.get(reservation_id) as Dictionary
			var terminal_binding: Dictionary = terminal.get("reservation_binding", {}) \
					if terminal.get("reservation_binding") is Dictionary else {}
			if str(terminal_binding.get("fingerprint", "")) != str(reservation_ref.get("reservation_fingerprint", "")) \
					or int(terminal_binding.get("player_index", -1)) != player_index:
				return {"valid": false, "reason_code": "facility_restore_terminal_reservation_mismatch"}
			var expected_outcome := "consumed" if lifecycle_state == "finalized" else "released"
			if post_effect and str(terminal.get("outcome", "")) != expected_outcome:
				return {"valid": false, "reason_code": "facility_restore_terminal_reservation_mismatch"}
		else:
			return {"valid": false, "reason_code": "facility_restore_reservation_missing"}
		if not bool(entry.get("asset_reservation_required", false)) \
				or str(entry.get("asset_reservation_id", "")) != reservation_id:
			return {"valid": false, "reason_code": "facility_restore_reservation_queue_mismatch"}
	else:
		var expected_free := Wire.fingerprint({"required": false, "player_index": player_index})
		if str(reservation_ref.get("reservation_id", "")) != "" \
				or str(reservation_ref.get("reservation_fingerprint", "")) != expected_free \
				or bool(entry.get("asset_reservation_required", true)) \
				or str(entry.get("asset_reservation_id", "")) != "":
			return {"valid": false, "reason_code": "facility_restore_free_reservation_invalid"}
	return {"valid": true}


static func _reference_phase(row: Dictionary) -> Dictionary:
	var evidence_variant: Variant = row.get("source_evidence", [])
	if not (evidence_variant is Array) or (evidence_variant as Array).is_empty():
		return {"valid": false, "reason_code": "facility_restore_reference_phase_invalid"}
	var stage_id := ""
	for item_variant in evidence_variant as Array:
		if not (item_variant is Dictionary):
			return {"valid": false, "reason_code": "facility_restore_reference_phase_invalid"}
		var item_stage_id := str((item_variant as Dictionary).get("stage_id", ""))
		if item_stage_id not in ["pre_effect", "post_effect"]:
			return {"valid": false, "reason_code": "facility_restore_reference_phase_invalid"}
		if stage_id.is_empty():
			stage_id = item_stage_id
		elif stage_id != item_stage_id:
			return {"valid": false, "reason_code": "facility_restore_reference_phase_collision"}
	return {"valid": true, "stage_id": stage_id}


static func _validate_post_effect_facility_binding(
	binding: Dictionary,
	target: Dictionary,
	region: Dictionary,
	expected_slot_id: String,
	regions: Dictionary
) -> Dictionary:
	var transaction_id := "facility-resolution.%d.%s" % [
		int(binding.get("resolution_id", 0)),
		str(binding.get("binding_fingerprint", "")).substr(0, 16),
	]
	var lifecycles := regions.get("facility_action_lifecycles") as Dictionary
	if not lifecycles.has(transaction_id) or not (lifecycles.get(transaction_id) is Dictionary):
		return {"valid": false, "reason_code": "facility_restore_post_effect_lifecycle_missing"}
	var lifecycle := lifecycles.get(transaction_id) as Dictionary
	var lifecycle_state := str(lifecycle.get("state", ""))
	if lifecycle_state not in ["finalized", "rolled_back"] \
			or str(lifecycle.get("transaction_id", "")) != transaction_id \
			or bool(lifecycle.get("rollback_open", true)) \
			or lifecycle.get("preimage", null) != {} \
			or not bool(lifecycle.get("preimage_cleared", false)):
		return {"valid": false, "reason_code": "facility_restore_post_effect_lifecycle_invalid"}
	var owner_binding: Dictionary = lifecycle.get("owner_binding", {}) \
			if lifecycle.get("owner_binding", {}) is Dictionary else {}
	var action_kind := str(owner_binding.get("action_kind", ""))
	var target_generation := int(target.get("target_slot_generation", -1))
	var applied_generation := int(owner_binding.get("generation", -1))
	var expected_generation := target_generation + 1 if action_kind == "build" else target_generation
	var expected_intent_fingerprint := _owner_binding_fingerprint({
		"transaction_id": transaction_id,
		"region_id": str(target.get("region_id", "")),
		"owner_kind": "player",
		"owner_player_index": int(binding.get("actor_player_index", -1)),
		"facility_type": str(binding.get("facility_kind_id", "")),
		"industry_id": str(binding.get("industry_id", "")),
		"rank": int(binding.get("rank", 0)),
		"occurred_at": float(int(binding.get("submitted_at_world_time", 0))) / 1000.0,
	})
	if owner_binding.is_empty() or action_kind not in ["build", "upgrade", "repair"] \
			or str(owner_binding.get("receipt_kind", "")) != "facility_action" \
			or str(owner_binding.get("transaction_id", "")) != transaction_id \
			or str(owner_binding.get("intent_fingerprint", "")) != expected_intent_fingerprint \
			or str(lifecycle.get("intent_fingerprint", "")) != expected_intent_fingerprint \
			or str(owner_binding.get("region_id", "")) != str(target.get("region_id", "")) \
			or str(owner_binding.get("slot_id", "")) != expected_slot_id \
			or str(owner_binding.get("facility_type", "")) != str(binding.get("facility_kind_id", "")) \
			or str(owner_binding.get("industry_id", "")) != str(binding.get("industry_id", "")) \
			or str(owner_binding.get("owner_kind", "")) != "player" \
			or int(owner_binding.get("owner_player_index", -1)) != int(binding.get("actor_player_index", -2)) \
			or int(owner_binding.get("region_revision_before", -1)) != int(target.get("region_revision", -2)) \
			or int(owner_binding.get("region_revision_after", -1)) != int(target.get("region_revision", -2)) + 1 \
			or int(owner_binding.get("controller_revision_after", -1)) != int(owner_binding.get("controller_revision_before", -2)) + 1 \
			or applied_generation != expected_generation \
			or str(lifecycle.get("owner_binding_fingerprint", "")) != _owner_binding_fingerprint(owner_binding):
		return {"valid": false, "reason_code": "facility_restore_post_effect_binding_mismatch"}
	var facility_id := str(owner_binding.get("facility_id", ""))
	var postimage: Dictionary = lifecycle.get("postimage", {}) \
			if lifecycle.get("postimage", {}) is Dictionary else {}
	var region_after: Dictionary = postimage.get("region_after", {}) \
			if postimage.get("region_after", {}) is Dictionary else {}
	var facility_after: Dictionary = postimage.get("facility_after", {}) \
			if postimage.get("facility_after", {}) is Dictionary else {}
	if facility_id.is_empty() or region_after.is_empty() or facility_after.is_empty() \
			or str(region_after.get("region_id", "")) != str(target.get("region_id", "")) \
			or int(region_after.get("revision", -1)) != int(owner_binding.get("region_revision_after", -2)) \
			or str(facility_after.get("facility_id", "")) != facility_id \
			or str(facility_after.get("slot_id", "")) != expected_slot_id \
			or str(facility_after.get("region_id", "")) != str(target.get("region_id", "")) \
			or str(facility_after.get("facility_type", "")) != str(binding.get("facility_kind_id", "")) \
			or str(facility_after.get("industry_id", "")) != str(binding.get("industry_id", "")) \
			or str(facility_after.get("owner_kind", "")) != "player" \
			or int(facility_after.get("owner_player_index", -1)) != int(binding.get("actor_player_index", -2)) \
			or int(facility_after.get("generation", -1)) != applied_generation \
			or str(postimage.get("slot_mapping_after", "")) != facility_id \
			or int(postimage.get("slot_generation_after", -1)) != applied_generation \
			or int(postimage.get("controller_revision_after", -1)) != int(owner_binding.get("controller_revision_after", -2)):
		return {"valid": false, "reason_code": "facility_restore_post_effect_postimage_mismatch"}
	var original_receipt: Dictionary = lifecycle.get("original_receipt", {}) \
			if lifecycle.get("original_receipt", {}) is Dictionary else {}
	var terminal_receipt: Dictionary = lifecycle.get("terminal_receipt", {}) \
			if lifecycle.get("terminal_receipt", {}) is Dictionary else {}
	if not _facility_receipt_matches_owner_binding(original_receipt, owner_binding, lifecycle) \
			or not bool(original_receipt.get("committed", false)) \
			or not bool(original_receipt.get("rollback_open", false)) \
			or bool(original_receipt.get("rolled_back", false)) \
			or bool(original_receipt.get("finalized", false)) \
			or not _facility_receipt_matches_owner_binding(terminal_receipt, owner_binding, lifecycle) \
			or int(lifecycle.get("terminal_revision", -1)) != int(terminal_receipt.get("revision", -2)) \
			or int(lifecycle.get("terminal_receipt_sequence", -1)) != int(terminal_receipt.get("receipt_sequence", -2)):
		return {"valid": false, "reason_code": "facility_restore_post_effect_receipt_mismatch"}
	var slot_generations := regions.get("slot_generations") as Dictionary
	var facilities := regions.get("facilities") as Dictionary
	var facilities_by_slot := regions.get("facilities_by_slot") as Dictionary
	if lifecycle_state == "finalized":
		if str(terminal_receipt.get("receipt_kind", "")) != "facility_action_finalize" \
				or not bool(terminal_receipt.get("committed", false)) \
				or not bool(terminal_receipt.get("finalized", false)) \
				or bool(terminal_receipt.get("rolled_back", true)) \
				or region != region_after \
				or int(slot_generations.get(expected_slot_id, -1)) != applied_generation \
				or str(facilities_by_slot.get(expected_slot_id, "")) != facility_id \
				or not facilities.has(facility_id) \
				or facilities.get(facility_id) != facility_after:
			return {"valid": false, "reason_code": "facility_restore_post_effect_terminal_mismatch"}
	else:
		if str(terminal_receipt.get("receipt_kind", "")) != "facility_action_rollback" \
				or bool(terminal_receipt.get("committed", true)) \
				or not bool(terminal_receipt.get("rolled_back", false)) \
				or bool(terminal_receipt.get("finalized", true)) \
				or int(region.get("revision", -1)) != int(owner_binding.get("region_revision_after", -2)) + 1 \
				or int(slot_generations.get(expected_slot_id, 0)) != target_generation \
				or (action_kind == "build" and str(facilities_by_slot.get(expected_slot_id, "")) == facility_id):
			return {"valid": false, "reason_code": "facility_restore_post_effect_terminal_mismatch"}
	return {"valid": true, "lifecycle_state": lifecycle_state}


static func _facility_receipt_matches_owner_binding(
	receipt: Dictionary,
	owner_binding: Dictionary,
	lifecycle: Dictionary
) -> bool:
	return not receipt.is_empty() \
		and str(receipt.get("transaction_id", "")) == str(owner_binding.get("transaction_id", "")) \
		and str(receipt.get("region_id", "")) == str(owner_binding.get("region_id", "")) \
		and str(receipt.get("slot_id", "")) == str(owner_binding.get("slot_id", "")) \
		and str(receipt.get("facility_id", "")) == str(owner_binding.get("facility_id", "")) \
		and receipt.get("owner_binding", {}) == owner_binding \
		and str(receipt.get("owner_binding_fingerprint", "")) \
			== str(lifecycle.get("owner_binding_fingerprint", ""))


static func _owner_binding_fingerprint(value: Variant) -> String:
	return str(hash(JSON.stringify(_canonicalize(value))))


static func _escrow_matches_binding(value: Dictionary, binding: Dictionary) -> bool:
	for field_id in [
		"request_id", "intent_fingerprint", "actor_id", "actor_player_index",
		"source_slot_index", "hand_slot_id", "card_semantic_id", "runtime_instance_id",
		"source_record_fingerprint", "source_slot_fingerprint",
	]:
		if value.get(field_id) != binding.get(field_id):
			return false
	return true


static func _facility_slot_id(region_id: String, facility_kind_id: String, industry_id: String) -> String:
	if facility_kind_id in ["factory", "market", "warehouse"]:
		return "%s::%s.%s" % [region_id, facility_kind_id, industry_id]
	if facility_kind_id in ["road", "port", "spaceport"] and industry_id.is_empty():
		return "%s::%s" % [region_id, facility_kind_id]
	return ""


static func _exact_nonnegative_map(value: Variant, fields: Array) -> bool:
	if not (value is Dictionary) or not Wire.exact_fields(value as Dictionary, fields):
		return false
	for field_id in fields:
		if not Wire.is_nonnegative_integer((value as Dictionary).get(field_id)):
			return false
	return true


static func _stable_data_fingerprint(value: Variant, omitted_field: String = "") -> String:
	if not _is_finite_pure_data(value):
		return ""
	var material: Variant = value.duplicate(true) if value is Dictionary or value is Array else value
	if not omitted_field.is_empty() and material is Dictionary:
		(material as Dictionary).erase(omitted_field)
	return JSON.stringify(_canonicalize(material)).sha256_text().to_lower()


static func _canonicalize(value: Variant) -> Variant:
	if value is Dictionary:
		var keys: Array = (value as Dictionary).keys()
		keys.sort_custom(func(left: Variant, right: Variant) -> bool: return str(left) < str(right))
		var result: Dictionary = {}
		for key_variant in keys:
			result[str(key_variant)] = _canonicalize((value as Dictionary).get(key_variant))
		return result
	if value is Array:
		var result: Array = []
		for item_variant in value as Array:
			result.append(_canonicalize(item_variant))
		return result
	return value


static func _is_finite_pure_data(value: Variant) -> bool:
	if typeof(value) == TYPE_OBJECT or value is Callable:
		return false
	if value is float and not is_finite(value):
		return false
	if value is Dictionary:
		for key_variant in (value as Dictionary).keys():
			if not _is_finite_pure_data(key_variant) \
					or not _is_finite_pure_data((value as Dictionary).get(key_variant)):
				return false
	elif value is Array:
		for item_variant in value as Array:
			if not _is_finite_pure_data(item_variant):
				return false
	return true


static func _accepted(reference_count: int, escrow_count: int, reservation_count: int, target_count: int) -> Dictionary:
	return {
		"accepted": true,
		"reason_code": "facility_restore_dependencies_valid",
		"facility_reference_count": reference_count,
		"facility_escrow_reference_count": escrow_count,
		"facility_reservation_reference_count": reservation_count,
		"facility_target_catalog_count": target_count,
	}


static func _reject(reason_code: String) -> Dictionary:
	return {"accepted": false, "reason": reason_code, "reason_code": reason_code}
