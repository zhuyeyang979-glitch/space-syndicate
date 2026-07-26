@tool
extends RefCounted
class_name CardPlayerFacePublicTokenManifestV1

const RANK_LABEL_BY_RANK := {1: "I", 2: "II", 3: "III", 4: "IV"}

const CATEGORY_PRESENTATION := {
	"commodity": {"label": "商品牌", "icon_token_id": "icon.card.category.commodity", "color_token_id": "color.card.category.commodity", "icon_value": "◇", "color_value": "#4ade80"},
	"facility": {"label": "公共设施", "icon_token_id": "icon.card.category.facility", "color_token_id": "color.card.category.facility", "icon_value": "▣", "color_value": "#94a3b8"},
	"supply_demand": {"label": "供需订单", "icon_token_id": "icon.card.category.supply_demand", "color_token_id": "color.card.category.supply_demand", "icon_value": "↔", "color_value": "#06b6d4"},
	"monster": {"label": "怪兽单位", "icon_token_id": "icon.card.category.monster", "color_token_id": "color.card.category.monster", "icon_value": "怪", "color_value": "#fb7185"},
	"military": {"label": "军队单位", "icon_token_id": "icon.card.category.military", "color_token_id": "color.card.category.military", "icon_value": "◆", "color_value": "#f97316"},
	"interaction": {"label": "玩家互动", "icon_token_id": "icon.card.category.interaction", "color_token_id": "color.card.category.interaction", "icon_value": "✦", "color_value": "#c084fc"},
	"organization": {"label": "组织升级", "icon_token_id": "icon.card.category.organization", "color_token_id": "color.card.category.organization", "icon_value": "◎", "color_value": "#fbbf24"},
}

const INDUSTRY_PRESENTATION := {
	"life": {"label": "生命", "icon_token_id": "icon.card.industry.life", "color_token_id": "color.card.industry.life", "icon_value": "●", "color_value": "#4ade80"},
	"energy": {"label": "能源", "icon_token_id": "icon.card.industry.energy", "color_token_id": "color.card.industry.energy", "icon_value": "●", "color_value": "#facc15"},
	"industry": {"label": "工业", "icon_token_id": "icon.card.industry.industry", "color_token_id": "color.card.industry.industry", "icon_value": "●", "color_value": "#94a3b8"},
	"technology": {"label": "科技", "icon_token_id": "icon.card.industry.technology", "color_token_id": "color.card.industry.technology", "icon_value": "●", "color_value": "#38bdf8"},
	"commerce": {"label": "商业", "icon_token_id": "icon.card.industry.commerce", "color_token_id": "color.card.industry.commerce", "icon_value": "●", "color_value": "#c084fc"},
	"shipping": {"label": "航运", "icon_token_id": "icon.card.industry.shipping", "color_token_id": "color.card.industry.shipping", "icon_value": "●", "color_value": "#06b6d4"},
	"generic": {"label": "通用", "icon_token_id": "icon.card.industry.generic", "color_token_id": "color.card.industry.generic", "icon_value": "●", "color_value": "#fde68a"},
}

const GENERIC_ICON_VALUES := {
	"timing": "◷",
	"response": "↩",
	"operation": "•",
}
const GENERIC_COLOR_VALUES := {
	"color.card.timing": "#67e8f9",
	"color.card.response": "#38bdf8",
	"color.card.operation": "#cbd5e1",
}



static func icon_value(token_id: String) -> String:
	for presentation_variant in CATEGORY_PRESENTATION.values():
		var presentation := presentation_variant as Dictionary
		if token_id == str(presentation.get("icon_token_id", "")):
			return str(presentation.get("icon_value", ""))
	for presentation_variant in INDUSTRY_PRESENTATION.values():
		var presentation := presentation_variant as Dictionary
		if token_id == str(presentation.get("icon_token_id", "")):
			return str(presentation.get("icon_value", ""))
	if token_id.begins_with("icon.card.timing."):
		return str(GENERIC_ICON_VALUES.get("timing", ""))
	if token_id.begins_with("icon.card.response."):
		return str(GENERIC_ICON_VALUES.get("response", ""))
	if token_id.begins_with("icon.card.operation."):
		return str(GENERIC_ICON_VALUES.get("operation", ""))
	return ""


static func color_value(token_id: String) -> String:
	for presentation_variant in CATEGORY_PRESENTATION.values():
		var presentation := presentation_variant as Dictionary
		if token_id == str(presentation.get("color_token_id", "")):
			return str(presentation.get("color_value", ""))
	for presentation_variant in INDUSTRY_PRESENTATION.values():
		var presentation := presentation_variant as Dictionary
		if token_id == str(presentation.get("color_token_id", "")):
			return str(presentation.get("color_value", ""))
	return str(GENERIC_COLOR_VALUES.get(token_id, ""))
