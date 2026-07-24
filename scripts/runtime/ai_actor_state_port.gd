@tool
extends Node
class_name AiActorStatePort

const PUBLIC_PLAYER_SCHEMA_VERSION := 1
const PUBLIC_PLAYER_VISIBILITY_SCOPE := "public"
const PUBLIC_PLAYER_ROW_KEYS := [
	"schema_version",
	"session_id",
	"session_revision",
	"source_revision",
	"fingerprint",
	"visibility_scope",
	"player_index",
	"public_seat_order",
	"public_player_name",
	"seat_type",
	"is_ai",
	"role_index",
	"role_name",
	"eliminated",
]
const PRIVATE_ACTOR_PUBLIC_KEYS := [
	"name",
	"seat_type",
	"is_ai",
	"role_index",
	"eliminated",
	"eliminated_at",
	"elimination_reason",
]
const PRIVATE_ACTOR_KEYS := [
	"cash",
	"cash_cents",
	"action_cooldown",
	"cities_built",
	"last_cycle_income",
	"last_cashflow_income",
	"cashflow_remainder",
	"total_city_income",
	"total_role_income",
	"total_card_income",
	"total_card_spend",
	"total_build_spend",
	"total_business_spend",
	"city_guesses",
	"city_guess_confidence",
	"city_guess_reasons",
	"known_card_owners",
	"ai_profile",
	"ai_memory",
	"slots",
	"discard",
	"discarded_cards",
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
@export var game_session_runtime_controller_path: NodePath
@export var role_catalog_runtime_service_path: NodePath

var _capability: AiActorStateCapability
var _capability_revision := 0
var _capability_bind_rejection_count := 0
var _private_query_count := 0
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


func bind_ai_capability(capability: AiActorStateCapability) -> bool:
	_bind_world_lifecycle()
	if capability == null:
		_capability_bind_rejection_count += 1
		return false
	if _capability == null:
		_capability = capability
		_capability_revision = 1
		return true
	if capability == _capability:
		return true
	_capability_bind_rejection_count += 1
	return false


func is_ready() -> bool:
	return _public_dependencies_ready() and _capability != null


func player_count() -> int:
	return public_player_count()


func public_player_count() -> int:
	return public_players_snapshot().size()


func human_player_count(include_eliminated := true) -> int:
	var count := 0
	for row_variant in public_players_snapshot():
		var row := row_variant as Dictionary
		if bool(row.get("is_ai", false)):
			continue
		if not include_eliminated and bool(row.get("eliminated", false)):
			continue
		count += 1
	return count


func ai_player_count(include_eliminated := true) -> int:
	return ai_player_indices(include_eliminated).size()


func public_players_snapshot() -> Array:
	var context := _public_context()
	var base_rows := _normalized_public_roster_base()
	if (
		context.is_empty()
		or base_rows.is_empty()
		or _world() == null
		or base_rows.size() != _world().players.size()
	):
		return []
	var roster_fingerprint := JSON.stringify([
		"ai_public_player_roster_v1",
		context.get("session_id", ""),
		context.get("session_revision", -1),
		base_rows,
	]).sha256_text()
	var source_revision := JSON.stringify([
		"ai_public_player_source_v1",
		context.get("session_id", ""),
		context.get("session_revision", -1),
		_restore_epoch,
		roster_fingerprint,
	]).sha256_text()
	var result: Array = []
	for base_variant in base_rows:
		var base := base_variant as Dictionary
		var row := {
			"schema_version": PUBLIC_PLAYER_SCHEMA_VERSION,
			"session_id": str(context.get("session_id", "")),
			"session_revision": int(context.get("session_revision", -1)),
			"source_revision": source_revision,
			"fingerprint": JSON.stringify([
				"ai_public_player_row_v1",
				roster_fingerprint,
				int(base.get("player_index", -1)),
			]).sha256_text(),
			"visibility_scope": PUBLIC_PLAYER_VISIBILITY_SCOPE,
			"player_index": int(base.get("player_index", -1)),
			"public_seat_order": int(base.get("public_seat_order", -1)),
			"public_player_name": str(base.get("public_player_name", "")),
			"seat_type": str(base.get("seat_type", "")),
			"is_ai": bool(base.get("is_ai", false)),
			"role_index": int(base.get("role_index", -1)),
			"role_name": str(base.get("role_name", "")),
			"eliminated": bool(base.get("eliminated", false)),
		}
		if not _exact_keys(row, PUBLIC_PLAYER_ROW_KEYS) or not _pure(row):
			return []
		result.append(_copy(row))
	return result


func public_player_snapshot(player_index: int) -> Dictionary:
	if player_index < 0:
		return {}
	for row_variant in public_players_snapshot():
		var row := row_variant as Dictionary
		if int(row.get("player_index", -1)) == player_index:
			return row.duplicate(true)
	return {}


func is_current_public_player_snapshot(snapshot: Dictionary) -> bool:
	if not _exact_keys(snapshot, PUBLIC_PLAYER_ROW_KEYS) or not _pure(snapshot):
		return false
	var current := public_player_snapshot(int(snapshot.get("player_index", -1)))
	return not current.is_empty() and current == snapshot


func public_player_name(player_index: int) -> String:
	return str(public_player_snapshot(player_index).get("public_player_name", ""))


func public_target_label(player_index: int) -> String:
	return "玩家%d" % (player_index + 1) if not public_player_snapshot(player_index).is_empty() else "未知玩家"


func public_role_definition(player_index: int) -> Dictionary:
	var row := public_player_snapshot(player_index)
	var catalog := _role_catalog()
	if row.is_empty() or catalog == null:
		return {}
	var definition := catalog.public_definition_at(int(row.get("role_index", -1)))
	if definition.is_empty() or str(definition.get("name", "")) != str(row.get("role_name", "")):
		return {}
	definition["role_index"] = int(row.get("role_index", -1))
	definition["role_name"] = str(row.get("role_name", ""))
	definition["visibility_scope"] = PUBLIC_PLAYER_VISIBILITY_SCOPE
	return _copy(definition)


func public_active_target_rows(actor_index: int) -> Array:
	var actor := public_player_snapshot(actor_index)
	if actor.is_empty() or bool(actor.get("eliminated", false)):
		return []
	var result: Array = []
	for row_variant in public_players_snapshot():
		var row := row_variant as Dictionary
		if int(row.get("player_index", -1)) == actor_index or bool(row.get("eliminated", false)):
			continue
		result.append(row.duplicate(true))
	return result


func active_target_player_indices(actor_index: int) -> Array:
	var result: Array = []
	for row_variant in public_active_target_rows(actor_index):
		result.append(int((row_variant as Dictionary).get("player_index", -1)))
	return result


func is_ai_player(player_index: int) -> bool:
	var row := public_player_snapshot(player_index)
	return not row.is_empty() and bool(row.get("is_ai", false))


func is_player_eliminated(player_index: int) -> bool:
	var row := public_player_snapshot(player_index)
	return row.is_empty() or bool(row.get("eliminated", false))


func ai_player_indices(include_eliminated := false) -> Array:
	var result: Array = []
	for row_variant in public_players_snapshot():
		var row := row_variant as Dictionary
		if not bool(row.get("is_ai", false)):
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
	capability: AiActorStateCapability,
	include_eliminated := true
) -> Array:
	var receipt := capture_ai_state_batch_receipt(capability, include_eliminated)
	return (receipt.get("rows", []) as Array).duplicate(true) \
		if bool(receipt.get("captured", false)) else []


func capture_ai_state_batch_receipt(
	capability: AiActorStateCapability,
	include_eliminated := true
) -> Dictionary:
	_bind_world_lifecycle()
	if not is_ready() or capability == null or capability != _capability:
		_rejected_query_count += 1
		return {
			"captured": false,
			"reason_code": "ai_actor_state_capture_unauthorized",
			"rows": [],
			"actor_indices": [],
		}
	var actor_indices := ai_player_indices(include_eliminated)
	var result: Array = []
	for player_index_variant in actor_indices:
		var player_index := int(player_index_variant)
		var snapshot := ai_actor_state_snapshot(capability, player_index)
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
	capability: AiActorStateCapability,
	rows: Array
) -> Dictionary:
	_bind_world_lifecycle()
	if not is_ready() or capability == null or capability != _capability:
		_rejected_commit_count += 1
		return _batch_receipt(false, false, "ai_actor_state_batch_unauthorized", 0)
	if not _pure(rows):
		_rejected_commit_count += 1
		return _batch_receipt(false, false, "ai_actor_state_batch_invalid", 0)
	var expected_actor_indices := ai_player_indices(true)
	expected_actor_indices.sort()
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
		if seen_indices.has(player_index) or not _authorized(capability, player_index):
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


func private_actor_snapshot(
	capability: AiActorStateCapability,
	player_index: int
) -> Dictionary:
	_private_query_count += 1
	return _private_snapshot(capability, player_index, PRIVATE_ACTOR_PUBLIC_KEYS + PRIVATE_ACTOR_KEYS)


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
		"capability_bind_rejection_count": _capability_bind_rejection_count,
		"public_query_count": 0,
		"public_query_literal_zero_mutation": true,
		"public_snapshot_schema_version": PUBLIC_PLAYER_SCHEMA_VERSION,
		"public_snapshot_session_bound": true,
		"private_query_count": _private_query_count,
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
		"public_snapshot_exposes_elimination_details": false,
		"ai_state_snapshot_exposes_cash": false,
		"ai_state_snapshot_exposes_hand": false,
		"ai_state_commit_requires_revision": true,
		"batch_preflight_before_apply": true,
		"restore_epoch": _restore_epoch,
		"state_generation": _restore_epoch,
		"mutable_world_collection_exposed": false,
		"references_main": false,
	}


func _authorized(capability: AiActorStateCapability, player_index: int) -> bool:
	return capability != null \
		and capability == _capability \
		and _world() != null \
		and player_index >= 0 \
		and player_index < _world().players.size() \
		and _world().players[player_index] is Dictionary \
		and (bool((_world().players[player_index] as Dictionary).get("is_ai", false)) \
			or str((_world().players[player_index] as Dictionary).get("seat_type", "human")) == "ai")


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


func _public_dependencies_ready() -> bool:
	return _world() != null and _session() != null and _role_catalog() != null


func _public_context() -> Dictionary:
	var session := _session()
	if not _public_dependencies_ready() or session == null:
		return {}
	var summary := session.session_summary()
	var session_id := str(summary.get("session_id", "")).strip_edges()
	if session_id.is_empty():
		return {}
	return {
		"session_id": session_id,
		"session_revision": session.session_start_revision(),
	}


func _normalized_public_roster_base() -> Array:
	var world := _world()
	var catalog := _role_catalog()
	if world == null or catalog == null:
		return []
	var result: Array = []
	var seen_player_indices: Dictionary = {}
	for player_index in range(world.players.size()):
		var source_variant: Variant = world.players[player_index]
		if not (source_variant is Dictionary):
			return []
		var source := source_variant as Dictionary
		if (
			not source.has("id")
			or not (source.get("id") is int)
			or int(source.get("id", -1)) != player_index
			or seen_player_indices.has(player_index)
		):
			return []
		seen_player_indices[player_index] = true
		if (
			not source.has("name")
			or not (source.get("name") is String)
			or str(source.get("name", "")).strip_edges().is_empty()
		):
			return []
		if (
			not source.has("seat_type")
			or not (source.get("seat_type") is String)
			or str(source.get("seat_type", "")) not in ["human", "ai"]
			or not source.has("is_ai")
			or not (source.get("is_ai") is bool)
			or bool(source.get("is_ai", false)) != (str(source.get("seat_type", "")) == "ai")
		):
			return []
		if (
			not source.has("role_index")
			or not (source.get("role_index") is int)
			or not source.has("role_card")
			or not (source.get("role_card") is Dictionary)
		):
			return []
		var role_index := int(source.get("role_index", -1))
		var role_card := source.get("role_card", {}) as Dictionary
		var role_definition := catalog.public_definition_at(role_index)
		if (
			role_definition.is_empty()
			or int(role_card.get("role_index", -1)) != role_index
			or str(role_card.get("name", "")) != str(role_definition.get("name", ""))
		):
			return []
		if (
			not source.has("eliminated")
			or not (source.get("eliminated") is bool)
		):
			return []
		result.append({
			"player_index": player_index,
			"public_seat_order": player_index,
			"public_player_name": str(source.get("name", "")),
			"seat_type": str(source.get("seat_type", "")),
			"is_ai": bool(source.get("is_ai", false)),
			"role_index": role_index,
			"role_name": str(role_definition.get("name", "")),
			"eliminated": bool(source.get("eliminated", false)),
		})
	return result


func _exact_keys(value: Dictionary, keys: Array) -> bool:
	if value.size() != keys.size():
		return false
	for key_variant in keys:
		if not value.has(str(key_variant)):
			return false
	return true


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


func _session() -> GameSessionRuntimeController:
	return get_node_or_null(game_session_runtime_controller_path) as GameSessionRuntimeController


func _role_catalog() -> RoleCatalogRuntimeService:
	return get_node_or_null(role_catalog_runtime_service_path) as RoleCatalogRuntimeService


func _world() -> WorldSessionState:
	return get_node_or_null(world_session_state_path) as WorldSessionState
