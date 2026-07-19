@tool
extends Node
class_name CardHistoryPrivateAnnotationService

const MAX_SUBSCRIPTIONS := 2
const SAVE_SCHEMA_VERSION := 1
const MAX_RESIDUAL_CATALOG_USAGE := 2
const MAX_PUBLIC_EXCLUSION_USAGE := 3
const SAVE_ROOT_FIELDS := ["schema_version", "revision", "annotations_by_viewer", "role_usage_by_viewer"]
const SAVE_ANNOTATION_FIELDS := [
	"note_text",
	"private_tags",
	"suspected_player_indices",
	"private_confidence",
	"excluded_player_indices",
	"subscribed",
]
const ROLE_USAGE_LIMITS := {
	"residual_catalog": MAX_RESIDUAL_CATALOG_USAGE,
	"public_exclusion": MAX_PUBLIC_EXCLUSION_USAGE,
}
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

var _public_query: CardHistoryPublicQueryPort
var _annotations_by_viewer: Dictionary = {}
var _role_usage_by_viewer: Dictionary = {}
var _subscription_fingerprints: Dictionary = {}
var _revision := 0
var _notification_count := 0


func configure(public_query: CardHistoryPublicQueryPort) -> void:
	_public_query = public_query


func reset_state() -> void:
	_annotations_by_viewer.clear()
	_role_usage_by_viewer.clear()
	_subscription_fingerprints.clear()
	_revision = 0
	_notification_count = 0


func annotation_for_viewer(viewer_index: int, history_entry_id: String) -> Dictionary:
	var normalized_id := history_entry_id.strip_edges()
	if viewer_index < 0 or normalized_id.is_empty():
		return {}
	var viewer_rows: Dictionary = _annotations_by_viewer.get(str(viewer_index), {}) if _annotations_by_viewer.get(str(viewer_index), {}) is Dictionary else {}
	var row_variant: Variant = viewer_rows.get(normalized_id, {})
	return (row_variant as Dictionary).duplicate(true) if row_variant is Dictionary else {}


func viewer_snapshot(viewer_index: int) -> Dictionary:
	var rows := _viewer_annotation_rows(viewer_index)
	return {
		"schema_version": 1,
		"visibility_scope": "viewer_private",
		"viewer_index": viewer_index,
		"revision": _viewer_owner_revision(viewer_index, rows),
		"annotations": rows,
	}


func apply_annotation(viewer_index: int, history_entry_id: String, patch: Dictionary) -> Dictionary:
	if patch.has("excluded_player_indices"):
		return {"applied": false, "reason_code": "annotation_exclusion_requires_public_evidence", "revision": _revision}
	return _apply_annotation_patch(viewer_index, history_entry_id, patch, false)


func owner_revision_for_viewer(viewer_index: int) -> String:
	if viewer_index < 0:
		return ""
	return _viewer_owner_revision(viewer_index, _viewer_annotation_rows(viewer_index))


func _viewer_owner_revision(viewer_index: int, rows: Array) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(JSON.stringify({
		"schema_version": SAVE_SCHEMA_VERSION,
		"viewer_index": viewer_index,
		"annotations": rows,
		"role_usage": role_usage_snapshot(viewer_index),
	}).to_utf8_buffer())
	return context.finish().hex_encode()


func _viewer_annotation_rows(viewer_index: int) -> Array:
	var rows: Array = []
	if viewer_index < 0:
		return rows
	var viewer_rows: Dictionary = _annotations_by_viewer.get(str(viewer_index), {}) if _annotations_by_viewer.get(str(viewer_index), {}) is Dictionary else {}
	var ids: Array = viewer_rows.keys()
	ids.sort()
	for entry_id_variant in ids:
		rows.append((viewer_rows[entry_id_variant] as Dictionary).duplicate(true))
	return rows


func role_usage_snapshot(viewer_index: int) -> Dictionary:
	if viewer_index < 0:
		return {}
	return {
		"viewer_index": viewer_index,
		"residual_catalog": _role_usage(viewer_index, "residual_catalog"),
		"public_exclusion": _role_usage(viewer_index, "public_exclusion"),
		"visibility_scope": "viewer_private",
	}


func notification_count() -> int:
	return _notification_count


func set_note_exact(viewer_index: int, history_entry_id: String, note_text: String) -> Dictionary:
	if note_text.length() > 240:
		return {"applied": false, "reason_code": "annotation_note_invalid", "revision": _revision}
	return _apply_annotation_patch(viewer_index, history_entry_id, {"note_text": note_text}, false)


func set_tags_exact(viewer_index: int, history_entry_id: String, private_tags: Array) -> Dictionary:
	if not _strict_tags_valid(private_tags):
		return {"applied": false, "reason_code": "annotation_tags_invalid", "revision": _revision}
	return _apply_annotation_patch(viewer_index, history_entry_id, {"private_tags": private_tags.duplicate()}, false)


func set_suspects_exact(viewer_index: int, history_entry_id: String, suspected_player_indices: Array, valid_player_count: int) -> Dictionary:
	if not _strict_indices_valid(suspected_player_indices, valid_player_count):
		return {"applied": false, "reason_code": "annotation_suspects_invalid", "revision": _revision}
	var current := annotation_for_viewer(viewer_index, history_entry_id)
	var excluded: Array = current.get("excluded_player_indices", []) if current.get("excluded_player_indices", []) is Array else []
	for player_index_variant in suspected_player_indices:
		if excluded.has(player_index_variant):
			return {"applied": false, "reason_code": "annotation_indices_overlap", "revision": _revision}
	return _apply_annotation_patch(viewer_index, history_entry_id, {"suspected_player_indices": suspected_player_indices.duplicate()}, false)


func set_private_confidence_exact(viewer_index: int, history_entry_id: String, private_confidence: int) -> Dictionary:
	if private_confidence < 0 or private_confidence > 3:
		return {"applied": false, "reason_code": "annotation_confidence_invalid", "revision": _revision}
	return _apply_annotation_patch(viewer_index, history_entry_id, {"private_confidence": private_confidence}, false)


func set_subscription_exact(viewer_index: int, history_entry_id: String, subscribed: bool) -> Dictionary:
	return _apply_annotation_patch(viewer_index, history_entry_id, {"subscribed": subscribed}, false)


func clear_annotation_exact(viewer_index: int, history_entry_id: String) -> Dictionary:
	if annotation_for_viewer(viewer_index, history_entry_id).is_empty():
		return {"applied": true, "changed": false, "reason_code": "unchanged", "revision": _revision}
	return _apply_annotation_patch(viewer_index, history_entry_id, {
		"note_text": "",
		"private_tags": [],
		"suspected_player_indices": [],
		"private_confidence": 0,
		"excluded_player_indices": [],
		"subscribed": false,
	}, true)


func use_residual_catalog_from_public_evidence(viewer_index: int, history_entry_id: String, valid_player_count: int, maximum_charges: int) -> Dictionary:
	var public_entry := _public_entry(history_entry_id)
	if public_entry.is_empty() or not str(public_entry.get("publicly_revealed_actor", "")).is_empty() or valid_player_count < 2:
		return {"applied": false, "reason_code": "public_evidence_not_meaningful", "revision": _revision}
	var public_candidates: Array[int] = []
	for player_index in range(valid_player_count):
		public_candidates.append(player_index)
	return use_residual_catalog_role(viewer_index, history_entry_id, public_candidates, mini(maximum_charges, MAX_RESIDUAL_CATALOG_USAGE))


func use_public_exclusion_from_public_evidence(viewer_index: int, history_entry_id: String, maximum_charges: int) -> Dictionary:
	var public_entry := _public_entry(history_entry_id)
	if public_entry.is_empty() or maximum_charges <= 0:
		return {"applied": false, "reason_code": "public_evidence_not_meaningful", "revision": _revision}
	# The frozen public-history projection exposes no authoritative impossibility set.
	# Failing closed avoids manufacturing an exclusion from a target label.
	return {"applied": false, "reason_code": "no_publicly_impossible_suspect", "revision": _revision}


func _apply_annotation_patch(viewer_index: int, history_entry_id: String, patch: Dictionary, allow_evidence_exclusion: bool) -> Dictionary:
	var normalized_id := history_entry_id.strip_edges()
	var public_entry := _public_entry(normalized_id)
	if viewer_index < 0 or public_entry.is_empty() or patch.is_empty() or not _valid_patch(patch) \
			or (patch.has("excluded_player_indices") and not allow_evidence_exclusion):
		return {"applied": false, "reason_code": "annotation_request_invalid", "revision": _revision}
	var before := annotation_for_viewer(viewer_index, normalized_id)
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
	_store_annotation(viewer_index, normalized_id, after)
	_subscription_fingerprints[_subscription_key(viewer_index, normalized_id)] = _public_fingerprint(public_entry)
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
	var result := _apply_annotation_patch(viewer_index, history_entry_id, {"suspected_player_indices": suspects, "excluded_player_indices": excluded}, true)
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


func capture_save_checkpoint(valid_viewer_count: int) -> Dictionary:
	var validation := validate_save_checkpoint(_durable_checkpoint(), valid_viewer_count)
	if not bool(validation.get("accepted", false)):
		return validation
	return {
		"accepted": true,
		"reason_code": "card_annotation_checkpoint_ready",
		"checkpoint": (validation.get("normalized_state", {}) as Dictionary).duplicate(true),
	}


func validate_save_checkpoint(data: Dictionary, valid_viewer_count: int) -> Dictionary:
	if valid_viewer_count < 0 or not _has_exact_keys(data, SAVE_ROOT_FIELDS) \
			or int(data.get("schema_version", -1)) != SAVE_SCHEMA_VERSION \
			or not (data.get("revision") is int) \
			or int(data.get("revision", -1)) < 0 \
			or not (data.get("annotations_by_viewer") is Dictionary) \
			or not (data.get("role_usage_by_viewer") is Dictionary):
		return _checkpoint_rejection("card_annotation_checkpoint_schema_invalid")
	var normalized_annotations: Dictionary = {}
	var annotation_buckets: Dictionary = data.get("annotations_by_viewer", {})
	for viewer_key_variant in annotation_buckets.keys():
		var viewer_result := _validated_viewer_key(viewer_key_variant, valid_viewer_count)
		if not bool(viewer_result.get("accepted", false)):
			return viewer_result
		var viewer_index := int(viewer_result.get("viewer_index", -1))
		if not (annotation_buckets[viewer_key_variant] is Dictionary):
			return _checkpoint_rejection("card_annotation_viewer_rows_invalid")
		var rows: Dictionary = annotation_buckets[viewer_key_variant]
		var normalized_rows: Dictionary = {}
		var subscription_count := 0
		for history_id_variant in rows.keys():
			if not (history_id_variant is String):
				return _checkpoint_rejection("card_annotation_history_id_invalid")
			var history_entry_id := str(history_id_variant)
			if not _canonical_history_entry_id(history_entry_id) or not (rows[history_id_variant] is Dictionary):
				return _checkpoint_rejection("card_annotation_history_id_invalid")
			var row_result := _normalize_saved_annotation(rows[history_id_variant] as Dictionary, valid_viewer_count)
			if not bool(row_result.get("accepted", false)):
				return row_result
			var normalized_row: Dictionary = row_result.get("normalized_row", {})
			if bool(normalized_row.get("subscribed", false)):
				subscription_count += 1
			normalized_rows[history_entry_id] = normalized_row
		if subscription_count > MAX_SUBSCRIPTIONS:
			return _checkpoint_rejection("card_annotation_subscription_limit_invalid")
		normalized_annotations[str(viewer_index)] = normalized_rows
	var normalized_role_usage: Dictionary = {}
	var role_usage_buckets: Dictionary = data.get("role_usage_by_viewer", {})
	for viewer_key_variant in role_usage_buckets.keys():
		var viewer_result := _validated_viewer_key(viewer_key_variant, valid_viewer_count)
		if not bool(viewer_result.get("accepted", false)):
			return viewer_result
		var viewer_index := int(viewer_result.get("viewer_index", -1))
		if not (role_usage_buckets[viewer_key_variant] is Dictionary):
			return _checkpoint_rejection("card_annotation_role_usage_invalid")
		var usage: Dictionary = role_usage_buckets[viewer_key_variant]
		var normalized_usage: Dictionary = {}
		for ability_variant in usage.keys():
			var ability_id := str(ability_variant)
			if not ROLE_USAGE_LIMITS.has(ability_id) \
					or not (usage[ability_variant] is int) \
					or int(usage[ability_variant]) < 0 \
					or int(usage[ability_variant]) > int(ROLE_USAGE_LIMITS[ability_id]):
				return _checkpoint_rejection("card_annotation_role_usage_invalid")
			normalized_usage[ability_id] = int(usage[ability_variant])
		normalized_role_usage[str(viewer_index)] = normalized_usage
	return {
		"accepted": true,
		"reason_code": "card_annotation_checkpoint_valid",
		"normalized_state": {
			"schema_version": SAVE_SCHEMA_VERSION,
			"revision": int(data.get("revision", 0)),
			"annotations_by_viewer": normalized_annotations,
			"role_usage_by_viewer": normalized_role_usage,
		},
	}


func apply_save_checkpoint(data: Dictionary, valid_viewer_count: int) -> Dictionary:
	var validation := validate_save_checkpoint(data, valid_viewer_count)
	if not bool(validation.get("accepted", false)):
		return {
			"applied": false,
			"reason_code": str(validation.get("reason_code", "card_annotation_checkpoint_invalid")),
		}
	var normalized: Dictionary = validation.get("normalized_state", {})
	var rebuilt_annotations: Dictionary = {}
	var rebuilt_fingerprints: Dictionary = {}
	var saved_annotations: Dictionary = normalized.get("annotations_by_viewer", {})
	for viewer_key_variant in saved_annotations.keys():
		var viewer_index := int(str(viewer_key_variant))
		var saved_rows: Dictionary = saved_annotations[viewer_key_variant]
		var rebuilt_rows: Dictionary = {}
		for history_id_variant in saved_rows.keys():
			var history_entry_id := str(history_id_variant)
			var public_entry := _public_entry(history_entry_id)
			if public_entry.is_empty():
				return {"applied": false, "reason_code": "card_annotation_public_history_missing"}
			var rebuilt := _base_annotation(viewer_index, public_entry)
			var saved_row: Dictionary = saved_rows[history_id_variant]
			for field_variant in SAVE_ANNOTATION_FIELDS:
				var field := str(field_variant)
				rebuilt[field] = _duplicate_data(saved_row[field])
			rebuilt_rows[history_entry_id] = rebuilt
			if bool(rebuilt.get("subscribed", false)):
				rebuilt_fingerprints[_subscription_key(viewer_index, history_entry_id)] = _public_fingerprint(public_entry)
		rebuilt_annotations[str(viewer_index)] = rebuilt_rows
	_annotations_by_viewer = rebuilt_annotations
	_role_usage_by_viewer = (normalized.get("role_usage_by_viewer", {}) as Dictionary).duplicate(true)
	_subscription_fingerprints = rebuilt_fingerprints
	_revision = int(normalized.get("revision", 0))
	return {
		"applied": true,
		"reason_code": "card_annotation_checkpoint_restored",
		"revision": _revision,
	}


func empty_save_checkpoint() -> Dictionary:
	return {
		"schema_version": SAVE_SCHEMA_VERSION,
		"revision": 0,
		"annotations_by_viewer": {},
		"role_usage_by_viewer": {},
	}


func capture_runtime_checkpoint() -> Dictionary:
	return {
		"annotations_by_viewer": _annotations_by_viewer.duplicate(true),
		"role_usage_by_viewer": _role_usage_by_viewer.duplicate(true),
		"subscription_fingerprints": _subscription_fingerprints.duplicate(true),
		"revision": _revision,
		"notification_count": _notification_count,
	}


func restore_runtime_checkpoint(checkpoint: Dictionary) -> Dictionary:
	for key in ["annotations_by_viewer", "role_usage_by_viewer", "subscription_fingerprints"]:
		if not (checkpoint.get(key) is Dictionary):
			return {"applied": false, "reason_code": "card_annotation_runtime_checkpoint_invalid"}
	if not (checkpoint.get("revision") is int) or not (checkpoint.get("notification_count") is int):
		return {"applied": false, "reason_code": "card_annotation_runtime_checkpoint_invalid"}
	_annotations_by_viewer = (checkpoint.get("annotations_by_viewer", {}) as Dictionary).duplicate(true)
	_role_usage_by_viewer = (checkpoint.get("role_usage_by_viewer", {}) as Dictionary).duplicate(true)
	_subscription_fingerprints = (checkpoint.get("subscription_fingerprints", {}) as Dictionary).duplicate(true)
	_revision = int(checkpoint.get("revision", 0))
	_notification_count = int(checkpoint.get("notification_count", 0))
	return {"applied": true, "restored": true, "reason_code": "card_annotation_runtime_checkpoint_restored"}


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
		"checkpoint_persisted_by_session_owner": true,
		"notification_state_persisted": false,
		"preflight_reads_live_history": false,
		"generic_exclusion_patch_allowed": false,
		"typed_command_adapter": true,
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


func _durable_checkpoint() -> Dictionary:
	var annotations: Dictionary = {}
	for viewer_key_variant in _annotations_by_viewer.keys():
		var rows_variant: Variant = _annotations_by_viewer[viewer_key_variant]
		if not (rows_variant is Dictionary):
			annotations[viewer_key_variant] = rows_variant
			continue
		var durable_rows: Dictionary = {}
		for history_id_variant in (rows_variant as Dictionary).keys():
			var row_variant: Variant = (rows_variant as Dictionary)[history_id_variant]
			if not (row_variant is Dictionary):
				durable_rows[history_id_variant] = row_variant
				continue
			var durable_row: Dictionary = {}
			for field_variant in SAVE_ANNOTATION_FIELDS:
				var field := str(field_variant)
				durable_row[field] = _duplicate_data((row_variant as Dictionary).get(field))
			durable_rows[history_id_variant] = durable_row
		annotations[viewer_key_variant] = durable_rows
	return {
		"schema_version": SAVE_SCHEMA_VERSION,
		"revision": _revision,
		"annotations_by_viewer": annotations,
		"role_usage_by_viewer": _role_usage_by_viewer.duplicate(true),
	}


func _normalize_saved_annotation(row: Dictionary, valid_viewer_count: int) -> Dictionary:
	if not _has_exact_keys(row, SAVE_ANNOTATION_FIELDS) \
			or not (row.get("note_text") is String) \
			or str(row.get("note_text", "")).length() > 240 \
			or not (row.get("private_tags") is Array) \
			or not (row.get("suspected_player_indices") is Array) \
			or not (row.get("excluded_player_indices") is Array) \
			or not (row.get("private_confidence") is int) \
			or int(row.get("private_confidence", -1)) < 0 \
			or int(row.get("private_confidence", -1)) > 3 \
			or not (row.get("subscribed") is bool):
		return _checkpoint_rejection("card_annotation_row_invalid")
	var tags: Array[String] = []
	for tag_variant in row.get("private_tags", []) as Array:
		if not (tag_variant is String):
			return _checkpoint_rejection("card_annotation_tags_invalid")
		var tag := str(tag_variant)
		if tag.strip_edges() != tag or tag.is_empty() or tag.length() > 32 or tags.has(tag) or tags.size() >= 8:
			return _checkpoint_rejection("card_annotation_tags_invalid")
		tags.append(tag)
	var suspects_result := _validated_saved_indices(row.get("suspected_player_indices", []), valid_viewer_count)
	var excluded_result := _validated_saved_indices(row.get("excluded_player_indices", []), valid_viewer_count)
	if not bool(suspects_result.get("accepted", false)):
		return suspects_result
	if not bool(excluded_result.get("accepted", false)):
		return excluded_result
	var suspects: Array = suspects_result.get("values", [])
	var excluded: Array = excluded_result.get("values", [])
	for player_index_variant in suspects:
		if excluded.has(player_index_variant):
			return _checkpoint_rejection("card_annotation_indices_overlap")
	return {
		"accepted": true,
		"normalized_row": {
			"note_text": str(row.get("note_text", "")),
			"private_tags": tags,
			"suspected_player_indices": suspects,
			"private_confidence": int(row.get("private_confidence", 0)),
			"excluded_player_indices": excluded,
			"subscribed": bool(row.get("subscribed", false)),
		},
	}


func _validated_saved_indices(value: Variant, valid_viewer_count: int) -> Dictionary:
	if not (value is Array):
		return _checkpoint_rejection("card_annotation_indices_invalid")
	var result: Array[int] = []
	for index_variant in value as Array:
		if not (index_variant is int):
			return _checkpoint_rejection("card_annotation_indices_invalid")
		var player_index := int(index_variant)
		if player_index < 0 or player_index >= valid_viewer_count or result.has(player_index):
			return _checkpoint_rejection("card_annotation_indices_invalid")
		result.append(player_index)
	var sorted := result.duplicate()
	sorted.sort()
	if result != sorted:
		return _checkpoint_rejection("card_annotation_indices_not_canonical")
	return {"accepted": true, "values": result}


func _validated_viewer_key(value: Variant, valid_viewer_count: int) -> Dictionary:
	if not (value is String) or not str(value).is_valid_int():
		return _checkpoint_rejection("card_annotation_viewer_invalid")
	var viewer_index := int(str(value))
	if str(viewer_index) != str(value) or viewer_index < 0 or viewer_index >= valid_viewer_count:
		return _checkpoint_rejection("card_annotation_viewer_invalid")
	return {"accepted": true, "viewer_index": viewer_index}


func _canonical_history_entry_id(value: String) -> bool:
	if value.strip_edges() != value or not value.begins_with("card-history:"):
		return false
	var suffix := value.trim_prefix("card-history:")
	return suffix.is_valid_int() and int(suffix) >= 0 and str(int(suffix)) == suffix


func _has_exact_keys(dictionary: Dictionary, fields: Array) -> bool:
	if dictionary.keys().size() != fields.size():
		return false
	for field_variant in fields:
		if not dictionary.has(str(field_variant)):
			return false
	return true


func _checkpoint_rejection(reason_code: String) -> Dictionary:
	return {"accepted": false, "reason_code": reason_code}


func _duplicate_data(value: Variant) -> Variant:
	if value is Dictionary or value is Array:
		return value.duplicate(true)
	return value


func _valid_patch(patch: Dictionary) -> bool:
	for key_variant in patch.keys():
		if not EDITABLE_FIELDS.has(str(key_variant)):
			return false
	return true


func _strict_tags_valid(tags: Array) -> bool:
	if tags.size() > 8:
		return false
	var seen: Array[String] = []
	for tag_variant in tags:
		if not (tag_variant is String):
			return false
		var tag := str(tag_variant)
		if tag.is_empty() or tag.length() > 32 or tag.strip_edges() != tag or seen.has(tag):
			return false
		seen.append(tag)
	return true


func _strict_indices_valid(indices: Array, valid_player_count: int) -> bool:
	if valid_player_count < 0:
		return false
	var normalized: Array[int] = []
	for index_variant in indices:
		if not (index_variant is int):
			return false
		var player_index := int(index_variant)
		if player_index < 0 or player_index >= valid_player_count or normalized.has(player_index):
			return false
		normalized.append(player_index)
	var sorted := normalized.duplicate()
	sorted.sort()
	return normalized == sorted


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
