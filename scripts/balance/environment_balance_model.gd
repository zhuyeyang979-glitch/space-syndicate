extends RefCounted
class_name EnvironmentBalanceModel

## Developer-only global environment balance model.
##
## This script owns public weather states, market refresh timing, and economic
## volatility causal functions.  It intentionally has no dependency on main.gd.

const ROGUELIKE_DEPTH_MIN := 1
const ROGUELIKE_DEPTH_MAX := 6
const DEFAULT_ROGUELIKE_DEPTH := 1

const MARKET_REFRESH_MIN_SECONDS := 30.0
const MARKET_REFRESH_MAX_SECONDS := 60.0
const WEATHER_FORECAST_MIN_SECONDS := 60.0
const WEATHER_FORECAST_MAX_SECONDS := 180.0
const WEATHER_DURATION_MIN_SECONDS := 75.0
const WEATHER_DURATION_MAX_SECONDS := 180.0
const WEATHER_ZONE_MIN := 1
const WEATHER_ZONE_MAX := 5

const VOLATILITY_STABLE_CAP := 0.12
const VOLATILITY_NORMAL_CAP := 0.22
const VOLATILITY_CRISIS_CAP := 0.40


func market_refresh_interval_seconds(depth: int = -1, volatility_level: int = 1) -> float:
	var safe_depth := _safe_depth(depth)
	var volatility := clampi(volatility_level, 0, 3)
	var baseline := 60.0 - float(safe_depth - 1) * 4.0 - float(volatility) * 5.0
	return clampf(baseline, MARKET_REFRESH_MIN_SECONDS, MARKET_REFRESH_MAX_SECONDS)


func weather_forecast_window_seconds(depth: int = -1, volatility_level: int = 1) -> float:
	var safe_depth := _safe_depth(depth)
	var volatility := clampi(volatility_level, 0, 3)
	var baseline := 140.0 - float(safe_depth - 1) * 6.0 - float(volatility) * 10.0
	return clampf(baseline, WEATHER_FORECAST_MIN_SECONDS, WEATHER_FORECAST_MAX_SECONDS)


func weather_duration_seconds(weather_state: String = "clear", depth: int = -1) -> float:
	var safe_depth := _safe_depth(depth)
	var state := weather_state.strip_edges().to_lower()
	var baseline := 95.0 + float(safe_depth - 1) * 10.0
	if state in ["storm", "ion_storm", "tidal_surge", "meteor_shower"]:
		baseline += 35.0
	if state in ["clear", "calm"]:
		baseline = 75.0
	return clampf(baseline, WEATHER_DURATION_MIN_SECONDS, WEATHER_DURATION_MAX_SECONDS)


func weather_zone_count_model(depth: int = -1, region_count: int = -1) -> Dictionary:
	var safe_depth := _safe_depth(depth)
	var inferred_regions := region_count if region_count > 0 else 6 + safe_depth * 6
	var zones := clampi(int(ceil(float(inferred_regions) / 12.0)), WEATHER_ZONE_MIN, WEATHER_ZONE_MAX)
	return {
		"depth": safe_depth,
		"region_count": inferred_regions,
		"weather_zone_count": zones,
		"min_zone_count": WEATHER_ZONE_MIN,
		"max_zone_count": WEATHER_ZONE_MAX,
		"design_note": "一次天气变化影响 1-5 个区域，星球越大可同时预报的天气区越多。",
	}


func weather_state_effect_model(weather_state: String, terrain: String = "", product_category: String = "") -> Dictionary:
	var state := weather_state.strip_edges().to_lower()
	var safe_terrain := terrain.strip_edges().to_lower()
	var category := product_category.strip_edges()
	var production_multiplier := 1.0
	var transport_multiplier := 1.0
	var demand_multiplier := 1.0
	var price_weather_modifier := 0
	var route_damage_pressure := 0
	var monster_pressure_modifier := 0
	var tags := []

	match state:
		"clear", "calm", "":
			tags.append("stable")
		"rain", "monsoon":
			transport_multiplier = 0.82
			production_multiplier = 1.08 if category in ["食物/生物", "海洋/运输"] else 0.96
			price_weather_modifier = 3
			route_damage_pressure = 1
			tags.append("wet_route")
		"storm", "ion_storm":
			transport_multiplier = 0.55
			production_multiplier = 0.88
			price_weather_modifier = 9
			route_damage_pressure = 3
			monster_pressure_modifier = 1
			tags.append("route_crisis")
		"tidal_surge":
			transport_multiplier = 0.62 if safe_terrain in ["ocean", "sea", "coast"] else 0.86
			production_multiplier = 1.12 if category == "海洋/运输" else 0.92
			price_weather_modifier = 7
			route_damage_pressure = 2
			tags.append("ocean_pressure")
		"drought":
			transport_multiplier = 0.92
			production_multiplier = 0.74 if category == "食物/生物" else 0.96
			demand_multiplier = 1.12 if category in ["食物/生物", "能源"] else 1.0
			price_weather_modifier = 8
			tags.append("supply_shock")
		"solar_wind":
			transport_multiplier = 0.74 if category == "科技/数据" else 0.93
			production_multiplier = 1.08 if category == "能源" else 0.98
			price_weather_modifier = 5
			route_damage_pressure = 1
			tags.append("signal_noise")
		"meteor_shower":
			transport_multiplier = 0.7
			production_multiplier = 0.9
			price_weather_modifier = 10
			route_damage_pressure = 3
			monster_pressure_modifier = 1
			tags.append("impact_risk")
		"miasma":
			transport_multiplier = 0.78
			demand_multiplier = 0.88
			price_weather_modifier = 6
			monster_pressure_modifier = 2
			tags.append("monster_lure")
		_:
			price_weather_modifier = 2
			tags.append("minor_weather")

	return {
		"weather_state": weather_state if weather_state != "" else "clear",
		"terrain": terrain,
		"product_category": product_category,
		"production_multiplier": production_multiplier,
		"transport_multiplier": transport_multiplier,
		"demand_multiplier": demand_multiplier,
		"price_weather_modifier": price_weather_modifier,
		"route_damage_pressure": route_damage_pressure,
		"monster_pressure_modifier": monster_pressure_modifier,
		"public_forecast_required": state not in ["clear", "calm", ""],
		"causal_tags": tags,
	}


func economic_volatility_model(base_volatility: int = 4, supply_pressure: int = 0, demand_pressure: int = 0, route_damage: int = 0, monster_pressure: int = 0, weather_pressure: int = 0, contract_pressure: int = 0) -> Dictionary:
	var volatility_score := clampi(base_volatility, 1, 30)
	volatility_score += maxi(0, route_damage) * 2
	volatility_score += maxi(0, monster_pressure) * 2
	volatility_score += maxi(0, weather_pressure)
	volatility_score += maxi(0, contract_pressure)
	volatility_score += int(round(absf(float(demand_pressure - supply_pressure)) * 0.5))
	volatility_score = clampi(volatility_score, 1, 30)
	var cap := VOLATILITY_STABLE_CAP
	var band := "stable"
	if volatility_score >= 18:
		cap = VOLATILITY_CRISIS_CAP
		band = "crisis"
	elif volatility_score >= 9:
		cap = VOLATILITY_NORMAL_CAP
		band = "normal"
	return {
		"base_volatility": base_volatility,
		"supply_pressure": maxi(0, supply_pressure),
		"demand_pressure": maxi(0, demand_pressure),
		"route_damage": maxi(0, route_damage),
		"monster_pressure": maxi(0, monster_pressure),
		"weather_pressure": maxi(0, weather_pressure),
		"contract_pressure": maxi(0, contract_pressure),
		"volatility_score": volatility_score,
		"volatility_band": band,
		"single_refresh_cap_pct": cap,
		"driver_summary": "供需差%d/断路%d/怪兽%d/天气%d/合约%d" % [abs(demand_pressure - supply_pressure), route_damage, monster_pressure, weather_pressure, contract_pressure],
	}


func global_environment_refresh_model(depth: int = -1, region_count: int = -1, active_weather_count: int = 0, volatility_level: int = 1) -> Dictionary:
	var safe_depth := _safe_depth(depth)
	var zones := weather_zone_count_model(safe_depth, region_count)
	var market_seconds := market_refresh_interval_seconds(safe_depth, volatility_level)
	var forecast_seconds := weather_forecast_window_seconds(safe_depth, volatility_level)
	var max_active := clampi(int(zones.get("weather_zone_count", 1)), WEATHER_ZONE_MIN, WEATHER_ZONE_MAX)
	return {
		"depth": safe_depth,
		"market_refresh_seconds": market_seconds,
		"forecast_window_seconds": forecast_seconds,
		"weather_zone_count": max_active,
		"active_weather_count": clampi(active_weather_count, 0, max_active),
		"weather_duration_min_seconds": WEATHER_DURATION_MIN_SECONDS,
		"weather_duration_max_seconds": WEATHER_DURATION_MAX_SECONDS,
		"public_information": true,
		"player_facing_rule": "天气和市场刷新属于公开全局信息；新闻仍由玩家打出的牌制造。",
	}


func environment_causal_rows() -> Array:
	return [
		weather_state_effect_model("clear", "land", "食物/生物"),
		weather_state_effect_model("storm", "ocean", "海洋/运输"),
		weather_state_effect_model("drought", "land", "食物/生物"),
		weather_state_effect_model("solar_wind", "city", "科技/数据"),
		weather_state_effect_model("miasma", "route", "奢侈/文化"),
	]


func _safe_depth(depth: int) -> int:
	var value := DEFAULT_ROGUELIKE_DEPTH if depth < 0 else depth
	return clampi(value, ROGUELIKE_DEPTH_MIN, ROGUELIKE_DEPTH_MAX)
