@tool
extends Node
class_name VictoryControlWorldBridge

const BRIDGE_ID := "victory_control_world_bridge_v05"
const CURRENCY_SCALE := 100

var _world: Node
var _city_trade_network_controller: Node
var _contract_controller: Node
var _product_market_controller: Node
var _city_gdp_derivative_controller: Node
var _military_controller: Node
var _capture_count := 0
var _apply_count := 0
var _applied_outcome_ids: Dictionary = {}


func bind_world(world: Node) -> void:
	_world = world


func set_runtime_dependencies(city_trade_network_controller: Node, contract_controller: Node, product_market_controller: Node, city_gdp_derivative_controller: Node, military_controller: Node) -> void:
	_city_trade_network_controller = city_trade_network_controller
	_contract_controller = contract_controller
	_product_market_controller = product_market_controller
	_city_gdp_derivative_controller = city_gdp_derivative_controller
	_military_controller = military_controller


func has_world() -> bool:
	return _world != null and is_instance_valid(_world)


func reset_state() -> void:
	_capture_count = 0
	_apply_count = 0
	_applied_outcome_ids = {}


func capture_world_snapshot(clock_pause: Dictionary = {}) -> Dictionary:
	if not has_world() or _city_trade_network_controller == null:
		return {}
	_capture_count += 1
	var players_variant: Variant = _world.get("players")
	var districts_variant: Variant = _world.get("districts")
	var players: Array = players_variant if players_variant is Array else []
	var districts: Array = districts_variant if districts_variant is Array else []
	var region_rows: Array = []
	var project_positions_by_player := {}
	for player_index in range(players.size()):
		project_positions_by_player[str(player_index)] = []
	for district_index in range(districts.size()):
		var district: Dictionary = districts[district_index] if districts[district_index] is Dictionary else {}
		var public_gdp_variant: Variant = _city_trade_network_controller.call("public_region_gdp_snapshot", district_index) if _city_trade_network_controller.has_method("public_region_gdp_snapshot") else {}
		var public_gdp: Dictionary = public_gdp_variant if public_gdp_variant is Dictionary else {}
		var player_gdp_by_index := {}
		for player_index in range(players.size()):
			var private_gdp_variant: Variant = _city_trade_network_controller.call("private_region_gdp_snapshot", district_index, player_index) if _city_trade_network_controller.has_method("private_region_gdp_snapshot") else {}
			var private_gdp: Dictionary = private_gdp_variant if private_gdp_variant is Dictionary else {}
			player_gdp_by_index[str(player_index)] = maxi(0, int(private_gdp.get("own_gdp_per_minute", 0)))
			for attribution_variant in private_gdp.get("own_attribution_rows", []):
				if not (attribution_variant is Dictionary):
					continue
				var attribution: Dictionary = attribution_variant
				(project_positions_by_player[str(player_index)] as Array).append({
					"region_id": str(public_gdp.get("region_id", "")),
					"district_index": district_index,
					"project_id": str(attribution.get("project_id", "")),
					"project_generation": int(attribution.get("project_generation", 0)),
					"share_basis_points": int(attribution.get("share_basis_points", 0)),
					"attributable_gdp_per_minute": int(attribution.get("attributable_gdp_per_minute", 0)),
				})
		var city: Dictionary = district.get("city", {}) if district.get("city", {}) is Dictionary else {}
		region_rows.append({
			"region_id": str(public_gdp.get("region_id", city.get("region_id", "region_%d" % district_index))),
			"district_index": district_index,
			"destroyed": bool(district.get("destroyed", false)),
			"region_gdp_per_minute": int(public_gdp.get("region_gdp_per_minute", 0)),
			"player_gdp_by_index": player_gdp_by_index,
		})
	var player_rows: Array = []
	for player_index in range(players.size()):
		var player: Dictionary = players[player_index] if players[player_index] is Dictionary else {}
		var available_cents := int(player.get("cash", 0)) * CURRENCY_SCALE
		var escrow_cents := _player_escrow_cents(player_index)
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
				"project_positions": (project_positions_by_player.get(str(player_index), []) as Array).duplicate(true),
				"contracts": _contract_assets(player_index),
				"warehouses": _warehouse_assets(player_index),
				"financial_positions": _financial_assets(player_index),
				"hand_count": _ordinary_hand_count(player),
				"unit_count": _military_unit_count(player_index),
			},
		})
	var depth_tier := int(_world.get("configured_roguelike_depth"))
	if depth_tier <= 0:
		depth_tier = 3
	return {
		"schema_version": "v0.5.victory-world.1",
		"depth_tier": depth_tier,
		"players": player_rows,
		"regions": region_rows,
		"clock_pause": clock_pause.duplicate(true) if _is_data_only(clock_pause) else {},
		"visibility_scope": "controller_private",
	}


func apply_outcome_receipt(receipt: Dictionary) -> Dictionary:
	if not has_world() or not _is_data_only(receipt):
		return {"applied": false, "reason": "world_or_receipt_invalid"}
	var outcome_id := str(receipt.get("outcome_id", ""))
	if outcome_id.is_empty():
		return {"applied": false, "reason": "outcome_id_missing"}
	if _applied_outcome_ids.has(outcome_id):
		return {"applied": true, "duplicate": true, "outcome_id": outcome_id}
	_applied_outcome_ids[outcome_id] = true
	_apply_count += 1
	if _world.has_method("_on_victory_outcome_applied"):
		_world.call("_on_victory_outcome_applied", receipt.duplicate(true))
	return {"applied": true, "duplicate": false, "outcome_id": outcome_id}


func debug_snapshot() -> Dictionary:
	return {
		"bridge_id": BRIDGE_ID,
		"bridge_ready": has_world() and _city_trade_network_controller != null,
		"capture_count": _capture_count,
		"apply_count": _apply_count,
		"applied_outcome_count": _applied_outcome_ids.size(),
		"owns_gdp_formula": false,
		"owns_project_attribution": false,
		"owns_victory_state": false,
		"owns_session_state": false,
		"pure_fact_bridge": true,
	}


func _player_eliminated(player_index: int, player: Dictionary) -> bool:
	return bool(_world.call("_player_is_eliminated", player_index)) if _world.has_method("_player_is_eliminated") else bool(player.get("eliminated", false))


func _player_escrow_cents(player_index: int) -> int:
	if _world.has_method("_victory_control_escrow_cents"):
		return maxi(0, int(_world.call("_victory_control_escrow_cents", player_index)))
	return 0


func _ordinary_hand_count(player: Dictionary) -> int:
	var count := 0
	for skill_variant in player.get("skills", []):
		if skill_variant is Dictionary and not bool((skill_variant as Dictionary).get("fixed", false)):
			count += 1
	return count


func _military_unit_count(player_index: int) -> int:
	if _military_controller != null and _military_controller.has_method("visible_unit_count"):
		return maxi(0, int(_military_controller.call("visible_unit_count", player_index, player_index)))
	return 0


func _contract_assets(player_index: int) -> Array:
	var result: Array = []
	if _contract_controller == null or not _contract_controller.has_method("pending_offers_snapshot"):
		return result
	var offers_variant: Variant = _contract_controller.call("pending_offers_snapshot", true)
	if not (offers_variant is Array):
		return result
	for offer_variant in offers_variant:
		if not (offer_variant is Dictionary):
			continue
		var offer: Dictionary = offer_variant
		if player_index not in [int(offer.get("contract_source_owner", -1)), int(offer.get("contract_target_owner", -1))]:
			continue
		result.append({
			"contract_id": int(offer.get("contract_offer_id", offer.get("resolution_id", -1))),
			"response": str(offer.get("contract_response", "")),
			"source_district": int(offer.get("contract_source_district", -1)),
			"target_district": int(offer.get("contract_target_district", -1)),
			"products": (offer.get("contract_products", []) as Array).duplicate() if offer.get("contract_products", []) is Array else [],
		})
	return result


func _warehouse_assets(player_index: int) -> Array:
	var result: Array = []
	for position_variant in _product_financial_positions(player_index):
		if position_variant is Dictionary and int((position_variant as Dictionary).get("warehouse_district", -1)) >= 0:
			result.append({
				"position_id": int((position_variant as Dictionary).get("position_id", -1)),
				"product_id": str((position_variant as Dictionary).get("product", (position_variant as Dictionary).get("product_id", ""))),
				"warehouse_district": int((position_variant as Dictionary).get("warehouse_district", -1)),
				"units": int((position_variant as Dictionary).get("units", 0)),
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
