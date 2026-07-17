extends RefCounted
class_name VictoryPresentationStateChangeReceipt

var receipt_id := ""
var revision := 0
var change_kind: StringName = &""
var previous_state := "idle"
var state := "idle"
var world_time := 0.0
var public_snapshot: Dictionary = {}
var participant_names: Dictionary = {}
var public_map_facts: Dictionary = {}
var immediate_refresh_mask: Array[StringName] = []


func is_valid() -> bool:
	return not receipt_id.is_empty() \
		and not str(change_kind).is_empty() \
		and _is_public_data(public_snapshot) \
		and _is_public_data(participant_names) \
		and _is_public_data(public_map_facts) \
		and not _contains_private_key(public_snapshot)


func to_dictionary() -> Dictionary:
	if not is_valid():
		return {}
	var refresh_values: Array = []
	for value in immediate_refresh_mask:
		refresh_values.append(str(value))
	return {
		"receipt_id": receipt_id,
		"revision": revision,
		"change_kind": str(change_kind),
		"previous_state": previous_state,
		"state": state,
		"world_time": world_time,
		"public_snapshot": public_snapshot.duplicate(true),
		"participant_names": participant_names.duplicate(true),
		"public_map_facts": public_map_facts.duplicate(true),
		"immediate_refresh_mask": refresh_values,
		"visibility_scope": "public",
	}


func public_context() -> Dictionary:
	if not is_valid():
		return {}
	return {
		"victory_public_snapshot": public_snapshot.duplicate(true),
		"participant_names": participant_names.duplicate(true),
		"public_map_facts": public_map_facts.duplicate(true),
		"reason": str(change_kind),
	}


func _contains_private_key(value: Variant) -> bool:
	if value is Dictionary:
		for key_variant in value.keys():
			var key := str(key_variant).to_lower()
			if key in [
				"ai_plan", "ai_reason", "ai_utility_score", "decision_samples",
				"discard", "hand", "hidden_owner", "learning_bonus", "opponent_hand",
				"owner_truth", "players", "private_hand", "private_route_plan",
				"raw_players", "route_plan_score", "true_owner",
			]:
				return true
			if _contains_private_key(value[key_variant]):
				return true
	elif value is Array:
		for child in value:
			if _contains_private_key(child):
				return true
	return false


func _is_public_data(value: Variant) -> bool:
	if value == null or value is bool or value is int or value is float or value is String or value is StringName:
		return true
	if value is Array:
		for child in value:
			if not _is_public_data(child):
				return false
		return true
	if value is Dictionary:
		for key_variant in value.keys():
			if not _is_public_data(key_variant) or not _is_public_data(value[key_variant]):
				return false
		return true
	return false
