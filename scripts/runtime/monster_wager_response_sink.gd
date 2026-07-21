@tool
extends Node
class_name MonsterWagerResponseSink

const RESPONSE_RECEIPT_SCRIPT := preload("res://scripts/runtime/monster_wager_response_receipt.gd")

signal receipt_ready(receipt: RESPONSE_RECEIPT_SCRIPT)
signal presentation_refresh_requested(kind: StringName, reason: StringName)

@export var monster_runtime_controller_path: NodePath
@export var identity_boundary_path: NodePath

var _journal: Dictionary = {}
var _journal_session_key := ""
var _submission_count := 0
var _accepted_count := 0
var _rejected_count := 0
var _mutation_count := 0
var _replay_count := 0
var _collision_count := 0


func consume_authorized_response(request: ForcedDecisionResponseRequest) -> RESPONSE_RECEIPT_SCRIPT:
	if request == null:
		return _complete(_receipt(null, false, "request_missing"))
	if request.decision_kind != &"monster_wager":
		return null
	_submission_count += 1
	var validation := request.validation_report()
	if not bool(validation.get("valid", false)):
		return _complete(_receipt(request, false, str(validation.get("reason_code", "request_invalid"))))
	if _wager_owner() == null or _identity_boundary() == null:
		return _complete(_receipt(request, false, "monster_wager_response_dependency_missing"))
	# The shared response port is the sole identity-journal authority. Re-running
	# authorize_request here would turn the already-authorized envelope into a
	# false replay; the sink only rechecks the bound public actor fact.
	if request.viewer_index != request.authorized_player_index:
		return _complete(_receipt(request, false, "monster_wager_actor_mismatch"))
	if not _identity_boundary().public_player_is_active(request.authorized_player_index):
		return _complete(_receipt(request, false, "monster_wager_actor_unavailable"))
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
	var binding := _live_action_binding(request)
	if not bool(binding.get("valid", false)):
		return _complete(_receipt(request, false, str(binding.get("reason_code", "monster_wager_binding_stale"))), true)
	_journal[request.request_id] = fingerprint
	var result := _wager_owner().submit_monster_wager_response(
		int(binding.get("wager_id", -1)),
		request.authorized_player_index,
		StringName(str(binding.get("side", ""))),
		int(binding.get("stake_percent", 0))
	)
	var accepted := bool(result.get("accepted", false)) and bool(result.get("applied", false))
	var receipt := _receipt(request, accepted, str(result.get("reason_code", "monster_wager_response_rejected")))
	receipt.wager_id = int(result.get("wager_id", binding.get("wager_id", -1)))
	receipt.player_index = request.authorized_player_index
	receipt.side = StringName(str(result.get("side", binding.get("side", ""))))
	receipt.stake_percent = int(result.get("stake_percent", binding.get("stake_percent", 0)))
	receipt.stake = maxi(0, int(result.get("stake", 0)))
	receipt.applied = accepted
	receipt.decision_closed = bool(result.get("decision_closed", false))
	if accepted:
		_mutation_count += 1
		receipt.player_message = "下注已确认：%d%%（¥%d）。" % [receipt.stake_percent, receipt.stake]
	else:
		receipt.player_message = _rejection_message(receipt.reason_code)
	return _complete(receipt, true)


func debug_snapshot() -> Dictionary:
	return {
		"sink_id": "monster_wager_response_sink_v1",
		"submission_count": _submission_count,
		"accepted_count": _accepted_count,
		"rejected_count": _rejected_count,
		"mutation_count": _mutation_count,
		"replay_count": _replay_count,
		"collision_count": _collision_count,
		"journal_size": _journal.size(),
		"journal_session_key": _journal_session_key,
		"journal_eviction_enabled": false,
		"typed_response_required": true,
		"live_action_binding_required": true,
		"exact_once": true,
		"owns_wager_state": false,
		"owns_player_cash": false,
		"owns_public_pool": false,
		"owns_save_state": false,
		"references_main": false,
	}


func _live_action_binding(request: ForcedDecisionResponseRequest) -> Dictionary:
	var wager_id_text := request.decision_id.trim_prefix("monster_wager_")
	if not request.decision_id.begins_with("monster_wager_") or not wager_id_text.is_valid_int():
		return {"valid": false, "reason_code": "monster_wager_decision_id_invalid"}
	var wager_id := int(wager_id_text)
	var presentation := _wager_owner().monster_wager_presentation_for_viewer(request.viewer_index)
	if presentation.is_empty() or not bool(presentation.get("active", false)):
		return {"valid": false, "reason_code": "monster_wager_not_active"}
	if int(presentation.get("wager_id", -1)) != wager_id:
		return {"valid": false, "reason_code": "monster_wager_binding_stale"}
	var viewer_decision: Dictionary = presentation.get("viewer_decision", {}) \
			if presentation.get("viewer_decision", {}) is Dictionary else {}
	if bool(viewer_decision.get("decided", false)):
		return {"valid": false, "reason_code": "monster_wager_already_decided"}
	for action_variant in presentation.get("actions", []):
		if not (action_variant is Dictionary):
			continue
		var action := action_variant as Dictionary
		if str(action.get("id", "")) != request.option_id:
			continue
		if bool(action.get("disabled", false)):
			return {"valid": false, "reason_code": "monster_wager_already_decided"}
		return {
			"valid": true,
			"reason_code": "",
			"wager_id": wager_id,
			"side": str(action.get("side", "")),
			"stake_percent": int(action.get("stake_percent", 0)),
		}
	return {"valid": false, "reason_code": "monster_wager_option_unavailable"}


func _receipt(request: ForcedDecisionResponseRequest, accepted: bool, reason_code: String) -> RESPONSE_RECEIPT_SCRIPT:
	var receipt := RESPONSE_RECEIPT_SCRIPT.new()
	if request != null:
		receipt.request_id = request.request_id
		receipt.decision_id = request.decision_id
		receipt.decision_revision = request.decision_revision
		receipt.viewer_index = request.viewer_index
		receipt.player_index = request.authorized_player_index
	receipt.accepted = accepted
	receipt.reason_code = reason_code
	if receipt.player_message.is_empty():
		receipt.player_message = "下注已处理。" if accepted else _rejection_message(reason_code)
	return receipt


func _complete(receipt: RESPONSE_RECEIPT_SCRIPT, refresh: bool = false) -> RESPONSE_RECEIPT_SCRIPT:
	if receipt.accepted:
		_accepted_count += 1
	else:
		_rejected_count += 1
	receipt_ready.emit(receipt)
	if refresh:
		presentation_refresh_requested.emit(&"full", &"monster_wager_response_resolved")
	return receipt


func _rejection_message(reason_code: String) -> String:
	match reason_code:
		"monster_wager_already_decided":
			return "你已经完成本场下注。"
		"monster_wager_option_unavailable":
			return "该下注选项已失效，请按当前窗口重新选择。"
		"monster_wager_not_active", "monster_wager_binding_stale":
			return "本场赌局已经结束或更换。"
	return "下注未生效，请按当前窗口重试。"


func _sync_journal_session(session_id: String, session_revision: int) -> void:
	var session_key := "%s:%d" % [session_id, session_revision]
	if session_key == _journal_session_key:
		return
	_journal.clear()
	_journal_session_key = session_key


func _wager_owner() -> MonsterRuntimeController:
	return get_node_or_null(monster_runtime_controller_path) as MonsterRuntimeController


func _identity_boundary() -> PlayerIdentityAuthorizationBoundary:
	return get_node_or_null(identity_boundary_path) as PlayerIdentityAuthorizationBoundary
