@tool
extends Node
class_name RulesetRuntimeBridge

const DEFAULT_PROFILE_PATH := "res://resources/rules/space_syndicate_ruleset_v04.tres"

@export var ruleset_profile: Resource


func active_profile() -> Dictionary:
	var profile := _profile()
	var value: Variant = profile.call("debug_snapshot") if profile != null and profile.has_method("debug_snapshot") else _missing_snapshot()
	return (value as Dictionary).duplicate(true) if value is Dictionary else _missing_snapshot()


func timing_rules() -> Dictionary:
	var profile := _profile()
	var value: Variant = profile.call("timing_rules") if profile != null and profile.has_method("timing_rules") else {}
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func card_group_rules() -> Dictionary:
	var profile := _profile()
	var value: Variant = profile.call("card_group_rules") if profile != null and profile.has_method("card_group_rules") else {}
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func card_inventory_rules() -> Dictionary:
	var profile := _profile()
	var value: Variant = profile.call("card_inventory_rules") if profile != null and profile.has_method("card_inventory_rules") else {}
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func capability_rules() -> Dictionary:
	var profile := _profile()
	var value: Variant = profile.call("capability_rules") if profile != null and profile.has_method("capability_rules") else {}
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func decision_priority() -> Array[String]:
	var profile := _profile()
	var value: Variant = profile.call("decision_priority") if profile != null and profile.has_method("decision_priority") else []
	var result: Array[String] = []
	if value is Array:
		for item in value:
			result.append(str(item))
	return result


func debug_snapshot() -> Dictionary:
	var profile := _profile()
	if profile == null:
		return _missing_snapshot()
	var snapshot_variant: Variant = profile.call("debug_snapshot") if profile.has_method("debug_snapshot") else {}
	var snapshot: Dictionary = (snapshot_variant as Dictionary).duplicate(true) if snapshot_variant is Dictionary else {}
	if snapshot.is_empty():
		return _missing_snapshot()
	snapshot["bridge_ready"] = true
	snapshot["profile_path"] = DEFAULT_PROFILE_PATH
	return snapshot


func is_profile_ready() -> bool:
	var profile := _profile()
	if profile == null or not profile.has_method("validation_snapshot"):
		return false
	var validation_variant: Variant = profile.call("validation_snapshot")
	return validation_variant is Dictionary and bool((validation_variant as Dictionary).get("valid", false))


func _profile() -> Resource:
	if ruleset_profile != null:
		return ruleset_profile
	var loaded := load(DEFAULT_PROFILE_PATH) as Resource
	if loaded != null:
		ruleset_profile = loaded
	return ruleset_profile


func _missing_snapshot() -> Dictionary:
	return {
		"ruleset_id": "",
		"bridge_ready": false,
		"profile_path": DEFAULT_PROFILE_PATH,
		"timing": {},
		"card_group": {},
		"card_inventory": {},
		"forced_decision_priority": [],
		"capabilities": {},
		"validation": {
			"valid": false,
			"issues": ["ruleset profile unavailable"],
		},
	}
