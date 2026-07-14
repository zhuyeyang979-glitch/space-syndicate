extends RefCounted
class_name UnitCardEffectRouterV06

const SCHEMA := preload("res://scripts/cards/v06/units/unit_card_runtime_schema_v06.gd")

var _handlers_by_effect_kind: Dictionary = {}
var _associations_by_transaction: Dictionary = {}


func configure(handlers_by_effect_kind: Dictionary) -> Dictionary:
	_handlers_by_effect_kind.clear()
	_associations_by_transaction.clear()
	for effect_kind in SCHEMA.supported_effect_kinds():
		var handler_variant: Variant = handlers_by_effect_kind.get(effect_kind)
		if handler_variant is Object:
			var handler := handler_variant as Object
			if handler.has_method("prepare_effect") and handler.has_method("commit_effect") and handler.has_method("rollback_effect") and handler.has_method("finalize_effect"):
				_handlers_by_effect_kind[effect_kind] = handler
	return {
		"configured": not _handlers_by_effect_kind.is_empty(),
		"effect_kinds": configured_effect_kinds(),
	}


func prepare_effect(intent: Dictionary) -> Dictionary:
	intent = _normalize_card_flow_intent(intent)
	var validation: Dictionary = SCHEMA.validate_intent(intent)
	if not bool(validation.get("valid", false)):
		return _validation_failure(intent, validation)
	var transaction_id := str(intent.get("transaction_id", ""))
	if _associations_by_transaction.has(transaction_id):
		var existing: Dictionary = _association(transaction_id)
		if not SCHEMA.binding_matches(existing.get("binding", {}) as Dictionary, intent):
			return _failure(intent, "unit_transaction_binding_conflict", "该结算编号已用于其他动作。", "重新打出这张牌。")
		return _replay_for_association(existing)
	var effect_kind := str(intent.get("effect_kind", ""))
	var handler := _handler(effect_kind)
	if handler == null:
		return _failure(intent, "unit_effect_owner_unavailable", "该单位牌效果尚未接入。", "请选择其他卡牌。")
	var value_variant: Variant = handler.call("prepare_effect", intent.duplicate(true))
	if not (value_variant is Dictionary):
		return _failure(intent, "unit_prepare_receipt_invalid", "单位状态未能安全预留。", "刷新场景后重试。")
	var prepared: Dictionary = (value_variant as Dictionary).duplicate(true)
	if not bool(prepared.get("prepared", false)):
		return prepared
	if not SCHEMA.binding_matches(intent, prepared):
		return _failure(intent, "unit_prepare_binding_mismatch", "单位状态已发生变化。", "刷新场景后重试。", {"owner_receipt": prepared})
	_associations_by_transaction[transaction_id] = {
		"transaction_id": transaction_id,
		"intent_hash": str(intent.get("intent_hash", "")),
		"effect_kind": effect_kind,
		"action_kind": str(intent.get("action_kind", "")),
		"binding": SCHEMA.binding_from(intent),
		"stage": "prepared",
		"prepared_receipt": prepared.duplicate(true),
	}
	return prepared


func commit_effect(prepared: Dictionary) -> Dictionary:
	var transaction_id := str(prepared.get("transaction_id", ""))
	if not _associations_by_transaction.has(transaction_id):
		return _failure(prepared, "unit_commit_transaction_missing", "该单位动作的预留已失效。", "重新打出这张牌。")
	var association: Dictionary = _association(transaction_id)
	if not _source_matches_association(prepared, association):
		return _association_failure(prepared, association, "unit_commit_binding_mismatch")
	if association.has("committed_receipt"):
		return _idempotent(association.get("committed_receipt", {}) as Dictionary)
	if ["rolled_back", "finalized"].has(str(association.get("stage", ""))):
		return _failure(prepared, "unit_commit_window_closed", "该单位动作已经结束。", "重新打出这张牌。")
	var handler := _handler(str(association.get("effect_kind", "")))
	if handler == null:
		return _failure(prepared, "unit_effect_owner_unavailable", "该单位牌效果尚未接入。", "请选择其他卡牌。")
	var value_variant: Variant = handler.call("commit_effect", (association.get("prepared_receipt", prepared) as Dictionary).duplicate(true))
	if not (value_variant is Dictionary):
		association["stage"] = "commit_failed"
		_associations_by_transaction[transaction_id] = association
		return _failure(prepared, "unit_commit_receipt_invalid", "单位动作未能安全完成。", "请重试或取消该动作。")
	var receipt: Dictionary = (value_variant as Dictionary).duplicate(true)
	if not SCHEMA.binding_matches(association.get("binding", {}) as Dictionary, receipt):
		association["stage"] = "commit_failed"
		_associations_by_transaction[transaction_id] = association
		return _association_failure(prepared, association, "unit_commit_owner_binding_mismatch", {"owner_receipt": receipt})
	if bool(receipt.get("committed", false)):
		association["stage"] = "committed"
		association["committed_receipt"] = receipt.duplicate(true)
	else:
		association["stage"] = "commit_failed"
		association["last_commit_failure"] = receipt.duplicate(true)
	_associations_by_transaction[transaction_id] = association
	return receipt


func rollback_effect(receipt: Dictionary) -> Dictionary:
	var transaction_id := str(receipt.get("transaction_id", ""))
	if not _associations_by_transaction.has(transaction_id):
		return _failure(receipt, "unit_rollback_transaction_missing", "该单位动作没有可撤销的预留。", "刷新场景后重试。")
	var association: Dictionary = _association(transaction_id)
	if not _source_matches_association(receipt, association):
		return _association_failure(receipt, association, "unit_rollback_binding_mismatch")
	if association.has("rollback_receipt"):
		return _idempotent(association.get("rollback_receipt", {}) as Dictionary)
	if str(association.get("stage", "")) == "finalized":
		return _failure(receipt, "unit_rollback_window_closed", "该单位动作已经最终结算。", "无法再撤销此动作。")
	var handler := _handler(str(association.get("effect_kind", "")))
	if handler == null:
		return _failure(receipt, "unit_effect_owner_unavailable", "该单位动作无法安全撤销。", "请保留现场并联系开发者。")
	var owner_source: Dictionary = association.get("committed_receipt", association.get("prepared_receipt", receipt)) as Dictionary
	var value_variant: Variant = handler.call("rollback_effect", owner_source.duplicate(true))
	if not (value_variant is Dictionary):
		association["stage"] = "rollback_failed"
		_associations_by_transaction[transaction_id] = association
		return _failure(receipt, "unit_rollback_receipt_invalid", "单位动作撤销失败。", "请保留现场并联系开发者。")
	var result: Dictionary = (value_variant as Dictionary).duplicate(true)
	if not SCHEMA.binding_matches(association.get("binding", {}) as Dictionary, result):
		association["stage"] = "rollback_failed"
		_associations_by_transaction[transaction_id] = association
		return _association_failure(receipt, association, "unit_rollback_owner_binding_mismatch", {"owner_receipt": result})
	if bool(result.get("rolled_back", false)):
		association["stage"] = "rolled_back"
		association["rollback_receipt"] = result.duplicate(true)
	else:
		association["stage"] = "rollback_failed"
		association["last_rollback_failure"] = result.duplicate(true)
	_associations_by_transaction[transaction_id] = association
	return result


func finalize_effect(receipt: Dictionary) -> Dictionary:
	var transaction_id := str(receipt.get("transaction_id", ""))
	if not _associations_by_transaction.has(transaction_id):
		return _failure(receipt, "unit_finalize_transaction_missing", "该单位动作没有可完成的结算。", "刷新场景后重试。")
	var association: Dictionary = _association(transaction_id)
	if not _source_matches_association(receipt, association):
		return _association_failure(receipt, association, "unit_finalize_binding_mismatch")
	if association.has("finalized_receipt"):
		return _idempotent(association.get("finalized_receipt", {}) as Dictionary)
	if not ["committed", "finalize_failed"].has(str(association.get("stage", ""))):
		return _failure(receipt, "unit_finalize_commit_missing", "该单位动作尚未成功执行。", "先完成或撤销当前动作。")
	var handler := _handler(str(association.get("effect_kind", "")))
	if handler == null:
		return _failure(receipt, "unit_effect_owner_unavailable", "该单位动作无法完成最终结算。", "请稍后重试。")
	var owner_source: Dictionary = association.get("committed_receipt", receipt) as Dictionary
	var value_variant: Variant = handler.call("finalize_effect", owner_source.duplicate(true))
	if not (value_variant is Dictionary):
		association["stage"] = "finalize_failed"
		_associations_by_transaction[transaction_id] = association
		return _failure(receipt, "unit_finalize_receipt_invalid", "单位动作未能完成最终结算。", "请稍后重试。")
	var result: Dictionary = (value_variant as Dictionary).duplicate(true)
	if not SCHEMA.binding_matches(association.get("binding", {}) as Dictionary, result):
		association["stage"] = "finalize_failed"
		_associations_by_transaction[transaction_id] = association
		return _association_failure(receipt, association, "unit_finalize_owner_binding_mismatch", {"owner_receipt": result})
	if bool(result.get("finalized", false)):
		association["stage"] = "finalized"
		association["finalized_receipt"] = result.duplicate(true)
	else:
		association["stage"] = "finalize_failed"
		association["last_finalize_failure"] = result.duplicate(true)
	_associations_by_transaction[transaction_id] = association
	return result


func configured_effect_kinds() -> Array[String]:
	var result: Array[String] = []
	for key_variant in _handlers_by_effect_kind.keys():
		result.append(str(key_variant))
	result.sort()
	return result


func checkpoint_status() -> Dictionary:
	var inflight: Array[String] = []
	for transaction_variant in _associations_by_transaction.keys():
		var transaction_id := str(transaction_variant)
		var stage := str((_associations_by_transaction.get(transaction_id, {}) as Dictionary).get("stage", ""))
		if not ["rolled_back", "finalized"].has(stage):
			inflight.append(transaction_id)
	inflight.sort()
	return {
		"can_checkpoint": inflight.is_empty(),
		"reason_code": "unit_router_checkpoint_ready" if inflight.is_empty() else "unit_router_inflight_transactions",
		"inflight_count": inflight.size(),
		"inflight_transaction_ids": inflight,
	}


func debug_snapshot() -> Dictionary:
	var stage_counts: Dictionary = {}
	for association_variant in _associations_by_transaction.values():
		var association: Dictionary = association_variant if association_variant is Dictionary else {}
		var stage := str(association.get("stage", "unknown"))
		stage_counts[stage] = int(stage_counts.get(stage, 0)) + 1
	return {
		"configured_effect_kinds": configured_effect_kinds(),
		"transaction_count": _associations_by_transaction.size(),
		"stage_counts": stage_counts,
		"checkpoint": checkpoint_status(),
	}


func _handler(effect_kind: String) -> Object:
	var value: Variant = _handlers_by_effect_kind.get(effect_kind)
	return value as Object if value is Object else null


func _normalize_card_flow_intent(intent: Dictionary) -> Dictionary:
	if str(intent.get("contract_version", "")) == SCHEMA.CONTRACT_VERSION:
		return intent.duplicate(true)
	var effect_kind := str(intent.get("effect_kind", ""))
	var target: Dictionary = intent.get("target_context", {}) if intent.get("target_context", {}) is Dictionary else {}
	var payload: Dictionary = intent.get("effect_payload", {}) if intent.get("effect_payload", {}) is Dictionary else {}
	var action_kind := ""
	if effect_kind == "deploy_or_upgrade_monster" or effect_kind == "deploy_or_upgrade_military":
		action_kind = effect_kind
	else:
		action_kind = str(payload.get("action_kind", target.get("action_kind", "")))
	return SCHEMA.normalize_card_flow_intent(intent, int(target.get("expected_owner_revision", -1)), action_kind)


func _association(transaction_id: String) -> Dictionary:
	return (_associations_by_transaction.get(transaction_id, {}) as Dictionary).duplicate(true)


func _source_matches_association(source: Dictionary, association: Dictionary) -> bool:
	var binding: Dictionary = association.get("binding", {}) if association.get("binding", {}) is Dictionary else {}
	return SCHEMA.binding_matches(binding, source)


func _replay_for_association(association: Dictionary) -> Dictionary:
	for key in ["finalized_receipt", "rollback_receipt", "committed_receipt", "prepared_receipt"]:
		if association.has(key):
			return _idempotent(association.get(key, {}) as Dictionary)
	return _failure(association.get("binding", {}) as Dictionary, "unit_transaction_journal_invalid", "该单位动作的结算记录无效。", "刷新场景后重试。")


func _idempotent(receipt: Dictionary) -> Dictionary:
	var result := receipt.duplicate(true)
	result["idempotent_replay"] = true
	return result


func _validation_failure(intent: Dictionary, validation: Dictionary) -> Dictionary:
	var feedback: Dictionary = validation.get("player_feedback", {}) if validation.get("player_feedback", {}) is Dictionary else {}
	return _failure(intent, str(validation.get("reason_code", "unit_intent_invalid")), str(feedback.get("reason", "这张牌暂时不能使用。")), str(feedback.get("next_step", "重新选择卡牌与目标。")), validation.get("developer_fields", {}) as Dictionary)


func _association_failure(source: Dictionary, association: Dictionary, reason_code: String, developer_fields: Dictionary = {}) -> Dictionary:
	var fields := developer_fields.duplicate(true)
	fields["authoritative_effect_kind"] = str(association.get("effect_kind", ""))
	fields["authoritative_action_kind"] = str(association.get("action_kind", ""))
	return _failure(source, reason_code, "单位动作与原结算记录不一致。", "重新打出这张牌。", fields)


func _failure(source: Dictionary, reason_code: String, player_reason: String, next_step: String, developer_fields: Dictionary = {}) -> Dictionary:
	return SCHEMA.failure_receipt(source, reason_code, player_reason, next_step, developer_fields)
