extends SceneTree

const SUPPORT := preload("res://tests/support/commodity_flow_v06_test_support.gd")

const ACTUAL_FLOW_ALLOWED_KEYS := [
	"flow_event_id",
	"public_revision",
	"commodity_id",
	"from_region_id",
	"to_region_id",
	"flow_kind",
	"display_label",
	"route_id",
	"transport_modes",
	"delivered_units_band",
	"capacity_limited",
	"congested",
	"last_active_world_effective",
	"activity_state",
	"ambient_one_hop",
	"low_emphasis",
]

const FORBIDDEN_PUBLIC_TOKENS := [
	"commodity_owner",
	"owner_net_cash",
	"source_installation",
	"demand_installation",
	"source_factory",
	"player_index",
	"transaction_id",
	"batch_transaction",
	"storage_rent_debt",
	"remainder",
	"pair_id",
	"candidate",
	"fingerprint",
	"ai_plan",
	"private_sentinel",
]

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var region := SUPPORT.region("region.public")
	var factory := SUPPORT.facility("factory.public", "region.public", "factory", 0)
	var market := SUPPORT.facility("market.public", "region.public", "market", 1)
	var warehouse := SUPPORT.facility("warehouse.public", "region.public", "warehouse", 2)
	var route := SUPPORT.route("local:public", "region.public", "region.public", 15, "local:public", ["local"], 0)
	var fixture := SUPPORT.create_fixture(self, [region], [factory, market, warehouse], [route])
	var flow: Node = fixture.get("flow")
	var bridge = fixture.get("bridge")
	SUPPORT.install(flow, factory, SUPPORT.DEFAULT_PRODUCT_ID, "production", 0, 2, false, "public-factory-install")
	SUPPORT.install(flow, market, SUPPORT.DEFAULT_PRODUCT_ID, "demand", 1, 1, false, "public-market-install")
	SUPPORT.advance(flow, bridge, 60.0, 60.0)
	bridge.facts["facilities"] = [market, warehouse]
	bridge.facts["destroyed_facility_ids"] = ["factory.public"]
	SUPPORT.advance(flow, bridge, 1.0, 1.0)
	_verify_actual_flow_projection(flow)
	_verify_other_public_projections(flow)
	_verify_allowlist_survives_malicious_saved_event(flow)
	SUPPORT.free_fixture(fixture)
	print("COMMODITY_FLOW_PUBLIC_PRIVACY_V06_TEST|status=%s|checks=%d|failures=%d" % [
		"PASS" if _failures.is_empty() else "FAIL",
		_checks,
		_failures.size(),
	])
	quit(_failures.size())


func _verify_actual_flow_projection(flow: Node) -> void:
	var projection: Dictionary = flow.call("recent_actual_flow_snapshot")
	_expect(bool(projection.get("available", false)) and int(projection.get("public_revision", 0)) > 0, "actual-flow public wrapper exposes only availability and public revision metadata")
	var rows: Array = projection.get("rows", [])
	_expect(rows.size() >= 4, "recent actual-flow window includes market sale, ambient, warehouse inbound, and warehouse outbound")
	var kinds: Dictionary = {}
	var event_ids: Dictionary = {}
	for row_variant in rows:
		var row: Dictionary = row_variant
		for key_variant in row.keys():
			_expect(ACTUAL_FLOW_ALLOWED_KEYS.has(str(key_variant)), "actual-flow row contains only allowlisted fields")
		var event_id := str(row.get("flow_event_id", ""))
		_expect(not event_id.is_empty() and not event_ids.has(event_id), "actual-flow event ID is stable and unique")
		event_ids[event_id] = true
		var flow_kind := str(row.get("flow_kind", ""))
		kinds[flow_kind] = true
		_expect(["market_sale", "warehouse_inbound", "warehouse_outbound", "ambient_consumption"].has(flow_kind), "flow kind is a stable machine enum")
		_expect(["trace", "low", "medium", "high", "bulk"].has(str(row.get("delivered_units_band", ""))), "quantity is exposed only as a player-readable band")
		_expect(["current_tick", "recent"].has(str(row.get("activity_state", ""))), "activity state is current-tick or recent")
		if flow_kind == "ambient_consumption":
			_expect(str(row.get("route_id", "x")).is_empty() and (row.get("transport_modes", []) as Array).is_empty() and bool(row.get("low_emphasis", false)), "ambient flow is low-emphasis and fabricates no route geometry")
	_expect(kinds.has("market_sale") and kinds.has("warehouse_inbound") and kinds.has("warehouse_outbound") and kinds.has("ambient_consumption"), "all four public actual-flow kinds are represented")
	_expect(_contains_no_forbidden_tokens(projection), "actual-flow projection exposes no facility, installation, owner, cash, transaction, remainder, candidate, or AI-private fields")
	var filtered: Dictionary = flow.call("recent_actual_flow_snapshot", SUPPORT.DEFAULT_PRODUCT_ID)
	_expect((filtered.get("rows", []) as Array).size() == rows.size(), "commodity filter keeps exactly the matching committed flow rows")


func _verify_other_public_projections(flow: Node) -> void:
	var receipts: Array = flow.call("recent_sale_receipts_snapshot", -1)
	_expect(not receipts.is_empty() and _contains_no_forbidden_tokens(receipts), "public Sale Receipts remove supplier identity, private owner cash, installation, and observer lineage")
	var inventory: Array = flow.call("warehouse_inventory_snapshot", -1)
	_expect(not inventory.is_empty(), "public warehouse projection exposes aggregate stored goods")
	for row_variant in inventory:
		var row: Dictionary = row_variant
		_expect(not row.has("bucket_id") and not row.has("owner_player_index") and not row.has("source_installation_id") and not row.has("source_factory_id") and not row.has("storage_rent_debt_cents"), "public inventory removes private bucket, supplier, commodity owner, and debt detail")
	var backlog: Dictionary = flow.call("public_market_backlog_snapshot")
	_expect(not (backlog.get("rows", []) as Array).is_empty() and _contains_no_forbidden_tokens(backlog), "public backlog exposes commodity/facility demand status without supplier or fixed-point internals")
	var waste: Dictionary = flow.call("public_waste_summary_snapshot")
	_expect(_contains_no_forbidden_tokens(waste), "public waste summary is aggregate by commodity/region and reveals no source identity")


func _verify_allowlist_survives_malicious_saved_event(flow: Node) -> void:
	var saved: Dictionary = flow.call("to_save_data")
	var events: Array = (saved.get("recent_flow_events", []) as Array).duplicate(true)
	events.append({
		"flow_event_id": "malicious-private-event",
		"public_revision": 999,
		"internal_flow_kind": "market",
		"source_kind": "continuous",
		"commodity_id": SUPPORT.DEFAULT_PRODUCT_ID,
		"source_region_id": "region.public",
		"market_region_id": "region.public",
		"route_id": "local:public",
		"transport_modes": ["local"],
		"quantity_units": 1.0,
		"settled_at": 61.0,
		"commodity_owner": 7,
		"owner_net_cash": 999999,
		"source_installation_id": "private_sentinel",
		"transaction_id": "private_sentinel",
		"candidate_route": "private_sentinel",
	})
	saved["recent_flow_events"] = events
	var applied: Dictionary = flow.call("apply_save_data", saved)
	_expect(bool(applied.get("applied", false)), "pure authoritative save may contain richer private internal event state")
	var projection: Dictionary = flow.call("recent_actual_flow_snapshot")
	_expect(not JSON.stringify(projection).contains("private_sentinel") and _contains_no_forbidden_tokens(projection), "public allowlist projection strips malicious or future private event fields recursively")


func _contains_no_forbidden_tokens(value: Variant) -> bool:
	var serialized := JSON.stringify(value).to_lower()
	for token_variant in FORBIDDEN_PUBLIC_TOKENS:
		if serialized.contains(str(token_variant).to_lower()):
			return false
	return true


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		return
	_failures.append(message)
	push_error(message)
