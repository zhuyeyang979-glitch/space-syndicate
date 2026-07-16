extends SceneTree

const PRODUCT := "环晶电池"
const LONG_CARD := "商品看涨1"
const SHORT_CARD := "商品看跌1"
const STOCKPILE_CARD := "港仓囤货1"

var _failures: Array[String] = []
var _checks := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load("res://scenes/main.tscn") as PackedScene
	_expect(packed != null, "real main scene loads the production runtime composition")
	if packed == null:
		_finish()
		return
	var main := packed.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	main.call("_new_game")
	await process_frame
	await process_frame

	var coordinator := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator")
	var ai := coordinator.get_node_or_null("AiRuntimeController") if coordinator != null else null
	var market := coordinator.get_node_or_null("ProductMarketRuntimeController") if coordinator != null else null
	var commodity := coordinator.get_node_or_null("CommodityFlowRuntimeController") if coordinator != null else null
	_expect(coordinator != null, "GameRuntimeCoordinator owns the production composition")
	_expect(_script_path(ai) == "res://scripts/runtime/ai_runtime_controller.gd", "AiRuntimeController is the real production AI owner")
	_expect(_script_path(market) == "res://scripts/runtime/product_market_runtime_controller.gd", "ProductMarketRuntimeController is the real futures owner")
	_expect(_script_path(commodity) == "res://scripts/runtime/commodity_flow_runtime_controller.gd", "CommodityFlowRuntimeController is the real commodity owner")
	if ai == null or market == null or commodity == null:
		_dispose(main)
		_finish()
		return

	var fixture := _install_fixture(main, ai, market)
	_expect(bool(fixture.get("ready", false)), "futures fixture uses a sunlit listing and two active cities")
	if bool(fixture.get("ready", false)):
		_check_terms_owner(market)
		_check_play_candidates(main, ai, fixture)
		_check_buy_candidates(main, ai, fixture)
		_check_budget_discipline(main, ai)
		_check_training_metadata(ai, fixture)
		_check_private_state_invariance(main, ai, fixture)
		_check_owner_privacy(commodity, market)

	_dispose(main)
	_finish()


func _install_fixture(main: Node, ai: Node, market: Node) -> Dictionary:
	var districts: Array = (((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts as Array).duplicate(true)
	var own_index := -1
	for index in range(districts.size()):
		var district: Dictionary = districts[index]
		if bool(district.get("destroyed", false)) or str(district.get("terrain", "")) == "ocean":
			continue
		if bool(main.call("_district_market_currently_purchasable", index)):
			own_index = index
			break
	var rival_index := -1
	for index in range(districts.size()):
		if index == own_index:
			continue
		var district: Dictionary = districts[index]
		if not bool(district.get("destroyed", false)) and str(district.get("terrain", "")) != "ocean":
			rival_index = index
			break
	if own_index < 0 or rival_index < 0:
		return {"ready": false}

	var players: Array = (((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players as Array).duplicate(true)
	if players.size() < 3:
		return {"ready": false}
	for player_index in range(players.size()):
		var player: Dictionary = players[player_index]
		player["cash"] = 7200
		player["cash_cents"] = 720000
		player["action_cooldown"] = 0.0
		if player_index == 1:
			var memory := ai.call("_empty_ai_memory") as Dictionary
			memory["economic_focus_product"] = PRODUCT
			memory["economic_focus_score"] = 900
			memory["strategy_intent"] = "grow_focus"
			memory["strategy_score"] = 820
			memory["route_plan_product"] = PRODUCT
			memory["route_plan_stage"] = "strengthen_route"
			memory["route_plan_score"] = 760
			player["ai_memory"] = memory
			player["slots"] = [
				ai.call("_make_skill", LONG_CARD),
				ai.call("_make_skill", SHORT_CARD),
				ai.call("_make_skill", STOCKPILE_CARD),
			]
		players[player_index] = player
	((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players = players

	var own_district: Dictionary = districts[own_index]
	own_district["destroyed"] = false
	own_district["damage"] = 0
	own_district["panic"] = 0
	own_district["products"] = [PRODUCT]
	own_district["demands"] = [PRODUCT]
	own_district["card_choices"] = [LONG_CARD, SHORT_CARD, STOCKPILE_CARD]
	own_district["city"] = _city(1, "AI期货港仓城", PRODUCT, PRODUCT, 980, 3)
	districts[own_index] = own_district
	var rival_district: Dictionary = districts[rival_index]
	rival_district["destroyed"] = false
	rival_district["damage"] = 2
	rival_district["panic"] = 18
	rival_district["products"] = [PRODUCT]
	rival_district["demands"] = ["轨迹墨水"]
	rival_district["city"] = _city(2, "AI期货竞品城", PRODUCT, "轨迹墨水", 1180, 4)
	districts[rival_index] = rival_district
	((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts = districts
	((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).table_selection_state()).selected_trade_product = PRODUCT

	var market_save := market.call("to_save_data") as Dictionary
	var product_market: Dictionary = (market_save.get("product_market", {}) as Dictionary).duplicate(true)
	var entry: Dictionary = (product_market.get(PRODUCT, {}) as Dictionary).duplicate(true)
	entry["price"] = 132
	entry["base_price"] = 100
	entry["demand"] = 14
	entry["supply"] = 2
	entry["temporary_demand_pressure"] = 6
	entry["temporary_supply_pressure"] = 0
	entry["volatility"] = 5
	entry["price_history"] = [100, 116, 132]
	product_market[PRODUCT] = entry
	market_save["product_market"] = product_market
	market.call("apply_save_data", market_save)
	return {
		"ready": true,
		"own_index": own_index,
		"rival_index": rival_index,
		"long_skill": ai.call("_make_skill", LONG_CARD),
		"short_skill": ai.call("_make_skill", SHORT_CARD),
		"stockpile_skill": ai.call("_make_skill", STOCKPILE_CARD),
	}


func _city(owner: int, display_name: String, product: String, demand: String, income: int, warehouse_units: int) -> Dictionary:
	return {
		"active": true,
		"owner": owner,
		"name": display_name,
		"products": [{"name": product, "level": 2}],
		"demands": [demand],
		"trade_routes": [{"product": product, "disrupted": false}],
		"last_income": income,
		"trade_route_damage": 0,
		"trade_disrupted_routes": 0,
		"warehouse_stockpile_count": 1,
		"warehouse_stockpile_units": warehouse_units,
		"warehouse_stockpile_products": [product],
	}


func _check_terms_owner(market: Node) -> void:
	for card_id in [LONG_CARD, SHORT_CARD, STOCKPILE_CARD]:
		var terms := market.call("terms_for_card_id", card_id) as Dictionary
		_expect(not terms.is_empty(), "%s terms come from ProductMarketRuntimeController" % card_id)
		_expect(float(terms.get("duration_seconds", 0.0)) > 0.0, "%s has owner-authored realtime duration" % card_id)
	_expect(str((market.call("terms_for_card_id", LONG_CARD) as Dictionary).get("direction", "")) == "up", "long terms retain the up direction")
	_expect(str((market.call("terms_for_card_id", SHORT_CARD) as Dictionary).get("direction", "")) == "down", "short terms retain the down direction")
	_expect(bool((market.call("terms_for_card_id", STOCKPILE_CARD) as Dictionary).get("requires_warehouse", false)), "stockpile terms require an owned warehouse")


func _check_play_candidates(main: Node, ai: Node, fixture: Dictionary) -> void:
	var long_context := ai.call("_ai_card_play_context", 1, 0, fixture.long_skill) as Dictionary
	var stockpile_context := ai.call("_ai_card_play_context", 1, 2, fixture.stockpile_skill) as Dictionary
	_expect(str(long_context.get("policy_kind", "")) == "product_futures_up", "long play candidate uses the futures-up policy")
	_expect(str(long_context.get("product", "")) == PRODUCT and int(long_context.get("futures_signal", 0)) > 0, "long play candidate follows the configured commodity signal")
	_expect(str(stockpile_context.get("policy_kind", "")) == "product_futures_stockpile", "stockpile play candidate uses its distinct policy")
	_expect(bool(stockpile_context.get("futures_warehouse_required", false)), "stockpile play candidate carries the owner-authored warehouse requirement")
	_expect(int(stockpile_context.get("futures_warehouse_city", -1)) == int(fixture.own_index), "stockpile play candidate targets the owned active warehouse city")

	_set_market_bias(main, false)
	var short_context := ai.call("_ai_card_play_context", 1, 1, fixture.short_skill) as Dictionary
	fixture["long_context"] = long_context
	fixture["short_context"] = short_context
	fixture["stockpile_context"] = stockpile_context
	_expect(str(short_context.get("policy_kind", "")) == "product_futures_down", "short play candidate uses the futures-down policy")
	_expect(str(short_context.get("product", "")) == PRODUCT and int(short_context.get("futures_market_score", 0)) > 0, "short play candidate responds to the real market owner's bearish state")
	_set_market_bias(main, true)


func _set_market_bias(main: Node, bullish: bool) -> void:
	var coordinator := main.get_node("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator")
	var market := coordinator.get_node("ProductMarketRuntimeController")
	var saved := market.call("to_save_data") as Dictionary
	var product_market: Dictionary = (saved.get("product_market", {}) as Dictionary).duplicate(true)
	var entry: Dictionary = (product_market.get(PRODUCT, {}) as Dictionary).duplicate(true)
	entry["price"] = 132 if bullish else 92
	entry["base_price"] = 100 if bullish else 120
	entry["demand"] = 14 if bullish else 1
	entry["supply"] = 2 if bullish else 13
	entry["temporary_demand_pressure"] = 6 if bullish else 0
	entry["temporary_supply_pressure"] = 0 if bullish else 7
	product_market[PRODUCT] = entry
	saved["product_market"] = product_market
	market.call("apply_save_data", saved)


func _check_buy_candidates(_main: Node, ai: Node, fixture: Dictionary) -> void:
	var candidates := ai.call("_ai_card_buy_candidates", 1) as Array
	var long_buy := _candidate(candidates, LONG_CARD)
	var stockpile_buy := _candidate(candidates, STOCKPILE_CARD)
	fixture["long_buy"] = long_buy
	fixture["stockpile_buy"] = stockpile_buy
	_expect(not long_buy.is_empty(), "affordable sunlit market exposes a long-card buy candidate")
	_expect(str(long_buy.get("policy_kind", "")) == "product_futures_up" and int(long_buy.get("futures_play_district", -1)) >= 0, "long buy candidate carries a playable futures plan")
	_expect(not stockpile_buy.is_empty(), "affordable sunlit market exposes a stockpile-card buy candidate")
	_expect(int(stockpile_buy.get("futures_warehouse_city", -1)) == int(fixture.own_index), "stockpile buy candidate retains the owned warehouse target")


func _check_budget_discipline(main: Node, ai: Node) -> void:
	var players: Array = (((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players as Array).duplicate(true)
	var buyer: Dictionary = players[1]
	var original_cash := int(buyer.get("cash", 0))
	var original_cash_cents := int(buyer.get("cash_cents", original_cash * 100))
	buyer["cash"] = 0
	buyer["cash_cents"] = 0
	players[1] = buyer
	((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players = players
	var blocked := ai.call("_ai_card_buy_candidates", 1) as Array
	_expect(_candidate(blocked, LONG_CARD).is_empty() and _candidate(blocked, STOCKPILE_CARD).is_empty(), "AI budget reserve blocks unaffordable futures purchases")
	players = (((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players as Array).duplicate(true)
	buyer = players[1]
	buyer["cash"] = original_cash
	buyer["cash_cents"] = original_cash_cents
	players[1] = buyer
	((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players = players


func _check_training_metadata(ai: Node, fixture: Dictionary) -> void:
	for label in ["long_context", "short_context", "stockpile_context", "long_buy", "stockpile_buy"]:
		var candidate: Dictionary = fixture.get(label, {})
		var training := ai.call("_ai_candidate_training_view", candidate) as Dictionary
		_expect(training.has("policy_kind") and training.has("futures_signal"), "%s keeps policy and signal training metadata" % label)
		_expect(training.has("futures_margin_cash") and training.has("futures_maximum_gain") and training.has("futures_maximum_loss"), "%s keeps owner-authored risk metadata" % label)
		_expect(not _has_forbidden_private_key(training), "%s training metadata excludes private player state" % label)


func _check_private_state_invariance(main: Node, ai: Node, fixture: Dictionary) -> void:
	var before := _decision_projection(ai.call("_ai_card_play_context", 1, 0, fixture.long_skill) as Dictionary)
	var players: Array = (((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players as Array).duplicate(true)
	var rival: Dictionary = players[2]
	rival["cash"] = 987654321
	rival["cash_cents"] = 98765432100
	rival["slots"] = [{"name": "PRIVATE_HAND_SENTINEL", "secret": "DO_NOT_READ"}]
	rival["discard"] = [{"name": "PRIVATE_DISCARD_SENTINEL"}]
	rival["city_guesses"] = {"PRIVATE_GUESS_SENTINEL": {"owner": 1}}
	rival["ai_private_plan"] = {"target": PRODUCT, "score": 999999}
	players[2] = rival
	((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players = players
	var after := _decision_projection(ai.call("_ai_card_play_context", 1, 0, fixture.long_skill) as Dictionary)
	_expect(before == after, "rival cash, hand, discard, guesses, and private AI plan do not alter the futures decision projection")
	_expect(not JSON.stringify(after).contains("PRIVATE_"), "futures decision metadata contains no rival-private sentinel")


func _check_owner_privacy(commodity: Node, market: Node) -> void:
	var commodity_debug := commodity.call("debug_snapshot") as Dictionary
	var public_market := market.call("public_market_snapshot") as Dictionary
	_expect(bool(commodity_debug.get("controller_ready", false)), "real CommodityFlow owner is configured for the AI fixture")
	var public_json := JSON.stringify(public_market)
	_expect(not public_json.contains("\"owner\"") and not public_json.contains("locked_margin"), "public ProductMarket projection excludes futures owner and locked margin")


func _candidate(candidates: Array, card_name: String) -> Dictionary:
	for candidate_variant in candidates:
		if candidate_variant is Dictionary and str((candidate_variant as Dictionary).get("card_name", "")) == card_name:
			return (candidate_variant as Dictionary).duplicate(true)
	return {}


func _script_path(node: Node) -> String:
	if node == null:
		return ""
	var script := node.get_script() as Script
	return script.resource_path if script != null else ""


func _decision_projection(candidate: Dictionary) -> Dictionary:
	var result := {}
	for key in ["policy_kind", "district", "product", "futures_direction", "futures_signal", "futures_market_score", "futures_stockpile_score", "futures_stockpile_units", "futures_duration_seconds", "futures_multiplier_x100", "futures_margin_cash", "futures_maximum_gain", "futures_maximum_loss", "futures_risk_adjusted_ev", "futures_warehouse_city", "futures_warehouse_required", "futures_product_flow"]:
		result[key] = candidate.get(key)
	return result


func _has_forbidden_private_key(value: Variant) -> bool:
	if value is Dictionary:
		for key_variant in (value as Dictionary).keys():
			var key := str(key_variant).to_lower()
			if key in ["cash", "cash_cents", "hand", "slots", "discard", "city_guesses", "ai_private_plan", "owner_secret"]:
				return true
			if _has_forbidden_private_key((value as Dictionary)[key_variant]):
				return true
	elif value is Array:
		for entry in value as Array:
			if _has_forbidden_private_key(entry):
				return true
	return false


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append(message)
		push_error(message)


func _dispose(main: Node) -> void:
	if is_instance_valid(main):
		root.remove_child(main)
		main.queue_free()


func _finish() -> void:
	if _failures.is_empty():
		print("AI_COMMODITY_FUTURES_POLICY_RUNTIME_TEST|status=PASS|checks=%d|failures=0" % _checks)
		quit(0)
		return
	push_error("AI_COMMODITY_FUTURES_POLICY_RUNTIME_TEST|status=FAIL|checks=%d|failures=%d\n- %s" % [_checks, _failures.size(), "\n- ".join(_failures)])
	quit(1)
