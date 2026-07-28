@tool
extends RefCounted
class_name CardBatchPreboundTargetSpecV1

const PURE = preload("res://scripts/semantic/card_batch_pure_data.gd")

const SCHEMA_VERSION := 1
const INVALIDATION_POLICIES := [
	"FIZZLE_NO_EFFECT", "COMMIT_LEGAL_REMAINDER",
	"REFUND_BY_AUTHORED_RULE", "DETERMINISTIC_FALLBACK",
]
const DEFAULT_INVALIDATION_POLICY := "FIZZLE_NO_EFFECT"
const FIELDS: Array[String] = [
	"schema_version", "target_kind", "target_ids", "target_revision",
	"placement_slot_id", "mode_id", "quantity", "authored_parameters",
	"target_invalidation_policy",
]


static func build(
	target_kind: String,
	target_ids: Array,
	target_revision: int,
	placement_slot_id: String = "",
	mode_id: String = "default",
	quantity: int = 1,
	authored_parameters: Dictionary = {},
	target_invalidation_policy: String = DEFAULT_INVALIDATION_POLICY
) -> Dictionary:
	var normalized_ids := PURE.string_array(target_ids, true)
	return {
		"schema_version": SCHEMA_VERSION,
		"target_kind": target_kind.strip_edges(),
		"target_ids": normalized_ids,
		"target_revision": target_revision,
		"placement_slot_id": placement_slot_id.strip_edges(),
		"mode_id": mode_id.strip_edges(),
		"quantity": quantity,
		"authored_parameters": authored_parameters.duplicate(true),
		"target_invalidation_policy": target_invalidation_policy.strip_edges(),
	}


static func validate(value: Dictionary) -> Dictionary:
	if not PURE.has_exact_keys(value, FIELDS) or int(value.get("schema_version", -1)) != SCHEMA_VERSION:
		return _rejected("target_binding_schema_invalid")
	if not PURE.is_pure_json_data(value) or not PURE.first_forbidden_runtime_key(value).is_empty():
		return _rejected("target_binding_not_pure_data")
	if not PURE.first_retired_counter_key(value).is_empty():
		return _rejected("target_binding_retired_counter_payload")
	var target_kind := str(value.get("target_kind", ""))
	var target_ids_variant: Variant = value.get("target_ids")
	if target_kind.is_empty() or not (target_ids_variant is Array):
		return _rejected("target_binding_kind_or_ids_invalid")
	var target_ids := PURE.string_array(target_ids_variant, true)
	if target_ids.size() != (target_ids_variant as Array).size():
		return _rejected("target_binding_ids_invalid")
	if target_kind == "none" and not target_ids.is_empty():
		return _rejected("target_binding_none_has_targets")
	if target_kind != "none" and target_ids.is_empty():
		return _rejected("target_binding_targets_required")
	if int(value.get("target_revision", -1)) < 0:
		return _rejected("target_binding_revision_invalid")
	if str(value.get("mode_id", "")).is_empty() or int(value.get("quantity", 0)) <= 0:
		return _rejected("target_binding_mode_or_quantity_invalid")
	if not (value.get("authored_parameters") is Dictionary):
		return _rejected("target_binding_parameters_invalid")
	if str(value.get("target_invalidation_policy", "")) not in INVALIDATION_POLICIES:
		return _rejected("target_binding_invalidation_policy_invalid")
	return {"valid": true, "reason_code": "target_binding_valid", "normalized": value.duplicate(true)}


static func fingerprint(value: Dictionary) -> String:
	return PURE.stable_fingerprint(value) if bool(validate(value).get("valid", false)) else ""


static func _rejected(reason_code: String) -> Dictionary:
	return {"valid": false, "reason_code": reason_code, "normalized": {}}
