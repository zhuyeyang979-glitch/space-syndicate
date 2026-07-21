extends RefCounted
class_name SpaceSyndicateTemporaryDecisionPreviewFixtures

const MONSTER_WAGER := "monster_wager"
const DISCARD_PURCHASE := "discard_purchase"
const MONSTER_TARGET_CHOICE := "monster_target_choice"
const PLAYER_TARGET_CHOICE := "player_target_choice"


func preview_ids() -> Array[String]:
	return [
		MONSTER_WAGER,
		DISCARD_PURCHASE,
		MONSTER_TARGET_CHOICE,
		PLAYER_TARGET_CHOICE,
	]


func preview_label(id: String) -> String:
	match id:
		MONSTER_WAGER:
			return "怪兽赌局"
		DISCARD_PURCHASE:
			return "私密弃牌"
		MONSTER_TARGET_CHOICE:
			return "怪兽目标"
		PLAYER_TARGET_CHOICE:
			return "玩家目标"
	return "未知状态"


func fixture(id: String) -> Dictionary:
	match id:
		MONSTER_WAGER:
			return _monster_wager_fixture()
		DISCARD_PURCHASE:
			return _discard_purchase_fixture()
		MONSTER_TARGET_CHOICE:
			return _monster_target_fixture()
		PLAYER_TARGET_CHOICE:
			return _player_target_fixture()
	return malformed_fixture()


func all_fixtures() -> Array:
	var result: Array = []
	for id in preview_ids():
		result.append(fixture(id))
	return result


func long_text_fixture(id: String) -> Dictionary:
	var data := fixture(id).duplicate(true)
	var long_tail := " 这段压力文本用于检查 UI 截断、换行和 tooltip：匿名身份、公开线索、隐私边界、倒计时、禁用按钮与长商品路线都需要稳定显示。"
	data["body"] = str(data.get("body", "")) + long_tail + long_tail
	data["tooltip"] = str(data.get("tooltip", "")) + long_tail
	var kind := str(data.get("kind", ""))
	if kind == MONSTER_WAGER and data.get("wager", {}) is Dictionary:
		var wager: Dictionary = (data.get("wager", {}) as Dictionary).duplicate(true)
		wager["side_hint"] = str(wager.get("side_hint", "")) + long_tail
		wager["public_decisions"] = str(wager.get("public_decisions", "")) + "｜玩家2 +10%｜玩家3 强制底注｜玩家4 尚未决定"
		data["wager"] = wager
	elif data.get("choice", {}) is Dictionary:
		var choice: Dictionary = (data.get("choice", {}) as Dictionary).duplicate(true)
		choice["summary"] = str(choice.get("summary", "")) + long_tail
		choice["privacy"] = str(choice.get("privacy", "")) + long_tail
		choice["public_after"] = str(choice.get("public_after", "")) + "，并和牌轨、地图、收益变化一起成为推理依据"
		data["choice"] = choice
	return data


func disabled_action_fixture(id: String) -> Dictionary:
	var data := fixture(id).duplicate(true)
	var actions: Array = data.get("actions", []) if data.get("actions", []) is Array else []
	var normalized: Array = []
	for i in range(actions.size()):
		if not (actions[i] is Dictionary):
			continue
		var action := (actions[i] as Dictionary).duplicate(true)
		if i == 0:
			action["disabled"] = true
			action["tooltip"] = "%s｜QA：此按钮被禁用。" % str(action.get("tooltip", ""))
		normalized.append(action)
	data["actions"] = normalized
	return data


func malformed_fixture() -> Dictionary:
	return {
		"id": "preview_malformed_payload",
		"kind": "preview_unknown_kind",
		"title": "异常 payload",
		"body": "缺少已知 kind 时应该落回通用确认面板；空 action id 保持不可点。",
		"tooltip": "Preview 用来验证 OverlayLayer 的兜底渲染，不连接任何规则函数。",
		"chips": [
			{"text": "兜底", "tooltip": "未知 kind", "accent": "#94a3b8"},
			{"text": "无规则", "tooltip": "不调用 main.gd", "accent": "#cbd5e1"},
		],
		"actions": [
			{"id": "", "label": "空动作", "tooltip": "空 id 应禁用", "disabled": true},
			{"id": "preview_malformed_ack", "label": "确认", "tooltip": "只验证信号通道"},
		],
		"accent": "#94a3b8",
	}


func _monster_wager_fixture() -> Dictionary:
	return {
		"id": "preview_monster_wager_7",
		"kind": MONSTER_WAGER,
		"title": "怪兽赌局 #7",
		"body": "相位兽 vs 潮汐巨兽｜全场冻结，公开百分比下注。",
		"tooltip": "怪兽遭遇触发公开下注；身份、方向、百分比和金额都公开。",
		"chips": [
			{"text": "全场冻结", "tooltip": "下注结束前暂停常规出牌。", "accent": "#fb7185"},
			{"text": "底注5%", "tooltip": "最低公开下注。", "accent": "#fb923c"},
			{"text": "已押 1/4", "tooltip": "全员下注后提前结算。", "accent": "#c4b5fd"},
			{"text": "选择中", "tooltip": "15秒强制选择窗口正在缩短。", "accent": "#fed7aa"},
		],
		"actions": [
			{"id": "monster_wager:7:a:5", "label": "押相位兽 5%", "tooltip": "以当前席位公开押相位兽。"},
			{"id": "monster_wager:7:b:5", "label": "押潮汐兽 5%", "tooltip": "以当前席位公开押潮汐巨兽。"},
			{"id": "monster_wager:7:a:10", "label": "相位兽 +5%", "tooltip": "加码公开下注。"},
			{"id": "monster_wager:7:b:10", "label": "潮汐兽 +5%", "tooltip": "加码公开下注。"},
		],
		"wager": {
			"matchup": "相位兽 vs 潮汐巨兽",
			"damage": "相位兽:3 / 潮汐巨兽:1",
			"public_decisions": "玩家1 5%/¥50 → 相位兽",
			"context": "怪兽遭遇",
			"base_percent": 5,
			"pool": 50,
			"decided": 1,
			"seat_count": 4,
			"timer": 15.0,
			"timer_text": "选择中",
			"side_hint": "你尚未下注；底注5%，可加码。",
		},
		"accent": "#fb923c",
	}


func _discard_purchase_fixture() -> Dictionary:
	return {
		"id": "preview_discard_purchase",
		"kind": DISCARD_PURCHASE,
		"title": "私密弃牌确认",
		"body": "手牌已满。弃1张旧牌，接收轨道融资（约¥20）。",
		"tooltip": "购牌窗口锁定后的私密选择；公开日志不写手牌或弃牌名称。",
		"chips": [
			{"text": "私密", "tooltip": "只有当前玩家可见。", "accent": "#bfdbfe"},
			{"text": "不公开", "tooltip": "不公开弃牌名称。", "accent": "#facc15"},
			{"text": "换购", "tooltip": "弃旧牌后接收新牌。", "accent": "#22c55e"},
		],
		"actions": [
			{"id": "discard_purchase_0", "label": "弃掉 移动", "tooltip": "私密弃掉旧普通牌。"},
			{"id": "discard_purchase_2", "label": "弃掉 侦察", "tooltip": "私密弃掉另一张旧牌。"},
			{"id": "discard_purchase_cancel", "label": "取消换购", "tooltip": "取消本次购牌。"},
		],
		"choice": {
			"mode": "discard",
			"mode_label": "私密换购",
			"card": "轨道融资",
			"summary": "手牌已满；从2张可弃旧普通牌中选1张，再接收新牌。",
			"context": "价格约¥20｜普通手牌上限5张",
			"privacy": "弃牌选择只在当前玩家私有流水中记录；公开日志不会写手牌或弃掉哪张牌。",
			"public_after": "换购完成后只体现经济结果，不公开弃牌名称。",
			"option_count": 2,
		},
		"accent": "#a78bfa",
	}


func _monster_target_fixture() -> Dictionary:
	return {
		"id": "preview_monster_target_choice",
		"kind": MONSTER_TARGET_CHOICE,
		"title": "请选择目标怪兽",
		"body": "相位诱导需要先指定目标怪兽；进入公开牌轨后，卡面和目标会向所有人展示。",
		"tooltip": "目标与效果公开，出牌者仍匿名。",
		"chips": [
			{"text": "私密", "tooltip": "只有当前出牌玩家操作。", "accent": "#bfdbfe"},
			{"text": "阻塞出牌", "tooltip": "选定目标后提交到牌轨。", "accent": "#fecdd3"},
			{"text": "目标公开", "tooltip": "目标会成为推理线索。", "accent": "#fda4af"},
		],
		"actions": [
			{"id": "target_monster_uid_101", "label": "怪1 相位兽", "tooltip": "指定相位兽。"},
			{"id": "target_monster_uid_102", "label": "怪2 潮汐兽", "tooltip": "指定潮汐巨兽。", "disabled": true},
			{"id": "target_monster_cancel", "label": "取消", "tooltip": "取消目标选择。"},
		],
		"choice": {
			"mode": "monster_target",
			"mode_label": "怪兽目标",
			"card": "相位诱导",
			"summary": "先选目标怪兽，再把卡牌送入公开牌轨。",
			"context": "可选目标1/2只｜倒下目标不可选",
			"privacy": "选择动作只给当前出牌者；卡牌进入轨道后仍隐藏出牌者。",
			"public_after": "卡面和目标怪兽会公开，成为全场推理线索。",
			"target_count": 2,
			"enabled_count": 1,
		},
		"accent": "#fb7185",
	}


func _player_target_fixture() -> Dictionary:
	return {
		"id": "preview_player_target_choice",
		"kind": PLAYER_TARGET_CHOICE,
		"title": "请选择目标玩家",
		"body": "相位否决会影响一名玩家；结算时目标和影响公开，但出牌者仍保持匿名。",
		"tooltip": "直接互动牌先在桌边选目标，再进入公开牌轨。",
		"chips": [
			{"text": "私密", "tooltip": "只有当前出牌玩家操作。", "accent": "#bfdbfe"},
			{"text": "直接互动", "tooltip": "目标玩家会成为公开线索。", "accent": "#93c5fd"},
			{"text": "匿名入轨", "tooltip": "提交后仍隐藏出牌者。", "accent": "#60a5fa"},
		],
		"actions": [
			{"id": "target_player_1", "label": "玩家2", "tooltip": "选择玩家2。"},
			{"id": "target_player_2", "label": "玩家3", "tooltip": "选择玩家3。"},
			{"id": "target_player_cancel", "label": "取消", "tooltip": "取消目标玩家选择。"},
		],
		"choice": {
			"mode": "player_target",
			"mode_label": "玩家目标",
			"card": "相位否决",
			"summary": "选择一名其他席位作为直接互动目标。",
			"context": "可选目标3名｜不能选择自己",
			"privacy": "选择动作只给当前出牌者；卡牌提交后仍隐藏出牌者。",
			"public_after": "目标玩家和影响会公开，成为后续收益变化的线索。",
			"target_count": 3,
		},
		"accent": "#60a5fa",
	}
