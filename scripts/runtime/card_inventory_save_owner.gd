@tool
extends Node
class_name CardInventorySaveOwner

const SCHEMA_VERSION := 4
const RULESET_ID := "v0.6"
const RUNTIME_CHECKPOINT_VERSION := 2
const RUNTIME_CHECKPOINT_ID := "card_inventory_runtime_checkpoint_v2"
const SECTION_ID := "card_inventory"
const CHECKPOINT_MODE := "closed_runtime_checkpoint"
const SEMANTIC_WIRE := preload("res://scripts/semantic/semantic_wire_v1.gd")
const ROOT_FIELDS := [
	"schema_version",
	"ruleset_id",
	"commodity_card_inventory",
	"product_market",
	"district_purchase",
]
const CHILD_IDS := ["commodity_card_inventory", "product_market", "district_purchase"]
const CHILD_CHECKPOINT_VERSIONS := {
	"commodity_card_inventory": 2,
	"product_market": 2,
	"district_purchase": 2,
}
const RUNTIME_CHECKPOINT_FIELDS := [
	"captured",
	"schema_version",
	"checkpoint_id",
	"section_id",
	"ruleset_id",
	"children",
	"owner_counters",
	"checkpoint_fingerprint",
]
const CHILD_CHECKPOINT_FIELDS := [
	"child_id",
	"checkpoint_mode",
	"checkpoint_schema_version",
	"state",
	"state_fingerprint",
]
const OWNER_COUNTER_FIELDS := ["apply_count", "rollback_count", "last_reason_code"]
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
	if _has_exact_keys(data, ROOT_FIELDS) \
			and data.get("schema_version") is int \
			and int(data.get("schema_version", 0)) == 2:
		return _preflight_rejection("allocator_cursor_missing_requires_backup", "district_purchase")
	if _has_exact_keys(data, ROOT_FIELDS) \
			and data.get("schema_version") is int \
			and int(data.get("schema_version", 0)) == 3:
		return _preflight_rejection("card_inventory_v3_closed_wire_upgrade_requires_backup")
	if not _dependencies_ready() or not _has_exact_keys(data, ROOT_FIELDS) \
			or not SEMANTIC_WIRE.is_closed_data(data) \
			or not (data.get("schema_version") is int) or int(data.get("schema_version", 0)) != SCHEMA_VERSION \
			or not (data.get("ruleset_id") is String) or str(data.get("ruleset_id", "")) != RULESET_ID:
		return _preflight_rejection("card_inventory_v4_invalid")
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
		if not SEMANTIC_WIRE.is_closed_data(normalized_children.get(child_id)):
			return _preflight_rejection("card_inventory_v4_invalid", child_id)
	var maximum_quote_sequence := _maximum_market_quote_sequence(normalized_children)
	var district_state: Dictionary = normalized_children.get("district_purchase", {}) \
			if normalized_children.get("district_purchase", {}) is Dictionary else {}
	var district_payload: Dictionary = district_state.get("district_purchase_runtime", {}) \
			if district_state.get("district_purchase_runtime", {}) is Dictionary else {}
	if not (district_payload.get("next_quote_sequence") is int) \
			or int(district_payload.get("next_quote_sequence", 0)) <= maximum_quote_sequence:
		return _preflight_rejection("allocator_cursor_regressed", "district_purchase")
	var normalized := {"schema_version": SCHEMA_VERSION, "ruleset_id": RULESET_ID}
	for child_id_variant in CHILD_IDS:
		var child_id := str(child_id_variant)
		normalized[child_id] = (normalized_children.get(child_id, {}) as Dictionary).duplicate(true)
	return {
		"accepted": true,
		"reason_code": "card_inventory_v4_valid",
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
	var region_supply: Dictionary = all_normalized_states.get("region_supply", {}) \
			if all_normalized_states.get("region_supply", {}) is Dictionary else {}
	var district_state := normalized.get("district_purchase", {}) as Dictionary
	var district_payload := district_state.get("district_purchase_runtime", {}) as Dictionary
	var next_quote_sequence := int(district_payload.get("next_quote_sequence", 0))
	var maximum_saved_quote_sequence := maxi(
		_maximum_market_quote_sequence(normalized),
		_maximum_market_quote_sequence(region_supply)
	)
	if next_quote_sequence <= maximum_saved_quote_sequence:
		return {
			"accepted": false,
			"reason_code": "allocator_cursor_regressed",
			"failing_dependency": "region_supply" if _maximum_market_quote_sequence(region_supply) >= next_quote_sequence else "card_inventory",
		}
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
		var reason_code := str(preflight.get("reason_code", "card_inventory_preflight_failed"))
		return {
			"applied": false,
			"reason_code": reason_code,
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
	var children: Dictionary = {}
	for child_id_variant in CHILD_IDS:
		var child_id := str(child_id_variant)
		var child := _child_node(child_id)
		if child == null or not child.has_method("capture_runtime_checkpoint") \
				or not child.has_method("restore_runtime_checkpoint"):
			return {"captured": false, "reason_code": "%s_checkpoint_contract_missing" % child_id}
		var checkpoint_variant: Variant = child.call("capture_runtime_checkpoint")
		if not (checkpoint_variant is Dictionary):
			return {"captured": false, "reason_code": "%s_checkpoint_capture_failed" % child_id}
		var child_state := checkpoint_variant as Dictionary
		var expected_version := int(CHILD_CHECKPOINT_VERSIONS.get(child_id, 0))
		if child_state.is_empty() or not SEMANTIC_WIRE.is_closed_data(child_state) \
				or not (child_state.get("schema_version") is int) \
				or int(child_state.get("schema_version", 0)) != expected_version:
			return {"captured": false, "reason_code": "%s_checkpoint_capture_failed" % child_id}
		var child_fingerprint := SEMANTIC_WIRE.fingerprint(child_state)
		if child_fingerprint.is_empty():
			return {"captured": false, "reason_code": "%s_checkpoint_fingerprint_failed" % child_id}
		children[child_id] = {
			"child_id": child_id,
			"checkpoint_mode": CHECKPOINT_MODE,
			"checkpoint_schema_version": expected_version,
			"state": child_state.duplicate(true),
			"state_fingerprint": child_fingerprint,
		}
	var unsealed := {
		"captured": true,
		"schema_version": RUNTIME_CHECKPOINT_VERSION,
		"checkpoint_id": RUNTIME_CHECKPOINT_ID,
		"section_id": SECTION_ID,
		"ruleset_id": RULESET_ID,
		"children": children,
		"owner_counters": _owner_counters_snapshot(),
	}
	var sealed := SEMANTIC_WIRE.sealed_copy(unsealed, "checkpoint_fingerprint")
	return sealed if not sealed.is_empty() else {"captured": false, "reason_code": "card_inventory_checkpoint_v2_seal_failed"}


func restore_runtime_checkpoint(checkpoint: Dictionary) -> Dictionary:
	var preflight := preflight_runtime_checkpoint(checkpoint)
	if not bool(preflight.get("accepted", false)):
		return {"restored": false, "applied": false, "reason_code": "card_inventory_checkpoint_v2_invalid", "failures": []}
	var backup := capture_runtime_checkpoint()
	if not bool(backup.get("captured", false)):
		return {"restored": false, "applied": false, "reason_code": "card_inventory_checkpoint_backup_failed", "failures": []}
	var normalized := preflight.get("normalized_state", {}) as Dictionary
	var applied := _restore_preflighted_checkpoint(normalized)
	if bool(applied.get("restored", false)):
		return applied
	var backup_preflight := preflight_runtime_checkpoint(backup)
	var rollback := _restore_preflighted_checkpoint(
		backup_preflight.get("normalized_state", {}) as Dictionary
	) if bool(backup_preflight.get("accepted", false)) else {"restored": false, "failures": ["backup_preflight"]}
	applied["rollback_attempted"] = true
	applied["rollback_complete"] = bool(rollback.get("restored", false))
	return applied


func preflight_runtime_checkpoint(checkpoint: Dictionary) -> Dictionary:
	if not _dependencies_ready() or not _has_exact_keys(checkpoint, RUNTIME_CHECKPOINT_FIELDS) \
			or not SEMANTIC_WIRE.is_closed_data(checkpoint) \
			or not (checkpoint.get("captured") is bool) or not bool(checkpoint.get("captured", false)) \
			or not (checkpoint.get("schema_version") is int) \
			or int(checkpoint.get("schema_version", 0)) != RUNTIME_CHECKPOINT_VERSION \
			or not (checkpoint.get("checkpoint_id") is String) \
			or str(checkpoint.get("checkpoint_id", "")) != RUNTIME_CHECKPOINT_ID \
			or not (checkpoint.get("section_id") is String) \
			or str(checkpoint.get("section_id", "")) != SECTION_ID \
			or not (checkpoint.get("ruleset_id") is String) \
			or str(checkpoint.get("ruleset_id", "")) != RULESET_ID \
			or not (checkpoint.get("checkpoint_fingerprint") is String) \
			or str(checkpoint.get("checkpoint_fingerprint", "")) != SEMANTIC_WIRE.fingerprint(checkpoint, "checkpoint_fingerprint") \
			or not (checkpoint.get("children") is Dictionary) \
			or not (checkpoint.get("owner_counters") is Dictionary):
		return _checkpoint_preflight_rejection("card_inventory_checkpoint_v2_invalid")
	var children := checkpoint.get("children", {}) as Dictionary
	if not _has_exact_keys(children, CHILD_IDS):
		return _checkpoint_preflight_rejection("card_inventory_checkpoint_v2_invalid")
	var normalized_children: Dictionary = {}
	for child_id_variant in CHILD_IDS:
		var child_id := str(child_id_variant)
		if not (children.get(child_id) is Dictionary):
			return _checkpoint_preflight_rejection("card_inventory_checkpoint_v2_invalid", child_id)
		var wrapper := children.get(child_id, {}) as Dictionary
		var expected_version := int(CHILD_CHECKPOINT_VERSIONS.get(child_id, 0))
		if not _has_exact_keys(wrapper, CHILD_CHECKPOINT_FIELDS) \
				or not (wrapper.get("child_id") is String) or str(wrapper.get("child_id", "")) != child_id \
				or not (wrapper.get("checkpoint_mode") is String) \
				or str(wrapper.get("checkpoint_mode", "")) != CHECKPOINT_MODE \
				or not (wrapper.get("checkpoint_schema_version") is int) \
				or int(wrapper.get("checkpoint_schema_version", 0)) != expected_version \
				or not (wrapper.get("state") is Dictionary) \
				or not SEMANTIC_WIRE.is_closed_data(wrapper.get("state")) \
				or not (wrapper.get("state_fingerprint") is String) \
				or str(wrapper.get("state_fingerprint", "")) != SEMANTIC_WIRE.fingerprint(wrapper.get("state")):
			return _checkpoint_preflight_rejection("card_inventory_checkpoint_v2_invalid", child_id)
		var child := _child_node(child_id)
		if child == null or not child.has_method("preflight_runtime_checkpoint"):
			return _checkpoint_preflight_rejection("card_inventory_child_checkpoint_preflight_missing", child_id)
		var child_preflight_variant: Variant = child.call(
			"preflight_runtime_checkpoint",
			(wrapper.get("state", {}) as Dictionary).duplicate(true)
		)
		var child_preflight: Dictionary = child_preflight_variant if child_preflight_variant is Dictionary else {}
		if not bool(child_preflight.get("accepted", false)):
			return _checkpoint_preflight_rejection(
				str(child_preflight.get("reason_code", "card_inventory_checkpoint_v2_invalid")),
				child_id
			)
		normalized_children[child_id] = wrapper.duplicate(true)
	var counters := checkpoint.get("owner_counters", {}) as Dictionary
	if not _owner_counters_valid(counters):
		return _checkpoint_preflight_rejection("card_inventory_checkpoint_v2_invalid")
	return {
		"accepted": true,
		"reason_code": "card_inventory_checkpoint_v2_valid",
		"normalized_state": {
			"children": normalized_children,
			"owner_counters": counters.duplicate(true),
		},
	}


func _restore_preflighted_checkpoint(normalized: Dictionary) -> Dictionary:
	var children := normalized.get("children", {}) as Dictionary
	var failures: Array[String] = []
	var reversed := CHILD_IDS.duplicate()
	reversed.reverse()
	for child_id_variant in reversed:
		var child_id := str(child_id_variant)
		var wrapper := children.get(child_id, {}) as Dictionary
		var child := _child_node(child_id)
		var result_variant: Variant = child.call(
			"restore_runtime_checkpoint",
			wrapper.get("state", {}) as Dictionary
		)
		var result: Dictionary = result_variant if result_variant is Dictionary else {}
		if not (bool(result.get("applied", false)) or bool(result.get("restored", false))):
			failures.append(child_id)
			break
	if failures.is_empty():
		_restore_owner_counters(normalized.get("owner_counters", {}) as Dictionary)
	return {
		"restored": failures.is_empty(),
		"applied": failures.is_empty(),
		"reason_code": "card_inventory_checkpoint_v2_restored" if failures.is_empty() else "card_inventory_checkpoint_v2_restore_failed",
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
	return {
		"accepted": false,
		"reason_code": reason_code,
		"failing_child": failing_child,
		"requires_backup": reason_code in [
			"allocator_cursor_missing_requires_backup",
			"card_inventory_v3_closed_wire_upgrade_requires_backup",
		],
	}


func _checkpoint_preflight_rejection(reason_code: String, failing_child: String = "card_inventory") -> Dictionary:
	return {
		"accepted": false,
		"reason_code": reason_code,
		"failing_child": failing_child,
	}


func _owner_counters_snapshot() -> Dictionary:
	return {
		"apply_count": _apply_count,
		"rollback_count": _rollback_count,
		"last_reason_code": _last_reason_code,
	}


func _owner_counters_valid(counters: Dictionary) -> bool:
	return _has_exact_keys(counters, OWNER_COUNTER_FIELDS) \
			and counters.get("apply_count") is int \
			and SEMANTIC_WIRE.is_nonnegative_integer(counters.get("apply_count")) \
			and counters.get("rollback_count") is int \
			and SEMANTIC_WIRE.is_nonnegative_integer(counters.get("rollback_count")) \
			and counters.get("last_reason_code") is String


func _restore_owner_counters(counters: Dictionary) -> void:
	_apply_count = int(counters.get("apply_count", 0))
	_rollback_count = int(counters.get("rollback_count", 0))
	_last_reason_code = str(counters.get("last_reason_code", "idle"))


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


func _maximum_market_quote_sequence(value: Variant) -> int:
	var maximum := 0
	if value is Dictionary:
		for key_variant in (value as Dictionary).keys():
			maximum = maxi(maximum, _market_quote_sequence_from_identity(str(key_variant)))
			var child_variant: Variant = (value as Dictionary).get(key_variant)
			maximum = maxi(maximum, _maximum_market_quote_sequence(child_variant))
	elif value is Array:
		for child_variant in value as Array:
			maximum = maxi(maximum, _maximum_market_quote_sequence(child_variant))
	elif value is String:
		maximum = maxi(maximum, _market_quote_sequence_from_identity(str(value)))
	return maximum


func _market_quote_sequence_from_identity(value: String) -> int:
	var prefix_index := value.find("market-quote-")
	if prefix_index < 0:
		return 0
	var quote_identity := value.substr(prefix_index)
	var transaction_suffix := quote_identity.find(":")
	if transaction_suffix >= 0:
		quote_identity = quote_identity.left(transaction_suffix)
	var final_separator := quote_identity.rfind("-")
	if final_separator < 0 or final_separator + 1 >= quote_identity.length():
		return 0
	var sequence_text := quote_identity.substr(final_separator + 1)
	if not sequence_text.is_valid_int():
		return 0
	return maxi(0, int(sequence_text))


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
