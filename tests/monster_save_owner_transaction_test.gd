extends SceneTree

const MONSTER_SCENE := preload("res://scenes/runtime/MonsterRuntimeController.tscn")

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var owner := MONSTER_SCENE.instantiate() as MonsterRuntimeController
	root.add_child(owner)

	var empty_state := owner.to_save_data()
	var empty_before := empty_state.duplicate(true)
	var owner_before := owner.to_save_data()
	var empty_preflight := owner.preflight_save_data(empty_state)
	_expect(bool(empty_preflight.get("accepted", false)), "empty monster capture passes strict live-owner preflight")
	_expect(_same_value(empty_state, empty_preflight.get("normalized_state", {})), "empty monster preflight normalizes exactly")
	_expect(_same_value(owner_before, owner.to_save_data()) and _same_value(empty_before, empty_state), "accepted empty monster preflight mutates neither owner nor input")
	var detached_empty := (empty_preflight.get("normalized_state", {}) as Dictionary).duplicate(true)
	detached_empty["monster_timer"] = 999.0
	_expect(_same_value(owner_before, owner.to_save_data()), "monster preflight returns detached normalized state")

	owner.auto_monsters = [{
		"uid": 41,
		"slot": 0,
		"monster_family_id": "save-owner-test-family",
		"name": "存档测试怪兽",
		"world_position": Vector2(12.5, 34.25),
		"down": false,
	}]
	owner.next_auto_monster_uid = 42
	owner.next_special_monster_slot = 0
	owner.selected_auto_monster_slot = 0
	owner.monster_timer = 3.25
	owner.special_monster_timer = 4.75
	var populated := owner.to_save_data()
	var populated_input_before := populated.duplicate(true)
	var populated_owner_before := owner.to_save_data()
	var populated_preflight := owner.preflight_save_data(populated)
	_expect(bool(populated_preflight.get("accepted", false)) and _same_value(populated, populated_preflight.get("normalized_state", {})), "populated monster capture with finite Vector2 state passes exact preflight")
	_expect(_same_value(populated_owner_before, owner.to_save_data()) and _same_value(populated_input_before, populated), "populated monster preflight is literally mutation-free")

	var extra_field := populated.duplicate(true)
	extra_field["world_player_cash"] = [123]
	_expect_rejected_without_mutation(owner, extra_field, "monster_save_v2_shape_invalid", "monster preflight rejects non-ledger root fields")
	var nested_duplicate := populated.duplicate(true)
	(nested_duplicate.get("auto_monsters", []) as Array)[0]["visual_cues"] = []
	_expect_rejected_without_mutation(owner, nested_duplicate, "monster_save_authority_duplicate_forbidden", "monster preflight rejects nested duplicate authority")
	var stale_uid := populated.duplicate(true)
	(stale_uid.get("next_auto_monster_uid") as Dictionary)["value"] = "41"
	_expect_rejected_without_mutation(owner, stale_uid, "monster_save_uid_allocator_stale", "monster preflight rejects a stale UID allocator")
	var wrong_slot := populated.duplicate(true)
	(((wrong_slot.get("auto_monsters", []) as Array)[0] as Dictionary).get("slot") as Dictionary)["value"] = "1"
	_expect_rejected_without_mutation(owner, wrong_slot, "monster_save_actor_invalid", "monster preflight rejects a non-canonical roster slot")
	var wrong_schema := populated.duplicate(true)
	wrong_schema["monster_card_atomic_schema_version"] = "forged-monster-schema"
	_expect_rejected_without_mutation(owner, wrong_schema, "monster_save_schema_attestation_invalid", "monster preflight rejects forged schema attestation")
	var nonfinite := populated.duplicate(true)
	var nonfinite_position := ((nonfinite.get("auto_monsters", []) as Array)[0] as Dictionary).get("world_position") as Dictionary
	(nonfinite_position.get("x") as Dictionary)["bits"] = "000000000000f07f"
	_expect_rejected_without_mutation(owner, nonfinite, "monster_save_vector2_component_invalid", "monster preflight rejects non-finite actor state")
	var noncanonical_numeric := populated.duplicate(true)
	noncanonical_numeric["monster_timer"] = 3
	_expect_rejected_without_mutation(owner, noncanonical_numeric, "monster_save_raw_integer_rejected", "monster preflight rejects an untagged numeric value")
	var retired_contract := populated.duplicate(true)
	(retired_contract.get("auto_monsters", []) as Array)[0]["contract_response"] = "accept"
	_expect_rejected_without_mutation(owner, retired_contract, "retired_contract_payload_rejected", "monster preflight rejects retired contract payloads")

	var applied_empty := owner.apply_save_data(empty_state)
	var restored := owner.apply_save_data(populated)
	_expect(bool(applied_empty.get("applied", false)) and bool(restored.get("applied", false)) and _same_value(populated, owner.to_save_data()), "preflight-approved monster state remains an exact apply/rollback checkpoint")

	owner.queue_free()
	await process_frame
	_finish()


func _expect_rejected_without_mutation(
	owner: MonsterRuntimeController,
	candidate: Dictionary,
	expected_reason: String,
	message: String
) -> void:
	var owner_before := owner.to_save_data()
	var candidate_before := candidate.duplicate(true)
	var receipt := owner.preflight_save_data(candidate)
	_expect(not bool(receipt.get("accepted", true)) and str(receipt.get("reason_code", "")) == expected_reason, message)
	_expect(_same_value(owner_before, owner.to_save_data()) and _same_value(candidate_before, candidate), "%s with zero owner/input mutation" % message)


func _same_value(left: Variant, right: Variant) -> bool:
	if typeof(left) != typeof(right):
		return false
	if left is Dictionary:
		var left_dictionary := left as Dictionary
		var right_dictionary := right as Dictionary
		if left_dictionary.size() != right_dictionary.size():
			return false
		for key_variant: Variant in left_dictionary.keys():
			if not right_dictionary.has(key_variant) or not _same_value(left_dictionary.get(key_variant), right_dictionary.get(key_variant)):
				return false
		return true
	if left is Array:
		var left_array := left as Array
		var right_array := right as Array
		if left_array.size() != right_array.size():
			return false
		for index in range(left_array.size()):
			if not _same_value(left_array[index], right_array[index]):
				return false
		return true
	return left == right


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
		push_error(message)


func _finish() -> void:
	print("MONSTER_SAVE_OWNER_TRANSACTION_TEST|status=%s|checks=%d|failures=%d" % ["PASS" if _failures.is_empty() else "FAIL", _checks, _failures.size()])
	quit(0 if _failures.is_empty() else 1)
