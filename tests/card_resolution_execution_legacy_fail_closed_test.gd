extends SceneTree

const FIXTURE := preload("res://tests/fixtures/card_resolution_execution_save_full_state_fixture.gd")
const LEGACY_REASON := "card_resolution_execution_v3_closed_wire_upgrade_requires_backup"

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var fixture := FIXTURE.create(self)
	var owner := fixture.get("execution") as CardResolutionExecutionRuntimeService
	var controller := fixture.get("transition") as CardResolutionRuntimeController
	controller.begin_active_display(4.25)
	var before := owner.to_save_data()
	var legacy_states := [
		{
			"schema_version": 1,
			"transaction_sequence": 0,
			"completed_resolution_ids": [],
			"inflight_resolution_ids": [],
		},
		{
			"schema_version": 2,
			"transaction_sequence": 0,
			"completed_resolution_ids": [],
			"inflight_resolution_ids": [],
			"transition_controller": controller.to_save_data(),
		},
		{
			"schema_version": 3,
			"transaction_sequence": 0,
			"completed_resolution_ids": [],
			"inflight_resolution_ids": [],
			"inflight_execution_transactions": [],
			"pending_settlements": [],
			"transition_controller": controller.to_save_data(),
		},
	]
	var apply_count := 0
	for legacy_variant: Variant in legacy_states:
		var legacy := legacy_variant as Dictionary
		var preflight := owner.preflight_save_data(legacy)
		_expect(not bool(preflight.get("accepted", true)) \
				and str(preflight.get("reason_code", "")) == LEGACY_REASON \
				and bool(preflight.get("requires_backup", false)), "legacy Execution owner state requires backup and cannot resume")
		var applied := owner.apply_save_data(legacy)
		if bool(applied.get("applied", false)):
			apply_count += 1
		_expect(not bool(applied.get("applied", true)) and owner.to_save_data() == before, "legacy rejection performs no partial owner or Transition mutation")

	var legacy_file_path := "user://alpha04c_execution_legacy_v3_preservation_%d.json" % OS.get_process_id()
	var legacy_file := FileAccess.open(legacy_file_path, FileAccess.WRITE)
	_expect(legacy_file != null, "isolated legacy file fixture opens")
	var authored_text := JSON.stringify(legacy_states.back(), "\t", false) + "\n"
	if legacy_file != null:
		legacy_file.store_string(authored_text)
		legacy_file.close()
	var file_before := FileAccess.get_file_as_string(legacy_file_path)
	owner.apply_save_data(legacy_states.back() as Dictionary)
	var file_after := FileAccess.get_file_as_string(legacy_file_path)
	_expect(file_before == authored_text and file_after == file_before, "legacy Save file is neither deleted nor overwritten")
	_expect(apply_count == 0 and owner.to_save_data() == before, "legacy apply count and partial mutation count remain zero")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(legacy_file_path))

	FIXTURE.cleanup(fixture)
	await process_frame
	print("CARD_RESOLUTION_EXECUTION_LEGACY_FAIL_CLOSED_TEST|status=%s|checks=%d|failures=%d|apply_count=%d" % [
		"PASS" if _failures.is_empty() else "FAIL", _checks, _failures.size(), apply_count
	])
	if not _failures.is_empty():
		push_error("Execution legacy fail-closed failed:\n- " + "\n- ".join(_failures))
	quit(0 if _failures.is_empty() else 1)


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
