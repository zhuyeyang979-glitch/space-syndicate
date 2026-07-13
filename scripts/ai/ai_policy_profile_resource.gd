@tool
extends Resource
class_name AiPolicyProfileResource

@export var profile_id := "ai_policy_v1"
@export var display_name := "AI Policy Profile v1"
@export_multiline var design_notes := "Inspector-editable runtime source for player-AI timing, thresholds, strategy weights, learning controls, and personality profiles."
@export_file("*.gd") var runtime_owner_script := "res://scripts/runtime/ai_runtime_controller.gd"
@export var runtime_cutover_enabled := true

@export_category("Decision Timing")
@export_range(0.1, 30.0, 0.1) var card_decision_interval_seconds := 2.2
@export_range(0.1, 10.0, 0.1) var auction_reaction_interval_seconds := 0.7
@export_range(0.1, 30.0, 0.1) var intel_decision_interval_seconds := 5.5

@export_category("Selection Thresholds")
@export_range(0, 5000, 1) var card_buy_min_cash_reserve := 260
@export_range(1, 256, 1) var decision_sample_limit := 48
@export_range(1, 64, 1) var candidate_sample_limit := 8
@export_range(0, 1000, 1) var intel_min_city_score := 78
@export_range(0, 1000, 1) var intel_min_card_score := 125
@export_range(1, 16, 1) var intel_actions_per_tick := 2

@export_category("Counter Policy")
@export_range(0, 2000, 1) var counter_response_min_score := 160
@export_range(0, 2000, 1) var counter_response_confident_score := 270

@export_category("Strategy And Route Planning")
@export_range(1, 16, 1) var economic_focus_top_limit := 3
@export_range(0, 1000, 1) var economic_focus_match_bonus := 85
@export_range(0, 1000, 1) var strategy_match_bonus := 92
@export_range(1, 16, 1) var strategy_top_limit := 3
@export_range(0, 1000, 1) var route_plan_match_bonus := 78
@export_range(1, 16, 1) var route_plan_top_limit := 4
@export_range(0, 2000, 1) var route_plan_switch_margin := 140
@export_range(0, 4000, 1) var route_plan_entrenched_switch_margin := 360

@export_category("Game Phase And Posture")
@export_range(0.0, 1.0, 0.01) var endgame_goal_ratio := 0.72
@export_range(1, 64, 1) var endgame_cycle := 7
@export_range(0, 16, 1) var opening_cycle_max := 1
@export_range(0, 5000, 1) var lead_margin := 280
@export_range(0, 5000, 1) var trailing_margin := 360

@export_category("Learning Controls")
@export_range(0, 10000, 1) var learning_reward_clamp := 1200
@export_range(0.0, 1000.0, 0.1) var learning_value_clamp := 90.0
@export_range(0, 2000, 1) var learning_bonus_clamp := 140
@export_range(0.0, 1.0, 0.01) var learning_base_rate := 0.22
@export_range(0, 10000, 1) var episode_reward_clamp := 1800
@export_range(0.0, 1.0, 0.01) var episode_sample_decay := 0.88
@export_range(0, 5000, 1) var episode_win_bonus := 420
@export_range(0, 5000, 1) var episode_goal_bonus := 240

@export_category("Personality Profiles")
@export var personality_profiles: Array[Resource] = []


func parameter_groups() -> Dictionary:
	return {
		"timing": {
			"card_decision_interval_seconds": card_decision_interval_seconds,
			"auction_reaction_interval_seconds": auction_reaction_interval_seconds,
			"intel_decision_interval_seconds": intel_decision_interval_seconds,
		},
		"selection": {
			"card_buy_min_cash_reserve": card_buy_min_cash_reserve,
			"decision_sample_limit": decision_sample_limit,
			"candidate_sample_limit": candidate_sample_limit,
			"intel_min_city_score": intel_min_city_score,
			"intel_min_card_score": intel_min_card_score,
			"intel_actions_per_tick": intel_actions_per_tick,
		},
		"counter": {
			"counter_response_min_score": counter_response_min_score,
			"counter_response_confident_score": counter_response_confident_score,
		},
		"strategy": {
			"economic_focus_top_limit": economic_focus_top_limit,
			"economic_focus_match_bonus": economic_focus_match_bonus,
			"strategy_match_bonus": strategy_match_bonus,
			"strategy_top_limit": strategy_top_limit,
			"route_plan_match_bonus": route_plan_match_bonus,
			"route_plan_top_limit": route_plan_top_limit,
			"route_plan_switch_margin": route_plan_switch_margin,
			"route_plan_entrenched_switch_margin": route_plan_entrenched_switch_margin,
		},
		"phase": {
			"endgame_goal_ratio": endgame_goal_ratio,
			"endgame_cycle": endgame_cycle,
			"opening_cycle_max": opening_cycle_max,
			"lead_margin": lead_margin,
			"trailing_margin": trailing_margin,
		},
		"learning": {
			"learning_reward_clamp": learning_reward_clamp,
			"learning_value_clamp": learning_value_clamp,
			"learning_bonus_clamp": learning_bonus_clamp,
			"learning_base_rate": learning_base_rate,
			"episode_reward_clamp": episode_reward_clamp,
			"episode_sample_decay": episode_sample_decay,
			"episode_win_bonus": episode_win_bonus,
			"episode_goal_bonus": episode_goal_bonus,
		},
	}


func to_policy_dictionary() -> Dictionary:
	var payload := parameter_groups()
	payload["profile_id"] = profile_id
	payload["display_name"] = display_name
	payload["runtime_owner_script"] = runtime_owner_script
	payload["runtime_cutover_enabled"] = runtime_cutover_enabled
	payload["personalities"] = _personality_payloads(false)
	return payload


func to_main_source_dictionary() -> Dictionary:
	var payload := parameter_groups()
	payload["personalities"] = _personality_payloads(true)
	return payload


func validate_profile() -> Array:
	var personality_ids: Array[String] = []
	var personalities_valid := personality_profiles.size() == 6
	for personality in personality_profiles:
		if personality == null or not personality.has_method("to_policy_dictionary") or not personality.has_method("to_main_catalog_dictionary"):
			personalities_valid = false
			continue
		var personality_payload: Dictionary = personality.call("to_policy_dictionary")
		var personality_id := str(personality_payload.get("policy_id", ""))
		if personality_id == "" or personality_ids.has(personality_id):
			personalities_valid = false
		else:
			personality_ids.append(personality_id)
	return [
		{
			"id": "ai_policy_identity",
			"passed": profile_id != "" and display_name != "" and runtime_owner_script == "res://scripts/runtime/ai_runtime_controller.gd",
			"notes": "profile has stable metadata and names AiRuntimeController as the runtime owner",
		},
		{
			"id": "ai_policy_cutover_guard",
			"passed": runtime_cutover_enabled,
			"notes": "AI Policy Resource is the explicit runtime parameter source after hard cutover",
		},
		{
			"id": "ai_policy_personalities",
			"passed": personalities_valid,
			"notes": "six unique personality Resources expose policy and main-catalog payloads",
		},
	]


func resource_summary() -> Dictionary:
	var groups := parameter_groups()
	var tunable_count := 0
	for group_variant in groups.values():
		if group_variant is Dictionary:
			tunable_count += (group_variant as Dictionary).size()
	return {
		"profile_id": profile_id,
		"display_name": display_name,
		"runtime_owner_script": runtime_owner_script,
		"runtime_cutover_enabled": runtime_cutover_enabled,
		"tunable_count": tunable_count,
		"personality_count": personality_profiles.size(),
		"group_count": groups.size(),
	}


func _personality_payloads(main_compatible: bool) -> Array:
	var payloads: Array = []
	for personality in personality_profiles:
		if personality == null:
			continue
		var method_name := "to_main_catalog_dictionary" if main_compatible else "to_policy_dictionary"
		if not personality.has_method(method_name):
			continue
		var payload: Variant = personality.call(method_name)
		if payload is Dictionary:
			payloads.append((payload as Dictionary).duplicate(true))
	return payloads
