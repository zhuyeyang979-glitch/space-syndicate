extends PanelContainer
class_name TopCommoditySushiTrackItem

const ITEM_SNAPSHOT_SCRIPT := preload("res://scripts/viewmodels/commodity_sushi_track_item_snapshot.gd")

signal item_focused(item: ITEM_SNAPSHOT_SCRIPT)
signal claim_requested(item: ITEM_SNAPSHOT_SCRIPT)

@onready var icon_label: Label = %CommodityIconLabel
@onready var name_label: Label = %CommodityNameLabel
@onready var industry_label: Label = %CommodityIndustryLabel
@onready var price_label: Label = %CommodityPriceLabel
@onready var pressure_label: Label = %CommodityPressureLabel
@onready var claim_button: Button = %CommodityClaimButton

var _item: ITEM_SNAPSHOT_SCRIPT
var _selected := false


func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if not mouse_entered.is_connected(_emit_focus):
		mouse_entered.connect(_emit_focus)
	if not focus_entered.is_connected(_emit_focus):
		focus_entered.connect(_emit_focus)
	if claim_button != null and not claim_button.pressed.is_connected(_on_claim_pressed):
		claim_button.pressed.connect(_on_claim_pressed)
	_apply_style()


func set_item(item: ITEM_SNAPSHOT_SCRIPT) -> void:
	_item = item
	if item == null or not item.is_valid():
		visible = false
		return
	visible = true
	icon_label.text = _icon_text(item.public_icon_id)
	name_label.text = item.public_name
	name_label.tooltip_text = item.public_name
	industry_label.text = "%s｜%s" % [
		item.public_industry,
		"¥%d" % item.public_market_price if item.public_market_price >= 0 else "行情 --",
	]
	price_label.text = "供 %d｜需 %d" % [item.public_supply_pressure, item.public_demand_pressure]
	pressure_label.visible = false
	claim_button.disabled = not item.claimable
	claim_button.text = "免费领取" if item.claimable else "暂不可领"
	claim_button.tooltip_text = "领取不支付现金。" if item.claimable else item.public_claim_disabled_reason
	tooltip_text = "%s｜%s\n%s\n%s" % [
		item.public_name,
		item.public_industry,
		item.public_short_effect,
		"供给 %d｜需求 %d｜市场价 ¥%d" % [item.public_supply_pressure, item.public_demand_pressure, item.public_market_price]
	]
	_apply_style()


func set_selected(selected: bool) -> void:
	if _selected == selected:
		return
	_selected = selected
	_apply_style()


func item_snapshot() -> ITEM_SNAPSHOT_SCRIPT:
	return ITEM_SNAPSHOT_SCRIPT.new().apply_dictionary(_item.to_dictionary()) \
		if _item != null and _item.is_valid() else null


func debug_snapshot() -> Dictionary:
	return {
		"slot_id": _item.commodity_slot_id if _item != null else "",
		"card_id": _item.commodity_card_id if _item != null else "",
		"selected": _selected,
		"claimable": _item != null and _item.claimable,
		"claim_button_disabled": claim_button.disabled if claim_button != null else true,
	}


func _gui_input(event: InputEvent) -> void:
	var mouse_event := event as InputEventMouseButton
	if mouse_event != null and mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
		grab_focus()
		_emit_focus()
		accept_event()


func _emit_focus() -> void:
	if _item != null and _item.is_valid():
		item_focused.emit(item_snapshot())


func _on_claim_pressed() -> void:
	if _item == null or not _item.is_valid() or not _item.claimable:
		return
	claim_requested.emit(item_snapshot())


func _apply_style() -> void:
	var accent := _accent_color(_item.display_accent_id if _item != null else "generic")
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#07111f").lerp(accent, 0.14 if _selected else 0.07)
	style.border_color = accent if _selected else Color("#334155").lerp(accent, 0.42)
	style.set_border_width_all(2 if _selected else 1)
	style.set_corner_radius_all(6)
	style.set_content_margin(SIDE_LEFT, 7.0)
	style.set_content_margin(SIDE_RIGHT, 7.0)
	style.set_content_margin(SIDE_TOP, 6.0)
	style.set_content_margin(SIDE_BOTTOM, 6.0)
	add_theme_stylebox_override("panel", style)


func _icon_text(icon_id: String) -> String:
	return {
		"life": "生",
		"energy": "能",
		"industry": "工",
		"technology": "技",
		"commerce": "商",
		"shipping": "运",
	}.get(icon_id, "货")


func _accent_color(accent_id: String) -> Color:
	return {
		"life": Color("#4ade80"),
		"energy": Color("#facc15"),
		"industry": Color("#fb923c"),
		"technology": Color("#67e8f9"),
		"commerce": Color("#f472b6"),
		"shipping": Color("#60a5fa"),
	}.get(accent_id, Color("#cbd5e1"))
