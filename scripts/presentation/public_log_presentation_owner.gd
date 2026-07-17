@tool
extends Node
class_name PublicLogPresentationOwner

signal public_log_changed(revision: int)

const MAX_ENTRIES := 90
const MAX_TOMBSTONES := 4096
const LOCALIZED_MESSAGES := {
	"public.contract.updated": "合约局势已更新",
	"public.military.updated": "军事部署已更新",
	"public.monster.updated": "怪兽局势已更新",
	"public.market.updated": "商品市场已更新",
	"public.weather.updated": "天气局势已更新",
}
const VICTORY_STATE_LABELS := {
	"idle": "等待",
	"qualification": "资格确认",
	"audit": "公开审计",
	"cooldown": "审计冷却",
	"resolved": "结算完成",
}
const GENERIC_PUBLIC_MESSAGE := "公开局势已更新"

var _entries: Array = []
var _applied_receipt_ids: Dictionary = {}
var _tombstone_order: Array[String] = []
var _retired_revision_floor_by_kind: Dictionary = {}
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
	var retired_floor := int(_retired_revision_floor_by_kind.get(str(receipt.event_kind), -1))
	if receipt.source_revision <= retired_floor:
		_duplicate_receipt_count += 1
		return {"applied": false, "stale": true, "reason_code": "public_log_receipt_stale", "revision": _revision}
	var row := receipt.to_dictionary()
	row["message"] = _render_message(receipt)
	_entries.append(row)
	_applied_receipt_ids[receipt.receipt_id] = {
		"event_kind": str(receipt.event_kind),
		"source_revision": receipt.source_revision,
	}
	_tombstone_order.append(receipt.receipt_id)
	while _entries.size() > MAX_ENTRIES:
		_entries.pop_front()
	while _tombstone_order.size() > MAX_TOMBSTONES:
		var retired_id: String = str(_tombstone_order.pop_front())
		var retired: Dictionary = _applied_receipt_ids.get(retired_id, {}) if _applied_receipt_ids.get(retired_id, {}) is Dictionary else {}
		var event_kind := str(retired.get("event_kind", ""))
		if not event_kind.is_empty():
			_retired_revision_floor_by_kind[event_kind] = maxi(
				int(_retired_revision_floor_by_kind.get(event_kind, -1)),
				int(retired.get("source_revision", -1))
			)
		_applied_receipt_ids.erase(retired_id)
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
	_tombstone_order.clear()
	_retired_revision_floor_by_kind.clear()
	_duplicate_receipt_count = 0
	_rejected_receipt_count = 0
	_revision += 1
	public_log_changed.emit(_revision)


func to_save_data() -> Dictionary:
	return {
		"schema_version": 1,
		"entries": _entries.duplicate(true),
		"applied_receipt_ids": _applied_receipt_ids.duplicate(true),
		"tombstone_order": _tombstone_order.duplicate(),
		"retired_revision_floor_by_kind": _retired_revision_floor_by_kind.duplicate(true),
		"revision": _revision,
	}


func apply_save_data(data: Dictionary) -> Dictionary:
	var entries: Variant = data.get("entries", [])
	var tombstones: Variant = data.get("applied_receipt_ids", {})
	var order: Variant = data.get("tombstone_order", [])
	var retired: Variant = data.get("retired_revision_floor_by_kind", {})
	if not (entries is Array) or not (tombstones is Dictionary) or not (order is Array) or not (retired is Dictionary):
		return {"applied": false, "reason_code": "public_log_save_invalid"}
	if not TablePresentationPureDataPolicy.is_pure_data([entries, tombstones, order, retired]):
		return {"applied": false, "reason_code": "public_log_save_not_pure_data"}
	_entries = (TablePresentationPureDataPolicy.detached_copy(entries) as Array).slice(maxi(0, (entries as Array).size() - MAX_ENTRIES))
	_applied_receipt_ids = TablePresentationPureDataPolicy.detached_copy(tombstones) as Dictionary
	_tombstone_order.clear()
	for receipt_id_variant in order:
		var receipt_id := str(receipt_id_variant).strip_edges()
		if not receipt_id.is_empty() and _applied_receipt_ids.has(receipt_id):
			_tombstone_order.append(receipt_id)
	while _tombstone_order.size() > MAX_TOMBSTONES:
		_applied_receipt_ids.erase(_tombstone_order.pop_front())
	_retired_revision_floor_by_kind = TablePresentationPureDataPolicy.detached_copy(retired) as Dictionary
	_revision = maxi(0, int(data.get("revision", 0)))
	_duplicate_receipt_count = 0
	_rejected_receipt_count = 0
	public_log_changed.emit(_revision)
	return {"applied": true, "reason_code": "", "revision": _revision}


func debug_snapshot() -> Dictionary:
	return {
		"owner": "PublicLogPresentationOwner",
		"entry_count": _entries.size(),
		"tombstone_count": _applied_receipt_ids.size(),
		"retired_event_kind_count": _retired_revision_floor_by_kind.size(),
		"revision": _revision,
		"duplicate_receipt_count": _duplicate_receipt_count,
		"rejected_receipt_count": _rejected_receipt_count,
		"typed_receipts_only": true,
		"private_payload_exposed": false,
	}


func _render_message(receipt: PublicLogReceipt) -> String:
	var message := _localized_message(receipt)
	var minutes := int(floor(receipt.world_time / 60.0))
	var seconds := int(floor(receipt.world_time)) % 60
	return "[%02d:%02d] %s" % [minutes, seconds, message]


func _localized_message(receipt: PublicLogReceipt) -> String:
	var localization_key := str(receipt.localization_key)
	if LOCALIZED_MESSAGES.has(localization_key):
		return str(LOCALIZED_MESSAGES[localization_key])
	if localization_key == "victory.public.state_changed":
		var previous_label := str(VICTORY_STATE_LABELS.get(str(receipt.public_values.get("previous_state", "")), ""))
		var state_label := str(VICTORY_STATE_LABELS.get(str(receipt.public_values.get("state", "")), ""))
		if not previous_label.is_empty() and not state_label.is_empty():
			return "胜利进程：%s → %s" % [previous_label, state_label]
		return "胜利进程已更新"
	return GENERIC_PUBLIC_MESSAGE
