@tool
extends Node
class_name AiActorStatePort

signal ai_capability_refresh_requested()

const PUBLIC_PLAYER_KEYS := [
	"name",
	"seat_type",
	"is_ai",
	"role_index",
	"eliminated",
	"eliminated_at",
	"elimination_reason",
]
const AI_STATE_PATCH_KEYS := ["ai_profile", "ai_memory"]
const AI_STATE_BATCH_ROW_KEYS := ["player_index", "ai_profile", "ai_memory", "expected_revision"]
const AI_STATE_SNAPSHOT_KEYS := [
	"name",
	"seat_type",
	"is_ai",
	"role_index",
	"eliminated",
	"eliminated_at",
	"elimination_reason",
	"ai_profile",
	"ai_memory",
]

@export var world_session_state_path: NodePath

var _capabilities_by_actor: Dictionary = {}
var _capability_binding_initialized := false
var _capability_revision := 0
var _public_query_count := 0
var _ai_state_query_count := 0
var _state_commit_count := 0
var _duplicate_commit_count := 0
var _batch_commit_count := 0
var _batch_rollback_count := 0
var _rejected_query_count := 0
var _rejected_commit_count := 0
var _restore_epoch := 0
var _actor_state_write_in_progress := false
var _bound_world: WorldSessionState


func _ready() -> void:
	_bind_world_lifecycle()


func bind_ai_capabilities(capabilities_by_actor: Dictionary) -> bool:
	_bind_world_lifecycle()
	var expected_actor_indices := ai_player_indices(true)
	expected_actor_indices.sort()
	if capabilities_by_actor.size() != expected_actor_indices.size():
		return _reject_capability_binding()
	var normalized: Dictionary = {}
	var seen_tokens: Dictionary = {}
	for actor_index_variant in expected_actor_indices:
		if not (actor_index_variant is int) or not capabilities_by_actor.has(actor_index_variant):
			return _reject_capability_binding()
		var actor_index := int(actor_index_variant)
		var capability_variant: Variant = capabilities_by_actor[actor_index_variant]
		if actor_index < 0 or not (capability_variant is AiActorStateCapability):
			return _reject_capability_binding()
		var token_id := (capability_variant as AiActorStateCapability).get_instance_id()
		if seen_tokens.has(token_id):
			return _reject_capability_binding()
		seen_tokens[token_id] = true
		normalized[actor_index] = capability_variant
	_capabilities_by_actor = normalized
	_capability_binding_initialized = true
	_capability_revision += 1
	return true


func is_ready() -> bool:
	return _world() != null and _capability_binding_initialized


func player_count() -> int:
	_public_query_count += 1
	return _world().players.size() if _world() != null else 0


func public_players_snapshot() -> Array:
	_public_query_count += 1
	var result: Array = []
	if _world() == null:
		return result
	for player_index in range(_world().players.size()):
		var source: Dictionary = _world().players[player_index] \
			if _world().players[player_index] is Dictionary else {}
		var row := _allowlist(source, PUBLIC_PLAYER_KEYS)
		row["player_index"] = player_index
		row["public_player_name"] = str(source.get("name", "玩家%d" % (player_index + 1)))
		var role: Dictionary = source.get("role_card", {}) \
			if source.get("role_card", {}) is Dictionary else {}
		row["role_name"] = str(role.get("name", ""))
		if _pure(row):
			result.append(_copy(row))
	return result


func public_player_snapshot(player_index: int) -> Dictionary:
	for row_variant in public_players_snapshot():
		if row_variant is Dictionary and int((row_variant as Dictionary).get("player_index", -1)) == player_index:
			return (row_variant as Dictionary).duplicate(true)
	return {}


func is_ai_player(player_index: int) -> bool:
	var row := public_player_snapshot(player_index)
	return bool(row.get("is_ai", false)) or str(row.get("seat_type", "human")) == "ai"


func is_player_eliminated(player_index: int) -> bool:
	var row := public_player_snapshot(player_index)
	return row.is_empty() or bool(row.get("eliminated", false))


func ai_player_indices(include_eliminated := false) -> Array:
	var result: Array = []
	for row_variant in public_players_snapshot():
		if not (row_variant is Dictionary):
			continue
		var row := row_variant as Dictionary
		if not (bool(row.get("is_ai", false)) or str(row.get("seat_type", "human")) == "ai"):
			continue
		if not include_eliminated and bool(row.get("eliminated", false)):
			continue
		result.append(int(row.get("player_index", -1)))
	return result


func ai_actor_state_snapshot(
	capability: AiActorStateCapability,
	player_index: int
) -> Dictionary:
	_ai_state_query_count += 1
	var snapshot := _private_snapshot(capability, player_index, AI_STATE_SNAPSHOT_KEYS)
	if snapshot.is_empty() \
			or not (snapshot.get("ai_profile") is Dictionary) \
			or not (snapshot.get("ai_memory") is Dictionary) \
			or not _safe_state_payload(snapshot.get("ai_profile")) \
			or not _safe_state_payload(snapshot.get("ai_memory")):
		_rejected_query_count += 1
		return {}
	snapshot["state_generation"] = _restore_epoch
	return snapshot


func capture_ai_state_batch(
	capabilities_by_actor: Dictionary,
	include_eliminated := true
) -> Array:
	var receipt := capture_ai_state_batch_receipt(capabilities_by_actor, include_eliminated)
	return (receipt.get("rows", []) as Array).duplicate(true) \
		if bool(receipt.get("captured", false)) else []


func capture_ai_state_batch_receipt(
	capabilities_by_actor: Dictionary,
	include_eliminated := true
) -> Dictionary:
	_bind_world_lifecycle()
	var actor_indices := ai_player_indices(include_eliminated)
	if not is_ready() or not _batch_authorized(capabilities_by_actor, actor_indices):
		_rejected_query_count += 1
		return {
			"captured": false,
			"reason_code": "ai_actor_state_capture_unauthorized",
			"rows": [],
			"actor_indices": [],
		}
	var result: Array = []
	for player_index_variant in actor_indices:
		var player_index := int(player_index_variant)
		var snapshot := ai_actor_state_snapshot(
			capabilities_by_actor.get(player_index) as AiActorStateCapability,
			player_index
		)
		if snapshot.is_empty():
			return {
				"captured": false,
				"reason_code": "ai_actor_state_capture_incomplete",
				"rows": [],
				"actor_indices": actor_indices.duplicate(),
			}
		result.append({
			"player_index": player_index,
			"ai_profile": (snapshot.get("ai_profile", {}) as Dictionary).duplicate(true),
			"ai_memory": (snapshot.get("ai_memory", {}) as Dictionary).duplicate(true),
			"expected_revision": str(snapshot.get("state_revision", "")),
		})
	return {
		"captured": result.size() == actor_indices.size(),
		"reason_code": "ai_actor_state_captured",
		"rows": result,
		"actor_indices": actor_indices.duplicate(),
	}


func apply_ai_state_batch(
	capabilities_by_actor: Dictionary,
	rows: Array
) -> Dictionary:
	_bind_world_lifecycle()
	var expected_actor_indices := ai_player_indices(true)
	expected_actor_indices.sort()
	if not is_ready() or not _batch_authorized(capabilities_by_actor, expected_actor_indices):
		_rejected_commit_count += 1
		return _batch_receipt(false, false, "ai_actor_state_batch_unauthorized", 0)
	if not _pure(rows):
		_rejected_commit_count += 1
		return _batch_receipt(false, false, "ai_actor_state_batch_invalid", 0)
	if rows.is_empty():
		if not expected_actor_indices.is_empty():
			_rejected_commit_count += 1
			return _batch_receipt(false, false, "ai_actor_state_batch_roster_mismatch", 0)
		return _batch_receipt(true, false, "ai_actor_state_batch_unchanged", 0)
	var seen_indices: Dictionary = {}
	var normalized_rows: Array = []
	for row_variant in rows:
		if not (row_variant is Dictionary):
			_rejected_commit_count += 1
			return _batch_receipt(false, false, "ai_actor_state_batch_invalid", 0)
		var row := row_variant as Dictionary
		if not _exact_batch_row(row):
			_rejected_commit_count += 1
			return _batch_receipt(false, false, "ai_actor_state_batch_invalid", 0)
		var player_index := int(row.get("player_index", -1))
		var actor_capability := capabilities_by_actor.get(player_index) as AiActorStateCapability
		if seen_indices.has(player_index) or not _authorized(actor_capability, player_index):
			_rejected_commit_count += 1
			return _batch_receipt(false, false, "ai_actor_state_batch_unauthorized", 0)
		seen_indices[player_index] = true
		var source := _world().players[player_index] as Dictionary
		if str(row.get("expected_revision", "")) != _state_revision(source, player_index):
			_rejected_commit_count += 1
			return _batch_receipt(false, false, "ai_actor_state_batch_revision_changed", 0)
		var profile := (row.get("ai_profile", {}) as Dictionary).duplicate(true)
		var memory := (row.get("ai_memory", {}) as Dictionary).duplicate(true)
		if not _safe_state_payload(profile) or not _safe_state_payload(memory):
			_rejected_commit_count += 1
			return _batch_receipt(false, false, "ai_actor_state_batch_not_serializable", 0)
		normalized_rows.append({
			"player_index": player_index,
			"ai_profile": profile,
			"ai_memory": memory,
		})
	var provided_actor_indices := seen_indices.keys()
	provided_actor_indices.sort()
	if provided_actor_indices != expected_actor_indices:
		_rejected_commit_count += 1
		return _batch_receipt(false, false, "ai_actor_state_batch_roster_mismatch", 0)
	var next_players := _world().players.duplicate(true)
	var changed_count := 0
	for row_variant in normalized_rows:
		var row := row_variant as Dictionary
		var player_index := int(row.get("player_index", -1))
		var source := (next_players[player_index] as Dictionary).duplicate(true)
		var profile := row.get("ai_profile", {}) as Dictionary
		var memory := row.get("ai_memory", {}) as Dictionary
		if source.get("ai_profile", {}) == profile and source.get("ai_memory", {}) == memory:
			continue
		source["ai_profile"] = profile.duplicate(true)
		source["ai_memory"] = memory.duplicate(true)
		next_players[player_index] = source
		changed_count += 1
	if changed_count > 0:
		_actor_state_write_in_progress = true
		_world().players = next_players
		_actor_state_write_in_progress = false
		_state_commit_count += changed_count
		_batch_commit_count += 1
	else:
		_duplicate_commit_count += rows.size()
	return _batch_receipt(true, changed_count > 0, "ai_actor_state_batch_committed" if changed_count > 0 else "ai_actor_state_batch_unchanged", changed_count)


func _private_snapshot(
	capability: AiActorStateCapability,
	player_index: int,
	keys: Array
) -> Dictionary:
	if not _authorized(capability, player_index):
		_rejected_query_count += 1
		return {}
	var source := _world().players[player_index] as Dictionary
	var result := _allowlist(source, keys)
	result["player_index"] = player_index
	result["public_player_name"] = str(source.get("name", "玩家%d" % (player_index + 1)))
	result["state_revision"] = _state_revision(source, player_index)
	result["visibility_scope"] = "actor_private"
	if not _pure(result):
		_rejected_query_count += 1
		return {}
	return _copy(result)


func commit_ai_state(
	capability: AiActorStateCapability,
	player_index: int,
	patch: Dictionary,
	expected_revision := ""
) -> Dictionary:
	if not _authorized(capability, player_index) or not _exact_patch(patch) or expected_revision.is_empty():
		_rejected_commit_count += 1
		return _commit_receipt(false, false, "ai_actor_state_commit_rejected", player_index, "", "")
	var source := (_world().players[player_index] as Dictionary).duplicate(true)
	var before_revision := _state_revision(source, player_index)
	if not expected_revision.is_empty() and expected_revision != before_revision:
		_rejected_commit_count += 1
		return _commit_receipt(false, false, "ai_actor_state_revision_changed", player_index, before_revision, before_revision)
	var next_profile := (patch.get("ai_profile", {}) as Dictionary).duplicate(true)
	var next_memory := (patch.get("ai_memory", {}) as Dictionary).duplicate(true)
	if not _safe_state_payload(next_profile) or not _safe_state_payload(next_memory):
		_rejected_commit_count += 1
		return _commit_receipt(false, false, "ai_actor_state_not_pure_data", player_index, before_revision, before_revision)
	var changed: bool = source.get("ai_profile", {}) != next_profile or source.get("ai_memory", {}) != next_memory
	if not changed:
		_duplicate_commit_count += 1
		return _commit_receipt(true, false, "ai_actor_state_unchanged", player_index, before_revision, before_revision)
	source["ai_profile"] = next_profile
	source["ai_memory"] = next_memory
	var next_players := _world().players.duplicate(true)
	next_players[player_index] = source
	_actor_state_write_in_progress = true
	_world().players = next_players
	_actor_state_write_in_progress = false
	_state_commit_count += 1
	return _commit_receipt(true, true, "ai_actor_state_committed", player_index, before_revision, _state_revision(source, player_index))


func debug_snapshot() -> Dictionary:
	return {
		"port_ready": is_ready(),
		"capability_revision": _capability_revision,
		"capability_binding_initialized": _capability_binding_initialized,
		"actor_scoped_capability_count": _capabilities_by_actor.size(),
		"public_query_count": _public_query_count,
		"ai_state_query_count": _ai_state_query_count,
		"state_commit_count": _state_commit_count,
		"duplicate_commit_count": _duplicate_commit_count,
		"batch_commit_count": _batch_commit_count,
		"batch_rollback_count": _batch_rollback_count,
		"rejected_query_count": _rejected_query_count,
		"rejected_commit_count": _rejected_commit_count,
		"public_snapshot_exposes_cash": false,
		"public_snapshot_exposes_hand": false,
		"public_snapshot_exposes_ai_memory": false,
		"ai_state_snapshot_exposes_cash": false,
		"ai_state_snapshot_exposes_hand": false,
		"broad_private_actor_snapshot_available": false,
		"capabilities_are_actor_scoped": true,
		"ai_state_commit_requires_revision": true,
		"batch_preflight_before_apply": true,
		"restore_epoch": _restore_epoch,
		"state_generation": _restore_epoch,
		"mutable_world_collection_exposed": false,
		"references_main": false,
	}


func _authorized(capability: AiActorStateCapability, player_index: int) -> bool:
	return capability != null \
		and _capabilities_by_actor.get(player_index) == capability \
		and _world() != null \
		and player_index >= 0 \
		and player_index < _world().players.size() \
		and _world().players[player_index] is Dictionary \
		and (bool((_world().players[player_index] as Dictionary).get("is_ai", false)) \
			or str((_world().players[player_index] as Dictionary).get("seat_type", "human")) == "ai")


func _batch_authorized(capabilities_by_actor: Dictionary, actor_indices: Array) -> bool:
	if capabilities_by_actor.size() != _capabilities_by_actor.size():
		return false
	for actor_index_variant in _capabilities_by_actor:
		var actor_index := int(actor_index_variant)
		if capabilities_by_actor.get(actor_index) != _capabilities_by_actor[actor_index]:
			return false
	for actor_index_variant in actor_indices:
		var actor_index := int(actor_index_variant)
		if not _authorized(capabilities_by_actor.get(actor_index) as AiActorStateCapability, actor_index):
			return false
	return true


func _reject_capability_binding() -> bool:
	_capabilities_by_actor.clear()
	_capability_binding_initialized = false
	_capability_revision += 1
	return false


func _exact_patch(patch: Dictionary) -> bool:
	if patch.size() != AI_STATE_PATCH_KEYS.size():
		return false
	for key in AI_STATE_PATCH_KEYS:
		if not patch.has(key) or not (patch.get(key) is Dictionary):
			return false
	return true


func _exact_batch_row(row: Dictionary) -> bool:
	if row.size() != AI_STATE_BATCH_ROW_KEYS.size():
		return false
	for key in AI_STATE_BATCH_ROW_KEYS:
		if not row.has(key):
			return false
	return row.get("player_index") is int \
		and row.get("ai_profile") is Dictionary \
		and row.get("ai_memory") is Dictionary \
		and row.get("expected_revision") is String \
		and not str(row.get("expected_revision", "")).is_empty()


func _state_revision(source: Dictionary, player_index: int) -> String:
	return JSON.stringify([
		"ai_actor_state_v2",
		player_index,
		_restore_epoch,
		source.get("ai_profile", {}),
		source.get("ai_memory", {}),
	]).sha256_text()


func _safe_state_payload(value: Variant) -> bool:
	return _finite_pure_data(value) \
		and bool(LegacyContractPayloadGuardV06.validation_report(value).get("valid", false))


func _finite_pure_data(value: Variant) -> bool:
	if not _pure(value):
		return false
	if value is float and not is_finite(float(value)):
		return false
	if value is Dictionary:
		for key in (value as Dictionary):
			if not _finite_pure_data(key) or not _finite_pure_data((value as Dictionary)[key]):
				return false
	elif value is Array:
		for item in value as Array:
			if not _finite_pure_data(item):
				return false
	return true


func _commit_receipt(
	accepted: bool,
	changed: bool,
	reason_code: String,
	player_index: int,
	before_revision: String,
	after_revision: String
) -> Dictionary:
	return {
		"accepted": accepted,
		"changed": changed,
		"reason_code": reason_code,
		"player_index": player_index,
		"before_revision": before_revision,
		"after_revision": after_revision,
	}


func _batch_receipt(
	accepted: bool,
	changed: bool,
	reason_code: String,
	changed_count: int
) -> Dictionary:
	return {
		"accepted": accepted,
		"changed": changed,
		"reason_code": reason_code,
		"changed_count": changed_count,
		"rollback_count": _batch_rollback_count,
	}


func _bind_world_lifecycle() -> void:
	var world := _world()
	if world == _bound_world:
		return
	if _bound_world != null and is_instance_valid(_bound_world) \
			and _bound_world.session_restored.is_connected(_on_world_session_restored):
		_bound_world.session_restored.disconnect(_on_world_session_restored)
	if _bound_world != null and is_instance_valid(_bound_world) \
			and _bound_world.players_replaced.is_connected(_on_world_players_replaced):
		_bound_world.players_replaced.disconnect(_on_world_players_replaced)
	_bound_world = world
	if _bound_world != null and not _bound_world.session_restored.is_connected(_on_world_session_restored):
		_bound_world.session_restored.connect(_on_world_session_restored)
	if _bound_world != null and not _bound_world.players_replaced.is_connected(_on_world_players_replaced):
		_bound_world.players_replaced.connect(_on_world_players_replaced)
	_restore_epoch += 1


func _on_world_session_restored(_summary: Dictionary) -> void:
	_restore_epoch += 1


func _on_world_players_replaced(_player_count: int) -> void:
	if not _actor_state_write_in_progress:
		_restore_epoch += 1
		_capabilities_by_actor.clear()
		_capability_binding_initialized = false
		_capability_revision += 1
		ai_capability_refresh_requested.emit()


func _allowlist(source: Dictionary, keys: Array) -> Dictionary:
	var result := {}
	for key_variant in keys:
		var key := str(key_variant)
		if source.has(key) and _pure(source[key]):
			result[key] = _copy(source[key])
	return result


func _copy(value: Variant) -> Variant:
	return TablePresentationPureDataPolicy.detached_copy(value)


func _pure(value: Variant) -> bool:
	return TablePresentationPureDataPolicy.is_pure_data(value)


func _world() -> WorldSessionState:
	return get_node_or_null(world_session_state_path) as WorldSessionState
