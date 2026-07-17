@tool
extends Node
class_name EconomyDashboardPublicSnapshotService

## Formats a viewer-scoped presentation source containing public facts plus the
## authorized viewer's own private facts. This service never decides access.

var _configured := false
var _compose_count := 0


func configure(_config: Dictionary = {}) -> void:
	_configured = true


func compose(source: Dictionary) -> Dictionary:
	_compose_count += 1
	if not _source_valid(source):
		return _empty_snapshot(str(source.get("reason_code", "data_unavailable")))
	var own := source.get("own_private_economy", {}) as Dictionary
	var commodities := _dictionary_array(source.get("public_commodity_entries", []), 64)
	var regions := _dictionary_array(source.get("public_region_economy_entries", []), 64)
	var integrity := _dictionary_array(source.get("public_region_integrity_entries", []), 64)
	var facilities := _dictionary_array(source.get("public_facility_entries", []), 128)
	var routes := _dictionary_array(source.get("public_route_summaries", []), 64)
	var warehouse_risk := _dictionary_array(source.get("public_warehouse_risk_entries", []), 32)
	var monsters := _dictionary_array(source.get("public_monster_pressure", []), 16)
	var logs := _dictionary_array(source.get("public_log_clues", []), 8)
	var layout := source.get("layout", {}) as Dictionary
	var weather := source.get("public_weather", {}) as Dictionary
	var own_receipts := _dictionary_array(own.get("sale_receipts", []), 8)
	var own_warehouses := _dictionary_array(own.get("warehouses", []), 8)
	var own_facilities := _dictionary_array(own.get("facilities", []), 32)
	var dashboard := {
		"title": "经济仪表板",
		"title_tooltip": "公共市场、设施、运输与区域完整度；现金和流水仅显示你自己的。",
		"tooltip": "经济仪表板：查看商品生产、需求、销售收据、公共设施和实际运输压力。",
		"accent": Color("#4ade80"),
		"kpi_columns": clampi(int(layout.get("kpi_columns", 4)), 1, 4),
		"lane_columns": clampi(int(layout.get("lane_columns", 3)), 1, 3),
		"overview_columns": clampi(int(layout.get("overview_columns", 4)), 1, 4),
		"chips": [
			{"text": "商品%d" % commodities.size(), "accent": Color("#facc15"), "tooltip": "只读公共商品目录与价格压力。"},
			{"text": "设施%d" % facilities.size(), "accent": Color("#4ade80"), "tooltip": "公共设施类型、等级及明确公开的所有权。"},
			{"text": _short_text(str(weather.get("short_text", weather.get("status_text", "天气稳定"))), 18), "accent": Color("#38bdf8"), "tooltip": "公共天气对生产、需求和运输的影响。"},
		],
		"kpis": [
			{"title": "我的现金", "value": "%d" % int(own.get("exact_cash", 0)), "meta": str(own.get("name", "当前玩家")), "accent": Color("#4ade80"), "tooltip": "仅当前授权玩家可见的准确现金。"},
			{"title": "我的商品GDP/min", "value": "%d" % int(own.get("commodity_gdp_per_minute", 0)), "meta": "来自商品销售收据", "accent": Color("#86efac"), "tooltip": "商品销售同时产生净现金和商品GDP；此处不重复换算。"},
			{"title": "公共区域GDP", "value": "%d" % _sum_int(regions, "commodity_gdp_per_minute"), "meta": "%d个区域" % regions.size(), "accent": Color("#facc15"), "tooltip": "区域商品GDP是公共销售活动的汇总，不含对手私人拆解。"},
			{"title": "怪兽压力", "value": "%d" % monsters.size(), "meta": "公开在场状态", "accent": Color("#fb7185"), "tooltip": "只显示公开怪兽位置与状态，不显示资金池或隐藏归属。"},
		],
		"overview_cards": [
			{"title": "商品与销售", "body": "先对照生产、需求、积压和浪费，再看商品销售收据。", "accent": Color("#facc15"), "tooltip": "销售收据记录商品GDP与净现金。"},
			{"title": "公共设施", "body": "设施类型、等级、租金和区域完整度决定经济承载力。", "accent": Color("#4ade80"), "tooltip": "区域可以包含多个不同所有者的设施。"},
			{"title": "运输吞吐", "body": "实际流量、容量、天气与拥堵共同形成物流瓶颈。", "accent": Color("#38bdf8"), "tooltip": "页面只读取已缓存路线，不会重新计算网络。"},
			{"title": "隐私边界", "body": "对手现金、账本、库存和隐藏所有权不会出现在本页。", "accent": Color("#c084fc"), "tooltip": "终局也不会自动解除这一边界。"},
		],
		"decisions": [
			{"title": "补供给", "body": "关注高需求、低供给商品。", "keyword": "生产｜需求｜积压", "accent": Color("#facc15"), "tooltip": "从公开供需判断设施布局。"},
			{"title": "保吞吐", "body": "关注低完整度区域与运输瓶颈。", "keyword": "设施｜完整度｜运输", "accent": Color("#38bdf8"), "tooltip": "运输设施和区域完整度影响实际流量。"},
			{"title": "核流水", "body": "用自己的销售收据核对净现金与GDP。", "keyword": "收据｜租金｜仓储", "accent": Color("#4ade80"), "tooltip": "只显示当前玩家自己的详细流水。"},
		],
		"lanes": [
			{"title": "公共商品", "lines": _commodity_lines(commodities), "accent": Color("#facc15"), "tooltip": "公共价格、供给、需求与压力。"},
			{"title": "区域GDP与完整度", "lines": _region_lines(regions, integrity), "accent": Color("#4ade80"), "tooltip": "公共区域商品GDP和设施完整度。"},
			{"title": "公共运输", "lines": _route_lines(routes), "accent": Color("#38bdf8"), "tooltip": "只读缓存中的实际运输能力与瓶颈。"},
			{"title": "我的销售收据", "lines": _receipt_lines(own_receipts), "accent": Color("#86efac"), "tooltip": "仅当前玩家可见的商品GDP、净现金与设施租金。"},
			{"title": "我的设施与仓库", "lines": _own_asset_lines(own_facilities, own_warehouses), "accent": Color("#a78bfa"), "tooltip": "仅当前玩家自己的设施和仓库库存。"},
			{"title": "公开压力与线索", "lines": _pressure_lines(monsters, warehouse_risk, logs), "accent": Color("#fb7185"), "tooltip": "公开怪兽、匿名仓储风险和公开日志；不反推出隐藏所有权。"},
		],
	}
	return {
		"summary_text": "经济总览｜公共商品%d｜公共设施%d｜区域GDP %d｜我的商品GDP/min %d｜我的现金%d。对手私人经济保持隐藏。" % [commodities.size(), facilities.size(), _sum_int(regions, "commodity_gdp_per_minute"), int(own.get("commodity_gdp_per_minute", 0)), int(own.get("exact_cash", 0))],
		"overview_cards": dashboard["overview_cards"],
		"dashboard": dashboard,
	}


func debug_snapshot() -> Dictionary:
	return {"service_ready": _configured, "supported_domain": "viewer_scoped_economy_dashboard_presentation", "compose_count": _compose_count, "formats_public_plus_authorized_own_private": true, "calculates_product_prices": false, "calculates_city_income": false, "calculates_cashflow": false, "evaluates_private_truth": false, "reads_runtime_nodes": false, "bounded_input_lists": true, "legacy_main_formatter_active": false}


func _source_valid(source: Dictionary) -> bool:
	if not bool(source.get("valid", false)) or str(source.get("contract_version", "")) != "economy_dashboard_viewer_source.v1": return false
	var context: Dictionary = source.get("viewer_context", {}) if source.get("viewer_context", {}) is Dictionary else {}
	var own: Dictionary = source.get("own_private_economy", {}) if source.get("own_private_economy", {}) is Dictionary else {}
	var viewer := int(context.get("viewer_index", -1))
	return bool(context.get("authorized", false)) and bool(own.get("authorized_private", false)) and viewer >= 0 and int(own.get("viewer_index", -1)) == viewer and int(own.get("subject_index", -1)) == viewer and TablePresentationPureDataPolicy.is_pure_data(source)


func _empty_snapshot(reason: String) -> Dictionary:
	return {"summary_text": "还没有可显示的经济数据。商品目录、对局或当前玩家授权尚未准备好。", "reason_code": reason, "overview_cards": [{"title": "暂无经济数据", "body": "开始新局并等待权威经济系统完成配置。打开本页不会初始化目录或刷新路线。", "accent": Color("#38bdf8"), "tooltip": "只读页面采用失败关闭策略。"}], "dashboard": {"title": "经济仪表板", "accent": Color("#4ade80"), "chips": [], "kpis": [], "decisions": [], "lanes": []}}


func _commodity_lines(entries: Array) -> Array:
	var lines: Array = []
	for entry in entries.slice(0, 6): lines.append("%s｜价格%d（%s）｜供给%d｜需求%d｜压力%+d｜%s" % [str(entry.get("name", entry.get("commodity_id", "商品"))), int(entry.get("price", 0)), str(entry.get("price_band_label", "未知")), int(entry.get("supply", 0)), int(entry.get("demand", 0)), int(entry.get("pressure", 0)), str(entry.get("weather_summary", "无天气影响"))])
	return lines if not lines.is_empty() else ["暂无公共商品报价。"]


func _region_lines(gdp_entries: Array, integrity_entries: Array) -> Array:
	var gdp_by_region: Dictionary = {}
	for entry in gdp_entries: gdp_by_region[str(entry.get("region_id", ""))] = int(entry.get("commodity_gdp_per_minute", 0))
	var lines: Array = []
	for entry in integrity_entries.slice(0, 6): lines.append("%s｜商品GDP/min %d｜完整度%d%%｜设施%d｜%s" % [str(entry.get("region_id", "区域")), int(gdp_by_region.get(str(entry.get("region_id", "")), 0)), int(round(float(int(entry.get("integrity_basis_points", 0))) / 100.0)), int(entry.get("facility_count", 0)), "废墟" if str(entry.get("lifecycle_state", "")) == "ruined" else "存续"])
	return lines if not lines.is_empty() else ["暂无公共区域经济数据。"]


func _route_lines(entries: Array) -> Array:
	var lines: Array = []
	for entry in entries.slice(0, 6): lines.append("%s→%s｜%s｜吞吐%d/min｜天气×%.2f｜%s" % [str(entry.get("source_region_id", "?")), str(entry.get("market_region_id", "?")), str(entry.get("transport_mode", "land")), int(entry.get("capacity_units_per_minute", 0)), float(entry.get("weather_multiplier", 1.0)), "瓶颈" if bool(entry.get("bottleneck", false)) else "可用"])
	return lines if not lines.is_empty() else ["路线缓存尚未准备好；本页不会主动刷新。"]


func _receipt_lines(entries: Array) -> Array:
	var lines: Array = []
	for entry in entries.slice(0, 4): lines.append("%s｜商品GDP %d｜净现金%+d｜设施租金%d" % [str(entry.get("commodity_id", "商品")), int(entry.get("gdp_value", 0)), int(entry.get("owner_net_cash", 0)), int(entry.get("storage_rent_cents", 0))])
	return lines if not lines.is_empty() else ["暂无自己的商品销售收据。"]


func _own_asset_lines(facilities: Array, warehouses: Array) -> Array:
	var lines: Array = []
	for entry in facilities.slice(0, 2): lines.append("我的设施｜%s｜%s %s｜等级%d" % [str(entry.get("region_id", "区域")), str(entry.get("facility_type", "设施")), str(entry.get("industry_id", "")), int(entry.get("rank", 1))])
	for entry in warehouses.slice(0, 2): lines.append("我的仓库｜%s｜%s｜库存%s" % [str(entry.get("region_id", "区域")), str(entry.get("commodity_id", "商品")), str(entry.get("quantity_milliunits", entry.get("units", 0)))])
	return lines if not lines.is_empty() else ["暂无自己的设施或仓库库存。"]


func _pressure_lines(monsters: Array, warehouses: Array, logs: Array) -> Array:
	var lines: Array = []
	for entry in monsters.slice(0, 2): lines.append("怪兽｜%s %d级｜区域%d｜%s" % [str(entry.get("name", "怪兽")), int(entry.get("rank", 1)), int(entry.get("region_index", -1)), str(entry.get("pressure_label", "在场压力"))])
	for entry in warehouses.slice(0, 1): lines.append("匿名仓储风险｜%s｜设施%d" % [str(entry.get("region_id", "区域")), int(entry.get("public_warehouse_count", 0))])
	for entry in logs.slice(0, 1): lines.append("公开日志｜%s" % str(entry.get("message", entry.get("public_text", "经济异动"))))
	return lines if not lines.is_empty() else ["暂无公开压力或经济线索。"]


func _sum_int(entries: Array, key: String) -> int:
	var total := 0
	for entry in entries: total += int(entry.get(key, 0))
	return total


func _dictionary_array(value: Variant, limit: int) -> Array:
	var result: Array = []
	if value is Array:
		for entry in value:
			if entry is Dictionary: result.append((entry as Dictionary).duplicate(true))
			if result.size() >= limit: break
	return result


func _short_text(value: String, limit: int) -> String:
	return value if limit <= 0 or value.length() <= limit else value.substr(0, limit - 1) + "…"
