@tool
extends Node
class_name CardTargetChoiceResponseSink

const RESPONSE_RECEIPT_SCRIPT := preload("res://scripts/runtime/card_target_choice_response_receipt.gd")

signal receipt_ready(receipt: RESPONSE_RECEIPT_SCRIPT)
signal presentation_refresh_requested(kind: StringName, reason: StringName)

@export var target_choice_controller_path: NodePath
@export var card_play_submission_controller_path: NodePath
@export var monster_runtime_controller_path: NodePath
@export var identity_boundary_path: NodePath

const JOURNAL_LIMIT := 128

var _journal: Dictionary = {}
var _journal_order: Array[String] = []
var _journal_session_key := ""
var _submission_count := 0
var _accepted_count := 0
var _rejected_count := 0
var _queue_commit_count := 0
var _cancel_commit_count := 0
var _clear_commit_count := 0
var _replay_count := 0
var _collision_count := 0


func consume_authorized_response(request: ForcedDecisionResponseRequest) -> RESPONSE_RECEIPT_SCRIPT:
	if request == null:
		return _complete(_receipt(null, false, "request_missing"))
	if str(request.decision_kind) not in [CardTargetChoiceRuntimeController.KIND_MONSTER, CardTargetChoiceRuntimeController.KIND_PLAYER]:
		return null
	_submission_count += 1
	var validation := request.validation_report()
	if not bool(validation.get("valid", false)):
		return _complete(_receipt(request, false, str(validation.get("reason_code", "request_invalid"))))
	if _choice_owner() == null or _submission_owner() == null or _identity_boundary() == null:
		return _complete(_receipt(request, false, "target_choice_dependency_missing"))
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
	_remember_request(request.request_id, fingerprint)
	var kind := str(request.decision_kind)
	var choice := _choice_owner().choice_snapshot(kind)
	if choice.is_empty():
		return _complete(_receipt(request, false, "target_choice_not_active"), true)
	if str(choice.get("choice_id", "")) != request.decision_id:
		return _complete(_receipt(request, false, "target_choice_binding_stale"), true)
	var actor_index := int(choice.get("player_index", -1))
	if actor_index < 0 or actor_index != request.viewer_index or actor_index != request.authorized_player_index:
		return _complete(_receipt(request, false, "target_choice_actor_mismatch"), true)
	if request.option_id == _cancel_option(kind):
		var cancel_reservation := _choice_owner().reserve_choice(kind, str(choice.get("choice_id", "")), request.request_id)
		if not bool(cancel_reservation.get("reserved", false)):
			return _complete(_receipt(request, false, str(cancel_reservation.get("reason", "target_choice_reservation_failed"))), true)
		return _cancel(request, choice)
	var target_binding := _target_binding(request.option_id, kind, choice)
	if not bool(target_binding.get("valid", false)):
		return _complete(_receipt(request, false, str(target_binding.get("reason", "target_option_invalid"))))
	var reservation := _choice_owner().reserve_choice(kind, str(choice.get("choice_id", "")), request.request_id)
	if not bool(reservation.get("reserved", false)):
		return _complete(_receipt(request, false, str(reservation.get("reason", "target_choice_reservation_failed"))), true)
	return _submit_target(request, choice, target_binding)


func debug_snapshot() -> Dictionary:
	return {
		"sink_id": "card_target_choice_response_sink_v1",
		"submission_count": _submission_count,
		"accepted_count": _accepted_count,
		"rejected_count": _rejected_count,
		"queue_commit_count": _queue_commit_count,
		"cancel_commit_count": _cancel_commit_count,
		"clear_commit_count": _clear_commit_count,
		"replay_count": _replay_count,
		"collision_count": _collision_count,
		"journal_size": _journal.size(),
		"journal_limit": JOURNAL_LIMIT,
		"journal_session_key": _journal_session_key,
		"typed_response_required": true,
		"choice_reservation_required": true,
		"stable_monster_uid_required": true,
		"owns_target_choice": false,
		"owns_card_queue": false,
		"owns_monster_roster": false,
		"owns_player_state": false,
		"references_main": false,
	}


func _cancel(request: ForcedDecisionResponseRequest, choice: Dictionary) -> RESPONSE_RECEIPT_SCRIPT:
	var cleared := _choice_owner().consume_reserved_choice(str(request.decision_kind), str(choice.get("choice_id", "")), request.request_id)
	if not bool(cleared.get("cleared", false)) or str(cleared.get("choice_id", "")) != str(choice.get("choice_id", "")):
		return _complete(_receipt(request, false, "target_choice_clear_failed"))
	_clear_commit_count += 1
	_cancel_commit_count += 1
	var receipt := _receipt(request, true, "target_choice_cancelled")
	receipt.applied = true
	receipt.cancelled = true
	receipt.choice_cleared = true
	receipt.player_message = "已取消目标选择，卡牌未消耗。"
	return _complete(receipt, true)


func _submit_target(request: ForcedDecisionResponseRequest, choice: Dictionary, target_binding: Dictionary) -> RESPONSE_RECEIPT_SCRIPT:
	var kind := str(request.decision_kind)
	var target_index := int(target_binding.get("target_index", -1))
	var target_monster_uid := int(target_binding.get("target_monster_uid", -1))
	var submit_request := {
		"player_index": int(choice.get("player_index", -1)),
		"slot_index": int(choice.get("slot_index", -1)),
		"target_slot": target_index if kind == CardTargetChoiceRuntimeController.KIND_MONSTER else -1,
		"target_monster_uid": target_monster_uid if kind == CardTargetChoiceRuntimeController.KIND_MONSTER else -1,
		"target_player": target_index if kind == CardTargetChoiceRuntimeController.KIND_PLAYER else -1,
		"submission_source": "human_target_choice",
	}
	var submission := _submission_owner().submit_card_play(submit_request)
	if not bool(submission.get("accepted", false)):
		var released := _choice_owner().release_choice_reservation(kind, request.request_id)
		if not bool(released.get("released", false)):
			push_error("CardTargetChoiceResponseSink could not release a rejected submission reservation.")
		var rejected := _receipt(request, false, str(submission.get("reason", "target_card_submission_rejected")))
		rejected.target_index = target_index
		rejected.player_message = str(submission.get("player_message", "目标当前不可用，请重新选择。"))
		return _complete(rejected)
	var cleared := _choice_owner().consume_reserved_choice(kind, str(choice.get("choice_id", "")), request.request_id)
	if not bool(cleared.get("cleared", false)) or str(cleared.get("choice_id", "")) != str(choice.get("choice_id", "")):
		push_error("CardTargetChoiceResponseSink committed a card but could not clear the matching choice.")
		var partial := _receipt(request, true, "target_card_queued_choice_clear_failed")
		partial.applied = true
		partial.queued = true
		partial.target_index = target_index
		partial.player_message = "卡牌已提交，但目标窗口状态异常。"
		_queue_commit_count += 1
		return _complete(partial, true)
	_queue_commit_count += 1
	_clear_commit_count += 1
	var receipt := _receipt(request, true, "target_card_queued")
	receipt.applied = true
	receipt.queued = true
	receipt.choice_cleared = true
	receipt.target_index = target_index
	receipt.player_message = str(submission.get("player_message", "卡牌已进入共享卡牌窗。"))
	return _complete(receipt, true)


func _receipt(request: ForcedDecisionResponseRequest, accepted: bool, reason_code: String) -> RESPONSE_RECEIPT_SCRIPT:
	var receipt := RESPONSE_RECEIPT_SCRIPT.new()
	if request != null:
		receipt.request_id = request.request_id
		receipt.decision_id = request.decision_id
		receipt.decision_kind = request.decision_kind
		receipt.option_id = request.option_id
		receipt.viewer_index = request.viewer_index
	receipt.accepted = accepted
	receipt.reason_code = reason_code
	if receipt.player_message.is_empty():
		receipt.player_message = "目标选择已处理。" if accepted else "目标当前不可用，请重新选择。"
	return receipt


func _complete(receipt: RESPONSE_RECEIPT_SCRIPT, refresh: bool = false) -> RESPONSE_RECEIPT_SCRIPT:
	if receipt.accepted:
		_accepted_count += 1
	else:
		_rejected_count += 1
	receipt_ready.emit(receipt)
	if refresh:
		presentation_refresh_requested.emit(&"full", &"card_target_choice_resolved")
	return receipt


func _sync_journal_session(session_id: String, session_revision: int) -> void:
	var session_key := "%s:%d" % [session_id, session_revision]
	if session_key == _journal_session_key:
		return
	_journal.clear()
	_journal_order.clear()
	_journal_session_key = session_key


func _remember_request(request_id: String, fingerprint: String) -> void:
	_journal[request_id] = fingerprint
	_journal_order.append(request_id)
	while _journal_order.size() > JOURNAL_LIMIT:
		_journal.erase(_journal_order.pop_front())


func _cancel_option(kind: String) -> String:
	return "target_monster_cancel" if kind == CardTargetChoiceRuntimeController.KIND_MONSTER else "target_player_cancel"


func _target_binding(option_id: String, kind: String, choice: Dictionary) -> Dictionary:
	if kind == CardTargetChoiceRuntimeController.KIND_MONSTER:
		var uid_text := option_id.trim_prefix("target_monster_uid_")
		if not option_id.begins_with("target_monster_uid_") or not uid_text.is_valid_int() or int(uid_text) <= 0:
			return {"valid": false, "reason": "target_option_invalid"}
		var target_uid := int(uid_text)
		var roster := _monster_owner().roster_snapshot(false) if _monster_owner() != null else []
		for index in range(roster.size()):
			if not (roster[index] is Dictionary) or int((roster[index] as Dictionary).get("uid", -1)) != target_uid:
				continue
			if bool((roster[index] as Dictionary).get("down", false)):
				return {"valid": false, "reason": "target_monster_down"}
			return {"valid": true, "target_index": index, "target_monster_uid": target_uid}
		return {"valid": false, "reason": "target_monster_invalid"}
	var index_text := option_id.trim_prefix("target_player_")
	if not option_id.begins_with("target_player_") or not index_text.is_valid_int() or int(index_text) < 0:
		return {"valid": false, "reason": "target_option_invalid"}
	var target_player := int(index_text)
	if target_player == int(choice.get("player_index", -1)):
		return {"valid": false, "reason": "target_player_self"}
	if not _identity_boundary().public_player_is_active(target_player):
		return {"valid": false, "reason": "target_player_unavailable"}
	return {"valid": true, "target_index": target_player, "target_monster_uid": -1}


func _choice_owner() -> CardTargetChoiceRuntimeController:
	return get_node_or_null(target_choice_controller_path) as CardTargetChoiceRuntimeController


func _submission_owner() -> CardPlaySubmissionRuntimeController:
	return get_node_or_null(card_play_submission_controller_path) as CardPlaySubmissionRuntimeController


func _monster_owner() -> MonsterRuntimeController:
	return get_node_or_null(monster_runtime_controller_path) as MonsterRuntimeController


func _identity_boundary() -> PlayerIdentityAuthorizationBoundary:
	return get_node_or_null(identity_boundary_path) as PlayerIdentityAuthorizationBoundary
