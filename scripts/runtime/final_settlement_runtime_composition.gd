@tool
extends Node
class_name FinalSettlementRuntimeComposition

signal action_requested(action_id: StringName)
signal menu_open_requested(title: String, summary: String, can_continue: bool)
signal public_log_receipt_requested(receipt: PublicLogReceipt, acknowledgement: Dictionary)
signal victory_presentation_result_ready(result: Dictionary)

const COMPOSITION_ID := "final_settlement_runtime_composition_v06"
const FORBIDDEN_CONTEXT_KEYS := [
	"players",
	"raw_players",
	"internal_receipt",
	"private_hand",
	"opponent_hand",
	"ai_plan",
]
const PUBLIC_LOG_ACK_KEYS := [
	"schema_version",
	"receipt_id",
	"outcome_id",
	"receipt_fingerprint",
	"accepted",
	"duplicate",
	"reason_id",
]
const SESSION_RESET_REASON_IDS := ["session_began", "session_reset"]
const SESSION_PLAN_APPLIED_REASON_ID := "session_plan_applied"
const SESSION_CHECKPOINT_ROLLED_BACK_REASON_ID := "session_checkpoint_rolled_back"
const SESSION_SAVE_APPLIED_REASON_ID := "session_save_applied"
const SESSION_LOAD_COMPLETED_REASON_ID := "session_load_completed"

@export var menu_overlay_path: NodePath
@export var snapshot_service_path: NodePath

@onready var _source_adapter: Node = $FinalSettlementPublicSourceAdapter
@onready var _board: Control = $FinalSettlementBoardPanel

var _last_public_snapshot: Dictionary = {}
var _last_public_summary := ""
var _logged_outcome_ids := {}
var _presented_outcome_bindings := {}
var _last_presented_outcome_id := ""
var _present_count := 0
var _action_emission_count := 0
var _session_plan_checkpoint: Dictionary = {}
var _session_checkpoint_epoch := 0
var _session_checkpoint_kind := ""


func present_victory_receipt(receipt: VictoryPresentationStateChangeReceipt) -> Dictionary:
	if receipt == null or not receipt.is_valid():
		return _rejected("victory_presentation_receipt_invalid")
	var public_context := receipt.public_context()
	public_context["source_revision"] = receipt.revision
	public_context["world_time"] = receipt.world_time
	var result := present(public_context)
	victory_presentation_result_ready.emit({
		"schema_version": 1,
		"receipt_id": receipt.receipt_id,
		"accepted": bool(result.get("accepted", false)),
		"duplicate": bool(result.get("duplicate", false)),
		"reason_id": str(result.get("reason", "")),
		"outcome_id": str(result.get("outcome_id", "")),
	})
	return result


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
	var outcome: Dictionary = source.get("outcome_receipt", {}) if source.get("outcome_receipt", {}) is Dictionary else {}
	var outcome_id := str(outcome.get("outcome_id", "")).strip_edges()
	if outcome_id.is_empty():
		return _rejected("victory_outcome_id_missing")
	var outcome_binding := _public_source_fingerprint(source)
	if _presented_outcome_bindings.has(outcome_id):
		if str(_presented_outcome_bindings.get(outcome_id, "")) != outcome_binding:
			return _rejected("victory_outcome_binding_collision")
		return {
			"accepted": true,
			"duplicate": true,
			"reason": "victory_outcome_already_presented",
			"outcome_id": outcome_id,
			"present_count": _present_count,
			"board_generation": _board_generation(),
			"public_snapshot": _last_public_snapshot.duplicate(true),
		}
	var snapshot := compose_public_snapshot(public_context)
	if not snapshot.get("board", {}) is Dictionary or str(snapshot.get("summary_text", "")).strip_edges().is_empty():
		return _rejected("public_snapshot_invalid")
	var preview_host := overlay.call("get_preview_host") as Container
	if preview_host == null:
		return _rejected("menu_preview_host_missing")
	var long_summary := str(_source_adapter.call("compose_public_summary", facts)) if _source_adapter.has_method("compose_public_summary") else str(snapshot.get("summary_text", ""))
	var log_payload := _public_log_payload(public_context)
	var log_acknowledgement := _acknowledge_public_log_once(log_payload, public_context)
	if not bool(log_acknowledgement.get("accepted", false)):
		return _rejected(str(log_acknowledgement.get("reason_id", "final_settlement_public_log_rejected")))
	_park_board()
	menu_open_requested.emit("终局结算", str(snapshot.get("summary_text", "游戏结束。")), false)
	_attach_board(preview_host, snapshot.get("board", {}) as Dictionary)
	_last_public_snapshot = snapshot.duplicate(true)
	_last_public_summary = long_summary
	_present_count += 1
	_presented_outcome_bindings[outcome_id] = outcome_binding
	_last_presented_outcome_id = outcome_id
	var board_generation := _board_generation()
	return {
		"accepted": true,
		"duplicate": false,
		"reason": "",
		"outcome_id": outcome_id,
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


func reset_state() -> void:
	_discard_session_plan_checkpoint()
	_reset_presentation_state()


func _reset_presentation_state() -> void:
	_last_public_snapshot.clear()
	_last_public_summary = ""
	_logged_outcome_ids.clear()
	_presented_outcome_bindings.clear()
	_last_presented_outcome_id = ""
	_present_count = 0
	_action_emission_count = 0
	_park_board()
	if _board != null:
		_board.visible = false


func _on_session_authorization_context_changed(reason_id: String) -> void:
	if reason_id == SESSION_PLAN_APPLIED_REASON_ID:
		_begin_session_checkpoint(SESSION_PLAN_APPLIED_REASON_ID)
	elif reason_id == SESSION_CHECKPOINT_ROLLED_BACK_REASON_ID:
		_restore_session_checkpoint(SESSION_PLAN_APPLIED_REASON_ID)
	elif reason_id == SESSION_SAVE_APPLIED_REASON_ID:
		if _session_checkpoint_kind == SESSION_SAVE_APPLIED_REASON_ID:
			_restore_session_checkpoint(SESSION_SAVE_APPLIED_REASON_ID)
		else:
			_begin_session_checkpoint(SESSION_SAVE_APPLIED_REASON_ID)
	elif reason_id == SESSION_LOAD_COMPLETED_REASON_ID:
		_discard_session_plan_checkpoint()
		_reset_presentation_state()
	elif SESSION_RESET_REASON_IDS.has(reason_id):
		reset_state()


func debug_snapshot() -> Dictionary:
	return {
		"composition_id": COMPOSITION_ID,
		"present_count": _present_count,
		"presented_outcome_count": _presented_outcome_bindings.size(),
		"last_presented_outcome_id": _last_presented_outcome_id,
		"last_public_snapshot_fingerprint": _public_source_fingerprint(_last_public_snapshot),
		"action_emission_count": _action_emission_count,
		"logged_outcome_count": _logged_outcome_ids.size(),
		"session_plan_checkpoint_pending": not _session_plan_checkpoint.is_empty(),
		"lifecycle_checkpoint_pending": not _session_plan_checkpoint.is_empty(),
		"lifecycle_transition_kind": _session_checkpoint_kind,
		"session_lifecycle_checkpoint_kind": _session_checkpoint_kind,
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


func _begin_session_checkpoint(checkpoint_kind: String) -> void:
	_session_checkpoint_epoch += 1
	var checkpoint_epoch := _session_checkpoint_epoch
	_session_plan_checkpoint = {
		"schema_version": 1,
		"last_public_snapshot": _last_public_snapshot.duplicate(true),
		"last_public_summary": _last_public_summary,
		"logged_outcome_ids": _logged_outcome_ids.duplicate(true),
		"presented_outcome_bindings": _presented_outcome_bindings.duplicate(true),
		"last_presented_outcome_id": _last_presented_outcome_id,
		"present_count": _present_count,
		"action_emission_count": _action_emission_count,
		"board_attached": _board != null and _board.get_parent() != self,
		"board_visible": _board != null and _board.visible,
	}
	_session_checkpoint_kind = checkpoint_kind
	_reset_presentation_state()
	call_deferred("_finalize_session_plan_checkpoint", checkpoint_epoch)


func _restore_session_checkpoint(expected_kind: String) -> void:
	if _session_plan_checkpoint.is_empty() or _session_checkpoint_kind != expected_kind:
		return
	var checkpoint := _session_plan_checkpoint.duplicate(true)
	_discard_session_plan_checkpoint()
	_last_public_snapshot = (checkpoint.get("last_public_snapshot", {}) as Dictionary).duplicate(true)
	_last_public_summary = str(checkpoint.get("last_public_summary", ""))
	_logged_outcome_ids = (checkpoint.get("logged_outcome_ids", {}) as Dictionary).duplicate(true)
	_presented_outcome_bindings = (checkpoint.get("presented_outcome_bindings", {}) as Dictionary).duplicate(true)
	_last_presented_outcome_id = str(checkpoint.get("last_presented_outcome_id", ""))
	_present_count = int(checkpoint.get("present_count", 0))
	_action_emission_count = int(checkpoint.get("action_emission_count", 0))
	_restore_checkpointed_board(
		bool(checkpoint.get("board_attached", false)),
		bool(checkpoint.get("board_visible", false))
	)


func _restore_checkpointed_board(was_attached: bool, was_visible: bool) -> void:
	if _board == null:
		return
	var board_snapshot: Dictionary = _last_public_snapshot.get("board", {}) \
		if _last_public_snapshot.get("board", {}) is Dictionary else {}
	if was_attached:
		var overlay := _menu_overlay()
		var preview_host := overlay.call("get_preview_host") as Container \
			if overlay != null and overlay.has_method("get_preview_host") else null
		if preview_host != null:
			_attach_board(preview_host, board_snapshot)
		else:
			_park_board()
	elif not board_snapshot.is_empty() and _board.has_method("set_board"):
		_board.call("set_board", board_snapshot)
	_board.visible = was_visible


func _finalize_session_plan_checkpoint(checkpoint_epoch: int) -> void:
	if checkpoint_epoch == _session_checkpoint_epoch:
		_session_plan_checkpoint.clear()
		_session_checkpoint_kind = ""


func _discard_session_plan_checkpoint() -> void:
	_session_checkpoint_epoch += 1
	_session_plan_checkpoint.clear()
	_session_checkpoint_kind = ""


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


func _board_generation() -> int:
	var generation := _present_count
	if _board != null and _board.has_method("debug_snapshot"):
		var board_debug_variant: Variant = _board.call("debug_snapshot")
		if board_debug_variant is Dictionary:
			generation = int((board_debug_variant as Dictionary).get("generation", generation))
	return generation


func _acknowledge_public_log_once(log_payload: Dictionary, public_context: Dictionary = {}) -> Dictionary:
	if not bool(log_payload.get("accepted", false)):
		return _public_log_rejected("final_settlement_public_log_payload_invalid")
	var outcome_id := str(log_payload.get("outcome_id", "")).strip_edges()
	if outcome_id.is_empty():
		return _public_log_rejected("final_settlement_public_log_outcome_id_missing")
	var victory_public := _dictionary(public_context.get("victory_public_snapshot", {}))
	var outcome := _dictionary(victory_public.get("outcome_receipt", {}))
	if str(outcome.get("outcome_id", "")).strip_edges() != outcome_id:
		return _public_log_rejected("final_settlement_public_log_outcome_mismatch")
	var winner_player_indices: Array = []
	for player_index_variant in _array(outcome.get("winner_player_indices", [])):
		if typeof(player_index_variant) != TYPE_INT or int(player_index_variant) < 0 \
				or winner_player_indices.has(int(player_index_variant)):
			return _public_log_rejected("final_settlement_public_log_winners_invalid")
		winner_player_indices.append(int(player_index_variant))
	var reason_code := str(outcome.get("reason_code", "")).strip_edges()
	if winner_player_indices.is_empty() or reason_code.is_empty():
		return _public_log_rejected("final_settlement_public_log_outcome_invalid")
	var source_revision_variant: Variant = public_context.get("source_revision", 0)
	var world_time_variant: Variant = public_context.get("world_time", 0.0)
	if typeof(source_revision_variant) != TYPE_INT or int(source_revision_variant) < 0 \
			or not (world_time_variant is int or world_time_variant is float) \
			or not is_finite(float(world_time_variant)) or float(world_time_variant) < 0.0:
		return _public_log_rejected("final_settlement_public_log_clock_invalid")
	var receipt := PublicLogReceipt.create(
		"final-settlement-%s" % outcome_id.sha256_text().left(16),
		&"final_settlement",
		&"victory.public.final_settlement",
		{
			"outcome_id": outcome_id,
			"public_status": "settled",
			"reason_code": reason_code,
			"winner_player_indices": winner_player_indices,
		},
		int(source_revision_variant),
		float(world_time_variant)
	)
	if not receipt.is_valid():
		return _public_log_rejected("final_settlement_public_log_receipt_invalid")
	var receipt_fingerprint := receipt.fingerprint()
	if _logged_outcome_ids.has(outcome_id):
		if str(_logged_outcome_ids.get(outcome_id, "")) != receipt_fingerprint:
			return _public_log_rejected("final_settlement_public_log_binding_collision")
		return {
			"accepted": true,
			"duplicate": true,
			"reason_id": "",
			"receipt_id": receipt.receipt_id,
			"outcome_id": outcome_id,
			"receipt_fingerprint": receipt_fingerprint,
		}
	if get_signal_connection_list(&"public_log_receipt_requested").size() != 1:
		return _public_log_rejected("final_settlement_public_log_acknowledger_missing")
	var acknowledgement := {}
	public_log_receipt_requested.emit(receipt, acknowledgement)
	if not _public_log_acknowledgement_valid(acknowledgement, receipt, outcome_id):
		if _is_pure_data(acknowledgement) and str(acknowledgement.get("reason_id", "")).strip_edges() != "":
			return _public_log_rejected(str(acknowledgement.get("reason_id", "")))
		return _public_log_rejected("final_settlement_public_log_ack_invalid")
	if not bool(acknowledgement.get("accepted", false)):
		return _public_log_rejected(str(acknowledgement.get("reason_id", "final_settlement_public_log_rejected")))
	_logged_outcome_ids[outcome_id] = receipt_fingerprint
	return acknowledgement.duplicate(true)


func _public_log_acknowledgement_valid(
	acknowledgement: Dictionary,
	receipt: PublicLogReceipt,
	outcome_id: String
) -> bool:
	if receipt == null or not receipt.is_valid() or not _is_pure_data(acknowledgement) \
			or not _has_exact_keys(acknowledgement, PUBLIC_LOG_ACK_KEYS) \
			or typeof(acknowledgement.get("schema_version")) != TYPE_INT \
			or int(acknowledgement.get("schema_version", 0)) != 1 \
			or not (acknowledgement.get("receipt_id") is String) \
			or not (acknowledgement.get("outcome_id") is String) \
			or not (acknowledgement.get("receipt_fingerprint") is String) \
			or typeof(acknowledgement.get("accepted")) != TYPE_BOOL \
			or typeof(acknowledgement.get("duplicate")) != TYPE_BOOL \
			or not (acknowledgement.get("reason_id") is String):
		return false
	if str(acknowledgement.get("receipt_id", "")) != receipt.receipt_id \
			or str(acknowledgement.get("outcome_id", "")) != outcome_id \
			or str(acknowledgement.get("receipt_fingerprint", "")) != receipt.fingerprint():
		return false
	return str(acknowledgement.get("reason_id", "")).is_empty() \
		if bool(acknowledgement.get("accepted", false)) \
		else not str(acknowledgement.get("reason_id", "")).strip_edges().is_empty()


func _public_log_rejected(reason_id: String) -> Dictionary:
	return {
		"accepted": false,
		"duplicate": false,
		"reason_id": reason_id,
		"receipt_id": "",
		"outcome_id": "",
		"receipt_fingerprint": "",
	}


func _on_board_action_requested(action_id: String) -> void:
	var routed_action := "setup" if action_id == "new_run" else action_id
	if not ["standings", "economy", "setup"].has(routed_action):
		return
	_action_emission_count += 1
	action_requested.emit(StringName(routed_action))


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


func _has_exact_keys(value: Dictionary, expected: Array) -> bool:
	if value.size() != expected.size():
		return false
	for key_variant in expected:
		if not value.has(key_variant):
			return false
	return true


func _public_source_fingerprint(value: Variant) -> String:
	return JSON.stringify(_canonicalize(value)).sha256_text()


func _canonicalize(value: Variant) -> Variant:
	if value is Dictionary:
		var source := value as Dictionary
		var keys := source.keys()
		keys.sort_custom(func(left: Variant, right: Variant) -> bool: return str(left) < str(right))
		var result := {}
		for key_variant in keys:
			result[str(key_variant)] = _canonicalize(source[key_variant])
		return result
	if value is Array:
		var result: Array = []
		for child in value as Array:
			result.append(_canonicalize(child))
		return result
	return value


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
