@tool
extends Node
class_name CompendiumNavigationPort

const CODEX_OPEN_REQUEST_SCRIPT := preload("res://scripts/runtime/codex_open_request.gd")

signal navigation_requested(request: CODEX_OPEN_REQUEST_SCRIPT)

var _next_revision := 1
var _accepted_count := 0
var _rejected_count := 0
var _duplicate_count := 0
var _seen_revisions: Dictionary = {}


func request_open(
	domain: String,
	view: String,
	stable_item_id: String,
	optional_index: int = -1,
	filter_id: String = "",
	page_delta: int = 0,
	return_target: String = "compendium",
	public_source_context: Dictionary = {}
) -> bool:
	var request := CODEX_OPEN_REQUEST_SCRIPT.new()
	request.domain = domain.strip_edges()
	request.view = view.strip_edges()
	request.stable_item_id = stable_item_id.strip_edges()
	request.optional_index = optional_index
	request.filter_id = filter_id.strip_edges()
	request.page_delta = page_delta
	request.return_target = return_target.strip_edges()
	request.request_revision = _next_revision
	request.public_source_context = public_source_context.duplicate(true)
	_next_revision += 1
	return submit_request(request)


func submit_request(request: CODEX_OPEN_REQUEST_SCRIPT) -> bool:
	if request == null:
		_rejected_count += 1
		return false
	var report := request.validation_report()
	if not bool(report.get("valid", false)):
		_rejected_count += 1
		return false
	var revision_key := str(request.request_revision)
	if _seen_revisions.has(revision_key):
		_duplicate_count += 1
		_rejected_count += 1
		return false
	_seen_revisions[revision_key] = request.canonical_key()
	_accepted_count += 1
	navigation_requested.emit(request)
	return true


func debug_snapshot() -> Dictionary:
	return {
		"port_id": "compendium_navigation_port_v06",
		"accepted_count": _accepted_count,
		"rejected_count": _rejected_count,
		"duplicate_count": _duplicate_count,
		"next_revision": _next_revision,
		"typed_request_boundary": true,
		"request_contains_main": false,
		"request_contains_callable": false,
		"request_contains_mutable_player": false,
		"owns_navigation_state": false,
		"owns_gameplay_state": false,
	}
