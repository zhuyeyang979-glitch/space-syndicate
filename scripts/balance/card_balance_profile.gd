extends RefCounted
class_name CardBalanceProfile


static func normalize_card(card_data: Dictionary) -> Dictionary:
	var normalized := card_data.duplicate(true)
	normalized["card_id"] = str(card_data.get("card_id", card_data.get("id", "")))
	normalized["name"] = str(card_data.get("name", normalized.get("card_id", "")))
	normalized["type"] = str(card_data.get("type", "经济"))
	normalized["rank"] = str(card_data.get("rank", "I"))
	normalized["current_price"] = int(card_data.get("current_price", card_data.get("price", 0)))
	normalized["complexity_score"] = int(card_data.get("complexity_score", 1))
	normalized["scenario_tags"] = card_data.get("scenario_tags", [])
	return normalized


static func impact_score(card_data: Dictionary) -> int:
	return int(card_data.get("effect_power", 0)) \
		+ int(card_data.get("economy_scaling_premium", 0)) \
		+ int(card_data.get("monster_impact_score", card_data.get("interaction_premium", 0)))


static func onboarding_difficulty(card_data: Dictionary) -> String:
	var complexity := int(card_data.get("complexity_score", 1))
	if complexity <= 2:
		return "easy"
	if complexity <= 4:
		return "medium"
	return "hard"
