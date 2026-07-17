@tool
extends Node
class_name CardPlayEligibilityWorldBridge

## Typed fact provider retained under its historical scene name so existing
## composition paths stay stable. It never stores or reflects the Main node.

var _table_selection_state: TableSelectionState
var _world_session_state: WorldSessionState
var _queue_service: CardResolutionQueueRuntimeService
var _resolution_controller: CardResolutionRuntimeController
var _target_choice_controller: CardTargetChoiceRuntimeController
var _monster_controller: MonsterRuntimeController
var _military_controller: MilitaryRuntimeController
var _contract_controller: ContractRuntimeController
var _session_controller: GameSessionRuntimeController
var _forced_decision_scheduler: ForcedDecisionRuntimeScheduler
var _commodity_flow_controller: CommodityFlowRuntimeController
var _build_count := 0


func set_table_selection_state(state: TableSelectionState) -> void:
	_table_selection_state = state


func set_world_session_state(state: WorldSessionState) -> void:
	_world_session_state = state


func set_runtime_dependencies(
	queue_service: CardResolutionQueueRuntimeService,
	resolution_controller: CardResolutionRuntimeController,
	target_choice_controller: CardTargetChoiceRuntimeController,
	monster_controller: MonsterRuntimeController,
	military_controller: MilitaryRuntimeController,
	contract_controller: ContractRuntimeController,
	session_controller: GameSessionRuntimeController,
	forced_decision_scheduler: ForcedDecisionRuntimeScheduler,
	commodity_flow_controller: CommodityFlowRuntimeController
) -> void:
	_queue_service = queue_service
	_resolution_controller = resolution_controller
	_target_choice_controller = target_choice_controller
	_monster_controller = monster_controller
	_military_controller = military_controller
	_contract_controller = contract_controller
	_session_controller = session_controller
	_forced_decision_scheduler = forced_decision_scheduler
	_commodity_flow_controller = commodity_flow_controller


func world_session_state() -> WorldSessionState:
	return _world_session_state


func table_selection_state() -> TableSelectionState:
	return _table_selection_state


func monster_roster_snapshot() -> Array:
	return _monster_controller.roster_snapshot(true) if _monster_controller != null else []


func build_facts(player_index: int, skill: Dictionary, context: Dictionary = {}) -> Dictionary:
	_build_count += 1
	if _world_session_state == null or _table_selection_state == null:
		return {"player_valid": false, "reason": "typed_state_missing"}
	var players := _world_session_state.players
	var districts := _world_session_state.districts
	var monsters := _monster_controller.roster_snapshot(true) if _monster_controller != null else []
	var player_valid := player_index >= 0 and player_index < players.size()
	var player: Dictionary = (players[player_index] as Dictionary).duplicate(true) if player_valid and players[player_index] is Dictionary else {}
	var selected_district := int(context.get("selected_district", _table_selection_state.selected_district))
	var selected_district_valid := selected_district >= 0 and selected_district < districts.size()
	var selected_district_data: Dictionary = (districts[selected_district] as Dictionary).duplicate(true) if selected_district_valid and districts[selected_district] is Dictionary else {}
	var active_entry := _queue_service.active_entry() if _queue_service != null else {}
	var active_skill: Dictionary = _dictionary(active_entry.get("skill", {}))
	var current_queue := _queue_service.current_queue() if _queue_service != null else []
	var next_queue := _queue_service.next_queue() if _queue_service != null else []
	var unit: Dictionary = {}
	if str(skill.get("kind", "")) == "military_command" and _military_controller != null:
		unit = _military_controller.active_unit_for_player(player_index, int(skill.get("bound_military_uid", 0)))
	var contract_selection := _contract_controller.selection_snapshot() if _contract_controller != null else {}
	var contract_context: Dictionary = {}
	if str(skill.get("kind", "")) == "area_trade_contract":
		contract_context = _contract_controller.offer_context(
			skill,
			player_index,
			int(context.get("contract_source_district", contract_selection.get("source_district", -1))),
			int(context.get("contract_target_district", contract_selection.get("target_district", -1))),
			str(context.get("selected_trade_product", _table_selection_state.selected_trade_product))
		) if _contract_controller != null else {"error": "合约运行时控制器不可用", "reason": "contract_controller_missing"}
	var share_by_district := _share_basis_points_by_district(player_index, districts) if player_valid else {}
	var runtime_state := _resolution_controller.card_play_fact_snapshot() if _resolution_controller != null else {}
	var batch_locked := bool(runtime_state.get("batch_locked", false))
	var simultaneous_timer := float(runtime_state.get("simultaneous_timer", 0.0))
	var queue_to_next_batch := batch_locked or not active_entry.is_empty() or (not current_queue.is_empty() and simultaneous_timer <= 0.0)
	var desired_bid_cash := maxi(0, int(player.get("queued_card_tip", 0))) if queue_to_next_batch else 0
	var pending_target_choice := _target_choice_controller != null and (
		_target_choice_controller.has_choice(CardTargetChoiceRuntimeController.KIND_MONSTER)
		or _target_choice_controller.has_choice(CardTargetChoiceRuntimeController.KIND_PLAYER)
	)
	var role: Dictionary = _dictionary(player.get("role_card", {}))
	var military_deployment_valid := true
	var military_terrain_label := "有效地形"
	if str(skill.get("kind", "")) == "military_force":
		military_deployment_valid = _military_controller != null and _military_controller.can_deploy_at_district(skill, selected_district)
		military_terrain_label = _military_controller.deploy_terrain_label(skill) if _military_controller != null else "有效地形"
	return {
		"player_valid": player_valid,
		"player_count": players.size(),
		"monster_count": monsters.size(),
		"player_name": str(player.get("name", "玩家%d" % (player_index + 1))) if player_valid else "玩家",
		"player_eliminated": bool(player.get("eliminated", false)) if player_valid else true,
		"player_cash": int(player.get("cash", 0)),
		"player_cash_cents": int(player.get("cash", 0)) * 100,
		"player_action_cooldown": float(player.get("action_cooldown", 0.0)),
		"game_over": _session_controller != null and _session_controller.is_finished(),
		"selected_district": selected_district,
		"selected_district_valid": selected_district_valid,
		"selected_district_destroyed": bool(selected_district_data.get("destroyed", false)),
		"selected_district_name": str(selected_district_data.get("name", "区域")),
		"contract_source_district": int(context.get("contract_source_district", contract_selection.get("source_district", -1))),
		"contract_share_discount_percent": int(role.get("contract_gdp_share_discount_percent", int(role.get("contract_flow_discount", 0)) * 5)),
		"best_share_district": _best_share_district(share_by_district),
		"share_basis_points_by_district": share_by_district,
		"pending_target_choice": pending_target_choice,
		"monster_wager_freeze": _monster_controller != null and not _monster_controller.active_wagers_snapshot().is_empty(),
		"forced_decision_pending": _forced_decision_scheduler != null and (
			_forced_decision_scheduler.blocks_global_time()
			or _forced_decision_scheduler.blocks_player_actions(player_index)
		),
		"role_can_convert_monster_to_counter": bool(role.get("monster_cards_as_counter", false)),
		"counter_window_active": bool(runtime_state.get("counter_window_active", false)),
		"active_resolution_present": not active_entry.is_empty(),
		"active_skill": active_skill,
		"active_skill_counterable": _counterable(active_skill),
		"contract_error": str(contract_context.get("error", "")),
		"contract_context": contract_context,
		"military_unit_present": not unit.is_empty(),
		"military_unit_cooldown": float(unit.get("cooldown_left", 0.0)),
		"military_deployment_valid": military_deployment_valid,
		"military_deploy_terrain_label": military_terrain_label,
		"desired_bid_cents": desired_bid_cash * 100,
		"queue_preflight": {
			"batch_locked": batch_locked,
			"active_present": not active_entry.is_empty(),
			"current_count": current_queue.size(),
			"next_count": next_queue.size(),
			"simultaneous_timer": simultaneous_timer,
			"routes_to_next_batch": queue_to_next_batch,
		},
		"default_monster_play_cash_per_existing": int(context.get("default_monster_play_cash_per_existing", 100)),
	}


func debug_snapshot() -> Dictionary:
	return {
		"bridge_ready": _world_session_state != null and _table_selection_state != null and _queue_service != null,
		"holds_world_reference": false,
		"build_count": _build_count,
		"fact_collection_authority": true,
		"eligibility_authority": false,
		"queue_authority": false,
		"execution_authority": false,
		"world_mutation_authority": false,
	}


func _share_basis_points_by_district(player_index: int, districts: Array) -> Dictionary:
	var result := {}
	for district_index in range(districts.size()):
		var district: Dictionary = districts[district_index] if districts[district_index] is Dictionary else {}
		var region_id := str(district.get("region_id", "region.%03d" % district_index))
		result[str(district_index)] = _commodity_flow_controller.player_region_gdp_share_basis_points(player_index, region_id) if _commodity_flow_controller != null else 0
	return result


func _best_share_district(share_by_district: Dictionary) -> int:
	var best_index := -1
	var best_share := 0
	for key_variant in share_by_district.keys():
		var district_index := int(str(key_variant))
		var share := int(share_by_district.get(key_variant, 0))
		if share > best_share or (share == best_share and share > 0 and (best_index < 0 or district_index < best_index)):
			best_index = district_index
			best_share = share
	return best_index


func _counterable(skill: Dictionary) -> bool:
	return ["player_hand_disrupt", "player_hand_steal", "city_control_dispute", "global_barrage"].has(str(skill.get("kind", ""))) and str(skill.get("kind", "")) != "card_counter"


func _dictionary(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}
