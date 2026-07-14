@tool
extends Node
class_name FinalSettlementRuntimeComposition

signal action_requested(action_id: String)
signal menu_open_requested(title: String, summary: String, can_continue: bool)
signal public_log_entry_requested(text: String)

const COMPOSITION_ID := "final_settlement_runtime_composition_v06"
const FORBIDDEN_CONTEXT_KEYS := [
	"players",
	"raw_players",
	"internal_receipt",
	"private_hand",
	"opponent_hand",
	"ai_plan",
]

@export var menu_overlay_path: NodePath
@export var snapshot_service_path: NodePath

@onready var _source_adapter: Node = $FinalSettlementPublicSourceAdapter
@onready var _board: Control = $FinalSettlementBoardPanel

var _last_public_snapshot: Dictionary = {}
var _last_public_summary := ""
var _logged_outcome_ids := {}
var _present_count := 0
var _action_emission_count := 0


func present(public_context: Dictionary) -> Dictionary:
	var overlay := _menu_overlay()
	if overlay == null:
		return _rejected("composition_dependency_missing")
	if not overlay.has_method("get_preview_host"):
		return _rejected("composition_dependency_api_missing")
	var facts := _facts_from_public_context(public_context)
	var source := compose_public_source(public_context)
	if not bool(source.get("valid", false)):
		return _rejected(str(source.get("reason", "public_source_invalid")))
	var snapshot := compose_public_snapshot(public_context)
	if not snapshot.get("board", {}) is Dictionary or str(snapshot.get("summary_text", "")).strip_edges().is_empty():
		return _rejected("public_snapshot_invalid")
	var preview_host := overlay.call("get_preview_host") as Container
	if preview_host == null:
		return _rejected("menu_preview_host_missing")
	var long_summary := str(_source_adapter.call("compose_public_summary", facts)) if _source_adapter.has_method("compose_public_summary") else str(snapshot.get("summary_text", ""))
	var log_payload := _public_log_payload(public_context)
	_park_board()
	menu_open_requested.emit("终局结算", str(snapshot.get("summary_text", "游戏结束。")), false)
	_attach_board(preview_host, snapshot.get("board", {}) as Dictionary)
	_emit_public_log_once(log_payload)
	_last_public_snapshot = snapshot.duplicate(true)
	_last_public_summary = long_summary
	_present_count += 1
	var board_generation := _present_count
	if _board.has_method("debug_snapshot"):
		var board_debug_variant: Variant = _board.call("debug_snapshot")
		if board_debug_variant is Dictionary:
			board_generation = int((board_debug_variant as Dictionary).get("generation", board_generation))
	return {
		"accepted": true,
		"reason": "",
		"outcome_id": str((source.get("outcome_receipt", {}) as Dictionary).get("outcome_id", "")),
		"present_count": _present_count,
		"board_generation": board_generation,
		"public_snapshot": snapshot.duplicate(true),
	}


func compose_public_source(public_context: Dictionary) -> Dictionary:
	if not _is_pure_data(public_context) or _contains_forbidden_context_key(public_context):
		return {"valid": false, "reason": "public_context_not_allowlisted"}
	if _source_adapter == null or not _source_adapter.has_method("compose_public_source"):
		return {"valid": false, "reason": "public_source_adapter_unavailable"}
	var source_variant: Variant = _source_adapter.call("compose_public_source", _facts_from_public_context(public_context))
	return (source_variant as Dictionary).duplicate(true) if source_variant is Dictionary else {"valid": false, "reason": "public_source_invalid"}


func compose_public_snapshot(public_context: Dictionary) -> Dictionary:
	var service := _snapshot_service()
	if service == null or not service.has_method("compose"):
		return {}
	var source := compose_public_source(public_context)
	if not bool(source.get("valid", false)):
		return {}
	var snapshot_variant: Variant = service.call("compose", source)
	return (snapshot_variant as Dictionary).duplicate(true) if snapshot_variant is Dictionary else {}


func latest_public_summary() -> String:
	return _last_public_summary


func last_public_snapshot() -> Dictionary:
	return _last_public_snapshot.duplicate(true)


func sanitize_public_log_entries(entries: Array) -> Array:
	if _source_adapter == null or not _source_adapter.has_method("sanitize_public_log_entries"):
		return []
	var sanitized_variant: Variant = _source_adapter.call("sanitize_public_log_entries", entries)
	return (sanitized_variant as Array).duplicate(true) if sanitized_variant is Array else []


func board_node() -> Control:
	return _board


func debug_snapshot() -> Dictionary:
	return {
		"composition_id": COMPOSITION_ID,
		"present_count": _present_count,
		"action_emission_count": _action_emission_count,
		"logged_outcome_count": _logged_outcome_ids.size(),
		"source_adapter_ready": _source_adapter != null,
		"snapshot_service_ready": _snapshot_service() != null,
		"menu_overlay_ready": _menu_overlay() != null,
		"board_ready": _board != null,
		"owns_victory_rules": false,
		"owns_cash": false,
		"reads_raw_players": false,
		"reads_internal_receipt": false,
		"pure_data_snapshots": true,
	}


func _facts_from_public_context(public_context: Dictionary) -> Dictionary:
	var victory_public := _dictionary(public_context.get("victory_public_snapshot", {}))
	var receipt := _dictionary(victory_public.get("outcome_receipt", {}))
	var participant_names := _dictionary(public_context.get("participant_names", {}))
	var participant_public_facts: Array = []
	for ranking_variant in _array(receipt.get("rankings", [])):
		var ranking := _dictionary(ranking_variant)
		var player_index := int(ranking.get("player_index", -1))
		if player_index < 0:
			continue
		participant_public_facts.append({
			"player_index": player_index,
			"name": str(participant_names.get(str(player_index), "玩家%d" % (player_index + 1))),
			"active_cities": 0,
			"gdp_per_minute": int(ranking.get("top_n_gdp_per_minute", ranking.get("top_k_gdp_per_minute", 0))),
			"city_income": 0,
			"card_income": 0,
			"role_income": 0,
			"card_spend": 0,
			"build_spend": 0,
			"business_spend": 0,
			"identity": "公开终局审计席位",
			"eliminated": false,
		})
	var victory_rule := _dictionary(victory_public.get("victory_rule", {}))
	var facts := {
		"victory_public_snapshot": victory_public,
		"participant_public_facts": participant_public_facts,
		"required_top_n_gdp_per_minute": int(victory_rule.get("required_top_k_gdp_per_minute", 0)),
		"required_controlled_region_count": int(victory_rule.get("required_region_count", 0)),
		"map_facts": _public_map_facts(_dictionary(public_context.get("public_map_facts", {}))),
		"resolved_card_count": int(public_context.get("resolved_card_count", 0)),
		"kpi_columns": 4,
		"money_columns": 4,
		"rank_columns": 4,
	}
	var reason := str(public_context.get("reason", "")).strip_edges()
	if not reason.is_empty():
		facts["reason"] = reason
	return facts


func _public_log_payload(public_context: Dictionary) -> Dictionary:
	if not _source_adapter.has_method("public_outcome_log_payload"):
		return {}
	var value: Variant = _source_adapter.call(
		"public_outcome_log_payload",
		_dictionary(public_context.get("victory_public_snapshot", {})),
		_dictionary(public_context.get("participant_names", {})),
	)
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _attach_board(preview_host: Container, board_snapshot: Dictionary) -> void:
	for child in preview_host.get_children():
		if child == _board:
			continue
		preview_host.remove_child(child)
		child.queue_free()
	if _board.get_parent() != preview_host:
		_board.reparent(preview_host)
	preview_host.visible = true
	_board.visible = true
	_board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_board.call("set_board", board_snapshot)


func _park_board() -> void:
	if _board != null and _board.get_parent() != self:
		_board.reparent(self)


func _emit_public_log_once(log_payload: Dictionary) -> void:
	if not bool(log_payload.get("accepted", false)):
		return
	var outcome_id := str(log_payload.get("outcome_id", "")).strip_edges()
	if outcome_id.is_empty() or _logged_outcome_ids.has(outcome_id):
		return
	_logged_outcome_ids[outcome_id] = true
	for entry_variant in _array(log_payload.get("entries", [])):
		public_log_entry_requested.emit(str(entry_variant))


func _on_board_action_requested(action_id: String) -> void:
	var routed_action := "setup" if action_id == "new_run" else action_id
	if not ["standings", "economy", "setup"].has(routed_action):
		return
	_action_emission_count += 1
	action_requested.emit(routed_action)


func _snapshot_service() -> Node:
	return get_node_or_null(snapshot_service_path) if not snapshot_service_path.is_empty() else null


func _menu_overlay() -> Node:
	return get_node_or_null(menu_overlay_path) if not menu_overlay_path.is_empty() else null


func _public_map_facts(source: Dictionary) -> Dictionary:
	return {
		"active_city_count": int(source.get("active_city_count", 0)),
		"destroyed_district_count": int(source.get("destroyed_district_count", 0)),
		"active_monster_count": int(source.get("active_monster_count", 0)),
		"monster_count": int(source.get("monster_count", 0)),
		"key_city": _dictionary(source.get("key_city", {})),
	}


func _contains_forbidden_context_key(value: Variant) -> bool:
	if value is Dictionary:
		for key_variant in value.keys():
			if FORBIDDEN_CONTEXT_KEYS.has(str(key_variant).to_lower()) or _contains_forbidden_context_key(value[key_variant]):
				return true
	elif value is Array:
		for child_variant in value:
			if _contains_forbidden_context_key(child_variant):
				return true
	return false


func _rejected(reason: String) -> Dictionary:
	return {"accepted": false, "reason": reason, "present_count": _present_count}


func _dictionary(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _array(value: Variant) -> Array:
	return (value as Array).duplicate(true) if value is Array else []


func _is_pure_data(value: Variant) -> bool:
	if value is Object or value is Callable:
		return false
	if value is Dictionary:
		for key_variant in value.keys():
			if not _is_pure_data(key_variant) or not _is_pure_data(value[key_variant]):
				return false
	elif value is Array:
		for child_variant in value:
			if not _is_pure_data(child_variant):
				return false
	return true
