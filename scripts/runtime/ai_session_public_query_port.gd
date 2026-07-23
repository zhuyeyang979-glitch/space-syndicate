@tool
extends Node
class_name AiSessionPublicQueryPort

const SNAPSHOT_FIELDS := [
	"session_id",
	"session_revision",
	"session_state",
	"session_finished",
	"world_effective_time",
	"game_time",
	"business_cycle_revision",
	"player_count",
	"district_count",
	"map_width_m",
	"map_height_m",
	"challenge_depth",
	"active_resolution_present",
	"public_phase",
]

@export var world_session_state_path: NodePath
@export var game_session_runtime_controller_path: NodePath
@export var world_effective_clock_path: NodePath
@export var product_market_runtime_controller_path: NodePath
@export var card_resolution_runtime_controller_path: NodePath
@export var card_resolution_queue_path: NodePath

var _query_count := 0
var _rejected_query_count := 0


func is_ready() -> bool:
	return _world() != null \
		and _game_session() != null \
		and _world_clock() != null \
		and _product_market() != null \
		and _card_resolution() != null \
		and _card_resolution_queue() != null


func public_snapshot() -> Dictionary:
	_query_count += 1
	if not is_ready():
		_rejected_query_count += 1
		return {}
	var session := _game_session().session_summary()
	var setup: Dictionary = session.get("setup", {}) if session.get("setup", {}) is Dictionary else {}
	var market := _product_market().public_market_snapshot()
	var active_resolution := _card_resolution_queue().active_entry()
	var snapshot := {
		"session_id": str(session.get("session_id", "")),
		"session_revision": _game_session().session_start_revision(),
		"session_state": str(session.get("session_state", GameSessionRuntimeController.STATE_IDLE)),
		"session_finished": _game_session().is_finished(),
		"world_effective_time": _world_clock().world_effective_seconds(),
		"game_time": _world().game_time,
		"business_cycle_revision": int(market.get("market_revision", 0)),
		"player_count": _world().players.size(),
		"district_count": _world().districts.size(),
		"map_width_m": _world().map_width_m,
		"map_height_m": _world().map_height_m,
		"challenge_depth": _challenge_depth(setup),
		"active_resolution_present": not active_resolution.is_empty(),
		"public_phase": _card_resolution().current_phase(),
	}
	if snapshot.keys().size() != SNAPSHOT_FIELDS.size() or not _has_exact_fields(snapshot) \
			or not TablePresentationPureDataPolicy.is_pure_data(snapshot):
		_rejected_query_count += 1
		return {}
	return TablePresentationPureDataPolicy.detached_copy(snapshot)


func debug_snapshot() -> Dictionary:
	return {
		"port_ready": is_ready(),
		"query_count": _query_count,
		"rejected_query_count": _rejected_query_count,
		"snapshot_fields": SNAPSHOT_FIELDS.duplicate(),
		"returns_whole_players": false,
		"returns_whole_districts": false,
		"returns_nodes": false,
		"mutates_world": false,
		"consumes_rng": false,
		"references_main": false,
	}


func _challenge_depth(setup: Dictionary) -> int:
	var explicit_depth := int(setup.get("challenge_depth", 0))
	if explicit_depth > 0:
		return explicit_depth
	match str(setup.get("difficulty", "")):
		"深度II": return 2
		"深度III": return 3
		_: return 1


func _has_exact_fields(snapshot: Dictionary) -> bool:
	for field_variant in SNAPSHOT_FIELDS:
		if not snapshot.has(str(field_variant)):
			return false
	return true


func _world() -> WorldSessionState:
	return get_node_or_null(world_session_state_path) as WorldSessionState


func _game_session() -> GameSessionRuntimeController:
	return get_node_or_null(game_session_runtime_controller_path) as GameSessionRuntimeController


func _world_clock() -> WorldEffectiveClockRuntimeController:
	return get_node_or_null(world_effective_clock_path) as WorldEffectiveClockRuntimeController


func _product_market() -> ProductMarketRuntimeController:
	return get_node_or_null(product_market_runtime_controller_path) as ProductMarketRuntimeController


func _card_resolution() -> CardResolutionRuntimeController:
	return get_node_or_null(card_resolution_runtime_controller_path) as CardResolutionRuntimeController


func _card_resolution_queue() -> CardResolutionQueueRuntimeService:
	return get_node_or_null(card_resolution_queue_path) as CardResolutionQueueRuntimeService
