@tool
extends Node
class_name ContractRuntimeController

signal contract_offer_opened(offer: Dictionary)
signal contract_offer_resolved(receipt: Dictionary)

const RESPONSE_PENDING := "pending"
const RESPONSE_ACCEPTED := "accepted"
const RESPONSE_REJECTED := "rejected"
const RESPONSE_TIMEOUT := "timeout"
const CONTRACT_KIND := "area_trade_contract"
const DEFAULT_DECISION_SECONDS := 5.0

var _world_bridge: ContractRuntimeWorldBridge
var _ruleset_snapshot: Dictionary = {}
var _configured := false
var _decision_seconds := DEFAULT_DECISION_SECONDS
var _state_revision := 0
var _committed_transaction_ids: Array[String] = []

var selected_source_district := -1
var selected_target_district := -1
var pending_offers: Array = []


func set_world_bridge(bridge: ContractRuntimeWorldBridge) -> void:
	_world_bridge = bridge


func configure(ruleset_snapshot: Dictionary) -> void:
	_ruleset_snapshot = ruleset_snapshot.duplicate(true)
	var timing: Dictionary = _ruleset_snapshot.get("timing", {}) as Dictionary if _ruleset_snapshot.get("timing", {}) is Dictionary else {}
	_decision_seconds = maxf(0.1, float(timing.get("contract_window_seconds", _ruleset_snapshot.get("contract_window_seconds", DEFAULT_DECISION_SECONDS))))
	_configured = str(_ruleset_snapshot.get("ruleset_id", "")) == "v0.4" and _world_bridge != null and _world_bridge.has_world()


func reset_state() -> void:
	selected_source_district = -1
	selected_target_district = -1
	pending_offers.clear()
	_committed_transaction_ids.clear()
	_state_revision = 0


func set_selection_state(source_index: int, target_index: int) -> Dictionary:
	selected_source_district = source_index
	selected_target_district = target_index
	_state_revision += 1
	return selection_snapshot()


func selection_snapshot() -> Dictionary:
	return {
		"source_district": selected_source_district,
		"target_district": selected_target_district,
		"ready": selection_ready(),
		"revision": _state_revision,
	}


func valid_source_district(index: int) -> bool:
	var fact := _district_fact(index)
	return bool(fact.get("valid", false)) and not bool(fact.get("destroyed", true)) and str(fact.get("terrain", "")) != "ocean"


func valid_target_district(index: int) -> bool:
	var fact := _district_fact(index)
	return bool(fact.get("valid", false)) and not bool(fact.get("destroyed", true)) and bool((fact.get("city", {}) as Dictionary).get("active", false))


func district_short_name(index: int) -> String:
	return str(_district_fact(index).get("name", "未设"))


func selection_ready() -> bool:
	return valid_source_district(selected_source_district) and valid_target_district(selected_target_district) and selected_source_district != selected_target_district


func selection_summary(selected_product: String = "", fallback_product: String = "") -> String:
	var product_text := selected_product if selected_product != "" else fallback_product
	if product_text == "":
		product_text = "自动商品"
	return "合约:%s→%s｜%s｜%s" % [district_short_name(selected_source_district), district_short_name(selected_target_district), product_text, "就绪" if selection_ready() else "未就绪"]


func select_source_district(index: int, selected_product: String = "") -> Dictionary:
	if not valid_source_district(index):
		return {"accepted": false, "reason": "source_district_invalid", "message": "供给区必须是未毁陆地区域；海洋区暂只承担运输，不能作为生产合约源。"}
	selected_source_district = index
	if selected_target_district == index:
		selected_target_district = -1
	var product := selected_product
	if product == "" and _world_bridge != null:
		product = _world_bridge.default_trade_product(index)
	_state_revision += 1
	return {"accepted": true, "reason": "selected", "selected_product": product, "selection": selection_snapshot(), "message": "已把%s设为下一张区域供需合约的供给区。" % district_short_name(index)}


func select_target_district(index: int, selected_product: String = "") -> Dictionary:
	if not valid_target_district(index):
		return {"accepted": false, "reason": "target_district_invalid", "message": "需求区必须是一座存活城市群；公开展示结束后，目标商品控制者会获得独立签/拒窗口。"}
	selected_target_district = index
	if selected_source_district == index:
		selected_source_district = -1
	var product := selected_product
	if product == "" and _world_bridge != null:
		product = _world_bridge.default_trade_product(index)
	_state_revision += 1
	return {"accepted": true, "reason": "selected", "selected_product": product, "selection": selection_snapshot(), "message": "已把%s设为下一张区域供需合约的需求/签约区；真实商品控制者仍不公开。" % district_short_name(index)}


func offer_context(skill: Dictionary, player_index: int, source_index: int = -2, target_index: int = -2, selected_product: String = "") -> Dictionary:
	var source := selected_source_district if source_index == -2 else source_index
	var target := selected_target_district if target_index == -2 else target_index
	var facts := _facts(source, target, selected_product)
	var request := {
		"skill": skill.duplicate(true),
		"player_index": player_index,
		"contract_source_district": source,
		"contract_target_district": target,
		"selected_product": selected_product,
		"context_only": true,
	}
	var plan := plan_offer(request, facts)
	return {
		"error": "" if bool(plan.get("planned", false)) else _reason_message(str(plan.get("reason", "contract_invalid")), skill),
		"reason": str(plan.get("reason", "")),
		"source": source,
		"target": target,
		"target_owner": int(plan.get("contract_target_owner", -1)),
		"target_project_ids": (plan.get("contract_target_project_ids", []) as Array).duplicate(true) if plan.get("contract_target_project_ids", []) is Array else [],
		"products": (plan.get("contract_products", []) as Array).duplicate(true) if plan.get("contract_products", []) is Array else [],
		"context_revision": int(plan.get("context_revision", _state_revision)),
	}


func plan_offer(request: Dictionary, facts: Dictionary) -> Dictionary:
	if not _is_pure_data(request) or not _is_pure_data(facts):
		return _offer_rejection("request_not_pure_data")
	var skill: Dictionary = (request.get("skill", {}) as Dictionary).duplicate(true) if request.get("skill", {}) is Dictionary else {}
	if str(skill.get("kind", CONTRACT_KIND)) != CONTRACT_KIND:
		return _offer_rejection("contract_skill_invalid")
	var source_index := int(request.get("contract_source_district", -1))
	var target_index := int(request.get("contract_target_district", -1))
	var source: Dictionary = facts.get("source", {}) as Dictionary if facts.get("source", {}) is Dictionary else {}
	var target: Dictionary = facts.get("target", {}) as Dictionary if facts.get("target", {}) is Dictionary else {}
	if not _source_fact_valid(source):
		return _offer_rejection("source_district_invalid")
	if not _target_fact_valid(target):
		return _offer_rejection("target_district_invalid")
	if source_index == target_index:
		return _offer_rejection("same_source_target")
	var products := _contract_products(skill, facts)
	if products.is_empty():
		return _offer_rejection("contract_products_missing")
	var authority := _target_project_authority(products, target)
	if not bool(authority.get("resolved", false)):
		return _offer_rejection(str(authority.get("reason", "target_project_controller_missing")), {"contract_products": products})
	var target_controller := int(authority.get("controller_player_index", -1))
	var player_count_value := int(facts.get("player_count", 0))
	if target_controller < 0 or target_controller >= player_count_value:
		return _offer_rejection("target_project_controller_invalid", {"contract_products": products})
	var proposer := int(request.get("player_index", -1))
	if proposer == target_controller and not bool(skill.get("contract_allow_self_sign", false)):
		return _offer_rejection("self_sign_not_allowed", {"contract_products": products, "contract_target_owner": target_controller})
	var entry: Dictionary = (request.get("entry", {}) as Dictionary).duplicate(true) if request.get("entry", {}) is Dictionary else {}
	var contract_id := int(request.get("contract_offer_id", entry.get("resolution_id", entry.get("queued_order", -1))))
	var offer := entry.duplicate(true)
	offer["contract_offer_id"] = contract_id
	offer["contract_source_district"] = source_index
	offer["contract_target_district"] = target_index
	offer["contract_target_owner"] = target_controller
	offer["contract_target_project_ids"] = (authority.get("project_ids", []) as Array).duplicate(true)
	offer["contract_products"] = products.duplicate(true)
	offer["contract_response"] = RESPONSE_PENDING
	offer["contract_decision_timer"] = _decision_seconds
	offer["contract_decision_started_time"] = float(facts.get("game_time", 0.0))
	offer["contract_response_player"] = -1
	offer["contract_response_time"] = -1.0
	offer["offer_revision"] = _state_revision + 1
	offer["skill"] = skill.duplicate(true)
	return {
		"planned": true,
		"reason": "ready",
		"context_revision": _state_revision,
		"contract_offer_id": contract_id,
		"contract_source_district": source_index,
		"contract_target_district": target_index,
		"contract_target_owner": target_controller,
		"contract_target_project_ids": (authority.get("project_ids", []) as Array).duplicate(true),
		"contract_products": products.duplicate(true),
		"offer": offer,
	}


func commit_offer(plan: Dictionary) -> Dictionary:
	if not _configured:
		return {"committed": false, "reason": "controller_not_ready"}
	if not bool(plan.get("planned", false)):
		return {"committed": false, "reason": str(plan.get("reason", "offer_not_planned"))}
	if int(plan.get("context_revision", -1)) != _state_revision:
		return {"committed": false, "reason": "context_revision_drift"}
	var offer: Dictionary = (plan.get("offer", {}) as Dictionary).duplicate(true) if plan.get("offer", {}) is Dictionary else {}
	var contract_id := int(offer.get("contract_offer_id", -1))
	if contract_id < 0:
		return {"committed": false, "reason": "contract_offer_id_invalid"}
	var existing := _offer_index(contract_id)
	if existing >= 0:
		return {"committed": true, "reason": "already_committed", "idempotent": true, "offer": (pending_offers[existing] as Dictionary).duplicate(true)}
	pending_offers.append(offer)
	_state_revision += 1
	contract_offer_opened.emit(_public_offer_snapshot(offer))
	return {"committed": true, "reason": "committed", "idempotent": false, "offer": offer.duplicate(true)}


func open_offer(skill: Dictionary, entry: Dictionary) -> Dictionary:
	if not _configured or _world_bridge == null:
		return {"opened": false, "reason": "controller_not_ready"}
	var source_index := int(entry.get("contract_source_district", selected_source_district))
	var target_index := int(entry.get("contract_target_district", selected_target_district))
	var selected_product := str(entry.get("selected_trade_product", ""))
	var request := {
		"skill": skill.duplicate(true),
		"entry": entry.duplicate(true),
		"player_index": int(entry.get("player_index", -1)),
		"contract_offer_id": int(entry.get("resolution_id", entry.get("queued_order", -1))),
		"contract_source_district": source_index,
		"contract_target_district": target_index,
		"selected_product": selected_product,
	}
	var plan := plan_offer(request, _facts(source_index, target_index, selected_product))
	var commit := commit_offer(plan)
	if bool(commit.get("committed", false)):
		_world_bridge.log_message("%s公开展示结束：目标商品控制者获得独立签约窗口；其他玩家可以继续出牌。" % str(skill.get("name", "区域供需合约")))
		_world_bridge.refresh_ui()
	return {
		"opened": bool(commit.get("committed", false)),
		"reason": str(commit.get("reason", plan.get("reason", "offer_rejected"))),
		"offer": (commit.get("offer", {}) as Dictionary).duplicate(true) if commit.get("offer", {}) is Dictionary else {},
	}


func plan_response(request: Dictionary, facts: Dictionary) -> Dictionary:
	if not _is_pure_data(request) or not _is_pure_data(facts):
		return {"planned": false, "reason": "request_not_pure_data"}
	var contract_id := int(request.get("contract_offer_id", -1))
	var index := _offer_index(contract_id)
	if index < 0:
		return {"planned": false, "reason": "offer_not_found"}
	var offer := (pending_offers[index] as Dictionary).duplicate(true)
	if str(offer.get("contract_response", RESPONSE_PENDING)) != RESPONSE_PENDING:
		return {"planned": false, "reason": "offer_already_resolved"}
	var timeout := bool(request.get("timeout", false))
	if not timeout and float(offer.get("contract_decision_timer", 0.0)) <= 0.0:
		return {"planned": false, "reason": "response_expired"}
	var responder := int(request.get("player_index", -1))
	var expected_responder := int(offer.get("contract_target_owner", -1))
	if not timeout and responder != expected_responder:
		return {"planned": false, "reason": "response_not_authorized"}
	var target: Dictionary = facts.get("target", {}) as Dictionary if facts.get("target", {}) is Dictionary else {}
	var authority := _target_project_authority(offer.get("contract_products", []) as Array, target)
	if not bool(authority.get("resolved", false)):
		return {"planned": false, "reason": str(authority.get("reason", "target_project_controller_missing"))}
	if int(authority.get("controller_player_index", -1)) != expected_responder:
		return {"planned": false, "reason": "target_project_controller_drift"}
	var response := RESPONSE_TIMEOUT if timeout else (RESPONSE_ACCEPTED if bool(request.get("accept", false)) else RESPONSE_REJECTED)
	var transaction_id := "contract:%d:%s" % [contract_id, response]
	if _committed_transaction_ids.has(transaction_id):
		return {"planned": false, "reason": "transaction_already_committed", "transaction_id": transaction_id}
	var transaction := offer.duplicate(true)
	transaction["transaction_id"] = transaction_id
	transaction["contract_response"] = response
	transaction["contract_response_player"] = -1 if timeout else responder
	transaction["contract_response_time"] = float(facts.get("game_time", 0.0))
	transaction["contract_target_project_ids"] = (authority.get("project_ids", []) as Array).duplicate(true)
	transaction["contract_accept_summary"] = accept_effect_summary(transaction.get("skill", {}) as Dictionary)
	transaction["contract_decline_summary"] = decline_effect_summary(transaction.get("skill", {}) as Dictionary)
	return {"planned": true, "reason": "ready", "offer_index": index, "offer_revision": int(offer.get("offer_revision", 0)), "transaction_id": transaction_id, "transaction": transaction}


func commit_response(plan: Dictionary) -> Dictionary:
	if not _configured or _world_bridge == null:
		return {"committed": false, "reason": "controller_not_ready"}
	if not bool(plan.get("planned", false)):
		return {"committed": false, "reason": str(plan.get("reason", "response_not_planned"))}
	var transaction: Dictionary = (plan.get("transaction", {}) as Dictionary).duplicate(true) if plan.get("transaction", {}) is Dictionary else {}
	var contract_id := int(transaction.get("contract_offer_id", -1))
	var index := _offer_index(contract_id)
	if index < 0:
		return {"committed": false, "reason": "offer_not_found"}
	var live_offer := pending_offers[index] as Dictionary
	if int(live_offer.get("offer_revision", 0)) != int(plan.get("offer_revision", -1)):
		return {"committed": false, "reason": "offer_revision_drift"}
	var transaction_id := str(plan.get("transaction_id", transaction.get("transaction_id", "")))
	if transaction_id == "" or _committed_transaction_ids.has(transaction_id):
		return {"committed": false, "reason": "transaction_already_committed"}
	var receipt := _world_bridge.apply_response_transaction(transaction)
	if not bool(receipt.get("applied", false)):
		return {"committed": false, "reason": str(receipt.get("reason", "world_commit_failed")), "receipt": receipt}
	pending_offers.remove_at(index)
	_committed_transaction_ids.append(transaction_id)
	while _committed_transaction_ids.size() > 64:
		_committed_transaction_ids.pop_front()
	transaction["contract_result_clue"] = response_result_clue(transaction)
	transaction["aftermath_clue"] = str(transaction.get("contract_result_clue", ""))
	transaction["aftermath_style"] = "generic"
	transaction["resolved_time"] = _world_bridge.game_time()
	_world_bridge.store_contract_result(transaction)
	_state_revision += 1
	var result := {
		"committed": true,
		"reason": str(transaction.get("contract_response", "")),
		"contract_offer_id": contract_id,
		"response": str(transaction.get("contract_response", "")),
		"receipt": receipt.duplicate(true),
	}
	contract_offer_resolved.emit(result.duplicate(true))
	return result


func respond_to_offer(player_index: int, contract_id: int, accept: bool, announce: bool = true, timeout: bool = false) -> Dictionary:
	if not _configured or _world_bridge == null:
		return {"committed": false, "reason": "controller_not_ready"}
	var offer := offer_by_id(contract_id)
	if offer.is_empty():
		if announce:
			_world_bridge.log_message("这份匿名合约已经结算或已失效。")
		return {"committed": false, "reason": "offer_not_found"}
	var source_index := int(offer.get("contract_source_district", -1))
	var target_index := int(offer.get("contract_target_district", -1))
	var facts := _facts(source_index, target_index, "")
	var plan := plan_response({"player_index": player_index, "contract_offer_id": contract_id, "accept": accept, "timeout": timeout}, facts)
	if not bool(plan.get("planned", false)):
		if announce and str(plan.get("reason", "")) == "response_not_authorized":
			_world_bridge.log_message("只有目标商品项目的控制者可以回应这份匿名合约。")
		return {"committed": false, "reason": str(plan.get("reason", "response_rejected"))}
	var result := commit_response(plan)
	if announce:
		_world_bridge.log_message("目标商品控制者已在展示后的独立签约窗口中%s匿名合约；合约发起者仍不公开。" % ("签署" if accept and not timeout else "拒绝"))
	_world_bridge.refresh_ui()
	return result


func tick(delta: float, arbitration: Dictionary) -> Array:
	var active_decision_id := str(arbitration.get("active_decision_id", arbitration.get("id", "")))
	var result := tick_visible_offer(delta, active_decision_id)
	return [result] if bool(result.get("ticked", false)) else []


func tick_visible_offer(delta: float, active_decision_id: String) -> Dictionary:
	if delta <= 0.0 or not active_decision_id.begins_with("contract_response_"):
		return {"ticked": false, "reason": "contract_not_visible"}
	var id_text := active_decision_id.substr("contract_response_".length())
	if not id_text.is_valid_int():
		return {"ticked": false, "reason": "active_decision_id_invalid"}
	var contract_id := int(id_text)
	var index := _offer_index(contract_id)
	if index < 0:
		return {"ticked": false, "reason": "offer_not_found"}
	var offer := (pending_offers[index] as Dictionary).duplicate(true)
	var previous := maxf(0.0, float(offer.get("contract_decision_timer", _decision_seconds)))
	var remaining := maxf(0.0, previous - delta)
	offer["contract_decision_timer"] = remaining
	pending_offers[index] = offer
	var refresh_needed := ceili(previous * 10.0) != ceili(remaining * 10.0)
	if remaining > 0.0:
		if refresh_needed:
			_world_bridge.refresh_ui()
		return {"ticked": true, "reason": "visible_timer_advanced", "contract_offer_id": contract_id, "remaining": remaining, "timed_out": false}
	var timeout_result := respond_to_offer(int(offer.get("contract_target_owner", -1)), contract_id, false, false, true)
	if bool(timeout_result.get("committed", false)):
		_world_bridge.log_message("匿名合约的独立签约窗口结束：目标商品控制者未回应，按超时拒签处理。")
		_world_bridge.refresh_ui()
	return {"ticked": true, "reason": str(timeout_result.get("reason", "timeout")), "contract_offer_id": contract_id, "remaining": 0.0, "timed_out": bool(timeout_result.get("committed", false))}


func forced_decision_candidates() -> Array:
	var result: Array = []
	for offer_variant in pending_offers:
		if not (offer_variant is Dictionary):
			continue
		var offer := offer_variant as Dictionary
		if str(offer.get("contract_response", "")) != RESPONSE_PENDING:
			continue
		var contract_id := int(offer.get("contract_offer_id", offer.get("resolution_id", -1)))
		result.append({
			"id": "contract_response_%d" % contract_id,
			"kind": "contract_response",
			"priority_group": "contract_response",
			"owner_player_index": int(offer.get("contract_target_owner", -1)),
			"visibility_scope": "private",
			"presentation_surface": "overlay",
			"opened_sequence": float(contract_id),
			"blocks_global_time": false,
			"blocks_player_actions": true,
			"blocks_card_resolution": false,
			"source_ref": "contract_response",
			"notes": "Only the target product-project controller receives this non-blocking response payload.",
		})
	return result


func active_offer_for_player(player_index: int) -> Dictionary:
	var offers := offers_for_player(player_index)
	return (offers[0] as Dictionary).duplicate(true) if not offers.is_empty() and offers[0] is Dictionary else {}


func offer_by_id(contract_id: int) -> Dictionary:
	var index := _offer_index(contract_id)
	return (pending_offers[index] as Dictionary).duplicate(true) if index >= 0 else {}


func offers_for_player(player_index: int) -> Array:
	var result: Array = []
	for offer_variant in pending_offers:
		if not (offer_variant is Dictionary):
			continue
		var offer := offer_variant as Dictionary
		if int(offer.get("contract_target_owner", -1)) == player_index and str(offer.get("contract_response", "")) == RESPONSE_PENDING:
			result.append(offer.duplicate(true))
	return result


func pending_offers_snapshot(include_private: bool = false) -> Array:
	var result: Array = []
	for offer_variant in pending_offers:
		if offer_variant is Dictionary:
			result.append((offer_variant as Dictionary).duplicate(true) if include_private else _public_offer_snapshot(offer_variant as Dictionary))
	return result


func decision_snapshot(player_index: int) -> Dictionary:
	if _world_bridge == null or not _world_bridge.can_view_private_player(player_index):
		return {}
	var entry := active_offer_for_player(player_index)
	if entry.is_empty():
		return {}
	var skill: Dictionary = entry.get("skill", {}) as Dictionary
	var contract_id := int(entry.get("contract_offer_id", entry.get("resolution_id", -1)))
	var timer := maxf(0.0, float(entry.get("contract_decision_timer", _decision_seconds)))
	var accept_summary := accept_effect_summary(skill)
	var reject_summary := decline_effect_summary(skill)
	var source_name := district_short_name(int(entry.get("contract_source_district", -1)))
	var target_name := district_short_name(int(entry.get("contract_target_district", -1)))
	var products := entry_product_text(entry)
	var card_name := str(skill.get("name", "合约牌"))
	return {
		"id": "contract_response_%d" % contract_id,
		"kind": "contract_response",
		"title": "匿名合约签署窗口",
		"body": "%s｜%s → %s｜商品：%s。签约：%s；拒绝：%s。" % [card_name, source_name, target_name, products, accept_summary, reject_summary],
		"tooltip": "合约牌公开展示后，签约选择只发给目标商品项目控制者；发起者和回应者身份仍需从路线、商品和收益变化推理。",
		"chips": [
			{"text": "私密签约权", "tooltip": "只有目标商品项目控制者可操作。", "accent": "#bfdbfe"},
			{"text": "不阻塞", "tooltip": "不会阻塞其他玩家继续出牌。", "accent": "#fde68a"},
			{"text": "%.0fs" % timer, "tooltip": "沙漏只在该窗口真正显示时倒计时；结束按拒签处理。", "accent": "#fbbf24"},
		],
		"actions": [
			{"id": "contract_accept_%d" % contract_id, "label": "签约", "tooltip": "接受这份已完成公开展示的匿名合约。"},
			{"id": "contract_reject_%d" % contract_id, "label": "拒绝", "tooltip": "拒绝匿名合约；如果卡面带拒签惩罚，结算时会生效。"},
		],
		"contract": {
			"card": card_name,
			"route": "%s → %s" % [source_name, target_name],
			"products": products,
			"accept": accept_summary,
			"reject": reject_summary,
			"timer": timer,
			"timer_text": "%.0fs" % timer,
			"privacy": "签约选择只发给目标商品项目控制者；合约牌本身和公开条件仍在牌轨中供全场推理。",
		},
		"accent": "#fbbf24",
	}


func private_response_snapshot(viewer_index: int) -> Dictionary:
	return decision_snapshot(viewer_index)


func public_snapshot() -> Dictionary:
	return {
		"pending_offers": pending_offers_snapshot(false),
		"pending_offer_count": pending_offers.size(),
		"selection": {
			"source_district": selected_source_district,
			"target_district": selected_target_district,
			"ready": selection_ready(),
		},
		"owner_hidden": true,
	}


func entry_product_text(entry: Dictionary) -> String:
	var products: Array = entry.get("contract_products", []) as Array if entry.get("contract_products", []) is Array else []
	return "未指定商品" if products.is_empty() else "、".join(products)


func response_public_label(entry: Dictionary) -> String:
	match str(entry.get("contract_response", "")):
		RESPONSE_ACCEPTED: return "已签约"
		RESPONSE_REJECTED: return "已拒签"
		RESPONSE_TIMEOUT: return "超时拒签"
		RESPONSE_PENDING:
			var contract_id := int(entry.get("contract_offer_id", entry.get("resolution_id", -1)))
			return "签约窗口开放" if _offer_index(contract_id) >= 0 else "等待目标商品控制者"
	return "无签约窗口"


func accept_effect_summary(skill: Dictionary) -> String:
	var pieces: Array = []
	var cash := int(skill.get("accept_cash", 0))
	if cash > 0: pieces.append("¥+%d" % cash)
	var production_delta := int(skill.get("accept_production_delta", 0))
	var transport_delta := int(skill.get("accept_transport_delta", 0))
	var consumption_delta := int(skill.get("accept_consumption_delta", 0))
	if production_delta != 0: pieces.append("生产%s" % _signed_int(production_delta))
	if transport_delta != 0: pieces.append("交通%s" % _signed_int(transport_delta))
	if consumption_delta != 0: pieces.append("消费%s" % _signed_int(consumption_delta))
	var flow_multiplier := float(skill.get("accept_route_flow_multiplier", 1.0))
	if flow_multiplier > 1.001:
		pieces.append("流通×%.2f/%s" % [flow_multiplier, _duration_text(_skill_duration(skill, "route_flow_seconds", "route_flow_turns", 1))])
	var add_products := int(skill.get("contract_add_products", 0))
	var add_demands := int(skill.get("contract_add_demands", 0))
	var remove_products := int(skill.get("contract_remove_products", 0))
	var remove_demands := int(skill.get("contract_remove_demands", 0))
	if add_products > 0 or add_demands > 0: pieces.append("接入供%d/需%d" % [maxi(0, add_products), maxi(0, add_demands)])
	if remove_products > 0 or remove_demands > 0: pieces.append("替换供%d/需%d" % [maxi(0, remove_products), maxi(0, remove_demands)])
	return "、".join(pieces) if not pieces.is_empty() else "无额外奖励"


func decline_effect_summary(skill: Dictionary) -> String:
	var pieces: Array = []
	var penalty := int(skill.get("decline_cash_penalty", 0))
	if penalty > 0: pieces.append("罚¥%d" % penalty)
	var production_delta := int(skill.get("decline_production_delta", 0))
	var transport_delta := int(skill.get("decline_transport_delta", 0))
	var consumption_delta := int(skill.get("decline_consumption_delta", 0))
	if production_delta != 0: pieces.append("生产%s" % _signed_int(production_delta))
	if transport_delta != 0: pieces.append("交通%s" % _signed_int(transport_delta))
	if consumption_delta != 0: pieces.append("消费%s" % _signed_int(consumption_delta))
	var route_damage := int(skill.get("decline_route_damage", 0))
	if route_damage > 0: pieces.append("断路+%d" % route_damage)
	return "、".join(pieces) if not pieces.is_empty() else "无额外惩罚"


func response_result_clue(entry: Dictionary) -> String:
	var response := str(entry.get("contract_response", RESPONSE_PENDING))
	var effect_label := "签约奖励" if response == RESPONSE_ACCEPTED else "拒签惩罚"
	var effect_summary := accept_effect_summary(entry.get("skill", {}) as Dictionary) if response == RESPONSE_ACCEPTED else decline_effect_summary(entry.get("skill", {}) as Dictionary)
	if response == RESPONSE_PENDING:
		effect_label = "待定影响"
		effect_summary = "等待目标商品控制者回应"
	return "合约%s｜%s→%s｜商品:%s｜%s:%s｜发起者和回应者仍需推理" % [response_public_label(entry), district_short_name(int(entry.get("contract_source_district", -1))), district_short_name(int(entry.get("contract_target_district", -1))), entry_product_text(entry), effect_label, effect_summary]


func card_resolution_public_text(entry: Dictionary) -> String:
	var skill: Dictionary = entry.get("skill", {}) as Dictionary
	if str(skill.get("kind", "")) != CONTRACT_KIND:
		return ""
	return "合约：%s→%s｜%s｜回应：%s｜签%s｜拒%s" % [district_short_name(int(entry.get("contract_source_district", -1))), district_short_name(int(entry.get("contract_target_district", -1))), entry_product_text(entry), response_public_label(entry), accept_effect_summary(skill), decline_effect_summary(skill)]


func traceable_contract_entries(preferred_resolution_id: int = -1, limit: int = 1) -> Array:
	var result: Array = []
	if _world_bridge == null:
		return result
	for entry_variant in _world_bridge.contract_history_entries(preferred_resolution_id, limit):
		if entry_variant is Dictionary:
			result.append(_public_offer_snapshot(entry_variant as Dictionary))
	return result


func trace_contract_parties(viewer_index: int, preferred_resolution_id: int = -1, count: int = 1, source: String = "密约回溯") -> int:
	if _world_bridge == null:
		return 0
	var traced := 0
	for entry_variant in _world_bridge.contract_history_entries(preferred_resolution_id, maxi(1, count)):
		if entry_variant is Dictionary and _world_bridge.remember_contract_parties(viewer_index, entry_variant as Dictionary, source):
			traced += 1
	return traced


func apply_intel_contract_trace(viewer_index: int, preferred_resolution_id: int, skill: Dictionary) -> bool:
	return trace_contract_parties(viewer_index, preferred_resolution_id, maxi(1, int(skill.get("trace_contract_count", 1))), str(skill.get("name", "密约回溯"))) > 0


func to_save_data() -> Dictionary:
	return {
		"selected_contract_source_district": selected_source_district,
		"selected_contract_target_district": selected_target_district,
		"pending_contract_offers": pending_offers.duplicate(true),
		"contract_runtime_revision": _state_revision,
		"contract_committed_transaction_ids": _committed_transaction_ids.duplicate(),
	}


func apply_save_data(data: Dictionary) -> Dictionary:
	selected_source_district = int(data.get("selected_contract_source_district", -1))
	selected_target_district = int(data.get("selected_contract_target_district", -1))
	pending_offers = (data.get("pending_contract_offers", []) as Array).duplicate(true) if data.get("pending_contract_offers", []) is Array else []
	_state_revision = maxi(0, int(data.get("contract_runtime_revision", 0)))
	_committed_transaction_ids.clear()
	var transaction_ids: Variant = data.get("contract_committed_transaction_ids", [])
	if transaction_ids is Array:
		for id_variant in transaction_ids:
			var transaction_id := str(id_variant)
			if transaction_id != "" and not _committed_transaction_ids.has(transaction_id):
				_committed_transaction_ids.append(transaction_id)
	return {"applied": true, "pending_offer_count": pending_offers.size(), "revision": _state_revision}


func debug_snapshot(viewer_index: int = -1) -> Dictionary:
	var viewer_offer_count := offers_for_player(viewer_index).size() if viewer_index >= 0 else 0
	return {
		"controller_ready": _configured and _world_bridge != null and _world_bridge.has_world(),
		"controller_authoritative": _configured,
		"runtime_owner": "res://scripts/runtime/contract_runtime_controller.gd",
		"decision_seconds": _decision_seconds,
		"pending_offer_count": pending_offers.size(),
		"viewer_offer_count": viewer_offer_count,
		"selection_ready": selection_ready(),
		"state_revision": _state_revision,
		"committed_transaction_count": _committed_transaction_ids.size(),
		"response_authority": "target_product_project_controller",
		"self_sign_default_allowed": false,
		"visible_timer_only": true,
		"blocks_card_resolution": false,
		"private_owner_exposed": false,
	}


func _facts(source_index: int, target_index: int, selected_product: String) -> Dictionary:
	return _world_bridge.contract_facts(source_index, target_index, selected_product) if _world_bridge != null else {}


func _district_fact(index: int) -> Dictionary:
	if _world_bridge == null:
		return {"index": index, "valid": false, "name": "未设", "destroyed": true, "terrain": "", "city": {}}
	var facts := _world_bridge.contract_facts(index, index, "")
	return (facts.get("source", {}) as Dictionary).duplicate(true) if facts.get("source", {}) is Dictionary else {}


func _source_fact_valid(source: Dictionary) -> bool:
	return bool(source.get("valid", false)) and not bool(source.get("destroyed", true)) and str(source.get("terrain", "")) != "ocean"


func _target_fact_valid(target: Dictionary) -> bool:
	return bool(target.get("valid", false)) and not bool(target.get("destroyed", true)) and bool((target.get("city", {}) as Dictionary).get("active", false))


func _contract_products(skill: Dictionary, facts: Dictionary) -> Array:
	var result: Array = []
	var goal := _product_goal(skill)
	_append_unique_values(result, skill.get("contract_products", []), goal)
	if result.size() >= goal:
		return result
	var mode := str(skill.get("contract_product_mode", "selected"))
	var selected_product := str(facts.get("selected_product", ""))
	var catalog: Array = facts.get("product_catalog", []) as Array if facts.get("product_catalog", []) is Array else []
	if mode != "auto" and selected_product != "" and catalog.has(selected_product):
		_append_unique(result, selected_product)
		if mode == "selected" and result.size() >= goal:
			return result
	var source: Dictionary = facts.get("source", {}) as Dictionary if facts.get("source", {}) is Dictionary else {}
	var target: Dictionary = facts.get("target", {}) as Dictionary if facts.get("target", {}) is Dictionary else {}
	var source_city: Dictionary = source.get("city", {}) as Dictionary if source.get("city", {}) is Dictionary else {}
	var target_city: Dictionary = target.get("city", {}) as Dictionary if target.get("city", {}) is Dictionary else {}
	_append_unique_values(result, source_city.get("products", []), goal)
	_append_unique_values(result, source.get("products", []), goal)
	_append_unique_values(result, target_city.get("demands", []), goal)
	_append_unique_values(result, target.get("demands", []), goal)
	_append_unique_values(result, catalog, goal)
	return result


func _product_goal(skill: Dictionary) -> int:
	var requested := maxi(1, maxi(maxi(0, int(skill.get("contract_add_products", 1))), maxi(0, int(skill.get("contract_add_demands", 1)))))
	return mini(requested, 1) if str(skill.get("contract_product_mode", "selected")) == "selected" else requested


func _target_project_authority(products: Array, target: Dictionary) -> Dictionary:
	var city: Dictionary = target.get("city", {}) as Dictionary if target.get("city", {}) is Dictionary else {}
	var projects: Array = city.get("projects", []) as Array if city.get("projects", []) is Array else []
	var controllers: Array = []
	var project_ids: Array = []
	for product_variant in products:
		var product_id := str(product_variant)
		var matching: Array = []
		var demand_matching: Array = []
		for project_variant in projects:
			if not (project_variant is Dictionary):
				continue
			var project := project_variant as Dictionary
			if not bool(project.get("active", true)) or str(project.get("product_id", "")) != product_id:
				continue
			matching.append(project)
			if str(project.get("direction", "")) == "demand":
				demand_matching.append(project)
		var authoritative := demand_matching if not demand_matching.is_empty() else matching
		if authoritative.is_empty():
			return {"resolved": false, "reason": "missing_target_product_project", "product_id": product_id}
		for project_variant in authoritative:
			var project := project_variant as Dictionary
			var controller := int(project.get("controller_player_index", -1))
			if controller < 0:
				return {"resolved": false, "reason": "target_project_controller_invalid", "product_id": product_id}
			if not controllers.has(controller):
				controllers.append(controller)
			var project_id := str(project.get("project_id", ""))
			if project_id != "" and not project_ids.has(project_id):
				project_ids.append(project_id)
	if controllers.size() != 1:
		return {"resolved": false, "reason": "ambiguous_target_project_controller", "controller_count": controllers.size(), "project_ids": project_ids}
	return {"resolved": true, "reason": "resolved", "controller_player_index": int(controllers[0]), "project_ids": project_ids}


func _public_offer_snapshot(offer: Dictionary) -> Dictionary:
	return {
		"contract_offer_id": int(offer.get("contract_offer_id", offer.get("resolution_id", -1))),
		"resolution_id": int(offer.get("resolution_id", offer.get("queued_order", -1))),
		"contract_source_district": int(offer.get("contract_source_district", -1)),
		"contract_target_district": int(offer.get("contract_target_district", -1)),
		"contract_products": (offer.get("contract_products", []) as Array).duplicate(true) if offer.get("contract_products", []) is Array else [],
		"contract_response": str(offer.get("contract_response", RESPONSE_PENDING)),
		"contract_decision_timer": maxf(0.0, float(offer.get("contract_decision_timer", 0.0))),
		"card_name": str((offer.get("skill", {}) as Dictionary).get("name", "匿名合约")),
		"owner_hidden": true,
	}


func _offer_index(contract_id: int) -> int:
	for index in range(pending_offers.size()):
		if pending_offers[index] is Dictionary and int((pending_offers[index] as Dictionary).get("contract_offer_id", (pending_offers[index] as Dictionary).get("resolution_id", -1))) == contract_id:
			return index
	return -1


func _offer_rejection(reason: String, extra: Dictionary = {}) -> Dictionary:
	var result := {"planned": false, "reason": reason, "context_revision": _state_revision}
	result.merge(extra, true)
	return result


func _reason_message(reason: String, skill: Dictionary) -> String:
	var card_name := str(skill.get("name", "区域供需合约"))
	match reason:
		"source_district_invalid": return "%s需要先在地图上设置一个未毁陆地供给区。" % card_name
		"target_district_invalid": return "%s需要先在地图上设置一个有存活城市群的需求/签约区。" % card_name
		"same_source_target": return "%s的供给区和需求区不能是同一区域。" % card_name
		"contract_products_missing": return "%s没有可写入合约的商品。" % card_name
		"missing_target_product_project": return "%s的目标商品没有可回应的城市商品项目。" % card_name
		"ambiguous_target_project_controller": return "%s的目标商品由多个控制者管理，无法确定唯一签约权。" % card_name
		"target_project_controller_invalid": return "%s找不到有效的目标商品项目控制者。" % card_name
		"self_sign_not_allowed": return "%s不允许同一玩家自行签署供需两端。" % card_name
	return "%s当前不能建立有效匿名合约。" % card_name


func _append_unique_values(target: Array, values: Variant, limit: int) -> void:
	if not (values is Array):
		return
	for value in values:
		if target.size() >= limit:
			return
		_append_unique(target, str(value))


func _append_unique(target: Array, value: String) -> void:
	if value != "" and not target.has(value):
		target.append(value)


func _signed_int(value: int) -> String:
	return "+%d" % value if value > 0 else str(value)


func _skill_duration(skill: Dictionary, seconds_key: String, turns_key: String, fallback_turns: int) -> float:
	if skill.has(seconds_key):
		return maxf(0.0, float(skill.get(seconds_key, 0.0)))
	return maxf(0.0, float(skill.get(turns_key, fallback_turns)) * 30.0)


func _duration_text(seconds: float) -> String:
	return "%.0f秒" % seconds


func _is_pure_data(value: Variant) -> bool:
	if value is Callable or value is Object:
		return false
	if value is Dictionary:
		for key in (value as Dictionary):
			if not _is_pure_data(key) or not _is_pure_data((value as Dictionary)[key]):
				return false
	if value is Array:
		for item in value:
			if not _is_pure_data(item):
				return false
	return true
