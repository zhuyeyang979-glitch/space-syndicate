extends "res://scripts/runtime/game_runtime_coordinator.gd"

const WORLD_SESSION_STATE_SCRIPT := preload("res://scripts/runtime/world_session_state.gd")

var gate_session: Node
var gate_world: WORLD_SESSION_STATE_SCRIPT
var slot_metadata := {
	"slot_state": "ready",
	"can_save": true,
	"can_resume": true,
	"backup_available": false,
	"saved_at_unix": 1,
	"world_time_seconds": 10,
	"seat_count": 4,
	"ruleset_id": "v0.6",
	"mission_title": "",
	"session_state": "running",
}


func _session_node() -> Node:
	return gate_session


func _world_session_state_node() -> WORLD_SESSION_STATE_SCRIPT:
	return gate_world


func _current_public_slot_metadata(_path: String) -> Dictionary:
	return slot_metadata.duplicate(true)


func _production_save_available() -> bool:
	return true
