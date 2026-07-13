extends Resource
class_name ProductIndustryDefinitionResource

@export var industry_id: String = ""
@export var display_name: String = ""
@export var icon_key: String = ""
@export var color_key: String = ""
@export_multiline var gameplay_summary: String = ""
@export var capacity_thresholds: Array[int] = [15, 40, 80, 140]


func to_snapshot() -> Dictionary:
	return {
		"industry_id": industry_id,
		"display_name": display_name,
		"icon_key": icon_key,
		"color_key": color_key,
		"gameplay_summary": gameplay_summary,
		"capacity_thresholds": capacity_thresholds.duplicate(),
	}
