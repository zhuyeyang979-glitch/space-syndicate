extends Resource
class_name CardPlayRequirementV05Resource

const KIND_COLORLESS := "colorless"
const KIND_SINGLE_INDUSTRY := "single_industry"
const KIND_DUAL_INDUSTRY := "dual_industry"
const KIND_EITHER_INDUSTRY := "either_industry"
const KIND_NAMED_PRODUCT := "named_product"

@export_enum("colorless", "single_industry", "dual_industry", "either_industry", "named_product") var requirement_kind: String = KIND_COLORLESS
@export var industry_ids: Array[String] = []
@export_range(0, 4, 1) var required_capacity: int = 0
@export var product_id: String = ""
@export var required_product_gdp: int = 0
@export var region_scope: String = "none"
@export_range(0, 10000, 1) var required_influence_bp: int = 0


func to_snapshot() -> Dictionary:
	return {
		"requirement_kind": requirement_kind,
		"industry_ids": industry_ids.duplicate(),
		"required_capacity": required_capacity,
		"product_id": product_id,
		"required_product_gdp": required_product_gdp,
		"region_scope": region_scope,
		"required_influence_bp": required_influence_bp,
	}
