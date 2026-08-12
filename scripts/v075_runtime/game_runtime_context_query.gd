extends RefCounted
class_name GameRuntimeContextQuery

## Version-neutral, read-only application context query. The application root
## supplies the bound ports; consumers never discover them from versioned node
## names, script paths, or class names.

const REASON_READY := "ready"
const REASON_MAIN_ROOT_MISSING := "main_root_missing"
const REASON_RUNTIME_COMPOSITION_MISSING := "runtime_composition_missing"
const REASON_RUNTIME_NOT_ACTIVE := "runtime_not_active"
const REASON_GAME_SCREEN_MISSING := "game_screen_missing"
const REASON_TELEMETRY_SERVICE_MISSING := "telemetry_service_missing"
const REASON_UNSUPPORTED_RULESET_CONTEXT := "unsupported_ruleset_context"
const REASON_LEGACY_NODE_PATH_ONLY := "legacy_node_path_only"
const RUNTIME_METHODS: Array[StringName] = [
	&"identity_snapshot",
	&"debug_snapshot",
	&"issue_intent",
	&"submit_intent",
	&"local_snapshot",
]
const SCREEN_METHODS: Array[StringName] = [
	&"bind_application_flow",
	&"apply_snapshot",
	&"debug_snapshot",
]
const TELEMETRY_METHODS: Array[StringName] = [
	&"bind_sources",
	&"debug_snapshot",
	&"events_snapshot",
]

var _application_root: Node
var _runtime_composition: Node
var _game_screen: Control
var _telemetry_service: Node
var _binding_reason_code := ""


static func bind(
	bound_application_root: Node,
	bound_runtime_composition: Node,
	bound_game_screen: Control,
	bound_telemetry_service: Node
) -> GameRuntimeContextQuery:
	var query := new()
	query._application_root = bound_application_root
	query._runtime_composition = bound_runtime_composition
	query._game_screen = bound_game_screen
	query._telemetry_service = bound_telemetry_service
	return query


static func rejected(reason_code: String) -> GameRuntimeContextQuery:
	var query := new()
	query._binding_reason_code = reason_code
	return query


static func from_application(
	application_candidate: Node
) -> GameRuntimeContextQuery:
	if not is_instance_valid(application_candidate):
		return rejected(REASON_MAIN_ROOT_MISSING)
	if not application_candidate.has_method("game_runtime_context_query"):
		return rejected(
			REASON_LEGACY_NODE_PATH_ONLY
			if _has_unported_runtime_context(application_candidate)
			else REASON_RUNTIME_COMPOSITION_MISSING
		)
	var candidate: Variant = application_candidate.call(
		"game_runtime_context_query"
	)
	if (
		candidate is GameRuntimeContextQuery
		and (candidate as GameRuntimeContextQuery).has_method("snapshot")
		and (candidate as GameRuntimeContextQuery).has_method(
			"runtime_composition"
		)
		and (candidate as GameRuntimeContextQuery).has_method("game_screen")
		and (candidate as GameRuntimeContextQuery).has_method(
			"telemetry_service"
		)
	):
		return candidate as GameRuntimeContextQuery
	return rejected(REASON_RUNTIME_COMPOSITION_MISSING)


func application_root() -> Node:
	return _application_root


func runtime_composition() -> Node:
	return _runtime_composition


func game_screen() -> Control:
	return _game_screen


func telemetry_service() -> Node:
	return _telemetry_service


func snapshot() -> Dictionary:
	var result := _empty_snapshot(
		_binding_reason_code
		if not _binding_reason_code.is_empty()
		else REASON_RUNTIME_NOT_ACTIVE
	)
	if not _binding_reason_code.is_empty():
		return result
	if not is_instance_valid(_application_root):
		return _with_reason(result, REASON_MAIN_ROOT_MISSING)
	if (
		not is_instance_valid(_runtime_composition)
		or not _has_methods(_runtime_composition, RUNTIME_METHODS)
	):
		return _with_reason(result, REASON_RUNTIME_COMPOSITION_MISSING)
	if (
		not is_instance_valid(_game_screen)
		or not _has_methods(_game_screen, SCREEN_METHODS)
	):
		return _with_reason(result, REASON_GAME_SCREEN_MISSING)
	if (
		not is_instance_valid(_telemetry_service)
		or not _has_methods(_telemetry_service, TELEMETRY_METHODS)
	):
		return _with_reason(result, REASON_TELEMETRY_SERVICE_MISSING)

	var identity_value: Variant = _runtime_composition.call("identity_snapshot")
	var composition_value: Variant = _runtime_composition.call("debug_snapshot")
	var screen_value: Variant = _game_screen.call("debug_snapshot")
	var telemetry_value: Variant = _telemetry_service.call("debug_snapshot")
	if (
		not (identity_value is Dictionary)
		or not (composition_value is Dictionary)
		or not (screen_value is Dictionary)
		or not (telemetry_value is Dictionary)
	):
		return _with_reason(result, REASON_UNSUPPORTED_RULESET_CONTEXT)

	var identity := identity_value as Dictionary
	var composition := composition_value as Dictionary
	var runtime := composition.get("runtime", {}) as Dictionary
	var combat := runtime.get("combat", {}) as Dictionary
	var screen := screen_value as Dictionary
	var telemetry := telemetry_value as Dictionary
	var receipt := composition.get("last_receipt", {}) as Dictionary
	var ruleset_id := str(identity.get("ruleset_id", "")).strip_edges()
	var runtime_ruleset_id := str(runtime.get("ruleset_id", "")).strip_edges()
	var screen_ruleset_id := str(screen.get("ruleset_id", "")).strip_edges()
	var composition_ruleset_id := str(
		composition.get("ruleset_id", "")
	).strip_edges()
	var ruleset_supported := (
		not ruleset_id.is_empty()
		and composition_ruleset_id == ruleset_id
		and runtime_ruleset_id in ["", ruleset_id]
		and screen_ruleset_id in ["", ruleset_id]
	)
	result["ruleset_id"] = ruleset_id
	if not ruleset_supported:
		return _with_reason(result, REASON_UNSUPPORTED_RULESET_CONTEXT)

	var session_id := str(identity.get("last_session_id", "")).strip_edges()
	var activation_count := int(identity.get("activation_count", 0))
	var published_activation_count := int(
		identity.get("published_activation_count", 0)
	)
	var session_committed := (
		activation_count > 0
		and published_activation_count == activation_count
		and not session_id.is_empty()
		and str(identity.get("activation_transaction_stage", "")) == "idle"
		and bool(receipt.get("accepted", false))
		and str(receipt.get("session_id", "")) == session_id
		and str(composition.get("new_game_transaction_stage", "")) == "idle"
		and not bool(composition.get("new_game_transaction_in_progress", true))
		and not bool(composition.get("pending_initialization_rollback", true))
	)
	var typed_bindings := {
		"ruleset_owner_count": int(
			composition.get("ruleset_owner_count", 0)
		),
		"gameplay_owner_count": int(
			composition.get("gameplay_owner_count", 0)
		),
		"combat_runtime_owner_count": int(
			composition.get("combat_runtime_owner_count", 0)
		),
		"combat_state_writer_count": int(
			composition.get("combat_state_writer_count", 0)
		),
		"combat_telemetry_service_count": int(
			composition.get("combat_telemetry_service_count", 0)
		),
		"combat_initialized": bool(combat.get("initialized", false)),
	}
	var typed_bindings_ready := (
		int(typed_bindings["ruleset_owner_count"]) == 1
		and int(typed_bindings["gameplay_owner_count"]) == 1
		and int(typed_bindings["combat_runtime_owner_count"]) == 1
		and int(typed_bindings["combat_state_writer_count"]) == 1
		and int(typed_bindings["combat_telemetry_service_count"]) == 1
		and bool(typed_bindings["combat_initialized"])
	)
	var runtime_active := (
		bool(composition.get("composition_ready", false))
		and session_committed
		and typed_bindings_ready
		and not str(runtime.get("match_id", "")).is_empty()
		and str(runtime.get("phase", "")) not in ["", "idle", "failed"]
		and int(runtime.get("active_rule_owner_count", 0)) == 1
		and str(runtime.get("new_game_transaction_stage", "")) == "idle"
		and not bool(runtime.get("new_game_transaction_in_progress", true))
		and not bool(runtime.get("pending_initialization_rollback", true))
	)
	var game_screen_ready := (
		bool(screen.get("application_flow_bound", false))
		and screen_ruleset_id == ruleset_id
	)
	var telemetry_ready := (
		bool(telemetry.get("ready", false))
		and not str(telemetry.get("session_id", "")).is_empty()
	)
	result.merge({
		"session_state": "committed" if session_committed else "not_committed",
		"runtime_active": runtime_active,
		"game_screen_ready": game_screen_ready,
		"telemetry_ready": telemetry_ready,
		"typed_owner_bindings": typed_bindings,
		"combat_owner_active": (
			bool(typed_bindings["combat_initialized"])
			and int(typed_bindings["combat_runtime_owner_count"]) == 1
			and int(typed_bindings["combat_state_writer_count"]) == 1
		),
	}, true)
	if not runtime_active:
		return _with_reason(result, REASON_RUNTIME_NOT_ACTIVE)
	if not game_screen_ready:
		return _with_reason(result, REASON_GAME_SCREEN_MISSING)
	if not telemetry_ready:
		return _with_reason(result, REASON_TELEMETRY_SERVICE_MISSING)
	result["ready"] = true
	result["reason_code"] = REASON_READY
	return result


static func _empty_snapshot(reason_code: String) -> Dictionary:
	return {
		"schema": "GameRuntimeContextQueryV1",
		"ready": false,
		"reason_code": reason_code,
		"ruleset_id": "",
		"session_state": "not_committed",
		"runtime_active": false,
		"game_screen_ready": false,
		"telemetry_ready": false,
		"combat_owner_active": false,
		"typed_owner_bindings": {
			"ruleset_owner_count": 0,
			"gameplay_owner_count": 0,
			"combat_runtime_owner_count": 0,
			"combat_state_writer_count": 0,
			"combat_telemetry_service_count": 0,
			"combat_initialized": false,
		},
	}


static func _with_reason(
	result: Dictionary,
	reason_code: String
) -> Dictionary:
	result["ready"] = false
	result["reason_code"] = reason_code
	return result


static func _has_methods(node: Node, method_names: Array[StringName]) -> bool:
	if not is_instance_valid(node):
		return false
	for method_name in method_names:
		if not node.has_method(method_name):
			return false
	return true


static func _has_unported_runtime_context(application_candidate: Node) -> bool:
	var nodes: Array[Node] = []
	_collect_nodes(application_candidate, nodes)
	var runtime_count := 0
	var screen_count := 0
	for node in nodes:
		runtime_count += int(_has_methods(node, RUNTIME_METHODS))
		screen_count += int(_has_methods(node, SCREEN_METHODS))
	return runtime_count == 1 and screen_count == 1


static func _collect_nodes(node: Node, output: Array[Node]) -> void:
	output.append(node)
	for child in node.get_children():
		_collect_nodes(child as Node, output)
