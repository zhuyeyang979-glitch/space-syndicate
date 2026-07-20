extends Node
class_name TableCardSupplyPresentationState

var selected_market_skill := ""
var previewed_district_card := ""
var open_district := -1
var open_player := -1


func snapshot() -> Dictionary:
	return {
		"selected_market_skill": selected_market_skill,
		"previewed_district_card": previewed_district_card,
		"open_district": open_district,
		"open_player": open_player,
	}


func capture_new_session_checkpoint() -> Dictionary:
	return snapshot()


func restore_new_session_checkpoint(checkpoint: Dictionary) -> Dictionary:
	if not _is_valid_snapshot(checkpoint):
		return {"restored": false, "reason_code": "card_supply_presentation_checkpoint_invalid"}
	selected_market_skill = str(checkpoint.get("selected_market_skill", ""))
	previewed_district_card = str(checkpoint.get("previewed_district_card", ""))
	open_district = int(checkpoint.get("open_district", -1))
	open_player = int(checkpoint.get("open_player", -1))
	return {"restored": true, "reason_code": "card_supply_presentation_checkpoint_restored"}


func reset_for_committed_session() -> void:
	selected_market_skill = ""
	previewed_district_card = ""
	open_district = -1
	open_player = -1


func reconcile_district_card_choices(card_ids: Array) -> Dictionary:
	var normalized: Array[String] = []
	for card_id_variant in card_ids:
		var card_id := str(card_id_variant).strip_edges()
		if card_id.is_empty() or normalized.has(card_id):
			continue
		normalized.append(card_id)
	var previous_selected := selected_market_skill
	var previous_previewed := previewed_district_card
	if normalized.is_empty():
		selected_market_skill = ""
		previewed_district_card = ""
	else:
		if not normalized.has(selected_market_skill):
			selected_market_skill = normalized[0]
		if not normalized.has(previewed_district_card):
			previewed_district_card = selected_market_skill
	return {
		"changed": previous_selected != selected_market_skill or previous_previewed != previewed_district_card,
		"selected_market_skill": selected_market_skill,
		"previewed_district_card": previewed_district_card,
		"choice_count": normalized.size(),
	}


func _is_valid_snapshot(value: Dictionary) -> bool:
	return (
		value.get("selected_market_skill", "") is String
		and value.get("previewed_district_card", "") is String
		and value.get("open_district", -1) is int
		and value.get("open_player", -1) is int
	)
