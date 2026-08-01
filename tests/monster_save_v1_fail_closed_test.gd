extends SceneTree

const MONSTER_SCENE := preload("res://scenes/runtime/MonsterRuntimeController.tscn")
const REASON := "monster_save_v1_closed_wire_upgrade_requires_backup"
const V1_PATH := "user://test_runs/monster_save_v1_preserved.json"

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var owner = MONSTER_SCENE.instantiate()
	root.add_child(owner)
	var v1 := _v1_state()
	var owner_before: Dictionary = owner.call("to_save_data")
	var preflight: Dictionary = owner.call("preflight_save_data", v1)
	var applied: Dictionary = owner.call("apply_save_data", v1)
	_expect(not bool(preflight.get("accepted", true)) and str(preflight.get("reason_code", "")) == REASON, "Monster v1 preflight returns the typed backup-required reason")
	_expect(not bool(applied.get("applied", true)) and str(applied.get("reason_code", "")) == REASON, "Monster v1 direct apply is blocked")
	_expect(owner_before == owner.call("to_save_data"), "Monster v1 rejection mutates zero owner state")

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://test_runs"))
	var original_text := JSON.stringify(v1, "\t", false) + "\n"
	var file := FileAccess.open(V1_PATH, FileAccess.WRITE)
	_expect(file != null, "v1 preservation fixture opens")
	if file != null:
		file.store_string(original_text)
		file.close()
	var read_file := FileAccess.open(V1_PATH, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(read_file.get_as_text()) if read_file != null else null
	if read_file != null:
		read_file.close()
	var file_apply: Dictionary = owner.call("apply_save_data", parsed as Dictionary if parsed is Dictionary else {})
	var after_file := FileAccess.open(V1_PATH, FileAccess.READ)
	var after_text := after_file.get_as_text() if after_file != null else ""
	if after_file != null:
		after_file.close()
	_expect(not bool(file_apply.get("applied", true)) and str(file_apply.get("reason_code", "")) == REASON, "JSON-read v1 is rejected before apply")
	_expect(after_text == original_text and FileAccess.file_exists(V1_PATH), "v1 Save file is preserved byte-for-byte")
	_expect(owner_before == owner.call("to_save_data"), "v1 file rejection has zero partial mutation")

	var legacy_unit_wrapper := v1.duplicate(true)
	legacy_unit_wrapper["contract_version"] = "v0.6"
	legacy_unit_wrapper["domain"] = "monster"
	var legacy_unit_apply: Dictionary = owner.call("apply_unit_card_save_data_v06", legacy_unit_wrapper, "monster")
	_expect(not bool(legacy_unit_apply.get("applied", true)) and str(legacy_unit_apply.get("reason_code", "")) == REASON, "legacy flat unit-card Monster state also fails closed")
	_expect(owner_before == owner.call("to_save_data"), "all v1 rejection paths leave the v2 owner untouched")

	owner.queue_free()
	await process_frame
	print("MONSTER_SAVE_V1_FAIL_CLOSED_TEST|status=%s|checks=%d|failures=%d|v1_direct_resume=false|v1_file_preserved=%s|v1_apply_count=0|partial_mutation_count=0" % [
		"PASS" if _failures.is_empty() else "FAIL",
		_checks,
		_failures.size(),
		str(after_text == original_text).to_lower(),
	])
	if not _failures.is_empty():
		push_error("Monster v1 fail-closed failures:\n- " + "\n- ".join(_failures))
	quit(0 if _failures.is_empty() else 1)


func _v1_state() -> Dictionary:
	return {
		"auto_monsters": [],
		"next_auto_monster_uid": 1,
		"next_special_monster_slot": 0,
		"selected_auto_monster_slot": 0,
		"active_monster_wagers": [],
		"resolved_monster_wager_history": [],
		"monster_wager_sequence": 0,
		"public_card_bid_monster_wager_pool": 0,
		"monster_wager_settlement_revision": 0,
		"monster_wager_settlement_terminal_journal": {},
		"monster_battle_lifecycle_schema_version": 1,
		"monster_timer": 4.0,
		"special_monster_timer": 5.0,
		"monster_card_atomic_schema_version": "monster_deploy_atomic_lifecycle_v06",
		"monster_card_atomic_owner_revision": 0,
		"monster_card_atomic_starter_state": {},
		"monster_card_atomic_reservations": {},
		"monster_card_atomic_terminal_journal": {},
		"monster_card_atomic_presentation_journal": {},
	}


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
