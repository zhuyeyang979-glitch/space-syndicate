@tool
extends Node
class_name AiCardQueueQueryPort

const FORBIDDEN_PUBLIC_KEYS := [
	"player_index",
	"slot_index",
	"actor_index",
	"actor_id",
	"ai_utility_score",
	"ai_reason",
	"ai_counter_response",
	"counter_target_resolution_id",
	"counter_target_card",
	"counter_threat_score",
	"counter_opportunity_cost",
	"counter_reason_key",
	"counter_source_card",
	"target_owner",
	"leader_index",
]
const PUBLIC_QUEUE_ENTRY_KEYS := [
	"resolution_id",
	"card_name",
	"card_kind",
	"selected_district",
	"group_id",
	"group_order",
	"group_size",
	"group_position",
	"queued_behind_resolution",
]
const PUBLIC_CARD_FACT_KEYS := [
	"name",
	"kind",
	"hand_discard_count",
	"hand_steal_count",
	"hand_lock_seconds",
	"production_delta",
	"transport_delta",
	"consumption_delta",
	"route_damage",
	"global_barrage_route_damage",
	"military_strike_route_damage",
	"damage",
	"global_barrage_damage",
	"control_gdp_penalty",
	"revenue_amount",
	"contract_income",
	"repair_routes",
	"route_flow_multiplier",
	"hp",
	"fixed_skill_count",
	"lure_speedup",
	"global_barrage_target_count",
	"weather_zone_count",
]

@export var card_resolution_queue_runtime_service_path: NodePath
@export var card_resolution_runtime_controller_path: NodePath
@export var card_play_eligibility_runtime_service_path: NodePath
@export var world_session_state_path: NodePath
@export var game_session_runtime_controller_path: NodePath

var _capabilities_by_actor: Dictionary = {}
var _capability_binding_authority: AiCapabilityBindingAuthority
var _capability_binding_initialized := false
var _bound_actor_roster_revision := ""
var _capability_revision := 0
var _public_query_count := 0
var _private_query_count := 0
var _rejected_query_count := 0


func bind_ai_capabilities(
	binding_authority: AiCapabilityBindingAuthority,
	capabilities_by_actor: Dictionary
) -> bool:
	if binding_authority == null or (_capability_binding_authority != null and _capability_binding_authority != binding_authority):
		return false
	var expected_actor_indices := _ai_player_indices()
	if capabilities_by_actor.size() != expected_actor_indices.size():
		return _reject_capability_binding()
	var normalized: Dictionary = {}
	var seen_tokens: Dictionary = {}
	for actor_index_variant in expected_actor_indices:
		var actor_index := int(actor_index_variant)
		var capability_variant: Variant = capabilities_by_actor.get(actor_index)
		if not (capability_variant is AiCardQueueCapability):
			return _reject_capability_binding()
		var token_id := (capability_variant as AiCardQueueCapability).get_instance_id()
		if seen_tokens.has(token_id):
			return _reject_capability_binding()
		seen_tokens[token_id] = true
		normalized[actor_index] = capability_variant
	_capability_binding_authority = binding_authority
	_capabilities_by_actor = normalized
	_capability_binding_initialized = true
	_bound_actor_roster_revision = _actor_roster_revision()
	_capability_revision += 1
	return true


func is_ready() -> bool:
	return _queue() != null \
		and _card_resolution() != null \
		and _eligibility() != null \
		and _world() != null \
		and _game_session() != null \
		and _capability_binding_initialized


func public_resolution_snapshot() -> Dictionary:
	_public_query_count += 1
	if not is_ready():
		_rejected_query_count += 1
		return {}
	var queue := _queue()
	var source := queue.public_snapshot()
	var result := {
		"schema_version": 1,
		"visibility_scope": "public",
		"current": _public_entries(source.get("current", []), queue.current_queue()),
		"active": _public_entry(
			_dictionary(source.get("active", {})),
			queue.active_entry()
		),
		"next": _public_entries(source.get("next", []), queue.next_queue()),
		"current_count": maxi(0, int(source.get("current_count", 0))),
		"active_present": bool(source.get("active_present", false)),
		"next_count": maxi(0, int(source.get("next_count", 0))),
	}
	result["state_revision"] = JSON.stringify(["ai_card_queue_public_v1", result]).sha256_text()
	if not TablePresentationPureDataPolicy.is_pure_data(result) or _contains_forbidden_public_key(result):
		_rejected_query_count += 1
		return {}
	return TablePresentationPureDataPolicy.detached_copy(result)


func public_window_snapshot() -> Dictionary:
	_public_query_count += 1
	if not is_ready():
		_rejected_query_count += 1
		return {}
	var controller := _card_resolution()
	var result := {
		"schema_version": 1,
		"visibility_scope": "public",
		"auction_open": controller.auction_open,
		"batch_locked": controller.batch_locked,
		"counter_window_active": controller.counter_window_active,
		"phase": controller.current_phase(),
	}
	result["state_revision"] = JSON.stringify(["ai_card_window_public_v1", result]).sha256_text()
	if not TablePresentationPureDataPolicy.is_pure_data(result):
		_rejected_query_count += 1
		return {}
	return TablePresentationPureDataPolicy.detached_copy(result)


func private_actor_submission_snapshot(
	capability: AiCardQueueCapability,
	actor_index: int
) -> Dictionary:
	_private_query_count += 1
	if not _authorized(capability, actor_index):
		_rejected_query_count += 1
		return {}
	var queue := _queue()
	var current_index := queue.entry_index_for_player(actor_index, false)
	var next_index := queue.entry_index_for_player(actor_index, true)
	var active_entry := queue.active_entry()
	var has_active_submission := int(active_entry.get("player_index", -1)) == actor_index
	var active_resolution_id := _resolution_id(active_entry) if has_active_submission else -1
	var current_resolution_id := _resolution_id_at(queue.current_queue(), current_index)
	var next_resolution_id := _resolution_id_at(queue.next_queue(), next_index)
	var queue_debug := queue.debug_snapshot()
	var actor := _world().players[actor_index] as Dictionary
	var result := {
		"schema_version": 1,
		"visibility_scope": "actor_private",
		"actor_index": actor_index,
		"actor_id": str(actor.get("actor_id", actor.get("id", "player:%d" % actor_index))),
		"has_active_submission": has_active_submission,
		"active_resolution_id": active_resolution_id,
		"has_current_submission": current_index >= 0,
		"current_resolution_id": current_resolution_id,
		"has_next_submission": next_index >= 0,
		"next_resolution_id": next_resolution_id,
	}
	result["state_revision"] = JSON.stringify([
		"ai_card_queue_private_v1",
		actor_index,
		_bound_actor_roster_revision,
		int(queue_debug.get("revision", 0)),
		active_resolution_id,
		current_resolution_id,
		next_resolution_id,
	]).sha256_text()
	if not TablePresentationPureDataPolicy.is_pure_data(result):
		_rejected_query_count += 1
		return {}
	return TablePresentationPureDataPolicy.detached_copy(result)


func debug_snapshot() -> Dictionary:
	return {
		"port_ready": is_ready(),
		"capability_revision": _capability_revision,
		"actor_scoped_capability_count": _capabilities_by_actor.size(),
		"public_query_count": _public_query_count,
		"private_query_count": _private_query_count,
		"rejected_query_count": _rejected_query_count,
		"returns_public_queue_only": true,
		"returns_public_window_state": true,
		"returns_actor_submission_identity_only": true,
		"returns_rival_submission_identity": false,
		"returns_private_entry": false,
		"returns_ai_metadata": false,
		"mutates_queue": false,
		"consumes_rng": false,
		"references_main": false,
	}


func _public_entries(public_entries_variant: Variant, private_entries: Array) -> Array:
	var public_entries: Array = public_entries_variant if public_entries_variant is Array else []
	var result: Array = []
	for public_entry_variant in public_entries:
		if not (public_entry_variant is Dictionary):
			continue
		var public_entry := public_entry_variant as Dictionary
		var private_entry := _entry_for_resolution_id(
			private_entries,
			int(public_entry.get("resolution_id", -1))
		)
		var projected := _public_entry(public_entry, private_entry)
		if not projected.is_empty():
			result.append(projected)
	return result


func _public_entry(public_entry: Dictionary, private_entry: Dictionary) -> Dictionary:
	if public_entry.is_empty() or private_entry.is_empty():
		return {}
	var resolution_id := int(public_entry.get("resolution_id", -1))
	if resolution_id < 0 or _resolution_id(private_entry) != resolution_id:
		return {}
	var skill := _dictionary(private_entry.get("skill", {}))
	var card_facts := _public_card_facts(skill)
	var target_status := _eligibility().target_status(
		{"skill": card_facts},
		{"player_count": _world().players.size(), "monster_count": 0}
	)
	var result: Dictionary = {}
	for key in PUBLIC_QUEUE_ENTRY_KEYS:
		if public_entry.has(key):
			result[key] = public_entry[key]
	result["card_facts"] = card_facts
	result["card_label"] = str(public_entry.get("card_name", ""))
	result["is_counter"] = bool(target_status.get("is_counter", false))
	result["counterable_player_interaction"] = bool(
		target_status.get("counterable_player_interaction", false)
	)
	result["counterable"] = not bool(result["is_counter"]) \
		and bool(result["counterable_player_interaction"]) \
		and not bool(private_entry.get("countered", false))
	result["target_player"] = int(private_entry.get("target_player", -1))
	result["target_monster_uid"] = int(private_entry.get("target_monster_uid", -1))
	result["selected_trade_product"] = str(private_entry.get("selected_trade_product", ""))
	return result


func _public_card_facts(skill: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key in PUBLIC_CARD_FACT_KEYS:
		if skill.has(key):
			result[key] = skill[key]
	return result


func _entry_for_resolution_id(entries: Array, resolution_id: int) -> Dictionary:
	if resolution_id < 0:
		return {}
	for entry_variant in entries:
		if entry_variant is Dictionary and _resolution_id(entry_variant as Dictionary) == resolution_id:
			return (entry_variant as Dictionary).duplicate(true)
	return {}


func _authorized(capability: AiCardQueueCapability, actor_index: int) -> bool:
	return capability != null \
		and is_ready() \
		and _bound_actor_roster_revision == _actor_roster_revision() \
		and _capabilities_by_actor.get(actor_index) == capability \
		and not _game_session().is_finished() \
		and actor_index >= 0 \
		and actor_index < _world().players.size() \
		and _world().players[actor_index] is Dictionary \
		and (
			bool((_world().players[actor_index] as Dictionary).get("is_ai", false))
			or str((_world().players[actor_index] as Dictionary).get("seat_type", "human")) == "ai"
		)


func _resolution_id_at(entries: Array, index: int) -> int:
	if index < 0 or index >= entries.size() or not (entries[index] is Dictionary):
		return -1
	return _resolution_id(entries[index] as Dictionary)


func _resolution_id(entry: Dictionary) -> int:
	return int(entry.get("resolution_id", entry.get("queued_order", -1)))


func _contains_forbidden_public_key(value: Variant) -> bool:
	if value is Dictionary:
		for key_variant in (value as Dictionary).keys():
			if FORBIDDEN_PUBLIC_KEYS.has(str(key_variant)) \
					or _contains_forbidden_public_key((value as Dictionary)[key_variant]):
				return true
	elif value is Array:
		for child in value as Array:
			if _contains_forbidden_public_key(child):
				return true
	return false


func _ai_player_indices() -> Array:
	var result: Array = []
	if _world() == null:
		return result
	for actor_index in range(_world().players.size()):
		if _world().players[actor_index] is Dictionary \
				and (
					bool((_world().players[actor_index] as Dictionary).get("is_ai", false))
					or str((_world().players[actor_index] as Dictionary).get("seat_type", "human")) == "ai"
				):
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
				str(actor.get("id", actor_index)),
				str(actor.get("name", "")),
				str(actor.get("seat_type", "ai")),
			])
	return JSON.stringify(["ai_card_queue_actor_roster_v1", roster_identity]).sha256_text()


func _reject_capability_binding() -> bool:
	_capabilities_by_actor.clear()
	_capability_binding_initialized = false
	_bound_actor_roster_revision = ""
	_capability_revision += 1
	return false


func _dictionary(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _queue() -> CardResolutionQueueRuntimeService:
	return get_node_or_null(card_resolution_queue_runtime_service_path) as CardResolutionQueueRuntimeService


func _card_resolution() -> CardResolutionRuntimeController:
	return get_node_or_null(card_resolution_runtime_controller_path) as CardResolutionRuntimeController


func _eligibility() -> CardPlayEligibilityRuntimeService:
	return get_node_or_null(card_play_eligibility_runtime_service_path) as CardPlayEligibilityRuntimeService


func _world() -> WorldSessionState:
	return get_node_or_null(world_session_state_path) as WorldSessionState


func _game_session() -> GameSessionRuntimeController:
	return get_node_or_null(game_session_runtime_controller_path) as GameSessionRuntimeController
