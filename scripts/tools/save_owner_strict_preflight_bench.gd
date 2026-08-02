extends Node

const StrictState := preload("res://scripts/runtime/save_owner_state_v2_contract.gd")
const RULESET_PROFILE := preload("res://resources/rules/space_syndicate_ruleset_v06.tres")

@onready var _mana: PlayerManaRuntimeController = $PlayerManaRuntimeController
@onready var _organization: PlayerOrganizationRuntimeController = $PlayerOrganizationRuntimeController
@onready var _victory: VictoryControlRuntimeController = $VictoryControlRuntimeController


func _ready() -> void:
	_mana.configure(RULESET_PROFILE.debug_snapshot())
	_mana.reset_state(2)
	_organization.configure(["human.alpha", "ai.beta"])
	_victory.configure()
	var failures: Array[String] = []
	for row in [
		{"id": "player_mana", "state_owner": _mana},
		{"id": "player_organization", "state_owner": _organization},
		{"id": "victory_control", "state_owner": _victory},
	]:
		var state_owner: Node = row.get("state_owner")
		var state: Dictionary = state_owner.call("to_save_data")
		var before: Dictionary = state_owner.call("debug_snapshot")
		var receipt: Dictionary = state_owner.call("preflight_save_data", state)
		if not bool(receipt.get("accepted", false)) \
				or receipt.get("normalized_state", {}) != state \
				or state_owner.call("debug_snapshot") != before \
				or StrictState.contains_rng_continuation(state):
			failures.append(str(row.get("id")))
	var passed := failures.is_empty()
	print("SAVE_OWNER_STRICT_PREFLIGHT_BENCH|status=%s|checks=3|failures=%d" % ["PASS" if passed else "FAIL", failures.size()])
	if not passed:
		push_error("Save owner strict preflight Bench failed: %s" % ",".join(failures))
	if DisplayServer.get_name() == "headless":
		get_tree().quit(0 if passed else 1)
