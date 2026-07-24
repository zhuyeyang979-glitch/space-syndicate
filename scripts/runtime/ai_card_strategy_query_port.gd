@tool
extends Node
class_name AiCardStrategyQueryPort

@export var route_catalog: DevelopmentRouteCatalogResource


func is_ready() -> bool:
	return route_catalog != null and bool(route_catalog.validation_report().get("valid", false))


func development_routes() -> Array:
	return route_catalog.all_routes() if is_ready() else []


func route_id_for_card(card_facts: Dictionary) -> String:
	return route_catalog.route_id_for_card(card_facts) if is_ready() else "tactical_support"


func route_label(route_id: String) -> String:
	return route_catalog.route_label(route_id) if is_ready() else "即时战术"


func debug_snapshot() -> Dictionary:
	return {
		"port_ready": is_ready(),
		"route_count": development_routes().size(),
		"visibility_scope": "public_catalog",
		"returns_pure_data": true,
		"mutates_world": false,
		"consumes_rng": false,
		"reads_table_selection": false,
		"reads_main": false,
		"reads_diagnostics_world": false,
	}