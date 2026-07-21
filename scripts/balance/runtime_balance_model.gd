extends RefCounted

## Developer-only runtime balance hub.
##
## This file is intentionally small.  Movement and combat physics live in:
## - scripts/balance/movement_balance_model.gd
## - scripts/balance/combat_balance_model.gd
## - scripts/balance/environment_balance_model.gd
##
## main.gd should only call this hub through thin wrappers and pass snapshots of
## real cards/products/monsters when a dev-only report is needed.

const MOVEMENT_BALANCE_MODEL_PATH := "res://scripts/balance/movement_balance_model.gd"
const COMBAT_BALANCE_MODEL_PATH := "res://scripts/balance/combat_balance_model.gd"
const ENVIRONMENT_BALANCE_MODEL_PATH := "res://scripts/balance/environment_balance_model.gd"

const VERSION := "runtime_balance_v1"
const HUB_VERSION := "balance_statistics_hub_v1"

const ROGUELIKE_DEPTH_MIN := 1
const ROGUELIKE_DEPTH_MAX := 6
const DEFAULT_ROGUELIKE_DEPTH := 1

const STARTING_CASH := 2000
const CITY_BUILD_COST := 600
const CITY_FINAL_VALUE := 700
const CITY_PRODUCT_BASE_REVENUE := 42
const CITY_DEMAND_SUPPLY_REVENUE := 28
const CITY_TRANSIT_GDP_BASE := 18
const ECONOMY_CASHFLOW_BASIS_SECONDS := 60.0

const TARGET_GAME_LENGTH_MIN_SECONDS := 1800.0
const TARGET_GAME_LENGTH_MAX_SECONDS := 3600.0
const TARGET_GAME_LENGTH_BASE_SECONDS := 1800.0
const TARGET_GAME_LENGTH_DEPTH_STEP_SECONDS := 360.0
const BALANCE_EXPECTED_CITY_COUNT_MAX := 6

const CARD_PRICE_UNIT := 70
const CARD_PRICE_COST_STEP := 45
const CARD_MIN_PRICE := 80

const PRODUCT_PRICE_MIN := 26
const PRODUCT_PRICE_MAX := 280
const PRODUCT_SUPPLY_PRICE_WEIGHT := 5
const PRODUCT_DEMAND_PRICE_WEIGHT := 8
const PRODUCT_ROUTE_DAMAGE_PRICE_WEIGHT := 10
const PRODUCT_VOLATILITY_MIN := 1
const PRODUCT_VOLATILITY_MAX := 30
const PRODUCT_GROWTH_MULTIPLIER_MAX := 3.0
const ROUTE_FLOW_MULTIPLIER_MAX := 2.8
const REGION_TRANSPORT_SCORE_MIN := 0.55
const REGION_TRANSPORT_SCORE_MAX := 2.4

const MONSTER_OWNER_DAMAGE_CASH_POOL := 700
const MONSTER_OWNER_DAMAGE_CASH_RANK_STEP := 170
const WEATHER_DURATION_MIN_SECONDS := 75.0


func _movement():
	var script = load(MOVEMENT_BALANCE_MODEL_PATH)
	return script.new()


func _combat():
	var script = load(COMBAT_BALANCE_MODEL_PATH)
	return script.new()


func _environment():
	var script = load(ENVIRONMENT_BALANCE_MODEL_PATH)
	return script.new()


func reference_city_gdp_per_minute():
	return maxi(1, CITY_PRODUCT_BASE_REVENUE + CITY_DEMAND_SUPPLY_REVENUE + CITY_TRANSIT_GDP_BASE)


func expected_city_count_for_depth(depth: int = -1):
	return clampi(_safe_depth(depth), 1, BALANCE_EXPECTED_CITY_COUNT_MAX)


func target_game_seconds(depth: int = -1):
	var value = _safe_depth(depth)
	return clampf(TARGET_GAME_LENGTH_BASE_SECONDS + float(value - 1) * TARGET_GAME_LENGTH_DEPTH_STEP_SECONDS, TARGET_GAME_LENGTH_MIN_SECONDS, TARGET_GAME_LENGTH_MAX_SECONDS)


func target_game_window_seconds(depth: int = -1):
	var target = target_game_seconds(depth)
	return {
		"min_seconds": TARGET_GAME_LENGTH_MIN_SECONDS,
		"target_seconds": target,
		"max_seconds": TARGET_GAME_LENGTH_MAX_SECONDS,
		"soft_min_seconds": maxf(TARGET_GAME_LENGTH_MIN_SECONDS, target * 0.86),
		"soft_max_seconds": minf(TARGET_GAME_LENGTH_MAX_SECONDS, target * 1.16),
	}


func region_count_range_for_depth(depth: int = -1):
	return _movement().call("region_count_range_for_depth", depth)


func planet_size_for_depth(depth: int = -1):
	return _movement().call("planet_size_for_depth", depth)


func region_size_model(depth: int = -1, region_count: int = -1):
	return _movement().call("region_size_model", depth, region_count)


func expected_engine_gdp_per_minute(depth: int = -1, city_count: int = -1):
	var value = _safe_depth(depth)
	var cities = expected_city_count_for_depth(value) if city_count < 0 else maxi(1, city_count)
	var route_maturity_multiplier = 1.0 + minf(0.18, float(maxi(0, value - 1)) * 0.03)
	return maxi(1, int(round(float(reference_city_gdp_per_minute() * cities) * route_maturity_multiplier)))


func expected_city_asset_value(depth: int = -1, city_count: int = -1):
	var cities = expected_city_count_for_depth(depth) if city_count < 0 else maxi(1, city_count)
	return STARTING_CASH - CITY_BUILD_COST * cities + CITY_FINAL_VALUE * cities


func victory_cash_goal_for_duration(depth: int = -1, target_seconds_override: float = -1.0):
	var value = _safe_depth(depth)
	var target = target_game_seconds(value) if target_seconds_override < 0.0 else clampf(target_seconds_override, TARGET_GAME_LENGTH_MIN_SECONDS, TARGET_GAME_LENGTH_MAX_SECONDS)
	var raw_goal = expected_city_asset_value(value) + int(round(float(expected_engine_gdp_per_minute(value)) * target / ECONOMY_CASHFLOW_BASIS_SECONDS))
	return maxi(STARTING_CASH + 1200, int(round(float(raw_goal) / 10.0)) * 10)


func product_price_step_cap(volatility: int, base_price: int = 100):
	var safe_volatility = clampi(volatility, PRODUCT_VOLATILITY_MIN, PRODUCT_VOLATILITY_MAX)
	var pct_cap = 0.12
	if safe_volatility >= 18:
		pct_cap = 0.40
	elif safe_volatility >= 9:
		pct_cap = 0.22
	return maxi(4, int(round(float(maxi(1, base_price)) * pct_cap)))


func product_price_model(base_price: int, supply_score: int, demand_score: int, route_damage_score: int, monster_pressure: int = 0, weather_modifier: int = 0, volatility: int = 4, random_noise: float = 0.0, growth_multiplier: float = 1.0):
	var safe_base = clampi(base_price, PRODUCT_PRICE_MIN, PRODUCT_PRICE_MAX)
	var safe_growth = clampf(growth_multiplier, 1.0, PRODUCT_GROWTH_MULTIPLIER_MAX)
	var positive_pressure = float(maxi(0, demand_score) * PRODUCT_DEMAND_PRICE_WEIGHT + maxi(0, route_damage_score) * PRODUCT_ROUTE_DAMAGE_PRICE_WEIGHT + maxi(0, monster_pressure) * 6 + weather_modifier)
	var negative_pressure = float(maxi(0, supply_score) * PRODUCT_SUPPLY_PRICE_WEIGHT)
	var raw_delta = int(round(positive_pressure * safe_growth - negative_pressure + random_noise))
	var cap = product_price_step_cap(volatility, safe_base)
	var capped_delta = clampi(raw_delta, -cap, cap)
	return {
		"base_price": safe_base,
		"supply_score": maxi(0, supply_score),
		"demand_score": maxi(0, demand_score),
		"route_damage_score": maxi(0, route_damage_score),
		"monster_pressure": maxi(0, monster_pressure),
		"weather_modifier": weather_modifier,
		"volatility": clampi(volatility, PRODUCT_VOLATILITY_MIN, PRODUCT_VOLATILITY_MAX),
		"growth_multiplier": safe_growth,
		"raw_delta": raw_delta,
		"step_cap": cap,
		"delta": capped_delta,
		"price": clampi(safe_base + capped_delta, PRODUCT_PRICE_MIN, PRODUCT_PRICE_MAX),
		"driver_summary": "需%d/供%d/断路%d/怪兽%d/天气%d/增速×%.2f" % [demand_score, supply_score, route_damage_score, monster_pressure, weather_modifier, safe_growth],
	}


func product_flow_speed_model(product_name: String = "", transport_score: float = 1.0, route_flow_multiplier: float = 1.0, route_damage: int = 0, weather_multiplier: float = 1.0):
	var transport = clampf(transport_score, REGION_TRANSPORT_SCORE_MIN, REGION_TRANSPORT_SCORE_MAX)
	var route_multiplier = clampf(route_flow_multiplier, 0.2, ROUTE_FLOW_MULTIPLIER_MAX)
	var damage_multiplier = clampf(1.0 - float(maxi(0, route_damage)) * 0.16, 0.25, 1.0)
	var weather = clampf(weather_multiplier, 0.35, 1.85)
	var units_per_minute = 60.0 * transport * route_multiplier * damage_multiplier * weather
	return {
		"product": product_name,
		"transport_score": transport,
		"route_flow_multiplier": route_multiplier,
		"route_damage": maxi(0, route_damage),
		"route_damage_multiplier": damage_multiplier,
		"weather_multiplier": weather,
		"flow_units_per_minute": units_per_minute,
		"flow_units_per_second": units_per_minute / ECONOMY_CASHFLOW_BASIS_SECONDS,
	}


func market_refresh_interval_seconds(depth: int = -1, volatility_level: int = 1):
	return float(_environment().call("market_refresh_interval_seconds", depth, volatility_level))


func weather_forecast_window_seconds(depth: int = -1, volatility_level: int = 1):
	return float(_environment().call("weather_forecast_window_seconds", depth, volatility_level))


func weather_duration_seconds(weather_state: String = "clear", depth: int = -1):
	return float(_environment().call("weather_duration_seconds", weather_state, depth))


func weather_zone_count_model(depth: int = -1, region_count: int = -1):
	return _environment().call("weather_zone_count_model", depth, region_count)


func weather_state_effect_model(weather_state: String, terrain: String = "", product_category: String = ""):
	return _environment().call("weather_state_effect_model", weather_state, terrain, product_category)


func economic_volatility_model(base_volatility: int = 4, supply_pressure: int = 0, demand_pressure: int = 0, route_damage: int = 0, monster_pressure: int = 0, weather_pressure: int = 0, contract_pressure: int = 0):
	return _environment().call("economic_volatility_model", base_volatility, supply_pressure, demand_pressure, route_damage, monster_pressure, weather_pressure, contract_pressure)


func global_environment_refresh_model(depth: int = -1, region_count: int = -1, active_weather_count: int = 0, volatility_level: int = 1):
	return _environment().call("global_environment_refresh_model", depth, region_count, active_weather_count, volatility_level)


func monster_region_exit_speed_model(depth: int = -1, region_count: int = -1, terrain_multiplier: float = 1.0, speed_rating: float = 1.0):
	return _movement().call("monster_region_exit_speed_model", depth, region_count, terrain_multiplier, speed_rating)


func monster_movement_speed_model(actor: Dictionary, terrain_multiplier: float = 1.0, action_speed_mps: float = -1.0, region_radius_m: float = -1.0, target_region_exit_seconds: float = 10.0):
	return _movement().call("monster_movement_speed_model", actor, terrain_multiplier, action_speed_mps, region_radius_m, target_region_exit_seconds)


func monster_ecology_speed_multiplier(actor: Dictionary):
	return float(_movement().call("monster_ecology_speed_multiplier", actor))


func military_movement_speed_model(unit: Dictionary, terrain_multiplier: float = 1.0, command_speed_mps: float = -1.0, region_radius_m: float = -1.0):
	return _movement().call("military_movement_speed_model", unit, terrain_multiplier, command_speed_mps, region_radius_m)


func military_domain_speed_multiplier(unit: Dictionary):
	return float(_movement().call("military_domain_speed_multiplier", unit))


func monster_knockback_distance_model(action: Dictionary, actor: Dictionary = {}, region_radius_m: float = -1.0):
	return _combat().call("monster_knockback_distance_model", action, actor, region_radius_m)


func monster_knockback_profile(action: Dictionary):
	return String(_combat().call("monster_knockback_profile", action))


func monster_knockback_speed_model(action: Dictionary, actor: Dictionary = {}, region_radius_m: float = -1.0, duration_seconds: float = 0.5):
	return _combat().call("monster_knockback_speed_model", action, actor, region_radius_m, duration_seconds)


func monster_attack_model(action: Dictionary, actor: Dictionary = {}):
	return _combat().call("monster_attack_model", action, actor)


func owner_damage_cash_total_for_rank(rank: int):
	return MONSTER_OWNER_DAMAGE_CASH_POOL + (clampi(rank, 1, 4) - 1) * MONSTER_OWNER_DAMAGE_CASH_RANK_STEP


func skill_price_power_adjustment(skill: Dictionary):
	var kind = String(skill.get("kind", ""))
	var futures_terms: Dictionary = _dict_or_empty(skill.get("futures_terms", {}))
	var derivative_terms: Dictionary = _dict_or_empty(skill.get("gdp_derivative_terms", {}))
	var tags = _as_array(skill.get("tags", []))
	var adjustment = 0
	adjustment += mini(90, int(round(float(abs(int(skill.get("cash", 0)))) / 8.0)))
	adjustment += mini(95, int(round(float(abs(int(skill.get("revenue_amount", 0)))) / 3.0)))
	adjustment += mini(80, int(round(float(abs(int(skill.get("contract_income", 0)))) / 4.0)))
	adjustment += maxi(0, int(skill.get("production_delta", 0))) * 10
	adjustment += maxi(0, int(skill.get("transport_delta", 0))) * 10
	adjustment += maxi(0, int(skill.get("consumption_delta", 0))) * 10
	adjustment += maxi(0, int(skill.get("market_demand_pressure", 0))) * 12
	adjustment += maxi(0, int(skill.get("market_supply_pressure", 0))) * 12
	adjustment += maxi(0, int(skill.get("route_damage", 0))) * 24
	adjustment += maxi(0, int(skill.get("repair_routes", 0))) * 18
	adjustment += maxi(0, int(skill.get("damage", 0))) * 18
	adjustment += maxi(0, int(skill.get("draw_amount", 0))) * 26
	if kind == "monster_card":
		adjustment += 46 + mini(70, int(round(float(int(skill.get("hp", 0))) / 8.0))) + maxi(0, int(skill.get("fixed_skill_count", 0))) * 12
	if kind == "military_force":
		adjustment += 32 + mini(65, int(round(float(int(skill.get("military_hp", 0))) / 4.0))) + maxi(0, int(skill.get("military_damage", 0))) * 13
		adjustment += mini(55, int(round(float(int(skill.get("military_gdp_penalty", 0))) / 3.0))) + maxi(0, int(skill.get("military_strike_route_damage", 0))) * 22
	if kind == "product_futures":
		adjustment += 28 + int(round(float(futures_terms.get("multiplier", 1.0)) * 18.0)) + maxi(0, int(futures_terms.get("units", 0))) * 8
	if kind == "city_gdp_derivative":
		adjustment += 30 + int(round(float(derivative_terms.get("multiplier", 1.0)) * 18.0)) + mini(60, int(round(float(maxi(0, int(derivative_terms.get("maximum_gain", 0)))) / 20.0)))
	if ["player_hand_disrupt", "player_hand_steal", "city_control_dispute", "global_barrage", "card_counter"].has(kind):
		adjustment += 34 + maxi(0, int(skill.get("hand_discard_count", 0))) * 35 + maxi(0, int(skill.get("hand_steal_count", 0))) * 52
		adjustment += maxi(0, int(skill.get("global_barrage_target_count", 0))) * 18 + maxi(0, int(skill.get("counter_strength", 0))) * 28
	if tags.has("情报") or kind.begins_with("intel_"):
		adjustment += 18
	if tags.has("天气") or kind == "weather_control":
		adjustment += 16 + maxi(0, int(skill.get("weather_zone_count", 0))) * 10
	if bool(futures_terms.get("requires_warehouse", false)):
		adjustment -= 34
	var region_share_required = skill_play_region_gdp_share_required(skill)
	if region_share_required > 0:
		# Preserve roughly the old 0-48 gate-discount band while making the
		# public regional GDP threshold the only normal economic play gate.
		adjustment -= mini(48, int(round(float(region_share_required) * 1.2)))
	if float(futures_terms.get("duration_seconds", 0.0)) >= 90.0 or float(derivative_terms.get("duration_seconds", 0.0)) >= 90.0:
		adjustment -= 12
	if int(skill.get("play_cash_per_monster", 0)) > 0:
		adjustment -= 12
	return clampi(adjustment, -60, 190)


func card_price_for_skill(skill: Dictionary, district_multiplier: float = 1.0):
	var power_cost = maxi(2, int(skill.get("cost", 2)))
	var price = CARD_PRICE_UNIT + (power_cost - 2) * CARD_PRICE_COST_STEP + skill_price_power_adjustment(skill)
	return int(max(CARD_MIN_PRICE, round(float(price) * district_multiplier)))


func card_price_tier_text(price: int):
	if price <= 125:
		return "基础档"
	if price <= 210:
		return "进阶档"
	if price <= 305:
		return "高阶档"
	return "旗舰档"


func runtime_balance_audit_report(snapshot: Dictionary = {}):
	return {
		"version": VERSION,
		"starting_cash": STARTING_CASH,
		"city_build_cost": CITY_BUILD_COST,
		"city_final_value": CITY_FINAL_VALUE,
		"reference_city_gdp_per_minute": reference_city_gdp_per_minute(),
		"game_length_rows": runtime_balance_game_length_rows(),
		"planet_geometry_rows": runtime_balance_planet_geometry_rows(snapshot),
		"cash_goal_rows": runtime_balance_cash_goal_rows(snapshot),
		"card_price_rows": runtime_balance_card_price_rows(snapshot),
		"monster_damage_cash_rows": runtime_balance_monster_damage_cash_rows(),
		"monster_combat_rows": runtime_balance_monster_combat_rows(snapshot),
		"product_price_rows": runtime_balance_product_price_rows(),
		"flow_speed_rows": runtime_balance_flow_speed_rows(),
		"environment_rows": runtime_balance_environment_rows(),
		"system_constraint_rows": runtime_balance_system_constraint_rows(),
		"rule_loopholes": runtime_balance_rule_loophole_rows(),
	}


func statistics_hub_report(snapshot: Dictionary = {}, sample_only: bool = true):
	var game_length_rows = runtime_balance_game_length_rows()
	var environment_report = runtime_balance_environment_rows()
	var environment_refresh_rows = _as_array(_dict_or_empty(environment_report).get("refresh_rows", []))
	var card_report = balance_card_statistics_report(snapshot, sample_only)
	var product_report = balance_product_statistics_report(snapshot)
	var monster_report = balance_monster_statistics_report(snapshot)
	var ai_report = balance_ai_statistics_report(snapshot)
	var constraints = balance_cross_system_constraint_report(game_length_rows, card_report, product_report, monster_report, ai_report)
	return {
		"version": HUB_VERSION,
		"dev_only": true,
		"player_ui_allowed": false,
		"summary": {
			"target_min_minutes": TARGET_GAME_LENGTH_MIN_SECONDS / 60.0,
			"target_max_minutes": TARGET_GAME_LENGTH_MAX_SECONDS / 60.0,
			"card_vector_count": int(card_report.get("card_count", 0)),
			"product_count": int(product_report.get("product_count", 0)),
			"monster_family_count": int(monster_report.get("monster_family_count", 0)),
			"ai_route_count": int(ai_report.get("route_count", 0)),
			"environment_depth_count": environment_refresh_rows.size(),
		},
		"runtime": runtime_balance_audit_report(snapshot),
		"game_length": game_length_rows,
		"planet_geometry": runtime_balance_planet_geometry_rows(snapshot),
		"environment": environment_report,
		"cards": card_report,
		"products": product_report,
		"monsters": monster_report,
		"ai": ai_report,
		"constraints": constraints,
	}


func developer_greybox_snapshot(snapshot: Dictionary = {}, enabled: bool = false):
	var report = statistics_hub_report(snapshot, true)
	return {
		"version": "developer_balance_greybox_v1",
		"dev_only": true,
		"player_ui_allowed": false,
		"enabled": enabled,
		"title": "DEV BALANCE HUB",
		"summary": report.get("summary", {}),
		"constraints": report.get("constraints", {}),
		"rows": runtime_balance_cash_goal_rows(snapshot),
		"planet_geometry": runtime_balance_planet_geometry_rows(snapshot),
	}


func runtime_balance_game_length_rows():
	var rows = []
	for depth in range(ROGUELIKE_DEPTH_MIN, ROGUELIKE_DEPTH_MAX + 1):
		var window = target_game_window_seconds(depth)
		rows.append({
			"depth": depth,
			"depth_label": _rank_label(depth),
			"target_minutes": float(window.get("target_seconds", 0.0)) / 60.0,
			"soft_min_minutes": float(window.get("soft_min_seconds", 0.0)) / 60.0,
			"soft_max_minutes": float(window.get("soft_max_seconds", 0.0)) / 60.0,
			"hard_min_minutes": TARGET_GAME_LENGTH_MIN_SECONDS / 60.0,
			"hard_max_minutes": TARGET_GAME_LENGTH_MAX_SECONDS / 60.0,
		})
	return rows


func runtime_balance_planet_geometry_rows(snapshot: Dictionary = {}):
	var snapshot_regions = _dict_or_empty(snapshot.get("region_rows", {}))
	var rows = []
	for depth in range(ROGUELIKE_DEPTH_MIN, ROGUELIKE_DEPTH_MAX + 1):
		var count_range = region_count_range_for_depth(depth)
		if snapshot_regions.has(depth):
			var override = _dict_or_empty(snapshot_regions[depth])
			count_range["region_min"] = int(override.get("min", count_range.get("region_min", 6)))
			count_range["region_max"] = int(override.get("max", count_range.get("region_max", 9)))
			count_range["region_mid"] = int(round(float(int(count_range["region_min"]) + int(count_range["region_max"])) * 0.5))
		var mid_count = int(count_range.get("region_mid", 1))
		var size = region_size_model(depth, mid_count)
		var radius = float(size.get("avg_region_radius_m", 180.0))
		var normal_speed = monster_region_exit_speed_model(depth, mid_count, 1.0, 1.0)
		var flying_speed = monster_region_exit_speed_model(depth, mid_count, 1.0, 10.0)
		var sea_speed = monster_region_exit_speed_model(depth, mid_count, 1.0, 6.5)
		var military_speed = military_movement_speed_model({"military_domain": "mixed", "military_type": "defense", "move": 260.0}, 1.0, -1.0, radius)
		size["depth_label"] = _rank_label(depth)
		size["normal_monster_speed_mps"] = float(normal_speed.get("speed_mps", 0.0))
		size["normal_region_exit_seconds"] = float(normal_speed.get("estimated_region_exit_seconds", 0.0))
		size["flying_monster_speed_mps"] = float(flying_speed.get("speed_mps", 0.0))
		size["sea_monster_speed_mps"] = float(sea_speed.get("speed_mps", 0.0))
		size["standard_military_speed_mps"] = float(military_speed.get("speed_mps", 0.0))
		size["standard_military_exit_seconds"] = float(military_speed.get("estimated_region_exit_seconds", 0.0))
		rows.append(size)
	return rows


func runtime_balance_cash_goal_rows(snapshot: Dictionary = {}):
	var region_rows = _dict_or_empty(snapshot.get("region_rows", {}))
	var rows = []
	var opening_after_one_city = STARTING_CASH - CITY_BUILD_COST + CITY_FINAL_VALUE
	for depth in range(ROGUELIKE_DEPTH_MIN, ROGUELIKE_DEPTH_MAX + 1):
		var expected_gdp = expected_engine_gdp_per_minute(depth)
		var assets = expected_city_asset_value(depth)
		var goal = victory_cash_goal_for_duration(depth)
		var expected_seconds = float(maxi(0, goal - assets)) / float(maxi(1, expected_gdp)) * ECONOMY_CASHFLOW_BASIS_SECONDS
		var reference_seconds_after_one_city = float(maxi(0, goal - opening_after_one_city)) / float(reference_city_gdp_per_minute()) * ECONOMY_CASHFLOW_BASIS_SECONDS
		var count_range = region_count_range_for_depth(depth)
		if region_rows.has(depth):
			var override = _dict_or_empty(region_rows[depth])
			count_range["region_min"] = int(override.get("min", count_range.get("region_min", 6)))
			count_range["region_max"] = int(override.get("max", count_range.get("region_max", 9)))
		rows.append({
			"depth": depth,
			"depth_label": _rank_label(depth),
			"region_min": int(count_range.get("region_min", 0)),
			"region_max": int(count_range.get("region_max", 0)),
			"expected_city_count": expected_city_count_for_depth(depth),
			"expected_engine_gdp_per_minute": expected_gdp,
			"expected_city_assets": assets,
			"cash_goal": goal,
			"gap_after_one_city": goal - opening_after_one_city,
			"expected_minutes_to_goal": expected_seconds / 60.0,
			"reference_minutes_after_one_city": reference_seconds_after_one_city / 60.0,
		})
	return rows


func runtime_balance_product_price_rows():
	var scenarios = [
		{"name": "稳定食物", "base": 80, "supply": 2, "demand": 3, "route": 0, "monster": 0, "weather": 0, "volatility": 4},
		{"name": "普通能源", "base": 110, "supply": 1, "demand": 5, "route": 2, "monster": 1, "weather": 0, "volatility": 11},
		{"name": "危机奢侈品", "base": 150, "supply": 0, "demand": 7, "route": 4, "monster": 3, "weather": 8, "volatility": 22},
		{"name": "供给过剩材料", "base": 95, "supply": 8, "demand": 2, "route": 0, "monster": 0, "weather": 0, "volatility": 8},
	]
	var rows = []
	for scenario in scenarios:
		var model = product_price_model(int(scenario["base"]), int(scenario["supply"]), int(scenario["demand"]), int(scenario["route"]), int(scenario["monster"]), int(scenario["weather"]), int(scenario["volatility"]))
		model["scenario"] = scenario["name"]
		rows.append(model)
	return rows


func runtime_balance_flow_speed_rows():
	return [
		product_flow_speed_model("稳定陆运", 1.0, 1.0, 0, 1.0),
		product_flow_speed_model("高速海运", 1.6, 1.25, 0, 1.0),
		product_flow_speed_model("受损商道", 1.2, 1.0, 3, 0.9),
		product_flow_speed_model("风暴封锁", 0.9, 0.85, 4, 0.55),
	]


func runtime_balance_environment_rows():
	var rows = []
	for depth in range(ROGUELIKE_DEPTH_MIN, ROGUELIKE_DEPTH_MAX + 1):
		var region_range = region_count_range_for_depth(depth)
		var refresh = global_environment_refresh_model(depth, int(region_range.get("region_mid", -1)), 0, 1)
		rows.append(refresh)
	var effect_rows = _environment().call("environment_causal_rows")
	return {"refresh_rows": rows, "weather_effect_rows": effect_rows}


func runtime_balance_monster_combat_rows(snapshot: Dictionary = {}):
	var monsters = _as_array(snapshot.get("monsters", []))
	if monsters.is_empty():
		monsters = [
			{"name": "陆行碾城兽", "rank": 1, "move": 190.0, "movement_mode": "walk", "move_damage": 1, "actions": [{"name": "撞击", "damage": 1, "range": 110.0, "knockback_profile": "melee"}]},
			{"name": "飞翼掠夺体", "rank": 2, "move": 260.0, "movement_mode": "fly", "movement_traits": ["flying"], "move_damage": 0, "actions": [{"name": "白谱光线", "damage": 2, "range": 520.0, "knockback_profile": "beam"}]},
		]
	var rows = []
	for monster_variant in monsters:
		if not (monster_variant is Dictionary):
			continue
		var monster = monster_variant
		var actions = _as_array(monster.get("actions", []))
		if actions.is_empty():
			actions = [{"name": "普通攻击", "damage": 1, "range": 100.0}]
		var movement_row = monster_movement_speed_model(monster, float(monster.get("terrain_move_multiplier", 1.0)))
		var action = actions[0] if actions[0] is Dictionary else {}
		var attack_row = monster_attack_model(action, monster)
		rows.append({"monster": String(monster.get("name", "")), "rank": int(monster.get("rank", 1)), "movement": movement_row, "attack": attack_row})
	return rows


func runtime_balance_system_constraint_rows():
	var rows = []
	for depth in range(ROGUELIKE_DEPTH_MIN, ROGUELIKE_DEPTH_MAX + 1):
		rows.append(balance_system_constraint_report(depth))
	return rows


func runtime_balance_card_price_rows(snapshot: Dictionary = {}):
	var rows = []
	for entry_variant in _card_entries(snapshot, true):
		if not (entry_variant is Dictionary):
			continue
		var entry = entry_variant
		var skill = _dict_or_empty(entry.get("skill", {}))
		if skill.is_empty():
			continue
		var card_name = String(entry.get("card_name", skill.get("name", "")))
		var price = int(entry.get("price", card_price_for_skill(skill)))
		var vector = skill_balance_feature_vector(card_name, skill, int(entry.get("rank", _rank_from_card_name(card_name))), String(entry.get("family", _skill_family(card_name))), price, String(entry.get("route_id", "")), String(entry.get("route_label", "")))
		var breakdown = _dict_or_empty(vector.get("score_breakdown", {}))
		rows.append({
			"card": card_name,
			"price_anchor": String(entry.get("price_anchor", "%s1" % _skill_family(card_name))),
			"family": vector.get("family", ""),
			"rank": vector.get("rank", 1),
			"rank_label": vector.get("rank_label", "I"),
			"kind": vector.get("kind", ""),
			"cost": int(skill.get("cost", 0)),
			"field_adjustment": skill_price_power_adjustment(skill),
			"actual_price": price,
			"tier": card_price_tier_text(price),
			"supply_product": skill_supply_product(skill),
			"play_requirement_kind": skill_play_requirement_kind(skill),
			"play_region_scope": skill_play_region_scope(skill),
			"play_region_gdp_share_required": skill_play_region_gdp_share_required(skill),
			"play_flow_required": skill_play_flow_required(skill),
			"cash": int(skill.get("cash", 0)),
			"revenue_amount": int(skill.get("revenue_amount", 0)),
			"damage": int(skill.get("damage", 0)),
			"route_damage": int(skill.get("route_damage", 0)),
			"market_demand_pressure": int(skill.get("market_demand_pressure", 0)),
			"market_supply_pressure": int(skill.get("market_supply_pressure", 0)),
			"route_tags": vector.get("route_tags", []),
			"ai_play_tags": vector.get("ai_play_tags", []),
			"power_score": int(breakdown.get("power_score", 0)),
			"complexity_score": int(breakdown.get("complexity_score", 0)),
		})
	return rows


func runtime_balance_monster_damage_cash_rows():
	var rows = []
	for rank in range(1, 5):
		var pool = owner_damage_cash_total_for_rank(rank)
		for ratio in [0.05, 0.10, 0.25, 0.50, 1.00]:
			rows.append({"rank": rank, "rank_label": _rank_label(rank), "owner_damage_cash_pool": pool, "hp_damage_ratio": ratio, "cash_loss": int(round(float(pool) * float(ratio))), "pool_to_starting_cash_pct": float(pool) / float(STARTING_CASH), "damage_basis": "actual_hp_lost_not_overkill"})
	return rows


func runtime_balance_rule_loophole_rows():
	return [
		{"rule": "victory_goal_depth_gap", "status": "patched", "player_facing": "深度I目标现金不再贴近开局一城后的资产。", "test_focus": "现金目标随深度递增，首局接近30分钟。"},
		{"rule": "card_purchase_price_gradient", "status": "patched", "player_facing": "购买价按I级锚定，同时读取高杠杆字段加价。", "test_focus": "金融/军队/互动牌价格高于基础牌。"},
		{"rule": "monster_owner_damage_cash_ratio", "status": "patched", "player_facing": "怪兽受伤让召唤者输钱时，只按实际损失生命结算。", "test_focus": "过量伤害不放大赔付。"},
		{"rule": "global_environment_causal_functions", "status": "patched", "player_facing": "天气和市场刷新属于公开全局信息，并通过供需/断路/怪兽/天气压力影响商品。", "test_focus": "市场刷新、天气预报、天气效果和波动带均由独立模型输出。"},
	]


func skill_balance_numeric_field_names():
	return ["cash", "revenue_amount", "contract_income", "production_delta", "transport_delta", "consumption_delta", "market_demand_pressure", "market_supply_pressure", "price_delta", "growth_multiplier", "route_flow_multiplier", "repair_routes", "route_damage", "damage", "panic", "draw_amount", "history_review_count", "history_subscription_count", "reveal_city_count", "hand_discard_count", "hand_steal_count", "counter_strength", "counter_trace", "global_barrage_damage", "global_barrage_target_count", "global_barrage_route_damage", "hp", "fixed_skill_count", "military_hp", "military_damage", "military_gdp_penalty", "military_strike_route_damage", "weather_zone_count", "weather_duration_seconds"]


func skill_balance_feature_vector(card_name: String, skill: Dictionary, rank: int = 1, family: String = "", price: int = 0, route_id: String = "", route_label: String = ""):
	var safe_name = card_name if card_name != "" else String(skill.get("name", ""))
	if safe_name == "" or skill.is_empty():
		return {}
	var safe_rank = clampi(rank if rank > 0 else _rank_from_card_name(safe_name), 1, 4)
	var numeric_fields = {}
	var present_fields = []
	for field_variant in skill_balance_numeric_field_names():
		var field_name = String(field_variant)
		var value = float(skill.get(field_name, 0.0))
		numeric_fields[field_name] = value
		if absf(value) > 0.001:
			present_fields.append(field_name)
	var actual_price = price if price > 0 else card_price_for_skill(skill)
	var points = card_strength_budget_points(skill)
	return {
		"card_name": safe_name,
		"family": family if family != "" else _skill_family(safe_name),
		"rank": safe_rank,
		"rank_label": _rank_label(safe_rank),
		"kind": String(skill.get("kind", "")),
		"route_id": route_id if route_id != "" else _route_id_for_skill(skill),
		"route_label": route_label if route_label != "" else _route_label_for_skill(skill),
		"route_tags": skill_balance_route_tags(skill),
		"ai_play_tags": skill_balance_ai_play_tags(skill),
		"target_type": skill_balance_target_type(skill),
		"numeric_fields": numeric_fields,
		"present_fields": present_fields,
		"play_gate": skill_balance_play_gate(skill),
		"price": actual_price,
		"price_tier": card_price_tier_text(actual_price),
		"price_adjustment": skill_price_power_adjustment(skill),
		"strength_budget_points": points,
		"strength_budget_band": card_strength_budget_band_text(points),
		"score_breakdown": skill_balance_score_breakdown(skill, safe_rank),
	}


func skill_balance_score_breakdown(skill: Dictionary, rank: int = 1):
	var kind = String(skill.get("kind", ""))
	var futures_terms: Dictionary = _dict_or_empty(skill.get("futures_terms", {}))
	var derivative_terms: Dictionary = _dict_or_empty(skill.get("gdp_derivative_terms", {}))
	var cash_score = int(float(maxi(0, int(skill.get("cash", 0)))) / 4.0) + int(float(maxi(0, int(skill.get("contract_income", 0)))) / 5.0)
	var economy_score = int(float(maxi(0, int(skill.get("revenue_amount", 0)))) / 2.0) + maxi(0, int(skill.get("production_delta", 0))) * 42 + maxi(0, int(skill.get("transport_delta", 0))) * 42 + maxi(0, int(skill.get("consumption_delta", 0))) * 42
	var market_score = abs(int(skill.get("market_demand_pressure", 0))) * 34 + abs(int(skill.get("market_supply_pressure", 0))) * 34 + int(float(abs(int(skill.get("price_delta", 0)))) / 2.0)
	var futures_score = 80 + int(round(maxf(0.1, float(futures_terms.get("multiplier", 1.0))) * 70.0)) + maxi(0, int(futures_terms.get("units", 0))) * 32 + int(float(maxi(0, int(futures_terms.get("maximum_gain", 0))) - maxi(0, int(futures_terms.get("maximum_loss", 0)))) / 8.0) if kind == "product_futures" else 0
	var gdp_score = 90 + int(round(maxf(0.1, float(derivative_terms.get("multiplier", 1.0))) * 70.0)) + int(float(maxi(0, int(derivative_terms.get("maximum_gain", 0)))) / 8.0) + int(float(maxi(0, int(derivative_terms.get("maximum_loss", 0)))) / 12.0) if kind == "city_gdp_derivative" else 0
	var route_score = maxi(0, int(skill.get("repair_routes", 0))) * 48 + maxi(0, int(skill.get("route_damage", 0))) * 62
	var damage_score = maxi(0, int(skill.get("damage", 0))) * 58 + maxi(0, int(skill.get("global_barrage_damage", 0))) * 74 + maxi(0, int(skill.get("global_barrage_target_count", 0))) * 32
	var interaction_score = maxi(0, int(skill.get("hand_discard_count", 0))) * 82 + maxi(0, int(skill.get("hand_steal_count", 0))) * 112 + maxi(0, int(skill.get("global_barrage_route_damage", 0))) * 56
	var defense_score = maxi(0, int(skill.get("armor", 0))) * 35 + maxi(0, int(skill.get("guard", 0))) * 42 + maxi(0, int(skill.get("counter_strength", 0))) * 58
	var intel_score = maxi(0, int(skill.get("history_review_count", 0))) * 28 + maxi(0, int(skill.get("history_subscription_count", 0))) * 24 + maxi(0, int(skill.get("reveal_city_count", 0))) * 48 + maxi(0, int(skill.get("counter_trace", 0))) * 42
	var monster_score = 140 + maxi(0, int(skill.get("hp", 0))) * 7 + maxi(0, int(skill.get("fixed_skill_count", 0))) * 36 if kind == "monster_card" else 0
	var military_score = 70 + maxi(0, int(skill.get("military_hp", 0))) * 7 + maxi(0, int(skill.get("military_damage", 0))) * 70 if ["military_force", "military_command"].has(kind) else 0
	var weather_score = maxi(1, int(skill.get("weather_zone_count", 1))) * 42 + int(round(float(skill.get("weather_duration_seconds", WEATHER_DURATION_MIN_SECONDS)) / 3.0)) if kind == "weather_control" else 0
	var gate_penalty = skill_play_region_gdp_share_required(skill) * 2 + int(float(skill_play_cash_cost(skill)) / 20.0)
	var complexity_score = skill_balance_complexity_score(skill, rank)
	var power_score = cash_score + economy_score + market_score + futures_score + gdp_score + route_score + damage_score + interaction_score + defense_score + intel_score + monster_score + military_score + weather_score
	return {"cash_score": cash_score, "economy_score": economy_score, "market_score": market_score, "futures_score": futures_score, "gdp_derivative_score": gdp_score, "route_score": route_score, "damage_score": damage_score, "interaction_score": interaction_score, "defense_score": defense_score, "intel_score": intel_score, "monster_score": monster_score, "military_score": military_score, "weather_score": weather_score, "gate_penalty": gate_penalty, "public_telegraph_score": skill_balance_public_telegraph_score(skill), "tempo_score": cash_score + damage_score + int(float(route_score) / 3.0), "engine_score": economy_score + market_score + futures_score + gdp_score + int(float(route_score) / 2.0), "disruption_score": interaction_score + damage_score + route_score, "complexity_score": complexity_score, "power_score": maxi(1, power_score), "net_power_score": maxi(1, power_score - int(float(gate_penalty) / 2.0))}


func runtime_balance_card_feature_matrix(snapshot: Dictionary = {}, sample_only: bool = true):
	var result = []
	for entry_variant in _card_entries(snapshot, sample_only):
		if not (entry_variant is Dictionary):
			continue
		var entry = entry_variant
		var skill = _dict_or_empty(entry.get("skill", {}))
		if skill.is_empty():
			continue
		var name = String(entry.get("card_name", skill.get("name", "")))
		result.append(skill_balance_feature_vector(name, skill, int(entry.get("rank", _rank_from_card_name(name))), String(entry.get("family", _skill_family(name))), int(entry.get("price", card_price_for_skill(skill))), String(entry.get("route_id", "")), String(entry.get("route_label", ""))))
	return result


func balance_card_statistics_report(snapshot: Dictionary = {}, sample_only: bool = true):
	var matrix = runtime_balance_card_feature_matrix(snapshot, sample_only)
	var route_counts = {}
	var ai_tag_counts = {}
	var total_price = 0
	var total_power = 0
	var max_price = 0
	var max_power = 0
	for entry_variant in matrix:
		var entry = entry_variant
		total_price += int(entry.get("price", 0))
		max_price = maxi(max_price, int(entry.get("price", 0)))
		var breakdown = _dict_or_empty(entry.get("score_breakdown", {}))
		total_power += int(breakdown.get("power_score", 0))
		max_power = maxi(max_power, int(breakdown.get("power_score", 0)))
		var route_id = String(entry.get("route_id", "unknown"))
		route_counts[route_id] = int(route_counts.get(route_id, 0)) + 1
		for tag_variant in _as_array(entry.get("ai_play_tags", [])):
			var tag = String(tag_variant)
			ai_tag_counts[tag] = int(ai_tag_counts.get(tag, 0)) + 1
	var count = maxi(1, matrix.size())
	return {"sample_only": sample_only, "card_count": matrix.size(), "avg_price": int(round(float(total_price) / float(count))), "max_price": max_price, "avg_power_score": int(round(float(total_power) / float(count))), "max_power_score": max_power, "route_counts": route_counts, "ai_tag_counts": ai_tag_counts, "sample_vectors": matrix.slice(0, mini(8, matrix.size()))}


func balance_product_statistics_report(snapshot: Dictionary = {}):
	var products = _as_array(snapshot.get("products", []))
	var category_counts = {}
	var total_base_price = 0
	var total_volatility = 0
	var max_volatility = 0
	var priced_count = 0
	for product_variant in products:
		if not (product_variant is Dictionary):
			continue
		var product = product_variant
		var category = String(product.get("category", product.get("type", "未分类")))
		category_counts[category] = int(category_counts.get(category, 0)) + 1
		var base_price = int(product.get("base_price", product.get("price", 0)))
		if base_price > 0:
			total_base_price += base_price
			var volatility = int(product.get("volatility", PRODUCT_VOLATILITY_MIN))
			total_volatility += volatility
			max_volatility = maxi(max_volatility, volatility)
			priced_count += 1
	return {"product_count": products.size(), "priced_count": priced_count, "category_counts": category_counts, "avg_base_price": int(round(float(total_base_price) / float(maxi(1, priced_count)))), "avg_volatility": int(round(float(total_volatility) / float(maxi(1, priced_count)))), "max_volatility": max_volatility, "price_model_samples": runtime_balance_product_price_rows(), "flow_speed_samples": runtime_balance_flow_speed_rows()}


func balance_monster_statistics_report(snapshot: Dictionary = {}):
	var monsters = _as_array(snapshot.get("monsters", []))
	var movement_counts = {}
	var total_speed = 0.0
	var total_attack_pressure = 0
	var action_count = 0
	for monster_variant in monsters:
		if not (monster_variant is Dictionary):
			continue
		var monster = monster_variant
		var movement = monster_movement_speed_model(monster, float(monster.get("terrain_move_multiplier", 1.0)))
		var mode = String(movement.get("movement_mode", "walk"))
		movement_counts[mode] = int(movement_counts.get(mode, 0)) + 1
		total_speed += float(movement.get("speed_mps", 0.0))
		for action_variant in _as_array(monster.get("actions", [])):
			if action_variant is Dictionary:
				total_attack_pressure += int(monster_attack_model(action_variant, monster).get("attack_pressure_score", 0))
				action_count += 1
	return {"monster_family_count": monsters.size(), "movement_counts": movement_counts, "avg_speed_mps": total_speed / float(maxi(1, monsters.size())), "avg_attack_pressure_score": int(round(float(total_attack_pressure) / float(maxi(1, action_count)))), "damage_cash_rows": runtime_balance_monster_damage_cash_rows(), "combat_samples": runtime_balance_monster_combat_rows(snapshot)}


func balance_ai_statistics_report(snapshot: Dictionary = {}):
	var routes = _as_array(snapshot.get("ai_routes", []))
	var route_ids = []
	for route_variant in routes:
		if route_variant is Dictionary:
			var route = route_variant
			route_ids.append(String(route.get("id", route.get("route_id", ""))))
		else:
			route_ids.append(String(route_variant))
	return {"route_count": route_ids.size(), "route_ids": route_ids.slice(0, mini(16, route_ids.size())), "field_driven_note": "AI balance should read effect fields and tags instead of bespoke card-name logic."}


func balance_cross_system_constraint_report(game_length_rows: Array, card_report: Dictionary, product_report: Dictionary, monster_report: Dictionary, ai_report: Dictionary):
	var issues = []
	var passes = []
	if game_length_rows.size() >= 6:
		passes.append("game_length_depth_gradient_present")
	else:
		issues.append("missing_game_length_depth_gradient")
	for geometry_variant in runtime_balance_planet_geometry_rows():
		var geometry = geometry_variant
		if not bool(geometry.get("passes", true)):
			issues.append("planet_region_geometry_out_of_bounds_depth_%s" % str(geometry.get("depth", "?")))
	if int(card_report.get("card_count", 0)) >= 10:
		passes.append("card_feature_matrix_connected")
	else:
		issues.append("card_feature_matrix_too_small")
	if int(product_report.get("product_count", 0)) >= 20:
		passes.append("product_catalog_connected")
	else:
		issues.append("product_catalog_below_strategy_depth_target")
	if int(monster_report.get("monster_family_count", 0)) >= 8:
		passes.append("monster_catalog_connected")
	else:
		issues.append("monster_catalog_below_strategy_depth_target")
	if int(ai_report.get("route_count", 0)) >= 4:
		passes.append("ai_routes_connected")
	else:
		issues.append("ai_route_sample_too_small")
	return {"issue_count": issues.size(), "issues": issues, "passes": passes, "dev_only": true}


func balance_system_constraint_report(depth: int = -1):
	var value = _safe_depth(depth)
	var window = target_game_window_seconds(value)
	var goal = victory_cash_goal_for_duration(value)
	var expected_gdp = expected_engine_gdp_per_minute(value)
	var expected_assets = expected_city_asset_value(value)
	var estimated_seconds = float(maxi(0, goal - expected_assets)) / float(maxi(1, expected_gdp)) * ECONOMY_CASHFLOW_BASIS_SECONDS
	var issues = []
	if estimated_seconds < float(window.get("soft_min_seconds", TARGET_GAME_LENGTH_MIN_SECONDS)):
		issues.append("victory_goal_too_low_for_target_length")
	if estimated_seconds > float(window.get("soft_max_seconds", TARGET_GAME_LENGTH_MAX_SECONDS)):
		issues.append("victory_goal_too_high_for_target_length")
	return {"depth": value, "target_window": window, "cash_goal": goal, "expected_city_count": expected_city_count_for_depth(value), "expected_city_assets": expected_assets, "expected_engine_gdp_per_minute": expected_gdp, "estimated_seconds_to_goal": estimated_seconds, "estimated_minutes_to_goal": estimated_seconds / 60.0, "issues": issues, "passes": issues.is_empty()}


func skill_balance_route_tags(skill: Dictionary):
	var result = []
	for tag_variant in _as_array(skill.get("tags", [])):
		_append_unique(result, String(tag_variant))
	var kind = String(skill.get("kind", ""))
	if ["product_futures", "product_speculation"].has(kind):
		_append_unique(result, "商品金融")
	if kind == "city_gdp_derivative":
		_append_unique(result, "GDP衍生")
	if kind == "weather_control":
		_append_unique(result, "天气")
	var futures_terms: Dictionary = _dict_or_empty(skill.get("futures_terms", {}))
	if bool(futures_terms.get("requires_warehouse", false)) or int(futures_terms.get("units", 0)) > 1:
		_append_unique(result, "仓储")
	if ["monster_card", "monster_bound_action"].has(kind):
		_append_unique(result, "怪兽")
	if ["military_force", "military_command"].has(kind):
		_append_unique(result, "军队")
	if result.is_empty():
		_append_unique(result, "战术")
	return result


func skill_balance_ai_play_tags(skill: Dictionary):
	var tags = []
	var kind = String(skill.get("kind", ""))
	if skill_targets_player(skill):
		_append_unique(tags, "needs_target_player")
	if skill_targets_monster(skill):
		_append_unique(tags, "needs_monster_target")
	if skill_play_region_gdp_share_required(skill) > 0:
		_append_unique(tags, "uses_region_gdp_share")
	if skill_play_cash_cost(skill) > 0:
		_append_unique(tags, "uses_cash_cost")
	if ["city_revenue_boost", "city_product_upgrade", "city_product_shift", "city_demand_shift", "route_flow_boon", "region_economy_shift"].has(kind):
		_append_unique(tags, "builds_city_engine")
	if ["route_sabotage", "player_hand_disrupt", "player_hand_steal", "global_barrage", "military_command"].has(kind):
		_append_unique(tags, "pressures_rival")
	if ["product_futures", "city_gdp_derivative"].has(kind):
		_append_unique(tags, "time_window_finance")
	if ["intel_city_reveal", "card_history_public_review", "card_history_subscription", "card_counter"].has(kind):
		_append_unique(tags, "uses_public_clues")
	if kind == "monster_card":
		_append_unique(tags, "creates_map_pressure")
	if kind == "military_force":
		_append_unique(tags, "creates_controlled_unit")
	if tags.is_empty():
		_append_unique(tags, "tactical")
	return tags


func skill_balance_target_type(skill: Dictionary):
	if skill_targets_player(skill):
		return "player"
	if skill_targets_monster(skill):
		return "monster"
	match String(skill.get("kind", "")):
		"weather_control":
			return "weather_anchor"
		"city_gdp_derivative", "city_revenue_boost", "city_product_upgrade", "city_product_shift", "city_demand_shift", "route_flow_boon", "route_insurance", "region_economy_shift":
			return "district_or_city"
		"product_futures", "product_speculation":
			return "product"
	return "self_or_context"


func skill_balance_play_gate(skill: Dictionary):
	var requirement_kind = skill_play_requirement_kind(skill)
	var region_scope = skill_play_region_scope(skill)
	var required_share_percent = skill_play_region_gdp_share_required(skill)
	return {
		"requirement_kind": requirement_kind,
		"region_scope": region_scope,
		"required_share_percent": required_share_percent,
		"flow_required": skill_play_flow_required(skill),
		# Keep the source-data names beside the normalized analyzer keys so
		# developer reports can be traced back to the card dictionary directly.
		"play_requirement_kind": requirement_kind,
		"play_region_scope": region_scope,
		"play_region_gdp_share_required": required_share_percent,
		"cash_cost": skill_play_cash_cost(skill),
		"requires_warehouse_city": bool(_dict_or_empty(skill.get("futures_terms", {})).get("requires_warehouse", false)),
		"starter_play_free": bool(skill.get("starter_play_free", false)),
		"target_type": skill_balance_target_type(skill),
	}


func skill_balance_public_telegraph_score(skill: Dictionary):
	var score = 0
	var region_share_required = skill_play_region_gdp_share_required(skill)
	if region_share_required > 0:
		# The threshold is public, but the opponent's exact share remains private.
		score += 20 + region_share_required
	if skill_targets_player(skill) or skill_targets_monster(skill):
		score += 24
	if int(skill.get("damage", 0)) > 0 or int(skill.get("route_damage", 0)) > 0:
		score += 28
	if int(skill.get("market_demand_pressure", 0)) != 0 or int(skill.get("market_supply_pressure", 0)) != 0:
		score += 20
	if ["weather_control", "military_force", "monster_card", "global_barrage"].has(String(skill.get("kind", ""))):
		score += 30
	return score


func skill_balance_complexity_score(skill: Dictionary, rank: int = 1):
	var score = 1 + clampi(rank, 1, 4) * 2
	for field_variant in skill_balance_numeric_field_names():
		if absf(float(skill.get(String(field_variant), 0.0))) > 0.001:
			score += 1
	if skill_targets_player(skill) or skill_targets_monster(skill):
		score += 3
	if skill_play_region_gdp_share_required(skill) > 0:
		score += 2
	if skill_play_cash_cost(skill) > 0:
		score += 1
	if bool(_dict_or_empty(skill.get("futures_terms", {})).get("requires_warehouse", false)):
		score += 3
	if ["product_futures", "city_gdp_derivative", "weather_control", "card_counter"].has(String(skill.get("kind", ""))):
		score += 4
	return score


func card_strength_budget_points(skill: Dictionary):
	var points = maxi(2, int(skill.get("cost", 2))) * 10
	for key in skill_balance_numeric_field_names():
		points += abs(int(skill.get(String(key), 0))) * 4
	points += int(round(absf(float(skill.get("move", 0.0))) / 90.0))
	points += int(round(absf(float(skill.get("range", 0.0))) / 110.0))
	points += int(round(absf(float(skill.get("military_move", 0.0))) / 90.0))
	points += int(round(absf(float(skill.get("military_range", 0.0))) / 110.0))
	points += int(round(absf(float(skill.get("knockback", 0.0))) / 120.0))
	return maxi(1, points)


func card_strength_budget_band_text(points: int):
	if points <= 35:
		return "轻量"
	if points <= 70:
		return "标准"
	if points <= 120:
		return "核心"
	return "终端"


func skill_play_requirement_kind(skill: Dictionary):
	var explicit_kind = String(skill.get("play_requirement_kind", ""))
	if explicit_kind != "":
		return explicit_kind
	return "region_gdp_share" if skill_play_region_gdp_share_required(skill) > 0 else "none"


func skill_play_region_scope(skill: Dictionary):
	return String(skill.get("play_region_scope", "own_best_region"))


func skill_play_region_gdp_share_required(skill: Dictionary):
	if bool(skill.get("starter_play_free", false)):
		return 0
	return clampi(int(skill.get("play_region_gdp_share_required", 0)), 0, 100)


func skill_supply_product(skill: Dictionary):
	# Legacy play_product data is retained only as regional supply affinity.
	return String(skill.get("supply_product", skill.get("play_product", "")))


func skill_play_flow_required(skill: Dictionary):
	# Product-flow gates are opt-in legacy fixtures only. Normal cards use the
	# regional GDP-share policy above and therefore report zero flow demand.
	if not bool(skill.get("legacy_flow_gate_enabled", false)):
		return 0
	if bool(skill.get("starter_play_free", false)):
		return 0
	if skill.has("play_flow_required"):
		return maxi(0, int(skill.get("play_flow_required", 0)))
	if String(skill.get("play_product", "")) == "":
		return 0
	return maxi(1, int(ceil(float(maxi(1, int(skill.get("cost", 2)))) / 3.0)))


func skill_play_cash_cost(skill: Dictionary, active_monster_count: int = 0):
	var cash = maxi(0, int(skill.get("play_cash", 0)))
	if String(skill.get("kind", "")) == "monster_card":
		cash += maxi(0, int(skill.get("play_cash_per_monster", 0))) * maxi(0, active_monster_count)
	return cash


func skill_targets_monster(skill: Dictionary):
	var kind = String(skill.get("kind", ""))
	return bool(skill.get("target_monster_required", false)) or ["monster_bound_action", "monster_lure", "monster_redirect", "monster_attack", "military_command"].has(kind)


func skill_targets_player(skill: Dictionary):
	var kind = String(skill.get("kind", ""))
	return bool(skill.get("target_player_required", false)) or ["player_hand_disrupt", "player_hand_steal", "city_control_dispute"].has(kind)


func _card_entries(snapshot: Dictionary, sample_only: bool):
	var cards = _as_array(snapshot.get("cards", []))
	return cards.slice(0, mini(24, cards.size())) if sample_only else cards


func _safe_depth(depth: int):
	return clampi(DEFAULT_ROGUELIKE_DEPTH if depth < 0 else depth, ROGUELIKE_DEPTH_MIN, ROGUELIKE_DEPTH_MAX)


func _rank_label(rank: int):
	match clampi(rank, 1, 6):
		1:
			return "I"
		2:
			return "II"
		3:
			return "III"
		4:
			return "IV"
		5:
			return "V"
		6:
			return "VI"
	return "I"


func _rank_from_card_name(card_name: String):
	if card_name.length() <= 0:
		return 1
	var last = card_name.substr(card_name.length() - 1, 1)
	return clampi(int(last), 1, 4) if last.is_valid_int() else 1


func _skill_family(card_name: String):
	if card_name.length() <= 0:
		return ""
	var last = card_name.substr(card_name.length() - 1, 1)
	return card_name.substr(0, card_name.length() - 1) if last.is_valid_int() else card_name


func _route_id_for_skill(skill: Dictionary):
	var kind = String(skill.get("kind", ""))
	if ["product_futures", "product_speculation"].has(kind):
		return "product_finance"
	if kind == "city_gdp_derivative":
		return "gdp_derivative"
	if kind == "monster_card":
		return "monster_pressure"
	if ["military_force", "military_command"].has(kind):
		return "military_pressure"
	if ["player_hand_disrupt", "player_hand_steal", "card_counter"].has(kind):
		return "direct_interaction"
	if kind == "weather_control":
		return "weather_control"
	return "tactical"


func _route_label_for_skill(skill: Dictionary):
	match _route_id_for_skill(skill):
		"product_finance":
			return "商品金融"
		"gdp_derivative":
			return "GDP衍生"
		"monster_pressure":
			return "怪兽压力"
		"military_pressure":
			return "军队压制"
		"direct_interaction":
			return "直接互动"
		"weather_control":
			return "天气控制"
	return "战术"


func _as_array(value: Variant):
	return value as Array if value is Array else []


func _dict_or_empty(value: Variant):
	return value as Dictionary if value is Dictionary else {}


func _append_unique(result: Array, value: String):
	if value != "" and not result.has(value):
		result.append(value)
