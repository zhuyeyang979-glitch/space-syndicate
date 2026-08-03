extends Node

const MAIN_SCENE := preload("res://scenes/main.tscn")
const BENCH_SCRIPT := preload("res://scripts/tools/card_inventory_runtime_characterization_bench.gd")
const BENCH_SOURCE_PATH := "res://scripts/tools/card_inventory_runtime_characterization_bench.gd"
const MAIN_SOURCE_PATH := "res://scripts/main.gd"
const COORDINATOR_PATH := "RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator"

var _contract_passed := 0
var _contract_total := 0
var _mutation_passed := 0
var _mutation_total := 0
var _privacy_passed := 0
var _privacy_total := 0
var _failures: Array[String] = []
var _observed_results: Dictionary = {}


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_source_contract()
	var detached_bench := BENCH_SCRIPT.new()
	var missing_query_variant: Variant = detached_bench.call("_discardable_slots_for_player_via_runtime", 0)
	var missing_query: Dictionary = missing_query_variant if missing_query_variant is Dictionary else {}
	_expect_contract(not bool(missing_query.get("valid", true)) and str(missing_query.get("reason_code", "")) == "discardability_coordinator_missing" and (missing_query.get("slots", []) as Array).is_empty(), "missing Coordinator fails closed")
	detached_bench.free()

	var fake_main := Control.new()
	var runtime_services := Node.new()
	runtime_services.name = "RuntimeServices"
	var host := Node.new()
	host.name = "RuntimeControllerHost"
	var empty_coordinator := GameRuntimeCoordinator.new()
	empty_coordinator.name = "GameRuntimeCoordinator"
	fake_main.add_child(runtime_services)
	runtime_services.add_child(host)
	host.add_child(empty_coordinator)
	var service_missing_bench := BENCH_SCRIPT.new()
	service_missing_bench.set("_runtime_main", fake_main)
	var service_missing_variant: Variant = service_missing_bench.call("_discardable_slots_for_player_via_runtime", 0)
	var service_missing: Dictionary = service_missing_variant if service_missing_variant is Dictionary else {}
	_expect_contract(not bool(service_missing.get("valid", true)) and str(service_missing.get("reason_code", "")) == "discardability_service_missing" and (service_missing.get("slots", []) as Array).is_empty(), "missing Card Inventory service fails closed")
	service_missing_bench.free()
	fake_main.free()

	var main := MAIN_SCENE.instantiate()
	main.process_mode = Node.PROCESS_MODE_DISABLED
	get_tree().root.add_child(main)
	await get_tree().process_frame
	var coordinator := main.get_node_or_null(COORDINATOR_PATH) as GameRuntimeCoordinator
	var draft := main.get_node_or_null("RuntimeServices/NewGameSetupDraftService") as NewGameSetupDraftService
	var transaction := main.get_node_or_null("RuntimeServices/SessionStartTransactionCoordinator") as SessionStartTransactionCoordinator
	var session := main.get_node_or_null(COORDINATOR_PATH + "/GameSessionRuntimeController") as GameSessionRuntimeController
	_expect_contract(coordinator != null and draft != null and transaction != null and session != null, "production Session Start and Coordinator composition is available")
	if coordinator == null or draft == null or transaction == null or session == null:
		main.queue_free()
		await get_tree().process_frame
		_finish()
		return
	var request := SessionStartRequest.create(
		"card-inventory-discardability-migration-test",
		draft.draft_snapshot(),
		session.session_start_revision(),
		SessionStartRequest.SOURCE_CONTEXT_CARD_INVENTORY_BENCH
	)
	var receipt := transaction.start_session(request)
	_expect_contract(receipt != null and receipt.accepted and receipt.applied and receipt.reason_code == "session_start_committed", "production Session Start commits before typed Bench queries")
	if receipt == null or not receipt.applied:
		main.queue_free()
		await get_tree().process_frame
		_finish()
		return

	var bench := BENCH_SCRIPT.new()
	bench.auto_run = false
	bench.set("_runtime_main", main)
	var world := coordinator.world_session_state()
	_expect_contract(world != null and world.players.size() > 0, "production World player slots are available")
	if world != null and world.players.size() > 0:
		_exercise_query_case(bench, coordinator, world, [
			_card("private.queued", true, 0.0),
			_card("private.ordinary", false, 0.0),
		], [1], "queued")
		_exercise_query_case(bench, coordinator, world, [
			_card("private.locked", false, 8.0),
			_card("private.ordinary", false, 0.0),
		], [1], "cooldown")
		_exercise_query_case(bench, coordinator, world, [
			_card("private.queued", true, 0.0),
			_card("private.locked", false, 6.0),
			_card("private.ordinary", false, 0.0),
		], [2], "cutover")

		var invalid_variant: Variant = bench.call("_discardable_slots_for_player_via_runtime", world.players.size())
		var invalid: Dictionary = invalid_variant if invalid_variant is Dictionary else {}
		_expect_contract(not bool(invalid.get("valid", true)) and str(invalid.get("reason_code", "")) == "discardability_player_invalid" and (invalid.get("slots", []) as Array).is_empty(), "invalid player index fails closed")
		var negative_variant: Variant = bench.call("_discardable_slots_for_player_via_runtime", -1)
		var negative: Dictionary = negative_variant if negative_variant is Dictionary else {}
		_expect_contract(not bool(negative.get("valid", true)) and str(negative.get("reason_code", "")) == "discardability_player_invalid" and (negative.get("slots", []) as Array).is_empty(), "negative player index fails closed")
		bench.call("_reset_player", 0, [42])
		var malformed_variant: Variant = bench.call("_discardable_slots_for_player_via_runtime", 0)
		var malformed: Dictionary = malformed_variant if malformed_variant is Dictionary else {}
		_expect_contract(not bool(malformed.get("valid", true)) and str(malformed.get("reason_code", "")) == "discardability_world_slot_malformed" and (malformed.get("slots", []) as Array).is_empty(), "malformed real player slot record fails closed")
		var players_without_slots := world.players.duplicate(true)
		var player_without_slots := (players_without_slots[0] as Dictionary).duplicate(true)
		player_without_slots.erase("slots")
		players_without_slots[0] = player_without_slots
		world.players = players_without_slots
		var missing_slots_variant: Variant = bench.call("_discardable_slots_for_player_via_runtime", 0)
		var missing_slots: Dictionary = missing_slots_variant if missing_slots_variant is Dictionary else {}
		_expect_contract(not bool(missing_slots.get("valid", true)) and str(missing_slots.get("reason_code", "")) == "discardability_player_slots_malformed" and (missing_slots.get("slots", []) as Array).is_empty(), "missing player slots field fails closed")

	bench.set("_runtime_main", null)
	bench.free()
	main.queue_free()
	await get_tree().process_frame
	_finish()


func _test_source_contract() -> void:
	var bench_source := FileAccess.get_file_as_string(BENCH_SOURCE_PATH)
	var main_source := FileAccess.get_file_as_string(MAIN_SOURCE_PATH)
	var helper_source := _function_source(bench_source, "_discardable_slots_for_player_via_runtime")
	var queued_source := _function_source(bench_source, "_case_queued_card_not_discardable")
	var cooldown_source := _function_source(bench_source, "_case_cooldown_locked_card_not_discardable")
	var cutover_source := _function_source(bench_source, "_cutover_discardability_owned")
	var retired_main_method := "_" + "discardable_hand_slots_for_purchase"
	_expect_contract(not bench_source.contains(retired_main_method) and not main_source.contains("func %s(" % retired_main_method), "retired Main discardability entrypoint reference count is zero")
	_expect_contract(bench_source.count("func _discardable_slots_for_player_via_runtime(") == 1, "Bench contains exactly one discardability query helper")
	_expect_contract(not helper_source.is_empty() and helper_source.contains("CardInventoryRuntimeService.discardability_facts_from_world_slots") and helper_source.contains("coordinator.card_inventory_discardable_slots(inventory_facts)"), "helper projects real slots and calls the typed Coordinator facade")
	_expect_contract(not helper_source.contains("queued_for_resolution") and not helper_source.contains("lock_left") and not helper_source.contains("counts_toward_hand_limit"), "helper contains no copied discardability filter")
	_expect_contract(queued_source.contains("_discardable_slots_for_player_via_runtime(0)") and cooldown_source.contains("_discardable_slots_for_player_via_runtime(0)") and cutover_source.contains("_discardable_slots_for_player_via_runtime(0)"), "queued, cooldown and cutover cases share the one helper")
	_expect_contract(queued_source.contains("GameRuntimeCoordinator.card_inventory_discardable_slots") and cooldown_source.contains("GameRuntimeCoordinator.card_inventory_discardable_slots") and cutover_source.contains("GameRuntimeCoordinator.card_inventory_discardable_slots"), "all three records name the typed Coordinator source entrypoint")
	_expect_contract(not cutover_source.contains("_card_inventory_snapshot") and bench_source.count("_card_inventory_snapshot") == 2, "cutover removed its Main snapshot while two unrelated snapshot calls remain unchanged")


func _exercise_query_case(bench: Control, coordinator: GameRuntimeCoordinator, world: WorldSessionState, cards: Array, expected_slots: Array, label: String) -> void:
	bench.call("_reset_player", 0, cards)
	var player_before := (world.players[0] as Dictionary).duplicate(true)
	var world_before := world.to_save_data()
	var queue_before := coordinator.card_resolution_queue_debug()
	var inventory_before := coordinator.card_inventory_debug()
	var safety_before := coordinator.save_restore_safety_observation()
	var rng_before := coordinator.run_rng_service().capture_plan_checkpoint()
	var query_variant: Variant = bench.call("_discardable_slots_for_player_via_runtime", 0)
	var query: Dictionary = query_variant if query_variant is Dictionary else {}
	var player_after := (world.players[0] as Dictionary).duplicate(true)
	var world_after := world.to_save_data()
	var queue_after := coordinator.card_resolution_queue_debug()
	var inventory_after := coordinator.card_inventory_debug()
	var safety_after := coordinator.save_restore_safety_observation()
	var rng_after := coordinator.run_rng_service().capture_plan_checkpoint()
	var slots: Array = query.get("slots", []) if query.get("slots", []) is Array else []
	_observed_results[label] = slots.duplicate()
	_expect_contract(bool(query.get("valid", false)) and slots == expected_slots, "%s case returns the exact authoritative slot set" % label)
	_expect_mutation(player_before == player_after, "%s query does not mutate the player" % label)
	_expect_mutation(world_before == world_after, "%s query does not mutate the complete World Save state" % label)
	_expect_mutation(queue_before == queue_after, "%s query does not mutate Queue" % label)
	_expect_mutation(inventory_before == inventory_after, "%s query does not increment Card Inventory counters" % label)
	_expect_mutation(safety_before == safety_after, "%s query does not draw RNG, advance time, write logs or emit feedback" % label)
	_expect_mutation(rng_before == rng_after, "%s query preserves the exact RNG checkpoint" % label)
	if label == "cutover":
		slots.append(999)
		var facts_variant: Variant = query.get("inventory_facts", {})
		if facts_variant is Dictionary:
			(facts_variant as Dictionary)["slots"] = []
		var repeated_variant: Variant = bench.call("_discardable_slots_for_player_via_runtime", 0)
		var repeated: Dictionary = repeated_variant if repeated_variant is Dictionary else {}
		_expect_mutation(bool(repeated.get("valid", false)) and repeated.get("slots", []) == expected_slots and world.to_save_data() == world_before, "query returns detached copies that cannot mutate World or later results")
	_expect_privacy(_data_only(query), "%s query returns pure data" % label)
	var serialized := JSON.stringify(query)
	for card_variant in cards:
		if card_variant is Dictionary:
			_expect_privacy(not serialized.contains(str((card_variant as Dictionary).get("name", ""))), "%s query omits a concrete private card ID" % label)
	_expect_privacy(not serialized.contains("runtime_instance_id") and not serialized.contains("card_id") and not serialized.contains("\"card\""), "%s query omits private card identity fields" % label)


func _card(card_id: String, queued: bool, lock_left: float) -> Dictionary:
	return {
		"name": card_id,
		"kind": "facility",
		"persistent": false,
		"queued_for_resolution": queued,
		"lock_left": lock_left,
	}


func _function_source(source: String, function_name: String) -> String:
	var start := source.find("func %s(" % function_name)
	if start < 0:
		return ""
	var next_instance := source.find("\nfunc ", start + 1)
	var next_static := source.find("\nstatic func ", start + 1)
	var finish := source.length()
	if next_instance >= 0:
		finish = mini(finish, next_instance)
	if next_static >= 0:
		finish = mini(finish, next_static)
	return source.substr(start, finish - start)


func _data_only(value: Variant) -> bool:
	if value == null or value is String or value is StringName or value is bool or value is int or value is float:
		return true
	if value is Array:
		for item in value as Array:
			if not _data_only(item):
				return false
		return true
	if value is Dictionary:
		for key in (value as Dictionary).keys():
			if not _data_only(key) or not _data_only((value as Dictionary).get(key)):
				return false
		return true
	return false


func _expect_contract(condition: bool, message: String) -> void:
	_contract_total += 1
	if condition:
		_contract_passed += 1
	else:
		_failures.append(message)


func _expect_mutation(condition: bool, message: String) -> void:
	_mutation_total += 1
	if condition:
		_mutation_passed += 1
	else:
		_failures.append(message)


func _expect_privacy(condition: bool, message: String) -> void:
	_privacy_total += 1
	if condition:
		_privacy_passed += 1
	else:
		_failures.append(message)


func _finish() -> void:
	var status := "PASS" if _failures.is_empty() else "FAIL"
	print("CARD_INVENTORY_BENCH_DISCARDABILITY_MIGRATION_TEST|status=%s|queued=%s|cooldown=%s|cutover=%s|contract=%d/%d|zero_mutation=%d/%d|privacy=%d/%d|failures=%d" % [
		status,
		JSON.stringify(_observed_results.get("queued", [])),
		JSON.stringify(_observed_results.get("cooldown", [])),
		JSON.stringify(_observed_results.get("cutover", [])),
		_contract_passed,
		_contract_total,
		_mutation_passed,
		_mutation_total,
		_privacy_passed,
		_privacy_total,
		_failures.size(),
	])
	if not _failures.is_empty():
		push_error("Card Inventory Bench discardability migration failures:\n- " + "\n- ".join(_failures))
	get_tree().quit(0 if _failures.is_empty() else 1)
