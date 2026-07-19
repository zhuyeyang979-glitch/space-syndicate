extends RefCounted
class_name SessionStartRequest

const SCHEMA_VERSION := 1

var request_id := ""
var expected_draft_revision := -1
var expected_active_session_revision := -1
var setup_draft: Dictionary = {}
var source_context := "setup_ui"


static func create(id: String, draft: Dictionary, active_revision: int, context: String = "setup_ui") -> SessionStartRequest:
	var request := SessionStartRequest.new()
	request.request_id = id.strip_edges()
	request.setup_draft = draft.duplicate(true)
	request.expected_draft_revision = int(draft.get("draft_revision", -1))
	request.expected_active_session_revision = active_revision
	request.source_context = context.strip_edges()
	return request


func is_valid() -> bool:
	return not request_id.is_empty() and expected_draft_revision >= 0 and expected_active_session_revision >= 0 \
		and int(setup_draft.get("schema_version", 0)) == 1 and source_context in ["setup_ui", "quality_driver", "focused_test"] \
		and _is_data_only(setup_draft)


func to_dictionary() -> Dictionary:
	return {"schema_version": SCHEMA_VERSION, "request_id": request_id, "expected_draft_revision": expected_draft_revision, "expected_active_session_revision": expected_active_session_revision, "setup_draft": setup_draft.duplicate(true), "source_context": source_context}


func fingerprint() -> String:
	return JSON.stringify(to_dictionary())


func _is_data_only(value: Variant) -> bool:
	if value is Object or value is Callable:
		return false
	if value is Dictionary:
		for key in value:
			if not _is_data_only(key) or not _is_data_only(value[key]):
				return false
	elif value is Array:
		for item in value:
			if not _is_data_only(item):
				return false
	return true
