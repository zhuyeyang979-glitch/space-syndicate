@tool
extends Node
class_name VictoryControlWorldBridge

const BRIDGE_ID := "victory_control_world_bridge_v06"
const CURRENCY_SCALE := 100

var _world: Node
var _world_session_state: WorldSessionState
var _region_infrastructure_controller: Node
var _commodity_flow_controller: Node
var _product_market_controller: Node
var _city_gdp_derivative_controller: Node
var _military_controller: Node
var _capture_count := 0


func bind_world(world: Node) -> void:
	_world = world


func set_world_session_state(state: WorldSessionState) -> void:
	_world_session_state = state


func world_session_state() -> WorldSessionState:
	return _world_session_state


func set_runtime_dependencies(region_infrastructure_controller: Node, commodity_flow_controller: Node, product_market_controller: Node, city_gdp_derivative_controller: Node, military_controller: Node) -> void:
	_region_infrastructure_controller = region_infrastructure_controller
	_commodity_flow_controller = commodity_flow_controller
	_product_market_controller = product_market_controller
	_city_gdp_derivative_controller = city_gdp_derivative_controller
	_military_controller = military_controller


func has_world() -> bool:
	return _world != null and is_instance_valid(_world)


func reset_state() -> void:
	_capture_count = 0


func capture_world_snapshot(clock_pause: Dictionary = {}, settlement_checkpoint := "read_only") -> Dictionary:
	if not has_world() or _region_infrastructure_controller == null or _commodity_flow_controller == null:
		return {}
	_capture_count += 1
	var players_variant: Variant = _world_session_state.players if _world_session_state != null else []
	var players: Array = players_variant if players_variant is Array else []
	var region_rows: Array = []
	var runtime_regions_variant: Variant = _region_infrastructure_controller.call("regions_snapshot") if _region_infrastructure_controller.has_method("regions_snapshot") else []
	var runtime_regions: Array = runtime_regions_variant if runtime_regions_variant is Array else []
	for region_variant in runtime_regions:
		if not (region_variant is Dictionary):
			continue
		var region: Dictionary = region_variant
		var region_id := str(region.get("region_id", ""))
		if region_id.is_empty():
			continue
		var public_gdp_variant: Variant = _commodity_flow_controller.call("region_gdp_snapshot", region_id) if _commodity_flow_controller.has_method("region_gdp_snapshot") else {}
		var public_gdp: Dictionary = public_gdp_variant if public_gdp_variant is Dictionary else {}
		var player_gdp_by_index: Dictionary = public_gdp.get("player_gdp_per_minute_cents_by_index", {}) if public_gdp.get("player_gdp_per_minute_cents_by_index", {}) is Dictionary else {}
		region_rows.append({
			"region_id": region_id,
			"district_index": int(region.get("legacy_index", -1)),
			"lifecycle_state": str(region.get("lifecycle_state", "undeveloped")),
			"destroyed": str(region.get("lifecycle_state", "undeveloped")) == "ruined",
			"region_generation": int(region.get("generation", 1)),
			"region_revision": int(region.get("revision", 0)),
			"region_gdp_per_minute_cents": int(public_gdp.get("region_gdp_per_minute_cents", 0)),
			"region_gdp_per_minute": int(public_gdp.get("region_gdp_per_minute", 0)),
			"player_gdp_by_index": player_gdp_by_index,
		})
	var player_rows: Array = []
	for player_index in range(players.size()):
		var player: Dictionary = players[player_index] if players[player_index] is Dictionary else {}
		var available_cents := int(player.get("cash_cents", int(player.get("cash", 0)) * CURRENCY_SCALE))
		# Wager commitments remain inside MonsterRuntimeController and are applied
		# only in the atomic settlement swap; VictoryControl has no cash escrow.
		var escrow_cents := 0
		player_rows.append({
			"player_index": player_index,
			"eliminated": _player_eliminated(player_index, player),
			"available_cents": available_cents,
			"escrow_cents": escrow_cents,
			"cash_ledger_cents": available_cents + escrow_cents,
			"audit_assets": {
				"available_cents": available_cents,
				"escrow_cents": escrow_cents,
				"cash_ledger_cents": available_cents + escrow_cents,
				"ordinary_hand": _ordinary_hand_snapshot(player),
				"facilities": _facility_assets(player_index),
				"installations": _installation_assets(player_index),
				"commodity_inventory": _commodity_inventory_assets(player_index),
				"color_gdp": _color_gdp_snapshot(player_index),
				"units": _unit_assets(player_index),
				"financial_positions": _financial_assets(player_index),
			},
		})
	return {
		"schema_version": "v0.6.victory-world.2",
		"players": player_rows,
		"regions": region_rows,
		"clock_pause": clock_pause.duplicate(true) if _is_data_only(clock_pause) else {},
		"settlement_checkpoint": settlement_checkpoint,
		"ordering_receipt": _ordering_receipt(settlement_checkpoint),
		"visibility_scope": "controller_private",
	}


func debug_snapshot() -> Dictionary:
	return {
		"bridge_id": BRIDGE_ID,
		"bridge_ready": has_world() and _region_infrastructure_controller != null and _commodity_flow_controller != null,
		"capture_count": _capture_count,
		"owns_gdp_formula": false,
		"region_lifecycle_source": "RegionInfrastructureRuntimeController",
		"gdp_source": "CommodityFlowRuntimeController.sale_receipts",
		"owns_project_attribution": false,
		"owns_victory_state": false,
		"owns_session_state": false,
		"pure_fact_bridge": true,
		"world_session_state_ready": _world_session_state != null,
	}


func _player_eliminated(player_index: int, player: Dictionary) -> bool:
	return bool(_world.call("_player_is_eliminated", player_index)) if _world.has_method("_player_is_eliminated") else bool(player.get("eliminated", false))


func _ordinary_hand_snapshot(player: Dictionary) -> Array:
	var result: Array = []
	for skill_variant in player.get("skills", []):
		if skill_variant is Dictionary and not bool((skill_variant as Dictionary).get("fixed", false)):
			var skill: Dictionary = skill_variant
			result.append({
				"card_id": str(skill.get("card_id", skill.get("id", skill.get("name", "")))),
				"family_id": str(skill.get("family_id", skill.get("family", ""))),
				"rank": int(skill.get("rank", 1)),
				"kind": str(skill.get("kind", "")),
				"queued": bool(skill.get("queued", false)),
				"locked": bool(skill.get("locked", false)),
			})
	return result


func _facility_assets(player_index: int) -> Array:
	var result: Array = []
	if _region_infrastructure_controller == null or not _region_infrastructure_controller.has_method("facilities_snapshot"):
		return result
	var facilities_variant: Variant = _region_infrastructure_controller.call("facilities_snapshot", false)
	if not (facilities_variant is Array):
		return result
	for facility_variant in facilities_variant:
		if not (facility_variant is Dictionary):
			continue
		var facility: Dictionary = facility_variant
		if str(facility.get("owner_kind", "")) != "player" or int(facility.get("owner_player_index", -1)) != player_index:
			continue
		result.append({
			"facility_id": str(facility.get("facility_id", "")),
			"region_id": str(facility.get("region_id", "")),
			"facility_type": str(facility.get("facility_type", "")),
			"industry_id": str(facility.get("industry_id", "")),
			"rank": int(facility.get("rank", 1)),
			"generation": int(facility.get("generation", 1)),
			"active": bool(facility.get("active", false)),
		})
	return result


func _installation_assets(player_index: int) -> Array:
	var result: Array = []
	if _commodity_flow_controller == null or not _commodity_flow_controller.has_method("installations_snapshot"):
		return result
	var installations_variant: Variant = _commodity_flow_controller.call("installations_snapshot", false)
	if not (installations_variant is Array):
		return result
	for installation_variant in installations_variant:
		if not (installation_variant is Dictionary):
			continue
		var installation: Dictionary = installation_variant
		if int(installation.get("installer_player_index", -1)) != player_index:
			continue
		result.append({
			"installation_id": str(installation.get("installation_id", "")),
			"commodity_id": str(installation.get("commodity_id", "")),
			"color": str(installation.get("color", "")),
			"direction": str(installation.get("direction", "")),
			"base_units_per_minute": int(installation.get("base_units_per_minute", 0)),
			"source_card_rank": int(installation.get("source_card_rank", 1)),
			"facility_id": str(installation.get("facility_id", "")),
			"region_id": str(installation.get("region_id", "")),
			"active": bool(installation.get("active", false)),
		})
	return result


func _commodity_inventory_assets(player_index: int) -> Array:
	var result: Array = []
	if _commodity_flow_controller == null or not _commodity_flow_controller.has_method("warehouse_inventory_snapshot"):
		return result
	var inventory_variant: Variant = _commodity_flow_controller.call("warehouse_inventory_snapshot", player_index)
	if not (inventory_variant is Array):
		return result
	for row_variant in inventory_variant:
		if not (row_variant is Dictionary):
			continue
		var row: Dictionary = row_variant
		if int(row.get("owner_player_index", -1)) != player_index:
			continue
		result.append({
			"warehouse_id": str(row.get("warehouse_id", "")),
			"commodity_id": str(row.get("commodity_id", "")),
			"color": str(row.get("color", "")),
			"stored_milliunits": int(row.get("stored_milliunits", 0)),
			"source_region_id": str(row.get("source_region_id", "")),
		})
	return result


func _color_gdp_snapshot(player_index: int) -> Dictionary:
	if _commodity_flow_controller == null or not _commodity_flow_controller.has_method("player_color_flow_snapshot"):
		return {}
	var snapshot_variant: Variant = _commodity_flow_controller.call("player_color_flow_snapshot", player_index)
	if not (snapshot_variant is Dictionary):
		return {}
	var snapshot: Dictionary = snapshot_variant
	return (snapshot.get("colors", {}) as Dictionary).duplicate(true) if snapshot.get("colors", {}) is Dictionary else {}


func _unit_assets(player_index: int) -> Array:
	var result: Array = []
	if _military_controller == null or not _military_controller.has_method("roster_snapshot"):
		return result
	var roster_variant: Variant = _military_controller.call("roster_snapshot", true)
	if not (roster_variant is Array):
		return result
	for unit_variant in roster_variant:
		if not (unit_variant is Dictionary):
			continue
		var unit: Dictionary = unit_variant
		if int(unit.get("owner", -1)) != player_index:
			continue
		result.append({
			"unit_uid": int(unit.get("uid", unit.get("unit_uid", -1))),
			"military_type": str(unit.get("military_type", "")),
			"rank": int(unit.get("rank", 1)),
			"district_index": int(unit.get("district_index", unit.get("current_district", -1))),
			"duration_remaining": float(unit.get("duration_remaining", 0.0)),
		})
	return result


func _financial_assets(player_index: int) -> Array:
	var result := _product_financial_positions(player_index)
	if _city_gdp_derivative_controller != null and _city_gdp_derivative_controller.has_method("runtime_state_snapshot"):
		var state_variant: Variant = _city_gdp_derivative_controller.call("runtime_state_snapshot")
		var state: Dictionary = state_variant if state_variant is Dictionary else {}
		var by_district: Dictionary = state.get("positions_by_district", {}) if state.get("positions_by_district", {}) is Dictionary else {}
		for positions_variant in by_district.values():
			if not (positions_variant is Array):
				continue
			for position_variant in positions_variant:
				if position_variant is Dictionary and int((position_variant as Dictionary).get("owner", -1)) == player_index:
					result.append(_sanitize_financial_position(position_variant as Dictionary, "city_gdp_derivative"))
	return result


func _product_financial_positions(player_index: int) -> Array:
	var result: Array = []
	if _product_market_controller == null or not _product_market_controller.has_method("runtime_state_snapshot"):
		return result
	var state_variant: Variant = _product_market_controller.call("runtime_state_snapshot")
	var state: Dictionary = state_variant if state_variant is Dictionary else {}
	var market: Dictionary = state.get("product_market", {}) if state.get("product_market", {}) is Dictionary else {}
	for product_variant in market.keys():
		var entry: Dictionary = market[product_variant] if market[product_variant] is Dictionary else {}
		for position_variant in entry.get("futures_positions", []):
			if position_variant is Dictionary and int((position_variant as Dictionary).get("owner", -1)) == player_index:
				var sanitized := _sanitize_financial_position(position_variant as Dictionary, "product_futures")
				sanitized["product_id"] = str(product_variant)
				result.append(sanitized)
	return result


func _sanitize_financial_position(position: Dictionary, position_kind: String) -> Dictionary:
	return {
		"position_kind": position_kind,
		"position_id": int(position.get("position_id", -1)),
		"product_id": str(position.get("product", position.get("product_id", ""))),
		"direction": str(position.get("direction", "")),
		"district_index": int(position.get("district_index", position.get("warehouse_district", -1))),
		"warehouse_district": int(position.get("warehouse_district", -1)),
		"locked_margin_cents": int(position.get("locked_margin", 0)) * CURRENCY_SCALE,
		"maximum_gain_cents": int(position.get("maximum_gain", 0)) * CURRENCY_SCALE,
		"maximum_loss_cents": int(position.get("maximum_loss", 0)) * CURRENCY_SCALE,
	}


func _ordering_receipt(settlement_checkpoint: String) -> Dictionary:
	var region_debug_variant: Variant = _region_infrastructure_controller.call("debug_snapshot") if _region_infrastructure_controller != null and _region_infrastructure_controller.has_method("debug_snapshot") else {}
	var flow_debug_variant: Variant = _commodity_flow_controller.call("debug_snapshot") if _commodity_flow_controller != null and _commodity_flow_controller.has_method("debug_snapshot") else {}
	var region_debug: Dictionary = region_debug_variant if region_debug_variant is Dictionary else {}
	var flow_debug: Dictionary = flow_debug_variant if flow_debug_variant is Dictionary else {}
	return {
		"checkpoint": settlement_checkpoint,
		"region_revision": int(region_debug.get("revision", 0)),
		"flow_revision": int(flow_debug.get("flow_revision", 0)),
		"captured_at_game_time": _world_session_state.game_time if _world_session_state != null else 0.0,
		"victory_reads_after": ["locked_intents", "construction_repair", "unit_attacks", "region_lifecycle", "route_rebuild", "commodity_flow", "sale_receipts", "bankruptcy"],
	}


func _is_data_only(value: Variant) -> bool:
	if typeof(value) == TYPE_OBJECT or value is Callable:
		return false
	if value is Dictionary:
		for key_variant in value.keys():
			if not _is_data_only(key_variant) or not _is_data_only(value[key_variant]):
				return false
	elif value is Array:
		for item_variant in value:
			if not _is_data_only(item_variant):
				return false
	return true
