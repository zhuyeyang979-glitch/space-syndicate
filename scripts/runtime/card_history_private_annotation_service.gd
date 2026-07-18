@tool
extends Node
class_name CardHistoryPrivateAnnotationService

const MAX_SUBSCRIPTIONS := 2
const EDITABLE_FIELDS := [
	"note_text",
	"private_tags",
	"suspected_player_indices",
	"private_confidence",
	"excluded_player_indices",
	"subscribed",
]
const OUTPUT_FIELDS := [
	"viewer_index",
	"history_entry_id",
	"note_text",
	"private_tags",
	"suspected_player_indices",
	"private_confidence",
	"public_evidence_summary",
	"excluded_player_indices",
	"subscribed",
	"verified_by_public_reveal",
	"updated_at_public_revision",
]

var _public_query: Node
var _annotations_by_viewer: Dictionary = {}
var _role_usage_by_viewer: Dictionary = {}
var _subscription_fingerprints: Dictionary = {}
var _revision := 0
var _notification_count := 0


func configure(public_query: Node) -> void:
	_public_query = public_query if public_query != null and public_query.has_method("entry_by_id") else null


func reset_state() -> void:
	_annotations_by_viewer.clear()
	_role_usage_by_viewer.clear()
	_subscription_fingerprints.clear()
	_revision = 0
	_notification_count = 0


func annotation_for_viewer(viewer_index: int, history_entry_id: String) -> Dictionary:
	if viewer_index < 0 or history_entry_id.strip_edges().is_empty():
		return {}
	var viewer_rows: Dictionary = _annotations_by_viewer.get(str(viewer_index), {}) if _annotations_by_viewer.get(str(viewer_index), {}) is Dictionary else {}
	var row_variant: Variant = viewer_rows.get(history_entry_id, {})
	return (row_variant as Dictionary).duplicate(true) if row_variant is Dictionary else {}


func viewer_snapshot(viewer_index: int) -> Dictionary:
	var rows: Array = []
	var viewer_rows: Dictionary = _annotations_by_viewer.get(str(viewer_index), {}) if _annotations_by_viewer.get(str(viewer_index), {}) is Dictionary else {}
	var ids: Array = viewer_rows.keys()
	ids.sort()
	for entry_id_variant in ids:
		rows.append((viewer_rows[entry_id_variant] as Dictionary).duplicate(true))
	return {
		"schema_version": 1,
		"visibility_scope": "viewer_private",
		"viewer_index": viewer_index,
		"revision": _revision,
		"annotations": rows,
	}


func apply_annotation(viewer_index: int, history_entry_id: String, patch: Dictionary) -> Dictionary:
	var public_entry := _public_entry(history_entry_id)
	if viewer_index < 0 or public_entry.is_empty() or patch.is_empty() or not _valid_patch(patch):
		return {"applied": false, "reason_code": "annotation_request_invalid", "revision": _revision}
	var before := annotation_for_viewer(viewer_index, history_entry_id)
	var after := _base_annotation(viewer_index, public_entry) if before.is_empty() else before.duplicate(true)
	for field_variant in EDITABLE_FIELDS:
		var field := str(field_variant)
		if patch.has(field):
			after[field] = _normalized_field(field, patch[field])
	if bool(after.get("subscribed", false)) and not bool(before.get("subscribed", false)) and _subscription_count(viewer_index) >= MAX_SUBSCRIPTIONS:
		return {"applied": false, "reason_code": "subscription_limit_reached", "revision": _revision}
	after["public_evidence_summary"] = _evidence_summary(public_entry)
	after["verified_by_public_reveal"] = not str(public_entry.get("publicly_revealed_actor", "")).is_empty()
	after["updated_at_public_revision"] = int(public_entry.get("public_revision", 0))
	if after == before:
		return {"applied": true, "changed": false, "reason_code": "unchanged", "revision": _revision, "annotation": after}
	_store_annotation(viewer_index, history_entry_id, after)
	_subscription_fingerprints[_subscription_key(viewer_index, history_entry_id)] = _public_fingerprint(public_entry)
	_revision += 1
	return {"applied": true, "changed": true, "reason_code": "annotation_updated", "revision": _revision, "annotation": after.duplicate(true)}


func create_public_evidence_review(viewer_index: int, history_entry_id: String, public_player_indices: Array) -> Dictionary:
	var suspects := _normalized_indices(public_player_indices)
	if suspects.is_empty():
		return {"applied": false, "reason_code": "public_evidence_not_meaningful", "revision": _revision}
	return apply_annotation(viewer_index, history_entry_id, {
		"suspected_player_indices": suspects,
		"private_tags": ["公开证据复盘"],
		"private_confidence": 1,
	})


func subscribe_entries(viewer_index: int, history_entry_ids: Array) -> Dictionary:
	var applied_ids: Array[String] = []
	for entry_id_variant in history_entry_ids:
		if applied_ids.size() >= MAX_SUBSCRIPTIONS:
			break
		var entry_id := str(entry_id_variant).strip_edges()
		if entry_id.is_empty() or applied_ids.has(entry_id):
			continue
		var result := apply_annotation(viewer_index, entry_id, {"subscribed": true, "private_tags": ["线索订阅"]})
		if bool(result.get("applied", false)):
			applied_ids.append(entry_id)
	return {
		"applied": not applied_ids.is_empty(),
		"reason_code": "subscriptions_updated" if not applied_ids.is_empty() else "no_subscription_target",
		"history_entry_ids": applied_ids,
		"revision": _revision,
	}


func use_residual_catalog_role(viewer_index: int, history_entry_id: String, public_player_indices: Array, maximum_charges: int) -> Dictionary:
	var used := _role_usage(viewer_index, "residual_catalog")
	if maximum_charges <= 0 or used >= maximum_charges:
		return {"applied": false, "reason_code": "role_charges_exhausted", "used": used}
	var result := create_public_evidence_review(viewer_index, history_entry_id, public_player_indices)
	if bool(result.get("changed", false)):
		_set_role_usage(viewer_index, "residual_catalog", used + 1)
		result["used"] = used + 1
		result["remaining"] = maxi(0, maximum_charges - used - 1)
	return result


func use_public_exclusion_role(viewer_index: int, history_entry_id: String, publicly_impossible_player_indices: Array, maximum_charges: int) -> Dictionary:
	var used := _role_usage(viewer_index, "public_exclusion")
	var impossible := _normalized_indices(publicly_impossible_player_indices)
	if maximum_charges <= 0 or used >= maximum_charges:
		return {"applied": false, "reason_code": "role_charges_exhausted", "used": used}
	if impossible.is_empty():
		return {"applied": false, "reason_code": "no_publicly_impossible_suspect", "used": used}
	var before := annotation_for_viewer(viewer_index, history_entry_id)
	var suspects: Array = before.get("suspected_player_indices", []) if before.get("suspected_player_indices", []) is Array else []
	var excluded: Array = before.get("excluded_player_indices", []) if before.get("excluded_player_indices", []) is Array else []
	var selected := -1
	for player_index_variant in impossible:
		var player_index := int(player_index_variant)
		if suspects.has(player_index) and not excluded.has(player_index):
			selected = player_index
			break
	if selected < 0:
		return {"applied": false, "reason_code": "no_publicly_impossible_suspect", "used": used}
	excluded.append(selected)
	suspects.erase(selected)
	var result := apply_annotation(viewer_index, history_entry_id, {"suspected_player_indices": suspects, "excluded_player_indices": excluded})
	if bool(result.get("changed", false)):
		_set_role_usage(viewer_index, "public_exclusion", used + 1)
		result["excluded_player_index"] = selected
		result["used"] = used + 1
		result["remaining"] = maxi(0, maximum_charges - used - 1)
	return result


func refresh_subscriptions() -> Dictionary:
	var changed_ids: Array[String] = []
	for viewer_key_variant in _annotations_by_viewer.keys():
		var viewer_index := int(viewer_key_variant)
		var rows: Dictionary = _annotations_by_viewer[viewer_key_variant]
		for entry_id_variant in rows.keys():
			var entry_id := str(entry_id_variant)
			var annotation: Dictionary = rows[entry_id_variant]
			if not bool(annotation.get("subscribed", false)):
				continue
			var public_entry := _public_entry(entry_id)
			if public_entry.is_empty():
				continue
			var key := _subscription_key(viewer_index, entry_id)
			var fingerprint := _public_fingerprint(public_entry)
			if str(_subscription_fingerprints.get(key, "")) == fingerprint:
				continue
			annotation["public_evidence_summary"] = _evidence_summary(public_entry)
			annotation["verified_by_public_reveal"] = not str(public_entry.get("publicly_revealed_actor", "")).is_empty()
			annotation["updated_at_public_revision"] = int(public_entry.get("public_revision", 0))
			rows[entry_id] = annotation
			_subscription_fingerprints[key] = fingerprint
			changed_ids.append("%d:%s" % [viewer_index, entry_id])
			_notification_count += 1
	if not changed_ids.is_empty():
		_revision += 1
	return {"refreshed": true, "changed_entry_ids": changed_ids, "notification_count": changed_ids.size(), "revision": _revision}


func debug_snapshot() -> Dictionary:
	return {
		"service_ready": _public_query != null,
		"runtime_owner": "CardHistoryPrivateAnnotationService",
		"viewer_count": _annotations_by_viewer.size(),
		"revision": _revision,
		"notification_count": _notification_count,
		"viewer_scoped": true,
		"economic_reward_count": 0,
		"gdp_reward_count": 0,
		"reads_hidden_actor": false,
		"public_broadcast_count": 0,
		"owns_save_schema": false,
		"save_debt": "session_scoped_until_existing_card_execution_owner_can_version_annotations",
	}


func _public_entry(history_entry_id: String) -> Dictionary:
	return _public_query.entry_by_id(history_entry_id) if _public_query != null else {}


func _base_annotation(viewer_index: int, public_entry: Dictionary) -> Dictionary:
	return {
		"viewer_index": viewer_index,
		"history_entry_id": str(public_entry.get("history_entry_id", "")),
		"note_text": "",
		"private_tags": [],
		"suspected_player_indices": [],
		"private_confidence": 0,
		"public_evidence_summary": _evidence_summary(public_entry),
		"excluded_player_indices": [],
		"subscribed": false,
		"verified_by_public_reveal": not str(public_entry.get("publicly_revealed_actor", "")).is_empty(),
		"updated_at_public_revision": int(public_entry.get("public_revision", 0)),
	}


func _store_annotation(viewer_index: int, history_entry_id: String, annotation: Dictionary) -> void:
	var viewer_key := str(viewer_index)
	var rows: Dictionary = _annotations_by_viewer.get(viewer_key, {}) if _annotations_by_viewer.get(viewer_key, {}) is Dictionary else {}
	rows[history_entry_id] = annotation.duplicate(true)
	_annotations_by_viewer[viewer_key] = rows


func _valid_patch(patch: Dictionary) -> bool:
	for key_variant in patch.keys():
		if not EDITABLE_FIELDS.has(str(key_variant)):
			return false
	return true


func _normalized_field(field: String, value: Variant) -> Variant:
	match field:
		"note_text": return str(value).substr(0, 240)
		"private_tags":
			var tags: Array[String] = []
			if value is Array:
				for tag_variant in value:
					var tag := str(tag_variant).strip_edges().substr(0, 32)
					if not tag.is_empty() and not tags.has(tag) and tags.size() < 8:
						tags.append(tag)
			return tags
		"suspected_player_indices", "excluded_player_indices": return _normalized_indices(value as Array if value is Array else [])
		"private_confidence": return clampi(int(value), 0, 3)
		"subscribed": return bool(value)
	return null


func _normalized_indices(values: Array) -> Array[int]:
	var result: Array[int] = []
	for value_variant in values:
		var value := int(value_variant)
		if value >= 0 and not result.has(value):
			result.append(value)
	result.sort()
	return result


func _subscription_count(viewer_index: int) -> int:
	var count := 0
	var rows: Dictionary = _annotations_by_viewer.get(str(viewer_index), {}) if _annotations_by_viewer.get(str(viewer_index), {}) is Dictionary else {}
	for row_variant in rows.values():
		if row_variant is Dictionary and bool((row_variant as Dictionary).get("subscribed", false)):
			count += 1
	return count


func _role_usage(viewer_index: int, ability_id: String) -> int:
	var rows: Dictionary = _role_usage_by_viewer.get(str(viewer_index), {}) if _role_usage_by_viewer.get(str(viewer_index), {}) is Dictionary else {}
	return maxi(0, int(rows.get(ability_id, 0)))


func _set_role_usage(viewer_index: int, ability_id: String, value: int) -> void:
	var key := str(viewer_index)
	var rows: Dictionary = _role_usage_by_viewer.get(key, {}) if _role_usage_by_viewer.get(key, {}) is Dictionary else {}
	rows[ability_id] = maxi(0, value)
	_role_usage_by_viewer[key] = rows


func _evidence_summary(public_entry: Dictionary) -> String:
	return "%s｜%s｜%s｜%s｜%s" % [
		str(public_entry.get("public_card_name", "未知牌")),
		str(public_entry.get("public_target", "无公开目标")),
		str(public_entry.get("public_card_category", "unknown")),
		str(public_entry.get("public_action_phase", "unknown")),
		str(public_entry.get("public_result", "无公开结果")),
	]


func _public_fingerprint(public_entry: Dictionary) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(JSON.stringify(public_entry).to_utf8_buffer())
	return context.finish().hex_encode()


func _subscription_key(viewer_index: int, history_entry_id: String) -> String:
	return "%d|%s" % [viewer_index, history_entry_id]
