extends Node

@onready var query: EconomyDashboardViewerQueryPort = $EconomyDashboardViewerQueryPort
@onready var service: EconomyDashboardPublicSnapshotService = $EconomyDashboardPublicSnapshotService
@onready var dashboard: SpaceSyndicateEconomyDashboard = $EconomyDashboard


func _ready() -> void:
	service.configure()
	var invalid := query.snapshot_for_authorized_viewer(960.0)
	var valid := service.compose(_fixture())
	dashboard.set_dashboard(valid.get("dashboard", {}) as Dictionary)
	await get_tree().process_frame
	var rendered := _rendered_text(dashboard)
	var passed := str(invalid.get("reason_code", "")) == "dependency_missing" \
		and rendered.contains("我的现金") and rendered.contains("321") \
		and not rendered.contains("987654") and not rendered.contains("opponent-ledger") \
		and int(query.debug_snapshot().get("rejected_count", 0)) == 1
	print("ECONOMY_VIEWER_QUERY_CUTOVER_BENCH=%s" % ("PASS" if passed else "FAIL"))
	get_tree().quit(0 if passed else 1)


func _fixture() -> Dictionary:
	return {"contract_version": "economy_dashboard_viewer_source.v1", "valid": true, "viewer_context": {"viewer_index": 0, "authorized": true}, "public_player_summaries": [{"subject_index": 1, "name": "对手"}], "public_commodity_entries": [{"commodity_id": "life", "name": "生命", "price": 40, "supply": 2, "demand": 4, "pressure": 2, "price_band_label": "低价"}], "public_region_economy_entries": [{"region_id": "r1", "commodity_gdp_per_minute": 55}], "public_facility_entries": [{"region_id": "r1", "facility_type": "factory", "industry_id": "life", "rank": 1}], "public_region_integrity_entries": [{"region_id": "r1", "integrity_basis_points": 10000, "facility_count": 1, "lifecycle_state": "active"}], "public_route_summaries": [], "public_warehouse_risk_entries": [], "public_weather": {"short_text": "稳定"}, "public_monster_pressure": [], "public_log_clues": [], "own_private_economy": {"viewer_index": 0, "subject_index": 0, "authorized_private": true, "name": "我", "exact_cash": 321, "commodity_gdp_per_minute": 25, "sale_receipts": [], "warehouses": [], "facilities": []}, "layout": {}}


func _rendered_text(node: Node) -> String:
	var parts: Array[String] = []
	if node is Label: parts.append((node as Label).text); parts.append((node as Label).tooltip_text)
	if node is Control: parts.append((node as Control).tooltip_text)
	for child in node.get_children(): parts.append(_rendered_text(child))
	return "\n".join(parts)
