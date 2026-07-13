@tool
extends Resource
class_name AiPersonalityPolicyResource

@export var policy_id := "pioneer"
@export var display_name := "拓荒型AI"
@export_multiline var style := "优先抢高GDP陆地与海洋邻接位，尽快形成城市收入。"

@export_category("Decision Biases")
@export_range(0.0, 2.5, 0.01) var build_bias := 1.0
@export_range(0.0, 2.5, 0.01) var business_bias := 1.0
@export_range(0.0, 2.5, 0.01) var monster_bias := 1.0
@export_range(0.0, 2.5, 0.01) var economy_bias := 1.0
@export_range(0.0, 2.5, 0.01) var bid_aggression := 1.0
@export_range(0.0, 1.0, 0.01) var exploration := 0.15

@export_category("Development Routes")
@export var route_preferences: Dictionary = {}


func to_policy_dictionary() -> Dictionary:
	var payload := to_main_catalog_dictionary()
	payload["policy_id"] = policy_id
	return payload


func to_main_catalog_dictionary() -> Dictionary:
	return {
		"name": display_name,
		"style": style,
		"build_bias": build_bias,
		"business_bias": business_bias,
		"monster_bias": monster_bias,
		"economy_bias": economy_bias,
		"bid_aggression": bid_aggression,
		"exploration": exploration,
		"route_preferences": route_preferences.duplicate(true),
	}


func validate_profile() -> Array:
	return [
		{
			"id": "%s_identity" % policy_id,
			"passed": policy_id != "" and display_name != "" and style != "",
			"notes": "personality has an id, display name, and designer-readable style",
		},
		{
			"id": "%s_bias_ranges" % policy_id,
			"passed": build_bias >= 0.0 and business_bias >= 0.0 and monster_bias >= 0.0 and economy_bias >= 0.0 and bid_aggression >= 0.0 and exploration >= 0.0 and exploration <= 1.0,
			"notes": "biases are non-negative and exploration stays in the 0..1 range",
		},
		{
			"id": "%s_route_preferences" % policy_id,
			"passed": not route_preferences.is_empty() and _route_preferences_are_numeric(),
			"notes": "route preferences are Inspector-editable numeric weights",
		},
	]


func _route_preferences_are_numeric() -> bool:
	for route_id in route_preferences:
		if str(route_id) == "" or not (route_preferences[route_id] is int or route_preferences[route_id] is float):
			return false
	return true
