@tool
extends Node
class_name PublicLogPresentationOwner

signal public_log_changed(revision: int)

const MAX_ENTRIES := 90

var _entries: Array = []
var _applied_receipt_ids: Dictionary = {}
var _revision := 0
var _duplicate_receipt_count := 0
var _rejected_receipt_count := 0


func append_receipt(receipt: PublicLogReceipt) -> Dictionary:
	if receipt == null or not receipt.is_valid():
		_rejected_receipt_count += 1
		return {"applied": false, "reason_code": "public_log_receipt_invalid", "revision": _revision}
	if _applied_receipt_ids.has(receipt.receipt_id):
		_duplicate_receipt_count += 1
		return {"applied": false, "duplicate": true, "reason_code": "public_log_receipt_duplicate", "revision": _revision}
	var row := receipt.to_dictionary()
	row["message"] = _render_message(receipt)
	_entries.append(row)
	_applied_receipt_ids[receipt.receipt_id] = true
	while _entries.size() > MAX_ENTRIES:
		var removed: Dictionary = _entries.pop_front()
		_applied_receipt_ids.erase(str(removed.get("receipt_id", "")))
	_revision += 1
	public_log_changed.emit(_revision)
	return {"applied": true, "duplicate": false, "reason_code": "", "revision": _revision}


func recent_public_entries(limit := 6) -> Array:
	var normalized_limit := clampi(limit, 0, MAX_ENTRIES)
	var start := maxi(0, _entries.size() - normalized_limit)
	return _entries.slice(start, _entries.size()).duplicate(true)


func recent_public_messages(limit := 6) -> Array:
	var result: Array = []
	for entry_variant in recent_public_entries(limit):
		if entry_variant is Dictionary:
			result.append(str((entry_variant as Dictionary).get("message", "")))
	return result


func reset_state() -> void:
	_entries.clear()
	_applied_receipt_ids.clear()
	_duplicate_receipt_count = 0
	_rejected_receipt_count = 0
	_revision += 1
	public_log_changed.emit(_revision)


func import_legacy_messages(messages: Array) -> Dictionary:
	reset_state()
	var applied := 0
	for index in range(messages.size()):
		var text := str(messages[index]).strip_edges()
		if text.is_empty():
			continue
		var receipt := PublicLogReceipt.create(
			"legacy-import-%d-%s" % [index, text.sha256_text().left(12)],
			&"legacy_import",
			&"public.legacy.message",
			{"message": text},
			index,
			0.0
		)
		if bool(append_receipt(receipt).get("applied", false)):
			applied += 1
	return {"applied": applied, "revision": _revision}


func debug_snapshot() -> Dictionary:
	return {
		"owner": "PublicLogPresentationOwner",
		"entry_count": _entries.size(),
		"revision": _revision,
		"duplicate_receipt_count": _duplicate_receipt_count,
		"rejected_receipt_count": _rejected_receipt_count,
		"typed_receipts_only": true,
		"private_payload_exposed": false,
	}


func _render_message(receipt: PublicLogReceipt) -> String:
	var message := str(receipt.public_values.get("message", "")).strip_edges()
	if message.is_empty():
		message = str(receipt.localization_key)
	if message.begins_with("["):
		return message
	var minutes := int(floor(receipt.world_time / 60.0))
	var seconds := int(floor(receipt.world_time)) % 60
	return "[%02d:%02d] %s" % [minutes, seconds, message]
