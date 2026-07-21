extends RefCounted
class_name ForcedDecisionResponseOptionPolicy


static func validation_report(decision_kind: StringName, decision_id: String, option_id: String) -> Dictionary:
	match decision_kind:
		&"monster_wager":
			return _monster_wager_option(decision_id, option_id)
		&"counter_response":
			return _counter_option(option_id)
		&"discard_purchase":
			return _indexed_or_cancel(option_id, "discard_purchase_", "discard_purchase_cancel")
		&"monster_target_choice":
			return _positive_uid_or_cancel(option_id, "target_monster_uid_", "target_monster_cancel")
		&"player_target_choice":
			return _indexed_or_cancel(option_id, "target_player_", "target_player_cancel")
		&"public_bid":
			return _public_bid_option(option_id)
	return _invalid("decision_kind_invalid")


static func _monster_wager_option(decision_id: String, option_id: String) -> Dictionary:
	var decision_parts := decision_id.split("_", false)
	var option_parts := option_id.split(":", false)
	if decision_parts.size() != 3 or not String(decision_parts[2]).is_valid_int():
		return _invalid("decision_id_invalid")
	var side := String(option_parts[2]).to_lower() if option_parts.size() >= 3 else ""
	if option_parts.size() != 4 or option_parts[0] != "monster_wager" \
			or not String(option_parts[1]).is_valid_int() or String(option_parts[1]) != String(decision_parts[2]) \
			or side.length() != 1 or side < "a" or side > "h" or not String(option_parts[3]).is_valid_int() \
			or int(option_parts[3]) <= 0 or int(option_parts[3]) > 100:
		return _invalid("option_not_available")
	return _valid()


static func _counter_option(option_id: String) -> Dictionary:
	if option_id == "counter_pass":
		return _valid()
	if option_id.begins_with("counter_play_") and option_id.trim_prefix("counter_play_").is_valid_int() and int(option_id.trim_prefix("counter_play_")) >= 0:
		return _valid()
	return _invalid("option_not_available")


static func _indexed_or_cancel(option_id: String, prefix: String, cancel_id: String) -> Dictionary:
	if option_id == cancel_id:
		return _valid()
	var index_text := option_id.trim_prefix(prefix)
	if option_id.begins_with(prefix) and index_text.is_valid_int() and int(index_text) >= 0:
		return _valid()
	return _invalid("option_not_available")


static func _positive_uid_or_cancel(option_id: String, prefix: String, cancel_id: String) -> Dictionary:
	if option_id == cancel_id:
		return _valid()
	var uid_text := option_id.trim_prefix(prefix)
	if option_id.begins_with(prefix) and uid_text.is_valid_int() and int(uid_text) > 0:
		return _valid()
	return _invalid("option_not_available")


static func _public_bid_option(option_id: String) -> Dictionary:
	if option_id == "card_group_ready":
		return _valid()
	for prefix in ["group_order_up_", "group_order_down_"]:
		var resolution_text := option_id.trim_prefix(prefix)
		if option_id.begins_with(prefix) and resolution_text.is_valid_int() and int(resolution_text) >= 0:
			return _valid()
	return _invalid("option_not_available")


static func _valid() -> Dictionary:
	return {"valid": true, "reason_code": ""}


static func _invalid(reason_code: String) -> Dictionary:
	return {"valid": false, "reason_code": reason_code}
