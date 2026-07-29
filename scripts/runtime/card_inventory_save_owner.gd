@tool
extends Node
class_name CardInventorySaveOwner

const SCHEMA_VERSION := 2
const RULESET_ID := "v0.6"
const ROOT_FIELDS := [
	"schema_version",
	"ruleset_id",
	"commodity_card_inventory",
	"product_market",
	"district_purchase",
]
const CHILD_IDS := ["commodity_card_inventory", "product_market", "district_purchase"]
const FORBIDDEN_DUPLICATE_FIELDS := [
	"player_slots",
	"slots",
	"player_cash",
	"cash",
	"cash_cents",
	"ai_profile",
	"ai_memory",
	"runtime_instance_id",
	"result_instance_id",
]
const TEST_FAULT_STAGES := [
	"commodity_after",
	"product_market_after",
	"district_purchase_after",
]

@export var commodity_card_inventory_path: NodePath
@export var product_market_path: NodePath
@export var district_purchase_path: NodePath

var _commodity_override: Node
var _product_market_override: Node
var _district_purchase_override: Node
var _test_fault_once := ""
var _apply_count := 0
var _rollback_count := 0
var _last_reason_code := "idle"


func configure_dependencies(
	commodity_card_inventory: Node,
	product_market: Node,
	district_purchase: Node
) -> Dictionary:
	_commodity_override = commodity_card_inventory
	_product_market_override = product_market
	_district_purchase_override = district_purchase
	return {
		"configured": _dependencies_ready(),
		"reason_code": "card_inventory_save_owner_ready" if _dependencies_ready() else "card_inventory_save_owner_dependency_missing",
	}


func to_save_data() -> Dictionary:
	var capture := capture_composite_state()
	return (capture.get("state", {}) as Dictionary).duplicate(true) \
			if bool(capture.get("captured", false)) else {}


func capture_composite_state() -> Dictionary:
	if not _dependencies_ready():
		return _capture_rejection("card_inventory_save_owner_dependency_missing")
	var commodity := _commodity_node()
	if commodity.has_method("checkpoint_status"):
		var status_variant: Variant = commodity.call("checkpoint_status")
		var status: Dictionary = status_variant if status_variant is Dictionary else {}
		if not bool(status.get("can_checkpoint", false)):
			return _capture_rejection(str(status.get("reason_code", "commodity_card_inventory_checkpoint_blocked")))
	var candidate := {
		"schema_version": SCHEMA_VERSION,
		"ruleset_id": RULESET_ID,
		"commodity_card_inventory": _capture_child(_commodity_node()),
		"product_market": _capture_child(_product_market_node()),
		"district_purchase": _capture_child(_district_purchase_node()),
	}
	for child_id in CHILD_IDS:
		if not (candidate.get(child_id) is Dictionary) or (candidate.get(child_id, {}) as Dictionary).is_empty():
			return _capture_rejection("%s_capture_failed" % child_id)
	var preflight := preflight_save_data(candidate)
	if not bool(preflight.get("accepted", false)):
		return _capture_rejection(str(preflight.get("reason_code", "card_inventory_capture_invalid")))
	return {
		"captured": true,
		"reason_code": "card_inventory_composite_captured",
		"state": (preflight.get("normalized_state", {}) as Dictionary).duplicate(true),
	}


func preflight_save_data(data: Dictionary) -> Dictionary:
	if not _dependencies_ready() or not _has_exact_keys(data, ROOT_FIELDS) \
			or not _is_finite_pure_data(data) \
			or not (data.get("schema_version") is int) or int(data.get("schema_version", 0)) != SCHEMA_VERSION \
			or not (data.get("ruleset_id") is String) or str(data.get("ruleset_id", "")) != RULESET_ID:
		return _preflight_rejection("card_inventory_v2_invalid")
	var retired_payload := LegacyContractPayloadGuardV06.validation_report(data)
	if not bool(retired_payload.get("valid", false)):
		return _preflight_rejection("retired_contract_payload_rejected")
	if _contains_forbidden_duplicate(data):
		return _preflight_rejection("card_inventory_world_authority_duplicate_forbidden")
	var normalized_children: Dictionary = {}
	var children := {
		"commodity_card_inventory": _commodity_node(),
		"product_market": _product_market_node(),
		"district_purchase": _district_purchase_node(),
	}
	for child_id_variant in CHILD_IDS:
		var child_id := str(child_id_variant)
		var child: Node = children.get(child_id)
		if not (data.get(child_id) is Dictionary) or child == null or not child.has_method("preflight_save_data"):
			return _preflight_rejection("card_inventory_child_contract_missing", child_id)
		var child_preflight_variant: Variant = child.call(
			"preflight_save_data",
			(data.get(child_id, {}) as Dictionary).duplicate(true)
		)
		var child_preflight: Dictionary = child_preflight_variant if child_preflight_variant is Dictionary else {}
		if not bool(child_preflight.get("accepted", false)):
			return _preflight_rejection(
				str(child_preflight.get("reason_code", "%s_preflight_failed" % child_id)),
				child_id
			)
		normalized_children[child_id] = (child_preflight.get("normalized_state", {}) as Dictionary).duplicate(true)
	var normalized := {"schema_version": SCHEMA_VERSION, "ruleset_id": RULESET_ID}
	for child_id_variant in CHILD_IDS:
		var child_id := str(child_id_variant)
		normalized[child_id] = (normalized_children.get(child_id, {}) as Dictionary).duplicate(true)
	return {
		"accepted": true,
		"reason_code": "card_inventory_v2_valid",
		"normalized_state": normalized,
	}


func preflight_restore_dependencies(
	section_state: Dictionary,
	all_normalized_states: Dictionary
) -> Dictionary:
	var own_preflight := preflight_save_data(section_state)
	if not bool(own_preflight.get("accepted", false)):
		return own_preflight
	var session_variant: Variant = all_normalized_states.get(
		"session",
		all_normalized_states.get("session_foundation", {})
	)
	if not (session_variant is Dictionary):
		return {"accepted": false, "reason_code": "card_inventory_session_foundation_missing", "failing_dependency": "session"}
	var session := session_variant as Dictionary
	var world_variant: Variant = session.get("world_session_state", session)
	if not (world_variant is Dictionary) or not ((world_variant as Dictionary).get("players") is Array):
		return {"accepted": false, "reason_code": "card_inventory_session_roster_missing", "failing_dependency": "session"}
	var player_count := ((world_variant as Dictionary).get("players", []) as Array).size()
	var normalized := own_preflight.get("normalized_state", {}) as Dictionary
	var district_state := normalized.get("district_purchase", {}) as Dictionary
	var district_payload := district_state.get("district_purchase_runtime", {}) as Dictionary
	for session_row_variant in district_payload.get("sessions", []) as Array:
		if not (session_row_variant is Dictionary):
			return {"accepted": false, "reason_code": "card_inventory_district_purchase_invalid", "failing_dependency": "session"}
		var player_index := int((session_row_variant as Dictionary).get("player_index", -1))
		if player_index < 0 or player_index >= player_count:
			return {"accepted": false, "reason_code": "card_inventory_district_player_missing", "failing_dependency": "session"}
	return {
		"accepted": true,
		"reason_code": "card_inventory_restore_dependencies_valid",
		"normalized_state": normalized.duplicate(true),
	}


func apply_save_data(data: Dictionary) -> Dictionary:
	var preflight := preflight_save_data(data)
	if not bool(preflight.get("accepted", false)):
		_last_reason_code = str(preflight.get("reason_code", "card_inventory_preflight_failed"))
		return {
			"applied": false,
			"reason_code": _last_reason_code,
			"failing_child": str(preflight.get("failing_child", "preflight")),
			"rollback_attempted": false,
			"rollback_complete": true,
		}
	var normalized := preflight.get("normalized_state", {}) as Dictionary
	var checkpoint := capture_runtime_checkpoint()
	if not bool(checkpoint.get("captured", false)):
		return {
			"applied": false,
			"reason_code": str(checkpoint.get("reason_code", "card_inventory_checkpoint_capture_failed")),
			"failing_child": "checkpoint",
			"rollback_attempted": false,
			"rollback_complete": true,
		}
	var touched: Array[String] = []
	for child_id_variant in CHILD_IDS:
		var child_id := str(child_id_variant)
		var child := _child_node(child_id)
		touched.append(child_id)
		var apply_variant: Variant = child.call("apply_save_data", normalized.get(child_id, {}) as Dictionary)
		var apply_result: Dictionary = apply_variant if apply_variant is Dictionary else {}
		if not bool(apply_result.get("applied", false)):
			return _apply_failure(child_id, str(apply_result.get("reason_code", apply_result.get("reason", "%s_apply_failed" % child_id))), touched, checkpoint)
		if _capture_child(child) != (normalized.get(child_id, {}) as Dictionary):
			return _apply_failure(child_id, "%s_exact_replace_mismatch" % child_id, touched, checkpoint)
		var fault_stage := "commodity_after" if child_id == "commodity_card_inventory" else "%s_after" % child_id
		if _consume_test_fault(fault_stage):
			return _apply_failure(child_id, "qa_fault_%s_after" % child_id, touched, checkpoint)
	_apply_count += 1
	_last_reason_code = "card_inventory_composite_applied"
	return {
		"applied": true,
		"reason_code": _last_reason_code,
		"apply_count": _apply_count,
		"rollback_attempted": false,
		"rollback_complete": true,
	}


func capture_runtime_checkpoint() -> Dictionary:
	if not _dependencies_ready():
		return {"captured": false, "reason_code": "card_inventory_save_owner_dependency_missing"}
	for child_id_variant in CHILD_IDS:
		var child_id := str(child_id_variant)
		if _capture_child(_child_node(child_id)).is_empty():
			return {"captured": false, "reason_code": "%s_checkpoint_blocked" % child_id}
	var checkpoints: Dictionary = {}
	var checkpoint_modes: Dictionary = {}
	for child_id_variant in CHILD_IDS:
		var child_id := str(child_id_variant)
		var child := _child_node(child_id)
		if child.has_method("capture_runtime_checkpoint") and child.has_method("restore_runtime_checkpoint"):
			var checkpoint_variant: Variant = child.call("capture_runtime_checkpoint")
			if not (checkpoint_variant is Dictionary) or (checkpoint_variant as Dictionary).is_empty():
				return {"captured": false, "reason_code": "%s_checkpoint_capture_failed" % child_id}
			checkpoints[child_id] = (checkpoint_variant as Dictionary).duplicate(true)
			checkpoint_modes[child_id] = "runtime"
		else:
			var save_data := _capture_child(child)
			if save_data.is_empty():
				return {"captured": false, "reason_code": "%s_checkpoint_capture_failed" % child_id}
			checkpoints[child_id] = save_data
			checkpoint_modes[child_id] = "save"
	return {
		"captured": true,
		"schema_version": 1,
		"children": checkpoints,
		"modes": checkpoint_modes,
	}


func restore_runtime_checkpoint(checkpoint: Dictionary) -> Dictionary:
	if not _dependencies_ready() or not bool(checkpoint.get("captured", false)) \
			or int(checkpoint.get("schema_version", 0)) != 1 \
			or not (checkpoint.get("children") is Dictionary) \
			or not (checkpoint.get("modes") is Dictionary):
		return {"restored": false, "applied": false, "reason_code": "card_inventory_runtime_checkpoint_invalid", "failures": []}
	var children := checkpoint.get("children", {}) as Dictionary
	var modes := checkpoint.get("modes", {}) as Dictionary
	var failures: Array[String] = []
	var reversed := CHILD_IDS.duplicate()
	reversed.reverse()
	for child_id_variant in reversed:
		var child_id := str(child_id_variant)
		var child := _child_node(child_id)
		var result_variant: Variant
		if str(modes.get(child_id, "")) == "runtime":
			result_variant = child.call("restore_runtime_checkpoint", children.get(child_id, {}) as Dictionary)
		else:
			result_variant = child.call("apply_save_data", children.get(child_id, {}) as Dictionary)
		var result: Dictionary = result_variant if result_variant is Dictionary else {}
		if not (bool(result.get("applied", false)) or bool(result.get("restored", false))):
			failures.append(child_id)
	_rollback_count += 1
	return {
		"restored": failures.is_empty(),
		"applied": failures.is_empty(),
		"reason_code": "card_inventory_runtime_checkpoint_restored" if failures.is_empty() else "card_inventory_runtime_checkpoint_restore_failed",
		"failures": failures,
	}


func post_restore_rebind() -> Dictionary:
	return {
		"rebound": _dependencies_ready(),
		"reason_code": "card_inventory_post_restore_rebind_ready" if _dependencies_ready() else "card_inventory_save_owner_dependency_missing",
		"bindings": [
			"card_player_state_port",
			"product_market_world_bridge",
			"district_purchase_quote_authority",
			"commodity_track_source",
			"player_card_dock_query",
		],
	}


func arm_test_fault_once(stage: String) -> bool:
	if stage not in TEST_FAULT_STAGES:
		return false
	_test_fault_once = stage
	return true


func clear_test_fault() -> void:
	_test_fault_once = ""


func debug_snapshot() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"runtime_owner": "CardInventorySaveOwner",
		"section_id": "card_inventory",
		"dependencies_ready": _dependencies_ready(),
		"child_owner_count": CHILD_IDS.size(),
		"apply_count": _apply_count,
		"rollback_count": _rollback_count,
		"last_reason_code": _last_reason_code,
		"fault_armed": not _test_fault_once.is_empty(),
		"owns_player_slots": false,
		"owns_player_cash": false,
		"owns_ai_state": false,
		"restore_phase": 5,
	}


func _apply_failure(
	failing_child: String,
	reason_code: String,
	_touched: Array[String],
	checkpoint: Dictionary
) -> Dictionary:
	var rollback := restore_runtime_checkpoint(checkpoint)
	_last_reason_code = reason_code
	return {
		"applied": false,
		"reason_code": reason_code,
		"failing_child": failing_child,
		"rollback_attempted": true,
		"rollback_complete": bool(rollback.get("restored", rollback.get("applied", false))),
		"rollback_failures": (rollback.get("failures", []) as Array).duplicate(),
	}


func _capture_child(child: Node) -> Dictionary:
	if child == null or not child.has_method("to_save_data"):
		return {}
	var value_variant: Variant = child.call("to_save_data")
	return (value_variant as Dictionary).duplicate(true) if value_variant is Dictionary else {}


func _child_node(child_id: String) -> Node:
	match child_id:
		"commodity_card_inventory":
			return _commodity_node()
		"product_market":
			return _product_market_node()
		"district_purchase":
			return _district_purchase_node()
	return null


func _commodity_node() -> Node:
	return _commodity_override if _commodity_override != null else get_node_or_null(commodity_card_inventory_path)


func _product_market_node() -> Node:
	return _product_market_override if _product_market_override != null else get_node_or_null(product_market_path)


func _district_purchase_node() -> Node:
	return _district_purchase_override if _district_purchase_override != null else get_node_or_null(district_purchase_path)


func _dependencies_ready() -> bool:
	for child in [_commodity_node(), _product_market_node(), _district_purchase_node()]:
		if child == null:
			return false
		for method_name in ["to_save_data", "preflight_save_data", "apply_save_data"]:
			if not child.has_method(method_name):
				return false
	return true


func _consume_test_fault(stage: String) -> bool:
	if _test_fault_once != stage:
		return false
	_test_fault_once = ""
	return true


func _capture_rejection(reason_code: String) -> Dictionary:
	_last_reason_code = reason_code
	return {"captured": false, "reason_code": reason_code, "state": {}}


func _preflight_rejection(reason_code: String, failing_child: String = "card_inventory") -> Dictionary:
	return {"accepted": false, "reason_code": reason_code, "failing_child": failing_child}


func _has_exact_keys(dictionary: Dictionary, fields: Array) -> bool:
	if dictionary.size() != fields.size():
		return false
	for field_variant in fields:
		if not dictionary.has(str(field_variant)):
			return false
	return true


func _contains_forbidden_duplicate(value: Variant) -> bool:
	if value is Dictionary:
		for key_variant in (value as Dictionary).keys():
			var key := str(key_variant)
			if key in FORBIDDEN_DUPLICATE_FIELDS \
					or _contains_forbidden_duplicate((value as Dictionary).get(key_variant)):
				return true
	elif value is Array:
		for item_variant in value as Array:
			if _contains_forbidden_duplicate(item_variant):
				return true
	return false


func _is_finite_pure_data(value: Variant) -> bool:
	if typeof(value) == TYPE_OBJECT or value is Callable:
		return false
	if value is float and not is_finite(value):
		return false
	if value is Vector2:
		var vector := value as Vector2
		if not is_finite(vector.x) or not is_finite(vector.y):
			return false
	if value is Color:
		var color := value as Color
		if not is_finite(color.r) or not is_finite(color.g) or not is_finite(color.b) or not is_finite(color.a):
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
