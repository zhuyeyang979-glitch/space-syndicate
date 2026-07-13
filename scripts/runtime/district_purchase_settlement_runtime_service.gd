@tool
extends Node
class_name DistrictPurchaseSettlementRuntimeService

const STATUS_READY := "ready"
const STATUS_REQUIRES_DISCARD := "requires_discard"
const STATUS_REJECTED := "rejected"

var _configured := false
var _inventory_service: Node = null
var _purchase_plan_count := 0
var _inventory_delegate_plan_count := 0
var _commit_attempt_count := 0
var _committed_count := 0
var _rejected_count := 0
var _last_reason := ""
var _last_operation := ""
var _last_committed := false


func set_inventory_service(service: Node) -> void:
	_inventory_service = service


func configure(_config: Dictionary = {}) -> void:
	_configured = _inventory_service != null and _inventory_service.has_method("plan_receive") and _inventory_service.has_method("commit_receive")
	reset_state()


func reset_state() -> void:
	_purchase_plan_count = 0
	_inventory_delegate_plan_count = 0
	_commit_attempt_count = 0
	_committed_count = 0
	_rejected_count = 0
	_last_reason = ""
	_last_operation = ""
	_last_committed = false


func plan_purchase(request: Dictionary) -> Dictionary:
	_purchase_plan_count += 1
	if not _configured:
		return _purchase_rejection("service_not_configured")
	if not _is_data_only(request):
		return _purchase_rejection("invalid_request")
	var authorization: Dictionary = request.get("authorization", {}) if request.get("authorization", {}) is Dictionary else {}
	if not bool(authorization.get("authorized", false)):
		return _purchase_rejection(str(authorization.get("reason", "window_unauthorized")))
	if not bool(request.get("live_access_valid", false)):
		return _purchase_rejection("live_access_invalid")
	if not bool(request.get("supply_contains_card", false)):
		return _purchase_rejection("card_not_in_supply")
	var price := maxi(0, int(request.get("price", 0)))
	if int(request.get("player_cash", 0)) < price:
		return _purchase_rejection("insufficient_cash")
	var inventory: Dictionary = request.get("inventory", {}) if request.get("inventory", {}) is Dictionary else {}
	inventory = inventory.duplicate(true)
	inventory["discard_slot"] = int(request.get("discard_slot", inventory.get("discard_slot", -1)))
	var inventory_plan := _inventory_receive_plan(inventory)
	var status := str(inventory_plan.get("status", STATUS_REJECTED))
	if status == STATUS_REQUIRES_DISCARD:
		return {
			"status": STATUS_REQUIRES_DISCARD,
			"ready": false,
			"requires_discard": true,
			"reason": "hand_limit_requires_discard",
			"card_id": str(inventory.get("incoming_card_id", "")),
			"price": price,
			"supply_revision": str(request.get("supply_revision", "")),
			"discardable_slots": inventory_plan.get("discardable_slots", []).duplicate(),
			"inventory_fingerprint": str(inventory_plan.get("inventory_fingerprint", "")),
			"mutation_expected": false,
		}
	if status != STATUS_READY:
		return _purchase_rejection(str(inventory_plan.get("reason", "inventory_rejected")))
	return {
		"status": STATUS_READY,
		"ready": true,
		"requires_discard": false,
		"reason": "ready",
		"card_id": str(inventory.get("incoming_card_id", "")),
		"price": price,
		"supply_revision": str(request.get("supply_revision", "")),
		"operation": str(inventory_plan.get("operation", "")),
		"target_slot": int(inventory_plan.get("target_slot", -1)),
		"discard_slot": int(inventory_plan.get("discard_slot", -1)),
		"result_card_id": str(inventory_plan.get("result_card_id", "")),
		"result_card": (inventory_plan.get("result_card", {}) as Dictionary).duplicate(true) if inventory_plan.get("result_card", {}) is Dictionary else {},
		"inventory_fingerprint": str(inventory_plan.get("inventory_fingerprint", "")),
		"hand_count_delta": int(inventory_plan.get("hand_count_delta", 0)),
		"slot_change_kind": str(inventory_plan.get("slot_change_kind", "")),
		"mutation_expected": true,
	}


func commit_purchase(player_state: Dictionary, current_facts: Dictionary, plan: Dictionary) -> Dictionary:
	_commit_attempt_count += 1
	if not _configured or not _is_data_only(player_state) or not _is_data_only(current_facts) or not _is_data_only(plan):
		return _commit_rejection("invalid_commit_request")
	if str(plan.get("status", "")) != STATUS_READY:
		return _commit_rejection("plan_not_ready")
	var current_plan := plan_purchase(current_facts)
	if not _plans_match(plan, current_plan):
		return _commit_rejection("state_drift")
	var price := maxi(0, int(current_facts.get("price", 0)))
	if int(player_state.get("cash", 0)) != int(current_facts.get("player_cash", 0)) or int(player_state.get("cash", 0)) < price:
		return _commit_rejection("cash_drift")
	var after_player := player_state.duplicate(true)
	var inventory: Dictionary = current_facts.get("inventory", {}) if current_facts.get("inventory", {}) is Dictionary else {}
	var inventory_result_variant: Variant = _inventory_service.call("commit_receive", after_player, inventory, current_plan)
	var inventory_result: Dictionary = inventory_result_variant if inventory_result_variant is Dictionary else {}
	if not bool(inventory_result.get("committed", false)):
		return _commit_rejection(str(inventory_result.get("reason", "inventory_commit_failed")))
	var operation := str(current_plan.get("operation", ""))
	if operation == "replace":
		_append_ledger_entry(after_player, current_facts.get("discard_ledger_context", {}) as Dictionary if current_facts.get("discard_ledger_context", {}) is Dictionary else {}, int(after_player.get("cash", 0)))
	after_player["cash"] = int(after_player.get("cash", 0)) - price
	after_player["card_purchase_count"] = int(after_player.get("card_purchase_count", 0)) + 1
	after_player["total_card_spend"] = int(after_player.get("total_card_spend", 0)) + price
	_append_ledger_entry(after_player, current_facts.get("purchase_ledger_context", {}) as Dictionary if current_facts.get("purchase_ledger_context", {}) is Dictionary else {}, int(after_player.get("cash", 0)))
	_append_cash_history(after_player, current_facts)
	player_state.clear()
	player_state.merge(after_player, true)
	_committed_count += 1
	_last_committed = true
	_last_reason = "committed"
	_last_operation = operation
	var private_intents: Array = [{"event": "purchase_spend_recorded", "amount": -price}]
	if operation == "replace":
		private_intents.push_front({"event": "discard_recorded", "amount": 0})
	return {
		"committed": true,
		"reason": "committed",
		"cash_delta": -price,
		"hand_count_delta": int(current_plan.get("hand_count_delta", 0)),
		"slot_change_kind": str(current_plan.get("slot_change_kind", operation)),
		"purchase_count_delta": 1,
		"ledger_delta": private_intents.size(),
		"ledger_intents": private_intents.duplicate(true),
		"public_event_intents": [{"event": "anonymous_purchase_committed", "district_index": int(current_facts.get("district_index", -1))}],
		"private_event_intents": private_intents.duplicate(true),
		"post_commit_hooks": ["scenario", "city_development_supply", "role_bonus", "bankruptcy"],
		"mutation_count": 5 + (1 if operation == "replace" else 0),
	}


func validate_discard(request: Dictionary, discard_slot: int) -> Dictionary:
	if not _is_data_only(request):
		return {"valid": false, "reason": "invalid_request"}
	var inventory: Dictionary = request.get("inventory", request) if request.get("inventory", request) is Dictionary else {}
	inventory = inventory.duplicate(true)
	inventory["discard_slot"] = discard_slot
	var inventory_plan := _inventory_receive_plan(inventory)
	return {
		"valid": str(inventory_plan.get("status", "")) == STATUS_READY and str(inventory_plan.get("operation", "")) == "replace",
		"reason": str(inventory_plan.get("reason", "")),
		"discard_slot": discard_slot,
	}


func debug_snapshot() -> Dictionary:
	return {
		"service_ready": _configured,
		"service_authoritative": _configured,
		"purchase_plan_count": _purchase_plan_count,
		"inventory_delegate_ready": _inventory_service != null and _inventory_service.has_method("plan_receive") and _inventory_service.has_method("commit_receive"),
		"inventory_delegate_plan_count": _inventory_delegate_plan_count,
		"commit_attempt_count": _commit_attempt_count,
		"committed_count": _committed_count,
		"rejected_count": _rejected_count,
		"last_reason": _last_reason,
		"last_operation": _last_operation,
		"last_committed": _last_committed,
		"window_authority": false,
		"presentation_authority": false,
		"legacy_settlement_fallback_used": false,
	}


func _inventory_receive_plan(inventory: Dictionary) -> Dictionary:
	_inventory_delegate_plan_count += 1
	if not _configured or _inventory_service == null or not _inventory_service.has_method("plan_receive"):
		return {"status": STATUS_REJECTED, "ready": false, "requires_discard": false, "reason": "inventory_service_missing"}
	var value: Variant = _inventory_service.call("plan_receive", inventory)
	return (value as Dictionary).duplicate(true) if value is Dictionary else {"status": STATUS_REJECTED, "ready": false, "requires_discard": false, "reason": "inventory_plan_invalid"}


func _purchase_rejection(reason: String) -> Dictionary:
	_last_committed = false
	_last_reason = reason
	_last_operation = ""
	return {
		"status": STATUS_REJECTED,
		"ready": false,
		"requires_discard": false,
		"reason": reason,
		"mutation_expected": false,
	}


func _commit_rejection(reason: String) -> Dictionary:
	_rejected_count += 1
	_last_committed = false
	_last_reason = reason
	_last_operation = ""
	return {
		"committed": false,
		"reason": reason,
		"cash_delta": 0,
		"hand_count_delta": 0,
		"slot_change_kind": "none",
		"purchase_count_delta": 0,
		"ledger_delta": 0,
		"ledger_intents": [],
		"public_event_intents": [],
		"private_event_intents": [],
		"post_commit_hooks": [],
		"mutation_count": 0,
	}


func _plans_match(expected: Dictionary, current: Dictionary) -> bool:
	for key in ["status", "card_id", "price", "supply_revision", "operation", "target_slot", "discard_slot", "result_card_id", "inventory_fingerprint"]:
		if expected.get(key) != current.get(key):
			return false
	return str(current.get("status", "")) == STATUS_READY


func _append_ledger_entry(player_state: Dictionary, context: Dictionary, cash_after: int) -> void:
	if context.is_empty():
		return
	var ledger: Array = (player_state.get("economic_ledger", []) as Array).duplicate(true) if player_state.get("economic_ledger", []) is Array else []
	ledger.append({
		"cycle": int(context.get("cycle", 0)),
		"time": float(context.get("time", 0.0)),
		"kind": str(context.get("kind", "")),
		"label": str(context.get("label", "")),
		"amount": int(context.get("amount", 0)),
		"cash_after": cash_after,
		"detail": str(context.get("detail", "")),
	})
	var limit := maxi(1, int(context.get("ledger_limit", 14)))
	while ledger.size() > limit:
		ledger.pop_front()
	player_state["economic_ledger"] = ledger


func _append_cash_history(player_state: Dictionary, current_facts: Dictionary) -> void:
	var history: Array = (player_state.get("cash_history", []) as Array).duplicate() if player_state.get("cash_history", []) is Array else []
	var current_cash := int(player_state.get("cash", 0))
	if history.is_empty() or int(history[history.size() - 1]) != current_cash:
		history.append(current_cash)
	var limit := maxi(1, int(current_facts.get("cash_history_limit", 24)))
	while history.size() > limit:
		history.pop_front()
	player_state["cash_history"] = history


func _is_data_only(value: Variant) -> bool:
	if value == null or value is String or value is StringName or value is bool or value is int or value is float:
		return true
	if value is Array:
		for item in value:
			if not _is_data_only(item):
				return false
		return true
	if value is Dictionary:
		for key in value.keys():
			if not _is_data_only(key) or not _is_data_only(value[key]):
				return false
		return true
	return false
