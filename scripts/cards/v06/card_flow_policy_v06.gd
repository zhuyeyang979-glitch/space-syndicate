extends RefCounted
class_name CardFlowPolicyV06

const HAND_LIMIT := 5
const MAXIMUM_RANK := 4
const COLORED_ASSET_KEYS := ["life", "energy", "industry", "technology", "commerce", "shipping"]
const ASSET_COST_KEYS := ["life", "energy", "industry", "technology", "commerce", "shipping", "generic"]


func plan_receive(inventory: Dictionary, incoming_card: Dictionary, catalog: CardRuntimeCatalogV06Resource) -> Dictionary:
	if catalog == null or not bool(catalog.validation_report().get("valid", false)):
		return _reject("catalog_unavailable")
	if int(inventory.get("hand_limit", HAND_LIMIT)) != HAND_LIMIT:
		return _reject("hand_limit_mismatch")
	var incoming_machine := _machine(incoming_card)
	var incoming_id := str(incoming_machine.get("card_id", ""))
	var family_id := str(incoming_machine.get("family_id", ""))
	var rank := int(incoming_machine.get("rank", 0))
	if incoming_id.is_empty() or family_id.is_empty() or rank < 1 or rank > MAXIMUM_RANK:
		return _reject("incoming_card_invalid")
	var slots := _slots(inventory)
	var counted := _counted_hand_size(slots)
	var incoming_counted := bool(incoming_machine.get("counts_toward_hand_limit", true))
	var fingerprint := inventory_fingerprint(inventory)
	if not incoming_counted or counted < HAND_LIMIT:
		var empty_slot := _first_empty_slot(slots, HAND_LIMIT if incoming_counted else maxi(HAND_LIMIT, slots.size() + 1))
		return {
			"ready": true,
			"reason_code": "ready_add",
			"operation": "add",
			"target_slot": empty_slot,
			"incoming_card": incoming_card.duplicate(true),
			"inventory_fingerprint": fingerprint,
			"hand_count_delta": 1 if incoming_counted else 0,
		}
	var matching_slot := _matching_same_rank_slot(slots, family_id, rank)
	if matching_slot < 0:
		return _reject("hand_full_no_matching_merge", fingerprint)
	if rank >= MAXIMUM_RANK:
		return _reject("matching_card_at_max_rank", fingerprint)
	var next_card_id := "%s.rank_%d" % [family_id, rank + 1]
	var next_card := catalog.card_snapshot(next_card_id)
	if next_card.is_empty():
		return _reject("merge_result_missing", fingerprint)
	return {
		"ready": true,
		"reason_code": "ready_auto_merge_when_full",
		"operation": "auto_merge_when_full",
		"target_slot": matching_slot,
		"incoming_card": incoming_card.duplicate(true),
		"result_card": next_card,
		"result_card_id": next_card_id,
		"inventory_fingerprint": fingerprint,
		"hand_count_delta": 0,
	}


func commit_receive(inventory: Dictionary, plan: Dictionary) -> Dictionary:
	if not bool(plan.get("ready", false)):
		return {"committed": false, "reason_code": str(plan.get("reason_code", "plan_not_ready")), "inventory": inventory.duplicate(true)}
	if str(plan.get("inventory_fingerprint", "")) != inventory_fingerprint(inventory):
		return {"committed": false, "reason_code": "inventory_changed", "inventory": inventory.duplicate(true)}
	var slots := _slots(inventory)
	var target_slot := int(plan.get("target_slot", -1))
	if target_slot < 0:
		return {"committed": false, "reason_code": "target_slot_invalid", "inventory": inventory.duplicate(true)}
	while slots.size() <= target_slot:
		slots.append(null)
	var operation := str(plan.get("operation", ""))
	if operation == "add":
		if slots[target_slot] is Dictionary:
			return {"committed": false, "reason_code": "target_slot_occupied", "inventory": inventory.duplicate(true)}
		slots[target_slot] = (plan.get("incoming_card", {}) as Dictionary).duplicate(true)
	elif operation == "auto_merge_when_full":
		if not (slots[target_slot] is Dictionary):
			return {"committed": false, "reason_code": "merge_source_missing", "inventory": inventory.duplicate(true)}
		slots[target_slot] = (plan.get("result_card", {}) as Dictionary).duplicate(true)
	else:
		return {"committed": false, "reason_code": "operation_invalid", "inventory": inventory.duplicate(true)}
	var result := inventory.duplicate(true)
	result["slots"] = slots
	return {"committed": true, "reason_code": "committed", "operation": operation, "inventory": result, "target_slot": target_slot}


func plan_manual_merge(inventory: Dictionary, first_slot: int, second_slot: int, catalog: CardRuntimeCatalogV06Resource) -> Dictionary:
	if first_slot == second_slot:
		return _reject("merge_requires_two_cards")
	var slots := _slots(inventory)
	if first_slot < 0 or second_slot < 0 or first_slot >= slots.size() or second_slot >= slots.size():
		return _reject("merge_slot_invalid")
	if not (slots[first_slot] is Dictionary) or not (slots[second_slot] is Dictionary):
		return _reject("merge_card_missing")
	var first_card: Dictionary = slots[first_slot]
	var second_card: Dictionary = slots[second_slot]
	var first_machine := _machine(first_card)
	var second_machine := _machine(second_card)
	if str(first_machine.get("family_id", "")) != str(second_machine.get("family_id", "")):
		return _reject("merge_family_mismatch")
	if int(first_machine.get("rank", 0)) != int(second_machine.get("rank", 0)):
		return _reject("merge_rank_mismatch")
	var rank := int(first_machine.get("rank", 0))
	if rank >= MAXIMUM_RANK:
		return _reject("matching_card_at_max_rank")
	var result_card_id := "%s.rank_%d" % [str(first_machine.get("family_id", "")), rank + 1]
	var result_card := catalog.card_snapshot(result_card_id)
	if result_card.is_empty():
		return _reject("merge_result_missing")
	return {
		"ready": true,
		"reason_code": "ready_manual_merge",
		"operation": "manual_merge",
		"first_slot": first_slot,
		"second_slot": second_slot,
		"result_card_id": result_card_id,
		"result_card": result_card,
		"inventory_fingerprint": inventory_fingerprint(inventory),
		"hand_count_delta": -1,
	}


func commit_manual_merge(inventory: Dictionary, plan: Dictionary) -> Dictionary:
	if not bool(plan.get("ready", false)):
		return {"committed": false, "reason_code": str(plan.get("reason_code", "plan_not_ready")), "inventory": inventory.duplicate(true)}
	if str(plan.get("inventory_fingerprint", "")) != inventory_fingerprint(inventory):
		return {"committed": false, "reason_code": "inventory_changed", "inventory": inventory.duplicate(true)}
	var slots := _slots(inventory)
	var first_slot := int(plan.get("first_slot", -1))
	var second_slot := int(plan.get("second_slot", -1))
	if first_slot < 0 or second_slot < 0 or first_slot >= slots.size() or second_slot >= slots.size():
		return {"committed": false, "reason_code": "merge_slot_invalid", "inventory": inventory.duplicate(true)}
	slots[first_slot] = (plan.get("result_card", {}) as Dictionary).duplicate(true)
	slots[second_slot] = null
	var result := inventory.duplicate(true)
	result["slots"] = slots
	return {"committed": true, "reason_code": "committed", "operation": "manual_merge", "inventory": result, "target_slot": first_slot, "cleared_slot": second_slot}


func plan_acquisition(player_state: Dictionary, card: Dictionary, context: Dictionary, catalog: CardRuntimeCatalogV06Resource) -> Dictionary:
	var machine := _machine(card)
	var acquisition_kind := str(machine.get("acquisition_kind", ""))
	var source_kind := str(context.get("source_kind", ""))
	var card_id := str(machine.get("card_id", ""))
	var transaction_id := str(context.get("transaction_id", ""))
	if transaction_id.is_empty():
		return _reject("transaction_id_missing")
	if source_kind == "commodity_belt":
		if acquisition_kind != "commodity_belt_free":
			return _reject("card_not_available_on_belt")
		if not bool(context.get("visible", false)) or not bool(context.get("claimable", false)):
			return _reject("belt_card_not_claimable")
		if int(context.get("expected_revision", -1)) != int(context.get("current_revision", -2)):
			return _reject("belt_revision_changed")
	elif source_kind == "dynamic_market":
		if acquisition_kind != "dynamic_market_cash" and acquisition_kind != "starter_or_dynamic_market_cash":
			return _reject("card_not_available_in_market")
		if str(context.get("listing_card_id", "")) != card_id:
			return _reject("market_listing_changed")
		if int(context.get("expected_revision", -1)) != int(context.get("current_revision", -2)):
			return _reject("market_revision_changed")
	elif source_kind == "starter_selection":
		if acquisition_kind != "starter_or_dynamic_market_cash":
			return _reject("card_not_available_as_starter")
	else:
		return _reject("acquisition_source_invalid")
	var inventory: Dictionary = player_state.get("inventory", {}) if player_state.get("inventory", {}) is Dictionary else {}
	var receive_plan := plan_receive(inventory, card, catalog)
	if not bool(receive_plan.get("ready", false)):
		return receive_plan
	var cash_cost := 0 if source_kind != "dynamic_market" else int(machine.get("purchase_cash", 0))
	if int(player_state.get("cash", 0)) < cash_cost:
		return _reject("cash_insufficient", inventory_fingerprint(inventory))
	return {
		"ready": true,
		"reason_code": "ready_acquisition",
		"operation": "acquire",
		"source_kind": source_kind,
		"card_id": card_id,
		"transaction_id": transaction_id,
		"cash_debit": cash_cost,
		"receive_plan": receive_plan,
		"market_refresh_required": source_kind == "dynamic_market",
	}


func commit_acquisition(player_state: Dictionary, plan: Dictionary) -> Dictionary:
	if not bool(plan.get("ready", false)):
		return {"committed": false, "reason_code": str(plan.get("reason_code", "plan_not_ready")), "player_state": player_state.duplicate(true)}
	var transaction_id := str(plan.get("transaction_id", ""))
	var committed_ids: Array = player_state.get("committed_transaction_ids", []) if player_state.get("committed_transaction_ids", []) is Array else []
	if committed_ids.has(transaction_id):
		return {"committed": false, "reason_code": "transaction_already_committed", "player_state": player_state.duplicate(true)}
	var cash_debit := int(plan.get("cash_debit", 0))
	if int(player_state.get("cash", 0)) < cash_debit:
		return {"committed": false, "reason_code": "cash_changed", "player_state": player_state.duplicate(true)}
	var inventory: Dictionary = player_state.get("inventory", {}) if player_state.get("inventory", {}) is Dictionary else {}
	var receive_result := commit_receive(inventory, plan.get("receive_plan", {}) as Dictionary)
	if not bool(receive_result.get("committed", false)):
		return {"committed": false, "reason_code": str(receive_result.get("reason_code", "inventory_commit_failed")), "player_state": player_state.duplicate(true)}
	var result := player_state.duplicate(true)
	result["inventory"] = (receive_result.get("inventory", {}) as Dictionary).duplicate(true)
	result["cash"] = int(player_state.get("cash", 0)) - cash_debit
	var next_ids := committed_ids.duplicate()
	next_ids.append(transaction_id)
	result["committed_transaction_ids"] = next_ids
	return {
		"committed": true,
		"reason_code": "committed",
		"player_state": result,
		"cash_debit": cash_debit,
		"card_id": plan.get("card_id", ""),
		"market_refresh_required": plan.get("market_refresh_required", false),
	}


func plan_play(player_state: Dictionary, slot_index: int, target_context: Dictionary, available_effect_kinds: Array[String], transaction_id: String) -> Dictionary:
	if transaction_id.is_empty():
		return _reject("transaction_id_missing")
	var inventory: Dictionary = player_state.get("inventory", {}) if player_state.get("inventory", {}) is Dictionary else {}
	var slots := _slots(inventory)
	if slot_index < 0 or slot_index >= slots.size() or not (slots[slot_index] is Dictionary):
		return _reject("play_card_missing")
	var card: Dictionary = slots[slot_index]
	var machine := _machine(card)
	var effect_kind := str(machine.get("effect_kind", ""))
	var target_kind := str(machine.get("target_kind", ""))
	if not available_effect_kinds.has(effect_kind):
		return _reject("effect_owner_unavailable", inventory_fingerprint(inventory))
	if not bool(target_context.get("valid", false)) or str(target_context.get("target_kind", "")) != target_kind:
		return _reject("target_invalid", inventory_fingerprint(inventory))
	var assets: Dictionary = player_state.get("assets", {}) if player_state.get("assets", {}) is Dictionary else {}
	var asset_cost: Dictionary = machine.get("asset_cost", {}) if machine.get("asset_cost", {}) is Dictionary else {}
	var preferred_allocation: Dictionary = target_context.get("generic_asset_allocation", {}) if target_context.get("generic_asset_allocation", {}) is Dictionary else {}
	var payment_plan := _plan_asset_payment(assets, asset_cost, preferred_allocation)
	if not bool(payment_plan.get("ready", false)):
		return _reject(str(payment_plan.get("reason_code", "assets_insufficient")), inventory_fingerprint(inventory))
	return {
		"ready": true,
		"reason_code": "ready_play",
		"operation": "play",
		"transaction_id": transaction_id,
		"inventory_fingerprint": inventory_fingerprint(inventory),
		"slot_index": slot_index,
		"card_id": str(machine.get("card_id", "")),
		"effect_kind": effect_kind,
		"target_kind": target_kind,
		"target_context": target_context.duplicate(true),
		"effect_payload": (machine.get("effect_payload", {}) as Dictionary).duplicate(true),
		"asset_cost": asset_cost.duplicate(true),
		"asset_debit": (payment_plan.get("debit", {}) as Dictionary).duplicate(true),
		"consume_only_after_effect_commit": true,
	}


func commit_play(player_state: Dictionary, plan: Dictionary, effect_receipt: Dictionary) -> Dictionary:
	if not bool(plan.get("ready", false)):
		return {"committed": false, "reason_code": str(plan.get("reason_code", "plan_not_ready")), "player_state": player_state.duplicate(true)}
	if not bool(effect_receipt.get("committed", false)):
		return {"committed": false, "reason_code": str(effect_receipt.get("reason_code", "effect_not_committed")), "player_state": player_state.duplicate(true)}
	if str(effect_receipt.get("transaction_id", "")) != str(plan.get("transaction_id", "")):
		return {"committed": false, "reason_code": "effect_receipt_mismatch", "player_state": player_state.duplicate(true)}
	var committed_ids: Array = player_state.get("committed_transaction_ids", []) if player_state.get("committed_transaction_ids", []) is Array else []
	if committed_ids.has(str(plan.get("transaction_id", ""))):
		return {"committed": false, "reason_code": "transaction_already_committed", "player_state": player_state.duplicate(true)}
	var inventory: Dictionary = player_state.get("inventory", {}) if player_state.get("inventory", {}) is Dictionary else {}
	if inventory_fingerprint(inventory) != str(plan.get("inventory_fingerprint", "")):
		return {"committed": false, "reason_code": "inventory_changed", "player_state": player_state.duplicate(true)}
	var slots := _slots(inventory)
	var slot_index := int(plan.get("slot_index", -1))
	if slot_index < 0 or slot_index >= slots.size() or not (slots[slot_index] is Dictionary):
		return {"committed": false, "reason_code": "play_card_missing", "player_state": player_state.duplicate(true)}
	if str(_machine(slots[slot_index]).get("card_id", "")) != str(plan.get("card_id", "")):
		return {"committed": false, "reason_code": "play_card_changed", "player_state": player_state.duplicate(true)}
	var assets: Dictionary = player_state.get("assets", {}) if player_state.get("assets", {}) is Dictionary else {}
	var asset_debit: Dictionary = plan.get("asset_debit", {}) if plan.get("asset_debit", {}) is Dictionary else {}
	if not _can_apply_asset_debit(assets, asset_debit):
		return {"committed": false, "reason_code": "assets_changed", "player_state": player_state.duplicate(true)}
	slots[slot_index] = null
	var next_inventory := inventory.duplicate(true)
	next_inventory["slots"] = slots
	var result := player_state.duplicate(true)
	result["inventory"] = next_inventory
	result["assets"] = _subtract_asset_debit(assets, asset_debit)
	var next_ids := committed_ids.duplicate()
	next_ids.append(str(plan.get("transaction_id", "")))
	result["committed_transaction_ids"] = next_ids
	return {"committed": true, "reason_code": "committed", "player_state": result, "card_id": plan.get("card_id", ""), "effect_kind": plan.get("effect_kind", "")}


func player_feedback(reason_code: String) -> Dictionary:
	var copy := {
		"catalog_unavailable": ["卡牌目录尚未就绪。", "等待本局卡牌数据加载完成。"],
		"hand_full_no_matching_merge": ["手牌已满，且没有同名同级牌可以合成。", "先打出一张牌，或选择已有同名同级牌手动合成。"],
		"matching_card_at_max_rank": ["手牌已满，而且同名牌已经是 IV 级。", "先打出一张牌腾出手牌位置。"],
		"merge_family_mismatch": ["只有同名牌可以合成。", "请选择两张同名同级牌。"],
		"merge_rank_mismatch": ["不同等级的牌不能直接合成。", "请选择两张同名同级牌。"],
		"cash_insufficient": ["现金不足，无法购买这张牌。", "等待收入增长或选择更便宜的牌。"],
		"assets_insufficient": ["对应颜色的资产不足。", "让自己的该色商品产生更多 GDP 后再打出。"],
		"asset_allocation_invalid": ["通用资产的支付分配无效。", "重新选择可用的产业资产，或让系统自动分配。"],
		"effect_owner_unavailable": ["这张牌的效果尚未接入本局。", "本次不会消耗卡牌；请选择其他可用牌。"],
		"target_invalid": ["当前目标不合法。", "选择牌面允许的目标后再确认。"],
		"belt_revision_changed": ["这张商品已经离开可领取位置。", "从当前可见履带重新选择。"],
		"market_listing_changed": ["该市场牌已经被其他玩家买走。", "从立即刷新的新牌中重新选择。"],
	}
	var pair: Array = copy.get(reason_code, ["当前操作无法完成。", "请重新检查目标和资源。"])
	return {"reason": str(pair[0]), "next_step": str(pair[1])}


func inventory_fingerprint(inventory: Dictionary) -> String:
	var normalized: Array[Dictionary] = []
	for slot_index in range(_slots(inventory).size()):
		var slot_variant: Variant = _slots(inventory)[slot_index]
		if slot_variant is Dictionary:
			var machine := _machine(slot_variant)
			normalized.append({"slot": slot_index, "card_id": str(machine.get("card_id", "")), "occupied": true})
		else:
			normalized.append({"slot": slot_index, "card_id": "", "occupied": false})
	return str(hash(JSON.stringify({"hand_limit": int(inventory.get("hand_limit", HAND_LIMIT)), "slots": normalized})))


func _machine(card: Dictionary) -> Dictionary:
	var value: Variant = card.get("machine", {})
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _slots(inventory: Dictionary) -> Array:
	var value: Variant = inventory.get("slots", [])
	return (value as Array).duplicate(true) if value is Array else []


func _counted_hand_size(slots: Array) -> int:
	var count := 0
	for slot_variant in slots:
		if slot_variant is Dictionary and bool(_machine(slot_variant).get("counts_toward_hand_limit", true)):
			count += 1
	return count


func _first_empty_slot(slots: Array, search_limit: int) -> int:
	for index in range(search_limit):
		if index >= slots.size() or not (slots[index] is Dictionary):
			return index
	return slots.size()


func _matching_same_rank_slot(slots: Array, family_id: String, rank: int) -> int:
	for index in range(slots.size()):
		if not (slots[index] is Dictionary):
			continue
		var machine := _machine(slots[index])
		if str(machine.get("family_id", "")) == family_id and int(machine.get("rank", 0)) == rank:
			return index
	return -1


func _plan_asset_payment(current: Dictionary, cost: Dictionary, preferred_allocation: Dictionary = {}) -> Dictionary:
	var debit: Dictionary = {}
	var remaining: Dictionary = {}
	for key in COLORED_ASSET_KEYS:
		var current_value := int(current.get(key, 0))
		var fixed_cost := int(cost.get(key, 0))
		if current_value < 0 or fixed_cost < 0 or current_value < fixed_cost:
			return {"ready": false, "reason_code": "assets_insufficient"}
		debit[key] = fixed_cost
		remaining[key] = current_value - fixed_cost
	for key_variant in cost.keys():
		if not ASSET_COST_KEYS.has(str(key_variant)) or int(cost.get(key_variant, 0)) < 0:
			return {"ready": false, "reason_code": "asset_allocation_invalid"}
	var generic_needed := int(cost.get("generic", 0))
	if generic_needed <= 0:
		return {"ready": true, "reason_code": "ready_asset_payment", "debit": debit}
	if not preferred_allocation.is_empty():
		var allocated := 0
		for key_variant in preferred_allocation.keys():
			var key := str(key_variant)
			var amount := int(preferred_allocation.get(key_variant, -1))
			if not COLORED_ASSET_KEYS.has(key) or amount < 0 or amount > int(remaining.get(key, 0)):
				return {"ready": false, "reason_code": "asset_allocation_invalid"}
			debit[key] = int(debit.get(key, 0)) + amount
			allocated += amount
		if allocated != generic_needed:
			return {"ready": false, "reason_code": "asset_allocation_invalid"}
		return {"ready": true, "reason_code": "ready_asset_payment", "debit": debit}
	var unallocated := generic_needed
	while unallocated > 0:
		var best_key := ""
		var best_available := 0
		for key in COLORED_ASSET_KEYS:
			var available := int(remaining.get(key, 0))
			if available > best_available:
				best_key = key
				best_available = available
		if best_key.is_empty():
			return {"ready": false, "reason_code": "assets_insufficient"}
		var amount := mini(unallocated, best_available)
		debit[best_key] = int(debit.get(best_key, 0)) + amount
		remaining[best_key] = best_available - amount
		unallocated -= amount
	return {"ready": true, "reason_code": "ready_asset_payment", "debit": debit}


func _can_apply_asset_debit(current: Dictionary, debit: Dictionary) -> bool:
	for key_variant in debit.keys():
		var key := str(key_variant)
		if not COLORED_ASSET_KEYS.has(key) or int(debit.get(key_variant, -1)) < 0:
			return false
	for key in COLORED_ASSET_KEYS:
		if int(current.get(key, 0)) < int(debit.get(key, 0)):
			return false
	return true


func _subtract_asset_debit(current: Dictionary, debit: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key in COLORED_ASSET_KEYS:
		result[key] = int(current.get(key, 0)) - int(debit.get(key, 0))
	return result


func _reject(reason_code: String, fingerprint: String = "") -> Dictionary:
	return {"ready": false, "reason_code": reason_code, "operation": "reject", "inventory_fingerprint": fingerprint}
