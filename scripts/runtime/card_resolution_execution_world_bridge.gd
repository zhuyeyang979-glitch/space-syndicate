@tool
extends Node
class_name CardResolutionExecutionWorldBridge

var _table_selection_state: TableSelectionState
var _world_session_state: WorldSessionState


func set_table_selection_state(state: TableSelectionState) -> void:
	_table_selection_state = state


func set_world_session_state(state: WorldSessionState) -> void:
	_world_session_state = state


func world_session_state() -> WorldSessionState:
	return _world_session_state


func table_selection_state() -> TableSelectionState:
	return _table_selection_state


func apply_intent(world: Node, transaction: Dictionary) -> Dictionary:
	if world == null or not is_instance_valid(world):
		return {"intent_type": "", "reason": "world_missing"}
	var next_intent: Dictionary = transaction.get("next_intent", {}) as Dictionary
	var intent_type := str(next_intent.get("intent_type", ""))
	match intent_type:
		"counter_check":
			var entry: Dictionary = (transaction.get("active_entry", {}) as Dictionary).duplicate(true)
			world.set("last_card_resolution_player_index", int(entry.get("player_index", world.get("last_card_resolution_player_index"))))
			var counter_variant: Variant = world.call("_resolve_reactive_counter_for_entry", entry)
			var counter_entry: Dictionary = counter_variant if counter_variant is Dictionary else {}
			var counter_skill: Dictionary = counter_entry.get("skill", {}) as Dictionary
			return {"intent_type": intent_type, "countered": not counter_entry.is_empty(), "counter_resolution_id": int(counter_entry.get("resolution_id", -1)), "counter_card_name": str(counter_skill.get("name", "相位否决"))}
		"release_active":
			var queue_service: Node = world.call("_card_resolution_queue_service_node") as Node
			var release_variant: Variant = queue_service.call("complete_active", int(transaction.get("resolution_id", -1)), {}) if queue_service != null and queue_service.has_method("complete_active") else {}
			var release: Dictionary = (release_variant as Dictionary).duplicate(true) if release_variant is Dictionary else {}
			release["intent_type"] = intent_type
			return release
		"finish_presentation":
			world.set("card_resolution_auction_open", false)
			world.set("card_resolution_timer", 0.0)
			world.set("card_resolution_counter_window_active", false)
			world.set("card_resolution_counter_timer", 0.0)
			world.call("_hide_card_resolution_overlay")
			return {"intent_type": intent_type, "finished": true}
		"revalidate_requirement": return _requirement_receipt(world, transaction)
		"revalidate_target": return _target_receipt(world, transaction)
		"dispatch_effect": return world.call("_apply_card_resolution_effect_request", transaction) as Dictionary
		"finish_card_commitment": return world.call("_card_resolution_commitment_receipt", transaction) as Dictionary
		"create_aftermath": return _aftermath_receipt(world, transaction)
		"restore_context": return _restore_context_receipt(world, transaction)
		"append_history": return world.call("_card_resolution_history_receipt", transaction) as Dictionary
		"start_next":
			world.call("_start_next_card_resolution")
			var active_variant: Variant = world.call("_card_resolution_active_entry")
			return {"intent_type": intent_type, "started": active_variant is Dictionary and not (active_variant as Dictionary).is_empty()}
		"finish_batch":
			world.call("_reset_card_resolution_batch_state")
			var next_variant: Variant = world.call("_card_resolution_next_queue")
			return {"intent_type": intent_type, "finished": true, "next_queue_count": (next_variant as Array).size() if next_variant is Array else 0}
		"promote_next_batch":
			world.call("_promote_next_card_resolution_batch", int((transaction.get("active_entry", {}) as Dictionary).get("player_index", -1)))
			var current_variant: Variant = world.call("_card_resolution_current_queue")
			return {"intent_type": intent_type, "promoted": current_variant is Array and not (current_variant as Array).is_empty()}
	return {"intent_type": intent_type, "reason": "unsupported_intent"}


func debug_snapshot() -> Dictionary:
	return {
		"bridge_ready": true,
		"intent_execution_authority": false,
		"execution_order_authority": false,
		"queue_authority": false,
		"timing_authority": false,
		"concrete_effect_authority": false,
	}


func _requirement_receipt(world: Node, transaction: Dictionary) -> Dictionary:
	var entry: Dictionary = (transaction.get("active_entry", {}) as Dictionary).duplicate(true)
	var skill: Dictionary = (transaction.get("skill", {}) as Dictionary).duplicate(true)
	var player_index := int(entry.get("player_index", -1))
	if _world_session_state == null:
		return {"intent_type": "apply_cash_cost", "applied": false, "reason": "world_session_state_missing"}
	var players: Array = _world_session_state.players
	if player_index < 0 or player_index >= players.size():
		return {"intent_type": "revalidate_requirement", "valid": false, "reason": "invalid_player", "skill": skill}
	if skill.is_empty():
		world.call("_log", "一张匿名候补卡缺少卡面快照，结算取消。")
		return {"intent_type": "revalidate_requirement", "valid": false, "reason": "missing_skill", "skill": skill}
	skill.erase("queued_for_resolution")
	var player: Dictionary = players[player_index]
	var slots: Array = player.get("slots", [])
	var consumed_on_queue := bool(entry.get("consumed_on_queue", false))
	var slot_index := int(entry.get("slot_index", -1))
	if not consumed_on_queue and slot_index >= 0 and slot_index < slots.size() and slots[slot_index] is Dictionary:
		slots[slot_index] = skill
		player["slots"] = slots
	players[player_index] = player
	_world_session_state.players = players
	if str(skill.get("kind", "")) == "area_trade_contract":
		var contract_controller := _contract_runtime_controller(world)
		if contract_controller != null:
			var selection := contract_controller.selection_snapshot()
			contract_controller.set_selection_state(
				int(entry.get("contract_source_district", selection.get("source_district", -1))),
				int(entry.get("contract_target_district", selection.get("target_district", -1)))
			)
	skill["play_requirement_district"] = int(entry.get("play_requirement_district", -1))
	var valid := bool(world.call("_authorize_card_play", player_index, skill, true, "rule"))
	skill.erase("play_requirement_district")
	if not valid:
		var display_name := str(world.call("_card_display_name", str(skill.get("name", "卡牌"))))
		world.call("_log", "%s公开展示后未能满足结算条件；%s本次不生效。" % [display_name, "已离手的一次性牌不会返还，" if consumed_on_queue else "固定技能保留，"])
	return {"intent_type": "revalidate_requirement", "valid": valid, "reason": "valid" if valid else "requirement_invalid", "skill": skill}


func _target_receipt(world: Node, transaction: Dictionary) -> Dictionary:
	var entry: Dictionary = transaction.get("active_entry", {}) as Dictionary
	var skill: Dictionary = transaction.get("skill", {}) as Dictionary
	if _world_session_state == null:
		return {"intent_type": "revalidate_target", "valid": false, "reason": "world_session_state_missing"}
	var players: Array = _world_session_state.players
	var districts: Array = _world_session_state.districts
	var player_index := int(entry.get("player_index", -1))
	if player_index < 0 or player_index >= players.size() or skill.is_empty():
		return {"intent_type": "revalidate_target", "valid": false, "reason": "invalid_actor"}
	if _table_selection_state == null:
		return {"intent_type": "revalidate_target", "valid": false, "reason": "table_selection_state_missing"}
	_table_selection_state.set_active_context(
		player_index,
		clampi(int(entry.get("selected_district", _table_selection_state.selected_district)), 0, max(0, districts.size() - 1)),
		str(entry.get("selected_trade_product", _table_selection_state.selected_trade_product))
	)
	var card_label := str(world.call("_card_display_name", str(skill.get("name", ""))))
	if card_label == "":
		card_label = str(skill.get("name", "卡牌"))
	var requirement_variant: Variant = world.call("_card_play_requirement_snapshot", player_index, skill)
	var requirement: Dictionary = requirement_variant if requirement_variant is Dictionary else {}
	world.call("_log", "匿名卡牌结算：%s（%s）。" % [card_label, str(requirement.get("requirement_text", "条件：无"))])
	var monster_controller := _monster_runtime_controller(world)
	var focused_variant: Variant = monster_controller.call("selected_actor_snapshot", true) if monster_controller != null and monster_controller.has_method("selected_actor_snapshot") else {}
	var focused_actor: Dictionary = focused_variant if focused_variant is Dictionary else {}
	var effect_position: Vector2 = world.call("_entity_world_position", focused_actor) as Vector2 if not focused_actor.is_empty() else world.call("_district_center", _table_selection_state.selected_district) as Vector2
	var presentation_variant: Variant = world.call("_card_resolution_presentation_snapshot", skill, entry, -1.0, true)
	var presentation: Dictionary = presentation_variant if presentation_variant is Dictionary else {}
	world.call("_add_action_callout", "匿名卡牌", card_label, str(presentation.get("animation_text", "卡面公开，效果等待结算。")), Color("#fb7185"), effect_position)
	var target_kind := str(transaction.get("target_kind", "none"))
	var valid := true
	var reason := "valid"
	if target_kind == "monster":
		var monsters_variant: Variant = monster_controller.call("roster_snapshot", true) if monster_controller != null and monster_controller.has_method("roster_snapshot") else []
		var monsters: Array = monsters_variant if monsters_variant is Array else []
		var target_slot := int(entry.get("target_slot", -1))
		valid = target_slot >= 0 and target_slot < monsters.size() and not bool((monsters[target_slot] as Dictionary).get("down", false))
		if not valid:
			reason = "target_monster_invalid"
			world.call("_log", "%s的目标怪兽已失效；%s未产生效果。" % [card_label, "已离手的一次性牌" if bool(entry.get("consumed_on_queue", false)) else "固定技能"])
	elif target_kind == "player":
		var target_player := int(entry.get("target_player", -1))
		valid = target_player >= 0 and target_player < players.size() and target_player != player_index
		if not valid:
			reason = "target_player_invalid"
			world.call("_log", "%s的目标玩家已失效，本次未产生效果。" % card_label)
	return {"intent_type": "revalidate_target", "valid": valid, "reason": reason}


func _monster_runtime_controller(world: Node) -> Node:
	return world.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/MonsterRuntimeController")


func _aftermath_receipt(world: Node, transaction: Dictionary) -> Dictionary:
	var entry: Dictionary = (transaction.get("active_entry", {}) as Dictionary).duplicate(true)
	var skill: Dictionary = transaction.get("skill", {}) as Dictionary
	if bool(transaction.get("countered", false)):
		entry["countered"] = true
		entry["countered_by_resolution_id"] = int(transaction.get("counter_resolution_id", -1))
		entry["aftermath_clue"] = "被%s反制，未结算。" % str(world.call("_card_display_name", str(transaction.get("counter_card_name", "相位否决"))))
	elif not skill.is_empty():
		world.call("_add_card_resolution_aftermath_clue", entry, skill, bool(transaction.get("resolved", false)))
	return {"intent_type": "create_aftermath", "entry_patch": entry}


func _restore_context_receipt(world: Node, transaction: Dictionary) -> Dictionary:
	var context: Dictionary = transaction.get("selection_context", {}) as Dictionary
	if _world_session_state == null:
		return {"intent_type": "restore_context", "restored": false, "reason": "world_session_state_missing"}
	var players: Array = _world_session_state.players
	var districts: Array = _world_session_state.districts
	if _table_selection_state == null:
		return {"intent_type": "restore_context", "restored": false, "reason": "table_selection_state_missing"}
	_table_selection_state.set_active_context(
		clampi(int(context.get("selected_player", _table_selection_state.selected_player)), 0, max(0, players.size() - 1)),
		clampi(int(context.get("selected_district", _table_selection_state.selected_district)), 0, max(0, districts.size() - 1)),
		str(context.get("selected_trade_product", _table_selection_state.selected_trade_product))
	)
	var contract_controller := _contract_runtime_controller(world)
	if contract_controller != null:
		var selection := contract_controller.selection_snapshot()
		contract_controller.set_selection_state(
			int(context.get("contract_source_district", selection.get("source_district", -1))),
			int(context.get("contract_target_district", selection.get("target_district", -1)))
		)
	return {"intent_type": "restore_context", "restored": true}


func _contract_runtime_controller(world: Node) -> ContractRuntimeController:
	return world.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/ContractRuntimeController") as ContractRuntimeController
