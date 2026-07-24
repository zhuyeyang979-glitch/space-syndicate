extends Node
class_name AiBusinessCostTypedCashCutoverBench

const RuntimeBalanceModelScript := preload("res://scripts/balance/runtime_balance_model.gd")
const FailOncePublicLogPortScript := preload("res://scripts/tools/ai_business_cost_fail_once_public_log_port.gd")

@export var auto_run := true

@onready var rng: RunRngService = $RunRngService
@onready var world: WorldSessionState = $WorldSessionState
@onready var formula: CardEconomyProductRouteFormulaRuntimeService = $CardEconomyProductRouteFormulaRuntimeService
@onready var market_bridge: ProductMarketRuntimeWorldBridge = $ProductMarketRuntimeWorldBridge
@onready var market: ProductMarketRuntimeController = $ProductMarketRuntimeController
@onready var weather: Node = $QaWeatherRuntimeController
@onready var monster: AiBusinessCostFakeMonsterRuntime = $AiBusinessCostFakeMonsterRuntime
@onready var query: MonsterWagerCashCommitmentQueryPort = $MonsterWagerCashCommitmentQueryPort
@onready var cash: PlayerCashMutationPort = $PlayerCashMutationPort
@onready var session: GameSessionRuntimeController = $GameSessionRuntimeController
@onready var identity: SimulationStateIdentity = $SimulationStateIdentity
@onready var audit: SimulationDeterminismAudit = $SimulationDeterminismAudit
@onready var authority: SimulationMutationAuthority = $SimulationMutationAuthority
@onready var cash_port: AiBusinessCostCashPort = $AiBusinessCostCashPort
@onready var ai_bridge: AiRuntimeWorldBridge = $AiRuntimeWorldBridge
@onready var ai: AiRuntimeController = $AiRuntimeController
@onready var public_log_owner: PublicLogPresentationOwner = $PublicLogPresentationOwner
@onready var public_log_port: PublicLogProducerPort = $PublicLogProducerPort
@onready var world_clock: WorldEffectiveClockRuntimeController = $WorldEffectiveClockRuntimeController

var _balance := RuntimeBalanceModelScript.new()
var _capability: AiBusinessCostCapability
var _step_index := 0
var _checks := 0
var _failures: Array[String] = []
var _telemetry_rows: Array[Dictionary] = []


func _ready() -> void:
	if auto_run and not Engine.is_editor_hint():
		call_deferred("run_suite")


func run_suite() -> Dictionary:
	_checks = 0
	_failures.clear()
	_telemetry_rows.clear()
	audit.bind_identity(identity)
	authority.bind_diagnostics(identity, audit)
	_configure_static_dependencies()
	_case_success_duplicate_and_public_privacy()
	_case_committed_wager_rejection_and_exact_available()
	_case_exact_once_collision_and_stale_guards()
	_case_bounded_journal_owner_replay()
	_case_actor_currency_and_capability_guards()
	_case_policy_fail_closed()
	_case_policy_revision_drift_rejected()
	_case_route_sabotage_remains_fail_closed()
	_case_market_commit_then_cash_failure_rolls_back()
	_case_publication_preflight_and_retry()
	_case_production_pending_publication_counts_action()
	var report := debug_snapshot()
	print("AI_BUSINESS_COST_TYPED_CASH_CUTOVER_BENCH|status=%s|checks=%d|failures=%d|details=%s" % [
		str(report.get("status", "FAIL")),
		_checks,
		_failures.size(),
		JSON.stringify(_failures),
	])
	return report


func debug_snapshot() -> Dictionary:
	return {
		"bench_complete": _checks > 0,
		"status": "PASS" if _failures.is_empty() else "FAIL",
		"check_count": _checks,
		"failure_count": _failures.size(),
		"failures": _failures.duplicate(),
		"cash_port": cash_port.debug_snapshot(),
		"cash_owner": cash.debug_snapshot(),
		"market_transaction": market.ai_business_market_pressure_debug_snapshot(),
		"mutation_authority": authority.debug_snapshot(),
	}


func observe_public_metric(event_id: int, metric_key: String, value: float) -> void:
	_telemetry_rows.append({"event_id": event_id, "metric_key": metric_key, "value": value})


func _balance_product_price_model(base_price: int, supply: int, demand: int, disrupted: int, monster_pressure: int, weather_modifier: int, volatility: int, noise: float, growth_multiplier: float) -> Dictionary:
	return _balance.product_price_model(base_price, supply, demand, disrupted, monster_pressure, weather_modifier, volatility, noise, growth_multiplier)


func _balance_product_price_step_cap(volatility: int, base_price: int) -> int:
	return int(_balance.product_price_step_cap(volatility, base_price))


func _configure_static_dependencies() -> void:
	market_bridge.bind_world(self)
	market_bridge.set_rng_service(rng)
	market_bridge.set_world_session_state(world)
	market.set_world_bridge(market_bridge)
	market.set_weather_runtime_controller(weather)
	market.set_weather_telemetry_runtime_service(self)
	public_log_port.configure(public_log_owner)
	world_clock.configure()
	market.set_table_presentation_log_port(public_log_port, world_clock)
	monster.set_qa_world_session_state(world)
	query.configure(world, monster)
	cash.configure(world, query, authority)
	ai_bridge.bind_world(self)
	ai.set_world_bridge(ai_bridge)
	ai.set_run_rng_service(rng)
	ai.set_monster_runtime_controller(monster)
	ai.set_product_market_runtime_controller(market)
	ai.configure({"ruleset_id": "v0.4"}, ai.policy_profile)


func _reset_case(case_id: String, ai_cash_cents: int, reserved_cents: int = 0) -> void:
	if authority.is_active():
		authority.end_step()
	_step_index += 1
	rng.set_seed(20260722)
	world.replace_players([
		_player(false, 100000, false),
		_player(true, ai_cash_cents, false),
		_player(true, 100000, true),
		_player(true, 100000, false),
	], true)
	world.replace_districts([{
		"region_id": "region-public-0",
		"destroyed": false,
		"products": [str(ProductMarketRuntimeController.PRODUCT_CATALOG[0])],
		"demands": [str(ProductMarketRuntimeController.PRODUCT_CATALOG[1])],
		"city": {
			"active": true,
			"owner": 1,
			"products": [{"name": str(ProductMarketRuntimeController.PRODUCT_CATALOG[0])}],
			"demands": [],
		},
	}], true)
	monster.qa_reserved_cents_by_player.clear()
	monster.set_qa_reserved_cents(1, reserved_cents)
	formula.configure({"ruleset_id": "v0.4"})
	market.configure({"ruleset_id": "v0.4"}, formula)
	market.reset_state()
	public_log_owner.reset_state()
	world_clock.reset_state()
	session.reset_state()
	session.configure({"ruleset_id": "v0.4"}, {})
	session.begin_session({
		"session_id": "qa-ai-business-%s" % case_id,
		"scenario_id": "qa-ai-business",
		"seed": 20260722,
		"player_count": 4,
	})
	authority.begin_step(_step_index)
	_capability = AiBusinessCostCapability.new()
	cash_port.configure(
		world,
		query,
		cash,
		session,
		authority,
		ai.policy_profile as AiPolicyProfileResource,
		market,
		_capability
	)
	ai.set_ai_business_cost_cash_port(cash_port, _capability)
	_telemetry_rows.clear()


func _player(is_ai: bool, cash_cents: int, eliminated: bool) -> Dictionary:
	return {
		"seat_type": "ai" if is_ai else "human",
		"is_ai": is_ai,
		"eliminated": eliminated,
		"cash_cents": cash_cents,
		"cash": floori(float(cash_cents) / 100.0),
		"cash_history": [floori(float(cash_cents) / 100.0)],
		"economic_ledger": [],
		"v06_transaction_ledger": [],
		"total_business_spend": 0,
		"hand": ["PRIVATE_HAND_SENTINEL"],
		"ai_plan": "PRIVATE_AI_PLAN_SENTINEL",
	}


func _action() -> Dictionary:
	return {
		"kind": "price_pump",
		"policy_kind": "price_pump",
		"product": str(ProductMarketRuntimeController.PRODUCT_CATALOG[0]),
		"own_city": 0,
		"score": 100,
	}


func _request(request_id: String, player_index: int = 1) -> AiBusinessCostDebitRequest:
	var context := cash_port.private_request_context(_capability, player_index)
	var request := AiBusinessCostDebitRequest.new()
	request.request_id = request_id
	request.player_index = player_index
	request.business_action_id = "price_pump"
	request.product_id = str(ProductMarketRuntimeController.PRODUCT_CATALOG[0])
	request.public_region_id = "region-public-0"
	request.business_cycle_revision = int(context.get("business_cycle_revision", 0))
	request.session_id = str(context.get("session_id", session.session_summary().get("session_id", "")))
	request.session_revision = int(context.get("session_revision", session.session_start_revision()))
	request.simulation_step_index = int(context.get("simulation_step_index", authority.current_step_index()))
	request.cost_cents = 9000
	request.policy_fingerprint = str(context.get(
		"policy_fingerprint",
		(ai.policy_profile as AiPolicyProfileResource).business_action_policy_fingerprint()
	))
	request.expected_availability_fingerprint = str(context.get("expected_availability_fingerprint", "0".repeat(64)))
	request.seal()
	return request


func _case_success_duplicate_and_public_privacy() -> void:
	_reset_case("success", 100000)
	var before_market := market.runtime_state_snapshot()
	var rng_before := rng.capture_plan_checkpoint()
	var mutation_before := audit.recent_mutations(32).size()
	var applied := bool(ai.call("_execute_rival_business_action_transaction", 1, _action(), 1))
	var player := world.players[1] as Dictionary
	_expect(applied, "production AI transaction applies a valid price-pump action")
	_expect(int(player.get("cash_cents", -1)) == 91000 and int(player.get("cash", -1)) == 910, "success debits exactly 9000 cents and updates the whole-unit mirror")
	_expect(int(player.get("total_business_spend", -1)) == 90, "success records the existing 90-unit business spend once")
	_expect((player.get("v06_transaction_ledger", []) as Array).size() == 1 and (player.get("economic_ledger", []) as Array).size() == 1, "cash owner records one transaction and one economic event")
	_expect(not _same(before_market, market.runtime_state_snapshot()), "success changes the authoritative market once")
	_expect(int(rng.capture_plan_checkpoint().get("draw_count", 0)) - int(rng_before.get("draw_count", 0)) == 47, "success consumes the unchanged 47-draw market sequence")
	_expect(int(market.ai_business_market_pressure_debug_snapshot().get("finalize_call_count", 0)) == 1, "success finalizes the market participant once")
	_expect(audit.recent_mutations(32).size() == mutation_before + 1, "success records one cash mutation through SimulationMutationAuthority")
	var public_clues: Array = (((world.districts[0] as Dictionary).get("city", {}) as Dictionary).get("public_clues", []) as Array)
	_expect(public_clues.size() == 1 and str((public_clues[0] as Dictionary).get("text", "")).contains("供需重算"), "success persists one legacy-equivalent public region clue through WorldSessionState")
	var public_entries := public_log_owner.recent_public_entries(8)
	_expect(public_entries.size() == 1 and str((public_entries[0] as Dictionary).get("event_kind", "")) == "ai_business_market_pressure_resolved", "success publishes one typed detailed public log receipt")
	var public_entries_text := JSON.stringify(public_entries).to_lower()
	_expect(not (public_entries[0] as Dictionary).has("receipt_id") and not public_entries_text.contains("ai-business:") and not public_entries_text.contains("player_index"), "player-facing public log projection exposes no internal transaction identity")
	var cash_after := int(player.get("cash_cents", 0))
	var market_after := market.runtime_state_snapshot()
	var rng_after := rng.capture_plan_checkpoint()
	var replay_applied := bool(ai.call("_execute_rival_business_action_transaction", 1, _action(), 1))
	player = world.players[1] as Dictionary
	_expect(not replay_applied and int(player.get("cash_cents", 0)) == cash_after, "duplicate production intent cannot debit cash twice")
	_expect(_same(market_after, market.runtime_state_snapshot()) and _same(rng_after, rng.capture_plan_checkpoint()), "duplicate production intent cannot apply the market effect or RNG twice")
	_expect((player.get("v06_transaction_ledger", []) as Array).size() == 1 and int(player.get("total_business_spend", 0)) == 90, "duplicate leaves owner ledgers exact-once")
	_expect((((world.districts[0] as Dictionary).get("city", {}) as Dictionary).get("public_clues", []) as Array).size() == 1 and public_log_owner.recent_public_entries(8).size() == 1, "duplicate cannot append the public clue or log twice")
	var port_debug_text := JSON.stringify(cash_port.debug_snapshot()).to_lower()
	_expect(not _contains_private_term(port_debug_text), "typed cash debug snapshot excludes actor cash, commitments, request fingerprints, and AI plans")
	var redacted := AiBusinessCostDebitReceipt.new().public_redacted_dictionary()
	_expect(not _contains_private_term(JSON.stringify(redacted).to_lower()), "typed cash receipt has no public cash projection")


func _case_committed_wager_rejection_and_exact_available() -> void:
	_reset_case("reserved-reject", 10000, 2000)
	var market_before := market.runtime_state_snapshot()
	var rng_before := rng.capture_plan_checkpoint()
	var applied := bool(ai.call("_execute_rival_business_action_transaction", 1, _action(), 1))
	var player := world.players[1] as Dictionary
	_expect(not applied and int(player.get("cash_cents", 0)) == 10000, "cash reserved by an unresolved monster wager cannot fund business actions")
	_expect(_same(market_before, market.runtime_state_snapshot()) and _same(rng_before, rng.capture_plan_checkpoint()), "reserved-cash rejection occurs before market or RNG mutation")
	_expect(monster.private_wager_cash_commitment_snapshot(1).get("reserved_cents") == 2000, "business rejection never cancels or settles the wager commitment")
	_reset_case("reserved-exact", 11000, 2000)
	applied = bool(ai.call("_execute_rival_business_action_transaction", 1, _action(), 1))
	player = world.players[1] as Dictionary
	_expect(applied and int(player.get("cash_cents", -1)) == 2000, "available cash exactly equal to cost is accepted")
	_expect(int(player.get("cash_cents", -1)) == int(monster.private_wager_cash_commitment_snapshot(1).get("reserved_cents", -2)), "successful debit never drops total cash below the reserved wager")


func _case_exact_once_collision_and_stale_guards() -> void:
	_reset_case("port-replay", 100000)
	var request := _request("qa-ai-business-port-replay")
	var first := cash_port.submit(_capability, request)
	var replay := cash_port.submit(_capability, request)
	_expect(first.accepted and first.changed and not first.idempotent, "typed cash request commits once")
	_expect(replay.accepted and replay.idempotent and not replay.changed, "same request ID and fingerprint returns a detached idempotent receipt")
	_expect(int((world.players[1] as Dictionary).get("cash_cents", 0)) == 91000, "typed request replay applies one debit total")
	var first_private := first.private_dictionary()
	authority.end_step()
	_step_index += 1
	authority.begin_step(_step_index)
	market.business_cycle_count += 1
	var later_replay := cash_port.submit(_capability, request)
	_expect(later_replay.accepted and later_replay.idempotent, "completed request replays after simulation step and market cycle advance")
	_expect(later_replay.total_cents_before == int(first_private.get("total_cents_before", -1)) and later_replay.reserved_cents == int(first_private.get("reserved_cents", -1)) and later_replay.available_cents_before == int(first_private.get("available_cents_before", -1)), "later replay preserves the original private authorization facts")
	market.business_cycle_count -= 1
	var collision := request.detached_copy()
	collision.business_action_id = "different_action"
	collision.seal()
	var collision_receipt := cash_port.submit(_capability, collision)
	_expect(not collision_receipt.accepted and collision_receipt.reason_code == "ai_business_cost_request_id_collision", "same request ID with another action fingerprint is rejected")
	var stale_cycle := _request("qa-ai-business-stale-cycle")
	stale_cycle.business_cycle_revision += 1
	stale_cycle.seal()
	var stale_cycle_receipt := cash_port.submit(_capability, stale_cycle)
	_expect(not stale_cycle_receipt.accepted and stale_cycle_receipt.reason_code == "ai_business_cost_cycle_stale", "stale business cycle is rejected")
	var stale_step := _request("qa-ai-business-stale-step")
	stale_step.simulation_step_index += 1
	stale_step.seal()
	var stale_step_receipt := cash_port.submit(_capability, stale_step)
	_expect(not stale_step_receipt.accepted and stale_step_receipt.reason_code == "ai_business_cost_simulation_step_stale", "stale simulation step is rejected")
	var stale_session := _request("qa-ai-business-stale-session")
	stale_session.session_id = "another-session"
	stale_session.seal()
	var stale_session_receipt := cash_port.submit(_capability, stale_session)
	_expect(not stale_session_receipt.accepted and stale_session_receipt.reason_code == "ai_business_cost_session_stale", "stale session identity is rejected")
	var stale_session_revision := _request("qa-ai-business-stale-session-revision")
	stale_session_revision.session_revision += 1
	stale_session_revision.seal()
	var stale_session_revision_receipt := cash_port.submit(_capability, stale_session_revision)
	_expect(not stale_session_revision_receipt.accepted and stale_session_revision_receipt.reason_code == "ai_business_cost_session_revision_stale", "stale session revision is rejected")
	var stale_availability := _request("qa-ai-business-stale-availability")
	stale_availability.expected_availability_fingerprint = "f".repeat(64)
	stale_availability.seal()
	var stale_availability_receipt := cash_port.submit(_capability, stale_availability)
	_expect(not stale_availability_receipt.accepted and stale_availability_receipt.reason_code == "cash_availability_changed", "stale cash availability fingerprint is rejected")
	_expect(int((world.players[1] as Dictionary).get("cash_cents", 0)) == 91000, "collision and stale requests have zero cash mutation")


func _case_actor_currency_and_capability_guards() -> void:
	_reset_case("actor-guards", 100050)
	var request := _request("qa-ai-business-fractional")
	var result := cash_port.submit(_capability, request)
	_expect(result.accepted and int((world.players[1] as Dictionary).get("cash_cents", -1)) == 91050, "fractional cents survive an exact 9000-cent debit")
	_expect(int((world.players[1] as Dictionary).get("cash", -1)) == 910, "fractional cash retains the canonical floor whole-unit mirror")
	var human_request := _request("qa-ai-business-human", 0)
	var human := cash_port.submit(_capability, human_request)
	_expect(not human.accepted and human.reason_code == "ai_business_cost_human_seat_rejected", "human seats cannot use the AI cash capability")
	var eliminated_request := _request("qa-ai-business-eliminated", 2)
	var eliminated := cash_port.submit(_capability, eliminated_request)
	_expect(not eliminated.accepted and eliminated.reason_code == "ai_business_cost_eliminated_seat_rejected", "eliminated AI seats cannot pay business costs")
	var wrong_capability := cash_port.submit(AiBusinessCostCapability.new(), _request("qa-ai-business-forged-capability"))
	_expect(not wrong_capability.accepted and wrong_capability.reason_code == "ai_business_cost_capability_rejected", "forged capability is rejected")
	var zero_cost := _request("qa-ai-business-zero")
	zero_cost.cost_cents = 0
	zero_cost.seal()
	var zero := cash_port.submit(_capability, zero_cost)
	_expect(not zero.accepted, "zero business cost is rejected")
	var fractional_cost := _request("qa-ai-business-fractional-cost")
	fractional_cost.cost_cents = 9001
	fractional_cost.seal()
	_expect(not cash_port.submit(_capability, fractional_cost).accepted, "non-policy fractional-unit business cost is rejected")
	var negative_cost := _request("qa-ai-business-negative-cost")
	negative_cost.cost_cents = -100
	negative_cost.seal()
	_expect(not cash_port.submit(_capability, negative_cost).accepted, "negative business cost is rejected")
	_reset_case("legacy-mirror", 100050)
	var legacy_player := (world.players[1] as Dictionary).duplicate(true)
	legacy_player["cash"] = 1000
	legacy_player["cash_cents"] = 100150
	var legacy_players := world.players.duplicate(true)
	legacy_players[1] = legacy_player
	world.replace_players(legacy_players, true)
	var legacy_request := _request("qa-ai-business-legacy-mirror")
	var legacy_result := cash_port.submit(_capability, legacy_request)
	_expect(legacy_result.accepted and int((world.players[1] as Dictionary).get("cash_cents", -1)) == 91000 and int((world.players[1] as Dictionary).get("cash", -1)) == 910, "legacy mirror drift uses canonical reconciliation and rewrites both currency fields")
	session.finish_session({"winner": "public"})
	var finished := cash_port.submit(_capability, _request("qa-ai-business-finished"))
	_expect(not finished.accepted and finished.reason_code == "ai_business_cost_session_not_running", "finished sessions reject AI business debit")


func _case_bounded_journal_owner_replay() -> void:
	_reset_case("journal-eviction", 3000000, 2000)
	var first_request: AiBusinessCostDebitRequest
	var first_receipt: AiBusinessCostDebitReceipt
	for index in range(257):
		var request := _request("qa-ai-business-journal-%03d" % index)
		if index == 0:
			first_request = request.detached_copy()
		var receipt := cash_port.submit(_capability, request)
		if index == 0:
			first_receipt = receipt.detached_copy()
		if not receipt.accepted or not receipt.changed:
			_failures.append("bounded journal setup debit failed at %d" % index)
			break
	var debug := cash_port.debug_snapshot()
	_expect(int(debug.get("journal_size", -1)) == 256, "typed port keeps a bounded 256-entry session journal")
	var cash_before_replay := int((world.players[1] as Dictionary).get("cash_cents", 0))
	var replay := cash_port.submit(_capability, first_request)
	_expect(replay.accepted and replay.idempotent and not replay.changed, "evicted typed receipt is reconstructed from the single cash-owner ledger")
	_expect(first_receipt != null and replay.reserved_cents == first_receipt.reserved_cents and replay.available_cents_before == first_receipt.available_cents_before and replay.available_cents_after == first_receipt.available_cents_after, "owner-ledger replay reconstructs the original reserved and available cash facts")
	_expect(int((world.players[1] as Dictionary).get("cash_cents", 0)) == cash_before_replay, "owner-ledger replay after port eviction never debits twice")


func _case_market_commit_then_cash_failure_rolls_back() -> void:
	_reset_case("rollback", 100000)
	var request := _request("qa-ai-business-rollback")
	var context := cash_port.private_request_context(_capability, 1)
	var market_before := market.runtime_state_snapshot()
	var rng_before := rng.capture_plan_checkpoint()
	var prepared := market.prepare_ai_business_market_pressure({
		"schema_version": 1,
		"transaction_id": request.request_id,
		"action_kind": request.business_action_id,
		"product_id": request.product_id,
		"public_region_id": request.public_region_id,
		"source_revision": request.business_cycle_revision,
		"expected_market_fingerprint": str(context.get("market_fingerprint", "")),
	})
	var committed := market.commit_ai_business_market_pressure(prepared)
	_expect(bool(committed.get("committed", false)), "fault fixture opens the real market rollback window")
	var finalize_ready := market.seal_ai_business_market_pressure_finalization(committed)
	_expect(bool(finalize_ready.get("finalization_ready", false)), "market finalization is sealed before the cash owner can commit")
	monster.set_qa_reserved_cents(1, 95000)
	var cash_result := cash_port.submit(_capability, request)
	_expect(not cash_result.accepted, "cash authorization failure is visible before finalization")
	var rolled_back := market.rollback_ai_business_market_pressure(finalize_ready)
	_expect(bool(rolled_back.get("rolled_back", false)), "cash failure rolls back the real market participant")
	_expect(_same(market_before, market.runtime_state_snapshot()) and _same(rng_before, rng.capture_plan_checkpoint()), "cash failure restores complete market and RNG preimages")
	_expect(int((world.players[1] as Dictionary).get("cash_cents", 0)) == 100000 and _telemetry_rows.is_empty(), "rolled-back action has no cash, telemetry, or public finalization side effect")


func _case_publication_preflight_and_retry() -> void:
	_reset_case("publication-preflight", 100000)
	var request := _request("qa-ai-business-publication-preflight")
	var context := cash_port.private_request_context(_capability, 1)
	var before_market := market.runtime_state_snapshot()
	var before_rng := rng.capture_plan_checkpoint()
	var prepared := market.prepare_ai_business_market_pressure({
		"schema_version": 1,
		"transaction_id": request.request_id,
		"action_kind": request.business_action_id,
		"product_id": request.product_id,
		"public_region_id": request.public_region_id,
		"source_revision": request.business_cycle_revision,
		"expected_market_fingerprint": str(context.get("market_fingerprint", "")),
	})
	var committed := market.commit_ai_business_market_pressure(prepared)
	market.set_table_presentation_log_port(null, world_clock)
	var unavailable_seal := market.seal_ai_business_market_pressure_finalization(committed)
	_expect(not bool(unavailable_seal.get("finalization_ready", false)), "publication dependency failure is rejected before the cash owner commits")
	var rolled_back := market.rollback_ai_business_market_pressure(committed)
	_expect(bool(rolled_back.get("rolled_back", false)) and _same(before_market, market.runtime_state_snapshot()) and _same(before_rng, rng.capture_plan_checkpoint()), "publication preflight failure keeps the market and RNG rollback window intact")
	_expect(int((world.players[1] as Dictionary).get("cash_cents", 0)) == 100000, "publication preflight failure has zero cash mutation")
	market.set_table_presentation_log_port(public_log_port, world_clock)

	_reset_case("publication-retry", 100000)
	request = _request("qa-ai-business-publication-retry")
	context = cash_port.private_request_context(_capability, 1)
	prepared = market.prepare_ai_business_market_pressure({
		"schema_version": 1,
		"transaction_id": request.request_id,
		"action_kind": request.business_action_id,
		"product_id": request.product_id,
		"public_region_id": request.public_region_id,
		"source_revision": request.business_cycle_revision,
		"expected_market_fingerprint": str(context.get("market_fingerprint", "")),
	})
	committed = market.commit_ai_business_market_pressure(prepared)
	var finalize_ready := market.seal_ai_business_market_pressure_finalization(committed)
	var cash_result := cash_port.submit(_capability, request)
	market.set_table_presentation_log_port(null, world_clock)
	var pending := market.finalize_ai_business_market_pressure(finalize_ready)
	_expect(cash_result.accepted and not bool(pending.get("finalized", false)) and bool(pending.get("committed", false)), "unexpected publication outage retains a bounded committed finalization receipt")
	_expect((((world.districts[0] as Dictionary).get("city", {}) as Dictionary).get("public_clues", []) as Array).size() == 1 and public_log_owner.recent_public_entries(8).is_empty(), "partial publication records only the destination that actually accepted the typed receipt")
	market.set_table_presentation_log_port(public_log_port, world_clock)
	market.tick_market_cycle(0.0)
	var maintenance := market.ai_business_market_pressure_debug_snapshot()
	_expect(int(maintenance.get("finalizing_count", -1)) == 0 and int(maintenance.get("finalize_call_count", 0)) == 1, "the production market tick drains one pending publication without replaying gameplay")
	var replay_finalized := market.finalize_ai_business_market_pressure(pending)
	_expect(bool(replay_finalized.get("finalized", false)) and bool(replay_finalized.get("duplicate", false)) and bool(replay_finalized.get("public_clue_applied", false)) and bool(replay_finalized.get("public_log_applied", false)), "completed publication recovery is exact-once and replay-visible")
	_expect((((world.districts[0] as Dictionary).get("city", {}) as Dictionary).get("public_clues", []) as Array).size() == 1 and public_log_owner.recent_public_entries(8).size() == 1, "retry never duplicates the public clue or log")


func _case_production_pending_publication_counts_action() -> void:
	_reset_case("production-publication-pending", 100000)
	var fail_once_port := FailOncePublicLogPortScript.new() as PublicLogProducerPort
	fail_once_port.configure(public_log_owner)
	market.set_table_presentation_log_port(fail_once_port, world_clock)
	var applied := bool(ai.call("_execute_rival_business_action_transaction", 1, _action(), 1))
	var transaction_debug := market.ai_business_market_pressure_debug_snapshot()
	_expect(applied and int((world.players[1] as Dictionary).get("cash_cents", 0)) == 91000, "a committed action with presentation pending still counts toward the AI per-cycle cap")
	_expect(int(transaction_debug.get("finalizing_count", 0)) == 1 and public_log_owner.recent_public_entries(8).is_empty(), "fail-once production target leaves exactly one public-only finalization pending")
	market.set_table_presentation_log_port(public_log_port, world_clock)
	session.finish_session({"winner": "public"})
	var save_snapshot := market.to_save_data()
	transaction_debug = market.ai_business_market_pressure_debug_snapshot()
	_expect(not save_snapshot.is_empty() and int(transaction_debug.get("finalizing_count", -1)) == 0, "save maintenance drains pending public output even after the session has finished")
	_expect((((world.districts[0] as Dictionary).get("city", {}) as Dictionary).get("public_clues", []) as Array).size() == 1 and public_log_owner.recent_public_entries(8).size() == 1, "post-finish drain keeps clue and log exact-once")
	fail_once_port.queue_free()


func _case_policy_fail_closed() -> void:
	_reset_case("policy-fail-closed", 100000)
	var invalid_policy := AiPolicyProfileResource.new()
	invalid_policy.business_action_cost_units = 0
	_expect(not bool(ai.call("_business_action_policy_valid", invalid_policy.business_action_terms())), "AI rejects an incomplete typed Business Action Policy before runtime activation")
	_expect(int(ai.RIVAL_BUSINESS_ACTION_COST) == 90 and int(ai.RIVAL_BUSINESS_ACTION_CHANCE_PERCENT) == 76 and int(ai.RIVAL_BUSINESS_ACTION_MAX_PER_CYCLE) == 2, "restored production policy remains the sole 76/2/90 source")


func _case_policy_revision_drift_rejected() -> void:
	_reset_case("policy-drift", 100000)
	var drift_policy := AiPolicyProfileResource.new()
	drift_policy.business_action_cost_units = 91
	ai.configure({"ruleset_id": "v0.4"}, drift_policy)
	var market_before := market.runtime_state_snapshot()
	var rng_before := rng.capture_plan_checkpoint()
	var applied := bool(ai.call("_execute_rival_business_action_transaction", 1, _action(), 1))
	_expect(not applied and int((world.players[1] as Dictionary).get("cash_cents", 0)) == 100000, "AI policy reconfiguration cannot silently drift from the frozen cash authority terms")
	_expect(_same(market_before, market.runtime_state_snapshot()) and _same(rng_before, rng.capture_plan_checkpoint()), "policy fingerprint mismatch rolls back market and RNG with zero partial mutation")
	ai.configure({"ruleset_id": "v0.4"}, load("res://resources/ai/ai_policy_profile_v1.tres"))


func _case_route_sabotage_remains_fail_closed() -> void:
	_reset_case("route-sabotage", 100000)
	var action := _action()
	action["kind"] = "route_sabotage"
	action["policy_kind"] = "route_sabotage"
	var market_before := market.runtime_state_snapshot()
	var rng_before := rng.capture_plan_checkpoint()
	var applied := bool(ai.call("_execute_rival_business_action_transaction", 1, action, 1))
	_expect(not applied, "route sabotage remains explicitly fail-closed without a reversible route owner")
	_expect(int((world.players[1] as Dictionary).get("cash_cents", 0)) == 100000 and _same(market_before, market.runtime_state_snapshot()) and _same(rng_before, rng.capture_plan_checkpoint()), "unsupported route action has zero cash, market, and RNG mutation")


func _contains_private_term(text: String) -> bool:
	for term in ["cash_cents", "reserved_cents", "available_cents", "commitment_fingerprint", "request_fingerprint", "player_index", "ai_plan", "decision_samples", "private_hand_sentinel", "private_ai_plan_sentinel", "98765432199"]:
		if text.contains(term):
			return true
	return false


func _same(left: Variant, right: Variant) -> bool:
	return JSON.stringify(left) == JSON.stringify(right)


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
