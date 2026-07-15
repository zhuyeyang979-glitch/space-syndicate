extends SceneTree

const MODEL_SCRIPT := preload("res://scripts/balance/runtime_balance_model.gd")
const REQUIREMENT_POLICY := preload("res://scripts/cards/card_play_requirement_policy.gd")
const DIAGNOSTICS_SCENE := preload("res://scenes/runtime/GameplayBalanceDiagnosticsRuntimeService.tscn")
const ROUTE_CATALOG := preload("res://resources/balance/development_route_catalog_v04.tres")

var _failures: Array[String] = []
var _model: RefCounted
var _snapshot: Dictionary


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_model = MODEL_SCRIPT.new()
	_snapshot = _sample_snapshot()
	_expect(_model != null, "runtime balance model instantiates without loading main.gd")
	_expect(FileAccess.file_exists("res://scripts/balance/runtime_balance_model.gd"), "runtime balance model is split into scripts/balance")
	_expect(FileAccess.file_exists("res://scripts/balance/movement_balance_model.gd"), "movement balance model is split out of main.gd")
	_expect(FileAccess.file_exists("res://scripts/balance/combat_balance_model.gd"), "combat balance model is split out of main.gd")
	_expect(FileAccess.file_exists("res://scripts/balance/environment_balance_model.gd"), "environment balance model is split out of main.gd")
	_expect(FileAccess.file_exists("res://data/balance/runtime_balance_targets.json"), "runtime balance targets data is checked in")
	_expect(FileAccess.file_exists("res://docs/runtime_balance_report.md"), "runtime balance report document is checked in")
	_expect(FileAccess.file_exists("res://docs/campaign_chapter_settings.md"), "campaign chapter settings document is checked in")
	_expect(FileAccess.file_exists("res://docs/global_environment_balance.md"), "global environment balance document is checked in")
	var report_text := FileAccess.get_file_as_string("res://docs/runtime_balance_report.md")
	_expect(report_text.contains("Runtime Balance Gradient Report") and report_text.contains("runtime_balance_model.gd") and report_text.contains("movement_balance_model.gd") and report_text.contains("combat_balance_model.gd"), "runtime balance report points to the independent model scripts")

	var report: Dictionary = _model.call("runtime_balance_audit_report", _snapshot)
	_expect(report.get("version", "") == "runtime_balance_v1", "runtime balance audit exposes a stable version")
	_verify_cash_goal_gradient(report)
	_verify_planet_geometry_gradient(report)
	_verify_card_price_gradient(report)
	_verify_skill_balance_feature_vector()
	_verify_region_gdp_share_play_gate()
	_verify_product_and_monster_models(report)
	_verify_balance_statistics_hub()
	_verify_main_bridge_is_thin()
	_verify_diagnostics_cutover()
	_finish()


func _verify_cash_goal_gradient(report: Dictionary) -> void:
	var rows: Array = _as_array(report.get("cash_goal_rows", []))
	_expect(rows.size() >= 6, "cash goal audit covers roguelike depths I-VI")
	var previous_goal := 0
	for row_variant in rows:
		var row: Dictionary = row_variant
		var goal := int(row.get("cash_goal", 0))
		_expect(goal > previous_goal, "cash goals increase monotonically by depth")
		previous_goal = goal
	var first: Dictionary = rows[0] if not rows.is_empty() else {}
	_expect(int(first.get("gap_after_one_city", 0)) >= 2500, "depth I cash goal leaves a 30-minute-scale gap after one starting city")
	_expect(float(first.get("reference_minutes_after_one_city", 0.0)) >= 29.0, "depth I baseline reference length targets about 30 minutes")
	var last: Dictionary = rows[rows.size() - 1] if not rows.is_empty() else {}
	_expect(int(last.get("region_max", 0)) >= 40 and float(last.get("expected_minutes_to_goal", 0.0)) >= 59.0, "late depth scales both map size and expected money race length toward 60 minutes")


func _verify_planet_geometry_gradient(report: Dictionary) -> void:
	var rows: Array = _as_array(report.get("planet_geometry_rows", []))
	_expect(rows.size() >= 6, "planet geometry audit covers roguelike depths I-VI")
	var previous_area := 0.0
	var previous_region_max := 0
	for row_variant in rows:
		var row: Dictionary = row_variant
		_expect(bool(row.get("passes", false)), "planet region size stays inside the target average-area band")
		_expect(float(row.get("planet_area_m2", 0.0)) > previous_area, "planet area increases by depth")
		_expect(int(row.get("region_max", 0)) >= previous_region_max, "region count range increases by depth")
		_expect(float(row.get("normal_region_exit_seconds", 0.0)) >= 7.0 and float(row.get("normal_region_exit_seconds", 0.0)) <= 14.0, "normal monster speed targets roughly ten seconds to leave a region")
		_expect(float(row.get("normal_monster_speed_mps", 0.0)) < 35.0, "normal monster movement speed cannot cross the planet like a cursor")
		_expect(float(row.get("flying_monster_speed_mps", 0.0)) >= float(row.get("normal_monster_speed_mps", 0.0)) * 6.0, "flying monster speed is allowed to be a large ecological outlier")
		_expect(float(row.get("sea_monster_speed_mps", 0.0)) >= float(row.get("normal_monster_speed_mps", 0.0)) * 4.0, "ocean monster speed is faster than normal movement in its ecology")
		_expect(float(row.get("standard_military_exit_seconds", 0.0)) >= 5.0 and float(row.get("standard_military_exit_seconds", 0.0)) <= 16.0, "standard military movement remains close to normal region-exit scale")
		previous_area = float(row.get("planet_area_m2", 0.0))
		previous_region_max = int(row.get("region_max", 0))


func _verify_card_price_gradient(report: Dictionary) -> void:
	var basic_price := int(_model.call("card_price_for_skill", {"cost": 2, "kind": "move", "move": 180}))
	var arbitrage_price := int(_model.call("card_price_for_skill", {"cost": 3, "kind": "product_speculation", "cash": 260, "price_delta": 18}))
	var futures_price := int(_model.call("card_price_for_skill", {"cost": 4, "kind": "product_futures", "futures_terms": {"direction": "up", "multiplier": 1.0, "duration_seconds": 60.0, "units": 1, "margin_cash": 120, "maximum_gain": 260, "maximum_loss": 120}, "market_demand_pressure": 1}))
	var short_price := int(_model.call("card_price_for_skill", {"cost": 4, "kind": "city_gdp_derivative", "gdp_derivative_terms": {"direction": "down", "multiplier": 1.2, "duration_seconds": 60, "destroy_bonus": 180, "margin_cash": 120, "maximum_gain": 260, "maximum_loss": 120}}))
	var disrupt_price := int(_model.call("card_price_for_skill", {"cost": 4, "kind": "player_hand_disrupt", "target_player_required": true, "hand_discard_count": 1}))
	var military_price := int(_model.call("card_price_for_skill", {"cost": 5, "kind": "military_force", "military_hp": 8, "military_damage": 1}))
	var monster_price := int(_model.call("card_price_for_skill", {"cost": 5, "kind": "monster_card", "hp": 48, "fixed_skill_count": 1}))
	_expect(arbitrage_price > basic_price, "direct cash/speculation card costs more than basic movement")
	_expect(futures_price > basic_price, "product futures card costs more than basic movement")
	_expect(short_price > arbitrage_price, "GDP short card prices its larger swing above simple arbitrage")
	_expect(disrupt_price > basic_price, "direct player interaction card prices above basic movement")
	_expect(military_price > basic_price, "military force card prices above basic movement")
	_expect(monster_price > basic_price, "monster card prices above basic movement")
	_expect(["高阶档", "旗舰档"].has(String(_model.call("card_price_tier_text", short_price))), "high-leverage GDP short card is shown as high/flagship tier")

	var rows: Array = _as_array(report.get("card_price_rows", []))
	_expect(rows.size() >= 10, "runtime balance report emits sampled card price rows")
	for row_variant in rows:
		var row: Dictionary = row_variant
		_expect(row.has("card") and row.has("actual_price") and row.has("field_adjustment") and row.has("route_tags") and row.has("ai_play_tags"), "card price rows expose price, field adjustment, route tags, and AI tags")
		_expect(row.has("play_requirement_kind") and row.has("play_region_scope") and row.has("play_region_gdp_share_required"), "card price rows expose the regional GDP-share play gate")
		_expect(not row.has("play_flow_required") or int(row.get("play_flow_required", 0)) == 0, "card price rows keep the retired product-flow gate disabled")


func _verify_skill_balance_feature_vector() -> void:
	var matrix: Array = _as_array(_model.call("runtime_balance_card_feature_matrix", _snapshot, true))
	_expect(matrix.size() >= 10, "runtime balance feature matrix returns sample card vectors")
	var by_name := {}
	for vector_variant in matrix:
		if vector_variant is Dictionary:
			var vector: Dictionary = vector_variant
			by_name[String(vector.get("card_name", ""))] = vector
	var futures: Dictionary = by_name.get("商品看涨1", {})
	var gdp_short: Dictionary = by_name.get("城市做空1", {})
	var disrupt: Dictionary = by_name.get("星链拆解1", {})
	var military: Dictionary = by_name.get("行星防卫军1", {})
	_expect(not futures.is_empty(), "skill balance feature vector exists for futures cards")
	_expect(_as_array(futures.get("route_tags", [])).has("商品金融") and _as_array(futures.get("ai_play_tags", [])).has("time_window_finance"), "futures feature vector exposes finance route and AI time-window tag")
	_expect(String(gdp_short.get("target_type", "")) == "district_or_city" and int((gdp_short.get("score_breakdown", {}) as Dictionary).get("gdp_derivative_score", 0)) > 0, "GDP derivative vector exposes city target and derivative score")
	_expect(_as_array(disrupt.get("ai_play_tags", [])).has("needs_target_player") and _as_array(disrupt.get("ai_play_tags", [])).has("uses_region_gdp_share") and int((disrupt.get("score_breakdown", {}) as Dictionary).get("interaction_score", 0)) > 0, "direct interaction vector exposes target-player, regional GDP gate, and interaction score")
	_expect(not _as_array(disrupt.get("ai_play_tags", [])).has("uses_product_flow"), "AI balance tags no longer treat product flow as a play cost")
	_expect(_as_array(military.get("ai_play_tags", [])).has("creates_controlled_unit") and int((military.get("score_breakdown", {}) as Dictionary).get("military_score", 0)) > 0, "military force vector exposes controlled-unit AI tag and military score")


func _verify_region_gdp_share_play_gate() -> void:
	var matrix: Array = _as_array(_model.call("runtime_balance_card_feature_matrix", _snapshot, true))
	var by_name := {}
	for vector_variant in matrix:
		if vector_variant is Dictionary:
			var vector: Dictionary = vector_variant
			by_name[String(vector.get("card_name", ""))] = vector
	var basic_gate: Dictionary = (by_name.get("商品看涨1", {}) as Dictionary).get("play_gate", {}) as Dictionary
	var disrupt_gate: Dictionary = (by_name.get("星链拆解1", {}) as Dictionary).get("play_gate", {}) as Dictionary
	_expect(String(basic_gate.get("play_requirement_kind", "")) == "none" and int(basic_gate.get("play_region_gdp_share_required", -1)) == 0, "ordinary rank-I cards have no GDP-share play condition")
	_expect(String(disrupt_gate.get("play_requirement_kind", "")) == "region_gdp_share", "high-impact rank-I interaction cards use a regional GDP-share condition")
	_expect(String(disrupt_gate.get("play_region_scope", "")) == "own_best_region" and int(disrupt_gate.get("play_region_gdp_share_required", 0)) == 10, "high-impact rank-I interaction cards require 10% in an owned staging region")
	_expect(not disrupt_gate.has("flow_required") or int(disrupt_gate.get("flow_required", 0)) == 0, "regional GDP-share gates do not retain a product-flow cost")


func _verify_product_and_monster_models(report: Dictionary) -> void:
	var stable: Dictionary = _model.call("product_price_model", 100, 0, 10, 10, 5, 20, 4, 0.0, 2.0)
	var volatile: Dictionary = _model.call("product_price_model", 100, 0, 10, 10, 5, 20, 22, 0.0, 2.0)
	_expect(abs(int(stable.get("delta", 0))) <= int(stable.get("step_cap", 0)), "stable product price change is capped by the hard step cap")
	_expect(int(volatile.get("step_cap", 0)) > int(stable.get("step_cap", 0)), "volatile product allows a larger but still explicit price step")
	_expect(String(volatile.get("driver_summary", "")).contains("需") and String(volatile.get("driver_summary", "")).contains("怪兽"), "price model records driver summary")
	var healthy: Dictionary = _model.call("product_flow_speed_model", "海浪供电", 1.2, 1.1, 0, 1.0)
	var damaged: Dictionary = _model.call("product_flow_speed_model", "海浪供电", 1.2, 1.1, 4, 1.0)
	_expect(float(damaged.get("flow_units_per_second", 0.0)) < float(healthy.get("flow_units_per_second", 0.0)), "route damage slows product flow speed")
	var normal: Dictionary = _model.call("monster_movement_speed_model", {"name": "步行测试体", "move": 190.0, "movement_mode": "walk", "move_damage": 1}, 1.0, -1.0, 180.0, 10.0)
	var flying: Dictionary = _model.call("monster_movement_speed_model", {"name": "飞翼测试体", "move": 260.0, "movement_mode": "fly", "movement_traits": ["flying"], "move_damage": 3}, 1.0, -1.0, 180.0, 10.0)
	_expect(bool(flying.get("flying_no_trample", false)) and int(flying.get("move_damage", -1)) == 0, "flying monster movement does not cause ordinary trample damage")
	_expect(float(flying.get("speed_mps", 0.0)) >= float(normal.get("speed_mps", 1.0)) * 6.0 and float(flying.get("speed_mps", 0.0)) <= float(normal.get("speed_mps", 1.0)) * 14.0, "flying monster movement is fast but still constrained by ecology caps")
	var aquatic: Dictionary = _model.call("monster_movement_speed_model", {"name": "海行测试体", "move": 230.0, "movement_mode": "swim", "movement_traits": ["ocean"], "move_damage": 1}, 1.0, -1.0, 180.0, 10.0)
	_expect(float(aquatic.get("speed_mps", 0.0)) >= float(normal.get("speed_mps", 1.0)) * 4.0, "aquatic monster movement is meaningfully faster in ocean ecology")
	var stationary: Dictionary = _model.call("monster_movement_speed_model", {"name": "定着母巢", "move": 190.0, "movement_mode": "walk", "stationary": true}, 1.0, -1.0, 180.0, 10.0)
	_expect(float(stationary.get("speed_mps", 0.0)) <= float(normal.get("speed_mps", 1.0)) * 0.2, "stationary monster can be nearly immobile")
	var military: Dictionary = _model.call("military_movement_speed_model", {"military_domain": "mixed", "military_type": "defense", "move": 260.0}, 1.0, -1.0, 180.0)
	var air_military: Dictionary = _model.call("military_movement_speed_model", {"military_domain": "air", "military_type": "fighter", "move": 360.0}, 1.0, -1.0, 180.0)
	_expect(float(military.get("estimated_region_exit_seconds", 0.0)) >= 5.0 and float(military.get("estimated_region_exit_seconds", 0.0)) <= 16.0, "military movement stays close to original normal monster speed")
	_expect(float(air_military.get("speed_mps", 0.0)) < float(flying.get("speed_mps", 0.0)), "air military is faster than ground force but below extreme flying monsters")
	var melee_knockback: Dictionary = _model.call("monster_knockback_speed_model", {"name": "普通撞击", "damage": 2, "knockback_profile": "melee"}, {}, 180.0, 0.5)
	var beam_knockback: Dictionary = _model.call("monster_knockback_speed_model", {"name": "白谱光线", "damage": 2, "range": 520.0}, {}, 180.0, 0.5)
	var throw_knockback: Dictionary = _model.call("monster_knockback_speed_model", {"name": "重力投掷", "damage": 2, "knockback_profile": "throw"}, {}, 180.0, 0.5)
	_expect(float(melee_knockback.get("radius_ratio", 0.0)) >= 0.75 and float(melee_knockback.get("radius_ratio", 0.0)) <= 1.1, "normal melee knockback feels like center-to-edge of one region")
	_expect(float(melee_knockback.get("knockback_duration_seconds", 0.0)) >= 0.35 and float(melee_knockback.get("knockback_duration_seconds", 0.0)) <= 0.65, "knockback happens in a short impact window")
	_expect(float(beam_knockback.get("knockback_m", 0.0)) > float(melee_knockback.get("knockback_m", 0.0)) and float(throw_knockback.get("knockback_m", 0.0)) > float(beam_knockback.get("knockback_m", 0.0)), "beam and throw knockback profiles have larger displacement than melee")
	_verify_environment_models()
	var damage_rows: Array = _as_array(report.get("monster_damage_cash_rows", []))
	_expect(damage_rows.size() >= 16, "monster damage cash audit covers ranks and damage ratios")
	var rank_iv_full := false
	for row_variant in damage_rows:
		var row: Dictionary = row_variant
		if int(row.get("rank", 0)) == 4 and is_equal_approx(float(row.get("hp_damage_ratio", 0.0)), 1.0):
			rank_iv_full = int(row.get("owner_damage_cash_pool", 0)) == 1210 and int(row.get("cash_loss", 0)) == 1210
	_expect(rank_iv_full, "rank IV monster owner damage pool is exposed in the audit")


func _verify_balance_statistics_hub() -> void:
	var hub: Dictionary = _model.call("statistics_hub_report", _snapshot, true)
	_expect(hub.get("version", "") == "balance_statistics_hub_v1", "developer balance statistics hub exposes a stable version")
	_expect(bool(hub.get("dev_only", false)) and not bool(hub.get("player_ui_allowed", true)), "balance statistics hub is marked developer-only and not player-facing")
	var summary: Dictionary = hub.get("summary", {}) if hub.get("summary", {}) is Dictionary else {}
	_expect(float(summary.get("target_min_minutes", 0.0)) == 30.0 and float(summary.get("target_max_minutes", 0.0)) == 60.0, "hub summary exposes the 30-60 minute run-length target")
	_expect(int(summary.get("card_vector_count", 0)) >= 10 and int(summary.get("product_count", 0)) >= 20 and int(summary.get("monster_family_count", 0)) >= 8, "hub summary connects cards, products, and monsters")
	var constraints: Dictionary = hub.get("constraints", {}) if hub.get("constraints", {}) is Dictionary else {}
	_expect(constraints.has("issue_count") and constraints.has("issues") and constraints.has("passes"), "hub emits cross-system constraint status")
	var greybox: Dictionary = _model.call("developer_greybox_snapshot", _snapshot, true)
	_expect(bool(greybox.get("dev_only", false)) and String(greybox.get("title", "")).contains("DEV BALANCE HUB"), "developer greybox snapshot is available without exposing player UI")


func _verify_main_bridge_is_thin() -> void:
	var main_text := FileAccess.get_file_as_string("res://scripts/main.gd")
	_expect(main_text.contains("const RuntimeBalanceModelScript") and main_text.contains("func _runtime_balance_model()"), "main.gd bridges to the independent runtime balance model")
	_expect(main_text.contains("var base_price := int(_runtime_balance_model().call(\"card_price_for_skill\", skill))") and not main_text.contains("func _card_price_power_adjustment("), "main.gd reads card prices from the balance model without reviving a duplicate pricing wrapper")
	var military_text := FileAccess.get_file_as_string("res://scripts/runtime/military_runtime_controller.gd")
	var monster_runtime_text := FileAccess.get_file_as_string("res://scripts/runtime/monster_runtime_controller.gd")
	_expect(main_text.contains("_auto_monster_movement_speed_mps") and military_text.contains("func unit_movement_speed_mps(") and military_text.contains("military_movement_speed_model") and main_text.contains("_monster_knockback_model"), "monster/main and MilitaryRuntimeController use the shared balance movement models")
	_expect(main_text.contains("var price_name := \"%s1\" % _game_runtime_coordinator_node().card_family_id(skill_name)"), "runtime card purchase price remains anchored to the rank-I family card through the authoritative Catalog Service")
	_expect(monster_runtime_text.contains("hp_damage") and monster_runtime_text.contains("mini(remaining, hp_before)") and monster_runtime_text.contains("return hp_damage"), "MonsterRuntimeController protects owner cash loss with actual HP damage semantics")


func _verify_diagnostics_cutover() -> void:
	var service := DIAGNOSTICS_SCENE.instantiate() as GameplayBalanceDiagnosticsRuntimeService
	_expect(service != null, "gameplay balance diagnostics service scene instantiates independently of main.gd")
	if service == null:
		return
	root.add_child(service)
	var configured := service.configure(ROUTE_CATALOG, _model)
	_expect(bool(configured.get("configured", false)), "diagnostics service configures from the v0.4 development route catalog and RuntimeBalanceModel")
	var validation := ROUTE_CATALOG.validation_report()
	_expect(bool(validation.get("valid", false)) and int(validation.get("route_count", 0)) == 7, "development route catalog contains seven valid Inspector-editable profiles")
	var routes := service.development_routes()
	_expect(routes.size() == 7 and str((routes[0] as Dictionary).get("id", "")) == "city_growth" and str((routes[6] as Dictionary).get("id", "")) == "tactical_support", "diagnostics service preserves route ids and sort order")
	var budget := service.card_budget_report(_card_entry("星链拆解1", {"cost": 4, "kind": "player_hand_disrupt", "target_player_required": true, "hand_discard_count": 1}))
	_expect(int(budget.get("points", -1)) >= 0 and str(budget.get("band", "")) != "", "card budget diagnostics remain available through the service API")
	var debug := service.debug_snapshot()
	_expect(str(debug.get("runtime_balance_model_owner", "")) == "res://scripts/balance/runtime_balance_model.gd" and not bool(debug.get("formula_authority", true)) and not bool(debug.get("world_mutation_authority", true)), "RuntimeBalanceModel remains formula owner while diagnostics stays read-only")
	var main_text := FileAccess.get_file_as_string("res://scripts/main.gd")
	for retired_symbol in ["_development_route_profiles", "_card_strength_budget_report", "_development_route_balance_audit", "_direct_interaction_balance_report", "_role_balance_audit", "_monster_ecology_balance_report", "_product_ecosystem_report", "_card_supply_product_filter_audit", "_card_one_glance_audit_report", "_runtime_balance_snapshot"]:
		_expect(not main_text.contains("func %s(" % retired_symbol), "main.gd no longer owns retired diagnostic function %s" % retired_symbol)
	service.queue_free()


func _verify_environment_models() -> void:
	var refresh: Dictionary = _model.call("global_environment_refresh_model", 3, 18, 0, 1)
	_expect(float(refresh.get("market_refresh_seconds", 0.0)) >= 30.0 and float(refresh.get("market_refresh_seconds", 0.0)) <= 60.0, "global market refresh cadence stays inside the public 30-60 second band")
	_expect(float(refresh.get("forecast_window_seconds", 0.0)) >= 60.0 and float(refresh.get("forecast_window_seconds", 0.0)) <= 180.0, "weather forecast window stays inside the public 1-3 minute band")
	_expect(int(refresh.get("weather_zone_count", 0)) >= 1 and int(refresh.get("weather_zone_count", 0)) <= 5, "weather affects one to five zones by planet size")
	var storm: Dictionary = _model.call("weather_state_effect_model", "storm", "ocean", "海洋/运输")
	var clear: Dictionary = _model.call("weather_state_effect_model", "clear", "land", "食物/生物")
	_expect(float(storm.get("transport_multiplier", 1.0)) < float(clear.get("transport_multiplier", 1.0)) and int(storm.get("route_damage_pressure", 0)) > 0, "storm weather causally slows transport and creates route pressure")
	var volatility: Dictionary = _model.call("economic_volatility_model", 4, 1, 8, 3, 2, 3, 2)
	_expect(["normal", "crisis"].has(str(volatility.get("volatility_band", ""))) and float(volatility.get("single_refresh_cap_pct", 0.0)) <= 0.40, "economic volatility is derived from public pressure fields and remains capped")


func _sample_snapshot() -> Dictionary:
	return {
		"cards": [
			_card_entry("移动1", {"cost": 2, "kind": "move", "move": 180}),
			_card_entry("价格套利1", {"cost": 3, "kind": "product_speculation", "cash": 260, "price_delta": 18, "tags": ["经济", "商品"]}),
			_card_entry("垄断协议1", {"cost": 4, "kind": "area_trade_contract", "contract_income": 160, "accept_cash": 120, "market_demand_pressure": 1, "tags": ["合约", "经济"]}),
			_card_entry("商品看涨1", {"cost": 4, "kind": "product_futures", "futures_terms": {"direction": "up", "multiplier": 1.0, "duration_seconds": 60.0, "units": 1, "margin_cash": 120, "maximum_gain": 260, "maximum_loss": 120}, "market_demand_pressure": 1, "tags": ["经济", "期货"]}),
			_card_entry("商品看跌1", {"cost": 4, "kind": "product_futures", "futures_terms": {"direction": "down", "multiplier": 1.0, "duration_seconds": 60.0, "units": 1, "margin_cash": 120, "maximum_gain": 260, "maximum_loss": 120}, "market_supply_pressure": 1, "tags": ["经济", "期货"]}),
			_card_entry("港仓囤货1", {"cost": 4, "kind": "product_futures", "futures_terms": {"direction": "up", "multiplier": 0.75, "duration_seconds": 90.0, "units": 2, "requires_warehouse": true, "margin_cash": 180, "maximum_gain": 360, "maximum_loss": 180}, "tags": ["经济", "仓储"]}),
			_card_entry("城市买涨1", {"cost": 4, "kind": "city_gdp_derivative", "gdp_derivative_terms": {"direction": "up", "multiplier": 1.0, "duration_seconds": 60, "margin_cash": 120, "maximum_gain": 260, "maximum_loss": 120}, "tags": ["经济", "GDP"]}),
			_card_entry("城市做空1", {"cost": 4, "kind": "city_gdp_derivative", "gdp_derivative_terms": {"direction": "down", "multiplier": 1.2, "duration_seconds": 60, "destroy_bonus": 180, "margin_cash": 120, "maximum_gain": 260, "maximum_loss": 120}, "tags": ["经济", "GDP"]}),
			_card_entry("星链拆解1", {"cost": 4, "kind": "player_hand_disrupt", "target_player_required": true, "supply_product": "轨迹墨水", "hand_discard_count": 1, "tags": ["互动", "拆牌", "情报"]}),
			_card_entry("影仓牵引1", {"cost": 3, "kind": "player_hand_steal", "target_player_required": true, "hand_steal_count": 1, "supply_product": "阴影海藻", "tags": ["互动", "情报"]}),
			_card_entry("轨道齐射1", {"cost": 5, "kind": "global_barrage", "global_barrage_damage": 1, "global_barrage_target_count": 3, "global_barrage_route_damage": 1, "tags": ["战斗", "压制"]}),
			_card_entry("相位否决1", {"cost": 3, "kind": "card_counter", "counter_strength": 1, "counter_trace": 1, "tags": ["互动", "情报"]}),
			_card_entry("行星防卫军1", {"cost": 5, "kind": "military_force", "military_hp": 8, "military_damage": 1, "fixed_skill_count": 2, "tags": ["军队"]}),
			_card_entry("怪兽·孢雾海皇1", {"cost": 5, "kind": "monster_card", "hp": 48, "fixed_skill_count": 1, "tags": ["怪兽"]}),
		],
		"products": _sample_products(),
		"monsters": _sample_monsters(),
		"ai_routes": [
			{"id": "city_engine"},
			{"id": "monster_pressure"},
			{"id": "product_finance"},
			{"id": "military_pressure"},
		],
		"region_rows": {
			1: {"min": 6, "max": 9},
			2: {"min": 10, "max": 14},
			3: {"min": 15, "max": 21},
			4: {"min": 22, "max": 30},
			5: {"min": 31, "max": 41},
			6: {"min": 40, "max": 54},
		},
	}


func _card_entry(card_name: String, skill: Dictionary) -> Dictionary:
	var safe_skill := skill.duplicate(true)
	safe_skill["name"] = card_name
	var rank := int(card_name.substr(card_name.length() - 1, 1)) if card_name.substr(card_name.length() - 1, 1).is_valid_int() else 1
	safe_skill["rank"] = rank
	safe_skill = REQUIREMENT_POLICY.apply_to_card(card_name, safe_skill)
	return {
		"card_name": card_name,
		"skill": safe_skill,
		"rank": rank,
		"family": card_name.substr(0, card_name.length() - 1) if card_name.substr(card_name.length() - 1, 1).is_valid_int() else card_name,
		"price": int(_model.call("card_price_for_skill", safe_skill)) if _model != null else 80,
	}


func _sample_products() -> Array:
	var categories := ["食物/生物", "能源", "矿物/材料", "科技/数据", "奢侈/文化", "海洋/运输"]
	var rows := []
	for i in range(24):
		rows.append({
			"name": "测试商品%d" % (i + 1),
			"category": categories[i % categories.size()],
			"base_price": 70 + i * 5,
			"price": 70 + i * 5,
			"volatility": 3 + (i % 20),
		})
	return rows


func _sample_monsters() -> Array:
	return [
		{"name": "陆行碾城兽", "rank": 1, "move": 190.0, "movement_mode": "walk", "move_damage": 1, "actions": [{"name": "撞击", "damage": 1, "range": 110.0, "knockback": 70.0}]},
		{"name": "飞翼掠夺体", "rank": 2, "move": 260.0, "movement_mode": "fly", "movement_traits": ["flying"], "move_damage": 0, "actions": [{"name": "俯冲", "damage": 2, "range": 180.0, "knockback": 120.0}]},
		{"name": "海沟吞航者", "rank": 2, "move": 230.0, "movement_mode": "swim", "movement_traits": ["ocean"], "move_damage": 1, "actions": [{"name": "吞航", "damage": 2, "range": 160.0, "knockback": 80.0}]},
		{"name": "地脉钻行兽", "rank": 3, "move": 210.0, "movement_mode": "tunnel", "movement_traits": ["tunnel"], "move_damage": 2, "actions": [{"name": "地震", "damage": 3, "range": 260.0, "knockback": 180.0}]},
		{"name": "轨道孢子母巢", "rank": 3, "move": 180.0, "movement_mode": "orbital", "movement_traits": ["orbital"], "move_damage": 1, "actions": [{"name": "孢雾", "damage": 2, "range": 300.0, "knockback": 60.0}]},
		{"name": "冻海电鳗", "rank": 1, "move": 220.0, "movement_mode": "hybrid", "movement_traits": ["ocean", "land"], "move_damage": 1, "actions": [{"name": "电击", "damage": 2, "range": 170.0, "knockback": 110.0}]},
		{"name": "港仓噬金虫", "rank": 2, "move": 200.0, "movement_mode": "walk", "move_damage": 1, "actions": [{"name": "啃仓", "damage": 2, "range": 100.0, "knockback": 40.0}]},
		{"name": "红雾鲸", "rank": 4, "move": 250.0, "movement_mode": "swim", "movement_traits": ["ocean"], "move_damage": 2, "actions": [{"name": "红潮", "damage": 4, "range": 360.0, "knockback": 240.0}]},
	]


func _as_array(value: Variant) -> Array:
	return value as Array if value is Array else []


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
		return
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("Runtime balance report test passed.")
		quit(0)
	else:
		printerr("Runtime balance report test failed:")
		for failure in _failures:
			printerr("- %s" % failure)
		quit(1)
