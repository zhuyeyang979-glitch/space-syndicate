@tool
extends Node
class_name MonsterMoveCommandSink

var _authority: SimulationMutationAuthority
var _monster: MonsterRuntimeController
var _applied_command_ids: Dictionary = {}
var _mutation_count := 0
var _rejected_count := 0


func configure(authority: SimulationMutationAuthority, monster: MonsterRuntimeController) -> void:
	_authority = authority
	_monster = monster


func is_ready() -> bool:
	return _authority != null and _monster != null


func apply_command(command: Dictionary, _envelope: Dictionary = {}) -> Dictionary:
	if not is_ready():
		return _reject("monster_move_dependencies_unavailable")
	var command_id := str(command.get("command_id", "")).strip_edges()
	if command_id.is_empty():
		return _reject("monster_move_command_id_missing")
	if _applied_command_ids.has(command_id):
		return _reject("monster_move_duplicate_command")
	var authorization := _authority.authorize_mutation({
		"command_type": String(RuntimeCommandEnvelope.TYPE_MONSTER_MOVE),
		"command_id": command_id,
		"source": str(command.get("source", "monster_ai")),
	})
	if not bool(authorization.get("authorized", false)):
		return _reject(str(authorization.get("reason", "monster_move_unauthorized")))
	var target_uid := int(command.get("actor_uid", -1))
	var before := _monster.simulation_mutation_snapshot_by_uid(target_uid)
	if before.is_empty():
		return _reject("monster_move_actor_unavailable")
	var mutation := _monster.apply_autonomous_move_command(command)
	if not bool(mutation.get("accepted", false)):
		return _reject(str(mutation.get("reason", "monster_move_mutation_rejected")))
	var after := _monster.simulation_mutation_snapshot_by_uid(target_uid)
	if after.is_empty():
		return _reject("monster_move_postimage_unavailable")
	var mutation_command := command.duplicate(true)
	mutation_command["command_type"] = String(RuntimeCommandEnvelope.TYPE_MONSTER_MOVE)
	var audit := _authority.record_mutation(mutation_command, before, after, {
		"domain": "monster",
		"mutation_kind": "autonomous_move_%s" % str(command.get("operation", "")),
		"target_key": "monster:%d" % target_uid,
		"outcome": "applied",
		"moved": float(mutation.get("moved", 0.0)),
		"arrived": bool(mutation.get("arrived", false)),
	})
	if not bool(audit.get("recorded", false)):
		return _reject(str(audit.get("reason", "monster_move_audit_rejected")))
	_applied_command_ids[command_id] = true
	while _applied_command_ids.size() > 128:
		_applied_command_ids.erase(_applied_command_ids.keys()[0])
	_mutation_count += 1
	return {
		"handled": true,
		"accepted": true,
		"reason": "",
		"actor_uid": target_uid,
		"operation": str(command.get("operation", "")),
		"moved": float(mutation.get("moved", 0.0)),
		"planned_distance": float(mutation.get("planned_distance", 0.0)),
		"arrived": bool(mutation.get("arrived", false)),
		"mutation_audit": audit,
	}


func debug_snapshot() -> Dictionary:
	return {
		"ready": is_ready(),
		"mutation_count": _mutation_count,
		"rejected_count": _rejected_count,
		"applied_command_count": _applied_command_ids.size(),
		"owns_monster_state": false,
		"owns_world_state": false,
		"uses_main": false,
	}


func _reject(reason: String) -> Dictionary:
	_rejected_count += 1
	return {"handled": false, "accepted": false, "reason": reason}
