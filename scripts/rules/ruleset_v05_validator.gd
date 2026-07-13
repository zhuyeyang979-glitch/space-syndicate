extends RefCounted
class_name RulesetV05Validator

const EXPECTED_DEPTH_TABLE := {
	"I": {"regions": 3, "depth": 90},
	"II": {"regions": 4, "depth": 130},
	"III": {"regions": 5, "depth": 180},
	"IV": {"regions": 6, "depth": 230},
	"V": {"regions": 7, "depth": 290},
	"VI": {"regions": 8, "depth": 360},
}


static func validate(profile: Resource) -> Dictionary:
	var errors: Array[String] = []
	if profile == null:
		return {"valid": false, "errors": ["profile_missing"], "snapshot": {}}
	if not profile.has_method("debug_snapshot"):
		return {"valid": false, "errors": ["profile_api_missing"], "snapshot": {}}
	var snapshot: Dictionary = profile.debug_snapshot()
	var identity: Dictionary = snapshot.get("identity", {})
	var validation: Dictionary = snapshot.get("validation", {})
	var timing: Dictionary = snapshot.get("timing", {})
	var card_group: Dictionary = snapshot.get("card_group", {})
	var card_inventory: Dictionary = snapshot.get("card_inventory", {})
	var capabilities: Dictionary = snapshot.get("capabilities", {})
	if str(identity.get("ruleset_id", "")) != "v0.5":
		errors.append("ruleset_id_must_be_v0.5")
	if int(identity.get("profile_schema_version", 0)) <= 0:
		errors.append("profile_schema_version_invalid")
	if int(identity.get("currency_scale", 0)) != 100:
		errors.append("currency_scale_must_be_100")
	if int(validation.get("region_control_threshold_bp", -1)) != 3000:
		errors.append("region_control_threshold_bp_invalid")
	if validation.get("victory_depth_table", {}) != EXPECTED_DEPTH_TABLE:
		errors.append("victory_depth_table_invalid")
	if validation.get("industry_capacity_thresholds", []) != [15, 40, 80, 140]:
		errors.append("industry_capacity_thresholds_invalid")
	if validation.get("project_slot_counts", {}) != {"production": 2, "demand": 2, "commerce": 1}:
		errors.append("project_slot_counts_invalid")
	if int(validation.get("maximum_project_rank", 0)) != 4:
		errors.append("maximum_project_rank_invalid")
	if int(timing.get("card_group_seconds", 0)) != 8 or int(timing.get("organize_seconds", 0)) != 6 or int(timing.get("lock_seconds", 0)) != 2:
		errors.append("card_group_timing_invalid")
	if int(card_group.get("tutorial_group_card_limit", 0)) != 1 or int(card_group.get("standard_group_card_limit", 0)) != 2:
		errors.append("card_group_limit_invalid")
	if card_group.get("priority_bid_options_cents", []) != [0, 5000, 10000]:
		errors.append("priority_bid_options_invalid")
	if int(card_inventory.get("ordinary_hand_limit", 0)) != 5 or int(card_inventory.get("maximum_card_rank", 0)) != 4:
		errors.append("card_inventory_rules_invalid")
	if not bool(capabilities.get("realtime_income_enabled", false)):
		errors.append("realtime_income_must_be_enabled")
	for disabled_capability in ["direct_city_build_allowed", "private_plan_enabled", "end_turn_enabled", "player_pipeline_building_enabled", "standard_market_noise_enabled"]:
		if bool(capabilities.get(disabled_capability, true)):
			errors.append("capability_must_be_disabled:%s" % disabled_capability)
	if not _is_pure_data(snapshot):
		errors.append("snapshot_not_pure_data")
	return {"valid": errors.is_empty(), "errors": errors, "snapshot": snapshot.duplicate(true)}


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
			if not (key is String or key is StringName or key is int):
				return false
			if not _is_pure_data(value[key]):
				return false
		return true
	return false
