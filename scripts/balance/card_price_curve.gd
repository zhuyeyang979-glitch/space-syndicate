extends RefCounted
class_name CardPriceCurve

const DEFAULT_CURVE_PATH := "res://data/balance/price_curve_v1.json"

var curve: Dictionary = {}


func load_default() -> void:
	load_from_file(DEFAULT_CURVE_PATH)


func load_from_file(path: String) -> bool:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary):
		return false
	curve = parsed as Dictionary
	return true


func suggested_price(card_data: Dictionary) -> int:
	if curve.is_empty():
		load_default()
	var base_by_type: Dictionary = curve.get("base_by_type", {})
	var rank_step: Dictionary = curve.get("rank_step", {})
	var weights: Dictionary = curve.get("weights", {})
	var card_type := str(card_data.get("type", "经济"))
	var rank := str(card_data.get("rank", "I"))
	var value := int(base_by_type.get(card_type, 60)) + int(rank_step.get(rank, 0))
	value += int(card_data.get("effect_power", 0)) * int(weights.get("effect_power", 8))
	value += int(card_data.get("targeting_premium", 0)) * int(weights.get("targeting_premium", 12))
	value += int(card_data.get("hidden_info_premium", 0)) * int(weights.get("hidden_info_premium", 10))
	value += int(card_data.get("economy_scaling_premium", 0)) * int(weights.get("economy_scaling_premium", 9))
	value += int(card_data.get("interaction_premium", 0)) * int(weights.get("interaction_premium", 8))
	value -= int(card_data.get("setup_requirement_discount", 0)) * int(weights.get("setup_requirement_discount", 9))
	value -= int(card_data.get("delayed_effect_discount", 0)) * int(weights.get("delayed_effect_discount", 7))
	value -= int(card_data.get("self_risk_discount", 0)) * int(weights.get("self_risk_discount", 8))
	return maxi(10, int(round(float(value) / 5.0) * 5))
