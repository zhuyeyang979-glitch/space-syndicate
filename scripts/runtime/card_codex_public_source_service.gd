@tool
extends Node
class_name CardCodexPublicSourceService

const SOURCE_ADAPTER_SCRIPT := preload("res://scripts/runtime/card_codex_public_source_adapter.gd")
const DEPENDENCY_KEYS := [
	"catalog",
	"presentation",
	"eligibility",
	"diagnostics",
	"snapshot",
	"runtime_balance_model",
]

var _catalog: CardRuntimeCatalogService
var _presentation: CardPresentationRuntimeService
var _eligibility: CardPlayEligibilityRuntimeService
var _diagnostics: GameplayBalanceDiagnosticsRuntimeService
var _snapshot: CardCodexPublicSnapshotService
var _runtime_balance_model: RefCounted
var _adapter: RefCounted = SOURCE_ADAPTER_SCRIPT.new()
var _configured := false
var _last_error := "dependencies_not_configured"


func configure(dependencies: Dictionary) -> Dictionary:
	_clear_dependencies()
	for key_variant: Variant in dependencies:
		if not DEPENDENCY_KEYS.has(str(key_variant)):
			_last_error = "unexpected_dependency:%s" % str(key_variant)
			return debug_snapshot()
	_catalog = dependencies.get("catalog") as CardRuntimeCatalogService
	_presentation = dependencies.get("presentation") as CardPresentationRuntimeService
	_eligibility = dependencies.get("eligibility") as CardPlayEligibilityRuntimeService
	_diagnostics = dependencies.get("diagnostics") as GameplayBalanceDiagnosticsRuntimeService
	_snapshot = dependencies.get("snapshot") as CardCodexPublicSnapshotService
	_runtime_balance_model = dependencies.get("runtime_balance_model") as RefCounted
	var missing: Array[String] = []
	if _catalog == null: missing.append("catalog")
	if _presentation == null: missing.append("presentation")
	if _eligibility == null: missing.append("eligibility")
	if _diagnostics == null: missing.append("diagnostics")
	if _snapshot == null: missing.append("snapshot")
	if _runtime_balance_model == null or not _runtime_balance_model.has_method("card_price_for_skill"): missing.append("runtime_balance_model")
	if not missing.is_empty():
		_clear_dependencies()
		_last_error = "missing_or_invalid_dependencies:%s" % ",".join(missing)
		return debug_snapshot()
	_configured = true
	_last_error = ""
	return debug_snapshot()


func compose_browser_source(request: Dictionary) -> Dictionary:
	if not _require_ready() or not _accepts_public_input(request):
		return {}
	var names := _string_array(request.get("names", []))
	var cards: Array = []
	for card_index in range(names.size()):
		var facts := compose_card_facts(str(names[card_index]), card_index)
		if bool(facts.get("valid", false)):
			cards.append(facts)
	var preview_name := str(request.get("selected_card", ""))
	if preview_name == "" or not names.has(preview_name):
		preview_name = str(names[0]) if not names.is_empty() else ""
	var preview_facts := compose_card_facts(preview_name, names.find(preview_name)) if preview_name != "" else {}
	var source_request := request.duplicate(true)
	source_request["names"] = names
	source_request["selected_card"] = preview_name
	source_request["columns"] = clampi(int(request.get("columns", 3)), 1, 6)
	source_request["rows"] = maxi(1, int(request.get("rows", 1)))
	source_request["page_index"] = maxi(0, int(request.get("page_index", 0)))
	source_request["filter_id"] = str(request.get("filter_id", "all"))
	source_request["filter_label"] = str(request.get("filter_label", _filter_label(str(source_request["filter_id"]))))
	source_request["icon_legend"] = str(request.get("icon_legend", _presentation.icon_legend_text()))
	source_request["run_pool_count"] = maxi(0, int(request.get("run_pool_count", 0)))
	source_request["district_supply_count"] = maxi(0, int(request.get("district_supply_count", 0)))
	var value: Variant = _adapter.call("compose_browser_source", source_request, cards, preview_facts, _public_filters(request.get("filters", [])))
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func compose_browser(request: Dictionary) -> Dictionary:
	var source := compose_browser_source(request)
	return _snapshot.compose_browser(source) if not source.is_empty() else {}


func compose_card_facts(card_name: String, card_index: int = -1) -> Dictionary:
	return _compose_card_facts(card_name, card_index, true)


func compose_upgrades(card_name: String) -> Array:
	if not _require_ready():
		return []
	var upgrades: Array = []
	var family := _catalog.family_id(card_name)
	for level in range(1, 5):
		var level_name := "%s%d" % [family, level]
		if not _catalog.has_card(level_name):
			continue
		var facts := _compose_card_facts(level_name, level - 1, false)
		var preview := _join_facts(facts.get("key_rule_facts", []) as Array, 4)
		if preview == "":
			preview = str(facts.get("full_effect_text", ""))
		var points := _diagnostics.card_budget_points(_catalog.definition(level_name))
		var accent: Color = facts.get("accent", Color("#94a3b8")) as Color
		upgrades.append({
			"roman": _roman_rank(level),
			"price": _rank_one_price(level_name),
			"strength_band": _diagnostics.card_budget_band_text(points),
			"preview": preview,
			"display_name": _display_name(level_name),
			"full_effect_text": str(facts.get("full_effect_text", "")),
			"accent": accent.lerp(Color("#fef3c7"), 0.08 * float(level - 1)),
			"fill_weight": 0.10 + 0.03 * float(level - 1),
		})
	return upgrades


func compose_detail(card_name: String, index: int, total: int) -> Dictionary:
	if not _require_ready():
		return {}
	var facts := compose_card_facts(card_name, index)
	if not bool(facts.get("valid", false)):
		return {}
	var value: Variant = _adapter.call("compose_detail_source", facts, compose_upgrades(card_name), total)
	var source := (value as Dictionary).duplicate(true) if value is Dictionary else {}
	return _snapshot.compose_detail(source) if not source.is_empty() else {}


func public_field_schema() -> Dictionary:
	var value: Variant = _adapter.call("public_field_schema")
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func debug_snapshot() -> Dictionary:
	var adapter_debug: Dictionary = _adapter.call("debug_snapshot") as Dictionary
	return {
		"service_ready": _configured,
		"service_authoritative": _configured,
		"last_error": _last_error,
		"dependency_allowlist": DEPENDENCY_KEYS.duplicate(),
		"dependency_count": DEPENDENCY_KEYS.size() if _configured else 0,
		"owns_public_source_assembly": true,
		"owns_rules": false,
		"owns_save_state": false,
		"has_save_api": false,
		"reads_world_bridge": false,
		"reads_private_world": false,
		"reads_player_state": false,
		"uses_snapshot_service_for_viewmodels": _snapshot != null,
		"uses_runtime_balance_rank_one_price": _runtime_balance_model != null,
		"adapter": adapter_debug.duplicate(true),
	}


func _compose_card_facts(card_name: String, card_index: int, include_gradient: bool) -> Dictionary:
	if not _require_ready():
		return {}
	var skill := _catalog.definition(card_name)
	if card_name == "" or skill.is_empty():
		return {"valid": false, "card_name": card_name, "index": card_index}
	var requirement := _eligibility.requirement_status({"skill": skill}, {})
	var target := _eligibility.target_status({"skill": skill}, {"player_count": 2, "monster_count": 1})
	var price := _rank_one_price(card_name)
	var presentation := _presentation.compose_card({
		"card_name": card_name,
		"skill": skill,
		"display_name": _display_name(card_name),
		"display_text": str(skill.get("text", "")),
		"tag_text": _tag_text(skill),
		"rank": maxi(1, _catalog.rank(card_name)),
		"price": price,
		"play_requirement_text": str(requirement.get("requirement_text", "条件：无")),
		"required_share_percent": int(requirement.get("required_share_percent", 0)),
		"play_cash_cost": int(requirement.get("cash_cost", 0)),
		"targets_monster": bool(target.get("targets_monster", false)),
		"targets_player": bool(target.get("targets_player", false)),
		"requires_target_monster": bool(target.get("requires_target_monster", false)),
		"requires_target_player": bool(target.get("requires_target_player", false)),
		"is_monster_card": str(skill.get("kind", "")) == "monster_card",
		"is_direct_monster_skill": bool(target.get("targets_monster", false)) and not ["monster_lure", "special_monster_delay", "mudslide", "monster_takeover", "military_command"].has(str(skill.get("kind", ""))),
	})
	if presentation.is_empty():
		return {}
	var read_chips: Array = []
	for entry_variant: Variant in presentation.get("chips", []):
		if not (entry_variant is Dictionary):
			continue
		var entry := entry_variant as Dictionary
		var accent: Color = entry.get("fg", Color("#e2e8f0")) as Color
		read_chips.append({"text": str(entry.get("text", "")), "tooltip": str(entry.get("tip", "")), "fg": accent, "bg": entry.get("bg", Color("#020617")), "accent": accent})
	var resolution := _presentation.compose_resolution({
		"card": presentation.merged({"skill": skill}, true),
		"skill": skill,
		"resolved": true,
		"animation_facts": {
			"family": _catalog.family_id(card_name),
			"monster_name": str(skill.get("monster_name", "")),
			"monster_move_text": "%.0fm" % float(skill.get("move", 0.0)),
			"monster_duration_text": _duration_text(float(skill.get("duration", -1.0))),
			"military_hp": int(skill.get("military_hp", 0)),
			"military_damage": int(skill.get("military_damage", 0)),
			"military_range": float(skill.get("range", 0.0)),
		},
	})
	var source := {
		"valid": true,
		"index": card_index,
		"card_name": card_name,
		"display_name": str(presentation.get("display_name", _display_name(card_name))),
		"icon": str(presentation.get("icon", "□")),
		"family": _catalog.family_id(card_name),
		"kind": str(skill.get("kind", "")),
		"rank": maxi(1, _catalog.rank(card_name)),
		"rank_label": str(presentation.get("rank_label", _roman_rank(_catalog.rank(card_name)))),
		"tag_text": _tag_text(skill),
		"accent": presentation.get("accent", Color("#94a3b8")),
		"price": price,
		"category_label": _filter_label(str(presentation.get("category_id", "other"))),
		"icon_route_label": str(presentation.get("icon_route_label", "□ 即时战术")),
		"subtype_label": str(presentation.get("subtype_label", "即时战术")),
		"source_type_label": _source_type_label(skill),
		"supply_layer": "公开牌池" if _catalog.public_pool().has(card_name) else "完整资料库",
		"art_stats": str(presentation.get("art_stats", "")),
		"use_case": str(presentation.get("use_case", "")),
		"strategy_route_label": str(presentation.get("strategy_route_label", "即时战术")),
		"strategy_summary": str(presentation.get("strategy_summary", "")),
		"strategy_use_text": str(presentation.get("strategy_use_text", "")),
		"quick_effect_compact": str(presentation.get("quick_effect_compact", "")),
		"quick_effect_full": str(presentation.get("quick_effect_full", "")),
		"full_effect_text": str(skill.get("text", "")),
		"rules_text_compact": str(presentation.get("rules_text_compact", "")),
		"level_gradient_text": _level_gradient_text(card_name) if include_gradient else "",
		"detail_tooltip": str(presentation.get("detail_tooltip", "")),
		"face_route_text": str(presentation.get("face_route_full", "")),
		"type_label": str(presentation.get("icon_type_label", "□ 卡牌")),
		"requires_target_monster": bool(target.get("requires_target_monster", false)),
		"targets_player": bool(target.get("targets_player", false)),
		"targets_monster": bool(target.get("targets_monster", false)),
		"play_region_share_required": int(requirement.get("required_share_percent", 0)),
		"play_region_scope_label": str(requirement.get("scope_label", "任一经营区")),
		"route_damage": int(skill.get("route_damage", 0)),
		"persistent": bool(skill.get("persistent", false)),
		"play_requirement_text": str(requirement.get("requirement_text", "条件：无")),
		"key_rule_facts": (presentation.get("key_rule_facts", []) as Array).duplicate(true),
		"read_chips": read_chips,
		"resolution_animation_text": str(resolution.get("animation_catalog_text", "")).replace("\n", " / "),
	}
	var value: Variant = _adapter.call("compose_card_facts", source)
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _public_filters(value: Variant) -> Array:
	var result: Array = []
	if not (value is Array): return result
	for entry_variant: Variant in value:
		if not (entry_variant is Dictionary): continue
		var entry := entry_variant as Dictionary
		var filter_id := str(entry.get("id", "all"))
		result.append({"id": filter_id, "label": str(entry.get("label", _filter_label(filter_id))), "short_label": str(entry.get("short_label", _short_filter_label(filter_id))), "icon": _presentation.category_icon(filter_id), "count": maxi(0, int(entry.get("count", 0))), "accent": entry.get("accent", Color("#93c5fd"))})
	return result


func _filter_label(filter_id: String) -> String:
	if filter_id.begins_with("route:"):
		return "路线:%s" % _diagnostics.route_label(filter_id.trim_prefix("route:"))
	return str({"all":"全部牌", "monster":"怪兽牌", "monster_skill":"怪兽技能", "military":"军队/军令", "interaction":"玩家互动", "city":"城市经营", "commodity":"商品经营", "futures":"商品期货", "finance":"金融/GDP", "contract":"合约", "intel":"情报推理", "supply":"补给/采购", "tactic":"怪兽诱导", "news":"新闻事件", "weather":"天气干预", "other":"其他", "economy":"经济聚合", "business":"经营/合约", "combat":"战斗/指令"}.get(filter_id, "全部牌"))


func _short_filter_label(filter_id: String) -> String:
	return str({"all":"全部", "monster":"怪兽", "monster_skill":"兽技", "military":"军队", "interaction":"互动", "city":"城市", "commodity":"商品", "futures":"期货", "finance":"金融", "contract":"合约", "intel":"情报", "supply":"补给", "tactic":"诱导", "news":"新闻", "weather":"天气", "other":"其他"}.get(filter_id, _filter_label(filter_id)))


func _display_name(card_name: String) -> String:
	return "%s %s级" % [_catalog.family_id(card_name), _roman_rank(maxi(1, _catalog.rank(card_name)))] if card_name != "" else ""


func _tag_text(skill: Dictionary) -> String:
	var labels: Array[String] = []
	for tag_variant: Variant in skill.get("tags", []) as Array:
		var tag := str(tag_variant)
		if tag != "": labels.append(tag)
	return " / ".join(labels)


func _source_type_label(skill: Dictionary) -> String:
	match str(skill.get("kind", "")):
		"monster_card": return "怪兽牌"
		"monster_bound_action": return "怪兽固定技能"
	return "固定技能" if bool(skill.get("persistent", false)) else "公共卡牌"


func _rank_one_price(card_name: String) -> int:
	var price_card_name := "%s1" % _catalog.family_id(card_name)
	if not _catalog.has_card(price_card_name): price_card_name = card_name
	var price_skill := _catalog.definition(price_card_name)
	return int(_runtime_balance_model.call("card_price_for_skill", price_skill)) if not price_skill.is_empty() else 0


func _level_gradient_text(card_name: String) -> String:
	var lines: Array[String] = []
	for entry_variant: Variant in compose_upgrades(card_name):
		if entry_variant is Dictionary:
			var entry := entry_variant as Dictionary
			lines.append("%s  ¥%d  %s｜%s" % [str(entry.get("roman", "")), int(entry.get("price", 0)), str(entry.get("strength_band", "")), str(entry.get("preview", ""))])
	return "\n".join(lines) if not lines.is_empty() else "该卡暂无I→IV强化。"


func _join_facts(facts: Array, max_count: int) -> String:
	var pieces: Array[String] = []
	for index in range(mini(maxi(0, max_count), facts.size())):
		var fact := str(facts[index])
		if fact != "": pieces.append(fact)
	return "｜".join(pieces)


func _roman_rank(rank: int) -> String:
	return str({1:"I", 2:"II", 3:"III", 4:"IV"}.get(clampi(rank, 1, 4), "I"))


func _duration_text(seconds: float) -> String:
	return "常驻" if seconds < 0.0 else "%.0fs" % seconds


func _string_array(value: Variant) -> Array:
	var result: Array = []
	if not (value is Array): return result
	for entry_variant: Variant in value:
		var entry := str(entry_variant)
		if entry != "": result.append(entry)
	return result


func _accepts_public_input(value: Variant) -> bool:
	return bool(_adapter.call("accepts_public_input", value))


func _require_ready() -> bool:
	if _configured: return true
	_last_error = "dependencies_not_configured"
	return false


func _clear_dependencies() -> void:
	_catalog = null
	_presentation = null
	_eligibility = null
	_diagnostics = null
	_snapshot = null
	_runtime_balance_model = null
	_configured = false
