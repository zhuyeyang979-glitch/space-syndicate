extends ColorRect
class_name SpaceSyndicateDistrictSupplyDrawer

signal supply_action_requested(action_id: String, payload: Dictionary)

const MARKET_CARD_SCENE := preload("res://scenes/ui/DistrictSupplyMarketCard.tscn")
const PREVIEW_CARD_SCENE := preload("res://scenes/ui/DistrictSupplyPreviewCard.tscn")
const STATUS_CHIP_SCENE := preload("res://scenes/ui/DistrictSupplyStatusChip.tscn")

@onready var title_label: Label = %DistrictSupplyTitleLabel
@onready var close_button: Button = %DistrictSupplyCloseButton
@onready var rule_strip: Label = %DistrictSupplyRuleStrip
@onready var purchase_status: Control = %DistrictPurchaseWindowStatus
@onready var header_chip_rail: HBoxContainer = %DistrictSupplyShelfChipRail
@onready var market_status_rail: HFlowContainer = %DistrictSupplyMarketStatusRail
@onready var privacy_hint: Label = %DistrictSupplyPrivacyHint
@onready var market_grid: HFlowContainer = %DistrictSupplyMarketGrid
@onready var market_empty_state: Label = %DistrictSupplyMarketEmptyState
@onready var preview_box: VBoxContainer = %DistrictSupplyPreviewBox
@onready var preview_empty_state: Label = %DistrictSupplyPreviewEmptyState

var _snapshot: Dictionary = {}
var _market_card_names: Array[String] = []
var _cards_signature := ""
var _header_signature := ""
var _market_status_signature := ""
var _preview_signature := ""
var _preview_card: Control
var _market_entries_by_name: Dictionary = {}
var _local_preview_card_name := ""


func _ready() -> void:
	if close_button != null and not close_button.pressed.is_connected(_on_close_pressed):
		close_button.pressed.connect(_on_close_pressed)
	clear_supply()


func set_supply(snapshot: Dictionary) -> void:
	_snapshot = snapshot.duplicate(true)
	title_label.text = str(snapshot.get("title", "区域牌架"))
	rule_strip.text = str(snapshot.get("rule_strip", "悬停/单击预览｜双击或购买按钮才报价"))
	rule_strip.tooltip_text = str(snapshot.get("rule_tooltip", rule_strip.text))
	privacy_hint.text = str(snapshot.get("privacy_hint", "只显示当前玩家可见的购买状态；不会公开手牌、弃牌或渠道来源。"))
	privacy_hint.tooltip_text = str(snapshot.get("privacy_tooltip", privacy_hint.text))
	var window_snapshot: Dictionary = snapshot.get("purchase_window", {}) if snapshot.get("purchase_window", {}) is Dictionary else {}
	if purchase_status != null and purchase_status.has_method("set_snapshot"):
		purchase_status.call("set_snapshot", window_snapshot)
	_render_chip_row(header_chip_rail, snapshot.get("header_chips", []), true)
	_render_chip_row(market_status_rail, snapshot.get("market_status", []), false)
	var snapshot_preview: Dictionary = snapshot.get("preview", {}) if snapshot.get("preview", {}) is Dictionary else {}
	if _local_preview_card_name.is_empty():
		_local_preview_card_name = str(snapshot_preview.get("card_name", ""))
	_render_market_cards(snapshot.get("cards", []))
	if _market_entries_by_name.has(_local_preview_card_name):
		var local_entry: Dictionary = _market_entries_by_name.get(_local_preview_card_name, {}) as Dictionary
		var local_preview: Dictionary = local_entry.get("preview", {}) if local_entry.get("preview", {}) is Dictionary else {}
		if local_preview.is_empty() and str(snapshot_preview.get("card_name", "")) == _local_preview_card_name:
			local_preview = snapshot_preview
		_render_preview(local_preview)
	else:
		_local_preview_card_name = str(snapshot_preview.get("card_name", ""))
		_render_preview(snapshot_preview)
	var empty_state: Dictionary = snapshot.get("empty_state", {}) if snapshot.get("empty_state", {}) is Dictionary else {}
	market_empty_state.text = str(empty_state.get("market_text", "当前区域暂无卡牌。"))
	preview_empty_state.text = str(empty_state.get("preview_text", "选择一张区域供牌查看详情。"))
	market_empty_state.visible = _market_card_names.is_empty()
	preview_empty_state.visible = _preview_card == null or not _preview_card.visible


func clear_supply() -> void:
	_snapshot = {}
	_cards_signature = ""
	_header_signature = ""
	_market_status_signature = ""
	_preview_signature = ""
	_market_card_names.clear()
	_market_entries_by_name.clear()
	_local_preview_card_name = ""
	if title_label != null:
		title_label.text = "区域牌架"
	if rule_strip != null:
		rule_strip.text = "悬停/单击预览｜双击或购买按钮才报价"
	if privacy_hint != null:
		privacy_hint.text = "只显示当前玩家可见的购买状态。"
	if purchase_status != null and purchase_status.has_method("set_snapshot"):
		purchase_status.call("set_snapshot", {})
	_clear_children(header_chip_rail)
	_clear_children(market_status_rail)
	_clear_children(market_grid)
	_clear_children(preview_box)
	_preview_card = null
	if market_empty_state != null:
		market_empty_state.visible = true
	if preview_empty_state != null:
		preview_empty_state.visible = true


func debug_snapshot() -> Dictionary:
	var result := _snapshot.duplicate(true)
	result["rendered_card_names"] = _market_card_names.duplicate()
	result["rendered_card_count"] = _market_card_names.size()
	result["market_empty_visible"] = market_empty_state.visible if market_empty_state != null else true
	result["preview_empty_visible"] = preview_empty_state.visible if preview_empty_state != null else true
	result["focus_chain"] = _market_card_names.duplicate()
	result["local_preview_card_name"] = _local_preview_card_name
	result["passive_preview_only"] = true
	if purchase_status != null and purchase_status.has_method("debug_snapshot"):
		result["rendered_purchase_window"] = purchase_status.call("debug_snapshot")
	return result


func _render_chip_row(parent: Container, entries_variant: Variant, header: bool) -> void:
	var entries: Array = entries_variant if entries_variant is Array else []
	var signature := var_to_str(entries)
	if header:
		if signature == _header_signature:
			return
		_header_signature = signature
	else:
		if signature == _market_status_signature:
			return
		_market_status_signature = signature
	_clear_children(parent)
	for entry_variant in entries:
		if not (entry_variant is Dictionary):
			continue
		var chip := STATUS_CHIP_SCENE.instantiate() as Control
		if chip == null:
			continue
		parent.add_child(chip)
		if chip.has_method("set_chip"):
			chip.call("set_chip", entry_variant as Dictionary)


func _render_market_cards(entries_variant: Variant) -> void:
	var entries: Array = entries_variant if entries_variant is Array else []
	var valid_entries: Array[Dictionary] = []
	var card_names: Array[String] = []
	_market_entries_by_name.clear()
	for entry_variant in entries:
		if not (entry_variant is Dictionary):
			continue
		var entry := entry_variant as Dictionary
		var card_name := str(entry.get("card_name", ""))
		if card_name.is_empty():
			continue
		var local_entry := entry.duplicate(true)
		var entry_preview: Dictionary = local_entry.get("preview", {}) if local_entry.get("preview", {}) is Dictionary else {}
		var snapshot_preview: Dictionary = _snapshot.get("preview", {}) if _snapshot.get("preview", {}) is Dictionary else {}
		if entry_preview.is_empty() and str(snapshot_preview.get("card_name", "")) == card_name:
			local_entry["preview"] = snapshot_preview.duplicate(true)
		local_entry["selected"] = card_name == _local_preview_card_name
		valid_entries.append(local_entry)
		card_names.append(card_name)
		_market_entries_by_name[card_name] = local_entry
	var signature := var_to_str(card_names)
	if signature == _cards_signature:
		_update_market_cards(valid_entries)
		return
	_cards_signature = signature
	_market_card_names = card_names
	_clear_children(market_grid)
	for entry in valid_entries:
		var card := MARKET_CARD_SCENE.instantiate() as Control
		if card == null:
			continue
		card.name = "DistrictSupplyMarketCard_%d" % market_grid.get_child_count()
		market_grid.add_child(card)
		if card.has_signal("card_hovered"):
			card.connect("card_hovered", Callable(self, "_on_card_preview_requested").bind("hover"))
		if card.has_signal("card_preview_requested"):
			card.connect("card_preview_requested", Callable(self, "_on_card_preview_requested").bind("click_or_keyboard"))
		if card.has_signal("card_activated"):
			card.connect("card_activated", Callable(self, "_on_card_purchase_requested").bind("market_activation"))
		if card.has_method("set_card"):
			card.call("set_card", entry)
	_sync_market_focus_chain()


func _update_market_cards(entries: Array[Dictionary]) -> void:
	var children := market_grid.get_children()
	if children.size() != entries.size():
		_cards_signature = ""
		_render_market_cards(entries)
		return
	for index in range(entries.size()):
		var card := children[index] as Control
		if card == null or not card.has_method("set_card"):
			_cards_signature = ""
			_render_market_cards(entries)
			return
		card.call("set_card", entries[index])


func _render_preview(entry_variant: Variant) -> void:
	var entry: Dictionary = entry_variant if entry_variant is Dictionary else {}
	var signature := var_to_str(entry)
	if signature == _preview_signature:
		return
	_preview_signature = signature
	if entry.is_empty() or str(entry.get("card_name", "")) == "":
		_clear_children(preview_box)
		_preview_card = null
		return
	if _preview_card != null and is_instance_valid(_preview_card):
		if _preview_card.has_method("set_preview"):
			_preview_card.call("set_preview", entry)
		return
	var preview := PREVIEW_CARD_SCENE.instantiate() as Control
	if preview == null:
		return
	preview.name = "DistrictSupplySelectedPreview"
	preview_box.add_child(preview)
	if preview.has_signal("buy_requested"):
		preview.connect("buy_requested", Callable(self, "_on_card_purchase_requested").bind("preview_button"))
	if preview.has_method("set_preview"):
		preview.call("set_preview", entry)
	_preview_card = preview


func _sync_market_focus_chain() -> void:
	var market_cards: Array[Control] = []
	for child in market_grid.get_children():
		if child is Control and child.has_method("get_card_name"):
			var control := child as Control
			control.focus_mode = Control.FOCUS_ALL
			control.set_meta("runtime_focus_kind", "district_supply_market_card")
			market_cards.append(control)
	for index in range(market_cards.size()):
		var control := market_cards[index]
		if market_cards.size() <= 1:
			control.focus_next = NodePath("")
			control.focus_previous = NodePath("")
			continue
		control.focus_previous = control.get_path_to(market_cards[wrapi(index - 1, 0, market_cards.size())])
		control.focus_next = control.get_path_to(market_cards[wrapi(index + 1, 0, market_cards.size())])


func _on_close_pressed() -> void:
	supply_action_requested.emit("district_supply_close", {})


func _on_card_preview_requested(card_name: String, source: String) -> void:
	if card_name == "" or not _market_entries_by_name.has(card_name):
		return
	_local_preview_card_name = card_name
	var entry: Dictionary = _market_entries_by_name.get(card_name, {}) as Dictionary
	_render_preview(entry.get("preview", {}))
	for child in market_grid.get_children():
		if child is Control and child.has_method("get_card_name") and child.has_method("set_card"):
			var child_name := str(child.call("get_card_name"))
			var child_entry: Dictionary = (_market_entries_by_name.get(child_name, {}) as Dictionary).duplicate(true)
			child_entry["selected"] = child_name == card_name
			child.call("set_card", child_entry)
	set_meta("last_passive_preview_source", source)
	if source != "hover":
		supply_action_requested.emit("district_supply_preview_card", {"card_name": card_name, "source": source})


func _on_card_purchase_requested(card_name: String, source: String) -> void:
	if card_name.is_empty() or str(_snapshot.get("visibility_scope", "public")) != "viewer_private":
		return
	var entry: Dictionary = _market_entries_by_name.get(card_name, {}) as Dictionary
	var preview: Dictionary = entry.get("preview", {}) if entry.get("preview", {}) is Dictionary else {}
	if preview.is_empty() and str((_snapshot.get("preview", {}) as Dictionary).get("card_name", "")) == card_name:
		preview = _snapshot.get("preview", {}) as Dictionary
	var primary_action_id := str(preview.get("primary_action_id", ""))
	if primary_action_id not in ["district_supply_preview_card", "district_supply_purchase_card"]:
		return
	supply_action_requested.emit(primary_action_id, {"card_name": card_name, "source": source})


func _clear_children(parent: Node) -> void:
	if parent == null:
		return
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()
