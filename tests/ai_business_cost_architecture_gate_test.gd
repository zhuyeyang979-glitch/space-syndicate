extends SceneTree

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var main_source := _read("res://scripts/" + "main.gd")
	var ai_source := _read("res://scripts/runtime/ai_runtime_controller.gd")
	var port_source := _read("res://scripts/runtime/ai_business_cost_cash_port.gd")
	var cash_source := _read("res://scripts/runtime/player_cash_mutation_port.gd")
	var coordinator_source := _read("res://scripts/runtime/game_runtime_coordinator.gd")
	var coordinator_scene := _read("res://scenes/runtime/GameRuntimeCoordinator.tscn")
	var policy_source := _read("res://scripts/ai/ai_policy_profile_resource.gd")
	var policy_resource := _read("res://resources/ai/ai_policy_profile_v1.tres")
	var market_source := _read("res://scripts/runtime/product_market_runtime_controller.gd")
	var market_bridge_source := _read("res://scripts/runtime/product_market_runtime_world_bridge.gd")
	var world_state_source := _read("res://scripts/runtime/world_session_state.gd")
	_expect(not main_source.contains("RIVAL_BUSINESS_ACTION_CHANCE_PERCENT"), "Main no longer owns business action chance")
	_expect(not main_source.contains("RIVAL_BUSINESS_ACTION_MAX_PER_CYCLE"), "Main no longer owns business action cycle limit")
	_expect(not main_source.contains("RIVAL_BUSINESS_ACTION_COST"), "Main no longer owns business action cost")
	_expect(not main_source.contains("RIVAL_BUSINESS_PRICE_DELTA_MIN") and not main_source.contains("RIVAL_BUSINESS_PRICE_DELTA_MAX"), "Main no longer owns business pressure draw bounds")
	for retired_method in ["func _pay_rival_business_cost", "func _apply_rival_price_pump", "func _apply_rival_business_action", "func _set_city_public_clue"]:
		_expect(not main_source.contains(retired_method), "Main retired path removed: %s" % retired_method)
	_expect(not ai_source.contains("_call_world(&\"_apply_rival_business_action\""), "AI has no generic Main business-action call")
	_expect(not ai_source.contains("reconcile_private_player_cash_after_unit_mutation"), "AI has no post-hoc legacy cash reconciliation")
	_expect(not ai_source.contains("_world_constant(&\"RIVAL_BUSINESS_ACTION_"), "AI policy terms no longer come from Main constants")
	_expect(ai_source.contains("prepare_ai_business_market_pressure") and ai_source.contains("commit_ai_business_market_pressure") and ai_source.contains("rollback_ai_business_market_pressure") and ai_source.contains("finalize_ai_business_market_pressure"), "AI uses the reversible ProductMarket participant lifecycle")
	var market_commit_index := ai_source.find("commit_ai_business_market_pressure")
	var market_seal_index := ai_source.find("seal_ai_business_market_pressure_finalization", market_commit_index)
	var cash_submit_index := ai_source.find("_ai_business_cost_cash_port.submit", market_seal_index)
	var market_finalize_index := ai_source.find("finalize_ai_business_market_pressure", cash_submit_index)
	_expect(market_commit_index >= 0 and market_seal_index > market_commit_index and cash_submit_index > market_seal_index and market_finalize_index > cash_submit_index, "cross-owner order seals market finalization before committing cash")
	_expect(market_source.contains("state == \"finalize_ready\"") and market_source.contains("finalize_token"), "sealed finalization has no post-cash mutable CAS gate")
	_expect(ai_source.contains("AiBusinessCostDebitRequest.new()") and ai_source.contains("_ai_business_cost_cash_port.submit"), "AI constructs and submits the typed debit request")
	_expect(not port_source.contains("Main") and not port_source.contains("current_scene") and not port_source.contains("/root/" + "Main"), "typed cash port has no Main or service-locator fallback")
	_expect(port_source.contains("JOURNAL_LIMIT := 256") and port_source.contains("owns_save_section\": false"), "typed cash journal is bounded and owns no save section")
	_expect(port_source.contains("authorize_debit_cents") and port_source.contains("expected_availability_fingerprint"), "typed cash port binds unresolved wager commitments")
	_expect(cash_source.contains("commit_ai_business_action_cost") and cash_source.contains("total_business_spend"), "existing cash authority owns business spend mutation")
	_expect(cash_source.contains("next_player[\"cash_cents\"]") and cash_source.contains("next_player[\"cash\"]"), "cash authority atomically updates cents and the unit mirror")
	_expect(cash_source.contains("ai_business_cost_debit") and cash_source.contains("AiBusinessCostCashPort"), "cash mutation is audited with the typed command identity")
	_expect(_count(coordinator_scene, "[node name=\"AiBusinessCostCashPort\"") == 1, "production composition has exactly one AI business cash port")
	_expect(_count(coordinator_source, "func _wire_ai_business_cost_cash_port") == 1, "coordinator has one explicit wiring function")
	_expect(coordinator_source.contains("AiBusinessCostCapability.new()") and coordinator_source.contains("set_ai_business_cost_cash_port"), "coordinator alone issues and injects the opaque capability")
	_expect(policy_source.contains("business_action_chance_percent := 76") and policy_source.contains("business_action_max_per_cycle := 2") and policy_source.contains("business_action_cost_units := 90"), "AI policy preserves 76 percent, two actions, and 90-unit cost")
	_expect(policy_resource.contains("business_action_chance_percent = 76") and policy_resource.contains("business_action_max_per_cycle = 2") and policy_resource.contains("business_action_cost_units = 90"), "production policy resource explicitly freezes existing values")
	_expect(ai_source.contains("func _business_action_policy_valid") and not ai_source.contains("_policy_value(\"business_action\""), "missing business policy terms fail closed without literal runtime fallback")
	_expect(market_bridge_source.contains("append_ai_business_public_clue") and world_state_source.contains("append_ai_business_market_pressure_public_clue") and not world_state_source.contains("func append_public_region_clue"), "typed market receipt restores the public region clue without a free-form text or Main path")
	_expect(market_source.contains("public.ai_business.market_pressure_resolved"), "ProductMarket publishes the detailed typed public log receipt")
	_expect(market_source.contains("_ai_business_market_pressure_publication_preflight") and market_source.contains("ai_business_market_pressure_publication_pending"), "cash commits only after public destinations preflight and missing exact-once publication remains retryable")
	_expect(market_source.contains("func retry_pending_ai_business_publications") and market_source.contains("retry_pending_ai_business_publications()\n\tmarket_timer"), "production market cadence owns the bounded public-only retry drain")
	_expect(ai_source.contains("this action must still count toward the per-cycle cap") and coordinator_source.contains("_drain_ai_business_publications_before_session_finish"), "committed actions count once and session finish drains pending public output")
	_expect(coordinator_source.contains("new_session_checkpoint_product_market_blocked") and market_source.contains("func to_save_data() -> Dictionary:\n\tretry_pending_ai_business_publications()"), "checkpoint and save paths reject an undrained ProductMarket publication tail")
	var formal_source := _read("res://tests/ai_business_cost_formal_four_player_test.gd")
	_expect(formal_source.contains("res://scenes/main.tscn") and formal_source.contains("RuntimeLoop") and formal_source.contains("_open_monster_wager_for_pair"), "formal QA covers real main, RuntimeLoop, ProductMarket cycle, and monster wager")
	var request_source := _read("res://scripts/runtime/ai_business_cost_debit_request.gd")
	_expect(request_source.contains("product_id") and request_source.contains("public_region_id"), "request fingerprint binds the selected product and public region")
	_expect(request_source.contains("policy_fingerprint") and port_source.contains("ai_business_cost_policy_revision_mismatch"), "typed request binds the frozen cash-cost policy revision")
	var receipt_source := _read("res://scripts/runtime/ai_business_cost_debit_receipt.gd")
	_expect(receipt_source.contains("func public_redacted_dictionary") and receipt_source.contains("return {}") and not receipt_source.contains("public_cash"), "typed cash receipt exposes no public balance payload")
	var passed := _failures.is_empty()
	print("AI_BUSINESS_COST_ARCHITECTURE_GATE_TEST|status=%s|checks=%d|failures=%d|details=%s" % [
		"PASS" if passed else "FAIL", _checks, _failures.size(), JSON.stringify(_failures),
	])
	quit(0 if passed else 1)


func _read(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	return file.get_as_text() if file != null else ""


func _count(text: String, needle: String) -> int:
	return text.count(needle)


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
