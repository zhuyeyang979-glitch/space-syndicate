extends RefCounted
class_name CardViewSnapshot

var id: String = ""
var name: String = ""
var rank: String = ""
var card_type: String = ""
var cost_text: String = ""
var target_text: String = ""
var effect_text: String = ""
var chips: Array = []


func apply_dictionary(data: Dictionary) -> RefCounted:
	id = str(data.get("id", data.get("card_id", "")))
	name = str(data.get("name", "未命名卡牌"))
	rank = str(data.get("rank", data.get("level", "")))
	card_type = str(data.get("type", data.get("category", "")))
	cost_text = str(data.get("cost", data.get("price", data.get("play_cost", ""))))
	target_text = str(data.get("target", data.get("target_type", "")))
	effect_text = str(data.get("effect", data.get("description", "")))
	chips = data.get("chips", []) if data.get("chips", []) is Array else []
	return self


func to_ui_dictionary() -> Dictionary:
	return {
		"id": id,
		"name": name,
		"rank": rank,
		"type": card_type,
		"cost": cost_text,
		"target": target_text,
		"effect": effect_text,
		"chips": chips,
	}
