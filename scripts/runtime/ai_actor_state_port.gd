@tool
extends Node
class_name AiActorStatePort

const PUBLIC_PLAYER_KEYS := [
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

@export var world_session_state_path: NodePath

var _capability: AiActorStateCapability
var _capability_revision := 0
var _public_query_count := 0
var _private_query_count := 0
var _state_commit_count := 0
var _duplicate_commit_count := 0
var _rejected_query_count := 0
var _rejected_commit_count := 0


func bind_ai_capability(capability: AiActorStateCapability) -> void:
	_capability = capability
	_capability_revision += 1


func is_ready() -> bool:
	return _world() != null and _capability != null


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


func private_actor_snapshot(
	capability: AiActorStateCapability,
	player_index: int
) -> Dictionary:
	_private_query_count += 1
	if not _authorized(capability, player_index):
		_rejected_query_count += 1
		return {}
	var source := _world().players[player_index] as Dictionary
	var result := _allowlist(source, PUBLIC_PLAYER_KEYS + PRIVATE_ACTOR_KEYS)
	result["player_index"] = player_index
	result["public_player_name"] = str(source.get("name", "玩家%d" % (player_index + 1)))
	result["state_revision"] = _state_revision(source)
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
	if not _authorized(capability, player_index) or not _exact_patch(patch):
		_rejected_commit_count += 1
		return _commit_receipt(false, false, "ai_actor_state_commit_rejected", player_index, "", "")
	var players := _world().players
	var source := (players[player_index] as Dictionary).duplicate(true)
	var before_revision := _state_revision(source)
	if not expected_revision.is_empty() and expected_revision != before_revision:
		_rejected_commit_count += 1
		return _commit_receipt(false, false, "ai_actor_state_revision_changed", player_index, before_revision, before_revision)
	var next_profile := (patch.get("ai_profile", {}) as Dictionary).duplicate(true)
	var next_memory := (patch.get("ai_memory", {}) as Dictionary).duplicate(true)
	if not _pure(next_profile) or not _pure(next_memory):
		_rejected_commit_count += 1
		return _commit_receipt(false, false, "ai_actor_state_not_pure_data", player_index, before_revision, before_revision)
	var changed: bool = source.get("ai_profile", {}) != next_profile or source.get("ai_memory", {}) != next_memory
	if not changed:
		_duplicate_commit_count += 1
		return _commit_receipt(true, false, "ai_actor_state_unchanged", player_index, before_revision, before_revision)
	source["ai_profile"] = next_profile
	source["ai_memory"] = next_memory
	players[player_index] = source
	_world().players = players
	_state_commit_count += 1
	return _commit_receipt(true, true, "ai_actor_state_committed", player_index, before_revision, _state_revision(source))


func debug_snapshot() -> Dictionary:
	return {
		"port_ready": is_ready(),
		"capability_revision": _capability_revision,
		"public_query_count": _public_query_count,
		"private_query_count": _private_query_count,
		"state_commit_count": _state_commit_count,
		"duplicate_commit_count": _duplicate_commit_count,
		"rejected_query_count": _rejected_query_count,
		"rejected_commit_count": _rejected_commit_count,
		"public_snapshot_exposes_cash": false,
		"public_snapshot_exposes_hand": false,
		"public_snapshot_exposes_ai_memory": false,
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


func _state_revision(source: Dictionary) -> String:
	return JSON.stringify([
		source.get("ai_profile", {}),
		source.get("ai_memory", {}),
	]).sha256_text()


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
