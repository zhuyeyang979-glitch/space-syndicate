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
		return _unsafe_source_result(str(source.get("action_id", "")), str(source.get("action_family", "")))
	if str(request.get("action_id", "")) == "district_card_purchase":
		return _compose_district_card_purchase(request)
	return _compose_card_group_ready(request)


func _compose_card_group_ready(request: Dictionary) -> Dictionary:
	var outcome_code := str(request.get("outcome_code", "ready_rejected"))
	var copy := _card_group_ready_copy(outcome_code)
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


func _compose_district_card_purchase(request: Dictionary) -> Dictionary:
	var outcome_code := str(request.get("outcome_code", "purchase_conflict"))
	var copy := _district_card_purchase_copy(outcome_code)
	var success := outcome_code == "purchase_committed"
	var affected_entity_ids: Array = []
	var district_index := int(request.get("district_index", -1))
	var price_cash := int(request.get("price_cash", -1))
	if success and district_index >= 0:
		affected_entity_ids.append("district:%d" % district_index)
	var consequence := str(copy.get("consequence", "现金、私有手牌与公开挂牌均未由展示服务修改。"))
	if success:
		consequence = "已按公开锁价支付¥%d；一张区域牌进入本席私有手牌，来源区域挂牌已刷新。" % price_cash
	return ACTION_RESULT_V1.sanitize_public_result({
		"schema_version": ACTION_RESULT_V1.SCHEMA_VERSION,
		"action_id": "district_card_purchase",
		"action_family": "card_market",
		"status": "committed" if success else "rejected",
		"success": success,
		"failure_code": "" if success else outcome_code,
		"title": str(copy.get("title", "区域购牌未完成")),
		"explanation": str(copy.get("explanation", "现役市场或结算服务没有接受本次购买。")),
		"consequence": consequence,
		"suggested_action": str(copy.get("suggested_action", "刷新区域牌架后重试。")),
		"focus_target": "district_supply",
		"relevant_cost": "¥%d" % price_cash if success else "未扣款；重新报价前以牌架显示为准",
		"relevant_requirement": str(copy.get("relevant_requirement", "须通过现役市场资格、报价与库存事务检查。")),
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


func _card_group_ready_copy(outcome_code: String) -> Dictionary:
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
	return _card_group_ready_copy("ready_rejected")


func _district_card_purchase_copy(outcome_code: String) -> Dictionary:
	match outcome_code:
		"purchase_committed":
			return {
				"title": "区域购牌已完成",
				"explanation": "现役卡牌事务已提交一笔匿名区域购牌。",
				"consequence": "来源区域记录匿名购牌结果；买家、具体牌名与私有手牌不公开。",
				"suggested_action": "查看本席手牌，或继续浏览区域牌架。",
				"relevant_requirement": "购买须由现役市场报价与库存事务共同提交。",
			}
		"purchase_market_unavailable":
			return {
				"title": "区域市场暂不可用",
				"explanation": "现役区域市场或玩家绑定尚未提供可提交的购买事务。",
				"consequence": "没有产生购牌提交，公开挂牌保持原状态。",
				"suggested_action": "返回牌桌并刷新区域牌架。",
				"relevant_requirement": "区域市场、当前席位与卡牌事务必须同时可用。",
			}
		"purchase_listing_changed":
			return {
				"title": "区域挂牌已经变化",
				"explanation": "提交时的现役挂牌已不再对应刚才选择的牌。",
				"consequence": "本次购买未提交，新的公开挂牌继续有效。",
				"suggested_action": "刷新牌架并重新选择当前挂牌。",
				"relevant_requirement": "选择必须与提交时的现役挂牌一致。",
			}
		"purchase_source_unavailable":
			return {
				"title": "来源区域暂不可购买",
				"explanation": "现役来源资格没有接受这次区域购牌。",
				"consequence": "挂牌、现金与私有手牌保持不变。",
				"suggested_action": "查看来源区域状态，或等待其恢复购买资格。",
				"relevant_requirement": "来源区域必须满足现役市场的购买资格。",
			}
		"purchase_terms_unavailable":
			return {
				"title": "当前报价不能提交",
				"explanation": "现役报价授权在提交前已失效或不再匹配当前挂牌。",
				"consequence": "没有扣款，也没有卡牌进入私有手牌。",
				"suggested_action": "刷新区域牌架并取得新的现役报价。",
				"relevant_requirement": "提交必须通过现役报价授权。",
			}
		"purchase_funds_unavailable":
			return {
				"title": "本次购买资金不足",
				"explanation": "现役结算拒绝了当前报价下的资金提交。",
				"consequence": "没有扣款，私有手牌与公开挂牌保持不变。",
				"suggested_action": "积累资金，或选择其他可承担的公开挂牌。",
				"relevant_requirement": "购买席位须能承担现役锁定报价；不会公开其现金数值。",
			}
		"purchase_inventory_unavailable":
			return {
				"title": "私有牌库暂不能接收",
				"explanation": "现役库存事务没有接受这张区域牌。",
				"consequence": "购买未提交；不会公开手牌、弃牌或库存细节。",
				"suggested_action": "先处理本席私有牌库，再重新购买。",
				"relevant_requirement": "私有牌库必须通过现役库存事务检查。",
			}
		"purchase_conflict":
			return {
				"title": "区域购牌未完成",
				"explanation": "现役事务在提交前检测到状态变化。",
				"consequence": "本次操作没有形成新的购买提交。",
				"suggested_action": "刷新区域牌架后重试。",
				"relevant_requirement": "市场、玩家与库存状态必须在同一次提交中保持一致。",
			}
	return _district_card_purchase_copy("purchase_conflict")


func _unsafe_source_result(requested_action_id: String = "", requested_action_family: String = "") -> Dictionary:
	if requested_action_id == "district_card_purchase" and requested_action_family == "card_market":
		return ACTION_RESULT_V1.sanitize_public_result({
			"schema_version": ACTION_RESULT_V1.SCHEMA_VERSION,
			"action_id": "district_card_purchase",
			"action_family": "card_market",
			"status": "rejected",
			"success": false,
			"failure_code": "unsafe_source",
			"title": "购牌结果不可公开",
			"explanation": "本次结果包含公开 receipt 或失败码之外的数据。",
			"consequence": "公开反馈已关闭，展示服务不会修改现金、库存或挂牌。",
			"suggested_action": "刷新区域牌架后重试。",
			"focus_target": "district_supply",
			"relevant_cost": "以现役市场锁定报价为准",
			"relevant_requirement": "购牌结果只能由匿名公开 receipt 或公开失败码投影。",
			"affected_entity_ids": [],
		})
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
