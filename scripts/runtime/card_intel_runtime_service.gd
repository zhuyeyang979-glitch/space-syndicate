@tool
extends Node
class_name CardIntelRuntimeService

var _world_session_state: WorldSessionState
var _table_selection_state: TableSelectionState
var _history_service: CardResolutionHistoryRuntimeService
var _contract_controller: ContractRuntimeController


func set_dependencies(
	world_session_state: WorldSessionState,
	table_selection_state: TableSelectionState,
	history_service: CardResolutionHistoryRuntimeService,
	contract_controller: ContractRuntimeController
) -> void:
	_world_session_state = world_session_state
	_table_selection_state = table_selection_state
	_history_service = history_service
	_contract_controller = contract_controller


func apply_intel_effect(player_index: int, skill: Dictionary, context: Dictionary = {}) -> Dictionary:
	if _world_session_state == null or _table_selection_state == null or player_index < 0 or player_index >= _world_session_state.players.size():
		return _receipt(false, "intel_context_missing")
	match str(skill.get("kind", "")):
		"intel_city_reveal":
			return _reveal_city_owners(player_index, maxi(1, int(skill.get("reveal_city_count", 1))), str(skill.get("name", "业主透镜")), int(context.get("selected_district", -1)))
		"intel_card_trace":
			return _trace_cards_and_optional_clues(player_index, skill, context)
		"intel_contract_trace":
			var count := maxi(1, int(skill.get("trace_contract_count", 1)))
			var traced := _contract_controller.trace_contract_parties(player_index, int(context.get("selected_card_resolution_id", _table_selection_state.selected_card_resolution_id)), count, str(skill.get("name", "合约追溯"))) if _contract_controller != null else 0
			return _receipt(traced > 0, "resolved" if traced > 0 else "no_traceable_contract", {"contract_trace_count": traced})
	return _receipt(false, "intel_kind_unsupported")


func debug_snapshot() -> Dictionary:
	return {
		"service_ready": _world_session_state != null and _table_selection_state != null and _history_service != null,
		"private_intel_authority": true,
		"public_owner_truth_exposed": false,
	}


func _trace_cards_and_optional_clues(player_index: int, skill: Dictionary, context: Dictionary) -> Dictionary:
	var selected_resolution_id := int(context.get("selected_card_resolution_id", _table_selection_state.selected_card_resolution_id))
	var traced := _trace_card_owners(player_index, maxi(1, int(skill.get("trace_card_count", 1))), selected_resolution_id)
	var revealed := 0
	if int(skill.get("reveal_city_count", 0)) > 0:
		revealed = int(_reveal_city_owners(player_index, int(skill.get("reveal_city_count", 0)), str(skill.get("name", "线索悬赏")), int(context.get("selected_district", -1))).get("city_reveal_count", 0))
	var contract_traced := 0
	if int(skill.get("trace_contract_count", 0)) > 0 and _contract_controller != null:
		contract_traced = _contract_controller.trace_contract_parties(
			player_index,
			selected_resolution_id,
			int(skill.get("trace_contract_count", 0)),
			str(skill.get("name", "线索悬赏"))
		)
	return _receipt(traced + revealed + contract_traced > 0, "resolved" if traced + revealed + contract_traced > 0 else "no_traceable_intel", {
		"card_trace_count": traced,
		"city_reveal_count": revealed,
		"contract_trace_count": contract_traced,
	})


func _trace_card_owners(player_index: int, count: int, selected_id: int) -> int:
	if _history_service == null:
		return 0
	var history: Array = _history_service.history_snapshot()
	var candidates: Array = []
	for entry_variant in history:
		if not (entry_variant is Dictionary):
			continue
		var entry: Dictionary = entry_variant
		if selected_id >= 0 and int(entry.get("resolution_id", -1)) == selected_id:
			candidates.push_front(entry)
		else:
			candidates.append(entry)
	var player: Dictionary = _world_session_state.players[player_index]
	var known: Dictionary = player.get("known_card_owners", {}) if player.get("known_card_owners", {}) is Dictionary else {}
	var traced := 0
	for index in range(candidates.size() - 1, -1, -1):
		if traced >= count:
			break
		var entry: Dictionary = candidates[index]
		var resolution_id := int(entry.get("resolution_id", -1))
		var owner_index := int(entry.get("player_index", -1))
		if resolution_id < 0 or owner_index < 0 or owner_index == player_index or known.has(str(resolution_id)):
			continue
		known[str(resolution_id)] = owner_index
		traced += 1
	player["known_card_owners"] = known
	_world_session_state.players[player_index] = player
	return traced


func _reveal_city_owners(player_index: int, count: int, source: String, selected_district: int) -> Dictionary:
	var districts := _world_session_state.districts
	var order: Array = []
	if selected_district >= 0:
		order.append(selected_district)
	for district_index in range(districts.size()):
		if not order.has(district_index):
			order.append(district_index)
	var player: Dictionary = _world_session_state.players[player_index]
	var guesses: Dictionary = player.get("city_guesses", {}) if player.get("city_guesses", {}) is Dictionary else {}
	var reasons: Dictionary = player.get("city_guess_reasons", {}) if player.get("city_guess_reasons", {}) is Dictionary else {}
	var confidence: Dictionary = player.get("city_guess_confidence", {}) if player.get("city_guess_confidence", {}) is Dictionary else {}
	var revealed := 0
	for district_index_variant in order:
		if revealed >= count:
			break
		var district_index := int(district_index_variant)
		if district_index < 0 or district_index >= districts.size() or not (districts[district_index] is Dictionary):
			continue
		var city_variant: Variant = (districts[district_index] as Dictionary).get("city", {})
		var city: Dictionary = city_variant if city_variant is Dictionary else {}
		var owner_index := int(city.get("owner", -1))
		if city.is_empty() or not bool(city.get("active", true)) or owner_index < 0 or owner_index == player_index:
			continue
		guesses[district_index] = owner_index
		reasons[district_index] = source
		confidence[district_index] = 100
		revealed += 1
	player["city_guesses"] = guesses
	player["city_guess_reasons"] = reasons
	player["city_guess_confidence"] = confidence
	_world_session_state.players[player_index] = player
	return _receipt(revealed > 0, "resolved" if revealed > 0 else "no_traceable_city", {"city_reveal_count": revealed})


func _receipt(resolved: bool, reason: String, extras: Dictionary = {}) -> Dictionary:
	var result := {"resolved": resolved, "reason": reason}
	result.merge(extras, true)
	return result
