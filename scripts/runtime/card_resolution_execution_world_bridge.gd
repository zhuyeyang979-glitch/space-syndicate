@tool
extends Node
class_name CardResolutionExecutionWorldBridge

## Historical scene name retained for composition stability. This is now a
## typed execution port: it never receives, stores, discovers, or reflects Main.

var _world_session_state: WorldSessionState
var _table_selection_state: TableSelectionState
var _queue_service: CardResolutionQueueRuntimeService
var _resolution_controller: CardResolutionRuntimeController
var _eligibility_facts: CardPlayEligibilityWorldBridge
var _eligibility_service: CardPlayEligibilityRuntimeService
var _counter_service: CardCounterSettlementRuntimeService
var _commitment_service: CardCommitmentRuntimeService
var _history_service: CardResolutionHistoryRuntimeService
var _presentation_port: CardResolutionPresentationPort
var _effect_router: CardEffectRuntimeRouter
var _runtime_coordinator: GameRuntimeCoordinator
var _apply_count := 0


func set_table_selection_state(state: TableSelectionState) -> void:
	_table_selection_state = state


func set_world_session_state(state: WorldSessionState) -> void:
	_world_session_state = state


func set_runtime_dependencies(
	queue_service: CardResolutionQueueRuntimeService,
	resolution_controller: CardResolutionRuntimeController,
	eligibility_facts: CardPlayEligibilityWorldBridge,
	eligibility_service: CardPlayEligibilityRuntimeService,
	counter_service: CardCounterSettlementRuntimeService,
	commitment_service: CardCommitmentRuntimeService,
	history_service: CardResolutionHistoryRuntimeService,
	presentation_port: CardResolutionPresentationPort,
	effect_router: CardEffectRuntimeRouter,
	runtime_coordinator: GameRuntimeCoordinator
) -> void:
	_queue_service = queue_service
	_resolution_controller = resolution_controller
	_eligibility_facts = eligibility_facts
	_eligibility_service = eligibility_service
	_counter_service = counter_service
	_commitment_service = commitment_service
	_history_service = history_service
	_presentation_port = presentation_port
	_effect_router = effect_router
	_runtime_coordinator = runtime_coordinator


func world_session_state() -> WorldSessionState:
	return _world_session_state


func table_selection_state() -> TableSelectionState:
	return _table_selection_state


func apply_intent(transaction: Dictionary) -> Dictionary:
	_apply_count += 1
	var next_intent: Dictionary = _dictionary(transaction.get("next_intent", {}))
	var intent_type := str(next_intent.get("intent_type", ""))
	match intent_type:
		"counter_check":
			var entry := _dictionary(transaction.get("active_entry", {}))
			_resolution_controller.record_resolving_player(int(entry.get("player_index", -1)))
			return _counter_service.resolve_counter(entry)
		"release_active":
			var release := _queue_service.complete_active(int(transaction.get("resolution_id", -1)), {})
			release["intent_type"] = intent_type
			return release
		"finish_presentation":
			_resolution_controller.finish_active_presentation()
			_presentation_port.set_overlay_state({"visible": false, "phase": "idle", "resolution_id": -1})
			return {"intent_type": intent_type, "finished": true}
		"revalidate_requirement":
			return _requirement_receipt(transaction)
		"revalidate_target":
			return _target_receipt(transaction)
		"dispatch_effect":
			return _effect_router.dispatch(transaction)
		"finish_card_commitment":
			return _commitment_service.finalize_commitment({
				"transaction_id": "card-commitment:%d" % int(transaction.get("resolution_id", -1)),
				"entry": _dictionary(transaction.get("active_entry", {})),
				"skill": _dictionary(transaction.get("skill", {})),
				"selected_district": int(_dictionary(transaction.get("active_entry", {})).get("selected_district", -1)),
			})
		"create_aftermath":
			return _aftermath_receipt(transaction)
		"restore_context":
			# Revalidation and routing consume the immutable queue context directly;
			# global table selection is therefore never borrowed and needs no restore.
			return {"intent_type": intent_type, "restored": true, "selection_unchanged": true}
		"append_history":
			return _history_receipt(transaction)
		"start_next":
			return _start_next_receipt()
		"finish_batch":
			_resolution_controller.finish_batch_state()
			_presentation_port.set_overlay_state({"visible": false, "phase": "idle", "resolution_id": -1})
			return {"intent_type": intent_type, "finished": true, "next_queue_count": _queue_service.next_queue().size()}
		"promote_next_batch":
			return _promote_next_batch_receipt()
	return {"intent_type": intent_type, "reason": "unsupported_intent"}


func start_next_transition() -> Dictionary:
	var receipt := _start_next_receipt()
	if bool(receipt.get("started", false)):
		return receipt
	if str(receipt.get("reason", "")) != "batch_empty":
		return receipt
	_resolution_controller.finish_batch_state()
	_presentation_port.set_overlay_state({"visible": false, "phase": "idle", "resolution_id": -1})
	var promotion := _promote_next_batch_receipt() if not _queue_service.next_queue().is_empty() else {
		"intent_type": "promote_next_batch",
		"promoted": false,
		"reason": "next_queue_empty",
	}
	return {
		"intent_type": "start_next",
		"started": false,
		"batch_finished": true,
		"promoted": bool(promotion.get("promoted", false)),
		"reason": "batch_empty",
	}


func lock_batch_transition() -> Dictionary:
	if _queue_service == null or _resolution_controller == null or _world_session_state == null:
		return {"handled": false, "reason": "transition_dependencies_missing"}
	var lock_receipt := _queue_service.lock_batch({
		"reference_player": _resolution_controller.batch_reference_player,
		"player_count": _world_session_state.players.size(),
	})
	if not bool(lock_receipt.get("locked", false)):
		return {
			"handled": false,
			"reason": str(lock_receipt.get("reason", "queue_not_lockable")),
			"lock_receipt": lock_receipt,
		}
	var start_receipt := start_next_transition()
	return {
		"handled": bool(start_receipt.get("started", false)) or bool(start_receipt.get("batch_finished", false)),
		"reason": str(start_receipt.get("reason", "")),
		"lock_receipt": lock_receipt,
		"start_receipt": start_receipt,
	}


func settle_finalized_execution(transaction: Dictionary, finalized: Dictionary) -> Dictionary:
	if not bool(finalized.get("completed", false)):
		return {"settled": false, "reason": str(finalized.get("reason", "execution_not_completed"))}
	if _runtime_coordinator == null:
		return {"settled": false, "reason": "runtime_coordinator_missing"}
	var entry := _dictionary(transaction.get("active_entry", {}))
	var coordinator_receipt := _runtime_coordinator.settle_card_mana_reservation(entry, finalized)
	if not coordinator_receipt is Dictionary:
		return {"settled": false, "reason": "mana_settlement_receipt_invalid"}
	var result := (coordinator_receipt as Dictionary).duplicate(true)
	result["settled"] = bool(coordinator_receipt.get("settled", false))
	result["reason"] = str(coordinator_receipt.get("reason", "" if bool(result["settled"]) else "mana_settlement_failed"))
	result["resolution_id"] = int(finalized.get("resolution_id", -1))
	result["execution_id"] = int(finalized.get("execution_id", -1))
	result["settlement_binding"] = _dictionary(finalized.get("settlement_binding", {}))
	result["settlement_binding_fingerprint"] = str(finalized.get("settlement_binding_fingerprint", ""))
	return result


func debug_snapshot() -> Dictionary:
	return {
		"bridge_ready": _world_session_state != null \
			and _table_selection_state != null \
			and _queue_service != null \
			and _counter_service != null \
			and _effect_router != null,
		"typed_execution_port": true,
		"holds_main_reference": false,
		"dynamic_main_access_count": 0,
		"apply_count": _apply_count,
		"intent_execution_authority": false,
		"execution_order_authority": false,
		"queue_authority": false,
		"timing_authority": false,
		"concrete_effect_authority": false,
	}


func _requirement_receipt(transaction: Dictionary) -> Dictionary:
	var entry := _dictionary(transaction.get("active_entry", {}))
	var skill := _dictionary(transaction.get("skill", {}))
	var player_index := int(entry.get("player_index", -1))
	if _world_session_state == null or player_index < 0 or player_index >= _world_session_state.players.size():
		return {"intent_type": "revalidate_requirement", "valid": false, "reason": "invalid_player", "skill": skill}
	if skill.is_empty():
		return {"intent_type": "revalidate_requirement", "valid": false, "reason": "missing_skill", "skill": skill}
	skill.erase("queued_for_resolution")
	var context := _entry_context(entry)
	var facts := _eligibility_facts.build_facts(player_index, skill, context)
	if _runtime_coordinator != null:
		facts["commodity_color_flow"] = _runtime_coordinator.commodity_color_flow_snapshot(player_index)
		facts["player_mana"] = _runtime_coordinator.player_mana_availability(player_index)
	var result := _eligibility_service.evaluate_play({
		"player_index": player_index,
		"skill": skill,
		"evaluation_mode": "rule",
	}, facts)
	var valid := bool(result.get("allowed", false))
	return {
		"intent_type": "revalidate_requirement",
		"valid": valid,
		"reason": "valid" if valid else str(result.get("reason_code", "requirement_invalid")),
		"skill": skill,
	}


func _target_receipt(transaction: Dictionary) -> Dictionary:
	var entry := _dictionary(transaction.get("active_entry", {}))
	var skill := _dictionary(transaction.get("skill", {}))
	var player_index := int(entry.get("player_index", -1))
	var target_kind := str(transaction.get("target_kind", "none"))
	var valid := player_index >= 0 and _world_session_state != null and player_index < _world_session_state.players.size() and not skill.is_empty()
	var reason := "valid" if valid else "invalid_actor"
	if valid and target_kind == "monster":
		var monsters := _eligibility_facts.monster_roster_snapshot()
		var target_slot := int(entry.get("target_slot", -1))
		var target_uid := int(entry.get("target_monster_uid", -1))
		if target_uid > 0:
			target_slot = -1
			for monster_index in range(monsters.size()):
				if monsters[monster_index] is Dictionary and int((monsters[monster_index] as Dictionary).get("uid", -1)) == target_uid:
					target_slot = monster_index
					break
		valid = target_slot >= 0 and target_slot < monsters.size() and monsters[target_slot] is Dictionary and not bool((monsters[target_slot] as Dictionary).get("down", false))
		reason = "valid" if valid else "target_monster_invalid"
	elif valid and target_kind == "player":
		var target_player := int(entry.get("target_player", -1))
		valid = target_player >= 0 and target_player < _world_session_state.players.size() and target_player != player_index
		reason = "valid" if valid else "target_player_invalid"
	_presentation_port.publish_public_event({
		"event_id": "card-target:%d" % int(entry.get("resolution_id", entry.get("queued_order", -1))),
		"event_kind": "card_target_check",
		"resolution_id": int(entry.get("resolution_id", entry.get("queued_order", -1))),
		"card_name": str(skill.get("name", "卡牌")),
		"target_kind": target_kind,
		"status": "valid" if valid else "invalid",
		"summary": "目标有效，效果开始结算。" if valid else "目标已失效，本次不产生效果。",
		"district_index": int(entry.get("selected_district", -1)),
	})
	return {"intent_type": "revalidate_target", "valid": valid, "reason": reason}


func _aftermath_receipt(transaction: Dictionary) -> Dictionary:
	var entry := _dictionary(transaction.get("active_entry", {}))
	var skill := _dictionary(transaction.get("skill", {}))
	var resolution_id := int(entry.get("resolution_id", entry.get("queued_order", -1)))
	var clue := ""
	if bool(transaction.get("countered", false)):
		entry["countered"] = true
		entry["countered_by_resolution_id"] = int(transaction.get("counter_resolution_id", -1))
		clue = "被%s反制，未结算。" % str(transaction.get("counter_card_name", "相位否决"))
	elif bool(transaction.get("resolved", false)):
		clue = "%s已经完成结算。" % str(skill.get("name", "卡牌"))
	else:
		clue = "%s未能产生效果。" % str(skill.get("name", "卡牌"))
	entry["aftermath_clue"] = clue
	_presentation_port.publish_public_event({
		"event_id": "card-aftermath:%d" % resolution_id,
		"event_kind": "card_aftermath",
		"resolution_id": resolution_id,
		"card_name": str(skill.get("name", "卡牌")),
		"status": "resolved" if bool(transaction.get("resolved", false)) else "not_resolved",
		"aftermath_clue": clue,
		"summary": clue,
		"district_index": int(entry.get("selected_district", -1)),
	})
	return {"intent_type": "create_aftermath", "entry_patch": entry}


func _history_receipt(transaction: Dictionary) -> Dictionary:
	var entry := _dictionary(transaction.get("active_entry", {}))
	entry.erase("stable_target_envelope")
	entry["resolved_time"] = _world_session_state.game_time if _world_session_state != null else 0.0
	var append := _history_service.append_resolved(entry)
	return {
		"intent_type": "append_history",
		"appended": bool(append.get("appended", false)) or bool(append.get("duplicate", false)),
		"reason": str(append.get("reason", "history_append_failed")),
		"current_queue_count": _queue_service.current_queue().size(),
	}


func _start_next_receipt() -> Dictionary:
	var start := _queue_service.start_next({"game_time": _world_session_state.game_time if _world_session_state != null else 0.0})
	for skipped_variant in start.get("skipped_entries", []):
		if skipped_variant is Dictionary:
			_clear_queued_flag(skipped_variant as Dictionary)
			_runtime_coordinator.settle_card_mana_reservation(skipped_variant as Dictionary, {"resolved": false, "reason": "queue_entry_invalid"})
	if not bool(start.get("started", false)):
		return {"intent_type": "start_next", "started": false, "reason": str(start.get("reason", "batch_empty"))}
	var entry := _dictionary(start.get("active_entry", {}))
	var skill := _dictionary(entry.get("skill", {}))
	_resolution_controller.begin_active_display(float(skill.get("display_seconds", _resolution_controller.display_seconds)))
	_presentation_port.set_overlay_state({
		"visible": true,
		"phase": "reveal",
		"resolution_id": int(entry.get("resolution_id", -1)),
		"remaining_seconds": _resolution_controller.active_display_timer,
		"card_name": str(skill.get("name", "卡牌")),
	})
	return {"intent_type": "start_next", "started": true}


func _promote_next_batch_receipt() -> Dictionary:
	var previous_player := _resolution_controller.last_resolution_player_index
	var promotion := _queue_service.promote_next_batch({
		"window_sequence": _resolution_controller.window_sequence,
		"game_time": _world_session_state.game_time if _world_session_state != null else 0.0,
		"previous_player": previous_player,
		"player_count": _world_session_state.players.size() if _world_session_state != null else 0,
	})
	if bool(promotion.get("promoted", false)):
		_resolution_controller.begin_group_window(-1.0, int(promotion.get("reference_player", -1)), int(promotion.get("window_sequence", _resolution_controller.window_sequence + 1)))
	return {"intent_type": "promote_next_batch", "promoted": bool(promotion.get("promoted", false)), "reason": str(promotion.get("reason", ""))}


func _clear_queued_flag(entry: Dictionary) -> void:
	if _world_session_state == null or bool(entry.get("consumed_on_queue", false)):
		return
	var player_index := int(entry.get("player_index", -1))
	var slot_index := int(entry.get("slot_index", -1))
	var players := _world_session_state.players
	if player_index < 0 or player_index >= players.size() or not (players[player_index] is Dictionary):
		return
	var player := (players[player_index] as Dictionary).duplicate(true)
	var slots: Array = player.get("slots", []) if player.get("slots", []) is Array else []
	if slot_index < 0 or slot_index >= slots.size() or not (slots[slot_index] is Dictionary):
		return
	var skill := (slots[slot_index] as Dictionary).duplicate(true)
	skill.erase("queued_for_resolution")
	slots[slot_index] = skill
	player["slots"] = slots
	players[player_index] = player
	_world_session_state.players = players


func _entry_context(entry: Dictionary) -> Dictionary:
	return {
		"selected_district": int(entry.get("selected_district", -1)),
		"selected_trade_product": str(entry.get("selected_trade_product", "")),
		"contract_source_district": int(entry.get("contract_source_district", -1)),
		"contract_target_district": int(entry.get("contract_target_district", -1)),
		"play_requirement_district": int(entry.get("play_requirement_district", -1)),
	}


func _dictionary(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}
