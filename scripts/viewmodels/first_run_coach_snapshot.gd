extends RefCounted
class_name FirstRunCoachSnapshot

const STAGE_SELECT_DISTRICT := "select_district"
const STAGE_FIRST_SUMMON := "first_summon"
const STAGE_BUILD_CITY := "build_city"
const STAGE_OPEN_RACK := "open_rack"
const STAGE_BUY_CARD := "buy_card"
const STAGE_PLAY_CARD := "play_card"
const STAGE_INSPECT_TRACK := "inspect_track"
const STAGE_INSPECT_CLUES := "inspect_clues"
const STAGE_DONE := "done"

const STEP_ORDER := [
	STAGE_SELECT_DISTRICT,
	STAGE_FIRST_SUMMON,
	STAGE_BUILD_CITY,
	STAGE_OPEN_RACK,
	STAGE_BUY_CARD,
	STAGE_PLAY_CARD,
	STAGE_INSPECT_TRACK,
	STAGE_INSPECT_CLUES,
]

var ui: Dictionary = {}


func apply_dictionary(data: Dictionary) -> RefCounted:
	var source := data.duplicate(true)
	var progress: Dictionary = source.get("progress", {}) if source.get("progress", {}) is Dictionary else {}
	var visible := bool(source.get("visible", not source.is_empty()))
	var dismissed := bool(source.get("dismissed", false))
	var stage := str(source.get("stage", "")).strip_edges()
	if stage == "":
		stage = _stage_from_progress(progress, bool(source.get("auto_fold_when_track_seen", true)))
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
		"progress_text": _progress_text(progress, stage),
		"chips": _normalized_chips(source.get("chips", _stage_chips(progress, stage))),
		"primary_action": _normalize_action(primary_action, stage),
		"recommended_setup": _recommended_setup(source.get("recommended_setup", {})),
		"steps": _step_summaries(progress, stage),
	}
	return self


func to_ui_dictionary() -> Dictionary:
	return ui.duplicate(true)


func _stage_from_progress(progress: Dictionary, auto_fold_when_track_seen: bool) -> String:
	if _bool(progress, "completed"):
		return STAGE_DONE
	if auto_fold_when_track_seen and _bool(progress, "has_played_card") and _bool(progress, "has_seen_public_track"):
		return STAGE_DONE
	if not _bool(progress, "selected_district"):
		return STAGE_SELECT_DISTRICT
	if not _bool(progress, "has_monster"):
		return STAGE_FIRST_SUMMON
	if not _bool(progress, "has_city"):
		return STAGE_BUILD_CITY
	if not _bool(progress, "has_opened_supply"):
		return STAGE_OPEN_RACK
	if not _bool(progress, "has_bought_card"):
		return STAGE_BUY_CARD
	if not _bool(progress, "has_played_card"):
		return STAGE_PLAY_CARD
	if not _bool(progress, "has_seen_public_track"):
		return STAGE_INSPECT_TRACK
	if not _bool(progress, "has_seen_clues"):
		return STAGE_INSPECT_CLUES
	return STAGE_DONE


func _stage_definition(stage: String) -> Dictionary:
	match stage:
		STAGE_SELECT_DISTRICT:
			return {
				"phase_label": "点区",
				"title": "先点一个区域",
				"body": "从中央星球选一块地，右侧会说明这里能不能建城、看牌架。",
				"tooltip": "首局只需要先选地。区域详情、商品和限制放在右侧说明，不堆在主桌。",
			}
		STAGE_FIRST_SUMMON:
			return {
				"phase_label": "首召",
				"title": "在选区首召怪兽",
				"body": "打出起始怪兽，附近区域才会成为第一批买牌地点。",
				"tooltip": "起始怪兽不暴露归属；首召后，怪兽所在区和邻区会开放购牌机会。",
			}
		STAGE_BUILD_CITY:
			return {
				"phase_label": "建城",
				"title": "建第一座城市",
				"body": "城市会带来实时现金流，也是你要保护的核心资产。",
				"tooltip": "首局先建立收入点，再考虑扩张、金融、怪兽干扰或情报推理。",
			}
		STAGE_OPEN_RACK:
			return {
				"phase_label": "牌架",
				"title": "打开区域牌架",
				"body": "双击区域或点按钮查看这里提供哪些牌；不能买时也能先看。",
				"tooltip": "买牌资格按打开窗口瞬间检查。一个玩家同时只保留一个区域牌架窗口。",
			}
		STAGE_BUY_CARD:
			return {
				"phase_label": "买牌",
				"title": "买一张能理解的牌",
				"body": "先买经济、建城、怪兽或简单互动牌；重复获得会升级。",
				"tooltip": "普通手牌有上限；超出时会进入私密弃牌选择，不公开手牌数量。",
			}
		STAGE_PLAY_CARD:
			return {
				"phase_label": "出牌",
				"title": "打出一张手牌",
				"body": "出牌会公开进入牌轨，但不会直接公开是谁打的。",
				"tooltip": "需要目标的牌会先询问目标；打出条件和结果会留下推理线索。",
			}
		STAGE_INSPECT_TRACK:
			return {
				"phase_label": "牌轨",
				"title": "看顶部公开牌轨",
				"body": "确认刚才的匿名牌如何展示、排队、结算和留下线索。",
				"tooltip": "公共牌轨是全桌时间线：牌、事件、天气、赌局都会逐步统一到这里。",
			}
		STAGE_INSPECT_CLUES:
			return {
				"phase_label": "线索",
				"title": "打开线索档案",
				"body": "线索档案帮助你猜牌、城市或怪兽背后的玩家。",
				"tooltip": "这里只显示公开事实和你自己的推理，不暴露 AI 内部计划或对手私密手牌。",
			}
		_:
			return {
				"phase_label": "完成",
				"title": "首轮路径完成",
				"body": "你已经完成首召、建城、买牌、出牌并看过公开牌轨。",
				"tooltip": "继续围绕 GDP、怪兽压力、商品路线和匿名线索做决策。",
			}


func _default_primary_action(stage: String) -> Dictionary:
	match stage:
		STAGE_SELECT_DISTRICT:
			return {"id": "coach_select_district", "label": "点选区域", "tooltip": "把焦点放到一个区域。"}
		STAGE_FIRST_SUMMON:
			return {"id": "coach_first_summon", "label": "在选区首召", "tooltip": "打出起始怪兽。"}
		STAGE_BUILD_CITY:
			return {"id": "coach_build_city", "label": "城市化", "tooltip": "建第一座城市。"}
		STAGE_OPEN_RACK:
			return {"id": "coach_open_rack", "label": "查看牌架", "tooltip": "打开当前区域牌架。"}
		STAGE_BUY_CARD:
			return {"id": "coach_buy_card", "label": "买第一牌", "tooltip": "从牌架买一张牌。"}
		STAGE_PLAY_CARD:
			return {"id": "coach_play_card", "label": "打出手牌", "tooltip": "打出当前可用手牌。"}
		STAGE_INSPECT_TRACK:
			return {"id": "coach_inspect_track", "label": "看牌轨", "tooltip": "聚焦顶部公开牌轨。"}
		STAGE_INSPECT_CLUES:
			return {"id": "coach_inspect_clues", "label": "看线索", "tooltip": "打开线索档案。"}
		_:
			return {"id": "", "label": "已完成", "disabled": true, "tooltip": "首局引导已折叠。"}


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


func _stage_chips(progress: Dictionary, stage: String) -> Array:
	return [
		{"text": _stage_definition(stage).get("phase_label", "首局"), "accent": _stage_accent(stage)},
		{"text": "%d/8" % _completed_count(progress), "tooltip": "首轮核心动作进度。", "accent": Color("#bfdbfe")},
	]


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
		STAGE_INSPECT_CLUES:
			return _bool(progress, "has_seen_clues")
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
	return "%d/8｜%s" % [_completed_count(progress), str(_stage_definition(stage).get("phase_label", "下一步"))]


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
		STAGE_INSPECT_CLUES:
			return Color("#93c5fd")
	return Color("#22c55e")


func _bool(source: Dictionary, key: String) -> bool:
	return bool(source.get(key, false))
