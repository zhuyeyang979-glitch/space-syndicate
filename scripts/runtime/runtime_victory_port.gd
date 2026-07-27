extends Node
class_name RuntimeVictoryPort

const TRANSACTIONAL_SESSION_PLAN_REASON := "session_plan_applied"
const TRANSACTIONAL_SESSION_ROLLBACK_REASON := "session_checkpoint_rolled_back"
const TRANSACTIONAL_SAVE_REASON := "session_save_applied"
const COMMITTED_LOAD_REASON := "session_load_completed"
const HARD_RESET_REASON_IDS := ["session_began", "session_reset"]

var _victory: VictoryControlRuntimeController
var _world_query: VictoryControlWorldBridge
var _session: GameSessionRuntimeController
var _ai: AiRuntimeController
var _presentation_queries: TablePresentationQueryPorts
var _pending_outcome: Dictionary = {}
var _pending_public_snapshot: Dictionary = {}
var _pending_binding := ""
var _pending_public_binding := ""
var _pending_presentation_committed := false
var _pending_presentation_receipt_fingerprint := ""
var _terminal_queue_count := 0
var _terminal_retry_count := 0
var _terminal_commit_count := 0
var _terminal_reject_count := 0
var _terminal_stale_drop_count := 0
var _session_context_binding := ""
var _lifecycle_checkpoint: Dictionary = {}
var _lifecycle_checkpoint_context_binding := ""
var _lifecycle_applied_context_binding := ""
var _lifecycle_transition_kind := ""
var _lifecycle_transition_sequence := 0
var _lifecycle_restore_count := 0


func bind_dependencies(
	victory: VictoryControlRuntimeController,
	world_query: VictoryControlWorldBridge,
	session: GameSessionRuntimeController,
	ai: AiRuntimeController,
	presentation_queries: TablePresentationQueryPorts
) -> void:
	if _session != null and _session.authorization_context_changed.is_connected(_on_session_authorization_context_changed):
		_session.authorization_context_changed.disconnect(_on_session_authorization_context_changed)
	_victory = victory
	_world_query = world_query
	_session = session
	_ai = ai
	_presentation_queries = presentation_queries
	if _session != null and not _session.authorization_context_changed.is_connected(_on_session_authorization_context_changed):
		_session.authorization_context_changed.connect(_on_session_authorization_context_changed)
	reset_state()
	_session_context_binding = _current_session_context_binding()


func is_ready() -> bool:
	return is_instance_valid(_victory) and is_instance_valid(_world_query) \
		and is_instance_valid(_session) and is_instance_valid(_presentation_queries)


func advance_victory_control(delta_seconds: float, clock_pause: Dictionary = {}) -> Dictionary:
	if has_pending_terminal_outcome():
		var pending_public := _pending_public_snapshot.duplicate(true)
		var pending_outcome := _pending_outcome.duplicate(true)
		var retry := retry_pending_terminal_outcome()
		return {
			"valid": bool(retry.get("accepted", false)),
			"reason": str(retry.get("reason_id", "")),
			"state": "resolved",
			"public_snapshot": pending_public,
			"outcome_receipt": pending_outcome,
			"terminal_commit": retry,
		}
	if _victory == null or _world_query == null:
		return {"valid": false, "reason": "victory_boundary_unavailable"}
	var world_snapshot := _world_query.capture_world_snapshot(clock_pause, "post_world_settlement")
	var result := _victory.advance_world_effective(delta_seconds, world_snapshot).duplicate(true)
	var outcome: Dictionary = result.get("outcome_receipt", {}) if result.get("outcome_receipt", {}) is Dictionary else {}
	var public_snapshot: Dictionary = result.get("public_snapshot", {}) if result.get("public_snapshot", {}) is Dictionary else {}
	var resolved := str(result.get("state", "")) == "resolved" or str(public_snapshot.get("state", "")) == "resolved"
	if outcome.is_empty():
		if not resolved and _presentation_queries != null:
			_presentation_queries.capture_victory_advance(result)
	else:
		result["terminal_commit"] = commit_terminal_outcome(outcome, public_snapshot)
	return result


func commit_terminal_outcome(outcome: Dictionary, public_snapshot: Dictionary) -> Dictionary:
	if _session == null or _presentation_queries == null:
		return _terminal_rejected("terminal_dependency_unavailable")
	if _session.is_finished():
		return _terminal_rejected("session_already_finished")
	if not _is_pure_data(outcome) or not _is_pure_data(public_snapshot):
		return _terminal_rejected("terminal_payload_not_pure_data")
	if str(public_snapshot.get("visibility_scope", "")) != "public" or str(public_snapshot.get("state", "")) != "resolved":
		return _terminal_rejected("terminal_public_snapshot_invalid")
	var public_outcome: Dictionary = public_snapshot.get("outcome_receipt", {}) if public_snapshot.get("outcome_receipt", {}) is Dictionary else {}
	if not _outcomes_share_identity(outcome, public_outcome):
		return _terminal_rejected("terminal_outcome_identity_mismatch")
	var binding := _outcome_binding(outcome)
	var public_binding := _public_snapshot_binding(public_snapshot)
	if binding.is_empty() or public_binding.is_empty():
		return _terminal_rejected("terminal_outcome_identity_invalid")
	if not _pending_binding.is_empty():
		if _pending_binding != binding:
			return _terminal_rejected("terminal_outcome_binding_collision")
		return retry_pending_terminal_outcome()
	_pending_outcome = outcome.duplicate(true)
	_pending_public_snapshot = public_snapshot.duplicate(true)
	_pending_binding = binding
	_pending_public_binding = public_binding
	_pending_presentation_committed = false
	_pending_presentation_receipt_fingerprint = ""
	_terminal_queue_count += 1
	return retry_pending_terminal_outcome()


func has_pending_terminal_outcome() -> bool:
	return not _pending_binding.is_empty()


func retry_pending_terminal_outcome() -> Dictionary:
	if not has_pending_terminal_outcome():
		return _terminal_rejected("terminal_outcome_not_pending")
	_terminal_retry_count += 1
	if _session == null or _presentation_queries == null or _victory == null:
		return _terminal_rejected("terminal_dependency_unavailable")
	if _session.is_finished():
		return _terminal_rejected("session_already_finished")
	var current_public := _victory.public_snapshot(-1)
	var current_outcome: Dictionary = current_public.get("outcome_receipt", {}) if current_public.get("outcome_receipt", {}) is Dictionary else {}
	if _outcome_binding(_pending_outcome) != _pending_binding \
			or _public_snapshot_binding(_pending_public_snapshot) != _pending_public_binding \
			or _outcome_binding(current_outcome) != _pending_binding \
			or _public_snapshot_binding(current_public) != _pending_public_binding:
		var stale_outcome_id := str(_pending_outcome.get("outcome_id", ""))
		_clear_pending_terminal()
		_terminal_stale_drop_count += 1
		return _terminal_rejected("terminal_outcome_became_stale", stale_outcome_id)
	if not _pending_presentation_committed:
		var presentation_receipt := _presentation_queries.capture_victory_outcome(_pending_public_snapshot.duplicate(true))
		if presentation_receipt == null or not presentation_receipt.is_valid():
			return _terminal_rejected("terminal_presentation_not_accepted")
		var presented_outcome: Dictionary = presentation_receipt.public_snapshot.get("outcome_receipt", {}) if presentation_receipt.public_snapshot.get("outcome_receipt", {}) is Dictionary else {}
		if _outcome_binding(presented_outcome) != _pending_binding:
			return _terminal_rejected("terminal_presentation_outcome_mismatch")
		var presentation_dictionary := presentation_receipt.to_dictionary()
		if presentation_dictionary.is_empty():
			return _terminal_rejected("terminal_presentation_receipt_invalid")
		_pending_presentation_receipt_fingerprint = JSON.stringify(presentation_dictionary).sha256_text()
		_pending_presentation_committed = true
	var committed_outcome := _pending_outcome.duplicate(true)
	_session.finish_session(committed_outcome)
	if not _session.is_finished():
		return _terminal_rejected("terminal_session_finish_rejected")
	if _ai != null:
		_ai.finalize_victory_outcome_learning(committed_outcome)
	var outcome_id := str(committed_outcome.get("outcome_id", ""))
	_clear_pending_terminal()
	_terminal_commit_count += 1
	return {
		"accepted": true,
		"reason_id": "",
		"outcome_id": outcome_id,
		"terminal_commit_count": _terminal_commit_count,
	}


func reset_state() -> void:
	_reset_active_terminal_state()
	_clear_lifecycle_transition()
	_lifecycle_restore_count = 0
	_session_context_binding = _current_session_context_binding()


func debug_snapshot() -> Dictionary:
	return {
		"port_kind": "victory",
		"ready": is_ready(),
		"operation_count": 2,
		"owns_victory_state": false,
		"pending_terminal": has_pending_terminal_outcome(),
		"pending_outcome_id": str(_pending_outcome.get("outcome_id", "")),
		"pending_binding_fingerprint": _pending_binding,
		"pending_public_binding_fingerprint": _pending_public_binding,
		"pending_presentation_committed": _pending_presentation_committed,
		"pending_presentation_receipt_fingerprint": _pending_presentation_receipt_fingerprint,
		"terminal_queue_count": _terminal_queue_count,
		"terminal_retry_count": _terminal_retry_count,
		"terminal_commit_count": _terminal_commit_count,
		"terminal_reject_count": _terminal_reject_count,
		"terminal_stale_drop_count": _terminal_stale_drop_count,
		"session_context_binding_fingerprint": _session_context_binding,
		"lifecycle_checkpoint_pending": not _lifecycle_transition_kind.is_empty(),
		"lifecycle_transition_kind": _lifecycle_transition_kind,
		"lifecycle_restore_count": _lifecycle_restore_count,
	}


func _on_session_authorization_context_changed(reason_id: String) -> void:
	var current_context_binding := _current_session_context_binding()
	if reason_id in HARD_RESET_REASON_IDS:
		_clear_lifecycle_transition()
		_reset_active_terminal_state()
		_lifecycle_restore_count = 0
		_session_context_binding = current_context_binding
		return
	match reason_id:
		TRANSACTIONAL_SESSION_PLAN_REASON:
			_begin_lifecycle_transition(TRANSACTIONAL_SESSION_PLAN_REASON, current_context_binding)
		TRANSACTIONAL_SESSION_ROLLBACK_REASON:
			_restore_lifecycle_transition(TRANSACTIONAL_SESSION_PLAN_REASON, current_context_binding)
		TRANSACTIONAL_SAVE_REASON:
			if _lifecycle_transition_kind == TRANSACTIONAL_SAVE_REASON:
				_restore_lifecycle_transition(TRANSACTIONAL_SAVE_REASON, current_context_binding)
			else:
				_begin_lifecycle_transition(TRANSACTIONAL_SAVE_REASON, current_context_binding)
		COMMITTED_LOAD_REASON:
			_clear_lifecycle_transition()
			_reset_active_terminal_state()
			_session_context_binding = current_context_binding
		_:
			# Every unrecognized authorization-context change invalidates terminal
			# authority. This keeps future lifecycle additions fail closed.
			_clear_lifecycle_transition()
			_reset_active_terminal_state()
			_session_context_binding = current_context_binding


func _begin_lifecycle_transition(kind: String, current_context_binding: String) -> void:
	_clear_lifecycle_transition()
	_lifecycle_checkpoint = _capture_active_terminal_state()
	_lifecycle_checkpoint_context_binding = _session_context_binding
	_lifecycle_applied_context_binding = current_context_binding
	_lifecycle_transition_kind = kind
	_lifecycle_transition_sequence += 1
	var transition_sequence := _lifecycle_transition_sequence
	_reset_active_terminal_state()
	_session_context_binding = current_context_binding
	call_deferred("_commit_lifecycle_transition", transition_sequence)


func _restore_lifecycle_transition(expected_kind: String, current_context_binding: String) -> void:
	if _lifecycle_transition_kind.is_empty():
		_session_context_binding = current_context_binding
		return
	var can_restore := _lifecycle_transition_kind == expected_kind \
			and not _lifecycle_checkpoint.is_empty() \
			and not _lifecycle_checkpoint_context_binding.is_empty() \
			and _session_context_binding == _lifecycle_applied_context_binding \
			and current_context_binding == _lifecycle_checkpoint_context_binding
	var checkpoint := _lifecycle_checkpoint.duplicate(true)
	_clear_lifecycle_transition()
	if can_restore:
		_restore_active_terminal_state(checkpoint)
		_lifecycle_restore_count += 1
	else:
		_reset_active_terminal_state()
	_session_context_binding = current_context_binding


func _commit_lifecycle_transition(transition_sequence: int) -> void:
	if _lifecycle_transition_kind.is_empty() or transition_sequence != _lifecycle_transition_sequence:
		return
	_clear_lifecycle_transition()


func _clear_lifecycle_transition() -> void:
	_lifecycle_checkpoint = {}
	_lifecycle_checkpoint_context_binding = ""
	_lifecycle_applied_context_binding = ""
	_lifecycle_transition_kind = ""
	_lifecycle_transition_sequence += 1


func _capture_active_terminal_state() -> Dictionary:
	return {
		"pending_outcome": _pending_outcome.duplicate(true),
		"pending_public_snapshot": _pending_public_snapshot.duplicate(true),
		"pending_binding": _pending_binding,
		"pending_public_binding": _pending_public_binding,
		"pending_presentation_committed": _pending_presentation_committed,
		"pending_presentation_receipt_fingerprint": _pending_presentation_receipt_fingerprint,
		"terminal_queue_count": _terminal_queue_count,
		"terminal_retry_count": _terminal_retry_count,
		"terminal_commit_count": _terminal_commit_count,
		"terminal_reject_count": _terminal_reject_count,
		"terminal_stale_drop_count": _terminal_stale_drop_count,
	}


func _restore_active_terminal_state(checkpoint: Dictionary) -> void:
	_pending_outcome = (checkpoint.get("pending_outcome", {}) as Dictionary).duplicate(true)
	_pending_public_snapshot = (checkpoint.get("pending_public_snapshot", {}) as Dictionary).duplicate(true)
	_pending_binding = str(checkpoint.get("pending_binding", ""))
	_pending_public_binding = str(checkpoint.get("pending_public_binding", ""))
	_pending_presentation_committed = bool(checkpoint.get("pending_presentation_committed", false))
	_pending_presentation_receipt_fingerprint = str(checkpoint.get("pending_presentation_receipt_fingerprint", ""))
	_terminal_queue_count = int(checkpoint.get("terminal_queue_count", 0))
	_terminal_retry_count = int(checkpoint.get("terminal_retry_count", 0))
	_terminal_commit_count = int(checkpoint.get("terminal_commit_count", 0))
	_terminal_reject_count = int(checkpoint.get("terminal_reject_count", 0))
	_terminal_stale_drop_count = int(checkpoint.get("terminal_stale_drop_count", 0))


func _reset_active_terminal_state() -> void:
	_clear_pending_terminal()
	_terminal_queue_count = 0
	_terminal_retry_count = 0
	_terminal_commit_count = 0
	_terminal_reject_count = 0
	_terminal_stale_drop_count = 0


func _current_session_context_binding() -> String:
	if not is_instance_valid(_session):
		return ""
	var summary := _session.session_summary()
	if not _is_pure_data(summary):
		return ""
	return JSON.stringify({
		"session_state": str(summary.get("session_state", "")),
		"session_id": str(summary.get("session_id", "")),
		"scenario_id": str(summary.get("scenario_id", "")),
		"ruleset_id": str(summary.get("ruleset_id", "")),
		"seed": int(summary.get("seed", 0)),
		"setup": (summary.get("setup", {}) as Dictionary).duplicate(true) if summary.get("setup", {}) is Dictionary else {},
		"outcome_receipt": (summary.get("outcome_receipt", {}) as Dictionary).duplicate(true) if summary.get("outcome_receipt", {}) is Dictionary else {},
	}).sha256_text()


func _clear_pending_terminal() -> void:
	_pending_outcome = {}
	_pending_public_snapshot = {}
	_pending_binding = ""
	_pending_public_binding = ""
	_pending_presentation_committed = false
	_pending_presentation_receipt_fingerprint = ""


func _terminal_rejected(reason_id: String, outcome_id: String = "") -> Dictionary:
	_terminal_reject_count += 1
	return {
		"accepted": false,
		"reason_id": reason_id,
		"outcome_id": outcome_id if not outcome_id.is_empty() else str(_pending_outcome.get("outcome_id", "")),
	}


func _outcomes_share_identity(authoritative: Dictionary, projected: Dictionary) -> bool:
	var authoritative_identity := _outcome_identity(authoritative)
	var projected_identity := _outcome_identity(projected)
	return not authoritative_identity.is_empty() \
		and authoritative_identity == projected_identity \
		and _outcome_binding(authoritative) == _outcome_binding(projected)


func _outcome_binding(outcome: Dictionary) -> String:
	var identity := _outcome_identity(outcome)
	if identity.is_empty() or not _is_pure_data(outcome):
		return ""
	return JSON.stringify({"identity": identity, "payload": outcome}).sha256_text()


func _public_snapshot_binding(public_snapshot: Dictionary) -> String:
	if not _is_pure_data(public_snapshot) \
			or str(public_snapshot.get("visibility_scope", "")) != "public" \
			or str(public_snapshot.get("state", "")) != "resolved":
		return ""
	var outcome: Dictionary = public_snapshot.get("outcome_receipt", {}) \
		if public_snapshot.get("outcome_receipt", {}) is Dictionary else {}
	var outcome_binding := _outcome_binding(outcome)
	if outcome_binding.is_empty():
		return ""
	return JSON.stringify({
		"outcome_binding": outcome_binding,
		"public_snapshot": public_snapshot,
	}).sha256_text()


func _outcome_identity(outcome: Dictionary) -> Dictionary:
	var outcome_id := str(outcome.get("outcome_id", "")).strip_edges()
	var reason_code := str(outcome.get("reason_code", "")).strip_edges()
	var schema_version := str(outcome.get("schema_version", "")).strip_edges()
	var ruleset_id := str(outcome.get("ruleset_id", "")).strip_edges()
	var winner_indices: Array = outcome.get("winner_player_indices", []) if outcome.get("winner_player_indices", []) is Array else []
	var comparison_order: Array = outcome.get("comparison_order", []) if outcome.get("comparison_order", []) is Array else []
	var rankings: Array = outcome.get("rankings", []) if outcome.get("rankings", []) is Array else []
	if outcome_id.is_empty() or reason_code.is_empty() or schema_version.is_empty() or ruleset_id.is_empty() or winner_indices.is_empty() or comparison_order.is_empty() or rankings.is_empty():
		return {}
	var normalized_winners: Array[int] = []
	for value in winner_indices:
		if typeof(value) != TYPE_INT or int(value) < 0 or normalized_winners.has(int(value)):
			return {}
		normalized_winners.append(int(value))
	var normalized_order: Array[String] = []
	for value in comparison_order:
		var token := str(value).strip_edges()
		if token.is_empty():
			return {}
		normalized_order.append(token)
	var normalized_rankings: Array[Dictionary] = []
	var ranked_players := {}
	for ranking_variant in rankings:
		if not (ranking_variant is Dictionary):
			return {}
		var ranking := ranking_variant as Dictionary
		var player_index := int(ranking.get("player_index", -1))
		if player_index < 0 or ranked_players.has(player_index):
			return {}
		ranked_players[player_index] = true
		normalized_rankings.append({
			"player_index": player_index,
			"top_k_gdp_per_minute_cents": int(ranking.get("top_k_gdp_per_minute_cents", 0)),
			"top_k_gdp_per_minute": int(ranking.get("top_k_gdp_per_minute", ranking.get("top_n_gdp_per_minute", 0))),
			"controlled_region_count": int(ranking.get("controlled_region_count", 0)),
			"winner": bool(ranking.get("winner", false)),
		})
	return {
		"outcome_id": outcome_id,
		"schema_version": schema_version,
		"ruleset_id": ruleset_id,
		"reason_code": reason_code,
		"winner_player_indices": normalized_winners,
		"co_victory": bool(outcome.get("co_victory", false)),
		"comparison_order": normalized_order,
		"rankings": normalized_rankings,
	}


func _is_pure_data(value: Variant) -> bool:
	if value is Object or value is Callable:
		return false
	if value is Dictionary:
		for key_variant in value.keys():
			if not _is_pure_data(key_variant) or not _is_pure_data(value[key_variant]):
				return false
	elif value is Array:
		for item_variant in value:
			if not _is_pure_data(item_variant):
				return false
	return true
