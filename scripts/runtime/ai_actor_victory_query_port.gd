@tool
extends Node
class_name AiActorVictoryQueryPort

@export var victory_control_runtime_controller_path: NodePath
@export var victory_public_query_port_path: NodePath
@export var world_session_state_path: NodePath
@export var game_session_runtime_controller_path: NodePath

var _capabilities_by_actor: Dictionary = {}
var _capability_binding_authority: AiCapabilityBindingAuthority
var _capability_binding_initialized := false
var _bound_actor_roster_revision := ""
var _capability_revision := 0
var _query_count := 0
var _rejected_query_count := 0


func bind_ai_capabilities(
	binding_authority: AiCapabilityBindingAuthority,
	capabilities_by_actor: Dictionary
) -> bool:
	if binding_authority == null or (_capability_binding_authority != null and _capability_binding_authority != binding_authority):
		return false
	var expected := _ai_player_indices()
	if capabilities_by_actor.size() != expected.size():
		return _reject_binding()
	var normalized: Dictionary = {}
	var seen_tokens: Dictionary = {}
	for actor_index_variant in expected:
		var actor_index := int(actor_index_variant)
		var token: Variant = capabilities_by_actor.get(actor_index)
		if not (token is AiActorVictoryCapability):
			return _reject_binding()
		var token_id := (token as AiActorVictoryCapability).get_instance_id()
		if seen_tokens.has(token_id):
			return _reject_binding()
		seen_tokens[token_id] = true
		normalized[actor_index] = token
	_capability_binding_authority = binding_authority
	_capabilities_by_actor = normalized
	_capability_binding_initialized = true
	_bound_actor_roster_revision = _actor_roster_revision()
	_capability_revision += 1
	return true


func is_ready() -> bool:
	return _victory() != null \
		and _public_query() != null \
		and _public_query().is_ready() \
		and _world() != null \
		and _game_session() != null \
		and _capability_binding_initialized


func actor_snapshot(
	capability: AiActorVictoryCapability,
	actor_index: int
) -> Dictionary:
	_query_count += 1
	if not _authorized(capability, actor_index):
		_rejected_query_count += 1
		return {}
	var public_snapshot := _public_query().public_snapshot()
	if not bool(public_snapshot.get("available", false)):
		_rejected_query_count += 1
		return {}
	var source := _victory().private_snapshot(actor_index)
	var candidate := _own_candidate(source, actor_index)
	if candidate.is_empty():
		_rejected_query_count += 1
		return {}
	var result := {
		"schema_version": 1,
		"visibility_scope": "actor_private",
		"available": true,
		"actor_index": actor_index,
		"own_candidate": candidate.duplicate(true),
		"own_qualification_elapsed_seconds": maxf(
			0.0,
			float(source.get("own_qualification_elapsed_seconds", 0.0))
		),
	}
	result["state_revision"] = JSON.stringify([
		"ai_actor_victory_snapshot_v1",
		actor_index,
		_bound_actor_roster_revision,
		result["own_candidate"],
		result["own_qualification_elapsed_seconds"],
	]).sha256_text()
	if not TablePresentationPureDataPolicy.is_pure_data(result):
		_rejected_query_count += 1
		return {}
	return TablePresentationPureDataPolicy.detached_copy(result)


func candidate_visible_to_actor(
	capability: AiActorVictoryCapability,
	viewer_index: int,
	subject_index: int
) -> Dictionary:
	_query_count += 1
	if not _authorized(capability, viewer_index) \
			or subject_index < 0 or subject_index >= _world().players.size():
		_rejected_query_count += 1
		return {}
	var public_snapshot := _public_query().public_snapshot()
	if not bool(public_snapshot.get("available", false)):
		_rejected_query_count += 1
		return {}
	var public_candidate := _public_candidate(public_snapshot, subject_index)
	if subject_index != viewer_index:
		return TablePresentationPureDataPolicy.detached_copy(public_candidate) \
			if not public_candidate.is_empty() else {}
	var private_snapshot := _victory().private_snapshot(viewer_index)
	var own_candidate := _own_candidate(private_snapshot, viewer_index)
	if own_candidate.is_empty():
		_rejected_query_count += 1
		return {}
	if not public_candidate.is_empty():
		own_candidate.merge(public_candidate, true)
	if not TablePresentationPureDataPolicy.is_pure_data(own_candidate):
		_rejected_query_count += 1
		return {}
	return TablePresentationPureDataPolicy.detached_copy(own_candidate)


func _own_candidate(source: Dictionary, actor_index: int) -> Dictionary:
	var candidate: Dictionary = source.get("own_candidate", {}) \
		if source.get("own_candidate", {}) is Dictionary else {}
	if candidate.is_empty() or int(candidate.get("player_index", -1)) != actor_index:
		return {}
	return candidate.duplicate(true)


func _public_candidate(public_snapshot: Dictionary, subject_index: int) -> Dictionary:
	for entry_variant in public_snapshot.get("audit_entries", []):
		if entry_variant is Dictionary \
				and int((entry_variant as Dictionary).get("player_index", -1)) == subject_index:
			return (entry_variant as Dictionary).duplicate(true)
	return {}


func debug_snapshot() -> Dictionary:
	return {
		"port_ready": is_ready(),
		"capability_revision": _capability_revision,
		"actor_scoped_capability_count": _capabilities_by_actor.size(),
		"query_count": _query_count,
		"rejected_query_count": _rejected_query_count,
		"returns_own_candidate_only": true,
		"returns_own_economic_assets": false,
		"returns_rival_private_audit": false,
		"rival_candidate_requires_public_audit": true,
		"mutates_world": false,
		"consumes_rng": false,
		"references_main": false,
		"owns_state": false,
	}


func _authorized(capability: AiActorVictoryCapability, actor_index: int) -> bool:
	return capability != null \
		and is_ready() \
		and _bound_actor_roster_revision == _actor_roster_revision() \
		and _capabilities_by_actor.get(actor_index) == capability \
		and actor_index >= 0 \
		and actor_index < _world().players.size() \
		and _world().players[actor_index] is Dictionary \
		and (bool((_world().players[actor_index] as Dictionary).get("is_ai", false)) \
			or str((_world().players[actor_index] as Dictionary).get("seat_type", "human")) == "ai")


func _ai_player_indices() -> Array:
	var result: Array = []
	if _world() != null:
		for actor_index in range(_world().players.size()):
			var actor: Dictionary = _world().players[actor_index] \
				if _world().players[actor_index] is Dictionary else {}
			if bool(actor.get("is_ai", false)) or str(actor.get("seat_type", "human")) == "ai":
				result.append(actor_index)
	return result


func _actor_roster_revision() -> String:
	var roster_identity: Array = []
	if _world() != null:
		for actor_index_variant in _ai_player_indices():
			var actor_index := int(actor_index_variant)
			var actor := _world().players[actor_index] as Dictionary
			roster_identity.append([
				actor_index,
				str(actor.get("actor_id", actor.get("id", actor_index))),
				str(actor.get("seat_type", "ai")),
			])
	return JSON.stringify([
		"ai_actor_victory_roster_v1",
		_session_identity_revision(),
		roster_identity,
	]).sha256_text()


func _session_identity_revision() -> String:
	var summary := _game_session().session_summary() if _game_session() != null else {}
	return JSON.stringify([
		"ai_actor_victory_session_identity_v1",
		str(summary.get("ruleset_id", "")),
		str(summary.get("session_id", "")),
		str(summary.get("scenario_id", "")),
		int(summary.get("seed", 0)),
		summary.get("setup", {}),
	]).sha256_text()


func _reject_binding() -> bool:
	_capabilities_by_actor.clear()
	_capability_binding_initialized = false
	_bound_actor_roster_revision = ""
	_capability_revision += 1
	return false


func _victory() -> VictoryControlRuntimeController:
	return get_node_or_null(victory_control_runtime_controller_path) as VictoryControlRuntimeController


func _public_query() -> AiVictoryPublicQueryPort:
	return get_node_or_null(victory_public_query_port_path) as AiVictoryPublicQueryPort


func _world() -> WorldSessionState:
	return get_node_or_null(world_session_state_path) as WorldSessionState


func _game_session() -> GameSessionRuntimeController:
	return get_node_or_null(game_session_runtime_controller_path) as GameSessionRuntimeController
