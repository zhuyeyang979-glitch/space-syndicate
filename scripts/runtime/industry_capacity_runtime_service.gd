extends Node
class_name IndustryCapacityRuntimeService

const REQUIRED_INDUSTRY_IDS := ["life", "energy", "industry", "technology", "commerce", "shipping"]

@export var ruleset_profile: Resource
@export var product_industry_catalog: Resource

var _derive_count := 0
var _last_snapshot: Dictionary = {}


func configure(profile: Resource = ruleset_profile, catalog: Resource = product_industry_catalog) -> Dictionary:
	ruleset_profile = profile
	product_industry_catalog = catalog
	var validation := _configuration_validation()
	if not bool(validation.get("valid", false)):
		push_error("IndustryCapacityRuntimeService configuration failed: %s" % str(validation.get("errors", [])))
	return validation


func derive_player_capacity(player_index: int, project_rows: Array) -> Dictionary:
	var configuration := _configuration_validation()
	if not bool(configuration.get("valid", false)):
		return {
			"valid": false,
			"reason": "industry_capacity_configuration_invalid",
			"errors": configuration.get("errors", []).duplicate(true),
			"player_index": player_index,
			"industries": {},
			"products": {},
		}
	var gdp_by_industry := _empty_industry_values()
	var gdp_by_product := {}
	var industry_by_product := {}
	var normalized_rows: Array = []
	var errors: Array = []
	for row_variant in project_rows:
		if not (row_variant is Dictionary):
			errors.append("project_row_not_dictionary")
			continue
		var row := row_variant as Dictionary
		var product_id := str(row.get("product_id", ""))
		if product_id.is_empty():
			errors.append("project_product_missing")
			continue
		var catalog_industry_id := str(product_industry_catalog.call("industry_for_product", product_id))
		if catalog_industry_id.is_empty():
			errors.append("unknown_product:%s" % product_id)
			continue
		var supplied_industry_id := str(row.get("industry_id", ""))
		if not supplied_industry_id.is_empty() and supplied_industry_id != catalog_industry_id:
			errors.append("industry_mismatch:%s" % product_id)
			continue
		var attributable_gdp := maxi(0, int(row.get("attributable_gdp_per_minute", row.get("own_gdp_per_minute", 0))))
		gdp_by_industry[catalog_industry_id] = int(gdp_by_industry.get(catalog_industry_id, 0)) + attributable_gdp
		gdp_by_product[product_id] = int(gdp_by_product.get(product_id, 0)) + attributable_gdp
		industry_by_product[product_id] = catalog_industry_id
		normalized_rows.append({
			"district_index": int(row.get("district_index", -1)),
			"project_id": str(row.get("project_id", "")),
			"slot_id": str(row.get("slot_id", "")),
			"generation": maxi(0, int(row.get("generation", 0))),
			"product_id": product_id,
			"industry_id": catalog_industry_id,
			"attributable_gdp_per_minute": attributable_gdp,
		})
	normalized_rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var district_a := int(a.get("district_index", -1))
		var district_b := int(b.get("district_index", -1))
		if district_a != district_b:
			return district_a < district_b
		return str(a.get("project_id", "")) < str(b.get("project_id", ""))
	)
	var industries := {}
	for industry_id_variant in REQUIRED_INDUSTRY_IDS:
		var industry_id := str(industry_id_variant)
		var attributable_gdp := int(gdp_by_industry.get(industry_id, 0))
		industries[industry_id] = {
			"industry_id": industry_id,
			"attributable_gdp_per_minute": attributable_gdp,
			"total_capacity": capacity_for_gdp(attributable_gdp),
		}
	var snapshot := {
		"valid": errors.is_empty(),
		"reason": "" if errors.is_empty() else "industry_capacity_rows_invalid",
		"errors": errors,
		"ruleset_id": str(ruleset_profile.get("ruleset_id")),
		"player_index": player_index,
		"industries": industries,
		"products": gdp_by_product,
		"product_industries": industry_by_product,
		"project_rows": normalized_rows,
	}
	snapshot["capacity_revision"] = JSON.stringify(snapshot).sha256_text()
	_derive_count += 1
	_last_snapshot = snapshot.duplicate(true)
	return snapshot


func capacity_for_gdp(attributable_gdp_per_minute: int) -> int:
	if ruleset_profile == null:
		return 0
	var thresholds_variant: Variant = ruleset_profile.get("industry_capacity_thresholds")
	var thresholds: Array = thresholds_variant if thresholds_variant is Array else []
	var capacity := 0
	for threshold_variant in thresholds:
		if attributable_gdp_per_minute >= int(threshold_variant):
			capacity += 1
	return capacity


func availability_snapshot(capacity_snapshot: Dictionary, reserved_by_industry: Dictionary) -> Dictionary:
	var result := {}
	var industries: Dictionary = capacity_snapshot.get("industries", {}) if capacity_snapshot.get("industries", {}) is Dictionary else {}
	for industry_id_variant in REQUIRED_INDUSTRY_IDS:
		var industry_id := str(industry_id_variant)
		var industry_row: Dictionary = industries.get(industry_id, {}) if industries.get(industry_id, {}) is Dictionary else {}
		var total := maxi(0, int(industry_row.get("total_capacity", 0)))
		var reserved := maxi(0, int(reserved_by_industry.get(industry_id, 0)))
		result[industry_id] = {
			"industry_id": industry_id,
			"attributable_gdp_per_minute": maxi(0, int(industry_row.get("attributable_gdp_per_minute", 0))),
			"total_capacity": total,
			"reserved_capacity": reserved,
			"available_capacity": maxi(0, total - reserved),
		}
	return {
		"valid": bool(capacity_snapshot.get("valid", false)),
		"player_index": int(capacity_snapshot.get("player_index", -1)),
		"capacity_revision": str(capacity_snapshot.get("capacity_revision", "")),
		"industries": result,
		"products": (capacity_snapshot.get("products", {}) as Dictionary).duplicate(true) if capacity_snapshot.get("products", {}) is Dictionary else {},
		"product_industries": (capacity_snapshot.get("product_industries", {}) as Dictionary).duplicate(true) if capacity_snapshot.get("product_industries", {}) is Dictionary else {},
	}


func debug_snapshot() -> Dictionary:
	var configuration := _configuration_validation()
	return {
		"service_ready": bool(configuration.get("valid", false)),
		"service_authoritative": bool(configuration.get("valid", false)),
		"runtime_owner": "IndustryCapacityRuntimeService",
		"ruleset_id": str(ruleset_profile.get("ruleset_id")) if ruleset_profile != null else "",
		"industry_ids": REQUIRED_INDUSTRY_IDS.duplicate(),
		"capacity_thresholds": (ruleset_profile.get("industry_capacity_thresholds") as Array).duplicate() if ruleset_profile != null and ruleset_profile.get("industry_capacity_thresholds") is Array else [],
		"derive_count": _derive_count,
		"last_snapshot": _last_snapshot.duplicate(true),
	}


func _configuration_validation() -> Dictionary:
	var errors: Array = []
	if ruleset_profile == null:
		errors.append("ruleset_profile_missing")
	elif str(ruleset_profile.get("ruleset_id")) != "v0.5":
		errors.append("ruleset_profile_not_v05")
	elif ruleset_profile.get("industry_capacity_thresholds") != [15, 40, 80, 140]:
		errors.append("capacity_thresholds_invalid")
	if product_industry_catalog == null:
		errors.append("product_industry_catalog_missing")
	elif not product_industry_catalog.has_method("industry_for_product"):
		errors.append("product_industry_catalog_api_missing")
	else:
		var ids_variant: Variant = product_industry_catalog.call("industry_ids")
		var ids: Array = ids_variant if ids_variant is Array else []
		for industry_id_variant in REQUIRED_INDUSTRY_IDS:
			if not ids.has(str(industry_id_variant)):
				errors.append("industry_missing:%s" % str(industry_id_variant))
	return {"valid": errors.is_empty(), "errors": errors}


func _empty_industry_values() -> Dictionary:
	var result := {}
	for industry_id_variant in REQUIRED_INDUSTRY_IDS:
		result[str(industry_id_variant)] = 0
	return result
