@tool
extends Node
class_name ProductCodexPublicSnapshotService

var _configured := false
var _compose_count := 0


func configure(_config: Dictionary = {}) -> void:
	_configured = true


func compose(source: Dictionary) -> Dictionary:
	_compose_count += 1
	if not bool(source.get("valid", false)):
		return {
			"summary_text": "",
			"preview_text": "",
			"detail_tooltip": "",
			"browser_entry": {},
			"detail": {},
		}
	var profile := _dictionary(source.get("profile", {}))
	var market := _dictionary(source.get("market", {}))
	var product_name := str(source.get("name", "商品"))
	var index := int(source.get("index", 0))
	var total := maxi(1, int(source.get("total", 1)))
	var current_price := int(market.get("current_price", 0))
	var base_price := int(market.get("base_price", current_price))
	var category := str(profile.get("category", "商品"))
	var route := str(profile.get("route", "商业线"))
	var terrain := str(profile.get("terrain", "通用"))
	var use_text := str(profile.get("use", "观察供需、天气、运输吞吐和怪兽偏好。"))
	var accent := _color(profile.get("accent", Color("#22c55e")), Color("#22c55e"))
	var secondary := _color(profile.get("secondary", Color("#f8fafc")), Color("#f8fafc"))
	var strategy_summary := _strategy_summary(source.get("strategy_rankings", []) as Array)
	var primary_strategy := _primary_strategy_tag(source.get("strategy_rankings", []) as Array)
	var monster_focus_compact := _monster_focus_text(source.get("monster_focus_names", []) as Array, true)
	var monster_focus_full := _monster_focus_text(source.get("monster_focus_names", []) as Array, false)
	var related_cards := _limited_names(source.get("related_card_names", []) as Array, 4, "无固定门槛；可通过当前商路商品类卡牌临时选用")
	var supply_districts := _limited_names(source.get("supply_district_names", []) as Array, 6, "开局后显示")
	var demand_districts := _limited_names(source.get("demand_district_names", []) as Array, 6, "开局后显示")
	var clue_summary := _limited_names(source.get("public_clue_lines", []) as Array, 3, "暂无公开区域事件", " / ")
	var clue_summary_full := _limited_names(source.get("public_clue_lines", []) as Array, 4, "暂无公开区域事件", " / ")
	var clue_preview := _limited_names(source.get("public_clue_labels", []) as Array, 2, "暂无", "；")
	var weather_text := str(market.get("weather_text", "暂无经济天气"))
	var trend_text := str(market.get("trend_text", "0"))
	var tier_text := str(market.get("tier", "未定价"))
	var badge := {
		"name": product_name,
		"glyph": str(profile.get("glyph", "◇")),
		"profile": "%s｜%s" % [category, route],
		"terrain": "地形:%s" % terrain,
		"price": "¥%d｜基准¥%d｜%s" % [current_price, base_price, trend_text],
		"meter": "供%d 需%d 波%d" % [
			int(market.get("supply", 0)),
			int(market.get("demand", 0)),
			int(market.get("volatility", 0)),
		],
		"weather": _short_text(weather_text, 80),
		"use": use_text,
		"accent": accent,
		"secondary": secondary,
	}
	var preview_text := "\n".join([
		"◇ 商品：%s / %s｜地形:%s｜符号:%s" % [category, route, terrain, str(profile.get("glyph", "◇"))],
		"价格带：%s｜当前价¥%d｜基准¥%d｜供%d 需%d 波%d" % [tier_text, current_price, base_price, int(market.get("supply", 0)), int(market.get("demand", 0)), int(market.get("volatility", 0))],
		"策略:%s" % strategy_summary,
		"公开边界：只显示聚合市场；私人仓储和期货持仓保持隐藏。",
		"怪兽：%s" % monster_focus_compact,
		"相关卡：%s" % related_cards,
		"天气：%s" % _short_text(weather_text, 84),
		"供给区：%s｜需求区：%s" % [_limited_names(source.get("supply_district_names", []) as Array, 3, "开局后显示"), _limited_names(source.get("demand_district_names", []) as Array, 3, "开局后显示")],
		"区域公开事件：%s" % clue_preview,
		"用途：%s" % _short_text(use_text, 92),
		"牌路：%s" % _short_text(str(profile.get("hook", "")), 92),
	])
	var detail_tooltip := "%s\n%s\n操作：悬停/单击预览；双击进入完整商品详情。" % [product_name, preview_text]
	var detail := {
		"title": "%s｜%s" % [product_name, route],
		"subtitle": "%s｜地形:%s｜%s" % [category, terrain, use_text],
		"tooltip": "商品市场板：先看价格、供需、天气、运输、怪兽偏好和地图入口。",
		"accent": accent,
		"secondary": secondary,
		"badge": badge,
		"chips": _detail_chips(market, current_price, base_price),
		"kpis": _detail_kpis(market, current_price, primary_strategy, strategy_summary, weather_text, related_cards),
		"strategies": _strategy_cards(profile, strategy_summary, monster_focus_compact, monster_focus_full, supply_districts, demand_districts, clue_summary, clue_summary_full),
	}
	var summary_text := "\n".join([
		"商品详情｜第%d/%d种｜%s｜%s｜%s｜地形:%s" % [index + 1, total, product_name, tier_text, category, terrain],
		"看下方商品市场板：价格、供需、趋势、天气、怪兽偏好、相关卡牌和地图入口。",
		"当前价¥%d｜基准¥%d｜偏离%s｜趋势%s｜商业线:%s｜符号:%s" % [current_price, base_price, _signed_int_text(current_price - base_price), trend_text, route, str(profile.get("glyph", "◇"))],
		"供%d｜需%d｜波%d；供给、需求、天气与真实运输吞吐共同解释公开价格变化。" % [int(market.get("supply", 0)), int(market.get("demand", 0)), int(market.get("volatility", 0))],
		"【商品卡】价格带:%s｜当前价¥%d｜基准¥%d｜地形:%s。" % [tier_text, current_price, base_price, terrain],
		"【市场面板】供%d｜需%d｜波%d｜经济天气:%s。" % [int(market.get("supply", 0)), int(market.get("demand", 0)), int(market.get("volatility", 0)), weather_text],
		"【策略面板】策略摘要：%s" % strategy_summary,
		"【天气与运输】经济天气：%s｜运输影响只显示公开聚合；私人仓储和期货持仓保持隐藏。" % weather_text,
		"【生态与卡牌】怪兽偏好：%s｜相关卡牌：%s｜商品相关公开事件：%s" % [monster_focus_compact, related_cards, clue_summary],
		"玩家现金、手牌、私人库存与期货位置保持隐藏；只用公开事件、怪兽偏好和价格变化判断。",
	])
	return {
		"summary_text": summary_text,
		"preview_text": preview_text,
		"detail_tooltip": detail_tooltip,
		"browser_entry": {
			"catalog_index": index,
			"selected": bool(source.get("selected", false)),
			"badge": badge.duplicate(true),
			"tooltip": detail_tooltip,
		},
		"detail": detail,
	}


func debug_snapshot() -> Dictionary:
	return {
		"service_ready": _configured,
		"service_authoritative": _configured,
		"supported_domain": "product",
		"compose_count": _compose_count,
		"calculates_market_price": false,
		"calculates_strategy_scores": false,
		"reads_runtime_nodes": false,
		"legacy_main_formatter_active": false,
	}


func _detail_chips(market: Dictionary, current_price: int, base_price: int) -> Array:
	return [
		{"text": "¥%d" % current_price, "fg": Color("#bbf7d0"), "accent": Color("#bbf7d0"), "tooltip": "当前市场价。"},
		{"text": "基准¥%d" % base_price, "fg": Color("#fde68a"), "accent": Color("#fde68a"), "tooltip": "商品基准价。"},
		{"text": str(market.get("trend_text", "0")), "fg": Color("#fef3c7"), "accent": Color("#fef3c7"), "tooltip": "最近价格趋势。"},
		{"text": "供%d" % int(market.get("supply", 0)), "fg": Color("#4ade80"), "accent": Color("#4ade80"), "tooltip": "公开供给越多，价格越容易下行。"},
		{"text": "需%d" % int(market.get("demand", 0)), "fg": Color("#fb7185"), "accent": Color("#fb7185"), "tooltip": "公开需求越多，价格越容易上行。"},
		{"text": "波%d" % int(market.get("volatility", 0)), "fg": Color("#c084fc"), "accent": Color("#c084fc"), "tooltip": "波动越高，公开价格变化越敏感。"},
	]


func _detail_kpis(market: Dictionary, current_price: int, primary_strategy: String, strategy_summary: String, weather_text: String, related_cards: String) -> Array:
	return [
		{"title": "价格", "value": "¥%d｜%s" % [current_price, str(market.get("tier", "未定价"))], "meta": "近期:%s" % str(market.get("price_path_text", current_price)), "accent": Color("#bbf7d0")},
		{"title": "主策略", "value": primary_strategy, "meta": _short_text(strategy_summary, 42), "accent": Color("#facc15")},
		{"title": "天气", "value": _short_text(weather_text, 34), "meta": "天气会改写产/交/消", "accent": Color("#38bdf8")},
		{"title": "牌路", "value": _short_text(related_cards, 34), "meta": "相关卡牌会在有该商品的星球/区域出现", "accent": Color("#a78bfa")},
	]


func _strategy_cards(profile: Dictionary, strategy_summary: String, monster_compact: String, monster_full: String, supply_districts: String, demand_districts: String, clue_summary: String, clue_summary_full: String) -> Array:
	return [
		{"title": "策略用途", "body": _short_text(str(profile.get("hook", "当前没有额外牌路。")), 82), "tooltip": strategy_summary, "accent": Color("#fde68a")},
		{"title": "公开市场", "body": "价格、供需、天气与运输聚合可见", "tooltip": "私人仓储、库存单位、期货方向、位置与到期时间不属于公共图鉴。", "accent": Color("#f97316")},
		{"title": "怪兽偏好", "body": _short_text(monster_compact, 82), "tooltip": monster_full, "accent": Color("#fb923c")},
		{"title": "地图供给", "body": _short_text(supply_districts, 82), "tooltip": "本地供给区域：%s" % supply_districts, "accent": Color("#4ade80")},
		{"title": "地图需求", "body": _short_text(demand_districts, 82), "tooltip": "本地需求区域：%s" % demand_districts, "accent": Color("#fb7185")},
		{"title": "区域事件", "body": _short_text(clue_summary, 82), "tooltip": clue_summary_full, "accent": Color("#f0abfc")},
	]


func _strategy_summary(rankings: Array) -> String:
	if rankings.size() < 2:
		return "观察0 / 线索0｜建议:观察供需变化。"
	var first := _dictionary(rankings[0])
	var second := _dictionary(rankings[1])
	return "%s%d / %s%d｜建议:%s" % [str(first.get("label", "策略")), int(first.get("score", 0)), str(second.get("label", "次选")), int(second.get("score", 0)), str(first.get("hint", "观察供需变化。"))]


func _primary_strategy_tag(rankings: Array) -> String:
	if rankings.is_empty():
		return "主策略:观察0"
	var first := _dictionary(rankings[0])
	return "主策略:%s%d" % [str(first.get("label", "观察")), int(first.get("score", 0))]


func _monster_focus_text(names: Array, compact: bool) -> String:
	var text := _limited_names(names, 3 if compact else 6, "暂无固定偏好怪兽")
	if text == "暂无固定偏好怪兽" or compact:
		return text
	return "%s；这些怪兽更容易被该商品产区、需求城或仓库吸引。" % text


func _limited_names(values: Array, limit: int, empty_text: String, separator: String = "、") -> String:
	var names := []
	for value: Variant in values:
		var text_value := str(value)
		if text_value != "":
			names.append(text_value)
		if names.size() >= maxi(1, limit):
			break
	return separator.join(names) if not names.is_empty() else empty_text


func _short_text(value: String, limit: int) -> String:
	if limit <= 0 or value.length() <= limit:
		return value
	return value.substr(0, maxi(0, limit - 1)) + "…"


func _signed_int_text(value: int) -> String:
	return "+%d" % value if value > 0 else str(value)


func _dictionary(value: Variant) -> Dictionary:
	return value as Dictionary if value is Dictionary else {}


func _color(value: Variant, fallback: Color) -> Color:
	if value is Color:
		return value as Color
	if value is String and str(value).begins_with("#"):
		return Color(str(value))
	return fallback
