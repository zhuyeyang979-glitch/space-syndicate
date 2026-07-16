@tool
extends Node
class_name CardPlayEligibilityWorldBridge

var _world: Node = null
var _table_selection_state: TableSelectionState
var _world_session_state: WorldSessionState
var _build_count := 0


func bind_world(world: Node) -> void:
	_world = world


func set_table_selection_state(state: TableSelectionState) -> void:
	_table_selection_state = state


func set_world_session_state(state: WorldSessionState) -> void:
	_world_session_state = state


func world_session_state() -> WorldSessionState:
	return _world_session_state


func table_selection_state() -> TableSelectionState:
	return _table_selection_state


func build_facts(player_index: int, skill: Dictionary, context: Dictionary = {}) -> Dictionary:
	_build_count += 1
	if _world == null or not is_instance_valid(_world):
		return {"player_valid": false, "reason": "world_missing"}
	var players: Array = _array_property("players")
	var districts: Array = _array_property("districts")
	var monsters: Array = _array_property("auto_monsters")
	var player_valid := player_index >= 0 and player_index < players.size()
	var player: Dictionary = (players[player_index] as Dictionary).duplicate(true) if player_valid and players[player_index] is Dictionary else {}
	var selected_district := int(context.get(
		"selected_district",
		_table_selection_state.selected_district if _table_selection_state != null else -1
	))
	var selected_district_valid := selected_district >= 0 and selected_district < districts.size()
	var selected_district_data: Dictionary = (districts[selected_district] as Dictionary).duplicate(true) if selected_district_valid and districts[selected_district] is Dictionary else {}
	var active_entry := _world_dictionary_call(&"_card_resolution_active_entry")
	var active_skill := _dictionary(active_entry.get("skill", {}))
	var military_controller := _military_runtime_controller()
	var unit: Dictionary = {}
	if str(skill.get("kind", "")) == "military_command":
		unit = military_controller.active_unit_for_player(player_index, int(skill.get("bound_military_uid", 0))) if military_controller != null else {}
	var contract_context: Dictionary = {}
	var contract_selection: Dictionary = {}
	var contract_controller := _contract_runtime_controller()
	if contract_controller != null:
		contract_selection = contract_controller.selection_snapshot()
	if str(skill.get("kind", "")) == "area_trade_contract":
		contract_context = contract_controller.offer_context(
			skill,
			player_index,
			int(context.get("contract_source_district", contract_selection.get("source_district", -1))),
			int(context.get("contract_target_district", contract_selection.get("target_district", -1))),
			str(context.get(
				"selected_trade_product",
				_table_selection_state.selected_trade_product if _table_selection_state != null else ""
			))
		) if contract_controller != null else {"error": "合约运行时控制器不可用", "reason": "contract_controller_missing"}
	var role: Dictionary = _world_dictionary_call(&"_player_role_card_for_index", [player_index]) if player_valid else {}
	var share_by_district := {}
	for district_index in range(districts.size()):
		share_by_district[str(district_index)] = int(_world.call("_player_region_gdp_share_basis_points", player_index, district_index)) if player_valid and _world.has_method("_player_region_gdp_share_basis_points") else 0
	var current_queue := _world_array_call(&"_card_resolution_current_queue")
	var next_queue := _world_array_call(&"_card_resolution_next_queue")
	var queue_to_next_batch := bool(_world.get("card_resolution_batch_locked")) \
		or not active_entry.is_empty() \
		or (not current_queue.is_empty() and float(_world.get("card_resolution_simultaneous_timer")) <= 0.0)
	var desired_bid_cash := 0
	if queue_to_next_batch:
		desired_bid_cash = maxi(0, int(player.get("queued_card_tip", 0)))
	elif player_valid and _world.has_method("_selected_card_priority_bid_amount"):
		desired_bid_cash = int(_world.call("_selected_card_priority_bid_amount", player_index))
	var pending_target_choice := false
	if _world.has_method("_has_pending_target_choice"):
		pending_target_choice = bool(_world.call("_has_pending_target_choice"))
	if _world.has_method("_has_pending_player_target_choice"):
		pending_target_choice = pending_target_choice or bool(_world.call("_has_pending_player_target_choice"))
	var military_deployment_valid := true
	var military_terrain_label := "有效地形"
	if str(skill.get("kind", "")) == "military_force":
		military_deployment_valid = military_controller.can_deploy_at_district(skill, selected_district) if military_controller != null else false
		military_terrain_label = military_controller.deploy_terrain_label(skill) if military_controller != null else "有效地形"
	return {
		"player_valid": player_valid,
		"player_count": players.size(),
		"monster_count": monsters.size(),
		"player_name": str(_world.call("_player_name", player_index)) if player_valid and _world.has_method("_player_name") else "玩家",
		"player_eliminated": bool(_world.call("_player_is_eliminated", player_index)) if player_valid and _world.has_method("_player_is_eliminated") else false,
		"player_cash": int(player.get("cash", 0)),
		"player_cash_cents": int(player.get("cash", 0)) * 100,
		"player_action_cooldown": float(player.get("action_cooldown", 0.0)),
		"game_over": bool(_world.call("_runtime_session_finished")) if _world.has_method("_runtime_session_finished") else false,
		"selected_district": selected_district,
		"selected_district_valid": selected_district_valid,
		"selected_district_destroyed": bool(selected_district_data.get("destroyed", false)),
		"selected_district_name": str(selected_district_data.get("name", "区域")),
		"contract_source_district": int(context.get("contract_source_district", contract_selection.get("source_district", -1))),
		"contract_share_discount_percent": int(role.get("contract_gdp_share_discount_percent", int(role.get("contract_flow_discount", 0)) * 5)),
		"best_share_district": int(_world.call("_best_player_gdp_share_district", player_index)) if player_valid and _world.has_method("_best_player_gdp_share_district") else -1,
		"share_basis_points_by_district": share_by_district,
		"pending_target_choice": pending_target_choice,
		"monster_wager_freeze": bool(_world.call("_monster_wager_freezes_game")) if _world.has_method("_monster_wager_freezes_game") else false,
		"forced_decision_pending": bool(_world.call("_has_pending_blocking_decision")) if _world.has_method("_has_pending_blocking_decision") else false,
		"role_can_convert_monster_to_counter": bool(_world.call("_role_can_use_monster_card_as_counter", player_index)) if player_valid and _world.has_method("_role_can_use_monster_card_as_counter") else false,
		"counter_window_active": bool(_world.get("card_resolution_counter_window_active")),
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
			"batch_locked": bool(_world.get("card_resolution_batch_locked")),
			"active_present": not active_entry.is_empty(),
			"current_count": current_queue.size(),
			"next_count": next_queue.size(),
			"simultaneous_timer": float(_world.get("card_resolution_simultaneous_timer")),
			"routes_to_next_batch": queue_to_next_batch,
		},
		"default_monster_play_cash_per_existing": int(context.get("default_monster_play_cash_per_existing", 100)),
	}


func debug_snapshot() -> Dictionary:
	return {
		"bridge_ready": _world != null and is_instance_valid(_world),
		"build_count": _build_count,
		"fact_collection_authority": true,
		"eligibility_authority": false,
		"queue_authority": false,
		"execution_authority": false,
		"world_mutation_authority": false,
	}


func _counterable(skill: Dictionary) -> bool:
	return ["player_hand_disrupt", "player_hand_steal", "city_control_dispute", "global_barrage"].has(str(skill.get("kind", ""))) and str(skill.get("kind", "")) != "card_counter"


func _array_property(property_name: StringName) -> Array:
	if _world_session_state != null:
		match property_name:
			&"players":
				return _world_session_state.players.duplicate(true)
			&"districts":
				return _world_session_state.districts.duplicate(true)
	var value: Variant = _world.get(property_name)
	return (value as Array).duplicate(true) if value is Array else []


func _world_dictionary_call(method_name: StringName, arguments: Array = []) -> Dictionary:
	if _world == null or not _world.has_method(method_name):
		return {}
	var value: Variant = _world.callv(method_name, arguments)
	return _dictionary(value)


func _world_array_call(method_name: StringName, arguments: Array = []) -> Array:
	if _world == null or not _world.has_method(method_name):
		return []
	var value: Variant = _world.callv(method_name, arguments)
	return (value as Array).duplicate(true) if value is Array else []


func _dictionary(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _military_runtime_controller() -> MilitaryRuntimeController:
	if _world == null or not is_instance_valid(_world):
		return null
	var coordinator := _world.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator")
	return coordinator.get_node_or_null("MilitaryRuntimeController") as MilitaryRuntimeController if coordinator != null else null


func _contract_runtime_controller() -> ContractRuntimeController:
	if _world == null or not is_instance_valid(_world):
		return null
	var coordinator := _world.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator")
	return coordinator.get_node_or_null("ContractRuntimeController") as ContractRuntimeController if coordinator != null else null
