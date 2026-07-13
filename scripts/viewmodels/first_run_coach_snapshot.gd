extends RefCounted
class_name FirstRunCoachSnapshot

const STAGE_SELECT_DISTRICT := "select_district"
const STAGE_FIRST_SUMMON := "first_summon"
const STAGE_BUILD_CITY := "build_city"
const STAGE_OPEN_RACK := "open_rack"
const STAGE_BUY_CARD := "buy_card"
const STAGE_PLAY_CARD := "play_card"
const STAGE_INSPECT_TRACK := "inspect_track"
const STAGE_CHECK_ECONOMY := "check_economy"
const STAGE_OBSERVE_AI_PUBLIC_ACTION := "observe_ai_public_action"
const STAGE_INSPECT_CLUES := "inspect_clues"
const STAGE_INSPECT_MONSTER_PRESSURE := "inspect_monster_pressure"
const STAGE_CHOOSE_ROUTE := "choose_route"
const STAGE_DONE := "done"

const STEP_ORDER := [
	STAGE_SELECT_DISTRICT,
	STAGE_FIRST_SUMMON,
	STAGE_OPEN_RACK,
	STAGE_BUY_CARD,
	STAGE_PLAY_CARD,
	STAGE_INSPECT_TRACK,
	STAGE_CHECK_ECONOMY,
	STAGE_OBSERVE_AI_PUBLIC_ACTION,
	STAGE_INSPECT_CLUES,
	STAGE_INSPECT_MONSTER_PRESSURE,
	STAGE_CHOOSE_ROUTE,
]

var ui: Dictionary = {}


func apply_dictionary(data: Dictionary) -> RefCounted:
	var source := data.duplicate(true)
	var progress: Dictionary = source.get("progress", {}) if source.get("progress", {}) is Dictionary else {}
	var visible := bool(source.get("visible", not source.is_empty()))
	var dismissed := bool(source.get("dismissed", false))
	var stage := str(source.get("stage", "")).strip_edges()
	if stage == "":
		stage = _stage_from_progress(progress, bool(source.get("auto_fold_after_route_choice", true)))
	var collapsed := bool(source.get("collapsed", false)) or stage == STAGE_DONE
	if dismissed:
		visible = false
	var definition := _stage_definition(stage)
	var primary_action: Dictionary = source.get("primary_action", {}) if source.get("primary_action", {}) is Dictionary else {}
	if primary_action.is_empty():
		primary_action = _default_primary_action(stage)
	ui = {
		"visible": visible,
		"collapsed": collapsed,
		"stage": stage,
		"phase_id": stage,
		"phase_label": str(source.get("phase_label", definition.get("phase_label", "首局引导"))),
		"title": str(source.get("title", definition.get("title", "下一步"))),
		"body": str(source.get("body", definition.get("body", ""))),
		"tooltip": str(source.get("tooltip", definition.get("tooltip", definition.get("body", "")))),
		"focus_target": str(source.get("focus_target", _focus_target_for_stage(stage))).strip_edges(),
		"stuck_state": str(source.get("stuck_state", "none")),
		"pulse_focus": bool(source.get("pulse_focus", false)),
		"shortest_action_text": str(source.get("shortest_action_text", _shortest_action_for_stage(stage))),
		"progress_text": _progress_text(progress, stage),
		"chips": _normalized_chips(source.get("chips", _stage_chips(progress, stage))),
		"primary_action": _normalize_action(primary_action, stage),
		"recommended_setup": _recommended_setup(source.get("recommended_setup", {})),
		"steps": _step_summaries(progress, stage),
	}
	return self


func to_ui_dictionary() -> Dictionary:
	return ui.duplicate(true)


func _stage_from_progress(progress: Dictionary, auto_fold_after_route_choice: bool) -> String:
	if _bool(progress, "completed"):
		return STAGE_DONE
	if auto_fold_after_route_choice and _bool(progress, "has_chosen_route"):
		return STAGE_DONE
	if not _bool(progress, "selected_district"):
		return STAGE_SELECT_DISTRICT
	if not _bool(progress, "has_monster"):
		return STAGE_FIRST_SUMMON
	if not _bool(progress, "has_opened_supply"):
		return STAGE_OPEN_RACK
	if not _bool(progress, "has_bought_card"):
		return STAGE_BUY_CARD
	if not _bool(progress, "has_played_card"):
		return STAGE_PLAY_CARD
	if not _bool(progress, "has_seen_public_track"):
		return STAGE_INSPECT_TRACK
	if not _bool(progress, "has_checked_economy"):
		return STAGE_CHECK_ECONOMY
	if not _bool(progress, "has_seen_ai_public_action"):
		return STAGE_OBSERVE_AI_PUBLIC_ACTION
	if not _bool(progress, "has_seen_clues"):
		return STAGE_INSPECT_CLUES
	if not _bool(progress, "has_seen_monster_pressure"):
		return STAGE_INSPECT_MONSTER_PRESSURE
	if not _bool(progress, "has_chosen_route"):
		return STAGE_CHOOSE_ROUTE
	return STAGE_DONE


func _stage_definition(stage: String) -> Dictionary:
	match stage:
		STAGE_SELECT_DISTRICT:
			return {
				"phase_label": "点区",
				"title": "先点一个区域",
				"body": "点中央星球的一块地。",
				"tooltip": "选区后，右侧只给下一步和关键条件。",
			}
		STAGE_FIRST_SUMMON:
			return {
				"phase_label": "首召",
				"title": "在选区首召怪兽",
				"body": "打一张起始怪兽牌。",
				"tooltip": "首召后，怪兽所在区和邻区可买牌。",
			}
		STAGE_BUILD_CITY:
			return {
				"phase_label": "发展牌",
				"title": "打开发展牌架",
				"body": "购买并打出绑定商品项目的发展牌。",
				"tooltip": "v0.4 不允许直接建城；城市表面由合法商品项目结算创建。",
			}
		STAGE_OPEN_RACK:
			return {
				"phase_label": "牌架",
				"title": "打开区域牌架",
				"body": "双击区域，看它卖什么牌。",
				"tooltip": "能不能买在打开窗口时锁定；不能买也能看。",
			}
		STAGE_BUY_CARD:
			return {
				"phase_label": "买牌",
				"title": "买一张能理解的牌",
				"body": "买一张现在能用的牌。",
				"tooltip": "重复牌会升级；满手时私密弃一张。",
			}
		STAGE_PLAY_CARD:
			return {
				"phase_label": "出牌",
				"title": "打出一张手牌",
				"body": "打一张可用手牌。",
				"tooltip": "牌会公开进牌轨，牌主留给全桌推理。",
			}
		STAGE_INSPECT_TRACK:
			return {
				"phase_label": "牌轨",
				"title": "看顶部公开牌轨",
				"body": "看这张牌留下什么线索。",
				"tooltip": "牌轨是公共时间线：牌、事件、天气、赌局。",
			}
		STAGE_CHECK_ECONOMY:
			return {
				"phase_label": "经济",
				"title": "看经济总览",
				"body": "看钱从哪里来。",
				"tooltip": "经济总览把GDP、商品、商路和城市收入拆成可读线索。",
			}
		STAGE_OBSERVE_AI_PUBLIC_ACTION:
			return {
				"phase_label": "AI暗流",
				"title": "观察一次AI公开行动",
				"body": "只读目标、结果和线索。",
				"tooltip": "真实操作者、策略评分和AI私有计划不会显示。",
			}
		STAGE_INSPECT_CLUES:
			return {
				"phase_label": "线索",
				"title": "打开线索档案",
				"body": "把公开线索整理成嫌疑。",
				"tooltip": "只显示公开事实和你的推理，不露私密手牌。",
			}
		STAGE_INSPECT_MONSTER_PRESSURE:
			return {
				"phase_label": "怪兽",
				"title": "查看怪兽压力",
				"body": "看移动、目标与受压路线。",
				"tooltip": "怪兽的地图结果公开；真实归属仍需从公开线索判断。",
			}
		STAGE_CHOOSE_ROUTE:
			return {
				"phase_label": "路线",
				"title": "选一条路线继续",
				"body": "首局推荐先扩GDP。",
				"tooltip": "路线只给接下来几分钟的方向：扩GDP、护商路、压竞争。",
			}
		_:
			return {
				"phase_label": "完成",
				"title": "首轮路径完成",
				"body": "钱、牌、路线已跑通。",
				"tooltip": "继续围绕现金流、怪兽压力和公开线索决策。",
			}


func _default_primary_action(stage: String) -> Dictionary:
	match stage:
		STAGE_SELECT_DISTRICT:
			return {"id": "coach_select_district", "label": "点选区域", "tooltip": "把焦点放到一个区域。"}
		STAGE_FIRST_SUMMON:
			return {"id": "coach_first_summon", "label": "在选区首召", "tooltip": "打出起始怪兽。"}
		STAGE_BUILD_CITY:
			return {"id": "coach_open_rack", "label": "打开发展牌架", "tooltip": "直建已停用；从真实发展牌进入城市项目。"}
		STAGE_OPEN_RACK:
			return {"id": "coach_open_rack", "label": "查看牌架", "tooltip": "打开当前区域牌架。"}
		STAGE_BUY_CARD:
			return {"id": "coach_buy_card", "label": "买第一牌", "tooltip": "从牌架买一张牌。"}
		STAGE_PLAY_CARD:
			return {"id": "coach_play_card", "label": "打出手牌", "tooltip": "打出当前可用手牌。"}
		STAGE_INSPECT_TRACK:
			return {"id": "coach_inspect_track", "label": "看牌轨", "tooltip": "聚焦顶部公开牌轨。"}
		STAGE_CHECK_ECONOMY:
			return {"id": "coach_check_economy", "label": "看经济", "tooltip": "打开经济总览。"}
		STAGE_OBSERVE_AI_PUBLIC_ACTION:
			return {"id": "coach_observe_ai_public_action", "label": "观察AI行动", "tooltip": "读取公开目标和结果。"}
		STAGE_INSPECT_CLUES:
			return {"id": "coach_inspect_clues", "label": "看线索", "tooltip": "打开线索档案。"}
		STAGE_INSPECT_MONSTER_PRESSURE:
			return {"id": "coach_inspect_monster_pressure", "label": "看怪兽压力", "tooltip": "聚焦地图怪兽层。"}
		STAGE_CHOOSE_ROUTE:
			return {"id": "coach_choose_route_growth", "label": "走扩GDP", "tooltip": "先围绕城市收入、商品和商路继续玩。"}
		_:
			return {"id": "", "label": "已完成", "disabled": true, "tooltip": "首局引导已折叠。"}


func _focus_target_for_stage(stage: String) -> String:
	match stage:
		STAGE_SELECT_DISTRICT:
			return "planet"
		STAGE_FIRST_SUMMON:
			return "player_hand"
		STAGE_BUILD_CITY:
			return "action_dock"
		STAGE_OPEN_RACK:
			return "planet"
		STAGE_BUY_CARD:
			return "district_supply"
		STAGE_PLAY_CARD:
			return "player_hand"
		STAGE_INSPECT_TRACK:
			return "public_track"
		STAGE_CHECK_ECONOMY:
			return "economy_overview"
		STAGE_OBSERVE_AI_PUBLIC_ACTION:
			return "public_track"
		STAGE_INSPECT_CLUES:
			return "right_inspector"
		STAGE_INSPECT_MONSTER_PRESSURE:
			return "planet"
		STAGE_CHOOSE_ROUTE:
			return "action_dock"
		_:
			return ""


func _shortest_action_for_stage(stage: String) -> String:
	match stage:
		STAGE_SELECT_DISTRICT:
			return "按确认选区。"
		STAGE_FIRST_SUMMON:
			return "看手牌，首召怪兽。"
		STAGE_BUILD_CITY:
			return "打开发展牌架，购买并打出项目牌。"
		STAGE_OPEN_RACK:
			return "打开当前区域牌架。"
		STAGE_BUY_CARD:
			return "买一张可购买牌。"
		STAGE_PLAY_CARD:
			return "打出一张可用手牌。"
		STAGE_INSPECT_TRACK:
			return "看顶部牌轨。"
		STAGE_CHECK_ECONOMY:
			return "看经济总览。"
		STAGE_OBSERVE_AI_PUBLIC_ACTION:
			return "看公开结果。"
		STAGE_INSPECT_CLUES:
			return "打开线索档案。"
		STAGE_INSPECT_MONSTER_PRESSURE:
			return "看怪兽轨迹和目标。"
		STAGE_CHOOSE_ROUTE:
			return "走扩GDP路线。"
	return "继续下一步。"


func _normalize_action(action: Dictionary, stage: String) -> Dictionary:
	var fallback := _default_primary_action(stage)
	var action_id := str(action.get("id", fallback.get("id", ""))).strip_edges()
	var label := str(action.get("label", action.get("text", fallback.get("label", "下一步")))).strip_edges()
	if label == "":
		label = str(fallback.get("label", "下一步"))
	return {
		"id": action_id,
		"label": label,
		"tooltip": str(action.get("tooltip", action.get("detail", fallback.get("tooltip", "")))),
		"disabled": bool(action.get("disabled", action_id == "")),
		"accent": action.get("accent", _stage_accent(stage)),
	}


func _normalized_chips(value: Variant) -> Array:
	var source: Array = value if value is Array else []
	var normalized: Array = []
	for chip_variant in source:
		if chip_variant is Dictionary:
			var chip: Dictionary = chip_variant
			var text := str(chip.get("text", chip.get("label", ""))).strip_edges()
			if text != "":
				normalized.append({
					"text": text,
					"tooltip": str(chip.get("tooltip", chip.get("tip", ""))),
					"accent": chip.get("accent", Color("#cbd5e1")),
				})
		else:
			var chip_text := str(chip_variant).strip_edges()
			if chip_text != "":
				normalized.append({"text": chip_text, "tooltip": "", "accent": Color("#cbd5e1")})
	return normalized


func _stage_chips(_progress: Dictionary, stage: String) -> Array:
	if stage == STAGE_CHOOSE_ROUTE:
		return [
			{"text": "扩GDP", "tooltip": "强化城市收入、商品供需和商路。", "accent": Color("#4ade80")},
			{"text": "护商路", "tooltip": "保护高收入城市，修复路线。", "accent": Color("#38bdf8")},
			{"text": "压竞争", "tooltip": "读公开线索，攻击竞争城市。", "accent": Color("#fb7185")},
		]
	return [
		{"text": _stage_definition(stage).get("phase_label", "首局"), "accent": _stage_accent(stage)},
		{"text": _stage_focus_chip_text(stage), "tooltip": "下一眼先看这块桌面区域。", "accent": Color("#bfdbfe")},
		{"text": _stage_result_chip_text(stage), "tooltip": "完成这步后，牌局会发生的最直接变化。", "accent": Color("#bbf7d0")},
	]


func _stage_focus_chip_text(stage: String) -> String:
	match stage:
		STAGE_SELECT_DISTRICT:
			return "看星球"
		STAGE_FIRST_SUMMON:
			return "看手牌"
		STAGE_BUILD_CITY:
			return "看行动"
		STAGE_OPEN_RACK:
			return "双击区"
		STAGE_BUY_CARD:
			return "看牌架"
		STAGE_PLAY_CARD:
			return "看手牌"
		STAGE_INSPECT_TRACK:
			return "看牌轨"
		STAGE_CHECK_ECONOMY:
			return "看经济"
		STAGE_OBSERVE_AI_PUBLIC_ACTION:
			return "看公开"
		STAGE_INSPECT_CLUES:
			return "看右侧"
		STAGE_INSPECT_MONSTER_PRESSURE:
			return "看怪兽"
		STAGE_CHOOSE_ROUTE:
			return "看路线"
		_:
			return "继续玩"


func _stage_result_chip_text(stage: String) -> String:
	match stage:
		STAGE_SELECT_DISTRICT:
			return "选定区"
		STAGE_FIRST_SUMMON:
			return "怪兽落地"
		STAGE_BUILD_CITY:
			return "现金流"
		STAGE_OPEN_RACK:
			return "只查看"
		STAGE_BUY_CARD:
			return "入手牌"
		STAGE_PLAY_CARD:
			return "进牌轨"
		STAGE_INSPECT_TRACK:
			return "找线索"
		STAGE_CHECK_ECONOMY:
			return "懂钱源"
		STAGE_OBSERVE_AI_PUBLIC_ACTION:
			return "读结果"
		STAGE_INSPECT_CLUES:
			return "猜归属"
		STAGE_INSPECT_MONSTER_PRESSURE:
			return "读压力"
		STAGE_CHOOSE_ROUTE:
			return "定方向"
		_:
			return "自由决策"


func _step_summaries(progress: Dictionary, stage: String) -> Array:
	var steps: Array = []
	for step_variant in STEP_ORDER:
		var step := str(step_variant)
		steps.append({
			"id": step,
			"label": str(_stage_definition(step).get("phase_label", step)),
			"done": _stage_done(progress, step) or stage == STAGE_DONE,
			"current": step == stage,
			"accent": _stage_accent(step),
		})
	return steps


func _stage_done(progress: Dictionary, stage: String) -> bool:
	match stage:
		STAGE_SELECT_DISTRICT:
			return _bool(progress, "selected_district")
		STAGE_FIRST_SUMMON:
			return _bool(progress, "has_monster")
		STAGE_BUILD_CITY:
			return _bool(progress, "has_city")
		STAGE_OPEN_RACK:
			return _bool(progress, "has_opened_supply")
		STAGE_BUY_CARD:
			return _bool(progress, "has_bought_card")
		STAGE_PLAY_CARD:
			return _bool(progress, "has_played_card")
		STAGE_INSPECT_TRACK:
			return _bool(progress, "has_seen_public_track")
		STAGE_CHECK_ECONOMY:
			return _bool(progress, "has_checked_economy")
		STAGE_OBSERVE_AI_PUBLIC_ACTION:
			return _bool(progress, "has_seen_ai_public_action")
		STAGE_INSPECT_CLUES:
			return _bool(progress, "has_seen_clues")
		STAGE_INSPECT_MONSTER_PRESSURE:
			return _bool(progress, "has_seen_monster_pressure")
		STAGE_CHOOSE_ROUTE:
			return _bool(progress, "has_chosen_route")
	return false


func _completed_count(progress: Dictionary) -> int:
	var count := 0
	for step_variant in STEP_ORDER:
		if _stage_done(progress, str(step_variant)):
			count += 1
	return count


func _progress_text(progress: Dictionary, stage: String) -> String:
	if stage == STAGE_DONE:
		return "已完成"
	return "%d/%d｜%s" % [_completed_count(progress), STEP_ORDER.size(), str(_stage_definition(stage).get("phase_label", "下一步"))]


func _recommended_setup(value: Variant) -> Dictionary:
	var source: Dictionary = value if value is Dictionary else {}
	return {
		"player_count": int(source.get("player_count", 4)),
		"ai_count": int(source.get("ai_count", 3)),
		"role_indices": (source.get("role_indices", [0, 1, 2, 3]) as Array).duplicate(true) if source.get("role_indices", []) is Array else [0, 1, 2, 3],
		"starter_monster_indices": (source.get("starter_monster_indices", [7, 6, 2, 4]) as Array).duplicate(true) if source.get("starter_monster_indices", []) is Array else [7, 6, 2, 4],
		"label": str(source.get("label", "推荐首局：4席 / 3 AI")),
	}


func _stage_accent(stage: String) -> Color:
	match stage:
		STAGE_SELECT_DISTRICT:
			return Color("#38bdf8")
		STAGE_FIRST_SUMMON:
			return Color("#fb7185")
		STAGE_BUILD_CITY:
			return Color("#4ade80")
		STAGE_OPEN_RACK:
			return Color("#facc15")
		STAGE_BUY_CARD:
			return Color("#fde68a")
		STAGE_PLAY_CARD:
			return Color("#c084fc")
		STAGE_INSPECT_TRACK:
			return Color("#f59e0b")
		STAGE_CHECK_ECONOMY:
			return Color("#38bdf8")
		STAGE_OBSERVE_AI_PUBLIC_ACTION:
			return Color("#f59e0b")
		STAGE_INSPECT_CLUES:
			return Color("#93c5fd")
		STAGE_INSPECT_MONSTER_PRESSURE:
			return Color("#fb7185")
		STAGE_CHOOSE_ROUTE:
			return Color("#22c55e")
	return Color("#22c55e")


func _bool(source: Dictionary, key: String) -> bool:
	return bool(source.get(key, false))
