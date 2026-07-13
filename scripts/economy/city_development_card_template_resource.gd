extends Resource
class_name CityDevelopmentCardTemplateResource

@export var template_id := "production"
@export var card_name_pattern := "%s生产城%d"
@export_enum("production", "demand", "commerce") var project_direction := "production"
@export var purchase_price := 3
@export var contribution_units := 1
@export var allowed_terrains: PackedStringArray = ["land"]
@export_multiline var effect_pattern := "在目标区域建立或强化%s生产项目，并获得项目贡献份额。"


func make_definition(product_id: String, rank: int = 1) -> Dictionary:
	var safe_rank := clampi(rank, 1, 4)
	var card_name := card_name_pattern % [product_id, safe_rank]
	return {
		"name": card_name,
		"cost": maxi(1, purchase_price + (safe_rank - 1) * 2),
		"kind": "city_development",
		"rank": safe_rank,
		"product_id": product_id,
		"project_direction": project_direction,
		"contribution_units": maxi(1, contribution_units * safe_rank),
		"allowed_terrains": Array(allowed_terrains),
		"play_flow_required": 0,
		"damage": 0,
		"move": 0.0,
		"range": 0.0,
		"tags": ["城市发展", _direction_label(project_direction), product_id],
		"use_case": "建立%s%s项目并取得隐藏贡献份额。" % [product_id, _direction_label(project_direction)],
		"text": effect_pattern % product_id,
	}


func _direction_label(direction: String) -> String:
	match direction:
		"demand":
			return "需求"
		"commerce":
			return "通商"
	return "生产"
