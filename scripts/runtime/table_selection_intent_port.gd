@tool
extends Node
class_name TableSelectionIntentPort

signal receipt_ready(receipt: TableSelectionReceipt)
signal presentation_refresh_requested(kind: StringName, reason: StringName)

@export var identity_boundary_path: NodePath
@export var selection_state_path: NodePath
@export var forced_decision_response_port_path: NodePath

var _journal: Dictionary = {}
var _journal_session_key := ""
var _submission_count := 0
var _accepted_count := 0
var _rejected_count := 0
var _changed_count := 0
var _refresh_emission_count := 0
var _replay_count := 0
var _collision_count := 0


func submit_intent(intent: TableSelectionIntent) -> TableSelectionReceipt:
	_submission_count += 1
	if intent == null:
		return _complete(_receipt(null, false, "intent_missing"))
	var validation := intent.validation_report()
	if not bool(validation.get("valid", false)):
		return _complete(_receipt(intent, false, str(validation.get("reason_code", "intent_invalid"))))
	if _identity_boundary() == null or _selection_state() == null:
		return _complete(_receipt(intent, false, "selection_dependency_missing"))
	var request := _request_from_intent(intent)
	var request_validation := request.validation_report()
	if not bool(request_validation.get("valid", false)):
		return _complete(_receipt(intent, false, str(request_validation.get("reason_code", "request_invalid"))))
	_sync_journal_session(request.session_id, request.session_revision)
	var fingerprint := request.fingerprint()
	if _journal.has(request.request_id):
		if str(_journal.get(request.request_id, "")) != fingerprint:
			_collision_count += 1
			var collision := _receipt(intent, false, "request_id_collision")
			collision.request_id_collision = true
			return _complete(collision)
		_replay_count += 1
		var replay := _receipt(intent, false, "request_replay")
		replay.idempotent_replay = true
		return _complete(replay)
	if _forced_response_port() != null and _forced_response_port().blocks_ordinary_gameplay(intent.viewer_index):
		return _complete(_receipt(intent, false, "forced_decision_blocks_selection"))
	var before := _selection_state().snapshot()
	if intent.expected_selection_revision != int(before.get("revision", -1)):
		var stale := _receipt(intent, false, "selection_revision_stale")
		stale.selection_revision_before = int(before.get("revision", -1))
		stale.selection_revision_after = stale.selection_revision_before
		return _complete(stale)
	var identity_receipt := _identity_boundary().authorize_request(request)
	if not identity_receipt.authorized:
		return _complete(_receipt(intent, false, "identity_%s" % identity_receipt.reason_code))
	_journal[request.request_id] = fingerprint
	_selection_state().selected_map_layer_focus = str(request.map_layer_id)
	var after := _selection_state().snapshot()
	var receipt := _receipt(intent, true, "selection_applied")
	receipt.selection_revision_before = int(before.get("revision", -1))
	receipt.selection_revision_after = int(after.get("revision", -1))
	receipt.changed = receipt.selection_revision_after != receipt.selection_revision_before
	if receipt.changed:
		_changed_count += 1
		receipt.presentation_refresh_requested = true
		_refresh_emission_count += 1
		presentation_refresh_requested.emit(&"map", &"table_selection_changed")
	else:
		receipt.reason_code = "selection_unchanged"
	return _complete(receipt)


func debug_snapshot() -> Dictionary:
	return {
		"port_id": "table_selection_intent_port_v1",
		"submission_count": _submission_count,
		"accepted_count": _accepted_count,
		"rejected_count": _rejected_count,
		"changed_count": _changed_count,
		"refresh_emission_count": _refresh_emission_count,
		"replay_count": _replay_count,
		"collision_count": _collision_count,
		"journal_size": _journal.size(),
		"journal_session_key": _journal_session_key,
		"journal_eviction_enabled": false,
		"supported_selection_kinds": [TableSelectionIntent.KIND_MAP_LAYER],
		"typed_identity_envelope_required": true,
		"exact_once": true,
		"owns_selection_state": false,
		"gameplay_mutation_count": 0,
		"references_main": false,
	}


func _request_from_intent(intent: TableSelectionIntent) -> TableSelectionRequest:
	var request := TableSelectionRequest.new()
	var identity := _identity_boundary().build_request(intent.request_id, intent.source_surface, intent.request_revision)
	request.schema_version = identity.schema_version
	request.request_id = identity.request_id
	request.viewer_index = intent.viewer_index
	request.authorized_player_index = intent.viewer_index
	request.authorization_revision = intent.authorization_revision
	request.session_id = identity.session_id
	request.session_revision = identity.session_revision
	request.source_surface = intent.source_surface
	request.request_revision = intent.request_revision
	request.selection_kind = intent.selection_kind
	request.expected_selection_revision = intent.expected_selection_revision
	request.map_layer_id = intent.map_layer_id
	return request


func _sync_journal_session(session_id: String, session_revision: int) -> void:
	var session_key := "%s:%d" % [session_id, session_revision]
	if _journal_session_key == session_key:
		return
	_journal.clear()
	_journal_session_key = session_key


func _receipt(intent: TableSelectionIntent, accepted: bool, reason_code: String) -> TableSelectionReceipt:
	var receipt := TableSelectionReceipt.new()
	if intent != null:
		receipt.request_id = intent.request_id
		receipt.selection_kind = intent.selection_kind
		receipt.viewer_index = intent.viewer_index
		receipt.map_layer_id = intent.map_layer_id
	receipt.accepted = accepted
	receipt.reason_code = reason_code
	return receipt


func _complete(receipt: TableSelectionReceipt) -> TableSelectionReceipt:
	if _selection_state() != null:
		receipt.effective_map_layer_id = StringName(_selection_state().selected_map_layer_focus)
	if receipt.accepted:
		_accepted_count += 1
	else:
		_rejected_count += 1
	receipt_ready.emit(receipt)
	return receipt


func _identity_boundary() -> PlayerIdentityAuthorizationBoundary:
	return get_node_or_null(identity_boundary_path) as PlayerIdentityAuthorizationBoundary


func _selection_state() -> TableSelectionState:
	return get_node_or_null(selection_state_path) as TableSelectionState


func _forced_response_port() -> ForcedDecisionResponsePort:
	return get_node_or_null(forced_decision_response_port_path) as ForcedDecisionResponsePort
