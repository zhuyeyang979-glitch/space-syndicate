extends RefCounted
class_name RulesetV06SchemaRegistry

const SCHEMA_VERSION := 1
const SCHEMA_IDS := [
	"region",
	"public_facility",
	"installed_commodity_rate",
	"route",
	"commodity_sale_receipt",
	"player_mana",
	"commodity_belt_visibility",
]

const SCHEMAS := {
	"region": {
		"required": ["region_id", "terrain_id", "neighbor_region_ids", "facility_slot_ids", "lifecycle_state", "damage_taken", "generation", "revision"],
		"types": {"region_id": "string", "terrain_id": "string", "neighbor_region_ids": "array", "facility_slot_ids": "array", "lifecycle_state": "string", "damage_taken": "int", "generation": "int", "revision": "int"},
		"forbidden": ["max_hp", "current_hp", "owner", "projects", "project_shares"],
		"notes": "max_hp is derived from active public facilities and is never a second writable state.",
	},
	"public_facility": {
		"required": ["facility_id", "slot_id", "region_id", "facility_type", "owner_kind", "owner_player_index", "rank", "generation", "active", "built_at"],
		"types": {"facility_id": "string", "slot_id": "string", "region_id": "string", "facility_type": "string", "owner_kind": "string", "owner_player_index": "int", "rank": "int", "generation": "int", "active": "bool", "built_at": "float"},
		"forbidden": ["current_hp", "damage", "project_id", "share_basis_points_by_player"],
		"notes": "A facility contributes rank-based HP but does not own an independent current HP bar.",
	},
	"installed_commodity_rate": {
		"required": ["installation_id", "commodity_id", "color", "installer_player_index", "direction", "base_units_per_minute", "source_card_rank", "facility_id", "region_id", "region_revision", "generation", "active"],
		"types": {"installation_id": "string", "commodity_id": "string", "color": "string", "installer_player_index": "int", "direction": "string", "base_units_per_minute": "int", "source_card_rank": "int", "facility_id": "string", "region_id": "string", "region_revision": "int", "generation": "int", "active": "bool"},
		"forbidden": ["node", "resource", "callable", "project_share"],
		"notes": "Permanent authored installation rate; effective flow is derived elsewhere.",
	},
	"route": {
		"required": ["route_id", "product_id", "owner_player_index", "source_region_id", "target_region_id", "segment_region_ids", "mode_tags", "capacity_per_minute", "distance_units", "revision", "active"],
		"types": {"route_id": "string", "product_id": "string", "owner_player_index": "int", "source_region_id": "string", "target_region_id": "string", "segment_region_ids": "array", "mode_tags": "array", "capacity_per_minute": "int", "distance_units": "float", "revision": "int", "active": "bool"},
		"forbidden": ["hp", "damage", "line_node", "curve"],
		"notes": "Routes are derived economic paths, not independent damageable entities.",
	},
	"commodity_sale_receipt": {
		"required": ["receipt_id", "commodity_owner", "commodity_id", "color", "units", "source_region_id", "market_region_id", "route_id", "base_unit_price_cents", "shortest_legal_distance", "distance_premium_basis_points", "unit_price_cents", "gross_value", "rent_rows", "owner_net_cash", "gdp_value", "settled_at"],
		"types": {"receipt_id": "string", "commodity_owner": "int", "commodity_id": "string", "color": "string", "units": "int", "source_region_id": "string", "market_region_id": "string", "route_id": "string", "base_unit_price_cents": "int", "shortest_legal_distance": "int", "distance_premium_basis_points": "int", "unit_price_cents": "int", "gross_value": "int", "rent_rows": "array", "owner_net_cash": "int", "gdp_value": "int", "settled_at": "float"},
		"forbidden": ["owner_name", "private_plan", "node", "resource"],
		"notes": "The exact-once source for cash, rent, GDP, mana, and belt tier observations.",
	},
	"player_mana": {
		"required": ["player_index", "pools", "updated_at", "revision"],
		"types": {"player_index": "int", "pools": "dictionary", "updated_at": "float", "revision": "int"},
		"forbidden": ["public_total", "opponent_pools", "node"],
		"notes": "Six viewer-private color pools; public snapshots must remove pools before presentation.",
	},
	"commodity_belt_visibility": {
		"required": ["viewer_player_index", "gdp_tier", "visible_card_ids", "obscured_entries", "belt_revision", "computed_at"],
		"types": {"viewer_player_index": "int", "gdp_tier": "int", "visible_card_ids": "array", "obscured_entries": "array", "belt_revision": "int", "computed_at": "float"},
		"forbidden": ["complete_deck", "other_player_gdp", "hidden_card_ids", "ai_private_plan"],
		"notes": "Viewer-scoped claim authority; obscured entries expose color only.",
	},
}


static func schema_ids() -> Array[String]:
	var result: Array[String] = []
	for schema_id in SCHEMA_IDS:
		result.append(str(schema_id))
	return result


static func schema_snapshot(schema_id: String) -> Dictionary:
	return (SCHEMAS.get(schema_id, {}) as Dictionary).duplicate(true)


static func debug_snapshot() -> Dictionary:
	var result: Dictionary = {}
	for schema_id in SCHEMA_IDS:
		result[str(schema_id)] = schema_snapshot(str(schema_id))
	return {"schema_version": SCHEMA_VERSION, "schema_ids": schema_ids(), "schemas": result}


static func validate_payload(schema_id: String, payload: Dictionary) -> Dictionary:
	var errors: Array[String] = []
	var schema := schema_snapshot(schema_id)
	if schema.is_empty():
		return {"valid": false, "errors": ["unknown_schema:%s" % schema_id]}
	if not _is_pure_data(payload):
		errors.append("payload_not_pure_data")
	for field_variant in schema.get("required", []):
		var field := str(field_variant)
		if not payload.has(field):
			errors.append("missing_field:%s" % field)
	for field_variant in schema.get("forbidden", []):
		var field := str(field_variant)
		if payload.has(field):
			errors.append("forbidden_field:%s" % field)
	var types: Dictionary = schema.get("types", {})
	for field_variant in types.keys():
		var field := str(field_variant)
		if payload.has(field) and not _matches_type(payload[field], str(types[field_variant])):
			errors.append("type_mismatch:%s:%s" % [field, str(types[field_variant])])
	return {"valid": errors.is_empty(), "errors": errors, "schema_id": schema_id}


static func _matches_type(value: Variant, type_name: String) -> bool:
	match type_name:
		"string": return value is String or value is StringName
		"int": return value is int
		"float": return value is float or value is int
		"bool": return value is bool
		"array": return value is Array
		"dictionary": return value is Dictionary
	return false


static func _is_pure_data(value: Variant) -> bool:
	if value == null or value is String or value is StringName or value is bool or value is int or value is float:
		return true
	if value is Array:
		for item in value:
			if not _is_pure_data(item):
				return false
		return true
	if value is Dictionary:
		for key in value:
			if not (key is String or key is StringName or key is int) or not _is_pure_data(value[key]):
				return false
		return true
	return false
