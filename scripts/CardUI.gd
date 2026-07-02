extends Control
class_name CardUI

signal card_double_clicked(card_data: Dictionary)
signal card_clicked(card_data: Dictionary)

@export var cost_text: String = "3"
@export var card_name: String = "轨道融资"
@export_multiline var effect_text: String = "提升一座城市的现金流。"
@export var card_type: String = "经济"
@export var stats_text: String = "I"
@export var accent_color: Color = Color(0.45, 0.65, 0.95, 1.0)
@export var presentation_mode: String = "full"

const PRESENTATION_MINI_HAND := "mini_hand"
const PRESENTATION_INSPECTOR_FULL := "inspector_full"
const PRESENTATION_CODEX_FULL := "codex_full"
const CARD_FEEL_V3_STATE_KEYS := ["hovered", "selected", "dragging", "drop_valid", "drop_invalid"]

var _card_data: Dictionary = {}
var _interaction_state: Dictionary = {
	"hovered": false,
	"selected": false,
	"dragging": false,
	"drop_valid": true,
	"drop_invalid": false,
}

@onready var cost_label: Label = %CostLabel
@onready var name_label: Label = %NameLabel
@onready var art_panel: PanelContainer = %ArtPanel
@onready var art_label: Label = %ArtLabel
@onready var effect_label: Label = %EffectLabel
@onready var type_label: Label = %TypeLabel
@onready var stat_label: Label = %StatLabel

func _ready() -> void:
	clip_contents = true
	_apply_data()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_apply_density_for_size()


func set_card_data(data: Dictionary) -> void:
	_card_data = data.duplicate(true)
	cost_text = str(data.get("cost", data.get("price", data.get("play_cost", cost_text))))
	card_name = str(data.get("name", card_name))
	effect_text = str(data.get("effect", data.get("text", data.get("description", effect_text))))
	card_type = str(data.get("type", data.get("category", card_type)))
	stats_text = str(data.get("rank", data.get("stats", stats_text)))
	presentation_mode = str(data.get("presentation", data.get("display_mode", presentation_mode)))
	if data.has("accent") and data["accent"] is Color:
		accent_color = data["accent"]
	elif data.has("accent") and data["accent"] is String and str(data["accent"]).begins_with("#"):
		accent_color = Color(str(data["accent"]))
	else:
		accent_color = _accent_for_type(card_type)
	_apply_data()


func get_card_data() -> Dictionary:
	return _card_data.duplicate(true)


func set_interaction_state(state: Dictionary) -> void:
	_interaction_state = {
		"hovered": bool(state.get("hovered", false)),
		"selected": bool(state.get("selected", false)),
		"dragging": bool(state.get("dragging", false)),
		"drop_valid": bool(state.get("drop_valid", true)),
		"drop_invalid": bool(state.get("drop_invalid", false)),
		"tokens": state.get("tokens", []),
	}
	set_meta("card_interaction_state", _interaction_state.duplicate(true))
	set_meta("card_visual_state", _card_visual_state_label())
	_apply_frame_style()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			if mouse_event.double_click:
				card_double_clicked.emit(get_card_data())
			else:
				card_clicked.emit(get_card_data())
			accept_event()


func _apply_data() -> void:
	if not is_node_ready():
		return
	var display_type := _player_facing_type_label(card_type)
	var hand_mini := _is_mini_hand_card()
	var inspector_full := _is_inspector_full_card()
	cost_label.text = cost_text
	name_label.text = _short_card_text(card_name, 12) if hand_mini else card_name
	effect_label.text = _mini_effect_line() if hand_mini else (_inspector_full_effect_text() if inspector_full else effect_text)
	type_label.text = _mini_route_text(display_type) if hand_mini else (_inspector_full_route_text(display_type) if inspector_full else display_type)
	stat_label.text = _mini_rank_text() if hand_mini else stats_text
	tooltip_text = "%s\n%s\n%s" % [card_name, display_type, effect_text]
	art_label.text = _mini_status_text() if hand_mini else (_inspector_status_text() if inspector_full else _art_hint_for_type(card_type))
	set_meta("card_presentation_spec", _presentation_spec())
	set_meta("card_primary_action_label", _primary_action_label())
	_apply_density_for_size()
	_apply_frame_style()


func _apply_frame_style() -> void:
	if not is_node_ready():
		return
	var state_accent := _interaction_accent()
	var state_border_width := _interaction_border_width()
	var frame := get_node_or_null("CardFrame") as PanelContainer
	if frame != null:
		var frame_style := StyleBoxFlat.new()
		frame_style.bg_color = Color("#020617").lerp(state_accent, _interaction_fill_weight())
		frame_style.border_color = Color("#334155").lerp(state_accent, _interaction_border_weight())
		frame_style.set_border_width_all(state_border_width)
		frame_style.set_corner_radius_all(7 if _is_mini_hand_card() else 8)
		frame.add_theme_stylebox_override("panel", frame_style)
	var art_style := StyleBoxFlat.new()
	art_style.bg_color = Color(state_accent.r, state_accent.g, state_accent.b, 0.42 if _is_mini_hand_card() else 0.28)
	art_style.border_color = Color(state_accent.r, state_accent.g, state_accent.b, 0.82)
	art_style.border_width_left = 1
	art_style.border_width_top = 1
	art_style.border_width_right = 1
	art_style.border_width_bottom = 1
	art_style.corner_radius_top_left = 8
	art_style.corner_radius_top_right = 8
	art_style.corner_radius_bottom_left = 8
	art_style.corner_radius_bottom_right = 8
	art_panel.add_theme_stylebox_override("panel", art_style)
	var cost_badge := get_node_or_null("CardFrame/CardMargin/CardRows/Header/CostBadge") as PanelContainer
	if cost_badge != null:
		var cost_style := StyleBoxFlat.new()
		cost_style.bg_color = Color("#020617").lerp(state_accent, 0.24)
		cost_style.border_color = state_accent
		cost_style.set_border_width_all(1)
		cost_style.set_corner_radius_all(5)
		cost_badge.add_theme_stylebox_override("panel", cost_style)


func _apply_density_for_size() -> void:
	if not is_node_ready():
		return
	var hand_mini := _is_mini_hand_card()
	var inspector_full := _is_inspector_full_card()
	var mini := hand_mini or (not inspector_full and (size.x <= 94.0 or size.y <= 118.0))
	var compact := mini or size.x <= 122.0 or size.y <= 150.0
	var frame := get_node_or_null("CardFrame") as Control
	if frame != null:
		frame.clip_contents = true
	var margin := get_node_or_null("CardFrame/CardMargin") as MarginContainer
	if margin != null:
		var margin_value := 3 if mini else (8 if inspector_full else (5 if compact else 8))
		margin.add_theme_constant_override("margin_left", margin_value)
		margin.add_theme_constant_override("margin_top", margin_value)
		margin.add_theme_constant_override("margin_right", margin_value)
		margin.add_theme_constant_override("margin_bottom", margin_value)
	var rows := get_node_or_null("CardFrame/CardMargin/CardRows") as VBoxContainer
	if rows != null:
		rows.add_theme_constant_override("separation", 2 if mini else (6 if inspector_full else (3 if compact else 6)))
	var cost_badge := get_node_or_null("CardFrame/CardMargin/CardRows/Header/CostBadge") as Control
	if cost_badge != null:
		cost_badge.custom_minimum_size = Vector2(20, 18) if mini else (Vector2(22, 20) if compact else Vector2(28, 26))
	art_panel.custom_minimum_size = Vector2(0, 14 if hand_mini else (58 if inspector_full else (18 if mini else (30 if compact else 70))))
	effect_label.custom_minimum_size = Vector2(0, 20 if hand_mini else (92 if inspector_full else (26 if mini else (34 if compact else 58))))
	effect_label.max_lines_visible = 1 if hand_mini else (7 if inspector_full else (2 if mini else (3 if compact else 4)))
	effect_label.autowrap_mode = TextServer.AUTOWRAP_OFF if hand_mini else TextServer.AUTOWRAP_WORD_SMART
	effect_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	stat_label.custom_minimum_size = Vector2(22, 0) if mini else (Vector2(26, 0) if compact else Vector2(36, 0))
	var font_size := 10 if hand_mini else (12 if inspector_full else (10 if mini else (11 if compact else 15)))
	cost_label.add_theme_font_size_override("font_size", font_size)
	name_label.add_theme_font_size_override("font_size", font_size + (1 if hand_mini else 0))
	art_label.add_theme_font_size_override("font_size", 8 if hand_mini else font_size)
	effect_label.add_theme_font_size_override("font_size", font_size)
	type_label.add_theme_font_size_override("font_size", font_size)
	stat_label.add_theme_font_size_override("font_size", font_size)


func _art_hint_for_type(value: String) -> String:
	return _player_facing_type_label(value)


func _player_facing_type_label(value: String) -> String:
	var trimmed := value.strip_edges()
	if trimmed.is_empty():
		return "行动"
	match trimmed:
		"怪兽":
			return "怪兽"
		"金融":
			return "金融"
		"经济":
			return "经济"
		"情报":
			return "情报"
		"军队":
			return "军队"
		"合约":
			return "合约"
		"商品":
			return "商品"
		"天气":
			return "天气"
		"商路":
			return "商路"
		"互动":
			return "互动"
		"行动":
			return "行动"
	var normalized := trimmed.to_lower()
	match normalized:
		"monster", "monster_bound_action":
			return "怪兽"
		"finance", "financial", "futures":
			return "金融"
		"economy", "economic":
			return "经济"
		"intel", "intelligence", "intel_supply":
			return "情报"
		"military", "force", "military_force", "military_command":
			return "军队"
		"contract", "pact", "contract_route":
			return "合约"
		"goods", "product", "commodity":
			return "商品"
		"weather", "weather_control":
			return "天气"
		"route", "trade", "trade_route":
			return "商路"
		"interaction", "direct_interaction":
			return "互动"
		"action", "card", "skill":
			return "行动"
	if _contains_cjk(trimmed):
		return trimmed
	return "行动"


func _contains_cjk(value: String) -> bool:
	for index in range(value.length()):
		var code := value.unicode_at(index)
		if code >= 0x4e00 and code <= 0x9fff:
			return true
	return false


func _is_mini_hand_card() -> bool:
	var normalized := presentation_mode.strip_edges().to_lower()
	return normalized == "mini_hand" or normalized == "hand_mini" or normalized == "mini"


func _is_inspector_full_card() -> bool:
	var normalized := presentation_mode.strip_edges().to_lower()
	return normalized == PRESENTATION_INSPECTOR_FULL or normalized == "full_inspector" or normalized == "inspector"


func _is_codex_full_card() -> bool:
	var normalized := presentation_mode.strip_edges().to_lower()
	return normalized == PRESENTATION_CODEX_FULL or normalized == "codex"


func _presentation_spec() -> String:
	if _is_mini_hand_card():
		return "MiniCard"
	if _is_inspector_full_card():
		return "inspector_full"
	if _is_codex_full_card():
		return "codex_full"
	return "full"


func _mini_effect_line() -> String:
	var explicit := str(_card_data.get("summary", _card_data.get("short_effect", ""))).strip_edges()
	if explicit != "":
		return _short_card_text(explicit, 24)
	var effect := effect_text.replace("\n", " ").strip_edges()
	if effect == "":
		return "点选查看详情"
	return _short_card_text(effect, 24)


func _mini_status_text() -> String:
	for key in ["play_state", "action_state", "state", "status", "verdict"]:
		var value := str(_card_data.get(key, "")).strip_edges()
		if value != "":
			return _short_card_text(value, 10)
	return "点选详情"


func _mini_route_text(display_type: String) -> String:
	for key in ["route", "lane", "family", "target", "district"]:
		var value := str(_card_data.get(key, "")).strip_edges()
		if value != "":
			var route := _short_card_text(value, 4)
			return _short_card_text("%s｜%s" % [display_type, route], 10)
	return _short_card_text(display_type, 10)


func _mini_rank_text() -> String:
	var rank := stats_text.strip_edges()
	if rank == "":
		rank = str(_card_data.get("tier", _card_data.get("level", ""))).strip_edges()
	if rank == "":
		rank = str(_card_data.get("speed", _card_data.get("timing", ""))).strip_edges()
	return _short_card_text(rank, 5) if rank != "" else "I"


func _inspector_full_effect_text() -> String:
	var lines: Array[String] = []
	var target := str(_card_data.get("target", _card_data.get("target_type", ""))).strip_edges()
	var requirement := str(_card_data.get("requirement", _card_data.get("play_requirement", _card_data.get("condition", "")))).strip_edges()
	var disabled_reason := str(_card_data.get("disabled_reason", _card_data.get("block_reason", ""))).strip_edges()
	var primary_action := _primary_action_label()
	if target != "":
		lines.append("目标｜%s" % target)
	if requirement != "":
		lines.append("条件｜%s" % requirement)
	if effect_text.strip_edges() != "":
		lines.append("效果｜%s" % effect_text.strip_edges())
	if primary_action != "":
		lines.append("主动作｜%s" % primary_action)
	if disabled_reason != "":
		lines.append("暂不可用｜%s" % disabled_reason)
	if lines.is_empty():
		lines.append("点选手牌后在这里查看完整说明。")
	return "\n".join(lines)


func _inspector_full_route_text(display_type: String) -> String:
	var route := str(_card_data.get("route", _card_data.get("family", ""))).strip_edges()
	if route != "":
		return "%s｜%s" % [display_type, _short_card_text(route, 12)]
	return display_type


func _inspector_status_text() -> String:
	var state := _mini_status_text()
	if state != "":
		return state
	return "完整说明"


func _primary_action_label() -> String:
	var actions: Array = _card_data.get("actions", []) if _card_data.get("actions", []) is Array else []
	for action_variant in actions:
		if not (action_variant is Dictionary):
			continue
		var action: Dictionary = action_variant
		if bool(action.get("disabled", false)):
			continue
		var label := str(action.get("label", action.get("id", ""))).strip_edges()
		if label != "":
			return label
	return ""


func _card_visual_state_label() -> String:
	if bool(_interaction_state.get("drop_invalid", false)):
		return "invalid_drop"
	if bool(_interaction_state.get("dragging", false)):
		return "dragging"
	if bool(_interaction_state.get("hovered", false)):
		return "hovered"
	if bool(_interaction_state.get("selected", false)):
		return "selected"
	return "idle"


func _interaction_accent() -> Color:
	if bool(_interaction_state.get("drop_invalid", false)):
		return Color("#fb7185")
	if bool(_interaction_state.get("dragging", false)):
		return Color("#38bdf8")
	if bool(_interaction_state.get("selected", false)):
		return Color("#facc15")
	if bool(_interaction_state.get("hovered", false)):
		return accent_color.lightened(0.16)
	return accent_color


func _interaction_border_width() -> int:
	if bool(_interaction_state.get("drop_invalid", false)) or bool(_interaction_state.get("dragging", false)):
		return 3
	if bool(_interaction_state.get("selected", false)) or bool(_interaction_state.get("hovered", false)):
		return 2
	return 1


func _interaction_fill_weight() -> float:
	if bool(_interaction_state.get("drop_invalid", false)):
		return 0.20
	if bool(_interaction_state.get("dragging", false)):
		return 0.18
	if bool(_interaction_state.get("selected", false)):
		return 0.16
	if _is_mini_hand_card():
		return 0.10
	return 0.07


func _interaction_border_weight() -> float:
	if bool(_interaction_state.get("drop_invalid", false)) or bool(_interaction_state.get("dragging", false)):
		return 0.92
	if bool(_interaction_state.get("selected", false)) or bool(_interaction_state.get("hovered", false)):
		return 0.82
	return 0.72 if _is_mini_hand_card() else 0.48


func _short_card_text(value: String, limit: int) -> String:
	var text := value.strip_edges()
	if text.length() <= limit:
		return text
	return "%s..." % text.left(maxi(1, limit - 3))


func _accent_for_type(value: String) -> Color:
	match _player_facing_type_label(value):
		"怪兽":
			return Color("#fb7185")
		"金融":
			return Color("#facc15")
		"经济":
			return Color("#22c55e")
		"情报":
			return Color("#c084fc")
		"军队":
			return Color("#93c5fd")
		"合约":
			return Color("#f472b6")
		"商品":
			return Color("#fb923c")
		"天气":
			return Color("#38bdf8")
		"商路":
			return Color("#a3e635")
		"互动":
			return Color("#818cf8")
	return accent_color
