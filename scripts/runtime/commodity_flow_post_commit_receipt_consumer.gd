@tool
extends Node
class_name CommodityFlowPostCommitReceiptConsumer

## Scene-owned forward-recovery consumer for effects that follow an
## authoritative CommodityFlow sale commit. It owns only post-commit
## consumption lineage. CommodityFlow remains the Sale Receipt owner,
## WorldSessionState remains the player/district owner; derivative, visual,
## bankruptcy and PlayerMana owners remain authoritative for their own effects.

const JOURNAL_VERSION := 2
const JOURNAL_LIMIT := 128
const LEGACY_BOOTSTRAP_REASON := "legacy_flow_batches_assumed_synchronously_completed"
const RULESET_ID := "v0.6"
const GDP_SOURCE_LABEL := "商品成交回执"
const PULSE_COLOR := Color("#2dd4bf")
const VALID_STATES := ["pending", "finalized", "recovery_required"]
const CITY_BREAKDOWN_KEYS := [
	"net",
	"net_cents",
	"receipt_count",
	"observation_window_seconds",
	"competition_matches",
	"product_lines",
	"route_lines",
	"transit_lines",
]
const CITY_BREAKDOWN_ROW_KEYS := ["district_index", "region_id", "breakdown"]
const COLOR_FLOW_SNAPSHOT_KEYS := [
	"valid",
	"ruleset_id",
	"player_index",
	"observation_window_seconds",
	"colors",
	"asset_recovery_observation_only",
]
const COLOR_FLOW_ENTRY_KEYS := ["color", "gdp_per_minute_cents", "gdp_per_minute"]
const DOWNSTREAM_SNAPSHOT_KEYS := [
	"batch_id",
	"batch_sequence",
	"batch_fingerprint",
	"flow_revision",
	"settled_at",
	"delta_milliseconds",
	"bankruptcy_transaction_id",
	"bankruptcy_request_fingerprint",
	"asset_recovery_transaction_id",
	"color_gdp_by_player",
	"asset_recovery_request_fingerprint",
	"snapshot_fingerprint",
]
const FINAL_RECEIPT_KEYS := [
	"completed",
	"recovered",
	"replayed",
	"reason_code",
	"batch_id",
	"batch_sequence",
	"batch_fingerprint",
	"flow_revision",
	"settled_at",
	"flow_delta_seconds",
	"receipt_count",
	"flow_result_summary",
	"trace",
]
const SAVE_KEYS := [
	"schema_version",
	"completed_through_batch_sequence",
	"pending_batch_id",
	"journal",
	"terminal_order",
	"legacy_bootstrap_reason",
]
const RECORD_KEYS := [
	"schema_version",
	"state",
	"batch_id",
	"batch_sequence",
	"batch_fingerprint",
	"batch",
	"region_ids",
	"district_indices",
	"player_count",
	"city_breakdown_by_district",
	"city_breakdown_fingerprint",
	"district_progress",
	"city_target_completed_by_district",
	"derivative_target_completed_by_district",
	"pulse_target_completed_by_district",
	"cash_target_completed_by_player",
	"cash_completed_by_player",
	"inputs_sealed",
	"downstream_snapshot",
	"bankruptcy_target_completed",
	"asset_recovery_target_completed",
	"downstream_progress",
	"public_receipt",
	"public_log_target_completed",
	"presentation_invalidation_completed",
	"tail_progress",
	"trace",
	"final_receipt",
]

var _flow_owner: CommodityFlowRuntimeController
var _world_session: WorldSessionState
var _derivative_owner: CityGdpDerivativeRuntimeController
var _visual_cue_owner: VisualCueRuntimeOwner
var _bankruptcy_owner: BankruptcyNeutralEstateRuntimeController
var _player_mana_owner: PlayerManaRuntimeController
var _public_log_port: PublicLogProducerPort
var _presentation_scheduler: TablePresentationRefreshScheduler
var _journal: Dictionary = {}
var _terminal_order: Array[String] = []
var _pending_batch_id := ""
var _completed_through_batch_sequence := 0
var _fault_stage := &""
var _apply_count := 0
var _replay_count := 0
var _reject_count := 0
var _recovery_count := 0
var _public_receipt_count := 0
var _public_log_apply_count := 0
var _presentation_invalidation_count := 0
var _last_trace: Array[String] = []
var _last_reason_code := "commodity_postcommit_idle"
var _legacy_bootstrap_reason := ""


func configure(
	flow_owner: CommodityFlowRuntimeController,
	world_session: WorldSessionState,
	derivative_owner: CityGdpDerivativeRuntimeController,
	visual_cue_owner: VisualCueRuntimeOwner,
	bankruptcy_owner: BankruptcyNeutralEstateRuntimeController,
	player_mana_owner: PlayerManaRuntimeController,
	public_log_port: PublicLogProducerPort,
	presentation_scheduler: TablePresentationRefreshScheduler
) -> Dictionary:
	_flow_owner = flow_owner
	_world_session = world_session
	_derivative_owner = derivative_owner
	_visual_cue_owner = visual_cue_owner
	_bankruptcy_owner = bankruptcy_owner
	_player_mana_owner = player_mana_owner
	_public_log_port = public_log_port
	_presentation_scheduler = presentation_scheduler
	return {
		"configured": is_ready(),
		"reason_code": "commodity_postcommit_consumer_ready" if is_ready() else "commodity_postcommit_dependency_missing",
	}


func is_ready() -> bool:
	return _flow_owner != null and is_instance_valid(_flow_owner) \
		and _world_session != null and is_instance_valid(_world_session) \
		and _derivative_owner != null and is_instance_valid(_derivative_owner) \
		and _visual_cue_owner != null and is_instance_valid(_visual_cue_owner) \
		and _bankruptcy_owner != null and is_instance_valid(_bankruptcy_owner) \
		and _player_mana_owner != null and is_instance_valid(_player_mana_owner) \
		and _public_log_port != null and is_instance_valid(_public_log_port) \
		and _presentation_scheduler != null and is_instance_valid(_presentation_scheduler)


func has_pending_batch() -> bool:
	return not _pending_batch_id.is_empty()


func prepare_committed_batch(batch: Dictionary) -> Dictionary:
	if not is_ready():
		return _reject("commodity_postcommit_consumer_not_ready")
	var staged := _stage_batch(batch)
	if bool(staged.get("replayed", false)):
		return _reject("commodity_postcommit_precommit_lineage_replay")
	return staged


func seal_committed_batch_inputs(batch: Dictionary) -> Dictionary:
	## Freezes every read-only input immediately after CommodityFlow commits and
	## before telemetry or other observers can run. Recovery therefore never
	## rebuilds GDP or asset-recovery inputs from a later live world revision.
	if not is_ready():
		return _reject("commodity_postcommit_consumer_not_ready")
	var staged := _stage_batch(batch)
	if not bool(staged.get("staged", false)):
		return staged
	var batch_id := str(staged.get("batch_id", ""))
	if bool(staged.get("replayed", false)):
		return {
			"sealed": true,
			"replayed": true,
			"batch_id": batch_id,
			"reason_code": "commodity_postcommit_inputs_already_finalized",
		}
	var record: Dictionary = (_journal.get(batch_id, {}) as Dictionary).duplicate(true) \
		if _journal.get(batch_id, {}) is Dictionary else {}
	var sealed := _seal_record_inputs(record)
	if not bool(sealed.get("valid", false)):
		record = (sealed.get("record", record) as Dictionary).duplicate(true) \
			if sealed.get("record", record) is Dictionary else record
		if bool(sealed.get("interrupted", false)):
			return _interrupted(
				record,
				str(sealed.get("reason_code", "commodity_postcommit_input_seal_interrupted"))
			)
		return _recovery_required(
			record,
			str(sealed.get("reason_code", "commodity_postcommit_input_seal_failed"))
		)
	record = (sealed.get("record", {}) as Dictionary).duplicate(true)
	return {
		"sealed": true,
		"replayed": false,
		"batch_id": batch_id,
		"batch_sequence": int(record.get("batch_sequence", -1)),
		"reason_code": "commodity_postcommit_inputs_sealed",
	}


func abort_prepared_batch(batch_id: String, expected_batch_fingerprint: String) -> Dictionary:
	if batch_id.is_empty() or _pending_batch_id != batch_id or not _journal.has(batch_id):
		return {"aborted": false, "reason_code": "commodity_postcommit_prepared_batch_missing"}
	var record: Dictionary = _journal[batch_id]
	if str(record.get("batch_fingerprint", "")) != expected_batch_fingerprint \
			or not _record_has_zero_progress(record):
		return {"aborted": false, "reason_code": "commodity_postcommit_prepared_batch_bound"}
	_journal.erase(batch_id)
	_pending_batch_id = ""
	return {"aborted": true, "reason_code": "commodity_postcommit_prepared_batch_aborted"}


func reset_state() -> void:
	_journal.clear()
	_terminal_order.clear()
	_pending_batch_id = ""
	_completed_through_batch_sequence = 0
	_fault_stage = &""
	_apply_count = 0
	_replay_count = 0
	_reject_count = 0
	_recovery_count = 0
	_public_receipt_count = 0
	_public_log_apply_count = 0
	_presentation_invalidation_count = 0
	_last_trace.clear()
	_last_reason_code = "commodity_postcommit_idle"
	_legacy_bootstrap_reason = ""


func consume_committed_batch(batch: Dictionary) -> Dictionary:
	if not is_ready():
		return _reject("commodity_postcommit_consumer_not_ready")
	var staged := _stage_batch(batch)
	if not bool(staged.get("staged", false)):
		return staged
	if bool(staged.get("replayed", false)):
		_replay_count += 1
		_last_reason_code = "commodity_postcommit_replayed"
		return _terminal_receipt(str(staged.get("batch_id", "")), true, false)
	return _apply_pending_batch(false)


func retry_pending_batch() -> Dictionary:
	if _pending_batch_id.is_empty():
		return {
			"completed": true,
			"recovered": false,
			"reason_code": "commodity_postcommit_idle",
			"pending_count": 0,
		}
	if not is_ready():
		return _reject("commodity_postcommit_consumer_not_ready")
	var result := _apply_pending_batch(true)
	if bool(result.get("completed", false)):
		_recovery_count += 1
	return result


func inject_test_failure(stage: StringName) -> void:
	_fault_stage = stage


func clear_test_failure() -> void:
	_fault_stage = &""


func to_save_data() -> Dictionary:
	return {
		"schema_version": JOURNAL_VERSION,
		"completed_through_batch_sequence": _completed_through_batch_sequence,
		"pending_batch_id": _pending_batch_id,
		"journal": _journal.duplicate(true),
		"terminal_order": _terminal_order.duplicate(),
		"legacy_bootstrap_reason": _legacy_bootstrap_reason,
	}


func preflight_save_data(
	data: Dictionary,
	restored_flow_batch_sequence: int,
	allow_legacy_missing := false
) -> Dictionary:
	if data.is_empty() and allow_legacy_missing:
		return {
			"accepted": true,
			"legacy_bootstrap": true,
			"completed_through_batch_sequence": maxi(0, restored_flow_batch_sequence),
		}
	if data.is_empty() or not _is_pure_data(data) \
			or not _has_exact_keys(data, SAVE_KEYS) \
			or not (data.get("schema_version") is int) \
			or int(data.get("schema_version", -1)) != JOURNAL_VERSION \
			or not (data.get("completed_through_batch_sequence") is int) \
			or not (data.get("pending_batch_id") is String) \
			or not (data.get("journal") is Dictionary) \
			or not (data.get("terminal_order") is Array) \
			or not (data.get("legacy_bootstrap_reason") is String):
		return {"accepted": false, "reason_code": "commodity_postcommit_save_header_invalid"}
	var completed := maxi(0, int(data.get("completed_through_batch_sequence", 0)))
	var pending_id := str(data.get("pending_batch_id", ""))
	var journal: Dictionary = data.get("journal", {}) if data.get("journal", {}) is Dictionary else {}
	var terminal_order: Array = data.get("terminal_order", []) if data.get("terminal_order", []) is Array else []
	var legacy_bootstrap_reason := str(data.get("legacy_bootstrap_reason", ""))
	if not legacy_bootstrap_reason in ["", LEGACY_BOOTSTRAP_REASON]:
		return {"accepted": false, "reason_code": "commodity_postcommit_legacy_bootstrap_reason_invalid"}
	if completed > maxi(0, restored_flow_batch_sequence) \
			or journal.size() > JOURNAL_LIMIT + int(not pending_id.is_empty()):
		return {"accepted": false, "reason_code": "commodity_postcommit_save_cursor_invalid"}
	var pending_count := 0
	var finalized_count := 0
	var seen_sequences: Dictionary = {}
	for batch_id_variant in journal.keys():
		if not (batch_id_variant is String or batch_id_variant is StringName):
			return {"accepted": false, "reason_code": "commodity_postcommit_save_record_invalid"}
		var batch_id := str(batch_id_variant)
		var record_variant: Variant = journal.get(batch_id_variant, {})
		if batch_id.is_empty() or not (record_variant is Dictionary):
			return {"accepted": false, "reason_code": "commodity_postcommit_save_record_invalid"}
		var record := record_variant as Dictionary
		var state := str(record.get("state", ""))
		var sequence := int(record.get("batch_sequence", -1))
		var stored_batch: Dictionary = record.get("batch", {}) if record.get("batch", {}) is Dictionary else {}
		var validation := _validate_batch(stored_batch, false)
		var record_region_ids: Array = record.get("region_ids", []) if record.get("region_ids", []) is Array else []
		var record_district_indices: Array = record.get("district_indices", []) if record.get("district_indices", []) is Array else []
		var player_count := int(record.get("player_count", -1))
		if not _has_exact_keys(record, RECORD_KEYS) \
				or not (record.get("schema_version") is int) \
				or not (record.get("state") is String) \
				or not (record.get("batch_id") is String) \
				or not (record.get("batch_sequence") is int) \
				or not (record.get("batch_fingerprint") is String) \
				or not (record.get("batch") is Dictionary) \
				or not (record.get("region_ids") is Array) \
				or not (record.get("district_indices") is Array) \
				or not (record.get("player_count") is int) \
				or not (record.get("city_breakdown_by_district") is Dictionary) \
				or not (record.get("city_breakdown_fingerprint") is String) \
				or not (record.get("district_progress") is Dictionary) \
				or not (record.get("city_target_completed_by_district") is Dictionary) \
				or not (record.get("derivative_target_completed_by_district") is Dictionary) \
				or not (record.get("pulse_target_completed_by_district") is Dictionary) \
				or not (record.get("cash_target_completed_by_player") is Dictionary) \
				or not (record.get("cash_completed_by_player") is Dictionary) \
				or not (record.get("inputs_sealed") is bool) \
				or not (record.get("downstream_snapshot") is Dictionary) \
				or not (record.get("downstream_progress") is int) \
				or not (record.get("bankruptcy_target_completed") is bool) \
				or not (record.get("asset_recovery_target_completed") is bool) \
				or not (record.get("public_receipt") is Dictionary) \
				or not (record.get("public_log_target_completed") is bool) \
				or not (record.get("presentation_invalidation_completed") is bool) \
				or not (record.get("tail_progress") is int) \
				or not (record.get("trace") is Array) \
				or not (record.get("final_receipt") is Dictionary) \
				or int(record.get("schema_version", -1)) != JOURNAL_VERSION \
				or str(record.get("batch_id", "")) != batch_id \
				or not VALID_STATES.has(state) or sequence <= 0 \
				or sequence > maxi(0, restored_flow_batch_sequence) \
				or seen_sequences.has(sequence) \
				or not bool(validation.get("valid", false)) \
				or str(stored_batch.get("batch_id", "")) != batch_id \
				or int(stored_batch.get("batch_sequence", -1)) != sequence \
				or record_region_ids != (validation.get("region_ids", []) as Array) \
				or record_district_indices.size() != record_region_ids.size() \
				or player_count < 0 or player_count > 8 \
				or str(record.get("batch_fingerprint", "")) != str(stored_batch.get("batch_fingerprint", "")) \
				or not _city_breakdown_snapshot_valid(record) \
				or not _record_progress_valid(record):
			return {"accepted": false, "reason_code": "commodity_postcommit_save_record_invalid"}
		seen_sequences[sequence] = true
		if state == "finalized":
			finalized_count += 1
			if sequence > completed:
				return {"accepted": false, "reason_code": "commodity_postcommit_terminal_cursor_invalid"}
		else:
			pending_count += 1
			if pending_id != batch_id or sequence != completed + 1:
				return {"accepted": false, "reason_code": "commodity_postcommit_pending_cursor_invalid"}
	if pending_count != int(not pending_id.is_empty()):
		return {"accepted": false, "reason_code": "commodity_postcommit_pending_identity_invalid"}
	if pending_id.is_empty():
		if completed != maxi(0, restored_flow_batch_sequence):
			return {"accepted": false, "reason_code": "commodity_postcommit_flow_cursor_mismatch"}
	else:
		var pending_record: Dictionary = journal.get(pending_id, {}) if journal.get(pending_id, {}) is Dictionary else {}
		var pending_sequence := int(pending_record.get("batch_sequence", -1))
		if pending_sequence != maxi(0, restored_flow_batch_sequence) or completed != pending_sequence - 1:
			return {"accepted": false, "reason_code": "commodity_postcommit_pending_flow_cursor_mismatch"}
	var seen_terminal_ids: Dictionary = {}
	for terminal_id_variant in terminal_order:
		if not (terminal_id_variant is String or terminal_id_variant is StringName):
			return {"accepted": false, "reason_code": "commodity_postcommit_terminal_order_invalid"}
		var terminal_id := str(terminal_id_variant)
		if seen_terminal_ids.has(terminal_id) or not journal.has(terminal_id) \
				or str((journal[terminal_id] as Dictionary).get("state", "")) != "finalized":
			return {"accepted": false, "reason_code": "commodity_postcommit_terminal_order_invalid"}
		seen_terminal_ids[terminal_id] = true
	if seen_terminal_ids.size() != finalized_count:
		return {"accepted": false, "reason_code": "commodity_postcommit_terminal_order_incomplete"}
	return {
		"accepted": true,
		"legacy_bootstrap": false,
		"completed_through_batch_sequence": completed,
		"pending_batch_id": pending_id,
		"journal": journal.duplicate(true),
		"terminal_order": terminal_order.duplicate(),
		"legacy_bootstrap_reason": legacy_bootstrap_reason,
	}


func apply_save_data(
	data: Dictionary,
	restored_flow_batch_sequence: int,
	allow_legacy_missing := false
) -> Dictionary:
	var preflight := preflight_save_data(data, restored_flow_batch_sequence, allow_legacy_missing)
	if not bool(preflight.get("accepted", false)):
		return {"applied": false, "reason_code": str(preflight.get("reason_code", "commodity_postcommit_save_invalid"))}
	_journal.clear()
	_terminal_order.clear()
	_pending_batch_id = ""
	if bool(preflight.get("legacy_bootstrap", false)):
		_completed_through_batch_sequence = int(preflight.get("completed_through_batch_sequence", 0))
		_legacy_bootstrap_reason = LEGACY_BOOTSTRAP_REASON
	else:
		_completed_through_batch_sequence = int(preflight.get("completed_through_batch_sequence", 0))
		_pending_batch_id = str(preflight.get("pending_batch_id", ""))
		_journal = (preflight.get("journal", {}) as Dictionary).duplicate(true)
		for batch_id_variant in preflight.get("terminal_order", []):
			_terminal_order.append(str(batch_id_variant))
		_legacy_bootstrap_reason = str(preflight.get("legacy_bootstrap_reason", ""))
	_last_trace.clear()
	_last_reason_code = "commodity_postcommit_save_restored"
	return {
		"applied": true,
		"reason_code": "commodity_postcommit_save_restored",
		"pending_count": int(not _pending_batch_id.is_empty()),
		"completed_through_batch_sequence": _completed_through_batch_sequence,
	}


func debug_snapshot() -> Dictionary:
	return {
		"consumer_ready": is_ready(),
		"scene_owned": true,
		"runtime_owner": "CommodityFlowPostCommitReceiptConsumer",
		"owns_commodity_flow": false,
		"owns_cash": false,
		"owns_gdp_formula": false,
		"owns_derivative_positions": false,
		"owns_visual_state": false,
		"holds_main_reference": false,
		"journal_version": JOURNAL_VERSION,
		"journal_count": _journal.size(),
		"pending_count": int(not _pending_batch_id.is_empty()),
		"completed_through_batch_sequence": _completed_through_batch_sequence,
		"apply_count": _apply_count,
		"replay_count": _replay_count,
		"reject_count": _reject_count,
		"recovery_count": _recovery_count,
		"public_receipt_count": _public_receipt_count,
		"public_log_apply_count": _public_log_apply_count,
		"presentation_invalidation_count": _presentation_invalidation_count,
		"last_trace": _last_trace.duplicate(),
		"last_reason_code": _last_reason_code,
		"legacy_bootstrap_reason": _legacy_bootstrap_reason,
		"private_payload_exposed": false,
	}


static func batch_fingerprint(batch: Dictionary) -> String:
	var canonical := batch.duplicate(true)
	canonical.erase("batch_fingerprint")
	return JSON.stringify(_canonicalize(canonical)).sha256_text()


func _stage_batch(batch: Dictionary) -> Dictionary:
	var validation := _validate_batch(batch)
	if not bool(validation.get("valid", false)):
		return _reject(str(validation.get("reason_code", "commodity_postcommit_batch_invalid")))
	var batch_id := str(batch.get("batch_id", ""))
	var batch_sequence := int(batch.get("batch_sequence", -1))
	var fingerprint := str(batch.get("batch_fingerprint", ""))
	if _journal.has(batch_id):
		var existing: Dictionary = _journal[batch_id]
		if str(existing.get("batch_fingerprint", "")) != fingerprint:
			return _reject("commodity_postcommit_batch_binding_collision")
		if str(existing.get("state", "")) == "finalized":
			return {"staged": true, "replayed": true, "batch_id": batch_id}
		if _pending_batch_id != batch_id:
			return _reject("commodity_postcommit_pending_identity_collision")
		return {"staged": true, "replayed": false, "batch_id": batch_id}
	if not _pending_batch_id.is_empty():
		return _reject("commodity_postcommit_pending_batch_blocks_new_batch")
	if batch_sequence <= _completed_through_batch_sequence:
		return _reject("commodity_postcommit_lineage_evicted")
	if batch_sequence != _completed_through_batch_sequence + 1:
		return _reject("commodity_postcommit_batch_sequence_gap")
	var record := {
		"schema_version": JOURNAL_VERSION,
		"state": "pending",
		"batch_id": batch_id,
		"batch_sequence": batch_sequence,
		"batch_fingerprint": fingerprint,
		"batch": batch.duplicate(true),
		"region_ids": (validation.get("region_ids", []) as Array).duplicate(),
		"district_indices": (validation.get("district_indices", []) as Array).duplicate(),
		"player_count": _world_session.players.size(),
		"city_breakdown_by_district": {},
		"city_breakdown_fingerprint": "",
		"district_progress": {},
		"city_target_completed_by_district": {},
		"derivative_target_completed_by_district": {},
		"pulse_target_completed_by_district": {},
		"cash_target_completed_by_player": {},
		"cash_completed_by_player": {},
		"inputs_sealed": false,
		"downstream_snapshot": {},
		"bankruptcy_target_completed": false,
		"asset_recovery_target_completed": false,
		"downstream_progress": 0,
		"public_receipt": {},
		"public_log_target_completed": false,
		"presentation_invalidation_completed": false,
		"tail_progress": 0,
		"trace": [],
		"final_receipt": {},
	}
	_journal[batch_id] = record
	_pending_batch_id = batch_id
	return {"staged": true, "replayed": false, "batch_id": batch_id}


func _seal_record_inputs(record: Dictionary) -> Dictionary:
	var runtime_binding := _runtime_record_binding(record)
	if not bool(runtime_binding.get("valid", false)):
		return {
			"valid": false,
			"reason_code": str(runtime_binding.get("reason_code", "commodity_postcommit_runtime_binding_invalid")),
			"record": record,
		}
	var batch: Dictionary = (record.get("batch", {}) as Dictionary).duplicate(true) \
		if record.get("batch", {}) is Dictionary else {}
	var receipt_ids: Array = batch.get("receipt_ids", []) if batch.get("receipt_ids", []) is Array else []
	var observer_snapshot := _ensure_city_breakdown_snapshot(record, receipt_ids)
	if not bool(observer_snapshot.get("valid", false)):
		return {
			"valid": false,
			"reason_code": str(observer_snapshot.get("reason_code", "commodity_postcommit_city_breakdown_invalid")),
			"record": (observer_snapshot.get("record", record) as Dictionary).duplicate(true) \
				if observer_snapshot.get("record", record) is Dictionary else record,
		}
	record = (observer_snapshot.get("record", {}) as Dictionary).duplicate(true)
	if _consume_fault(&"after_city_breakdown_snapshot"):
		return {
			"valid": false,
			"interrupted": true,
			"reason_code": "fault_injected_after_city_breakdown_snapshot",
			"record": record,
		}
	var downstream_snapshot := _ensure_downstream_snapshot(record)
	if not bool(downstream_snapshot.get("valid", false)):
		return {
			"valid": false,
			"reason_code": str(downstream_snapshot.get("reason_code", "commodity_postcommit_downstream_snapshot_invalid")),
			"record": (downstream_snapshot.get("record", record) as Dictionary).duplicate(true) \
				if downstream_snapshot.get("record", record) is Dictionary else record,
		}
	record = (downstream_snapshot.get("record", {}) as Dictionary).duplicate(true)
	record["inputs_sealed"] = true
	_store_record(record)
	return {"valid": true, "reason_code": "commodity_postcommit_inputs_sealed", "record": record}


func _apply_pending_batch(recovered: bool) -> Dictionary:
	var batch_id := _pending_batch_id
	if batch_id.is_empty() or not _journal.has(batch_id):
		return _reject("commodity_postcommit_pending_record_missing")
	var record: Dictionary = (_journal[batch_id] as Dictionary).duplicate(true)
	var sealed := _seal_record_inputs(record)
	record = (sealed.get("record", record) as Dictionary).duplicate(true) \
		if sealed.get("record", record) is Dictionary else record
	if not bool(sealed.get("valid", false)):
		if bool(sealed.get("interrupted", false)):
			return _interrupted(record, str(sealed.get("reason_code", "commodity_postcommit_input_seal_interrupted")))
		return _recovery_required(record, str(sealed.get("reason_code", "commodity_postcommit_input_seal_failed")))
	var batch: Dictionary = (record.get("batch", {}) as Dictionary).duplicate(true)
	var receipt_ids: Array = batch.get("receipt_ids", []) if batch.get("receipt_ids", []) is Array else []
	var city_breakdowns: Dictionary = record.get("city_breakdown_by_district", {}) if record.get("city_breakdown_by_district", {}) is Dictionary else {}
	for district_index_variant in ([] if receipt_ids.is_empty() else record.get("district_indices", [])):
		var district_index := int(district_index_variant)
		var progress: Dictionary = record.get("district_progress", {}) if record.get("district_progress", {}) is Dictionary else {}
		var stage := int(progress.get(str(district_index), 0))
		if stage < 1:
			var city_targets: Dictionary = record.get("city_target_completed_by_district", {}) if record.get("city_target_completed_by_district", {}) is Dictionary else {}
			if not bool(city_targets.get(str(district_index), false)):
				var frozen_row: Dictionary = city_breakdowns.get(str(district_index), {}) \
					if city_breakdowns.get(str(district_index), {}) is Dictionary else {}
				var breakdown: Dictionary = (frozen_row.get("breakdown", {}) as Dictionary).duplicate(true) \
					if frozen_row.get("breakdown", {}) is Dictionary else {}
				var city_result := _world_session.apply_commodity_postcommit_city_gdp_snapshot(
					int(record.get("batch_sequence", -1)),
					batch_id,
					str(record.get("batch_fingerprint", "")),
					str(record.get("city_breakdown_fingerprint", "")),
					district_index,
					breakdown
				)
				if not bool(city_result.get("applied", false)):
					return _recovery_required(record, str(city_result.get("reason_code", "commodity_postcommit_city_gdp_failed")))
				city_targets[str(district_index)] = true
				record["city_target_completed_by_district"] = city_targets
				_store_record(record)
			if _consume_fault(&"after_city_target_before_mark"):
				return _interrupted(record, "fault_injected_after_city_target_before_mark")
			progress[str(district_index)] = 1
			record["district_progress"] = progress
			_append_trace(record, "district:%d:gdp_history" % district_index)
			_store_record(record)
		stage = int((record.get("district_progress", {}) as Dictionary).get(str(district_index), 0))
		if stage < 2:
			var derivative_targets: Dictionary = record.get("derivative_target_completed_by_district", {}) if record.get("derivative_target_completed_by_district", {}) is Dictionary else {}
			if not bool(derivative_targets.get(str(district_index), false)):
				var due_count := _due_derivative_count(district_index)
				var settlement := _derivative_owner.settle_district(
					district_index,
					_world_session.commodity_postcommit_city_gdp(district_index),
					GDP_SOURCE_LABEL,
					false
				)
				if int(settlement.get("settled_count", 0)) != due_count:
					return _interrupted(record, str(settlement.get("reason", "commodity_postcommit_derivative_failed")))
				derivative_targets[str(district_index)] = true
				record["derivative_target_completed_by_district"] = derivative_targets
				_store_record(record)
			if _consume_fault(&"after_derivative_target_before_mark"):
				return _interrupted(record, "fault_injected_after_derivative_target_before_mark")
			progress = record.get("district_progress", {}) as Dictionary
			progress[str(district_index)] = 2
			record["district_progress"] = progress
			_append_trace(record, "district:%d:derivative" % district_index)
			_store_record(record)
		stage = int((record.get("district_progress", {}) as Dictionary).get(str(district_index), 0))
		if stage < 3:
			var event_id := "%s:district:%d" % [batch_id, district_index]
			var pulse_targets: Dictionary = record.get("pulse_target_completed_by_district", {}) if record.get("pulse_target_completed_by_district", {}) is Dictionary else {}
			if not bool(pulse_targets.get(str(district_index), false)):
				var pulse := _visual_cue_owner.pulse_district_once(event_id, district_index, PULSE_COLOR)
				if not bool(pulse.get("pulsed", false)):
					return _interrupted(record, str(pulse.get("reason", "commodity_postcommit_pulse_failed")))
				pulse_targets[str(district_index)] = true
				record["pulse_target_completed_by_district"] = pulse_targets
				_store_record(record)
			if _consume_fault(&"after_pulse_target_before_mark"):
				return _interrupted(record, "fault_injected_after_pulse_target_before_mark")
			progress = record.get("district_progress", {}) as Dictionary
			progress[str(district_index)] = 3
			record["district_progress"] = progress
			_append_trace(record, "district:%d:pulse" % district_index)
			_store_record(record)
	var cash_completed: Dictionary = record.get("cash_completed_by_player", {}) if record.get("cash_completed_by_player", {}) is Dictionary else {}
	var cash_targets: Dictionary = record.get("cash_target_completed_by_player", {}) if record.get("cash_target_completed_by_player", {}) is Dictionary else {}
	for player_index in range(0 if receipt_ids.is_empty() else int(record.get("player_count", 0))):
		if bool(cash_completed.get(str(player_index), false)):
			continue
		if not bool(cash_targets.get(str(player_index), false)):
			var cash_result := _world_session.record_commodity_postcommit_cash_snapshot(
				int(record.get("batch_sequence", -1)),
				batch_id,
				str(record.get("batch_fingerprint", "")),
				player_index
			)
			if not bool(cash_result.get("applied", false)):
				return _recovery_required(record, str(cash_result.get("reason_code", "commodity_postcommit_cash_snapshot_failed")))
			cash_targets[str(player_index)] = true
			record["cash_target_completed_by_player"] = cash_targets
			_store_record(record)
		if _consume_fault(&"after_cash_target_before_mark"):
			return _interrupted(record, "fault_injected_after_cash_target_before_mark")
		cash_completed[str(player_index)] = true
		record["cash_completed_by_player"] = cash_completed
		_append_trace(record, "player:%d:cash_snapshot" % player_index)
		_store_record(record)
	return _apply_downstream_and_finalize(record, recovered)


func _apply_downstream_and_finalize(record: Dictionary, recovered: bool) -> Dictionary:
	var snapshot_result := _ensure_downstream_snapshot(record)
	if not bool(snapshot_result.get("valid", false)):
		return _recovery_required(record, str(snapshot_result.get("reason_code", "commodity_postcommit_downstream_snapshot_invalid")))
	record = (snapshot_result.get("record", {}) as Dictionary).duplicate(true)
	var downstream: Dictionary = record.get("downstream_snapshot", {}) if record.get("downstream_snapshot", {}) is Dictionary else {}
	var progress := int(record.get("downstream_progress", 0))
	if progress < 1:
		if not bool(record.get("bankruptcy_target_completed", false)):
			var bankruptcy := _bankruptcy_owner.settle_checkpoint({
				"transaction_id": str(downstream.get("bankruptcy_transaction_id", "")),
				"reason_code": "post_sale_receipt",
				"occurred_at": float(downstream.get("settled_at", 0.0)),
				"source_fingerprint": str(downstream.get("batch_fingerprint", "")),
			})
			if not bool(bankruptcy.get("finalized", false)):
				return _recovery_required(record, str(bankruptcy.get("reason_code", "commodity_postcommit_bankruptcy_failed")))
			record["bankruptcy_target_completed"] = true
			_store_record(record)
		if _consume_fault(&"after_bankruptcy_target_before_mark"):
			return _interrupted(record, "fault_injected_after_bankruptcy_target_before_mark")
		record["downstream_progress"] = 1
		_append_trace(record, "bankruptcy_checkpoint")
		_store_record(record)
	progress = int(record.get("downstream_progress", 0))
	if progress < 2:
		if not bool(record.get("asset_recovery_target_completed", false)):
			var recovery := _player_mana_owner.advance_once(
				str(downstream.get("asset_recovery_transaction_id", "")),
				int(downstream.get("delta_milliseconds", 0)),
				float(downstream.get("settled_at", 0.0)),
				(downstream.get("color_gdp_by_player", {}) as Dictionary).duplicate(true)
			)
			if not bool(recovery.get("advanced", false)):
				return _recovery_required(record, str(recovery.get("reason", "commodity_postcommit_asset_recovery_failed")))
			record["asset_recovery_target_completed"] = true
			_store_record(record)
		if _consume_fault(&"after_asset_recovery_target_before_mark"):
			return _interrupted(record, "fault_injected_after_asset_recovery_target_before_mark")
		record["downstream_progress"] = 2
		_append_trace(record, "asset_recovery")
		_store_record(record)
	return _apply_public_tail_and_finalize(record, recovered)


func _apply_public_tail_and_finalize(record: Dictionary, recovered: bool) -> Dictionary:
	var batch: Dictionary = record.get("batch", {}) if record.get("batch", {}) is Dictionary else {}
	var receipt_ids: Array = batch.get("receipt_ids", []) if batch.get("receipt_ids", []) is Array else []
	if receipt_ids.is_empty():
		if not (record.get("public_receipt", {}) as Dictionary).is_empty() \
				or bool(record.get("public_log_target_completed", false)) \
				or bool(record.get("presentation_invalidation_completed", false)):
			return _recovery_required(record, "commodity_postcommit_empty_public_tail_invalid")
		if int(record.get("tail_progress", 0)) < 2:
			record["tail_progress"] = 2
			_append_trace(record, "public_tail:empty_noop")
			_store_record(record)
		return _finalize_record(record, recovered)

	var public_result := _ensure_public_receipt(record)
	if not bool(public_result.get("valid", false)):
		return _recovery_required(record, str(public_result.get("reason_code", "commodity_postcommit_public_receipt_invalid")))
	record = (public_result.get("record", {}) as Dictionary).duplicate(true)
	var public_receipt := CommodityFlowPostCommitPublicReceipt.from_dictionary(
		record.get("public_receipt", {}) as Dictionary
	)
	if not public_receipt.is_valid() or not public_receipt.matches_committed_batch(batch):
		return _recovery_required(record, "commodity_postcommit_public_receipt_binding_invalid")
	var log_receipt := public_receipt.to_public_log_receipt()
	if log_receipt == null or not log_receipt.is_valid():
		return _recovery_required(record, "commodity_postcommit_public_log_receipt_invalid")
	var expected_log_fingerprint := log_receipt.fingerprint()
	var target_binding := _public_log_port.receipt_binding(log_receipt.receipt_id)
	if not target_binding.is_empty() \
			and str(target_binding.get("receipt_fingerprint", "")) != expected_log_fingerprint:
		return _recovery_required(record, "commodity_postcommit_public_log_target_collision")

	var tail_progress := int(record.get("tail_progress", 0))
	if tail_progress < 1 or target_binding.is_empty():
		var public_apply := _public_log_port.append_receipt(log_receipt)
		var public_accepted := bool(public_apply.get("applied", false)) \
			or bool(public_apply.get("duplicate", false))
		if not public_accepted \
				or str(public_apply.get("receipt_fingerprint", "")) != expected_log_fingerprint:
			return _recovery_required(
				record,
				str(public_apply.get("reason_code", "commodity_postcommit_public_log_target_failed"))
			)
		if bool(public_apply.get("applied", false)):
			_public_log_apply_count += 1
		if _consume_fault(&"after_public_log_target_before_mark"):
			return _interrupted(record, "fault_injected_after_public_log_target_before_mark")
		record["public_log_target_completed"] = true
		record["tail_progress"] = maxi(1, tail_progress)
		_append_trace(record, "public_receipt")
		_store_record(record)

	tail_progress = int(record.get("tail_progress", 0))
	if tail_progress < 2:
		var refresh := _presentation_scheduler.request_immediate(TablePresentationRefreshScheduler.LIVE_KIND)
		if not bool(refresh.get("accepted", false)):
			return _recovery_required(
				record,
				str(refresh.get("reason", "commodity_postcommit_presentation_invalidation_failed"))
			)
		if _consume_fault(&"after_presentation_invalidation_before_mark"):
			return _interrupted(record, "fault_injected_after_presentation_invalidation_before_mark")
		record["presentation_invalidation_completed"] = true
		record["tail_progress"] = 2
		_presentation_invalidation_count += 1
		_append_trace(record, "presentation_refresh_requested")
		_store_record(record)
	elif bool(record.get("presentation_invalidation_completed", false)):
		# The scheduler is deliberately not a save owner. Reasserting a due bit is
		# idempotent and guarantees a cold-restored pending tail still refreshes.
		var restored_refresh := _presentation_scheduler.request_immediate(TablePresentationRefreshScheduler.LIVE_KIND)
		if not bool(restored_refresh.get("accepted", false)):
			return _recovery_required(record, "commodity_postcommit_presentation_rehydrate_failed")
	return _finalize_record(record, recovered)


func _ensure_public_receipt(record: Dictionary) -> Dictionary:
	var batch: Dictionary = record.get("batch", {}) if record.get("batch", {}) is Dictionary else {}
	var receipt_ids: Array = batch.get("receipt_ids", []) if batch.get("receipt_ids", []) is Array else []
	var existing: Dictionary = record.get("public_receipt", {}) \
		if record.get("public_receipt", {}) is Dictionary else {}
	if receipt_ids.is_empty():
		return {
			"valid": existing.is_empty(),
			"reason_code": "commodity_postcommit_empty_public_receipt_invalid" if not existing.is_empty() else "",
			"record": record,
		}
	if not existing.is_empty():
		var restored := CommodityFlowPostCommitPublicReceipt.from_dictionary(existing)
		return {
			"valid": restored.is_valid() and restored.matches_committed_batch(batch),
			"reason_code": "commodity_postcommit_public_receipt_binding_invalid",
			"record": record,
		}
	var receipt := CommodityFlowPostCommitPublicReceipt.from_committed_batch(batch)
	if not receipt.is_valid() or not receipt.matches_committed_batch(batch):
		return {
			"valid": false,
			"reason_code": "commodity_postcommit_public_receipt_derivation_failed",
			"record": record,
		}
	record["public_receipt"] = receipt.to_dictionary()
	_public_receipt_count += 1
	_store_record(record)
	return {"valid": true, "reason_code": "", "record": record}


func _ensure_downstream_snapshot(record: Dictionary) -> Dictionary:
	var existing: Dictionary = record.get("downstream_snapshot", {}) if record.get("downstream_snapshot", {}) is Dictionary else {}
	if not existing.is_empty():
		return {"valid": _downstream_snapshot_valid(record, existing), "record": record}
	var batch: Dictionary = record.get("batch", {}) if record.get("batch", {}) is Dictionary else {}
	var batch_id := str(record.get("batch_id", ""))
	var color_gdp_by_player: Dictionary = {}
	for player_index in range(int(record.get("player_count", 0))):
		var color_snapshot := _flow_owner.player_color_flow_snapshot(player_index)
		if not _is_pure_data(color_snapshot):
			return {"valid": false, "reason_code": "commodity_postcommit_asset_snapshot_not_pure"}
		color_gdp_by_player[str(player_index)] = color_snapshot.duplicate(true)
	var snapshot := {
		"batch_id": batch_id,
		"batch_sequence": int(record.get("batch_sequence", -1)),
		"batch_fingerprint": str(record.get("batch_fingerprint", "")),
		"flow_revision": int(batch.get("flow_revision", -1)),
		"settled_at": float(batch.get("settled_at", 0.0)),
		"delta_milliseconds": maxi(1, int(round(float(batch.get("flow_delta_seconds", 0.0)) * 1000.0))),
		"bankruptcy_transaction_id": "bankruptcy:%s" % batch_id,
		"asset_recovery_transaction_id": "asset-recovery:%s" % batch_id,
		"color_gdp_by_player": color_gdp_by_player,
	}
	var bankruptcy_request := {
		"transaction_id": str(snapshot.get("bankruptcy_transaction_id", "")),
		"reason_code": "post_sale_receipt",
		"occurred_at": float(snapshot.get("settled_at", 0.0)),
		"source_fingerprint": str(snapshot.get("batch_fingerprint", "")),
	}
	snapshot["bankruptcy_request_fingerprint"] = _bankruptcy_request_fingerprint(bankruptcy_request)
	var asset_request := {
		"transaction_id": str(snapshot.get("asset_recovery_transaction_id", "")),
		"delta_milliseconds": int(snapshot.get("delta_milliseconds", 0)),
		"game_time": float(snapshot.get("settled_at", 0.0)),
		"color_gdp_by_player": color_gdp_by_player.duplicate(true),
	}
	snapshot["asset_recovery_request_fingerprint"] = JSON.stringify(_canonicalize(asset_request)).sha256_text()
	snapshot["snapshot_fingerprint"] = JSON.stringify(_canonicalize(snapshot)).sha256_text()
	if not _downstream_snapshot_valid(record, snapshot):
		return {"valid": false, "reason_code": "commodity_postcommit_downstream_snapshot_invalid"}
	record["downstream_snapshot"] = snapshot
	_store_record(record)
	return {"valid": true, "record": record}


func _downstream_snapshot_valid(record: Dictionary, snapshot: Dictionary) -> bool:
	var batch: Dictionary = record.get("batch", {}) if record.get("batch", {}) is Dictionary else {}
	var expected_delta_milliseconds := maxi(1, int(round(float(batch.get("flow_delta_seconds", 0.0)) * 1000.0)))
	if not _is_pure_data(snapshot) or not _has_exact_keys(snapshot, DOWNSTREAM_SNAPSHOT_KEYS) \
			or not (snapshot.get("batch_id") is String) \
			or not (snapshot.get("batch_sequence") is int) \
			or not (snapshot.get("batch_fingerprint") is String) \
			or not (snapshot.get("flow_revision") is int) \
			or not (snapshot.get("settled_at") is float) \
			or not (snapshot.get("delta_milliseconds") is int) \
			or not (snapshot.get("bankruptcy_transaction_id") is String) \
			or not (snapshot.get("bankruptcy_request_fingerprint") is String) \
			or not (snapshot.get("asset_recovery_transaction_id") is String) \
			or not (snapshot.get("asset_recovery_request_fingerprint") is String) \
			or not (snapshot.get("snapshot_fingerprint") is String) \
			or str(snapshot.get("batch_id", "")) != str(record.get("batch_id", "")) \
			or int(snapshot.get("batch_sequence", -1)) != int(record.get("batch_sequence", -2)) \
			or str(snapshot.get("batch_fingerprint", "")) != str(record.get("batch_fingerprint", "")) \
			or int(snapshot.get("flow_revision", -1)) != int(batch.get("flow_revision", -2)) \
			or int(snapshot.get("delta_milliseconds", 0)) != expected_delta_milliseconds \
			or not is_finite(float(snapshot.get("settled_at", -1.0))) \
			or not is_equal_approx(float(snapshot.get("settled_at", -1.0)), float(batch.get("settled_at", -2.0))) \
			or str(snapshot.get("bankruptcy_transaction_id", "")) != "bankruptcy:%s" % str(record.get("batch_id", "")) \
			or str(snapshot.get("bankruptcy_request_fingerprint", "")).length() != 64 \
			or str(snapshot.get("asset_recovery_transaction_id", "")) != "asset-recovery:%s" % str(record.get("batch_id", "")) \
			or str(snapshot.get("asset_recovery_request_fingerprint", "")).length() != 64 \
			or not (snapshot.get("color_gdp_by_player", {}) is Dictionary):
		return false
	var expected_bankruptcy_request := {
		"transaction_id": str(snapshot.get("bankruptcy_transaction_id", "")),
		"reason_code": "post_sale_receipt",
		"occurred_at": float(snapshot.get("settled_at", 0.0)),
		"source_fingerprint": str(snapshot.get("batch_fingerprint", "")),
	}
	if str(snapshot.get("bankruptcy_request_fingerprint", "")) \
			!= _bankruptcy_request_fingerprint(expected_bankruptcy_request):
		return false
	var color_gdp_by_player := snapshot.get("color_gdp_by_player", {}) as Dictionary
	var player_count := int(record.get("player_count", -1))
	if player_count < 0 or color_gdp_by_player.size() != player_count:
		return false
	for player_index in range(player_count):
		var player_key := str(player_index)
		if not color_gdp_by_player.has(player_key) or not (color_gdp_by_player.get(player_key) is Dictionary) \
				or not _color_flow_snapshot_valid(color_gdp_by_player.get(player_key) as Dictionary, player_index):
			return false
	for player_key_variant in color_gdp_by_player.keys():
		if not (player_key_variant is String or player_key_variant is StringName) \
				or not _canonical_index_key(str(player_key_variant)) \
				or int(str(player_key_variant)) >= player_count:
			return false
	var expected_asset_request := {
		"transaction_id": str(snapshot.get("asset_recovery_transaction_id", "")),
		"delta_milliseconds": int(snapshot.get("delta_milliseconds", 0)),
		"game_time": float(snapshot.get("settled_at", 0.0)),
		"color_gdp_by_player": color_gdp_by_player.duplicate(true),
	}
	if str(snapshot.get("asset_recovery_request_fingerprint", "")) \
			!= JSON.stringify(_canonicalize(expected_asset_request)).sha256_text():
		return false
	var canonical := snapshot.duplicate(true)
	var fingerprint := str(canonical.get("snapshot_fingerprint", ""))
	canonical.erase("snapshot_fingerprint")
	return fingerprint == JSON.stringify(_canonicalize(canonical)).sha256_text()


func _color_flow_snapshot_valid(snapshot: Dictionary, expected_player_index: int) -> bool:
	if not _is_pure_data(snapshot) or not _has_exact_keys(snapshot, COLOR_FLOW_SNAPSHOT_KEYS) \
			or not (snapshot.get("valid") is bool) or not bool(snapshot.get("valid", false)) \
			or not (snapshot.get("ruleset_id") is String) or str(snapshot.get("ruleset_id", "")) != RULESET_ID \
			or not (snapshot.get("player_index") is int) or int(snapshot.get("player_index", -1)) != expected_player_index \
			or not (snapshot.get("observation_window_seconds") is float) \
			or not is_finite(float(snapshot.get("observation_window_seconds", -1.0))) \
			or float(snapshot.get("observation_window_seconds", -1.0)) <= 0.0 \
			or not (snapshot.get("colors") is Dictionary) \
			or not (snapshot.get("asset_recovery_observation_only") is bool) \
			or not bool(snapshot.get("asset_recovery_observation_only", false)):
		return false
	var colors := snapshot.get("colors", {}) as Dictionary
	for color_id_variant in colors.keys():
		if not (color_id_variant is String or color_id_variant is StringName) \
				or not (colors.get(color_id_variant) is Dictionary):
			return false
		var color_id := str(color_id_variant)
		var entry := colors.get(color_id_variant) as Dictionary
		if color_id.is_empty() or not _has_exact_keys(entry, COLOR_FLOW_ENTRY_KEYS) \
				or not (entry.get("color") is String) or str(entry.get("color", "")) != color_id \
				or not (entry.get("gdp_per_minute_cents") is int) \
				or int(entry.get("gdp_per_minute_cents", -1)) < 0 \
				or not (entry.get("gdp_per_minute") is int) \
				or int(entry.get("gdp_per_minute", -1)) < 0:
			return false
	return true


func _bankruptcy_request_fingerprint(request: Dictionary) -> String:
	return JSON.stringify([
		str(request.get("transaction_id", "")),
		str(request.get("reason_code", "")),
		float(request.get("occurred_at", 0.0)),
		str(request.get("source_fingerprint", "")),
	]).sha256_text()


func _finalize_record(record: Dictionary, recovered: bool) -> Dictionary:
	var batch_id := str(record.get("batch_id", ""))
	var batch: Dictionary = record.get("batch", {}) if record.get("batch", {}) is Dictionary else {}
	record["state"] = "finalized"
	_append_trace(record, "finalize")
	var receipt := {
		"completed": true,
		"recovered": recovered,
		"replayed": false,
		"reason_code": "commodity_postcommit_recovered" if recovered else "commodity_postcommit_applied",
		"batch_id": batch_id,
		"batch_sequence": int(record.get("batch_sequence", -1)),
		"batch_fingerprint": str(record.get("batch_fingerprint", "")),
		"flow_revision": int(batch.get("flow_revision", -1)),
		"settled_at": float(batch.get("settled_at", 0.0)),
		"flow_delta_seconds": float(batch.get("flow_delta_seconds", 0.0)),
		"receipt_count": (batch.get("receipt_ids", []) as Array).size() if batch.get("receipt_ids", []) is Array else 0,
		"flow_result_summary": (batch.get("flow_result_summary", {}) as Dictionary).duplicate(true) if batch.get("flow_result_summary", {}) is Dictionary else {},
		"trace": (record.get("trace", []) as Array).duplicate() if record.get("trace", []) is Array else [],
	}
	record["final_receipt"] = receipt.duplicate(true)
	_journal[batch_id] = record
	_pending_batch_id = ""
	_completed_through_batch_sequence = maxi(
		_completed_through_batch_sequence,
		int(record.get("batch_sequence", 0))
	)
	_terminal_order.append(batch_id)
	_prune_terminal_records()
	_apply_count += 1
	_last_trace.clear()
	for trace_variant in receipt.get("trace", []):
		_last_trace.append(str(trace_variant))
	_last_reason_code = str(receipt.get("reason_code", "commodity_postcommit_applied"))
	return receipt


func _terminal_receipt(batch_id: String, replayed: bool, recovered: bool) -> Dictionary:
	if not _journal.has(batch_id):
		return _reject("commodity_postcommit_terminal_record_missing")
	var record: Dictionary = _journal[batch_id]
	var receipt: Dictionary = (record.get("final_receipt", {}) as Dictionary).duplicate(true) if record.get("final_receipt", {}) is Dictionary else {}
	receipt["completed"] = true
	receipt["replayed"] = replayed
	receipt["recovered"] = recovered
	receipt["reason_code"] = "commodity_postcommit_replayed" if replayed else str(receipt.get("reason_code", "commodity_postcommit_applied"))
	return receipt


func _validate_batch(batch: Dictionary, resolve_districts := true) -> Dictionary:
	if not _is_pure_data(batch):
		return {"valid": false, "reason_code": "commodity_postcommit_batch_not_pure_data"}
	var sequence := int(batch.get("batch_sequence", -1))
	var receipts: Array = batch.get("receipts", []) if batch.get("receipts", []) is Array else []
	var receipt_ids: Array = batch.get("receipt_ids", []) if batch.get("receipt_ids", []) is Array else []
	if sequence <= 0 or str(batch.get("batch_id", "")) != "commodity-flow-batch-%010d" % sequence \
			or str(batch.get("ruleset_id", "")) != RULESET_ID \
			or int(batch.get("flow_revision", -1)) != int(batch.get("flow_revision_before", -2)) + 1 \
			or int(batch.get("flow_revision", -1)) <= 0 \
			or not is_finite(float(batch.get("flow_delta_seconds", -1.0))) \
			or float(batch.get("flow_delta_seconds", -1.0)) <= 0.0 \
			or not is_finite(float(batch.get("settled_at", -1.0))) \
			or float(batch.get("settled_at", -1.0)) < 0.0 \
			or str(batch.get("batch_fingerprint", "")) != batch_fingerprint(batch):
		return {"valid": false, "reason_code": "commodity_postcommit_batch_binding_invalid"}
	var extracted_ids: Array = []
	var seen_ids: Dictionary = {}
	var region_ids: Dictionary = {}
	for receipt_variant in receipts:
		if not (receipt_variant is Dictionary):
			return {"valid": false, "reason_code": "commodity_postcommit_receipt_invalid"}
		var receipt := receipt_variant as Dictionary
		var receipt_id := str(receipt.get("receipt_id", ""))
		var region_id := str(receipt.get("market_region_id", ""))
		if receipt_id.is_empty() or seen_ids.has(receipt_id) or region_id.is_empty():
			return {"valid": false, "reason_code": "commodity_postcommit_receipt_identity_invalid"}
		seen_ids[receipt_id] = true
		extracted_ids.append(receipt_id)
		region_ids[region_id] = true
	if extracted_ids != receipt_ids:
		return {"valid": false, "reason_code": "commodity_postcommit_receipt_order_invalid"}
	var district_indices: Array = []
	var ordered_region_ids: Array = region_ids.keys()
	ordered_region_ids.sort()
	if resolve_districts:
		for region_id_variant in ordered_region_ids:
			var district_index := _world_session.district_index_for_region_id(str(region_id_variant)) if _world_session != null else -1
			if district_index < 0:
				return {"valid": false, "reason_code": "commodity_postcommit_region_unknown"}
			if not district_indices.has(district_index):
				district_indices.append(district_index)
		district_indices.sort()
	return {
		"valid": true,
		"reason_code": "commodity_postcommit_batch_valid",
		"region_ids": ordered_region_ids,
		"district_indices": district_indices,
	}


func _runtime_record_binding(record: Dictionary) -> Dictionary:
	if _world_session == null or _world_session.players.size() != int(record.get("player_count", -1)):
		return {"valid": false, "reason_code": "commodity_postcommit_player_binding_changed"}
	var region_ids: Array = record.get("region_ids", []) if record.get("region_ids", []) is Array else []
	var expected_districts: Array = record.get("district_indices", []) if record.get("district_indices", []) is Array else []
	var batch_sequence := int(record.get("batch_sequence", -1))
	var expected_binding := {
		"batch_sequence": batch_sequence,
		"batch_id": str(record.get("batch_id", "")),
		"batch_fingerprint": str(record.get("batch_fingerprint", "")),
	}
	var expected_city_binding := expected_binding.duplicate(true)
	expected_city_binding["city_breakdown_fingerprint"] = str(record.get("city_breakdown_fingerprint", ""))
	var city_targets: Dictionary = record.get("city_target_completed_by_district", {}) if record.get("city_target_completed_by_district", {}) is Dictionary else {}
	var derivative_targets: Dictionary = record.get("derivative_target_completed_by_district", {}) if record.get("derivative_target_completed_by_district", {}) is Dictionary else {}
	var actual_districts: Array = []
	for region_id_variant in region_ids:
		var district_index := _world_session.district_index_for_region_id(str(region_id_variant))
		if district_index < 0 or actual_districts.has(district_index):
			return {"valid": false, "reason_code": "commodity_postcommit_region_binding_changed"}
		actual_districts.append(district_index)
	actual_districts.sort()
	if actual_districts != expected_districts:
		return {"valid": false, "reason_code": "commodity_postcommit_district_binding_changed"}
	var frozen_breakdowns: Dictionary = record.get("city_breakdown_by_district", {}) \
		if record.get("city_breakdown_by_district", {}) is Dictionary else {}
	for district_key_variant in frozen_breakdowns.keys():
		var frozen_row: Dictionary = frozen_breakdowns.get(district_key_variant, {}) \
			if frozen_breakdowns.get(district_key_variant, {}) is Dictionary else {}
		if _world_session.district_index_for_region_id(str(frozen_row.get("region_id", ""))) \
				!= int(frozen_row.get("district_index", -1)):
			return {"valid": false, "reason_code": "commodity_postcommit_city_breakdown_binding_changed"}
	for district_index_variant in expected_districts:
		var district_index := int(district_index_variant)
		var city_binding := _world_session.commodity_postcommit_city_binding(district_index)
		var city_sequence := int(city_binding.get("batch_sequence", 0))
		var city_target_done := bool(city_targets.get(str(district_index), false))
		if city_sequence > batch_sequence \
				or city_sequence == batch_sequence and not _same_binding(city_binding, expected_city_binding, true) \
				or city_target_done and not _same_binding(city_binding, expected_city_binding, true):
			return {"valid": false, "reason_code": "commodity_postcommit_city_target_lineage_mismatch"}
		if bool(derivative_targets.get(str(district_index), false)) and _due_derivative_count(district_index) > 0:
			return {"valid": false, "reason_code": "commodity_postcommit_derivative_target_lineage_mismatch"}
	var cash_targets: Dictionary = record.get("cash_target_completed_by_player", {}) if record.get("cash_target_completed_by_player", {}) is Dictionary else {}
	for player_index in range(int(record.get("player_count", 0))):
		var player_binding := _world_session.commodity_postcommit_player_observation_binding(player_index)
		var player_sequence := int(player_binding.get("batch_sequence", 0))
		var cash_target_done := bool(cash_targets.get(str(player_index), false))
		if player_sequence > batch_sequence \
				or player_sequence == batch_sequence and not _same_binding(player_binding, expected_binding) \
				or cash_target_done and not _same_binding(player_binding, expected_binding):
			return {"valid": false, "reason_code": "commodity_postcommit_player_target_lineage_mismatch"}
	var downstream: Dictionary = record.get("downstream_snapshot", {}) if record.get("downstream_snapshot", {}) is Dictionary else {}
	if not downstream.is_empty():
		var bankruptcy_id := str(downstream.get("bankruptcy_transaction_id", ""))
		var bankruptcy_binding := _bankruptcy_owner.checkpoint_transaction_binding(bankruptcy_id)
		if not bankruptcy_binding.is_empty() and str(bankruptcy_binding.get("request_fingerprint", "")) \
				!= str(downstream.get("bankruptcy_request_fingerprint", "")):
			return {"valid": false, "reason_code": "commodity_postcommit_bankruptcy_target_lineage_collision"}
		if bool(record.get("bankruptcy_target_completed", false)) \
				and (not bool(bankruptcy_binding.get("finalized", false)) \
				or str(bankruptcy_binding.get("transaction_id", "")) != bankruptcy_id \
				or str(bankruptcy_binding.get("request_fingerprint", "")) \
					!= str(downstream.get("bankruptcy_request_fingerprint", ""))):
			return {"valid": false, "reason_code": "commodity_postcommit_bankruptcy_target_lineage_mismatch"}
		var asset_id := str(downstream.get("asset_recovery_transaction_id", ""))
		var asset_binding := _player_mana_owner.advance_once_binding(asset_id)
		if not asset_binding.is_empty() and str(asset_binding.get("fingerprint", "")) != str(downstream.get("asset_recovery_request_fingerprint", "")):
			return {"valid": false, "reason_code": "commodity_postcommit_asset_target_lineage_collision"}
		if bool(record.get("asset_recovery_target_completed", false)) \
				and (not bool(asset_binding.get("advanced", false)) \
				or str(asset_binding.get("transaction_id", "")) != asset_id):
			return {"valid": false, "reason_code": "commodity_postcommit_asset_target_lineage_mismatch"}
	return {"valid": true, "reason_code": "commodity_postcommit_runtime_binding_valid"}


func _ensure_city_breakdown_snapshot(record: Dictionary, receipt_ids: Array) -> Dictionary:
	var existing: Dictionary = record.get("city_breakdown_by_district", {}) \
		if record.get("city_breakdown_by_district", {}) is Dictionary else {}
	var existing_fingerprint := str(record.get("city_breakdown_fingerprint", ""))
	if receipt_ids.is_empty():
		if not existing.is_empty() or not existing_fingerprint.is_empty():
			return {"valid": false, "reason_code": "commodity_postcommit_empty_observer_snapshot_invalid"}
		return {"valid": true, "record": record}
	if not existing.is_empty() or not existing_fingerprint.is_empty():
		var existing_valid := _city_breakdown_snapshot_valid(record)
		return {
			"valid": existing_valid,
			"reason_code": "commodity_postcommit_city_breakdown_restored" \
				if existing_valid else "commodity_postcommit_city_breakdown_invalid",
			"record": record,
		}
	var expected_districts: Array = record.get("district_indices", []) \
		if record.get("district_indices", []) is Array else []
	var region_ids: Array = record.get("region_ids", []) if record.get("region_ids", []) is Array else []
	var breakdown_by_district: Dictionary = {}
	for region_id_variant in region_ids:
		var region_id := str(region_id_variant)
		var district_index := _world_session.district_index_for_region_id(region_id) if _world_session != null else -1
		if district_index < 0 or not expected_districts.has(district_index) \
				or breakdown_by_district.has(str(district_index)):
			return {"valid": false, "reason_code": "commodity_postcommit_city_breakdown_binding_invalid"}
		var breakdown := _city_gdp_breakdown(region_id)
		if not _city_breakdown_valid(breakdown):
			return {"valid": false, "reason_code": "commodity_postcommit_city_breakdown_payload_invalid"}
		breakdown_by_district[str(district_index)] = {
			"district_index": district_index,
			"region_id": region_id,
			"breakdown": breakdown.duplicate(true),
		}
	if breakdown_by_district.size() != expected_districts.size():
		return {"valid": false, "reason_code": "commodity_postcommit_city_breakdown_incomplete"}
	record["city_breakdown_by_district"] = breakdown_by_district
	record["city_breakdown_fingerprint"] = _city_breakdown_fingerprint(record, breakdown_by_district)
	if not _city_breakdown_snapshot_valid(record):
		return {"valid": false, "reason_code": "commodity_postcommit_city_breakdown_invalid"}
	_store_record(record)
	return {
		"valid": true,
		"reason_code": "commodity_postcommit_city_breakdown_captured",
		"record": record,
	}


func _city_breakdown_snapshot_valid(record: Dictionary) -> bool:
	var batch: Dictionary = record.get("batch", {}) if record.get("batch", {}) is Dictionary else {}
	var receipt_ids: Array = batch.get("receipt_ids", []) if batch.get("receipt_ids", []) is Array else []
	var snapshot: Dictionary = record.get("city_breakdown_by_district", {}) \
		if record.get("city_breakdown_by_district", {}) is Dictionary else {}
	var fingerprint := str(record.get("city_breakdown_fingerprint", ""))
	if receipt_ids.is_empty():
		return snapshot.is_empty() and fingerprint.is_empty()
	var district_indices: Array = record.get("district_indices", []) \
		if record.get("district_indices", []) is Array else []
	if snapshot.is_empty() and fingerprint.is_empty():
		return _record_has_zero_progress(record)
	if snapshot.size() != district_indices.size() or fingerprint.length() != 64:
		return false
	var region_ids: Array = record.get("region_ids", []) if record.get("region_ids", []) is Array else []
	var seen_regions: Dictionary = {}
	for district_index_variant in district_indices:
		if not (district_index_variant is int):
			return false
		var district_key := str(int(district_index_variant))
		if not snapshot.has(district_key) or not (snapshot.get(district_key) is Dictionary):
			return false
		var row := snapshot.get(district_key) as Dictionary
		var region_id := str(row.get("region_id", ""))
		if not _has_exact_keys(row, CITY_BREAKDOWN_ROW_KEYS) \
				or not (row.get("district_index") is int) \
				or int(row.get("district_index", -1)) != int(district_index_variant) \
				or not (row.get("region_id") is String) or region_id.is_empty() \
				or not region_ids.has(region_id) or seen_regions.has(region_id) \
				or not (row.get("breakdown") is Dictionary) \
				or not _city_breakdown_valid(row.get("breakdown") as Dictionary):
			return false
		seen_regions[region_id] = true
	for district_key_variant in snapshot.keys():
		var district_key := str(district_key_variant)
		if not (district_key_variant is String or district_key_variant is StringName) \
				or not _canonical_index_key(district_key) or not district_indices.has(int(district_key)):
			return false
	if seen_regions.size() != region_ids.size():
		return false
	return fingerprint == _city_breakdown_fingerprint(record, snapshot)


func _city_breakdown_valid(breakdown: Dictionary) -> bool:
	if not _is_pure_data(breakdown) or not _has_exact_keys(breakdown, CITY_BREAKDOWN_KEYS) \
			or not (breakdown.get("net") is int) or int(breakdown.get("net", -1)) < 0 \
			or not (breakdown.get("net_cents") is int) or int(breakdown.get("net_cents", -1)) < 0 \
			or not (breakdown.get("receipt_count") is int) or int(breakdown.get("receipt_count", -1)) < 0 \
			or not (breakdown.get("observation_window_seconds") is float) \
			or not is_finite(float(breakdown.get("observation_window_seconds", -1.0))) \
			or float(breakdown.get("observation_window_seconds", -1.0)) < 0.0 \
			or not (breakdown.get("competition_matches") is int) \
			or int(breakdown.get("competition_matches", -1)) < 0:
		return false
	for key in ["product_lines", "route_lines", "transit_lines"]:
		if not (breakdown.get(key) is Array):
			return false
		for line_variant in breakdown.get(key) as Array:
			if not (line_variant is String or line_variant is StringName):
				return false
	return true


func _city_breakdown_fingerprint(record: Dictionary, snapshot: Dictionary) -> String:
	var payload := {
		"batch_id": str(record.get("batch_id", "")),
		"batch_sequence": int(record.get("batch_sequence", -1)),
		"batch_fingerprint": str(record.get("batch_fingerprint", "")),
		"flow_revision": int((record.get("batch", {}) as Dictionary).get("flow_revision", -1)) \
			if record.get("batch", {}) is Dictionary else -1,
		"region_ids": (record.get("region_ids", []) as Array).duplicate() \
			if record.get("region_ids", []) is Array else [],
		"district_indices": (record.get("district_indices", []) as Array).duplicate() \
			if record.get("district_indices", []) is Array else [],
		"city_breakdown_by_district": snapshot.duplicate(true),
	}
	return JSON.stringify(_canonicalize(payload)).sha256_text()


func _city_gdp_breakdown(region_id: String) -> Dictionary:
	var snapshot := _flow_owner.region_gdp_snapshot(region_id)
	var product_lines: Array = []
	var route_lines: Array = []
	for receipt_variant in _flow_owner.recent_sale_receipts_snapshot(-1):
		if not (receipt_variant is Dictionary):
			continue
		var receipt := receipt_variant as Dictionary
		if str(receipt.get("market_region_id", "")) != region_id:
			continue
		product_lines.append("%s ×%d" % [str(receipt.get("commodity_id", "")), int(receipt.get("units", 0))])
		route_lines.append("距离%d｜单价%.2f" % [
			int(receipt.get("shortest_legal_distance", 0)),
			float(int(receipt.get("unit_price_cents", 0))) / 100.0,
		])
	return {
		"net": int(snapshot.get("region_gdp_per_minute", 0)),
		"net_cents": int(snapshot.get("region_gdp_per_minute_cents", 0)),
		"receipt_count": (snapshot.get("receipt_ids", []) as Array).size() if snapshot.get("receipt_ids", []) is Array else 0,
		"observation_window_seconds": float(snapshot.get("observation_window_seconds", 0.0)),
		"competition_matches": 0,
		"product_lines": product_lines,
		"route_lines": route_lines,
		"transit_lines": route_lines.duplicate(),
	}


func _due_derivative_count(district_index: int) -> int:
	var due_count := 0
	for position_variant in _derivative_owner.positions_for_district(district_index, true):
		if position_variant is Dictionary \
				and _world_session.game_time >= float((position_variant as Dictionary).get("expires_at", _world_session.game_time)):
			due_count += 1
	return due_count


func _record_progress_valid(record: Dictionary) -> bool:
	var district_indices: Array = record.get("district_indices", []) if record.get("district_indices", []) is Array else []
	var district_progress: Dictionary = record.get("district_progress", {}) if record.get("district_progress", {}) is Dictionary else {}
	var city_targets: Dictionary = record.get("city_target_completed_by_district", {}) if record.get("city_target_completed_by_district", {}) is Dictionary else {}
	var derivative_targets: Dictionary = record.get("derivative_target_completed_by_district", {}) if record.get("derivative_target_completed_by_district", {}) is Dictionary else {}
	var pulse_targets: Dictionary = record.get("pulse_target_completed_by_district", {}) if record.get("pulse_target_completed_by_district", {}) is Dictionary else {}
	var previous := -1
	for district_index_variant in district_indices:
		if not (district_index_variant is int):
			return false
		var district_index := int(district_index_variant)
		if district_index < 0 or district_index <= previous:
			return false
		previous = district_index
		var progress := int(district_progress.get(str(district_index), 0))
		if progress < 0 or progress > 3:
			return false
		var city_done := bool(city_targets.get(str(district_index), false))
		var derivative_done := bool(derivative_targets.get(str(district_index), false))
		var pulse_done := bool(pulse_targets.get(str(district_index), false))
		if (progress >= 1 and not city_done) or (progress >= 2 and not derivative_done) or (progress >= 3 and not pulse_done) \
				or derivative_done and not city_done or pulse_done and not derivative_done:
			return false
	for target_dictionary in [district_progress, city_targets, derivative_targets, pulse_targets]:
		for key_variant in (target_dictionary as Dictionary).keys():
			var key_text := str(key_variant)
			if not _canonical_index_key(key_text) or not district_indices.has(int(key_text)) \
					or (target_dictionary != district_progress and not bool((target_dictionary as Dictionary)[key_variant])):
				return false
	var player_count := int(record.get("player_count", -1))
	if player_count < 0 or player_count > 8:
		return false
	var cash_targets: Dictionary = record.get("cash_target_completed_by_player", {}) if record.get("cash_target_completed_by_player", {}) is Dictionary else {}
	var cash_completed: Dictionary = record.get("cash_completed_by_player", {}) if record.get("cash_completed_by_player", {}) is Dictionary else {}
	for target_dictionary in [cash_targets, cash_completed]:
		for player_key_variant in (target_dictionary as Dictionary).keys():
			var player_key := str(player_key_variant)
			var player_index := int(player_key)
			if not _canonical_index_key(player_key) or player_index < 0 or player_index >= player_count \
					or not bool((target_dictionary as Dictionary)[player_key_variant]):
				return false
	for player_key_variant in cash_completed.keys():
		if not bool(cash_targets.get(str(player_key_variant), false)):
			return false
	var downstream_progress := int(record.get("downstream_progress", -1))
	var bankruptcy_done := bool(record.get("bankruptcy_target_completed", false))
	var asset_recovery_done := bool(record.get("asset_recovery_target_completed", false))
	var downstream_snapshot: Dictionary = record.get("downstream_snapshot", {}) if record.get("downstream_snapshot", {}) is Dictionary else {}
	if downstream_progress < 0 or downstream_progress > 2 \
			or downstream_progress >= 1 and not bankruptcy_done \
			or downstream_progress >= 2 and not asset_recovery_done \
			or asset_recovery_done and not bankruptcy_done:
		return false
	if downstream_snapshot.is_empty():
		if downstream_progress != 0 or bankruptcy_done or asset_recovery_done:
			return false
	elif not _downstream_snapshot_valid(record, downstream_snapshot):
		return false
	var tail_progress := int(record.get("tail_progress", -1))
	var public_receipt: Dictionary = record.get("public_receipt", {}) \
		if record.get("public_receipt", {}) is Dictionary else {}
	var public_done := bool(record.get("public_log_target_completed", false))
	var presentation_done := bool(record.get("presentation_invalidation_completed", false))
	if tail_progress < 0 or tail_progress > 2:
		return false
	var inputs_sealed := bool(record.get("inputs_sealed", false))
	if inputs_sealed:
		if downstream_snapshot.is_empty():
			return false
	else:
		if not _record_has_zero_effect_progress(record) \
				or not downstream_snapshot.is_empty() and not _downstream_snapshot_valid(record, downstream_snapshot):
			return false
	var batch: Dictionary = record.get("batch", {}) if record.get("batch", {}) is Dictionary else {}
	var has_observer_work := not (batch.get("receipt_ids", []) as Array).is_empty() if batch.get("receipt_ids", []) is Array else false
	if has_observer_work:
		if public_done != (tail_progress >= 1) \
				or presentation_done != (tail_progress >= 2):
			return false
		if not public_receipt.is_empty():
			var typed_public := CommodityFlowPostCommitPublicReceipt.from_dictionary(public_receipt)
			if not typed_public.is_valid() or not typed_public.matches_committed_batch(batch):
				return false
		elif tail_progress > 0:
			return false
	else:
		if not public_receipt.is_empty() or public_done or presentation_done \
				or tail_progress not in [0, 2]:
			return false
	if str(record.get("state", "")) == "finalized" and has_observer_work:
		for district_index_variant in district_indices:
			if int(district_progress.get(str(int(district_index_variant)), 0)) != 3:
				return false
		if cash_completed.size() != player_count:
			return false
	if str(record.get("state", "")) == "finalized" \
			and (downstream_progress != 2 or not bankruptcy_done or not asset_recovery_done \
				or tail_progress != 2):
		return false
	if str(record.get("state", "")) == "finalized" and not inputs_sealed:
		return false
	var final_receipt: Dictionary = record.get("final_receipt", {}) if record.get("final_receipt", {}) is Dictionary else {}
	if str(record.get("state", "")) == "finalized":
		if not _final_receipt_valid(record, final_receipt):
			return false
	elif not final_receipt.is_empty():
		return false
	return true


func _final_receipt_valid(record: Dictionary, final_receipt: Dictionary) -> bool:
	if not _is_pure_data(final_receipt) or not _has_exact_keys(final_receipt, FINAL_RECEIPT_KEYS) \
			or not (final_receipt.get("completed") is bool) \
			or not (final_receipt.get("recovered") is bool) \
			or not (final_receipt.get("replayed") is bool) \
			or not (final_receipt.get("reason_code") is String) \
			or not (final_receipt.get("batch_id") is String) \
			or not (final_receipt.get("batch_sequence") is int) \
			or not (final_receipt.get("batch_fingerprint") is String) \
			or not (final_receipt.get("flow_revision") is int) \
			or not (final_receipt.get("settled_at") is float) \
			or not (final_receipt.get("flow_delta_seconds") is float) \
			or not (final_receipt.get("receipt_count") is int) \
			or not (final_receipt.get("flow_result_summary") is Dictionary) \
			or not (final_receipt.get("trace") is Array):
		return false
	var batch: Dictionary = record.get("batch", {}) if record.get("batch", {}) is Dictionary else {}
	var trace: Array = record.get("trace", []) if record.get("trace", []) is Array else []
	return bool(final_receipt.get("completed", false)) \
		and not bool(final_receipt.get("replayed", true)) \
		and str(final_receipt.get("reason_code", "")) == ("commodity_postcommit_recovered" \
			if bool(final_receipt.get("recovered", false)) else "commodity_postcommit_applied") \
		and str(final_receipt.get("batch_id", "")) == str(record.get("batch_id", "")) \
		and int(final_receipt.get("batch_sequence", -1)) == int(record.get("batch_sequence", -2)) \
		and str(final_receipt.get("batch_fingerprint", "")) == str(record.get("batch_fingerprint", "")) \
		and int(final_receipt.get("flow_revision", -1)) == int(batch.get("flow_revision", -2)) \
		and is_equal_approx(float(final_receipt.get("settled_at", -1.0)), float(batch.get("settled_at", -2.0))) \
		and is_equal_approx(float(final_receipt.get("flow_delta_seconds", -1.0)), float(batch.get("flow_delta_seconds", -2.0))) \
		and int(final_receipt.get("receipt_count", -1)) == ((batch.get("receipt_ids", []) as Array).size() \
			if batch.get("receipt_ids", []) is Array else -1) \
		and final_receipt.get("flow_result_summary", {}) == batch.get("flow_result_summary", {}) \
		and final_receipt.get("trace", []) == trace \
		and not trace.is_empty() and str(trace.back()) == "finalize"


func _record_has_zero_progress(record: Dictionary) -> bool:
	for key in [
		"district_progress",
		"city_target_completed_by_district",
		"derivative_target_completed_by_district",
		"pulse_target_completed_by_district",
		"cash_target_completed_by_player",
		"cash_completed_by_player",
		"downstream_snapshot",
		"public_receipt",
		"final_receipt",
	]:
		if not (record.get(key, {}) is Dictionary) or not (record.get(key, {}) as Dictionary).is_empty():
			return false
	return (record.get("city_breakdown_by_district", {}) is Dictionary) \
		and (record.get("city_breakdown_by_district", {}) as Dictionary).is_empty() \
		and str(record.get("city_breakdown_fingerprint", "")).is_empty() \
		and not bool(record.get("inputs_sealed", false)) \
		and int(record.get("downstream_progress", 0)) == 0 \
		and not bool(record.get("bankruptcy_target_completed", false)) \
		and not bool(record.get("asset_recovery_target_completed", false)) \
		and not bool(record.get("public_log_target_completed", false)) \
		and not bool(record.get("presentation_invalidation_completed", false)) \
		and int(record.get("tail_progress", 0)) == 0 \
		and record.get("trace", []) is Array and (record.get("trace", []) as Array).is_empty()


func _record_has_zero_effect_progress(record: Dictionary) -> bool:
	for key in [
		"district_progress",
		"city_target_completed_by_district",
		"derivative_target_completed_by_district",
		"pulse_target_completed_by_district",
		"cash_target_completed_by_player",
		"cash_completed_by_player",
		"public_receipt",
		"final_receipt",
	]:
		if not (record.get(key, {}) is Dictionary) or not (record.get(key, {}) as Dictionary).is_empty():
			return false
	return int(record.get("downstream_progress", 0)) == 0 \
		and not bool(record.get("bankruptcy_target_completed", false)) \
		and not bool(record.get("asset_recovery_target_completed", false)) \
		and not bool(record.get("public_log_target_completed", false)) \
		and not bool(record.get("presentation_invalidation_completed", false)) \
		and int(record.get("tail_progress", 0)) == 0 \
		and record.get("trace", []) is Array and (record.get("trace", []) as Array).is_empty()


func _canonical_index_key(value: String) -> bool:
	return value.is_valid_int() and int(value) >= 0 and str(int(value)) == value


func _same_binding(left: Dictionary, right: Dictionary, include_city_breakdown := false) -> bool:
	var same := int(left.get("batch_sequence", -1)) == int(right.get("batch_sequence", -2)) \
		and str(left.get("batch_id", "")) == str(right.get("batch_id", "")) \
		and str(left.get("batch_fingerprint", "")) == str(right.get("batch_fingerprint", ""))
	if include_city_breakdown:
		same = same and str(left.get("city_breakdown_fingerprint", "")) \
			== str(right.get("city_breakdown_fingerprint", ""))
	return same


func _has_exact_keys(dictionary: Dictionary, expected: Array) -> bool:
	if dictionary.size() != expected.size():
		return false
	for key_variant in expected:
		if not dictionary.has(key_variant):
			return false
	return true


func _store_record(record: Dictionary) -> void:
	_journal[str(record.get("batch_id", ""))] = record.duplicate(true)


func _append_trace(record: Dictionary, step: String) -> void:
	var trace: Array = record.get("trace", []) if record.get("trace", []) is Array else []
	trace.append(step)
	record["trace"] = trace


func _interrupted(record: Dictionary, reason_code: String) -> Dictionary:
	_store_record(record)
	_last_reason_code = reason_code
	return {
		"completed": false,
		"recovered": false,
		"reason_code": reason_code,
		"batch_id": str(record.get("batch_id", "")),
		"pending_count": 1,
	}


func _recovery_required(record: Dictionary, reason_code: String) -> Dictionary:
	record["state"] = "recovery_required"
	_store_record(record)
	_last_reason_code = reason_code
	return {
		"completed": false,
		"recovered": false,
		"reason_code": reason_code,
		"batch_id": str(record.get("batch_id", "")),
		"pending_count": 1,
		"recovery_required": true,
	}


func _prune_terminal_records() -> void:
	while _terminal_order.size() > JOURNAL_LIMIT:
		var evicted_id: String = _terminal_order.pop_front()
		if evicted_id != _pending_batch_id:
			_journal.erase(evicted_id)


func _consume_fault(stage: StringName) -> bool:
	if _fault_stage != stage:
		return false
	_fault_stage = &""
	return true


func _reject(reason_code: String) -> Dictionary:
	_reject_count += 1
	_last_reason_code = reason_code
	return {
		"completed": false,
		"recovered": false,
		"reason_code": reason_code,
		"pending_count": int(not _pending_batch_id.is_empty()),
	}


static func _canonicalize(value: Variant) -> Variant:
	if value is Dictionary:
		var source := value as Dictionary
		var keys: Array = source.keys()
		keys.sort_custom(func(left: Variant, right: Variant) -> bool: return str(left) < str(right))
		var result: Dictionary = {}
		for key_variant in keys:
			result[str(key_variant)] = _canonicalize(source[key_variant])
		return result
	if value is Array:
		var result: Array = []
		for item_variant in value as Array:
			result.append(_canonicalize(item_variant))
		return result
	return value


static func _is_pure_data(value: Variant) -> bool:
	if value == null or value is String or value is StringName or value is bool or value is int or value is float:
		return true
	if value is Dictionary:
		for key_variant in value.keys():
			if not _is_pure_data(key_variant) or not _is_pure_data(value[key_variant]):
				return false
		return true
	if value is Array:
		for item_variant in value:
			if not _is_pure_data(item_variant):
				return false
		return true
	return false
