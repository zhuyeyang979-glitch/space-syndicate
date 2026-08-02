extends Node

const RULESET_PROFILE := preload("res://resources/rules/space_syndicate_ruleset_v06.tres")

@onready var _routes: RouteNetworkRuntimeController = $RouteNetworkRuntimeController
@onready var _military: MilitaryRuntimeController = $MilitaryRuntimeController
@onready var _queue: CardResolutionQueueRuntimeService = $CardResolutionQueueRuntimeService


func _ready() -> void:
	_routes.configure(RULESET_PROFILE.debug_snapshot())
	_queue.configure({"ruleset_id": "v0.6", "card_group": RULESET_PROFILE.card_group_rules()})
	var all_states := {
		"region_infrastructure": {"regions": [], "facilities": []},
		"session": {"world_session_state": {"players": [], "districts": []}},
		"weather": {"events": [], "queue": [], "history": [], "region_history": {}},
		"card_resolution_execution": {
			"completed_resolution_ids": [],
			"inflight_resolution_ids": [],
			"inflight_execution_transactions": [],
			"pending_settlements": [],
		},
		"card_resolution_history": {"history": [], "appended_resolution_ids": []},
	}
	var failures: Array[String] = []
	for row in [
		{"id": "routes", "owner": _routes},
		{"id": "military", "owner": _military},
		{"id": "queue", "owner": _queue},
	]:
		var state_owner := row.get("owner") as Node
		var owner_before: Dictionary = state_owner.call("capture_runtime_checkpoint")
		var state: Dictionary = state_owner.call("to_save_data")
		var states_before := all_states.duplicate(true)
		var receipt: Dictionary = state_owner.call("preflight_restore_dependencies", state, all_states)
		if not bool(receipt.get("accepted", false)) \
				or state_owner.call("capture_runtime_checkpoint") != owner_before \
				or all_states != states_before:
			failures.append(str(row.get("id")))
	var passed := failures.is_empty()
	print("RESTORE_DEPENDENCY_PREFLIGHT_BENCH|status=%s|checks=3|failures=%d" % ["PASS" if passed else "FAIL", failures.size()])
	if not passed:
		push_error("Restore dependency preflight Bench failed: %s" % ",".join(failures))
	if DisplayServer.get_name() == "headless":
		get_tree().quit(0 if passed else 1)
