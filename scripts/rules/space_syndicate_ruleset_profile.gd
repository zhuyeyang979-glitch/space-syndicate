@tool
extends Resource
class_name SpaceSyndicateRulesetProfile

@export_category("Identity")
@export var ruleset_id := "v0.4"
@export_multiline var design_notes := "Inspector-editable source of truth for stable Space Syndicate v0.4 ruleset parameters."

@export_category("Timing")
@export_range(1.0, 120.0, 1.0) var shared_window_seconds := 30.0
@export_range(1.0, 120.0, 1.0) var organize_seconds := 25.0
@export_range(1.0, 30.0, 1.0) var lock_seconds := 5.0
@export_range(1.0, 30.0, 1.0) var purchase_window_seconds := 12.0
@export_range(1.0, 30.0, 1.0) var counter_window_seconds := 5.0
@export_range(1.0, 30.0, 1.0) var contract_window_seconds := 5.0
@export_range(1.0, 60.0, 1.0) var monster_wager_default_seconds := 15.0
@export_range(1.0, 60.0, 1.0) var monster_wager_max_seconds := 15.0
@export_range(0.0, 120.0, 1.0) var monster_wager_reopen_cooldown_seconds := 20.0
@export_range(1.0, 180.0, 1.0) var final_countdown_seconds := 75.0

@export_category("Card Group")
@export_range(1, 4, 1) var default_group_card_limit := 3
@export_range(1, 6, 1) var maximum_group_card_limit := 4

@export_category("Card Inventory")
@export_range(1, 10, 1) var ordinary_hand_limit := 5
@export_range(1, 4, 1) var maximum_card_rank := 4

@export_category("Decision Scheduling")
@export var forced_decision_priority: Array[String] = [
	"monster_wager",
	"counter_response",
	"contract_response",
	"other_choice",
]

@export_category("Capabilities")
@export var realtime_income_enabled := true
@export var direct_city_build_allowed := false
@export var city_development_requires_product_project := true
@export var private_plan_enabled := true


func timing_rules() -> Dictionary:
	return {
		"shared_window_seconds": shared_window_seconds,
		"organize_seconds": organize_seconds,
		"lock_seconds": lock_seconds,
		"purchase_window_seconds": purchase_window_seconds,
		"counter_window_seconds": counter_window_seconds,
		"contract_window_seconds": contract_window_seconds,
		"monster_wager_default_seconds": monster_wager_default_seconds,
		"monster_wager_max_seconds": monster_wager_max_seconds,
		"monster_wager_reopen_cooldown_seconds": monster_wager_reopen_cooldown_seconds,
		"final_countdown_seconds": final_countdown_seconds,
	}


func card_group_rules() -> Dictionary:
	return {
		"default_group_card_limit": default_group_card_limit,
		"maximum_group_card_limit": maximum_group_card_limit,
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
		"city_development_requires_product_project": city_development_requires_product_project,
		"private_plan_enabled": private_plan_enabled,
	}


func decision_priority() -> Array[String]:
	return forced_decision_priority.duplicate()


func debug_snapshot() -> Dictionary:
	return {
		"ruleset_id": ruleset_id,
		"timing": timing_rules(),
		"card_group": card_group_rules(),
		"card_inventory": card_inventory_rules(),
		"forced_decision_priority": decision_priority(),
		"capabilities": capability_rules(),
		"validation": validation_snapshot(),
	}


func validation_snapshot() -> Dictionary:
	var issues: Array[String] = []
	if ruleset_id != "v0.4":
		issues.append("ruleset_id must be v0.4")
	if not is_equal_approx(shared_window_seconds, organize_seconds + lock_seconds):
		issues.append("organize_seconds + lock_seconds must equal shared_window_seconds")
	if monster_wager_default_seconds > monster_wager_max_seconds:
		issues.append("monster wager default cannot exceed maximum")
	if default_group_card_limit > maximum_group_card_limit:
		issues.append("default card-group limit cannot exceed maximum")
	if ordinary_hand_limit != 5:
		issues.append("ordinary hand limit must be five for v0.4")
	if maximum_card_rank != 4:
		issues.append("maximum card rank must be IV for v0.4")
	if forced_decision_priority != ["monster_wager", "counter_response", "contract_response", "other_choice"]:
		issues.append("forced decision priority does not match v0.4")
	return {
		"valid": issues.is_empty(),
		"issues": issues,
	}
