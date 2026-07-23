@tool
extends Node
class_name AiCardHandQueryPort

const CardFlowPolicy := preload("res://scripts/cards/v06/card_flow_policy_v06.gd")

@export var world_session_state_path: NodePath
@export var game_session_runtime_controller_path: NodePath

var _capabilities_by_actor: Dictionary = {}
var _capability_binding_initialized := false
var _bound_actor_roster_revision := ""
var _capability_revision := 0
var _query_count := 0
var _rejected_query_count := 0


func bind_ai_capabilities(capabilities_by_actor: Dictionary) -> bool:
	var expected_actor_indices := _ai_player_indices()
	if capabilities_by_actor.size() != expected_actor_indices.size():
		return _reject_capability_binding()
	var normalized: Dictionary = {}
	var seen_tokens: Dictionary = {}
	for actor_index_variant in expected_actor_indices:
		var actor_index := int(actor_index_variant)
		var capability_variant: Variant = capabilities_by_actor.get(actor_index)
		if not (capability_variant is AiCardHandCapability):
			return _reject_capability_binding()
		var token_id := (capability_variant as AiCardHandCapability).get_instance_id()
		if seen_tokens.has(token_id):
			return _reject_capability_binding()
		seen_tokens[token_id] = true
		normalized[actor_index] = capability_variant
	_capabilities_by_actor = normalized
	_capability_binding_initialized = true
	_bound_actor_roster_revision = _actor_roster_revision()
	_capability_revision += 1
	return true


func is_ready() -> bool:
	return _world() != null and _game_session() != null and _capability_binding_initialized


func private_hand_snapshot(capability: AiCardHandCapability, actor_index: int) -> Dictionary:
	_query_count += 1
	if not _authorized(capability, actor_index):
		_rejected_query_count += 1
		return {}
	var actor := _world().players[actor_index] as Dictionary
	var slots: Array = (actor.get("slots", []) as Array).duplicate(true) \
		if actor.get("slots", []) is Array else []
	var discard: Array = (actor.get("discard", []) as Array).duplicate(true) \
		if actor.get("discard", []) is Array else []
	var discarded_cards: Array = (actor.get("discarded_cards", []) as Array).duplicate(true) \
		if actor.get("discarded_cards", []) is Array else []
	var inventory := {"hand_limit": CardFlowPolicyV06.HAND_LIMIT, "slots": slots.duplicate(true)}
	var discardable := CardFlowPolicy.new().discardable_counted_slots(inventory)
	var snapshot := {
		"actor_index": actor_index,
		"actor_id": str(actor.get("actor_id", actor.get("id", "player:%d" % actor_index))),
		"visibility_scope": "actor_private",
		"state_revision": _state_revision(actor_index, actor),
		"action_cooldown": maxf(0.0, float(actor.get("action_cooldown", 0.0))),
		"slots": slots,
		"discard": discard,
		"discarded_cards": discarded_cards,
		"counted_hand_size": _counted_hand_size(slots),
		"discardable_slots": discardable.duplicate(),
		"hand_limit": CardFlowPolicyV06.HAND_LIMIT,
	}
	if not TablePresentationPureDataPolicy.is_pure_data(snapshot):
		_rejected_query_count += 1
		return {}
	return TablePresentationPureDataPolicy.detached_copy(snapshot)


func debug_snapshot() -> Dictionary:
	return {
		"port_ready": is_ready(),
		"capability_revision": _capability_revision,
		"actor_scoped_capability_count": _capabilities_by_actor.size(),
		"capabilities_are_actor_scoped": true,
		"query_count": _query_count,
		"rejected_query_count": _rejected_query_count,
		"returns_cash": false,
		"returns_rival_hand": false,
		"returns_whole_players": false,
		"mutates_world": false,
		"consumes_rng": false,
		"references_main": false,
	}


func _authorized(capability: AiCardHandCapability, actor_index: int) -> bool:
	return capability != null \
		and is_ready() \
		and _bound_actor_roster_revision == _actor_roster_revision() \
		and _capabilities_by_actor.get(actor_index) == capability \
		and not _game_session().is_finished() \
		and actor_index >= 0 \
		and actor_index < _world().players.size() \
		and _world().players[actor_index] is Dictionary \
		and (bool((_world().players[actor_index] as Dictionary).get("is_ai", false)) \
			or str((_world().players[actor_index] as Dictionary).get("seat_type", "human")) == "ai")


func _ai_player_indices() -> Array:
	var result: Array = []
	if _world() == null:
		return result
	for actor_index in range(_world().players.size()):
		if _world().players[actor_index] is Dictionary \
				and (bool((_world().players[actor_index] as Dictionary).get("is_ai", false)) \
				or str((_world().players[actor_index] as Dictionary).get("seat_type", "human")) == "ai"):
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
				str(actor.get("id", actor_index)),
				str(actor.get("name", "")),
				str(actor.get("seat_type", "ai")),
			])
	return JSON.stringify(["ai_card_hand_actor_roster_v1", roster_identity]).sha256_text()


func _state_revision(actor_index: int, actor: Dictionary) -> String:
	return JSON.stringify([
		"ai_card_hand_snapshot_v1",
		actor_index,
		_bound_actor_roster_revision,
		actor.get("action_cooldown", 0.0),
		actor.get("slots", []),
		actor.get("discard", []),
		actor.get("discarded_cards", []),
	]).sha256_text()


func _counted_hand_size(slots: Array) -> int:
	var result := 0
	for slot_variant in slots:
		if not (slot_variant is Dictionary):
			continue
		var card := slot_variant as Dictionary
		var machine: Dictionary = card.get("machine", {}) if card.get("machine", {}) is Dictionary else {}
		if bool(machine.get("counts_toward_hand_limit", true)):
			result += 1
	return result


func _reject_capability_binding() -> bool:
	_capabilities_by_actor.clear()
	_capability_binding_initialized = false
	_bound_actor_roster_revision = ""
	_capability_revision += 1
	return false


func _world() -> WorldSessionState:
	return get_node_or_null(world_session_state_path) as WorldSessionState


func _game_session() -> GameSessionRuntimeController:
	return get_node_or_null(game_session_runtime_controller_path) as GameSessionRuntimeController
