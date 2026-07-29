extends SceneTree

const StrictState := preload("res://scripts/runtime/save_owner_state_v2_contract.gd")
const RULESET_PROFILE := preload("res://resources/rules/space_syndicate_ruleset_v06.tres")
const MANA_SCENE := preload("res://scenes/runtime/PlayerManaRuntimeController.tscn")
const ORGANIZATION_SCENE := preload("res://scenes/runtime/PlayerOrganizationRuntimeController.tscn")
const VICTORY_SCENE := preload("res://scenes/runtime/VictoryControlRuntimeController.tscn")

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_player_mana_preflight()
	_test_player_organization_preflight()
	_test_victory_control_preflight()
	_finish()


func _test_player_mana_preflight() -> void:
	var owner := MANA_SCENE.instantiate() as PlayerManaRuntimeController
	root.add_child(owner)
	_expect(bool(owner.configure(RULESET_PROFILE.debug_snapshot()).get("configured", false)), "PlayerMana configures from v0.6")
	owner.reset_state(2)
	var saved := owner.to_save_data()
	_exercise_valid_preflight(owner, saved, "PlayerMana")
	var missing := saved.duplicate(true)
	missing.erase("reservations")
	_expect_rejected_without_mutation(owner, missing, "PlayerMana rejects a missing field")
	_expect_rejected_without_mutation(owner, _with(saved, "state_version", 2), "PlayerMana rejects a wrong version")
	_expect_rejected_without_mutation(owner, _with(saved, "current_game_time", INF), "PlayerMana rejects non-finite time")
	var malformed_row := saved.duplicate(true)
	(((malformed_row.get("pools_by_player") as Dictionary).get("0") as Dictionary)).erase("shipping")
	_expect_rejected_without_mutation(owner, malformed_row, "PlayerMana rejects an incomplete six-color row")
	var callable_payload := saved.duplicate(true)
	callable_payload["terminal_receipts"] = {"bad": Callable(self, "_run")}
	_expect_rejected_without_mutation(owner, callable_payload, "PlayerMana rejects non-codec objects")
	_expect(_apply_exact(owner, saved), "PlayerMana applies its preflight-normalized state exactly")
	owner.queue_free()


func _test_player_organization_preflight() -> void:
	var owner := ORGANIZATION_SCENE.instantiate() as PlayerOrganizationRuntimeController
	root.add_child(owner)
	var empty_saved := owner.to_save_data()
	_exercise_valid_preflight(owner, empty_saved, "PlayerOrganization empty")
	_expect(bool(owner.configure(["human.alpha", "ai.beta"]).get("configured", false)), "PlayerOrganization configures a stable actor roster")
	var saved := owner.to_save_data()
	_exercise_valid_preflight(owner, saved, "PlayerOrganization")
	var matching_session := _session_roster_state(["player.0", "player.1"])
	var production_owner := ORGANIZATION_SCENE.instantiate() as PlayerOrganizationRuntimeController
	root.add_child(production_owner)
	production_owner.configure(["player.0", "player.1"])
	var production_saved := production_owner.to_save_data()
	_expect(bool(production_owner.preflight_restore_dependencies(production_saved, matching_session).get("accepted", false)), "PlayerOrganization cross-section preflight accepts the matching session roster")
	_expect(not bool(production_owner.preflight_restore_dependencies(empty_saved, matching_session).get("accepted", true)), "PlayerOrganization cross-section preflight rejects an empty organization for a running session")
	_expect(not bool(production_owner.preflight_restore_dependencies(production_saved, _session_roster_state([])).get("accepted", true)), "PlayerOrganization cross-section preflight rejects configured actors for an empty session")
	production_owner.queue_free()
	var missing := saved.duplicate(true)
	missing.erase("capability_secret")
	_expect_rejected_without_mutation(owner, missing, "PlayerOrganization rejects a missing field")
	_expect_rejected_without_mutation(owner, _with(saved, "state_version", 2), "PlayerOrganization rejects a wrong version")
	_expect_rejected_without_mutation(owner, _with(saved, "revision", INF), "PlayerOrganization rejects a non-finite revision")
	var duplicate_actor := saved.duplicate(true)
	(duplicate_actor.get("actor_ids") as Array).append("human.alpha")
	_expect_rejected_without_mutation(owner, duplicate_actor, "PlayerOrganization rejects duplicate actor IDs")
	var callable_payload := saved.duplicate(true)
	callable_payload["transaction_journal"] = {"bad": Callable(self, "_run")}
	_expect_rejected_without_mutation(owner, callable_payload, "PlayerOrganization rejects non-codec objects")
	_expect(_apply_exact(owner, saved), "PlayerOrganization applies its preflight-normalized state exactly")
	owner.queue_free()


func _session_roster_state(actor_ids: Array[String]) -> Dictionary:
	var players: Array[Dictionary] = []
	for index in range(actor_ids.size()):
		players.append({"id": index, "actor_id": actor_ids[index]})
	return {"session": {"world_session_state": {"players": players}}}


func _test_victory_control_preflight() -> void:
	var owner := VICTORY_SCENE.instantiate() as VictoryControlRuntimeController
	root.add_child(owner)
	_expect(bool(owner.configure().get("configured", false)), "VictoryControl configures from v0.6 resources")
	var saved := owner.to_save_data()
	_exercise_valid_preflight(owner, saved, "VictoryControl")
	var missing := saved.duplicate(true)
	(missing.get("victory_control_runtime") as Dictionary).erase("outcome_receipt")
	_expect_rejected_without_mutation(owner, missing, "VictoryControl rejects a missing payload field")
	var wrong_version := saved.duplicate(true)
	(wrong_version.get("victory_control_runtime") as Dictionary)["schema_version"] = 1
	_expect_rejected_without_mutation(owner, wrong_version, "VictoryControl rejects a wrong version")
	var nonfinite := saved.duplicate(true)
	(nonfinite.get("victory_control_runtime") as Dictionary)["audit_remaining_seconds"] = NAN
	_expect_rejected_without_mutation(owner, nonfinite, "VictoryControl rejects non-finite audit time")
	var duplicate_roster := saved.duplicate(true)
	var duplicate_payload := duplicate_roster.get("victory_control_runtime") as Dictionary
	duplicate_payload["state"] = "audit"
	duplicate_payload["audit_roster"] = [0, 0]
	duplicate_payload["audit_remaining_seconds"] = 120.0
	_expect_rejected_without_mutation(owner, duplicate_roster, "VictoryControl rejects a duplicate audit roster")
	_expect_rejected_without_mutation(owner, (saved.get("victory_control_runtime") as Dictionary).duplicate(true), "VictoryControl preflight rejects an unwrapped payload")
	var callable_payload := saved.duplicate(true)
	(callable_payload.get("victory_control_runtime") as Dictionary)["outcome_receipt"] = {"bad": Callable(self, "_run")}
	_expect_rejected_without_mutation(owner, callable_payload, "VictoryControl rejects non-codec objects")
	_expect(_apply_exact(owner, saved), "VictoryControl applies its preflight-normalized state exactly")
	owner.queue_free()


func _exercise_valid_preflight(owner: Node, saved: Dictionary, label: String) -> void:
	var before_state: Dictionary = owner.call("to_save_data")
	var before_debug: Dictionary = owner.call("debug_snapshot")
	var first: Dictionary = owner.call("preflight_save_data", saved.duplicate(true))
	var second: Dictionary = owner.call("preflight_save_data", saved.duplicate(true))
	_expect(bool(first.get("accepted", false)), "%s accepts its current save state" % label)
	_expect(first.get("normalized_state", {}) == saved and second.get("normalized_state", {}) == saved, "%s preflight is deterministic and exact" % label)
	_expect(owner.call("to_save_data") == before_state and owner.call("debug_snapshot") == before_debug, "%s preflight has zero live mutation" % label)
	_expect(not StrictState.contains_rng_continuation(first.get("normalized_state", {})), "%s normalized state owns no RNG continuation" % label)
	_expect_rejected_without_mutation(owner, _with(saved, "unknown_field", true), "%s rejects unknown top-level fields" % label)


func _expect_rejected_without_mutation(owner: Node, candidate: Dictionary, message: String) -> void:
	var before_state: Dictionary = owner.call("to_save_data")
	var before_debug: Dictionary = owner.call("debug_snapshot")
	var receipt: Dictionary = owner.call("preflight_save_data", candidate)
	_expect(not bool(receipt.get("accepted", true)) and not str(receipt.get("reason_code", "")).is_empty() \
		and owner.call("to_save_data") == before_state and owner.call("debug_snapshot") == before_debug, message)


func _apply_exact(owner: Node, state: Dictionary) -> bool:
	var receipt: Dictionary = owner.call("apply_save_data", state.duplicate(true))
	return bool(receipt.get("applied", false)) and owner.call("to_save_data") == state


func _with(source: Dictionary, key: String, value: Variant) -> Dictionary:
	var result := source.duplicate(true)
	result[key] = value
	return result


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		print("PASS: %s" % message)
		return
	_failures.append(message)
	push_error("FAIL: %s" % message)


func _finish() -> void:
	var passed := _failures.is_empty()
	print("ALPHA04C_STRICT_PREFLIGHT_TEST|status=%s|checks=%d|failures=%d" % ["PASS" if passed else "FAIL", _checks, _failures.size()])
	if not passed:
		push_error("Strict preflight failures: %s" % JSON.stringify(_failures))
	quit(0 if passed else 1)
