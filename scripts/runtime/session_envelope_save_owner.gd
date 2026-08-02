@tool
extends Node
class_name SessionEnvelopeSaveOwner

const SCHEMA_VERSION := 3
const ROOT_FIELDS := [
	"schema_version",
	"game_session_runtime",
	"world_session_state",
	"run_rng_state",
	"card_history_private_annotations",
]
const TEST_FAULT_STAGES := [
	"world_before",
	"world_after",
	"annotation_before",
	"annotation_after",
	"session_before",
	"session_after",
]

@export var game_session_path: NodePath
@export var world_session_path: NodePath
@export var run_rng_path: NodePath
@export var card_annotation_path: NodePath
@export var card_state_validation_path: NodePath

var _test_fault_once := ""
var _apply_count := 0
var _rollback_count := 0
var _last_reason_code := "idle"


func to_save_data() -> Dictionary:
	var capture := capture_composite_state()
	return (capture.get("state", {}) as Dictionary).duplicate(true) if bool(capture.get("captured", false)) else {}


func capture_composite_state() -> Dictionary:
	var game_session := _game_session_node()
	var world_session := _world_session_node()
	var run_rng := _run_rng_node()
	var annotations := _annotation_node()
	if game_session == null or world_session == null or run_rng == null or annotations == null:
		return _capture_rejection("session_envelope_dependency_missing")
	var game_state_variant: Variant = game_session.call("to_save_data")
	var game_state: Dictionary = game_state_variant if game_state_variant is Dictionary else {}
	var game_payload: Dictionary = game_state.get("game_session_runtime", {}) if game_state.get("game_session_runtime", {}) is Dictionary else {}
	var game_preflight: Dictionary = game_session.call("preflight_save_data", game_payload)
	if not bool(game_preflight.get("accepted", false)):
		return _capture_rejection(str(game_preflight.get("reason_code", "session_runtime_capture_invalid")))
	var world_capture: Dictionary = world_session.call("capture_envelope_save_data")
	if not bool(world_capture.get("accepted", false)):
		return _capture_rejection(str(world_capture.get("reason_code", "world_session_capture_invalid")))
	var world_state: Dictionary = world_capture.get("normalized_state", {})
	var escrow_preflight := _preflight_world_facility_card_escrows(world_state)
	if not bool(escrow_preflight.get("accepted", false)):
		return _capture_rejection(str(escrow_preflight.get("reason_code", "facility_card_escrow_world_state_invalid")))
	var rng_state_variant: Variant = run_rng.call("to_save_data")
	var rng_state: Dictionary = rng_state_variant if rng_state_variant is Dictionary else {}
	var rng_preflight: Dictionary = run_rng.call("preflight_save_data", rng_state)
	if not bool(rng_preflight.get("accepted", false)):
		return _capture_rejection(str(rng_preflight.get("reason_code", "run_rng_capture_invalid")))
	var player_count := (world_state.get("players", []) as Array).size() if world_state.get("players", []) is Array else -1
	var annotation_capture: Dictionary = annotations.call("capture_save_checkpoint", player_count)
	if not bool(annotation_capture.get("accepted", false)):
		return _capture_rejection(str(annotation_capture.get("reason_code", "card_annotation_capture_invalid")))
	var state := {
		"schema_version": SCHEMA_VERSION,
		"game_session_runtime": (game_preflight.get("normalized_state", {}) as Dictionary).duplicate(true),
		"world_session_state": world_state.duplicate(true),
		"run_rng_state": (rng_preflight.get("normalized_state", {}) as Dictionary).duplicate(true),
		"card_history_private_annotations": (annotation_capture.get("checkpoint", {}) as Dictionary).duplicate(true),
	}
	if not _is_data_only(state):
		return _capture_rejection("session_envelope_not_data_only")
	return {"captured": true, "reason_code": "session_envelope_captured", "state": state}


func capture_restore_verification_state() -> Dictionary:
	var capture := capture_composite_state()
	if not bool(capture.get("captured", false)):
		return {}
	var state := (capture.get("state", {}) as Dictionary).duplicate(true)
	var game_session := _game_session_node()
	if game_session == null or not game_session.has_method("restore_target_save_data"):
		return state
	var target_capture: Dictionary = game_session.call("restore_target_save_data")
	var target_payload: Dictionary = target_capture.get("game_session_runtime", {}) \
		if target_capture.get("game_session_runtime", {}) is Dictionary else {}
	var target_preflight: Dictionary = game_session.call("preflight_save_data", target_payload)
	if not bool(target_preflight.get("accepted", false)):
		return {}
	state["game_session_runtime"] = (target_preflight.get("normalized_state", {}) as Dictionary).duplicate(true)
	return state


func preflight_save_data(data: Dictionary) -> Dictionary:
	var retired_payload := LegacyContractPayloadGuardV06.validation_report(data)
	if not bool(retired_payload.get("valid", false)):
		return _preflight_rejection("retired_contract_payload_rejected", str(retired_payload.get("path", "session_envelope")))
	if _looks_like_pre_resume(data):
		return _preflight_rejection("v06_pre_resume_manifest", "session_envelope", true)
	if not _has_exact_keys(data, ROOT_FIELDS) or int(data.get("schema_version", -1)) != SCHEMA_VERSION or not _is_data_only(data):
		return _preflight_rejection("session_envelope_v3_invalid")
	var game_session := _game_session_node()
	var world_session := _world_session_node()
	var run_rng := _run_rng_node()
	var annotations := _annotation_node()
	if game_session == null or world_session == null or run_rng == null or annotations == null:
		return _preflight_rejection("session_envelope_dependency_missing")
	if not (data.get("game_session_runtime") is Dictionary) \
			or not (data.get("world_session_state") is Dictionary) \
			or not (data.get("run_rng_state") is Dictionary) \
			or not (data.get("card_history_private_annotations") is Dictionary):
		return _preflight_rejection("session_envelope_children_invalid")
	var game_preflight: Dictionary = game_session.call("preflight_save_data", data.get("game_session_runtime", {}))
	if not bool(game_preflight.get("accepted", false)):
		return _preflight_rejection(str(game_preflight.get("reason_code", "session_runtime_preflight_failed")), "game_session_runtime")
	var world_preflight: Dictionary = world_session.call("preflight_envelope_save_data", data.get("world_session_state", {}))
	if not bool(world_preflight.get("accepted", false)):
		return _preflight_rejection(str(world_preflight.get("reason_code", "world_session_preflight_failed")), "world_session_state")
	var normalized_world: Dictionary = world_preflight.get("normalized_state", {})
	var escrow_preflight := _preflight_world_facility_card_escrows(normalized_world)
	if not bool(escrow_preflight.get("accepted", false)):
		return _preflight_rejection(
			str(escrow_preflight.get("reason_code", "facility_card_escrow_world_state_invalid")),
			"world_session_state"
		)
	var rng_preflight: Dictionary = run_rng.call("preflight_save_data", data.get("run_rng_state", {}))
	if not bool(rng_preflight.get("accepted", false)):
		return _preflight_rejection(str(rng_preflight.get("reason_code", "run_rng_preflight_failed")), "run_rng_state")
	var player_count := (normalized_world.get("players", []) as Array).size() if normalized_world.get("players", []) is Array else -1
	var annotation_preflight: Dictionary = annotations.call("validate_save_checkpoint", data.get("card_history_private_annotations", {}), player_count)
	if not bool(annotation_preflight.get("accepted", false)):
		return _preflight_rejection(str(annotation_preflight.get("reason_code", "card_annotation_preflight_failed")), "card_history_private_annotations")
	return {
		"accepted": true,
		"reason_code": "session_envelope_v3_valid",
		"normalized_state": {
			"schema_version": SCHEMA_VERSION,
			"game_session_runtime": (game_preflight.get("normalized_state", {}) as Dictionary).duplicate(true),
			"world_session_state": normalized_world.duplicate(true),
			"run_rng_state": (rng_preflight.get("normalized_state", {}) as Dictionary).duplicate(true),
			"card_history_private_annotations": (annotation_preflight.get("normalized_state", {}) as Dictionary).duplicate(true),
		},
	}


func apply_save_data(data: Dictionary) -> Dictionary:
	var preflight := preflight_save_data(data)
	if not bool(preflight.get("accepted", false)):
		_last_reason_code = str(preflight.get("reason_code", "session_envelope_preflight_failed"))
		return {
			"applied": false,
			"reason_code": _last_reason_code,
			"failing_child": str(preflight.get("failing_child", "preflight")),
			"requires_backup": bool(preflight.get("requires_backup", false)),
			"rollback_attempted": false,
			"rollback_complete": true,
		}
	var checkpoint := capture_runtime_checkpoint()
	if checkpoint.is_empty():
		return {
			"applied": false,
			"reason_code": "session_checkpoint_capture_failed",
			"failing_child": "session_envelope",
			"rollback_attempted": false,
			"rollback_complete": true,
		}
	var foundation := apply_restore_foundation(preflight.get("normalized_state", {}) as Dictionary)
	if not bool(foundation.get("applied", false)):
		return _direct_apply_failure(foundation, checkpoint)
	var tail := finalize_restore_tail(preflight.get("normalized_state", {}) as Dictionary)
	if not bool(tail.get("applied", false)):
		return _direct_apply_failure(tail, checkpoint)
	_apply_count += 1
	_last_reason_code = "session_envelope_applied"
	return {
		"applied": true,
		"reason_code": _last_reason_code,
		"apply_count": _apply_count,
		"rollback_attempted": false,
		"rollback_complete": true,
	}


func apply_restore_foundation(data: Dictionary) -> Dictionary:
	var preflight := preflight_save_data(data)
	if not bool(preflight.get("accepted", false)):
		return {"applied": false, "reason_code": str(preflight.get("reason_code", "session_envelope_preflight_failed")), "failing_child": str(preflight.get("failing_child", "preflight"))}
	var normalized := preflight.get("normalized_state", {}) as Dictionary
	if _consume_test_fault("session_before"):
		return {"applied": false, "reason_code": "qa_fault_session_before", "failing_child": "game_session_runtime"}
	var session_apply: Dictionary = _game_session_node().call("apply_restore_foundation", normalized.get("game_session_runtime", {}))
	if not bool(session_apply.get("applied", false)):
		return {"applied": false, "reason_code": str(session_apply.get("reason_code", "session_foundation_apply_failed")), "failing_child": "game_session_runtime"}
	if _consume_test_fault("world_before"):
		return {"applied": false, "reason_code": "qa_fault_world_before", "failing_child": "world_session_state"}
	var world_apply: Dictionary = _world_session_node().call("apply_envelope_save_data", normalized.get("world_session_state", {}))
	if not bool(world_apply.get("applied", false)):
		return {"applied": false, "reason_code": str(world_apply.get("reason_code", "world_session_apply_failed")), "failing_child": "world_session_state"}
	if _consume_test_fault("world_after"):
		return {"applied": false, "reason_code": "qa_fault_world_after", "failing_child": "world_session_state"}
	var rng_apply: Dictionary = _run_rng_node().call("apply_save_data", normalized.get("run_rng_state", {}))
	if not bool(rng_apply.get("applied", false)):
		return {"applied": false, "reason_code": str(rng_apply.get("reason_code", "run_rng_apply_failed")), "failing_child": "run_rng_state"}
	if _consume_test_fault("session_after"):
		return {"applied": false, "reason_code": "qa_fault_session_after", "failing_child": "game_session_runtime"}
	return {"applied": true, "reason_code": "session_foundation_applied"}


func finalize_restore_tail(data: Dictionary) -> Dictionary:
	var preflight := preflight_save_data(data)
	if not bool(preflight.get("accepted", false)):
		return {"applied": false, "reason_code": str(preflight.get("reason_code", "session_envelope_preflight_failed")), "failing_child": str(preflight.get("failing_child", "preflight"))}
	var normalized := preflight.get("normalized_state", {}) as Dictionary
	if _consume_test_fault("annotation_before"):
		return {"applied": false, "reason_code": "qa_fault_annotation_before", "failing_child": "card_history_private_annotations"}
	var annotation_apply: Dictionary = _annotation_node().call(
		"apply_save_checkpoint",
		normalized.get("card_history_private_annotations", {}),
		(normalized.get("world_session_state", {}).get("players", []) as Array).size()
	)
	if not bool(annotation_apply.get("applied", false)):
		return {"applied": false, "reason_code": str(annotation_apply.get("reason_code", "card_annotation_apply_failed")), "failing_child": "card_history_private_annotations"}
	if _consume_test_fault("annotation_after"):
		return {"applied": false, "reason_code": "qa_fault_annotation_after", "failing_child": "card_history_private_annotations"}
	var session_apply: Dictionary = _game_session_node().call("finalize_restore_tail", normalized.get("game_session_runtime", {}))
	if not bool(session_apply.get("applied", false)):
		return {"applied": false, "reason_code": str(session_apply.get("reason_code", "session_tail_apply_failed")), "failing_child": "game_session_runtime"}
	return {"applied": true, "reason_code": "session_tail_applied"}


func capture_runtime_checkpoint() -> Dictionary:
	var game_session := _game_session_node()
	var world_session := _world_session_node()
	var run_rng := _run_rng_node()
	var annotations := _annotation_node()
	if game_session == null or world_session == null or run_rng == null or annotations == null:
		return {}
	return {
		"schema_version": 1,
		"game_session_runtime": (((game_session.call("to_save_data") as Dictionary).get("game_session_runtime", {}) as Dictionary).duplicate(true)),
		"world_session_state": (world_session.call("capture_runtime_checkpoint") as Dictionary).duplicate(true),
		"run_rng_state": (run_rng.call("capture_runtime_checkpoint") as Dictionary).duplicate(true),
		"card_history_private_annotations": (annotations.call("capture_runtime_checkpoint") as Dictionary).duplicate(true),
	}


func restore_runtime_checkpoint(checkpoint: Dictionary) -> Dictionary:
	if int(checkpoint.get("schema_version", 0)) != 1:
		return {"applied": false, "reason_code": "session_checkpoint_invalid"}
	var failures: Array[String] = []
	var world_result: Dictionary = _world_session_node().call("restore_runtime_checkpoint", checkpoint.get("world_session_state", {}))
	if not bool(world_result.get("applied", false)):
		failures.append("world_session_state")
	var rng_result: Dictionary = _run_rng_node().call("restore_runtime_checkpoint", checkpoint.get("run_rng_state", {}))
	if not bool(rng_result.get("applied", false)):
		failures.append("run_rng_state")
	var annotation_result: Dictionary = _annotation_node().call("restore_runtime_checkpoint", checkpoint.get("card_history_private_annotations", {}))
	if not bool(annotation_result.get("applied", false)):
		failures.append("card_history_private_annotations")
	var session_result: Dictionary = _game_session_node().call("apply_save_data", checkpoint.get("game_session_runtime", {}))
	if not bool(session_result.get("applied", false)):
		failures.append("game_session_runtime")
	_rollback_count += 1
	return {"applied": failures.is_empty(), "reason_code": "session_checkpoint_restored" if failures.is_empty() else "session_checkpoint_restore_failed", "failures": failures}


func _direct_apply_failure(failure: Dictionary, checkpoint: Dictionary) -> Dictionary:
	var rollback := restore_runtime_checkpoint(checkpoint)
	var reason_code := str(failure.get("reason_code", "session_envelope_apply_failed"))
	_last_reason_code = reason_code
	return {
		"applied": false,
		"reason_code": reason_code,
		"failing_child": str(failure.get("failing_child", "session_envelope")),
		"rollback_attempted": true,
		"rollback_complete": bool(rollback.get("applied", false)),
		"rollback_failures": (rollback.get("failures", []) as Array).duplicate(),
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
		"runtime_owner": "SessionEnvelopeSaveOwner",
		"composite_owner_id": "game_session",
		"owns_gameplay_state": false,
		"owns_save_section": false,
		"coordinates_existing_owners": true,
		"child_owner_count": 3,
		"facility_escrow_validation_dependency": true,
		"apply_count": _apply_count,
		"rollback_count": _rollback_count,
		"last_reason_code": _last_reason_code,
		"fault_armed": not _test_fault_once.is_empty(),
		"full_run_resume_claimed": false,
	}


func _apply_failure(failing_child: String, reason_code: String, touched: Array[String], checkpoints: Dictionary) -> Dictionary:
	var rollback := _rollback_touched(touched, checkpoints)
	_last_reason_code = reason_code
	return {
		"applied": false,
		"reason_code": reason_code,
		"failing_child": failing_child,
		"rollback_attempted": not touched.is_empty(),
		"rollback_complete": bool(rollback.get("complete", false)),
		"rollback_failures": (rollback.get("failures", []) as Array).duplicate(),
	}


func _rollback_touched(touched: Array[String], checkpoints: Dictionary) -> Dictionary:
	var failures: Array[String] = []
	var reversed := touched.duplicate()
	reversed.reverse()
	for child_variant in reversed:
		var child := str(child_variant)
		var receipt: Dictionary = {}
		match child:
			"game_session_runtime":
				receipt = _game_session_node().call("apply_save_data", checkpoints.get(child, {}))
			"card_history_private_annotations":
				receipt = _annotation_node().call("restore_runtime_checkpoint", checkpoints.get(child, {}))
			"world_session_state":
				receipt = _world_session_node().call("restore_runtime_checkpoint", checkpoints.get(child, {}))
		if not bool(receipt.get("applied", false)):
			failures.append(child)
	_rollback_count += 1
	return {"complete": failures.is_empty(), "failures": failures}


func _consume_test_fault(stage: String) -> bool:
	if _test_fault_once != stage:
		return false
	_test_fault_once = ""
	return true


func _game_session_node() -> GameSessionRuntimeController:
	return get_node_or_null(game_session_path) as GameSessionRuntimeController


func _world_session_node() -> WorldSessionState:
	return get_node_or_null(world_session_path) as WorldSessionState


func _run_rng_node() -> RunRngService:
	return get_node_or_null(run_rng_path) as RunRngService


func _annotation_node() -> CardHistoryPrivateAnnotationService:
	return get_node_or_null(card_annotation_path) as CardHistoryPrivateAnnotationService


func _card_state_validation_node() -> Node:
	return get_node_or_null(card_state_validation_path)


func _preflight_world_facility_card_escrows(world_state: Dictionary) -> Dictionary:
	var players_variant: Variant = world_state.get("players", [])
	if not (players_variant is Array):
		return {"accepted": false, "reason_code": "facility_card_escrow_world_state_invalid"}
	var has_facility_state := false
	for player_variant in players_variant as Array:
		if not (player_variant is Dictionary):
			return {"accepted": false, "reason_code": "facility_card_escrow_world_state_invalid"}
		var player := player_variant as Dictionary
		for field_id in ["facility_card_escrows", "facility_card_escrow_receipts"]:
			if not player.has(field_id):
				continue
			if not (player.get(field_id) is Dictionary):
				return {"accepted": false, "reason_code": "facility_card_escrow_state_invalid"}
			has_facility_state = has_facility_state or not (player.get(field_id) as Dictionary).is_empty()
	if not has_facility_state:
		return {"accepted": true, "reason_code": "facility_card_escrow_world_state_empty"}
	var validator := _card_state_validation_node()
	if validator == null or not validator.has_method("preflight_facility_card_escrow_world_state"):
		return {"accepted": false, "reason_code": "facility_card_escrow_validator_unavailable"}
	var receipt_variant: Variant = validator.call(
		"preflight_facility_card_escrow_world_state",
		world_state.duplicate(true)
	)
	return (receipt_variant as Dictionary).duplicate(true) if receipt_variant is Dictionary else {
		"accepted": false,
		"reason_code": "facility_card_escrow_validation_receipt_invalid",
	}


func _looks_like_pre_resume(data: Dictionary) -> bool:
	return (data.keys().size() == 1 and data.has("game_session_runtime")) \
			or int(data.get("schema_version", 0)) in [1, 2]


func _capture_rejection(reason_code: String) -> Dictionary:
	_last_reason_code = reason_code
	return {"captured": false, "reason_code": reason_code, "state": {}}


func _preflight_rejection(reason_code: String, failing_child: String = "session_envelope", requires_backup: bool = false) -> Dictionary:
	return {
		"accepted": false,
		"reason_code": reason_code,
		"failing_child": failing_child,
		"requires_backup": requires_backup,
	}


func _has_exact_keys(dictionary: Dictionary, fields: Array) -> bool:
	if dictionary.keys().size() != fields.size():
		return false
	for field_variant in fields:
		if not dictionary.has(str(field_variant)):
			return false
	return true


func _is_data_only(value: Variant) -> bool:
	if typeof(value) == TYPE_OBJECT or value is Callable:
		return false
	if value is float and not is_finite(value):
		return false
	if value is Vector2 and (not is_finite((value as Vector2).x) or not is_finite((value as Vector2).y)):
		return false
	if value is Color:
		var color := value as Color
		if not is_finite(color.r) or not is_finite(color.g) or not is_finite(color.b) or not is_finite(color.a):
			return false
	if value is Dictionary:
		for key_variant in value.keys():
			if not _is_data_only(key_variant) or not _is_data_only(value[key_variant]):
				return false
	elif value is Array:
		for item_variant in value:
			if not _is_data_only(item_variant):
				return false
	return true
