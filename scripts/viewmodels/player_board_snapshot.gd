extends RefCounted
class_name PlayerBoardSnapshot

var title: String = ""
var hint: String = ""
var cash_text: String = ""
var gdp_text: String = ""
var goal_ratio: float = 0.0
var hand_cards: Array = []
var primary_actions: Array = []


func apply_dictionary(data: Dictionary) -> RefCounted:
	title = str(data.get("title", "玩家板｜手牌"))
	hint = str(data.get("hint", "选择一张手牌后，右侧详情会显示主操作。"))
	cash_text = str(data.get("cash_text", data.get("cash", "")))
	gdp_text = str(data.get("gdp_text", data.get("gdp", "")))
	goal_ratio = clampf(float(data.get("goal_ratio", 0.0)), 0.0, 1.0)
	hand_cards = data.get("hand_cards", []) if data.get("hand_cards", []) is Array else []
	primary_actions = data.get("actions", []) if data.get("actions", []) is Array else []
	return self


func to_ui_dictionary() -> Dictionary:
	return {
		"title": title,
		"hint": hint,
		"cash_text": cash_text,
		"gdp_text": gdp_text,
		"goal_ratio": goal_ratio,
		"hand_cards": hand_cards,
		"actions": primary_actions,
	}
