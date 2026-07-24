@tool
extends Node
class_name AiActorEconomyFactsQueryPort

const SCHEMA_VERSION := 1
const VISIBILITY_SCOPE := "actor_private"
const DECISION_FACT_KEYS := [
	"schema_version",
	"session_id",
	"session_revision",
	"source_revision",
	"fingerprint",
	"visibility_scope",
	"actor_index",
	"available_cash_cents",
	"available_cash_units",
	"action_cooldown_seconds",
	"action_ready",
]
const TRAINING_FACT_KEYS := [
	"schema_version",
	"session_id",
	"session_revision",
	"source_revision",
	"fingerprint",
	"visibility_scope",
	"actor_index",
	"total_cash_cents",
	"total_cash_units",
	"cities_built",
	"total_city_income_units",
	"total_card_income_units",
	"total_role_income_units",
	"total_card_spend_units",
	"total_build_spend_units",
	"total_business_spend_units",
]
const TRAINING_COUNTER_FIELDS := [
	"cities_built",
	"total_city_income",
	"total_card_income",
	"total_role_income",
	"total_card_spend",
	"total_build_spend",
	"total_business_spend",
]

@export var world_session_state_path: NodePath
@export var game_session_runtime_controller_path: NodePath
@export var ai_actor_state_port_path: NodePath
@export var cash_commitment_query_port_path: NodePath

var _capability: AiActorEconomyFactsCapability
var _capability_revision := 0
var _capability_bind_rejection_count := 0
var _restore_epoch := 0
var _bound_world: WorldSessionState


func _ready() -> void:
	_bind_world_lifecycle()


func bind_ai_capability(capability: AiActorEconomyFactsCapability) -> bool:
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
	return (
		_capability != null
		and _world() != null
		and _session() != null
		and _actor_state_port() != null
		and _cash_query_port() != null
		and _cash_query_port().is_ready()
	)


func actor_decision_facts(
	capability: AiActorEconomyFactsCapability,
	actor_index: int
) -> Dictionary:
	var source := _authorized_source(capability, actor_index)
	if source.is_empty():
		return {}
	var availability := source.get("availability", {}) as Dictionary
	var player := source.get("player", {}) as Dictionary
	var cooldown_variant: Variant = player.get("action_cooldown", 0.0)
	if not (cooldown_variant is int or cooldown_variant is float):
		return {}
	var cooldown := float(cooldown_variant)
	if not is_finite(cooldown) or cooldown < 0.0:
		return {}
	var source_revision := JSON.stringify([
		"ai_actor_economy_decision_source_v1",
		source.get("session_id", ""),
		source.get("session_revision", -1),
		_restore_epoch,
		actor_index,
		availability.get("availability_fingerprint", ""),
		cooldown,
	]).sha256_text()
	var result := {
		"schema_version": SCHEMA_VERSION,
		"session_id": str(source.get("session_id", "")),
		"session_revision": int(source.get("session_revision", -1)),
		"source_revision": source_revision,
		"fingerprint": "",
		"visibility_scope": VISIBILITY_SCOPE,
		"actor_index": actor_index,
		"available_cash_cents": int(availability.get("available_cents", 0)),
		"available_cash_units": floori(
			float(int(availability.get("available_cents", 0)))
			/ float(WorldSessionState.CASH_CENTS_PER_UNIT)
		),
		"action_cooldown_seconds": cooldown,
		"action_ready": cooldown <= 0.0,
	}
	result["fingerprint"] = JSON.stringify([
		"ai_actor_economy_decision_row_v1",
		source_revision,
		actor_index,
		result.get("available_cash_cents", 0),
		cooldown,
	]).sha256_text()
	if not _exact_keys(result, DECISION_FACT_KEYS) or not _pure(result):
		return {}
	return result.duplicate(true)


func actor_training_economy_facts(
	capability: AiActorEconomyFactsCapability,
	actor_index: int
) -> Dictionary:
	var source := _authorized_source(capability, actor_index)
	if source.is_empty():
		return {}
	var availability := source.get("availability", {}) as Dictionary
	var player := source.get("player", {}) as Dictionary
	var counters := _training_counters(player)
	if counters.size() != TRAINING_COUNTER_FIELDS.size():
		return {}
	var total_cents := int(availability.get("total_cents", 0))
	var source_revision := JSON.stringify([
		"ai_actor_economy_training_source_v1",
		source.get("session_id", ""),
		source.get("session_revision", -1),
		_restore_epoch,
		actor_index,
		total_cents,
		counters,
	]).sha256_text()
	var result := {
		"schema_version": SCHEMA_VERSION,
		"session_id": str(source.get("session_id", "")),
		"session_revision": int(source.get("session_revision", -1)),
		"source_revision": source_revision,
		"fingerprint": "",
		"visibility_scope": VISIBILITY_SCOPE,
		"actor_index": actor_index,
		"total_cash_cents": total_cents,
		"total_cash_units": floori(
			float(total_cents) / float(WorldSessionState.CASH_CENTS_PER_UNIT)
		),
		"cities_built": int(counters.get("cities_built", 0)),
		"total_city_income_units": int(counters.get("total_city_income", 0)),
		"total_card_income_units": int(counters.get("total_card_income", 0)),
		"total_role_income_units": int(counters.get("total_role_income", 0)),
		"total_card_spend_units": int(counters.get("total_card_spend", 0)),
		"total_build_spend_units": int(counters.get("total_build_spend", 0)),
		"total_business_spend_units": int(counters.get("total_business_spend", 0)),
	}
	result["fingerprint"] = JSON.stringify([
		"ai_actor_economy_training_row_v1",
		source_revision,
		actor_index,
		total_cents,
		counters,
	]).sha256_text()
	if not _exact_keys(result, TRAINING_FACT_KEYS) or not _pure(result):
		return {}
	return result.duplicate(true)


func is_current_decision_facts(
	capability: AiActorEconomyFactsCapability,
	snapshot: Dictionary
) -> bool:
	if not _exact_keys(snapshot, DECISION_FACT_KEYS) or not _pure(snapshot):
		return false
	var current := actor_decision_facts(
		capability,
		int(snapshot.get("actor_index", -1))
	)
	return not current.is_empty() and current == snapshot


func is_current_training_economy_facts(
	capability: AiActorEconomyFactsCapability,
	snapshot: Dictionary
) -> bool:
	if not _exact_keys(snapshot, TRAINING_FACT_KEYS) or not _pure(snapshot):
		return false
	var current := actor_training_economy_facts(
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
		"stores_cash": false,
		"stores_wager_commitments": false,
		"stores_action_cooldown": false,
		"stores_training_counters": false,
		"owns_save_section": false,
		"public_snapshot_provider": false,
		"exposes_rival_private_facts": false,
		"exposes_hand_or_inventory": false,
		"references_main": false,
	}


func _authorized_source(
	capability: AiActorEconomyFactsCapability,
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
		or int(actor.get("session_revision", -1)) != int(session_context.get("session_revision", -2))
	):
		return {}
	var world := _world()
	if (
		actor_index < 0
		or actor_index >= world.players.size()
		or not (world.players[actor_index] is Dictionary)
	):
		return {}
	var availability := _cash_query_port().private_cash_availability_projection(actor_index)
	if (
		not bool(availability.get("valid", false))
		or int(availability.get("player_index", -1)) != actor_index
		or int(availability.get("total_cents", -1)) < 0
		or int(availability.get("reserved_cents", -1)) < 0
		or int(availability.get("available_cents", -1)) < 0
		or int(availability.get("total_cents", -1))
			!= int(availability.get("reserved_cents", 0))
			+ int(availability.get("available_cents", 0))
	):
		return {}
	return {
		"session_id": str(session_context.get("session_id", "")),
		"session_revision": int(session_context.get("session_revision", -1)),
		"player": world.players[actor_index],
		"availability": availability,
	}


func _session_context() -> Dictionary:
	var session := _session()
	if session == null:
		return {}
	var summary := session.session_summary()
	var session_id := str(summary.get("session_id", "")).strip_edges()
	if (
		session_id.is_empty()
		or str(summary.get("session_state", ""))
			!= GameSessionRuntimeController.STATE_RUNNING
	):
		return {}
	return {
		"session_id": session_id,
		"session_revision": session.session_start_revision(),
	}


func _training_counters(player: Dictionary) -> Dictionary:
	var result := {}
	for field_variant in TRAINING_COUNTER_FIELDS:
		var field := str(field_variant)
		if not player.has(field):
			result[field] = 0
			continue
		var value: Variant = player.get(field)
		if not (value is int) or int(value) < 0:
			return {}
		result[field] = int(value)
	return result


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


func _world() -> WorldSessionState:
	return get_node_or_null(world_session_state_path) as WorldSessionState


func _session() -> GameSessionRuntimeController:
	return get_node_or_null(
		game_session_runtime_controller_path
	) as GameSessionRuntimeController


func _actor_state_port() -> AiActorStatePort:
	return get_node_or_null(ai_actor_state_port_path) as AiActorStatePort


func _cash_query_port() -> MonsterWagerCashCommitmentQueryPort:
	return get_node_or_null(
		cash_commitment_query_port_path
	) as MonsterWagerCashCommitmentQueryPort
