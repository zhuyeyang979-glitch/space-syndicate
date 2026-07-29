extends RefCounted
class_name SaveSlotPolicyV06

## Local path policy for the single v0.6 production slot and isolated QA runs.
## Paths never cross the player-facing application-flow boundary.

const SCHEMA_VERSION := 1
const MECHANIC_ID := "v06_save_resume_application_flow"
const PRODUCTION_SLOT_ID := &"current_run"
const PRODUCTION_PATH := "user://saves/v06/current_run.save"
const QA_ROOT := "user://test_runs/alpha04c/"
const SAVE_SUFFIX := ".save"


static func production_slot_descriptor() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"mechanic_id": MECHANIC_ID,
		"slot_id": String(PRODUCTION_SLOT_ID),
		"slot_kind": "single_local_run",
		"ruleset_id": "v0.6",
	}


static func path_for_production_slot(slot_id: StringName) -> String:
	return PRODUCTION_PATH if slot_id == PRODUCTION_SLOT_ID else ""


static func qa_path(run_id: String, process_role: String) -> String:
	var normalized_run_id := run_id.strip_edges()
	var normalized_role := process_role.strip_edges()
	if not _safe_segment(normalized_run_id) or not _safe_segment(normalized_role):
		return ""
	return "%s%s/%s%s" % [QA_ROOT, normalized_run_id, normalized_role, SAVE_SUFFIX]


static func is_allowed_path(path: String, allow_qa: bool = false) -> bool:
	if path == PRODUCTION_PATH:
		return true
	return allow_qa and is_qa_path(path)


static func is_qa_path(path: String) -> bool:
	if not path.begins_with(QA_ROOT) or not path.ends_with(SAVE_SUFFIX):
		return false
	if path.contains("\\") or path.contains(".."):
		return false
	var relative := path.trim_prefix(QA_ROOT)
	if relative.is_empty() or relative.contains("//"):
		return false
	var segments := relative.split("/", false)
	if segments.size() != 2:
		return false
	var file_name := str(segments[1])
	var role := file_name.trim_suffix(SAVE_SUFFIX)
	return _safe_segment(str(segments[0])) and _safe_segment(role)


static func path_classification(path: String) -> StringName:
	if path == PRODUCTION_PATH:
		return &"production"
	if is_qa_path(path):
		return &"qa"
	return &"rejected"


static func _safe_segment(value: String) -> bool:
	if value.is_empty() or value.length() > 96:
		return false
	for index in range(value.length()):
		var code := value.unicode_at(index)
		var allowed := (
			(code >= 48 and code <= 57)
			or (code >= 65 and code <= 90)
			or (code >= 97 and code <= 122)
			or code in [45, 95]
		)
		if not allowed:
			return false
	return true
