@tool
extends Node
class_name ForcedDecisionResponsePort

signal response_authorized(request: ForcedDecisionResponseRequest)
signal receipt_ready(receipt: ForcedDecisionResponseReceipt)

@export var identity_boundary_path: NodePath
@export var scheduler_path: NodePath

var _journal: Dictionary = {}
var _journal_session_key := ""
var _submission_count := 0
var _accepted_count := 0
var _rejected_count := 0
var _emission_count := 0
var _replay_count := 0
var _collision_count := 0


func build_request(request_id: String, option_id: String, request_revision: int) -> ForcedDecisionResponseRequest:
	var request := ForcedDecisionResponseRequest.new()
	var identity := _identity_boundary()
	if identity != null:
		var identity_request := identity.build_request(request_id, &"forced_decision", request_revision)
		request.schema_version = identity_request.schema_version
		request.request_id = identity_request.request_id
		request.viewer_index = identity_request.viewer_index
		request.authorized_player_index = identity_request.authorized_player_index
		request.authorization_revision = identity_request.authorization_revision
		request.session_id = identity_request.session_id
		request.session_revision = identity_request.session_revision
		request.source_surface = identity_request.source_surface
		request.request_revision = identity_request.request_revision
	else:
		request.request_id = request_id
		request.source_surface = &"forced_decision"
		request.request_revision = request_revision
	request.option_id = option_id
	var scheduler := _scheduler()
	if scheduler != null:
		var active := scheduler.active_decision(request.viewer_index)
		request.decision_id = str(active.get("id", ""))
		request.decision_kind = StringName(str(active.get("kind", "")))
		request.decision_revision = int(active.get("decision_revision", 0))
	return request


func submit_response(request: ForcedDecisionResponseRequest) -> ForcedDecisionResponseReceipt:
	_submission_count += 1
	if request == null:
		return _complete(_receipt(null, false, "request_missing"))
	var validation := request.validation_report()
	if not bool(validation.get("valid", false)):
		return _complete(_receipt(request, false, str(validation.get("reason_code", "request_invalid"))))
	if _identity_boundary() == null or _scheduler() == null:
		return _complete(_receipt(request, false, "response_dependency_missing"))
	var active := _scheduler().active_decision(request.viewer_index)
	if active.is_empty():
		return _complete(_receipt(request, false, "decision_already_closed"))
	if str(active.get("kind", "")) == "private_forced_decision" or not bool(active.get("visible_to_viewer", false)):
		return _complete(_receipt(request, false, "decision_viewer_unauthorized"))
	if request.decision_id != str(active.get("id", "")):
		return _complete(_receipt(request, false, "decision_not_active"))
	if str(request.decision_kind) != str(active.get("kind", "")):
		return _complete(_receipt(request, false, "decision_kind_mismatch"))
	if request.decision_revision != int(active.get("decision_revision", 0)):
		return _complete(_receipt(request, false, "decision_revision_stale"))
	var option_validation := ForcedDecisionResponseOptionPolicy.validation_report(request.decision_kind, request.decision_id, request.option_id)
	if not bool(option_validation.get("valid", false)):
		return _complete(_receipt(request, false, str(option_validation.get("reason_code", "option_not_available"))))
	_sync_journal_session(request.session_id, request.session_revision)
	var fingerprint := request.fingerprint()
	if _journal.has(request.request_id):
		if str(_journal.get(request.request_id, "")) != fingerprint:
			_collision_count += 1
			var collision := _receipt(request, false, "request_id_collision")
			collision.request_id_collision = true
			return _complete(collision)
		_replay_count += 1
		var replay := _receipt(request, false, "request_replay")
		replay.idempotent_replay = true
		return _complete(replay)
	var identity_receipt := _identity_boundary().authorize_request(request)
	if not identity_receipt.authorized:
		return _complete(_receipt(request, false, "identity_%s" % identity_receipt.reason_code))
	_journal[request.request_id] = fingerprint
	var receipt := _receipt(request, true, "response_authorized")
	receipt.emitted = true
	_emission_count += 1
	response_authorized.emit(request)
	return _complete(receipt)


func blocks_ordinary_gameplay(viewer_index: int) -> bool:
	var scheduler := _scheduler()
	return scheduler != null and scheduler.blocks_player_actions(viewer_index)


func debug_snapshot() -> Dictionary:
	return {
		"port_id": "forced_decision_response_port_v1",
		"submission_count": _submission_count,
		"accepted_count": _accepted_count,
		"rejected_count": _rejected_count,
		"emission_count": _emission_count,
		"replay_count": _replay_count,
		"collision_count": _collision_count,
		"journal_size": _journal.size(),
		"journal_session_key": _journal_session_key,
		"journal_eviction_enabled": false,
		"decision_kind_count": ForcedDecisionResponseRequest.DECISION_KINDS.size(),
		"typed_identity_envelope_required": true,
		"active_decision_required": true,
		"exact_once": true,
		"owns_decision_state": false,
		"owns_gameplay_state": false,
		"gameplay_mutation_count": 0,
		"references_main": false,
	}


func _sync_journal_session(session_id: String, session_revision: int) -> void:
	var session_key := "%s:%d" % [session_id, session_revision]
	if _journal_session_key == session_key:
		return
	_journal.clear()
	_journal_session_key = session_key


func _receipt(request: ForcedDecisionResponseRequest, accepted: bool, reason_code: String) -> ForcedDecisionResponseReceipt:
	var receipt := ForcedDecisionResponseReceipt.new()
	if request != null:
		receipt.request_id = request.request_id
		receipt.decision_id = request.decision_id
		receipt.decision_kind = request.decision_kind
		receipt.decision_revision = request.decision_revision
		receipt.option_id = request.option_id
		receipt.viewer_index = request.viewer_index
	receipt.accepted = accepted
	receipt.reason_code = reason_code
	return receipt


func _complete(receipt: ForcedDecisionResponseReceipt) -> ForcedDecisionResponseReceipt:
	if receipt.accepted:
		_accepted_count += 1
	else:
		_rejected_count += 1
	receipt_ready.emit(receipt)
	return receipt


func _identity_boundary() -> PlayerIdentityAuthorizationBoundary:
	return get_node_or_null(identity_boundary_path) as PlayerIdentityAuthorizationBoundary


func _scheduler() -> ForcedDecisionRuntimeScheduler:
	return get_node_or_null(scheduler_path) as ForcedDecisionRuntimeScheduler
