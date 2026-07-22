extends SceneTree

const SUPPORT := preload("res://tests/support/commodity_flow_v06_test_support.gd")

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_current_roundtrip_and_transactional_rejection()
	_verify_one_time_legacy_waste_migration()
	print("COMMODITY_FLOW_BACKLOG_SAVE_ROUNDTRIP_V06_TEST|status=%s|checks=%d|failures=%d" % [
		"PASS" if _failures.is_empty() else "FAIL",
		_checks,
		_failures.size(),
	])
	quit(_failures.size())


func _verify_current_roundtrip_and_transactional_rejection() -> void:
	var region := SUPPORT.region("region.save")
	var factory := SUPPORT.facility("factory.save", "region.save", "factory", 0)
	var market := SUPPORT.facility("market.save", "region.save", "market", 1)
	var warehouse := SUPPORT.facility("warehouse.save", "region.save", "warehouse", 2)
	var route := SUPPORT.route("local:save", "region.save", "region.save", 15, "local:save", ["local"], 0)
	var fixture := SUPPORT.create_fixture(self, [region], [factory, market, warehouse], [route])
	var flow: Node = fixture.get("flow")
	var bridge = fixture.get("bridge")
	_expect(bool(SUPPORT.install(flow, factory, SUPPORT.DEFAULT_PRODUCT_ID, "production", 0, 2, false, "save-factory-install").get("finalized", false)), "save fixture production installs")
	_expect(bool(SUPPORT.install(flow, market, SUPPORT.DEFAULT_PRODUCT_ID, "demand", 1, 1, false, "save-market-install").get("finalized", false)), "save fixture demand installs")
	SUPPORT.advance(flow, bridge, 60.0, 60.0)
	bridge.facts["route_candidates"] = []
	SUPPORT.advance(flow, bridge, 60.5, 60.0)
	var saved: Dictionary = flow.call("to_save_data")
	_expect(int(saved.get("state_version", 0)) == 3 and int(saved.get("commodity_flow_terms_version", 0)) == 2, "new save writes the post-commit-lineage schema with current continuous-economy terms")
	_expect(not saved.has("backpressured_milliunits_by_source"), "new save never rewrites the migrated legacy overflow field")
	_expect(not (saved.get("market_backlog_by_key", {}) as Dictionary).is_empty() and not (saved.get("warehouse_inventory", {}) as Dictionary).is_empty(), "save contains concrete backlog and warehouse inventory together")
	_expect(not (saved.get("cumulative_wasted_milliunits_by_source", {}) as Dictionary).is_empty() and int(saved.get("waste_revision", 0)) > 0, "save contains exact current and cumulative waste state")
	_expect(not (saved.get("ambient_rate_remainders", {}) as Dictionary).is_empty() and int(saved.get("ambient_revision", 0)) > 0, "save contains ambient fixed-point continuation")
	var restored_fixture := SUPPORT.create_fixture(
		self,
		[region],
		[factory, market, warehouse],
		[],
		{SUPPORT.DEFAULT_PRODUCT_ID: SUPPORT.DEFAULT_PRICE_CENTS}
	)
	var restored_flow: Node = restored_fixture.get("flow")
	var restored_bridge = restored_fixture.get("bridge")
	restored_bridge.facts["game_time"] = float(bridge.facts.get("game_time", 0.0))
	var applied: Dictionary = restored_flow.call("apply_save_data", saved)
	_expect(bool(applied.get("applied", false)), "current save applies through the public transactional restore API")
	_expect(JSON.stringify(saved) == JSON.stringify(restored_flow.call("to_save_data")), "load is non-advancing and restores backlog, inventory, waste, remainders, receipts, and sequences exactly")
	_expect(restored_bridge.committed_receipts.is_empty(), "load emits no Sale Receipt and applies no cash")
	var corrupt := saved.duplicate(true)
	corrupt["market_backlog_by_key"] = {"invalid": {"unmet_backlog_milliunits": -1}}
	var before_corrupt := JSON.stringify(restored_flow.call("to_save_data"))
	var rejected: Dictionary = restored_flow.call("apply_save_data", corrupt)
	_expect(not bool(rejected.get("applied", false)) and before_corrupt == JSON.stringify(restored_flow.call("to_save_data")), "invalid restore fails closed without partial state mutation")
	var original_next: Dictionary = SUPPORT.advance(flow, bridge, 1.25, 1.25)
	var restored_next: Dictionary = SUPPORT.advance(restored_flow, restored_bridge, 1.25, 1.25)
	_expect(JSON.stringify(original_next) == JSON.stringify(restored_next), "restored fixed-point state produces the exact same next authoritative tick")
	_expect(JSON.stringify(flow.call("to_save_data")) == JSON.stringify(restored_flow.call("to_save_data")), "continued save state remains byte-equivalent after the same next tick")
	SUPPORT.free_fixture(fixture)
	SUPPORT.free_fixture(restored_fixture)


func _verify_one_time_legacy_waste_migration() -> void:
	var region := SUPPORT.region("region.legacy")
	var factory := SUPPORT.facility("factory.legacy", "region.legacy", "factory", 0)
	var warehouse := SUPPORT.facility("warehouse.legacy", "region.legacy", "warehouse", 1)
	var route := SUPPORT.route("local:legacy", "region.legacy", "region.legacy", 1000000, "local:legacy", ["local"], 0)
	var source_fixture := SUPPORT.create_fixture(self, [region], [factory, warehouse], [route])
	var source_flow: Node = source_fixture.get("flow")
	var source_bridge = source_fixture.get("bridge")
	SUPPORT.install(source_flow, factory, SUPPORT.DEFAULT_PRODUCT_ID, "production", 0, 1, false, "legacy-source-install")
	SUPPORT.advance(source_flow, source_bridge, 60.0, 60.0)
	var current: Dictionary = source_flow.call("to_save_data")
	var inventory_before: Dictionary = (current.get("warehouse_inventory", {}) as Dictionary).duplicate(true)
	var legacy := current.duplicate(true)
	legacy["state_version"] = 1
	legacy["local_baseline_terms_version"] = 1
	legacy["backpressured_milliunits_by_source"] = {"legacy-source-install": 7000}
	for field_name in [
		"commodity_flow_terms_version",
		"ambient_consumption_default_units_per_minute",
		"ambient_consumption_units_per_minute_by_commodity",
		"ambient_consumption_value_basis_points",
		"market_backlog_horizon_seconds",
		"market_backlog_recovery_extra_basis_points",
		"ambient_rate_remainders",
		"ambient_fairness_cursor_by_region_commodity",
		"ambient_revision",
		"market_backlog_by_key",
		"wasted_continuous_milliunits_by_source",
		"wasted_continuous_milliunits_per_minute_by_source",
		"cumulative_wasted_milliunits_by_source",
		"cumulative_wasted_milliunits_by_commodity",
		"cumulative_wasted_milliunits_by_region",
		"waste_revision",
		"recent_flow_loss_events",
		"recent_flow_events",
		"legacy_backpressure_migration_version",
	]:
		legacy.erase(field_name)
	var target_fixture := SUPPORT.create_fixture(self, [region], [factory, warehouse], [route])
	var target_flow: Node = target_fixture.get("flow")
	var migrated: Dictionary = target_flow.call("apply_save_data", legacy)
	_expect(bool(migrated.get("applied", false)) and bool(migrated.get("migrated_legacy_backpressure", false)), "state-v1 overflow is accepted only through the explicit migration path")
	var migrated_save: Dictionary = target_flow.call("to_save_data")
	_expect(int(migrated_save.get("legacy_backpressure_migration_version", 0)) == 1 and not migrated_save.has("backpressured_milliunits_by_source"), "migration records terminal lineage and never rewrites the legacy field")
	_expect(int((migrated_save.get("cumulative_wasted_milliunits_by_source", {}) as Dictionary).get("legacy-source-install", 0)) == 7000, "legacy non-sale quantity becomes cumulative waste history exactly once")
	_expect(JSON.stringify(inventory_before) == JSON.stringify(migrated_save.get("warehouse_inventory", {})), "legacy migration does not turn waste into goods or otherwise change inventory")
	var ambiguous := legacy.duplicate(true)
	ambiguous["cumulative_wasted_milliunits_by_source"] = {"legacy-source-install": 1}
	var before_ambiguous := JSON.stringify(target_flow.call("to_save_data"))
	var ambiguous_result: Dictionary = target_flow.call("apply_save_data", ambiguous)
	_expect(not bool(ambiguous_result.get("applied", false)) and str(ambiguous_result.get("reason", "")) == "legacy_backpressure_migration_ambiguous" and before_ambiguous == JSON.stringify(target_flow.call("to_save_data")), "payload containing both legacy overflow and new waste authority fails closed")
	var invalid_source := legacy.duplicate(true)
	invalid_source.erase("local_baseline_terms_version")
	var invalid_result: Dictionary = target_flow.call("apply_save_data", invalid_source)
	_expect(not bool(invalid_result.get("applied", false)) and str(invalid_result.get("reason", "")) == "legacy_backpressure_migration_source_invalid", "legacy migration validates its exact source schema version")
	SUPPORT.free_fixture(source_fixture)
	SUPPORT.free_fixture(target_fixture)


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		return
	_failures.append(message)
	push_error(message)
