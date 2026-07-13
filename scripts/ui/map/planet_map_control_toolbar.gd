extends VBoxContainer
class_name PlanetMapControlToolbar

signal control_action_requested(action_id: String, payload: Dictionary)

const LAYER_IDS := ["all", "product", "route", "intel", "weather", "monster", "city"]

@onready var center_hint_label: Label = %MapCenterHintLabel
@onready var zoom_hint_label: Label = %MapZoomHintLabel
@onready var drag_hint_label: Label = %MapDragHintLabel
@onready var supply_hint_label: Label = %MapOpenSupplyHintLabel
@onready var district_status_label: Label = %MapDistrictStatusLabel
@onready var layer_status_label: Label = %MapLayerStatusLabel
@onready var trade_product_selector: OptionButton = %MapTradeProductSelector
@onready var trade_status_label: Label = %MapTradeStatusLabel
@onready var contract_source_button: Button = %MapContractSourceButton
@onready var contract_target_button: Button = %MapContractTargetButton
@onready var contract_status_label: Label = %MapContractStatusLabel

var _layer_buttons: Dictionary = {}
var _applying_snapshot := false


func _ready() -> void:
	_layer_buttons = {
		"all": %MapLayerAllButton,
		"product": %MapLayerProductButton,
		"route": %MapLayerRouteButton,
		"intel": %MapLayerIntelButton,
		"weather": %MapLayerWeatherButton,
		"monster": %MapLayerMonsterButton,
		"city": %MapLayerCityButton,
	}
	for layer_id_variant: Variant in _layer_buttons:
		var layer_id := str(layer_id_variant)
		var button := _layer_buttons[layer_id] as Button
		button.set_meta("layer_id", layer_id)
		button.pressed.connect(_emit_layer_focus.bind(layer_id))
	trade_product_selector.item_selected.connect(_on_trade_product_selected)
	contract_source_button.pressed.connect(_emit_contract_endpoint.bind("map_contract_source_select", contract_source_button))
	contract_target_button.pressed.connect(_emit_contract_endpoint.bind("map_contract_target_select", contract_target_button))
	_style_command_button(contract_source_button, Color("#38bdf8"))
	_style_command_button(contract_target_button, Color("#f59e0b"))
	set_controls({})


func set_controls(snapshot: Dictionary) -> void:
	_applying_snapshot = true
	_apply_reading_hints(snapshot.get("reading_hints", []))
	_apply_label(district_status_label, snapshot.get("district_status", {}), "⌖ 未选区", "当前未选择区域。")
	_apply_layers(snapshot.get("layers", []), str(snapshot.get("selected_layer_id", "all")))
	_apply_label(layer_status_label, snapshot.get("layer_status", {}), "图层:全图", "当前地图图层焦点。")
	_apply_trade(snapshot.get("trade", {}))
	_apply_button(contract_source_button, snapshot.get("contract_source", {}), "供给端")
	_apply_button(contract_target_button, snapshot.get("contract_target", {}), "需求端")
	_apply_label(contract_status_label, snapshot.get("contract_status", {}), "⇄ 合约未设", "下一张合约牌的供给端与需求端。")
	_applying_snapshot = false


func debug_snapshot() -> Dictionary:
	var rendered_layers: Array = []
	for layer_id_variant: Variant in LAYER_IDS:
		var layer_id := str(layer_id_variant)
		var button := _layer_buttons.get(layer_id) as Button
		if button != null:
			rendered_layers.append({
				"id": layer_id,
				"label": button.text,
				"tooltip": button.tooltip_text,
				"disabled": button.disabled,
				"visible": button.visible,
				"selected": bool(button.get_meta("selected", false)),
			})
	var trade_options: Array = []
	for item_index in range(trade_product_selector.item_count):
		trade_options.append({
			"id": str(trade_product_selector.get_item_metadata(item_index)),
			"label": trade_product_selector.get_item_text(item_index),
			"disabled": trade_product_selector.is_item_disabled(item_index),
		})
	return {
		"component": "PlanetMapControlToolbar",
		"reading_hints": [center_hint_label.text, zoom_hint_label.text, drag_hint_label.text, supply_hint_label.text],
		"district_status": district_status_label.text,
		"rendered_layers": rendered_layers,
		"layer_status": layer_status_label.text,
		"trade_options": trade_options,
		"selected_trade_product_id": _selected_trade_product_id(),
		"trade_status": trade_status_label.text,
		"contract_source": _button_snapshot(contract_source_button),
		"contract_target": _button_snapshot(contract_target_button),
		"contract_status": contract_status_label.text,
	}


func _apply_reading_hints(entries_variant: Variant) -> void:
	var labels := [center_hint_label, zoom_hint_label, drag_hint_label, supply_hint_label]
	var defaults := ["◎ 赌桌中央", "滚轮缩放", "拖拽地图", "双击看牌"]
	var entries: Array = entries_variant if entries_variant is Array else []
	for index in range(labels.size()):
		var entry: Dictionary = entries[index] if index < entries.size() and entries[index] is Dictionary else {}
		_apply_label(labels[index] as Label, entry, defaults[index], defaults[index])


func _apply_layers(entries_variant: Variant, selected_layer_id: String) -> void:
	var entries_by_id: Dictionary = {}
	if entries_variant is Array:
		for entry_variant: Variant in entries_variant:
			if entry_variant is Dictionary:
				var entry := entry_variant as Dictionary
				entries_by_id[str(entry.get("id", ""))] = entry
	for layer_id_variant: Variant in LAYER_IDS:
		var layer_id := str(layer_id_variant)
		var button := _layer_buttons.get(layer_id) as Button
		if button == null:
			continue
		var entry: Dictionary = entries_by_id.get(layer_id, {}) as Dictionary
		var selected := layer_id == selected_layer_id
		button.visible = not entry.is_empty()
		button.text = str(entry.get("label", layer_id.left(1).to_upper()))
		button.tooltip_text = "%s｜%s" % [str(entry.get("text", layer_id)), str(entry.get("tip", "点击切换地图图层。"))]
		button.disabled = bool(entry.get("disabled", false))
		button.set_meta("selected", selected)
		_style_layer_button(button, Color(str(entry.get("accent", "#94a3b8"))), selected)


func _apply_trade(trade_variant: Variant) -> void:
	var trade: Dictionary = trade_variant if trade_variant is Dictionary else {}
	var options: Array = trade.get("options", []) if trade.get("options", []) is Array else []
	trade_product_selector.clear()
	var selected_index := 0
	var selected_product_id := str(trade.get("selected_product_id", ""))
	for option_variant: Variant in options:
		if not (option_variant is Dictionary):
			continue
		var option := option_variant as Dictionary
		var product_id := str(option.get("id", ""))
		trade_product_selector.add_item(str(option.get("label", product_id)))
		var item_index := trade_product_selector.item_count - 1
		trade_product_selector.set_item_metadata(item_index, product_id)
		trade_product_selector.set_item_disabled(item_index, bool(option.get("disabled", false)))
		if product_id == selected_product_id:
			selected_index = item_index
	if trade_product_selector.item_count == 0:
		trade_product_selector.add_item("商路关闭")
		trade_product_selector.set_item_metadata(0, "")
	trade_product_selector.select(clampi(selected_index, 0, trade_product_selector.item_count - 1))
	trade_product_selector.disabled = bool(trade.get("disabled", false))
	trade_product_selector.tooltip_text = str(trade.get("tooltip", "选择要在地图上显示运输路径的商品。"))
	_apply_label(trade_status_label, trade.get("status", {}), "⇄ 商路关", "当前地图不显示商品运输路径。")


func _apply_label(label: Label, entry_variant: Variant, fallback_text: String, fallback_tooltip: String) -> void:
	var entry: Dictionary = entry_variant if entry_variant is Dictionary else {}
	label.text = str(entry.get("text", fallback_text))
	label.tooltip_text = str(entry.get("tooltip", fallback_tooltip))
	label.visible = bool(entry.get("visible", true))


func _apply_button(button: Button, entry_variant: Variant, fallback_text: String) -> void:
	var entry: Dictionary = entry_variant if entry_variant is Dictionary else {}
	button.text = str(entry.get("text", fallback_text))
	button.tooltip_text = str(entry.get("tooltip", ""))
	button.disabled = bool(entry.get("disabled", false))
	button.visible = bool(entry.get("visible", true))


func _on_trade_product_selected(item_index: int) -> void:
	if _applying_snapshot or trade_product_selector.disabled or item_index < 0 or item_index >= trade_product_selector.item_count or trade_product_selector.is_item_disabled(item_index):
		return
	var product_id := ""
	if item_index >= 0 and item_index < trade_product_selector.item_count:
		product_id = str(trade_product_selector.get_item_metadata(item_index))
	_emit_control_action("map_trade_product_select", {"product_id": product_id})


func _emit_layer_focus(layer_id: String) -> void:
	var button := _layer_buttons.get(layer_id) as Button
	if button != null and button.visible and not button.disabled:
		_emit_control_action("map_layer_focus", {"layer_id": layer_id})


func _emit_contract_endpoint(action_id: String, button: Button) -> void:
	if button != null and button.visible and not button.disabled:
		_emit_control_action(action_id, {})


func _emit_control_action(action_id: String, payload: Dictionary) -> void:
	if action_id.strip_edges() != "":
		control_action_requested.emit(action_id, payload.duplicate(true))


func _selected_trade_product_id() -> String:
	var item_index := trade_product_selector.selected
	return str(trade_product_selector.get_item_metadata(item_index)) if item_index >= 0 and item_index < trade_product_selector.item_count else ""


func _button_snapshot(button: Button) -> Dictionary:
	return {"text": button.text, "tooltip": button.tooltip_text, "disabled": button.disabled, "visible": button.visible}


func _style_layer_button(button: Button, accent: Color, selected: bool) -> void:
	button.custom_minimum_size = Vector2(34, 27)
	button.add_theme_font_size_override("font_size", 11)
	button.add_theme_color_override("font_color", Color("#f8fafc"))
	button.add_theme_color_override("font_disabled_color", Color("#64748b"))
	button.add_theme_stylebox_override("normal", _button_style(accent, Color("#020617").lerp(accent, 0.28 if selected else 0.1), 2 if selected else 1))
	button.add_theme_stylebox_override("hover", _button_style(accent.lightened(0.18), Color("#020617").lerp(accent, 0.3), 1))
	button.add_theme_stylebox_override("pressed", _button_style(accent.lightened(0.28), Color("#020617").lerp(accent, 0.4), 1))


func _style_command_button(button: Button, accent: Color) -> void:
	button.custom_minimum_size = Vector2(74, 29)
	button.add_theme_font_size_override("font_size", 11)
	button.add_theme_color_override("font_color", Color("#f8fafc"))
	button.add_theme_color_override("font_disabled_color", Color("#64748b"))
	button.add_theme_stylebox_override("normal", _button_style(accent, Color("#020617").lerp(accent, 0.14), 1))
	button.add_theme_stylebox_override("hover", _button_style(accent.lightened(0.18), Color("#020617").lerp(accent, 0.3), 1))
	button.add_theme_stylebox_override("pressed", _button_style(accent.lightened(0.28), Color("#020617").lerp(accent, 0.4), 1))


func _button_style(accent: Color, fill: Color, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = accent
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(6)
	return style
