@tool
extends Node
class_name DistrictSupplyActionPort

signal receipt_ready(receipt: DistrictSupplyActionReceipt)
signal presentation_refresh_requested(kind: StringName, reason: StringName)

@export var identity_boundary_path: NodePath
@export var coordinator_path: NodePath
@export var world_session_state_path: NodePath
@export var presentation_state_path: NodePath
@export var purchase_controller_path: NodePath
@export var commodity_card_inventory_path: NodePath
@export var game_session_path: NodePath

const LEDGER_LIMIT := 14

var _journal: Dictionary = {}
var _journal_order: Array[String] = []
var _journal_session_key := ""
var _submission_count := 0
var _accepted_count := 0
var _rejected_count := 0
var _purchase_commit_count := 0
var _replay_count := 0
var _collision_count := 0
var _last_reason_code := ""


func submit_intent(intent: DistrictSupplyActionIntent) -> DistrictSupplyActionReceipt:
	_submission_count += 1
	if intent == null:
		return _complete(_receipt(null, false, "intent_missing"))
	var validation := intent.validation_report()
	if not bool(validation.get("valid", false)):
		return _complete(_receipt(intent, false, str(validation.get("reason_code", "intent_invalid"))))
	if _coordinator() == null or _world() == null or _presentation() == null or _purchase() == null or _commodity_inventory() == null or _identity() == null:
		return _complete(_receipt(intent, false, "district_supply_dependency_missing"))
	var session_key := "%s:%d" % [intent.session_id, intent.session_revision]
	if _journal_session_key == session_key and _journal.has(intent.request_id):
		if str(_journal.get(intent.request_id, "")) != intent.fingerprint():
			_collision_count += 1
			var collision := _receipt(intent, false, "request_id_collision")
			collision.request_id_collision = true
			return _complete(collision)
		_replay_count += 1
		var replay := _receipt(intent, false, "request_replay")
		replay.idempotent_replay = true
		return _complete(replay)
	var actor_context := _identity().authorize_actor_index(intent.actor_player_index, intent.source_surface)
	if not actor_context.is_valid() or actor_context.authorization_revision != intent.authorization_revision \
			or actor_context.session_id != intent.session_id or actor_context.session_revision != intent.session_revision:
		return _complete(_receipt(intent, false, "actor_authorization_rejected"))
	if intent.action_kind not in [DistrictSupplyActionIntent.KIND_DISCARD_CONFIRM, DistrictSupplyActionIntent.KIND_DISCARD_CANCEL] \
			and _coordinator().blocks_player_actions(intent.actor_player_index):
		return _complete(_receipt(intent, false, "forced_decision_blocks_district_supply"))
	_sync_journal(session_key)
	_remember_request(intent.request_id, intent.fingerprint())
	var receipt := _dispatch(intent)
	return _complete(receipt)


func submit_ai_purchase(
	player_index: int,
	district_index: int,
	card_id: String,
	discard_slot := -1,
	request_id := ""
) -> bool:
	if _coordinator() == null or _world() == null or _presentation() == null or _purchase() == null or _commodity_inventory() == null or _game_session() == null:
		return false
	if _coordinator().session_is_finished() or not _player_valid(player_index) \
			or not bool((_world().players[player_index] as Dictionary).get("is_ai", false)) \
			or _coordinator().blocks_player_actions(player_index):
		return false
	var session_key := "%s:%d" % [
		str(_game_session().session_summary().get("session_id", "")),
		_game_session().session_start_revision(),
	]
	_sync_journal(session_key)
	var normalized_request_id := request_id.strip_edges()
	if normalized_request_id.is_empty():
		var simulation_step_index := _coordinator().current_runtime_simulation_step_index()
		if simulation_step_index <= 0:
			return false
		normalized_request_id = "district-supply-ai:%s:%d:%d" % [
			session_key,
			simulation_step_index,
			player_index,
		]
	var fingerprint := "%s|%d|%d|%s|%d" % [session_key, player_index, district_index, card_id, discard_slot]
	if _journal.has(normalized_request_id):
		if str(_journal.get(normalized_request_id, "")) != fingerprint:
			_collision_count += 1
		else:
			_replay_count += 1
		return false
	_remember_request(normalized_request_id, fingerprint)
	_submission_count += 1
	var outcome := _purchase_card(player_index, district_index, card_id, discard_slot, "", true)
	_last_reason_code = str(outcome.get("reason", "purchase_rejected"))
	return bool(outcome.get("committed", false))


func submit_current_actor_action(action_kind: StringName, district_index := -1, card_id := "", discard_slot := -1, source_surface: StringName = &"game_screen") -> DistrictSupplyActionReceipt:
	if _identity() == null:
		return _complete(_receipt(null, false, "identity_boundary_missing"))
	var context := _identity().current_actor_context(source_surface)
	if not context.is_valid():
		return _complete(_receipt(null, false, "actor_authorization_rejected"))
	var intent := DistrictSupplyActionIntent.new()
	intent.request_id = "district-supply-internal:%d:%d" % [context.authorized_actor_player_index, _submission_count + 1]
	intent.action_kind = action_kind
	intent.actor_player_index = context.authorized_actor_player_index
	intent.authorization_revision = context.authorization_revision
	intent.session_id = context.session_id
	intent.session_revision = context.session_revision
	intent.district_index = district_index
	intent.card_id = card_id
	intent.discard_slot = discard_slot
	intent.source_surface = source_surface
	intent.request_revision = _submission_count + 1
	return submit_intent(intent)


func debug_snapshot() -> Dictionary:
	return {
		"port_id": "district_supply_action_port_v1",
		"submission_count": _submission_count,
		"accepted_count": _accepted_count,
		"rejected_count": _rejected_count,
		"purchase_commit_count": _purchase_commit_count,
		"replay_count": _replay_count,
		"collision_count": _collision_count,
		"last_reason_code": _last_reason_code,
		"journal_size": _journal.size(),
		"journal_limit": LEDGER_LIMIT,
		"scene_owned": true,
		"typed_intents": true,
		"owns_region_supply": false,
		"owns_inventory": false,
		"owns_cash": false,
		"references_main": false,
	}


func _dispatch(intent: DistrictSupplyActionIntent) -> DistrictSupplyActionReceipt:
	match intent.action_kind:
		DistrictSupplyActionIntent.KIND_OPEN:
			return _open(intent)
		DistrictSupplyActionIntent.KIND_CLOSE:
			return _close(intent)
		DistrictSupplyActionIntent.KIND_PREVIEW:
			return _preview(intent, false)
		DistrictSupplyActionIntent.KIND_QUOTE:
			return _preview(intent, true)
		DistrictSupplyActionIntent.KIND_PURCHASE:
			return _purchase_intent(intent)
		DistrictSupplyActionIntent.KIND_DISCARD_CANCEL:
			return _cancel_discard(intent)
		DistrictSupplyActionIntent.KIND_DISCARD_CONFIRM:
			return _confirm_discard(intent)
	return _receipt(intent, false, "action_kind_unsupported")


func _open(intent: DistrictSupplyActionIntent) -> DistrictSupplyActionReceipt:
	if not _district_valid(intent.district_index):
		return _receipt(intent, false, "district_unavailable")
	var revision := _coordinator().region_supply_rack_revision(_region_id(intent.district_index))
	var window := _coordinator().open_district_purchase_window(intent.actor_player_index, intent.district_index, {"supply_revision": revision})
	if window.is_empty():
		return _receipt(intent, false, "purchase_window_unavailable")
	_presentation().open_district = intent.district_index
	_presentation().open_player = intent.actor_player_index
	_reconcile_selection(intent.district_index)
	var receipt := _receipt(intent, true, "district_supply_opened")
	receipt.applied = true
	receipt.focus_district_index = intent.district_index
	return _refresh(receipt)


func _close(intent: DistrictSupplyActionIntent) -> DistrictSupplyActionReceipt:
	var actor := _presentation().open_player if _presentation().open_player >= 0 else intent.actor_player_index
	if actor >= 0:
		_coordinator().close_district_purchase_window(actor, "drawer_closed")
	_presentation().open_district = -1
	_presentation().open_player = -1
	var receipt := _receipt(intent, true, "district_supply_closed")
	receipt.applied = true
	receipt.close_drawer = true
	return _refresh(receipt)


func _preview(intent: DistrictSupplyActionIntent, lock_quote: bool) -> DistrictSupplyActionReceipt:
	var listing := _coordinator().region_supply_listing(_region_id(intent.district_index), intent.card_id)
	if listing.is_empty():
		return _receipt(intent, false, "card_not_in_supply")
	if lock_quote and _coordinator().session_is_finished():
		return _receipt(intent, false, "session_finished")
	if lock_quote:
		var availability := _coordinator().card_market_listing_availability(intent.district_index)
		if not bool(availability.get("purchasable", false)):
			return _receipt(intent, false, str(availability.get("reason_code", "listing_not_purchasable")))
		var listing_revision := str(listing.get("supply_revision", ""))
		_coordinator().acknowledge_district_purchase_selection(intent.actor_player_index, intent.district_index, intent.card_id, listing_revision)
		var quote := _quote(intent.actor_player_index, intent.district_index, intent.card_id)
		if quote.is_empty() or not bool(quote.get("confirmable", false)):
			return _receipt(intent, false, "quote_unavailable")
		_presentation().previewed_district_card = intent.card_id
		_presentation().selected_market_skill = intent.card_id
		var quoted := _receipt(intent, true, "quote_locked")
		quoted.applied = true
		quoted.quote_id = str(quote.get("quote_id", ""))
		quoted.price = int(quote.get("final_price", quote.get("price", -1)))
		return _refresh(quoted)
	_presentation().previewed_district_card = intent.card_id
	var receipt := _receipt(intent, true, "card_previewed")
	receipt.applied = true
	return _refresh(receipt)


func _purchase_intent(intent: DistrictSupplyActionIntent) -> DistrictSupplyActionReceipt:
	if _coordinator().session_is_finished():
		return _receipt(intent, false, "session_finished")
	var outcome := _purchase_card(intent.actor_player_index, intent.district_index, intent.card_id, intent.discard_slot, intent.locked_quote_id, false)
	_last_reason_code = str(outcome.get("reason", "purchase_rejected"))
	var receipt := _receipt(intent, bool(outcome.get("committed", false)), str(outcome.get("reason", "purchase_rejected")))
	receipt.applied = receipt.accepted
	receipt.quote_id = str(outcome.get("quote_id", ""))
	receipt.price = int(outcome.get("price", -1))
	receipt.requires_discard = bool(outcome.get("requires_discard", false))
	if receipt.accepted or receipt.requires_discard:
		return _refresh(receipt)
	return receipt


func _cancel_discard(intent: DistrictSupplyActionIntent) -> DistrictSupplyActionReceipt:
	var pending := _purchase().pending_discard_private_snapshot(intent.actor_player_index)
	if pending.is_empty():
		return _receipt(intent, false, "pending_discard_missing")
	_purchase().resolve_pending_discard({"player_index": intent.actor_player_index, "reason": "discard_cancelled"})
	var receipt := _receipt(intent, true, "discard_cancelled")
	receipt.applied = true
	return _refresh(receipt)


func _confirm_discard(intent: DistrictSupplyActionIntent) -> DistrictSupplyActionReceipt:
	var pending := _purchase().pending_discard_private_snapshot(intent.actor_player_index)
	if pending.is_empty():
		return _receipt(intent, false, "pending_discard_missing")
	var purchase_intent := DistrictSupplyActionIntent.new()
	purchase_intent.request_id = intent.request_id
	purchase_intent.action_kind = DistrictSupplyActionIntent.KIND_PURCHASE
	purchase_intent.actor_player_index = intent.actor_player_index
	purchase_intent.authorization_revision = intent.authorization_revision
	purchase_intent.session_id = intent.session_id
	purchase_intent.session_revision = intent.session_revision
	purchase_intent.district_index = int(pending.get("district_index", -1))
	purchase_intent.card_id = str(pending.get("card_id", pending.get("skill_name", "")))
	purchase_intent.discard_slot = intent.discard_slot
	purchase_intent.locked_quote_id = str(pending.get("quote_id", ""))
	purchase_intent.source_surface = intent.source_surface
	purchase_intent.request_revision = intent.request_revision
	var receipt := _purchase_intent(purchase_intent)
	_purchase().resolve_pending_discard({"player_index": intent.actor_player_index, "reason": "discard_confirmed" if receipt.accepted else "discard_purchase_failed"})
	return receipt


func _purchase_card(player_index: int, district_index: int, card_id: String, discard_slot: int, locked_quote_id: String, anonymous: bool) -> Dictionary:
	if not _district_valid(district_index) or not _player_valid(player_index) or not _listing_exists(district_index, card_id):
		return {"committed": false, "reason": "purchase_target_invalid"}
	var player: Dictionary = _world().players[player_index]
	if bool(player.get("eliminated", false)):
		return {"committed": false, "reason": "player_eliminated"}
	var listing := _coordinator().region_supply_listing(_region_id(district_index), card_id)
	var rack_revision := _coordinator().region_supply_rack_revision(_region_id(district_index))
	var listing_revision := str(listing.get("supply_revision", ""))
	if not _purchase().is_window_active(player_index, district_index):
		_coordinator().open_district_purchase_window(player_index, district_index, {"supply_revision": rack_revision})
	_coordinator().mark_district_supply_revision(player_index, district_index, rack_revision)
	_coordinator().acknowledge_district_purchase_selection(player_index, district_index, card_id, listing_revision)
	var quote: Dictionary = {}
	if not locked_quote_id.is_empty():
		quote = _coordinator().card_market_active_quote(player_index, district_index)
		if quote.is_empty() or str(quote.get("quote_id", "")) != locked_quote_id or str(quote.get("card_id", "")) != card_id:
			return {"committed": false, "reason": "locked_quote_changed", "quote_id": locked_quote_id}
	elif anonymous:
		quote = _quote(player_index, district_index, card_id)
	else:
		return {"committed": false, "reason": "locked_quote_required"}
	if quote.is_empty():
		return {"committed": false, "reason": "quote_unavailable"}
	var authorization := _coordinator().authorize_card_market_purchase({
		"quote_id": str(quote.get("quote_id", "")),
		"quote_fingerprint": str(quote.get("quote_fingerprint", "")),
		"player_index": player_index,
		"district_index": district_index,
		"card_id": card_id,
		"supply_revision": listing_revision,
	})
	if not bool(authorization.get("authorized", false)):
		return {"committed": false, "reason": str(authorization.get("reason", "quote_unauthorized"))}
	var price := int(authorization.get("final_price", -1))
	var actor_id := _actor_id(player_index)
	var receive_preview := _commodity_inventory().region_supply_receive_preview(actor_id, card_id, discard_slot)
	if bool(receive_preview.get("requires_discard", false)) and discard_slot < 0:
		if anonymous:
			return {"committed": false, "requires_discard": true, "reason": "ai_discard_slot_required", "quote_id": str(quote.get("quote_id", "")), "price": price}
		_purchase().reserve_pending_discard({
			"player_index": player_index, "district_index": district_index, "skill_name": card_id, "card_id": card_id,
			"price": price, "quote_id": str(quote.get("quote_id", "")), "opened_at": _world().game_time,
		})
		return {"committed": false, "requires_discard": true, "reason": "hand_limit_requires_discard", "quote_id": str(quote.get("quote_id", "")), "price": price}
	if not bool(receive_preview.get("ready", false)):
		return {"committed": false, "reason": str(receive_preview.get("reason_code", "purchase_rejected")), "quote_id": str(quote.get("quote_id", "")), "price": price}
	# Reuse the prior authorization from quote generation to avoid duplicate checks.
	var player_snapshot := _coordinator().v06_card_player_snapshot(actor_id)
	if player_snapshot.is_empty():
		return {"committed": false, "reason": "player_state_unavailable", "quote_id": str(quote.get("quote_id", "")), "price": price}
	var transaction_id := "district-purchase:%s" % str(quote.get("quote_id", ""))
	var quote_request := {
		"quote_id": str(quote.get("quote_id", "")),
		"quote_fingerprint": str(quote.get("quote_fingerprint", "")),
		"player_index": player_index,
		"district_index": district_index,
		"card_id": card_id,
		"supply_revision": listing_revision,
		"source_region_id": str(listing.get("source_region_id", _region_id(district_index))),
		"slot_index": int(listing.get("slot_index", -1)),
		"source_item_id": str(listing.get("item_id", "")),
	}
	var result := _coordinator().purchase_region_supply_card({
		"actor_id": actor_id,
		"region_id": str(listing.get("source_region_id", _region_id(district_index))),
		"slot_index": int(listing.get("slot_index", -1)),
		"item_id": str(listing.get("item_id", "")),
		"card_id": card_id,
		"player_revision": int(player_snapshot.get("revision", -1)),
		"supply_revision": listing_revision,
		"transaction_id": transaction_id,
		"quote_request": quote_request,
		"discard_slot": discard_slot,
	})
	if not bool(result.get("committed", false)):
		return {"committed": false, "reason": str(result.get("reason_code", result.get("reason", "purchase_commit_failed"))), "quote_id": str(quote.get("quote_id", "")), "price": price}
	var pending := _purchase().pending_discard_private_snapshot(player_index)
	if str(pending.get("card_id", pending.get("skill_name", ""))) == card_id \
			and str(pending.get("quote_id", "")) == str(quote.get("quote_id", "")):
		_purchase().resolve_pending_discard({"player_index": player_index, "reason": "purchase_committed"})
	_coordinator().record_legacy_viewer_feedback("一次匿名区域购牌已完成；买家、具体卡牌、手牌数量和弃牌情况不公开。")
	_grant_role_bonus_card(player_index, district_index, card_id, transaction_id)
	_coordinator().record_weather_public_response(district_index, "buy_after_forecast")
	_purchase_commit_count += 1
	return {"committed": true, "reason": "purchase_committed", "quote_id": str(quote.get("quote_id", "")), "price": price}


func _grant_role_bonus_card(player_index: int, district_index: int, bought_card_id: String, source_transaction_id: String) -> bool:
	if not _player_valid(player_index) or not _district_valid(district_index):
		return false
	var player: Dictionary = _world().players[player_index]
	var role: Dictionary = player.get("role_card", {}) if player.get("role_card", {}) is Dictionary else {}
	var product_id := str(role.get("bonus_card_product", ""))
	if product_id.is_empty() or not _district_or_city_has_product(district_index, product_id):
		return false
	var actor_id := _actor_id(player_index)
	var candidate := _bonus_card_candidate(actor_id, district_index, bought_card_id)
	if candidate.is_empty():
		return false
	var player_snapshot := _coordinator().v06_card_player_snapshot(actor_id)
	if player_snapshot.is_empty():
		return false
	var result := _commodity_inventory().grant_card(
		actor_id,
		candidate,
		int(player_snapshot.get("revision", -1)),
		"district-role-bonus:%s:%s" % [source_transaction_id, candidate],
		"role_bonus_region_purchase"
	)
	if not bool(result.get("committed", false)):
		return false
	_coordinator().record_legacy_viewer_feedback("一次匿名区域购牌触发角色额外补给；具体买家、卡牌和手牌状态不公开。")
	return true


func _bonus_card_candidate(actor_id: String, district_index: int, bought_card_id: String) -> String:
	var fallback := ""
	for value: Variant in _coordinator().region_supply_card_ids(_region_id(district_index)):
		var candidate := str(value)
		if candidate.is_empty():
			continue
		if candidate == bought_card_id:
			fallback = candidate
			continue
		if bool(_commodity_inventory().region_supply_receive_preview(actor_id, candidate).get("ready", false)):
			return candidate
	if fallback.is_empty():
		fallback = bought_card_id
	if not fallback.is_empty() and bool(_commodity_inventory().region_supply_receive_preview(actor_id, fallback).get("ready", false)):
		return fallback
	return ""


func _district_or_city_has_product(district_index: int, product_id: String) -> bool:
	var district: Dictionary = _world().districts[district_index]
	if (district.get("products", []) as Array).has(product_id) or (district.get("demands", []) as Array).has(product_id):
		return true
	var city: Dictionary = district.get("city", {}) if district.get("city", {}) is Dictionary else {}
	if city.is_empty() or bool(city.get("destroyed", false)):
		return false
	return (city.get("products", []) as Array).has(product_id) or (city.get("demands", []) as Array).has(product_id)


func _quote(player_index: int, district_index: int, card_id: String) -> Dictionary:
	var listing := _coordinator().region_supply_listing(_region_id(district_index), card_id)
	if listing.is_empty():
		return {}
	return _coordinator().card_market_quote({
		"actor_id": _actor_id(player_index), "player_index": player_index, "district_index": district_index,
		"card_id": card_id, "supply_revision": str(listing.get("supply_revision", "")),
		"base_price": int(listing.get("price_cash", -1)),
	})


func _reconcile_selection(district_index: int) -> void:
	_presentation().reconcile_district_card_choices(_coordinator().region_supply_card_ids(_region_id(district_index)))


func _listing_exists(district_index: int, card_id: String) -> bool:
	return not _coordinator().region_supply_listing(_region_id(district_index), card_id).is_empty()


func _region_id(district_index: int) -> String:
	if not _district_valid(district_index):
		return ""
	return str((_world().districts[district_index] as Dictionary).get("region_id", "region.%03d" % district_index))


func _district_valid(index: int) -> bool:
	return index >= 0 and index < _world().districts.size() and not bool((_world().districts[index] as Dictionary).get("destroyed", false))


func _player_valid(index: int) -> bool:
	return index >= 0 and index < _world().players.size() and _world().players[index] is Dictionary


func _actor_id(player_index: int) -> String:
	return str((_world().players[player_index] as Dictionary).get("actor_id", "player.%d" % player_index)) if _player_valid(player_index) else ""


func _refresh(receipt: DistrictSupplyActionReceipt) -> DistrictSupplyActionReceipt:
	receipt.presentation_refresh_requested = true
	presentation_refresh_requested.emit(&"full", &"district_supply_action")
	return receipt


func _receipt(intent: DistrictSupplyActionIntent, accepted: bool, reason: String) -> DistrictSupplyActionReceipt:
	var receipt := DistrictSupplyActionReceipt.new()
	if intent != null:
		receipt.request_id = intent.request_id
		receipt.action_kind = intent.action_kind
		receipt.actor_player_index = intent.actor_player_index
		receipt.district_index = intent.district_index
		receipt.card_id = intent.card_id
	receipt.accepted = accepted
	receipt.reason_code = reason
	return receipt


func _complete(receipt: DistrictSupplyActionReceipt) -> DistrictSupplyActionReceipt:
	if receipt.accepted:
		_accepted_count += 1
	else:
		_rejected_count += 1
	receipt_ready.emit(receipt)
	return receipt


func _sync_journal(session_key: String) -> void:
	if _journal_session_key == session_key:
		return
	_journal.clear()
	_journal_order.clear()
	_journal_session_key = session_key


func _remember_request(request_id: String, fingerprint: String) -> void:
	if request_id.is_empty() or _journal.has(request_id):
		return
	_journal[request_id] = fingerprint
	_journal_order.append(request_id)
	while _journal_order.size() > LEDGER_LIMIT:
		var retired_request_id: String = _journal_order.pop_front()
		_journal.erase(retired_request_id)


func _identity() -> PlayerIdentityAuthorizationBoundary:
	return get_node_or_null(identity_boundary_path) as PlayerIdentityAuthorizationBoundary


func _coordinator() -> GameRuntimeCoordinator:
	return get_node_or_null(coordinator_path) as GameRuntimeCoordinator


func _world() -> WorldSessionState:
	return get_node_or_null(world_session_state_path) as WorldSessionState


func _presentation() -> TableCardSupplyPresentationState:
	return get_node_or_null(presentation_state_path) as TableCardSupplyPresentationState


func _purchase() -> DistrictPurchaseRuntimeController:
	return get_node_or_null(purchase_controller_path) as DistrictPurchaseRuntimeController


func _commodity_inventory() -> CommodityCardInventoryRuntimeController:
	return get_node_or_null(commodity_card_inventory_path) as CommodityCardInventoryRuntimeController


func _game_session() -> GameSessionRuntimeController:
	return get_node_or_null(game_session_path) as GameSessionRuntimeController
