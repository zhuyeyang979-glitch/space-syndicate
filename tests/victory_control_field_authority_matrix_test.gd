extends SceneTree

const MATRIX_PATH := "res://docs/save/alpha04c_victory_control_field_authority_matrix.json"
const PROJECTION := preload("res://scripts/tools/victory_authoritative_restore_projection_v1.gd")

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MATRIX_PATH))
	var matrix: Dictionary = parsed if parsed is Dictionary else {}
	var rows := matrix.get("fields", []) as Array
	_expect(bool(matrix.get("victory_authority_matrix_complete", false)), "authority_matrix_is_complete")
	_expect(int(matrix.get("unclassified_victory_field_count", -1)) == 0, "authority_matrix_has_no_unclassified_fields")
	_expect(int(matrix.get("victory_derived_world_fact_persisted_count", -1)) == 0 \
			and int(matrix.get("victory_private_asset_persisted_count", -1)) == 0, "derived_and_private_world_facts_are_not_persisted")
	_expect(int(matrix.get("victory_diagnostic_gameplay_reader_count", -1)) == 0 \
			and int(matrix.get("victory_diagnostic_exact_once_reader_count", -1)) == 0, "diagnostic_field_has_no_authoritative_consumers")
	var persisted := _fields_for_class(rows, "persisted_authority")
	_expect(persisted == [
		"_audit_remaining_seconds",
		"_audit_roster",
		"_outcome_receipt",
		"_outcome_sequence",
		"_qualification_elapsed_by_player",
		"_state",
	], "all_six_persisted_authority_fields_are_classified")
	var derived := _fields_for_class(rows, "derived_world_fact")
	_expect(derived == [
		"_last_candidates",
		"_last_pause_reasons",
		"_last_player_assets",
		"_last_settlement_checkpoint",
		"_last_victory_rule",
	], "all_five_world_fact_caches_are_derived")
	_expect(_fields_for_class(rows, "diagnostic_only") == ["_advance_count"], "advance_count_is_the_only_diagnostic_field")
	_expect(PROJECTION.PROJECTION_FIELDS == [
		"state",
		"qualification_elapsed_by_player",
		"audit_roster",
		"audit_remaining_seconds",
		"outcome_sequence",
		"outcome_receipt",
	], "authoritative_projection_covers_every_persisted_field")
	var controller_source := FileAccess.get_file_as_string("res://scripts/runtime/victory_control_runtime_controller.gd")
	var codec_source := FileAccess.get_file_as_string("res://scripts/runtime/victory_control_save_wire_codec_v3.gd")
	var bridge_source := FileAccess.get_file_as_string("res://scripts/runtime/victory_control_world_bridge.gd")
	_expect(not controller_source.contains('"last_candidates"') \
			and not controller_source.contains('"last_player_assets"') \
			and not controller_source.contains('"last_settlement_checkpoint"'), "derived_cache_names_are_absent_from_save_wire_fields")
	_expect(codec_source.contains("closed_save_scalar_codec_v1.gd") \
			and codec_source.contains("CLOSED_SCALAR_CODEC.encode_f64") \
			and not codec_source.contains("encode_double") \
			and not codec_source.contains("decode_double"), "victory_codec_reuses_the_single_shared_f64_implementation")
	_expect(bridge_source.contains("is_fresh_snapshot_after_restore") \
			and bridge_source.contains("capture_fingerprint"), "fresh_world_gate_uses_bridge_attestation_not_payload_sequence_alone")
	_finish()


func _fields_for_class(rows: Array, authority_class: String) -> Array[String]:
	var fields: Array[String] = []
	for row_variant in rows:
		if row_variant is Dictionary and str((row_variant as Dictionary).get("authority_class", "")) == authority_class:
			fields.append(str((row_variant as Dictionary).get("field_path", "")))
	fields.sort()
	return fields


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	print("VICTORY_CONTROL_FIELD_AUTHORITY_MATRIX_TEST|status=%s|checks=%d|failures=%d" % [
		"PASS" if _failures.is_empty() else "FAIL",
		_checks,
		_failures.size(),
	])
	for failure in _failures:
		push_error(failure)
	quit(0 if _failures.is_empty() else 1)
