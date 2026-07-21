extends RefCounted
class_name InteractionEffectRouterV06

const SCHEMA := preload("res://scripts/cards/v06/interaction/anonymous_interaction_runtime_schema_v06.gd")
const DOMAINS := ["intel", "direct_player", "counter_response"]

var _handlers_by_domain: Dictionary = {}
var _associations: Dictionary = {}


func configure(handlers_by_domain: Dictionary) -> Dictionary:
	_handlers_by_domain.clear()
	_associations.clear()
	for domain in DOMAINS:
		var value_variant: Variant = handlers_by_domain.get(domain)
		if value_variant is Object:
			var handler := value_variant as Object
			if handler.has_method("prepare_intent") and handler.has_method("commit_intent") and handler.has_method("rollback_intent") and handler.has_method("finalize_intent"):
				_handlers_by_domain[domain] = handler
	return {"configured": not _handlers_by_domain.is_empty(), "domains": configured_domains()}


func prepare_effect(intent: Dictionary) -> Dictionary:
	var validation := SCHEMA.validate_intent(intent)
	if not bool(validation.get("valid", false)):
		return _validation_failure(intent, validation)
	var transaction_id := str(intent.get("transaction_id", ""))
	if _associations.has(transaction_id):
		var existing := _association(transaction_id)
		if str(existing.get("intent_hash", "")) != str(intent.get("intent_hash", "")):
			return _failure(intent, "interaction_transaction_binding_conflict", "该结算编号已用于其他互动。", "重新打出这张牌。")
		return _replay(existing)
	var domain := str(validation.get("route_domain", ""))
	var handler := _handler(domain)
	if handler == null:
		return _failure(intent, "interaction_effect_owner_unavailable", "该互动效果尚未安全接入。", "请选择其他卡牌。", {"route_domain": domain})
	var routed_intent := intent.duplicate(true)
	routed_intent["route_domain"] = domain
	var value_variant: Variant = handler.call("prepare_intent", routed_intent)
	if not (value_variant is Dictionary):
		return _failure(intent, "interaction_prepare_receipt_invalid", "互动状态未能安全预留。", "刷新场景后重试。")
	var prepared: Dictionary = (value_variant as Dictionary).duplicate(true)
	if not bool(prepared.get("prepared", false)):
		return prepared
	if not SCHEMA.binding_matches(intent, prepared):
		return _failure(intent, "interaction_prepare_binding_mismatch", "互动目标状态已改变。", "刷新目标后重试。", {"owner_receipt": prepared})
	_associations[transaction_id] = {
		"transaction_id": transaction_id,
		"intent_hash": str(intent.get("intent_hash", "")),
		"authoritative_effect_kind": str(intent.get("effect_kind", "")),
		"route_domain": domain,
		"binding": SCHEMA.binding_from(intent),
		"stage": "prepared",
		"prepared_receipt": prepared.duplicate(true),
	}
	return prepared


func commit_effect(prepared: Dictionary) -> Dictionary:
	var association := _bound_association(prepared, "commit")
	if association.has("failure"):
		return association.get("failure") as Dictionary
	if association.has("committed_receipt"):
		return _idempotent(association.get("committed_receipt", {}) as Dictionary)
	if ["rolled_back", "finalized"].has(str(association.get("stage", ""))):
		return _failure(prepared, "interaction_commit_window_closed", "该互动已经结束。", "重新打出这张牌。")
	var handler := _handler(str(association.get("route_domain", "")))
	var owner_source: Dictionary = association.get("prepared_receipt", prepared)
	var value_variant: Variant = handler.call("commit_intent", owner_source.duplicate(true))
	if not (value_variant is Dictionary):
		return _record_failure(association, "commit_failed", _failure(prepared, "interaction_commit_receipt_invalid", "互动效果未能安全完成。", "请重试或取消。"))
	var receipt: Dictionary = (value_variant as Dictionary).duplicate(true)
	if not _owner_receipt_matches(association, receipt):
		return _record_failure(association, "commit_failed", _association_failure(prepared, association, "interaction_commit_owner_binding_mismatch", {"owner_receipt": receipt}))
	if bool(receipt.get("committed", false)):
		association["stage"] = "committed"
		association["committed_receipt"] = receipt.duplicate(true)
	else:
		association["stage"] = "commit_failed"
		association["last_commit_failure"] = receipt.duplicate(true)
	_associations[str(association.get("transaction_id", ""))] = association
	return receipt


func rollback_effect(receipt: Dictionary) -> Dictionary:
	var association := _bound_association(receipt, "rollback")
	if association.has("failure"):
		return association.get("failure") as Dictionary
	if association.has("rollback_receipt"):
		return _idempotent(association.get("rollback_receipt", {}) as Dictionary)
	if str(association.get("stage", "")) == "finalized":
		return _failure(receipt, "interaction_rollback_window_closed", "该互动已经最终结算。", "无法再撤销此互动。")
	var handler := _handler(str(association.get("route_domain", "")))
	var owner_source: Dictionary = association.get("committed_receipt", association.get("prepared_receipt", receipt))
	var value_variant: Variant = handler.call("rollback_intent", owner_source.duplicate(true))
	if not (value_variant is Dictionary):
		return _record_failure(association, "rollback_failed", _failure(receipt, "interaction_rollback_receipt_invalid", "互动效果撤销失败。", "请保留现场并联系开发者。"))
	var result: Dictionary = (value_variant as Dictionary).duplicate(true)
	if not _owner_receipt_matches(association, result):
		return _record_failure(association, "rollback_failed", _association_failure(receipt, association, "interaction_rollback_owner_binding_mismatch", {"owner_receipt": result}))
	if bool(result.get("rolled_back", false)):
		association["stage"] = "rolled_back"
		association["rollback_receipt"] = result.duplicate(true)
	else:
		association["stage"] = "rollback_failed"
		association["last_rollback_failure"] = result.duplicate(true)
	_associations[str(association.get("transaction_id", ""))] = association
	return result


func finalize_effect(receipt: Dictionary) -> Dictionary:
	var association := _bound_association(receipt, "finalize")
	if association.has("failure"):
		return association.get("failure") as Dictionary
	if association.has("finalize_receipt"):
		return _idempotent(association.get("finalize_receipt", {}) as Dictionary)
	if str(association.get("stage", "")) != "committed":
		return _failure(receipt, "interaction_finalize_commit_missing", "该互动尚未成功执行。", "先完成或撤销当前互动。")
	var handler := _handler(str(association.get("route_domain", "")))
	var owner_source: Dictionary = association.get("committed_receipt", receipt)
	var value_variant: Variant = handler.call("finalize_intent", owner_source.duplicate(true))
	if not (value_variant is Dictionary):
		return _record_failure(association, "finalize_failed", _failure(receipt, "interaction_finalize_receipt_invalid", "互动效果未能完成最终结算。", "请稍后重试。"))
	var result: Dictionary = (value_variant as Dictionary).duplicate(true)
	if not _owner_receipt_matches(association, result):
		return _record_failure(association, "finalize_failed", _association_failure(receipt, association, "interaction_finalize_owner_binding_mismatch", {"owner_receipt": result}))
	if bool(result.get("finalized", false)):
		association["stage"] = "finalized"
		association["finalize_receipt"] = result.duplicate(true)
	else:
		association["stage"] = "finalize_failed"
		association["last_finalize_failure"] = result.duplicate(true)
	_associations[str(association.get("transaction_id", ""))] = association
	return result


func configured_domains() -> Array[String]:
	var result: Array[String] = []
	for key_variant in _handlers_by_domain.keys():
		result.append(str(key_variant))
	result.sort()
	return result


func checkpoint_status() -> Dictionary:
	var inflight: Array[String] = []
	for key_variant in _associations.keys():
		var association: Dictionary = _associations.get(key_variant)
		if not ["rolled_back", "finalized"].has(str(association.get("stage", ""))):
			inflight.append(str(key_variant))
	inflight.sort()
	return {"can_checkpoint": inflight.is_empty(), "reason_code": "interaction_router_checkpoint_ready" if inflight.is_empty() else "interaction_router_inflight_transactions", "inflight_transaction_ids": inflight}


func debug_snapshot() -> Dictionary:
	var stages: Dictionary = {}
	for value_variant in _associations.values():
		var stage := str((value_variant as Dictionary).get("stage", "unknown"))
		stages[stage] = int(stages.get(stage, 0)) + 1
	return {"configured_domains": configured_domains(), "transaction_count": _associations.size(), "stage_counts": stages, "checkpoint": checkpoint_status()}


func _bound_association(source: Dictionary, stage: String) -> Dictionary:
	var transaction_id := str(source.get("transaction_id", ""))
	if not _associations.has(transaction_id):
		return {"failure": _failure(source, "interaction_%s_transaction_missing" % stage, "该互动的结算记录不存在。", "重新打出这张牌。")}
	var association := _association(transaction_id)
	if not SCHEMA.binding_matches(association.get("binding", {}) as Dictionary, source):
		return {"failure": _association_failure(source, association, "interaction_%s_binding_mismatch" % stage)}
	return association


func _owner_receipt_matches(association: Dictionary, receipt: Dictionary) -> bool:
	return SCHEMA.binding_matches(association.get("binding", {}) as Dictionary, receipt) \
	and str(receipt.get("effect_kind", "")) == str(association.get("authoritative_effect_kind", ""))


func _handler(domain: String) -> Object:
	var value_variant: Variant = _handlers_by_domain.get(domain)
	return value_variant as Object if value_variant is Object else null


func _association(transaction_id: String) -> Dictionary:
	return (_associations.get(transaction_id, {}) as Dictionary).duplicate(true)


func _record_failure(association: Dictionary, stage: String, failure: Dictionary) -> Dictionary:
	association["stage"] = stage
	association["last_failure"] = failure.duplicate(true)
	_associations[str(association.get("transaction_id", ""))] = association
	return failure


func _replay(association: Dictionary) -> Dictionary:
	for key in ["finalize_receipt", "rollback_receipt", "committed_receipt", "prepared_receipt"]:
		if association.has(key):
			return _idempotent(association.get(key, {}) as Dictionary)
	return _failure(association.get("binding", {}) as Dictionary, "interaction_journal_invalid", "互动结算记录无效。", "刷新场景后重试。")


func _idempotent(receipt: Dictionary) -> Dictionary:
	var result := receipt.duplicate(true)
	result["idempotent_replay"] = true
	return result


func _validation_failure(intent: Dictionary, validation: Dictionary) -> Dictionary:
	var feedback: Dictionary = validation.get("player_feedback", {}) if validation.get("player_feedback", {}) is Dictionary else {}
	return _failure(intent, str(validation.get("reason_code", "interaction_intent_invalid")), str(feedback.get("reason", "互动请求无效。")), str(feedback.get("next_step", "重新选择卡牌与目标。")), validation.get("developer_fields", {}) as Dictionary)


func _association_failure(source: Dictionary, association: Dictionary, reason_code: String, fields: Dictionary = {}) -> Dictionary:
	var developer_fields := fields.duplicate(true)
	developer_fields["authoritative_effect_kind"] = str(association.get("authoritative_effect_kind", ""))
	developer_fields["authoritative_route_domain"] = str(association.get("route_domain", ""))
	return _failure(source, reason_code, "互动请求与原结算记录不一致。", "重新打出这张牌。", developer_fields)


func _failure(source: Dictionary, reason_code: String, reason: String, next_step: String, fields: Dictionary = {}) -> Dictionary:
	return SCHEMA.failure_receipt(source, reason_code, reason, next_step, fields)
