extends RefCounted

const MARKET := preload("res://scripts/runtime/product_market_runtime_controller.gd")
const CODEC := preload("res://scripts/runtime/closed_save_scalar_codec_v1.gd")
const TERMS_CATALOG := preload("res://resources/finance/product_futures/product_futures_terms_v04_catalog.tres")


static func make_controller(timer := 19.75, cycle := 7, sequence := 12) -> ProductMarketRuntimeController:
	var controller := MARKET.new() as ProductMarketRuntimeController
	controller.terms_catalog = TERMS_CATALOG
	controller.product_market = {}
	controller.ensure_catalog()
	var product_ids: Array = controller.product_market.keys()
	product_ids.sort_custom(func(left: Variant, right: Variant) -> bool: return str(left) < str(right))
	if not product_ids.is_empty():
		controller.product_market[str(product_ids[0])] = _runtime_entry(str(product_ids[0]), sequence)
	controller.business_cycle_count = cycle
	controller.market_timer = timer
	controller.futures_position_sequence = sequence
	return controller


static func canonicalize_new_session_state(controller: ProductMarketRuntimeController) -> Dictionary:
	if controller == null:
		return {"applied": false, "restored": false, "reason_code": "fixture_controller_missing"}
	var wire := controller.to_save_data()
	return controller.restore_new_session_checkpoint(wire)


static func seed_non_default_runtime(controller: ProductMarketRuntimeController, salt: int) -> void:
	if controller == null or controller.product_market.is_empty():
		return
	var product_ids: Array = controller.product_market.keys()
	product_ids.sort_custom(func(left: Variant, right: Variant) -> bool: return str(left) < str(right))
	var product_id := str(product_ids[0])
	var entry := (controller.product_market.get(product_id, {}) as Dictionary).duplicate(true)
	entry["growth_multiplier"] = 1.375 + float(salt) * 0.03125
	entry["growth_seconds"] = 17.5 + float(salt) * 0.25
	entry["growth_turns"] = 1
	entry["growth_source"] = "rollback-fixture-%d" % salt
	entry["driver_summary"] = "rollback-fixture-%d" % salt
	var seeded_sequence := maxi(controller.futures_position_sequence, 100 + salt)
	entry["futures_positions"] = [_authored_futures_position(product_id, seeded_sequence)]
	controller.product_market[product_id] = entry
	controller.business_cycle_count = 70 + salt
	controller.market_timer = 17.25 + float(salt) * 0.5
	controller.futures_position_sequence = seeded_sequence


static func open_futures_position_count(controller: ProductMarketRuntimeController) -> int:
	if controller == null:
		return 0
	var count := 0
	for entry_variant in controller.product_market.values():
		if not (entry_variant is Dictionary):
			continue
		for position_variant in (entry_variant as Dictionary).get("futures_positions", []):
			if position_variant is Dictionary and not bool((position_variant as Dictionary).get("settled", false)):
				count += 1
	return count


static func timer_bits(wire: Dictionary) -> String:
	var timer_variant: Variant = wire.get("market_timer")
	if not (timer_variant is Dictionary):
		return ""
	return str((timer_variant as Dictionary).get("bits", ""))


static func timer_is_f64_tag(wire: Dictionary) -> bool:
	var timer_variant: Variant = wire.get("market_timer")
	return timer_variant is Dictionary \
			and str((timer_variant as Dictionary).get("codec", "")) == CODEC.F64_CODEC_ID \
			and timer_bits(wire).length() == 16 \
			and timer_bits(wire) == timer_bits(wire).to_lower()


static func authoritative_runtime_snapshot(controller: ProductMarketRuntimeController) -> Dictionary:
	var snapshot := controller.runtime_state_snapshot() if controller != null else {}
	var market := (snapshot.get("product_market", {}) as Dictionary).duplicate(true)
	for product_id_variant in market.keys():
		var product_id := str(product_id_variant)
		var entry := (market.get(product_id, {}) as Dictionary).duplicate(true)
		entry.erase("weather_price_growth_multiplier")
		entry.erase("weather_modifier")
		entry.erase("weather_contributions")
		entry.erase("weather_driver_summary")
		market[product_id] = entry
	snapshot["product_market"] = market
	return snapshot


static func invalid_save_v2_cases(valid_wire: Dictionary) -> Array[Dictionary]:
	var cases: Array[Dictionary] = []
	var missing_timer := valid_wire.duplicate(true)
	missing_timer.erase("market_timer")
	cases.append({"id": "missing_market_timer", "wire": missing_timer})
	var raw_timer := valid_wire.duplicate(true)
	raw_timer["market_timer"] = 1.25
	cases.append({"id": "raw_float_market_timer", "wire": raw_timer})
	var malformed_tag := valid_wire.duplicate(true)
	malformed_tag["market_timer"] = {"codec": "not_f64", "bits": "0000000000000000"}
	cases.append({"id": "malformed_f64_tag", "wire": malformed_tag})
	var short_bits := valid_wire.duplicate(true)
	short_bits["market_timer"] = {"codec": CODEC.F64_CODEC_ID, "bits": "00"}
	cases.append({"id": "invalid_f64_bits_length", "wire": short_bits})
	var nonfinite := valid_wire.duplicate(true)
	nonfinite["market_timer"] = {"codec": CODEC.F64_CODEC_ID, "bits": "000000000000f07f"}
	cases.append({"id": "nonfinite_f64", "wire": nonfinite})
	var wrong_version := valid_wire.duplicate(true)
	wrong_version["state_version"] = 3
	cases.append({"id": "wrong_state_version", "wire": wrong_version})
	var wrong_ruleset := valid_wire.duplicate(true)
	wrong_ruleset["ruleset_id"] = "v0.7"
	cases.append({"id": "wrong_ruleset_id", "wire": wrong_ruleset})
	var invalid_market := valid_wire.duplicate(true)
	invalid_market["product_market"] = {"": {}}
	cases.append({"id": "invalid_product_market_shape", "wire": invalid_market})
	var negative_cycle := valid_wire.duplicate(true)
	negative_cycle["business_cycle_count"] = -1
	cases.append({"id": "negative_business_cycle_count", "wire": negative_cycle})
	var negative_sequence := valid_wire.duplicate(true)
	negative_sequence["futures_position_sequence"] = -1
	cases.append({"id": "negative_futures_position_sequence", "wire": negative_sequence})
	return cases


static func _runtime_entry(product_id: String, sequence: int) -> Dictionary:
	return {
		"tier": "fixture",
		"base_price": 100,
		"price": 113,
		"trend": 2,
		"raw_trend": 4,
		"price_step_cap": 2,
		"volatility": 4,
		"supply": 3,
		"demand": 7,
		"disrupted": 0,
		"price_history": [100, 113],
		"base_growth_multiplier": 1.0,
		"growth_multiplier": 1.125,
		"growth_seconds": 29.999,
		"growth_turns": 1,
		"growth_source": "fixture",
		"base_growth_source": "fixture-base",
		"base_route_flow_multiplier": 1.0,
		"route_flow_multiplier": 1.25,
		"route_flow_seconds": 30.0,
		"route_flow_turns": 1,
		"route_flow_source": "fixture",
		"base_route_flow_source": "fixture-base",
		"market_contract_demand": 2,
		"market_contract_supply": 1,
		"market_contract_seconds": 30.0,
		"market_contract_turns": 1,
		"market_contract_source": "fixture",
		"futures_positions": [_authored_futures_position(product_id, sequence)],
		"driver_summary": "fixture-driver",
	}


static func _authored_futures_position(product_id: String, sequence: int) -> Dictionary:
	var terms := TERMS_CATALOG.terms_for_card_id("商品看涨1")
	return {
		"position_id": maxi(1, sequence),
		"owner": 0,
		"source": "商品看涨1",
		"card_id": "商品看涨1",
		"product_id": product_id,
		"direction": str(terms.get("direction", "up")),
		"baseline_price": 113,
		"opened_at": 12.125,
		"expires_at": 72.125,
		"duration_seconds": float(terms.get("duration_seconds", 60.0)),
		"multiplier": float(terms.get("multiplier", 1.0)),
		"units": int(terms.get("units", 1)),
		"warehouse_district": 0,
		"warehouse_region_id": "region.001",
		"action_fee_cash": int(terms.get("action_fee_cash", 0)),
		"locked_margin": int(terms.get("margin_cash", 0)),
		"maximum_gain": int(terms.get("maximum_gain", 0)),
		"maximum_loss": int(terms.get("maximum_loss", 0)),
		"terms_version": str(terms.get("terms_version", "v0.4")),
		"settlement_formula_id": str(terms.get("settlement_formula_id", "product_futures_v04_settlement")),
		"warehouse_loss_formula_id": str(terms.get("warehouse_loss_formula_id", "warehouse_futures_v04_loss")),
		"settled": false,
	}
