extends PanelContainer
class_name SpaceSyndicateMonsterWagerDecisionPanel

signal action_requested(action_id: String)

@onready var title_label: Label = %MonsterWagerTitleLabel
@onready var timer_label: Label = %MonsterWagerTimerLabel
@onready var matchup_label: Label = %MonsterWagerMatchupLabel
@onready var stats_label: Label = %MonsterWagerStatsLabel
@onready var decision_hint_label: Label = %MonsterWagerDecisionHintLabel
@onready var public_bets_label: Label = %MonsterWagerPublicBetsLabel
@onready var context_label: Label = %MonsterWagerContextLabel
@onready var chip_row: HFlowContainer = %MonsterWagerChipRow
@onready var action_grid: GridContainer = %MonsterWagerActionGrid


func _ready() -> void:
	visible = false


func set_decision(data: Dictionary) -> void:
	var wager: Dictionary = data.get("wager", {}) if data.get("wager", {}) is Dictionary else {}
	var accent := _entry_color(data, Color("#fb923c"))
	name = "MonsterWagerDecisionPanel"
	tooltip_text = str(data.get("tooltip", data.get("body", "")))
	add_theme_stylebox_override("panel", _panel_style(accent, Color("#020617").lerp(accent, 0.13), 2, 10))
	title_label.text = _short_text(str(data.get("title", "怪兽赌局")), 24)
	title_label.tooltip_text = tooltip_text
	timer_label.text = _timer_text(wager)
	timer_label.visible = timer_label.text != ""
	matchup_label.text = _short_text(str(wager.get("matchup", "怪兽遭遇")), 42)
	matchup_label.tooltip_text = tooltip_text
	stats_label.text = _short_text("伤害 %s｜奖池¥%d｜底注%d%%｜已押 %d/%d" % [
		str(wager.get("damage", "暂无")),
		int(wager.get("pool", 0)),
		int(wager.get("base_percent", 0)),
		int(wager.get("decided", 0)),
		int(wager.get("seat_count", 0)),
	], 72)
	decision_hint_label.text = _short_text(str(wager.get("side_hint", data.get("body", ""))), 116)
	decision_hint_label.tooltip_text = str(wager.get("side_hint", data.get("body", "")))
	public_bets_label.text = _short_text("公开下注｜%s" % str(wager.get("public_decisions", "暂无公开下注")), 116)
	public_bets_label.tooltip_text = str(wager.get("public_decisions", "暂无公开下注"))
	context_label.text = _short_text("触发｜%s" % str(wager.get("context", "怪兽遭遇")), 72)
	context_label.tooltip_text = str(wager.get("context", "怪兽遭遇"))
	_set_chip_row(data.get("chips", []))
	_set_action_grid(data.get("actions", []))
	visible = true


func _timer_text(wager: Dictionary) -> String:
	var text := str(wager.get("timer_text", "")).strip_edges()
	if text != "":
		return text
	var timer := float(wager.get("timer", -1.0))
	return "%.0fs" % timer if timer >= 0.0 else ""


func _set_chip_row(entries_variant: Variant) -> void:
	for child in chip_row.get_children():
		chip_row.remove_child(child)
		child.queue_free()
	var entries: Array = entries_variant if entries_variant is Array else []
	for entry_variant in entries:
		var entry: Dictionary = entry_variant if entry_variant is Dictionary else {"text": str(entry_variant)}
		var label := Label.new()
		label.name = "MonsterWagerDecisionChip"
		label.text = _short_text(str(entry.get("text", entry.get("label", ""))), 14)
		label.tooltip_text = str(entry.get("tooltip", ""))
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		label.add_theme_font_size_override("font_size", 10)
		label.add_theme_color_override("font_color", _entry_color(entry, Color("#fed7aa")).lightened(0.12))
		if label.text.strip_edges() != "":
			chip_row.add_child(label)


func _set_action_grid(entries_variant: Variant) -> void:
	for child in action_grid.get_children():
		action_grid.remove_child(child)
		child.queue_free()
	var entries: Array = entries_variant if entries_variant is Array else []
	action_grid.visible = not entries.is_empty()
	action_grid.columns = clampi(entries.size(), 1, 2)
	for entry_variant in entries:
		var entry: Dictionary = entry_variant if entry_variant is Dictionary else {"id": str(entry_variant), "label": str(entry_variant)}
		var action_id := str(entry.get("id", "")).strip_edges()
		var button := Button.new()
		button.name = "MonsterWagerActionButton"
		button.text = _short_text(str(entry.get("label", entry.get("text", "下注"))), 12)
		button.tooltip_text = str(entry.get("tooltip", ""))
		button.disabled = action_id == "" or bool(entry.get("disabled", false))
		button.custom_minimum_size = Vector2(132, 30)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(func() -> void:
			action_requested.emit(action_id)
		)
		action_grid.add_child(button)


func _entry_color(entry: Dictionary, fallback: Color) -> Color:
	var value: Variant = entry.get("accent", entry.get("color", fallback))
	if value is Color:
		return value as Color
	if value is String and str(value).begins_with("#"):
		return Color(str(value))
	return fallback


func _short_text(value: String, limit: int) -> String:
	var text := value.replace("\n", " ").strip_edges()
	if limit <= 0 or text.length() <= limit:
		return text
	return "%s…" % text.substr(0, maxi(1, limit - 1))


func _panel_style(accent: Color, fill: Color, border_width: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = accent
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	return style
