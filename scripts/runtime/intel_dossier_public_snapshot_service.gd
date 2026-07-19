@tool
extends Node
class_name IntelDossierPublicSnapshotService

const MAX_CITY_ENTRIES := 8
const MAX_CARD_ENTRIES := 8
const MAX_PUBLIC_WORLD_ENTRIES := 32

var _configured := false
var _compose_count := 0


func configure(_config: Dictionary = {}) -> void:
	_configured = true


func compose(source: Dictionary) -> Dictionary:
	_compose_count += 1
	if not bool(source.get("valid", false)):
		return _empty_snapshot(str(source.get("reason", "暂无当前局情报")))
	var viewer_index := int(source.get("viewer_index", -1))
	var public_world_intel := _dictionary_array(source.get("public_world_intel", []), MAX_PUBLIC_WORLD_ENTRIES)
	var cities := _dictionary_array(source.get("city_entries", []), MAX_CITY_ENTRIES)
	var cards := _dictionary_array(source.get("card_entries", []), MAX_CARD_ENTRIES)
	var focused_history_entry_id := str(source.get("focused_history_entry_id", ""))
	var focused_card := _focused_card(cards, focused_history_entry_id)
	var navigation_links := _typed_links(viewer_index, public_world_intel, cards)
	return {
		"summary_text": _summary_text(source, public_world_intel, cities, cards),
		"public_navigation_links": navigation_links.duplicate(true),
		"board": {
			"title": "情报侦探板",
			"title_tooltip": "整理公开证据和当前玩家自己的推理。",
			"tooltip": "只读公开事实；私人操作只写入当前玩家自己的 owner。",
			"accent": Color("#c084fc"),
			"focused_history_entry_id": str(focused_card.get("history_entry_id", "")),
			"focused_resolution_id": _history_sequence(focused_card),
			"kpi_columns": 4,
			"clue_columns": 2,
			"control_columns": 1,
			"link_columns": 2,
			"chips": _chips(source, focused_card),
			"kpis": _kpis(public_world_intel, cities, cards),
			"actions": _card_actions(source, focused_card),
			"clues": _clues(public_world_intel, cities, cards, focused_card),
			"control_title": "私人城市推理",
			"control_groups": _city_control_groups(source, cities),
			"link_title": "公开资料",
			"links": navigation_links,
		},
	}


func debug_snapshot() -> Dictionary:
	return {
		"service_ready": _configured,
		"service_authoritative": _configured,
		"supported_domain": "intel_dossier_public_presentation_and_typed_intents",
		"compose_count": _compose_count,
		"mutates_city_guesses": false,
		"settles_intel_cash": false,
		"reveals_city_owner_truth": false,
		"reveals_card_owner_truth": false,
		"reads_private_hands": false,
		"navigates_runtime_nodes": false,
		"emits_callable_controls": false,
		"action_id_controls": false,
		"typed_action_intents": true,
		"city_reveal_controls_exposed": false,
		"contract_trace_controls_exposed": false,
		"legacy_main_formatter_active": false,
	}


func _empty_snapshot(reason: String) -> Dictionary:
	var safe_reason := reason.strip_edges()
	if safe_reason.is_empty():
		safe_reason = "暂无当前局情报"
	return {
		"summary_text": safe_reason,
		"board": {
			"title": "情报侦探板",
			"accent": Color("#c084fc"),
			"chips": [],
			"kpis": [],
			"actions": [],
			"clues": [{"title": "暂无情报", "lines": [safe_reason], "accent": Color("#94a3b8")}],
			"control_groups": [],
			"links": [],
		},
	}


func _summary_text(source: Dictionary, public_world_intel: Array, cities: Array, cards: Array) -> String:
	var marked := 0
	for city_variant in cities:
		if int((city_variant as Dictionary).get("suspected_player_index", -1)) >= 0:
			marked += 1
	return "情报档案\n当前玩家：%s｜公开区域 %d｜城市推理 %d/%d｜公共卡牌履历 %d\n这里只组合公开事实与当前玩家自己的私人标注。" % [
		str(source.get("viewer_name", "当前玩家")),
		public_world_intel.size(),
		marked,
		cities.size(),
		cards.size(),
	]


func _chips(source: Dictionary, focused_card: Dictionary) -> Array:
	var chips: Array = [
		{"text": "授权本地视角", "accent": Color("#4ade80"), "tooltip": "视角由 LocalViewerAuthorization 决定。"},
		{"text": "公共履历", "accent": Color("#f472b6"), "tooltip": "卡牌来源只使用公共履历查询。"},
		{"text": "私人推理", "accent": Color("#38bdf8"), "tooltip": "只显示当前玩家自己的城市推理和卡牌标注。"},
	]
	if not focused_card.is_empty():
		chips.push_front({
			"text": _short_text(str(focused_card.get("public_card_name", "未知牌")), 16),
			"accent": Color("#f472b6"),
			"tooltip": "当前选中的公共卡牌履历。",
		})
	var role: Dictionary = source.get("role_definition", {}) if source.get("role_definition", {}) is Dictionary else {}
	if not role.is_empty():
		chips.append({"text": _short_text(str(role.get("name", "角色")), 16), "accent": Color("#facc15"), "tooltip": str(role.get("passive", ""))})
	return chips


func _kpis(public_world_intel: Array, cities: Array, cards: Array) -> Array:
	var marked := 0
	var revealed := 0
	var warehouse_count := 0
	for world_variant in public_world_intel:
		warehouse_count += maxi(0, int((world_variant as Dictionary).get("anonymous_warehouse_count", 0)))
	for city_variant in cities:
		var city := city_variant as Dictionary
		if int(city.get("suspected_player_index", -1)) >= 0:
			marked += 1
		if bool(city.get("authorized_reveal", false)):
			revealed += 1
	return [
		{"title": "公开区域", "value": str(public_world_intel.size()), "meta": "严格公开资料源", "accent": Color("#4ade80")},
		{"title": "仓储设施", "value": str(warehouse_count), "meta": "公开业主，不含库存", "accent": Color("#facc15")},
		{"title": "已标注", "value": str(marked), "meta": "授权揭示 %d" % revealed, "accent": Color("#c084fc")},
		{"title": "公共履历", "value": str(cards.size()), "meta": "私人标注独立", "accent": Color("#f472b6")},
	]


func _clues(public_world_intel: Array, cities: Array, cards: Array, focused_card: Dictionary) -> Array:
	var region_lines: Array = []
	var facility_lines: Array = []
	var market_lines: Array = []
	var monster_lines: Array = []
	for world_variant in public_world_intel.slice(0, mini(8, public_world_intel.size())):
		var world := world_variant as Dictionary
		var region_name := str(world.get("name", "区域"))
		region_lines.append("%s｜%s｜%s｜%s" % [
			region_name,
			str(world.get("terrain_label", "区域")),
			str(world.get("economic_focus_label", "均衡")),
			str(world.get("public_clue", "暂无公开线索")),
		])
		facility_lines.append("%s｜公开设施 %d｜仓储设施 %d" % [
			region_name,
			maxi(0, int(world.get("facility_count", 0))),
			maxi(0, int(world.get("anonymous_warehouse_count", 0))),
		])
		for facility_variant in world.get("public_facility_entries", []) if world.get("public_facility_entries", []) is Array else []:
			if facility_variant is Dictionary:
				var facility := facility_variant as Dictionary
				facility_lines.append("%s｜%s/%s｜%s｜等级%d" % [
					region_name,
					str(facility.get("facility_type", "facility")),
					str(facility.get("industry_id", "public")),
					_public_facility_owner_label(facility),
					maxi(0, int(facility.get("rank", 0))),
				])
		market_lines.append("%s｜供给 %s｜需求 %s｜路线负载 %d｜天气 %s" % [
			region_name,
			str(world.get("supply_text", "无")),
			str(world.get("demand_text", "无")),
			maxi(0, int(world.get("trade_route_load", 0))),
			str(world.get("weather_text", "暂无")),
		])
		for monster_variant in world.get("monster_attraction_entries", []) if world.get("monster_attraction_entries", []) is Array else []:
			if monster_variant is Dictionary:
				var monster := monster_variant as Dictionary
				monster_lines.append("%s｜%s：%s" % [region_name, str(monster.get("name", "怪兽")), str(monster.get("reason", "公开吸引线索"))])
	if region_lines.is_empty():
		region_lines.append("暂无公开区域证据。")
	if facility_lines.is_empty():
		facility_lines.append("暂无公开设施计数。")
	if market_lines.is_empty():
		market_lines.append("暂无公开供需、路线或天气摘要。")
	if monster_lines.is_empty():
		monster_lines.append("暂无非数值怪兽吸引线索。")
	var city_lines: Array = []
	for city_variant in cities.slice(0, mini(5, cities.size())):
		var city := city_variant as Dictionary
		city_lines.append("%s｜等级%d｜收入%d｜%s" % [
			str(city.get("name", "区域")),
			int(city.get("city_level", 0)),
			int(city.get("city_last_income", 0)),
			_city_guess_label(city),
		])
	if city_lines.is_empty():
		city_lines.append("暂无陌生存活城市。")
	var card_lines: Array = []
	for card_variant in cards.slice(0, mini(5, cards.size())):
		var card := card_variant as Dictionary
		card_lines.append("%s｜%s｜%s" % [
			str(card.get("public_card_name", "未知牌")),
			str(card.get("public_target", "无公开目标")),
			str(card.get("public_result", "公共记录")),
		])
	if card_lines.is_empty():
		card_lines.append("暂无公共卡牌履历。")
	var result: Array = [
		{"title": "公开区域证据", "lines": region_lines, "accent": Color("#4ade80")},
		{"title": "匿名设施概览", "lines": facility_lines, "accent": Color("#facc15")},
		{"title": "商品、路线与天气", "lines": market_lines, "accent": Color("#fb923c")},
		{"title": "怪兽吸引线索", "lines": monster_lines, "accent": Color("#ef4444")},
		{"title": "城市公开事实与我的推理", "lines": city_lines, "accent": Color("#38bdf8")},
		{"title": "公共卡牌履历", "lines": card_lines, "accent": Color("#f472b6")},
	]
	if not focused_card.is_empty():
		var annotation: Dictionary = focused_card.get("viewer_annotation", {}) if focused_card.get("viewer_annotation", {}) is Dictionary else {}
		result.push_front({
			"title": "已选履历",
			"resolution_id": _history_sequence(focused_card),
			"focused": true,
			"lines": [
				str(focused_card.get("public_card_name", "未知牌")),
				str(focused_card.get("public_target", "无公开目标")),
				str(focused_card.get("public_result", "公共记录")),
				_annotation_label(annotation),
			],
			"accent": Color("#f472b6"),
		})
	return result


func _city_control_groups(source: Dictionary, cities: Array) -> Array:
	var groups: Array = []
	var viewer_index := int(source.get("viewer_index", -1))
	var revision := str(source.get("city_owner_revision", ""))
	var players := _dictionary_array(source.get("public_players", []), 8)
	for city_variant in cities:
		var city := city_variant as Dictionary
		var region_id := str(city.get("region_id", ""))
		if region_id.is_empty():
			continue
		var actions: Array = []
		if not bool(city.get("authorized_reveal", false)):
			for player_variant in players:
				var player := player_variant as Dictionary
				var player_index := int(player.get("player_index", -1))
				if player_index < 0 or player_index == viewer_index:
					continue
				actions.append(_action(
					"标记 %s" % str(player.get("public_player_name", "玩家%d" % (player_index + 1))),
					&"set_city_owner_guess",
					viewer_index,
					"region:%s" % region_id,
					revision,
					{"suspected_player_index": player_index, "confidence": 2, "reason_id": "intuition"},
					Color("#38bdf8")
				))
			if int(city.get("suspected_player_index", -1)) >= 0:
				for confidence in [1, 2, 3]:
					actions.append(_action("置信 %d" % confidence, &"set_city_guess_confidence", viewer_index, "region:%s" % region_id, revision, {"confidence": confidence}, Color("#7dd3fc")))
				for reason_id in ["product", "route", "card", "monster", "role", "intuition"]:
					actions.append(_action(_reason_label(reason_id), &"set_city_guess_reason", viewer_index, "region:%s" % region_id, revision, {"reason_id": reason_id}, Color("#4ade80")))
				actions.append(_action("清除", &"clear_city_owner_guess", viewer_index, "region:%s" % region_id, revision, {}, Color("#94a3b8")))
		groups.append({
			"title": str(city.get("name", "区域")),
			"meta": _city_guess_label(city),
			"accent": Color("#facc15") if bool(city.get("authorized_reveal", false)) else Color("#38bdf8"),
			"actions": actions,
		})
	return groups


func _card_actions(source: Dictionary, card: Dictionary) -> Array:
	if card.is_empty():
		return []
	var history_entry_id := str(card.get("history_entry_id", ""))
	var viewer_index := int(source.get("viewer_index", -1))
	var revision := str(source.get("annotation_owner_revision", ""))
	var annotation: Dictionary = card.get("viewer_annotation", {}) if card.get("viewer_annotation", {}) is Dictionary else {}
	var actions: Array = [
		_action("取消订阅" if bool(annotation.get("subscribed", false)) else "私人订阅", &"set_card_history_subscription", viewer_index, history_entry_id, revision, {"subscribed": not bool(annotation.get("subscribed", false))}, Color("#c084fc")),
	]
	for player_variant in _dictionary_array(source.get("public_players", []), 8):
		var player := player_variant as Dictionary
		var player_index := int(player.get("player_index", -1))
		if player_index < 0 or player_index == viewer_index:
			continue
		actions.append(_action("私标 %s" % str(player.get("public_player_name", "玩家%d" % (player_index + 1))), &"set_card_history_suspects", viewer_index, history_entry_id, revision, {"suspected_player_indices": [player_index]}, Color("#f472b6")))
	actions.append(_action("清除私标", &"clear_card_history_annotation", viewer_index, history_entry_id, revision, {}, Color("#94a3b8")))
	return actions


func _typed_links(viewer_index: int, public_world_intel: Array, cards: Array) -> Array:
	var links: Array = []
	var seen := {}
	for world_variant in public_world_intel:
		var world := world_variant as Dictionary
		var region_stable_id := str(world.get("region_stable_item_id", ""))
		_append_typed_link(links, seen, "查看区域：%s" % str(world.get("name", "区域")), &"open_region", viewer_index, region_stable_id, Color("#38bdf8"))
		for product_variant in world.get("supply_product_ids", []) if world.get("supply_product_ids", []) is Array else []:
			var product_id := str(product_variant)
			_append_typed_link(links, seen, "查看商品：%s" % product_id, &"open_product", viewer_index, product_id, Color("#fb923c"))
		for monster_variant in world.get("monster_attraction_entries", []) if world.get("monster_attraction_entries", []) is Array else []:
			if monster_variant is Dictionary:
				var monster := monster_variant as Dictionary
				_append_typed_link(links, seen, "查看怪兽：%s" % str(monster.get("name", "怪兽")), &"open_monster", viewer_index, str(monster.get("stable_item_id", "")), Color("#ef4444"))
	for card_variant in cards.slice(0, mini(2, cards.size())):
		var card := card_variant as Dictionary
		_append_typed_link(links, seen, "选择履历：%s" % str(card.get("public_card_name", "未知牌")), &"focus_history", viewer_index, str(card.get("history_entry_id", "")), Color("#f472b6"))
		var card_id := str(card.get("public_card_id", ""))
		_append_typed_link(links, seen, "查看卡牌：%s" % str(card.get("public_card_name", card_id)), &"open_card", viewer_index, card_id, Color("#f472b6"))
	links.append(_action("打开经济总览", &"open_economy", viewer_index, "economy", "", {}, Color("#facc15")))
	return links


func _append_typed_link(links: Array, seen: Dictionary, label: String, kind: StringName, viewer_index: int, subject_id: String, accent: Color) -> void:
	if not _valid_public_link_subject(kind, subject_id):
		return
	var key := "%s:%s" % [kind, subject_id]
	if seen.has(key):
		return
	seen[key] = true
	links.append(_action(label, kind, viewer_index, subject_id, "", {}, accent))


func _valid_public_link_subject(kind: StringName, subject_id: String) -> bool:
	if subject_id.is_empty() or subject_id != subject_id.strip_edges() or subject_id.length() > 96:
		return false
	if kind == &"open_region":
		return _canonical_index_id(subject_id, "region:")
	if kind == &"open_monster":
		return _canonical_index_id(subject_id, "monster:")
	if kind == &"focus_history":
		return _canonical_index_id(subject_id, "card-history:")
	return kind == &"open_product" or kind == &"open_card"


func _canonical_index_id(value: String, prefix: String) -> bool:
	if not value.begins_with(prefix):
		return false
	var suffix := value.trim_prefix(prefix)
	return suffix.is_valid_int() and int(suffix) >= 0 and str(int(suffix)) == suffix


func _action(label: String, kind: StringName, viewer_index: int, subject_id: String, expected_revision: String, payload: Dictionary, accent: Color) -> Dictionary:
	return {
		"label": label,
		"accent": accent,
		"intent": {
			"schema_version": IntelDossierActionIntent.SCHEMA_VERSION,
			"intent_kind": kind,
			"viewer_index": viewer_index,
			"subject_id": subject_id,
			"expected_owner_revision": expected_revision,
			"payload": payload.duplicate(true),
		},
	}


func _focused_card(cards: Array, focused_history_entry_id: String) -> Dictionary:
	if not focused_history_entry_id.is_empty():
		for card_variant in cards:
			var card := card_variant as Dictionary
			if str(card.get("history_entry_id", "")) == focused_history_entry_id:
				return card.duplicate(true)
	return (cards[0] as Dictionary).duplicate(true) if not cards.is_empty() else {}


func _history_sequence(card: Dictionary) -> int:
	if card.is_empty():
		return -1
	return int(card.get("public_sequence", -1))


func _city_guess_label(city: Dictionary) -> String:
	var suspect := int(city.get("suspected_player_index", -1))
	if suspect < 0:
		return "未标注"
	if bool(city.get("authorized_reveal", false)):
		return "已授权揭示：P%d" % (suspect + 1)
	return "私标 P%d｜置信%d｜%s" % [suspect + 1, int(city.get("confidence", 0)), _reason_label(str(city.get("reason_id", "intuition")))]


func _annotation_label(annotation: Dictionary) -> String:
	if annotation.is_empty():
		return "尚无私人标注"
	var suspects: Array = annotation.get("suspected_player_indices", []) if annotation.get("suspected_player_indices", []) is Array else []
	var labels: Array[String] = []
	for player_index_variant in suspects:
		labels.append("P%d" % (int(player_index_variant) + 1))
	return "私人嫌疑：%s｜%s" % ["/".join(labels) if not labels.is_empty() else "无", "已订阅" if bool(annotation.get("subscribed", false)) else "未订阅"]


func _public_facility_owner_label(facility: Dictionary) -> String:
	if str(facility.get("owner_kind", "")) == "neutral":
		return "公开业主：中立"
	var player_index := int(facility.get("owner_player_index", -1))
	return "公开业主：玩家%d" % (player_index + 1) if player_index >= 0 else "公开业主：未知"


func _reason_label(reason_id: String) -> String:
	return {
		"product": "商品",
		"route": "商路",
		"card": "卡牌",
		"monster": "怪兽",
		"role": "角色",
		"intuition": "直觉",
	}.get(reason_id, "直觉")


func _dictionary_array(value: Variant, limit: int) -> Array:
	var result: Array = []
	if not (value is Array):
		return result
	for entry_variant in value as Array:
		if entry_variant is Dictionary:
			result.append((entry_variant as Dictionary).duplicate(true))
			if result.size() >= limit:
				break
	return result


func _short_text(value: String, limit: int) -> String:
	if limit <= 0 or value.length() <= limit:
		return value
	return value.substr(0, maxi(0, limit - 1)) + "…"
