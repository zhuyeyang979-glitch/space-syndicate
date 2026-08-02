extends RefCounted

const SEMANTIC_WIRE := preload("res://scripts/semantic/semantic_wire_v1.gd")
const SCENARIO_IDENTITY := preload("res://scripts/tools/diagnostic_scenario_identity_v1.gd")
const CAPTURE_FAILURE := preload("res://scripts/runtime/save_owner_capture_failure_v1.gd")

const DIAGNOSTIC_ID := "TargetedOwnerCaptureDiagnosticV2"
const TIMELINE_ID := "TargetedOwnerCaptureDiagnosticPhaseTimelineV1"
const PHASES := [
	"diagnostic_started", "session_creating", "session_started",
	"scenario_identity_attesting", "scenario_identity_attested",
	"registry_binding_attesting", "registry_binding_attested",
	"owner_audit_started", "owner_capture_started", "owner_capture_succeeded",
	"owner_capture_failed", "owner_audit_completed", "diagnostic_completed",
]
const SECTION_ORDER := [
	"ruleset", "region_infrastructure", "region_supply", "commodity_flow",
	"routes", "player_mana", "commodity_belt_visibility", "card_inventory",
	"player_organization", "monsters", "military", "weather",
	"card_resolution_queue", "card_resolution_execution", "card_resolution_history",
	"ai", "bankruptcy_neutral_estate", "victory_control", "session",
]
const OWNER_ORDER := [
	"ruleset_runtime", "public_facility_region", "region_supply", "commodity_flow",
	"route_network", "player_mana", "commodity_belt_visibility", "card_inventory",
	"player_organization", "monster_runtime", "military_runtime", "weather_runtime",
	"card_resolution_queue", "card_resolution_execution", "card_resolution_history",
	"ai_runtime", "bankruptcy_neutral_estate", "victory_control", "game_session",
]
const ROOT_FIELDS := [
	"schema_version", "diagnostic_id", "run_id", "repository_head", "official", "formal",
	"scenario_identity", "scenario_identity_attested", "scenario_identity_failure",
	"registry_binding_attested",
	"harness_or_scenario_failure_attested", "diagnostic_phase_timeline",
	"last_completed_diagnostic_phase", "current_diagnostic_phase", "next_expected_diagnostic_phase",
	"owner_audit_started", "owner_audit_completed", "first_owner_capture_index",
	"last_completed_owner_capture_index", "owner_capture_attempted_count",
	"owner_capture_succeeded_count", "owner_capture_failed_count", "owner_capture_skipped_count",
	"owner_capture_rows", "first_failure", "owner_capture_failure_attested",
	"post_capture_validation", "post_capture_failure", "safety_green", "save_file_exists",
	"official_claim_path_present", "evidence_fingerprint",
]
const TIMELINE_FIELDS := [
	"schema_version", "timeline_id", "run_id", "repository_head", "phase_rows",
	"last_completed_phase", "current_phase", "next_expected_phase", "evidence_fingerprint",
]
const PHASE_ROW_FIELDS := [
	"sequence", "phase_id", "owner_index", "completed_monotonic_ms", "success",
	"reason_code", "evidence_fingerprint",
]
const OWNER_ROW_FIELDS := [
	"owner_index", "section_id", "owner_id", "owner_path", "capture_started",
	"capture_completed", "capture_result_kind", "state_version",
	"payload_fingerprint", "payload_pure_data", "elapsed_milliseconds",
	"mutation_count", "rng_draw_delta", "world_time_delta", "public_log_delta",
	"reason_code", "private_payload_redacted", "row_evidence_fingerprint",
]
const FAILURE_FIELDS := [
	"schema_version", "registry_operation_id", "capture_sequence", "section_index",
	"section_id", "owner_id", "owner_node_path", "owner_script_path", "capture_method",
	"failure_class", "reason_code", "method_missing", "method_exception",
	"result_not_dictionary", "result_empty", "result_not_pure_data", "result_header_invalid",
	"result_version_invalid", "result_ruleset_invalid", "state_version_observed",
	"ruleset_id_observed", "live_state_mutated_during_capture",
	"private_payload_redacted",
]
const POST_CAPTURE_FAILURE_CLASSES := [
	"OWNER_CAPTURE_MUTATED_RUNTIME",
	"REGISTRY_INTERNAL_ERROR",
]


static func new_timeline(run_id: String, repository_head: String) -> Dictionary:
	return _seal_timeline({
		"schema_version": 1,
		"timeline_id": TIMELINE_ID,
		"run_id": run_id,
		"repository_head": repository_head,
		"phase_rows": [],
		"last_completed_phase": "none",
		"current_phase": "none",
		"next_expected_phase": "diagnostic_started",
	})


static func advance(
	timeline: Dictionary,
	phase_id: String,
	owner_index: int = -1,
	success: bool = true,
	reason_code: String = "ok",
	monotonic_ms: int = -1
) -> Dictionary:
	var validation := timeline_validation_report(timeline)
	if not bool(validation.get("valid", false)):
		return {"advanced": false, "reason_code": str(validation.get("reason_code", "diagnostic_timeline_invalid")), "timeline": timeline.duplicate(true)}
	var rows: Array = (timeline.get("phase_rows", []) as Array).duplicate(true)
	var previous: Dictionary = rows.back() as Dictionary if not rows.is_empty() and rows.back() is Dictionary else {}
	var safe_reason := _safe_reason(reason_code)
	var unsealed_row := {
		"sequence": rows.size() + 1,
		"phase_id": phase_id,
		"owner_index": owner_index,
		"completed_monotonic_ms": monotonic_ms if monotonic_ms >= 0 else Time.get_ticks_msec(),
		"success": success,
		"reason_code": safe_reason,
	}
	if not _transition_allowed(previous, phase_id, owner_index, safe_reason) \
			or not _phase_row_semantics_valid(unsealed_row):
		return {"advanced": false, "reason_code": "diagnostic_phase_transition_invalid", "timeline": timeline.duplicate(true)}
	rows.append(SEMANTIC_WIRE.sealed_copy(unsealed_row, "evidence_fingerprint"))
	var next_phase := _next_expected_phase(phase_id, owner_index, success)
	var updated := {
		"schema_version": 1,
		"timeline_id": TIMELINE_ID,
		"run_id": str(timeline.get("run_id", "")),
		"repository_head": str(timeline.get("repository_head", "")),
		"phase_rows": rows,
		"last_completed_phase": phase_id,
		"current_phase": phase_id,
		"next_expected_phase": next_phase,
	}
	return {"advanced": true, "reason_code": "ok", "timeline": _seal_timeline(updated)}


static func build(source: Dictionary) -> Dictionary:
	var timeline: Dictionary = source.get("diagnostic_phase_timeline", {}) \
			if source.get("diagnostic_phase_timeline", {}) is Dictionary else {}
	var rows: Array = source.get("owner_capture_rows", []) \
			if source.get("owner_capture_rows", []) is Array else []
	var public_rows := _public_dictionary_array(rows, OWNER_ROW_FIELDS)
	var counts := _owner_counts(rows)
	var phase_rows: Array = timeline.get("phase_rows", []) \
			if timeline.get("phase_rows", []) is Array else []
	var unsealed := {
		"schema_version": 2,
		"diagnostic_id": DIAGNOSTIC_ID,
		"run_id": str(source.get("run_id", "")),
		"repository_head": str(source.get("repository_head", "")),
		"official": false,
		"formal": false,
		"scenario_identity": (source.get("scenario_identity", {}) as Dictionary).duplicate(true) if source.get("scenario_identity", {}) is Dictionary else {},
		"scenario_identity_attested": bool(source.get("scenario_identity_attested", false)),
		"scenario_identity_failure": (source.get("scenario_identity_failure", {}) as Dictionary).duplicate(true) if source.get("scenario_identity_failure", {}) is Dictionary else {},
		"registry_binding_attested": _timeline_has_phase(
			phase_rows, "registry_binding_attested"
		),
		"harness_or_scenario_failure_attested": bool(source.get("harness_or_scenario_failure_attested", false)),
		"diagnostic_phase_timeline": timeline.duplicate(true),
		"last_completed_diagnostic_phase": str(timeline.get("last_completed_phase", "none")),
		"current_diagnostic_phase": str(timeline.get("current_phase", "none")),
		"next_expected_diagnostic_phase": str(timeline.get("next_expected_phase", "none")),
		"owner_audit_started": bool(source.get("owner_audit_started", false)),
		"owner_audit_completed": bool(source.get("owner_audit_completed", false)),
		"first_owner_capture_index": int(source.get("first_owner_capture_index", -1)),
		"last_completed_owner_capture_index": int(source.get("last_completed_owner_capture_index", -1)),
		"owner_capture_attempted_count": int(counts.get("attempted", 0)),
		"owner_capture_succeeded_count": int(counts.get("succeeded", 0)),
		"owner_capture_failed_count": int(counts.get("failed", 0)),
		"owner_capture_skipped_count": int(counts.get("skipped", 0)),
		"owner_capture_rows": public_rows,
		"first_failure": _public_dictionary(source.get("first_failure", {}), FAILURE_FIELDS),
		"owner_capture_failure_attested": bool(source.get("owner_capture_failure_attested", false)),
		"post_capture_validation": str(source.get("post_capture_validation", "NOT_RUN")),
		"post_capture_failure": _public_dictionary(source.get("post_capture_failure", {}), FAILURE_FIELDS),
		"safety_green": bool(source.get("safety_green", false)),
		"save_file_exists": false,
		"official_claim_path_present": false,
	}
	return SEMANTIC_WIRE.sealed_copy(unsealed, "evidence_fingerprint")


static func validation_report(
	value: Variant,
	expected_run_id: String = "",
	expected_repository_head: String = "",
	expected_scenario_fingerprint: String = ""
) -> Dictionary:
	if not (value is Dictionary) or not _has_exact_fields(value as Dictionary, ROOT_FIELDS):
		return {"valid": false, "reason_code": "targeted_diagnostic_field_set_invalid"}
	var diagnostic := value as Dictionary
	if not (diagnostic.get("schema_version") is int) or int(diagnostic.get("schema_version", 0)) != 2 \
			or not _is_string(diagnostic.get("diagnostic_id")) \
			or str(diagnostic.get("diagnostic_id", "")) != DIAGNOSTIC_ID \
			or not (diagnostic.get("official") is bool) or bool(diagnostic.get("official", true)) \
			or not (diagnostic.get("formal") is bool) or bool(diagnostic.get("formal", true)) \
			or not (diagnostic.get("save_file_exists") is bool) or bool(diagnostic.get("save_file_exists", true)) \
			or not (diagnostic.get("official_claim_path_present") is bool) or bool(diagnostic.get("official_claim_path_present", true)):
		return {"valid": false, "reason_code": "targeted_diagnostic_header_invalid"}
	for boolean_field in [
		"scenario_identity_attested", "harness_or_scenario_failure_attested",
		"registry_binding_attested",
		"owner_audit_started", "owner_audit_completed",
		"owner_capture_failure_attested", "safety_green",
	]:
		if not (diagnostic.get(boolean_field) is bool):
			return {"valid": false, "reason_code": "targeted_diagnostic_boolean_field_invalid"}
	var run_id := str(diagnostic.get("run_id", "")) if _is_string(diagnostic.get("run_id")) else ""
	var repository_head := str(diagnostic.get("repository_head", "")) \
			if _is_string(diagnostic.get("repository_head")) else ""
	if not _safe_run_id(run_id):
		return {"valid": false, "reason_code": "targeted_diagnostic_run_id_invalid"}
	if not _lower_hex(repository_head, 40, 64):
		return {"valid": false, "reason_code": "targeted_diagnostic_repository_head_invalid"}
	if not expected_run_id.is_empty() and run_id != expected_run_id:
		return {"valid": false, "reason_code": "targeted_diagnostic_run_id_mismatch"}
	if not expected_repository_head.is_empty() and repository_head != expected_repository_head:
		return {"valid": false, "reason_code": "targeted_diagnostic_repository_head_mismatch"}
	for dictionary_field in [
		"scenario_identity", "scenario_identity_failure", "diagnostic_phase_timeline",
		"first_failure", "post_capture_failure",
	]:
		if not (diagnostic.get(dictionary_field) is Dictionary):
			return {"valid": false, "reason_code": "targeted_diagnostic_nested_type_invalid"}
	if not (diagnostic.get("owner_capture_rows") is Array) \
			or not _is_string(diagnostic.get("post_capture_validation")):
		return {"valid": false, "reason_code": "targeted_diagnostic_nested_type_invalid"}
	var timeline_report := timeline_validation_report(diagnostic.get("diagnostic_phase_timeline", {}))
	if not bool(timeline_report.get("valid", false)):
		return timeline_report
	var timeline := diagnostic.get("diagnostic_phase_timeline", {}) as Dictionary
	if str(timeline.get("run_id", "")) != run_id \
			or str(timeline.get("repository_head", "")) != repository_head:
		return {"valid": false, "reason_code": "targeted_diagnostic_timeline_identity_invalid"}
	if not _is_string(diagnostic.get("last_completed_diagnostic_phase")) \
			or not _is_string(diagnostic.get("current_diagnostic_phase")) \
			or not _is_string(diagnostic.get("next_expected_diagnostic_phase")) \
			or str(diagnostic.get("last_completed_diagnostic_phase", "")) != str(timeline.get("last_completed_phase", "")) \
			or str(diagnostic.get("current_diagnostic_phase", "")) != str(timeline.get("current_phase", "")) \
			or str(diagnostic.get("next_expected_diagnostic_phase", "")) != str(timeline.get("next_expected_phase", "")):
		return {"valid": false, "reason_code": "targeted_diagnostic_phase_binding_invalid"}
	if str(timeline.get("last_completed_phase", "")) != "diagnostic_completed" \
			or str(timeline.get("current_phase", "")) != "diagnostic_completed" \
			or str(timeline.get("next_expected_phase", "")) != "none":
		return {"valid": false, "reason_code": "targeted_diagnostic_terminal_invalid"}
	var phase_rows := timeline.get("phase_rows", []) as Array
	var timeline_identity_attested := _timeline_has_phase(phase_rows, "scenario_identity_attested")
	var timeline_registry_binding_attested := _timeline_has_phase(
		phase_rows, "registry_binding_attested"
	)
	var timeline_owner_audit_started := _timeline_has_phase(phase_rows, "owner_audit_started")
	var timeline_owner_audit_completed := _timeline_has_phase(phase_rows, "owner_audit_completed")
	if bool(diagnostic.get("scenario_identity_attested", false)) != timeline_identity_attested \
			or bool(diagnostic.get("registry_binding_attested", false)) != timeline_registry_binding_attested \
			or bool(diagnostic.get("owner_audit_started", false)) != timeline_owner_audit_started \
			or bool(diagnostic.get("owner_audit_completed", false)) != timeline_owner_audit_completed:
		return {"valid": false, "reason_code": "targeted_diagnostic_phase_state_invalid"}
	var identity_attested := bool(diagnostic.get("scenario_identity_attested", false))
	var identity_failure: Dictionary = diagnostic.get("scenario_identity_failure", {}) as Dictionary
	if identity_attested:
		var identity_report := SCENARIO_IDENTITY.validation_report(
			diagnostic.get("scenario_identity", {}), run_id,
			repository_head, expected_scenario_fingerprint
		)
		if not bool(identity_report.get("valid", false)):
			return {"valid": false, "reason_code": "targeted_diagnostic_identity_binding_invalid"}
		if bool(diagnostic.get("harness_or_scenario_failure_attested", false)):
			if not SCENARIO_IDENTITY.valid_failure(identity_failure) \
					or bool(diagnostic.get("owner_audit_started", true)):
				return {"valid": false, "reason_code": "targeted_diagnostic_pre_owner_failure_invalid"}
		elif not identity_failure.is_empty():
			return {"valid": false, "reason_code": "targeted_diagnostic_identity_binding_invalid"}
	else:
		if not bool(diagnostic.get("harness_or_scenario_failure_attested", false)) \
				or not SCENARIO_IDENTITY.valid_failure(identity_failure) \
				or bool(diagnostic.get("owner_audit_started", true)):
			return {"valid": false, "reason_code": "targeted_diagnostic_pre_owner_failure_invalid"}
	var owner_rows: Array = diagnostic.get("owner_capture_rows", []) as Array
	var counts := _owner_counts(owner_rows)
	var first_failure: Dictionary = diagnostic.get("first_failure", {}) as Dictionary
	var post_capture_failure: Dictionary = diagnostic.get("post_capture_failure", {}) as Dictionary
	for field_and_count in [
		["owner_capture_attempted_count", counts.get("attempted", -1)],
		["owner_capture_succeeded_count", counts.get("succeeded", -1)],
		["owner_capture_failed_count", counts.get("failed", -1)],
		["owner_capture_skipped_count", counts.get("skipped", -1)],
	]:
		if not (diagnostic.get(field_and_count[0]) is int) \
				or int(diagnostic.get(field_and_count[0], -2)) != int(field_and_count[1]):
			return {"valid": false, "reason_code": "targeted_diagnostic_owner_count_invalid"}
	for index_field in ["first_owner_capture_index", "last_completed_owner_capture_index"]:
		if not (diagnostic.get(index_field) is int):
			return {"valid": false, "reason_code": "targeted_diagnostic_owner_index_invalid"}
	if not first_failure.is_empty() and not _valid_capture_failure(first_failure):
		return {"valid": false, "reason_code": "targeted_diagnostic_first_owner_failure_invalid"}
	if not post_capture_failure.is_empty():
		if not _valid_capture_failure(post_capture_failure) \
				or str(post_capture_failure.get("failure_class", "")) not in POST_CAPTURE_FAILURE_CLASSES:
			return {"valid": false, "reason_code": "targeted_diagnostic_post_capture_failure_invalid"}
		if not first_failure.is_empty() \
				and SEMANTIC_WIRE.fingerprint(first_failure) == SEMANTIC_WIRE.fingerprint(post_capture_failure):
			return {"valid": false, "reason_code": "targeted_diagnostic_post_capture_failure_not_distinct"}
	if bool(diagnostic.get("owner_audit_started", false)):
		if not identity_attested or owner_rows.size() != SECTION_ORDER.size() \
				or int(diagnostic.get("first_owner_capture_index", -1)) != 0:
			return {"valid": false, "reason_code": "targeted_diagnostic_owner_audit_shape_invalid"}
		for row_index in range(owner_rows.size()):
			if not _valid_owner_row(owner_rows[row_index], row_index):
				return {"valid": false, "reason_code": "targeted_diagnostic_owner_row_invalid"}
		if not _valid_owner_result_order(owner_rows) \
				or not bool(diagnostic.get("owner_audit_completed", false)):
			return {"valid": false, "reason_code": "targeted_diagnostic_owner_audit_incomplete"}
		var failed_count := int(counts.get("failed", 0))
		if failed_count == 0:
			if int(counts.get("succeeded", 0)) != SECTION_ORDER.size() or not first_failure.is_empty() \
					or bool(diagnostic.get("owner_capture_failure_attested", true)) \
					or int(diagnostic.get("last_completed_owner_capture_index", -1)) != SECTION_ORDER.size() - 1:
				return {"valid": false, "reason_code": "targeted_diagnostic_all_owner_result_invalid"}
			var post_validation := str(diagnostic.get("post_capture_validation", ""))
			if post_capture_failure.is_empty():
				if post_validation != "PASSED":
					return {"valid": false, "reason_code": "targeted_diagnostic_post_capture_result_invalid"}
			elif post_validation != "FAILED":
				return {"valid": false, "reason_code": "targeted_diagnostic_post_capture_result_invalid"}
		else:
			var failure_index := _first_failed_index(owner_rows)
			if failed_count != 1 or first_failure.is_empty() \
					or not bool(diagnostic.get("owner_capture_failure_attested", false)) \
					or int(diagnostic.get("last_completed_owner_capture_index", -1)) != failure_index \
					or int(first_failure.get("section_index", -1)) != failure_index \
					or (post_capture_failure.is_empty() \
							and str((owner_rows[failure_index] as Dictionary).get("reason_code", "")) != str(first_failure.get("reason_code", ""))) \
					or (not post_capture_failure.is_empty() \
							and (int(post_capture_failure.get("section_index", -1)) != failure_index \
									or str((owner_rows[failure_index] as Dictionary).get("reason_code", "")) != str(post_capture_failure.get("reason_code", "")))) \
					or (post_capture_failure.is_empty() \
							and str(diagnostic.get("post_capture_validation", "")) != "NOT_RUN_AFTER_OWNER_FAILURE") \
					or (not post_capture_failure.is_empty() \
							and str(diagnostic.get("post_capture_validation", "")) != "FAILED"):
				return {"valid": false, "reason_code": "targeted_diagnostic_first_owner_failure_invalid"}
		if not _timeline_matches_owner_rows(phase_rows, owner_rows, first_failure):
			return {"valid": false, "reason_code": "targeted_diagnostic_owner_timeline_invalid"}
	else:
		if not owner_rows.is_empty() or bool(diagnostic.get("owner_audit_completed", false)) \
				or int(diagnostic.get("first_owner_capture_index", -1)) != -1 \
				or int(diagnostic.get("last_completed_owner_capture_index", -1)) != -1 \
				or not first_failure.is_empty() \
				or bool(diagnostic.get("owner_capture_failure_attested", false)) \
				or not post_capture_failure.is_empty() \
				or str(diagnostic.get("post_capture_validation", "")) != "NOT_RUN":
			return {"valid": false, "reason_code": "targeted_diagnostic_pre_owner_payload_invalid"}
	var safety_green := _owner_capture_safety_green(owner_rows, first_failure, post_capture_failure)
	if bool(diagnostic.get("safety_green", false)) != safety_green:
		return {"valid": false, "reason_code": "targeted_diagnostic_safety_binding_invalid"}
	var expected_fingerprint := SEMANTIC_WIRE.fingerprint(diagnostic, "evidence_fingerprint")
	if expected_fingerprint.is_empty() or str(diagnostic.get("evidence_fingerprint", "")) != expected_fingerprint:
		return {"valid": false, "reason_code": "targeted_diagnostic_fingerprint_invalid"}
	return {"valid": true, "reason_code": "ok", "safety_green": safety_green}


static func timeline_validation_report(value: Variant) -> Dictionary:
	if not (value is Dictionary) or not _has_exact_fields(value as Dictionary, TIMELINE_FIELDS):
		return {"valid": false, "reason_code": "diagnostic_timeline_field_set_invalid"}
	var timeline := value as Dictionary
	if not (timeline.get("schema_version") is int) or int(timeline.get("schema_version", 0)) != 1 \
			or not _is_string(timeline.get("timeline_id")) \
			or str(timeline.get("timeline_id", "")) != TIMELINE_ID \
			or not _is_string(timeline.get("run_id")) \
			or not _safe_run_id(str(timeline.get("run_id", ""))) \
			or not _is_string(timeline.get("repository_head")) \
			or not _lower_hex(str(timeline.get("repository_head", "")), 40, 64) \
			or not _is_string(timeline.get("last_completed_phase")) \
			or not _is_string(timeline.get("current_phase")) \
			or not _is_string(timeline.get("next_expected_phase")) \
			or not (timeline.get("phase_rows") is Array):
		return {"valid": false, "reason_code": "diagnostic_timeline_header_invalid"}
	var rows: Array = timeline.get("phase_rows", []) as Array
	var previous: Dictionary = {}
	var previous_ms := -1
	for row_index in range(rows.size()):
		if not (rows[row_index] is Dictionary) or not _has_exact_fields(rows[row_index] as Dictionary, PHASE_ROW_FIELDS):
			return {"valid": false, "reason_code": "diagnostic_timeline_row_invalid"}
		var row := rows[row_index] as Dictionary
		if not (row.get("sequence") is int) or int(row.get("sequence", 0)) != row_index + 1 \
				or not (row.get("owner_index") is int) or not (row.get("completed_monotonic_ms") is int) \
				or int(row.get("completed_monotonic_ms", -1)) < previous_ms \
				or not (row.get("success") is bool) \
				or not _is_string(row.get("phase_id")) \
				or not _is_string(row.get("reason_code")) \
				or not _is_string(row.get("evidence_fingerprint")) \
				or str(row.get("phase_id", "")) not in PHASES \
				or not _transition_allowed(previous, str(row.get("phase_id", "")), int(row.get("owner_index", -1)), str(row.get("reason_code", ""))) \
				or not _phase_row_semantics_valid(row) \
				or str(row.get("evidence_fingerprint", "")) != SEMANTIC_WIRE.fingerprint(row, "evidence_fingerprint"):
			return {"valid": false, "reason_code": "diagnostic_timeline_row_invalid"}
		previous = row
		previous_ms = int(row.get("completed_monotonic_ms", -1))
	var last_phase := str(previous.get("phase_id", "none"))
	if str(timeline.get("last_completed_phase", "")) != last_phase \
			or str(timeline.get("current_phase", "")) != last_phase:
		return {"valid": false, "reason_code": "diagnostic_timeline_terminal_invalid"}
	var expected_next := "diagnostic_started" if rows.is_empty() else _next_expected_phase(
		str(previous.get("phase_id", "")),
		int(previous.get("owner_index", -1)),
		bool(previous.get("success", false))
	)
	if str(timeline.get("next_expected_phase", "")) != expected_next:
		return {"valid": false, "reason_code": "diagnostic_timeline_next_expected_invalid"}
	var expected_fingerprint := SEMANTIC_WIRE.fingerprint(timeline, "evidence_fingerprint")
	if expected_fingerprint.is_empty() or str(timeline.get("evidence_fingerprint", "")) != expected_fingerprint:
		return {"valid": false, "reason_code": "diagnostic_timeline_fingerprint_invalid"}
	return {"valid": true, "reason_code": "ok"}


static func _seal_timeline(value: Dictionary) -> Dictionary:
	return SEMANTIC_WIRE.sealed_copy(value, "evidence_fingerprint")


static func _transition_allowed(previous: Dictionary, phase_id: String, owner_index: int, reason_code: String) -> bool:
	var previous_phase := str(previous.get("phase_id", ""))
	var previous_owner := int(previous.get("owner_index", -1))
	if previous_phase.is_empty():
		return phase_id == "diagnostic_started" and owner_index == -1
	var fixed_next := {
		"diagnostic_started": "session_creating",
		"session_creating": "session_started",
		"session_started": "scenario_identity_attesting",
		"scenario_identity_attesting": "scenario_identity_attested",
		"scenario_identity_attested": "registry_binding_attesting",
		"registry_binding_attesting": "registry_binding_attested",
		"registry_binding_attested": "owner_audit_started",
	}
	if fixed_next.has(previous_phase):
		return (phase_id == str(fixed_next.get(previous_phase)) and owner_index == -1) \
				or (phase_id == "diagnostic_completed" and owner_index == -1 and reason_code.begins_with("diagnostic_pre_owner_"))
	if previous_phase == "owner_audit_started":
		return phase_id == "owner_capture_started" and owner_index == 0
	if previous_phase == "owner_capture_started":
		return phase_id in ["owner_capture_succeeded", "owner_capture_failed"] and owner_index == previous_owner
	if previous_phase == "owner_capture_succeeded":
		return (previous_owner < SECTION_ORDER.size() - 1 and phase_id == "owner_capture_started" and owner_index == previous_owner + 1) \
				or (previous_owner == SECTION_ORDER.size() - 1 and phase_id == "owner_audit_completed" and owner_index == -1)
	if previous_phase == "owner_capture_failed":
		return phase_id == "owner_audit_completed" and owner_index == -1
	if previous_phase == "owner_audit_completed":
		return phase_id == "diagnostic_completed" and owner_index == -1
	return false


static func _next_expected_phase(phase_id: String, owner_index: int, success: bool) -> String:
	if phase_id == "diagnostic_completed":
		return "none"
	if not success:
		return "none"
	var fixed := {
		"diagnostic_started": "session_creating",
		"session_creating": "session_started",
		"session_started": "scenario_identity_attesting",
		"scenario_identity_attesting": "scenario_identity_attested",
		"scenario_identity_attested": "registry_binding_attesting",
		"registry_binding_attesting": "registry_binding_attested",
		"registry_binding_attested": "owner_audit_started",
		"owner_audit_started": "owner_capture_started",
		"owner_capture_started": "owner_capture_succeeded_or_failed",
		"owner_capture_failed": "owner_audit_completed",
		"owner_audit_completed": "diagnostic_completed",
	}
	if phase_id == "owner_capture_succeeded":
		return "owner_capture_started" if owner_index < SECTION_ORDER.size() - 1 else "owner_audit_completed"
	return str(fixed.get(phase_id, "none"))


static func _phase_row_semantics_valid(row: Dictionary) -> bool:
	# `success` attests that the phase event itself completed and was written.
	# Diagnostic outcome failures use closed phase IDs and reason codes instead.
	if not (row.get("success") is bool) or not bool(row.get("success", false)):
		return false
	var phase_id := str(row.get("phase_id", ""))
	var owner_index := int(row.get("owner_index", -2)) if row.get("owner_index") is int else -2
	var reason_code := str(row.get("reason_code", "")) if _is_string(row.get("reason_code")) else ""
	if reason_code.is_empty() or reason_code != _safe_reason(reason_code):
		return false
	if phase_id in ["owner_capture_started", "owner_capture_succeeded", "owner_capture_failed"]:
		if owner_index < 0 or owner_index >= SECTION_ORDER.size():
			return false
		if phase_id == "owner_capture_started":
			return reason_code == "owner_capture_started"
		if phase_id == "owner_capture_succeeded":
			return reason_code == "owner_capture_valid"
		return CAPTURE_FAILURE.is_reason_code(reason_code) and reason_code != "owner_capture_valid"
	if owner_index != -1:
		return false
	if phase_id == "diagnostic_completed":
		return reason_code == "diagnostic_owner_audit_completed" \
				or (reason_code.begins_with("diagnostic_pre_owner_") \
						and reason_code.length() > "diagnostic_pre_owner_".length())
	return reason_code == "ok"


static func _valid_owner_row(value: Variant, expected_index: int) -> bool:
	if not (value is Dictionary) or not _has_exact_fields(value as Dictionary, OWNER_ROW_FIELDS):
		return false
	var row := value as Dictionary
	if not (row.get("owner_index") is int) or int(row.get("owner_index", -1)) != expected_index \
			or not _is_string(row.get("section_id")) \
			or str(row.get("section_id", "")) != str(SECTION_ORDER[expected_index]) \
			or not _is_string(row.get("owner_id")) \
			or str(row.get("owner_id", "")) != str(OWNER_ORDER[expected_index]) \
			or not _is_string(row.get("owner_path")) or not _safe_path(str(row.get("owner_path", ""))) \
			or not (row.get("capture_started") is bool) or not (row.get("capture_completed") is bool) \
			or not _is_string(row.get("capture_result_kind")) \
			or not (row.get("state_version") is int) \
			or not _is_string(row.get("payload_fingerprint")) \
			or not (row.get("payload_pure_data") is bool) \
			or not (row.get("elapsed_milliseconds") is int) or int(row.get("elapsed_milliseconds", -1)) < 0 \
			or not (row.get("mutation_count") is int) or int(row.get("mutation_count", -1)) < 0 \
			or not (row.get("rng_draw_delta") is int) or not (row.get("world_time_delta") is int) \
			or not (row.get("public_log_delta") is int) \
			or not _is_string(row.get("reason_code")) \
			or not (row.get("private_payload_redacted") is bool) or not bool(row.get("private_payload_redacted", false)):
		return false
	var kind := str(row.get("capture_result_kind", ""))
	var fingerprint := str(row.get("payload_fingerprint", ""))
	if kind == "CAPTURED":
		if not bool(row.get("capture_started", false)) or not bool(row.get("capture_completed", false)) \
				or int(row.get("state_version", 0)) < 1 \
				or not bool(row.get("payload_pure_data", false)) or not _lower_sha256(fingerprint) \
				or str(row.get("reason_code", "")) != "owner_capture_valid":
			return false
	elif kind == "FAILED":
		if not bool(row.get("capture_started", false)) or not bool(row.get("capture_completed", false)) \
				or int(row.get("state_version", -2)) < -1 \
				or bool(row.get("payload_pure_data", true)) \
				or (not fingerprint.is_empty() and not _lower_sha256(fingerprint)) \
				or not CAPTURE_FAILURE.is_reason_code(str(row.get("reason_code", ""))) \
				or str(row.get("reason_code", "")) == "owner_capture_valid":
			return false
	elif kind == "NOT_ATTEMPTED_AFTER_FIRST_FAILURE":
		if bool(row.get("capture_started", true)) or bool(row.get("capture_completed", true)) \
				or int(row.get("state_version", 0)) != -1 \
				or not fingerprint.is_empty() or bool(row.get("payload_pure_data", true)) \
				or int(row.get("elapsed_milliseconds", -1)) != 0 \
				or int(row.get("mutation_count", -1)) != 0 \
				or int(row.get("rng_draw_delta", 1)) != 0 \
				or int(row.get("world_time_delta", 1)) != 0 \
				or int(row.get("public_log_delta", 1)) != 0 \
				or str(row.get("reason_code", "")) != "not_attempted_after_first_failure":
			return false
	else:
		return false
	return _is_string(row.get("row_evidence_fingerprint")) \
			and str(row.get("row_evidence_fingerprint", "")) == SEMANTIC_WIRE.fingerprint(row, "row_evidence_fingerprint")


static func _owner_counts(rows: Array) -> Dictionary:
	var result := {"attempted": 0, "succeeded": 0, "failed": 0, "skipped": 0}
	for row_variant in rows:
		if not (row_variant is Dictionary):
			continue
		match str((row_variant as Dictionary).get("capture_result_kind", "")):
			"CAPTURED":
				result["attempted"] += 1
				result["succeeded"] += 1
			"FAILED":
				result["attempted"] += 1
				result["failed"] += 1
			"NOT_ATTEMPTED_AFTER_FIRST_FAILURE":
				result["skipped"] += 1
	return result


static func _first_failed_index(rows: Array) -> int:
	for index in range(rows.size()):
		if rows[index] is Dictionary \
				and str((rows[index] as Dictionary).get("capture_result_kind", "")) == "FAILED":
			return index
	return -1


static func _valid_owner_result_order(rows: Array) -> bool:
	var failure_seen := false
	for row_variant in rows:
		if not (row_variant is Dictionary):
			return false
		match str((row_variant as Dictionary).get("capture_result_kind", "")):
			"CAPTURED":
				if failure_seen:
					return false
			"FAILED":
				if failure_seen:
					return false
				failure_seen = true
			"NOT_ATTEMPTED_AFTER_FIRST_FAILURE":
				if not failure_seen:
					return false
			_:
				return false
	return true


static func _timeline_matches_owner_rows(
	phase_rows: Array,
	owner_rows: Array,
	first_failure: Dictionary
) -> bool:
	var owner_events: Array = []
	for phase_variant in phase_rows:
		if phase_variant is Dictionary \
				and str((phase_variant as Dictionary).get("phase_id", "")) in [
					"owner_capture_started", "owner_capture_succeeded", "owner_capture_failed",
				]:
			owner_events.append(phase_variant)
	var event_index := 0
	for row_variant in owner_rows:
		var row := row_variant as Dictionary
		var result_kind := str(row.get("capture_result_kind", ""))
		if result_kind == "NOT_ATTEMPTED_AFTER_FIRST_FAILURE":
			continue
		if event_index + 1 >= owner_events.size():
			return false
		var started := owner_events[event_index] as Dictionary
		var completed := owner_events[event_index + 1] as Dictionary
		var owner_index := int(row.get("owner_index", -1))
		if str(started.get("phase_id", "")) != "owner_capture_started" \
				or int(started.get("owner_index", -1)) != owner_index \
				or str(completed.get("phase_id", "")) != ("owner_capture_succeeded" if result_kind == "CAPTURED" else "owner_capture_failed") \
				or int(completed.get("owner_index", -1)) != owner_index:
			return false
		if result_kind == "CAPTURED":
			if str(completed.get("reason_code", "")) != "owner_capture_valid":
				return false
		elif first_failure.is_empty() \
				or str(completed.get("reason_code", "")) != str(first_failure.get("reason_code", "")):
			return false
		event_index += 2
	return event_index == owner_events.size()


static func _owner_capture_safety_green(
	owner_rows: Array,
	first_failure: Dictionary,
	post_capture_failure: Dictionary
) -> bool:
	for row_variant in owner_rows:
		if not (row_variant is Dictionary):
			return false
		var row := row_variant as Dictionary
		if int(row.get("mutation_count", 0)) != 0 \
				or int(row.get("rng_draw_delta", 0)) != 0 \
				or int(row.get("world_time_delta", 0)) != 0 \
				or int(row.get("public_log_delta", 0)) != 0:
			return false
	for failure in [first_failure, post_capture_failure]:
		if failure is Dictionary and bool((failure as Dictionary).get("live_state_mutated_during_capture", false)):
			return false
	return true


static func _timeline_has_phase(rows: Array, phase_id: String) -> bool:
	for row_variant in rows:
		if row_variant is Dictionary \
				and str((row_variant as Dictionary).get("phase_id", "")) == phase_id:
			return true
	return false


static func _valid_capture_failure(value: Dictionary) -> bool:
	if not _has_exact_fields(value, FAILURE_FIELDS):
		return false
	var section_index := int(value.get("section_index", -1)) \
			if value.get("section_index") is int else -1
	if not (value.get("schema_version") is int) \
			or int(value.get("schema_version", 0)) != int(CAPTURE_FAILURE.SCHEMA_VERSION) \
			or not _is_string(value.get("registry_operation_id")) \
			or str(value.get("registry_operation_id", "")).is_empty() \
			or not (value.get("capture_sequence") is int) or int(value.get("capture_sequence", 0)) < 1 \
			or section_index < 0 or section_index >= SECTION_ORDER.size() \
			or not _is_string(value.get("section_id")) \
			or str(value.get("section_id", "")) != str(SECTION_ORDER[section_index]) \
			or not _is_string(value.get("owner_id")) \
			or str(value.get("owner_id", "")) != str(OWNER_ORDER[section_index]) \
			or not _is_string(value.get("owner_node_path")) \
			or (not str(value.get("owner_node_path", "")).is_empty() \
					and not _safe_path(str(value.get("owner_node_path", "")))) \
			or not _is_string(value.get("owner_script_path")) \
			or (not str(value.get("owner_script_path", "")).is_empty() \
					and not _safe_path(str(value.get("owner_script_path", "")))) \
			or not _is_string(value.get("capture_method")) \
			or not _is_string(value.get("failure_class")) \
			or not CAPTURE_FAILURE.is_failure_class(str(value.get("failure_class", ""))) \
			or not _is_string(value.get("reason_code")) \
			or not CAPTURE_FAILURE.is_reason_code(str(value.get("reason_code", ""))) \
			or not (value.get("state_version_observed") is int) \
			or int(value.get("state_version_observed", -2)) < -1 \
			or not _is_string(value.get("ruleset_id_observed")) \
			or not (value.get("private_payload_redacted") is bool) \
			or not bool(value.get("private_payload_redacted", false)):
		return false
	for boolean_field in [
		"method_missing", "method_exception", "result_empty", "result_not_dictionary", "result_not_pure_data",
		"result_header_invalid", "result_version_invalid", "result_ruleset_invalid",
		"live_state_mutated_during_capture",
	]:
		if not (value.get(boolean_field) is bool):
			return false
	var canonical := CAPTURE_FAILURE.build({
		"registry_operation_id": value.get("registry_operation_id"),
		"capture_sequence": value.get("capture_sequence"),
		"section_index": value.get("section_index"),
		"section_id": value.get("section_id"),
		"owner_id": value.get("owner_id"),
		"owner_node_path": value.get("owner_node_path"),
		"owner_script_path": value.get("owner_script_path"),
		"capture_method": value.get("capture_method"),
		"failure_class": value.get("failure_class"),
		"reason_code": value.get("reason_code"),
		"method_missing": value.get("method_missing"),
		"method_exception": value.get("method_exception"),
		"result_empty": value.get("result_empty"),
		"result_not_dictionary": value.get("result_not_dictionary"),
		"result_not_pure_data": value.get("result_not_pure_data"),
		"result_header_invalid": value.get("result_header_invalid"),
		"result_version_invalid": value.get("result_version_invalid"),
		"result_ruleset_invalid": value.get("result_ruleset_invalid"),
		"state_version_observed": value.get("state_version_observed"),
		"ruleset_id_observed": value.get("ruleset_id_observed"),
		"live_state_mutated_during_capture": value.get("live_state_mutated_during_capture"),
	})
	for field_variant in FAILURE_FIELDS:
		var field := str(field_variant)
		if canonical.get(field) != value.get(field):
			return false
	match str(value.get("failure_class", "")):
		"OWNER_METHOD_MISSING":
			return bool(value.get("method_missing", false))
		"OWNER_CAPTURE_EXCEPTION":
			return bool(value.get("method_exception", false))
		"OWNER_CAPTURE_WRONG_TYPE":
			return bool(value.get("result_not_dictionary", false))
		"OWNER_CAPTURE_EMPTY":
			return bool(value.get("result_empty", false))
		"OWNER_CAPTURE_NOT_PURE_DATA":
			return bool(value.get("result_not_pure_data", false))
		"OWNER_CAPTURE_HEADER_INVALID":
			return bool(value.get("result_header_invalid", false))
		"OWNER_CAPTURE_VERSION_INVALID":
			return bool(value.get("result_version_invalid", false))
		"OWNER_CAPTURE_RULESET_INVALID":
			return bool(value.get("result_ruleset_invalid", false))
		"OWNER_CAPTURE_MUTATED_RUNTIME":
			return bool(value.get("live_state_mutated_during_capture", false))
	return true


static func _safe_reason(value: String) -> String:
	var normalized := value.strip_edges().to_lower()
	var result := ""
	for index in range(normalized.length()):
		var character := normalized.substr(index, 1)
		if "abcdefghijklmnopqrstuvwxyz0123456789_".contains(character):
			result += character
		elif not result.ends_with("_"):
			result += "_"
	return result.trim_prefix("_").trim_suffix("_").left(128)


static func _public_dictionary(value: Variant, fields: Array) -> Dictionary:
	if not (value is Dictionary):
		return {}
	var source := value as Dictionary
	var result: Dictionary = {}
	for field_variant in fields:
		var field := str(field_variant)
		if source.has(field):
			result[field] = source.get(field)
	return result


static func _public_dictionary_array(values: Array, fields: Array) -> Array:
	var result: Array = []
	for value in values:
		result.append(_public_dictionary(value, fields))
	return result


static func _is_string(value: Variant) -> bool:
	return value is String or value is StringName


static func _safe_run_id(value: String) -> bool:
	if value.is_empty() or value.length() > 96:
		return false
	for index in range(value.length()):
		if not "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-".contains(value.substr(index, 1)):
			return false
	return true


static func _safe_path(value: String) -> bool:
	if value.is_empty() or value.length() > 256:
		return false
	for index in range(value.length()):
		if not "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_./:-".contains(value.substr(index, 1)):
			return false
	return true


static func _has_exact_fields(value: Dictionary, fields: Array) -> bool:
	if value.size() != fields.size():
		return false
	for field_variant in fields:
		if not value.has(str(field_variant)):
			return false
	return true


static func _lower_sha256(value: String) -> bool:
	if value.length() != 64:
		return false
	for index in range(value.length()):
		if not "0123456789abcdef".contains(value.substr(index, 1)):
			return false
	return true


static func _lower_hex(value: String, minimum: int, maximum: int) -> bool:
	if value.length() < minimum or value.length() > maximum:
		return false
	for index in range(value.length()):
		if not "0123456789abcdef".contains(value.substr(index, 1)):
			return false
	return true
