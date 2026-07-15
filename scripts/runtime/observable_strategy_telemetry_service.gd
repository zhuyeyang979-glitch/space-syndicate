extends RefCounted
class_name ObservableStrategyTelemetryService

const RECEIPT_POLICY := preload("res://scripts/runtime/public_match_receipt_envelope_policy_v06.gd")
const AGGREGATE_SCHEMA_VERSION := "v0.6.observable-strategy-telemetry.1"
const OBSERVATION_KIND := "OBSERVED_TENDENCY"
const DEFAULT_RECEIPT_CAPACITY := 512
const MAX_RECEIPT_CAPACITY := 4096
const MAX_ABS_AGGREGATE := 4_000_000_000_000_000

var _policy: RefCounted = RECEIPT_POLICY.new()
var _receipt_capacity := DEFAULT_RECEIPT_CAPACITY
var _receipts_by_id := {}
var _receipt_id_by_sequence := {}
var _duplicate_receipt_count := 0
var _rejected_receipt_count := 0
var _overflow_count := 0
var _evidence_incomplete := false


func configure_receipt_capacity(value: int) -> bool:
	if value < 1 or value > MAX_RECEIPT_CAPACITY:
		return false
	if value < _receipts_by_id.size():
		_evidence_incomplete = true
		return false
	_receipt_capacity = value
	return true


func ingest_public_receipt(candidate: Variant) -> Dictionary:
	var validation := _policy.call("validate_and_seal", candidate) as Dictionary
	if not bool(validation.get("accepted", false)):
		_rejected_receipt_count += 1
		_evidence_incomplete = true
		return _ingest_result(false, false, str(validation.get("failure_code", "receipt_rejected")))
	var receipt := (validation.get("receipt", {}) as Dictionary).duplicate(true)
	var receipt_id := str(receipt.get("receipt_id", ""))
	if _receipts_by_id.has(receipt_id):
		if (_receipts_by_id[receipt_id] as Dictionary) == receipt:
			_duplicate_receipt_count += 1
			return _ingest_result(true, true, "")
		_rejected_receipt_count += 1
		_evidence_incomplete = true
		return _ingest_result(false, false, "receipt_id_conflict")
	var sequence := int(receipt.get("sequence", 0))
	if _receipt_id_by_sequence.has(sequence):
		_rejected_receipt_count += 1
		_evidence_incomplete = true
		return _ingest_result(false, false, "sequence_conflict")
	if _receipts_by_id.size() >= _receipt_capacity:
		_overflow_count += 1
		_evidence_incomplete = true
		return _ingest_result(false, false, "evidence_capacity_exceeded")
	_receipts_by_id[receipt_id] = receipt
	_receipt_id_by_sequence[sequence] = receipt_id
	return _ingest_result(true, false, "")


func aggregate_snapshot() -> Dictionary:
	var rows_by_id := {}
	for tendency_variant: Variant in RECEIPT_POLICY.TENDENCY_IDS:
		var tendency_id := str(tendency_variant)
		rows_by_id[tendency_id] = _empty_tendency_row(tendency_id)
	for receipt_variant: Variant in _ordered_receipts():
		var receipt := receipt_variant as Dictionary
		var tendency_id := RECEIPT_POLICY.tendency_id_for_event_kind(str(receipt.get("event_kind", "")))
		if tendency_id.is_empty() or not rows_by_id.has(tendency_id):
			_evidence_incomplete = true
			continue
		var row := (rows_by_id[tendency_id] as Dictionary).duplicate(true)
		var sequence := int(receipt.get("sequence", 0))
		row["observed_event_count"] = int(row.get("observed_event_count", 0)) + 1
		if int(row.get("first_sequence", -1)) < 0:
			row["first_sequence"] = sequence
		row["last_sequence"] = sequence
		var totals := (row.get("typed_delta_totals", {}) as Dictionary).duplicate(true)
		for delta_variant: Variant in (receipt.get("typed_deltas", {}) as Dictionary):
			var delta_id := str(delta_variant)
			var next_total := int(totals.get(delta_id, 0)) + int((receipt.get("typed_deltas", {}) as Dictionary)[delta_variant])
			if abs(next_total) > MAX_ABS_AGGREGATE:
				_evidence_incomplete = true
				continue
			totals[delta_id] = next_total
		row["typed_delta_totals"] = totals
		rows_by_id[tendency_id] = row
	var tendencies: Array = []
	for tendency_variant: Variant in RECEIPT_POLICY.TENDENCY_IDS:
		tendencies.append((rows_by_id[str(tendency_variant)] as Dictionary).duplicate(true))
	return {
		"schema_version": AGGREGATE_SCHEMA_VERSION,
		"observation_kind": OBSERVATION_KIND,
		"anonymity_scope": "match_public_aggregate",
		"evidence_incomplete": _evidence_incomplete,
		"accepted_receipt_count": _receipts_by_id.size(),
		"duplicate_receipt_count": _duplicate_receipt_count,
		"rejected_receipt_count": _rejected_receipt_count,
		"overflow_count": _overflow_count,
		"tendencies": tendencies,
	}


func clear() -> void:
	_receipts_by_id.clear()
	_receipt_id_by_sequence.clear()
	_duplicate_receipt_count = 0
	_rejected_receipt_count = 0
	_overflow_count = 0
	_evidence_incomplete = false


func _ordered_receipts() -> Array:
	var sequences := _receipt_id_by_sequence.keys()
	sequences.sort()
	var ordered: Array = []
	for sequence_variant: Variant in sequences:
		var receipt_id := str(_receipt_id_by_sequence[sequence_variant])
		ordered.append((_receipts_by_id[receipt_id] as Dictionary).duplicate(true))
	return ordered


func _empty_tendency_row(tendency_id: String) -> Dictionary:
	var totals := {}
	for delta_variant: Variant in RECEIPT_POLICY.PUBLIC_TYPED_DELTA_IDS:
		totals[str(delta_variant)] = 0
	return {
		"tendency_id": tendency_id,
		"observed_event_count": 0,
		"first_sequence": -1,
		"last_sequence": -1,
		"typed_delta_totals": totals,
	}


func _ingest_result(accepted: bool, duplicate: bool, failure_code: String) -> Dictionary:
	return {
		"accepted": accepted,
		"duplicate": duplicate,
		"failure_code": failure_code,
		"evidence_incomplete": _evidence_incomplete,
		"accepted_receipt_count": _receipts_by_id.size(),
	}
