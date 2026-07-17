@tool
extends Node
class_name PublicLogProducerPort

var _owner: PublicLogPresentationOwner
var _sequence := 0


func configure(log_owner: PublicLogPresentationOwner) -> void:
	_owner = log_owner


func reset_state() -> void:
	_sequence = 0


func publish(
	event_kind: StringName,
	localization_key: StringName,
	public_values: Dictionary,
	source_revision: int,
	world_time: float,
	receipt_id := ""
) -> Dictionary:
	if _owner == null:
		return {"applied": false, "reason_code": "public_log_owner_missing"}
	_sequence += 1
	var resolved_id := receipt_id.strip_edges()
	if resolved_id.is_empty():
		resolved_id = "public-log-%d-%s" % [_sequence, JSON.stringify([str(event_kind), public_values, source_revision]).sha256_text().left(16)]
	var receipt := PublicLogReceipt.create(resolved_id, event_kind, localization_key, public_values, source_revision, world_time)
	return _owner.append_receipt(receipt)


func append_receipt(receipt: PublicLogReceipt) -> Dictionary:
	return _owner.append_receipt(receipt) if _owner != null else {"applied": false, "reason_code": "public_log_owner_missing"}


func debug_snapshot() -> Dictionary:
	return {
		"configured": _owner != null,
		"sequence": _sequence,
		"owns_log_entries": false,
		"accepts_typed_receipts": true,
	}
