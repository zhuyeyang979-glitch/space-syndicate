extends RefCounted
class_name RemainingOwnerClosedDataPreflightAttemptV4

const AUTHORIZATION_PATH := "res://scripts/tools/remaining_owner_closed_data_preflight_attempt_v4_authorization.json"
const PRIOR_ATTEMPT_CHILD_PATH := "res://reports/handoffs/alpha04c_remaining_owner_preflight_index16_18_attempt_v3.json"
const PRIOR_ATTEMPT_PARENT_PATH := "res://reports/handoffs/alpha04c_remaining_owner_preflight_index16_18_attempt_v3_parent_attestation.json"
const VICTORY_REPLAY_CHILD_PATH := "res://reports/handoffs/alpha04c_victory_control_owner_replay_v1.json"
const VICTORY_REPLAY_PARENT_PATH := "res://reports/handoffs/alpha04c_victory_control_owner_replay_v1_parent_attestation.json"
const ATTEMPT_ROOT_RELATIVE_PATH := "codex/cold_restore_v3/non-official-alpha04c-remaining-owner-preflight-index18-attempt-v4"
const CONTRACT_ID := "RemainingOwnerClosedDataPreflightAttemptV4"
const ATTEMPT_ID := "alpha04c-remaining-owner-preflight-index18-attempt-v4"
const START_INDEX := 18
const END_INDEX := 18
const QUALIFIED_PRIOR_OWNER_COUNT := 10
const AUTHORIZATION_FIELDS := [
	"schema_version",
	"contract_id",
	"attempt_id",
	"start_index",
	"end_index",
	"qualified_prior_owner_count",
	"attempt_count_before",
	"authorized_new_attempt_count",
	"attempt_count_after",
	"targeted_owner_capture_diagnostic_count_before",
	"targeted_owner_capture_diagnostic_count_after",
	"prior_attempt_v3_child_sha256",
	"prior_attempt_v3_parent_sha256",
	"victory_replay_child_sha256",
	"victory_replay_parent_sha256",
	"victory_replay_evidence_commit",
	"pr77_victory_merge_commit",
]
const CLAIM_FIELDS := [
	"schema_version",
	"claim_id",
	"attempt_id",
	"frozen_code_head",
	"start_index",
	"end_index",
	"attempt_count_before",
	"authorized_new_attempt_count",
	"attempt_count_after",
	"started_at",
	"private_payload_redacted",
]
const ADMISSION_FIELDS := [
	"schema_version",
	"admission_id",
	"claim_sha256",
	"attempt_id",
	"frozen_code_head",
]


static func authorization() -> Dictionary:
	if not FileAccess.file_exists(AUTHORIZATION_PATH):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(AUTHORIZATION_PATH))
	if not (parsed is Dictionary):
		return {}
	var value := parsed as Dictionary
	if not _has_exact_fields(value, AUTHORIZATION_FIELDS) \
			or not _json_integer_equals(value.get("schema_version"), 1) \
			or str(value.get("contract_id", "")) != "RemainingOwnerClosedDataPreflightAttemptV4Authorization" \
			or str(value.get("attempt_id", "")) != ATTEMPT_ID \
			or not _json_integer_equals(value.get("start_index"), START_INDEX) \
			or not _json_integer_equals(value.get("end_index"), END_INDEX) \
			or not _json_integer_equals(value.get("qualified_prior_owner_count"), QUALIFIED_PRIOR_OWNER_COUNT) \
			or not _json_integer_equals(value.get("attempt_count_before"), 0) \
			or not _json_integer_equals(value.get("authorized_new_attempt_count"), 1) \
			or not _json_integer_equals(value.get("attempt_count_after"), 1) \
			or not _json_integer_equals(value.get("targeted_owner_capture_diagnostic_count_before"), 7) \
			or not _json_integer_equals(value.get("targeted_owner_capture_diagnostic_count_after"), 7):
		return {}
	for field in [
		"prior_attempt_v3_child_sha256", "prior_attempt_v3_parent_sha256",
		"victory_replay_child_sha256", "victory_replay_parent_sha256",
	]:
		if not _lower_hex(str(value.get(field, "")), 64):
			return {}
	for field in ["victory_replay_evidence_commit", "pr77_victory_merge_commit"]:
		if not _lower_hex(str(value.get(field, "")), 40):
			return {}
	if FileAccess.get_sha256(PRIOR_ATTEMPT_CHILD_PATH).to_lower() \
			!= str(value.get("prior_attempt_v3_child_sha256", "")) \
			or FileAccess.get_sha256(PRIOR_ATTEMPT_PARENT_PATH).to_lower() \
			!= str(value.get("prior_attempt_v3_parent_sha256", "")) \
			or FileAccess.get_sha256(VICTORY_REPLAY_CHILD_PATH).to_lower() \
			!= str(value.get("victory_replay_child_sha256", "")) \
			or FileAccess.get_sha256(VICTORY_REPLAY_PARENT_PATH).to_lower() \
			!= str(value.get("victory_replay_parent_sha256", "")):
		return {}
	return value.duplicate(true)


static func authorized_attempt_root() -> String:
	var common_dir := _git_common_dir()
	return "" if common_dir.is_empty() \
			else _normalize_absolute_path(common_dir.path_join(ATTEMPT_ROOT_RELATIVE_PATH))


static func consume_child_admission(
	repository_head: String,
	claim_path_value: String,
	claim_sha256: String,
	admission_path_value: String,
	consumed_path_value: String
) -> Dictionary:
	var attempt_root := authorized_attempt_root()
	var claim_path := _normalize_absolute_path(claim_path_value)
	var admission_path := _normalize_absolute_path(admission_path_value)
	var consumed_path := _normalize_absolute_path(consumed_path_value)
	var expected_claim := _normalize_absolute_path(attempt_root.path_join("preflight_attempt_claim.json"))
	var expected_admission := _normalize_absolute_path(attempt_root.path_join("preflight_child_admission.json"))
	var expected_consumed := _normalize_absolute_path(attempt_root.path_join("preflight_child_admission_consumed.json"))
	if attempt_root.is_empty() or claim_path != expected_claim \
			or admission_path != expected_admission or consumed_path != expected_consumed \
			or not _lower_hex(claim_sha256, 64) \
			or not FileAccess.file_exists(claim_path) \
			or not FileAccess.file_exists(admission_path) \
			or FileAccess.file_exists(consumed_path):
		return _rejected("remaining_owner_preflight_attempt_v4_admission_path_invalid")
	var claim_text := FileAccess.get_file_as_string(claim_path)
	if claim_text.is_empty() or claim_text.sha256_text().to_lower() != claim_sha256:
		return _rejected("remaining_owner_preflight_attempt_v4_claim_sha256_invalid")
	var claim_variant: Variant = JSON.parse_string(claim_text)
	var admission_variant: Variant = JSON.parse_string(FileAccess.get_file_as_string(admission_path))
	if not (claim_variant is Dictionary) or not (admission_variant is Dictionary):
		return _rejected("remaining_owner_preflight_attempt_v4_admission_invalid")
	var claim := claim_variant as Dictionary
	var admission := admission_variant as Dictionary
	if not _has_exact_fields(claim, CLAIM_FIELDS) \
			or int(claim.get("schema_version", 0)) != 1 \
			or str(claim.get("claim_id", "")) != "RemainingOwnerClosedDataPreflightAttemptClaimV4" \
			or str(claim.get("attempt_id", "")) != ATTEMPT_ID \
			or str(claim.get("frozen_code_head", "")) != repository_head \
			or int(claim.get("start_index", -1)) != START_INDEX \
			or int(claim.get("end_index", -1)) != END_INDEX \
			or int(claim.get("attempt_count_before", -1)) != 0 \
			or int(claim.get("authorized_new_attempt_count", -1)) != 1 \
			or int(claim.get("attempt_count_after", -1)) != 1 \
			or str(claim.get("started_at", "")).is_empty() \
			or not bool(claim.get("private_payload_redacted", false)):
		return _rejected("remaining_owner_preflight_attempt_v4_claim_invalid")
	if not _has_exact_fields(admission, ADMISSION_FIELDS) \
			or int(admission.get("schema_version", 0)) != 1 \
			or str(admission.get("admission_id", "")) != "RemainingOwnerClosedDataPreflightChildAdmissionV4" \
			or str(admission.get("claim_sha256", "")) != claim_sha256 \
			or str(admission.get("attempt_id", "")) != ATTEMPT_ID \
			or str(admission.get("frozen_code_head", "")) != repository_head:
		return _rejected("remaining_owner_preflight_attempt_v4_admission_invalid")
	if DirAccess.rename_absolute(admission_path, consumed_path) != OK:
		return _rejected("remaining_owner_preflight_attempt_v4_admission_already_consumed")
	return {
		"accepted": true,
		"reason_code": "remaining_owner_preflight_attempt_v4_admission_consumed",
		"claim_sha256": claim_sha256,
	}


static func _git_common_dir() -> String:
	var project_root := _normalize_absolute_path(ProjectSettings.globalize_path("res://"))
	if project_root.is_empty():
		return ""
	var git_marker := project_root.path_join(".git")
	if DirAccess.dir_exists_absolute(git_marker):
		return git_marker
	if not FileAccess.file_exists(git_marker):
		return ""
	var marker_text := FileAccess.get_file_as_string(git_marker).strip_edges()
	if not marker_text.begins_with("gitdir:"):
		return ""
	var git_dir := marker_text.trim_prefix("gitdir:").strip_edges()
	if not git_dir.is_absolute_path():
		git_dir = project_root.path_join(git_dir)
	git_dir = _normalize_absolute_path(git_dir)
	var common_file := git_dir.path_join("commondir")
	if not FileAccess.file_exists(common_file):
		return git_dir
	var common_dir := FileAccess.get_file_as_string(common_file).strip_edges()
	if not common_dir.is_absolute_path():
		common_dir = git_dir.path_join(common_dir)
	return _normalize_absolute_path(common_dir)


static func _has_exact_fields(value: Dictionary, fields: Array) -> bool:
	if value.size() != fields.size():
		return false
	for field_variant in fields:
		if not value.has(str(field_variant)):
			return false
	return true


static func _json_integer_equals(value: Variant, expected: int) -> bool:
	return (value is int and int(value) == expected) \
			or (value is float and is_finite(float(value)) and float(value) == float(expected))


static func _lower_hex(value: String, length: int) -> bool:
	if value.length() != length:
		return false
	for index in range(value.length()):
		if not "0123456789abcdef".contains(value.substr(index, 1)):
			return false
	return true


static func _normalize_absolute_path(value: String) -> String:
	if value.is_empty() or not value.is_absolute_path():
		return ""
	return value.replace("\\", "/").simplify_path().trim_suffix("/")


static func _rejected(reason_code: String) -> Dictionary:
	return {"accepted": false, "reason_code": reason_code}
