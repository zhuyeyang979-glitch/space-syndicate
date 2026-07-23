@tool
extends Node
class_name AiMarketPublicQueryPort

const PUBLIC_PRODUCT_KEYS := [
	"tier",
	"base_price",
	"price",
	"trend",
	"raw_trend",
	"price_step_cap",
	"volatility",
	"supply",
	"demand",
	"disrupted",
	"temporary_demand_pressure",
	"temporary_supply_pressure",
	"market_contract_demand",
	"market_contract_supply",
	"growth_multiplier",
	"route_flow_multiplier",
	"weather_price_growth_multiplier",
	"weather_modifier",
	"driver_summary",
	"weather_driver_summary",
	"futures_positions",
]
const PRIVATE_FUTURES_KEYS := [
	"owner",
	"position_id",
	"source",
	"card_id",
	"locked_margin",
	"action_fee_cash",
	"warehouse_district",
	"warehouse_region_id",
	"settlement_formula_id",
	"warehouse_loss_formula_id",
]

@export var product_market_runtime_controller_path: NodePath

var _query_count := 0
var _rejected_query_count := 0


func is_ready() -> bool:
	var source := _source_snapshot()
	return _valid_source(source)


func public_snapshot() -> Dictionary:
	_query_count += 1
	var source := _source_snapshot()
	if not _valid_source(source):
		_rejected_query_count += 1
		return _unavailable("market_public_catalog_unavailable")
	var source_market := source.get("product_market", {}) as Dictionary
	var products: Array = []
	for product_variant in ProductMarketRuntimeController.PRODUCT_CATALOG:
		var product_id := str(product_variant)
		var source_entry := source_market.get(product_id, {}) as Dictionary
		var entry := {
			"product_id": product_id,
			"public_name": product_id,
			"public_category": str((ProductMarketRuntimeController.PRODUCT_PROFILES.get(product_id, {}) as Dictionary).get("category", "")),
		}
		for key_variant in PUBLIC_PRODUCT_KEYS:
			var key := str(key_variant)
			if source_entry.has(key):
				entry[key] = TablePresentationPureDataPolicy.detached_copy(source_entry[key])
		if not _safe_public_entry(entry):
			_rejected_query_count += 1
			return _unavailable("market_public_entry_invalid")
		products.append(entry)
	var result := {
		"schema_version": 1,
		"available": true,
		"reason_code": "market_public_snapshot_ready",
		"visibility_scope": "public",
		"market_revision": int(source.get("market_revision", 0)),
		"business_cycle_count": int(source.get("business_cycle_count", 0)),
		"product_count": products.size(),
		"products": products,
	}
	result["state_revision"] = JSON.stringify([
		"ai_market_public_v1",
		result["market_revision"],
		products,
	]).sha256_text()
	return TablePresentationPureDataPolicy.detached_copy(result)


func public_product(product_id: String) -> Dictionary:
	var normalized := product_id.strip_edges()
	if normalized.is_empty() or normalized != product_id:
		return {}
	for row_variant in public_snapshot().get("products", []) as Array:
		if row_variant is Dictionary and str((row_variant as Dictionary).get("product_id", "")) == normalized:
			return (row_variant as Dictionary).duplicate(true)
	return {}


func public_price(product_id: String) -> int:
	var row := public_product(product_id)
	return int(row.get("price", row.get("base_price", 0)))


func debug_snapshot() -> Dictionary:
	return {
		"port_ready": is_ready(),
		"query_count": _query_count,
		"rejected_query_count": _rejected_query_count,
		"expected_product_count": ProductMarketRuntimeController.PRODUCT_CATALOG.size(),
		"returns_private_futures": false,
		"returns_mutable_market": false,
		"calls_ensure_catalog": false,
		"mutates_market": false,
		"consumes_rng": false,
		"references_main": false,
	}


func _source_snapshot() -> Dictionary:
	return _market().public_market_snapshot() if _market() != null else {}


func _valid_source(source: Dictionary) -> bool:
	if not bool(source.get("catalog_ready", false)) \
			or not (source.get("product_market", {}) is Dictionary):
		return false
	var source_market := source.get("product_market", {}) as Dictionary
	if source_market.size() != ProductMarketRuntimeController.PRODUCT_CATALOG.size():
		return false
	for product_variant in ProductMarketRuntimeController.PRODUCT_CATALOG:
		if not (source_market.get(str(product_variant)) is Dictionary):
			return false
	return true


func _safe_public_entry(entry: Dictionary) -> bool:
	if not TablePresentationPureDataPolicy.is_pure_data(entry):
		return false
	for position_variant in entry.get("futures_positions", []) as Array:
		if not (position_variant is Dictionary):
			return false
		for private_key in PRIVATE_FUTURES_KEYS:
			if (position_variant as Dictionary).has(private_key):
				return false
	return true


func _unavailable(reason_code: String) -> Dictionary:
	return {
		"schema_version": 1,
		"available": false,
		"reason_code": reason_code,
		"visibility_scope": "public",
		"market_revision": -1,
		"business_cycle_count": 0,
		"product_count": 0,
		"products": [],
		"state_revision": "",
	}


func _market() -> ProductMarketRuntimeController:
	return get_node_or_null(product_market_runtime_controller_path) as ProductMarketRuntimeController
