@tool
extends RefCounted
class_name CommodityFlowPostCommitRestoreDependencyContract

## Pure-data cross-section preflight for the CommodityFlow post-commit lineage.
## It never reads live owners. The save registry calls it only after every
## section owner has normalized its candidate state.

const BATCH_PREFIX := "commodity-flow-batch-"
const BANKRUPTCY_PREFIX := "bankruptcy:commodity-flow-batch-"
const ASSET_PREFIX := "asset-recovery:commodity-flow-batch-"
const LEGACY_BOOTSTRAP_REASON := CommodityFlowPostCommitReceiptConsumer.LEGACY_BOOTSTRAP_REASON


static func validate_dependencies(
	commodity_flow_state: Dictionary,
	session_state: Dictionary,
	bankruptcy_state: Dictionary,
	player_mana_state: Dictionary
) -> Dictionary:
	if not commodity_flow_state.has("postcommit_consumer"):
		return _accepted(false, "commodity_postcommit_dependency_not_applicable")
	if not (commodity_flow_state.get("postcommit_consumer") is Dictionary) \
			or not (session_state.get("world_session_state") is Dictionary) \
			or not (bankruptcy_state.get("journal") is Dictionary) \
			or not (player_mana_state.get("advance_once_journal") is Dictionary):
		return _rejected("commodity_postcommit_dependency_shape_invalid")
	var consumer := commodity_flow_state.get("postcommit_consumer") as Dictionary
	if not (consumer.get("journal") is Dictionary) \
			or not (consumer.get("completed_through_batch_sequence") is int) \
			or not (consumer.get("pending_batch_id") is String) \
			or not (consumer.get("legacy_bootstrap_reason") is String) \
			or not (commodity_flow_state.get("batch_sequence") is int):
		return _rejected("commodity_postcommit_consumer_cursor_invalid")
	var batch_sequence := int(commodity_flow_state.get("batch_sequence", -1))
	var completed_sequence := int(consumer.get("completed_through_batch_sequence", -1))
	var pending_batch_id := str(consumer.get("pending_batch_id", ""))
	var legacy_bootstrap_reason := str(consumer.get("legacy_bootstrap_reason", ""))
	if not legacy_bootstrap_reason in ["", LEGACY_BOOTSTRAP_REASON]:
		return _rejected("commodity_postcommit_legacy_bootstrap_reason_invalid")
	var legacy_bootstrap := legacy_bootstrap_reason == LEGACY_BOOTSTRAP_REASON
	var journal := consumer.get("journal") as Dictionary
	if batch_sequence < 0 or completed_sequence < 0 or completed_sequence > batch_sequence:
		return _rejected("commodity_postcommit_consumer_cursor_invalid")
	if journal.is_empty() and batch_sequence > 0 and not legacy_bootstrap:
		return _rejected("commodity_postcommit_consumer_journal_missing")

	var records_by_sequence: Dictionary = {}
	var ordered_sequences: Array[int] = []
	for batch_id_variant in journal.keys():
		var batch_id := str(batch_id_variant)
		var record_variant: Variant = journal.get(batch_id_variant)
		if not (record_variant is Dictionary):
			return _rejected("commodity_postcommit_consumer_record_invalid")
		var record := record_variant as Dictionary
		var sequence := int(record.get("batch_sequence", -1))
		var state := str(record.get("state", ""))
		if sequence <= 0 or sequence > batch_sequence \
				or batch_id != _batch_id(sequence) \
				or str(record.get("batch_id", "")) != batch_id \
				or not _valid_sha256(str(record.get("batch_fingerprint", ""))) \
				or records_by_sequence.has(str(sequence)):
			return _rejected("commodity_postcommit_consumer_record_invalid")
		if state == "finalized":
			if sequence > completed_sequence:
				return _rejected("commodity_postcommit_consumer_terminal_cursor_invalid")
		elif not state in ["pending", "recovery_required"] \
				or pending_batch_id != batch_id \
				or sequence != batch_sequence \
				or completed_sequence != sequence - 1:
			return _rejected("commodity_postcommit_consumer_pending_cursor_invalid")
		records_by_sequence[str(sequence)] = record
		ordered_sequences.append(sequence)
	ordered_sequences.sort()
	if pending_batch_id.is_empty():
		if completed_sequence != batch_sequence:
			return _rejected("commodity_postcommit_consumer_flow_cursor_mismatch")
	else:
		var pending_sequence := _batch_sequence(pending_batch_id)
		if pending_sequence != batch_sequence \
				or not records_by_sequence.has(str(pending_sequence)):
			return _rejected("commodity_postcommit_consumer_pending_identity_invalid")

	var world_state := session_state.get("world_session_state") as Dictionary
	if not (world_state.get("commodity_postcommit_city_lineage_by_district") is Dictionary) \
			or not (world_state.get("commodity_postcommit_cash_lineage_by_player") is Dictionary):
		return _rejected("commodity_postcommit_world_lineage_missing")
	var city_check := _validate_world_lineage(
		world_state.get("commodity_postcommit_city_lineage_by_district") as Dictionary,
		records_by_sequence,
		ordered_sequences,
		batch_sequence,
		"city_target_completed_by_district",
		true
	)
	if not bool(city_check.get("accepted", false)):
		return city_check
	var cash_check := _validate_world_lineage(
		world_state.get("commodity_postcommit_cash_lineage_by_player") as Dictionary,
		records_by_sequence,
		ordered_sequences,
		batch_sequence,
		"cash_target_completed_by_player",
		false
	)
	if not bool(cash_check.get("accepted", false)):
		return cash_check
	var bankruptcy_check := _validate_bankruptcy_lineage(
		bankruptcy_state,
		records_by_sequence,
		ordered_sequences,
		batch_sequence,
		pending_batch_id
	)
	if not bool(bankruptcy_check.get("accepted", false)):
		return bankruptcy_check
	var mana_check := _validate_asset_lineage(
		player_mana_state,
		records_by_sequence,
		ordered_sequences,
		batch_sequence
	)
	if not bool(mana_check.get("accepted", false)):
		return mana_check
	return _accepted(true, "commodity_postcommit_restore_dependencies_valid")


static func _validate_world_lineage(
	actual_by_index: Dictionary,
	records_by_sequence: Dictionary,
	ordered_sequences: Array[int],
	flow_batch_sequence: int,
	target_field: String,
	require_city_fingerprint: bool
) -> Dictionary:
	var expected_by_index: Dictionary = {}
	for sequence in ordered_sequences:
		var record := records_by_sequence.get(str(sequence)) as Dictionary
		var targets: Dictionary = record.get(target_field, {}) if record.get(target_field, {}) is Dictionary else {}
		for index_variant in targets.keys():
			if bool(targets.get(index_variant, false)):
				expected_by_index[str(index_variant)] = _record_binding(record, require_city_fingerprint)
	for index_variant in expected_by_index.keys():
		var actual_variant: Variant = actual_by_index.get(str(index_variant), {})
		if not (actual_variant is Dictionary) \
				or not _same_binding(actual_variant as Dictionary, expected_by_index[index_variant] as Dictionary, require_city_fingerprint):
			return _rejected("commodity_postcommit_world_target_behind")
	var minimum_retained: int = ordered_sequences.front() if not ordered_sequences.is_empty() else 0
	for index_variant in actual_by_index.keys():
		var actual_variant: Variant = actual_by_index.get(index_variant)
		if not (actual_variant is Dictionary):
			return _rejected("commodity_postcommit_world_binding_invalid")
		var actual := actual_variant as Dictionary
		var sequence := int(actual.get("batch_sequence", -1))
		if sequence <= 0 or sequence > flow_batch_sequence \
				or str(actual.get("batch_id", "")) != _batch_id(sequence) \
				or not _valid_sha256(str(actual.get("batch_fingerprint", ""))) \
				or require_city_fingerprint and not _valid_sha256(str(actual.get("city_breakdown_fingerprint", ""))):
			return _rejected("commodity_postcommit_world_target_ahead")
		if records_by_sequence.has(str(sequence)):
			var record := records_by_sequence.get(str(sequence)) as Dictionary
			var targets: Dictionary = record.get(target_field, {}) if record.get(target_field, {}) is Dictionary else {}
			if not bool(targets.get(str(index_variant), false)) \
					or not _same_binding(actual, _record_binding(record, require_city_fingerprint), require_city_fingerprint):
				return _rejected("commodity_postcommit_world_target_ahead")
		elif minimum_retained > 0 and sequence >= minimum_retained:
			return _rejected("commodity_postcommit_world_target_unbound")
	return _accepted(true, "commodity_postcommit_world_lineage_valid")


static func _validate_bankruptcy_lineage(
	bankruptcy_state: Dictionary,
	records_by_sequence: Dictionary,
	ordered_sequences: Array[int],
	flow_batch_sequence: int,
	pending_batch_id: String
) -> Dictionary:
	var journal := bankruptcy_state.get("journal") as Dictionary
	var retired_sequence := int(bankruptcy_state.get("commodity_flow_retired_sequence", 0))
	if retired_sequence < 0 or retired_sequence > flow_batch_sequence:
		return _rejected("commodity_postcommit_bankruptcy_target_ahead")
	for sequence in ordered_sequences:
		var record := records_by_sequence.get(str(sequence)) as Dictionary
		var downstream: Dictionary = record.get("downstream_snapshot", {}) if record.get("downstream_snapshot", {}) is Dictionary else {}
		if downstream.is_empty():
			continue
		var transaction_id := str(downstream.get("bankruptcy_transaction_id", ""))
		var expected_fingerprint := str(downstream.get("bankruptcy_request_fingerprint", ""))
		if transaction_id != "bankruptcy:%s" % _batch_id(sequence) or not _valid_sha256(expected_fingerprint):
			return _rejected("commodity_postcommit_bankruptcy_binding_invalid")
		var target_variant: Variant = journal.get(transaction_id, {})
		var target := target_variant as Dictionary if target_variant is Dictionary else {}
		if not target.is_empty() and not _bankruptcy_record_matches(target, expected_fingerprint, str(record.get("batch_fingerprint", ""))):
			return _rejected("commodity_postcommit_bankruptcy_binding_collision")
		if bool(record.get("bankruptcy_target_completed", false)) and target.is_empty():
			if sequence > retired_sequence or _batch_id(sequence) == pending_batch_id:
				return _rejected("commodity_postcommit_bankruptcy_target_behind")
	var minimum_retained: int = ordered_sequences.front() if not ordered_sequences.is_empty() else 0
	for transaction_id_variant in journal.keys():
		var transaction_id := str(transaction_id_variant)
		if not transaction_id.begins_with(BANKRUPTCY_PREFIX):
			continue
		var sequence := _transaction_sequence(transaction_id, "bankruptcy:")
		if sequence <= 0 or sequence > flow_batch_sequence:
			return _rejected("commodity_postcommit_bankruptcy_target_ahead")
		if records_by_sequence.has(str(sequence)):
			var record := records_by_sequence.get(str(sequence)) as Dictionary
			var downstream: Dictionary = record.get("downstream_snapshot", {}) if record.get("downstream_snapshot", {}) is Dictionary else {}
			var target_variant: Variant = journal.get(transaction_id_variant)
			if downstream.is_empty() or not (target_variant is Dictionary) \
					or str(downstream.get("bankruptcy_transaction_id", "")) != transaction_id \
					or not _bankruptcy_record_matches(
						target_variant as Dictionary,
						str(downstream.get("bankruptcy_request_fingerprint", "")),
						str(record.get("batch_fingerprint", ""))
					):
				return _rejected("commodity_postcommit_bankruptcy_target_unbound")
		elif minimum_retained > 0 and sequence >= minimum_retained:
			return _rejected("commodity_postcommit_bankruptcy_target_unbound")
	return _accepted(true, "commodity_postcommit_bankruptcy_lineage_valid")


static func _validate_asset_lineage(
	player_mana_state: Dictionary,
	records_by_sequence: Dictionary,
	ordered_sequences: Array[int],
	flow_batch_sequence: int
) -> Dictionary:
	var journal := player_mana_state.get("advance_once_journal") as Dictionary
	for sequence in ordered_sequences:
		var record := records_by_sequence.get(str(sequence)) as Dictionary
		var downstream: Dictionary = record.get("downstream_snapshot", {}) if record.get("downstream_snapshot", {}) is Dictionary else {}
		if downstream.is_empty():
			continue
		var transaction_id := str(downstream.get("asset_recovery_transaction_id", ""))
		var expected_fingerprint := str(downstream.get("asset_recovery_request_fingerprint", ""))
		if transaction_id != "asset-recovery:%s" % _batch_id(sequence) or not _valid_sha256(expected_fingerprint):
			return _rejected("commodity_postcommit_asset_binding_invalid")
		var target_variant: Variant = journal.get(transaction_id, {})
		var target := target_variant as Dictionary if target_variant is Dictionary else {}
		if not target.is_empty() and not _asset_record_matches(target, transaction_id, expected_fingerprint):
			return _rejected("commodity_postcommit_asset_binding_collision")
		if bool(record.get("asset_recovery_target_completed", false)) and target.is_empty():
			return _rejected("commodity_postcommit_asset_target_behind")
	var minimum_retained: int = ordered_sequences.front() if not ordered_sequences.is_empty() else 0
	for transaction_id_variant in journal.keys():
		var transaction_id := str(transaction_id_variant)
		if not transaction_id.begins_with(ASSET_PREFIX):
			continue
		var sequence := _transaction_sequence(transaction_id, "asset-recovery:")
		if sequence <= 0 or sequence > flow_batch_sequence:
			return _rejected("commodity_postcommit_asset_target_ahead")
		if records_by_sequence.has(str(sequence)):
			var record := records_by_sequence.get(str(sequence)) as Dictionary
			var downstream: Dictionary = record.get("downstream_snapshot", {}) if record.get("downstream_snapshot", {}) is Dictionary else {}
			var target_variant: Variant = journal.get(transaction_id_variant)
			if downstream.is_empty() or not (target_variant is Dictionary) \
					or str(downstream.get("asset_recovery_transaction_id", "")) != transaction_id \
					or not _asset_record_matches(
						target_variant as Dictionary,
						transaction_id,
						str(downstream.get("asset_recovery_request_fingerprint", ""))
					):
				return _rejected("commodity_postcommit_asset_target_unbound")
		elif minimum_retained > 0 and sequence >= minimum_retained:
			return _rejected("commodity_postcommit_asset_target_unbound")
	return _accepted(true, "commodity_postcommit_asset_lineage_valid")


static func _record_binding(record: Dictionary, include_city_fingerprint: bool) -> Dictionary:
	var binding := {
		"batch_sequence": int(record.get("batch_sequence", -1)),
		"batch_id": str(record.get("batch_id", "")),
		"batch_fingerprint": str(record.get("batch_fingerprint", "")),
	}
	if include_city_fingerprint:
		binding["city_breakdown_fingerprint"] = str(record.get("city_breakdown_fingerprint", ""))
	return binding


static func _same_binding(left: Dictionary, right: Dictionary, include_city_fingerprint: bool) -> bool:
	return int(left.get("batch_sequence", -1)) == int(right.get("batch_sequence", -2)) \
		and str(left.get("batch_id", "")) == str(right.get("batch_id", "")) \
		and str(left.get("batch_fingerprint", "")) == str(right.get("batch_fingerprint", "")) \
		and (not include_city_fingerprint or str(left.get("city_breakdown_fingerprint", "")) \
			== str(right.get("city_breakdown_fingerprint", "")))


static func _bankruptcy_record_matches(record: Dictionary, request_fingerprint: String, source_fingerprint: String) -> bool:
	return str(record.get("state", "")) == "finalized" \
		and str(record.get("request_fingerprint", "")) == request_fingerprint \
		and str(record.get("source_fingerprint", "")) == source_fingerprint


static func _asset_record_matches(record: Dictionary, transaction_id: String, fingerprint: String) -> bool:
	return str(record.get("transaction_id", "")) == transaction_id \
		and str(record.get("fingerprint", "")) == fingerprint \
		and record.get("receipt", {}) is Dictionary \
		and bool((record.get("receipt", {}) as Dictionary).get("advanced", false))


static func _batch_id(sequence: int) -> String:
	return "%s%010d" % [BATCH_PREFIX, sequence]


static func _batch_sequence(batch_id: String) -> int:
	if not batch_id.begins_with(BATCH_PREFIX):
		return -1
	var text := batch_id.trim_prefix(BATCH_PREFIX)
	if text.length() != 10 or not text.is_valid_int():
		return -1
	var sequence := int(text)
	return sequence if sequence > 0 and batch_id == _batch_id(sequence) else -1


static func _transaction_sequence(transaction_id: String, prefix: String) -> int:
	return _batch_sequence(transaction_id.trim_prefix(prefix)) if transaction_id.begins_with(prefix) else -1


static func _valid_sha256(value: String) -> bool:
	if value.length() != 64:
		return false
	for index in range(value.length()):
		if not "0123456789abcdef".contains(value.substr(index, 1)):
			return false
	return true


static func _accepted(applicable: bool, reason_code: String) -> Dictionary:
	return {"accepted": true, "applicable": applicable, "reason_code": reason_code}


static func _rejected(reason_code: String) -> Dictionary:
	return {"accepted": false, "applicable": true, "reason_code": reason_code}
