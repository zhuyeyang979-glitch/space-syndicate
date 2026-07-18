@tool
extends Node
class_name MonsterCodexPublicSnapshotService

var _configured := false
var _compose_count := 0


func configure(_config: Dictionary = {}) -> void:
	_configured = true


func compose(source: Dictionary) -> Dictionary:
	_compose_count += 1
	if not bool(source.get("valid", false)):
		return {"summary_text": "", "preview_text": "", "card_preview_text": "怪兽卡：暂无", "detail_tooltip": "", "public_identity_text": "", "browser_entry": {}, "detail": {}}
	var entry: Dictionary = source.get("entry", {}) if source.get("entry", {}) is Dictionary else {}
	var ecology: Dictionary = source.get("ecology", {}) if source.get("ecology", {}) is Dictionary else {}
	var profile: Dictionary = source.get("profile", {}) if source.get("profile", {}) is Dictionary else {}
	var monster_name := str(entry.get("name", "怪兽"))
	var resource_text := _resource_text(entry)
	var ladder_text := _bound_ladder_text(ecology, source.get("level_labels", []) as Array)
	var preview_text := _preview_text(source, entry, resource_text)
	var card_preview_text := _card_preview_text(source.get("monster_card", {}) as Dictionary)
	var detail_tooltip := "%s\n%s\n%s\n操作：悬停/单击预览；双击进入完整怪兽详情。" % [monster_name, preview_text, card_preview_text]
	var accent: Color = source.get("accent", Color("#fb7185")) as Color
	var summary_text := "怪兽详情｜第%d/%d只｜%s\n看下方怪兽档案板：画像、HP/速度、资源偏好、公开行动与固定技能成长。\n偏好:%s｜定位:%s｜怪兽牌在卡牌图鉴。\n正面经济天气：%s。内部权重、随机签与预选目标保持隐藏。" % [
		int(source.get("index", 0)) + 1,
		maxi(1, int(source.get("total", 1))),
		monster_name,
		resource_text,
		_short_text("、".join(ecology.get("role_tags", []) as Array), 36),
		str((ecology.get("economy_boon", {}) as Dictionary).get("label", "暂无")),
	]
	var detail := {
		"title": "%s｜怪兽单位档案" % monster_name,
		"subtitle": str(entry.get("style", "自动怪兽。")),
		"tooltip": detail_tooltip,
		"accent": accent,
		"art": {
			"name": monster_name,
			"style": str(entry.get("style", "自动怪兽。")),
			"hp": int(entry.get("hp", 0)),
			"armor": int(entry.get("armor", 0)),
			"move_text": str(source.get("art_move_text", source.get("move_text", "0m/s"))),
			"profile": profile.duplicate(true),
		},
		"chips": _detail_chips(source, entry, ecology, resource_text),
		"kpis": _detail_kpis(source, entry, ecology, resource_text, ladder_text),
		"action_title": "公开行动板｜类别与效果",
		"action_tooltip": "怪兽仍会自动行动；图鉴不公开内部权重、随机签或预选目标。",
		"actions": _detail_actions(source.get("actions", []) as Array, accent),
	}
	var browser_entry := {
		"catalog_index": int(source.get("index", 0)),
		"selected": bool(source.get("selected", false)),
		"name": monster_name,
		"stats": "HP%d｜%s｜%s" % [int(entry.get("hp", 0)), str(source.get("move_text", "0m/s")), _short_text(resource_text if resource_text != "暂无固定偏好" else "无偏好", 16)],
		"identity": "%s｜%s" % [str(ecology.get("movement_archetype", "通用")), _short_text("、".join(ecology.get("role_tags", []) as Array), 18)],
		"tooltip": detail_tooltip,
		"accent": accent,
		"art": detail.get("art", {}).duplicate(true),
	}
	return {
		"summary_text": summary_text,
		"preview_text": preview_text,
		"card_preview_text": card_preview_text,
		"detail_tooltip": detail_tooltip,
		"public_resource_text": resource_text,
		"bound_ladder_text": ladder_text,
		"public_identity_text": "生态位:%s｜行动定位:%s｜固定技能成长:%s" % [str(ecology.get("movement_archetype", "通用")), "、".join(ecology.get("role_tags", []) as Array), ladder_text],
		"browser_entry": browser_entry,
		"detail": detail,
	}


func debug_snapshot() -> Dictionary:
	return {
		"service_ready": _configured,
		"service_authoritative": _configured,
		"supported_domain": "monster",
		"compose_count": _compose_count,
		"reads_runtime_nodes": false,
		"calculates_action_weights": false,
		"legacy_main_formatter_active": false,
	}


func _resource_text(entry: Dictionary) -> String:
	var resource_focus: Array = entry.get("resource_focus", []) if entry.get("resource_focus", []) is Array else []
	return "、".join(resource_focus) if not resource_focus.is_empty() else "暂无固定偏好"


func _bound_ladder_text(ecology: Dictionary, level_labels: Array) -> String:
	var counts: Array = ecology.get("bound_skill_counts", []) if ecology.get("bound_skill_counts", []) is Array else []
	var pieces := []
	for index in range(mini(4, counts.size())):
		var level_label := str(level_labels[index]) if index < level_labels.size() else str(index + 1)
		pieces.append("%s:%d张" % [level_label, int(counts[index])])
	return " / ".join(pieces) if not pieces.is_empty() else "暂无"


func _preview_text(source: Dictionary, entry: Dictionary, resource_text: String) -> String:
	return "HP:%d｜护甲:%d｜移动:%s｜资源偏好:%s｜公开行动:%s" % [
		int(entry.get("hp", 0)), int(entry.get("armor", 0)), str(source.get("move_text", "0m/s")), resource_text,
		str(source.get("action_summary", "暂无")),
	]


func _card_preview_text(card: Dictionary) -> String:
	if not bool(card.get("valid", false)):
		return "怪兽卡：暂无"
	return "怪兽卡：%s｜¥%d｜%s" % [str(card.get("display_name", "怪兽牌")), int(card.get("price", 0)), str(card.get("region_text", "不限区"))]


func _detail_chips(source: Dictionary, entry: Dictionary, ecology: Dictionary, resource_text: String) -> Array:
	return [
		{"text": "HP%d" % int(entry.get("hp", 0)), "fg": Color("#fecdd3"), "accent": Color("#fecdd3"), "tooltip": "怪兽公开生命值；图鉴不披露召唤者或隐藏归属。"},
		{"text": "甲%d" % int(entry.get("armor", 0)), "fg": Color("#bfdbfe"), "accent": Color("#bfdbfe"), "tooltip": "护甲越高，越不容易被军队或其他怪兽快速清掉。"},
		{"text": "速%s" % str(source.get("move_text", "0m/s")), "fg": Color("#fdba74"), "accent": Color("#fdba74"), "tooltip": "移动按米/秒线性推进；飞行/水栖会影响路径破坏与地形速度。"},
		{"text": str(ecology.get("movement_archetype", "通用")), "fg": Color("#93c5fd"), "accent": Color("#93c5fd"), "tooltip": str(source.get("mobility_summary", "通用移动"))},
		{"text": "偏好:%s" % _short_text(resource_text, 12), "fg": Color("#bbf7d0"), "accent": Color("#bbf7d0"), "tooltip": "偏好商品会影响它被哪些区域吸引。"},
		{"text": "相遇%s" % str(source.get("encounter_range_text", "0m")), "fg": Color("#fca5a5"), "accent": Color("#fca5a5"), "tooltip": "怪兽靠近到相遇范围会触发战斗与怪兽赌局。"},
	]


func _detail_kpis(source: Dictionary, _entry: Dictionary, ecology: Dictionary, resource_text: String, ladder_text: String) -> Array:
	var role_tags := "、".join(ecology.get("role_tags", []) as Array)
	var boon: Dictionary = ecology.get("economy_boon", {}) if ecology.get("economy_boon", {}) is Dictionary else {}
	var economy_text := str(boon.get("label", "暂无经济钩子")) if not boon.is_empty() else "暂无经济钩子"
	return [
		{"title": "生态位", "value": "%s｜%s" % [str(ecology.get("movement_archetype", "通用")), str(source.get("mobility_summary", "通用移动"))], "meta": "召唤:%s｜移动%s" % [str(ecology.get("summon_access", "monster_zone")), str(source.get("ecology_move_text", source.get("move_text", "0m/s")))], "accent": Color("#fb923c")},
		{"title": "资源与经济", "value": _short_text(resource_text, 34), "meta": "吸取%d｜%s" % [int(ecology.get("resource_drain", 0)), economy_text], "accent": Color("#4ade80")},
		{"title": "行动定位", "value": _short_text(role_tags, 34), "meta": "最高伤%d｜射程%s" % [int(ecology.get("max_damage", 0)), str(source.get("max_range_text", "0m"))], "accent": Color("#38bdf8")},
		{"title": "固定技能成长", "value": ladder_text, "meta": "各等级公开绑定技能数量", "accent": Color("#fde047")},
	]


func _detail_actions(action_sources: Array, accent: Color) -> Array:
	var result := []
	for index in range(mini(action_sources.size(), 6)):
		var action: Dictionary = action_sources[index] if action_sources[index] is Dictionary else {}
		var action_accent := accent.lerp(Color("#fde68a"), clampf(float(index) / 7.0, 0.0, 0.45))
		var action_text := str(action.get("text", "自动行动。"))
		var facts := str(action.get("facts", ""))
		result.append({
			"index": "%02d" % (index + 1), "name": str(action.get("name", "行动")), "tags": "、".join(action.get("tags", []) as Array),
			"disclosure": "公开效果｜权重隐藏", "facts": facts, "body": _short_text(action_text, 72),
			"tooltip": "%s\n%s\n%s\n内部权重、随机签与预选目标不公开。" % [str(action.get("name", "行动")), facts, action_text], "accent": action_accent,
		})
	return result


func _short_text(text: String, limit: int) -> String:
	var compact := text.replace("\n", " ").strip_edges()
	return compact if compact.length() <= limit else compact.left(maxi(1, limit - 1)) + "…"
