extends Node

const MAIN_SCENE := preload("res://scenes/main.tscn")
const FIXTURE := preload("res://tests/product_market_save_v2_test_fixture.gd")
const COORDINATOR_PATH := "RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator"

var _checks := 0
var _failures: Array[String] = []
var _faults_completed := 0


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var main := MAIN_SCENE.instantiate()
	main.process_mode = Node.PROCESS_MODE_DISABLED
	get_tree().root.add_child(main)
	await get_tree().process_frame
	var coordinator := main.get_node_or_null(COORDINATOR_PATH) as GameRuntimeCoordinator
	var draft := main.get_node_or_null("RuntimeServices/NewGameSetupDraftService") as NewGameSetupDraftService
	var transaction := main.get_node_or_null("RuntimeServices/SessionStartTransactionCoordinator") as SessionStartTransactionCoordinator
	var session := main.get_node_or_null(COORDINATOR_PATH + "/GameSessionRuntimeController") as GameSessionRuntimeController
	var runtime_loop := main.get_node_or_null(COORDINATOR_PATH + "/RuntimeLoop") as RuntimeLoop
	var world := coordinator.world_session_state() if coordinator != null else null
	var rng := coordinator.run_rng_service() if coordinator != null else null
	var market := coordinator.product_market_runtime_controller() if coordinator != null else null
	_expect(coordinator != null and draft != null and transaction != null and session != null \
			and runtime_loop != null and world != null and rng != null and market != null, "production Session Start composition is available")
	if coordinator == null or draft == null or transaction == null or session == null \
			or runtime_loop == null or world == null or rng == null or market == null:
		main.queue_free()
		await get_tree().process_frame
		_finish()
		return

	var baseline_request := SessionStartRequest.create(
		"product-market-rollback-baseline",
		draft.draft_snapshot(),
		session.session_start_revision(),
		SessionStartRequest.SOURCE_CONTEXT_CARD_INVENTORY_BENCH
	)
	var baseline := transaction.start_session(baseline_request)
	_expect(baseline != null and baseline.applied, "baseline production Session starts before rollback probes")
	if baseline == null or not baseline.applied:
		main.queue_free()
		await get_tree().process_frame
		_finish()
		return
	draft.reset_to_defaults()

	_exercise_fault(coordinator, draft, transaction, session, runtime_loop, world, rng, market, {
		"id": "after-market-apply",
		"runtime_fault": "after_market_apply",
		"expected_stage": "runtime_apply",
		"expected_reason": "new_session_fault_after_market_apply",
	})
	_exercise_fault(coordinator, draft, transaction, session, runtime_loop, world, rng, market, {
		"id": "after-runtime-apply",
		"transaction_fault": "after_runtime_apply",
		"expected_stage": "runtime_apply",
		"expected_reason": "session_start_fault_after_runtime_apply",
	})
	_exercise_fault(coordinator, draft, transaction, session, runtime_loop, world, rng, market, {
		"id": "after-game-session-apply",
		"transaction_fault": "after_game_session_apply",
		"expected_stage": "game_session_apply",
		"expected_reason": "session_start_fault_after_game_session_apply",
	})
	_exercise_fault(coordinator, draft, transaction, session, runtime_loop, world, rng, market, {
		"id": "after-rng-commit",
		"transaction_fault": "after_rng_commit",
		"expected_stage": "rng_commit",
		"expected_reason": "session_start_fault_after_rng_commit",
	})

	main.queue_free()
	await get_tree().process_frame
	_finish()


func _exercise_fault(
	coordinator: GameRuntimeCoordinator,
	draft: NewGameSetupDraftService,
	transaction: SessionStartTransactionCoordinator,
	session: GameSessionRuntimeController,
	runtime_loop: RuntimeLoop,
	world: WorldSessionState,
	rng: RunRngService,
	market: ProductMarketRuntimeController,
	fault: Dictionary
) -> void:
	var fault_index := _faults_completed + 1
	FIXTURE.seed_non_default_runtime(market, fault_index)
	var market_wire_before := market.to_save_data()
	var market_runtime_before := FIXTURE.authoritative_runtime_snapshot(market)
	var timer_bits_before := FIXTURE.timer_bits(market_wire_before)
	var world_before := world.to_save_data()
	var rng_before := rng.capture_plan_checkpoint()
	var session_before := session.capture_new_session_checkpoint()
	var runtime_checkpoint_before := coordinator.capture_new_session_checkpoint()
	var commit_only_before := coordinator.new_session_start_debug_snapshot()
	var market_debug_before := market.debug_snapshot()
	var pressure_debug_before := market.ai_business_market_pressure_debug_snapshot()
	_expect(not market_wire_before.is_empty() and market.business_cycle_count > 0 \
			and market.market_timer != 8.0 and market.futures_position_sequence > 0 \
			and FIXTURE.open_futures_position_count(market) == 1, "%s starts from non-default Product Market authority with one authored open futures position" % str(fault.get("id", "fault")))

	var runtime_fault := str(fault.get("runtime_fault", ""))
	var transaction_fault := str(fault.get("transaction_fault", ""))
	if not runtime_fault.is_empty():
		coordinator.set_new_session_test_fault_stage(runtime_fault)
	if not transaction_fault.is_empty():
		transaction.set_test_fault_stage(transaction_fault)
	var request := SessionStartRequest.create(
		"product-market-rollback-%s" % str(fault.get("id", "fault")),
		draft.draft_snapshot(),
		session.session_start_revision(),
		SessionStartRequest.SOURCE_CONTEXT_CARD_INVENTORY_BENCH
	)
	var receipt := transaction.start_session(request)
	coordinator.set_new_session_test_fault_stage("")
	transaction.set_test_fault_stage("")

	_expect(receipt != null and not receipt.applied and receipt.rollback_complete, "%s completes the authoritative reverse rollback" % str(fault.get("id", "fault")))
	_expect(receipt != null and receipt.failing_stage == str(fault.get("expected_stage", "")) \
			and receipt.reason_code == str(fault.get("expected_reason", "")), "%s preserves the precise failing stage and reason" % str(fault.get("id", "fault")))
	var market_wire_after := market.to_save_data()
	_expect(market_wire_after == market_wire_before, "%s restores exact Product Market Save v2 wire" % str(fault.get("id", "fault")))
	var market_runtime_diff := _first_difference(market_runtime_before, FIXTURE.authoritative_runtime_snapshot(market))
	_expect(market_runtime_diff.is_empty(), "%s restores exact normalized authoritative Product Market runtime state: %s" % [str(fault.get("id", "fault")), market_runtime_diff])
	_expect(FIXTURE.timer_bits(market_wire_after) == timer_bits_before, "%s restores exact market_timer bits" % str(fault.get("id", "fault")))
	_expect(world.to_save_data() == world_before and rng.capture_plan_checkpoint() == rng_before \
			and session.capture_new_session_checkpoint() == session_before, "%s preserves World, RNG, and GameSession" % str(fault.get("id", "fault")))
	_expect(coordinator.capture_new_session_checkpoint() == runtime_checkpoint_before, "%s restores the full saved-owner checkpoint" % str(fault.get("id", "fault")))
	_expect(coordinator.new_session_start_debug_snapshot() == commit_only_before, "%s emits no duplicate commit-only side effect" % str(fault.get("id", "fault")))
	var market_debug_after := market.debug_snapshot()
	var pressure_debug_after := market.ai_business_market_pressure_debug_snapshot()
	_expect(int(market_debug_after.get("futures_open_count", -1)) == int(market_debug_before.get("futures_open_count", -2)) \
			and int(market_debug_after.get("futures_settlement_count", -1)) == int(market_debug_before.get("futures_settlement_count", -2)) \
			and int(pressure_debug_after.get("commit_call_count", -1)) == int(pressure_debug_before.get("commit_call_count", -2)) \
			and int(pressure_debug_after.get("telemetry_metric_count", -1)) == int(pressure_debug_before.get("telemetry_metric_count", -2)), "%s emits no duplicate futures settlement, market pressure, or weather telemetry" % str(fault.get("id", "fault")))
	_expect(not bool(runtime_loop.debug_snapshot().get("session_start_barrier_held", true)), "%s releases the RuntimeLoop barrier" % str(fault.get("id", "fault")))
	var trace: Array[String] = receipt.trace.duplicate() if receipt != null else []
	var rollback_suffix: Array[String] = ["rollback:session", "rollback:runtime", "rollback:world", "rollback:rng", "barrier:released"]
	_expect(trace.size() >= rollback_suffix.size() and trace.slice(trace.size() - rollback_suffix.size()) == rollback_suffix \
			and trace.count("barrier:released") == 1 and trace.find("commit:side_effects") == -1, "%s records the exact rollback suffix with one barrier release" % str(fault.get("id", "fault")))
	var details: Dictionary = receipt.details if receipt != null else {}
	var runtime_restore: Dictionary = details.get("runtime", {}) if details.get("runtime", {}) is Dictionary else {}
	_expect(bool((details.get("session", {}) as Dictionary).get("restored", false)) \
			and bool(runtime_restore.get("restored", false)) \
			and (runtime_restore.get("failures", []) as Array).is_empty() \
			and bool((details.get("world", {}) as Dictionary).get("applied", false)) \
			and bool((details.get("rng", {}) as Dictionary).get("restored", false)), "%s exposes four successful authority restore receipts" % str(fault.get("id", "fault")))
	var operation := transaction.operation_snapshot()
	_expect(str(operation.get("operation_state", "")) == "failed" and str(operation.get("active_request_id", "")).is_empty(), "%s leaves no active transaction identity" % str(fault.get("id", "fault")))
	_faults_completed += 1
	draft.reset_to_defaults()


func _first_difference(left: Variant, right: Variant, path := "$") -> String:
	if typeof(left) != typeof(right):
		return "%s type %s != %s" % [path, type_string(typeof(left)), type_string(typeof(right))]
	if left is Dictionary:
		var left_keys: Array = (left as Dictionary).keys()
		var right_keys: Array = (right as Dictionary).keys()
		left_keys.sort_custom(func(a: Variant, b: Variant) -> bool: return str(a) < str(b))
		right_keys.sort_custom(func(a: Variant, b: Variant) -> bool: return str(a) < str(b))
		if left_keys != right_keys:
			return "%s keys %s != %s" % [path, JSON.stringify(left_keys), JSON.stringify(right_keys)]
		for key in left_keys:
			var nested := _first_difference((left as Dictionary).get(key), (right as Dictionary).get(key), "%s.%s" % [path, str(key)])
			if not nested.is_empty():
				return nested
		return ""
	if left is Array:
		if (left as Array).size() != (right as Array).size():
			return "%s size %d != %d" % [path, (left as Array).size(), (right as Array).size()]
		for index in range((left as Array).size()):
			var nested := _first_difference((left as Array)[index], (right as Array)[index], "%s[%d]" % [path, index])
			if not nested.is_empty():
				return nested
		return ""
	return "" if left == right else "%s %s != %s" % [path, str(left), str(right)]


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	_expect(_faults_completed == 4, "all four Product Market rollback fault stages execute")
	print("SESSION_START_TRANSACTION_PRODUCT_MARKET_ROLLBACK_TEST|status=%s|checks=%d|faults=%d|failures=%d" % ["PASS" if _failures.is_empty() else "FAIL", _checks, _faults_completed, _failures.size()])
	if not _failures.is_empty():
		push_error("Session Start Product Market rollback failures:\n- " + "\n- ".join(_failures))
	get_tree().quit(0 if _failures.is_empty() else 1)
