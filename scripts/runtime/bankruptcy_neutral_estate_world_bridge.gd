@tool
extends Node
class_name BankruptcyNeutralEstateWorldBridge

const PARTICIPANT_ORDER := [
	"card_player_state",
	"commodity_flow",
	"military",
	"monster",
	"region_infrastructure",
]

var _world: Node
var _card_player_state: Node
var _commodity_flow: Node
var _military: Node
var _monster: Node
var _region_infrastructure: Node
var _route_network: Node
var _victory_coordinator: Node


func bind_world(world: Node) -> void:
	_world = world


func set_runtime_dependencies(
	card_player_state: Node,
	commodity_flow: Node,
	military: Node,
	monster: Node,
	region_infrastructure: Node,
	route_network: Node,
	victory_coordinator: Node
) -> void:
	_card_player_state = card_player_state
	_commodity_flow = commodity_flow
	_military = military
	_monster = monster
	_region_infrastructure = region_infrastructure
	_route_network = route_network
	_victory_coordinator = victory_coordinator


func capture_bankruptcy_candidates() -> Array:
	var result: Array = []
	for player_index in range(_players().size()):
		var player_variant: Variant = _players()[player_index]
		if not (player_variant is Dictionary):
			continue
		var player: Dictionary = player_variant
		result.append({
			"player_index": player_index,
			"exact_cash_cents": int(player.get("cash_cents", int(player.get("cash", 0)) * 100)),
			"eliminated": bool(player.get("eliminated", false)),
		})
	return result


func active_player_indices() -> Array:
	var result: Array = []
	for player_index in range(_players().size()):
		var player_variant: Variant = _players()[player_index]
		if player_variant is Dictionary and not bool((player_variant as Dictionary).get("eliminated", false)):
			result.append(player_index)
	return result


func bankruptcy_estate_stage(stage: String, request: Dictionary) -> Dictionary:
	if not ["prepare", "commit", "rollback", "finalize"].has(stage):
		return _stage_failure(stage, "bankruptcy_stage_invalid")
	if not _dependencies_ready():
		return _stage_failure(stage, "bankruptcy_participants_unavailable")
	var participant_ids: Array = PARTICIPANT_ORDER.duplicate()
	if stage == "rollback":
		participant_ids.reverse()
	var counts := _zero_estate_counts()
	var completed: Array = []
	for participant_id_variant in participant_ids:
		var participant_id := str(participant_id_variant)
		var participant := _participant(participant_id)
		var value: Variant = participant.call("bankruptcy_estate_stage", stage, request.duplicate(true))
		var result: Dictionary = (value as Dictionary).duplicate(true) if value is Dictionary else {}
		var success_key := "%sd" % stage if stage != "commit" else "committed"
		if stage == "rollback":
			success_key = "rolled_back"
		if not bool(result.get(success_key, false)):
			if stage in ["prepare", "commit"]:
				_rollback_completed(request, completed)
			return _stage_failure(stage, str(result.get("reason_code", "%s_%s_failed" % [participant_id, stage])))
		completed.append(participant_id)
		_merge_counts(counts, result.get("estate_counts", {}))
	if stage in ["commit", "rollback"] and _route_network != null and _route_network.has_method("refresh_routes"):
		_route_network.call("refresh_routes", true)
	var response := {
		"prepared": stage == "prepare",
		"committed": stage == "commit",
		"rolled_back": stage == "rollback",
		"finalized": stage == "finalize",
		"reason_code": "bankruptcy_estate_%s" % stage,
		"estate_counts": counts,
	}
	return response


func credit_public_wager_pool(amount: int) -> Dictionary:
	if _monster == null or not _monster.has_method("add_public_wager_pool") or amount < 0:
		return {"credited": false, "reason_code": "monster_public_pool_unavailable"}
	var total := int(_monster.call("add_public_wager_pool", amount))
	return {"credited": true, "reason_code": "monster_public_pool_credited", "public_pool_total": total}


func request_last_survivor_victory() -> Dictionary:
	if _victory_coordinator == null or not _victory_coordinator.has_method("resolve_victory_outcome"):
		return {"requested": false, "reason_code": "victory_coordinator_unavailable"}
	var receipt_variant: Variant = _victory_coordinator.call("resolve_victory_outcome", "last_survivor")
	var receipt: Dictionary = (receipt_variant as Dictionary).duplicate(true) if receipt_variant is Dictionary else {}
	return {"requested": not receipt.is_empty(), "reason_code": "last_survivor_requested" if not receipt.is_empty() else "last_survivor_not_resolved"}


func debug_snapshot() -> Dictionary:
	var participant_matrix: Dictionary = {}
	for participant_id_variant in PARTICIPANT_ORDER:
		var participant_id := str(participant_id_variant)
		var participant := _participant(participant_id)
		participant_matrix[participant_id] = participant != null and participant.has_method("bankruptcy_estate_stage")
	return {
		"bridge_ready": _dependencies_ready(),
		"runtime_owner": "none",
		"bridge_role": "bankruptcy_neutral_estate_participant_router",
		"participant_matrix": participant_matrix,
		"owns_rules": false,
		"owns_state": false,
	}


func _rollback_completed(request: Dictionary, completed: Array) -> void:
	var reverse := completed.duplicate()
	reverse.reverse()
	for participant_id_variant in reverse:
		var participant := _participant(str(participant_id_variant))
		if participant != null and participant.has_method("bankruptcy_estate_stage"):
			participant.call("bankruptcy_estate_stage", "rollback", request.duplicate(true))
	if _route_network != null and _route_network.has_method("refresh_routes"):
		_route_network.call("refresh_routes", true)


func _participant(participant_id: String) -> Node:
	match participant_id:
		"card_player_state": return _card_player_state
		"commodity_flow": return _commodity_flow
		"military": return _military
		"monster": return _monster
		"region_infrastructure": return _region_infrastructure
	return null


func _dependencies_ready() -> bool:
	if _world == null or not is_instance_valid(_world):
		return false
	for participant_id_variant in PARTICIPANT_ORDER:
		var participant := _participant(str(participant_id_variant))
		if participant == null or not participant.has_method("bankruptcy_estate_stage"):
			return false
	return true


func _players() -> Array:
	if _world == null or not is_instance_valid(_world):
		return []
	var value: Variant = _world.get("players")
	return value if value is Array else []


func _merge_counts(target: Dictionary, value: Variant) -> void:
	if not (value is Dictionary):
		return
	for key_variant in target.keys():
		var key := str(key_variant)
		target[key] = int(target.get(key, 0)) + maxi(0, int((value as Dictionary).get(key, 0)))


func _zero_estate_counts() -> Dictionary:
	return {
		"hand_cards_removed": 0,
		"goods_removed": 0,
		"military_units_removed": 0,
		"monsters_orphaned": 0,
		"facilities_neutralized": 0,
	}


func _stage_failure(stage: String, reason_code: String) -> Dictionary:
	return {
		"prepared": false,
		"committed": false,
		"rolled_back": false,
		"finalized": false,
		"stage": stage,
		"reason_code": reason_code,
		"estate_counts": _zero_estate_counts(),
	}
