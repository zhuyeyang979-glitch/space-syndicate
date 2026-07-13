@tool
extends Resource
class_name CardPriceCurveParametersResource

@export var source_json_path := "res://data/balance/price_curve_v1.json"
@export var source_script_path := "res://scripts/balance/card_price_curve.gd"

@export_group("Base Price")
@export var base_by_type: Dictionary = {
	"经济": 60,
	"怪兽": 80,
	"情报": 55,
	"军队": 70,
	"合约": 65,
	"商路": 58,
	"天气": 62,
	"互动": 66,
}
@export var rank_step: Dictionary = {
	"I": 0,
	"II": 45,
	"III": 95,
	"IV": 160,
}

@export_group("Weights")
@export var effect_power := 8
@export var targeting_premium := 12
@export var hidden_info_premium := 10
@export var economy_scaling_premium := 9
@export var interaction_premium := 8
@export var setup_requirement_discount := 9
@export var delayed_effect_discount := 7
@export var self_risk_discount := 8


func weights_dictionary() -> Dictionary:
	return {
		"effect_power": effect_power,
		"targeting_premium": targeting_premium,
		"hidden_info_premium": hidden_info_premium,
		"economy_scaling_premium": economy_scaling_premium,
		"interaction_premium": interaction_premium,
		"setup_requirement_discount": setup_requirement_discount,
		"delayed_effect_discount": delayed_effect_discount,
		"self_risk_discount": self_risk_discount,
	}


func to_price_curve_dictionary() -> Dictionary:
	return {
		"base_by_type": base_by_type.duplicate(true),
		"rank_step": rank_step.duplicate(true),
		"weights": weights_dictionary(),
	}


func validate_profile() -> Array:
	var records: Array = []
	records.append(_validation_record("price_curve_types", base_by_type.size() >= 8, "base price table covers the current public card type families"))
	records.append(_validation_record("price_curve_ranks", rank_step.has("I") and rank_step.has("IV"), "rank step exposes I-IV values"))
	records.append(_validation_record("price_curve_weights", weights_dictionary().size() == 8, "all eight price weight fields are inspectable"))
	return records


func _validation_record(id: String, passed: bool, notes: String) -> Dictionary:
	return {
		"id": id,
		"passed": passed,
		"notes": notes,
	}
