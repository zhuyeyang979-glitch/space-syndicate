extends SceneTree

var failures: Array[String] = []


func _init() -> void: call_deferred("_run")


func _run() -> void:
	var service := (load("res://scenes/runtime/EconomyDashboardPublicSnapshotService.tscn") as PackedScene).instantiate() as EconomyDashboardPublicSnapshotService
	root.add_child(service)
	service.configure()
	var snapshot := service.compose(_source())
	var text := JSON.stringify(snapshot)
	_expect(text.contains("我的现金") and text.contains("600"), "authorized own cash is rendered")
	_expect(not text.contains("987654") and not text.contains("opponent-ledger") and not text.contains("opponent-inventory"), "opponent private economy is absent")
	_expect(text.contains("商品销售同时产生净现金和商品GDP"), "v0.6 sale receipt semantics are explicit")
	_expect(not text.contains("合约签拒") and not text.contains("修商路") and not text.contains("城市业主"), "retired economy terms are absent")
	_expect(TablePresentationPureDataPolicy.is_pure_data(snapshot), "presentation snapshot is pure data")
	var mismatch := _source()
	(mismatch["own_private_economy"] as Dictionary)["subject_index"] = 1
	_expect((service.compose(mismatch).get("dashboard", {}) as Dictionary).get("kpis", []).is_empty(), "viewer subject mismatch fails closed")
	_expect((service.compose({"valid": false}).get("dashboard", {}) as Dictionary).get("kpis", []).is_empty(), "missing data fails closed")
	_finish()


func _source() -> Dictionary:
	return {
		"contract_version": "economy_dashboard_viewer_source.v1", "valid": true,
		"viewer_context": {"viewer_index": 0, "authorized": true},
		"public_player_summaries": [{"subject_index": 0, "name": "我"}, {"subject_index": 1, "name": "对手"}],
		"public_commodity_entries": [{"commodity_id": "energy", "name": "能源", "price": 80, "supply": 2, "demand": 5, "pressure": 3, "price_band_label": "中价", "weather_summary": "稳定"}],
		"public_region_economy_entries": [{"region_id": "r1", "commodity_gdp_per_minute": 90}],
		"public_facility_entries": [{"region_id": "r1", "facility_type": "market", "industry_id": "energy", "rank": 2}],
		"public_region_integrity_entries": [{"region_id": "r1", "integrity_basis_points": 8000, "facility_count": 2, "lifecycle_state": "active"}],
		"public_route_summaries": [{"source_region_id": "r1", "market_region_id": "r2", "transport_mode": "land", "capacity_units_per_minute": 20, "weather_multiplier": 1.0, "bottleneck": false}],
		"public_warehouse_risk_entries": [{"region_id": "r1", "public_warehouse_count": 1}],
		"public_weather": {"short_text": "天气稳定"}, "public_monster_pressure": [], "public_log_clues": [],
		"own_private_economy": {"visibility_scope": "viewer_private", "viewer_index": 0, "subject_index": 0, "authorized_private": true, "name": "我", "exact_cash": 600, "commodity_gdp_per_minute": 120, "sale_receipts": [{"commodity_id": "energy", "gdp_value": 20, "owner_net_cash": 18, "storage_rent_cents": 2}], "warehouses": [], "facilities": []},
		"layout": {"kpi_columns": 4, "lane_columns": 3, "overview_columns": 4},
	}


func _expect(value: bool, message: String) -> void:
	if not value: failures.append(message); push_error("ECONOMY SNAPSHOT: %s" % message)


func _finish() -> void:
	print("ECONOMY DASHBOARD PUBLIC SNAPSHOT SERVICE %s" % ("PASS" if failures.is_empty() else "FAIL: %d" % failures.size()))
	quit(0 if failures.is_empty() else 1)
