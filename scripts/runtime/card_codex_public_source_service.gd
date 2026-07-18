@tool
extends Node
class_name CardCodexPublicSourceService

const SOURCE_ADAPTER_SCRIPT := preload("res://scripts/runtime/card_codex_public_source_adapter.gd")
const DEPENDENCY_KEYS := ["snapshot"]
const CATEGORY_LABELS := {
	"commodity": "商品牌",
	"facility": "公共设施",
	"supply_demand": "供需订单",
	"monster": "怪兽单位",
	"military": "军队单位",
	"interaction": "玩家互动",
	"organization": "组织升级",
}
const CATEGORY_ICONS := {
	"commodity": "◇",
	"facility": "▣",
	"supply_demand": "↔",
	"monster": "怪",
	"military": "◆",
	"interaction": "✦",
	"organization": "◎",
}
const INDUSTRY_COLORS := {
	"life": Color("#4ade80"),
	"energy": Color("#facc15"),
	"industry": Color("#94a3b8"),
	"technology": Color("#38bdf8"),
	"commerce": Color("#c084fc"),
	"shipping": Color("#06b6d4"),
	"generic": Color("#fde68a"),
}

@export var public_catalog_v06: CardRuntimeCatalogV06Resource

var _snapshot: CardCodexPublicSnapshotService
var _adapter: RefCounted = SOURCE_ADAPTER_SCRIPT.new()
var _configured := false
var _last_error := "dependencies_not_configured"
var _source_compose_count := 0
var _browser_compose_count := 0
var _detail_compose_count := 0


func configure(dependencies: Dictionary) -> Dictionary:
	_clear_dependencies()
	var keys := dependencies.keys()
	keys.sort()
	var expected := DEPENDENCY_KEYS.duplicate()
	expected.sort()
	if keys != expected:
		_last_error = "dependency_keys_invalid"
		return debug_snapshot()
	_snapshot = dependencies.get("snapshot") as CardCodexPublicSnapshotService
	if _snapshot == null or not _snapshot.has_method("compose_browser") or not _snapshot.has_method("compose_detail"):
		_last_error = "snapshot_service_invalid"
		_clear_dependencies()
		return debug_snapshot()
	if public_catalog_v06 == null:
		_last_error = "v06_public_catalog_missing"
		_clear_dependencies()
		return debug_snapshot()
	var report := public_catalog_v06.validation_report()
	if not bool(report.get("valid", false)) or int(report.get("card_count", 0)) != 348:
		_last_error = "v06_public_catalog_invalid"
		_clear_dependencies()
		return debug_snapshot()
	_configured = true
	_last_error = ""
	return debug_snapshot()


func ordered_card_ids(filter_id: String = "all") -> Array[String]:
	if not _require_ready() or not _valid_filter_id(filter_id):
		return []
	var result: Array[String] = []
	for card_variant: Variant in _catalog_cards():
		if not (card_variant is Dictionary):
			continue
		var machine := _dictionary((card_variant as Dictionary).get("machine", {}))
		if not bool(machine.get("available_for_acquisition", false)):
			continue
		if not _filter_matches(filter_id, str(machine.get("category_id", ""))):
			continue
		var card_id := str(machine.get("card_id", ""))
		if card_id != "":
			result.append(card_id)
	return result


func public_filter_options() -> Array:
	var result: Array = [{"id": "all", "label": "全部", "short_label": "全部", "icon": "□", "accent": Color("#93c5fd")}]
	for category_id in ["commodity", "facility", "supply_demand", "monster", "military", "interaction", "organization"]:
		result.append({
			"id": category_id,
			"label": str(CATEGORY_LABELS.get(category_id, category_id)),
			"short_label": str(CATEGORY_LABELS.get(category_id, category_id)),
			"icon": str(CATEGORY_ICONS.get(category_id, "□")),
			"accent": _category_accent(category_id),
		})
	return result


func resolve_card_id(card_identity: String) -> String:
	if not _require_ready():
		return ""
	var identity := card_identity.strip_edges()
	if identity == "":
		return ""
	if not public_catalog_v06.card_snapshot(identity).is_empty():
		return identity
	var monster_name := ""
	var requested_rank := 0
	if identity.begins_with("怪兽·") and identity.length() > 4:
		var legacy := identity.trim_prefix("怪兽·")
		if legacy.right(1).is_valid_int():
			requested_rank = int(legacy.right(1))
			monster_name = legacy.left(legacy.length() - 1)
	for card_variant: Variant in _catalog_cards():
		if not (card_variant is Dictionary):
			continue
		var card := card_variant as Dictionary
		var machine := _dictionary(card.get("machine", {}))
		var player := _dictionary(card.get("player", {}))
		var card_id := str(machine.get("card_id", ""))
		var rank := int(machine.get("rank", 1))
		var display_name := str(player.get("name", ""))
		var rank_label := str(player.get("rank", _roman_rank(rank)))
		if identity in [display_name, "%s %s" % [display_name, rank_label], "%s%d" % [display_name, rank]]:
			if rank == 1 or identity != display_name:
				return card_id
		if monster_name != "" and str(machine.get("category_id", "")) == "monster" and display_name == monster_name and rank == requested_rank:
			return card_id
	return ""


func compose_browser_source(request: Dictionary) -> Dictionary:
	if not _require_ready() or not bool(_adapter.call("accepts_public_input", request)):
		_last_error = "browser_request_rejected"
		return {}
	var filter_id := str(request.get("filter_id", "all"))
	if not _valid_filter_id(filter_id):
		_last_error = "filter_id_invalid"
		return {}
	var requested_names := _string_array(request.get("names", []))
	var names: Array[String] = ordered_card_ids(filter_id) if requested_names.is_empty() else requested_names
	for card_id in names:
		if resolve_card_id(card_id) != card_id or not _filter_matches(filter_id, str(_machine_for_card(card_id).get("category_id", ""))):
			_last_error = "browser_card_id_invalid"
			return {}
	var cards: Array = []
	for card_index in range(names.size()):
		var facts := compose_card_facts(names[card_index], card_index)
		if not bool(facts.get("valid", false)):
			_last_error = "browser_card_facts_invalid"
			return {}
		cards.append(facts)
	var selected_card := str(request.get("selected_card", ""))
	if selected_card == "" and not names.is_empty():
		selected_card = names[0]
	if selected_card != "" and not names.has(selected_card):
		_last_error = "selected_card_not_in_page"
		return {}
	var preview := compose_card_facts(selected_card, names.find(selected_card)) if selected_card != "" else {}
	var source_request := {
		"names": names,
		"columns": clampi(int(request.get("columns", 3)), 1, 6),
		"rows": maxi(1, int(request.get("rows", 1))),
		"page_index": maxi(0, int(request.get("page_index", 0))),
		"filter_id": filter_id,
		"filter_label": _filter_label(filter_id),
		"selected_card": selected_card,
		"icon_legend": "◇商品免费｜▣设施｜怪兽｜◆军队｜✦互动｜◎组织",
		"run_pool_count": maxi(0, int(request.get("run_pool_count", 0))),
		"district_supply_count": maxi(0, int(request.get("district_supply_count", 0))),
		"filters": _filters_with_counts(request.get("filters", [])),
	}
	var value: Variant = _adapter.call("compose_browser_source", source_request, cards, preview, source_request["filters"])
	var result := (value as Dictionary).duplicate(true) if value is Dictionary else {}
	if not result.is_empty():
		_source_compose_count += 1
		_last_error = ""
	return result


func compose_browser(request: Dictionary) -> Dictionary:
	var source := compose_browser_source(request)
	if source.is_empty():
		return {}
	_browser_compose_count += 1
	return _snapshot.compose_browser(source)


func compose_card_facts(card_identity: String, card_index: int = -1) -> Dictionary:
	if not _require_ready():
		return {}
	var card_id := resolve_card_id(card_identity)
	if card_id == "":
		return {"valid": false, "card_name": card_identity, "index": card_index}
	var card := public_catalog_v06.card_snapshot(card_id)
	var machine := _dictionary(card.get("machine", {}))
	var player := _dictionary(card.get("player", {}))
	if machine.is_empty() or player.is_empty():
		return {"valid": false, "card_name": card_id, "index": card_index}
	var category_id := str(machine.get("category_id", ""))
	var industry_id := str(machine.get("industry_id", "generic"))
	var rank := clampi(int(machine.get("rank", 1)), 1, 4)
	var purchase_cash := maxi(0, int(machine.get("purchase_cash", 0)))
	var asset_cost := _public_asset_cost(machine.get("asset_cost", {}))
	var keyword_chips := _keyword_chips(player.get("keywords", []))
	var target_kind := str(machine.get("target_kind", ""))
	var acquisition_kind := str(machine.get("acquisition_kind", ""))
	var source := {
		"valid": true,
		"index": card_index,
		"card_name": card_id,
		"display_name": "%s %s" % [str(player.get("name", "卡牌")), str(player.get("rank", _roman_rank(rank)))],
		"icon": str(CATEGORY_ICONS.get(category_id, "□")),
		"family": str(machine.get("family_id", "")),
		"kind": str(machine.get("effect_kind", "")),
		"rank": rank,
		"rank_label": str(player.get("rank", _roman_rank(rank))),
		"tag_text": _keyword_text(player.get("keywords", [])),
		"accent": INDUSTRY_COLORS.get(industry_id, Color("#93c5fd")),
		"price": purchase_cash,
		"purchase_cost_text": "免费领取" if acquisition_kind == "commodity_belt_free" else "购买现金 ¥%d" % purchase_cash,
		"play_cost_text": "打出免费" if _asset_total(asset_cost) == 0 else "打出 %s" % _asset_cost_text(asset_cost),
		"category_label": str(CATEGORY_LABELS.get(category_id, "公开卡牌")),
		"category_id": category_id,
		"industry_label": str(player.get("industry", "通用")),
		"icon_route_label": "%s｜%s" % [str(CATEGORY_LABELS.get(category_id, "公开卡牌")), str(player.get("industry", "通用"))],
		"subtype_label": str(player.get("type", "公开卡牌")),
		"source_type_label": "商品带" if acquisition_kind == "commodity_belt_free" else "全局普通牌市场",
		"supply_layer": "商品带免费领取" if acquisition_kind == "commodity_belt_free" else "全局普通牌市场",
		"art_stats": "%s｜%s" % [str(player.get("timing", "普通出牌窗口")), str(player.get("duration", "立即结算"))],
		"use_case": str(player.get("next_step", "确认卡面目标")),
		"strategy_route_label": str(player.get("type", "公开卡牌")),
		"strategy_summary": str(player.get("short_effect", "")),
		"strategy_use_text": str(player.get("next_step", "确认卡面目标")),
		"quick_effect_compact": str(player.get("short_effect", "")),
		"quick_effect_full": str(player.get("short_effect", "")),
		"full_effect_text": str(player.get("effect", "")),
		"rules_text_compact": "%s｜目标:%s｜%s" % [str(player.get("timing", "普通出牌窗口")), str(player.get("target", "按卡面")), str(player.get("duration", "立即结算"))],
		"level_gradient_text": _level_gradient_text(str(machine.get("family_id", ""))),
		"detail_tooltip": "%s\n%s\n目标:%s\n%s" % [str(player.get("name", "卡牌")), str(player.get("cost", "")), str(player.get("target", "按卡面")), str(player.get("effect", ""))],
		"face_route_text": "%s｜%s" % [str(player.get("type", "公开卡牌")), str(player.get("industry", "通用"))],
		"type_label": str(player.get("type", "公开卡牌")),
		"requires_target": target_kind not in ["", "none", "self", "self_organization_slot", "global_matching_goods"],
		"requires_target_monster": target_kind.contains("monster"),
		"targets_player": target_kind.contains("opponent") or target_kind.contains("player"),
		"targets_monster": target_kind.contains("monster"),
		"target_text": str(player.get("target", "按卡面")),
		"timing_text": str(player.get("timing", "普通出牌窗口")),
		"duration_text": str(player.get("duration", "立即结算")),
		"visibility_text": str(player.get("visibility", "卡面与结算回执公开")),
		"play_requirement_text": "%s｜%s" % [str(player.get("timing", "普通出牌窗口")), str(player.get("cost", ""))],
		"key_rule_facts": _key_rule_facts(player),
		"read_chips": keyword_chips,
		"resolution_animation_text": str(player.get("short_effect", "")),
	}
	var value: Variant = _adapter.call("compose_card_facts", source)
	var result := (value as Dictionary).duplicate(true) if value is Dictionary else {}
	if not result.is_empty():
		_source_compose_count += 1
		_last_error = ""
	return result


func compose_upgrades(card_identity: String) -> Array:
	if not _require_ready():
		return []
	var card_id := resolve_card_id(card_identity)
	var machine := _machine_for_card(card_id)
	var family_id := str(machine.get("family_id", ""))
	if family_id == "":
		return []
	var result: Array = []
	for rank in range(1, 5):
		var ranked_id := "%s.rank_%d" % [family_id, rank]
		var card := public_catalog_v06.card_snapshot(ranked_id)
		if card.is_empty():
			continue
		var ranked_machine := _dictionary(card.get("machine", {}))
		var player := _dictionary(card.get("player", {}))
		result.append({
			"roman": str(player.get("rank", _roman_rank(rank))),
			"price": maxi(0, int(ranked_machine.get("purchase_cash", 0))),
			"purchase_cost_text": "免费领取" if str(ranked_machine.get("acquisition_kind", "")) == "commodity_belt_free" else "购买现金 ¥%d" % int(ranked_machine.get("purchase_cash", 0)),
			"play_cost_text": "打出免费" if _asset_total(ranked_machine.get("asset_cost", {})) == 0 else "打出 %s" % _asset_cost_text(ranked_machine.get("asset_cost", {})),
			"strength_band": "公开等级 %s" % str(player.get("rank", _roman_rank(rank))),
			"preview": str(player.get("short_effect", "")),
			"display_name": "%s %s" % [str(player.get("name", "卡牌")), str(player.get("rank", _roman_rank(rank)))],
			"full_effect_text": str(player.get("effect", "")),
			"accent": INDUSTRY_COLORS.get(str(ranked_machine.get("industry_id", "generic")), Color("#93c5fd")),
			"fill_weight": 0.10 + 0.03 * float(rank - 1),
		})
	return result


func compose_detail(card_identity: String, index: int, total: int) -> Dictionary:
	if not _require_ready():
		return {}
	var facts := compose_card_facts(card_identity, index)
	if not bool(facts.get("valid", false)):
		return {}
	var value: Variant = _adapter.call("compose_detail_source", facts, compose_upgrades(str(facts.get("card_name", ""))), total)
	var source := (value as Dictionary).duplicate(true) if value is Dictionary else {}
	if source.is_empty():
		return {}
	_detail_compose_count += 1
	return _snapshot.compose_detail(source)


func public_field_schema() -> Dictionary:
	var value: Variant = _adapter.call("public_field_schema")
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func debug_snapshot() -> Dictionary:
	var report := public_catalog_v06.validation_report() if public_catalog_v06 != null else {}
	return {
		"service_ready": _configured,
		"service_authoritative": _configured,
		"last_error": _last_error,
		"dependency_allowlist": DEPENDENCY_KEYS.duplicate(),
		"dependency_count": DEPENDENCY_KEYS.size() if _configured else 0,
		"public_catalog_schema": str(public_catalog_v06.schema_version) if public_catalog_v06 != null else "",
		"public_catalog_card_count": int(report.get("card_count", 0)),
		"public_catalog_family_count": int(report.get("family_count", 0)),
		"source_compose_count": _source_compose_count,
		"browser_compose_count": _browser_compose_count,
		"detail_compose_count": _detail_compose_count,
		"owns_public_source_assembly": true,
		"owns_rules": false,
		"owns_save_state": false,
		"has_save_api": false,
		"reads_world_bridge": false,
		"reads_private_world": false,
		"reads_player_state": false,
		"reads_legacy_v04_catalog": false,
		"uses_v06_player_contract": true,
		"uses_v06_machine_identity_and_cost": true,
		"adapter": _adapter.call("debug_snapshot"),
	}


func _catalog_cards() -> Array:
	if public_catalog_v06 == null:
		return []
	var catalog := public_catalog_v06.catalog_snapshot()
	return (catalog.get("cards", []) as Array).duplicate(true) if catalog.get("cards", []) is Array else []


func _machine_for_card(card_id: String) -> Dictionary:
	if public_catalog_v06 == null or card_id == "":
		return {}
	var card := public_catalog_v06.card_snapshot(card_id)
	return _dictionary(card.get("machine", {})).duplicate(true)


func _filters_with_counts(request_filters: Variant) -> Array:
	var supplied: Dictionary = {}
	if request_filters is Array:
		for entry_variant: Variant in request_filters:
			if entry_variant is Dictionary:
				supplied[str((entry_variant as Dictionary).get("id", ""))] = entry_variant
	var result: Array = []
	for option_variant: Variant in public_filter_options():
		var option := (option_variant as Dictionary).duplicate(true)
		var filter_id := str(option.get("id", "all"))
		option["count"] = ordered_card_ids(filter_id).size()
		if supplied.has(filter_id):
			var supplied_entry := supplied[filter_id] as Dictionary
			option["label"] = str(supplied_entry.get("label", option.get("label", filter_id)))
		result.append(option)
	return result


func _valid_filter_id(filter_id: String) -> bool:
	return filter_id == "all" or CATEGORY_LABELS.has(filter_id)


func _filter_matches(filter_id: String, category_id: String) -> bool:
	return filter_id == "all" or filter_id == category_id


func _filter_label(filter_id: String) -> String:
	return "全部" if filter_id == "all" else str(CATEGORY_LABELS.get(filter_id, ""))


func _category_accent(category_id: String) -> Color:
	return {
		"commodity": Color("#4ade80"),
		"facility": Color("#facc15"),
		"supply_demand": Color("#06b6d4"),
		"monster": Color("#fb7185"),
		"military": Color("#94a3b8"),
		"interaction": Color("#c084fc"),
		"organization": Color("#f59e0b"),
	}.get(category_id, Color("#93c5fd")) as Color


func _keyword_chips(value: Variant) -> Array:
	var result: Array = []
	if not (value is Array):
		return result
	for keyword_variant: Variant in value as Array:
		if not (keyword_variant is Dictionary):
			continue
		var keyword := keyword_variant as Dictionary
		var text_value := str(keyword.get("text", "")).strip_edges()
		if text_value == "":
			continue
		var accent := Color(str(keyword.get("accent", "#93c5fd")))
		result.append({"text": text_value, "tooltip": str(keyword.get("tooltip", "")), "fg": accent, "bg": Color("#020617"), "accent": accent})
	return result


func _keyword_text(value: Variant) -> String:
	var labels: Array[String] = []
	for chip_variant: Variant in _keyword_chips(value):
		labels.append(str((chip_variant as Dictionary).get("text", "")))
	return " / ".join(labels)


func _key_rule_facts(player: Dictionary) -> Array:
	return [
		"费用：%s" % str(player.get("cost", "")),
		"时机：%s" % str(player.get("timing", "")),
		"目标：%s" % str(player.get("target", "")),
		"持续：%s" % str(player.get("duration", "")),
		"公开：%s" % str(player.get("visibility", "")),
	]


func _public_asset_cost(value: Variant) -> Dictionary:
	var source := _dictionary(value)
	var result := {}
	for key in ["life", "energy", "industry", "technology", "commerce", "shipping", "generic"]:
		result[key] = maxi(0, int(source.get(key, 0)))
	return result


func _asset_total(value: Variant) -> int:
	var total := 0
	for amount_variant: Variant in _dictionary(value).values():
		total += maxi(0, int(amount_variant))
	return total


func _asset_cost_text(value: Variant) -> String:
	var labels := {"life":"生命", "energy":"能源", "industry":"工业", "technology":"科技", "commerce":"商业", "shipping":"航运", "generic":"通用"}
	var parts: Array[String] = []
	for key in ["life", "energy", "industry", "technology", "commerce", "shipping", "generic"]:
		var amount := maxi(0, int(_dictionary(value).get(key, 0)))
		if amount > 0:
			parts.append("%d %s资产" % [amount, str(labels[key])])
	return " + ".join(parts) if not parts.is_empty() else "免费"


func _level_gradient_text(family_id: String) -> String:
	var lines: Array[String] = []
	for rank in range(1, 5):
		var card := public_catalog_v06.card_snapshot("%s.rank_%d" % [family_id, rank]) if public_catalog_v06 != null else {}
		if card.is_empty():
			continue
		var machine := _dictionary(card.get("machine", {}))
		var player := _dictionary(card.get("player", {}))
		var purchase := "免费领取" if str(machine.get("acquisition_kind", "")) == "commodity_belt_free" else "购买¥%d" % int(machine.get("purchase_cash", 0))
		lines.append("%s｜%s｜%s" % [str(player.get("rank", _roman_rank(rank))), purchase, str(player.get("short_effect", ""))])
	return "\n".join(lines)


func _roman_rank(rank: int) -> String:
	return str({1:"I", 2:"II", 3:"III", 4:"IV"}.get(clampi(rank, 1, 4), "I"))


func _string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array or value is PackedStringArray:
		for item_variant: Variant in value:
			var item := str(item_variant).strip_edges()
			if item != "":
				result.append(item)
	return result


func _dictionary(value: Variant) -> Dictionary:
	return value as Dictionary if value is Dictionary else {}


func _require_ready() -> bool:
	if _configured:
		return true
	_last_error = "dependencies_not_configured"
	return false


func _clear_dependencies() -> void:
	_snapshot = null
	_configured = false
