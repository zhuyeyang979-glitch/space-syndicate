@tool
extends Node
class_name CommodityBeltVisibilitySaveOwner

const SCHEMA_VERSION := 1
const RULESET_ID := "v0.6"
const ROOT_FIELDS := [
	"schema_version",
	"ruleset_id",
	"belt_revision",
	"belt_item_ids",
	"visibility_acl_fingerprint",
]

@export var commodity_card_inventory_path: NodePath
@export var commodity_sushi_track_path: NodePath

var _commodity_override: Node
var _projection_override: Node
var _apply_count := 0
var _attestation_failure_count := 0
var _last_reason_code := "idle"


func configure_dependencies(commodity_card_inventory: Node, projection_service: Node = null) -> Dictionary:
	_commodity_override = commodity_card_inventory
	_projection_override = projection_service
	return {
		"configured": _commodity_node() != null and _commodity_node().has_method("belt_snapshot"),
		"reason_code": "commodity_belt_visibility_owner_ready" \
				if _commodity_node() != null and _commodity_node().has_method("belt_snapshot") \
				else "commodity_belt_visibility_dependency_missing",
	}


func to_save_data() -> Dictionary:
	var capture := _capture_live_attestation()
	return (capture.get("state", {}) as Dictionary).duplicate(true) \
			if bool(capture.get("captured", false)) else {}


func preflight_save_data(data: Dictionary) -> Dictionary:
	if not _has_exact_keys(data, ROOT_FIELDS) or not _is_finite_pure_data(data) \
			or not (data.get("schema_version") is int) or int(data.get("schema_version", 0)) != SCHEMA_VERSION \
			or not (data.get("ruleset_id") is String) or str(data.get("ruleset_id", "")) != RULESET_ID \
			or not (data.get("belt_revision") is int) or int(data.get("belt_revision", -1)) < 0 \
			or not (data.get("belt_item_ids") is Array) \
			or not (data.get("visibility_acl_fingerprint") is String):
		return _preflight_rejection("commodity_belt_visibility_save_invalid")
	var item_ids_result := _canonical_item_ids(data.get("belt_item_ids", []))
	if not bool(item_ids_result.get("valid", false)):
		return _preflight_rejection("commodity_belt_visibility_item_ids_invalid")
	var item_ids := item_ids_result.get("values", []) as Array
	if item_ids != (data.get("belt_item_ids", []) as Array):
		return _preflight_rejection("commodity_belt_visibility_item_ids_not_canonical")
	var fingerprint := str(data.get("visibility_acl_fingerprint", ""))
	if not _is_sha256_hex(fingerprint):
		return _preflight_rejection("commodity_belt_visibility_fingerprint_invalid")
	return {
		"accepted": true,
		"reason_code": "commodity_belt_visibility_save_valid",
		"normalized_state": {
			"schema_version": SCHEMA_VERSION,
			"ruleset_id": RULESET_ID,
			"belt_revision": int(data.get("belt_revision", 0)),
			"belt_item_ids": item_ids.duplicate(),
			"visibility_acl_fingerprint": fingerprint,
		},
	}


func preflight_restore_dependencies(
	section_state: Dictionary,
	all_normalized_states: Dictionary
) -> Dictionary:
	var own_preflight := preflight_save_data(section_state)
	if not bool(own_preflight.get("accepted", false)):
		return own_preflight
	var card_inventory_variant: Variant = all_normalized_states.get("card_inventory", {})
	if not (card_inventory_variant is Dictionary):
		return _dependency_rejection("commodity_belt_visibility_card_inventory_missing")
	var card_inventory := card_inventory_variant as Dictionary
	var commodity_variant: Variant = card_inventory.get("commodity_card_inventory", {})
	if not (commodity_variant is Dictionary):
		return _dependency_rejection("commodity_belt_visibility_card_inventory_invalid")
	var belt_variant: Variant = (commodity_variant as Dictionary).get("belt", {})
	if not (belt_variant is Dictionary):
		return _dependency_rejection("commodity_belt_visibility_belt_missing")
	var dependency_attestation := _attestation_from_belt(belt_variant as Dictionary)
	if not bool(dependency_attestation.get("accepted", false)):
		return _dependency_rejection(str(dependency_attestation.get("reason_code", "commodity_belt_visibility_belt_invalid")))
	var normalized := own_preflight.get("normalized_state", {}) as Dictionary
	if (dependency_attestation.get("state", {}) as Dictionary) != normalized:
		return _dependency_rejection("commodity_belt_visibility_card_inventory_mismatch")
	return {
		"accepted": true,
		"reason_code": "commodity_belt_visibility_dependencies_valid",
		"normalized_state": normalized.duplicate(true),
	}


func apply_save_data(data: Dictionary) -> Dictionary:
	var preflight := preflight_save_data(data)
	if not bool(preflight.get("accepted", false)):
		_last_reason_code = str(preflight.get("reason_code", "commodity_belt_visibility_save_invalid"))
		_attestation_failure_count += 1
		return {"applied": false, "reason_code": _last_reason_code, "mutated": false, "rollback_attempted": false, "rollback_complete": true}
	var live := _capture_live_attestation()
	if not bool(live.get("captured", false)):
		_last_reason_code = str(live.get("reason_code", "commodity_belt_visibility_dependency_missing"))
		_attestation_failure_count += 1
		return {"applied": false, "reason_code": _last_reason_code, "mutated": false, "rollback_attempted": false, "rollback_complete": true}
	var expected := preflight.get("normalized_state", {}) as Dictionary
	var actual := live.get("state", {}) as Dictionary
	if actual != expected:
		_last_reason_code = "commodity_belt_visibility_attestation_mismatch"
		_attestation_failure_count += 1
		return {
			"applied": false,
			"reason_code": _last_reason_code,
			"mutated": false,
			"rollback_attempted": false,
			"rollback_complete": true,
			"expected_belt_revision": int(expected.get("belt_revision", -1)),
			"actual_belt_revision": int(actual.get("belt_revision", -1)),
		}
	_apply_count += 1
	_last_reason_code = "commodity_belt_visibility_attested"
	return {
		"applied": true,
		"reason_code": _last_reason_code,
		"mutated": false,
		"apply_count": _apply_count,
		"rollback_attempted": false,
		"rollback_complete": true,
	}


func capture_runtime_checkpoint() -> Dictionary:
	return to_save_data()


func restore_runtime_checkpoint(checkpoint: Dictionary) -> Dictionary:
	var preflight := preflight_save_data(checkpoint)
	return {
		"restored": bool(preflight.get("accepted", false)),
		"applied": bool(preflight.get("accepted", false)),
		"reason_code": "commodity_belt_visibility_immutable_checkpoint_valid" \
				if bool(preflight.get("accepted", false)) \
				else str(preflight.get("reason_code", "commodity_belt_visibility_checkpoint_invalid")),
		"mutated": false,
	}


func post_restore_rebind() -> Dictionary:
	var projection := _projection_node()
	if projection != null and projection.has_method("reset_projection_state"):
		projection.call("reset_projection_state")
		return {"rebound": true, "reason_code": "commodity_belt_visibility_projections_regenerated"}
	return {"rebound": projection == null, "reason_code": "commodity_belt_visibility_projection_service_absent" if projection == null else "commodity_belt_visibility_projection_reset_missing"}


func debug_snapshot() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"runtime_owner": "CommodityBeltVisibilitySaveOwner",
		"section_id": "commodity_belt_visibility",
		"commodity_dependency_ready": _commodity_node() != null and _commodity_node().has_method("belt_snapshot"),
		"apply_count": _apply_count,
		"attestation_failure_count": _attestation_failure_count,
		"last_reason_code": _last_reason_code,
		"immutable_apply": true,
		"owns_belt_items": false,
		"owns_visibility_acl": false,
		"restore_phase": 6,
	}


func _capture_live_attestation() -> Dictionary:
	var commodity := _commodity_node()
	if commodity == null or not commodity.has_method("belt_snapshot"):
		return {"captured": false, "reason_code": "commodity_belt_visibility_dependency_missing", "state": {}}
	var belt_variant: Variant = commodity.call("belt_snapshot")
	if not (belt_variant is Dictionary):
		return {"captured": false, "reason_code": "commodity_belt_visibility_belt_invalid", "state": {}}
	var attestation := _attestation_from_belt(belt_variant as Dictionary)
	if not bool(attestation.get("accepted", false)):
		return {"captured": false, "reason_code": str(attestation.get("reason_code", "commodity_belt_visibility_belt_invalid")), "state": {}}
	return {"captured": true, "reason_code": "commodity_belt_visibility_captured", "state": (attestation.get("state", {}) as Dictionary).duplicate(true)}


func _attestation_from_belt(belt: Dictionary) -> Dictionary:
	if belt.keys().size() != 2 or not belt.has("revision") or not belt.has("items") \
			or not (belt.get("revision") is int) or int(belt.get("revision", -1)) < 0 \
			or not (belt.get("items") is Dictionary):
		return {"accepted": false, "reason_code": "commodity_belt_visibility_belt_invalid"}
	var items := belt.get("items", {}) as Dictionary
	var item_id_values: Array = items.keys()
	var item_ids_result := _canonical_item_ids(item_id_values)
	if not bool(item_ids_result.get("valid", false)):
		return {"accepted": false, "reason_code": "commodity_belt_visibility_item_ids_invalid"}
	var item_ids := item_ids_result.get("values", []) as Array
	var acl_rows: Array = []
	for item_id_variant in item_ids:
		var item_id := str(item_id_variant)
		var item_variant: Variant = items.get(item_id)
		if not (item_variant is Dictionary) or str((item_variant as Dictionary).get("item_id", "")) != item_id \
				or not ((item_variant as Dictionary).get("visible_actor_ids") is Array):
			return {"accepted": false, "reason_code": "commodity_belt_visibility_item_invalid"}
		var acl_result := _canonical_item_ids((item_variant as Dictionary).get("visible_actor_ids", []))
		if not bool(acl_result.get("valid", false)):
			return {"accepted": false, "reason_code": "commodity_belt_visibility_acl_invalid"}
		acl_rows.append({"item_id": item_id, "visible_actor_ids": (acl_result.get("values", []) as Array).duplicate()})
	var fingerprint := JSON.stringify(acl_rows).sha256_text()
	return {
		"accepted": true,
		"reason_code": "commodity_belt_visibility_belt_valid",
		"state": {
			"schema_version": SCHEMA_VERSION,
			"ruleset_id": RULESET_ID,
			"belt_revision": int(belt.get("revision", 0)),
			"belt_item_ids": item_ids.duplicate(),
			"visibility_acl_fingerprint": fingerprint,
		},
	}


func _canonical_item_ids(value: Variant) -> Dictionary:
	if not (value is Array):
		return {"valid": false, "values": []}
	var seen: Dictionary = {}
	var values: Array[String] = []
	for item_variant in value as Array:
		if not (item_variant is String or item_variant is StringName):
			return {"valid": false, "values": []}
		var item := str(item_variant).strip_edges()
		if item.is_empty() or seen.has(item):
			return {"valid": false, "values": []}
		seen[item] = true
		values.append(item)
	values.sort()
	return {"valid": true, "values": values}


func _is_sha256_hex(value: String) -> bool:
	if value.length() != 64 or value != value.to_lower():
		return false
	for index in range(value.length()):
		if value.substr(index, 1) not in "0123456789abcdef":
			return false
	return true


func _commodity_node() -> Node:
	return _commodity_override if _commodity_override != null else get_node_or_null(commodity_card_inventory_path)


func _projection_node() -> Node:
	return _projection_override if _projection_override != null else get_node_or_null(commodity_sushi_track_path)


func _preflight_rejection(reason_code: String) -> Dictionary:
	return {"accepted": false, "reason_code": reason_code, "failing_child": "commodity_belt_visibility"}


func _dependency_rejection(reason_code: String) -> Dictionary:
	return {"accepted": false, "reason_code": reason_code, "failing_dependency": "card_inventory"}


func _has_exact_keys(dictionary: Dictionary, fields: Array) -> bool:
	if dictionary.size() != fields.size():
		return false
	for field_variant in fields:
		if not dictionary.has(str(field_variant)):
			return false
	return true


func _is_finite_pure_data(value: Variant) -> bool:
	if typeof(value) == TYPE_OBJECT or value is Callable:
		return false
	if value is float and not is_finite(value):
		return false
	if value is Dictionary:
		for key_variant in (value as Dictionary).keys():
			if not (key_variant is String or key_variant is StringName) \
					or not _is_finite_pure_data((value as Dictionary).get(key_variant)):
				return false
	elif value is Array:
		for item_variant in value as Array:
			if not _is_finite_pure_data(item_variant):
				return false
	return true
