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
const ACTIVE_RUNTIME_PHASES: Array[String] = [
	"submission",
	"resolving",
	"maintenance",
	"settled",
]
const ACTIVE_COMBAT_PHASES: Array[String] = [
	"batch_active",
	"public_resolution_between_receipts",
	"maintenance_before_autonomy",
	"victory_pending",
	"victory_resolved",
	"final_settlement",
	"terminal",
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
	var screen := screen_value as Dictionary
	var telemetry := telemetry_value as Dictionary
	if (
		not _has_exact_schema(
			composition,
			"V075RuntimeCompositionDebugV1"
		)
		or not _has_dictionary_fields(composition, ["runtime", "combat_telemetry"])
		or not _has_string_fields(
			identity,
			[
				"ruleset_id",
				"last_session_id",
				"activation_transaction_stage",
			]
		)
		or not _has_integer_fields(
			identity,
			["activation_count", "published_activation_count"]
		)
		or not _has_boolean_fields(identity, ["pending_initialization_rollback"])
		or not _has_string_fields(composition, ["ruleset_id", "new_game_transaction_stage", "last_published_session_id"])
		or not _has_integer_fields(
			composition,
			[
				"ruleset_owner_count",
				"gameplay_owner_count",
				"combat_runtime_owner_count",
				"combat_state_writer_count",
				"combat_telemetry_service_count",
				"combat_telemetry_gameplay_owner_count",
				"connected_domain_count",
				"cutover_domain_count",
				"new_game_publication_count",
			]
		)
		or not _has_boolean_fields(
			composition,
			[
				"composition_ready",
				"new_game_transaction_in_progress",
				"pending_initialization_rollback",
			]
		)
		or not _has_exact_schema(screen, "V075SampleGameScreenCombatDebugV1")
		or not _has_string_fields(screen, ["ruleset_id"])
		or not _has_boolean_fields(screen, ["application_flow_bound"])
		or not _has_exact_schema(telemetry, "V073PlaytestTelemetryDebugV1")
		or not _has_string_fields(
			telemetry,
			["source_ruleset_id", "source_session_id", "session_id"]
		)
		or not _has_boolean_fields(telemetry, ["ready"])
		or not _has_integer_fields(
			telemetry,
			[
				"gameplay_owner_count",
				"rng_owner_count",
				"world_mutation_count",
				"source_flow_instance_id",
				"source_screen_instance_id",
			]
		)
	):
		return _with_reason(result, REASON_UNSUPPORTED_RULESET_CONTEXT)
	var runtime := composition["runtime"] as Dictionary
	var combat := runtime.get("combat", {}) as Dictionary
	var combat_telemetry := composition["combat_telemetry"] as Dictionary
	var ruleset_id := identity["ruleset_id"] as String
	var runtime_ruleset_id := str(runtime.get("ruleset_id", ""))
	var screen_ruleset_id := screen["ruleset_id"] as String
	var composition_ruleset_id := composition["ruleset_id"] as String
	var ruleset_supported: bool = (
		not ruleset_id.is_empty()
		and composition_ruleset_id == ruleset_id
		and runtime_ruleset_id == ruleset_id
		and screen_ruleset_id == ruleset_id
	)
	result["ruleset_id"] = ruleset_id
	if not ruleset_supported:
		return _with_reason(result, REASON_UNSUPPORTED_RULESET_CONTEXT)

	var session_id := (identity["last_session_id"] as String).strip_edges()
	var activation_count := identity["activation_count"] as int
	var published_activation_count := identity["published_activation_count"] as int
	var session_committed: bool = (
		activation_count > 0
		and published_activation_count == activation_count
		and not session_id.is_empty()
		and identity["activation_transaction_stage"] == "idle"
		and not identity["pending_initialization_rollback"]
		and composition["new_game_transaction_stage"] == "idle"
		and not composition["new_game_transaction_in_progress"]
		and not composition["pending_initialization_rollback"]
		and composition["new_game_publication_count"] == published_activation_count
		and composition["last_published_session_id"] == session_id
	)
	if not session_committed:
		result["session_state"] = "not_committed"
		return _with_reason(result, REASON_RUNTIME_NOT_ACTIVE)
	if (
		not _has_string_fields(runtime, ["ruleset_id", "match_id", "phase", "new_game_transaction_stage"])
		or not _has_integer_fields(
			runtime,
			[
				"active_rule_owner_count",
				"combat_runtime_owner_count",
				"combat_state_writer_count",
				"combat_telemetry_gameplay_owner_count",
				"combat_telemetry_rng_owner_count",
				"combat_telemetry_world_mutation_count",
				"connected_domain_count",
				"cutover_domain_count",
			]
		)
		or not _has_boolean_fields(runtime, ["new_game_transaction_in_progress", "pending_initialization_rollback"])
		or not _has_exact_schema(combat, "V075CombatRuntimeDebugV1")
		or not _has_string_fields(combat, ["ruleset_id", "phase"])
		or not _has_integer_fields(
			combat,
			[
				"combat_runtime_owner_count",
				"combat_state_writer_count",
				"connected_domain_count",
				"cutover_domain_count",
			]
		)
		or not _has_boolean_fields(combat, ["initialized"])
		or not _has_exact_schema(combat_telemetry, "V075CombatTelemetryServiceDebugV1")
		or not _has_string_fields(combat_telemetry, ["ruleset_id"])
		or not _has_integer_fields(combat_telemetry, ["gameplay_owner_count", "rng_owner_count", "world_mutation_count"])
		or combat["ruleset_id"] != ruleset_id
		or combat_telemetry["ruleset_id"] != ruleset_id
		or telemetry["source_ruleset_id"] != ruleset_id
	):
		return _with_reason(result, REASON_UNSUPPORTED_RULESET_CONTEXT)
	var typed_bindings := {
		"ruleset_owner_count": composition["ruleset_owner_count"],
		"gameplay_owner_count": composition["gameplay_owner_count"],
		"combat_runtime_owner_count": composition["combat_runtime_owner_count"],
		"combat_state_writer_count": composition["combat_state_writer_count"],
		"combat_telemetry_service_count": composition["combat_telemetry_service_count"],
		"combat_initialized": combat["initialized"],
	}
	var typed_bindings_ready: bool = (
		int(typed_bindings["ruleset_owner_count"]) == 1
		and int(typed_bindings["gameplay_owner_count"]) == 1
		and int(typed_bindings["combat_runtime_owner_count"]) == 1
		and int(typed_bindings["combat_state_writer_count"]) == 1
		and int(typed_bindings["combat_telemetry_service_count"]) == 1
		and bool(typed_bindings["combat_initialized"])
		and runtime["combat_runtime_owner_count"] == 1
		and runtime["combat_state_writer_count"] == 1
		and combat["combat_runtime_owner_count"] == 1
		and combat["combat_state_writer_count"] == 1
		and (
			composition["combat_runtime_owner_count"]
			== runtime["combat_runtime_owner_count"]
		)
		and (
			composition["combat_state_writer_count"]
			== runtime["combat_state_writer_count"]
		)
		and (
			runtime["combat_runtime_owner_count"]
			== combat["combat_runtime_owner_count"]
		)
		and (
			runtime["combat_state_writer_count"]
			== combat["combat_state_writer_count"]
		)
		and _complete_domain_binding(composition)
		and _complete_domain_binding(runtime)
		and _complete_domain_binding(combat)
		and (
			composition["connected_domain_count"]
			== runtime["connected_domain_count"]
		)
		and (
			composition["cutover_domain_count"]
			== runtime["cutover_domain_count"]
		)
		and composition["combat_telemetry_gameplay_owner_count"] == 0
		and runtime["combat_telemetry_gameplay_owner_count"] == 0
		and runtime["combat_telemetry_rng_owner_count"] == 0
		and runtime["combat_telemetry_world_mutation_count"] == 0
		and combat_telemetry["gameplay_owner_count"] == 0
		and combat_telemetry["rng_owner_count"] == 0
		and combat_telemetry["world_mutation_count"] == 0
	)
	var combat_owner_active: bool = (
		bool(typed_bindings["combat_initialized"])
		and int(typed_bindings["combat_runtime_owner_count"]) == 1
		and int(typed_bindings["combat_state_writer_count"]) == 1
		and combat["phase"] in ACTIVE_COMBAT_PHASES
		and _complete_domain_binding(combat)
		and combat_telemetry["gameplay_owner_count"] == 0
		and combat_telemetry["rng_owner_count"] == 0
		and combat_telemetry["world_mutation_count"] == 0
	)
	var runtime_active: bool = (
		composition["composition_ready"]
		and session_committed
		and typed_bindings_ready
		and combat_owner_active
		and not (runtime["match_id"] as String).is_empty()
		and runtime["phase"] in ACTIVE_RUNTIME_PHASES
		and runtime["active_rule_owner_count"] == 1
		and runtime["new_game_transaction_stage"] == "idle"
		and not runtime["new_game_transaction_in_progress"]
		and not runtime["pending_initialization_rollback"]
	)
	var game_screen_ready: bool = (
		screen["application_flow_bound"]
		and screen_ruleset_id == ruleset_id
	)
	var telemetry_ready: bool = (
		telemetry["ready"]
		and telemetry["source_session_id"] == session_id
		and not (telemetry["session_id"] as String).is_empty()
		and telemetry["source_flow_instance_id"] == _runtime_composition.get_instance_id()
		and telemetry["source_screen_instance_id"] == _game_screen.get_instance_id()
		and telemetry["gameplay_owner_count"] == 0
		and telemetry["rng_owner_count"] == 0
		and telemetry["world_mutation_count"] == 0
	)
	result.merge({
		"session_state": "committed" if session_committed else "not_committed",
		"runtime_active": runtime_active,
		"game_screen_ready": game_screen_ready,
		"telemetry_ready": telemetry_ready,
		"typed_owner_bindings": typed_bindings,
		"combat_owner_active": combat_owner_active,
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
	for paths in [
		["V073RuntimeComposition", "V073SampleGameScreen"],
		["V074RuntimeComposition", "V074GameScreen"],
	]:
		var runtime := application_candidate.get_node_or_null(paths[0])
		var screen := application_candidate.get_node_or_null(paths[1])
		if (
			is_instance_valid(runtime)
			and is_instance_valid(screen)
			and _has_methods(runtime, RUNTIME_METHODS)
			and _has_methods(screen, SCREEN_METHODS)
		):
			return true
	return false


static func _has_exact_schema(value: Dictionary, schema: String) -> bool:
	return value.get("schema") is String and value["schema"] == schema


static func _has_dictionary_fields(value: Dictionary, fields: Array[String]) -> bool:
	for field in fields:
		if not value.has(field) or not (value[field] is Dictionary):
			return false
	return true


static func _has_string_fields(value: Dictionary, fields: Array[String]) -> bool:
	for field in fields:
		if not value.has(field) or not (value[field] is String):
			return false
	return true


static func _has_integer_fields(value: Dictionary, fields: Array[String]) -> bool:
	for field in fields:
		if not value.has(field) or not (value[field] is int):
			return false
	return true


static func _has_boolean_fields(value: Dictionary, fields: Array[String]) -> bool:
	for field in fields:
		if not value.has(field) or not (value[field] is bool):
			return false
	return true


static func _complete_domain_binding(value: Dictionary) -> bool:
	return (
		value["cutover_domain_count"] > 0
		and value["connected_domain_count"] == value["cutover_domain_count"]
	)
