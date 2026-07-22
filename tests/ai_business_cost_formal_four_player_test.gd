extends SceneTree

const MAIN_SCENE := preload("res://scenes/main.tscn")
const FAIL_ONCE_PUBLIC_LOG_PORT := preload("res://scripts/tools/ai_business_cost_fail_once_public_log_port.gd")

var _checks := 0
var _failures: Array[String] = []
var _command_sequence := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var main := MAIN_SCENE.instantiate()
	main.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(main)
	await _wait_frames(3)
	var services := main.get_node("RuntimeServices")
	var coordinator := services.get_node("RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator
	var draft := services.get_node("NewGameSetupDraftService") as NewGameSetupDraftService
	var commands := services.get_node("SetupDraftCommandPort") as SetupDraftCommandPort
	var transaction := services.get_node("SessionStartTransactionCoordinator") as SessionStartTransactionCoordinator
	var session := coordinator.get_node("GameSessionRuntimeController") as GameSessionRuntimeController
	var rng := coordinator.get_node("RunRngService") as RunRngService
	var world := coordinator.world_session_state()
	var ai := coordinator.get_node("AiRuntimeController") as AiRuntimeController
	var market := coordinator.get_node("ProductMarketRuntimeController") as ProductMarketRuntimeController
	var monster := coordinator.get_node("MonsterRuntimeController") as MonsterRuntimeController
	var query := coordinator.get_node("MonsterWagerCashCommitmentQueryPort") as MonsterWagerCashCommitmentQueryPort
	var cash_port := coordinator.get_node("AiBusinessCostCashPort") as AiBusinessCostCashPort
	var runtime_loop := coordinator.get_node("RuntimeLoop") as RuntimeLoop
	var simulation_step := coordinator.get_node("RuntimePhaseCoordinator/RuntimeSimulationStep") as RuntimeSimulationStep
	var authority := simulation_step.simulation_mutation_authority()
	var public_log_owner := coordinator.get_node("TablePresentationQueryPorts/PublicLogPresentationOwner") as PublicLogPresentationOwner
	_expect(coordinator != null and runtime_loop != null and simulation_step != null, "formal main composes one RuntimeLoop and RuntimeSimulationStep")
	rng.set_seed(20260722)
	_set_integer(draft, commands, SetupDraftCommand.KIND_SET_PLAYER_COUNT, 4)
	_set_integer(draft, commands, SetupDraftCommand.KIND_SET_AI_PLAYER_COUNT, 3)
	var request := SessionStartRequest.create(
		"ai-business-formal-four-player",
		draft.draft_snapshot(),
		session.session_start_revision(),
		"focused_test"
	)
	var start := transaction.start_session(request)
	_expect(start != null and start.applied, "formal four-player SessionStartTransaction commits")
	_expect(world.players.size() == 4 and not bool((world.players[0] as Dictionary).get("is_ai", true)), "formal roster contains one human and three AI seats")
	_expect(bool((world.players[1] as Dictionary).get("is_ai", false)) and bool((world.players[2] as Dictionary).get("is_ai", false)) and bool((world.players[3] as Dictionary).get("is_ai", false)), "formal rival seats are authoritative AI actors")

	var target_index := _install_public_ai_city_fixture(world, 1)
	_expect(target_index >= 0, "formal world exposes one deterministic AI-owned product city fact")
	var product_id := _city_product(world, target_index)
	var region_id := str((world.districts[target_index] as Dictionary).get("region_id", "")) if target_index >= 0 else ""
	var production_policy := ai.policy_profile as AiPolicyProfileResource
	production_policy.business_action_chance_percent = 100
	production_policy.business_action_max_per_cycle = 1
	ai.configure({"ruleset_id": "v0.4"}, production_policy)
	_expect(int(ai.RIVAL_BUSINESS_ACTION_COST) == 90 and cash_port.authoritative_cost_cents() == 9000, "formal AI and typed cash port agree on the 90-unit authoritative cost")

	# Scenario A: a real RuntimeLoop frame reaches the real ProductMarket cycle.
	var cash_before_a := int((world.players[1] as Dictionary).get("cash_cents", 0))
	var finalize_before_a := int(market.ai_business_market_pressure_debug_snapshot().get("finalize_call_count", 0))
	var log_before_a := _event_count(public_log_owner, "ai_business_market_pressure_resolved")
	market.market_timer = 0.0
	main.process_mode = Node.PROCESS_MODE_INHERIT
	await _wait_frames(4)
	main.process_mode = Node.PROCESS_MODE_DISABLED
	var player_after_a := world.players[1] as Dictionary
	_expect(int(player_after_a.get("cash_cents", 0)) == cash_before_a - 9000, "formal RuntimeLoop market cycle debits the AI exactly once")
	_expect(int(market.ai_business_market_pressure_debug_snapshot().get("finalize_call_count", 0)) == finalize_before_a + 1, "formal RuntimeLoop market cycle finalizes one business effect")
	_expect(_event_count(public_log_owner, "ai_business_market_pressure_resolved") == log_before_a + 1, "formal success publishes one typed public event")
	_expect(_region_clue_count(world, target_index) == 1, "formal success leaves one persistent public inference clue")
	var mutation_rows := simulation_step.determinism_audit.recent_mutations(32)
	_expect(_has_mutation_kind(mutation_rows, "ai_business_cost_debit"), "formal success is recorded inside SimulationMutationAuthority")
	var loop_debug := runtime_loop.debug_snapshot()
	_expect(bool(loop_debug.get("frame_owner", false)) and int(loop_debug.get("frame_index", 0)) >= 4, "formal RuntimeLoop is the real frame owner for the exercised market cycle")

	# Scenario C: two identical production intents in one active step remain exact-once.
	market.business_cycle_count += 1
	var manual_step := simulation_step.current_step_index() + 1
	var opened := authority.begin_step(manual_step)
	var action := {"kind": "price_pump", "policy_kind": "price_pump", "product": product_id, "own_city": target_index, "score": 100}
	var cash_before_c := int((world.players[1] as Dictionary).get("cash_cents", 0))
	var finalize_before_c := int(market.ai_business_market_pressure_debug_snapshot().get("finalize_call_count", 0))
	var first_apply := bool(ai.call("_execute_rival_business_action_transaction", 1, action, 1)) if bool(opened.get("opened", false)) else false
	var duplicate_apply := bool(ai.call("_execute_rival_business_action_transaction", 1, action, 1)) if bool(opened.get("opened", false)) else true
	authority.end_step()
	_expect(first_apply and not duplicate_apply, "formal production nodes accept one intent and reject its duplicate")
	_expect(int((world.players[1] as Dictionary).get("cash_cents", 0)) == cash_before_c - 9000, "formal duplicate intent applies one cash debit total")
	_expect(int(market.ai_business_market_pressure_debug_snapshot().get("finalize_call_count", 0)) == finalize_before_c + 1, "formal duplicate intent applies one market effect total")

	# Scenario B: create a real unresolved monster wager, close only the decision
	# window, and prove its committed cash remains unavailable during the next
	# real ProductMarket cycle.
	_set_player_cash(world, 1, 9000)
	monster.auto_monsters = [
		{"uid": 7001, "slot": 0, "name": "QA怪兽A", "position": target_index, "world_position": Vector2(100, 100), "hp": 100000, "max_hp": 100000, "rank": 1, "down": false, "actions": []},
		{"uid": 7002, "slot": 1, "name": "QA怪兽B", "position": target_index, "world_position": Vector2(120, 100), "hp": 100000, "max_hp": 100000, "rank": 1, "down": false, "actions": []},
	]
	monster.active_monster_wagers.clear()
	var wager_id := int(monster.call("_open_monster_wager_for_pair", 0, 1, "formal typed-cash QA", {}))
	_expect(wager_id > 0, "formal MonsterRuntimeController opens a real wager")
	var wager_index := int(monster.call("_monster_wager_entry_index_by_id", wager_id))
	var wager := monster.active_monster_wagers[wager_index] as Dictionary if wager_index >= 0 else {}
	var base_percent := int(wager.get("base_percent", 5))
	var side := str(((wager.get("competitors", []) as Array)[0] as Dictionary).get("side", "a")) if not (wager.get("competitors", []) as Array).is_empty() else "a"
	for player_index in range(4):
		var decision := monster.monster_wager_decision_snapshot_for_actor(wager_id, player_index)
		if str((decision.get("viewer_decision", {}) as Dictionary).get("side", "")).is_empty():
			monster.submit_monster_wager_response(wager_id, player_index, StringName(side), base_percent, player_index != 0)
	var commitment_before := query.private_cash_availability_snapshot(1)
	_expect(bool(commitment_before.get("valid", false)) and int(commitment_before.get("reserved_cents", 0)) > 0 and int(commitment_before.get("available_cents", 9000)) < 9000, "real unresolved wager reserves part of the AI cash")
	var cash_before_b := int((world.players[1] as Dictionary).get("cash_cents", 0))
	var spend_before_b := int((world.players[1] as Dictionary).get("total_business_spend", 0))
	var finalize_before_b := int(market.ai_business_market_pressure_debug_snapshot().get("finalize_call_count", 0))
	var log_before_b := _event_count(public_log_owner, "ai_business_market_pressure_resolved")
	market.market_timer = 0.0
	main.process_mode = Node.PROCESS_MODE_INHERIT
	await _wait_frames(4)
	main.process_mode = Node.PROCESS_MODE_DISABLED
	var commitment_after := query.private_cash_availability_snapshot(1)
	_expect(int((world.players[1] as Dictionary).get("cash_cents", 0)) == cash_before_b and int((world.players[1] as Dictionary).get("total_business_spend", 0)) == spend_before_b, "formal committed-wager rejection applies zero cash mutation")
	_expect(int(market.ai_business_market_pressure_debug_snapshot().get("finalize_call_count", 0)) == finalize_before_b and _event_count(public_log_owner, "ai_business_market_pressure_resolved") == log_before_b, "formal committed-wager rejection applies zero business effect or public event")
	_expect(int(commitment_after.get("reserved_cents", 0)) == int(commitment_before.get("reserved_cents", -1)), "business rejection neither settles nor cancels the real wager commitment")

	# Scenario D: the scene contains the port, but UI and a human actor do not
	# possess the opaque production capability.
	var forged_context := cash_port.private_request_context(AiBusinessCostCapability.new(), 0)
	_expect(not bool(forged_context.get("authorized", true)) and str(forged_context.get("reason_code", "")) == "ai_business_cost_capability_rejected", "human/UI callers cannot obtain AI cash authority with a forged capability")
	var public_text := JSON.stringify(public_log_owner.recent_public_entries(32)).to_lower()
	_expect(not public_text.contains("cash_cents") and not public_text.contains("reserved_cents") and not public_text.contains("available_cents") \
		and not public_text.contains("receipt_id") and not public_text.contains("ai-business:"), "formal public logs expose no AI cash, wager commitment, or internal transaction identity")
	var game_screen_source := FileAccess.get_file_as_string("res://scripts/ui/game_screen.gd")
	_expect(not game_screen_source.contains("AiBusinessCostCapability") and not game_screen_source.contains("AiBusinessCostCashPort"), "production GameScreen has no capability or cash-port dependency")

	# Fault-only production path: an economically committed action still counts,
	# an unresolved public tail blocks new-session checkpoint capture, and the
	# typed owner drain recovers before any checkpoint can be accepted.
	monster.active_monster_wagers.clear()
	_set_player_cash(world, 1, 100000)
	market.business_cycle_count += 1
	var fail_once_port := FAIL_ONCE_PUBLIC_LOG_PORT.new() as PublicLogProducerPort
	fail_once_port.configure(public_log_owner)
	market.set_table_presentation_log_port(fail_once_port, coordinator.get_node("WorldEffectiveClockRuntimeController") as WorldEffectiveClockRuntimeController)
	manual_step = simulation_step.current_step_index() + 1
	opened = authority.begin_step(manual_step)
	var pending_action := bool(ai.call("_execute_rival_business_action_transaction", 1, action, 2)) if bool(opened.get("opened", false)) else false
	authority.end_step()
	_expect(pending_action and int(market.ai_business_market_pressure_debug_snapshot().get("finalizing_count", 0)) == 1, "formal fail-once public target keeps the committed action successful and publication pending")
	market.set_table_presentation_log_port(null, coordinator.get_node("WorldEffectiveClockRuntimeController") as WorldEffectiveClockRuntimeController)
	var blocked_checkpoint := coordinator.capture_new_session_checkpoint()
	_expect(not bool(blocked_checkpoint.get("captured", true)) and str(blocked_checkpoint.get("owner_id", "")) == "product_market", "new-session checkpoint capture fails closed while ProductMarket publication remains pending")
	market.set_table_presentation_log_port(public_log_owner.get_parent().get_node("PublicLogProducerPort") as PublicLogProducerPort, coordinator.get_node("WorldEffectiveClockRuntimeController") as WorldEffectiveClockRuntimeController)
	var recovered_checkpoint := coordinator.capture_new_session_checkpoint()
	_expect(bool(recovered_checkpoint.get("captured", false)) and int(market.ai_business_market_pressure_debug_snapshot().get("finalizing_count", -1)) == 0, "owner maintenance drains publication before accepting the recovered new-session checkpoint")
	fail_once_port.queue_free()

	main.queue_free()
	await process_frame
	_finish()


func _set_integer(draft: NewGameSetupDraftService, commands: SetupDraftCommandPort, kind: StringName, value: int) -> void:
	_command_sequence += 1
	var revision := int(draft.draft_snapshot().get("draft_revision", -1))
	var command := SetupDraftCommand.create("ai-business-formal:%d" % _command_sequence, kind, revision, value, -1, "focused_test")
	var receipt := commands.submit_command(command)
	_expect(receipt != null and receipt.applied, "formal setup command %s=%d applies" % [kind, value])


func _install_public_ai_city_fixture(world: WorldSessionState, owner_index: int) -> int:
	var districts := world.districts.duplicate(true)
	for index in range(districts.size()):
		if not (districts[index] is Dictionary):
			continue
		var district := districts[index] as Dictionary
		if bool(district.get("destroyed", false)) or bool(district.get("is_ocean", false)):
			continue
		var product_id := str((district.get("products", []) as Array)[0]) if not (district.get("products", []) as Array).is_empty() else str(ProductMarketRuntimeController.PRODUCT_CATALOG[0])
		district["city"] = {
			"active": true,
			"owner": owner_index,
			"products": [{"name": product_id}],
			"demands": [],
			"public_clues": [],
		}
		districts[index] = district
		world.replace_districts(districts, true)
		return index
	return -1


func _city_product(world: WorldSessionState, district_index: int) -> String:
	if district_index < 0:
		return ""
	var city := (world.districts[district_index] as Dictionary).get("city", {}) as Dictionary
	var products := city.get("products", []) as Array
	return str((products[0] as Dictionary).get("name", "")) if not products.is_empty() and products[0] is Dictionary else ""


func _set_player_cash(world: WorldSessionState, player_index: int, cash_cents: int) -> void:
	var players := world.players.duplicate(true)
	var player := (players[player_index] as Dictionary).duplicate(true)
	player["cash_cents"] = cash_cents
	player["cash"] = floori(float(cash_cents) / float(WorldSessionState.CASH_CENTS_PER_UNIT))
	players[player_index] = player
	world.replace_players(players, true)


func _region_clue_count(world: WorldSessionState, district_index: int) -> int:
	if district_index < 0:
		return 0
	var city := (world.districts[district_index] as Dictionary).get("city", {}) as Dictionary
	return (city.get("public_clues", []) as Array).size() if city.get("public_clues", []) is Array else 0


func _event_count(owner: PublicLogPresentationOwner, event_kind: String) -> int:
	var count := 0
	for row_variant in owner.recent_public_entries(90):
		if row_variant is Dictionary and str((row_variant as Dictionary).get("event_kind", "")) == event_kind:
			count += 1
	return count


func _has_mutation_kind(rows: Array, command_type: String) -> bool:
	for row_variant in rows:
		if row_variant is Dictionary and str((row_variant as Dictionary).get("command_type", "")) == command_type:
			return true
	return false


func _wait_frames(count: int) -> void:
	for _index in range(count):
		await process_frame


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	print("AI_BUSINESS_COST_FORMAL_FOUR_PLAYER_TEST|status=%s|checks=%d|failures=%d|details=%s" % [
		"PASS" if _failures.is_empty() else "FAIL",
		_checks,
		_failures.size(),
		JSON.stringify(_failures),
	])
	quit(0 if _failures.is_empty() else 1)
