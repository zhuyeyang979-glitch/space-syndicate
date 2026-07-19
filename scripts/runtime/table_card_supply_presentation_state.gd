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


func _is_valid_snapshot(value: Dictionary) -> bool:
	return (
		value.get("selected_market_skill", "") is String
		and value.get("previewed_district_card", "") is String
		and value.get("open_district", -1) is int
		and value.get("open_player", -1) is int
	)
