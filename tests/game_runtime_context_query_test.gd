extends SceneTree

const Query := preload(
	"res://scripts/v075_runtime/game_runtime_context_query.gd"
)
const GlobeSupport := preload(
	"res://tests/support/v073_ui_globe_test_support.gd"
)

var _checks := 0
var _failures: Array[String] = []


class FakeRuntimeComposition:
	extends Node
	var identity := {}
	var debug := {}

	func identity_snapshot() -> Dictionary:
		return identity.duplicate(true)

	func debug_snapshot() -> Dictionary:
		return debug.duplicate(true)

	func issue_intent(_kind: String, _parameters: Dictionary = {}) -> Dictionary:
		return {}

	func submit_intent(_intent: Dictionary) -> Dictionary:
		return {}

	func local_snapshot() -> Dictionary:
		return {}


class FakeGameScreen:
	extends Control
	var debug := {}

	func bind_application_flow(
		_flow: Node,
		_identity: Dictionary,
		_capabilities: Dictionary
	) -> void:
		pass

	func apply_snapshot(_snapshot: Dictionary) -> void:
		pass

	func debug_snapshot() -> Dictionary:
		return debug.duplicate(true)


class FakeTelemetryService:
	extends Node
	var debug := {}

	func bind_sources(_flow: Node, _screen: Node) -> void:
		pass

	func debug_snapshot() -> Dictionary:
		return debug.duplicate(true)

	func events_snapshot() -> Array:
		return []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_expect_reason(Query.from_application(null), "main_root_missing")
	var empty_root := Node.new()
	_expect_reason(
		Query.from_application(empty_root),
		"runtime_composition_missing"
	)
	empty_root.free()

	var structural_root := Node.new()
	structural_root.add_child(FakeRuntimeComposition.new())
	structural_root.add_child(FakeGameScreen.new())
	_expect_reason(
		Query.from_application(structural_root),
		"runtime_composition_missing"
	)
	structural_root.free()

	var named_but_untyped_root := Node.new()
	var named_but_untyped_runtime := Node.new()
	named_but_untyped_runtime.name = "V073RuntimeComposition"
	var named_but_untyped_screen := Node.new()
	named_but_untyped_screen.name = "V073SampleGameScreen"
	named_but_untyped_root.add_child(named_but_untyped_runtime)
	named_but_untyped_root.add_child(named_but_untyped_screen)
	_expect_reason(
		Query.from_application(named_but_untyped_root),
		"runtime_composition_missing"
	)
	named_but_untyped_root.free()

	var legacy_root := Node.new()
	var legacy_runtime := FakeRuntimeComposition.new()
	legacy_runtime.name = "V073RuntimeComposition"
	var legacy_screen := FakeGameScreen.new()
	legacy_screen.name = "V073SampleGameScreen"
	legacy_root.add_child(legacy_runtime)
	legacy_root.add_child(legacy_screen)
	_expect_reason(
		Query.from_application(legacy_root),
		"legacy_node_path_only"
	)
	legacy_root.free()

	var root := Node.new()
	var runtime := FakeRuntimeComposition.new()
	var screen := FakeGameScreen.new()
	var telemetry := FakeTelemetryService.new()
	root.add_child(runtime)
	root.add_child(screen)
	root.add_child(telemetry)
	_expect_reason(
		Query.bind(root, null, screen, telemetry),
		"runtime_composition_missing"
	)
	_expect_reason(
		Query.bind(root, runtime, null, telemetry),
		"game_screen_missing"
	)
	_expect_reason(
		Query.bind(root, runtime, screen, null),
		"telemetry_service_missing"
	)

	_set_active_fixture(runtime, screen, telemetry)
	runtime.debug["ruleset_id"] = "v0.7.other"
	_expect_reason(
		Query.bind(root, runtime, screen, telemetry),
		"unsupported_ruleset_context"
	)
	_set_active_fixture(runtime, screen, telemetry)
	runtime.identity["activation_count"] = 0
	_expect_reason(
		Query.bind(root, runtime, screen, telemetry),
		"runtime_not_active"
	)
	_set_active_fixture(runtime, screen, telemetry)
	runtime.debug["last_receipt"] = {
		"accepted": false,
		"intent_kind": "card.queue",
		"session_id": "unrelated.later.receipt",
	}
	_expect_ready(
		Query.bind(root, runtime, screen, telemetry),
		"later business receipt does not revoke a published session"
	)
	_set_active_fixture(runtime, screen, telemetry)
	runtime.identity["ruleset_id"] = ""
	_expect_reason(
		Query.bind(root, runtime, screen, telemetry),
		"unsupported_ruleset_context"
	)
	_set_active_fixture(runtime, screen, telemetry)
	runtime.identity["activation_count"] = "1"
	_expect_reason(
		Query.bind(root, runtime, screen, telemetry),
		"unsupported_ruleset_context"
	)
	_set_active_fixture(runtime, screen, telemetry)
	runtime.debug["new_game_transaction_in_progress"] = true
	_expect_reason(
		Query.bind(root, runtime, screen, telemetry),
		"runtime_not_active"
	)
	_set_active_fixture(runtime, screen, telemetry)
	runtime.debug["connected_domain_count"] = 28
	_expect_reason(
		Query.bind(root, runtime, screen, telemetry),
		"runtime_not_active"
	)
	_set_active_fixture(runtime, screen, telemetry)
	runtime.debug["cutover_domain_count"] = 28
	_expect_reason(
		Query.bind(root, runtime, screen, telemetry),
		"runtime_not_active"
	)
	_set_active_fixture(runtime, screen, telemetry)
	(runtime.debug["runtime"] as Dictionary)[
		"combat_runtime_owner_count"
	] = 2
	_expect_reason(
		Query.bind(root, runtime, screen, telemetry),
		"runtime_not_active"
	)
	_set_active_fixture(runtime, screen, telemetry)
	(runtime.debug["runtime"] as Dictionary)["combat"][
		"combat_state_writer_count"
	] = 2
	_expect_reason(
		Query.bind(root, runtime, screen, telemetry),
		"runtime_not_active"
	)
	_set_active_fixture(runtime, screen, telemetry)
	runtime.debug["connected_domain_count"] = 0
	runtime.debug["cutover_domain_count"] = 0
	_expect_reason(
		Query.bind(root, runtime, screen, telemetry),
		"runtime_not_active"
	)
	_set_active_fixture(runtime, screen, telemetry)
	(runtime.debug["runtime"] as Dictionary)["phase"] = "invented_phase"
	_expect_reason(
		Query.bind(root, runtime, screen, telemetry),
		"runtime_not_active"
	)
	_set_active_fixture(runtime, screen, telemetry)
	(runtime.debug["runtime"] as Dictionary)["combat"]["phase"] = (
		"invented_phase"
	)
	_expect_reason(
		Query.bind(root, runtime, screen, telemetry),
		"runtime_not_active"
	)
	_set_active_fixture(runtime, screen, telemetry)
	(runtime.debug["runtime"] as Dictionary)["combat"]["phase"] = "idle"
	var inactive_combat := Query.bind(
		root,
		runtime,
		screen,
		telemetry
	).call("snapshot") as Dictionary
	_expect(
		str(inactive_combat.get("reason_code", "")) == "runtime_not_active",
		"idle combat rejects runtime readiness"
	)
	_expect(
		not bool(inactive_combat.get("combat_owner_active", true)),
		"idle combat is not projected as active"
	)
	_set_active_fixture(runtime, screen, telemetry)
	(runtime.debug["combat_telemetry"] as Dictionary)[
		"gameplay_owner_count"
	] = 1
	_expect_reason(
		Query.bind(root, runtime, screen, telemetry),
		"runtime_not_active"
	)
	_set_active_fixture(runtime, screen, telemetry)
	screen.debug["application_flow_bound"] = false
	_expect_reason(
		Query.bind(root, runtime, screen, telemetry),
		"game_screen_missing"
	)
	_set_active_fixture(runtime, screen, telemetry)
	telemetry.debug["schema"] = "UnknownTelemetryDebugV1"
	_expect_reason(
		Query.bind(root, runtime, screen, telemetry),
		"unsupported_ruleset_context"
	)
	_set_active_fixture(runtime, screen, telemetry)
	telemetry.debug["source_session_id"] = 1
	_expect_reason(
		Query.bind(root, runtime, screen, telemetry),
		"unsupported_ruleset_context"
	)
	_set_active_fixture(runtime, screen, telemetry)
	telemetry.debug["ready"] = false
	_expect_reason(
		Query.bind(root, runtime, screen, telemetry),
		"telemetry_service_missing"
	)
	_set_active_fixture(runtime, screen, telemetry)
	telemetry.debug["source_session_id"] = "session.fixture.other"
	_expect_reason(
		Query.bind(root, runtime, screen, telemetry),
		"telemetry_service_missing"
	)
	_set_active_fixture(runtime, screen, telemetry)
	telemetry.debug["source_flow_instance_id"] = runtime.get_instance_id() + 1
	_expect_reason(
		Query.bind(root, runtime, screen, telemetry),
		"telemetry_service_missing"
	)
	_set_active_fixture(runtime, screen, telemetry)
	telemetry.debug["source_screen_instance_id"] = screen.get_instance_id() + 1
	_expect_reason(
		Query.bind(root, runtime, screen, telemetry),
		"telemetry_service_missing"
	)
	_set_active_fixture(runtime, screen, telemetry)
	telemetry.debug["source_ruleset_id"] = "v0.7.other"
	_expect_reason(
		Query.bind(root, runtime, screen, telemetry),
		"unsupported_ruleset_context"
	)
	_set_active_fixture(runtime, screen, telemetry)
	var ready := Query.bind(
		root,
		runtime,
		screen,
		telemetry
	).call("snapshot") as Dictionary
	_expect(bool(ready.get("ready", false)), "active typed context is ready")
	_expect(str(ready.get("reason_code", "")) == "ready", "ready reason is explicit")
	_expect(str(ready.get("ruleset_id", "")) == "v0.7.5", "ruleset is projected")
	_expect(str(ready.get("session_state", "")) == "committed", "session commit is projected")
	_expect(bool(ready.get("runtime_active", false)), "runtime active is projected")
	_expect(bool(ready.get("game_screen_ready", false)), "screen readiness is projected")
	_expect(bool(ready.get("telemetry_ready", false)), "telemetry readiness is projected")
	_expect(bool(ready.get("combat_owner_active", false)), "combat owner activity is projected")
	var failed_context := GlobeSupport._failed_main_context(
		"runtime_not_active"
	)
	var helper_state := {"checks": 0, "failures": []}
	_expect(
		not failed_context.is_empty()
		and not GlobeSupport._context_ready(
			helper_state,
			failed_context,
			"failure dictionary remains failed"
		)
		and int(helper_state.get("checks", 0)) == 1
		and (helper_state.get("failures", []) as Array).size() == 1,
		"nonempty failed main-context dictionary is never treated as success"
	)
	root.free()
	_finish()


func _set_active_fixture(
	runtime: FakeRuntimeComposition,
	screen: FakeGameScreen,
	telemetry: FakeTelemetryService
) -> void:
	runtime.identity = {
		"ruleset_id": "v0.7.5",
		"last_session_id": "session.fixture.1",
		"activation_count": 1,
		"published_activation_count": 1,
		"activation_transaction_stage": "idle",
		"pending_initialization_rollback": false,
	}
	runtime.debug = {
		"schema": "V075RuntimeCompositionDebugV1",
		"ruleset_id": "v0.7.5",
		"composition_ready": true,
		"ruleset_owner_count": 1,
		"gameplay_owner_count": 1,
		"combat_runtime_owner_count": 1,
		"combat_state_writer_count": 1,
		"combat_telemetry_service_count": 1,
		"combat_telemetry_gameplay_owner_count": 0,
		"connected_domain_count": 29,
		"cutover_domain_count": 29,
		"new_game_publication_count": 1,
		"last_published_session_id": "session.fixture.1",
		"last_receipt": {
			"accepted": true,
			"session_id": "session.fixture.1",
		},
		"new_game_transaction_stage": "idle",
		"new_game_transaction_in_progress": false,
		"pending_initialization_rollback": false,
		"runtime": {
			"ruleset_id": "v0.7.5",
			"match_id": "match.fixture.1",
			"phase": "submission",
			"active_rule_owner_count": 1,
			"combat_runtime_owner_count": 1,
			"combat_state_writer_count": 1,
			"connected_domain_count": 29,
			"cutover_domain_count": 29,
			"combat_telemetry_gameplay_owner_count": 0,
			"combat_telemetry_rng_owner_count": 0,
			"combat_telemetry_world_mutation_count": 0,
			"new_game_transaction_stage": "idle",
			"new_game_transaction_in_progress": false,
			"pending_initialization_rollback": false,
			"combat": {
				"schema": "V075CombatRuntimeDebugV1",
				"ruleset_id": "v0.7.5",
				"initialized": true,
				"phase": "batch_active",
				"combat_runtime_owner_count": 1,
				"combat_state_writer_count": 1,
				"connected_domain_count": 6,
				"cutover_domain_count": 6,
				"initialization_transaction_active": false,
			},
		},
		"combat_telemetry": {
			"schema": "V075CombatTelemetryServiceDebugV1",
			"ruleset_id": "v0.7.5",
			"gameplay_owner_count": 0,
			"rng_owner_count": 0,
			"world_mutation_count": 0,
		},
	}
	screen.debug = {
		"schema": "V075SampleGameScreenCombatDebugV1",
		"ruleset_id": "v0.7.5",
		"application_flow_bound": true,
	}
	telemetry.debug = {
		"schema": "V073PlaytestTelemetryDebugV1",
		"ready": true,
		"session_id": "telemetry.fixture.1",
		"source_session_id": "session.fixture.1",
		"source_ruleset_id": "v0.7.5",
		"source_flow_instance_id": runtime.get_instance_id(),
		"source_screen_instance_id": screen.get_instance_id(),
		"gameplay_owner_count": 0,
		"rng_owner_count": 0,
		"world_mutation_count": 0,
	}


func _expect_reason(query: Query, reason_code: String) -> void:
	var snapshot := query.call("snapshot") as Dictionary
	_expect(not bool(snapshot.get("ready", true)), "%s is rejected" % reason_code)
	_expect(
		str(snapshot.get("reason_code", "")) == reason_code,
		"%s reason is exact" % reason_code
	)


func _expect_ready(query: Query, message: String) -> void:
	var snapshot := query.call("snapshot") as Dictionary
	_expect(
		bool(snapshot.get("ready", false))
		and str(snapshot.get("reason_code", "")) == "ready",
		message
	)


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	var passed := _failures.is_empty()
	print("GAME_RUNTIME_CONTEXT_QUERY_TEST|status=%s|passed=%d|total=%d|details=%s" % [
		"PASS" if passed else "FAIL",
		_checks - _failures.size(),
		_checks,
		JSON.stringify(_failures),
	])
	quit(0 if passed else 1)
