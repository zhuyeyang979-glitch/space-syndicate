@tool
extends Node
class_name ProductCodexPublicSourceService

const SOURCE_ADAPTER_SCRIPT := preload("res://scripts/runtime/product_codex_public_source_adapter.gd")
const MONSTER_CATALOG_V06 := preload("res://scripts/runtime/monster_catalog_v06.gd")
const DEPENDENCY_KEYS := ["product_market", "snapshot", "card_catalog", "region_public_bridge"]

var _product_market: ProductMarketRuntimeController
var _snapshot: ProductCodexPublicSnapshotService
var _card_catalog: CardRuntimeCatalogService
var _region_public_bridge: Node
var _adapter: RefCounted = SOURCE_ADAPTER_SCRIPT.new()
var _configured := false
var _last_error := "dependencies_not_configured"
var _source_compose_count := 0
var _snapshot_compose_count := 0
var _browser_compose_count := 0


func configure(dependencies: Dictionary) -> Dictionary:
	_clear_dependencies()
	for key_variant: Variant in dependencies:
		if not DEPENDENCY_KEYS.has(str(key_variant)):
			_last_error = "unexpected_dependency:%s" % str(key_variant)
			return debug_snapshot()
	_product_market = dependencies.get("product_market") as ProductMarketRuntimeController
	_snapshot = dependencies.get("snapshot") as ProductCodexPublicSnapshotService
	_card_catalog = dependencies.get("card_catalog") as CardRuntimeCatalogService
	_region_public_bridge = dependencies.get("region_public_bridge") as Node
	var missing: Array[String] = []
	if _product_market == null or not _product_market.has_method("market_entry") or not _product_market.has_method("product_price") or not _product_market.has_method("futures_public_text"):
		missing.append("product_market")
	if _snapshot == null or not _snapshot.has_method("compose"):
		missing.append("snapshot")
	if _card_catalog == null or not _card_catalog.has_method("ordered_card_ids") or not _card_catalog.has_method("authored_definition"):
		missing.append("card_catalog")
	if _region_public_bridge == null or not _region_public_bridge.has_method("public_commodity_region_facts") or not _region_public_bridge.has_method("region_codex_public_facts"):
		missing.append("region_public_bridge")
	if not missing.is_empty():
		_clear_dependencies()
		_last_error = "missing_or_invalid_dependencies:%s" % ",".join(missing)
		return debug_snapshot()
	_configured = true
	_last_error = ""
	return debug_snapshot()


func compose_detail_source(product_name: String, catalog_index: int = -1, selected: bool = false) -> Dictionary:
	if not _require_ready():
		return {}
	var product_id := product_name.strip_edges()
	if product_id == "":
		product_id = _product_at_index(catalog_index)
	if product_id == "" or not ProductMarketRuntimeController.PRODUCT_CATALOG.has(product_id):
		return {"valid": false, "name": product_id, "index": catalog_index, "total": ProductMarketRuntimeController.PRODUCT_CATALOG.size()}
	var safe_index := ProductMarketRuntimeController.PRODUCT_CATALOG.find(product_id)
	if catalog_index >= 0 and catalog_index < ProductMarketRuntimeController.PRODUCT_CATALOG.size() and str(ProductMarketRuntimeController.PRODUCT_CATALOG[catalog_index]) == product_id:
		safe_index = catalog_index
	if _product_market.has_method("ensure_catalog"):
		_product_market.call("ensure_catalog")
	var entry_variant: Variant = _product_market.call("market_entry", product_id, false)
	var market_entry := (entry_variant as Dictionary).duplicate(true) if entry_variant is Dictionary else {}
	if market_entry.is_empty():
		return {"valid": false, "name": product_id, "index": safe_index, "total": ProductMarketRuntimeController.PRODUCT_CATALOG.size()}
	var current_price := int(_product_market.call("product_price", product_id))
	var base_price := int(market_entry.get("base_price", current_price))
	var source := {
		"valid": true,
		"index": safe_index,
		"total": ProductMarketRuntimeController.PRODUCT_CATALOG.size(),
		"selected": selected,
		"name": product_id,
		"profile": _product_profile(product_id),
		"market": {
			"current_price": current_price,
			"base_price": base_price,
			"tier": str(market_entry.get("tier", _product_tier(product_id))),
			"trend_text": _trend_text(market_entry),
			"price_path_text": _price_path_text(market_entry),
			"supply": int(market_entry.get("supply", 0)),
			"demand": int(market_entry.get("demand", 0)),
			"disrupted": int(market_entry.get("disrupted", 0)),
			"volatility": int(market_entry.get("volatility", 0)),
			"weather_text": _market_public_driver_text(market_entry),
		},
		"strategy_rankings": [],
		"futures_public_full": str(_product_market.call("futures_public_text", product_id, false)),
		"futures_public_compact": str(_product_market.call("futures_public_text", product_id, true)),
		"warehouse_public_entries": [],
		"monster_focus_names": _monster_focus_names(product_id, 6),
		"related_card_names": _related_card_names(product_id, 8),
		"supply_district_names": _related_region_names(product_id, "production_products", 6),
		"demand_district_names": _related_region_names(product_id, "demand_products", 6),
		"public_clue_lines": _public_clue_lines(product_id, 4),
		"public_clue_labels": _public_clue_labels(product_id, 4),
	}
	var value: Variant = _adapter.call("compose_source", source)
	var sanitized := (value as Dictionary).duplicate(true) if value is Dictionary else {}
	if sanitized.is_empty():
		_last_error = "public_source_rejected"
		return {}
	_source_compose_count += 1
	_last_error = ""
	return sanitized


func compose_snapshot(product_name: String, catalog_index: int = -1, selected: bool = false) -> Dictionary:
	var source := compose_detail_source(product_name, catalog_index, selected)
	if source.is_empty():
		return {}
	var value: Variant = _snapshot.call("compose", source)
	var result := (value as Dictionary).duplicate(true) if value is Dictionary else {}
	if not result.is_empty():
		_snapshot_compose_count += 1
	return result


func compose_browser_source(request: Dictionary) -> Dictionary:
	return _compose_browser(request, false)


func compose_browser_snapshot(request: Dictionary) -> Dictionary:
	return _compose_browser(request, true)


func public_field_schema() -> Dictionary:
	var value: Variant = _adapter.call("public_field_schema")
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func debug_snapshot() -> Dictionary:
	var adapter_debug: Dictionary = _adapter.call("debug_snapshot") as Dictionary
	return {
		"service_ready": _configured,
		"service_authoritative": _configured,
		"last_error": _last_error,
		"source_compose_count": _source_compose_count,
		"snapshot_compose_count": _snapshot_compose_count,
		"browser_compose_count": _browser_compose_count,
		"dependency_allowlist": DEPENDENCY_KEYS.duplicate(),
		"dependency_count": DEPENDENCY_KEYS.size() if _configured else 0,
		"owns_public_source_assembly": true,
		"owns_rules": false,
		"owns_save_state": false,
		"has_save_api": false,
		"reads_world_bridge": false,
		"reads_private_world": false,
		"reads_player_state": false,
		"reads_private_inventory": false,
		"reads_ai_plan": false,
		"reads_market_quote": false,
		"reads_camera": false,
		"reads_solar": false,
		"uses_product_market_public_owner": _product_market != null,
		"uses_card_catalog_public_owner": _card_catalog != null,
		"uses_region_public_projection": _region_public_bridge != null,
		"uses_existing_snapshot_formatter": _snapshot != null,
		"strategy_scores_fail_closed": true,
		"warehouse_pressure_fail_closed": true,
		"adapter": adapter_debug.duplicate(true),
	}


func _compose_browser(request: Dictionary, final_snapshot: bool) -> Dictionary:
	if not _require_ready() or not bool(_adapter.call("accepts_public_input", request)):
		_last_error = "browser_request_rejected"
		return {}
	var total_count := ProductMarketRuntimeController.PRODUCT_CATALOG.size()
	var start_index := clampi(int(request.get("start_index", 0)), 0, maxi(0, total_count))
	var end_index := clampi(int(request.get("end_index", total_count)), start_index, total_count)
	var selected_index := clampi(int(request.get("selected_index", start_index)), 0, maxi(0, total_count - 1))
	var entries: Array = []
	for catalog_index in range(start_index, end_index):
		var product_id := _product_at_index(catalog_index)
		var snapshot_or_source := compose_snapshot(product_id, catalog_index, catalog_index == selected_index) if final_snapshot else compose_detail_source(product_id, catalog_index, catalog_index == selected_index)
		if final_snapshot and snapshot_or_source.get("browser_entry", {}) is Dictionary:
			entries.append((snapshot_or_source.get("browser_entry", {}) as Dictionary).duplicate(true))
		elif not final_snapshot and not snapshot_or_source.is_empty():
			entries.append(snapshot_or_source.duplicate(true))
	var preview_product := _product_at_index(selected_index)
	var preview_value := compose_snapshot(preview_product, selected_index, true) if final_snapshot else compose_detail_source(preview_product, selected_index, true)
	var preview := (preview_value.get("detail", {}) as Dictionary).duplicate(true) if final_snapshot and preview_value.get("detail", {}) is Dictionary else preview_value.duplicate(true)
	var summaries := _browser_summaries()
	var browser_request := {
		"columns": clampi(int(request.get("columns", 3)), 1, 6),
		"selected_index": selected_index,
		"can_page": bool(request.get("can_page", false)),
		"page_label": str(request.get("page_label", "")),
		"summary_text": _browser_summary_text(request, total_count, start_index, end_index),
	}
	var value: Variant = _adapter.call("compose_browser_source", browser_request, entries, preview, summaries)
	var result := (value as Dictionary).duplicate(true) if value is Dictionary else {}
	if not result.is_empty():
		_browser_compose_count += 1
		_last_error = ""
	return result


func _browser_summary_text(request: Dictionary, total_count: int, start_index: int, end_index: int) -> String:
	var page_label := str(request.get("page_label", ""))
	if page_label != "":
		return "商品目录｜%s\n公开商品市场只显示目录、价格、供需、期货和地图公开线索；现金、手牌、城市猜测与AI计划保持隐藏。" % page_label
	return "商品目录｜%d种商品｜本页%d-%d\n公开商品市场只显示目录、价格、供需、期货和地图公开线索；现金、手牌、城市猜测与AI计划保持隐藏。" % [total_count, start_index + 1, end_index]


func _browser_summaries() -> Array:
	var market_variant: Variant = _product_market.call("public_market_snapshot") if _product_market.has_method("public_market_snapshot") else {}
	var market: Dictionary = ((market_variant as Dictionary).get("product_market", {}) as Dictionary).duplicate(true) if market_variant is Dictionary and (market_variant as Dictionary).get("product_market", {}) is Dictionary else {}
	var run_count := (market as Dictionary).size() if market is Dictionary else 0
	var route_counts := _profile_count("route")
	var category_counts := _profile_count("category")
	return [
		{"title": "公开商品目录", "body": "图鉴%d种｜本局%d种" % [ProductMarketRuntimeController.PRODUCT_CATALOG.size(), run_count], "meta": "商品市场 owner 提供公开价格；本页不读取玩家私密状态。", "accent": Color("#22c55e")},
		{"title": "商品路线分布", "body": _count_summary(route_counts, 5), "meta": "品类:%s" % _count_summary(category_counts, 4), "accent": Color("#38bdf8")},
		{"title": "牌路连接", "body": "相关卡、供需区和怪兽偏好来自公开目录/投影。", "meta": "策略评分、仓库压力、私密城市线索本切片不复制。", "accent": Color("#c084fc")},
	]


func _product_profile(product_id: String) -> Dictionary:
	var profile: Dictionary = ProductMarketRuntimeController.PRODUCT_PROFILES.get(product_id, {})
	if not profile.is_empty():
		return profile.duplicate(true)
	return {
		"category": "未分类商品",
		"route": "通用商业线",
		"terrain": "随机区域",
		"use": "参与供需、商路、GDP和出牌门槛。",
		"hook": "等待后续平衡时补充专属机制。",
		"flavor": "一件还没有被星际商会充分命名的货物。",
		"glyph": "◇",
		"accent": Color("#22c55e"),
		"secondary": Color("#f8fafc"),
	}


func _product_tier(product_id: String) -> String:
	return str(_product_market.call("product_tier", product_id)) if _product_market.has_method("product_tier") else "未定价"


func _trend_text(market_entry: Dictionary) -> String:
	var trend := int(market_entry.get("trend", 0))
	if trend > 0:
		return "+%d" % trend
	if trend < 0:
		return "%d" % trend
	return "持平"


func _price_path_text(market_entry: Dictionary, limit: int = 7) -> String:
	var history: Array = market_entry.get("price_history", []) if market_entry.get("price_history", []) is Array else []
	if history.is_empty():
		return str(int(market_entry.get("price", market_entry.get("base_price", 0))))
	var pieces: Array[String] = []
	var start_index := maxi(0, history.size() - maxi(2, limit))
	for i in range(start_index, history.size()):
		pieces.append(str(int(history[i])))
	return "→".join(pieces)


func _market_public_driver_text(market_entry: Dictionary) -> String:
	var pieces: Array[String] = []
	var weather_driver := str(market_entry.get("weather_driver_summary", "无天气因素"))
	if weather_driver != "无天气因素":
		pieces.append(weather_driver)
	var growth_multiplier := float(market_entry.get("growth_multiplier", 1.0))
	if growth_multiplier > 1.001:
		pieces.append("增速×%.2f" % growth_multiplier)
	var route_multiplier := float(market_entry.get("route_flow_multiplier", 1.0))
	if route_multiplier > 1.001:
		pieces.append("流通×%.2f" % route_multiplier)
	var demand := int(market_entry.get("market_contract_demand", 0))
	var supply := int(market_entry.get("market_contract_supply", 0))
	if demand > 0 or supply > 0:
		pieces.append("合约需+%d/供+%d" % [demand, supply])
	return "；".join(pieces) if not pieces.is_empty() else "暂无经济天气"


func _related_card_names(product_id: String, limit: int) -> Array:
	var names: Array = []
	if _card_catalog == null:
		return names
	for card_variant: Variant in _card_catalog.call("ordered_card_ids"):
		var card_id := str(card_variant)
		var definition_variant: Variant = _card_catalog.call("authored_definition", card_id)
		var definition := definition_variant as Dictionary if definition_variant is Dictionary else {}
		var matches := str(definition.get("play_product", "")) == product_id
		var contract_products_variant: Variant = definition.get("contract_products", [])
		if not matches and contract_products_variant is Array:
			matches = (contract_products_variant as Array).has(product_id)
		if matches:
			names.append(card_id)
		if names.size() >= limit:
			break
	return names


func _monster_focus_names(product_id: String, limit: int) -> Array:
	var names: Array = []
	for monster_variant: Variant in MONSTER_CATALOG_V06.roster():
		var monster := monster_variant as Dictionary if monster_variant is Dictionary else {}
		var focus: Array = monster.get("resource_focus", []) if monster.get("resource_focus", []) is Array else []
		if focus.has(product_id):
			names.append(str(monster.get("name", "怪兽")))
		if names.size() >= limit:
			break
	return names


func _related_region_names(product_id: String, field_name: String, limit: int) -> Array:
	var names: Array = []
	if _region_public_bridge == null:
		return names
	var facts_variant: Variant = _region_public_bridge.call("public_commodity_region_facts")
	if not (facts_variant is Array):
		return names
	for fact_variant: Variant in facts_variant as Array:
		if not (fact_variant is Dictionary):
			continue
		var fact := fact_variant as Dictionary
		if not _commodity_rows_have_product(fact.get(field_name, []), product_id):
			continue
		var legacy_index := int(fact.get("legacy_index", -1))
		var public_variant: Variant = _region_public_bridge.call("region_codex_public_facts", legacy_index)
		var public_fact := public_variant as Dictionary if public_variant is Dictionary else {}
		var region_name := str(public_fact.get("name", "")).strip_edges()
		if region_name != "" and not names.has(region_name):
			names.append(region_name)
		if names.size() >= limit:
			break
	return names


func _public_clue_lines(product_id: String, limit: int) -> Array:
	return _public_clue_entries(product_id, limit, false)


func _public_clue_labels(product_id: String, limit: int) -> Array:
	return _public_clue_entries(product_id, limit, true)


func _public_clue_entries(product_id: String, limit: int, labels: bool) -> Array:
	var result: Array = []
	if _region_public_bridge == null:
		return result
	var facts_variant: Variant = _region_public_bridge.call("public_commodity_region_facts")
	if not (facts_variant is Array):
		return result
	for fact_variant: Variant in facts_variant as Array:
		if not (fact_variant is Dictionary):
			continue
		var fact := fact_variant as Dictionary
		if not _commodity_rows_have_product(fact.get("production_products", []), product_id) and not _commodity_rows_have_product(fact.get("demand_products", []), product_id):
			continue
		var legacy_index := int(fact.get("legacy_index", -1))
		var public_variant: Variant = _region_public_bridge.call("region_codex_public_facts", legacy_index)
		var public_fact := public_variant as Dictionary if public_variant is Dictionary else {}
		var clue := str(public_fact.get("public_clue", "")).strip_edges()
		if clue == "" or clue == "暂无公开线索":
			continue
		var region_name := str(public_fact.get("name", "区域"))
		result.append("%s/线索" % region_name if labels else "%s｜%s" % [region_name, clue])
		if result.size() >= limit:
			break
	return result


func _commodity_rows_have_product(rows_variant: Variant, product_id: String) -> bool:
	if not (rows_variant is Array):
		return false
	for row_variant: Variant in rows_variant as Array:
		if row_variant is Dictionary and str((row_variant as Dictionary).get("product_id", "")) == product_id:
			return true
	return false


func _profile_count(field_name: String) -> Dictionary:
	var result := {}
	for product_variant: Variant in ProductMarketRuntimeController.PRODUCT_CATALOG:
		var profile := _product_profile(str(product_variant))
		var label := str(profile.get(field_name, "未分类"))
		result[label] = int(result.get(label, 0)) + 1
	return result


func _count_summary(counts: Dictionary, limit: int, empty_text: String = "暂无") -> String:
	var entries: Array = []
	for key_variant: Variant in counts.keys():
		entries.append({"label": str(key_variant), "count": int(counts.get(key_variant, 0))})
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var count_a := int(a.get("count", 0))
		var count_b := int(b.get("count", 0))
		if count_a != count_b:
			return count_a > count_b
		return str(a.get("label", "")) < str(b.get("label", ""))
	)
	var pieces: Array[String] = []
	for i in range(mini(limit, entries.size())):
		var entry := entries[i] as Dictionary
		pieces.append("%s×%d" % [str(entry.get("label", "")), int(entry.get("count", 0))])
	return " / ".join(pieces) if not pieces.is_empty() else empty_text


func _product_at_index(index: int) -> String:
	if index < 0 or index >= ProductMarketRuntimeController.PRODUCT_CATALOG.size():
		return ""
	return str(ProductMarketRuntimeController.PRODUCT_CATALOG[index])


func _clear_dependencies() -> void:
	_product_market = null
	_snapshot = null
	_card_catalog = null
	_region_public_bridge = null
	_configured = false


func _require_ready() -> bool:
	if _configured:
		return true
	_last_error = "dependencies_not_configured"
	return false
