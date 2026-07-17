@tool
extends Node
class_name CardPlaySubmissionRuntimeController

const TARGET_MONSTER := CardTargetChoiceRuntimeController.KIND_MONSTER
const TARGET_PLAYER := CardTargetChoiceRuntimeController.KIND_PLAYER

var _world_session_state: WorldSessionState
var _table_selection_state: TableSelectionState
var _eligibility_facts: CardPlayEligibilityWorldBridge
var _eligibility_service: CardPlayEligibilityRuntimeService
var _queue_service: CardResolutionQueueRuntimeService
var _resolution_controller: CardResolutionRuntimeController
var _target_choice_controller: CardTargetChoiceRuntimeController
var _contract_controller: ContractRuntimeController
var _product_market_controller: ProductMarketRuntimeController
var _derivative_controller: CityGdpDerivativeRuntimeController
var _runtime_coordinator: GameRuntimeCoordinator
var _submission_count := 0
var _accepted_count := 0
var _last_receipt: Dictionary = {}


func set_dependencies(
	world_session_state: WorldSessionState,
	table_selection_state: TableSelectionState,
	eligibility_facts: CardPlayEligibilityWorldBridge,
	eligibility_service: CardPlayEligibilityRuntimeService,
	queue_service: CardResolutionQueueRuntimeService,
	resolution_controller: CardResolutionRuntimeController,
	target_choice_controller: CardTargetChoiceRuntimeController,
	contract_controller: ContractRuntimeController,
	product_market_controller: ProductMarketRuntimeController,
	derivative_controller: CityGdpDerivativeRuntimeController,
	runtime_coordinator: GameRuntimeCoordinator
) -> void:
	_world_session_state = world_session_state
	_table_selection_state = table_selection_state
	_eligibility_facts = eligibility_facts
	_eligibility_service = eligibility_service
	_queue_service = queue_service
	_resolution_controller = resolution_controller
	_target_choice_controller = target_choice_controller
	_contract_controller = contract_controller
	_product_market_controller = product_market_controller
	_derivative_controller = derivative_controller
	_runtime_coordinator = runtime_coordinator


func request_hand_play(request: Dictionary) -> Dictionary:
	_submission_count += 1
	var player_index := int(request.get("player_index", _table_selection_state.selected_player if _table_selection_state != null else -1))
	var slot_index := int(request.get("slot_index", -1))
	var card_context := _card_at(player_index, slot_index)
	if not bool(card_context.get("valid", false)):
		return _remember(_rejection("card_slot_invalid"))
	var skill: Dictionary = card_context.get("skill", {})
	if _is_v06_runtime_card(skill):
		return _remember(_submit_v06(player_index, slot_index, skill))
	var eligibility := _eligibility(player_index, skill, "hand")
	if not bool(eligibility.get("allowed", false)):
		return _remember(_rejection(str(eligibility.get("reason_code", "card_play_rejected")), eligibility))
	if bool(eligibility.get("requires_target_monster", false)) and not request.has("target_slot"):
		return _remember(_begin_target(TARGET_MONSTER, player_index, slot_index))
	if bool(eligibility.get("requires_target_player", false)) and not request.has("target_player"):
		return _remember(_begin_target(TARGET_PLAYER, player_index, slot_index))
	return _remember(_submit_legacy(player_index, slot_index, int(request.get("target_slot", -1)), int(request.get("target_player", -1)), eligibility))


func submit_card_play(request: Dictionary) -> Dictionary:
	_submission_count += 1
	var player_index := int(request.get("player_index", -1))
	var slot_index := int(request.get("slot_index", -1))
	var card_context := _card_at(player_index, slot_index)
	if not bool(card_context.get("valid", false)):
		return _remember(_rejection("card_slot_invalid"))
	var skill: Dictionary = card_context.get("skill", {})
	if _is_v06_runtime_card(skill):
		return _remember(_submit_v06(player_index, slot_index, skill))
	var eligibility := _eligibility(player_index, skill, "rule")
	if not bool(eligibility.get("allowed", false)):
		return _remember(_rejection(str(eligibility.get("reason_code", "card_play_rejected")), eligibility))
	return _remember(_submit_legacy(player_index, slot_index, int(request.get("target_slot", -1)), int(request.get("target_player", -1)), eligibility))


func debug_snapshot() -> Dictionary:
	return {
		"controller_ready": _world_session_state != null and _eligibility_facts != null and _queue_service != null,
		"submission_count": _submission_count,
		"accepted_count": _accepted_count,
		"shared_human_ai_entry": true,
		"holds_main_reference": false,
		"last_receipt": _last_receipt.duplicate(true),
	}


func _submit_legacy(player_index: int, slot_index: int, target_slot: int, target_player: int, eligibility: Dictionary) -> Dictionary:
	var players := _world_session_state.players
	var player: Dictionary = players[player_index]
	var slots: Array = player.get("slots", [])
	var skill: Dictionary = (slots[slot_index] as Dictionary).duplicate(true)
	if bool(skill.get("queued_for_resolution", false)):
		return _rejection("already_queued")
	var target_status: Dictionary = eligibility.get("target_status", {}) if eligibility.get("target_status", {}) is Dictionary else {}
	var runtime_state := _resolution_controller.card_play_fact_snapshot() if _resolution_controller != null else {}
	var reactive_counter := bool(target_status.get("is_counter", false)) and bool(runtime_state.get("counter_window_active", false)) and not _queue_service.active_entry().is_empty()
	var contract_context := _contract_context(player_index, skill)
	if not str(contract_context.get("error", "")).is_empty():
		return _rejection(str(contract_context.get("reason", "contract_context_invalid")))
	var queued_skill := _skill_with_financial_terms(skill)
	if queued_skill.has("submission_terms_error"):
		return _rejection(str(queued_skill.get("submission_terms_error", "financial_terms_missing")))
	if str(queued_skill.get("kind", "")) == "public_facility":
		queued_skill["target_region_index"] = _table_selection_state.selected_district
	var requirement_status: Dictionary = eligibility.get("requirement_status", {}) if eligibility.get("requirement_status", {}) is Dictionary else {}
	var entry_context := {
		"target_slot": target_slot,
		"target_player": target_player,
		"selected_district": _table_selection_state.selected_district,
		"selected_trade_product": _table_selection_state.selected_trade_product,
		"contract_source_district": int(contract_context.get("source", -1)),
		"contract_target_district": int(contract_context.get("target", -1)),
		"contract_target_owner": int(contract_context.get("target_owner", -1)),
		"contract_target_project_ids": _array(contract_context.get("target_project_ids", [])),
		"contract_products": _array(contract_context.get("products", [])),
		"contract_response": ContractRuntimeController.RESPONSE_PENDING if str(skill.get("kind", "")) == "area_trade_contract" else "",
		"contract_response_player": -1,
		"contract_response_time": -1.0,
		"queued_time": _world_session_state.game_time,
		"play_requirement_kind": str(requirement_status.get("kind", "none")),
		"play_requirement_scope": str(requirement_status.get("scope", "")),
		"play_requirement_gdp_share_percent": int(requirement_status.get("required_share_percent", 0)),
		"play_requirement_district": int(requirement_status.get("qualifying_district", -1)),
		"play_requirement_product": "",
		"play_requirement_flow": 0,
		"play_requirement_text": str(requirement_status.get("requirement_text", "条件：无")),
	}
	var play_cash_cost := maxi(0, int(eligibility.get("cash_cost", 0)))
	var queue_plan := _runtime_coordinator.plan_card_resolution_queue_submission({
		"player_index": player_index,
		"slot_index": slot_index,
		"already_queued": bool(skill.get("queued_for_resolution", false)),
		"reactive_counter": reactive_counter,
		"group_card_limit": 1,
		"play_cash_cost_cents": play_cash_cost * 100,
		"financial_margin_cents": int(eligibility.get("financial_margin_cash", 0)) * 100,
		"financial_terms_version": str(eligibility.get("financial_terms_version", "")),
		"available_cash_cents": int(player.get("cash", 0)) * 100,
		"cash_revision": "%d" % int(player.get("cash", 0)),
		"asset_cost": _dictionary(eligibility.get("asset_cost", queued_skill.get("asset_cost", {}))),
		"skill": queued_skill,
		"entry_context": entry_context,
	}, {
		"player_count": players.size(),
		"counter_window_active": bool(runtime_state.get("counter_window_active", false)),
		"batch_locked": bool(runtime_state.get("batch_locked", false)),
		"simultaneous_timer": float(runtime_state.get("simultaneous_timer", 0.0)),
		"lock_duration": float(_resolution_controller.lock_seconds),
		"public_bid_duration": float(_resolution_controller.public_bid_seconds),
		"window_sequence": int(runtime_state.get("window_sequence", 0)),
		"reference_player": int(runtime_state.get("batch_reference_player", -1)),
	})
	if not bool(queue_plan.get("accepted", false)):
		return _rejection(str(queue_plan.get("reason", "queue_rejected")), queue_plan)
	var committed_entry: Dictionary = _dictionary(queue_plan.get("entry", {}))
	var committed_skill: Dictionary = _dictionary(committed_entry.get("skill", {}))
	var inventory_request := {
		"inventory": _inventory_snapshot(player),
		"target_slot": slot_index,
		"queued_skill": committed_skill,
		"consumed_on_queue": bool(queue_plan.get("consumed_on_queue", false)),
	}
	var inventory_plan := _runtime_coordinator.plan_card_inventory_queue_commit(inventory_request)
	if not bool(inventory_plan.get("ready", false)):
		return _rejection(str(inventory_plan.get("reason", "inventory_plan_rejected")))
	var prepared_player := player.duplicate(true)
	var inventory_commit := _runtime_coordinator.commit_card_inventory_queue_commit(prepared_player, inventory_request, inventory_plan)
	if not bool(inventory_commit.get("committed", false)):
		return _rejection(str(inventory_commit.get("reason", "inventory_commit_failed")))
	var total_cash_authorized_cents := play_cash_cost * 100 + maxi(0, int(queue_plan.get("financial_margin_cents", 0)))
	var queue_commit := _runtime_coordinator.commit_card_resolution_queue_submission(queue_plan, {
		"authorized": true,
		"inventory_committed": true,
		"play_cost_authorized": int(player.get("cash", 0)) * 100 >= total_cash_authorized_cents,
		"financial_margin_authorized": int(player.get("cash", 0)) * 100 >= total_cash_authorized_cents,
		"asset_authorized": true,
	})
	if not bool(queue_commit.get("committed", false)):
		return _rejection(str(queue_commit.get("reason", "queue_commit_failed")))
	prepared_player["queued_card_tip"] = 0
	prepared_player["cash"] = maxi(0, int(prepared_player.get("cash", 0)) - play_cash_cost)
	players[player_index] = prepared_player
	_world_session_state.players = players
	_resolution_controller.set_player_ready(player_index, false, _active_player_indices(players))
	if bool(queue_commit.get("begins_new_batch", false)):
		var sequence := int(queue_commit.get("next_window_sequence", int(runtime_state.get("window_sequence", 0)) + 1))
		_resolution_controller.begin_group_window(-1.0, int(queue_commit.get("reference_player", player_index)), sequence)
	_accepted_count += 1
	return {
		"accepted": true,
		"queued": true,
		"reason": "queued",
		"route": str(queue_commit.get("route", "current")),
		"resolution_id": int(committed_entry.get("resolution_id", -1)),
		"player_message": "卡牌已进入共享卡牌窗。",
	}


func _submit_v06(player_index: int, slot_index: int, card: Dictionary) -> Dictionary:
	if _runtime_coordinator == null:
		return _rejection("v06_runtime_unavailable")
	var actor_id := str((_world_session_state.players[player_index] as Dictionary).get("actor_id", "player.%d" % player_index)).strip_edges()
	var region_id := ""
	var district_index := _table_selection_state.selected_district
	if district_index >= 0 and district_index < _world_session_state.districts.size():
		region_id = str((_world_session_state.districts[district_index] as Dictionary).get("region_id", "region.%03d" % district_index))
	var machine: Dictionary = card.get("machine", {}) if card.get("machine", {}) is Dictionary else {}
	var authoritative_slot := _v06_authoritative_slot(actor_id, str(machine.get("card_id", "")))
	if authoritative_slot < 0:
		return _rejection("v06_authoritative_slot_changed")
	var runtime_instance_id := str(card.get("runtime_instance_id", "slot:%d" % slot_index))
	var result := _runtime_coordinator.play_v06_runtime_card({
		"actor_id": actor_id,
		"slot_index": authoritative_slot,
		"transaction_id": "v06-play:%s:%s:%s" % [actor_id, runtime_instance_id, region_id],
		"region_id": region_id,
		"game_time": _world_session_state.game_time,
	})
	var committed := bool(result.get("committed", false)) and bool(_dictionary(result.get("effect_finalization", {})).get("finalized", result.get("finalized", false)))
	if committed:
		_accepted_count += 1
	return {
		"accepted": committed,
		"queued": false,
		"reason": str(result.get("reason_code", "v06_card_play_committed" if committed else "v06_card_play_rejected")),
		"v06_receipt": result,
		"player_message": "卡牌事务已完成。" if committed else "卡牌当前未能生效。",
	}


func _v06_authoritative_slot(actor_id: String, card_id: String) -> int:
	var player := _runtime_coordinator.v06_card_player_snapshot(actor_id)
	var inventory: Dictionary = player.get("inventory", {}) if player.get("inventory", {}) is Dictionary else {}
	var slots: Array = inventory.get("slots", []) if inventory.get("slots", []) is Array else []
	for index in range(slots.size()):
		if slots[index] is Dictionary:
			var machine: Dictionary = (slots[index] as Dictionary).get("machine", {}) if (slots[index] as Dictionary).get("machine", {}) is Dictionary else {}
			if str(machine.get("card_id", "")) == card_id:
				return index
	return -1


func _eligibility(player_index: int, skill: Dictionary, mode: String) -> Dictionary:
	if _eligibility_facts == null or _eligibility_service == null:
		return {"allowed": false, "reason_code": "eligibility_service_missing"}
	var facts := _eligibility_facts.build_facts(player_index, skill)
	facts["commodity_color_flow"] = _runtime_coordinator.commodity_color_flow_snapshot(player_index)
	facts["player_mana"] = _runtime_coordinator.player_mana_availability(player_index)
	return _eligibility_service.evaluate_play({"player_index": player_index, "skill": skill, "evaluation_mode": mode}, facts)


func _contract_context(player_index: int, skill: Dictionary) -> Dictionary:
	if str(skill.get("kind", "")) != "area_trade_contract":
		return {}
	if _contract_controller == null:
		return {"error": "contract_controller_missing", "reason": "contract_controller_missing"}
	var selection := _contract_controller.selection_snapshot()
	return _contract_controller.offer_context(
		skill,
		player_index,
		int(selection.get("source_district", -1)),
		int(selection.get("target_district", -1)),
		_table_selection_state.selected_trade_product
	)


func _skill_with_financial_terms(skill: Dictionary) -> Dictionary:
	var result := skill.duplicate(true)
	match str(result.get("kind", "")):
		"product_futures":
			if _product_market_controller == null:
				result["submission_terms_error"] = "product_futures_terms_unavailable"
				return result
			result = _product_market_controller.skill_with_terms(str(result.get("name", "")), result)
			if result.has("futures_terms_error"):
				result["submission_terms_error"] = str(result.get("futures_terms_error"))
		"city_gdp_derivative":
			if _derivative_controller == null:
				result["submission_terms_error"] = "gdp_derivative_terms_unavailable"
				return result
			result = _derivative_controller.skill_with_terms(str(result.get("name", "")), result)
			if result.has("gdp_derivative_terms_error"):
				result["submission_terms_error"] = str(result.get("gdp_derivative_terms_error"))
	return result


func _begin_target(kind: String, player_index: int, slot_index: int) -> Dictionary:
	if _target_choice_controller == null:
		return _rejection("target_choice_controller_missing")
	var choice := _target_choice_controller.begin_choice(kind, player_index, slot_index)
	return {
		"accepted": bool(choice.get("accepted", true)),
		"queued": false,
		"target_choice_started": not choice.is_empty(),
		"target_kind": kind,
		"choice": choice,
		"reason": "target_choice_started",
		"player_message": "请选择目标怪兽。" if kind == TARGET_MONSTER else "请选择目标玩家。",
	}


func _card_at(player_index: int, slot_index: int) -> Dictionary:
	if _world_session_state == null or player_index < 0 or player_index >= _world_session_state.players.size():
		return {"valid": false}
	var player: Dictionary = _world_session_state.players[player_index]
	if bool(player.get("eliminated", false)):
		return {"valid": false, "reason": "player_eliminated"}
	var slots: Array = player.get("slots", []) if player.get("slots", []) is Array else []
	if slot_index < 0 or slot_index >= slots.size() or not (slots[slot_index] is Dictionary):
		return {"valid": false}
	return {"valid": true, "skill": (slots[slot_index] as Dictionary).duplicate(true)}


func _inventory_snapshot(player: Dictionary) -> Dictionary:
	var slot_facts: Array = []
	var counted := 0
	var slots: Array = player.get("slots", []) if player.get("slots", []) is Array else []
	for slot_index in range(slots.size()):
		if not (slots[slot_index] is Dictionary):
			slot_facts.append({"slot_index": slot_index, "occupied": false})
			continue
		var card: Dictionary = slots[slot_index]
		var counts := not (bool(card.get("persistent", false)) and str(card.get("kind", "")) in ["monster_bound_action", "military_command"])
		if counts:
			counted += 1
		slot_facts.append({
			"slot_index": slot_index,
			"occupied": true,
			"card_id": str(card.get("name", "")),
			"family": str(card.get("family_id", card.get("name", ""))),
			"rank": maxi(1, int(card.get("rank", 1))),
			"counts_toward_hand_limit": counts,
			"queued_for_resolution": bool(card.get("queued_for_resolution", false)),
			"lock_left": float(card.get("lock_left", 0.0)),
			"next_upgrade_id": "",
			"next_upgrade_card": {},
		})
	return {"valid": false, "counted_hand_size": counted, "hand_limit": 5, "discard_slot": -1, "slots": slot_facts}


func _active_player_indices(players: Array) -> Array:
	var result: Array = []
	for index in range(players.size()):
		if players[index] is Dictionary and not bool((players[index] as Dictionary).get("eliminated", false)):
			result.append(index)
	return result


func _is_v06_runtime_card(card: Dictionary) -> bool:
	var machine: Dictionary = card.get("machine", {}) if card.get("machine", {}) is Dictionary else {}
	return not str(machine.get("card_id", "")).is_empty() and not str(machine.get("effect_kind", "")).is_empty()


func _rejection(reason: String, details: Dictionary = {}) -> Dictionary:
	return {
		"accepted": false,
		"queued": false,
		"reason": reason,
		"details": details.duplicate(true),
		"player_message": "卡牌未能提交（%s）。" % reason,
	}


func _remember(receipt: Dictionary) -> Dictionary:
	_last_receipt = receipt.duplicate(true)
	return receipt


func _dictionary(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _array(value: Variant) -> Array:
	return (value as Array).duplicate(true) if value is Array else []
