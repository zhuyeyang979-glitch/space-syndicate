extends RefCounted
class_name UnitCardReferenceOwnerV06

const SCHEMA := preload("res://scripts/cards/v06/units/unit_card_runtime_schema_v06.gd")

var _domain := ""
var _revision := 0
var _next_uid := 1
var _units_by_uid: Dictionary = {}
var _reservations_by_transaction: Dictionary = {}
var _history_by_transaction: Dictionary = {}
var _command_log: Array = []
var _failure_modes := {"prepare": false, "commit": false, "rollback": false, "finalize": false}


func configure(domain: String) -> Dictionary:
	_domain = domain
	reset()
	return {
		"configured": ["monster", "military"].has(_domain),
		"domain": _domain,
		"reference_only": true,
	}


func reset() -> void:
	_revision = 0
	_next_uid = 1
	_units_by_uid.clear()
	_reservations_by_transaction.clear()
	_history_by_transaction.clear()
	_command_log.clear()
	for stage in _failure_modes.keys():
		_failure_modes[stage] = false


func set_failure_mode(stage: String, enabled: bool) -> void:
	if _failure_modes.has(stage):
		_failure_modes[stage] = enabled


func revision() -> int:
	return _revision


func seed_unit(actor_id: String, family_id: String, region_id: String, rank: int = 1) -> int:
	var uid := _next_uid
	_next_uid += 1
	_units_by_uid[uid] = {
		"unit_uid": uid,
		"unit_public_id": "%s-unit-%d" % [_domain, uid],
		"domain": _domain,
		"actor_id": actor_id,
		"family_id": family_id,
		"rank": clampi(rank, 1, 4),
		"region_id": region_id,
		"pending_lure": {},
		"accepted_actions": [],
	}
	_revision += 1
	return uid


func unit_card_runtime_capabilities_v06(domain: String) -> Dictionary:
	if domain != _domain:
		return {}
	var effects: Array[String] = []
	var actions: Array[String] = []
	if _domain == "monster":
		effects = ["deploy_or_upgrade_monster", "monster_lure_once", "monster_bound_action"]
		actions = ["deploy_or_upgrade_monster", "monster_lure", "monster_move", "monster_attack", "monster_guard", "monster_area_suppress"]
	else:
		effects = ["deploy_or_upgrade_military", "military_reusable_command"]
		actions = ["deploy_or_upgrade_military", "military_move", "military_guard", "military_attack_monster", "military_suppress_region"]
	return {
		"contract_version": SCHEMA.CONTRACT_VERSION,
		"revision": true,
		"prepare": true,
		"commit": true,
		"rollback": true,
		"finalize": true,
		"exact_once": true,
		"checkpoint_gate": true,
		"privacy_safe_snapshot": true,
		"supported_effect_kinds": effects,
		"supported_action_kinds": actions,
		"reference_only": true,
	}


func unit_card_snapshot_v06(domain: String) -> Dictionary:
	if domain != _domain:
		return {"available": false, "reason_code": "reference_owner_domain_mismatch"}
	var units: Array = []
	for unit_variant in _units_by_uid.values():
		var unit: Dictionary = unit_variant if unit_variant is Dictionary else {}
		units.append({
			"unit_public_id": str(unit.get("unit_public_id", "")),
			"domain": str(unit.get("domain", "")),
			"family_id": str(unit.get("family_id", "")),
			"rank": int(unit.get("rank", 1)),
			"region_id": str(unit.get("region_id", "")),
		})
	return {
		"available": true,
		"domain": _domain,
		"revision": _revision,
		"units": units,
	}


func unit_card_checkpoint_status_v06(domain: String) -> Dictionary:
	if domain != _domain:
		return {"can_checkpoint": false, "reason_code": "reference_owner_domain_mismatch", "inflight_count": -1}
	return {
		"can_checkpoint": _reservations_by_transaction.is_empty(),
		"reason_code": "reference_owner_checkpoint_ready" if _reservations_by_transaction.is_empty() else "reference_owner_inflight_reservations",
		"inflight_count": _reservations_by_transaction.size(),
	}


func prepare_unit_card_intent_v06(intent: Dictionary) -> Dictionary:
	var transaction_id := str(intent.get("transaction_id", ""))
	if _history_by_transaction.has(transaction_id):
		return _history_replay_checked(transaction_id, intent)
	if _reservations_by_transaction.has(transaction_id):
		var existing: Dictionary = _reservation(transaction_id)
		if not SCHEMA.binding_matches(existing.get("intent", {}) as Dictionary, intent):
			return _failure(intent, "reference_transaction_binding_conflict", "该动作编号已用于其他单位动作。", "重新打出这张牌。")
		return _idempotent(existing.get("committed_receipt", existing.get("prepared_receipt", {})) as Dictionary)
	if bool(_failure_modes.get("prepare", false)):
		return _failure(intent, "reference_prepare_injected_failure", "单位状态未能安全预留。", "稍后重试。")
	if int(intent.get("expected_owner_revision", -1)) != _revision:
		return _failure(intent, "unit_owner_revision_stale", "单位状态已发生变化。", "刷新场景后重新选择目标。", {"expected_revision": int(intent.get("expected_owner_revision", -1)), "actual_revision": _revision})
	var target_validation := _validate_authoritative_target(intent)
	if not bool(target_validation.get("valid", false)):
		return _failure(
			intent,
			str(target_validation.get("reason_code", "unit_authoritative_target_invalid")),
			str(target_validation.get("player_reason", "所选目标当前无效。")),
			str(target_validation.get("next_step", "重新选择目标。")),
			target_validation.get("developer_fields", {}) as Dictionary
		)
	var prepared := _base_receipt(intent)
	prepared.merge({
		"prepared": true,
		"committed": false,
		"rolled_back": false,
		"finalized": false,
		"reason_code": "reference_owner_prepared",
		"owner_revision_before": _revision,
		"developer_fields": {"reference_only": true, "domain": _domain},
	}, true)
	_reservations_by_transaction[transaction_id] = {
		"transaction_id": transaction_id,
		"intent_hash": str(intent.get("intent_hash", "")),
		"intent": intent.duplicate(true),
		"prepared_receipt": prepared.duplicate(true),
		"preimage_units": _units_by_uid.duplicate(true),
		"preimage_next_uid": _next_uid,
		"preimage_command_log": _command_log.duplicate(true),
		"revision_before": _revision,
		"committed": false,
	}
	return prepared


func commit_unit_card_intent_v06(prepared: Dictionary) -> Dictionary:
	var transaction_id := str(prepared.get("transaction_id", ""))
	if _history_by_transaction.has(transaction_id):
		return _history_replay_checked(transaction_id, prepared)
	if not _reservations_by_transaction.has(transaction_id):
		return _failure(prepared, "reference_commit_reservation_missing", "单位动作预留已失效。", "重新打出这张牌。")
	var reservation := _reservation(transaction_id)
	if not SCHEMA.binding_matches(reservation.get("intent", {}) as Dictionary, prepared):
		return _failure(prepared, "reference_commit_binding_mismatch", "单位动作与预留不一致。", "重新打出这张牌。")
	if reservation.has("committed_receipt"):
		return _idempotent(reservation.get("committed_receipt", {}) as Dictionary)
	if bool(_failure_modes.get("commit", false)):
		var commit_failed := _failure(prepared, "reference_commit_injected_failure", "单位动作未能执行。", "重试或取消当前动作。")
		commit_failed["prepared"] = true
		return commit_failed
	var intent: Dictionary = reservation.get("intent", {}) as Dictionary
	var apply_result := _apply_intent(intent)
	if not bool(apply_result.get("applied", false)):
		return _failure(prepared, str(apply_result.get("reason_code", "reference_apply_failed")), "单位动作未能执行。", "重新选择目标。", apply_result)
	_revision += 1
	var committed := _base_receipt(intent)
	committed.merge({
		"prepared": true,
		"committed": true,
		"rolled_back": false,
		"finalized": false,
		"reason_code": "reference_owner_committed",
		"owner_revision_before": int(reservation.get("revision_before", -1)),
		"owner_revision_after": _revision,
		"outcome": str(apply_result.get("outcome", "unit_action_accepted")),
		"anonymous": true,
		"public_fields": apply_result.get("public_fields", {}) as Dictionary,
		"private_fields": apply_result.get("private_fields", {}) as Dictionary,
		"developer_fields": {
			"reference_only": true,
			"domain": _domain,
			"owner_apply_result": apply_result.duplicate(true),
		},
	}, true)
	reservation["committed"] = true
	reservation["revision_after"] = _revision
	reservation["committed_receipt"] = committed.duplicate(true)
	_reservations_by_transaction[transaction_id] = reservation
	return committed


func rollback_unit_card_intent_v06(receipt: Dictionary) -> Dictionary:
	var transaction_id := str(receipt.get("transaction_id", ""))
	if _history_by_transaction.has(transaction_id):
		var history: Dictionary = _history_by_transaction.get(transaction_id, {}) as Dictionary
		if not SCHEMA.binding_matches(history.get("binding", {}) as Dictionary, receipt):
			return _failure(receipt, "reference_transaction_binding_conflict", "该动作编号已用于其他单位动作。", "重新打出这张牌。")
		if str(history.get("terminal_stage", "")) == "rolled_back":
			return _idempotent(history.get("receipt", {}) as Dictionary)
		return _failure(receipt, "reference_rollback_window_closed", "该单位动作已经最终结算。", "无法再撤销此动作。")
	if not _reservations_by_transaction.has(transaction_id):
		return _failure(receipt, "reference_rollback_reservation_missing", "该单位动作没有可撤销的预留。", "刷新场景后重试。")
	var reservation := _reservation(transaction_id)
	if not SCHEMA.binding_matches(reservation.get("intent", {}) as Dictionary, receipt):
		return _failure(receipt, "reference_rollback_binding_mismatch", "单位动作与预留不一致。", "刷新场景后重试。")
	if bool(_failure_modes.get("rollback", false)):
		var failed := _failure(receipt, "reference_rollback_injected_failure", "单位动作撤销失败。", "保留现场并联系开发者。")
		failed["prepared"] = true
		failed["committed"] = bool(reservation.get("committed", false))
		failed["compensation_failed"] = true
		return failed
	if bool(reservation.get("committed", false)):
		if _revision != int(reservation.get("revision_after", -1)):
			var closed := _failure(receipt, "reference_rollback_revision_changed", "单位状态之后又发生了变化，无法安全撤销。", "保留现场并联系开发者。")
			closed["prepared"] = true
			closed["committed"] = true
			closed["compensation_failed"] = true
			return closed
		_units_by_uid = (reservation.get("preimage_units", {}) as Dictionary).duplicate(true)
		_next_uid = int(reservation.get("preimage_next_uid", 1))
		_command_log = (reservation.get("preimage_command_log", []) as Array).duplicate(true)
		_revision = int(reservation.get("revision_before", 0))
	var rolled_back := _base_receipt(reservation.get("intent", {}) as Dictionary)
	rolled_back.merge({
		"prepared": true,
		"committed": bool(reservation.get("committed", false)),
		"rolled_back": true,
		"finalized": false,
		"reason_code": "reference_owner_rolled_back",
		"owner_revision_after_rollback": _revision,
	}, true)
	_history_by_transaction[transaction_id] = {
		"intent_hash": str(reservation.get("intent_hash", "")),
		"binding": SCHEMA.binding_from(reservation.get("intent", {}) as Dictionary),
		"terminal_stage": "rolled_back",
		"receipt": rolled_back.duplicate(true),
	}
	_reservations_by_transaction.erase(transaction_id)
	return rolled_back


func finalize_unit_card_intent_v06(receipt: Dictionary) -> Dictionary:
	var transaction_id := str(receipt.get("transaction_id", ""))
	if _history_by_transaction.has(transaction_id):
		var history: Dictionary = _history_by_transaction.get(transaction_id, {}) as Dictionary
		if not SCHEMA.binding_matches(history.get("binding", {}) as Dictionary, receipt):
			return _failure(receipt, "reference_transaction_binding_conflict", "该动作编号已用于其他单位动作。", "重新打出这张牌。")
		if str(history.get("terminal_stage", "")) == "finalized":
			return _idempotent(history.get("receipt", {}) as Dictionary)
		return _failure(receipt, "reference_finalize_window_closed", "该单位动作已经撤销。", "重新打出这张牌。")
	if not _reservations_by_transaction.has(transaction_id):
		return _failure(receipt, "reference_finalize_reservation_missing", "该单位动作没有可完成的结算。", "刷新场景后重试。")
	var reservation := _reservation(transaction_id)
	if not bool(reservation.get("committed", false)):
		var commit_missing := _failure(receipt, "reference_finalize_commit_missing", "单位动作尚未成功执行。", "先执行或撤销当前动作。")
		commit_missing["prepared"] = true
		return commit_missing
	if not SCHEMA.binding_matches(reservation.get("intent", {}) as Dictionary, receipt):
		return _failure(receipt, "reference_finalize_binding_mismatch", "单位动作与预留不一致。", "刷新场景后重试。")
	if bool(_failure_modes.get("finalize", false)):
		var finalize_failed := _failure(receipt, "reference_finalize_injected_failure", "单位动作未能完成最终结算。", "稍后重试。")
		finalize_failed["prepared"] = true
		finalize_failed["committed"] = true
		return finalize_failed
	var finalized := _base_receipt(reservation.get("intent", {}) as Dictionary)
	finalized.merge({
		"prepared": true,
		"committed": true,
		"rolled_back": false,
		"finalized": true,
		"reason_code": "reference_owner_finalized",
		"owner_revision_after": int(reservation.get("revision_after", _revision)),
		"outcome": str((reservation.get("committed_receipt", {}) as Dictionary).get("outcome", "unit_action_accepted")),
		"anonymous": true,
		"public_fields": ((reservation.get("committed_receipt", {}) as Dictionary).get("public_fields", {}) as Dictionary).duplicate(true),
		"private_fields": ((reservation.get("committed_receipt", {}) as Dictionary).get("private_fields", {}) as Dictionary).duplicate(true),
	}, true)
	_history_by_transaction[transaction_id] = {
		"intent_hash": str(reservation.get("intent_hash", "")),
		"binding": SCHEMA.binding_from(reservation.get("intent", {}) as Dictionary),
		"terminal_stage": "finalized",
		"receipt": finalized.duplicate(true),
	}
	_reservations_by_transaction.erase(transaction_id)
	return finalized


func consume_reference_lure(unit_uid: int) -> Dictionary:
	if not _units_by_uid.has(unit_uid):
		return {"consumed": false, "reason_code": "reference_unit_missing"}
	var unit: Dictionary = (_units_by_uid.get(unit_uid, {}) as Dictionary).duplicate(true)
	var lure: Dictionary = unit.get("pending_lure", {}) if unit.get("pending_lure", {}) is Dictionary else {}
	if lure.is_empty() or int(lure.get("remaining_uses", 0)) <= 0:
		return {"consumed": false, "reason_code": "reference_lure_absent"}
	var target_region_id := str(lure.get("target_region_id", ""))
	unit["pending_lure"] = {}
	_units_by_uid[unit_uid] = unit
	_revision += 1
	return {"consumed": true, "reason_code": "reference_lure_consumed", "target_region_id": target_region_id}


func private_debug_snapshot() -> Dictionary:
	return {
		"domain": _domain,
		"revision": _revision,
		"next_uid": _next_uid,
		"units": _units_by_uid.duplicate(true),
		"command_log": _command_log.duplicate(true),
		"inflight_transactions": _reservations_by_transaction.keys(),
		"history_count": _history_by_transaction.size(),
	}


func _validate_authoritative_target(intent: Dictionary) -> Dictionary:
	var target: Dictionary = intent.get("target_context", {}) as Dictionary
	var fields: Dictionary = intent.get("effect_fields", {}) as Dictionary
	var action_kind := str(intent.get("action_kind", ""))
	var actor_id := str(intent.get("actor_id", ""))
	if target.has("unit_uid"):
		var unit_uid := int(target.get("unit_uid", 0))
		if not _units_by_uid.has(unit_uid):
			return {"valid": false, "reason_code": "unit_target_not_found", "player_reason": "所选单位已不在场。", "next_step": "选择仍在场的单位。"}
		var unit: Dictionary = _units_by_uid.get(unit_uid, {}) as Dictionary
		if str(unit.get("actor_id", "")) != actor_id:
			return {"valid": false, "reason_code": "unit_target_not_owned", "player_reason": "你不能命令这支单位。", "next_step": "选择自己的单位。"}
		if action_kind == "deploy_or_upgrade_monster" and str(unit.get("family_id", "")) != str(fields.get("monster_family_id", "")):
			return {"valid": false, "reason_code": "monster_upgrade_family_mismatch", "player_reason": "只能升级自己的同族怪兽。", "next_step": "选择同族怪兽或改为部署。"}
		if action_kind == "deploy_or_upgrade_military" and str(unit.get("family_id", "")) != str(fields.get("military_family_id", "")):
			return {"valid": false, "reason_code": "military_upgrade_family_mismatch", "player_reason": "只能升级自己的同族军队。", "next_step": "选择同族军队或改为部署。"}
		if action_kind == "monster_lure" and not (unit.get("pending_lure", {}) as Dictionary).is_empty():
			return {"valid": false, "reason_code": "monster_lure_already_pending", "player_reason": "这只怪兽已有一次待消费诱导。", "next_step": "等待它完成下一次自动移动。"}
	if target.has("region_id") and str(target.get("region_id", "")).begins_with("invalid"):
		return {"valid": false, "reason_code": "unit_region_not_authoritative", "player_reason": "所选区域当前无效。", "next_step": "选择可进入的区域。"}
	if (action_kind == "deploy_or_upgrade_monster" or action_kind == "deploy_or_upgrade_military") and not target.has("unit_uid"):
		var public_rules: Dictionary = fields.get("public_rule_inputs", {}) if fields.get("public_rule_inputs", {}) is Dictionary else {}
		var control_limit := maxi(1, int(public_rules.get("unit_control_limit", 1)))
		var owned_count := 0
		for unit_variant in _units_by_uid.values():
			var existing: Dictionary = unit_variant if unit_variant is Dictionary else {}
			if str(existing.get("actor_id", "")) == actor_id:
				owned_count += 1
		if owned_count >= control_limit:
			return {"valid": false, "reason_code": "unit_control_limit_reached", "player_reason": "你已达到当前单位归属上限。", "next_step": "升级已有单位，或使用公开规则提供的上限修正。", "developer_fields": {"control_limit": control_limit}}
	return {"valid": true, "reason_code": "reference_target_valid"}


func _apply_intent(intent: Dictionary) -> Dictionary:
	var action_kind := str(intent.get("action_kind", ""))
	var target: Dictionary = intent.get("target_context", {}) as Dictionary
	var fields: Dictionary = intent.get("effect_fields", {}) as Dictionary
	var actor_id := str(intent.get("actor_id", ""))
	var transaction_id := str(intent.get("transaction_id", ""))
	match action_kind:
		"deploy_or_upgrade_monster", "deploy_or_upgrade_military":
			var family_key := "monster_family_id" if _domain == "monster" else "military_family_id"
			var family_id := str(fields.get(family_key, ""))
			var rank := int(fields.get("card_rank", 1))
			var uid := int(target.get("unit_uid", 0))
			var outcome := "unit_upgraded"
			if uid <= 0:
				uid = _next_uid
				_next_uid += 1
				_units_by_uid[uid] = {
					"unit_uid": uid,
					"unit_public_id": "%s-unit-%d" % [_domain, uid],
					"domain": _domain,
					"actor_id": actor_id,
					"family_id": family_id,
					"rank": rank,
					"region_id": str(target.get("region_id", "")),
					"pending_lure": {},
					"accepted_actions": [],
				}
				outcome = "unit_deployed"
			else:
				var unit: Dictionary = (_units_by_uid.get(uid, {}) as Dictionary).duplicate(true)
				unit["rank"] = maxi(int(unit.get("rank", 1)), rank)
				unit["healed_to_full"] = bool(fields.get("heal_to_full_on_upgrade", true))
				if _domain == "monster":
					unit["presence_extension_seconds"] = int(unit.get("presence_extension_seconds", 0)) + int(fields.get("same_name_upgrade_extend_seconds", 0))
				_units_by_uid[uid] = unit
			var public_unit: Dictionary = _units_by_uid.get(uid, {}) as Dictionary
			return {
				"applied": true,
				"outcome": outcome,
				"public_fields": {
					"unit_public_id": str(public_unit.get("unit_public_id", "")),
					"unit_rank": int(public_unit.get("rank", 1)),
					"target_public": {"region_id": str(public_unit.get("region_id", ""))},
					"public_changes": [outcome],
					"anonymous": true,
				},
				"private_fields": {"bound_unit_uid": uid, "card_instance_id": str(intent.get("card_instance_id", ""))},
			}
		"monster_lure":
			var lure_uid := int(target.get("unit_uid", 0))
			var lure_unit: Dictionary = (_units_by_uid.get(lure_uid, {}) as Dictionary).duplicate(true)
			lure_unit["pending_lure"] = {
				"target_region_id": str(target.get("target_region_id", "")),
				"remaining_uses": 1,
				"transaction_id": transaction_id,
			}
			_units_by_uid[lure_uid] = lure_unit
			return {
				"applied": true,
				"outcome": "monster_lure_reserved_once",
				"public_fields": {"unit_public_id": str(lure_unit.get("unit_public_id", "")), "public_changes": ["诱导信号已建立"], "anonymous": true},
				"private_fields": {"bound_unit_uid": lure_uid, "private_target": {"target_region_id": str(target.get("target_region_id", ""))}},
			}
		"monster_move", "monster_attack", "monster_guard", "monster_area_suppress", "military_move", "military_guard", "military_attack_monster", "military_suppress_region":
			var command_uid := int(target.get("unit_uid", 0))
			var command_unit: Dictionary = (_units_by_uid.get(command_uid, {}) as Dictionary).duplicate(true)
			var accepted_actions: Array = command_unit.get("accepted_actions", []) if command_unit.get("accepted_actions", []) is Array else []
			accepted_actions = accepted_actions.duplicate(true)
			accepted_actions.append({
				"transaction_id": transaction_id,
				"action_kind": action_kind,
				"profile_id": str(fields.get("skill_profile_id", fields.get("command_profile_id", ""))),
				"target": target.duplicate(true),
			})
			command_unit["accepted_actions"] = accepted_actions
			_units_by_uid[command_uid] = command_unit
			_command_log.append({"transaction_id": transaction_id, "unit_uid": command_uid, "action_kind": action_kind})
			return {
				"applied": true,
				"outcome": "unit_command_accepted",
				"public_fields": {"unit_public_id": str(command_unit.get("unit_public_id", "")), "public_changes": [action_kind], "anonymous": true},
				"private_fields": {"bound_unit_uid": command_uid, "command_instance_id": str(fields.get("command_instance_id", fields.get("bound_action_instance_id", ""))), "private_target": target.duplicate(true)},
			}
	return {"applied": false, "reason_code": "reference_action_kind_unsupported", "action_kind": action_kind}


func _base_receipt(source: Dictionary) -> Dictionary:
	var result := SCHEMA.binding_from(source)
	result["receipt_version"] = SCHEMA.CONTRACT_VERSION
	result["public_event_id"] = "unit-event-%s" % str(source.get("transaction_id", ""))
	return result


func _failure(source: Dictionary, reason_code: String, player_reason: String, next_step: String, developer_fields: Dictionary = {}) -> Dictionary:
	return SCHEMA.failure_receipt(source, reason_code, player_reason, next_step, developer_fields)


func _reservation(transaction_id: String) -> Dictionary:
	return (_reservations_by_transaction.get(transaction_id, {}) as Dictionary).duplicate(true)


func _history_replay_checked(transaction_id: String, source: Dictionary) -> Dictionary:
	var history: Dictionary = _history_by_transaction.get(transaction_id, {}) as Dictionary
	if not SCHEMA.binding_matches(history.get("binding", {}) as Dictionary, source):
		return _failure(source, "reference_transaction_binding_conflict", "该动作编号已用于其他单位动作。", "重新打出这张牌。")
	return _idempotent(history.get("receipt", {}) as Dictionary)


func _idempotent(receipt: Dictionary) -> Dictionary:
	var result := receipt.duplicate(true)
	result["idempotent_replay"] = true
	return result
