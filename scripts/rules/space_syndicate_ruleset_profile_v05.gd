extends Resource
class_name SpaceSyndicateRulesetProfileV05

@export var ruleset_id: String = "v0.5"
@export var profile_schema_version: int = 1
@export var currency_scale: int = 100
@export var region_control_threshold_bp: int = 3000
@export var victory_depth_table: Dictionary = {
	"I": {"regions": 3, "depth": 90},
	"II": {"regions": 4, "depth": 130},
	"III": {"regions": 5, "depth": 180},
	"IV": {"regions": 6, "depth": 230},
	"V": {"regions": 7, "depth": 290},
	"VI": {"regions": 8, "depth": 360},
}

@export_group("Qualification And Audit")
@export var qualification_seconds: int = 10
@export var audit_seconds: int = 120
@export var audit_failure_cooldown_seconds: int = 30

@export_group("Industry And Cards")
@export var industry_capacity_thresholds: Array[int] = [15, 40, 80, 140]
@export var card_group_seconds: int = 8
@export var organize_seconds: int = 6
@export var lock_seconds: int = 2
@export var tutorial_group_card_limit: int = 1
@export var standard_group_card_limit: int = 2
@export var priority_bid_options_cents: Array[int] = [0, 5000, 10000]
@export var ordinary_hand_limit: int = 5
@export var maximum_card_rank: int = 4

@export_group("Purchase And Responses")
@export var purchase_window_seconds: int = 12
@export var local_purchase_price_bp: int = 8000
@export var adjacent_purchase_price_bp: int = 10000

@export_group("Monster")
@export var monster_warning_seconds: int = 5
@export var monster_wager_seconds: int = 8
@export var monster_wager_min_rate_bp: int = 500
@export var monster_wager_max_rate_bp: int = 1000
@export var battle_limit_quick: int = 30
@export var battle_limit_standard: int = 45
@export var battle_limit_expert: int = 60

@export_group("Intel Weather And Distress")
@export var intel_stake_cents: int = 10000
@export var intel_correct_net_reward_cents: int = 10000
@export var intel_tracking_seconds: int = 60
@export var weather_forecast_seconds: int = 90
@export var weather_duration_seconds: int = 90
@export var financial_distress_seconds: int = 20

@export_group("Project Slots")
@export var project_slot_counts: Dictionary = {
	"production": 2,
	"demand": 2,
	"commerce": 1,
}
@export var maximum_project_rank: int = 4

@export_group("Capabilities")
@export var realtime_income_enabled: bool = true
@export var direct_city_build_allowed: bool = false
@export var private_plan_enabled: bool = false
@export var end_turn_enabled: bool = false
@export var player_pipeline_building_enabled: bool = false
@export var standard_market_noise_enabled: bool = false


func validation_snapshot() -> Dictionary:
	return {
		"ruleset_id": ruleset_id,
		"profile_schema_version": profile_schema_version,
		"currency_scale": currency_scale,
		"region_control_threshold_bp": region_control_threshold_bp,
		"victory_depth_table": victory_depth_table.duplicate(true),
		"industry_capacity_thresholds": industry_capacity_thresholds.duplicate(),
		"project_slot_counts": project_slot_counts.duplicate(true),
		"maximum_project_rank": maximum_project_rank,
	}


func timing_rules() -> Dictionary:
	return {
		"qualification_seconds": qualification_seconds,
		"audit_seconds": audit_seconds,
		"audit_failure_cooldown_seconds": audit_failure_cooldown_seconds,
		"card_group_seconds": card_group_seconds,
		"organize_seconds": organize_seconds,
		"lock_seconds": lock_seconds,
		"purchase_window_seconds": purchase_window_seconds,
		"monster_warning_seconds": monster_warning_seconds,
		"monster_wager_seconds": monster_wager_seconds,
		"battle_limit_quick": battle_limit_quick,
		"battle_limit_standard": battle_limit_standard,
		"battle_limit_expert": battle_limit_expert,
		"intel_tracking_seconds": intel_tracking_seconds,
		"weather_forecast_seconds": weather_forecast_seconds,
		"weather_duration_seconds": weather_duration_seconds,
		"financial_distress_seconds": financial_distress_seconds,
	}


func card_group_rules() -> Dictionary:
	return {
		"group_seconds": card_group_seconds,
		"organize_seconds": organize_seconds,
		"lock_seconds": lock_seconds,
		"tutorial_group_card_limit": tutorial_group_card_limit,
		"standard_group_card_limit": standard_group_card_limit,
		"priority_bid_options_cents": priority_bid_options_cents.duplicate(),
	}


func card_inventory_rules() -> Dictionary:
	return {
		"ordinary_hand_limit": ordinary_hand_limit,
		"maximum_card_rank": maximum_card_rank,
	}


func capability_rules() -> Dictionary:
	return {
		"realtime_income_enabled": realtime_income_enabled,
		"direct_city_build_allowed": direct_city_build_allowed,
		"private_plan_enabled": private_plan_enabled,
		"end_turn_enabled": end_turn_enabled,
		"player_pipeline_building_enabled": player_pipeline_building_enabled,
		"standard_market_noise_enabled": standard_market_noise_enabled,
	}


func debug_snapshot() -> Dictionary:
	return {
		"identity": {
			"ruleset_id": ruleset_id,
			"profile_schema_version": profile_schema_version,
			"currency_scale": currency_scale,
		},
		"validation": validation_snapshot(),
		"timing": timing_rules(),
		"card_group": card_group_rules(),
		"card_inventory": card_inventory_rules(),
		"capabilities": capability_rules(),
		"purchase": {
			"local_purchase_price_bp": local_purchase_price_bp,
			"adjacent_purchase_price_bp": adjacent_purchase_price_bp,
		},
		"monster_wager": {
			"minimum_rate_bp": monster_wager_min_rate_bp,
			"maximum_rate_bp": monster_wager_max_rate_bp,
		},
		"intel": {
			"stake_cents": intel_stake_cents,
			"correct_net_reward_cents": intel_correct_net_reward_cents,
		},
	}
