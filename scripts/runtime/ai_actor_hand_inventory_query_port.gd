@tool
extends Node
class_name AiActorHandInventoryQueryPort

const SCHEMA_VERSION := 1
const VISIBILITY_SCOPE := "actor_private"
const SNAPSHOT_KEYS := [
	"schema_version",
	"session_id",
	"session_revision",
	"source_revision",
	"fingerprint",
	"visibility_scope",
	"actor_index",
	"hand_limit",
	"counted_hand_size",
	"discardable_slot_indices",
	"slots",
]
const SLOT_KEYS := [
	"slot_index",
	"occupied",
	"card_id",
	"runtime_instance_id",
	"family_id",
	"rank",
	"kind",
	"counts_toward_hand_limit",
	"persistent",
	"queued_for_resolution",
	"cooldown_left",
	"lock_left",
	"card",
]
const EXTRA_FORBIDDEN_CARD_KEYS := [
	"actor_index",
	"ai_memory",
	"cash_cents",
	"city_guesses",
	"decision_samples",
	"opponent_slots",
	"player_index",
	"rival_hand",
	"save_payload",
]

@export var world_session_state_path: NodePath
@export var game_session_runtime_controller_path: NodePath
@export var ai_actor_state_port_path: NodePath
@export var card_inventory_runtime_service_path: NodePath

var _capability: AiActorHandInventoryCapability
var _capability_revision := 0
var _capability_bind_rejection_count := 0
var _restore_epoch := 0
var _bound_world: WorldSessionState


func _ready() -> void:
	_bind_world_lifecycle()


func bind_ai_capability(capability: AiActorHandInventoryCapability) -> bool:
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
	var inventory := _card_inventory_service()
	return (
		_capability != null
		and _world() != null
		and _session() != null
		and _actor_state_port() != null
		and inventory != null
		and inventory.is_ready()
	)


func actor_hand_snapshot(
	capability: AiActorHandInventoryCapability,
	actor_index: int
) -> Dictionary:
	_bind_world_lifecycle()
	var source := _authorized_source(capability, actor_index)
	if source.is_empty():
		return {}
	var player := source.get("player", {}) as Dictionary
	var slots_variant: Variant = player.get("slots", [])
	if not (slots_variant is Array):
		return {}
	var hand_limit := _card_inventory_service().ordinary_hand_limit()
	if hand_limit <= 0:
		return {}
	var slot_entries := _slot_entries(slots_variant as Array)
	if slot_entries.is_empty() and not (slots_variant as Array).is_empty():
		return {}
	var inventory_facts := {"slots": slot_entries}
	var counted_hand_size := _card_inventory_service().counted_hand_size(inventory_facts)
	if counted_hand_size < 0:
		return {}
	if counted_hand_size > hand_limit:
		return {}
	var discardable := _card_inventory_service().discardable_slots(inventory_facts)
	var source_revision := JSON.stringify([
		"ai_actor_hand_inventory_source_v1",
		source.get("session_id", ""),
		source.get("session_revision", -1),
		_restore_epoch,
		actor_index,
		hand_limit,
		slot_entries,
	]).sha256_text()
	var result := {
		"schema_version": SCHEMA_VERSION,
		"session_id": str(source.get("session_id", "")),
		"session_revision": int(source.get("session_revision", -1)),
		"source_revision": source_revision,
		"fingerprint": "",
		"visibility_scope": VISIBILITY_SCOPE,
		"actor_index": actor_index,
		"hand_limit": hand_limit,
		"counted_hand_size": counted_hand_size,
		"discardable_slot_indices": discardable.duplicate(),
		"slots": slot_entries.duplicate(true),
	}
	result["fingerprint"] = JSON.stringify([
		"ai_actor_hand_inventory_row_v1",
		source_revision,
		actor_index,
		counted_hand_size,
		discardable,
	]).sha256_text()
	if not _exact_keys(result, SNAPSHOT_KEYS) or not _pure(result):
		return {}
	return result.duplicate(true)


func is_current_snapshot(
	capability: AiActorHandInventoryCapability,
	snapshot: Dictionary
) -> bool:
	if not _exact_keys(snapshot, SNAPSHOT_KEYS) or not _pure(snapshot):
		return false
	var current := actor_hand_snapshot(
		capability,
		int(snapshot.get("actor_index", -1))
	)
	return not current.is_empty() and current == snapshot


func debug_snapshot() -> Dictionary:
	return {
		"port_ready": is_ready(),
		"schema_version": SCHEMA_VERSION,
		"capability_revision": _capability_revision,
		"capability_bind_rejection_count": _capability_bind_rejection_count,
		"restore_epoch": _restore_epoch,
		"query_literal_zero_mutation": true,
		"stores_hand_or_inventory": false,
		"stores_discard": false,
		"owns_save_section": false,
		"public_snapshot_provider": false,
		"exposes_rival_private_facts": false,
		"references_main": false,
	}


func _authorized_source(
	capability: AiActorHandInventoryCapability,
	actor_index: int
) -> Dictionary:
	if capability == null or capability != _capability or not is_ready():
		return {}
	var session_context := _session_context()
	if session_context.is_empty():
		return {}
	var actor := _actor_state_port().public_player_snapshot(actor_index)
	if (
		actor.is_empty()
		or not bool(actor.get("is_ai", false))
		or bool(actor.get("eliminated", false))
		or str(actor.get("session_id", "")) != str(session_context.get("session_id", ""))
		or int(actor.get("session_revision", -1))
			!= int(session_context.get("session_revision", -2))
	):
		return {}
	var world := _world()
	if (
		actor_index < 0
		or actor_index >= world.players.size()
		or not (world.players[actor_index] is Dictionary)
	):
		return {}
	return {
		"session_id": str(session_context.get("session_id", "")),
		"session_revision": int(session_context.get("session_revision", -1)),
		"player": world.players[actor_index],
	}


func _slot_entries(slots: Array) -> Array:
	var result: Array = []
	for slot_index in range(slots.size()):
		var slot_variant: Variant = slots[slot_index]
		if slot_variant == null:
			result.append(_empty_slot(slot_index))
			continue
		if not (slot_variant is Dictionary) or not _pure(slot_variant) \
				or _contains_forbidden_card_key(slot_variant):
			return []
		var card := (slot_variant as Dictionary).duplicate(true)
		var cooldown_variant: Variant = card.get("cooldown_left", 0.0)
		var lock_variant: Variant = card.get("lock_left", 0.0)
		if not (cooldown_variant is int or cooldown_variant is float) \
				or not (lock_variant is int or lock_variant is float):
			return []
		var cooldown := float(cooldown_variant)
		var lock_left := float(lock_variant)
		if not is_finite(cooldown) or not is_finite(lock_left) \
				or cooldown < 0.0 or lock_left < 0.0:
			return []
		var machine: Dictionary = card.get("machine", {}) \
			if card.get("machine", {}) is Dictionary else {}
		var card_id := str(card.get(
			"name",
			card.get("card_id", machine.get("card_id", ""))
		)).strip_edges()
		if card_id.is_empty():
			return []
		var kind := str(card.get("kind", machine.get("category_id", "")))
		var persistent := bool(card.get("persistent", false))
		var counts_toward_limit := _card_inventory_service() \
			.card_counts_toward_hand_limit(card)
		var entry := {
			"slot_index": slot_index,
			"occupied": true,
			"card_id": card_id,
			"runtime_instance_id": str(card.get("runtime_instance_id", "")),
			"family_id": str(card.get(
				"family_id",
				card.get("family", machine.get("family_id", card_id))
			)),
			"rank": maxi(1, int(card.get("rank", machine.get("rank", 1)))),
			"kind": kind,
			"counts_toward_hand_limit": counts_toward_limit,
			"persistent": persistent,
			"queued_for_resolution": bool(card.get("queued_for_resolution", false)),
			"cooldown_left": cooldown,
			"lock_left": lock_left,
			"card": card,
		}
		if not _exact_keys(entry, SLOT_KEYS):
			return []
		result.append(entry)
	return result


func _empty_slot(slot_index: int) -> Dictionary:
	return {
		"slot_index": slot_index,
		"occupied": false,
		"card_id": "",
		"runtime_instance_id": "",
		"family_id": "",
		"rank": 0,
		"kind": "",
		"counts_toward_hand_limit": false,
		"persistent": false,
		"queued_for_resolution": false,
		"cooldown_left": 0.0,
		"lock_left": 0.0,
		"card": {},
	}


func _session_context() -> Dictionary:
	var session := _session()
	if session == null:
		return {}
	var summary := session.session_summary()
	var session_id := str(summary.get("session_id", "")).strip_edges()
	if session_id.is_empty() or str(summary.get("session_state", "")) \
			!= GameSessionRuntimeController.STATE_RUNNING:
		return {}
	return {
		"session_id": session_id,
		"session_revision": session.session_start_revision(),
	}


func _bind_world_lifecycle() -> void:
	var world := _world()
	if world == _bound_world:
		return
	if (
		_bound_world != null
		and is_instance_valid(_bound_world)
		and _bound_world.session_restored.is_connected(_on_world_session_restored)
	):
		_bound_world.session_restored.disconnect(_on_world_session_restored)
	_bound_world = world
	if (
		_bound_world != null
		and not _bound_world.session_restored.is_connected(_on_world_session_restored)
	):
		_bound_world.session_restored.connect(_on_world_session_restored)
	_restore_epoch += 1


func _on_world_session_restored(_summary: Dictionary) -> void:
	_restore_epoch += 1


func _exact_keys(value: Dictionary, expected: Array) -> bool:
	if value.size() != expected.size():
		return false
	for key_variant in expected:
		if not value.has(str(key_variant)):
			return false
	return true


func _pure(value: Variant) -> bool:
	return TablePresentationPureDataPolicy.is_pure_data(value)


func _contains_forbidden_card_key(value: Variant) -> bool:
	if value is Dictionary:
		for key_variant in (value as Dictionary).keys():
			var key := str(key_variant).strip_edges().to_lower()
			if CardRuntimeKindSchema.FORBIDDEN_RUNTIME_FIELDS.has(key) \
					or EXTRA_FORBIDDEN_CARD_KEYS.has(key):
				return true
			if _contains_forbidden_card_key((value as Dictionary)[key_variant]):
				return true
	elif value is Array:
		for item_variant in value as Array:
			if _contains_forbidden_card_key(item_variant):
				return true
	return false


func _world() -> WorldSessionState:
	return get_node_or_null(world_session_state_path) as WorldSessionState


func _session() -> GameSessionRuntimeController:
	return get_node_or_null(game_session_runtime_controller_path) \
		as GameSessionRuntimeController


func _actor_state_port() -> AiActorStatePort:
	return get_node_or_null(ai_actor_state_port_path) as AiActorStatePort


func _card_inventory_service() -> CardInventoryRuntimeService:
	return get_node_or_null(card_inventory_runtime_service_path) \
		as CardInventoryRuntimeService
