@tool
extends Node
class_name CardEffectRuntimeRouter

var _world_session_state: WorldSessionState
var _table_selection_state: TableSelectionState
var _monster_controller: MonsterRuntimeController
var _military_controller: MilitaryRuntimeController
var _weather_controller: WeatherRuntimeController
var _hand_interaction_service: PlayerHandInteractionRuntimeService
var _economy_service: CardEconomyProductRouteEffectRuntimeService
var _economy_port: CardEconomyProductRouteEffectWorldBridge
var _intel_service: CardIntelRuntimeService
var _runtime_coordinator: GameRuntimeCoordinator
var _presentation_port: CardResolutionPresentationPort


func set_dependencies(
	world_session_state: WorldSessionState,
	table_selection_state: TableSelectionState,
	monster_controller: MonsterRuntimeController,
	military_controller: MilitaryRuntimeController,
	weather_controller: WeatherRuntimeController,
	hand_interaction_service: PlayerHandInteractionRuntimeService,
	economy_service: CardEconomyProductRouteEffectRuntimeService,
	economy_port: CardEconomyProductRouteEffectWorldBridge,
	intel_service: CardIntelRuntimeService,
	presentation_port: CardResolutionPresentationPort,
	runtime_coordinator: GameRuntimeCoordinator
) -> void:
	_world_session_state = world_session_state
	_table_selection_state = table_selection_state
	_monster_controller = monster_controller
	_military_controller = military_controller
	_weather_controller = weather_controller
	_hand_interaction_service = hand_interaction_service
	_economy_service = economy_service
	_economy_port = economy_port
	_intel_service = intel_service
	_presentation_port = presentation_port
	_runtime_coordinator = runtime_coordinator


func dispatch(transaction: Dictionary) -> Dictionary:
	var entry: Dictionary = _dictionary(transaction.get("active_entry", {}))
	var skill: Dictionary = _dictionary(transaction.get("skill", {}))
	var player_index := int(entry.get("player_index", -1))
	var handler_id := str(transaction.get("handler_id", skill.get("kind", "")))
	var players := _world_session_state.players if _world_session_state != null else []
	if skill.is_empty():
		return _receipt(false, false, "effect_context_missing")
	if player_index < 0 or player_index >= players.size():
		return _receipt(false, false, "monster_card_actor_invalid" if handler_id == "monster_card" else "effect_context_missing")
	var player: Dictionary = players[player_index]
	var resolved := false
	var continuation_kind := "normal"
	if handler_id in ["global_order_budget", "global_supply_spawn"]:
		if _runtime_coordinator == null or not _runtime_coordinator.has_method("resolve_queued_v06_automatic_supply_demand"):
			return _receipt(true, false, "queued_supply_demand_runtime_unavailable")
		var v06_result_variant: Variant = _runtime_coordinator.call("resolve_queued_v06_automatic_supply_demand", entry.duplicate(true), skill.duplicate(true))
		var v06_result: Dictionary = v06_result_variant if v06_result_variant is Dictionary else {}
		resolved = bool(v06_result.get("resolved", false)) and bool(v06_result.get("committed", false)) and bool(v06_result.get("finalized", false))
		if not resolved:
			return _receipt(true, false, str(v06_result.get("reason_code", "queued_supply_demand_effect_failed")))
	elif handler_id == "target_monster":
		resolved = _resolve_targeted_skill(skill, player, _resolved_monster_target_slot(entry), player_index, int(entry.get("selected_district", -1)), entry)
	elif handler_id == "target_player":
		resolved = _resolve_player_interaction(player_index, int(entry.get("target_player", -1)), skill)
	else:
		var family_result := _dispatch_economy_family(handler_id, entry, skill)
		if bool(family_result.get("supported", false)):
			resolved = bool(family_result.get("resolved", false))
			continuation_kind = str(family_result.get("continuation_kind", "normal"))
		else:
			resolved = _dispatch_domain_handler(handler_id, player_index, player, entry, skill)
	if _monster_controller != null and _monster_controller.open_wager_decision_count() > int(transaction.get("monster_wager_decision_count_before", 0)):
		continuation_kind = "forced_decision_handoff"
	return _receipt(true, resolved, "resolved" if resolved else "effect_not_resolved", continuation_kind)


func supported_handler_ids() -> Array:
	return [
		"target_monster", "target_player", "monster_card", "public_facility",
		"monster_bound_action", "military_force", "military_command",
		"card_counter", "weather_control", "intel_city_reveal",
		"card_history_public_review", "card_history_subscription", "supply_draw",
		"global_order_budget", "global_supply_spawn",
	] + (_economy_service.supported_handlers() if _economy_service != null else [])


func supports_skill(skill: Dictionary) -> bool:
	var kind := str(skill.get("kind", ""))
	var machine: Dictionary = skill.get("machine", {}) if skill.get("machine", {}) is Dictionary else {}
	var machine_effect_kind := str(machine.get("effect_kind", ""))
	if supported_handler_ids().has(machine_effect_kind):
		return true
	if kind.is_empty():
		return false
	if kind in ["player_hand_disrupt", "player_hand_steal", "city_control_dispute", "global_barrage"]:
		return true
	return supported_handler_ids().has(kind)


func debug_snapshot() -> Dictionary:
	return {
		"router_ready": _world_session_state != null and _table_selection_state != null,
		"owns_effect_formulas": false,
		"supported_handler_count": supported_handler_ids().size(),
		"main_reference_present": false,
	}


func _dispatch_economy_family(handler_id: String, entry: Dictionary, skill: Dictionary) -> Dictionary:
	if _economy_service == null or not _economy_service.supports_handler(handler_id):
		return {"supported": false}
	var plan := _economy_service.plan_effect({
		"handler_id": handler_id,
		"active_entry": entry,
		"skill": skill,
	})
	if not bool(plan.get("supported", false)) or _economy_port == null:
		return {"supported": true, "resolved": false, "continuation_kind": "normal"}
	var receipt := _economy_port.apply_effect(plan)
	var result := _economy_service.finalize_effect(plan, receipt)
	result["supported"] = true
	return result


func _dispatch_domain_handler(handler_id: String, player_index: int, player: Dictionary, entry: Dictionary, skill: Dictionary) -> bool:
	match handler_id:
		"monster_card":
			return _monster_controller != null and _monster_controller._summon_monster_from_card(player_index, skill, int(entry.get("selected_district", -1)))
		"public_facility":
			if _runtime_coordinator == null:
				return false
			var resolution_id := int(entry.get("resolution_id", entry.get("queued_order", -1)))
			var result := _runtime_coordinator.submit_public_facility_card({
				"transaction_id": "card-resolution-%d-public-facility" % resolution_id if resolution_id >= 0 else "",
				"player_index": player_index,
				"target_region_index": int(skill.get("target_region_index", entry.get("selected_district", -1))),
				"occurred_at": _world_session_state.game_time,
				"skill": skill,
			})
			return bool(result.get("committed", false))
		"monster_bound_action":
			return _monster_controller != null and _monster_controller._trigger_bound_monster_skill(skill, player, int(entry.get("selected_district", -1)))
		"military_force":
			return _military_controller != null and _military_controller.summon_from_card(player_index, skill, int(entry.get("selected_district", -1)))
		"military_command":
			return _military_controller != null and _military_controller.trigger_command(skill, -1, player_index, {"resolution_id": int(entry.get("resolution_id", entry.get("queued_order", -1))), "selected_district": int(entry.get("selected_district", -1))})
		"card_counter":
			return false
		"weather_control":
			return _weather_controller != null and _weather_controller.apply_weather_control_at(skill, int(entry.get("selected_district", -1)))
		"intel_city_reveal", "card_history_public_review", "card_history_subscription":
			return _intel_service != null and bool(_intel_service.apply_intel_effect(player_index, skill, entry).get("resolved", false))
		"supply_draw":
			return false
	return false


func _resolve_targeted_skill(skill: Dictionary, player: Dictionary, target_slot: int, player_index: int, selected_district: int, entry: Dictionary = {}) -> bool:
	if str(skill.get("kind", "")) == "military_command":
		return _military_controller != null and _military_controller.trigger_command(skill, target_slot, player_index, {"resolution_id": int(entry.get("resolution_id", entry.get("queued_order", -1))), "selected_district": int(entry.get("selected_district", -1))})
	return _monster_controller != null and _monster_controller.resolve_targeted_skill(skill, player, target_slot, player_index, selected_district)


func _resolved_monster_target_slot(entry: Dictionary) -> int:
	var target_uid := int(entry.get("target_monster_uid", -1))
	if target_uid <= 0 or _monster_controller == null:
		return int(entry.get("target_slot", -1))
	var roster := _monster_controller.roster_snapshot(false)
	for index in range(roster.size()):
		if roster[index] is Dictionary and int((roster[index] as Dictionary).get("uid", -1)) == target_uid:
			return index
	return -1


func _resolve_player_interaction(player_index: int, target_player_index: int, skill: Dictionary) -> bool:
	if _hand_interaction_service == null or _world_session_state == null:
		return false
	var players := _world_session_state.players
	if target_player_index < 0 or target_player_index >= players.size() or target_player_index == player_index:
		return false
	var actor: Dictionary = players[player_index]
	var target: Dictionary = players[target_player_index]
	var catalog := _interaction_catalog(actor, target)
	var request := {
		"actor_player_index": player_index,
		"target_player_index": target_player_index,
		"skill": skill.duplicate(true),
		"actor_inventory": _interaction_inventory(actor, catalog),
		"target_inventory": _interaction_inventory(target, catalog),
		"card_catalog": catalog,
	}
	var plan := _hand_interaction_service.plan_interaction(request)
	if str(plan.get("status", "")) != "ready":
		return false
	var candidates: Array = plan.get("candidate_slots", []) if plan.get("candidate_slots", []) is Array else []
	var draw_count := mini(candidates.size(), int(plan.get("selection_draw_count", 0)))
	plan["selected_slots"] = candidates.slice(0, draw_count)
	var result := _hand_interaction_service.commit_interaction(actor, target, request, plan)
	if not bool(result.get("committed", false)):
		return false
	players[player_index] = actor
	players[target_player_index] = target
	_world_session_state.players = players
	_publish_interaction_events(skill, result)
	return bool(result.get("resolution_success", false))


func _publish_interaction_events(skill: Dictionary, result: Dictionary) -> void:
	if _presentation_port == null:
		return
	var event_index := 0
	for event_variant in result.get("public_event_intents", []):
		if not (event_variant is Dictionary):
			continue
		_presentation_port.publish_public_event({
			"event_id": "interaction:%s:%d:%d" % [str(skill.get("name", "card")), int(round(_world_session_state.game_time * 1000.0)), event_index],
			"event_kind": "player_interaction",
			"card_name": str(skill.get("name", "互动卡牌")),
			"status": "resolved",
			"summary": "目标玩家受到公开互动效果；手牌细节保持私密。",
		})
		event_index += 1


func _interaction_catalog(actor: Dictionary, target: Dictionary) -> Dictionary:
	var result := {}
	for player in [actor, target]:
		for card_variant in (player as Dictionary).get("slots", []):
			if not (card_variant is Dictionary):
				continue
			var card: Dictionary = card_variant
			var card_id := str(card.get("name", ""))
			if card_id.is_empty():
				continue
			result[card_id] = {
				"family": str(card.get("family_id", card_id)),
				"rank": maxi(1, int(card.get("rank", 1))),
				"counts_toward_hand_limit": not (bool(card.get("persistent", false)) and str(card.get("kind", "")) in ["monster_bound_action", "military_command"]),
				"next_upgrade_id": "",
				"next_upgrade_card": {},
			}
	return result


func _interaction_inventory(player: Dictionary, catalog: Dictionary) -> Dictionary:
	var slot_facts: Array = []
	var counted := 0
	var slots: Array = player.get("slots", []) if player.get("slots", []) is Array else []
	for slot_index in range(slots.size()):
		var card_variant: Variant = slots[slot_index]
		if not (card_variant is Dictionary):
			slot_facts.append({"slot_index": slot_index, "occupied": false})
			continue
		var card: Dictionary = card_variant
		var card_id := str(card.get("name", ""))
		var metadata: Dictionary = catalog.get(card_id, {}) if catalog.get(card_id, {}) is Dictionary else {}
		var counts := bool(metadata.get("counts_toward_hand_limit", true))
		if counts:
			counted += 1
		slot_facts.append({
			"slot_index": slot_index,
			"occupied": true,
			"card_id": card_id,
			"family": str(metadata.get("family", card_id)),
			"rank": maxi(1, int(metadata.get("rank", card.get("rank", 1)))),
			"counts_toward_hand_limit": counts,
			"queued_for_resolution": bool(card.get("queued_for_resolution", false)),
			"lock_left": float(card.get("lock_left", 0.0)),
			"next_upgrade_id": "",
			"next_upgrade_card": {},
		})
	return {"valid": false, "counted_hand_size": counted, "hand_limit": 5, "discard_slot": -1, "slots": slot_facts}


func _receipt(dispatched: bool, resolved: bool, reason: String, continuation_kind: String = "normal") -> Dictionary:
	return {
		"intent_type": "dispatch_effect",
		"dispatched": dispatched,
		"resolved": resolved,
		"reason": reason,
		"continuation_kind": continuation_kind,
	}


func _dictionary(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}
