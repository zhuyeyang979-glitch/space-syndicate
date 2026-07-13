@tool
extends Resource
class_name CityGdpDerivativeTermsCatalogResource

@export var catalog_id := "city_gdp_derivative_terms_v04"
@export var display_name := "City GDP Derivative Terms v0.4"
@export_multiline var design_note := "Single Inspector-editable source for city longs, city shorts, and disaster insurance cards."
@export var term_resources: Array[Resource] = []


func terms_for_card_id(card_id: String) -> Dictionary:
	for term_resource in term_resources:
		if term_resource == null or not term_resource.has_method("to_runtime_dictionary"):
			continue
		var payload: Dictionary = term_resource.call("to_runtime_dictionary")
		if str(payload.get("card_id", "")) == card_id:
			return payload.duplicate(true)
	return {}


func all_terms() -> Array:
	var result: Array = []
	for term_resource in term_resources:
		if term_resource != null and term_resource.has_method("to_runtime_dictionary"):
			result.append((term_resource.call("to_runtime_dictionary") as Dictionary).duplicate(true))
	return result


func enrich_skill(card_id: String, skill: Dictionary) -> Dictionary:
	var result := skill.duplicate(true)
	if str(result.get("kind", "")) != "city_gdp_derivative":
		return result
	var terms := terms_for_card_id(card_id)
	if terms.is_empty():
		result["gdp_derivative_terms_error"] = "terms_missing"
		return result
	result["gdp_derivative_terms"] = terms
	return result


func validation_report() -> Dictionary:
	var issues: Array = []
	var card_ids: Array[String] = []
	for term_resource in term_resources:
		if term_resource == null or not term_resource.has_method("to_runtime_dictionary"):
			issues.append("invalid_resource")
			continue
		var payload: Dictionary = term_resource.call("to_runtime_dictionary")
		var card_id := str(payload.get("card_id", ""))
		if card_id == "" or card_ids.has(card_id): issues.append("duplicate_or_missing:%s" % card_id)
		else: card_ids.append(card_id)
		if term_resource.has_method("validation_issues"):
			for issue in term_resource.call("validation_issues"):
				issues.append("%s:%s" % [card_id, str(issue)])
	return {
		"catalog_id": catalog_id,
		"card_count": card_ids.size(),
		"card_ids": card_ids,
		"valid": issues.is_empty() and card_ids.size() == 12,
		"issues": issues,
	}


func debug_snapshot() -> Dictionary:
	var result := validation_report()
	result["terms"] = all_terms()
	return result
