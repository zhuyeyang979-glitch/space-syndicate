@tool
extends Node
class_name ForcedDecisionRuntimeScheduler

const VALID_VISIBILITY_SCOPES := ["public", "private"]
const VALID_PRESENTATION_SURFACES := ["overlay", "card_resolution_track", "player_hint"]

var _priority_order: Array[String] = []
var _candidates: Array = []
var _configured := false


func configure(priority_order: Array) -> void:
	_priority_order = []
	for priority_variant in priority_order:
		var priority := str(priority_variant).strip_edges()
		if priority != "" and priority != "public_bid" and not _priority_order.has(priority):
			_priority_order.append(priority)
	_configured = not _priority_order.is_empty()
	if _configured:
		_priority_order.append("public_bid")
	else:
		_candidates.clear()
	_sort_candidates()


func sync_candidates(candidates: Array) -> void:
	_candidates = []
	if not _configured:
		return
	for candidate_variant in candidates:
		if not (candidate_variant is Dictionary):
			continue
		var candidate := _normalize_candidate(candidate_variant as Dictionary)
		if str(candidate.get("id", "")) == "" or str(candidate.get("priority_group", "")) == "":
			continue
		if not _priority_order.has(str(candidate.get("priority_group", ""))):
			continue
		_candidates.append(candidate)
	_sort_candidates()


func active_decision(viewer_index: int = -1) -> Dictionary:
	var candidate := _active_candidate()
	if candidate.is_empty():
		return {}
	if _candidate_visible_to(candidate, viewer_index):
		var visible := _candidate_snapshot(candidate)
		visible["visible_to_viewer"] = true
		return visible
	return {
		"id": "private_forced_decision",
		"kind": "private_forced_decision",
		"priority_group": str(candidate.get("priority_group", "other_choice")),
		"visibility_scope": "private",
		"presentation_surface": "player_hint",
		"opened_sequence": float(candidate.get("opened_sequence", 0.0)),
		"blocks_global_time": bool(candidate.get("blocks_global_time", false)),
		"blocks_player_actions": false,
		"blocks_card_resolution": bool(candidate.get("blocks_card_resolution", false)),
		"owner_scope": "another_player",
		"visible_to_viewer": false,
		"notes": "Another player is resolving the active forced decision.",
	}


func active_priority_group() -> String:
	return str(_active_candidate().get("priority_group", ""))


func blocks_global_time() -> bool:
	return bool(_active_candidate().get("blocks_global_time", false))


func blocks_player_actions(player_index: int) -> bool:
	var candidate := _active_candidate()
	if candidate.is_empty() or not bool(candidate.get("blocks_player_actions", false)):
		return false
	var owner_player_index := int(candidate.get("owner_player_index", -1))
	return owner_player_index < 0 or owner_player_index == player_index


func blocks_card_resolution() -> bool:
	return bool(_active_candidate().get("blocks_card_resolution", false))


func debug_snapshot() -> Dictionary:
	var candidate_snapshots: Array = []
	for candidate_variant in _candidates:
		candidate_snapshots.append(_candidate_snapshot(candidate_variant as Dictionary))
	return {
		"scheduler_ready": _configured,
		"scheduler_authoritative": _configured,
		"priority_order": _priority_order.duplicate(),
		"candidate_count": candidate_snapshots.size(),
		"active_priority_group": active_priority_group(),
		"blocks_global_time": blocks_global_time(),
		"blocks_card_resolution": blocks_card_resolution(),
		"candidates": candidate_snapshots,
	}


func _normalize_candidate(source: Dictionary) -> Dictionary:
	var kind := str(source.get("kind", "")).strip_edges()
	var expected_priority_group := _priority_group_for_kind(kind)
	if expected_priority_group.is_empty():
		return {}
	var priority_group := str(source.get("priority_group", expected_priority_group)).strip_edges()
	if priority_group != expected_priority_group:
		return {}
	var owner_player_index := int(source.get("owner_player_index", -1))
	var visibility_scope := str(source.get("visibility_scope", "public" if owner_player_index < 0 else "private"))
	if not VALID_VISIBILITY_SCOPES.has(visibility_scope):
		visibility_scope = "private" if owner_player_index >= 0 else "public"
	var presentation_surface := str(source.get("presentation_surface", "overlay"))
	if not VALID_PRESENTATION_SURFACES.has(presentation_surface):
		presentation_surface = "player_hint"
	return {
		"id": str(source.get("id", "")).strip_edges(),
		"kind": kind,
		"priority_group": priority_group,
		"owner_player_index": owner_player_index,
		"visibility_scope": visibility_scope,
		"presentation_surface": presentation_surface,
		"opened_sequence": float(source.get("opened_sequence", 0.0)),
		"blocks_global_time": bool(source.get("blocks_global_time", false)),
		"blocks_player_actions": bool(source.get("blocks_player_actions", false)),
		"blocks_card_resolution": bool(source.get("blocks_card_resolution", false)),
		"source_ref": str(source.get("source_ref", "")).strip_edges(),
		"notes": str(source.get("notes", "")),
	}


func _priority_group_for_kind(kind: String) -> String:
	match kind:
		"monster_wager":
			return "monster_wager"
		"counter_response":
			return "counter_response"
		"contract_response":
			return "contract_response"
		"discard_purchase", "monster_target_choice", "player_target_choice":
			return "other_choice"
		"public_bid", "card_order_bid":
			return "public_bid"
	return ""


func _sort_candidates() -> void:
	_candidates.sort_custom(_candidate_precedes)


func _candidate_precedes(left_variant: Variant, right_variant: Variant) -> bool:
	var left: Dictionary = left_variant if left_variant is Dictionary else {}
	var right: Dictionary = right_variant if right_variant is Dictionary else {}
	var left_rank := _priority_rank(str(left.get("priority_group", "")))
	var right_rank := _priority_rank(str(right.get("priority_group", "")))
	if left_rank != right_rank:
		return left_rank < right_rank
	var left_sequence := float(left.get("opened_sequence", 0.0))
	var right_sequence := float(right.get("opened_sequence", 0.0))
	if not is_equal_approx(left_sequence, right_sequence):
		return left_sequence < right_sequence
	return str(left.get("id", "")) < str(right.get("id", ""))


func _priority_rank(priority_group: String) -> int:
	var index := _priority_order.find(priority_group)
	return index if index >= 0 else _priority_order.size() + 1


func _active_candidate() -> Dictionary:
	if not _configured or _candidates.is_empty():
		return {}
	return _candidates[0] as Dictionary


func _candidate_visible_to(candidate: Dictionary, viewer_index: int) -> bool:
	if str(candidate.get("visibility_scope", "public")) == "public":
		return true
	return viewer_index >= 0 and int(candidate.get("owner_player_index", -1)) == viewer_index


func _candidate_snapshot(candidate: Dictionary) -> Dictionary:
	return {
		"id": str(candidate.get("id", "")),
		"kind": str(candidate.get("kind", "")),
		"priority_group": str(candidate.get("priority_group", "")),
		"visibility_scope": str(candidate.get("visibility_scope", "public")),
		"presentation_surface": str(candidate.get("presentation_surface", "player_hint")),
		"opened_sequence": float(candidate.get("opened_sequence", 0.0)),
		"blocks_global_time": bool(candidate.get("blocks_global_time", false)),
		"blocks_player_actions": bool(candidate.get("blocks_player_actions", false)),
		"blocks_card_resolution": bool(candidate.get("blocks_card_resolution", false)),
		"source_ref": str(candidate.get("source_ref", "")),
		"owner_scope": "assigned" if int(candidate.get("owner_player_index", -1)) >= 0 else "all_players",
		"notes": str(candidate.get("notes", "")),
	}
