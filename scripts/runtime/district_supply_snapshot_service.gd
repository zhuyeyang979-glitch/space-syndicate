@tool
extends Node
class_name DistrictSupplySnapshotService

const REQUIRED_SOURCE_FIELDS := [
	"district_index",
	"district_name",
	"player_index",
	"subject_player_index",
	"viewer_player_index",
	"visibility_scope",
	"viewer_authorized",
	"selected_card_name",
	"availability_kind",
	"availability_text",
	"local_product_names",
	"cards",
]

const VIEWER_PRIVATE_REQUIRED_FIELDS := [
	"player_cash",
	"counted_hand_size",
	"hand_limit",
	"can_buy",
	"purchase_window",
]

const VIEWER_PRIVATE_SOURCE_KEYS := [
	"player_cash",
	"counted_hand_size",
	"hand_limit",
	"can_buy",
	"purchase_window",
]

const PUBLIC_PURCHASE_STATE_FIELDS := [
	"label",
	"detail",
	"actionable",
	"requires_discard",
	"price",
	"accent",
]

const VALID_VISIBILITY_SCOPES := ["public", "viewer_private"]

const SAFE_ACTION_REASON_CODES := [
	"facility_purchase_ready",
	"cash_insufficient",
	"source_region_dark",
	"source_region_destroyed",
	"market_listing_changed",
	"market_quote_unavailable",
	"quote_expired",
	"market_unavailable",
	"market_facts_unavailable",
	"purchase_unavailable",
]

const FORBIDDEN_SOURCE_KEYS := [
	"hidden_owner",
	"hidden_owner_id",
	"true_owner",
	"owner_truth",
	"owner_player_index",
	"owner_id",
	"source_monster_uid",
	"source_monster_owner",
	"private_plan",
	"private_target",
	"private_discard",
	"pending_discard_purchase",
	"discard_card",
	"discard_card_name",
	"hand_cards",
	"player_hand",
	"channel_source",
	"private_channel_source",
	"ai_plan",
	"ai_score",
	"ai_reason",
	"ai_utility_score",
	"route_plan_score",
	"pressure_bucket",
	"learning_bonus",
	"private_route_plan",
	"exact_hand",
	"hand_count",
	"cash_cents",
	"quote_id",
	"quote_key",
	"quote_fingerprint",
	"quote_binding_fingerprint",
	"supply_revision",
	"opened_at_world_us",
	"expires_at_world_us",
	"utility_scores",
	"decision_samples",
]

var _configured := false
var _compose_count := 0
var _last_source_card_count := 0
var _last_output_card_count := 0
var _last_pure_data_checked := true
var _last_source_valid := false
var _last_validation: Dictionary = {}


func configure(_config: Dictionary = {}) -> void:
	_configured = true


func compose(source: Dictionary) -> Dictionary:
	_compose_count += 1
	var validation := validate_source(source)
	_last_validation = validation.duplicate(true)
	_last_source_valid = bool(validation.get("valid", false))
	var source_cards: Array = source.get("cards", []) if source.get("cards", []) is Array else []
	_last_source_card_count = source_cards.size()
	if not _last_source_valid:
		_last_output_card_count = 0
		_last_pure_data_checked = true
		return _safe_snapshot()

	var cards: Array = []
	var selected_source: Dictionary = {}
	var selected_name := str(source.get("selected_card_name", ""))
	for card_variant: Variant in source_cards:
		var card_source: Dictionary = card_variant if card_variant is Dictionary else {}
		if card_source.is_empty() or str(card_source.get("card_name", "")) == "":
			continue
		cards.append(_market_card_snapshot(card_source, source))
		if str(card_source.get("card_name", "")) == selected_name:
			selected_source = card_source
	if selected_source.is_empty() and not source_cards.is_empty() and source_cards[0] is Dictionary:
		selected_source = source_cards[0] as Dictionary
		selected_name = str(selected_source.get("card_name", ""))

	var summary := _market_summary(source_cards)
	var visibility_scope := str(source.get("visibility_scope", "public"))
	var viewer_private := visibility_scope == "viewer_private"
	var output := {
		"title": "区域牌架｜%s" % str(source.get("district_name", "区域")),
		"rule_strip": "悬停/单击只预览｜双击/购买才报价",
		"rule_tooltip": "区域牌架 %d张｜%s｜%s\n公开预览不创建报价；本地玩家双击挂牌或点购买后才锁定5个世界秒。单击地图只换选区，双击其他区域才切换牌架。" % [
			source_cards.size(),
			"可购买" if bool(source.get("can_buy", false)) else "仅浏览",
			str(source.get("availability_text", "")),
		],
		"header_chips": _header_chips(source),
		"market_status": _market_status_entries(summary),
		"cards": cards,
		"selected_card_name": selected_name,
		"preview": _preview_snapshot(selected_source, source) if not selected_source.is_empty() else {},
		"visibility_scope": visibility_scope,
		"empty_state": {
			"market_text": "当前区域暂无卡牌。",
			"preview_text": "选择一张区域供牌查看详情。",
		},
		"privacy_hint": "当前仅显示本地玩家自己的购买状态。" if viewer_private else "公共牌架只显示卡牌与公开价格；购买状态保持私密。",
		"privacy_tooltip": "精确现金、手牌数量与购买资格仅对本地玩家本人显示。" if viewer_private else "公共视图不含任何玩家的精确现金、手牌或购买资格。",
	}
	if viewer_private:
		output["purchase_window"] = _purchase_window_snapshot(source.get("purchase_window", {}))
	_last_output_card_count = cards.size()
	_last_pure_data_checked = _is_data_only(output)
	return output if _last_pure_data_checked else _safe_snapshot()


func validate_source(source: Dictionary) -> Dictionary:
	var missing_fields: Array = []
	for field_variant: Variant in REQUIRED_SOURCE_FIELDS:
		var field := str(field_variant)
		if not source.has(field):
			missing_fields.append(field)
	var forbidden_paths: Array = []
	_collect_forbidden_paths(source, "source", forbidden_paths)
	var visibility_scope := str(source.get("visibility_scope", ""))
	var scope_valid := VALID_VISIBILITY_SCOPES.has(visibility_scope)
	var viewer_private := visibility_scope == "viewer_private"
	var private_paths: Array = []
	_collect_viewer_private_paths(source, "source", private_paths)
	var public_purchase_state_violations: Array = []
	if visibility_scope == "public":
		_collect_public_purchase_state_violations(source, public_purchase_state_violations)
	var viewer_relation_valid := false
	if viewer_private:
		for field_variant in VIEWER_PRIVATE_REQUIRED_FIELDS:
			var field := str(field_variant)
			if not source.has(field):
				missing_fields.append(field)
		viewer_relation_valid = bool(source.get("viewer_authorized", false)) \
			and int(source.get("viewer_player_index", -1)) >= 0 \
			and int(source.get("viewer_player_index", -1)) == int(source.get("subject_player_index", -2)) \
			and int(source.get("player_index", -3)) == int(source.get("subject_player_index", -2))
	else:
		viewer_relation_valid = not bool(source.get("viewer_authorized", true)) \
			and private_paths.is_empty() \
			and public_purchase_state_violations.is_empty()
	var pure_data := _is_data_only(source)
	return {
		"valid": pure_data and scope_valid and viewer_relation_valid and missing_fields.is_empty() and forbidden_paths.is_empty(),
		"pure_data": pure_data,
		"visibility_scope": visibility_scope,
		"scope_valid": scope_valid,
		"viewer_relation_valid": viewer_relation_valid,
		"missing_fields": missing_fields,
		"forbidden_paths": forbidden_paths,
		"private_paths": private_paths,
		"public_purchase_state_violations": public_purchase_state_violations,
		"card_count": (source.get("cards", []) as Array).size() if source.get("cards", []) is Array else 0,
	}


func debug_snapshot() -> Dictionary:
	return {
		"service_ready": _configured,
		"service_authoritative": _configured,
		"compose_count": _compose_count,
		"last_source_card_count": _last_source_card_count,
		"last_output_card_count": _last_output_card_count,
		"pure_data_checked": _last_pure_data_checked,
		"last_source_valid": _last_source_valid,
		"last_validation": _last_validation.duplicate(true),
		"calculates_purchase_eligibility": false,
		"calculates_card_price": false,
		"mutates_player_cash": false,
		"mutates_inventory": false,
		"reads_private_hand_cards": false,
		"reads_runtime_nodes": false,
		"supports_public_private_schema": true,
		"requires_explicit_viewer_subject": true,
		"legacy_main_formatter_active": false,
	}


func _safe_snapshot() -> Dictionary:
	return {
		"title": "区域牌架",
		"rule_strip": "牌架数据暂不可用",
		"rule_tooltip": "区域牌架只接受经过验证的纯数据快照。",
		"header_chips": [],
		"market_status": [],
		"cards": [],
		"selected_card_name": "",
		"preview": {},
		"visibility_scope": "public",
		"empty_state": {"market_text": "当前区域暂无卡牌。", "preview_text": "选择一张区域供牌查看详情。"},
		"privacy_hint": "只显示当前玩家可见的购买状态。",
		"privacy_tooltip": "不会公开手牌、隐藏牌主或渠道来源。",
	}


func _purchase_window_snapshot(value: Variant) -> Dictionary:
	if not (value is Dictionary):
		return {}
	var source := value as Dictionary
	if source.is_empty():
		return {}
	var result := {
		"state": str(source.get("state", "view_only")),
		"active": bool(source.get("active", false)),
		"requires_reselection": bool(source.get("requires_reselection", false)),
	}
	var source_quote: Dictionary = source.get("quote", {}) if source.get("quote", {}) is Dictionary else {}
	if not source_quote.is_empty():
		var quote := {}
		for key in [
			"quote_active",
			"locked_eligible",
			"eligible",
			"confirmable",
			"viewable",
			"availability_kind",
			"remaining_world_us",
			"final_price",
			"multiplier_q2",
			"same_region_alive_count",
			"directly_adjacent_alive_count",
		]:
			if source_quote.has(key):
				quote[key] = source_quote[key]
		result["quote"] = quote
	return result


func _header_chips(source: Dictionary) -> Array:
	var availability_kind := str(source.get("availability_kind", "invalid"))
	var can_buy := bool(source.get("can_buy", false))
	var availability_accent := _availability_color(availability_kind)
	var viewer_private := str(source.get("visibility_scope", "public")) == "viewer_private"
	var hand_size := int(source.get("counted_hand_size", 0))
	var hand_limit := maxi(0, int(source.get("hand_limit", 0)))
	var entries: Array = [
		{"text": "牌架 %d" % int((source.get("cards", []) as Array).size()), "accent": "#bfdbfeff", "fg": "#bfdbfeff", "bg": "#0f172aff", "tooltip": "当前区域的公开供牌数量。"},
		{"text": "可确认" if can_buy else "仅浏览", "accent": "#bbf7d0ff" if can_buy else "#cbd5e1ff", "fg": "#bbf7d0ff" if can_buy else "#cbd5e1ff", "bg": "#064e3bff" if can_buy else "#334155ff", "tooltip": str(source.get("availability_text", ""))},
		{"text": _availability_short_label(availability_kind), "accent": availability_accent, "bg": _mix("#020617ff", availability_accent, 0.25), "tooltip": str(source.get("availability_text", ""))},
	]
	if viewer_private:
		entries.append({"text": "¥%d" % int(source.get("player_cash", 0)), "accent": "#fde68aff", "fg": "#fde68aff", "bg": "#713f12ff", "tooltip": "当前玩家可见现金。"})
		entries.append({"text": "手牌 %d/%d" % [hand_size, hand_limit], "accent": "#d8b4feff", "fg": "#d8b4feff", "bg": "#2e1065ff", "tooltip": "普通手牌上限；固定技能牌不占格。"})
	var purchase_window: Dictionary = source.get("purchase_window", {}) if source.get("purchase_window", {}) is Dictionary else {}
	var quote: Dictionary = purchase_window.get("quote", {}) if purchase_window.get("quote", {}) is Dictionary else {}
	if viewer_private and bool(quote.get("quote_active", false)):
		var remaining_seconds := int(ceil(float(quote.get("remaining_world_us", 0)) / 1_000_000.0))
		entries.append({"text": "报价锁定 %ds" % remaining_seconds, "accent": "#fde68aff", "fg": "#fde68aff", "bg": "#713f12ff", "tooltip": "已显式选择挂牌；日照资格与最终价格锁定至倒计时结束。"})
	elif viewer_private and not quote.is_empty():
		entries.append({"text": "报价已过期", "accent": "#fb7185ff", "fg": "#fecdd3ff", "bg": "#7f1d1dff", "tooltip": "重新选择挂牌以获取新报价；界面刷新不会续期。"})
	else:
		entries.append({"text": "未报价", "accent": "#94a3b8ff", "fg": "#cbd5e1ff", "bg": "#334155ff", "tooltip": "公开预览不会创建报价；本地玩家显式选择或确认时才启动5秒锁定。"})
	entries.append({"text": "单窗口", "accent": "#c4b5fdff", "fg": "#c4b5fdff", "bg": "#312e81ff", "tooltip": "每名玩家同时只保留一个区域购买窗口。"})
	if viewer_private and hand_limit > 0 and hand_size >= hand_limit:
		entries.append({"text": "手牌已满", "accent": "#facc15ff", "fg": "#facc15ff", "bg": "#713f12ff", "tooltip": "满5张时，只有领取合法同名可升级商品牌才自动合并一次；其他牌不能直接接收。"})
	var products: Array = source.get("local_product_names", []) if source.get("local_product_names", []) is Array else []
	if not products.is_empty():
		var product_labels: Array = []
		for product_variant: Variant in products:
			product_labels.append(str(product_variant))
		entries.append({"text": "◇ %s" % _short_text(" / ".join(product_labels), 16), "accent": "#99f6e4ff", "fg": "#99f6e4ff", "bg": "#134e4aff", "tooltip": "当前区域的公开商品线索。"})
	return entries


func _market_summary(cards: Array) -> Dictionary:
	var summary := {"total": 0, "buy_now": 0, "discard": 0, "browse": 0, "blocked": 0, "upgrade": 0}
	for card_variant: Variant in cards:
		if not (card_variant is Dictionary):
			continue
		var card := card_variant as Dictionary
		var state := _purchase_state(card)
		summary["total"] = int(summary.get("total", 0)) + 1
		if bool(card.get("is_upgrade", false)):
			summary["upgrade"] = int(summary.get("upgrade", 0)) + 1
		if bool(state.get("actionable", false)):
			var key := "discard" if bool(state.get("requires_discard", false)) else "buy_now"
			summary[key] = int(summary.get(key, 0)) + 1
		elif str(state.get("label", "")) == "仅浏览":
			summary["browse"] = int(summary.get("browse", 0)) + 1
		else:
			summary["blocked"] = int(summary.get("blocked", 0)) + 1
	return summary


func _market_status_entries(summary: Dictionary) -> Array:
	var entries: Array = [
		_status_entry("可买", int(summary.get("buy_now", 0)), "#4ade80ff", "现在可以直接购买的牌。"),
		_status_entry("手满", int(summary.get("discard", 0)), "#facc15ff", "普通手牌已满；只有领取合法同名可升级商品牌才自动合并一次。"),
		_status_entry("仅看", int(summary.get("browse", 0)), "#93c5fdff", "可以查看，但这次窗口不能购买。"),
		_status_entry("受阻", int(summary.get("blocked", 0)), "#fb7185ff", "资金不足、已满级或其他状态导致暂时不能接收。"),
	]
	if int(summary.get("upgrade", 0)) > 0:
		entries.append(_status_entry("可合并", int(summary.get("upgrade", 0)), "#c084fcff", "同名同级牌可由玩家主动合并到下一罗马等级。"))
	return entries


func _status_entry(label: String, value: int, accent: String, tooltip: String) -> Dictionary:
	var active := value > 0
	return {
		"text": "%s %d" % [label, value],
		"accent": accent,
		"fg": _lighten(accent, 0.12) if active else "#94a3b8ff",
		"bg": _mix("#020617ff", accent, 0.24 if active else 0.10),
		"tooltip": tooltip,
		"active": active,
	}


func _market_card_snapshot(card: Dictionary, source: Dictionary) -> Dictionary:
	var state := _purchase_state(card)
	var card_name := str(card.get("card_name", ""))
	var display_name := str(card.get("display_name", card_name))
	var selected := bool(card.get("selected", false))
	var actionable := bool(state.get("actionable", false))
	var price := int(card.get("price", state.get("price", 0)))
	var theme_color := _hex(card.get("theme_color", "#94a3b8ff"), "#94a3b8ff")
	var accent := _hex(state.get("accent", theme_color), theme_color)
	var route_label := str(card.get("strategy_route", ""))
	var facts := _join_first(card.get("key_rule_facts", []) as Array, 2, "｜")
	if facts == "":
		facts = _short_text(str(card.get("effect_text", "")), 26)
	var result := {
		"card_name": card_name,
		"display_name": display_name,
		"selected": selected,
		"actionable": actionable,
		"title": "%s%s %s" % ["> " if selected else "", str(card.get("icon", "◇")), _short_text(display_name, 11)],
		"title_color": "#f8fafcff" if actionable else "#cbd5e1ff",
		"title_tooltip": display_name,
		"rank": str(card.get("rank_label", "I")),
		"rank_number": maxi(1, int(card.get("rank", 1))),
		"rank_tooltip": "Card rank / upgrade tier.",
		"kind": str(card.get("kind", "")),
		"card_stats": str(card.get("art_stats", "")),
		"card_art_stats": str(card.get("art_stats", "")),
		"chips": [
			{"text": "¥%d" % price, "accent": "#fde68aff", "fg": _lighten("#fde68aff", 0.12), "bg": _mix("#020617ff", "#fde68aff", 0.22), "tooltip": "Locked market price."},
			{"text": str(state.get("label", "仅浏览")), "accent": accent, "fg": _lighten(accent, 0.12), "bg": _mix("#020617ff", accent, 0.22), "tooltip": str(state.get("detail", ""))},
		],
		"micro_chips": _micro_chips(card),
		"route": _short_text(route_label, 18),
		"route_tooltip": "Strategy route: %s" % route_label,
		"facts": _short_text(facts, 32),
		"facts_tooltip": facts,
		"state_text": _short_text(str(state.get("label", "仅浏览")), 12),
		"state_tooltip": str(state.get("detail", "")),
		"accent": accent,
		"theme_color": theme_color,
		"tooltip": "%s\n%s" % [str(card.get("detail_tooltip", "")), str(state.get("detail", ""))],
	}
	result["preview"] = _preview_snapshot(card, source)
	return result


func _preview_snapshot(card: Dictionary, source: Dictionary) -> Dictionary:
	var state := _purchase_state(card)
	var card_name := str(card.get("card_name", ""))
	var display_name := str(card.get("display_name", card_name))
	var price := int(card.get("price", state.get("price", 0)))
	var theme_color := _hex(card.get("theme_color", "#94a3b8ff"), "#94a3b8ff")
	var accent := _hex(state.get("accent", theme_color), theme_color)
	var route_label := str(card.get("strategy_route", ""))
	var facts := _join_first(card.get("key_rule_facts", []) as Array, 4, "｜")
	var detail := str(state.get("detail", ""))
	var can_request_quote := _can_request_quote(state, source)
	var primary_action_id := _primary_action_id(state, can_request_quote)
	return {
		"card_name": card_name,
		"title": "%s | %s" % [display_name, str(card.get("primary_type_label", "卡牌"))],
		"title_tooltip": str(card.get("detail_tooltip", "")),
		"chips": [
			{"text": str(state.get("label", "仅浏览")), "accent": accent, "fg": _lighten(accent, 0.14), "bg": _mix("#020617ff", accent, 0.25), "tooltip": detail},
			{"text": "¥%d" % price, "accent": "#fde68aff", "fg": _lighten("#fde68aff", 0.12), "bg": "#713f12ff", "tooltip": "Locked market price."},
			{"text": _short_text(route_label, 14), "accent": _lighten(theme_color, 0.12), "fg": _lighten(theme_color, 0.18), "bg": _mix("#020617ff", theme_color, 0.20), "tooltip": route_label},
		],
		"micro_chips": _micro_chips(card),
		"decision_chips": _decision_chips(card),
		"verdicts": _purchase_verdicts(card, source),
		"scan_sections": _preview_scan_sections(card),
		"body": _short_text(str(card.get("effect_text", "")), 48),
		"body_tooltip": str(card.get("effect_text", "")),
		"facts": _short_text(facts, 42),
		"status_text": "%s｜¥%d｜%s" % [str(state.get("label", "仅浏览")), price, _short_text(detail, 36)],
		"status_tooltip": detail,
		"action_reason_code": _safe_action_reason_code(state),
		"primary_action_id": primary_action_id,
		"buy_text": "%s ¥%d" % ["获取报价" if can_request_quote else ("手满限制" if bool(state.get("requires_discard", false)) else "购买"), price],
		"buy_enabled": not primary_action_id.is_empty(),
		"buy_tooltip": "查看总是允许；%s" % detail,
		"card_face": _preview_card_face(card),
		"accent": accent,
		"theme_color": theme_color,
		"tooltip": str(card.get("detail_tooltip", "")),
	}


func _primary_action_id(state: Dictionary, can_request_quote: bool) -> String:
	if can_request_quote:
		return "district_supply_preview_card"
	if bool(state.get("actionable", false)):
		return "district_supply_purchase_card"
	return ""


func _can_request_quote(state: Dictionary, source: Dictionary) -> bool:
	if str(source.get("visibility_scope", "")) != "viewer_private":
		return false
	if str(source.get("availability_kind", "")) != "sunlit":
		return false
	return str(state.get("label", "")) in ["选择以报价", "报价已过期"]


func _micro_chips(card: Dictionary) -> Array:
	var entries: Array = []
	var required_percent := int(card.get("play_share_required", 0))
	if required_percent > 0:
		entries.append({"text": "GDP≥%d%%" % required_percent, "fg": "#bbf7d0ff", "bg": "#14532dff", "tip": str(card.get("play_requirement_text", ""))})
	else:
		entries.append({"text": "免门槛", "fg": "#cbd5e1ff", "bg": "#334155ff", "tip": "打出时不要求前置GDP份额。"})
	var target_kind := str(card.get("target_kind", "current_district"))
	match target_kind:
		"monster": entries.append({"text": "目标◆", "fg": "#fecacaff", "bg": "#7f1d1dff", "tip": "打出时需要指定一只在场怪兽。"})
		"player": entries.append({"text": "目标玩家", "fg": "#bfdbfeff", "bg": "#1e3a8aff", "tip": "直接影响一名玩家；目标会成为公开线索。"})
		"monster_deploy": entries.append({"text": "召唤/升级", "fg": "#fecacaff", "bg": "#7f1d1dff", "tip": "怪兽牌用于召唤、升级或刷新同名怪兽。"})
		"military_deploy": entries.append({"text": "部署", "fg": "#cffafeff", "bg": "#164e63ff", "tip": "军队牌部署一支短期受控战斗力量。"})
		_: entries.append({"text": "按选区", "fg": "#c4b5fdff", "bg": "#312e81ff", "tip": "按当前选区、当前商品或卡面规则结算。"})
	var cash_cost := int(card.get("play_cash_cost", 0))
	if cash_cost > 0:
		entries.append({"text": "打出¥%d" % cash_cost, "fg": "#fed7aaff", "bg": "#7c2d12ff", "tip": "打出时需要额外现金；购买费用另算。"})
	entries.append({"text": "固定" if bool(card.get("persistent", false)) else "一次", "fg": "#fef9c3ff" if bool(card.get("persistent", false)) else "#e2e8f0ff", "bg": "#854d0eff" if bool(card.get("persistent", false)) else "#1f2937ff", "tip": "固定技能可重复使用；一次性牌进入匿名队列后会离手。"})
	return entries


func _decision_chips(card: Dictionary) -> Array:
	var state := _purchase_state(card)
	var route_label := str(card.get("strategy_route", ""))
	var accent := _hex(state.get("accent", "#94a3b8ff"), "#94a3b8ff")
	var required_percent := int(card.get("play_share_required", 0))
	var entries: Array = [
		{"text": "用途:%s" % _short_text(route_label, 10), "fg": "#dbeafeff", "bg": "#1e3a8aff", "tip": "这张牌主要属于：%s。" % route_label},
		{"text": "买入:%s" % _short_text(str(state.get("label", "仅浏览")), 5), "fg": _lighten(accent, 0.16), "bg": _mix("#020617ff", accent, 0.32), "tip": str(state.get("detail", ""))},
	]
	entries.append({"text": "打出:GDP≥%d%%" % required_percent, "fg": "#bbf7d0ff", "bg": "#14532dff", "tip": str(card.get("play_requirement_text", ""))} if required_percent > 0 else {"text": "打出:免门槛", "fg": "#e2e8f0ff", "bg": "#334155ff", "tip": "打出时不要求前置GDP份额。"})
	var target_kind := str(card.get("target_kind", "current_district"))
	match target_kind:
		"monster": entries.append({"text": "目标:怪兽", "fg": "#fecacaff", "bg": "#7f1d1dff", "tip": "打出时需要指定一只在场怪兽。"})
		"player": entries.append({"text": "目标:玩家", "fg": "#bfdbfeff", "bg": "#1e3a8aff", "tip": "打出时需要指定一名玩家。"})
		_: entries.append({"text": "目标:按牌面", "fg": "#c4b5fdff", "bg": "#312e81ff", "tip": "按当前选区、当前商品或卡面文字结算。"})
	return entries


func _purchase_verdicts(card: Dictionary, source: Dictionary) -> Array:
	var state := _purchase_state(card)
	var accent := _hex(state.get("accent", "#94a3b8ff"), "#94a3b8ff")
	var viewer_private := str(source.get("visibility_scope", "public")) == "viewer_private"
	var hand_size := int(source.get("counted_hand_size", 0))
	var hand_limit := maxi(0, int(source.get("hand_limit", 0)))
	var hand_full := hand_limit > 0 and hand_size >= hand_limit
	var entries: Array = [
		{"text": str(state.get("label", "仅浏览")), "accent": accent, "active": bool(state.get("actionable", false)), "tip": str(state.get("detail", ""))},
		{"text": "价¥%d" % int(card.get("price", state.get("price", 0))), "accent": "#fde68aff", "active": true, "tip": "当前预览价；显式选择后才锁定5个世界秒。"},
	]
	if viewer_private:
		entries.append({"text": "手牌%d/%d" % [hand_size, hand_limit], "accent": "#facc15ff" if hand_full else "#d8b4feff", "active": hand_full, "tip": "普通手牌上限；固定技能牌不占格。"})
	else:
		entries.append({"text": "公开预览", "accent": "#93c5fdff", "active": true, "tip": "公共视图不显示任何玩家的手牌数量或购买资格。"})
	if viewer_private and bool(state.get("requires_discard", false)):
		entries.append({"text": "手满限制", "accent": "#facc15ff", "active": true, "tip": "普通牌不能直接接收；满5张领取合法同名可升级商品牌时才自动合并一次。"})
	var availability_kind := str(source.get("availability_kind", "invalid"))
	entries.append({"text": _availability_short_label(availability_kind), "accent": _availability_color(availability_kind), "active": availability_kind == "sunlit", "tip": str(source.get("availability_text", ""))})
	entries.append({
		"text": "显式报价" if viewer_private else "公开日照",
		"accent": "#93c5fdff",
		"active": true,
		"tip": "只有选择或确认挂牌才锁定5秒资格与价格。" if viewer_private else "日照资格与挂牌来源公开；玩家现金和手牌仍保持私密。",
	})
	return entries


func _preview_scan_sections(card: Dictionary) -> Array:
	var state := _purchase_state(card)
	var theme_color := _hex(card.get("theme_color", "#94a3b8ff"), "#94a3b8ff")
	var accent := _hex(state.get("accent", "#94a3b8ff"), "#94a3b8ff")
	return [
		{"title": "用途", "body": _short_text(str(card.get("strategy_route", "")), 30), "accent": _lighten(theme_color, 0.12), "tooltip": "主要路线：%s\n%s" % [str(card.get("strategy_route", "")), str((card.get("card_face_facts", {}) as Dictionary).get("quick_effect", ""))]},
		{"title": "买入", "body": _short_text(_buy_scan_text(state, int(card.get("price", 0))), 30), "accent": accent, "tooltip": str(state.get("detail", ""))},
		{"title": "打出", "body": _short_text(_play_scan_text(card), 30), "accent": "#86efacff", "tooltip": "打出门槛检查地区GDP份额；现金打出费用另算。"},
		{"title": "目标", "body": _short_text(_target_scan_text(card), 30), "accent": "#c4b5fdff", "tooltip": _target_scan_tooltip(card)},
	]


func _preview_card_face(card: Dictionary) -> Dictionary:
	var facts: Dictionary = card.get("card_face_facts", {}) if card.get("card_face_facts", {}) is Dictionary else {}
	return {
		"name": "%s %s" % [str(card.get("icon", "◇")), str(card.get("display_name", card.get("card_name", "卡牌")))],
		"cost": "$%d" % int(card.get("price", 0)),
		"effect": str(facts.get("quick_effect", "")),
		"use_case": str(facts.get("use_case", "")),
		"table_use": str(facts.get("use_case", "")),
		"type": str(facts.get("route_text", "")),
		"rank": str(facts.get("level_text", card.get("rank_label", "I"))),
		"kind": str(card.get("kind", "")),
		"card_kind": str(card.get("kind", "")),
		"card_stats": str(card.get("art_stats", "")),
		"presentation": "inspector_full",
		"accent": _hex(card.get("theme_color", "#94a3b8ff"), "#94a3b8ff"),
		"minimum_width": 174.0,
		"minimum_height": 218.0,
	}


func _purchase_state(card: Dictionary) -> Dictionary:
	if card.get("purchase_state", {}) is Dictionary and not (card.get("purchase_state", {}) as Dictionary).is_empty():
		return card.get("purchase_state", {}) as Dictionary
	return {
		"label": "仅浏览",
		"detail": "公共牌架预览；挂牌来源与日照资格公开，玩家现金和手牌保持私密。",
		"actionable": false,
		"requires_discard": false,
		"accent": "#94a3b8ff",
	}


func _safe_action_reason_code(state: Dictionary) -> String:
	var reason_code := str(state.get("reason_code", "purchase_unavailable")).strip_edges()
	return reason_code if SAFE_ACTION_REASON_CODES.has(reason_code) else "purchase_unavailable"


func _buy_scan_text(state: Dictionary, price: int) -> String:
	var parts: Array = [str(state.get("label", "仅浏览")), "¥%d" % price]
	if bool(state.get("requires_discard", false)):
		parts.append("手满限制")
	return "｜".join(parts)


func _play_scan_text(card: Dictionary) -> String:
	var parts: Array = []
	var required_percent := int(card.get("play_share_required", 0))
	parts.append("GDP≥%d%%" % required_percent if required_percent > 0 else "免门槛")
	var cash_cost := int(card.get("play_cash_cost", 0))
	if cash_cost > 0:
		parts.append("打出¥%d" % cash_cost)
	parts.append("固定" if bool(card.get("persistent", false)) else "一次")
	return "｜".join(parts)


func _target_scan_text(card: Dictionary) -> String:
	match str(card.get("target_kind", "current_district")):
		"monster": return "指定怪兽"
		"player": return "指定玩家"
		"monster_deploy": return "落点/同名怪兽"
		"military_deploy": return "部署区域"
	return "当前选区"


func _target_scan_tooltip(card: Dictionary) -> String:
	match str(card.get("target_kind", "current_district")):
		"monster": return "打出时要选择一只场上怪兽。"
		"player": return "打出时要选择一名玩家；结果会变成公开推理线索。"
		"monster_deploy": return "一级怪兽通常选择落点；同名在场时可升级并刷新生命/持续时间。"
		"military_deploy": return "军队牌部署短期受控单位，后续用命令牌行动。"
	return "多数经济牌按当前选区或卡面说明结算。"


func _availability_short_label(availability_kind: String) -> String:
	match availability_kind:
		"sunlit": return "日照可报价"
		"dark": return "暗面仅浏览"
		"destroyed": return "来源已摧毁"
		"public": return "公开日照"
	return "资格不可用"


func _availability_color(availability_kind: String) -> String:
	match availability_kind:
		"sunlit": return "#4ade80ff"
		"dark": return "#64748bff"
		"destroyed": return "#fb7185ff"
		"public": return "#93c5fdff"
	return "#94a3b8ff"


func _join_first(values: Array, limit: int, separator: String) -> String:
	var parts: Array = []
	for value_variant: Variant in values:
		var text_value := str(value_variant)
		if text_value != "":
			parts.append(text_value)
		if parts.size() >= maxi(1, limit):
			break
	return separator.join(parts)


func _short_text(value: String, limit: int) -> String:
	if limit <= 0 or value.length() <= limit:
		return value
	return value.substr(0, maxi(0, limit - 1)) + "…"


func _hex(value: Variant, fallback: String) -> String:
	var text_value := str(value)
	if not text_value.begins_with("#"):
		text_value = fallback
	return "#%s" % Color(text_value).to_html(true)


func _lighten(value: String, amount: float) -> String:
	return "#%s" % Color(_hex(value, "#94a3b8ff")).lightened(amount).to_html(true)


func _mix(left: String, right: String, weight: float) -> String:
	return "#%s" % Color(_hex(left, "#020617ff")).lerp(Color(_hex(right, "#94a3b8ff")), clampf(weight, 0.0, 1.0)).to_html(true)


func _collect_forbidden_paths(value: Variant, path: String, result: Array) -> void:
	if value is Dictionary:
		for key_variant: Variant in (value as Dictionary).keys():
			var key := str(key_variant)
			var child_path := "%s.%s" % [path, key]
			if FORBIDDEN_SOURCE_KEYS.has(key):
				result.append(child_path)
			_collect_forbidden_paths((value as Dictionary).get(key_variant), child_path, result)
	elif value is Array:
		for index in range((value as Array).size()):
			_collect_forbidden_paths((value as Array)[index], "%s[%d]" % [path, index], result)


func _collect_viewer_private_paths(value: Variant, path: String, result: Array) -> void:
	if value is Dictionary:
		for key_variant: Variant in (value as Dictionary).keys():
			var key := str(key_variant)
			var child_path := "%s.%s" % [path, key]
			if VIEWER_PRIVATE_SOURCE_KEYS.has(key):
				result.append(child_path)
			_collect_viewer_private_paths((value as Dictionary).get(key_variant), child_path, result)
	elif value is Array:
		for index in range((value as Array).size()):
			_collect_viewer_private_paths((value as Array)[index], "%s[%d]" % [path, index], result)


func _collect_public_purchase_state_violations(source: Dictionary, result: Array) -> void:
	var cards: Array = source.get("cards", []) if source.get("cards", []) is Array else []
	for card_index in range(cards.size()):
		if not (cards[card_index] is Dictionary):
			result.append("source.cards[%d]:not_dictionary" % card_index)
			continue
		var card := cards[card_index] as Dictionary
		if not (card.get("purchase_state", null) is Dictionary):
			result.append("source.cards[%d].purchase_state:missing" % card_index)
			continue
		var state := card.get("purchase_state", {}) as Dictionary
		for key_variant: Variant in state.keys():
			var key := str(key_variant)
			if not PUBLIC_PURCHASE_STATE_FIELDS.has(key):
				result.append("source.cards[%d].purchase_state.%s:not_public" % [card_index, key])
		if str(state.get("label", "")) != "仅浏览":
			result.append("source.cards[%d].purchase_state.label:not_browse" % card_index)
		if bool(state.get("actionable", true)):
			result.append("source.cards[%d].purchase_state.actionable:true" % card_index)
		if bool(state.get("requires_discard", true)):
			result.append("source.cards[%d].purchase_state.requires_discard:true" % card_index)
		if int(state.get("price", -1)) != int(card.get("price", -2)):
			result.append("source.cards[%d].purchase_state.price:mismatch" % card_index)


func _is_data_only(value: Variant) -> bool:
	if value is String or value is bool or value is int or value is float:
		return true
	if value is Array:
		for item_variant: Variant in value:
			if not _is_data_only(item_variant):
				return false
		return true
	if value is Dictionary:
		for key_variant: Variant in value.keys():
			if not (key_variant is String) or not _is_data_only(value.get(key_variant)):
				return false
		return true
	return false
