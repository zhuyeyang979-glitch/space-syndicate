extends Node

const StrictState := preload("res://scripts/runtime/save_owner_state_v2_contract.gd")
const RULESET_PROFILE := preload("res://resources/rules/space_syndicate_ruleset_v06.tres")

@onready var _ruleset: RulesetSaveAttestationOwner = $RulesetSaveAttestationOwner
@onready var _routes: RouteNetworkRuntimeController = $RouteNetworkRuntimeController
@onready var _military: MilitaryRuntimeController = $MilitaryRuntimeController
@onready var _queue: CardResolutionQueueRuntimeService = $CardResolutionQueueRuntimeService


func _ready() -> void:
	var checks := 0
	var failures: Array[String] = []
	_queue.configure({"ruleset_id": "v0.6", "card_group": RULESET_PROFILE.card_group_rules()})
	for row in [
		{"id": "ruleset", "owner": _ruleset, "version": 1},
		{"id": "routes", "owner": _routes, "version": 2},
		{"id": "military", "owner": _military, "version": 2},
		{"id": "card_resolution_queue", "owner": _queue, "version": 2},
	]:
		checks += 1
		var state_owner: Object = row.get("owner")
		var state: Dictionary = state_owner.call("to_save_data")
		var preflight: Dictionary = state_owner.call("preflight_save_data", state)
		if int(state.get("schema_version", -1)) != int(row.get("version", -2)) \
				or not bool(preflight.get("accepted", false)) \
				or StrictState.contains_rng_continuation(state):
			failures.append(str(row.get("id", "unknown")))
	var passed := failures.is_empty()
	print("SAVE_OWNER_DOMAIN_V2_BENCH|status=%s|checks=%d|failures=%d" % ["PASS" if passed else "FAIL", checks, failures.size()])
	if not passed:
		push_error("Save owner domain v2 Bench failed: %s" % ",".join(failures))
	if DisplayServer.get_name() == "headless":
		get_tree().quit(0 if passed else 1)
