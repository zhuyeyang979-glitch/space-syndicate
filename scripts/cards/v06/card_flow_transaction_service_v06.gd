extends RefCounted
class_name CardFlowTransactionServiceV06

const POLICY_SCRIPT := preload("res://scripts/cards/v06/card_flow_policy_v06.gd")
const STATE_PORT_SCRIPT := preload("res://scripts/cards/v06/card_player_state_port_v06.gd")
const HAND_LIMIT := 5
const COLORED_ASSET_KEYS := ["life", "energy", "industry", "technology", "commerce", "shipping"]

var _catalog: CardRuntimeCatalogV06Resource
var _policy: CardFlowPolicyV06
var _state_port: Object
var _market_quote_authority: Object
var _belt: Dictionary = {"revision": 0, "items": {}}
var _market: Dictionary = {"revision": 0, "listing": {}}
var _journal: Dictionary = {}
var _inflight_transactions: Dictionary = {}


func _init(
	catalog: CardRuntimeCatalogV06Resource = null,
	state_port: Object = null,
	market_quote_authority: Object = null
) -> void:
	_catalog = catalog
	_policy = POLICY_SCRIPT.new() as CardFlowPolicyV06
	_state_port = state_port if state_port != null else STATE_PORT_SCRIPT.new()
	_market_quote_authority = market_quote_authority


func register_player(actor_id: String, initial_state: Dictionary) -> Dictionary:
	if actor_id.strip_edges().is_empty():
		return _setup_reject("actor_id_invalid")
	if not _catalog_ready():
		return _setup_reject("catalog_unavailable")
	var normalized := _normalize_player_state(actor_id, initial_state)
	if not bool(normalized.get("valid", false)):
		return _setup_reject(str(normalized.get("reason_code", "player_state_invalid")))
	if not _state_port_ready():
		return _setup_reject("state_port_unavailable")
	var registered_variant: Variant = _state_port.call(
		"register_player",
		actor_id,
		(normalized.get("state", {}) as Dictionary).duplicate(true)
	)
	if not (registered_variant is Dictionary):
		return _setup_reject("state_port_unavailable")
	var registered: Dictionary = registered_variant as Dictionary
	if not bool(registered.get("configured", false)):
		return _setup_reject(str(registered.get("reason_code", "player_state_invalid")))
	return {"configured": true, "reason_code": "configured", "player_state": player_snapshot(actor_id)}


func configure_belt(revision: int, entries: Array) -> Dictionary:
	if revision < 0:
		return _setup_reject("source_revision_invalid")
	if not _catalog_ready():
		return _setup_reject("catalog_unavailable")
	var items: Dictionary = {}
	for entry_variant in entries:
		if not (entry_variant is Dictionary):
			return _setup_reject("source_item_invalid")
		var normalized := _normalize_source_item(entry_variant as Dictionary, "commodity_belt")
		if not bool(normalized.get("valid", false)):
			return _setup_reject(str(normalized.get("reason_code", "source_item_invalid")))
		var item: Dictionary = normalized.get("item", {}) as Dictionary
		var item_id := str(item.get("item_id", ""))
		if items.has(item_id):
			return _setup_reject("source_item_duplicate")
		items[item_id] = item
	_belt = {"revision": revision, "items": items}
	return {"configured": true, "reason_code": "configured", "belt": belt_snapshot()}


func configure_market(revision: int, listing: Dictionary) -> Dictionary:
	if revision < 0:
		return _setup_reject("source_revision_invalid")
	if not _catalog_ready():
		return _setup_reject("catalog_unavailable")
	var normalized := _normalize_market_listing(listing)
	if not bool(normalized.get("valid", false)):
		return _setup_reject(str(normalized.get("reason_code", "market_listing_invalid")))
	_market = {
		"revision": revision,
		"listing": (normalized.get("listing", {}) as Dictionary).duplicate(true),
	}
	return {"configured": true, "reason_code": "configured", "market": market_snapshot()}


func player_snapshot(actor_id: String) -> Dictionary:
	if not _state_port_ready():
		return {}
	var read_variant: Variant = _state_port.call("read_player", actor_id)
	if not (read_variant is Dictionary):
		return {}
	var read: Dictionary = read_variant as Dictionary
	if not bool(read.get("found", false)):
		return {}
	var state_variant: Variant = read.get("player_state", {})
	return (state_variant as Dictionary).duplicate(true) if state_variant is Dictionary else {}


func player_state_port() -> Object:
	return _state_port


func belt_snapshot() -> Dictionary:
	return _belt.duplicate(true)


func market_snapshot() -> Dictionary:
	return _market.duplicate(true)


func journal_snapshot() -> Dictionary:
	return _journal.duplicate(true)


func claim_belt_card(
	actor_id: String,
	source_item_id: String,
	expected_player_revision: int,
	expected_belt_revision: int,
	transaction_id: String
) -> Dictionary:
	var intent := {
		"operation": "belt_claim",
		"actor_id": actor_id,
		"source_item_id": source_item_id,
		"expected_player_revision": expected_player_revision,
		"expected_source_revision": expected_belt_revision,
	}
	var intent_hash := _intent_hash(intent)
	var gate := _transaction_gate(transaction_id, intent_hash)
	if bool(gate.get("handled", false)):
		return (gate.get("result", {}) as Dictionary).duplicate(true)
	if not _catalog_ready():
		return _finish_reject(transaction_id, intent_hash, "belt_claim", actor_id, "catalog_unavailable")
	var reservation := _reserve_player_state(actor_id, expected_player_revision, transaction_id, intent_hash)
	if not bool(reservation.get("reserved", false)):
		return _finish_reject(
			transaction_id,
			intent_hash,
			"belt_claim",
			actor_id,
			_reservation_failure_reason(reservation)
		)
	if int(_belt.get("revision", -1)) != expected_belt_revision:
		return _abort_and_finish_reject(reservation, transaction_id, intent_hash, "belt_claim", actor_id, "source_revision_changed")
	var items: Dictionary = _belt.get("items", {}) if _belt.get("items", {}) is Dictionary else {}
	if not items.has(source_item_id):
		return _abort_and_finish_reject(reservation, transaction_id, intent_hash, "belt_claim", actor_id, "source_item_missing")
	var item: Dictionary = (items.get(source_item_id, {}) as Dictionary).duplicate(true)
	if not bool(item.get("claimable", true)):
		return _abort_and_finish_reject(reservation, transaction_id, intent_hash, "belt_claim", actor_id, "source_item_unavailable")
	if not _actor_is_legal_for_source(actor_id, item):
		return _abort_and_finish_reject(reservation, transaction_id, intent_hash, "belt_claim", actor_id, "source_item_not_visible")
	var player := _reservation_player_snapshot(reservation, actor_id)
	if player.is_empty():
		return _abort_and_finish_reject(reservation, transaction_id, intent_hash, "belt_claim", actor_id, "player_missing")
	var incoming_card := _card_with_instance(item.get("card", {}) as Dictionary, "belt:%s:%s" % [source_item_id, transaction_id])
	var receive_plan := _policy.plan_receive(player.get("inventory", {}) as Dictionary, incoming_card, _catalog)
	if not bool(receive_plan.get("ready", false)):
		return _abort_and_finish_reject(reservation, transaction_id, intent_hash, "belt_claim", actor_id, str(receive_plan.get("reason_code", "inventory_commit_failed")))
	var receive_result := _policy.commit_receive(player.get("inventory", {}) as Dictionary, receive_plan)
	if not bool(receive_result.get("committed", false)):
		return _abort_and_finish_reject(reservation, transaction_id, intent_hash, "belt_claim", actor_id, str(receive_result.get("reason_code", "inventory_commit_failed")))
	var next_player := player.duplicate(true)
	next_player["inventory"] = (receive_result.get("inventory", {}) as Dictionary).duplicate(true)
	_assign_result_instance(next_player["inventory"] as Dictionary, receive_result, transaction_id)
	var next_items := items.duplicate(true)
	next_items.erase(source_item_id)
	var next_belt := {"revision": expected_belt_revision + 1, "items": next_items}
	var mutation_prepare := _prepare_player_state_mutation(reservation, actor_id, next_player)
	if not bool(mutation_prepare.get("prepared", false)):
		return _abort_and_finish_reject(
			reservation,
			transaction_id,
			intent_hash,
			"belt_claim",
			actor_id,
			str(mutation_prepare.get("reason_code", "player_state_prepare_failed"))
		)
	var state_commit := _commit_player_state(
		reservation,
		actor_id,
		next_player,
		_state_commit_receipt("belt_claim", transaction_id, intent_hash)
	)
	if not bool(state_commit.get("committed", false)):
		return _abort_and_finish_reject(
			reservation,
			transaction_id,
			intent_hash,
			"belt_claim",
			actor_id,
			str(state_commit.get("reason_code", "player_state_commit_failed"))
		)
	_belt = next_belt
	var committed_player := _committed_player_snapshot(state_commit, actor_id)
	var result := _success_result("belt_claim", actor_id, transaction_id, intent_hash)
	result["player_state"] = committed_player
	result["belt"] = next_belt.duplicate(true)
	result["source_item_id"] = source_item_id
	result["state_port_receipt"] = _compact_state_port_receipt(state_commit)
	return _finish_transaction(transaction_id, intent_hash, result)


func purchase_market_card(
	actor_id: String,
	source_item_id: String,
	next_listing: Dictionary,
	expected_player_revision: int,
	expected_market_revision: int,
	transaction_id: String,
	quote_request: Dictionary
) -> Dictionary:
	var next_descriptor := _listing_intent_descriptor(next_listing)
	var intent := {
		"operation": "market_purchase",
		"actor_id": actor_id,
		"source_item_id": source_item_id,
		"expected_player_revision": expected_player_revision,
		"expected_source_revision": expected_market_revision,
		"next_listing": next_descriptor,
		"quote_id": str(quote_request.get("quote_id", "")),
		"quote_fingerprint": str(quote_request.get("quote_fingerprint", "")),
	}
	var intent_hash := _intent_hash(intent)
	var gate := _transaction_gate(transaction_id, intent_hash)
	if bool(gate.get("handled", false)):
		return (gate.get("result", {}) as Dictionary).duplicate(true)
	if not _catalog_ready():
		return _finish_reject(transaction_id, intent_hash, "market_purchase", actor_id, "catalog_unavailable")
	var reservation := _reserve_player_state(actor_id, expected_player_revision, transaction_id, intent_hash)
	if not bool(reservation.get("reserved", false)):
		return _finish_reject(
			transaction_id,
			intent_hash,
			"market_purchase",
			actor_id,
			_reservation_failure_reason(reservation)
		)
	if int(_market.get("revision", -1)) != expected_market_revision:
		return _abort_and_finish_reject(reservation, transaction_id, intent_hash, "market_purchase", actor_id, "source_revision_changed")
	var listing: Dictionary = _market.get("listing", {}) if _market.get("listing", {}) is Dictionary else {}
	if str(listing.get("item_id", "")) != source_item_id:
		return _abort_and_finish_reject(reservation, transaction_id, intent_hash, "market_purchase", actor_id, "market_listing_changed")
	if not bool(listing.get("claimable", true)) or not _actor_is_legal_for_source(actor_id, listing):
		return _abort_and_finish_reject(reservation, transaction_id, intent_hash, "market_purchase", actor_id, "source_item_unavailable")
	var normalized_next := _normalize_market_listing(next_listing)
	if not bool(normalized_next.get("valid", false)):
		return _abort_and_finish_reject(reservation, transaction_id, intent_hash, "market_purchase", actor_id, "market_next_listing_invalid")
	var next_market_listing: Dictionary = normalized_next.get("listing", {}) as Dictionary
	if str(next_market_listing.get("item_id", "")) == source_item_id:
		return _abort_and_finish_reject(reservation, transaction_id, intent_hash, "market_purchase", actor_id, "market_next_listing_reuses_item")
	var player := _reservation_player_snapshot(reservation, actor_id)
	if player.is_empty():
		return _abort_and_finish_reject(reservation, transaction_id, intent_hash, "market_purchase", actor_id, "player_missing")
	if not _valid_market_quote_request(quote_request):
		return _abort_and_finish_reject(reservation, transaction_id, intent_hash, "market_purchase", actor_id, "market_quote_request_invalid")
	if _market_quote_authority == null or not _market_quote_authority.has_method("authorize_purchase"):
		return _abort_and_finish_reject(reservation, transaction_id, intent_hash, "market_purchase", actor_id, "market_quote_authority_unavailable")
	var authorization_variant: Variant = _market_quote_authority.call("authorize_purchase", quote_request.duplicate(true))
	var authorization: Dictionary = authorization_variant if authorization_variant is Dictionary else {}
	if not bool(authorization.get("authorized", false)):
		return _abort_and_finish_reject(reservation, transaction_id, intent_hash, "market_purchase", actor_id, "market_quote_unauthorized")
	var actor_player_index := _actor_player_index(actor_id)
	if actor_player_index < 0 \
			or actor_player_index != int(quote_request.get("player_index", -2)) \
			or int(authorization.get("player_index", -1)) != actor_player_index \
			or str(authorization.get("quote_id", "")) != str(quote_request.get("quote_id", "")) \
			or str(authorization.get("quote_fingerprint", "")) != str(quote_request.get("quote_fingerprint", "")) \
			or str(authorization.get("card_id", "")) != str(_machine(listing.get("card", {}) as Dictionary).get("card_id", "")) \
			or int(authorization.get("district_index", -1)) != int(listing.get("source_district_index", -1)) \
			or str(authorization.get("supply_revision", "")) != str(listing.get("supply_revision", "")):
		return _abort_and_finish_reject(reservation, transaction_id, intent_hash, "market_purchase", actor_id, "market_quote_binding_mismatch")
	var price_cash := int(authorization.get("final_price", -1))
	if price_cash < 0:
		return _abort_and_finish_reject(reservation, transaction_id, intent_hash, "market_purchase", actor_id, "market_listing_invalid")
	if int(player.get("cash", 0)) < price_cash:
		return _abort_and_finish_reject(reservation, transaction_id, intent_hash, "market_purchase", actor_id, "cash_insufficient")
	var incoming_card := _card_with_instance(listing.get("card", {}) as Dictionary, "market:%s:%s" % [source_item_id, transaction_id])
	var receive_plan := _policy.plan_receive(player.get("inventory", {}) as Dictionary, incoming_card, _catalog)
	if not bool(receive_plan.get("ready", false)):
		return _abort_and_finish_reject(reservation, transaction_id, intent_hash, "market_purchase", actor_id, str(receive_plan.get("reason_code", "inventory_commit_failed")))
	var receive_result := _policy.commit_receive(player.get("inventory", {}) as Dictionary, receive_plan)
	if not bool(receive_result.get("committed", false)):
		return _abort_and_finish_reject(reservation, transaction_id, intent_hash, "market_purchase", actor_id, str(receive_result.get("reason_code", "inventory_commit_failed")))
	var next_player := player.duplicate(true)
	next_player["inventory"] = (receive_result.get("inventory", {}) as Dictionary).duplicate(true)
	_assign_result_instance(next_player["inventory"] as Dictionary, receive_result, transaction_id)
	next_player["cash"] = int(player.get("cash", 0)) - price_cash
	next_player["card_purchase_count"] = int(player.get("card_purchase_count", 0)) + 1
	next_player["total_card_spend"] = int(player.get("total_card_spend", 0)) + price_cash
	var next_market := {
		"revision": expected_market_revision + 1,
		"listing": next_market_listing.duplicate(true),
	}
	var mutation_prepare := _prepare_player_state_mutation(reservation, actor_id, next_player)
	if not bool(mutation_prepare.get("prepared", false)):
		return _abort_and_finish_reject(
			reservation,
			transaction_id,
			intent_hash,
			"market_purchase",
			actor_id,
			str(mutation_prepare.get("reason_code", "player_state_prepare_failed"))
		)
	var state_commit := _commit_player_state(
		reservation,
		actor_id,
		next_player,
		_state_commit_receipt("market_purchase", transaction_id, intent_hash)
	)
	if not bool(state_commit.get("committed", false)):
		return _abort_and_finish_reject(
			reservation,
			transaction_id,
			intent_hash,
			"market_purchase",
			actor_id,
			str(state_commit.get("reason_code", "player_state_commit_failed"))
		)
	_market = next_market
	var committed_player := _committed_player_snapshot(state_commit, actor_id)
	var result := _success_result("market_purchase", actor_id, transaction_id, intent_hash)
	result["player_state"] = committed_player
	result["market"] = next_market.duplicate(true)
	result["cash_debit"] = price_cash
	result["source_item_id"] = source_item_id
	result["market_refreshed"] = true
	result["state_port_receipt"] = _compact_state_port_receipt(state_commit)
	return _finish_transaction(transaction_id, intent_hash, result)


func _valid_market_quote_request(request: Dictionary) -> bool:
	return not str(request.get("quote_id", "")).is_empty() \
		and not str(request.get("quote_fingerprint", "")).is_empty() \
		and int(request.get("player_index", -1)) >= 0 \
		and int(request.get("district_index", -1)) >= 0 \
		and not str(request.get("card_id", "")).is_empty() \
		and not str(request.get("supply_revision", "")).is_empty()


func _actor_player_index(actor_id: String) -> int:
	if _state_port == null or not _state_port.has_method("actor_player_indices"):
		return -1
	var value: Variant = _state_port.call("actor_player_indices")
	var actor_map: Dictionary = value if value is Dictionary else {}
	return int(actor_map.get(actor_id, -1))


func manual_merge(
	actor_id: String,
	first_slot: int,
	second_slot: int,
	expected_player_revision: int,
	transaction_id: String
) -> Dictionary:
	var intent := {
		"operation": "manual_merge",
		"actor_id": actor_id,
		"first_slot": first_slot,
		"second_slot": second_slot,
		"expected_player_revision": expected_player_revision,
	}
	var intent_hash := _intent_hash(intent)
	var gate := _transaction_gate(transaction_id, intent_hash)
	if bool(gate.get("handled", false)):
		return (gate.get("result", {}) as Dictionary).duplicate(true)
	if not _catalog_ready():
		return _finish_reject(transaction_id, intent_hash, "manual_merge", actor_id, "catalog_unavailable")
	var reservation := _reserve_player_state(actor_id, expected_player_revision, transaction_id, intent_hash)
	if not bool(reservation.get("reserved", false)):
		return _finish_reject(
			transaction_id,
			intent_hash,
			"manual_merge",
			actor_id,
			_reservation_failure_reason(reservation)
		)
	var player := _reservation_player_snapshot(reservation, actor_id)
	if player.is_empty():
		return _abort_and_finish_reject(reservation, transaction_id, intent_hash, "manual_merge", actor_id, "player_missing")
	var inventory: Dictionary = player.get("inventory", {}) as Dictionary
	var plan := _policy.plan_manual_merge(inventory, first_slot, second_slot, _catalog)
	if not bool(plan.get("ready", false)):
		return _abort_and_finish_reject(reservation, transaction_id, intent_hash, "manual_merge", actor_id, str(plan.get("reason_code", "merge_card_missing")))
	var commit := _policy.commit_manual_merge(inventory, plan)
	if not bool(commit.get("committed", false)):
		return _abort_and_finish_reject(reservation, transaction_id, intent_hash, "manual_merge", actor_id, str(commit.get("reason_code", "inventory_commit_failed")))
	var next_player := player.duplicate(true)
	next_player["inventory"] = (commit.get("inventory", {}) as Dictionary).duplicate(true)
	_assign_result_instance(next_player["inventory"] as Dictionary, commit, transaction_id)
	var mutation_prepare := _prepare_player_state_mutation(reservation, actor_id, next_player)
	if not bool(mutation_prepare.get("prepared", false)):
		return _abort_and_finish_reject(
			reservation,
			transaction_id,
			intent_hash,
			"manual_merge",
			actor_id,
			str(mutation_prepare.get("reason_code", "player_state_prepare_failed"))
		)
	var state_commit := _commit_player_state(
		reservation,
		actor_id,
		next_player,
		_state_commit_receipt("manual_merge", transaction_id, intent_hash)
	)
	if not bool(state_commit.get("committed", false)):
		return _abort_and_finish_reject(
			reservation,
			transaction_id,
			intent_hash,
			"manual_merge",
			actor_id,
			str(state_commit.get("reason_code", "player_state_commit_failed"))
		)
	var committed_player := _committed_player_snapshot(state_commit, actor_id)
	var result := _success_result("manual_merge", actor_id, transaction_id, intent_hash)
	result["player_state"] = committed_player
	result["result_card_id"] = plan.get("result_card_id", "")
	result["state_port_receipt"] = _compact_state_port_receipt(state_commit)
	return _finish_transaction(transaction_id, intent_hash, result)


func play_card(
	actor_id: String,
	slot_index: int,
	target_context: Dictionary,
	effect_handler: Object,
	expected_player_revision: int,
	transaction_id: String
) -> Dictionary:
	var target_hash := _intent_hash(target_context)
	var intent := {
		"operation": "play_card",
		"actor_id": actor_id,
		"slot_index": slot_index,
		"target_hash": target_hash,
		"expected_player_revision": expected_player_revision,
	}
	var intent_hash := _intent_hash(intent)
	var gate := _transaction_gate(transaction_id, intent_hash)
	if bool(gate.get("handled", false)):
		return (gate.get("result", {}) as Dictionary).duplicate(true)
	if not _catalog_ready():
		return _finish_reject(transaction_id, intent_hash, "play_card", actor_id, "catalog_unavailable")
	var reservation := _reserve_player_state(actor_id, expected_player_revision, transaction_id, intent_hash)
	if not bool(reservation.get("reserved", false)):
		return _finish_reject(
			transaction_id,
			intent_hash,
			"play_card",
			actor_id,
			_reservation_failure_reason(reservation)
		)
	var player_before := _reservation_player_snapshot(reservation, actor_id)
	if player_before.is_empty():
		return _abort_and_finish_reject(reservation, transaction_id, intent_hash, "play_card", actor_id, "player_missing")
	var card_before := _inventory_card_at(player_before, slot_index)
	var machine := _machine(card_before)
	var payload: Dictionary = machine.get("effect_payload", {}) if machine.get("effect_payload", {}) is Dictionary else {}
	var payload_hash := _intent_hash(payload)
	if card_before.is_empty() or str(machine.get("card_id", "")).is_empty():
		return _abort_and_finish_reject(reservation, transaction_id, intent_hash, "play_card", actor_id, "play_card_missing")
	if effect_handler == null or not effect_handler.has_method("prepare_effect") or not effect_handler.has_method("commit_effect"):
		return _abort_and_finish_reject(reservation, transaction_id, intent_hash, "play_card", actor_id, "effect_handler_unavailable")
	var effect_kind := str(machine.get("effect_kind", ""))
	var plan := _policy.plan_play(player_before, slot_index, target_context, [effect_kind], transaction_id)
	if not bool(plan.get("ready", false)):
		return _abort_and_finish_reject(reservation, transaction_id, intent_hash, "play_card", actor_id, str(plan.get("reason_code", "play_preflight_failed")))
	var asset_debit: Dictionary = plan.get("asset_debit", {}) if plan.get("asset_debit", {}) is Dictionary else {}
	if not _asset_debit_is_six_color(asset_debit):
		return _abort_and_finish_reject(reservation, transaction_id, intent_hash, "play_card", actor_id, "asset_allocation_invalid")
	var binding := {
		"transaction_id": transaction_id,
		"actor_id": actor_id,
		"card_id": str(machine.get("card_id", "")),
		"card_instance_id": str(card_before.get("runtime_instance_id", "")),
		"effect_kind": effect_kind,
		"target_hash": target_hash,
		"payload_hash": payload_hash,
		"intent_hash": intent_hash,
	}
	var effect_intent := binding.duplicate(true)
	effect_intent["target_context"] = target_context.duplicate(true)
	effect_intent["effect_payload"] = payload.duplicate(true)
	effect_intent["contract"] = "prepare_is_side_effect_free"
	var prepared_variant: Variant = effect_handler.call("prepare_effect", effect_intent.duplicate(true))
	if not (prepared_variant is Dictionary):
		return _abort_and_finish_reject(reservation, transaction_id, intent_hash, "play_card", actor_id, "effect_prepare_failed")
	var prepared: Dictionary = prepared_variant as Dictionary
	if not bool(prepared.get("prepared", false)):
		_abort_prepared_effect(effect_handler, prepared)
		return _abort_and_finish_reject(reservation, transaction_id, intent_hash, "play_card", actor_id, "effect_prepare_failed")
	if not _receipt_matches_binding(prepared, binding):
		_abort_prepared_effect(effect_handler, prepared)
		return _abort_and_finish_reject(reservation, transaction_id, intent_hash, "play_card", actor_id, "effect_receipt_invalid")
	var next_player_result := _consume_reserved_play(player_before, slot_index, binding, asset_debit)
	if not bool(next_player_result.get("valid", false)):
		_abort_prepared_effect(effect_handler, prepared)
		return _abort_and_finish_reject(reservation, transaction_id, intent_hash, "play_card", actor_id, str(next_player_result.get("reason_code", "play_card_changed")))
	var next_player: Dictionary = next_player_result.get("player_state", {}) as Dictionary
	var mutation_prepare := _prepare_player_state_mutation(reservation, actor_id, next_player)
	if not bool(mutation_prepare.get("prepared", false)):
		_abort_prepared_effect(effect_handler, prepared)
		return _abort_and_finish_reject(
			reservation,
			transaction_id,
			intent_hash,
			"play_card",
			actor_id,
			str(mutation_prepare.get("reason_code", "player_state_prepare_failed"))
		)
	var commit_variant: Variant = effect_handler.call("commit_effect", prepared.duplicate(true))
	if not (commit_variant is Dictionary):
		return _abort_and_finish_reject(
			reservation,
			transaction_id,
			intent_hash,
			"play_card",
			actor_id,
			"effect_commit_failed",
			{"rolled_back": false, "compensation_required": false}
		)
	var effect_commit: Dictionary = commit_variant as Dictionary
	if not _receipt_matches_binding(effect_commit, binding):
		var invalid_receipt_compensation := _compensate_effect(effect_handler, effect_commit)
		var invalid_receipt_reason := "effect_receipt_invalid" if bool(invalid_receipt_compensation.get("rolled_back", false)) else "effect_compensation_failed"
		return _abort_and_finish_reject(
			reservation,
			transaction_id,
			intent_hash,
			"play_card",
			actor_id,
			invalid_receipt_reason,
			{
				"rolled_back": bool(invalid_receipt_compensation.get("rolled_back", false)),
				"compensation_failed": bool(invalid_receipt_compensation.get("compensation_failed", true)),
				"original_reason_code": "effect_receipt_invalid",
				"compensation": invalid_receipt_compensation,
			}
		)
	if not bool(effect_commit.get("committed", false)):
		# A structured commit rejection is contractually zero-effect, so release
		# the prepared owner/router association instead of leaking it forever.
		_abort_prepared_effect(effect_handler, prepared)
		return _abort_and_finish_reject(
			reservation,
			transaction_id,
			intent_hash,
			"play_card",
			actor_id,
			"effect_commit_failed",
			{"rolled_back": false, "compensation_required": false}
		)
	var state_commit := _commit_player_state(reservation, actor_id, next_player, effect_commit)
	if not bool(state_commit.get("committed", false)):
		var compensation := _compensate_effect(effect_handler, effect_commit)
		var state_reason := str(state_commit.get("reason_code", "player_state_commit_failed"))
		var terminal_reason := "player_state_commit_failed" if bool(compensation.get("rolled_back", false)) else "effect_compensation_failed"
		return _abort_and_finish_reject(
			reservation,
			transaction_id,
			intent_hash,
			"play_card",
			actor_id,
			terminal_reason,
			{
				"rolled_back": bool(compensation.get("rolled_back", false)),
				"compensation_failed": bool(compensation.get("compensation_failed", true)),
				"original_reason_code": "player_state_commit_failed",
				"state_port_reason_code": state_reason,
				"compensation": compensation,
			}
		)
	var committed_player := _committed_player_snapshot(state_commit, actor_id)
	var finalization := _finalize_effect(effect_handler, effect_commit)
	var result := _success_result("play_card", actor_id, transaction_id, intent_hash)
	result["player_state"] = committed_player
	result["card_id"] = binding.get("card_id", "")
	result["card_instance_id"] = binding.get("card_instance_id", "")
	result["effect_kind"] = effect_kind
	result["effect_receipt"] = effect_commit.duplicate(true)
	result["effect_finalization"] = finalization
	result["state_port_receipt"] = _compact_state_port_receipt(state_commit)
	return _finish_transaction(transaction_id, intent_hash, result)


func player_feedback(reason_code: String) -> Dictionary:
	var messages := {
		"actor_id_invalid": ["玩家身份无效。", "返回对局并重新选择当前玩家。"],
		"catalog_unavailable": ["卡牌目录尚未就绪。", "等待卡牌数据加载完成后再试。"],
		"player_state_invalid": ["玩家状态无法载入。", "重新同步本局玩家数据。"],
		"player_missing": ["当前玩家尚未加入这局游戏。", "重新进入对局或等待玩家同步完成。"],
		"player_revision_changed": ["你的卡牌或资产已经发生变化。", "使用最新手牌与资产重新确认。"],
		"source_revision_invalid": ["牌源版本无效。", "重新载入当前牌源。"],
		"source_revision_changed": ["这批牌已经发生变化。", "查看刷新后的牌并重新选择。"],
		"source_item_invalid": ["这张来源牌的数据不完整。", "等待牌源重新生成。"],
		"source_item_duplicate": ["牌源中出现了重复位置。", "等待牌源重新生成。"],
		"source_item_missing": ["这张牌已经不在原来的位置。", "从当前可见牌中重新选择。"],
		"source_item_unavailable": ["这张牌当前不能领取或购买。", "查看它的新价格或合法条件后再试。"],
		"source_item_not_visible": ["你目前只能看见这张商品的颜色。", "等待排名或履带位置变化后再领取。"],
		"market_listing_invalid": ["当前市场牌的数据无效。", "等待市场立即刷新。"],
		"market_listing_changed": ["这张市场牌已被买走。", "直接查看刷新后的下一张牌。"],
		"market_next_listing_invalid": ["下一张市场牌未能生成。", "本次不会扣钱或拿牌，请重新刷新。"],
		"market_next_listing_reuses_item": ["市场没有生成新的牌位。", "生成新的牌位后再购买。"],
		"cash_insufficient": ["现金不足，无法购买这张牌。", "等待收入增长或选择更便宜的牌。"],
		"hand_limit_mismatch": ["手牌上限状态不同步。", "重新同步手牌后再操作。"],
		"incoming_card_invalid": ["这张牌的数据不完整。", "从当前牌源重新选择。"],
		"hand_full_no_matching_merge": ["手牌已满，且没有同名同级牌可自动合成。", "先打出一张牌，或手动合成已有同名同级牌。"],
		"matching_card_at_max_rank": ["同名牌已经是 IV 级，不能继续合成。", "先打出一张牌腾出位置。"],
		"merge_requires_two_cards": ["合成需要两张不同位置的牌。", "选择两张同名同级牌。"],
		"merge_slot_invalid": ["选择的手牌位置已经变化。", "在最新手牌中重新选择两张牌。"],
		"merge_card_missing": ["其中一张合成牌已经不在手中。", "在最新手牌中重新选择。"],
		"merge_family_mismatch": ["只有同名牌可以合成。", "请选择两张同名同级牌。"],
		"merge_rank_mismatch": ["不同等级的牌不能直接合成。", "请选择两张同名同级牌。"],
		"merge_result_missing": ["合成后的等级牌尚未载入。", "等待卡牌目录同步完成。"],
		"inventory_changed": ["手牌已经发生变化。", "使用最新手牌重新操作。"],
		"target_slot_invalid": ["预定的手牌位置无效。", "重新同步手牌并再次操作。"],
		"target_slot_occupied": ["预定的手牌位置已被占用。", "使用最新手牌重新操作。"],
		"merge_source_missing": ["用于自动合成的同名牌已经离开手牌。", "同步手牌后重新领取。"],
		"operation_invalid": ["这项卡牌操作无法识别。", "取消当前操作并重新发起。"],
		"inventory_commit_failed": ["手牌更新没有完成。", "本次不会扣费，请重新操作。"],
		"play_card_missing": ["要打出的牌已经不在该位置。", "从最新手牌重新选择。"],
		"play_card_changed": ["预留的牌已经发生变化。", "重新选择这张牌并确认目标。"],
		"effect_handler_unavailable": ["这张牌的效果尚未接入本局。", "本次不会消耗卡牌，请选择其他可用牌。"],
		"effect_owner_unavailable": ["这张牌的效果尚未接入本局。", "本次不会消耗卡牌，请选择其他可用牌。"],
		"target_invalid": ["当前目标不合法。", "选择牌面允许的目标后再确认。"],
		"assets_insufficient": ["对应颜色的资产不足。", "让自己的该色商品产生更多 GDP 后再打出。"],
		"asset_allocation_invalid": ["通用费用的资产分配无效。", "从六种产业资产中重新分配，或使用自动分配。"],
		"player_busy": ["该玩家正在结算另一张牌。", "等待当前结算完成后再操作。"],
		"transaction_id_missing": ["本次操作缺少交易编号。", "重新发起操作。"],
		"transaction_in_progress": ["这项操作正在结算。", "等待当前结算结果，不要重复点击。"],
		"transaction_intent_collision": ["同一交易编号对应了不同操作。", "取消旧操作并用新的交易编号重试。"],
		"effect_prepare_failed": ["效果未能通过最终预检。", "卡牌和资产均未消耗，请重新选择目标。"],
		"effect_receipt_invalid": ["效果结算凭据与这张牌不匹配。", "本次玩家状态已恢复，请重新发起操作。"],
		"effect_commit_failed": ["效果没有成功结算。", "卡牌和资产已恢复，请重新操作。"],
		"effect_compensation_failed": ["效果结算后未能安全撤销。", "本次卡牌、现金和资产没有提交；请等待对局同步完成后再操作。"],
		"play_preflight_failed": ["这张牌目前不能打出。", "检查目标和资产后再试。"],
		"state_port_unavailable": ["玩家状态服务尚未就绪。", "等待手牌、现金和资产完成同步后再试。"],
		"player_state_prepare_failed": ["玩家状态未能完成安全预留。", "本次不会扣牌、现金或资产；同步最新状态后重试。"],
		"state_port_replay_conflict": ["这项玩家状态已经结算，但牌源仍需同步。", "等待本局状态同步完成后再操作。"],
		"player_state_commit_failed": ["效果完成后，玩家状态未能安全提交。", "效果已确认撤销；同步最新手牌和资产后重试。"],
		"reservation_lost": ["本次玩家状态预留已经失效。", "同步最新状态并重新发起操作。"],
	}
	var pair: Array = messages.get(reason_code, ["当前操作没有完成。", "玩家状态未被消耗，请同步后重新操作。"])
	return {"reason": str(pair[0]), "next_step": str(pair[1])}


func _catalog_ready() -> bool:
	return _catalog != null and bool(_catalog.validation_report().get("valid", false))


func _normalize_player_state(actor_id: String, initial_state: Dictionary) -> Dictionary:
	var revision := int(initial_state.get("revision", 0))
	var cash := int(initial_state.get("cash", 0))
	var card_purchase_count := int(initial_state.get("card_purchase_count", 0))
	var total_card_spend := int(initial_state.get("total_card_spend", 0))
	if revision < 0 or cash < 0 or card_purchase_count < 0 or total_card_spend < 0:
		return {"valid": false, "reason_code": "player_state_invalid"}
	var has_player_index := initial_state.has("player_index")
	var player_index := int(initial_state.get("player_index", -1))
	if has_player_index and player_index < 0:
		return {"valid": false, "reason_code": "player_index_invalid"}
	var input_assets: Dictionary = initial_state.get("assets", {}) if initial_state.get("assets", {}) is Dictionary else {}
	for key_variant in input_assets.keys():
		if not COLORED_ASSET_KEYS.has(str(key_variant)):
			return {"valid": false, "reason_code": "asset_allocation_invalid"}
	var assets: Dictionary = {}
	for key in COLORED_ASSET_KEYS:
		var value := int(input_assets.get(key, 0))
		if value < 0:
			return {"valid": false, "reason_code": "player_state_invalid"}
		assets[key] = value
	var input_inventory: Dictionary = initial_state.get("inventory", {}) if initial_state.get("inventory", {}) is Dictionary else {}
	if int(input_inventory.get("hand_limit", HAND_LIMIT)) != HAND_LIMIT:
		return {"valid": false, "reason_code": "hand_limit_mismatch"}
	var input_slots: Array = input_inventory.get("slots", []) if input_inventory.get("slots", []) is Array else []
	var slots: Array = []
	for slot_index in range(input_slots.size()):
		var slot_variant: Variant = input_slots[slot_index]
		if not (slot_variant is Dictionary):
			slots.append(null)
			continue
		var machine := _machine(slot_variant as Dictionary)
		var card_id := str(machine.get("card_id", ""))
		var canonical := _catalog.card_snapshot(card_id)
		if canonical.is_empty():
			return {"valid": false, "reason_code": "incoming_card_invalid"}
		var instance_id := str((slot_variant as Dictionary).get("runtime_instance_id", ""))
		if instance_id.is_empty():
			instance_id = "setup:%s:%d:%s" % [actor_id, slot_index, card_id]
		canonical["runtime_instance_id"] = instance_id
		slots.append(canonical)
	var normalized_state := {
			"actor_id": actor_id,
			"revision": revision,
			"cash": cash,
			"card_purchase_count": card_purchase_count,
			"total_card_spend": total_card_spend,
			"assets": assets,
			"inventory": {"hand_limit": HAND_LIMIT, "slots": slots},
	}
	if has_player_index:
		normalized_state["player_index"] = player_index
	return {"valid": true, "state": normalized_state}


func _normalize_source_item(entry: Dictionary, source_kind: String) -> Dictionary:
	var item_id := str(entry.get("item_id", "")).strip_edges()
	var input_card: Dictionary = entry.get("card", {}) if entry.get("card", {}) is Dictionary else {}
	var card_id := str(_machine(input_card).get("card_id", ""))
	var canonical := _catalog.card_snapshot(card_id)
	if item_id.is_empty() or canonical.is_empty():
		return {"valid": false, "reason_code": "source_item_invalid"}
	var acquisition_kind := str(_machine(canonical).get("acquisition_kind", ""))
	if source_kind == "commodity_belt" and acquisition_kind != "commodity_belt_free":
		return {"valid": false, "reason_code": "source_item_invalid"}
	var visible_actor_ids: Array = entry.get("visible_actor_ids", []) if entry.get("visible_actor_ids", []) is Array else []
	return {
		"valid": true,
		"item": {
			"item_id": item_id,
			"card": canonical,
			"claimable": bool(entry.get("claimable", true)),
			"visible_actor_ids": visible_actor_ids.duplicate(true),
		},
	}


func _normalize_market_listing(listing: Dictionary) -> Dictionary:
	var item_id := str(listing.get("item_id", "")).strip_edges()
	var input_card: Dictionary = listing.get("card", {}) if listing.get("card", {}) is Dictionary else {}
	var card_id := str(_machine(input_card).get("card_id", ""))
	var canonical := _catalog.card_snapshot(card_id)
	if item_id.is_empty() or canonical.is_empty():
		return {"valid": false, "reason_code": "market_listing_invalid"}
	var acquisition_kind := str(_machine(canonical).get("acquisition_kind", ""))
	if acquisition_kind != "dynamic_market_cash" and acquisition_kind != "starter_or_dynamic_market_cash":
		return {"valid": false, "reason_code": "market_listing_invalid"}
	var price_cash := int(listing.get("price_cash", _machine(canonical).get("purchase_cash", -1)))
	var source_district_index := int(listing.get("source_district_index", -1))
	var source_region_id := str(listing.get("source_region_id", "")).strip_edges()
	var supply_revision := str(listing.get("supply_revision", ""))
	if price_cash < 0 or source_district_index < 0 or source_region_id.is_empty() or supply_revision.is_empty():
		return {"valid": false, "reason_code": "market_listing_invalid"}
	var legal_actor_ids: Array = listing.get("legal_actor_ids", []) if listing.get("legal_actor_ids", []) is Array else []
	return {
		"valid": true,
		"listing": {
			"item_id": item_id,
			"card": canonical,
			"price_cash": price_cash,
			"claimable": bool(listing.get("claimable", true)),
			"legal_actor_ids": legal_actor_ids.duplicate(true),
			"source_district_index": source_district_index,
			"source_region_id": source_region_id,
			"supply_revision": supply_revision,
		},
	}


func _listing_intent_descriptor(listing: Dictionary) -> Dictionary:
	var input_card: Dictionary = listing.get("card", {}) if listing.get("card", {}) is Dictionary else {}
	return {
		"item_id": str(listing.get("item_id", "")),
		"card_id": str(_machine(input_card).get("card_id", "")),
		"price_cash": int(listing.get("price_cash", -1)),
		"claimable": bool(listing.get("claimable", true)),
		"legal_actor_ids": (listing.get("legal_actor_ids", []) as Array).duplicate(true) if listing.get("legal_actor_ids", []) is Array else [],
		"source_district_index": int(listing.get("source_district_index", -1)),
		"source_region_id": str(listing.get("source_region_id", "")),
		"supply_revision": str(listing.get("supply_revision", "")),
	}


func _actor_is_legal_for_source(actor_id: String, item: Dictionary) -> bool:
	var actors_variant: Variant = item.get("visible_actor_ids", item.get("legal_actor_ids", []))
	if not (actors_variant is Array):
		return false
	var actors: Array = actors_variant
	return actors.is_empty() or actors.has(actor_id)


func _state_port_ready() -> bool:
	if _state_port == null:
		return false
	for method_name in [
		"register_player",
		"read_player",
		"reserve_transaction",
		"commit_reserved",
		"abort_reserved",
		"replay_result",
	]:
		if not _state_port.has_method(method_name):
			return false
	return true


func _reserve_player_state(
	actor_id: String,
	expected_revision: int,
	transaction_id: String,
	intent_hash: String
) -> Dictionary:
	if not _state_port_ready():
		return {"reserved": false, "reason_code": "state_port_unavailable"}
	var reservation_variant: Variant = _state_port.call(
		"reserve_transaction",
		transaction_id,
		intent_hash,
		{actor_id: expected_revision},
		[actor_id]
	)
	if not (reservation_variant is Dictionary):
		return {"reserved": false, "reason_code": "state_port_unavailable"}
	var reservation := (reservation_variant as Dictionary).duplicate(true)
	if bool(reservation.get("reserved", false)):
		_inflight_transactions[transaction_id] = intent_hash
	return reservation


func _reservation_failure_reason(reservation: Dictionary) -> String:
	if bool(reservation.get("idempotent_replay", false)) \
	and bool(reservation.get("committed", false)):
		return "state_port_replay_conflict"
	var reason_code := str(reservation.get("reason_code", "state_port_unavailable"))
	if reason_code == "committed" or reason_code == "reserved":
		return "state_port_replay_conflict"
	return reason_code


func _reservation_player_snapshot(reservation: Dictionary, actor_id: String) -> Dictionary:
	var before_snapshots: Dictionary = reservation.get("before_snapshots", {}) \
		if reservation.get("before_snapshots", {}) is Dictionary else {}
	var state_variant: Variant = before_snapshots.get(actor_id, {})
	return (state_variant as Dictionary).duplicate(true) if state_variant is Dictionary else {}


func _commit_player_state(
	reservation: Dictionary,
	actor_id: String,
	next_player: Dictionary,
	effect_receipt: Dictionary
) -> Dictionary:
	if not _state_port_ready():
		return {"committed": false, "reason_code": "state_port_unavailable"}
	var reservation_id := str(reservation.get("reservation_id", ""))
	if reservation_id.is_empty():
		return {"committed": false, "reason_code": "reservation_lost"}
	var commit_variant: Variant = _state_port.call(
		"commit_reserved",
		reservation_id,
		{actor_id: next_player.duplicate(true)},
		effect_receipt.duplicate(true)
	)
	if not (commit_variant is Dictionary):
		return {"committed": false, "reason_code": "state_port_unavailable"}
	return (commit_variant as Dictionary).duplicate(true)


func _prepare_player_state_mutation(
	reservation: Dictionary,
	actor_id: String,
	next_player: Dictionary
) -> Dictionary:
	if not _state_port_ready():
		return {"prepared": false, "reason_code": "state_port_unavailable"}
	if not _state_port.has_method("prepare_reserved_mutations"):
		return {"prepared": true, "reason_code": "reference_port_uses_commit_cas"}
	var reservation_id := str(reservation.get("reservation_id", ""))
	var prepared_variant: Variant = _state_port.call(
		"prepare_reserved_mutations",
		reservation_id,
		{actor_id: next_player.duplicate(true)}
	)
	if not (prepared_variant is Dictionary):
		return {"prepared": false, "reason_code": "player_state_prepare_failed"}
	return (prepared_variant as Dictionary).duplicate(true)


func _committed_player_snapshot(state_commit: Dictionary, actor_id: String) -> Dictionary:
	var player_states: Dictionary = state_commit.get("player_states", {}) \
		if state_commit.get("player_states", {}) is Dictionary else {}
	var state_variant: Variant = player_states.get(actor_id, {})
	if state_variant is Dictionary and not (state_variant as Dictionary).is_empty():
		return (state_variant as Dictionary).duplicate(true)
	return player_snapshot(actor_id)


func _state_commit_receipt(operation: String, transaction_id: String, intent_hash: String) -> Dictionary:
	return {
		"committed": true,
		"operation": operation,
		"transaction_id": transaction_id,
		"intent_hash": intent_hash,
	}


func _compact_state_port_receipt(state_commit: Dictionary) -> Dictionary:
	return {
		"reservation_id": str(state_commit.get("reservation_id", "")),
		"transaction_id": str(state_commit.get("transaction_id", "")),
		"intent_hash": str(state_commit.get("intent_hash", "")),
		"previous_revision_vector": (state_commit.get("previous_revision_vector", {}) as Dictionary).duplicate(true) \
			if state_commit.get("previous_revision_vector", {}) is Dictionary else {},
		"revision_vector": (state_commit.get("revision_vector", {}) as Dictionary).duplicate(true) \
			if state_commit.get("revision_vector", {}) is Dictionary else {},
	}


func _abort_state_reservation(reservation: Dictionary, reason_code: String) -> void:
	if not _state_port_ready():
		return
	var reservation_id := str(reservation.get("reservation_id", ""))
	if reservation_id.is_empty():
		return
	_state_port.call("abort_reserved", reservation_id, reason_code)


func _abort_and_finish_reject(
	reservation: Dictionary,
	transaction_id: String,
	intent_hash: String,
	operation: String,
	actor_id: String,
	reason_code: String,
	extra: Dictionary = {}
) -> Dictionary:
	_abort_state_reservation(reservation, reason_code)
	return _finish_reject(transaction_id, intent_hash, operation, actor_id, reason_code, extra)


func _inventory_card_at(player_state: Dictionary, slot_index: int) -> Dictionary:
	var inventory: Dictionary = player_state.get("inventory", {}) if player_state.get("inventory", {}) is Dictionary else {}
	var slots: Array = inventory.get("slots", []) if inventory.get("slots", []) is Array else []
	if slot_index < 0 or slot_index >= slots.size() or not (slots[slot_index] is Dictionary):
		return {}
	return (slots[slot_index] as Dictionary).duplicate(true)


func _consume_reserved_play(player: Dictionary, slot_index: int, binding: Dictionary, asset_debit: Dictionary) -> Dictionary:
	var card := _inventory_card_at(player, slot_index)
	if card.is_empty() or str(card.get("runtime_instance_id", "")) != str(binding.get("card_instance_id", "")):
		return {"valid": false, "reason_code": "play_card_changed"}
	if str(_machine(card).get("card_id", "")) != str(binding.get("card_id", "")):
		return {"valid": false, "reason_code": "play_card_changed"}
	var assets: Dictionary = player.get("assets", {}) if player.get("assets", {}) is Dictionary else {}
	for key in COLORED_ASSET_KEYS:
		if int(assets.get(key, 0)) < int(asset_debit.get(key, 0)):
			return {"valid": false, "reason_code": "assets_insufficient"}
	var next_player := player.duplicate(true)
	var next_inventory: Dictionary = (player.get("inventory", {}) as Dictionary).duplicate(true)
	var slots: Array = (next_inventory.get("slots", []) as Array).duplicate(true)
	slots[slot_index] = null
	next_inventory["slots"] = slots
	var next_assets := assets.duplicate(true)
	next_assets.erase("generic")
	for key in COLORED_ASSET_KEYS:
		next_assets[key] = int(assets.get(key, 0)) - int(asset_debit.get(key, 0))
	next_player["inventory"] = next_inventory
	next_player["assets"] = next_assets
	return {"valid": true, "player_state": next_player}


func _asset_debit_is_six_color(asset_debit: Dictionary) -> bool:
	for key_variant in asset_debit.keys():
		var key := str(key_variant)
		if not COLORED_ASSET_KEYS.has(key) or int(asset_debit.get(key_variant, -1)) < 0:
			return false
	return true


func _receipt_matches_binding(receipt: Dictionary, binding: Dictionary) -> bool:
	for key in ["transaction_id", "actor_id", "card_id", "card_instance_id", "effect_kind", "target_hash", "payload_hash", "intent_hash"]:
		if str(receipt.get(key, "")) != str(binding.get(key, "")):
			return false
	return true


func _abort_prepared_effect(effect_handler: Object, prepared: Dictionary) -> void:
	if effect_handler != null and effect_handler.has_method("abort_prepared_effect"):
		effect_handler.call("abort_prepared_effect", prepared.duplicate(true))


func _compensate_effect(effect_handler: Object, receipt: Dictionary) -> Dictionary:
	if effect_handler == null or not effect_handler.has_method("rollback_effect"):
		return {
			"attempted": false,
			"rolled_back": false,
			"compensation_failed": true,
			"reason_code": "effect_rollback_unavailable",
		}
	var value_variant: Variant = effect_handler.call("rollback_effect", receipt.duplicate(true))
	if not (value_variant is Dictionary):
		return {
			"attempted": true,
			"rolled_back": false,
			"compensation_failed": true,
			"reason_code": "effect_rollback_receipt_invalid",
		}
	var owner_result: Dictionary = (value_variant as Dictionary).duplicate(true)
	var rolled_back := bool(owner_result.get("rolled_back", false))
	return {
		"attempted": true,
		"rolled_back": rolled_back,
		"compensation_failed": not rolled_back,
		"reason_code": "effect_rolled_back" if rolled_back else str(owner_result.get("reason_code", "effect_rollback_failed")),
		"owner_result": owner_result,
	}


func _finalize_effect(effect_handler: Object, receipt: Dictionary) -> Dictionary:
	if effect_handler == null or not effect_handler.has_method("finalize_effect"):
		return {
			"supported": false,
			"finalized": false,
			"finalization_failed": false,
			"reason_code": "effect_finalize_not_required",
		}
	var value_variant: Variant = effect_handler.call("finalize_effect", receipt.duplicate(true))
	if not (value_variant is Dictionary):
		return {
			"supported": true,
			"finalized": false,
			"finalization_failed": true,
			"reason_code": "effect_finalize_receipt_invalid",
		}
	var owner_result: Dictionary = (value_variant as Dictionary).duplicate(true)
	var finalized := bool(owner_result.get("finalized", false))
	return {
		"supported": true,
		"finalized": finalized,
		"finalization_failed": not finalized,
		"reason_code": "effect_finalized" if finalized else str(owner_result.get("reason_code", "effect_finalize_failed")),
		"owner_result": owner_result,
	}


func _card_with_instance(card: Dictionary, instance_id: String) -> Dictionary:
	var result := card.duplicate(true)
	result["runtime_instance_id"] = instance_id
	return result


func _assign_result_instance(inventory: Dictionary, operation_result: Dictionary, transaction_id: String) -> void:
	var target_slot := int(operation_result.get("target_slot", -1))
	var slots: Array = inventory.get("slots", []) if inventory.get("slots", []) is Array else []
	if target_slot < 0 or target_slot >= slots.size() or not (slots[target_slot] is Dictionary):
		return
	var card: Dictionary = (slots[target_slot] as Dictionary).duplicate(true)
	if str(card.get("runtime_instance_id", "")).is_empty():
		card["runtime_instance_id"] = "result:%s:%d" % [transaction_id, target_slot]
		slots[target_slot] = card
		inventory["slots"] = slots


func _machine(card: Dictionary) -> Dictionary:
	var value: Variant = card.get("machine", {})
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _transaction_gate(transaction_id: String, intent_hash: String) -> Dictionary:
	if transaction_id.strip_edges().is_empty():
		return {"handled": true, "result": _reject_result("unknown", "", transaction_id, intent_hash, "transaction_id_missing")}
	if _inflight_transactions.has(transaction_id):
		if str(_inflight_transactions.get(transaction_id, "")) != intent_hash:
			return {"handled": true, "result": _reject_result("unknown", "", transaction_id, intent_hash, "transaction_intent_collision")}
		return {"handled": true, "result": _reject_result("unknown", "", transaction_id, intent_hash, "transaction_in_progress")}
	if not _journal.has(transaction_id):
		return {"handled": false}
	var record: Dictionary = _journal.get(transaction_id, {}) if _journal.get(transaction_id, {}) is Dictionary else {}
	if str(record.get("intent_hash", "")) != intent_hash:
		return {"handled": true, "result": _reject_result("unknown", "", transaction_id, intent_hash, "transaction_intent_collision")}
	var saved: Dictionary = record.get("result", {}) if record.get("result", {}) is Dictionary else {}
	var replay := saved.duplicate(true)
	replay["idempotent_replay"] = true
	return {"handled": true, "result": replay}


func _finish_reject(
	transaction_id: String,
	intent_hash: String,
	operation: String,
	actor_id: String,
	reason_code: String,
	extra: Dictionary = {}
) -> Dictionary:
	var result := _reject_result(operation, actor_id, transaction_id, intent_hash, reason_code)
	for key in extra.keys():
		result[key] = extra[key]
	return _finish_transaction(transaction_id, intent_hash, result)


func _finish_transaction(transaction_id: String, intent_hash: String, result: Dictionary) -> Dictionary:
	_inflight_transactions.erase(transaction_id)
	if not transaction_id.strip_edges().is_empty():
		_journal[transaction_id] = {"intent_hash": intent_hash, "result": result.duplicate(true)}
	return result.duplicate(true)


func _success_result(operation: String, actor_id: String, transaction_id: String, intent_hash: String) -> Dictionary:
	return {
		"committed": true,
		"reason_code": "committed",
		"operation": operation,
		"actor_id": actor_id,
		"transaction_id": transaction_id,
		"intent_hash": intent_hash,
		"idempotent_replay": false,
	}


func _reject_result(operation: String, actor_id: String, transaction_id: String, intent_hash: String, reason_code: String) -> Dictionary:
	return {
		"committed": false,
		"reason_code": reason_code,
		"operation": operation,
		"actor_id": actor_id,
		"transaction_id": transaction_id,
		"intent_hash": intent_hash,
		"feedback": player_feedback(reason_code),
		"idempotent_replay": false,
	}


func _setup_reject(reason_code: String) -> Dictionary:
	return {"configured": false, "reason_code": reason_code, "feedback": player_feedback(reason_code)}


func _intent_hash(value: Variant) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(JSON.stringify(_canonicalize(value)).to_utf8_buffer())
	return context.finish().hex_encode()


func _canonicalize(value: Variant) -> Variant:
	if value is Dictionary:
		var result: Dictionary = {}
		var keys: Array = (value as Dictionary).keys()
		keys.sort_custom(func(a: Variant, b: Variant) -> bool: return str(a) < str(b))
		for key in keys:
			result[str(key)] = _canonicalize((value as Dictionary).get(key))
		return result
	if value is Array:
		var result_array: Array = []
		for item in value as Array:
			result_array.append(_canonicalize(item))
		return result_array
	return value
