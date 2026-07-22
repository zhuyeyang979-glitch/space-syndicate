@tool
extends Node
class_name PublicLogPresentationOwner

signal public_log_changed(revision: int)

const MAX_ENTRIES := 90
const MAX_TOMBSTONES := 4096
const SAVE_SCHEMA_VERSION := 2
const LEGACY_SAVE_SCHEMA_VERSION := 1
const LEGACY_SAVE_KEYS := [
	"schema_version",
	"entries",
	"applied_receipt_ids",
	"tombstone_order",
	"retired_revision_floor_by_kind",
	"revision",
]
const SAVE_KEYS := LEGACY_SAVE_KEYS + ["legacy_unverified_receipt_ids"]
const ENTRY_KEYS := [
	"receipt_id",
	"event_kind",
	"localization_key",
	"public_values",
	"source_revision",
	"world_time",
	"visibility_scope",
	"message",
]
const BINDING_KEYS := ["event_kind", "source_revision", "receipt_fingerprint"]
const LEGACY_BINDING_KEYS := ["event_kind", "source_revision"]
const LOCALIZED_MESSAGES := {
	"public.military.updated": "军事部署已更新",
	"public.monster.updated": "怪兽局势已更新",
	"public.market.updated": "商品市场已更新",
	"public.commodity_flow.sale_batch_committed": "商品成交回执已结算",
	"public.ai_business.market_pressure_resolved": "匿名财团在{region_id}制造{commodity_id}需求压力{pressure_units}，价格¥{price_before}→¥{price_after}",
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
var _legacy_unverified_receipt_ids: Dictionary = {}
var _revision := 0
var _duplicate_receipt_count := 0
var _rejected_receipt_count := 0
var _collision_receipt_count := 0


func append_receipt(receipt: PublicLogReceipt) -> Dictionary:
	if receipt == null or not receipt.is_valid():
		_rejected_receipt_count += 1
		return {"applied": false, "reason_code": "public_log_receipt_invalid", "revision": _revision}
	var receipt_fingerprint := receipt.fingerprint()
	if _applied_receipt_ids.has(receipt.receipt_id):
		if bool(_legacy_unverified_receipt_ids.get(receipt.receipt_id, false)):
			_duplicate_receipt_count += 1
			return {
				"applied": false,
				"duplicate": true,
				"legacy_unverified": true,
				"reason_code": "public_log_receipt_legacy_duplicate",
				"revision": _revision,
				"receipt_fingerprint": receipt_fingerprint,
			}
		var existing: Dictionary = _applied_receipt_ids.get(receipt.receipt_id, {}) \
			if _applied_receipt_ids.get(receipt.receipt_id, {}) is Dictionary else {}
		var existing_fingerprint := str(existing.get("receipt_fingerprint", ""))
		if existing_fingerprint.is_empty() or existing_fingerprint != receipt_fingerprint:
			_collision_receipt_count += 1
			return {
				"applied": false,
				"collision": true,
				"reason_code": "public_log_receipt_binding_collision",
				"revision": _revision,
				"receipt_fingerprint": existing_fingerprint,
			}
		_duplicate_receipt_count += 1
		return {
			"applied": false,
			"duplicate": true,
			"reason_code": "public_log_receipt_duplicate",
			"revision": _revision,
			"receipt_fingerprint": existing_fingerprint,
		}
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
		"receipt_fingerprint": receipt_fingerprint,
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
		_legacy_unverified_receipt_ids.erase(retired_id)
	_revision += 1
	public_log_changed.emit(_revision)
	return {
		"applied": true,
		"duplicate": false,
		"reason_code": "",
		"revision": _revision,
		"receipt_fingerprint": receipt_fingerprint,
	}


func receipt_binding(receipt_id: String) -> Dictionary:
	if bool(_legacy_unverified_receipt_ids.get(receipt_id, false)):
		return {}
	var binding: Variant = _applied_receipt_ids.get(receipt_id, {})
	return (binding as Dictionary).duplicate(true) if binding is Dictionary else {}


func recent_public_entries(limit := 6) -> Array:
	var normalized_limit := clampi(limit, 0, MAX_ENTRIES)
	var start := maxi(0, _entries.size() - normalized_limit)
	var public_rows: Array = _entries.slice(start, _entries.size()).duplicate(true)
	# Receipt identities are exact-once internals. They may encode domain lineage,
	# so the player-facing projection never exposes them even though the owner
	# retains them for de-duplication and save continuity.
	for row_variant in public_rows:
		if row_variant is Dictionary:
			(row_variant as Dictionary).erase("receipt_id")
	return public_rows


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
	_legacy_unverified_receipt_ids.clear()
	_duplicate_receipt_count = 0
	_rejected_receipt_count = 0
	_collision_receipt_count = 0
	_revision += 1
	public_log_changed.emit(_revision)


func to_save_data() -> Dictionary:
	var legacy_unverified_ids: Array = _legacy_unverified_receipt_ids.keys()
	legacy_unverified_ids.sort()
	return {
		"schema_version": SAVE_SCHEMA_VERSION,
		"entries": _entries.duplicate(true),
		"applied_receipt_ids": _applied_receipt_ids.duplicate(true),
		"tombstone_order": _tombstone_order.duplicate(),
		"retired_revision_floor_by_kind": _retired_revision_floor_by_kind.duplicate(true),
		"revision": _revision,
		"legacy_unverified_receipt_ids": legacy_unverified_ids,
	}


func apply_save_data(data: Dictionary) -> Dictionary:
	var normalized := _normalize_save_data(data)
	if not bool(normalized.get("accepted", false)):
		return {"applied": false, "reason_code": str(normalized.get("reason_code", "public_log_save_invalid"))}
	_entries = (normalized.get("entries", []) as Array).duplicate(true)
	_applied_receipt_ids = (normalized.get("applied_receipt_ids", {}) as Dictionary).duplicate(true)
	_tombstone_order.clear()
	for receipt_id_variant in normalized.get("tombstone_order", []):
		_tombstone_order.append(str(receipt_id_variant))
	_retired_revision_floor_by_kind = (normalized.get("retired_revision_floor_by_kind", {}) as Dictionary).duplicate(true)
	_legacy_unverified_receipt_ids = (normalized.get("legacy_unverified_receipt_ids", {}) as Dictionary).duplicate(true)
	_revision = int(normalized.get("revision", 0))
	_duplicate_receipt_count = 0
	_rejected_receipt_count = 0
	_collision_receipt_count = 0
	public_log_changed.emit(_revision)
	return {"applied": true, "reason_code": "", "revision": _revision}


func debug_snapshot() -> Dictionary:
	return {
		"owner": "PublicLogPresentationOwner",
		"entry_count": _entries.size(),
		"tombstone_count": _applied_receipt_ids.size(),
		"retired_event_kind_count": _retired_revision_floor_by_kind.size(),
		"legacy_unverified_receipt_count": _legacy_unverified_receipt_ids.size(),
		"revision": _revision,
		"duplicate_receipt_count": _duplicate_receipt_count,
		"rejected_receipt_count": _rejected_receipt_count,
		"collision_receipt_count": _collision_receipt_count,
		"typed_receipts_only": true,
		"private_payload_exposed": false,
	}


func _normalize_save_data(data: Dictionary) -> Dictionary:
	if not TablePresentationPureDataPolicy.is_pure_data(data) \
			or not (data.get("schema_version") is int):
		return {"accepted": false, "reason_code": "public_log_save_not_pure_data"}
	var source_version := int(data.get("schema_version", -1))
	var expected_keys := LEGACY_SAVE_KEYS if source_version == LEGACY_SAVE_SCHEMA_VERSION else SAVE_KEYS
	if source_version not in [LEGACY_SAVE_SCHEMA_VERSION, SAVE_SCHEMA_VERSION] \
			or not _has_exact_keys(data, expected_keys) \
			or not (data.get("entries") is Array) \
			or not (data.get("applied_receipt_ids") is Dictionary) \
			or not (data.get("tombstone_order") is Array) \
			or not (data.get("retired_revision_floor_by_kind") is Dictionary) \
			or not (data.get("revision") is int) \
			or int(data.get("revision", -1)) < 0 \
			or source_version == SAVE_SCHEMA_VERSION and not (data.get("legacy_unverified_receipt_ids") is Array):
		return {"accepted": false, "reason_code": "public_log_save_invalid"}
	var source_entries := data.get("entries") as Array
	var source_bindings := data.get("applied_receipt_ids") as Dictionary
	var source_order := data.get("tombstone_order") as Array
	if source_entries.size() > MAX_ENTRIES \
			or source_bindings.size() > MAX_TOMBSTONES \
			or source_order.size() != source_bindings.size():
		return {"accepted": false, "reason_code": "public_log_save_capacity_invalid"}
	var normalized_entries: Array = []
	var normalized_entry_by_id: Dictionary = {}
	for entry_variant in source_entries:
		if not (entry_variant is Dictionary):
			return {"accepted": false, "reason_code": "public_log_save_entry_invalid"}
		var normalized_entry := _normalize_saved_entry(entry_variant as Dictionary)
		if not bool(normalized_entry.get("accepted", false)):
			return {"accepted": false, "reason_code": "public_log_save_entry_invalid"}
		var receipt_id := str(normalized_entry.get("receipt_id", ""))
		if normalized_entry_by_id.has(receipt_id):
			return {"accepted": false, "reason_code": "public_log_save_entry_duplicate"}
		normalized_entries.append((normalized_entry.get("row", {}) as Dictionary).duplicate(true))
		normalized_entry_by_id[receipt_id] = normalized_entry.duplicate(true)
	var declared_legacy_ids: Dictionary = {}
	if source_version == SAVE_SCHEMA_VERSION:
		for receipt_id_variant in data.get("legacy_unverified_receipt_ids", []):
			if not (receipt_id_variant is String or receipt_id_variant is StringName):
				return {"accepted": false, "reason_code": "public_log_save_legacy_binding_invalid"}
			var receipt_id := str(receipt_id_variant).strip_edges()
			if receipt_id.is_empty() or receipt_id != str(receipt_id_variant) \
					or declared_legacy_ids.has(receipt_id):
				return {"accepted": false, "reason_code": "public_log_save_legacy_binding_invalid"}
			declared_legacy_ids[receipt_id] = true
	var normalized_bindings: Dictionary = {}
	var normalized_order: Array[String] = []
	var normalized_legacy_ids: Dictionary = {}
	for receipt_id_variant in source_order:
		if not (receipt_id_variant is String or receipt_id_variant is StringName):
			return {"accepted": false, "reason_code": "public_log_save_tombstone_invalid"}
		var receipt_id := str(receipt_id_variant).strip_edges()
		var binding_variant: Variant = source_bindings.get(receipt_id_variant)
		if receipt_id.is_empty() or receipt_id != str(receipt_id_variant) \
				or normalized_bindings.has(receipt_id) \
				or not (binding_variant is Dictionary):
			return {"accepted": false, "reason_code": "public_log_save_tombstone_invalid"}
		var normalized_binding := _normalize_saved_binding(
			receipt_id,
			binding_variant as Dictionary,
			normalized_entry_by_id.get(receipt_id, {}) as Dictionary,
			source_version,
			bool(declared_legacy_ids.get(receipt_id, false))
		)
		if not bool(normalized_binding.get("accepted", false)):
			return {"accepted": false, "reason_code": str(normalized_binding.get("reason_code", "public_log_save_tombstone_invalid"))}
		normalized_bindings[receipt_id] = (normalized_binding.get("binding", {}) as Dictionary).duplicate(true)
		normalized_order.append(receipt_id)
		if bool(normalized_binding.get("legacy_unverified", false)):
			normalized_legacy_ids[receipt_id] = true
	for receipt_id_variant in source_bindings.keys():
		if not normalized_bindings.has(str(receipt_id_variant)):
			return {"accepted": false, "reason_code": "public_log_save_tombstone_order_incomplete"}
	for receipt_id_variant in normalized_entry_by_id.keys():
		if not normalized_bindings.has(str(receipt_id_variant)):
			return {"accepted": false, "reason_code": "public_log_save_entry_binding_missing"}
	for receipt_id_variant in declared_legacy_ids.keys():
		if not normalized_legacy_ids.has(str(receipt_id_variant)):
			return {"accepted": false, "reason_code": "public_log_save_legacy_binding_invalid"}
	var normalized_retired: Dictionary = {}
	for event_kind_variant in (data.get("retired_revision_floor_by_kind") as Dictionary).keys():
		var event_kind := str(event_kind_variant).strip_edges()
		var floor_variant: Variant = (data.get("retired_revision_floor_by_kind") as Dictionary).get(event_kind_variant)
		if event_kind.is_empty() or event_kind != str(event_kind_variant) \
				or not (floor_variant is int) or int(floor_variant) < -1 \
				or normalized_retired.has(event_kind):
			return {"accepted": false, "reason_code": "public_log_save_retired_floor_invalid"}
		normalized_retired[event_kind] = int(floor_variant)
	return {
		"accepted": true,
		"reason_code": "public_log_save_valid",
		"entries": normalized_entries,
		"applied_receipt_ids": normalized_bindings,
		"tombstone_order": normalized_order,
		"retired_revision_floor_by_kind": normalized_retired,
		"legacy_unverified_receipt_ids": normalized_legacy_ids,
		"revision": int(data.get("revision", 0)),
	}


func _normalize_saved_entry(entry: Dictionary) -> Dictionary:
	if not _has_exact_keys(entry, ENTRY_KEYS) \
			or not (entry.get("receipt_id") is String) \
			or not (entry.get("event_kind") is String) \
			or not (entry.get("localization_key") is String) \
			or not (entry.get("public_values") is Dictionary) \
			or not (entry.get("source_revision") is int) \
			or not (entry.get("world_time") is int or entry.get("world_time") is float) \
			or not (entry.get("visibility_scope") is String) \
			or not (entry.get("message") is String) \
			or int(entry.get("source_revision", -1)) < 0 \
			or not is_finite(float(entry.get("world_time", -1.0))) \
			or float(entry.get("world_time", -1.0)) < 0.0 \
			or str(entry.get("visibility_scope", "")) != "public":
		return {"accepted": false}
	var receipt := PublicLogReceipt.create(
		str(entry.get("receipt_id", "")),
		StringName(str(entry.get("event_kind", ""))),
		StringName(str(entry.get("localization_key", ""))),
		(entry.get("public_values", {}) as Dictionary).duplicate(true),
		int(entry.get("source_revision", 0)),
		float(entry.get("world_time", 0.0))
	)
	if not receipt.is_valid() or receipt.receipt_id != str(entry.get("receipt_id", "")):
		return {"accepted": false}
	var row := receipt.to_dictionary()
	row["message"] = _render_message(receipt)
	return {
		"accepted": true,
		"receipt_id": receipt.receipt_id,
		"fingerprint": receipt.fingerprint(),
		"event_kind": str(receipt.event_kind),
		"source_revision": receipt.source_revision,
		"row": row,
	}


func _normalize_saved_binding(
	receipt_id: String,
	binding: Dictionary,
	entry: Dictionary,
	source_version: int,
	declared_legacy_unverified: bool
) -> Dictionary:
	var legacy_shape := source_version == LEGACY_SAVE_SCHEMA_VERSION \
		and _has_exact_keys(binding, LEGACY_BINDING_KEYS)
	var fingerprint_shape := _has_exact_keys(binding, BINDING_KEYS)
	if not legacy_shape and not fingerprint_shape \
			or not (binding.get("event_kind") is String) \
			or not (binding.get("source_revision") is int) \
			or str(binding.get("event_kind", "")).is_empty() \
			or int(binding.get("source_revision", -1)) < 0:
		return {"accepted": false, "reason_code": "public_log_save_tombstone_invalid"}
	var fingerprint := str(binding.get("receipt_fingerprint", ""))
	var legacy_unverified := declared_legacy_unverified
	if not entry.is_empty():
		if str(binding.get("event_kind", "")) != str(entry.get("event_kind", "")) \
				or int(binding.get("source_revision", -1)) != int(entry.get("source_revision", -2)) \
				or declared_legacy_unverified:
			return {"accepted": false, "reason_code": "public_log_save_entry_binding_collision"}
		var entry_fingerprint := str(entry.get("fingerprint", ""))
		if fingerprint_shape and fingerprint != entry_fingerprint:
			return {"accepted": false, "reason_code": "public_log_save_entry_binding_collision"}
		fingerprint = entry_fingerprint
		legacy_unverified = false
	elif legacy_shape:
		fingerprint = JSON.stringify([
			"legacy-public-log-binding",
			receipt_id,
			str(binding.get("event_kind", "")),
			int(binding.get("source_revision", 0)),
		]).sha256_text()
		legacy_unverified = true
	elif not _valid_receipt_fingerprint(fingerprint):
		return {"accepted": false, "reason_code": "public_log_save_tombstone_fingerprint_invalid"}
	if source_version == SAVE_SCHEMA_VERSION and declared_legacy_unverified != legacy_unverified:
		return {"accepted": false, "reason_code": "public_log_save_legacy_binding_invalid"}
	return {
		"accepted": true,
		"legacy_unverified": legacy_unverified,
		"binding": {
			"event_kind": str(binding.get("event_kind", "")),
			"source_revision": int(binding.get("source_revision", 0)),
			"receipt_fingerprint": fingerprint,
		},
	}


func _valid_receipt_fingerprint(value: String) -> bool:
	if value.length() != 64:
		return false
	for index in range(value.length()):
		if not "0123456789abcdef".contains(value.substr(index, 1)):
			return false
	return true


func _has_exact_keys(dictionary: Dictionary, expected: Array) -> bool:
	if dictionary.size() != expected.size():
		return false
	for key in expected:
		if not dictionary.has(key):
			return false
	return true


func _render_message(receipt: PublicLogReceipt) -> String:
	var message := _localized_message(receipt)
	var minutes := int(floor(receipt.world_time / 60.0))
	var seconds := int(floor(receipt.world_time)) % 60
	return "[%02d:%02d] %s" % [minutes, seconds, message]


func _localized_message(receipt: PublicLogReceipt) -> String:
	var localization_key := str(receipt.localization_key)
	if localization_key == "public.ai_business.market_pressure_resolved":
		return "匿名财团在%s制造%s需求压力%d，价格¥%d→¥%d" % [
			str(receipt.public_values.get("region_id", "未知区域")),
			str(receipt.public_values.get("commodity_id", "未知商品")),
			maxi(0, int(receipt.public_values.get("pressure_units", 0))),
			maxi(0, int(receipt.public_values.get("price_before", 0))),
			maxi(0, int(receipt.public_values.get("price_after", 0))),
		]
	if LOCALIZED_MESSAGES.has(localization_key):
		return str(LOCALIZED_MESSAGES[localization_key])
	if localization_key == "victory.public.state_changed":
		var previous_label := str(VICTORY_STATE_LABELS.get(str(receipt.public_values.get("previous_state", "")), ""))
		var state_label := str(VICTORY_STATE_LABELS.get(str(receipt.public_values.get("state", "")), ""))
		if not previous_label.is_empty() and not state_label.is_empty():
			return "胜利进程：%s → %s" % [previous_label, state_label]
		return "胜利进程已更新"
	return GENERIC_PUBLIC_MESSAGE
