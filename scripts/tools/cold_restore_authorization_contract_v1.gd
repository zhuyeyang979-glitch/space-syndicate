extends RefCounted

const CONTRACT_PATH := "res://scripts/tools/cold_restore_authorization_contract_v1.json"
const DEFAULT_EVIDENCE_ROOT := "res://.godot/cold_restore_attestation_v1"
const TARGETED_AUTHORIZATION_NAME := "targeted_owner_capture_diagnostic_v4_importchain"
const ENTRY_NAMES := [
	"targeted_owner_capture_diagnostic_v3",
	TARGETED_AUTHORIZATION_NAME,
	"process_a_save_completion_rehearsal_v1",
	"official_attempt_2",
]


static func entry(entry_name: String) -> Dictionary:
	if entry_name not in ENTRY_NAMES or not FileAccess.file_exists(CONTRACT_PATH):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONTRACT_PATH))
	if not (parsed is Dictionary):
		return {}
	var contract := parsed as Dictionary
	if int(contract.get("schema_version", 0)) != 1 \
			or str(contract.get("contract_id", "")) != "ColdRestoreAuthorizationContractV1" \
			or not (contract.get(entry_name) is Dictionary):
		return {}
	return (contract.get(entry_name) as Dictionary).duplicate(true)


static func run_id(entry_name: String, repository_head: String) -> String:
	if repository_head.length() != 40 or not _is_lower_hex(repository_head):
		return ""
	var prefix := str(entry(entry_name).get("run_id_prefix", ""))
	return "" if prefix.is_empty() else "%s-%s" % [prefix, repository_head.left(12)]


static func is_targeted_run_id(value: String) -> bool:
	var prefix := str(entry(TARGETED_AUTHORIZATION_NAME).get("run_id_prefix", ""))
	if prefix.is_empty() or not value.begins_with("%s-" % prefix):
		return false
	var suffix := value.trim_prefix("%s-" % prefix)
	return suffix.length() == 12 and _is_lower_hex(suffix)


static func evidence_run_root(run_id_value: String, test_override: String = "") -> String:
	if not test_override.is_empty():
		var normalized_override := normalize_absolute_path(test_override)
		var authorized_test_root := normalize_absolute_path(
			OS.get_environment("SPACE_SYNDICATE_COLD_RESTORE_TEST_EVIDENCE_ROOT")
		)
		return normalized_override if not normalized_override.is_empty() \
				and normalized_override == authorized_test_root else ""
	if is_targeted_run_id(run_id_value):
		var expected_root := targeted_evidence_root()
		var environment_root := normalize_absolute_path(
			OS.get_environment("SPACE_SYNDICATE_COLD_RESTORE_EVIDENCE_ROOT")
		)
		return expected_root if not expected_root.is_empty() and environment_root == expected_root else ""
	return "%s/%s" % [DEFAULT_EVIDENCE_ROOT, run_id_value] if _safe_run_id(run_id_value) else ""


static func targeted_evidence_root() -> String:
	var common_dir := git_common_dir()
	var relative_path := str(entry(TARGETED_AUTHORIZATION_NAME).get(
		"evidence_root_relative_path", ""
	))
	if common_dir.is_empty() or relative_path.is_empty():
		return ""
	return normalize_absolute_path(common_dir.path_join(relative_path))


static func git_common_dir() -> String:
	var project_root := normalize_absolute_path(ProjectSettings.globalize_path("res://"))
	if project_root.is_empty():
		return ""
	var git_marker := project_root.path_join(".git")
	if DirAccess.dir_exists_absolute(git_marker):
		return normalize_absolute_path(git_marker)
	if not FileAccess.file_exists(git_marker):
		return ""
	var marker_text := FileAccess.get_file_as_string(git_marker).strip_edges()
	if not marker_text.begins_with("gitdir:"):
		return ""
	var git_dir := marker_text.trim_prefix("gitdir:").strip_edges()
	if not git_dir.is_absolute_path():
		git_dir = project_root.path_join(git_dir)
	git_dir = normalize_absolute_path(git_dir)
	if git_dir.is_empty():
		return ""
	var common_dir_path := git_dir.path_join("commondir")
	if not FileAccess.file_exists(common_dir_path):
		return git_dir
	var common_dir := FileAccess.get_file_as_string(common_dir_path).strip_edges()
	if not common_dir.is_absolute_path():
		common_dir = git_dir.path_join(common_dir)
	return normalize_absolute_path(common_dir)


static func normalize_absolute_path(value: String) -> String:
	if value.is_empty() or not value.is_absolute_path():
		return ""
	return value.replace("\\", "/").simplify_path().trim_suffix("/")


static func _safe_run_id(value: String) -> bool:
	if value.is_empty() or value.length() > 96:
		return false
	for index in range(value.length()):
		if not "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-".contains(
			value.substr(index, 1)
		):
			return false
	return true


static func _is_lower_hex(value: String) -> bool:
	if value.is_empty():
		return false
	for index in range(value.length()):
		if not "0123456789abcdef".contains(value.substr(index, 1)):
			return false
	return true
