@tool
extends Node
class_name CommoditySushiTrackRuntimeService

const SNAPSHOT_SCRIPT := preload("res://scripts/viewmodels/commodity_sushi_track_snapshot.gd")
const CLAIM_REQUEST_SCRIPT := preload("res://scripts/runtime/commodity_sushi_track_claim_request.gd")
const ITEM_SNAPSHOT_SCRIPT := preload("res://scripts/viewmodels/commodity_sushi_track_item_snapshot.gd")

var _inventory: CommodityCardInventoryRuntimeController
var _player_state: CardPlayerStateProductionAdapterV06
var _product_market: ProductMarketRuntimeController
var _snapshot_revision_by_viewer: Dictionary = {}
var _last_public_fingerprint_by_viewer: Dictionary = {}
var _last_visibility_fingerprint_by_viewer: Dictionary = {}
var _visibility_revision_by_viewer: Dictionary = {}
var _terminal_request_results: Dictionary = {}
var _compose_count := 0
var _claim_count := 0
var _rejected_count := 0


func configure(
	inventory: CommodityCardInventoryRuntimeController,
	player_state: CardPlayerStateProductionAdapterV06,
	product_market: ProductMarketRuntimeController
) -> Dictionary:
	_inventory = inventory
	_player_state = player_state
	_product_market = product_market
	return {
		"configured": _dependencies_ready(),
		"reason_code": "commodity_sushi_track_ready" if _dependencies_ready() else "commodity_sushi_track_dependencies_missing",
	}


func reset_projection_state() -> void:
	_snapshot_revision_by_viewer.clear()
	_last_public_fingerprint_by_viewer.clear()
	_last_visibility_fingerprint_by_viewer.clear()
	_visibility_revision_by_viewer.clear()
	_terminal_request_results.clear()
	_compose_count = 0
	_claim_count = 0
	_rejected_count = 0


func public_snapshot(viewer_index: int) -> SNAPSHOT_SCRIPT:
	_compose_count += 1
	if not _dependencies_ready() or viewer_index < 0:
		return SNAPSHOT_SCRIPT.new().apply_dictionary(_unavailable_snapshot())
	var actor_id := _actor_id_for_player(viewer_index)
	if actor_id.is_empty():
		return SNAPSHOT_SCRIPT.new().apply_dictionary(_unavailable_snapshot())
	var belt := _inventory.belt_snapshot()
	var belt_revision := maxi(0, int(belt.get("revision", 0)))
	var market := _product_market.public_market_snapshot()
	var market_revision := maxi(0, int(market.get("market_revision", 0)))
	var market_entries: Dictionary = market.get("product_market", {}) if market.get("product_market", {}) is Dictionary else {}
	var raw_items: Dictionary = belt.get("items", {}) if belt.get("items", {}) is Dictionary else {}
	var item_ids: Array[String] = []
	for item_id_variant in raw_items.keys():
		item_ids.append(str(item_id_variant))
	item_ids.sort()
	var visibility_bits: Array = []
	var rows: Array = []
	for slot_index in range(item_ids.size()):
		var item_id := item_ids[slot_index]
		var raw_item: Dictionary = raw_items.get(item_id, {}) if raw_items.get(item_id, {}) is Dictionary else {}
		var visible := _source_visible_to_actor(raw_item, actor_id)
		visibility_bits.append({"slot": item_id, "visible": visible})
		if not visible:
			continue
		var row := _public_item(raw_item, item_id, slot_index, market_entries, market_revision)
		if not row.is_empty():
			rows.append(row)
	var visibility_revision := _visibility_revision(viewer_index, visibility_bits)
	var candidate := {
		"schema_version": 1,
		"available": true,
		"snapshot_revision": 0,
		"belt_revision": belt_revision,
		"visibility_revision": visibility_revision,
		"market_revision": market_revision,
		"public_refresh_phase": "市场周期 %d" % market_revision,
		"items": rows,
		"empty_text": "商品带已领空，等待权威补货。" if rows.is_empty() else "",
	}
	var public_fingerprint := _stable_hash(candidate)
	var viewer_key := str(viewer_index)
	if str(_last_public_fingerprint_by_viewer.get(viewer_key, "")) != public_fingerprint:
		_snapshot_revision_by_viewer[viewer_key] = int(_snapshot_revision_by_viewer.get(viewer_key, 0)) + 1
		_last_public_fingerprint_by_viewer[viewer_key] = public_fingerprint
	candidate["snapshot_revision"] = int(_snapshot_revision_by_viewer.get(viewer_key, 0))
	if str(candidate.get("empty_text", "")).is_empty():
		candidate["empty_text"] = "商品带暂无可领取商品。"
	return SNAPSHOT_SCRIPT.new().apply_dictionary(candidate)


func claim(request: CLAIM_REQUEST_SCRIPT) -> Dictionary:
	if request == null or not bool(request.validation_report().get("valid", false)) or not _dependencies_ready():
		_rejected_count += 1
		return _public_result(false, "claim_request_invalid", request)
	var request_key: String = request.canonical_key()
	if _terminal_request_results.has(request_key):
		var replay: Dictionary = (_terminal_request_results.get(request_key, {}) as Dictionary).duplicate(true)
		replay["idempotent_replay"] = true
		return replay
	var current: SNAPSHOT_SCRIPT = public_snapshot(request.viewer_index)
	if current == null or not current.is_valid() \
			or current.snapshot_revision != request.snapshot_revision \
			or current.belt_revision != request.belt_revision \
			or current.visibility_revision != request.visibility_revision:
		_rejected_count += 1
		return _remember_result(request_key, _public_result(false, "snapshot_stale", request))
	var item: ITEM_SNAPSHOT_SCRIPT = current.item_by_id(request.commodity_slot_id)
	if item == null or item.commodity_card_id != request.commodity_card_id:
		_rejected_count += 1
		return _remember_result(request_key, _public_result(false, "commodity_slot_changed", request))
	if not item.claimable:
		_rejected_count += 1
		return _remember_result(request_key, _public_result(false, "commodity_slot_unavailable", request))
	var actor_id := _actor_id_for_player(request.viewer_index)
	var player := _inventory.player_snapshot(actor_id)
	if actor_id.is_empty() or player.is_empty():
		_rejected_count += 1
		return _remember_result(request_key, _public_result(false, "viewer_binding_unavailable", request))
	var transaction_id := "commodity_sushi:%d:%d:%s:%d" % [
		request.viewer_index,
		request.belt_revision,
		request.commodity_slot_id,
		request.request_revision,
	]
	var owner_result := _inventory.claim_belt_card(
		actor_id,
		request.commodity_slot_id,
		int(player.get("revision", -1)),
		request.belt_revision,
		transaction_id
	)
	var committed := bool(owner_result.get("committed", false))
	if committed:
		_claim_count += 1
	else:
		_rejected_count += 1
	var result := _public_result(
		committed,
		"claimed" if committed else _public_failure_code(str(owner_result.get("reason_code", "claim_failed"))),
		request
	)
	return _remember_result(request_key, result)


func debug_snapshot() -> Dictionary:
	return {
		"configured": _dependencies_ready(),
		"compose_count": _compose_count,
		"claim_count": _claim_count,
		"rejected_count": _rejected_count,
		"terminal_request_count": _terminal_request_results.size(),
		"owns_belt_state": false,
		"owns_player_state": false,
		"owns_market_state": false,
		"has_save_api": false,
		"references_main": false,
		"public_snapshot_contains_private_player_state": false,
	}


func _public_item(
	raw_item: Dictionary,
	item_id: String,
	slot_index: int,
	market_entries: Dictionary,
	market_revision: int
) -> Dictionary:
	var card: Dictionary = raw_item.get("card", {}) if raw_item.get("card", {}) is Dictionary else {}
	var machine: Dictionary = card.get("machine", {}) if card.get("machine", {}) is Dictionary else {}
	var player: Dictionary = card.get("player", {}) if card.get("player", {}) is Dictionary else {}
	var payload: Dictionary = machine.get("effect_payload", {}) if machine.get("effect_payload", {}) is Dictionary else {}
	var card_id := str(machine.get("card_id", "")).strip_edges()
	var product_id := str(payload.get("product_id", player.get("name", ""))).strip_edges()
	if card_id.is_empty() or product_id.is_empty() or str(machine.get("acquisition_kind", "")) != "commodity_belt_free":
		return {}
	var market: Dictionary = market_entries.get(product_id, {}) if market_entries.get(product_id, {}) is Dictionary else {}
	var source_claimable := bool(raw_item.get("claimable", true))
	return {
		"commodity_slot_id": item_id,
		"commodity_card_id": card_id,
		"public_name": str(player.get("name", product_id)),
		"public_icon_id": str(machine.get("industry_id", "generic")),
		"slot_index": slot_index,
		"availability_state": "available" if source_claimable else "unavailable",
		"claimable": source_claimable,
		"public_claim_disabled_reason": "" if source_claimable else "当前商品槽不可领取。",
		"public_supply_pressure": int(market.get("supply", 0)),
		"public_demand_pressure": int(market.get("demand", 0)),
		"public_market_price": int(market.get("price", -1)),
		"public_market_trend": int(market.get("trend", 0)),
		"public_refresh_phase": "市场周期 %d" % market_revision,
		"display_accent_id": str(machine.get("industry_id", "generic")),
		"public_industry": str(player.get("industry", "商品")),
		"public_short_effect": str(player.get("short_effect", "免费领取后安装到合法设施。")),
	}


func _visibility_revision(viewer_index: int, visibility_bits: Array) -> int:
	var key := str(viewer_index)
	var fingerprint := _stable_hash(visibility_bits)
	if str(_last_visibility_fingerprint_by_viewer.get(key, "")) != fingerprint:
		_visibility_revision_by_viewer[key] = int(_visibility_revision_by_viewer.get(key, 0)) + 1
		_last_visibility_fingerprint_by_viewer[key] = fingerprint
	return maxi(1, int(_visibility_revision_by_viewer.get(key, 1)))


func _source_visible_to_actor(item: Dictionary, actor_id: String) -> bool:
	var visible_actor_ids: Array = item.get("visible_actor_ids", []) if item.get("visible_actor_ids", []) is Array else []
	return visible_actor_ids.is_empty() or visible_actor_ids.has(actor_id)


func _actor_id_for_player(viewer_index: int) -> String:
	if _player_state == null or viewer_index < 0:
		return ""
	var actor_map := _player_state.actor_player_indices()
	var matches: Array[String] = []
	for actor_id_variant in actor_map.keys():
		if int(actor_map.get(actor_id_variant, -1)) == viewer_index:
			matches.append(str(actor_id_variant))
	matches.sort()
	return matches[0] if matches.size() == 1 else ""


func _public_result(success: bool, failure_code: String, request: CLAIM_REQUEST_SCRIPT) -> Dictionary:
	var item_name := "该商品"
	if request != null:
		var current: SNAPSHOT_SCRIPT = public_snapshot(request.viewer_index)
		var item: ITEM_SNAPSHOT_SCRIPT = current.item_by_id(request.commodity_slot_id) if current != null and current.is_valid() else null
		if item != null:
			item_name = item.public_name
	var explanation := _failure_explanation(failure_code)
	return {
		"success": success,
		"failure_code": "" if success else failure_code,
		"title": "已领取%s" % item_name if success else "未能领取%s" % item_name,
		"explanation": "免费商品牌已进入你的手牌。" if success else explanation,
		"consequence": "共享商品带已更新；领取不支付现金。" if success else "商品带和你的资源均未改变。",
		"suggested_action": "选择设施安装商品，或继续经营。" if success else _failure_suggestion(failure_code),
		"focus_target": request.commodity_slot_id if request != null else "",
		"relevant_cost": "免费",
		"relevant_requirement": "商品仍在共享轨道且当前可领取",
		"affected_entity_ids": [request.commodity_slot_id, request.commodity_card_id] if request != null else [],
		"request_revision": request.request_revision if request != null else 0,
		"idempotent_replay": false,
	}


func _failure_explanation(code: String) -> String:
	return {
		"snapshot_stale": "商品带已刷新，这次请求使用的是旧快照。",
		"commodity_slot_changed": "这个槽位的商品已经变化。",
		"commodity_slot_unavailable": "这个商品当前不可领取。",
		"viewer_binding_unavailable": "当前玩家席位尚未绑定到卡牌库存。",
		"inventory_full": "当前手牌没有可接收该商品的位置。",
	}.get(code, "领取条件在提交前发生变化。")


func _failure_suggestion(code: String) -> String:
	if code == "inventory_full":
		return "先打出或整理手牌，再领取商品。"
	return "查看刷新后的商品带并重新选择。"


func _public_failure_code(owner_code: String) -> String:
	return {
		"source_revision_changed": "snapshot_stale",
		"source_item_missing": "commodity_slot_changed",
		"source_item_unavailable": "commodity_slot_unavailable",
		"source_item_not_visible": "commodity_slot_unavailable",
		"hand_limit_reached": "inventory_full",
		"inventory_full": "inventory_full",
	}.get(owner_code, "claim_failed")


func _remember_result(request_key: String, result: Dictionary) -> Dictionary:
	_terminal_request_results[request_key] = result.duplicate(true)
	return result.duplicate(true)


func _dependencies_ready() -> bool:
	return _inventory != null and _player_state != null and _product_market != null


func _unavailable_snapshot() -> Dictionary:
	return {
		"schema_version": 1,
		"available": false,
		"snapshot_revision": 0,
		"belt_revision": 0,
		"visibility_revision": 0,
		"market_revision": 0,
		"public_refresh_phase": "",
		"items": [],
		"empty_text": "共享商品带尚未就绪。",
	}


func _stable_hash(value: Variant) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(JSON.stringify(value, "", true).to_utf8_buffer())
	return context.finish().hex_encode()
