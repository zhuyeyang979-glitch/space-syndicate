extends Node

const MAIN_SCENE := preload("res://scenes/main.tscn")
const BenchScript := preload("res://scripts/tools/card_inventory_runtime_characterization_bench.gd")
const MARKET_FIXTURE := preload("res://tests/product_market_save_v2_test_fixture.gd")
const BENCH_SOURCE_PATH := "res://scripts/tools/card_inventory_runtime_characterization_bench.gd"
const MAIN_SOURCE_PATH := "res://scripts/main.gd"
const REQUEST_SOURCE_PATH := "res://scripts/runtime/session_start_request.gd"
const COORDINATOR_PATH := "RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator"

var _checks := 0
var _failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_source_contract()
	await _test_forty_session_transactions()
	_finish()


func _test_source_contract() -> void:
	var bench_source := FileAccess.get_file_as_string(BENCH_SOURCE_PATH)
	var main_source := FileAccess.get_file_as_string(MAIN_SOURCE_PATH)
	var request_source := FileAccess.get_file_as_string(REQUEST_SOURCE_PATH)
	var reset_helper := _function_source(bench_source, "_reset_runtime_session_via_transaction")
	var suite_body := _function_source(bench_source, "run_characterization_suite")
	_expect(not bench_source.contains("_new_game"), "Card Inventory Bench contains no retired Main._new_game reference")
	_expect(not main_source.contains("func _new_game(") and not main_source.contains("func new_game("), "Main carries no new-game compatibility wrapper")
	_expect(not reset_helper.is_empty(), "transactional Bench reset helper is statically auditable")
	_expect(reset_helper.contains("SessionStartTransactionCoordinator") and reset_helper.contains("transaction.start_session(request)"), "Bench uses the public SessionStartTransactionCoordinator entry")
	_expect(reset_helper.contains("SessionStartRequest.create(") and reset_helper.contains("draft.draft_snapshot()") and reset_helper.contains("game_session.session_start_revision()"), "Bench request binds the current draft and active-session revision")
	_expect(reset_helper.contains("card-inventory-bench-reset:%d:%d:%d") and reset_helper.contains("_session_reset_sequence"), "Bench request identity binds its sequence, draft revision, and active-session revision")
	_expect(reset_helper.contains("SOURCE_CONTEXT_CARD_INVENTORY_BENCH") and request_source.contains("SOURCE_CONTEXT_CARD_INVENTORY_BENCH"), "the explicit Card Inventory Bench request context is allowlisted")
	_expect(reset_helper.contains("receipt.accepted") and reset_helper.contains("receipt.applied") and reset_helper.contains("session_start_committed"), "Bench gates every case on the authoritative success receipt")
	var fail_closed_index := suite_body.find("if not bool(session_start.get(\"ok\", false))")
	var case_run_index := suite_body.find("_run_case(case_id)")
	_expect(reset_helper.contains("_session_start_failure(") and fail_closed_index >= 0 and case_run_index > fail_closed_index, "session-start failure prevents the case body from running")
	_expect(not reset_helper.contains("apply_new_session_plan") and not reset_helper.contains("reset_state") and not reset_helper.contains("restore_state"), "Bench reset neither bypasses the transaction nor invokes owner resets")
	_expect(not reset_helper.contains(".players =") and not reset_helper.contains("replace_players") and not reset_helper.contains("replace_districts"), "Bench reset performs no direct World bootstrap mutation")
	_expect(not reset_helper.contains("_on_start_requested") and reset_helper.contains("menu_lifecycle.close_to_table()"), "Bench avoids private setup UI callbacks and returns through public MenuLifecycle")
	_expect(bench_source.contains("cross_case_card_inventory_leak_count") and bench_source.contains("cross_case_queue_leak_count") and bench_source.contains("cross_case_transaction_leak_count"), "Bench emits explicit cross-case isolation evidence")
	_expect(bench_source.contains("@export var auto_run := true"), "Bench auto-run remains enabled")
	var bench := BenchScript.new()
	var case_ids: Array = bench.all_cases()
	var unique_ids: Dictionary = {}
	for case_id_variant in case_ids:
		unique_ids[str(case_id_variant)] = true
	_expect(case_ids.size() == 40 and unique_ids.size() == 40, "Bench retains all 40 unique characterization and cutover cases")
	bench.free()


func _test_forty_session_transactions() -> void:
	var main := MAIN_SCENE.instantiate()
	main.process_mode = Node.PROCESS_MODE_DISABLED
	get_tree().root.add_child(main)
	await get_tree().process_frame
	var coordinator := main.get_node_or_null(COORDINATOR_PATH) as GameRuntimeCoordinator
	var draft := main.get_node_or_null("RuntimeServices/NewGameSetupDraftService") as NewGameSetupDraftService
	var transaction := main.get_node_or_null("RuntimeServices/SessionStartTransactionCoordinator") as SessionStartTransactionCoordinator
	var session := main.get_node_or_null(COORDINATOR_PATH + "/GameSessionRuntimeController") as GameSessionRuntimeController
	var lifecycle := main.get_node_or_null("RuntimeServices/MenuLifecycleApplicationFlowController") as MenuLifecycleApplicationFlowController
	var runtime_loop := main.get_node_or_null(COORDINATOR_PATH + "/RuntimeLoop") as RuntimeLoop
	var world := coordinator.world_session_state() if coordinator != null else null
	var rng := coordinator.run_rng_service() if coordinator != null else null
	var product_market := coordinator.product_market_runtime_controller() if coordinator != null else null
	_expect(coordinator != null and draft != null and transaction != null and session != null and lifecycle != null and runtime_loop != null and world != null and rng != null and product_market != null, "production Session Start composition is available")
	if coordinator == null or draft == null or transaction == null or session == null \
			or lifecycle == null or runtime_loop == null or world == null or rng == null or product_market == null:
		main.queue_free()
		await get_tree().process_frame
		return

	var request_ids: Dictionary = {}
	var session_revisions: Dictionary = {}
	var successful_starts := 0
	for case_index in range(40):
		var setup := draft.draft_snapshot()
		var draft_revision := int(setup.get("draft_revision", -1))
		var revision_before := session.session_start_revision()
		var request_id := "card-inventory-bench-reset:%d:%d:%d" % [case_index + 1, draft_revision, revision_before]
		_expect(not request_ids.has(request_id), "case %d request ID is unique before submission" % (case_index + 1))
		request_ids[request_id] = true
		var before_operation := transaction.operation_snapshot()
		var request := SessionStartRequest.create(
			request_id,
			setup,
			revision_before,
			SessionStartRequest.SOURCE_CONTEXT_CARD_INVENTORY_BENCH
		)
		_expect(request.is_valid(), "case %d SessionStartRequest is valid" % (case_index + 1))
		var receipt := transaction.start_session(request)
		var after_operation := transaction.operation_snapshot()
		var receipt_green := receipt != null \
			and receipt.request_id == request_id \
			and receipt.accepted and receipt.applied \
			and not receipt.idempotent and not receipt.in_progress \
			and receipt.reason_code == "session_start_committed" \
			and receipt.failing_stage.is_empty() \
			and not receipt.plan_fingerprint.is_empty()
		_expect(receipt_green, "case %d commits through the authoritative transaction" % (case_index + 1))
		if not receipt_green:
			break
		successful_starts += 1
		var revision_after := session.session_start_revision()
		var revision_key := str(revision_after)
		_expect(revision_after != revision_before and not session_revisions.has(revision_key), "case %d produces one unique session revision transition" % (case_index + 1))
		session_revisions[revision_key] = true
		var operation_delta := int(after_operation.get("operation_sequence", -1)) - int(before_operation.get("operation_sequence", -1))
		var terminal_delta := int(after_operation.get("terminal_request_count", -1)) - int(before_operation.get("terminal_request_count", -1))
		_expect(operation_delta == 1 and terminal_delta == 1 and receipt.operation_sequence == int(after_operation.get("operation_sequence", -1)), "case %d advances transaction sequence and terminal journal exactly once" % (case_index + 1))
		var details: Dictionary = receipt.details
		var session_gate := int(details.get("session_revision", -1)) == revision_after \
			and world.players.size() >= 3 and world.districts.size() > 0 \
			and session.session_state() in [GameSessionRuntimeController.STATE_RUNNING, GameSessionRuntimeController.STATE_PAUSED] \
			and bool(coordinator.debug_snapshot().get("coordinator_ready", false)) \
			and not bool(runtime_loop.debug_snapshot().get("session_start_barrier_held", true))
		_expect(session_gate, "case %d satisfies World, Session, Coordinator, and RuntimeLoop postconditions" % (case_index + 1))
		var isolation := _isolation_snapshot(coordinator, world)
		_expect(bool(isolation.get("clean", false)), "case %d starts without prior card, queue, transaction, or annotation state: %s" % [case_index + 1, JSON.stringify(isolation)])
		draft.reset_to_defaults()
		_expect(lifecycle.close_to_table(), "case %d closes the menu through public lifecycle" % (case_index + 1))
		if case_index < 39:
			_dirty_previous_case_state(coordinator, world, case_index)

	_expect(successful_starts == 40, "all 40 focused transaction starts succeed")
	_expect(request_ids.size() == 40 and session_revisions.size() == 40, "40 request IDs and 40 resulting session revisions are unique")
	_expect(int(transaction.operation_snapshot().get("terminal_request_count", -1)) == 40, "no request is replayed or collided in the 40-case sequence")

	var world_before := world.to_save_data()
	var rng_before := rng.capture_plan_checkpoint()
	var session_before := session.capture_new_session_checkpoint()
	MARKET_FIXTURE.seed_non_default_runtime(product_market, 40)
	var product_market_wire_before := product_market.to_save_data()
	var product_market_runtime_before := MARKET_FIXTURE.authoritative_runtime_snapshot(product_market)
	var product_market_timer_bits_before := MARKET_FIXTURE.timer_bits(product_market_wire_before)
	transaction.set_test_fault_stage("after_runtime_apply")
	var rollback_setup := draft.draft_snapshot()
	var rollback_request := SessionStartRequest.create(
		"card-inventory-bench-rollback-contract",
		rollback_setup,
		session.session_start_revision(),
		SessionStartRequest.SOURCE_CONTEXT_CARD_INVENTORY_BENCH
	)
	var failed := transaction.start_session(rollback_request)
	transaction.set_test_fault_stage("")
	_expect(failed != null and not failed.applied and failed.rollback_complete and failed.failing_stage == "runtime_apply", "transaction-owned failure rolls the attempted replacement back")
	_expect(world.to_save_data() == world_before and rng.capture_plan_checkpoint() == rng_before and session.capture_new_session_checkpoint() == session_before, "failed transaction preserves the prior World, RNG, and GameSession state")
	var product_market_wire_after := product_market.to_save_data()
	_expect(product_market_wire_after == product_market_wire_before and MARKET_FIXTURE.authoritative_runtime_snapshot(product_market) == product_market_runtime_before, "failed transaction restores exact Product Market Save wire and normalized authoritative runtime state")
	_expect(MARKET_FIXTURE.timer_bits(product_market_wire_after) == product_market_timer_bits_before, "failed transaction restores exact Product Market timer bits")
	_expect(not bool(runtime_loop.debug_snapshot().get("session_start_barrier_held", true)), "failed transaction releases the RuntimeLoop barrier")
	main.queue_free()
	await get_tree().process_frame


func _isolation_snapshot(coordinator: GameRuntimeCoordinator, world: WorldSessionState) -> Dictionary:
	var card_clean := true
	var player_ledgers_clean := true
	for player_variant in world.players:
		if not (player_variant is Dictionary):
			card_clean = false
			continue
		var player: Dictionary = player_variant
		var slots: Array = player.get("slots", []) if player.get("slots", []) is Array else []
		card_clean = card_clean and slots.size() == 1 and int(player.get("card_purchase_count", -1)) == 0 and int(player.get("total_card_spend", -1)) == 0
		player_ledgers_clean = player_ledgers_clean \
			and (player.get("economic_ledger", []) as Array).is_empty() \
			and (player.get("v06_transaction_ledger", []) as Array).is_empty()
		for slot_variant in slots:
			if not (slot_variant is Dictionary) or bool((slot_variant as Dictionary).get("queued_for_resolution", false)) or float((slot_variant as Dictionary).get("lock_left", 0.0)) > 0.0:
				card_clean = false
	var inventory_debug: Dictionary = coordinator.card_inventory_debug()
	for counter in ["receive_plan_count", "remove_plan_count", "lock_plan_count", "transfer_plan_count", "queue_commit_plan_count", "queue_committed_count", "commit_attempt_count", "committed_count", "rejected_count"]:
		card_clean = card_clean and int(inventory_debug.get(counter, -1)) == 0
	var queue_node := coordinator.get_node("CardResolutionQueueRuntimeService")
	var queue_debug: Dictionary = queue_node.call("debug_snapshot")
	var queue_clean := int(queue_debug.get("current_count", -1)) == 0 \
		and not bool(queue_debug.get("active_present", true)) \
		and int(queue_debug.get("next_count", -1)) == 0 \
		and int(queue_debug.get("resolution_sequence", -1)) == 0
	var execution := coordinator.get_node("CardResolutionExecutionRuntimeService")
	var execution_debug: Dictionary = execution.call("debug_snapshot")
	var commodity_debug: Dictionary = coordinator.get_node("CommodityCardInventoryRuntimeController").call("debug_snapshot")
	var cash_debug: Dictionary = coordinator.get_node("AiBusinessCostCashPort").call("debug_snapshot")
	var transaction_clean := player_ledgers_clean \
		and int(execution.get("_transaction_sequence")) == 0 \
		and int(execution_debug.get("inflight_count", -1)) == 0 \
		and int(execution_debug.get("pending_settlement_count", -1)) == 0 \
		and int(execution_debug.get("completed_count", -1)) == 0 \
		and int(commodity_debug.get("transaction_journal_count", -1)) == 0 \
		and int(cash_debug.get("journal_size", -1)) == 0
	var annotation_debug: Dictionary = coordinator.get_node("CardHistoryPrivateAnnotationService").call("debug_snapshot")
	var history_debug: Dictionary = coordinator.get_node("CardResolutionHistoryRuntimeService").call("debug_snapshot")
	var annotation_clean := int(annotation_debug.get("viewer_count", -1)) == 0 \
		and int(annotation_debug.get("revision", -1)) == 0 \
		and int(annotation_debug.get("notification_count", -1)) == 0 \
		and int(history_debug.get("history_count", -1)) == 0 \
		and int(history_debug.get("lineage_count", -1)) == 0
	return {
		"clean": card_clean and queue_clean and transaction_clean and annotation_clean,
		"card_clean": card_clean,
		"queue_clean": queue_clean,
		"transaction_clean": transaction_clean,
		"annotation_clean": annotation_clean,
	}


func _dirty_previous_case_state(coordinator: GameRuntimeCoordinator, world: WorldSessionState, case_index: int) -> void:
	var players: Array = world.players.duplicate(true)
	var player: Dictionary = players[0]
	var slots: Array = (player.get("slots", []) as Array).duplicate(true)
	var starter: Dictionary = (slots[0] as Dictionary).duplicate(true)
	starter["queued_for_resolution"] = true
	starter["lock_left"] = 5.0
	slots[0] = starter
	player["slots"] = slots
	player["economic_ledger"] = [{"detail": "prior-case-%d" % case_index}]
	player["v06_transaction_ledger"] = [{"request_id": "prior-case-%d" % case_index}]
	players[0] = player
	world.players = players
	coordinator.get_node("CardResolutionQueueRuntimeService").call("replace_current_queue", [{"resolution_id": case_index + 1}])
	coordinator.get_node("CardResolutionExecutionRuntimeService").set("_transaction_sequence", case_index + 1)
	coordinator.get_node("CardHistoryPrivateAnnotationService").set("_annotations_by_viewer", {"0": {}})
	coordinator.get_node("CardHistoryPrivateAnnotationService").set("_revision", case_index + 1)


func _function_source(source: String, function_name: String) -> String:
	var start := source.find("func %s(" % function_name)
	if start < 0:
		return ""
	var next := source.find("\nfunc ", start + 1)
	return source.substr(start) if next < 0 else source.substr(start, next - start)


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	print("CARD_INVENTORY_BENCH_SESSION_START_TRANSACTION_CONTRACT_TEST|status=%s|checks=%d|failures=%d" % ["PASS" if _failures.is_empty() else "FAIL", _checks, _failures.size()])
	if not _failures.is_empty():
		push_error("Card Inventory Bench transaction contract failures:\n- " + "\n- ".join(_failures))
	get_tree().quit(0 if _failures.is_empty() else 1)
