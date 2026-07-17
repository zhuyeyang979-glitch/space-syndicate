@tool
extends Node
class_name EconomyDashboardViewerQueryPort

## Strict read-only economy presentation boundary. It returns only public facts
## plus the authorized local viewer's own private economy facts.

@export var table_query_ports_path: NodePath
@export var world_session_state_path: NodePath
@export var product_market_path: NodePath
@export var commodity_flow_path: NodePath
@export var route_network_path: NodePath
@export var region_infrastructure_path: NodePath
@export var weather_runtime_path: NodePath
@export var monster_runtime_path: NodePath
@export var snapshot_service_path: NodePath

var _query_count := 0
var _rejected_count := 0
var _last_viewer_index := -1


func snapshot_for_authorized_viewer(content_width: float = 960.0) -> Dictionary:
	var query_ports := _table_query_ports()
	var world_state := _world_session_state()
	var market := _product_market()
	var flow := _commodity_flow()
	var routes := _route_network()
	var infrastructure := _region_infrastructure()
	var weather := _weather_runtime()
	var monsters := _monster_runtime()
	var service := _snapshot_service()
	if query_ports == null or world_state == null or market == null or flow == null or routes == null or infrastructure == null or weather == null or monsters == null or service == null:
		return _reject(service, "dependency_missing")
	var context := query_ports.viewer_context()
	var public_world := query_ports.public_world_projection()
	if not context.authorized or public_world.players.is_empty():
		return _reject(service, "viewer_unauthorized")
	var viewer_index := context.viewer_index
	var private_world := query_ports.private_world_projection(viewer_index, viewer_index)
	if not private_world.authorized or private_world.subject_index != viewer_index:
		return _reject(service, "viewer_subject_mismatch")
	var market_snapshot := market.public_market_snapshot()
	if not bool(market_snapshot.get("catalog_ready", false)):
		return _reject(service, "catalog_not_ready")
	var infrastructure_snapshot := infrastructure.public_economy_snapshot()
	var own_facilities := infrastructure.own_facilities_snapshot(viewer_index)
	if not bool(own_facilities.get("authorized", false)) or int(own_facilities.get("subject_index", -1)) != viewer_index:
		return _reject(service, "own_facilities_unauthorized")
	var source := {
		"contract_version": "economy_dashboard_viewer_source.v1",
		"valid": true,
		"viewer_context": {
			"viewer_index": viewer_index,
			"authorized": true,
			"authorization_revision": context.authorization_revision,
			"visibility_scope": "viewer_private",
		},
		"lifecycle": world_state.public_lifecycle_snapshot(),
		"public_player_summaries": _public_player_summaries(public_world.players),
		"public_commodity_entries": _public_commodity_entries(market_snapshot),
		"public_region_economy_entries": flow.public_regional_gdp_snapshot().get("rows", []),
		"public_facility_entries": infrastructure_snapshot.get("facilities", []),
		"public_region_integrity_entries": infrastructure_snapshot.get("regions", []),
		"public_route_summaries": routes.public_cached_route_snapshot().get("rows", []),
		"public_actual_flow": flow.public_actual_flow_snapshot(),
		"public_market_backlog": flow.public_market_backlog_snapshot(),
		"public_waste": flow.public_waste_summary_snapshot(),
		"public_warehouse_risk_entries": _public_warehouse_risk(infrastructure_snapshot.get("facilities", [])),
		"public_weather": weather.public_snapshot(),
		"public_weather_economy": flow.public_weather_contribution_snapshot(),
		"public_monster_pressure": _public_monster_pressure(monsters.roster_snapshot(false)),
		"public_log_clues": query_ports.recent_public_log_entries(8),
		"own_private_economy": _own_private_economy(viewer_index, private_world.player, flow, own_facilities),
		"layout": {
			"kpi_columns": clampi(int(floor(maxf(260.0, content_width) / 230.0)), 1, 4),
			"lane_columns": clampi(int(floor(maxf(260.0, content_width) / 300.0)), 1, 3),
			"overview_columns": clampi(int(floor(maxf(260.0, content_width) / 280.0)), 1, 4),
		},
	}
	if not _source_contract_valid(source, viewer_index) or not TablePresentationPureDataPolicy.is_pure_data(source):
		return _reject(service, "source_contract_invalid")
	_query_count += 1
	_last_viewer_index = viewer_index
	return service.compose(source)


func debug_snapshot() -> Dictionary:
	return {
		"port_id": "economy_dashboard_viewer_query_port_v06",
		"query_count": _query_count,
		"rejected_count": _rejected_count,
		"last_viewer_index": _last_viewer_index,
		"viewer_authorization_required": true,
		"refreshes_catalog": false,
		"refreshes_routes": false,
		"mutates_world": false,
		"reveals_all_on_session_finish": false,
		"references_main": false,
	}


func _reject(service: EconomyDashboardPublicSnapshotService, reason: String) -> Dictionary:
	_rejected_count += 1
	return service.compose({"valid": false, "reason_code": reason}) if service != null else {}


func _public_player_summaries(players: Array) -> Array:
	var rows: Array = []
	for player_variant in players:
		if player_variant is Dictionary:
			var player := player_variant as Dictionary
			rows.append({"subject_index": int(player.get("player_index", -1)), "name": str(player.get("public_player_name", "玩家")), "eliminated": bool(player.get("eliminated", false)), "visibility_scope": "public"})
	return rows


func _public_commodity_entries(market_snapshot: Dictionary) -> Array:
	var rows: Array = []
	var products: Dictionary = market_snapshot.get("product_market", {}) if market_snapshot.get("product_market", {}) is Dictionary else {}
	var product_ids: Array = products.keys()
	product_ids.sort()
	for product_id_variant in product_ids:
		var product_id := str(product_id_variant)
		var entry: Dictionary = products.get(product_id_variant, {}) if products.get(product_id_variant, {}) is Dictionary else {}
		var price := maxi(0, int(entry.get("price", entry.get("current_price", 0))))
		rows.append({
			"commodity_id": product_id,
			"name": str(entry.get("name", product_id)),
			"price": price,
			"supply": maxi(0, int(entry.get("supply", entry.get("market_supply", 0)))),
			"demand": maxi(0, int(entry.get("demand", entry.get("market_demand", 0)))),
			"pressure": int(entry.get("pressure", entry.get("price_modifier", 0))),
			"price_band_label": _price_band(price),
			"weather_summary": str(entry.get("weather_driver_summary", "无天气价格影响")),
			"visibility_scope": "public",
		})
	return rows


func _price_band(price: int) -> String:
	if price >= 100: return "高价"
	if price >= 50: return "中价"
	return "低价"


func _public_warehouse_risk(facilities: Variant) -> Array:
	var by_region: Dictionary = {}
	if facilities is Array:
		for facility_variant in facilities:
			if not (facility_variant is Dictionary): continue
			var facility := facility_variant as Dictionary
			if str(facility.get("facility_type", "")) != "warehouse": continue
			var region_id := str(facility.get("region_id", ""))
			by_region[region_id] = int(by_region.get(region_id, 0)) + 1
	var rows: Array = []
	for region_id_variant in by_region.keys():
		rows.append({"region_id": str(region_id_variant), "public_warehouse_count": int(by_region[region_id_variant]), "risk_label": "仓储设施可能受区域压力影响", "visibility_scope": "public_anonymous"})
	return rows


func _public_monster_pressure(roster: Array) -> Array:
	var rows: Array = []
	for actor_variant in roster:
		if not (actor_variant is Dictionary): continue
		var actor := actor_variant as Dictionary
		rows.append({
			"slot": int(actor.get("slot", -1)),
			"name": str(actor.get("name", "怪兽")),
			"rank": clampi(int(actor.get("rank", 1)), 1, 4),
			"region_index": int(actor.get("position", actor.get("region_index", -1))),
			"down": bool(actor.get("down", false)),
			"pressure_label": "倒地" if bool(actor.get("down", false)) else "在场压力",
			"visibility_scope": "public",
		})
	return rows


func _own_private_economy(viewer_index: int, player: Dictionary, flow: CommodityFlowRuntimeController, own_facilities: Dictionary) -> Dictionary:
	var color_flow := flow.player_color_flow_snapshot(viewer_index)
	var gdp_per_minute := 0
	var colors: Dictionary = color_flow.get("colors", {}) if color_flow.get("colors", {}) is Dictionary else {}
	for row_variant in colors.values():
		if row_variant is Dictionary: gdp_per_minute += maxi(0, int((row_variant as Dictionary).get("gdp_per_minute", 0)))
	return {
		"visibility_scope": "viewer_private",
		"viewer_index": viewer_index,
		"subject_index": viewer_index,
		"authorized_private": true,
		"name": str(player.get("public_player_name", "当前玩家")),
		"exact_cash": int(player.get("cash", int(round(float(int(player.get("cash_cents", 0))) / 100.0)))),
		"commodity_gdp_per_minute": gdp_per_minute,
		"six_color_gdp": colors,
		"sale_receipts": _own_receipts(flow.recent_sale_receipts_snapshot(viewer_index), viewer_index),
		"warehouses": _own_warehouses(flow.warehouse_inventory_snapshot(viewer_index), viewer_index),
		"facilities": own_facilities.get("facilities", []),
	}


func _own_receipts(receipts: Array, viewer_index: int) -> Array:
	var rows: Array = []
	for receipt_variant in receipts:
		if not (receipt_variant is Dictionary): continue
		var receipt := receipt_variant as Dictionary
		if int(receipt.get("commodity_owner", -1)) != viewer_index: continue
		rows.append({
			"commodity_id": str(receipt.get("commodity_id", "")),
			"market_region_id": str(receipt.get("market_region_id", "")),
			"settled_at": float(receipt.get("settled_at", 0.0)),
			"gdp_value": maxi(0, int(receipt.get("gdp_value", 0))),
			"owner_net_cash": int(receipt.get("owner_net_cash", 0)),
			"storage_rent_cents": maxi(0, int(receipt.get("storage_rent_cents", 0))),
			"visibility_scope": "viewer_private",
		})
		if rows.size() >= 8: break
	return rows


func _own_warehouses(warehouses: Array, viewer_index: int) -> Array:
	var rows: Array = []
	for warehouse_variant in warehouses:
		if not (warehouse_variant is Dictionary): continue
		var warehouse := warehouse_variant as Dictionary
		if int(warehouse.get("owner_player_index", -1)) != viewer_index: continue
		rows.append({
			"region_id": str(warehouse.get("region_id", "")),
			"commodity_id": str(warehouse.get("commodity_id", "")),
			"quantity_milliunits": maxi(0, int(warehouse.get("quantity_milliunits", warehouse.get("stored_milliunits", 0)))),
			"visibility_scope": "viewer_private",
		})
		if rows.size() >= 8: break
	return rows


func _source_contract_valid(source: Dictionary, viewer_index: int) -> bool:
	var own: Dictionary = source.get("own_private_economy", {}) if source.get("own_private_economy", {}) is Dictionary else {}
	return str(source.get("contract_version", "")) == "economy_dashboard_viewer_source.v1" \
		and bool(source.get("valid", false)) \
		and bool(own.get("authorized_private", false)) \
		and int(own.get("viewer_index", -1)) == viewer_index \
		and int(own.get("subject_index", -1)) == viewer_index \
		and not source.has("player_cash_entries") \
		and not source.has("private")


func _table_query_ports() -> TablePresentationQueryPorts: return get_node_or_null(table_query_ports_path) as TablePresentationQueryPorts
func _world_session_state() -> WorldSessionState: return get_node_or_null(world_session_state_path) as WorldSessionState
func _product_market() -> ProductMarketRuntimeController: return get_node_or_null(product_market_path) as ProductMarketRuntimeController
func _commodity_flow() -> CommodityFlowRuntimeController: return get_node_or_null(commodity_flow_path) as CommodityFlowRuntimeController
func _route_network() -> RouteNetworkRuntimeController: return get_node_or_null(route_network_path) as RouteNetworkRuntimeController
func _region_infrastructure() -> RegionInfrastructureRuntimeController: return get_node_or_null(region_infrastructure_path) as RegionInfrastructureRuntimeController
func _weather_runtime() -> WeatherRuntimeController: return get_node_or_null(weather_runtime_path) as WeatherRuntimeController
func _monster_runtime() -> MonsterRuntimeController: return get_node_or_null(monster_runtime_path) as MonsterRuntimeController
func _snapshot_service() -> EconomyDashboardPublicSnapshotService: return get_node_or_null(snapshot_service_path) as EconomyDashboardPublicSnapshotService
