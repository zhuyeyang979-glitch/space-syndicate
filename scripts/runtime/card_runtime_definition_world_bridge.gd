@tool
extends Node
class_name CardRuntimeDefinitionWorldBridge

var _world: Node
var _catalog_service: CardRuntimeCatalogService
var _product_market_runtime_controller: ProductMarketRuntimeController
var _city_gdp_derivative_runtime_controller: CityGdpDerivativeRuntimeController


func bind_world(world: Node) -> void:
	_world = world


func set_catalog_service(service: CardRuntimeCatalogService) -> void:
	_catalog_service = service


func set_product_market_runtime_controller(controller: ProductMarketRuntimeController) -> void:
	_product_market_runtime_controller = controller


func set_city_gdp_derivative_runtime_controller(controller: CityGdpDerivativeRuntimeController) -> void:
	_city_gdp_derivative_runtime_controller = controller


func has_runtime_card(card_id: String) -> bool:
	return not resolve_definition(card_id).is_empty()


func resolve_definition(card_id: String) -> Dictionary:
	if card_id.is_empty():
		return {}
	if _catalog_service == null:
		push_error("CardRuntimeDefinitionWorldBridge has no Catalog Service; no main.gd fallback is available.")
		return {}
	var exact := _catalog_service.exact_definition(card_id)
	if not exact.is_empty():
		return _enrich_external_terms(card_id, exact)
	var monster_definition := _monster_definition(card_id)
	if not monster_definition.is_empty():
		return monster_definition
	return _catalog_service.derived_definition(card_id)


func rank(card_id: String) -> int:
	return _catalog_service.rank(card_id) if _catalog_service != null else 0


func family_id(card_id: String) -> String:
	return _catalog_service.family_id(card_id) if _catalog_service != null else ""


func ordered_card_ids() -> Array:
	return _catalog_service.ordered_card_ids() if _catalog_service != null else []


func public_pool() -> Array:
	return _catalog_service.public_pool() if _catalog_service != null else []


func upgradeable_families() -> Array:
	return _catalog_service.upgradeable_families() if _catalog_service != null else []


func debug_snapshot() -> Dictionary:
	return {
		"bridge_ready": _catalog_service != null,
		"world_bound": _world != null,
		"catalog_service_ready": bool(_catalog_service.debug_snapshot().get("service_ready", false)) if _catalog_service != null else false,
		"product_terms_bound": _product_market_runtime_controller != null,
		"city_gdp_terms_bound": _city_gdp_derivative_runtime_controller != null,
		"source_precedence": ["catalog_exact", "financial_terms", "monster", "catalog_derived"],
	}


func _monster_definition(card_id: String) -> Dictionary:
	if _world == null:
		return {}
	if _world.has_method("_is_monster_card_name") and bool(_world.call("_is_monster_card_name", card_id)):
		var card_variant: Variant = _world.call("_monster_card_definition", card_id)
		return (card_variant as Dictionary).duplicate(true) if card_variant is Dictionary else {}
	if _world.has_method("_is_monster_technique_card_name") and bool(_world.call("_is_monster_technique_card_name", card_id)):
		var technique_variant: Variant = _world.call("_monster_technique_definition", card_id)
		return (technique_variant as Dictionary).duplicate(true) if technique_variant is Dictionary else {}
	return {}


func _enrich_external_terms(card_id: String, definition: Dictionary) -> Dictionary:
	var kind := str(definition.get("kind", ""))
	if kind == "product_futures":
		if _product_market_runtime_controller == null:
			push_error("Product futures terms cannot be loaded without ProductMarketRuntimeController: %s" % card_id)
			definition["futures_terms_error"] = "controller_missing"
			return definition
		return _product_market_runtime_controller.skill_with_terms(card_id, definition)
	if kind == "city_gdp_derivative":
		if _city_gdp_derivative_runtime_controller == null:
			push_error("City GDP derivative terms cannot be loaded without CityGdpDerivativeRuntimeController: %s" % card_id)
			definition["gdp_derivative_terms_error"] = "controller_missing"
			return definition
		return _city_gdp_derivative_runtime_controller.skill_with_terms(card_id, definition)
	return definition
