@tool
extends Node
class_name CardRuntimeCatalogService

@export var catalog: CardRuntimeCatalogResource

var _configured := false
var _last_error := ""


func configure(_ruleset_snapshot: Dictionary = {}) -> void:
	_configured = catalog != null
	_last_error = "" if _configured else "catalog_resource_missing"
	if not _configured:
		push_error("CardRuntimeCatalogService requires card_runtime_catalog_v04.tres; no legacy fallback is available.")
		return
	var report := catalog.validation_report()
	_configured = bool(report.get("valid", false))
	if not _configured:
		_last_error = "catalog_validation_failed"
		push_error("CardRuntimeCatalogService catalog validation failed: %s" % JSON.stringify(report.get("errors", [])))


func has_card(card_id: String) -> bool:
	return catalog.has_card(card_id) if _require_catalog() else false


func authored_definition(card_id: String) -> Dictionary:
	return catalog.authored_definition(card_id) if _require_catalog() else {}


func exact_definition(card_id: String) -> Dictionary:
	return catalog.exact_definition(card_id) if _require_catalog() else {}


func derived_definition(card_id: String) -> Dictionary:
	return catalog.derived_definition(card_id) if _require_catalog() else {}


func definition(card_id: String) -> Dictionary:
	return catalog.definition(card_id) if _require_catalog() else {}


func family_id(card_id: String) -> String:
	return catalog.family_id(card_id) if _require_catalog() else ""


func rank(card_id: String) -> int:
	return catalog.rank(card_id) if _require_catalog() else 0


func ordered_card_ids() -> Array:
	return catalog.ordered_card_ids() if _require_catalog() else []


func public_pool() -> Array:
	return catalog.public_pool() if _require_catalog() else []


func upgradeable_families() -> Array:
	return catalog.upgradeable_families() if _require_catalog() else []


func product_related_card_count(product_name: String) -> int:
	if product_name.is_empty() or not _require_catalog():
		return 0
	var count := 0
	for card_id_variant in catalog.ordered_card_ids():
		var card_definition := catalog.authored_definition(str(card_id_variant))
		if str(card_definition.get("play_product", "")) == product_name \
				or str(card_definition.get("supply_product", "")) == product_name:
			count += 1
	return count


func validation_report() -> Dictionary:
	if not _require_catalog():
		return {"valid": false, "errors": [_last_error]}
	return catalog.validation_report()


func debug_snapshot() -> Dictionary:
	var snapshot := catalog.debug_snapshot() if catalog != null else {}
	snapshot["service_ready"] = _configured
	snapshot["service_authoritative"] = _configured
	snapshot["runtime_owner"] = "CardRuntimeCatalogService"
	snapshot["catalog_resource_path"] = catalog.resource_path if catalog != null else ""
	snapshot["last_error"] = _last_error
	return snapshot


func _require_catalog() -> bool:
	if catalog != null:
		return true
	_last_error = "catalog_resource_missing"
	return false
