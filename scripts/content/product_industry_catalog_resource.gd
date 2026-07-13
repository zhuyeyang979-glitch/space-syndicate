extends Resource
class_name ProductIndustryCatalogResource

@export var schema_version: String = "v0.5"
@export var industries: Array[ProductIndustryDefinitionResource] = []
@export var products: Array[ProductIndustryEntryResource] = []


func industry_ids() -> Array[String]:
	var result: Array[String] = []
	for definition in industries:
		if definition != null:
			result.append(definition.industry_id)
	return result


func product_ids() -> Array[String]:
	var result: Array[String] = []
	for entry in products:
		if entry != null:
			result.append(entry.product_id)
	return result


func industry_for_product(product_id: String) -> String:
	for entry in products:
		if entry != null and entry.product_id == product_id:
			return entry.industry_id
	return ""


func product_snapshot(product_id: String) -> Dictionary:
	for entry in products:
		if entry != null and entry.product_id == product_id:
			return entry.to_snapshot()
	return {}


func validation_snapshot(expected_product_ids: Array = []) -> Dictionary:
	var errors: Array[String] = []
	var known_industries: Dictionary = {}
	var duplicate_industries: Array[String] = []
	for definition in industries:
		if definition == null or definition.industry_id.is_empty():
			errors.append("industry_definition_missing_id")
			continue
		if known_industries.has(definition.industry_id):
			duplicate_industries.append(definition.industry_id)
		else:
			known_industries[definition.industry_id] = true
		if definition.display_name.is_empty() or definition.icon_key.is_empty() or definition.color_key.is_empty():
			errors.append("industry_metadata_incomplete:%s" % definition.industry_id)
		if definition.capacity_thresholds != [15, 40, 80, 140]:
			errors.append("industry_thresholds_invalid:%s" % definition.industry_id)
	var seen_products: Dictionary = {}
	var duplicate_products: Array[String] = []
	var unknown_industry_products: Array[String] = []
	for entry in products:
		if entry == null or entry.product_id.is_empty():
			errors.append("product_entry_missing_id")
			continue
		if seen_products.has(entry.product_id):
			duplicate_products.append(entry.product_id)
		else:
			seen_products[entry.product_id] = entry.industry_id
		if not known_industries.has(entry.industry_id):
			unknown_industry_products.append(entry.product_id)
		if entry.display_name.is_empty() or entry.icon_key.is_empty():
			errors.append("product_metadata_incomplete:%s" % entry.product_id)
	var missing_products: Array[String] = []
	var unexpected_products: Array[String] = []
	for expected_variant in expected_product_ids:
		var expected_id := str(expected_variant)
		if not seen_products.has(expected_id):
			missing_products.append(expected_id)
	for product_id_variant in seen_products.keys():
		var product_id := str(product_id_variant)
		if not expected_product_ids.is_empty() and not expected_product_ids.has(product_id):
			unexpected_products.append(product_id)
	if not duplicate_industries.is_empty():
		errors.append("duplicate_industries")
	if not duplicate_products.is_empty():
		errors.append("duplicate_products")
	if not unknown_industry_products.is_empty():
		errors.append("unknown_industry_products")
	if not missing_products.is_empty():
		errors.append("missing_products")
	if not unexpected_products.is_empty():
		errors.append("unexpected_products")
	return {
		"valid": errors.is_empty(),
		"schema_version": schema_version,
		"industry_count": known_industries.size(),
		"product_count": seen_products.size(),
		"industry_ids": industry_ids(),
		"duplicate_industries": duplicate_industries,
		"duplicate_products": duplicate_products,
		"unknown_industry_products": unknown_industry_products,
		"missing_products": missing_products,
		"unexpected_products": unexpected_products,
		"errors": errors,
	}


func debug_snapshot() -> Dictionary:
	var industry_snapshots: Array[Dictionary] = []
	for definition in industries:
		if definition != null:
			industry_snapshots.append(definition.to_snapshot())
	var product_snapshots: Array[Dictionary] = []
	for entry in products:
		if entry != null:
			product_snapshots.append(entry.to_snapshot())
	return {
		"schema_version": schema_version,
		"industries": industry_snapshots,
		"products": product_snapshots,
	}
