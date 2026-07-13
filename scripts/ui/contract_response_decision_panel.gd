extends PanelContainer
class_name SpaceSyndicateContractResponseDecisionPanel

signal action_requested(action_id: String)

@onready var title_label: Label = %ContractResponseTitleLabel
@onready var timer_label: Label = %ContractResponseTimerLabel
@onready var route_label: Label = %ContractResponseRouteLabel
@onready var product_label: Label = %ContractResponseProductLabel
@onready var accept_label: Label = %ContractResponseAcceptLabel
@onready var reject_label: Label = %ContractResponseRejectLabel
@onready var privacy_label: Label = %ContractResponsePrivacyLabel
@onready var chip_row: HFlowContainer = %ContractResponseChipRow
@onready var action_grid: GridContainer = %ContractResponseActionGrid


func _ready() -> void:
	visible = false


func set_decision(data: Dictionary) -> void:
	var contract: Dictionary = data.get("contract", {}) if data.get("contract", {}) is Dictionary else {}
	var accent := _entry_color(data, Color("#fbbf24"))
	name = "ContractResponseDecisionPanel"
	tooltip_text = str(data.get("tooltip", data.get("body", "")))
	add_theme_stylebox_override("panel", _panel_style(accent, Color("#020617").lerp(accent, 0.12), 2, 10))
	title_label.text = _short_text(str(data.get("title", "匿名合约签署窗口")), 24)
	title_label.tooltip_text = tooltip_text
	timer_label.text = _timer_text(contract)
	timer_label.visible = timer_label.text != ""
	route_label.text = _short_text(str(contract.get("route", "未知路线")), 52)
	route_label.tooltip_text = str(contract.get("route", ""))
	product_label.text = _short_text("商品｜%s" % str(contract.get("products", "未指定商品")), 56)
	product_label.tooltip_text = str(contract.get("products", ""))
	accept_label.text = _short_text("签约｜%s" % str(contract.get("accept", "按卡面结算")), 64)
	accept_label.tooltip_text = str(contract.get("accept", ""))
	reject_label.text = _short_text("拒绝｜%s" % str(contract.get("reject", "按卡面结算")), 64)
	reject_label.tooltip_text = str(contract.get("reject", ""))
	privacy_label.text = _short_text(str(contract.get("privacy", data.get("body", ""))), 104)
	privacy_label.tooltip_text = str(contract.get("privacy", data.get("body", "")))
	_set_chip_row(data.get("chips", []))
	_set_action_grid(data.get("actions", []))
	visible = true


func _timer_text(contract: Dictionary) -> String:
	var text := str(contract.get("timer_text", "")).strip_edges()
	if text != "":
		return text
	var timer := float(contract.get("timer", -1.0))
	return "%.0fs" % timer if timer >= 0.0 else ""


func _set_chip_row(entries_variant: Variant) -> void:
	for child in chip_row.get_children():
		chip_row.remove_child(child)
		child.queue_free()
	var entries: Array = entries_variant if entries_variant is Array else []
	for entry_variant in entries:
		var entry: Dictionary = entry_variant if entry_variant is Dictionary else {"text": str(entry_variant)}
		var label := Label.new()
		label.name = "ContractResponseDecisionChip"
		label.text = _short_text(str(entry.get("text", entry.get("label", ""))), 14)
		label.tooltip_text = str(entry.get("tooltip", ""))
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		label.add_theme_font_size_override("font_size", 10)
		label.add_theme_color_override("font_color", _entry_color(entry, Color("#fde68a")).lightened(0.12))
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
		button.name = "ContractResponseActionButton"
		button.text = _short_text(str(entry.get("label", entry.get("text", "选择"))), 12)
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
