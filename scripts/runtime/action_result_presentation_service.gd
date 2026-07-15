@tool
extends Node
class_name ActionResultPresentationService

const ACTION_RESULT_V1 := preload("res://scripts/runtime/action_result_v1.gd")

var _configured := false
var _compose_count := 0
var _rejection_count := 0


func configure(_config: Dictionary = {}) -> void:
	_configured = true


func compose(source: Dictionary) -> Dictionary:
	_compose_count += 1
	if not _configured:
		_rejection_count += 1
		return {}
	var request := ACTION_RESULT_V1.sanitize_request(source)
	if request.is_empty():
		_rejection_count += 1
		return _unsafe_source_result()
	var outcome_code := str(request.get("outcome_code", "ready_rejected"))
	var copy := _copy_for_outcome(outcome_code)
	var success := outcome_code == "group_ready_committed"
	var affected_entity_ids: Array = []
	var resolution_id := int(request.get("resolution_id", -1))
	if resolution_id >= 0:
		affected_entity_ids.append("resolution:%d" % resolution_id)
	return ACTION_RESULT_V1.sanitize_public_result({
		"schema_version": ACTION_RESULT_V1.SCHEMA_VERSION,
		"action_id": "card_group_ready",
		"action_family": "card_resolution",
		"status": "committed" if success else "rejected",
		"success": success,
		"failure_code": "" if success else outcome_code,
		"title": str(copy.get("title", "准备状态未更新")),
		"explanation": str(copy.get("explanation", "本次操作没有改变公开牌组状态。")),
		"consequence": str(copy.get("consequence", "当前阶段与牌组保持不变。")),
		"suggested_action": str(copy.get("suggested_action", "请检查牌组状态后重试。")),
		"focus_target": "bid_board",
		"relevant_cost": "无额外费用",
		"relevant_requirement": str(copy.get("relevant_requirement", "持有当前公开牌组并处于可确认阶段。")),
		"affected_entity_ids": affected_entity_ids,
	})


func public_field_schema() -> Array:
	return ACTION_RESULT_V1.public_field_schema()


func debug_snapshot() -> Dictionary:
	return {
		"service_ready": _configured,
		"service_authoritative": false,
		"contract_version": ACTION_RESULT_V1.SCHEMA_VERSION,
		"compose_count": _compose_count,
		"rejection_count": _rejection_count,
		"owns_action_result_presentation": true,
		"owns_rules": false,
		"owns_save_state": false,
		"reads_runtime_nodes": false,
		"reads_world_bridge": false,
		"reads_private_player_state": false,
		"mutates_game_state": false,
		"has_save_api": has_method("to_save_data") or has_method("apply_save_data"),
	}


func _copy_for_outcome(outcome_code: String) -> Dictionary:
	match outcome_code:
		"group_ready_committed":
			return {
				"title": "本阶段准备已提交",
				"explanation": "当前席位已完成公开牌组的本阶段确认。",
				"consequence": "牌组、目标和结算顺序保持不变；全员准备后规则只推进一个阶段。",
				"suggested_action": "等待其他席位确认，或继续查看公开牌轨。",
				"relevant_requirement": "当前席位持有本窗口牌组，且本阶段尚未确认。",
			}
		"player_unavailable":
			return {
				"title": "当前席位无法确认",
				"explanation": "当前视角没有可执行牌组准备的在局席位。",
				"consequence": "准备名单、牌组和阶段均未改变。",
				"suggested_action": "返回牌桌并选择仍在局的当前席位。",
				"relevant_requirement": "必须由仍在局的当前席位提交准备。",
			}
		"queued_entry_missing":
			return {
				"title": "没有可确认的牌组",
				"explanation": "当前席位尚未在这个共享窗口提交普通牌组。",
				"consequence": "准备名单与共享窗口保持不变。",
				"suggested_action": "在规划阶段提交一张合法普通牌，或等待下一共享窗口。",
				"relevant_requirement": "当前席位必须在本窗口拥有一个公开牌组。",
			}
		"group_window_closed":
			return {
				"title": "当前阶段不能确认",
				"explanation": "共享牌组窗口已经结束，或正在进行牌组结算。",
				"consequence": "既有准备状态和结算进度保持不变。",
				"suggested_action": "等待当前结算完成，在下一次规划、公开展示或锁牌阶段确认。",
				"relevant_requirement": "仅规划、公开展示和锁牌阶段接受准备确认。",
			}
		"already_ready":
			return {
				"title": "本阶段已经确认",
				"explanation": "当前席位已经完成这个阶段的准备。",
				"consequence": "不会重复写入准备状态，也不会提前跨越多个阶段。",
				"suggested_action": "等待其他仍在局席位确认。",
				"relevant_requirement": "每个席位在同一阶段只需确认一次。",
			}
		"ready_rejected":
			return {
				"title": "准备提交未完成",
				"explanation": "牌组阶段控制器拒绝了本次准备提交。",
				"consequence": "准备名单、牌组和阶段均未改变。",
				"suggested_action": "刷新牌桌状态后重试；若窗口已推进，请等待下一阶段。",
				"relevant_requirement": "准备请求必须与当前牌组和仍在局席位状态一致。",
			}
	return _copy_for_outcome("ready_rejected")


func _unsafe_source_result() -> Dictionary:
	return ACTION_RESULT_V1.sanitize_public_result({
		"schema_version": ACTION_RESULT_V1.SCHEMA_VERSION,
		"action_id": "card_group_ready",
		"action_family": "card_resolution",
		"status": "rejected",
		"success": false,
		"failure_code": "unsafe_source",
		"title": "准备结果不可公开",
		"explanation": "本次结果包含不属于公开行动反馈的数据。",
		"consequence": "公开反馈已关闭，规则状态不会由展示服务修改。",
		"suggested_action": "刷新牌桌状态后重试。",
		"focus_target": "bid_board",
		"relevant_cost": "无额外费用",
		"relevant_requirement": "行动结果只能包含公开、与视角无关的字段。",
		"affected_entity_ids": [],
	})
