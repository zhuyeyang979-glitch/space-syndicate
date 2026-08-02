extends SceneTree

const MATRIX_PATH := "res://reports/handoffs/alpha04c_execution_restore_field_authority_matrix.json"
const MATRIX_MD_PATH := "res://reports/handoffs/alpha04c_execution_restore_field_authority_matrix.md"
const CHARACTERIZATION_PATH := "res://reports/handoffs/alpha04c_execution_restore_difference_characterization.json"
const OWNER_SOURCE_PATH := "res://scripts/runtime/card_resolution_execution_runtime_service.gd"
const PROJECTION_SOURCE_PATH := "res://scripts/tools/execution_authoritative_restore_projection_v1.gd"

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	var matrix := _json_dictionary(MATRIX_PATH)
	var characterization := _json_dictionary(CHARACTERIZATION_PATH)
	var markdown := FileAccess.get_file_as_string(MATRIX_MD_PATH)
	var owner_source := FileAccess.get_file_as_string(OWNER_SOURCE_PATH)
	var projection_source := FileAccess.get_file_as_string(PROJECTION_SOURCE_PATH)
	_expect(not matrix.is_empty() and not characterization.is_empty() and not markdown.is_empty(), "matrix, characterization, and human review are present")
	_expect(bool(matrix.get("field_authority_matrix_complete", false)) \
			and int(matrix.get("unclassified_restore_difference_count", -1)) == 0, "every observed difference is classified")
	_expect(int(matrix.get("execution_restore_difference_path_count", -1)) == 2 \
			and int(matrix.get("diagnostic_ephemeral_difference_count", -1)) == 2 \
			and int(matrix.get("persisted_authority_difference_count", -1)) == 0 \
			and int(matrix.get("derived_post_restore_difference_count", -1)) == 0, "only two diagnostic differences are observed")
	_expect(int(matrix.get("diagnostic_field_gameplay_reader_count", -1)) == 0 \
			and int(matrix.get("diagnostic_field_ai_reader_count", -1)) == 0 \
			and int(matrix.get("diagnostic_field_player_ui_authority_reader_count", -1)) == 0 \
			and int(matrix.get("diagnostic_field_receipt_reader_count", -1)) == 0 \
			and int(matrix.get("diagnostic_field_exact_once_reader_count", -1)) == 0 \
			and int(matrix.get("diagnostic_field_save_reader_count", -1)) == 0, "diagnostic fields have no authority consumers")
	_expect(int(matrix.get("parity_excluded_field_count", -1)) == 2 \
			and int(matrix.get("parity_excluded_field_reason_count", -1)) == 2 \
			and int(matrix.get("parity_exclusion_wildcard_count", -1)) == 0 \
			and int(matrix.get("unknown_parity_exclusion_count", -1)) == 0, "exclusions are exact, reasoned, and contain no wildcard")

	var observed_paths: Array[String] = []
	for record_variant: Variant in characterization.get("execution_restore_difference_paths", []) as Array:
		if record_variant is Dictionary:
			observed_paths.append(str((record_variant as Dictionary).get("path", "")))
	observed_paths.sort()
	var excluded_paths: Array[String] = []
	var allowed_classes := ["persisted_authority", "derived_post_restore_state", "diagnostic_ephemeral"]
	for field_variant: Variant in matrix.get("fields", []) as Array:
		if not (field_variant is Dictionary):
			continue
		var field := field_variant as Dictionary
		_expect(allowed_classes.has(str(field.get("authority_class", ""))), "matrix uses only allowed authority classes")
		if bool(field.get("parity_excluded", false)):
			excluded_paths.append(str(field.get("field_path", "")))
	excluded_paths.sort()
	_expect(observed_paths == excluded_paths \
			and excluded_paths == ["$.owner_debug.last_phase", "$.owner_debug.last_reason"], "every and only observed difference has an exact matrix exclusion")

	var save_block := _function_block(owner_source, "func to_save_data()")
	_expect(not save_block.contains("last_phase") and not save_block.contains("last_reason") \
			and not save_block.contains("last_summary"), "diagnostics are absent from Save v4")
	_expect(owner_source.contains('_last_phase = "restored"') \
			and owner_source.contains('_last_reason = "execution_lineage_restored"') \
			and owner_source.contains("_last_summary = {}"), "production apply defines the canonical diagnostic state")
	_expect(projection_source.contains("ATTESTED_DIAGNOSTIC_DIFFERENCE_PATHS") \
			and not projection_source.contains("ignore_paths") \
			and not projection_source.contains("begins_with(excluded"), "projection has no configurable, prefix, or wildcard ignore mechanism")
	_expect(int(matrix.get("diagnostic_fields_persisted_to_save_count", -1)) == 0 \
			and int(matrix.get("automatic_golden_update_count", -1)) == 0, "matrix forbids diagnostic persistence and automatic golden updates")
	_finish()


func _json_dictionary(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed as Dictionary if parsed is Dictionary else {}


func _function_block(source: String, signature: String) -> String:
	var start := source.find(signature)
	if start < 0:
		return ""
	var next := source.find("\nfunc ", start + signature.length())
	return source.substr(start) if next < 0 else source.substr(start, next - start)


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	print("CARD_RESOLUTION_EXECUTION_FIELD_AUTHORITY_MATRIX_TEST|status=%s|checks=%d|failures=%d" % [
		"PASS" if _failures.is_empty() else "FAIL", _checks, _failures.size()
	])
	if not _failures.is_empty():
		push_error("Execution field authority matrix failures:\n- " + "\n- ".join(_failures))
	quit(0 if _failures.is_empty() else 1)
