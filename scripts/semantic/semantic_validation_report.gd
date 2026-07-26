extends RefCounted
class_name SemanticValidationReport

const WIRE := preload("res://scripts/semantic/semantic_wire_v1.gd")
const SCHEMA_VERSION := 1
const REQUIRED_BUILD_FIELDS := [
	"schema_version",
	"report_id",
	"phase_id",
	"valid",
	"source_manifest_fingerprint",
	"issues",
	"domain_summaries",
	"unknown_condition_ids",
	"unknown_target_ids",
	"unknown_operation_ids",
	"unknown_randomness_policy_ids",
	"unknown_visibility_policy_ids",
	"unknown_mechanic_ids",
	"retired_identifier_hits",
	"active_operation_ids",
	"projection_only_operation_ids",
]
const OPTIONAL_BUILD_FIELDS := ["semantic_catalog_fingerprint", "registry_fingerprint"]
const REQUIRED_FIELDS := REQUIRED_BUILD_FIELDS + ["report_fingerprint"]
const OPTIONAL_FIELDS := OPTIONAL_BUILD_FIELDS
const FAIL_CLOSED_ID_FIELDS := [
	"unknown_condition_ids",
	"unknown_target_ids",
	"unknown_operation_ids",
	"unknown_randomness_policy_ids",
	"unknown_visibility_policy_ids",
	"unknown_mechanic_ids",
	"retired_identifier_hits",
]
const ISSUE_FIELDS := [
	"schema_version",
	"severity_id",
	"issue_code",
	"domain_id",
	"definition_id",
	"path",
]
const DOMAIN_SUMMARY_FIELDS := [
	"schema_version",
	"domain_id",
	"source_definition_count",
	"compiled_definition_count",
	"active_definition_count",
	"projection_only_definition_count",
	"failed_definition_count",
	"source_catalog_fingerprint",
	"semantic_catalog_fingerprint",
]
const SEVERITY_IDS := ["blocker", "error", "warning"]
const PHASE_FINGERPRINT_REQUIREMENTS := {
	"source_validation": [],
	"semantic_compilation": ["semantic_catalog_fingerprint"],
	"registry_seal": ["semantic_catalog_fingerprint", "registry_fingerprint"],
	"startup_readiness": ["semantic_catalog_fingerprint", "registry_fingerprint"],
}


static func build(unsealed: Dictionary) -> Dictionary:
	if not WIRE.is_closed_data(unsealed) \
			or not WIRE.exact_fields(unsealed, REQUIRED_BUILD_FIELDS, OPTIONAL_BUILD_FIELDS):
		return {}
	var sealed := WIRE.sealed_copy(unsealed, "report_fingerprint")
	return sealed if bool(validate(sealed).get("valid", false)) else {}


static func validate(value: Variant) -> Dictionary:
	if not (value is Dictionary) or not WIRE.is_closed_data(value):
		return WIRE.invalid_result("semantic_validation_report.not_closed_data")
	var report := value as Dictionary
	if not WIRE.exact_fields(report, REQUIRED_FIELDS, OPTIONAL_FIELDS):
		return WIRE.invalid_result("semantic_validation_report.fields_invalid")
	if report.get("schema_version") != SCHEMA_VERSION:
		return WIRE.invalid_result("semantic_validation_report.schema_version_invalid")
	for field in ["report_id", "phase_id"]:
		if not WIRE.is_stable_id(report.get(field)):
			return WIRE.invalid_result("semantic_validation_report.%s_invalid" % field)
	var phase_id := str(report.get("phase_id", ""))
	if not PHASE_FINGERPRINT_REQUIREMENTS.has(phase_id):
		return WIRE.invalid_result("semantic_validation_report.phase_id_unknown")
	if not (report.get("valid") is bool):
		return WIRE.invalid_result("semantic_validation_report.valid_invalid")
	if not WIRE.is_fingerprint(report.get("source_manifest_fingerprint")):
		return WIRE.invalid_result("semantic_validation_report.source_fingerprint_invalid")
	for fingerprint_field in OPTIONAL_BUILD_FIELDS:
		if report.has(fingerprint_field) and not WIRE.is_fingerprint(report.get(fingerprint_field)):
			return WIRE.invalid_result("semantic_validation_report.%s_invalid" % fingerprint_field)
	for required_fingerprint in PHASE_FINGERPRINT_REQUIREMENTS.get(phase_id, []) as Array:
		if not report.has(str(required_fingerprint)):
			return WIRE.invalid_result("semantic_validation_report.phase_fingerprint_missing")

	var issues_error := _issues_error(report.get("issues"))
	if not issues_error.is_empty():
		return WIRE.invalid_result("semantic_validation_report.%s" % issues_error)
	var summaries_error := _domain_summaries_error(report.get("domain_summaries"))
	if not summaries_error.is_empty():
		return WIRE.invalid_result("semantic_validation_report.%s" % summaries_error)
	for field in [
		"unknown_condition_ids",
		"unknown_target_ids",
		"unknown_operation_ids",
		"unknown_randomness_policy_ids",
		"unknown_visibility_policy_ids",
		"unknown_mechanic_ids",
		"retired_identifier_hits",
		"active_operation_ids",
		"projection_only_operation_ids",
	]:
		var ids_error := WIRE.stable_id_array_error(report.get(field), true, true)
		if not ids_error.is_empty():
			return WIRE.invalid_result("semantic_validation_report.%s_%s" % [field, ids_error])
	var has_invalidating_issue := false
	for issue_variant in report.get("issues") as Array:
		if ["blocker", "error"].has(str((issue_variant as Dictionary).get("severity_id", ""))):
			has_invalidating_issue = true
			break
	var has_fail_closed_id := false
	for field in FAIL_CLOSED_ID_FIELDS:
		if not (report.get(field, []) as Array).is_empty():
			has_fail_closed_id = true
			break
	var expected_valid := not has_invalidating_issue and not has_fail_closed_id
	if bool(report.get("valid", false)) != expected_valid:
		return WIRE.invalid_result("semantic_validation_report.validity_mismatch")
	if not WIRE.is_fingerprint(report.get("report_fingerprint")) \
			or str(report.get("report_fingerprint", "")) \
			!= WIRE.fingerprint(report, "report_fingerprint"):
		return WIRE.invalid_result("semantic_validation_report.fingerprint_invalid")
	return WIRE.valid_result()


static func _issues_error(value: Variant) -> String:
	if not (value is Array):
		return "issues_not_array"
	var previous_sort_key := ""
	for issue_variant in value as Array:
		if not (issue_variant is Dictionary) or not WIRE.is_closed_data(issue_variant):
			return "issue_not_closed_data"
		var issue := issue_variant as Dictionary
		if not WIRE.exact_fields(issue, ISSUE_FIELDS):
			return "issue_fields_invalid"
		if issue.get("schema_version") != SCHEMA_VERSION:
			return "issue_schema_version_invalid"
		if not SEVERITY_IDS.has(str(issue.get("severity_id", ""))):
			return "issue_severity_invalid"
		if not WIRE.is_stable_id(issue.get("issue_code")) \
				or not WIRE.DOMAIN_IDS.has(str(issue.get("domain_id", ""))) \
				or not WIRE.is_stable_id(issue.get("definition_id")) \
				or not WIRE.is_ascii_reference(issue.get("path")):
			return "issue_identity_invalid"
		var sort_key := "%d|%s|%s|%s|%s" % [
			SEVERITY_IDS.find(str(issue.get("severity_id", ""))),
			issue.get("domain_id", ""),
			issue.get("definition_id", ""),
			issue.get("path", ""),
			issue.get("issue_code", ""),
		]
		if not previous_sort_key.is_empty() and sort_key <= previous_sort_key:
			return "issues_not_sorted_unique"
		previous_sort_key = sort_key
	return ""

static func _domain_summaries_error(value: Variant) -> String:
	if not (value is Array):
		return "domain_summaries_not_array"
	var previous_domain := ""
	for summary_variant in value as Array:
		if not (summary_variant is Dictionary) or not WIRE.is_closed_data(summary_variant):
			return "domain_summary_not_closed_data"
		var summary := summary_variant as Dictionary
		if not WIRE.exact_fields(summary, DOMAIN_SUMMARY_FIELDS):
			return "domain_summary_fields_invalid"
		if summary.get("schema_version") != SCHEMA_VERSION \
				or not WIRE.DOMAIN_IDS.has(str(summary.get("domain_id", ""))):
			return "domain_summary_identity_invalid"
		var domain_id := str(summary.get("domain_id", ""))
		if not previous_domain.is_empty() and domain_id <= previous_domain:
			return "domain_summaries_not_sorted_unique"
		previous_domain = domain_id
		for count_field in [
			"source_definition_count",
			"compiled_definition_count",
			"active_definition_count",
			"projection_only_definition_count",
			"failed_definition_count",
		]:
			if not WIRE.is_nonnegative_integer(summary.get(count_field)):
				return "domain_summary_count_invalid"
		if not WIRE.is_fingerprint(summary.get("source_catalog_fingerprint")):
			return "domain_summary_source_fingerprint_invalid"
		var semantic_fingerprint: Variant = summary.get("semantic_catalog_fingerprint")
		if semantic_fingerprint != "" and not WIRE.is_fingerprint(semantic_fingerprint):
			return "domain_summary_semantic_fingerprint_invalid"
	return ""
