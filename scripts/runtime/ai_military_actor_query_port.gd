@tool
extends Node
class_name AiMilitaryActorQueryPort

@export var military_runtime_controller_path: NodePath
@export var military_public_query_port_path: NodePath
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
		if not (token is AiMilitaryActorCapability):
			return _reject_binding()
		var token_id := (token as AiMilitaryActorCapability).get_instance_id()
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
	return _military() != null \
		and _public_query() != null \
		and _public_query().is_ready() \
		and _world() != null \
		and _game_session() != null \
		and _capability_binding_initialized


func actor_roster_snapshot(capability: AiMilitaryActorCapability, actor_index: int) -> Dictionary:
	_query_count += 1
	if not _authorized(capability, actor_index):
		_rejected_query_count += 1
		return {}
	var raw_by_uid: Dictionary = {}
	for unit_variant in _military().roster_snapshot(true):
		if unit_variant is Dictionary:
			var source := unit_variant as Dictionary
			raw_by_uid[int(source.get("uid", 0))] = source
	var roster: Array = []
	for public_variant in _public_query().public_roster_snapshot():
		var row := (public_variant as Dictionary).duplicate(true)
		var raw: Dictionary = raw_by_uid.get(int(row.get("uid", 0)), {}) \
			if raw_by_uid.get(int(row.get("uid", 0)), {}) is Dictionary else {}
		var owner_index := int(raw.get("owner", -1))
		if owner_index == actor_index:
			row["ownership_scope"] = "actor_own"
			row["owner_index"] = actor_index
			row["bound_skill_count"] = (raw.get("bound_skill_names", []) as Array).size() \
				if raw.get("bound_skill_names", []) is Array else 0
		elif bool(raw.get("public_owner_revealed", false)) and owner_index >= 0:
			row["ownership_scope"] = "public_revealed"
			row["public_owner_index"] = owner_index
		else:
			row["ownership_scope"] = "public_unknown"
		roster.append(row)
	var result := {
		"schema_version": 1,
		"visibility_scope": "actor_private",
		"actor_index": actor_index,
		"roster": roster,
		"state_revision": JSON.stringify([
			"ai_military_actor_snapshot_v1",
			actor_index,
			_bound_actor_roster_revision,
			roster,
		]).sha256_text(),
	}
	return TablePresentationPureDataPolicy.detached_copy(result)


func own_unit_by_uid(
	capability: AiMilitaryActorCapability,
	actor_index: int,
	unit_uid: int
) -> Dictionary:
	var snapshot := actor_roster_snapshot(capability, actor_index)
	for unit_variant in snapshot.get("roster", []) as Array:
		var unit := unit_variant as Dictionary
		if int(unit.get("uid", 0)) == unit_uid \
			and str(unit.get("ownership_scope", "")) == "actor_own":
			return unit.duplicate(true)
	return {}


func ready_owned_unit_by_uid(
	capability: AiMilitaryActorCapability,
	actor_index: int,
	unit_uid: int
) -> Dictionary:
	if unit_uid <= 0:
		return {}
	var unit := own_unit_by_uid(capability, actor_index, unit_uid)
	if unit.is_empty() \
			or float(unit.get("remaining_time", 0.0)) <= 0.0 \
			or int(unit.get("hp", 0)) <= 0 \
			or float(unit.get("cooldown_left", 0.0)) > 0.0:
		return {}
	return unit


func debug_snapshot() -> Dictionary:
	return {
		"port_ready": is_ready(),
		"capability_revision": _capability_revision,
		"actor_scoped_capability_count": _capabilities_by_actor.size(),
		"query_count": _query_count,
		"rejected_query_count": _rejected_query_count,
		"returns_own_units_only_as_private": true,
		"returns_rival_hidden_owner": false,
		"returns_rival_private_target": false,
		"mutates_world": false,
		"consumes_rng": false,
		"references_main": false,
		"owns_state": false,
	}


func _authorized(capability: AiMilitaryActorCapability, actor_index: int) -> bool:
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
		"ai_military_actor_roster_v1",
		_session_identity_revision(),
		roster_identity,
	]).sha256_text()


func _session_identity_revision() -> String:
	var summary := _game_session().session_summary() if _game_session() != null else {}
	return JSON.stringify([
		"ai_military_actor_session_identity_v1",
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


func _military() -> MilitaryRuntimeController:
	return get_node_or_null(military_runtime_controller_path) as MilitaryRuntimeController


func _public_query() -> AiMilitaryPublicQueryPort:
	return get_node_or_null(military_public_query_port_path) as AiMilitaryPublicQueryPort


func _world() -> WorldSessionState:
	return get_node_or_null(world_session_state_path) as WorldSessionState


func _game_session() -> GameSessionRuntimeController:
	return get_node_or_null(game_session_runtime_controller_path) as GameSessionRuntimeController
