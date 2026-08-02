extends RefCounted
class_name MonsterSaveFullStateInspectorV1

const WIRE := preload("res://scripts/semantic/semantic_wire_v1.gd")
const PUBLIC_FIELDS := [
	"monster_save_schema_version",
	"ruleset_id",
	"auto_monsters",
	"next_auto_monster_uid",
	"next_special_monster_slot",
	"selected_auto_monster_slot",
	"active_monster_wagers",
	"resolved_monster_wager_history",
	"monster_wager_sequence",
	"public_card_bid_monster_wager_pool",
	"monster_wager_settlement_revision",
	"monster_wager_settlement_terminal_journal",
	"monster_battle_lifecycle_schema_version",
	"monster_timer",
	"special_monster_timer",
	"monster_card_atomic_schema_version",
	"monster_card_atomic_owner_revision",
	"monster_card_atomic_starter_state",
	"monster_card_atomic_reservations",
	"monster_card_atomic_terminal_journal",
	"monster_card_atomic_presentation_journal",
	"autonomous_move_sequence",
	"auto_monster_action_sequence",
	"bankruptcy_estate_journal",
	"uid",
	"slot",
	"monster_family_id",
	"duration",
	"remaining_time",
	"move",
	"world_position",
	"linear_move_target_position",
	"linear_move_speed_mps",
	"linear_move_started_at",
	"last_owner_damage_time",
	"revive_timer",
	"terrain_move_multiplier",
	"started_at",
	"decision_remaining_seconds",
	"battle_limit_seconds",
	"battle_remaining_seconds",
	"battle_started_at",
	"resolved_at",
	"upgrade_extend_seconds",
	"preimage",
	"postimage",
	"presentation_event",
	"transaction_id",
	"reservation_fingerprint",
	"snapshot_fingerprint",
	"preimage_fingerprint",
	"postimage_fingerprint",
	"participant_binding_fingerprint",
	"region_fingerprint",
	"profile_fingerprint",
	"rule_fingerprint",
	"binding_capability_fingerprint",
	"battle_roster_fingerprint",
	"commitment_fingerprint",
	"expected_hash",
	"contract_version",
	"lifecycle_schema_version",
	"stage",
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
	var records: Array = state.get("leaf_records", []) as Array
	records.sort_custom(func(left_variant: Variant, right_variant: Variant) -> bool:
		return str((left_variant as Dictionary).get("json_path", "")) < str((right_variant as Dictionary).get("json_path", ""))
	)
	var first_non_closed := {}
	for record_variant: Variant in records:
		var record := record_variant as Dictionary
		if not bool(record.get("closed_data", false)):
			first_non_closed = record.duplicate(true)
			break
	return {
		"schema_version": 1,
		"inspector_id": "monster_save_full_state_inspector_v1",
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


static func _walk(
	value: Variant,
	path: String,
	source_subdomain: String,
	dictionary_key_type: String,
	state: Dictionary
) -> void:
	if value is Dictionary:
		var dictionary := value as Dictionary
		var keys: Array = dictionary.keys()
		keys.sort_custom(func(left: Variant, right: Variant) -> bool:
			var left_type := type_string(typeof(left))
			var right_type := type_string(typeof(right))
			return "%s:%s" % [left_type, str(left)] < "%s:%s" % [right_type, str(right)]
		)
		for key_variant: Variant in keys:
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


static func _record_leaf(
	value: Variant,
	path: String,
	source_subdomain: String,
	dictionary_key_type: String,
	is_dictionary_key: bool,
	state: Dictionary
) -> void:
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
		"variant_type": variant_name,
		"dictionary_key_type": dictionary_key_type,
		"dictionary_key_leaf": is_dictionary_key,
		"authoritative": bool(classification.get("authoritative", true)),
		"presentation_required_for_exact_once": bool(classification.get("presentation_required_for_exact_once", false)),
		"derived_rebuildable": bool(classification.get("derived_rebuildable", false)),
		"state_classification": str(classification.get("state_classification", "authoritative_runtime_state")),
		"dependency_reference": _dependency_reference(path),
		"finite": _finite(value),
		"safe_integer": WIRE.is_safe_integer(value) if value is int else false,
		"closed_data": closed,
		"source_subdomain": source_subdomain,
		"reason_code": _reason_code(value, is_dictionary_key, closed),
		"redacted_fingerprint": JSON.stringify({
			"json_path": path,
			"variant_type": variant_name,
			"dictionary_key_type": dictionary_key_type,
			"source_subdomain": source_subdomain,
		}).sha256_text().to_lower(),
	})


static func _dictionary_path(parent: String, key_variant: Variant) -> String:
	if not (key_variant is String):
		return "%s.<non_string_key:%s>" % [parent, type_string(typeof(key_variant))]
	var key := str(key_variant)
	if key in PUBLIC_FIELDS:
		return "%s.%s" % [parent, key]
	return "%s.<redacted:%s>" % [parent, ("monster_save_key|%d|%s" % [
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


static func _dependency_reference(path: String) -> bool:
	for suffix in ["_id", "_uid", "_revision", "_sequence", "transaction_id", "slot"]:
		if path.ends_with(suffix) or path.contains(".%s" % suffix):
			return true
	return false


static func _classification(path: String, source_subdomain: String) -> Dictionary:
	if source_subdomain in [
		"monster_save_schema_version",
		"ruleset_id",
		"monster_battle_lifecycle_schema_version",
		"monster_card_atomic_schema_version",
	] or path.ends_with(".schema_version") or path.ends_with(".lifecycle_schema_version") \
			or path.ends_with(".contract_version"):
		return {
			"authoritative": false,
			"presentation_required_for_exact_once": false,
			"derived_rebuildable": true,
			"state_classification": "schema_attestation",
		}
	if path.contains("fingerprint") or path.ends_with("expected_hash"):
		return {
			"authoritative": false,
			"presentation_required_for_exact_once": false,
			"derived_rebuildable": true,
			"state_classification": "integrity_attestation",
		}
	if source_subdomain == "monster_card_atomic_presentation_journal" or path.contains(".presentation_event"):
		return {
			"authoritative": true,
			"presentation_required_for_exact_once": true,
			"derived_rebuildable": false,
			"state_classification": "exact_once_presentation_state",
		}
	if source_subdomain in [
		"monster_wager_settlement_terminal_journal",
		"monster_card_atomic_reservations",
		"monster_card_atomic_terminal_journal",
		"bankruptcy_estate_journal",
	]:
		return {
			"authoritative": true,
			"presentation_required_for_exact_once": false,
			"derived_rebuildable": false,
			"state_classification": "exact_once_transaction_state",
		}
	return {
		"authoritative": true,
		"presentation_required_for_exact_once": false,
		"derived_rebuildable": false,
		"state_classification": "authoritative_runtime_state",
	}


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
