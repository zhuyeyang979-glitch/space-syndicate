@tool
extends Node
class_name AiCityInferenceCommandPort

const JOURNAL_LIMIT := 128

@export var world_session_state_path: NodePath
@export var game_session_runtime_controller_path: NodePath

var _capability: AiRegionKnowledgeCapability
var _capability_revision := 0
var _accepted_count := 0
var _rejected_count := 0
var _idempotent_replay_count := 0
var _command_id_conflict_count := 0
var _journal: Dictionary = {}
var _journal_order: Array[String] = []
var _journal_session_id := ""
var _journal_epoch := 0
var _bound_world: WorldSessionState


func _ready() -> void:
	_bind_world_lifecycle()


func bind_ai_capability(capability: AiRegionKnowledgeCapability) -> void:
	_bind_world_lifecycle()
	if capability != _capability:
		_clear_journal()
		_journal_session_id = _current_session_id()
	_capability = capability
	_capability_revision += 1


func is_ready() -> bool:
	return _world() != null and _game_session() != null and _capability != null


func submit_guess(
	capability: AiRegionKnowledgeCapability,
	command_id: String,
	actor_index: int,
	region_id: String,
	guessed_player_index: int,
	confidence: int,
	reason_id: String,
	expected_owner_revision: String
) -> Dictionary:
	_bind_world_lifecycle()
	_ensure_session_scope(_current_session_id())
	var normalized_command_id := command_id.strip_edges()
	var normalized_region_id := region_id.strip_edges()
	if not _authorized(capability, actor_index) \
			or normalized_command_id.is_empty() \
			or normalized_command_id != command_id \
			or normalized_region_id.is_empty() \
			or normalized_region_id != region_id \
			or expected_owner_revision.is_empty():
		_rejected_count += 1
		return _receipt(false, false, "ai_city_inference_unauthorized", actor_index, normalized_region_id, "")
	var fingerprint := _command_fingerprint(
		_current_session_id(),
		actor_index,
		normalized_region_id,
		guessed_player_index,
		confidence,
		reason_id,
		expected_owner_revision
	)
	if _journal.has(normalized_command_id):
		var existing := _journal[normalized_command_id] as Dictionary
		if str(existing.get("fingerprint", "")) != fingerprint:
			_command_id_conflict_count += 1
			_rejected_count += 1
			return _receipt(false, false, "ai_city_inference_command_id_conflict", actor_index, normalized_region_id, expected_owner_revision)
		_idempotent_replay_count += 1
		var replay := (existing.get("receipt", {}) as Dictionary).duplicate(true)
		replay["idempotent_replay"] = true
		return replay
	var district_index := _world().district_index_for_region_id(normalized_region_id)
	if district_index < 0:
		_rejected_count += 1
		var missing := _receipt(false, false, "ai_city_inference_region_missing", actor_index, normalized_region_id, expected_owner_revision)
		_remember(normalized_command_id, fingerprint, missing)
		return missing
	var result := _world().set_city_owner_guess(
		actor_index,
		normalized_region_id,
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
	var receipt := {
		"applied": applied,
		"changed": bool(result.get("changed", false)),
		"reason_code": str(result.get("reason_code", "ai_city_inference_rejected")),
		"actor_index": actor_index,
		"region_id": normalized_region_id,
		"owner_revision_before": str(result.get("owner_revision_before", expected_owner_revision)),
		"owner_revision_after": str(result.get("owner_revision_after", expected_owner_revision)),
		"visibility_scope": "actor_private",
		"idempotent_replay": false,
	}
	_remember(normalized_command_id, fingerprint, receipt)
	return receipt


func debug_snapshot() -> Dictionary:
	return {
		"port_ready": is_ready(),
		"capability_revision": _capability_revision,
		"accepted_count": _accepted_count,
		"rejected_count": _rejected_count,
		"idempotent_replay_count": _idempotent_replay_count,
		"command_id_conflict_count": _command_id_conflict_count,
		"journal_size": _journal.size(),
		"journal_limit": JOURNAL_LIMIT,
		"journal_epoch": _journal_epoch,
		"journal_session_scoped": true,
		"world_restore_clears_journal": true,
		"writes_only_actor_inference": true,
		"reveals_authoritative_owner": false,
		"references_main": false,
	}


func _authorized(capability: AiRegionKnowledgeCapability, actor_index: int) -> bool:
	return capability != null \
		and capability == _capability \
		and is_ready() \
		and _game_session().session_state() == GameSessionRuntimeController.STATE_RUNNING \
		and actor_index >= 0 \
		and actor_index < _world().players.size() \
		and _world().players[actor_index] is Dictionary \
		and (bool((_world().players[actor_index] as Dictionary).get("is_ai", false)) \
			or str((_world().players[actor_index] as Dictionary).get("seat_type", "human")) == "ai") \
		and not bool((_world().players[actor_index] as Dictionary).get("eliminated", false))


func _receipt(
	applied: bool,
	changed: bool,
	reason_code: String,
	actor_index: int,
	region_id: String,
	revision: String
) -> Dictionary:
	return {
		"applied": applied,
		"changed": changed,
		"reason_code": reason_code,
		"actor_index": actor_index,
		"region_id": region_id,
		"owner_revision_before": revision,
		"owner_revision_after": revision,
		"visibility_scope": "actor_private",
		"idempotent_replay": false,
	}


func _command_fingerprint(
	session_id: String,
	actor_index: int,
	region_id: String,
	guessed_player_index: int,
	confidence: int,
	reason_id: String,
	expected_owner_revision: String
) -> String:
	return JSON.stringify([
		"ai_city_inference_v1",
		session_id,
		actor_index,
		region_id,
		guessed_player_index,
		confidence,
		reason_id,
		expected_owner_revision,
	]).sha256_text()


func _remember(command_id: String, fingerprint: String, receipt: Dictionary) -> void:
	_journal[command_id] = {
		"fingerprint": fingerprint,
		"receipt": receipt.duplicate(true),
	}
	_journal_order.append(command_id)
	while _journal_order.size() > JOURNAL_LIMIT:
		_journal.erase(_journal_order.pop_front())


func _bind_world_lifecycle() -> void:
	var world := _world()
	if world == _bound_world:
		return
	if _bound_world != null and is_instance_valid(_bound_world) \
			and _bound_world.session_restored.is_connected(_on_world_session_restored):
		_bound_world.session_restored.disconnect(_on_world_session_restored)
	_bound_world = world
	if _bound_world != null and not _bound_world.session_restored.is_connected(_on_world_session_restored):
		_bound_world.session_restored.connect(_on_world_session_restored)
	_clear_journal()
	_journal_session_id = _current_session_id()


func _on_world_session_restored(_summary: Dictionary) -> void:
	_clear_journal()
	_journal_session_id = _current_session_id()


func _ensure_session_scope(session_id: String) -> void:
	if session_id == _journal_session_id:
		return
	_clear_journal()
	_journal_session_id = session_id


func _clear_journal() -> void:
	_journal.clear()
	_journal_order.clear()
	_journal_epoch += 1


func _current_session_id() -> String:
	var session := _game_session()
	return str(session.session_summary().get("session_id", "")) if session != null else ""


func _world() -> WorldSessionState:
	return get_node_or_null(world_session_state_path) as WorldSessionState


func _game_session() -> GameSessionRuntimeController:
	return get_node_or_null(game_session_runtime_controller_path) as GameSessionRuntimeController
