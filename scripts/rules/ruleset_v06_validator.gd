extends RefCounted
class_name RulesetV06Validator

const RANKS := ["I", "II", "III", "IV"]


static func validate(profile: Resource) -> Dictionary:
	var errors: Array[String] = []
	if profile == null or not profile.has_method("debug_snapshot"):
		return {"valid": false, "errors": ["profile_missing_or_api_invalid"], "snapshot": {}}
	var snapshot: Dictionary = profile.debug_snapshot()
	var identity: Dictionary = snapshot.get("identity", {})
	var infrastructure: Dictionary = snapshot.get("infrastructure", {})
	var victory: Dictionary = snapshot.get("victory", {})
	var card_group: Dictionary = snapshot.get("card_group", {})
	var card_inventory: Dictionary = snapshot.get("card_inventory", {})
	var commodity: Dictionary = snapshot.get("commodity", {})
	var mana: Dictionary = snapshot.get("mana", {})
	var monster: Dictionary = snapshot.get("monster", {})
	var capabilities: Dictionary = snapshot.get("capabilities", {})
	_expect(errors, str(identity.get("ruleset_id", "")) == "v0.6", "ruleset_id_must_be_v0.6")
	_expect(errors, int(identity.get("profile_schema_version", 0)) > 0, "profile_schema_version_invalid")
	_expect(errors, int(identity.get("currency_scale", 0)) == 100, "currency_scale_must_be_100")
	_expect(errors, infrastructure.get("facility_hp_contribution_by_rank", {}) == {"I": 100, "II": 200, "III": 300, "IV": 400}, "facility_hp_contributions_invalid")
	_expect(errors, infrastructure.get("factory_market_capacity_by_rank", {}) == {"I": 40, "II": 80, "III": 140, "IV": 220}, "factory_market_capacity_invalid")
	_expect(errors, infrastructure.get("transport_throughput_by_rank", {}) == {"I": 50, "II": 100, "III": 175, "IV": 275}, "transport_throughput_invalid")
	_expect(errors, infrastructure.get("warehouse_capacity_by_rank", {}) == {"I": 200, "II": 400, "III": 700, "IV": 1100}, "warehouse_capacity_invalid")
	_expect(errors, infrastructure.get("warehouse_throughput_by_rank", {}) == {"I": 50, "II": 100, "III": 175, "IV": 275}, "warehouse_throughput_invalid")
	_expect(errors, infrastructure.get("warehouse_storage_rent_bp_per_minute_by_rank", {}) == {"I": 25, "II": 20, "III": 15, "IV": 10}, "warehouse_storage_rent_invalid")
	_expect(errors, int(victory.get("region_control_threshold_bp", 0)) == 3000, "region_control_threshold_invalid")
	_expect(errors, int(victory.get("dynamic_victory_coverage_bp", 0)) == 4000, "victory_coverage_invalid")
	_expect(errors, int(victory.get("gdp_per_required_region_per_minute", 0)) == 36, "gdp_per_region_invalid")
	_expect(errors, int(victory.get("qualification_seconds", 0)) == 10 and int(victory.get("audit_seconds", 0)) == 120 and int(victory.get("gdp_observation_window_seconds", 0)) == 30, "victory_timing_invalid")
	_expect(
		errors,
		int(card_group.get("group_seconds", 0)) == 30 \
			and int(card_group.get("planning_seconds", 0)) == 20 \
			and int(card_group.get("public_bid_seconds", 0)) == 5 \
			and int(card_group.get("lock_seconds", 0)) == 5,
		"card_window_invalid"
	)
	_expect(
		errors,
		int(card_group.get("opening_extended_windows", 0)) == 3 \
			and int(card_group.get("opening_group_seconds", 0)) == 45 \
			and int(card_group.get("opening_planning_seconds", 0)) == 35,
		"opening_card_window_invalid"
	)
	_expect(errors, int(card_group.get("ordinary_card_limit", 0)) == 1 and int(card_group.get("standard_group_card_limit", 0)) == 1, "ordinary_card_limit_invalid")
	_expect(errors, int(card_group.get("maximum_with_explicit_capability", 0)) == 3, "explicit_card_limit_invalid")
	_expect(errors, int(card_group.get("organize_seconds", 0)) == int(card_group.get("planning_seconds", -1)), "organize_alias_invalid")
	_expect(errors, int(card_inventory.get("ordinary_hand_limit", 0)) == 5 and int(card_inventory.get("maximum_card_rank", 0)) == 4, "card_inventory_invalid")
	_expect(errors, commodity.get("commodity_rate_by_rank", {}) == {"I": 10, "II": 20, "III": 40, "IV": 80}, "commodity_rate_invalid")
	_expect(errors, int(commodity.get("commodity_belt_refresh_seconds", 0)) == 5 and int(commodity.get("leading_tier_minimum_visible_cards", 0)) == 3, "commodity_belt_invalid")
	_expect(errors, int(mana.get("observation_window_seconds", 0)) == 30 and int(mana.get("per_color_maximum", 0)) == 100 and int(mana.get("gdp_per_minute_divisor", 0)) == 100, "mana_rules_invalid")
	_expect(errors, int(monster.get("battle_limit_seconds", 0)) == 60 and int(monster.get("upgrade_delay_extension_seconds", 0)) == 60 and int(monster.get("wager_seconds", 0)) == 8, "monster_timing_invalid")
	_expect(errors, int(monster.get("wager_minimum_rate_bp", 0)) == 500 and int(monster.get("wager_maximum_rate_bp", 0)) == 1000 and int(monster.get("wager_standard_rate_bp", 0)) == 500, "monster_wager_rate_invalid")
	for enabled_key in ["public_facility_model_enabled", "region_shared_hp_enabled", "continuous_commodity_flow_enabled", "six_color_mana_enabled"]:
		_expect(errors, bool(capabilities.get(enabled_key, false)), "capability_must_be_enabled:%s" % enabled_key)
	for disabled_key in ["legacy_project_slots_enabled", "industry_capacity_reservations_enabled", "direct_city_build_allowed", "private_plan_enabled", "end_turn_enabled", "player_pipeline_building_enabled", "standard_market_noise_enabled"]:
		_expect(errors, not bool(capabilities.get(disabled_key, true)), "capability_must_be_disabled:%s" % disabled_key)
	_expect(errors, _is_pure_data(snapshot), "snapshot_not_pure_data")
	return {"valid": errors.is_empty(), "errors": errors, "snapshot": snapshot.duplicate(true)}


static func _expect(errors: Array[String], condition: bool, error_code: String) -> void:
	if not condition:
		errors.append(error_code)


static func _is_pure_data(value: Variant) -> bool:
	if value == null or value is String or value is StringName or value is bool or value is int or value is float:
		return true
	if value is Array:
		for item in value:
			if not _is_pure_data(item):
				return false
		return true
	if value is Dictionary:
		for key in value:
			if not (key is String or key is StringName or key is int) or not _is_pure_data(value[key]):
				return false
		return true
	return false
