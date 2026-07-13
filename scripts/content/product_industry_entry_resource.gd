extends Resource
class_name ProductIndustryEntryResource

@export var product_id: String = ""
@export var industry_id: String = ""
@export var display_name: String = ""
@export var icon_key: String = ""
@export var optional_tags: Array[String] = []


func to_snapshot() -> Dictionary:
	return {
		"product_id": product_id,
		"industry_id": industry_id,
		"display_name": display_name,
		"icon_key": icon_key,
		"optional_tags": optional_tags.duplicate(),
	}
