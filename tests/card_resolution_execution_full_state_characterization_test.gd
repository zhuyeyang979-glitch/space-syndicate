extends SceneTree

const FIXTURE := preload("res://tests/fixtures/card_resolution_execution_save_full_state_fixture.gd")
const INSPECTOR := preload("res://scripts/tools/card_resolution_execution_full_state_inspector_v1.gd")
const WIRE := preload("res://scripts/semantic/semantic_wire_v1.gd")
const EVIDENCE_PATH := "res://reports/handoffs/alpha04c_card_resolution_execution_save_v4_pre_edit_characterization.json"
const BASELINE_SHA := "4c3787d16a7488d314bcaf50104cd361136d32f5"
const EXPECTED_TRANSITION_FLOAT_PATHS := [
	"$.transition_controller.card_group_cadence.lock_seconds",
	"$.transition_controller.card_group_cadence.planning_seconds",
	"$.transition_controller.card_group_cadence.public_bid_seconds",
	"$.transition_controller.card_group_cadence.total_seconds",
	"$.transition_controller.card_resolution_auction_timer",
	"$.transition_controller.card_resolution_counter_timer",
	"$.transition_controller.card_resolution_simultaneous_timer",
	"$.transition_controller.card_resolution_timer",
]

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var empty_fixture := FIXTURE.create(self)
	var empty_owner := empty_fixture.get("execution") as CardResolutionExecutionRuntimeService
	var empty_save := empty_owner.to_save_data()
	if int(empty_save.get("schema_version", -1)) == 4:
		FIXTURE.cleanup(empty_fixture)
		await process_frame
		await _run_v4_regression()
		return
	var empty_report := INSPECTOR.inspect(empty_save)
	var empty_float_paths := _non_closed_paths(empty_report, "float")
	_expect(int(empty_save.get("schema_version", -1)) == 3, "pre-edit Execution Save is schema v3")
	_expect(int(empty_report.get("non_closed_leaf_count", -1)) == 8, "idle Execution Save exposes exactly eight raw floats")
	_expect(empty_float_paths == EXPECTED_TRANSITION_FLOAT_PATHS, "the eight idle float paths are fully characterized")
	FIXTURE.cleanup(empty_fixture)
	await process_frame

	var rich_fixture := FIXTURE.create(self)
	var rich_owner := rich_fixture.get("execution") as CardResolutionExecutionRuntimeService
	var rich_result := FIXTURE.build_nontrivial_state(rich_fixture)
	_expect(bool(rich_result.get("ok", false)), "isolated real Execution Owner builds nontrivial transaction states")
	var rich_save := rich_result.get("save", {}) as Dictionary if rich_result.get("save", {}) is Dictionary else {}
	var rich_report := INSPECTOR.inspect(rich_save)
	var preflight := rich_owner.preflight_save_data(rich_save)
	_expect(bool(preflight.get("accepted", false)), "nontrivial v3 state is valid under the pre-edit domain contract")
	_expect((rich_save.get("inflight_execution_transactions", []) as Array).size() >= 7, "nontrivial state persists planned and retryable inflight records")
	_expect(not (rich_save.get("pending_settlements", []) as Array).is_empty(), "nontrivial state persists a pending settlement")
	_expect(not ((rich_save.get("transition_controller", {}) as Dictionary).get("card_transition_applied_lineage", []) as Array).is_empty(), "nontrivial state persists transition command lineage")
	_expect(int(rich_report.get("raw_float_count", 0)) > 8, "nested active entries and skills expose floats beyond the idle eight")
	_expect(int(rich_report.get("null_count", 0)) > 0, "nullable authored skill state is present and must roundtrip distinctly")
	_expect(int(rich_report.get("vector2_count", -1)) == 0 and int(rich_report.get("color_count", -1)) == 0, "Vector2 and Color are absent from actual valid Execution state")
	_expect(int(rich_report.get("string_name_count", -1)) == 0 and int(rich_report.get("non_string_key_count", -1)) == 0, "StringName and non-string dictionary keys are absent")
	_expect(int(rich_report.get("forbidden_dependency_type_count", -1)) == 0, "no Object, Resource, Callable, or RID enters Execution Save")

	var transition_scenarios := FIXTURE.build_transition_scenarios(self)
	var scenario_reports: Array = []
	var scenario_ids: Array[String] = []
	for scenario_variant in transition_scenarios:
		var scenario := scenario_variant as Dictionary
		var scenario_save := scenario.get("save", {}) as Dictionary
		var scenario_report := INSPECTOR.inspect(scenario_save)
		scenario_ids.append(str(scenario.get("scenario_id", "")))
		scenario_reports.append({
			"scenario_id": str(scenario.get("scenario_id", "")),
			"leaf_count": int(scenario_report.get("leaf_count", 0)),
			"non_closed_leaf_count": int(scenario_report.get("non_closed_leaf_count", 0)),
			"non_closed_type_counts": (scenario_report.get("non_closed_type_counts", {}) as Dictionary).duplicate(true),
		})
		FIXTURE.cleanup(scenario.get("fixture", {}) as Dictionary)
	_expect(scenario_ids == ["batch_30", "public_bid", "lock", "active_display", "counter_window"], "all required transition timing phases are characterized")
	await process_frame

	var report := {
		"schema_version": 1,
		"task_id": "ALPHA_0_4_C_ATTESTED_CARD_RESOLUTION_EXECUTION_SAVE_V4_CLOSED_WIRE_REPAIR_REPLAY_REMAINING_OWNER_PREFLIGHT_AND_CONDITIONAL_V8_PROCESS_A",
		"status": "PRE_EDIT_CHARACTERIZATION_COMPLETE" if _failures.is_empty() else "PRE_EDIT_CHARACTERIZATION_FAILED",
		"baseline_sha": BASELINE_SHA,
		"composition": "isolated real CardResolutionExecutionRuntimeService with real CardResolutionRuntimeController and valid transaction APIs",
		"empty_save": empty_report,
		"nontrivial_save": rich_report,
		"transition_scenarios": scenario_reports,
		"confirmed_transition_float_paths": EXPECTED_TRANSITION_FLOAT_PATHS,
		"coverage": (rich_result.get("coverage", {}) as Dictionary).duplicate(true),
		"v06_public_bid_state_present": (rich_save.get("transition_controller", {}) as Dictionary).has("card_resolution_auction_open") \
			and ((rich_save.get("transition_controller", {}) as Dictionary).get("card_group_cadence", {}) as Dictionary).has("public_bid_seconds"),
		"transition_command_schema_version": int((rich_save.get("transition_controller", {}) as Dictionary).get("card_transition_command_schema_version", -1)),
		"cadence_version": int((rich_save.get("transition_controller", {}) as Dictionary).get("card_group_cadence_version", -1)),
		"private_payload_redacted": true,
		"raw_payload_recorded": false,
		"v7_historical_registry_owner_capture": "7/19",
		"targeted_owner_capture_diagnostic_count": 7,
		"v8_authorization_created": false,
	}
	var output_path := _argument_value("--evidence-output=")
	if not output_path.is_empty():
		var expected_path := _normalize_path(ProjectSettings.globalize_path(EVIDENCE_PATH))
		_expect(_normalize_path(output_path) == expected_path, "characterization evidence path is canonical")
		_expect(not FileAccess.file_exists(expected_path), "pre-edit characterization evidence is append-once")
		if _failures.is_empty():
			var file := FileAccess.open(expected_path, FileAccess.WRITE)
			_expect(file != null, "characterization evidence file opens")
			if file != null:
				file.store_string(JSON.stringify(report, "\t", false) + "\n")
				file.close()

	FIXTURE.cleanup(rich_fixture)
	await process_frame
	print("CARD_RESOLUTION_EXECUTION_FULL_STATE_CHARACTERIZATION_TEST|status=%s|checks=%d|failures=%d|empty_leaves=%d|nontrivial_leaves=%d|non_closed=%d|float=%d|null=%d" % [
		"PASS" if _failures.is_empty() else "FAIL",
		_checks,
		_failures.size(),
		int(empty_report.get("leaf_count", 0)),
		int(rich_report.get("leaf_count", 0)),
		int(rich_report.get("non_closed_leaf_count", 0)),
		int(rich_report.get("raw_float_count", 0)),
		int(rich_report.get("null_count", 0)),
	])
	if not _failures.is_empty():
		push_error("Execution full-state characterization failed:\n- " + "\n- ".join(_failures))
	quit(0 if _failures.is_empty() else 1)


func _run_v4_regression() -> void:
	var frozen := _read_evidence()
	_expect(str(frozen.get("status", "")) == "PRE_EDIT_CHARACTERIZATION_COMPLETE", "frozen pre-edit characterization remains readable")
	var evidence_text := FileAccess.get_file_as_string(EVIDENCE_PATH)
	var private_sentinels_absent := true
	for sentinel in ["Execution Characterization Card", "card.instance.execution.characterization", "C:/Users/", "C:\\Users\\"]:
		private_sentinels_absent = private_sentinels_absent and not evidence_text.contains(sentinel)
	_expect(private_sentinels_absent, "frozen characterization contains no private skill, card instance, or absolute path")
	var fixture := FIXTURE.create(self)
	var rich := FIXTURE.build_nontrivial_state(fixture)
	_expect(bool(rich.get("ok", false)), "full-state fixture remains constructible after v4")
	var save := rich.get("save", {}) as Dictionary if rich.get("save", {}) is Dictionary else {}
	var owner := fixture.get("execution") as CardResolutionExecutionRuntimeService
	var preflight := owner.preflight_save_data(save)
	var wire_report := INSPECTOR.inspect(save)
	_expect(bool(preflight.get("accepted", false)), "full-state Execution Save v4 passes strict preflight")
	_expect(WIRE.is_closed_data(save) and int(wire_report.get("non_closed_leaf_count", -1)) == 0, "full-state Execution Save v4 has zero non-closed leaves")
	_expect(int(save.get("schema_version", -1)) == 4 and int(save.get("execution_wire_version", -1)) == 1, "v4 schema and Execution wire versions are explicit")
	FIXTURE.cleanup(fixture)
	await process_frame
	print("CARD_RESOLUTION_EXECUTION_FULL_STATE_CHARACTERIZATION_TEST|status=%s|checks=%d|failures=%d|v4_non_closed=%d" % [
		"PASS" if _failures.is_empty() else "FAIL",
		_checks,
		_failures.size(),
		int(wire_report.get("non_closed_leaf_count", -1)),
	])
	if not _failures.is_empty():
		push_error("Execution characterization regression failed:\n- " + "\n- ".join(_failures))
	quit(0 if _failures.is_empty() else 1)


func _non_closed_paths(report: Dictionary, variant_type: String) -> Array[String]:
	var result: Array[String] = []
	for record_variant in report.get("leaf_records", []) as Array:
		var record := record_variant as Dictionary
		if not bool(record.get("closed_data", false)) and str(record.get("variant_type", "")) == variant_type:
			result.append(str(record.get("json_path", "")))
	result.sort()
	return result


func _read_evidence() -> Dictionary:
	var file := FileAccess.open(EVIDENCE_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed as Dictionary if parsed is Dictionary else {}


func _argument_value(prefix: String) -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with(prefix):
			return argument.substr(prefix.length())
	return ""


func _normalize_path(path: String) -> String:
	return path.replace("\\", "/").to_lower()


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
