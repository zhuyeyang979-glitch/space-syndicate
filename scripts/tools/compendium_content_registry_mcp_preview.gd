extends Control
class_name CompendiumContentRegistryMcpPreview

const RegistryScript := preload("res://scripts/content/compendium_content_registry.gd")
const CardCodexDetailScene := preload("res://scenes/ui/CardCodexDetail.tscn")
const ProductCodexDetailScene := preload("res://scenes/ui/ProductCodexDetail.tscn")
const BestiaryDetailScene := preload("res://scenes/ui/BestiaryDetail.tscn")

@onready var category_button_list: VBoxContainer = %CompendiumContentCategoryButtonList
@onready var entry_button_list: VBoxContainer = %CompendiumContentEntryButtonList
@onready var title_label: Label = %CompendiumContentPreviewTitle
@onready var summary_label: Label = %CompendiumContentPreviewSummary
@onready var status_label: Label = %CompendiumContentRegistryStatusLabel
@onready var resource_label: Label = %CompendiumContentResourcePathLabel
@onready var preview_host: Control = %CompendiumContentPreviewHost

var _registry := RegistryScript.new()
var _current_entry_id := ""
var _current_type_filter := "all"


func _ready() -> void:
	_build_category_buttons()
	_rebuild_entry_buttons()
	var ids := entry_ids()
	if not ids.is_empty():
		apply_entry(ids[0])


func entry_ids() -> Array[String]:
	return _registry.entry_ids()


func current_entry_id() -> String:
	return _current_entry_id


func entry_payload(entry_id: String) -> Dictionary:
	return _registry.entry_payload(entry_id)


func registry_validation_records() -> Array:
	return _registry.validate_entries()


func apply_entry(entry_id: String) -> bool:
	var payload := _registry.entry_payload(entry_id)
	if payload.is_empty():
		return false
	_current_entry_id = entry_id
	_show_entry(payload)
	return true


func _build_category_buttons() -> void:
	_clear_children(category_button_list)
	var categories := [
		{"id": "all", "label": "All"},
		{"id": "card", "label": "Cards"},
		{"id": "product", "label": "Products"},
		{"id": "monster", "label": "Monsters"},
	]
	for category in categories:
		var button := Button.new()
		button.name = "%sContentCategoryButton" % str(category.get("id", "")).to_pascal_case()
		button.text = str(category.get("label", ""))
		button.custom_minimum_size = Vector2(0, 32)
		button.toggle_mode = true
		button.button_pressed = str(category.get("id", "")) == _current_type_filter
		button.pressed.connect(func() -> void:
			_current_type_filter = str(category.get("id", "all"))
			_build_category_buttons()
			_rebuild_entry_buttons()
		)
		category_button_list.add_child(button)


func _rebuild_entry_buttons() -> void:
	_clear_children(entry_button_list)
	for entry_id in entry_ids():
		var payload := _registry.entry_payload(entry_id)
		var entry_type := str(payload.get("entry_type", ""))
		if _current_type_filter != "all" and entry_type != _current_type_filter:
			continue
		var button := Button.new()
		button.name = "%sEntryButton" % entry_id.to_pascal_case()
		button.text = "%s | %s" % [entry_type, str(payload.get("display_name", entry_id))]
		button.tooltip_text = str(payload.get("resource_path", ""))
		button.custom_minimum_size = Vector2(0, 34)
		button.pressed.connect(func() -> void:
			apply_entry(entry_id)
		)
		entry_button_list.add_child(button)


func _show_entry(payload: Dictionary) -> void:
	_clear_children(preview_host)
	var entry_id := str(payload.get("entry_id", ""))
	var entry_type := str(payload.get("entry_type", ""))
	title_label.text = str(payload.get("display_name", entry_id))
	summary_label.text = "%s\nType: %s" % [str(payload.get("summary", "")), entry_type]
	resource_label.text = str(payload.get("resource_path", ""))
	status_label.text = _status_for_entry(entry_id)
	match entry_type:
		"card":
			var detail := CardCodexDetailScene.instantiate() as Control
			preview_host.add_child(detail)
			_fill_host(detail)
			if detail.has_method("set_detail"):
				detail.call("set_detail", _registry.to_card_codex_payload(entry_id))
		"product":
			var product := ProductCodexDetailScene.instantiate() as Control
			preview_host.add_child(product)
			_fill_host(product)
			if product.has_method("set_product"):
				product.call("set_product", _registry.to_product_codex_payload(entry_id))
		"monster":
			var bestiary := BestiaryDetailScene.instantiate() as Control
			preview_host.add_child(bestiary)
			_fill_host(bestiary)
			if bestiary.has_method("set_monster"):
				bestiary.call("set_monster", _registry.to_bestiary_payload(entry_id))
		_:
			_render_empty_state("Unknown content type: %s" % entry_type)


func _status_for_entry(entry_id: String) -> String:
	for record_variant in _registry.validate_entries():
		var record: Dictionary = record_variant if record_variant is Dictionary else {}
		if str(record.get("entry_id", "")) == entry_id:
			return "Validation: %s | payload=%s privacy=%s ui=%s" % [
				"passed" if bool(record.get("passed", false)) else "failed",
				str(record.get("payload_checked", false)),
				str(record.get("privacy_checked", false)),
				str(record.get("ui_payload_checked", false)),
			]
	return "Validation: not found"


func _render_empty_state(message: String) -> void:
	var panel := PanelContainer.new()
	panel.name = "CompendiumContentEmptyStateLayer"
	panel.custom_minimum_size = Vector2(420, 150)
	preview_host.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)
	var label := Label.new()
	label.name = "CompendiumContentEmptyStateLabel"
	label.text = message
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color("#bfdbfe"))
	margin.add_child(label)


func _fill_host(control: Control) -> void:
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	control.size_flags_vertical = Control.SIZE_EXPAND_FILL


func _clear_children(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()
