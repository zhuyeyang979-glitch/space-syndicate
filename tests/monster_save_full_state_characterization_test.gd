extends SceneTree

const FIXTURE := preload("res://tests/fixtures/monster_save_full_state_fixture.gd")
const INSPECTOR := preload("res://scripts/tools/monster_save_full_state_inspector_v1.gd")
const CODEC := preload("res://scripts/runtime/monster_save_wire_codec_v2.gd")
const WIRE := preload("res://scripts/semantic/semantic_wire_v1.gd")
const EVIDENCE_PATH := "res://reports/handoffs/alpha04c_monster_save_v2_pre_edit_characterization.json"
const BASELINE_SHA := "1964e6e8d86543f88781b91a239064d1a87b3e89"
const DEPENDENCY_FIELDS := [
	"_world_bridge",
	"_monster_binding_capability_provider_v06",
	"_region_infrastructure_world_bridge",
	"_route_network_runtime_controller",
	"_product_market_runtime_controller",
	"_player_cash_mutation_port",
	"_card_runtime_catalog_service",
	"_weather_runtime_controller",
	"_weather_telemetry_runtime_service",
	"_visual_cue_runtime_owner",
	"_table_presentation_refresh_port",
	"_public_log_producer_port",
	"_presentation_world_clock",
	"_runtime_command_pipeline",
]
const CONFIGURATION_FIELDS := ["_ruleset_snapshot", "_monster_battle_rules_v06", "_configured"]
const AUTHORITATIVE_RUNTIME_FIELDS := [
	"auto_monsters",
	"next_auto_monster_uid",
	"next_special_monster_slot",
	"selected_auto_monster_slot",
	"active_monster_wagers",
	"resolved_monster_wager_history",
	"monster_wager_sequence",
	"public_card_bid_monster_wager_pool",
	"_monster_wager_settlement_revision",
	"_monster_wager_settlement_terminal_journal",
	"monster_timer",
	"special_monster_timer",
	"_monster_card_revision_v06",
	"_monster_starter_state_v06",
	"_monster_card_reservations_v06",
	"_monster_card_terminal_journal_v06",
	"_monster_card_presentation_journal_v06",
	"_autonomous_move_sequence",
	"auto_monster_action_sequence",
	"_bankruptcy_estate_journal",
]
const DERIVED_CACHE_FIELDS := ["_monster_codex_public_catalog_cache_v06", "_monster_codex_public_catalog_summary_cache_v06"]
const DEBUG_ONLY_FIELDS := ["_monster_card_lifecycle_call_counts_v06"]
const EXTERNAL_AUTHORITY_PROXY_FIELDS := ["players", "districts", "game_time", "selected_district", "rng"]
const AUTHORITATIVE_WIRE_FIELDS := {
	"auto_monsters": "auto_monsters",
	"next_auto_monster_uid": "next_auto_monster_uid",
	"next_special_monster_slot": "next_special_monster_slot",
	"selected_auto_monster_slot": "selected_auto_monster_slot",
	"active_monster_wagers": "active_monster_wagers",
	"resolved_monster_wager_history": "resolved_monster_wager_history",
	"monster_wager_sequence": "monster_wager_sequence",
	"public_card_bid_monster_wager_pool": "public_card_bid_monster_wager_pool",
	"_monster_wager_settlement_revision": "monster_wager_settlement_revision",
	"_monster_wager_settlement_terminal_journal": "monster_wager_settlement_terminal_journal",
	"monster_timer": "monster_timer",
	"special_monster_timer": "special_monster_timer",
	"_monster_card_revision_v06": "monster_card_atomic_owner_revision",
	"_monster_starter_state_v06": "monster_card_atomic_starter_state",
	"_monster_card_reservations_v06": "monster_card_atomic_reservations",
	"_monster_card_terminal_journal_v06": "monster_card_atomic_terminal_journal",
	"_monster_card_presentation_journal_v06": "monster_card_atomic_presentation_journal",
	"_autonomous_move_sequence": "autonomous_move_sequence",
	"auto_monster_action_sequence": "auto_monster_action_sequence",
	"_bankruptcy_estate_journal": "bankruptcy_estate_journal",
}
const EXPECTED_PRE_EDIT_OMISSIONS := ["_autonomous_move_sequence", "_bankruptcy_estate_journal", "auto_monster_action_sequence"]

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var empty_fixture := FIXTURE.create(self)
	var empty_owner = empty_fixture.get("owner")
	var empty_save: Dictionary = empty_owner.call("to_save_data")
	if empty_save.has("monster_save_schema_version"):
		FIXTURE.cleanup(empty_fixture)
		await process_frame
		await _run_v2_characterization_regression()
		return
	var empty_report := INSPECTOR.inspect(empty_save)
	_expect(int(empty_report.get("non_closed_leaf_count", -1)) == 2, "empty Monster v1 Save has exactly two non-closed leaves")
	_expect(int(empty_report.get("raw_float_count", -1)) == 2, "both empty-state non-closed leaves are raw floats")
	_expect(str(empty_report.get("first_non_closed_path", "")) == "$.monster_timer", "first empty-state defect is monster_timer")
	FIXTURE.cleanup(empty_fixture)
	await process_frame

	var rich_fixture := FIXTURE.create(self)
	var rich_owner = rich_fixture.get("owner")
	var rich_result := FIXTURE.build_nontrivial_state(rich_fixture)
	_expect(bool(rich_result.get("ok", false)), "isolated production Owner builds the full nontrivial state")
	var rich_save: Dictionary = rich_result.get("save", {}) if rich_result.get("save", {}) is Dictionary else {}
	var omitted_state: Dictionary = rich_result.get("pre_edit_omitted_runtime_state", {}) \
			if rich_result.get("pre_edit_omitted_runtime_state", {}) is Dictionary else {}
	var rich_report := INSPECTOR.inspect(rich_save)
	var omitted_report := INSPECTOR.inspect(omitted_state)
	var mutable_field_audit := _mutable_field_audit(rich_save)
	var preflight: Dictionary = rich_owner.call("preflight_save_data", rich_save)
	_expect(bool(preflight.get("accepted", false)), "nontrivial v1 state is valid under the pre-edit Monster domain contract")
	_expect((rich_save.get("auto_monsters", []) as Array).size() >= 2, "nontrivial state has active and down/recovery monsters")
	_expect(not (rich_save.get("active_monster_wagers", []) as Array).is_empty(), "nontrivial state has an active wager")
	_expect(not (rich_save.get("resolved_monster_wager_history", []) as Array).is_empty(), "nontrivial state has resolved wager history")
	_expect(not (rich_save.get("monster_wager_settlement_terminal_journal", {}) as Dictionary).is_empty(), "nontrivial state has wager terminal journal")
	_expect(not (rich_save.get("monster_card_atomic_reservations", {}) as Dictionary).is_empty(), "nontrivial state has an atomic reservation")
	_expect(not (rich_save.get("monster_card_atomic_terminal_journal", {}) as Dictionary).is_empty(), "nontrivial state has an atomic terminal journal")
	_expect(not (rich_save.get("monster_card_atomic_presentation_journal", {}) as Dictionary).is_empty(), "nontrivial state has an exact-once presentation journal")
	_expect(float(rich_save.get("monster_timer", 4.0)) != 4.0 and float(rich_save.get("special_monster_timer", 5.0)) != 5.0, "both Monster timers are non-default")
	_expect(int(rich_report.get("raw_float_count", 0)) > 2, "full state exposes nested raw floats beyond the two top-level timers")
	_expect(int(rich_report.get("vector2_count", 0)) > 0, "full state exposes bit-sensitive Vector2 values")
	_expect(int(rich_report.get("color_count", -1)) == 0, "Color is not promoted into the Monster Save contract")
	_expect(int(rich_report.get("string_name_count", -1)) == 0, "StringName is absent from the actual Monster Save tree")
	_expect(int(rich_report.get("null_count", -1)) == 0, "null is absent from the actual Monster Save tree")
	_expect(int(rich_report.get("non_string_key_count", -1)) == 0, "actual Monster dictionaries use string keys")
	_expect(int(rich_report.get("forbidden_dependency_type_count", -1)) == 0, "no Object, Resource, Callable, or RID enters Monster Save")
	_expect(bool(mutable_field_audit.get("valid", false)), "every top-level mutable field has one explicit ownership classification")
	_expect(int(mutable_field_audit.get("top_level_mutable_field_count", -1)) == 45, "mutable-field audit covers all 45 top-level fields")
	_expect((mutable_field_audit.get("pre_edit_omitted_authoritative_fields", []) as Array) == EXPECTED_PRE_EDIT_OMISSIONS, "pre-edit Save omits exactly the three attested authoritative fields")
	_expect(omitted_state.size() == 3 and not (omitted_state.get("bankruptcy_estate_journal", {}) as Dictionary).is_empty(), "runtime fixture exposes the three omitted states with a nonempty journal")
	_expect(int(omitted_report.get("forbidden_dependency_type_count", -1)) == 0, "omitted authoritative runtime state has no rebind dependency")

	var report := {
		"schema_version": 1,
		"task_id": "ALPHA_0_4_C_ATTESTED_MONSTER_RUNTIME_SAVE_V2_CLOSED_WIRE_REPAIR_REPLAY_REMAINING_OWNER_PREFLIGHT_AND_CONDITIONAL_V8_PROCESS_A",
		"status": "PRE_EDIT_CHARACTERIZATION_COMPLETE" if _failures.is_empty() else "PRE_EDIT_CHARACTERIZATION_FAILED",
		"baseline_sha": BASELINE_SHA,
		"composition": "isolated real MonsterRuntimeController with real wager, atomic lifecycle, and bankruptcy participant APIs",
		"empty_save": empty_report,
		"nontrivial_save": rich_report,
		"pre_edit_omitted_authoritative_runtime_state": omitted_report,
		"mutable_field_classification": mutable_field_audit,
		"pre_edit_unattested_field_drop_count": (mutable_field_audit.get("pre_edit_omitted_authoritative_fields", []) as Array).size(),
		"pre_edit_unattested_field_drop_paths": [
			"$._autonomous_move_sequence",
			"$.auto_monster_action_sequence",
			"$._bankruptcy_estate_journal",
		],
		"coverage": {
			"active_monster": true,
			"world_position": true,
			"remaining_time": true,
			"linear_movement": true,
			"down_recovery": true,
			"nondefault_monster_timer": true,
			"nondefault_special_monster_timer": true,
			"active_wager": true,
			"resolved_wager_history": true,
			"wager_terminal_journal": true,
			"monster_card_atomic_reservation": true,
			"monster_card_atomic_terminal_journal": true,
			"monster_card_atomic_presentation_journal": true,
			"bankruptcy_estate_journal": true,
		},
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
	print("MONSTER_SAVE_FULL_STATE_CHARACTERIZATION_TEST|status=%s|checks=%d|failures=%d|empty_leaves=%d|nontrivial_leaves=%d|non_closed=%d|float=%d|vector2=%d" % [
		"PASS" if _failures.is_empty() else "FAIL",
		_checks,
		_failures.size(),
		int(empty_report.get("leaf_count", 0)),
		int(rich_report.get("leaf_count", 0)),
		int(rich_report.get("non_closed_leaf_count", 0)),
		int(rich_report.get("raw_float_count", 0)),
		int(rich_report.get("vector2_count", 0)),
	])
	if not _failures.is_empty():
		push_error("Monster Save full-state characterization failed:\n- " + "\n- ".join(_failures))
	quit(0 if _failures.is_empty() else 1)


func _run_v2_characterization_regression() -> void:
	var frozen := _read_evidence()
	_expect(str(frozen.get("status", "")) == "PRE_EDIT_CHARACTERIZATION_COMPLETE", "frozen pre-edit characterization remains readable")
	var evidence_text := FileAccess.get_file_as_string(EVIDENCE_PATH)
	var private_sentinels_absent := true
	for sentinel in ["human.alpha", "ai.beta", "tx-characterize", "C:/Users/", "C:\\Users\\"]:
		private_sentinels_absent = private_sentinels_absent and not evidence_text.contains(sentinel)
	_expect(private_sentinels_absent, "frozen characterization contains no actor, transaction, or absolute-path sentinel")
	var frozen_empty := frozen.get("empty_save", {}) as Dictionary
	var frozen_rich := frozen.get("nontrivial_save", {}) as Dictionary
	_expect(int(frozen_empty.get("leaf_count", -1)) == 11 and int(frozen_empty.get("non_closed_leaf_count", -1)) == 2, "frozen empty v1 evidence remains 11 leaves with two float defects")
	_expect(int(frozen_rich.get("leaf_count", -1)) == 673 and int(frozen_rich.get("non_closed_leaf_count", -1)) == 82, "frozen nontrivial v1 evidence remains 673 leaves with 82 non-closed values")
	_expect(int(frozen_rich.get("raw_float_count", -1)) == 70 and int(frozen_rich.get("vector2_count", -1)) == 12, "frozen nontrivial defect types remain 70 float plus 12 Vector2")
	_expect(int(frozen_rich.get("forbidden_dependency_type_count", -1)) == 0, "frozen Characterization contains no rebind dependency")
	var fixture := FIXTURE.create(self)
	var owner = fixture.get("owner")
	var rich := FIXTURE.build_nontrivial_state(fixture)
	_expect(bool(rich.get("ok", false)), "the same full-state fixture remains constructible after v2")
	var save: Dictionary = rich.get("save", {}) if rich.get("save", {}) is Dictionary else {}
	var preflight: Dictionary = owner.call("preflight_save_data", save)
	var wire_report := INSPECTOR.inspect(save)
	_expect(bool(preflight.get("accepted", false)), "full-state Monster Save v2 passes strict preflight")
	_expect(WIRE.is_closed_data(save) and int(wire_report.get("non_closed_leaf_count", -1)) == 0, "full-state Monster Save v2 has zero non-closed leaves")
	var decoded := CODEC.decode_save_state(save)
	var raw: Dictionary = decoded.get("value", {}) if decoded.get("value", {}) is Dictionary else {}
	_expect(bool(decoded.get("ok", false)) and int(raw.get("monster_save_schema_version", -1)) == 2 and str(raw.get("ruleset_id", "")) == "v0.6", "v2 schema and production ruleset attestations decode exactly")
	_expect(raw.has("autonomous_move_sequence") and raw.has("auto_monster_action_sequence") and raw.has("bankruptcy_estate_journal"), "all three formerly omitted authoritative fields are captured")
	FIXTURE.cleanup(fixture)
	await process_frame
	print("MONSTER_SAVE_FULL_STATE_CHARACTERIZATION_TEST|status=%s|checks=%d|failures=%d|frozen_non_closed=82|v2_non_closed=%d" % [
		"PASS" if _failures.is_empty() else "FAIL",
		_checks,
		_failures.size(),
		int(wire_report.get("non_closed_leaf_count", -1)),
	])
	if not _failures.is_empty():
		push_error("Monster Save characterization regression failed:\n- " + "\n- ".join(_failures))
	quit(0 if _failures.is_empty() else 1)


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


func _mutable_field_audit(save: Dictionary) -> Dictionary:
	var source_file := FileAccess.open("res://scripts/runtime/monster_runtime_controller.gd", FileAccess.READ)
	if source_file == null:
		return {"valid": false, "reason_code": "monster_controller_source_unreadable"}
	var expression := RegEx.new()
	if expression.compile("^var\\s+([A-Za-z0-9_]+)") != OK:
		return {"valid": false, "reason_code": "monster_mutable_field_regex_invalid"}
	var actual_fields: Array[String] = []
	for line in source_file.get_as_text().split("\n"):
		var match := expression.search(line)
		if match != null:
			actual_fields.append(match.get_string(1))
	actual_fields.sort()
	var categories := {
		"dependency_reference": DEPENDENCY_FIELDS.duplicate(),
		"configuration": CONFIGURATION_FIELDS.duplicate(),
		"authoritative_runtime_state": AUTHORITATIVE_RUNTIME_FIELDS.duplicate(),
		"derived_cache": DERIVED_CACHE_FIELDS.duplicate(),
		"debug_only": DEBUG_ONLY_FIELDS.duplicate(),
		"external_authority_proxy": EXTERNAL_AUTHORITY_PROXY_FIELDS.duplicate(),
	}
	var classified_fields: Array[String] = []
	var duplicates: Array[String] = []
	for category_variant: Variant in categories.keys():
		for field_variant: Variant in categories.get(category_variant, []):
			var field := str(field_variant)
			if classified_fields.has(field):
				duplicates.append(field)
			else:
				classified_fields.append(field)
	classified_fields.sort()
	duplicates.sort()
	var omitted: Array[String] = []
	for field in AUTHORITATIVE_RUNTIME_FIELDS:
		var wire_field := str(AUTHORITATIVE_WIRE_FIELDS.get(field, ""))
		if wire_field.is_empty() or not save.has(wire_field):
			omitted.append(field)
	omitted.sort()
	var expected_omissions: Array[String] = []
	for field in EXPECTED_PRE_EDIT_OMISSIONS:
		expected_omissions.append(field)
	expected_omissions.sort()
	return {
		"valid": duplicates.is_empty() and actual_fields == classified_fields and omitted == expected_omissions,
		"reason_code": "monster_mutable_fields_fully_classified" if duplicates.is_empty() and actual_fields == classified_fields and omitted == expected_omissions else "monster_mutable_field_classification_incomplete",
		"top_level_mutable_field_count": actual_fields.size(),
		"classified_field_count": classified_fields.size(),
		"duplicate_classification_fields": duplicates,
		"unclassified_fields": _array_difference(actual_fields, classified_fields),
		"unknown_classified_fields": _array_difference(classified_fields, actual_fields),
		"categories": categories,
		"authoritative_runtime_field_count": AUTHORITATIVE_RUNTIME_FIELDS.size(),
		"pre_edit_omitted_authoritative_fields": omitted,
	}


func _array_difference(left: Array[String], right: Array[String]) -> Array[String]:
	var result: Array[String] = []
	for value in left:
		if not right.has(value):
			result.append(value)
	return result


func _normalize_path(path: String) -> String:
	return path.replace("\\", "/").to_lower()


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
