@tool
extends Node
class_name CardIntelRuntimeService

var _world_session_state: WorldSessionState
var _table_selection_state: TableSelectionState
var _history_query: CardHistoryPublicQueryPort
var _annotation_service: CardHistoryPrivateAnnotationService
var _contract_controller: ContractRuntimeController


func set_dependencies(
	world_session_state: WorldSessionState,
	table_selection_state: TableSelectionState,
	history_query: CardHistoryPublicQueryPort,
	annotation_service: CardHistoryPrivateAnnotationService,
	contract_controller: ContractRuntimeController
) -> void:
	_world_session_state = world_session_state
	_table_selection_state = table_selection_state
	_history_query = history_query
	_annotation_service = annotation_service
	_contract_controller = contract_controller


func apply_intel_effect(player_index: int, skill: Dictionary, context: Dictionary = {}) -> Dictionary:
	if _world_session_state == null or _table_selection_state == null or player_index < 0 or player_index >= _world_session_state.players.size():
		return _receipt(false, "intel_context_missing")
	match str(skill.get("kind", "")):
		"intel_city_reveal":
			return _reveal_city_owners(player_index, maxi(1, int(skill.get("reveal_city_count", 1))), str(skill.get("name", "业主透镜")), int(context.get("selected_district", -1)))
		"card_history_public_review":
			return _review_public_history(player_index, skill, context)
		"card_history_subscription":
			return _subscribe_public_history(player_index, skill, context)
		"intel_contract_trace":
			var count := maxi(1, int(skill.get("trace_contract_count", 1)))
			var traced := _contract_controller.trace_contract_parties(player_index, int(context.get("selected_card_resolution_id", _table_selection_state.selected_card_resolution_id)), count, str(skill.get("name", "合约追溯"))) if _contract_controller != null else 0
			return _receipt(traced > 0, "resolved" if traced > 0 else "no_traceable_contract", {"contract_trace_count": traced})
	return _receipt(false, "intel_kind_unsupported")


func debug_snapshot() -> Dictionary:
	return {
		"service_ready": _world_session_state != null and _table_selection_state != null and _history_query != null and _annotation_service != null,
		"private_intel_authority": true,
		"public_owner_truth_exposed": false,
		"reads_hidden_actor": false,
		"economic_reward_count": 0,
	}


func _review_public_history(player_index: int, skill: Dictionary, context: Dictionary) -> Dictionary:
	if _history_query == null or _annotation_service == null:
		return _receipt(false, "history_services_unavailable")
	var targets := _history_targets(int(context.get("selected_card_resolution_id", _table_selection_state.selected_card_resolution_id)), maxi(1, int(skill.get("history_review_count", 1))))
	var public_players: Array = []
	for index in range(_world_session_state.players.size()):
		public_players.append(index)
	var reviewed := 0
	for history_entry_id_variant in targets:
		var result: Dictionary = _annotation_service.create_public_evidence_review(player_index, str(history_entry_id_variant), public_players)
		if bool(result.get("applied", false)):
			reviewed += 1
	return _receipt(reviewed > 0, "resolved" if reviewed > 0 else "no_public_history_target", {"history_review_count": reviewed})


func _subscribe_public_history(player_index: int, skill: Dictionary, context: Dictionary) -> Dictionary:
	if _history_query == null or _annotation_service == null:
		return _receipt(false, "history_services_unavailable")
	var targets := _history_targets(int(context.get("selected_card_resolution_id", _table_selection_state.selected_card_resolution_id)), clampi(int(skill.get("history_subscription_count", 1)), 1, 2))
	var result: Dictionary = _annotation_service.subscribe_entries(player_index, targets)
	return _receipt(bool(result.get("applied", false)), str(result.get("reason_code", "no_subscription_target")), {"history_subscription_count": (result.get("history_entry_ids", []) as Array).size()})


func _history_targets(selected_resolution_id: int, count: int) -> Array:
	var entries: Array = _history_query.compose_history().get("entries", []) if _history_query != null else []
	var result: Array[String] = []
	var selected_id := "card-history:%d" % selected_resolution_id if selected_resolution_id >= 0 else ""
	if not selected_id.is_empty():
		for entry_variant in entries:
			if entry_variant is Dictionary and str((entry_variant as Dictionary).get("history_entry_id", "")) == selected_id:
				result.append(selected_id)
				break
	for index in range(entries.size() - 1, -1, -1):
		if result.size() >= count:
			break
		if not (entries[index] is Dictionary):
			continue
		var entry_id := str((entries[index] as Dictionary).get("history_entry_id", ""))
		if not entry_id.is_empty() and not result.has(entry_id):
			result.append(entry_id)
	return result


func _reveal_city_owners(player_index: int, count: int, source: String, selected_district: int) -> Dictionary:
	var districts := _world_session_state.districts
	var order: Array = []
	if selected_district >= 0:
		order.append(selected_district)
	for district_index in range(districts.size()):
		if not order.has(district_index):
			order.append(district_index)
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
		var result := _world_session_state.apply_authorized_city_reveal(
			player_index,
			_world_session_state.region_id_for_district(district_index),
			owner_index,
			source
		)
		if bool(result.get("applied", false)):
			revealed += 1
	return _receipt(revealed > 0, "resolved" if revealed > 0 else "no_traceable_city", {"city_reveal_count": revealed})


func _receipt(resolved: bool, reason: String, extras: Dictionary = {}) -> Dictionary:
	var result := {"resolved": resolved, "reason": reason}
	result.merge(extras, true)
	return result
