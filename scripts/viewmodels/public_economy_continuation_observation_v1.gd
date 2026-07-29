extends RefCounted
class_name PublicEconomyContinuationObservationV1

const SCHEMA_VERSION := 1
const TOP_LEVEL_KEYS := [
	"schema_version",
	"source_revision",
	"visibility_scope",
	"commodity_rows",
	"facility_rows",
	"public_progress",
]
const COMMODITY_KEYS := [
	"commodity_id",
	"industry_id",
	"public_production_capacity",
	"public_demand_capacity",
	"public_settled_units",
	"public_transport_units",
	"public_waste_units",
]
const FACILITY_KEYS := [
	"facility_instance_id",
	"facility_kind",
	"commodity_id",
	"industry_id",
	"region_id",
	"direction",
	"base_units_per_minute",
	"active",
]
const PROGRESS_KEYS := [
	"top_k_gdp",
	"required_top_k_gdp",
	"controlled_regions",
	"required_regions",
	"eligible",
	"victory_state",
]


static func normalize(source: Dictionary) -> Dictionary:
	if not _has_exact_keys(source, TOP_LEVEL_KEYS) \
			or typeof(source.get("schema_version")) != TYPE_INT \
			or int(source.get("schema_version", 0)) != SCHEMA_VERSION \
			or typeof(source.get("source_revision")) != TYPE_INT \
			or int(source.get("source_revision", -1)) < 0 \
			or not _is_string(source.get("visibility_scope")) \
			or str(source.get("visibility_scope", "")) != "viewer_safe_aggregate" \
			or not (source.get("commodity_rows") is Array) \
			or not (source.get("facility_rows") is Array) \
			or not (source.get("public_progress") is Dictionary):
		return {}
	var commodity_rows: Variant = _normalize_commodity_rows(source.get("commodity_rows", []) as Array)
	var facility_rows: Variant = _normalize_facility_rows(source.get("facility_rows", []) as Array)
	var progress := _normalize_progress(source.get("public_progress", {}) as Dictionary)
	if commodity_rows == null or facility_rows == null or progress.is_empty() \
			or not _rows_are_consistent(commodity_rows as Array, facility_rows as Array):
		return {}
	return {
		"schema_version": SCHEMA_VERSION,
		"source_revision": int(source.get("source_revision", 0)),
		"visibility_scope": "viewer_safe_aggregate",
		"commodity_rows": commodity_rows,
		"facility_rows": facility_rows,
		"public_progress": progress,
	}


static func is_valid(value: Variant) -> bool:
	return value is Dictionary and not normalize(value as Dictionary).is_empty()


static func detached_copy(value: Variant) -> Dictionary:
	return normalize(value as Dictionary).duplicate(true) if value is Dictionary else {}


static func fingerprint(value: Variant) -> String:
	var normalized := detached_copy(value)
	return JSON.stringify(normalized).sha256_text() if not normalized.is_empty() else ""


static func _normalize_commodity_rows(rows: Array) -> Variant:
	var result: Array = []
	var seen := {}
	for row_variant in rows:
		if not (row_variant is Dictionary):
			return null
		var row := row_variant as Dictionary
		if not _has_exact_keys(row, COMMODITY_KEYS):
			return null
		if not _is_string(row.get("commodity_id")) or not _is_string(row.get("industry_id")):
			return null
		var commodity_id := str(row.get("commodity_id", "")).strip_edges()
		var industry_id := str(row.get("industry_id", "")).strip_edges()
		if commodity_id.is_empty() or industry_id.is_empty() or seen.has(commodity_id):
			return null
		for field in [
			"public_production_capacity",
			"public_demand_capacity",
			"public_settled_units",
			"public_transport_units",
			"public_waste_units",
		]:
			if not _is_nonnegative_number(row.get(field)):
				return null
		seen[commodity_id] = true
		result.append({
			"commodity_id": commodity_id,
			"industry_id": industry_id,
			"public_production_capacity": maxf(0.0, float(row.get("public_production_capacity", 0.0))),
			"public_demand_capacity": maxf(0.0, float(row.get("public_demand_capacity", 0.0))),
			"public_settled_units": maxf(0.0, float(row.get("public_settled_units", 0.0))),
			"public_transport_units": maxf(0.0, float(row.get("public_transport_units", 0.0))),
			"public_waste_units": maxf(0.0, float(row.get("public_waste_units", 0.0))),
		})
	result.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return str(left.get("commodity_id", "")) < str(right.get("commodity_id", ""))
	)
	return result


static func _normalize_facility_rows(rows: Array) -> Variant:
	var result: Array = []
	var seen := {}
	for row_variant in rows:
		if not (row_variant is Dictionary):
			return null
		var row := row_variant as Dictionary
		if not _has_exact_keys(row, FACILITY_KEYS):
			return null
		for field in [
			"facility_instance_id",
			"facility_kind",
			"commodity_id",
			"industry_id",
			"region_id",
			"direction",
		]:
			if not _is_string(row.get(field)):
				return null
		var facility_id := str(row.get("facility_instance_id", "")).strip_edges()
		var facility_kind := str(row.get("facility_kind", "")).strip_edges()
		var direction := str(row.get("direction", "")).strip_edges()
		if facility_id.is_empty() or seen.has(facility_id) \
				or facility_kind not in ["factory", "market"] \
				or direction not in ["production", "demand"] \
				or facility_kind != ("factory" if direction == "production" else "market") \
				or str(row.get("commodity_id", "")).strip_edges().is_empty() \
				or str(row.get("industry_id", "")).strip_edges().is_empty() \
				or str(row.get("region_id", "")).strip_edges().is_empty() \
				or not _is_nonnegative_number(row.get("base_units_per_minute")) \
				or not (row.get("active") is bool):
			return null
		seen[facility_id] = true
		result.append({
			"facility_instance_id": facility_id,
			"facility_kind": facility_kind,
			"commodity_id": str(row.get("commodity_id", "")).strip_edges(),
			"industry_id": str(row.get("industry_id", "")).strip_edges(),
			"region_id": str(row.get("region_id", "")).strip_edges(),
			"direction": direction,
			"base_units_per_minute": maxf(0.0, float(row.get("base_units_per_minute", 0.0))),
			"active": bool(row.get("active", false)),
		})
	result.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return str(left.get("facility_instance_id", "")) < str(right.get("facility_instance_id", ""))
	)
	return result


static func _normalize_progress(source: Dictionary) -> Dictionary:
	if not _has_exact_keys(source, PROGRESS_KEYS):
		return {}
	for field in ["top_k_gdp", "required_top_k_gdp", "controlled_regions", "required_regions"]:
		if typeof(source.get(field)) != TYPE_INT or int(source.get(field, -1)) < 0:
			return {}
	if not (source.get("eligible") is bool):
		return {}
	if not _is_string(source.get("victory_state")):
		return {}
	var victory_state := str(source.get("victory_state", ""))
	if victory_state not in ["idle", "qualification", "audit", "cooldown", "resolved"]:
		return {}
	return {
		"top_k_gdp": int(source.get("top_k_gdp", 0)),
		"required_top_k_gdp": int(source.get("required_top_k_gdp", 0)),
		"controlled_regions": int(source.get("controlled_regions", 0)),
		"required_regions": int(source.get("required_regions", 0)),
		"eligible": bool(source.get("eligible", false)),
		"victory_state": victory_state,
	}


static func _has_exact_keys(value: Dictionary, expected: Array) -> bool:
	if value.size() != expected.size():
		return false
	for key_variant in expected:
		if not value.has(key_variant):
			return false
	return true


static func _rows_are_consistent(commodity_rows: Array, facility_rows: Array) -> bool:
	var industry_by_commodity := {}
	for row_variant in commodity_rows:
		var row := row_variant as Dictionary
		industry_by_commodity[str(row.get("commodity_id", ""))] = str(row.get("industry_id", ""))
	for row_variant in facility_rows:
		var row := row_variant as Dictionary
		var commodity_id := str(row.get("commodity_id", ""))
		if not industry_by_commodity.has(commodity_id) \
				or str(industry_by_commodity.get(commodity_id, "")) != str(row.get("industry_id", "")):
			return false
	return true


static func _is_string(value: Variant) -> bool:
	return typeof(value) in [TYPE_STRING, TYPE_STRING_NAME]


static func _is_nonnegative_number(value: Variant) -> bool:
	return (typeof(value) == TYPE_INT and int(value) >= 0) \
		or (typeof(value) == TYPE_FLOAT and is_finite(float(value)) and float(value) >= 0.0)
