@tool
extends RefCounted
class_name CardBatchDefenseStatusV1

const PURE = preload("res://scripts/semantic/card_batch_pure_data.gd")

const SCHEMA_VERSION := 1
const VISIBILITY_POLICIES := ["public", "owner_private"]
const FIELDS: Array[String] = [
	"schema_version", "defense_status_id", "source_card_instance_id",
	"owner_player_id", "protected_target_ids", "defense_kind", "effect_filter",
	"reduction_amount", "prevention_count", "active_from_revision",
	"expires_at_batch_id", "expires_at_world_time_usec", "remaining_uses",
	"visibility_policy", "trigger_refund_amount", "private_trace_count",
]


static func build(
	defense_status_id: String,
	source_card_instance_id: String,
	owner_player_id: String,
	protected_target_ids: Array,
	defense_kind: String,
	effect_filter: String,
	reduction_amount: int,
	prevention_count: int,
	active_from_revision: int,
	expires_at_batch_id: String,
	expires_at_world_time_usec: int,
	remaining_uses: int,
	visibility_policy: String,
	trigger_refund_amount: int = 0,
	private_trace_count: int = 0
) -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"defense_status_id": defense_status_id.strip_edges(),
		"source_card_instance_id": source_card_instance_id.strip_edges(),
		"owner_player_id": owner_player_id.strip_edges(),
		"protected_target_ids": PURE.string_array(protected_target_ids, true),
		"defense_kind": defense_kind.strip_edges(),
		"effect_filter": effect_filter.strip_edges(),
		"reduction_amount": reduction_amount,
		"prevention_count": prevention_count,
		"active_from_revision": active_from_revision,
		"expires_at_batch_id": expires_at_batch_id.strip_edges(),
		"expires_at_world_time_usec": expires_at_world_time_usec,
		"remaining_uses": remaining_uses,
		"visibility_policy": visibility_policy.strip_edges(),
		"trigger_refund_amount": trigger_refund_amount,
		"private_trace_count": private_trace_count,
	}


static func validate(value: Dictionary) -> Dictionary:
	if not PURE.has_exact_keys(value, FIELDS) or int(value.get("schema_version", -1)) != SCHEMA_VERSION:
		return _rejected("defense_status_schema_invalid")
	if not PURE.is_pure_json_data(value) or not PURE.first_forbidden_runtime_key(value).is_empty():
		return _rejected("defense_status_not_pure_data")
	for field in ["defense_status_id", "source_card_instance_id", "owner_player_id", "defense_kind", "effect_filter", "visibility_policy"]:
		if str(value.get(field, "")).is_empty():
			return _rejected("defense_status_%s_missing" % field)
	var targets_variant: Variant = value.get("protected_target_ids")
	if not (targets_variant is Array) or PURE.string_array(targets_variant, true).size() != (targets_variant as Array).size():
		return _rejected("defense_status_targets_invalid")
	if int(value.get("reduction_amount", -1)) < 0 or int(value.get("prevention_count", -1)) < 0:
		return _rejected("defense_status_effect_invalid")
	if int(value.get("trigger_refund_amount", -1)) < 0 or int(value.get("private_trace_count", -1)) < 0:
		return _rejected("defense_status_trigger_benefit_invalid")
	if int(value.get("active_from_revision", -1)) < 0 or int(value.get("expires_at_world_time_usec", -1)) < 0 or int(value.get("remaining_uses", -1)) < 0:
		return _rejected("defense_status_lifecycle_invalid")
	if str(value.get("visibility_policy", "")) not in VISIBILITY_POLICIES:
		return _rejected("defense_status_visibility_invalid")
	return {"valid": true, "reason_code": "defense_status_valid", "normalized": value.duplicate(true)}


static func stable_order_key(value: Dictionary) -> String:
	return "%012d|%s|%s" % [
		int(value.get("active_from_revision", 0)),
		str(value.get("source_card_instance_id", "")),
		str(value.get("defense_status_id", "")),
	]


static func fingerprint(value: Dictionary) -> String:
	return PURE.stable_fingerprint(value) if bool(validate(value).get("valid", false)) else ""


static func _rejected(reason_code: String) -> Dictionary:
	return {"valid": false, "reason_code": reason_code, "normalized": {}}
