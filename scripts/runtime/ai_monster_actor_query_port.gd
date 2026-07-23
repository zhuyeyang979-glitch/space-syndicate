@tool
extends Node
class_name AiMonsterActorQueryPort

@export var monster_runtime_controller_path: NodePath
@export var monster_public_query_port_path: NodePath
@export var world_session_state_path: NodePath
@export var game_session_runtime_controller_path: NodePath

var _capabilities_by_actor: Dictionary = {}
var _capability_binding_initialized := false
var _bound_actor_roster_revision := ""
var _capability_revision := 0
var _query_count := 0
var _rejected_query_count := 0


func bind_ai_capabilities(capabilities_by_actor: Dictionary) -> bool:
	var expected := _ai_player_indices()
	if capabilities_by_actor.size() != expected.size():
		return _reject_binding()
	var normalized: Dictionary = {}
	var seen_tokens: Dictionary = {}
	for actor_index_variant in expected:
		var actor_index := int(actor_index_variant)
		var token: Variant = capabilities_by_actor.get(actor_index)
		if not (token is AiMonsterActorCapability):
			return _reject_binding()
		var token_id := (token as AiMonsterActorCapability).get_instance_id()
		if seen_tokens.has(token_id):
			return _reject_binding()
		seen_tokens[token_id] = true
		normalized[actor_index] = token
	_capabilities_by_actor = normalized
	_capability_binding_initialized = true
	_bound_actor_roster_revision = _actor_roster_revision()
	_capability_revision += 1
	return true


func is_ready() -> bool:
	return _monster() != null \
		and _public_query() != null \
		and _public_query().is_ready() \
		and _world() != null \
		and _game_session() != null \
		and _capability_binding_initialized


func actor_roster_snapshot(capability: AiMonsterActorCapability, actor_index: int) -> Dictionary:
	_query_count += 1
	if not _authorized(capability, actor_index):
		_rejected_query_count += 1
		return {}
	var raw_by_uid: Dictionary = {}
	for actor_variant in _monster().roster_snapshot(true):
		if actor_variant is Dictionary:
			var source := actor_variant as Dictionary
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
			row["owner_damage_cash_pool"] = maxi(0, int(raw.get("owner_damage_cash_pool", 0)))
			row["owner_damage_cash_total"] = maxi(0, int(raw.get("owner_damage_cash_total", 0)))
		elif bool(raw.get("owner_revealed", false)) and owner_index >= 0:
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
			"ai_monster_actor_snapshot_v1",
			actor_index,
			_bound_actor_roster_revision,
			roster,
		]).sha256_text(),
	}
	return TablePresentationPureDataPolicy.detached_copy(result)


func actor_monster_by_uid(
	capability: AiMonsterActorCapability,
	actor_index: int,
	monster_uid: int
) -> Dictionary:
	var snapshot := actor_roster_snapshot(capability, actor_index)
	for actor_variant in snapshot.get("roster", []) as Array:
		var actor := actor_variant as Dictionary
		if int(actor.get("uid", 0)) == monster_uid:
			return actor.duplicate(true)
	return {}


func own_active_monster_count(capability: AiMonsterActorCapability, actor_index: int) -> int:
	var result := 0
	var snapshot := actor_roster_snapshot(capability, actor_index)
	for actor_variant in snapshot.get("roster", []) as Array:
		var actor := actor_variant as Dictionary
		if str(actor.get("ownership_scope", "")) == "actor_own" and not bool(actor.get("down", false)):
			result += 1
	return result


func wager_decision_snapshot(
	capability: AiMonsterActorCapability,
	actor_index: int,
	wager_id: int
) -> Dictionary:
	_query_count += 1
	if not _authorized(capability, actor_index):
		_rejected_query_count += 1
		return {}
	var result := _monster().monster_wager_decision_snapshot_for_actor(wager_id, actor_index)
	if not TablePresentationPureDataPolicy.is_pure_data(result):
		_rejected_query_count += 1
		return {}
	return TablePresentationPureDataPolicy.detached_copy(result)


func debug_snapshot() -> Dictionary:
	return {
		"port_ready": is_ready(),
		"capability_revision": _capability_revision,
		"actor_scoped_capability_count": _capabilities_by_actor.size(),
		"query_count": _query_count,
		"rejected_query_count": _rejected_query_count,
		"returns_own_hidden_owner_only": true,
		"returns_rival_hidden_owner": false,
		"returns_rival_owner_damage_cash_pool": false,
		"returns_rival_wager_commitment": false,
		"mutates_world": false,
		"consumes_rng": false,
		"references_main": false,
		"owns_state": false,
	}


func _authorized(capability: AiMonsterActorCapability, actor_index: int) -> bool:
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
	var session := _game_session().session_summary() if _game_session() != null else {}
	return JSON.stringify([
		"ai_monster_actor_roster_v1",
		str(session.get("session_id", "")),
		int(session.get("revision", session.get("session_revision", 0))),
		roster_identity,
	]).sha256_text()


func _reject_binding() -> bool:
	_capabilities_by_actor.clear()
	_capability_binding_initialized = false
	_bound_actor_roster_revision = ""
	_capability_revision += 1
	return false


func _monster() -> MonsterRuntimeController:
	return get_node_or_null(monster_runtime_controller_path) as MonsterRuntimeController


func _public_query() -> AiMonsterPublicQueryPort:
	return get_node_or_null(monster_public_query_port_path) as AiMonsterPublicQueryPort


func _world() -> WorldSessionState:
	return get_node_or_null(world_session_state_path) as WorldSessionState


func _game_session() -> GameSessionRuntimeController:
	return get_node_or_null(game_session_runtime_controller_path) as GameSessionRuntimeController