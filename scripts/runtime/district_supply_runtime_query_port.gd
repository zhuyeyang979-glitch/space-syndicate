@tool
extends Node
class_name DistrictSupplyRuntimeQueryPort

@export var world_session_state_path: NodePath
@export var region_supply_path: NodePath
@export var pricing_path: NodePath
@export var commodity_card_inventory_path: NodePath
@export var game_session_path: NodePath

var _public_query_count := 0
var _private_ai_query_count := 0
var _rejected_query_count := 0
var _ai_private_capability: DistrictSupplyAiQueryCapability
var _ai_capability_revision := 0


func bind_ai_private_capability(capability: DistrictSupplyAiQueryCapability) -> void:
	_ai_private_capability = capability
	_ai_capability_revision += 1


func public_card_ids_for_district(district_index: int) -> Array:
	_public_query_count += 1
	var row := _public_rack_row(district_index)
	if row.is_empty():
		_rejected_query_count += 1
		return []
	var result: Array = []
	for listing_variant in row.get("slots", []) as Array:
		if not (listing_variant is Dictionary):
			continue
		var card_id := str((listing_variant as Dictionary).get("card_id", "")).strip_edges()
		if not card_id.is_empty() and not result.has(card_id):
			result.append(card_id)
	return result


func public_listing_for_district(district_index: int, card_id := "") -> Dictionary:
	_public_query_count += 1
	var row := _public_rack_row(district_index)
	if row.is_empty():
		_rejected_query_count += 1
		return {}
	var requested_card_id := card_id.strip_edges()
	if requested_card_id.is_empty():
		return row
	for listing_variant in row.get("slots", []) as Array:
		if listing_variant is Dictionary and str((listing_variant as Dictionary).get("card_id", "")) == requested_card_id:
			return (listing_variant as Dictionary).duplicate(true)
	_rejected_query_count += 1
	return {}


func public_rack_revision_for_district(district_index: int) -> String:
	_public_query_count += 1
	return str(_public_rack_row(district_index).get("rack_revision", ""))


func public_market_availability(district_index: int) -> Dictionary:
	_public_query_count += 1
	if not _district_valid(district_index) or _pricing() == null:
		_rejected_query_count += 1
		return {
			"viewable": false,
			"purchasable": false,
			"availability_kind": "invalid",
			"reason_code": "market_unavailable",
		}
	var result := _pricing().listing_availability(district_index)
	if _game_session() != null and _game_session().is_finished():
		result["purchasable"] = false
		result["reason_code"] = "session_finished"
	return result


func public_market_purchasable(district_index: int) -> bool:
	return bool(public_market_availability(district_index).get("purchasable", false))


func public_market_availability_text(district_index: int) -> String:
	var availability := public_market_availability(district_index)
	if str(availability.get("reason_code", "")) == "session_finished":
		return "对局已结束：区域牌架仅供查看。"
	match str(availability.get("availability_kind", "invalid")):
		"sunlit":
			return "来源区域处于日照半球：可购买；报价锁定5个世界秒。"
		"dark":
			return "来源区域处于暗面：可以查看，当前不可购买。"
		"destroyed":
			return "来源区域已摧毁：挂牌不可购买。"
	return "市场资格暂不可用。"


func public_price_preview(district_index: int, card_id: String) -> Dictionary:
	_public_query_count += 1
	var listing := public_listing_for_district(district_index, card_id)
	if listing.is_empty() or _pricing() == null:
		_rejected_query_count += 1
		return {}
	return _pricing().preview_listing({
		"district_index": district_index,
		"card_id": card_id,
		"supply_revision": str(listing.get("supply_revision", listing.get("rack_revision", ""))),
		"base_price": int(listing.get("price_cash", -1)),
	})


func private_inventory_snapshot_for_actor(
	capability: DistrictSupplyAiQueryCapability,
	player_index: int,
	incoming_card_id := "",
	discard_slot := -1
) -> Dictionary:
	_private_ai_query_count += 1
	if not _ai_private_authorized(capability, player_index) or _commodity_inventory() == null:
		_rejected_query_count += 1
		return {}
	var snapshot := _commodity_inventory().player_snapshot(_actor_id(player_index))
	if snapshot.is_empty():
		_rejected_query_count += 1
		return {}
	var result := snapshot.duplicate(true)
	result["incoming_card_id"] = incoming_card_id
	result["discard_slot"] = discard_slot
	return result


func private_inventory_plan_for_actor(
	capability: DistrictSupplyAiQueryCapability,
	player_index: int,
	incoming_card_id: String,
	discard_slot := -1
) -> Dictionary:
	if private_inventory_snapshot_for_actor(capability, player_index, incoming_card_id, discard_slot).is_empty():
		return {}
	return _commodity_inventory().region_supply_receive_preview(_actor_id(player_index), incoming_card_id, discard_slot)


func private_discardable_slots_for_actor(capability: DistrictSupplyAiQueryCapability, player_index: int) -> Array:
	return _commodity_inventory().discardable_slots(_actor_id(player_index)) \
		if not private_inventory_snapshot_for_actor(capability, player_index).is_empty() else []


func private_can_receive_with_discard(capability: DistrictSupplyAiQueryCapability, player_index: int, incoming_card_id: String) -> bool:
	var preview := private_inventory_plan_for_actor(capability, player_index, incoming_card_id)
	return bool(preview.get("ready", false)) or bool(preview.get("requires_discard", false))


func private_requires_discard(capability: DistrictSupplyAiQueryCapability, player_index: int, incoming_card_id: String) -> bool:
	return bool(private_inventory_plan_for_actor(capability, player_index, incoming_card_id).get("requires_discard", false))


func debug_snapshot() -> Dictionary:
	return {
		"configured": _is_configured(),
		"public_query_count": _public_query_count,
		"private_ai_query_count": _private_ai_query_count,
		"rejected_query_count": _rejected_query_count,
		"ai_capability_bound": _ai_private_capability != null,
		"ai_capability_revision": _ai_capability_revision,
		"reads_future_supply_bag": false,
		"mutates_gameplay": false,
		"references_main": false,
		"exposes_private_queries_to_presentation": false,
	}


func _ai_private_authorized(capability: DistrictSupplyAiQueryCapability, player_index: int) -> bool:
	return capability != null \
		and capability == _ai_private_capability \
		and _game_session() != null \
		and not _game_session().is_finished() \
		and _player_valid(player_index) \
		and bool((_world().players[player_index] as Dictionary).get("is_ai", false))


func _public_rack_row(district_index: int) -> Dictionary:
	if not _district_valid(district_index) or _region_supply() == null:
		return {}
	var region_id := _region_id(district_index)
	var rack := _region_supply().public_rack_snapshot(region_id)
	for row_variant in rack.get("regions", []) as Array:
		if row_variant is Dictionary and str((row_variant as Dictionary).get("region_id", "")) == region_id:
			return (row_variant as Dictionary).duplicate(true)
	return {}


func _region_id(district_index: int) -> String:
	return _world().region_id_for_district(district_index)


func _district_valid(district_index: int) -> bool:
	return _world() != null \
		and district_index >= 0 \
		and district_index < _world().districts.size() \
		and _world().districts[district_index] is Dictionary


func _player_valid(player_index: int) -> bool:
	return _world() != null \
		and player_index >= 0 \
		and player_index < _world().players.size() \
		and _world().players[player_index] is Dictionary


func _is_configured() -> bool:
	return _world() != null \
		and _region_supply() != null \
		and _pricing() != null \
		and _commodity_inventory() != null \
		and _game_session() != null


func _world() -> WorldSessionState:
	return get_node_or_null(world_session_state_path) as WorldSessionState


func _region_supply() -> RegionSupplyRuntimeController:
	return get_node_or_null(region_supply_path) as RegionSupplyRuntimeController


func _pricing() -> CardMarketPricingRuntimeController:
	return get_node_or_null(pricing_path) as CardMarketPricingRuntimeController


func _commodity_inventory() -> CommodityCardInventoryRuntimeController:
	return get_node_or_null(commodity_card_inventory_path) as CommodityCardInventoryRuntimeController


func _game_session() -> GameSessionRuntimeController:
	return get_node_or_null(game_session_path) as GameSessionRuntimeController


func _actor_id(player_index: int) -> String:
	if not _player_valid(player_index):
		return ""
	return str((_world().players[player_index] as Dictionary).get("actor_id", "player.%d" % player_index))
