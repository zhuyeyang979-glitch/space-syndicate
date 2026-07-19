extends SceneTree

const MAIN_SCENE := preload("res://scenes/main.tscn")

var _checks := 0
var _failures: Array[String] = []
var _command_sequence := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_application_flow_boundary()
	var main := MAIN_SCENE.instantiate()
	main.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(main)
	await process_frame
	var services := main.get_node("RuntimeServices")
	var coordinator := services.get_node("RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator
	var draft := services.get_node("NewGameSetupDraftService") as NewGameSetupDraftService
	var commands := services.get_node("SetupDraftCommandPort") as SetupDraftCommandPort
	var query := services.get_node("NewGameSetupViewerQueryPort") as NewGameSetupViewerQueryPort
	var builder := services.get_node("SessionStartPlanBuilder") as SessionStartPlanBuilder
	var transaction := services.get_node("SessionStartTransactionCoordinator") as SessionStartTransactionCoordinator
	var world := coordinator.world_session_state()
	var rng := coordinator.get_node("RunRngService") as RunRngService
	var session := coordinator.get_node("GameSessionRuntimeController") as GameSessionRuntimeController
	var application_flow := services.get_node("ApplicationFlowPort") as ApplicationFlowPort
	var setup_flow := services.get_node("SetupApplicationFlowController") as SetupApplicationFlowController
	var flow_before := setup_flow.debug_snapshot()
	application_flow.submit_action("setup")
	var flow_after := setup_flow.debug_snapshot()
	_expect(int(flow_after.get("open_count", 0)) == int(flow_before.get("open_count", 0)) + 1, "scene-composed setup intent opens the dedicated flow exactly once")
	_expect(int(flow_after.get("query_count", 0)) == int(flow_before.get("query_count", 0)) + 1, "scene-composed setup intent queries once")
	_expect(int(flow_after.get("page_apply_count", 0)) == int(flow_before.get("page_apply_count", 0)) + 1, "scene-composed setup intent applies one page")

	_test_pre_activation_receipt_identity(draft, session, transaction)
	_test_draft_commands(draft, commands)
	_test_query_and_plan(draft, query, builder, rng, session)
	var successful_requests: Array[SessionStartRequest] = []
	for player_count in range(3, 9):
		_set_integer(draft, commands, SetupDraftCommand.KIND_SET_PLAYER_COUNT, player_count)
		_set_integer(draft, commands, SetupDraftCommand.KIND_SET_AI_PLAYER_COUNT, player_count - 1)
		var request := SessionStartRequest.create(
			"focused-start-%d" % player_count,
			draft.draft_snapshot(),
			session.session_start_revision(),
			"focused_test"
		)
		var expected_plan_result := builder.build_plan(request, rng.capture_plan_checkpoint())
		var expected_plan := expected_plan_result.get("plan") as SessionStartPlan
		var receipt := transaction.start_session(request)
		_expect(receipt != null and receipt.applied, "%d-player start commits: %s" % [player_count, receipt.reason_code if receipt != null else "missing_receipt"])
		_expect(world.players.size() == player_count, "%d-player world has exact roster" % player_count)
		_expect(_unique_player_indices(world.players) == player_count, "%d-player roster indices are unique" % player_count)
		_expect(_unique_role_indices(world.players) == player_count, "%d-player roles are unique" % player_count)
		_expect(_trace_order_is_atomic(receipt.trace), "%d-player trace keeps all preflight/checkpoints before apply and GameSession last" % player_count)
		_expect(expected_plan != null and rng.capture_plan_checkpoint() == expected_plan.rng_terminal_cursor, "%d-player apply consumes exactly the RNG cursor staged by the plan" % player_count)
		if player_count == 3:
			var commit_only: Dictionary = receipt.details.get("commit_only", {})
			_expect(bool(commit_only.get("committed", false)) and int(commit_only.get("rng_draw_delta", -1)) == 0, "commit-only publication consumes zero RNG")
			_expect(int(commit_only.get("gameplay_mutation_count", -1)) == 0, "commit-only publication mutates neither ProductMarket nor Weather authority")
		successful_requests.append(request)

	var last_request := successful_requests.back() as SessionStartRequest
	var replay_world := world.to_save_data()
	var replay_rng := rng.capture_plan_checkpoint()
	var replay_commit_counts := coordinator.new_session_start_debug_snapshot()
	var replay := transaction.start_session(last_request)
	_expect(replay != null and replay.applied and replay.idempotent, "successful request replay returns the original idempotent receipt")
	_expect(world.to_save_data() == replay_world and rng.capture_plan_checkpoint() == replay_rng, "successful request replay applies no world or RNG mutation")
	_expect(coordinator.new_session_start_debug_snapshot() == replay_commit_counts, "successful request replay produces no duplicate commit side effect or presentation refresh")
	_expect(replay.request_id == last_request.request_id, "successful idempotent replay preserves request identity")

	_set_integer(draft, commands, SetupDraftCommand.KIND_SET_PLAYER_COUNT, 5)
	_set_integer(draft, commands, SetupDraftCommand.KIND_SET_AI_PLAYER_COUNT, 4)
	var before_world := world.to_save_data()
	var before_rng := rng.capture_plan_checkpoint()
	var before_session := session.capture_new_session_checkpoint()
	transaction.set_test_fault_stage("after_runtime_apply")
	var failed_request := SessionStartRequest.create("focused-active-isolation", draft.draft_snapshot(), session.session_start_revision(), "focused_test")
	var failed := transaction.start_session(failed_request)
	transaction.set_test_fault_stage("")
	_expect(failed != null and not failed.applied and failed.rollback_complete, "fault after runtime apply rolls every owner back: %s" % JSON.stringify(failed.details if failed != null else {}))
	_expect(world.to_save_data() == before_world, "failed replacement preserves active WorldSession")
	_expect(rng.capture_plan_checkpoint() == before_rng, "failed replacement preserves live RNG")
	_expect(session.capture_new_session_checkpoint() == before_session, "failed replacement preserves GameSession lifecycle")
	_expect(world.players.size() == 8 and session.session_state() == GameSessionRuntimeController.STATE_RUNNING, "failed replacement leaves the old eight-player table running")

	var presentation_state := coordinator.card_supply_presentation_state()
	presentation_state.selected_market_skill = "active-table-card"
	presentation_state.previewed_district_card = "active-table-preview"
	presentation_state.open_district = 3
	presentation_state.open_player = 2
	var presentation_before := presentation_state.snapshot()
	var product_market := coordinator.get_node("ProductMarketRuntimeController") as ProductMarketRuntimeController
	var weather := coordinator.get_node("WeatherRuntimeController") as WeatherRuntimeController
	var market_before := product_market.to_save_data()
	var weather_before := weather.to_save_data()
	coordinator.set_new_session_test_fault_stage("after_weather_market_apply")
	var weather_market_request := SessionStartRequest.create("focused-weather-market-rollback", draft.draft_snapshot(), session.session_start_revision(), "focused_test")
	var weather_market_failed := transaction.start_session(weather_market_request)
	coordinator.set_new_session_test_fault_stage("")
	_expect(weather_market_failed != null and not weather_market_failed.applied and weather_market_failed.rollback_complete, "fault after planned market/weather apply completes reverse rollback")
	_expect(product_market.to_save_data() == market_before, "market rollback restores the old active-session authority")
	_expect(weather.to_save_data() == weather_before, "weather rollback restores the old active-session authority")
	_expect(rng.capture_plan_checkpoint() == before_rng and session.capture_new_session_checkpoint() == before_session, "market/weather fault preserves RNG and GameSession")

	before_world = world.to_save_data()
	before_rng = rng.capture_plan_checkpoint()
	before_session = session.capture_new_session_checkpoint()
	coordinator.set_new_session_test_fault_stage("after_infrastructure_apply")
	var partial_request := SessionStartRequest.create("focused-cross-owner-rollback", draft.draft_snapshot(), session.session_start_revision(), "focused_test")
	var partial := transaction.start_session(partial_request)
	coordinator.set_new_session_test_fault_stage("")
	_expect(partial != null and not partial.applied and partial.rollback_complete, "infrastructure-stage partial apply rolls all runtime owners back")
	_expect(world.to_save_data() == before_world and rng.capture_plan_checkpoint() == before_rng, "cross-owner partial apply preserves active world and RNG")
	_expect(session.capture_new_session_checkpoint() == before_session, "cross-owner partial apply preserves GameSession")
	_expect(presentation_state.snapshot() == presentation_before, "failed replacement preserves active table card-supply presentation state")

	_assert_transaction_fault_preserves_active_session(
		transaction,
		coordinator,
		world,
		rng,
		session,
		draft,
		"after_checkpoints",
		"focused-fault-after-checkpoints",
		false
	)
	_assert_transaction_fault_preserves_active_session(
		transaction,
		coordinator,
		world,
		rng,
		session,
		draft,
		"after_game_session_apply",
		"focused-fault-after-game-session",
		true
	)
	_assert_transaction_fault_preserves_active_session(
		transaction,
		coordinator,
		world,
		rng,
		session,
		draft,
		"after_rng_commit",
		"focused-fault-after-rng-commit",
		true
	)

	var commit_counts_before := coordinator.new_session_start_debug_snapshot()
	var concurrent_receipts: Array = []
	var concurrent_request := SessionStartRequest.create("focused-concurrent-receipt", draft.draft_snapshot(), session.session_start_revision(), "focused_test")
	rng.plan_state_committed.connect(func(_state: int, _draw_delta: int) -> void:
		concurrent_receipts.append(transaction.start_session(concurrent_request))
	, CONNECT_ONE_SHOT)
	var committed_request := SessionStartRequest.create("focused-commit-presentation-reset", draft.draft_snapshot(), session.session_start_revision(), "focused_test")
	var committed := transaction.start_session(committed_request)
	var commit_counts_after := coordinator.new_session_start_debug_snapshot()
	_expect(committed != null and committed.applied, "replacement commits after the injected owner fault is cleared")
	_expect(presentation_state.snapshot() == {"selected_market_skill": "", "previewed_district_card": "", "open_district": -1, "open_player": -1}, "successful commit resets relocated card-supply presentation state")
	_expect(int(commit_counts_after.get("commit_side_effect_count", 0)) == int(commit_counts_before.get("commit_side_effect_count", 0)) + 1, "successful start crosses the commit side-effect barrier once")
	_expect(int(commit_counts_after.get("presentation_refresh_count", 0)) == int(commit_counts_before.get("presentation_refresh_count", 0)) + 1, "successful start requests one presentation refresh")
	var concurrent_receipt := concurrent_receipts.front() as SessionStartReceipt if not concurrent_receipts.is_empty() else null
	_expect(concurrent_receipt != null and concurrent_receipt.in_progress and concurrent_receipt.request_id == concurrent_request.request_id, "concurrent pre-activation failure preserves the submitted request identity")

	_test_main_source_negative()
	main.queue_free()
	await process_frame
	_finish()


func _test_application_flow_boundary() -> void:
	var port := ApplicationFlowPort.new()
	root.add_child(port)
	var setup_count := [0]
	var generic_count := [0]
	port.setup_requested.connect(func() -> void: setup_count[0] += 1)
	port.action_requested.connect(func(_action: String) -> void: generic_count[0] += 1)
	port.submit_action("setup")
	var debug := port.debug_snapshot()
	_expect(setup_count[0] == 1 and generic_count[0] == 0, "setup uses one dedicated application signal and zero generic emissions")
	_expect(bool(debug.get("setup_signal_boundary", false)) and not bool(debug.get("setup_to_main", true)), "setup application boundary reports no Main route")
	port.queue_free()


func _test_pre_activation_receipt_identity(draft: NewGameSetupDraftService, session: GameSessionRuntimeController, transaction: SessionStartTransactionCoordinator) -> void:
	var invalid := SessionStartRequest.create("receipt-invalid", draft.draft_snapshot(), session.session_start_revision(), "focused_test")
	invalid.source_context = "invalid_context"
	var invalid_receipt := transaction.start_session(invalid)
	_expect(invalid_receipt.request_id == invalid.request_id and invalid_receipt.reason_code == "session_start_request_invalid", "invalid request receipt preserves input identity")

	var detached := SessionStartTransactionCoordinator.new()
	root.add_child(detached)
	var dependency_request := SessionStartRequest.create("receipt-dependencies", draft.draft_snapshot(), session.session_start_revision(), "focused_test")
	var dependency_receipt := detached.start_session(dependency_request)
	_expect(dependency_receipt.request_id == dependency_request.request_id and dependency_receipt.reason_code == "session_start_dependencies_unavailable", "dependency failure receipt preserves input identity")
	detached.queue_free()

	var stale_draft := SessionStartRequest.create("receipt-stale-draft", draft.draft_snapshot(), session.session_start_revision(), "focused_test")
	stale_draft.expected_draft_revision += 1
	var stale_draft_receipt := transaction.start_session(stale_draft)
	_expect(stale_draft_receipt.request_id == stale_draft.request_id and stale_draft_receipt.reason_code == "session_start_draft_revision_stale", "stale draft receipt preserves input identity")
	var stale_replay := transaction.start_session(stale_draft)
	_expect(stale_replay.idempotent and stale_replay.request_id == stale_draft.request_id, "replayed terminal failure preserves request identity")

	var collision := SessionStartRequest.create(stale_draft.request_id, draft.draft_snapshot(), session.session_start_revision(), "focused_test")
	var collision_receipt := transaction.start_session(collision)
	_expect(collision_receipt.request_id == collision.request_id and collision_receipt.reason_code == "session_start_request_collision", "request collision receipt preserves colliding input identity")

	var stale_session := SessionStartRequest.create("receipt-stale-session", draft.draft_snapshot(), session.session_start_revision() + 1, "focused_test")
	var stale_session_receipt := transaction.start_session(stale_session)
	_expect(stale_session_receipt.request_id == stale_session.request_id and stale_session_receipt.reason_code == "active_session_revision_stale", "stale active-session receipt preserves input identity")


func _test_draft_commands(draft: NewGameSetupDraftService, commands: SetupDraftCommandPort) -> void:
	var before := draft.draft_snapshot()
	var command := SetupDraftCommand.create("focused-command-once", SetupDraftCommand.KIND_SET_CHALLENGE_DEPTH, int(before.get("draft_revision", -1)), 2, -1, "focused_test")
	var first := commands.submit_command(command)
	var revision_after_first := int(draft.draft_snapshot().get("draft_revision", -1))
	var replay := commands.submit_command(command)
	_expect(first.applied and replay.idempotent and not replay.applied, "draft command applies once and replays as an idempotent receipt")
	_expect(int(draft.draft_snapshot().get("draft_revision", -1)) == revision_after_first, "draft command replay does not bump revision")
	var collision := SetupDraftCommand.create("focused-command-once", SetupDraftCommand.KIND_SET_CHALLENGE_DEPTH, revision_after_first, 3, -1, "focused_test")
	_expect(commands.submit_command(collision).reason_code == "setup_command_id_collision", "same draft command ID with different payload fails closed")
	var stale := SetupDraftCommand.create("focused-command-stale", SetupDraftCommand.KIND_SET_CHALLENGE_DEPTH, revision_after_first - 1, 3, -1, "focused_test")
	_expect(commands.submit_command(stale).reason_code == "setup_draft_revision_stale", "stale draft revision fails closed")
	draft.reset_to_defaults()


func _test_query_and_plan(draft: NewGameSetupDraftService, query: NewGameSetupViewerQueryPort, builder: SessionStartPlanBuilder, rng: RunRngService, session: GameSessionRuntimeController) -> void:
	var rng_before := rng.capture_plan_checkpoint()
	var page := query.page_snapshot(1280.0)
	_expect(bool(page.get("valid", false)) and (page.get("seats", []) as Array).size() == 4, "setup query returns a detached four-seat page")
	_expect(rng.capture_plan_checkpoint() == rng_before, "setup query consumes zero live RNG")
	var request := SessionStartRequest.create("focused-plan-determinism", draft.draft_snapshot(), session.session_start_revision(), "focused_test")
	var first := builder.build_plan(request, rng_before)
	var second := builder.build_plan(request, rng_before)
	var first_plan := first.get("plan") as SessionStartPlan
	var second_plan := second.get("plan") as SessionStartPlan
	_expect(first_plan != null and second_plan != null and first_plan.plan_fingerprint == second_plan.plan_fingerprint, "same draft and RNG checkpoint produce the same plan fingerprint")
	_expect(rng.capture_plan_checkpoint() == rng_before, "plan construction consumes zero live RNG")
	var expected_market_draws := ProductMarketRuntimeController.PRODUCT_CATALOG.size() * 2
	_expect(first_plan != null and first_plan.initial_market_refresh_draw_count == expected_market_draws, "plan stages both complete initial ProductMarket refresh draw sets")
	_expect(first_plan != null and first_plan.initial_weather_draw_count == 3, "plan stages region, definition and next-generation weather draws")
	_expect(first_plan != null and int(first_plan.rng_terminal_cursor.get("draw_count", 0)) - int(first_plan.rng_checkpoint.get("draw_count", 0)) >= expected_market_draws + 3, "terminal RNG cursor includes every planned market/weather draw")
	_expect(first_plan != null and (first_plan.weather_state.get("events", []) as Array).size() == 1, "plan carries one authoritative initial weather forecast")


func _set_integer(draft: NewGameSetupDraftService, commands: SetupDraftCommandPort, kind: StringName, value: int) -> void:
	_command_sequence += 1
	var revision := int(draft.draft_snapshot().get("draft_revision", -1))
	var command := SetupDraftCommand.create("focused-value-%d" % _command_sequence, kind, revision, value, -1, "focused_test")
	var receipt := commands.submit_command(command)
	_expect(receipt.applied, "draft %s=%d applies" % [kind, value])


func _unique_player_indices(players: Array) -> int:
	var values := {}
	for player_variant in players:
		if player_variant is Dictionary:
			values[int((player_variant as Dictionary).get("id", -1))] = true
	return values.size()


func _unique_role_indices(players: Array) -> int:
	var values := {}
	for player_variant in players:
		if player_variant is Dictionary:
			values[int((player_variant as Dictionary).get("role_index", -1))] = true
	return values.size()


func _trace_order_is_atomic(trace: Array[String]) -> bool:
	var first_apply := trace.find("apply:world")
	var last_preflight := trace.find("preflight:session")
	var last_checkpoint := trace.find("checkpoint:session")
	var runtime_apply := trace.find("apply:runtime")
	var session_apply := trace.find("apply:game_session:last")
	return last_preflight >= 0 and last_checkpoint > last_preflight and first_apply > last_checkpoint and runtime_apply > first_apply and session_apply > runtime_apply


func _assert_transaction_fault_preserves_active_session(
	transaction: SessionStartTransactionCoordinator,
	coordinator: GameRuntimeCoordinator,
	world: WorldSessionState,
	rng: RunRngService,
	session: GameSessionRuntimeController,
	draft: NewGameSetupDraftService,
	fault_stage: String,
	request_id: String,
	expects_rollback: bool
) -> void:
	var world_before := world.to_save_data()
	var rng_before := rng.capture_plan_checkpoint()
	var session_before := session.capture_new_session_checkpoint()
	var runtime_before := coordinator.capture_new_session_checkpoint()
	var commit_counts_before := coordinator.new_session_start_debug_snapshot()
	transaction.set_test_fault_stage(fault_stage)
	var request := SessionStartRequest.create(request_id, draft.draft_snapshot(), session.session_start_revision(), "focused_test")
	var receipt := transaction.start_session(request)
	transaction.set_test_fault_stage("")
	_expect(receipt != null and not receipt.applied, "%s fault fails the replacement transaction" % fault_stage)
	_expect(receipt != null and receipt.reason_code == "session_start_fault_%s" % fault_stage, "%s fault returns its precise fail-closed reason" % fault_stage)
	if expects_rollback:
		_expect(receipt != null and receipt.rollback_complete, "%s fault completes reverse rollback" % fault_stage)
	else:
		_expect(receipt != null and receipt.trace.find("apply:world") == -1, "%s fault occurs before the first owner apply" % fault_stage)
	_expect(world.to_save_data() == world_before, "%s fault preserves active WorldSession" % fault_stage)
	_expect(rng.capture_plan_checkpoint() == rng_before, "%s fault preserves live RNG" % fault_stage)
	_expect(session.capture_new_session_checkpoint() == session_before, "%s fault preserves GameSession lifecycle" % fault_stage)
	_expect(coordinator.capture_new_session_checkpoint() == runtime_before, "%s fault preserves all runtime owner checkpoints" % fault_stage)
	_expect(coordinator.new_session_start_debug_snapshot() == commit_counts_before, "%s fault crosses no commit-only side-effect barrier" % fault_stage)
	var runtime_loop := coordinator.get_node_or_null("RuntimeLoop") as RuntimeLoop
	_expect(runtime_loop != null and not bool(runtime_loop.debug_snapshot().get("session_start_barrier_held", true)), "%s fault releases the RuntimeLoop barrier" % fault_stage)


func _test_main_source_negative() -> void:
	# Keep test-only source inspection distinct from production Main references.
	var source := FileAccess.get_file_as_string("res://scripts/" + "main.gd")
	for retired in ["configured_player_count", "configured_ai_player_count", "configured_roguelike_depth", "_open_new_game_setup_menu", "_confirm_start_new_run_from_setup", "func _new_game(", "NewGameSetupPageScene"]:
		_expect(not source.contains(retired), "Main no longer owns retired setup symbol %s" % retired)
	var coordinator_source := FileAccess.get_file_as_string("res://scripts/runtime/game_runtime_coordinator.gd")
	var commit_start := coordinator_source.find("func commit_new_session_side_effects(")
	var commit_end := coordinator_source.find("func set_new_session_test_fault_stage(", commit_start)
	var commit_body := coordinator_source.substr(commit_start, commit_end - commit_start) if commit_start >= 0 and commit_end > commit_start else ""
	_expect(not commit_body.is_empty(), "commit-only session-start body remains statically auditable")
	_expect(not commit_body.contains("refresh_prices") and not commit_body.contains("schedule_next_forecast"), "commit-only session-start body contains no market refresh or weather scheduling mutation")


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	print("SETUP_SESSION_START_TRANSACTION_CUTOVER_TEST|status=%s|checks=%d|failures=%d" % ["PASS" if _failures.is_empty() else "FAIL", _checks, _failures.size()])
	if not _failures.is_empty():
		push_error("Setup session-start cutover failures:\n- " + "\n- ".join(_failures))
	quit(0 if _failures.is_empty() else 1)
