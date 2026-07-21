@tool
extends Node
class_name SessionEnvelopeSaveOwner

const SCHEMA_VERSION := 2
const ROOT_FIELDS := [
	"schema_version",
	"game_session_runtime",
	"world_session_state",
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
@export var card_annotation_path: NodePath

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
	var annotations := _annotation_node()
	if game_session == null or world_session == null or annotations == null:
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
	var player_count := (world_state.get("players", []) as Array).size() if world_state.get("players", []) is Array else -1
	var annotation_capture: Dictionary = annotations.call("capture_save_checkpoint", player_count)
	if not bool(annotation_capture.get("accepted", false)):
		return _capture_rejection(str(annotation_capture.get("reason_code", "card_annotation_capture_invalid")))
	var state := {
		"schema_version": SCHEMA_VERSION,
		"game_session_runtime": (game_preflight.get("normalized_state", {}) as Dictionary).duplicate(true),
		"world_session_state": world_state.duplicate(true),
		"card_history_private_annotations": (annotation_capture.get("checkpoint", {}) as Dictionary).duplicate(true),
	}
	if not _is_data_only(state):
		return _capture_rejection("session_envelope_not_data_only")
	return {"captured": true, "reason_code": "session_envelope_captured", "state": state}


func preflight_save_data(data: Dictionary) -> Dictionary:
	var retired_payload := LegacyContractPayloadGuardV06.validation_report(data)
	if not bool(retired_payload.get("valid", false)):
		return _preflight_rejection("retired_contract_payload_rejected", str(retired_payload.get("path", "session_envelope")))
	if _looks_like_v1(data):
		return _preflight_v1(data)
	if not _has_exact_keys(data, ROOT_FIELDS) or int(data.get("schema_version", -1)) != SCHEMA_VERSION or not _is_data_only(data):
		return _preflight_rejection("session_envelope_v2_invalid")
	var game_session := _game_session_node()
	var world_session := _world_session_node()
	var annotations := _annotation_node()
	if game_session == null or world_session == null or annotations == null:
		return _preflight_rejection("session_envelope_dependency_missing")
	if not (data.get("game_session_runtime") is Dictionary) \
			or not (data.get("world_session_state") is Dictionary) \
			or not (data.get("card_history_private_annotations") is Dictionary):
		return _preflight_rejection("session_envelope_children_invalid")
	var game_preflight: Dictionary = game_session.call("preflight_save_data", data.get("game_session_runtime", {}))
	if not bool(game_preflight.get("accepted", false)):
		return _preflight_rejection(str(game_preflight.get("reason_code", "session_runtime_preflight_failed")), "game_session_runtime")
	var world_preflight: Dictionary = world_session.call("preflight_envelope_save_data", data.get("world_session_state", {}))
	if not bool(world_preflight.get("accepted", false)):
		return _preflight_rejection(str(world_preflight.get("reason_code", "world_session_preflight_failed")), "world_session_state")
	var normalized_world: Dictionary = world_preflight.get("normalized_state", {})
	var player_count := (normalized_world.get("players", []) as Array).size() if normalized_world.get("players", []) is Array else -1
	var annotation_preflight: Dictionary = annotations.call("validate_save_checkpoint", data.get("card_history_private_annotations", {}), player_count)
	if not bool(annotation_preflight.get("accepted", false)):
		return _preflight_rejection(str(annotation_preflight.get("reason_code", "card_annotation_preflight_failed")), "card_history_private_annotations")
	return {
		"accepted": true,
		"reason_code": "session_envelope_v2_valid",
		"normalized_state": {
			"schema_version": SCHEMA_VERSION,
			"game_session_runtime": (game_preflight.get("normalized_state", {}) as Dictionary).duplicate(true),
			"world_session_state": normalized_world.duplicate(true),
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
	var normalized: Dictionary = preflight.get("normalized_state", {})
	var game_session := _game_session_node()
	var world_session := _world_session_node()
	var annotations := _annotation_node()
	var checkpoints := {
		"game_session_runtime": (game_session.call("to_save_data") as Dictionary).duplicate(true),
		"world_session_state": (world_session.call("capture_runtime_checkpoint") as Dictionary).duplicate(true),
		"card_history_private_annotations": (annotations.call("capture_runtime_checkpoint") as Dictionary).duplicate(true),
	}
	var touched: Array[String] = []
	if _consume_test_fault("world_before"):
		return _apply_failure("world_session_state", "qa_fault_world_before", touched, checkpoints)
	touched.append("world_session_state")
	var world_apply: Dictionary = world_session.call("apply_envelope_save_data", normalized.get("world_session_state", {}))
	if not bool(world_apply.get("applied", false)):
		return _apply_failure("world_session_state", str(world_apply.get("reason_code", "world_session_apply_failed")), touched, checkpoints)
	if _consume_test_fault("world_after"):
		return _apply_failure("world_session_state", "qa_fault_world_after", touched, checkpoints)
	if _consume_test_fault("annotation_before"):
		return _apply_failure("card_history_private_annotations", "qa_fault_annotation_before", touched, checkpoints)
	touched.append("card_history_private_annotations")
	var annotation_apply: Dictionary = annotations.call(
		"apply_save_checkpoint",
		normalized.get("card_history_private_annotations", {}),
		(normalized.get("world_session_state", {}).get("players", []) as Array).size()
	)
	if not bool(annotation_apply.get("applied", false)):
		return _apply_failure("card_history_private_annotations", str(annotation_apply.get("reason_code", "card_annotation_apply_failed")), touched, checkpoints)
	if _consume_test_fault("annotation_after"):
		return _apply_failure("card_history_private_annotations", "qa_fault_annotation_after", touched, checkpoints)
	if _consume_test_fault("session_before"):
		return _apply_failure("game_session_runtime", "qa_fault_session_before", touched, checkpoints)
	touched.append("game_session_runtime")
	var session_apply: Dictionary = game_session.call("apply_save_data", normalized.get("game_session_runtime", {}))
	if not bool(session_apply.get("applied", false)):
		return _apply_failure("game_session_runtime", str(session_apply.get("reason_code", session_apply.get("reason", "session_runtime_apply_failed"))), touched, checkpoints)
	if _consume_test_fault("session_after"):
		return _apply_failure("game_session_runtime", "qa_fault_session_after", touched, checkpoints)
	_apply_count += 1
	_last_reason_code = "session_envelope_applied"
	return {
		"applied": true,
		"reason_code": _last_reason_code,
		"apply_count": _apply_count,
		"rollback_attempted": false,
		"rollback_complete": true,
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
		"apply_count": _apply_count,
		"rollback_count": _rollback_count,
		"last_reason_code": _last_reason_code,
		"fault_armed": not _test_fault_once.is_empty(),
		"full_run_resume_claimed": false,
	}


func _preflight_v1(data: Dictionary) -> Dictionary:
	var game_payload: Dictionary = data.get("game_session_runtime", {}) if data.get("game_session_runtime", {}) is Dictionary else {}
	var game_session := _game_session_node()
	var annotations := _annotation_node()
	if game_session == null or annotations == null or game_payload.is_empty():
		return _preflight_rejection("session_v1_world_state_missing", "world_session_state", true)
	var game_preflight: Dictionary = game_session.call("preflight_save_data", game_payload)
	if not bool(game_preflight.get("accepted", false)):
		return _preflight_rejection(str(game_preflight.get("reason_code", "session_v1_invalid")), "game_session_runtime", true)
	var normalized_game: Dictionary = game_preflight.get("normalized_state", {})
	var safe_idle := str(normalized_game.get("session_state", "")) == GameSessionRuntimeController.STATE_IDLE \
			and str(normalized_game.get("session_id", "")).is_empty() \
			and (normalized_game.get("setup", {}) as Dictionary).is_empty() \
			and (normalized_game.get("outcome_receipt", {}) as Dictionary).is_empty()
	if not safe_idle:
		return _preflight_rejection("session_v1_world_state_missing", "world_session_state", true)
	return {
		"accepted": true,
		"reason_code": "session_v1_idle_migrated",
		"requires_backup": false,
		"normalized_state": {
			"schema_version": SCHEMA_VERSION,
			"game_session_runtime": normalized_game.duplicate(true),
			"world_session_state": WorldSessionEnvelopeCodec.empty_state(),
			"card_history_private_annotations": annotations.call("empty_save_checkpoint"),
		},
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


func _annotation_node() -> CardHistoryPrivateAnnotationService:
	return get_node_or_null(card_annotation_path) as CardHistoryPrivateAnnotationService


func _looks_like_v1(data: Dictionary) -> bool:
	return data.keys().size() == 1 and data.has("game_session_runtime") and data.get("game_session_runtime") is Dictionary


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
