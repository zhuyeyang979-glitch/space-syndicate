@tool
extends Node
class_name AiCityInferenceCommandPort

@export var world_session_state_path: NodePath

var _capability: AiRegionKnowledgeCapability
var _capability_revision := 0
var _accepted_count := 0
var _rejected_count := 0


func bind_ai_capability(capability: AiRegionKnowledgeCapability) -> void:
	_capability = capability
	_capability_revision += 1


func submit_guess(
	capability: AiRegionKnowledgeCapability,
	actor_index: int,
	district_index: int,
	guessed_player_index: int,
	confidence: int,
	reason_id: String,
	expected_owner_revision: String
) -> Dictionary:
	if not _authorized(capability, actor_index) or expected_owner_revision.is_empty():
		_rejected_count += 1
		return _receipt(false, false, "ai_city_inference_unauthorized", actor_index, district_index, "")
	var region_id := _world().region_id_for_district(district_index)
	if region_id.is_empty():
		_rejected_count += 1
		return _receipt(false, false, "ai_city_inference_region_missing", actor_index, district_index, expected_owner_revision)
	var result := _world().set_city_owner_guess(
		actor_index,
		region_id,
		guessed_player_index,
		confidence,
		reason_id,
		expected_owner_revision
	)
	var applied := bool(result.get("applied", false))
	if applied:
		_accepted_count += 1
	else:
		_rejected_count += 1
	return {
		"applied": applied,
		"changed": bool(result.get("changed", false)),
		"reason_code": str(result.get("reason_code", "ai_city_inference_rejected")),
		"actor_index": actor_index,
		"district_index": district_index,
		"owner_revision_before": str(result.get("owner_revision_before", expected_owner_revision)),
		"owner_revision_after": str(result.get("owner_revision_after", expected_owner_revision)),
		"visibility_scope": "actor_private",
	}


func debug_snapshot() -> Dictionary:
	return {
		"port_ready": _world() != null and _capability != null,
		"capability_revision": _capability_revision,
		"accepted_count": _accepted_count,
		"rejected_count": _rejected_count,
		"writes_only_actor_inference": true,
		"reveals_authoritative_owner": false,
		"references_main": false,
	}


func _authorized(capability: AiRegionKnowledgeCapability, actor_index: int) -> bool:
	return capability != null \
		and capability == _capability \
		and _world() != null \
		and actor_index >= 0 \
		and actor_index < _world().players.size() \
		and _world().players[actor_index] is Dictionary \
		and (bool((_world().players[actor_index] as Dictionary).get("is_ai", false)) \
			or str((_world().players[actor_index] as Dictionary).get("seat_type", "human")) == "ai")


func _receipt(
	applied: bool,
	changed: bool,
	reason_code: String,
	actor_index: int,
	district_index: int,
	revision: String
) -> Dictionary:
	return {
		"applied": applied,
		"changed": changed,
		"reason_code": reason_code,
		"actor_index": actor_index,
		"district_index": district_index,
		"owner_revision_before": revision,
		"owner_revision_after": revision,
		"visibility_scope": "actor_private",
	}


func _world() -> WorldSessionState:
	return get_node_or_null(world_session_state_path) as WorldSessionState
