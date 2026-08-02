extends RefCounted
class_name CardResolutionExecutionFullStateInspectorV1

const WIRE := preload("res://scripts/semantic/semantic_wire_v1.gd")
const PUBLIC_FIELDS := [
	"schema_version",
	"execution_wire_version",
	"transaction_sequence",
	"completed_resolution_ids",
	"inflight_resolution_ids",
	"inflight_execution_transactions",
	"pending_settlements",
	"transition_controller",
	"transition_state_wire_version",
	"card_group_cadence_version",
	"card_group_cadence",
	"cadence_version",
	"total_seconds",
	"planning_seconds",
	"public_bid_seconds",
	"lock_seconds",
	"card_group_window_phase",
	"card_resolution_timer",
	"card_resolution_counter_timer",
	"card_resolution_simultaneous_timer",
	"card_resolution_auction_timer",
	"card_resolution_auction_open",
	"card_transition_command_schema_version",
	"card_transition_command_revision",
	"card_transition_command_next_order_index",
	"card_transition_applied_lineage",
	"card_transition_last_applied_revision",
	"card_transition_last_applied_order_index",
	"execution_id",
	"resolution_id",
	"status",
	"current_phase",
	"next_intent",
	"completed_intents",
	"history_appended",
	"effect_dispatched",
	"commitment_checked",
	"active_entry",
	"skill",
	"selection_context",
	"finalized",
	"settlement_binding",
	"settlement_binding_fingerprint",
	"started_time",
]


static func inspect(value: Variant) -> Dictionary:
	var state := {
		"leaf_records": [],
		"type_counts": {},
		"non_closed_type_counts": {},
		"non_closed_leaf_count": 0,
		"non_string_key_count": 0,
		"unsafe_integer_count": 0,
		"forbidden_dependency_type_count": 0,
	}
	_walk(value, "$", "root", "not_applicable", state)
	var records := state.get("leaf_records", []) as Array
	records.sort_custom(func(left_variant: Variant, right_variant: Variant) -> bool:
		return str((left_variant as Dictionary).get("json_path", "")) < str((right_variant as Dictionary).get("json_path", ""))
	)
	var first_non_closed := {}
	for record_variant in records:
		var record := record_variant as Dictionary
		if not bool(record.get("closed_data", false)):
			first_non_closed = record.duplicate(true)
			break
	return {
		"schema_version": 1,
		"inspector_id": "card_resolution_execution_full_state_inspector_v1",
		"leaf_count": records.size(),
		"closed_data": WIRE.is_closed_data(value),
		"non_closed_leaf_count": int(state.get("non_closed_leaf_count", 0)),
		"type_counts": (state.get("type_counts", {}) as Dictionary).duplicate(true),
		"non_closed_type_counts": (state.get("non_closed_type_counts", {}) as Dictionary).duplicate(true),
		"first_non_closed_path": str(first_non_closed.get("json_path", "")),
		"first_non_closed_type": str(first_non_closed.get("variant_type", "")),
		"raw_float_count": int((state.get("type_counts", {}) as Dictionary).get("float", 0)),
		"vector2_count": int((state.get("type_counts", {}) as Dictionary).get("Vector2", 0)),
		"color_count": int((state.get("type_counts", {}) as Dictionary).get("Color", 0)),
		"string_name_count": int((state.get("type_counts", {}) as Dictionary).get("StringName", 0)),
		"null_count": int((state.get("type_counts", {}) as Dictionary).get("Nil", 0)),
		"non_string_key_count": int(state.get("non_string_key_count", 0)),
		"unsafe_integer_count": int(state.get("unsafe_integer_count", 0)),
		"object_count": int((state.get("type_counts", {}) as Dictionary).get("Object", 0)),
		"resource_count": int((state.get("type_counts", {}) as Dictionary).get("Resource", 0)),
		"callable_count": int((state.get("type_counts", {}) as Dictionary).get("Callable", 0)),
		"rid_count": int((state.get("type_counts", {}) as Dictionary).get("RID", 0)),
		"forbidden_dependency_type_count": int(state.get("forbidden_dependency_type_count", 0)),
		"leaf_records": records.duplicate(true),
	}


static func _walk(value: Variant, path: String, source_subdomain: String, dictionary_key_type: String, state: Dictionary) -> void:
	if value is Dictionary:
		var dictionary := value as Dictionary
		var keys := dictionary.keys()
		keys.sort_custom(func(left: Variant, right: Variant) -> bool:
			return "%s:%s" % [type_string(typeof(left)), str(left)] < "%s:%s" % [type_string(typeof(right)), str(right)]
		)
		for key_variant in keys:
			var key_type := type_string(typeof(key_variant))
			var child_path := _dictionary_path(path, key_variant)
			var child_subdomain := source_subdomain
			if path == "$" and key_variant is String:
				child_subdomain = str(key_variant)
			if not (key_variant is String):
				state["non_string_key_count"] = int(state.get("non_string_key_count", 0)) + 1
				_record_leaf(key_variant, child_path, child_subdomain, key_type, true, state)
			_walk(dictionary.get(key_variant), child_path, child_subdomain, key_type, state)
		return
	if value is Array:
		var array := value as Array
		for index in range(array.size()):
			_walk(array[index], "%s[%d]" % [path, index], source_subdomain, "ArrayIndex", state)
		return
	_record_leaf(value, path, source_subdomain, dictionary_key_type, false, state)


static func _record_leaf(value: Variant, path: String, source_subdomain: String, dictionary_key_type: String, is_dictionary_key: bool, state: Dictionary) -> void:
	var variant_name := _variant_name(value)
	var type_counts := state.get("type_counts", {}) as Dictionary
	type_counts[variant_name] = int(type_counts.get(variant_name, 0)) + 1
	var closed := value is String if is_dictionary_key else WIRE.is_closed_data(value)
	if not closed:
		state["non_closed_leaf_count"] = int(state.get("non_closed_leaf_count", 0)) + 1
		var non_closed_counts := state.get("non_closed_type_counts", {}) as Dictionary
		non_closed_counts[variant_name] = int(non_closed_counts.get(variant_name, 0)) + 1
	if value is int and not WIRE.is_safe_integer(value):
		state["unsafe_integer_count"] = int(state.get("unsafe_integer_count", 0)) + 1
	if _forbidden_dependency(value):
		state["forbidden_dependency_type_count"] = int(state.get("forbidden_dependency_type_count", 0)) + 1
	var classification := _classification(path, source_subdomain)
	(state.get("leaf_records", []) as Array).append({
		"json_path": path,
		"source_subdomain": source_subdomain,
		"variant_type": variant_name,
		"dictionary_key_type": dictionary_key_type,
		"dictionary_key_leaf": is_dictionary_key,
		"authoritative": bool(classification.get("authoritative", true)),
		"exact_once_required": bool(classification.get("exact_once_required", false)),
		"presentation_only": bool(classification.get("presentation_only", false)),
		"derived_rebuildable": bool(classification.get("derived_rebuildable", false)),
		"finite": _finite(value),
		"safe_integer": WIRE.is_safe_integer(value) if value is int else false,
		"closed_data": closed,
		"reason_code": _reason_code(value, is_dictionary_key, closed),
		"redacted_fingerprint": JSON.stringify({
			"json_path": path,
			"source_subdomain": source_subdomain,
			"variant_type": variant_name,
			"dictionary_key_type": dictionary_key_type,
		}).sha256_text().to_lower(),
	})


static func _classification(path: String, source_subdomain: String) -> Dictionary:
	if path.ends_with(".schema_version") or path.contains("wire_version") or path.contains("cadence_version") \
			or path.contains("command_schema_version"):
		return {"authoritative": false, "exact_once_required": false, "presentation_only": false, "derived_rebuildable": true}
	if path.contains("fingerprint"):
		return {"authoritative": false, "exact_once_required": true, "presentation_only": false, "derived_rebuildable": true}
	if source_subdomain in ["completed_resolution_ids", "inflight_resolution_ids", "inflight_execution_transactions", "pending_settlements"] \
			or path.contains("card_transition_applied_lineage") or path.contains("card_transition_command_"):
		return {"authoritative": true, "exact_once_required": true, "presentation_only": false, "derived_rebuildable": false}
	return {"authoritative": true, "exact_once_required": false, "presentation_only": false, "derived_rebuildable": false}


static func _dictionary_path(parent: String, key_variant: Variant) -> String:
	if not (key_variant is String):
		return "%s.<non_string_key:%s>" % [parent, type_string(typeof(key_variant))]
	var key := str(key_variant)
	if key in PUBLIC_FIELDS:
		return "%s.%s" % [parent, key]
	return "%s.<redacted:%s>" % [parent, ("execution_save_key|%d|%s" % [
		key.length(),
		key.sha256_text().to_lower(),
	]).sha256_text().substr(0, 12)]


static func _variant_name(value: Variant) -> String:
	if value is Resource:
		return "Resource"
	if value is Object:
		return "Object"
	return type_string(typeof(value))


static func _finite(value: Variant) -> bool:
	if value is float:
		return is_finite(float(value))
	if value is Vector2:
		var vector := value as Vector2
		return is_finite(vector.x) and is_finite(vector.y)
	if value is Color:
		var color := value as Color
		return is_finite(color.r) and is_finite(color.g) and is_finite(color.b) and is_finite(color.a)
	return true


static func _forbidden_dependency(value: Variant) -> bool:
	return value is Object or value is Callable or typeof(value) == TYPE_RID


static func _reason_code(value: Variant, is_dictionary_key: bool, closed: bool) -> String:
	if closed:
		return "closed_data_leaf"
	if is_dictionary_key:
		return "dictionary_key_not_string"
	if value == null:
		return "raw_null_not_closed_data"
	if value is int:
		return "unsafe_integer_not_closed_data"
	if value is float:
		return "raw_float_not_closed_data" if is_finite(float(value)) else "nonfinite_float_not_closed_data"
	if value is Vector2:
		return "raw_vector2_not_closed_data"
	if value is Color:
		return "raw_color_not_closed_data"
	if value is StringName:
		return "raw_string_name_not_closed_data"
	if value is Resource:
		return "resource_dependency_rebind_required"
	if value is Object:
		return "object_dependency_rebind_required"
	if value is Callable:
		return "callable_dependency_rebind_required"
	if typeof(value) == TYPE_RID:
		return "rid_dependency_rebind_required"
	return "variant_type_not_closed_data"
